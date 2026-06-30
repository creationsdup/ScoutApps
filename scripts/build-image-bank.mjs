#!/usr/bin/env node
// build-image-bank.mjs
// -----------------------------------------------------------------------------
// Construit une "banque d'images" locale à partir de TA liste de matériel : pour
// chaque article, cherche une photo LIBRE de droit (API Openverse, licences
// commercial+modification) correspondant au nom, et la télécharge dans
// `image-bank/<CODE_INVENTAIRE>.<ext>`. Écrit aussi `image-bank/manifest.csv`
// (titre, auteur, licence, URL source) pour vérification/attribution.
//
// Le dossier produit alimente ensuite `populate-images.mjs` (upload dans l'app).
//
// Aucune dépendance : Node 18+ (fetch natif). À lancer par TOI, en local.
//
// --- Configuration (variables d'environnement) -------------------------------
//   SUPABASE_URL                 (défaut: projet ScoutManager)
//   SUPABASE_SERVICE_ROLE_KEY    (REQUIS si pas de --from-csv : lit la liste en base)
//   OUT_DIR                      (défaut: ./image-bank)
//   OVERRIDES                    (option: JSON { "ANIMA-BALLE-073": "balle tennis", ... })
//
// --- Modes / options ---------------------------------------------------------
//   --all            traite TOUT le matériel (défaut: seulement ceux SANS image)
//   --from-csv FILE  lit la liste depuis un CSV `inventory_code,name,...`
//                    (p.ex. items-list.csv produit par populate-images --list)
//                    au lieu d'interroger Supabase.
//   --limit N        s'arrête après N articles (utile pour tester un échantillon)
//
// --- Exemples ----------------------------------------------------------------
//   SUPABASE_SERVICE_ROLE_KEY=... node scripts/build-image-bank.mjs --limit 7
//   node scripts/build-image-bank.mjs --from-csv items-list.csv --all
//   OVERRIDES=./overrides.json SUPABASE_SERVICE_ROLE_KEY=... node scripts/build-image-bank.mjs
// -----------------------------------------------------------------------------

import { mkdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";

const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://vxzlluzkxygjofwgbjzu.supabase.co";
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const OUT_DIR = process.env.OUT_DIR || "./image-bank";
const OVERRIDES_FILE = process.env.OVERRIDES || "";

const ALL = process.argv.includes("--all");
const csvIdx = process.argv.indexOf("--from-csv");
const FROM_CSV = csvIdx !== -1 ? process.argv[csvIdx + 1] : "";
const limIdx = process.argv.indexOf("--limit");
const LIMIT = limIdx !== -1 ? parseInt(process.argv[limIdx + 1], 10) : Infinity;

const OV = "https://api.openverse.org/v1/images/";
const UA = "ScoutManager-image-bank/1.0 (local tooling)";
const EXT_FROM_TYPE = {
  "image/jpeg": ".jpg",
  "image/jpg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
};

function die(m) { console.error(`\n❌ ${m}\n`); process.exit(1); }
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// --- Liste du matériel -------------------------------------------------------
function parseCsv(text) {
  const lines = text.split(/\r?\n/).filter(Boolean);
  const header = lines.shift().split(",");
  const ci = header.indexOf("inventory_code");
  const ni = header.indexOf("name");
  const hi = header.indexOf("has_image");
  return lines.map((l) => {
    // name peut être entre guillemets JSON
    const cells = l.match(/("(?:[^"\\]|\\.)*"|[^,]*)/g).filter((_, i) => i % 2 === 0);
    const name = cells[ni]?.startsWith('"') ? JSON.parse(cells[ni]) : cells[ni];
    return {
      inventory_code: cells[ci],
      name,
      image_path: hi !== -1 && cells[hi] === "yes" ? "x" : null,
    };
  });
}

async function loadItems() {
  if (FROM_CSV) return parseCsv(await readFile(FROM_CSV, "utf8"));
  if (!SERVICE_KEY) die("SUPABASE_SERVICE_ROLE_KEY manquant (ou utilise --from-csv).");
  const url =
    `${SUPABASE_URL}/rest/v1/inventory_items` +
    `?select=inventory_code,name,image_path&order=inventory_code`;
  const res = await fetch(url, {
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
  });
  if (!res.ok) die(`Lecture inventory_items : HTTP ${res.status} ${await res.text()}`);
  return res.json();
}

// --- Recherche Openverse -----------------------------------------------------
async function searchImage(query) {
  const url =
    `${OV}?q=${encodeURIComponent(query)}` +
    `&page_size=1&mature=false&license_type=commercial,modification`;
  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await fetch(url, { headers: { "User-Agent": UA } });
    if (res.status === 429) { await sleep(2000 * (attempt + 1)); continue; }
    if (!res.ok) throw new Error(`Openverse HTTP ${res.status}`);
    const data = await res.json();
    return data.results?.[0] || null;
  }
  throw new Error("Openverse: trop de tentatives (429)");
}

