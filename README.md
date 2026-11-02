# Royaume — première zone (Godot 4.3, Android)

RPG médiéval-fantastique mobile : le royaume du joueur (château visitable, bourg, champs évolutifs,
forêts, rivière, lac, mine, portail vers le royaume des nains).

## Arborescence
- `scripts/world/layout.gd` : **plan du royaume** (relief, routes, rivière, zones réservées) — source unique
- `scripts/world/terrain.gd` : sol, collision, eau · `roads.gd` : route pavée et ponts
- `scripts/world/castle.gd` : château + donjon (salle du trône, conseil, bibliothèque, armurerie, trésorerie)
- `scripts/world/town.gd` : bourg (maisons à colombages, marché) · `fields.gd` : champs évolutifs
- `scripts/world/places.gd` : ferme/moulin, bûcherons, mine/gisements, ponton, portail, falaises
- `scripts/world/vegetation.gd` : forêts et rochers (MultiMesh par bloc)
- `scripts/player/` : joueur, caméra, commandes tactiles · `scripts/npc/` : gardes, villageois, paysans
- `tools/gen_textures.py` : génère les textures peintes (pierre, tuiles, bois…)

## Assets (licences)
- Quaternius — Universal Base Characters, Modular Character Outfits Fantasy, Universal Animation Library 1 & 2 (CC0)
- Avramania — Nature & Terrain Free (voir assets/nature/_doc/License.txt)
- BrokenVector — Low Poly Dungeon (licence Unity Asset Store)
- Modular Village Collection (OBJ)
- Textures d'architecture : générées (tools/gen_textures.py)

## APK
Chaque push sur la branche `royaume` construit l'APK (GitHub Actions) et le publie dans les Releases `royaume-v0.1.N`.
⚠️ `android/royaume.keystore` signe l'appli (mot de passe dans le workflow) : la garder pour pouvoir mettre à jour.
