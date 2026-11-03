# Royaume — première zone (Godot 4.3, Android)

RPG médiéval-fantastique mobile : le royaume du joueur (château visitable, bourg, champs évolutifs,
forêts, rivière, lac, mine, portail vers le royaume des nains).

## Arborescence
- `scripts/world/layout.gd` : **plan du royaume** (relief, routes, rivière, zones réservées) — source unique
- `scripts/world/terrain.gd` : sol, collision, eau · `roads.gd` : route pavée et ponts
- `scripts/world/castle.gd` : château + donjon (salle du trône, conseil, bibliothèque, armurerie, trésorerie)
- `scripts/world/town.gd` : assemble le bourg et sa vie (marché, forge, habitants) · `fields.gd` : champs évolutifs
- `scripts/world/bourg/` : **bourg de Valmont en MegaKit** — `plan.gd` (tracé des rues, rangées de maisons mitoyennes,
  trottoirs, place, impasse), `bourg.gd` (maison modulaire : colombages, encorbellement, balcon, pignon/gouttereau),
  `mk.gd` (pièces fusionnées par matériau + niveaux de détail), `deco.gd` (arrière-cours, intérieurs visitables),
  `repaire.gd` (grands repaires de bandits : salle commune visitable, cabanes, tours de guet, coffres)
- `scripts/world/places.gd` : ferme/moulin, bûcherons, mine/gisements, ponton, portail, falaises
- `scripts/world/vegetation.gd` : forêts et rochers (MultiMesh par bloc)
- `scripts/player/` : joueur, caméra, commandes tactiles · `scripts/npc/` : gardes, villageois, paysans
- `tools/gen_textures.py` : génère les textures peintes (pierre, tuiles, bois…)

## Combat et RPG (scripts/combat, scripts/ui)
- `monster_db.gd` : créatures (ajouter une entrée = nouvelle créature) · `monster.gd` : IA (errance, poursuite, attaque, fuite, retour, mort, butin)
- `spawner.gd` : repaires et réapparitions · `spell_db.gd` + `player_combat.gd` : sorts, combo d'épée, esquive, potions
- `progression.gd` : niveau, XP, caractéristiques, or (sauvegarde user://seigneur.json) · `fx.gd` : effets visuels · `sfx.gd` : sons
- `anim_retarget.gd` : animations humaines UAL appliquées aux créatures du Bestiary
- Test automatique : `godot --path . res://scenes/royaume.tscn -- --combat` (rapport dans shots/combat_rapport.txt)

## Assets (licences)
- Quaternius — Universal Base Characters, Modular Character Outfits Fantasy, Universal Animation Library 1 & 2 (CC0)
- Avramania — Nature & Terrain Free (voir assets/nature/_doc/License.txt)
- BrokenVector — Low Poly Dungeon (licence Unity Asset Store)
- Modular Village Collection (OBJ)
- Quaternius — Medieval Village MegaKit Standard (CC0) : maisons du bourg (assets/megakit, textures réduites)
- Avramania — Village Builder Free (CC0) : étals, cheminées, enseigne d'auberge (assets/village2)
- Quaternius — Bestiary Dungeon Monsters Kit (Imp, Puglin, CC0)
- Kenney — Particle Pack, RPG Audio, Impact Sounds, Interface Sounds, Music Jingles (CC0, voir assets/licences)
- Textures d'architecture : générées (tools/gen_textures.py)

## APK
Chaque push sur la branche `royaume` construit l'APK (GitHub Actions) et le publie dans les Releases `royaume-v0.1.N`.
⚠️ `android/royaume.keystore` signe l'appli (mot de passe dans le workflow) : la garder pour pouvoir mettre à jour.