async function download(url) {
  const res = await fetch(url, { headers: { "User-Agent": UA } });
  if (!res.ok) throw new Error(`download HTTP ${res.status}`);
  const type = (res.headers.get("content-type") || "").split(";")[0].trim();
  const ext = EXT_FROM_TYPE[type] || ".jpg";
  const buf = Buffer.from(await res.arrayBuffer());
  return { buf, ext };
}

function csvCell(s) { return JSON.stringify(s ?? ""); }

// --- MAIN --------------------------------------------------------------------
let overrides = {};
if (OVERRIDES_FILE) overrides = JSON.parse(await readFile(OVERRIDES_FILE, "utf8"));

let items = await loadItems();
if (!ALL) items = items.filter((i) => !i.image_path);
items = items.slice(0, LIMIT);
if (items.length === 0) die("Aucun matériel à traiter (déjà tous avec image ? essaie --all).");

await mkdir(OUT_DIR, { recursive: true });
console.log(`\n🖼️  Construction de la banque pour ${items.length} matériel(s) → ${OUT_DIR}\n`);

const manifest = [
  "inventory_code,name,query,found,title,creator,license,license_version,source_url,foreign_landing_url",
];
let ok = 0, miss = 0;
for (const it of items) {
  const query = overrides[it.inventory_code] || overrides[it.name] || it.name;
  try {
    const hit = await searchImage(query);
    if (!hit) {
      miss++;
      console.log(`  ∅ ${it.inventory_code.padEnd(18)} aucune image pour « ${query} »`);
      manifest.push([it.inventory_code, csvCell(it.name), csvCell(query), "no", "", "", "", "", "", ""].join(","));
    } else {
      const { buf, ext } = await download(hit.url);
      const file = `${it.inventory_code}${ext}`;
      await writeFile(join(OUT_DIR, file), buf);
      ok++;
      console.log(`  ✓ ${it.inventory_code.padEnd(18)} ${file.padEnd(26)} « ${hit.title || query} » [${hit.license} ${hit.license_version || ""}]`);
      manifest.push([
        it.inventory_code, csvCell(it.name), csvCell(query), "yes",
        csvCell(hit.title), csvCell(hit.creator), hit.license || "", hit.license_version || "",
        csvCell(hit.url), csvCell(hit.foreign_landing_url),
      ].join(","));
    }
  } catch (e) {
    miss++;
    console.log(`  ❌ ${it.inventory_code.padEnd(18)} ${e.message || e}`);
    manifest.push([it.inventory_code, csvCell(it.name), csvCell(query), "error", "", "", "", "", "", ""].join(","));
  }
  await sleep(400); // courtoisie API
}

await writeFile(join(OUT_DIR, "manifest.csv"), manifest.join("\n"));
console.log(`\n✔️  ${ok} téléchargée(s), ${miss} sans résultat. Manifeste : ${join(OUT_DIR, "manifest.csv")}`);
console.log(`\n👉 Vérifie/remplace les images douteuses, puis :`);
console.log(`     IMAGES_DIR='${OUT_DIR}' node scripts/populate-images.mjs --dry-run`);
console.log(`     IMAGES_DIR='${OUT_DIR}' node scripts/populate-images.mjs --apply\n`);
console.log(`ℹ️  Licences CC-BY : pense à créditer les auteurs (cf. manifest.csv) si tu diffuses.\n`);
