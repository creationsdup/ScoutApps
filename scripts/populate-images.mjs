#!/usr/bin/env node
// populate-images.mjs
// -----------------------------------------------------------------------------
// Associe des images d'un dossier local aux matériels existants dans Supabase,
// puis les téléverse dans le bucket `item-images` et renseigne `image_path`,
// EXACTEMENT comme le fait l'app (chemin `items/<id>.<ext>`, upsert).
//
// Aucune dépendance : Node 18+ (fetch natif). À lancer par TOI, en local, avec
// TES secrets — rien n'est commité.
//
// --- Configuration (variables d'environnement) -------------------------------
//   SUPABASE_URL                 (défaut: projet ScoutManager ci-dessous)
//   SUPABASE_SERVICE_ROLE_KEY    (REQUIS — clé service-role, contourne la RLS)
//   IMAGES_DIR                   (dossier des images, requis pour --apply)
//
// --- Modes -------------------------------------------------------------------
//   node scripts/populate-images.mjs --list
//       Affiche tout le matériel (code | nom | image ?) et écrit
//       `items-list.csv`. Sert à nommer les fichiers du dossier par CODE.
//
//   node scripts/populate-images.mjs --dry-run
//       Fait le matching dossier ↔ matériel et affiche le plan, SANS écrire.
//
//   node scripts/populate-images.mjs --apply
//       Téléverse + met à jour `image_path`. Idempotent (upsert).
//
// --- Nommage des fichiers du dossier -----------------------------------------
//   Par défaut, le nom du fichier (sans extension) = CODE INVENTAIRE.
//     ex.  ANIMA-BALLE-073.jpg   →  matériel ANIMA-BALLE-073
//   Repli : si aucun code ne correspond, on tente une correspondance par NOM
//   (insensible casse/accents). Les ambigus/non trouvés sont listés, pas écrits.
// -----------------------------------------------------------------------------

import { readFile, readdir, writeFile } from "node:fs/promises";
import { basename, extname, join } from "node:path";

const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://vxzlluzkxygjofwgbjzu.supabase.co";
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const IMAGES_DIR = process.env.IMAGES_DIR || "";
const BUCKET = "item-images";

const MODE = process.argv.includes("--apply")
  ? "apply"
  : process.argv.includes("--list")
  ? "list"
  : process.argv.includes("--dry-run")
  ? "dry-run"
  : "help";

const EXT_CONTENT_TYPE = {
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".webp": "image/webp",
  ".heic": "image/heic",
};

function die(msg) {
  console.error(`\n❌ ${msg}\n`);
  process.exit(1);
}

