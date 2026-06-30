# Remplir les images du matériel (`populate-images.mjs`)

Associe les images d'un dossier local à tes matériels Supabase existants, les
téléverse dans le bucket `item-images` et renseigne `image_path` — **exactement**
comme l'app (chemin `items/<id>.<ext>`, upsert). Aucune dépendance : **Node 18+**.

> ⚠️ Écrit sur le **backend de production partagé** (CampManager inclus). Commence
> toujours par `--list` puis `--dry-run`. Le mode `--apply` est le seul qui écrit.

## 1. Récupère ta clé service-role

Supabase → ton projet → **Project Settings → API → `service_role` secret**
(la clé `secret`, pas la `anon`). Elle contourne la RLS — **ne la commite jamais**,
révoque-la après si tu veux.

## 2. Liste ton matériel (et apprends comment nommer les fichiers)

```bash
export SUPABASE_SERVICE_ROLE_KEY='colle_ta_cle_service_role'
node scripts/populate-images.mjs --list
```

Affiche `CODE | IMG | NOM` pour tout le matériel et écrit `items-list.csv`.
**Nomme chaque image par le CODE INVENTAIRE** du matériel, p. ex. :

```
mes-images/
  ANIMA-BALLE-073.jpg
  ANIMA-BALLO-069.jpg
  ANIMA-BOITE-081.png
  ...
```

(Repli possible par **nom** si le fichier porte le nom du matériel, mais le code
est plus fiable.) Extensions acceptées : `.jpg .jpeg .png .webp .heic`.

## 3. Vérifie le plan (sans rien écrire)

```bash
export SUPABASE_SERVICE_ROLE_KEY='...'
export IMAGES_DIR='./mes-images'
node scripts/populate-images.mjs --dry-run
```

Montre les associations trouvées, ce qui sera **(nouveau)** ou **(remplace)**, et
les fichiers **non associés** (mauvais nom de fichier).

## 4. Applique

```bash
node scripts/populate-images.mjs --apply
```

Téléverse + met à jour `image_path`. Idempotent : relançable sans créer de doublons
(upsert sur le même chemin). À la fin, un récap `appliqués / échecs`.

## 5. Vérifie dans l'app

Onglet **Matériel** → les vignettes doivent apparaître. (Tire pour rafraîchir.)

---

**Notes**
- Le bucket `item-images` doit être **public** (l'app lit via `getPublicURL`). S'il
  ne l'est pas, les vignettes ne s'afficheront pas même après upload.
- `SUPABASE_URL` a une valeur par défaut (projet ScoutManager) ; surcharge-la si besoin.