function normalize(s) {
  return (s || "")
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // enlève les accents
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

if (MODE === "help") {
  console.log(`
Usage :
  SUPABASE_SERVICE_ROLE_KEY=... node scripts/populate-images.mjs --list
  SUPABASE_SERVICE_ROLE_KEY=... IMAGES_DIR=./mes-images node scripts/populate-images.mjs --dry-run
  SUPABASE_SERVICE_ROLE_KEY=... IMAGES_DIR=./mes-images node scripts/populate-images.mjs --apply
`);
  process.exit(0);
}

if (!SERVICE_KEY) die("SUPABASE_SERVICE_ROLE_KEY manquant (clé service-role requise).");

const headers = {
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
};

// --- 1. Charger tout le matériel ---------------------------------------------
async function fetchItems() {
  const url =
    `${SUPABASE_URL}/rest/v1/inventory_items` +
    `?select=id,inventory_code,name,image_path&order=inventory_code`;
  const res = await fetch(url, { headers });
  if (!res.ok) die(`Lecture inventory_items échouée : HTTP ${res.status} ${await res.text()}`);
  return res.json();
}

// --- 2. Upload Storage + update image_path -----------------------------------
async function uploadImage(item, filePath, ext) {
  const contentType = EXT_CONTENT_TYPE[ext] || "application/octet-stream";
  const objectPath = `items/${item.id}${ext}`; // même convention que l'app
  const bytes = await readFile(filePath);

  const upRes = await fetch(
    `${SUPABASE_URL}/storage/v1/object/${BUCKET}/${objectPath}`,
    {
      method: "POST",
      headers: { ...headers, "Content-Type": contentType, "x-upsert": "true" },
      body: bytes,
    }
  );
  if (!upRes.ok) throw new Error(`upload ${objectPath} → HTTP ${upRes.status} ${await upRes.text()}`);

  const patchRes = await fetch(
    `${SUPABASE_URL}/rest/v1/inventory_items?id=eq.${item.id}`,
    {
      method: "PATCH",
      headers: { ...headers, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify({ image_path: objectPath }),
    }
  );
  if (!patchRes.ok) throw new Error(`update image_path → HTTP ${patchRes.status} ${await patchRes.text()}`);

  return objectPath;
}

// --- MAIN --------------------------------------------------------------------
const items = await fetchItems();
console.log(`\n📦 ${items.length} matériel(s) chargé(s) depuis Supabase.\n`);

if (MODE === "list") {
  const withImg = items.filter((i) => i.image_path).length;
  console.log(`   ${withImg} avec image, ${items.length - withImg} sans.\n`);
  console.log("CODE".padEnd(20), "IMG", " NOM");
  console.log("-".repeat(60));
  for (const i of items) {
    console.log(
      (i.inventory_code || "—").padEnd(20),
      i.image_path ? " ✓ " : "   ",
      ` ${i.name || ""}`
    );
  }
  const csv =
    "inventory_code,name,has_image\n" +
    items
      .map((i) => `${i.inventory_code || ""},${JSON.stringify(i.name || "")},${i.image_path ? "yes" : "no"}`)
      .join("\n");
  await writeFile("items-list.csv", csv);
  console.log(`\n📝 Liste écrite dans items-list.csv (nomme tes fichiers par CODE).\n`);
  process.exit(0);
}

// dry-run / apply : besoin d'un dossier
if (!IMAGES_DIR) die("IMAGES_DIR manquant (dossier des images).");
const files = (await readdir(IMAGES_DIR)).filter((f) =>
  Object.keys(EXT_CONTENT_TYPE).includes(extname(f).toLowerCase())
);
if (files.length === 0) die(`Aucune image (${Object.keys(EXT_CONTENT_TYPE).join(", ")}) dans ${IMAGES_DIR}.`);

// Index pour le matching
const byCode = new Map(items.map((i) => [normalize(i.inventory_code), i]));
const byName = new Map();
for (const i of items) {
  const k = normalize(i.name);
  if (byName.has(k)) byName.set(k, null); // ambigu
  else byName.set(k, i);
}

const plan = [];
const unmatched = [];
for (const f of files) {
  const stem = basename(f, extname(f));
  const ext = extname(f).toLowerCase();
  let item = byCode.get(normalize(stem));
  let how = "code";
  if (!item) {
    const byNameHit = byName.get(normalize(stem));
    if (byNameHit) { item = byNameHit; how = "nom"; }
  }
  if (item) plan.push({ file: f, ext, item, how });
  else unmatched.push(f);
}

console.log(`🔗 ${plan.length} association(s) trouvée(s), ${unmatched.length} fichier(s) non associé(s).\n`);
for (const p of plan) {
  const tag = p.item.image_path ? "(remplace)" : "(nouveau) ";
  console.log(`  ✓ ${p.file.padEnd(28)} → ${p.item.inventory_code}  ${tag}  par ${p.how} : ${p.item.name}`);
}
if (unmatched.length) {
  console.log(`\n  ⚠️ Non associés (vérifie le nom = code inventaire) :`);
  for (const f of unmatched) console.log(`     - ${f}`);
}

if (MODE === "dry-run") {
  console.log(`\n🧪 Dry-run : rien n'a été écrit. Relance avec --apply pour appliquer.\n`);
  process.exit(0);
}

// --- apply -------------------------------------------------------------------
console.log(`\n🚀 Application sur le backend PARTAGÉ (production)…\n`);
let ok = 0;
const failures = [];
for (const p of plan) {
  try {
    const path = await uploadImage(p.item, join(IMAGES_DIR, p.file), p.ext);
    ok++;
    console.log(`  ✅ ${p.item.inventory_code} ← ${p.file}  (${path})`);
  } catch (e) {
    failures.push({ item: p.item.inventory_code, error: String(e.message || e) });
    console.log(`  ❌ ${p.item.inventory_code} ← ${p.file} : ${e.message || e}`);
  }
}
console.log(`\n✔️  ${ok}/${plan.length} appliqué(s). ${failures.length} échec(s).`);
if (failures.length) {
  console.log(`\nÉchecs :`);
  for (const f of failures) console.log(`  - ${f.item} : ${f.error}`);
  process.exit(1);
}
console.log("");
