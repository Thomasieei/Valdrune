# FRACTURE : Lame Zéro — Assets utilisés

Règle : uniquement des assets libres (CC0 / MIT / OFL) ou générés par le code. Chaque entrée indique l'hébergement réel.

| Asset | Auteur | Licence | Source | Hébergement | Utilisé pour |
|---|---|---|---|---|---|
| KayKit Character Pack : Adventurers 1.0 — `Knight.glb` (20 animations gardées sur 76) | Kay Lousberg | CC0 1.0 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 (commit épinglé `672074b`) | GitHub ✅ | Héros « Lame Zéro », épée 1 main et 2 mains (greffées sur les ennemis) |
| KayKit Character Pack : Skeletons 1.0 — `Skeleton_Minion.glb`, `Skeleton_Rogue.glb`, `Skeleton_Warrior.glb` (11 à 15 animations gardées) | Kay Lousberg | CC0 1.0 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 | GitHub ✅ | Grunt d'os, Lame Jumelle, Le Gardien Fêlé (×1,75) |
| Orbitron (variable) | Matt McInerney | SIL OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/orbitron | GitHub ✅ | Titres, HUD, chiffres des failles |
| Rajdhani SemiBold / Bold | Indian Type Foundry | SIL OFL 1.1 | https://github.com/google/fonts/tree/main/ofl/rajdhani | GitHub ✅ | Textes d'interface |
| three.js r160 (+ GLTFLoader) | mrdoob & contributeurs | MIT | https://github.com/mrdoob/three.js | GitHub ✅ | Moteur de rendu (déjà dans le dépôt) |

Licences complètes : `www/fonts/OFL-Orbitron.txt`, `www/fonts/OFL-Rajdhani.txt`. KayKit : texte CC0 lu dans `LICENSE.txt` de chaque dépôt (attribution facultative, créditée ici).

## Générés par le code (aucune licence tierce)

| Élément | Comment |
|---|---|
| Musique combat (140 BPM) et hub (92 BPM) | Synthèse Web Audio en temps réel (`www/js/audio.js`) |
| Tous les bruitages (impacts, parades, esquives, failles, Résonance, boss…) | Synthèse Web Audio (`www/js/audio.js`) |
| Ville néon, ciel, Fracture céleste, enseignes, sol de l'arène | Shaders + textures canvas (`www/js/render.js`) |
| VFX : failles, traînées de lame, lignes d'attaque, étincelles, ondes de choc, flash/vignette | Shaders en espace écran, poolés (`www/js/fx.js`) |
| Cel-shading + contour | `MeshToonMaterial` + liseré néon + coque inversée (three.js) |
| Icône de l'appli | Dessinée en Python/PIL |

## Validés mais PAS encore intégrés (et pourquoi)

| Asset | Statut |
|---|---|
| Quaternius Sci-Fi Essentials Kit (CC0) | Validé. Hébergé sur quaternius.com, **inaccessible depuis mon environnement de build** (proxy). Prévu étape 3 (hub) : il me faudra soit le zip déposé dans le dépôt, soit l'accès au site. |
| Quaternius Modular Sci-Fi MegaKit (CC0) | Idem — étape 3. |
| Frosty Cyberpunk Interior / rubberduck (CC0) | Idem (itch.io) — étape 3. |
| Kenney Impact / Interface / Sci-Fi Sounds (CC0) | Validé, mais **kenney.nl bloqué depuis mon environnement**. Remplacé pour l'instant par des SFX synthétisés (zéro risque de licence). Si tu poses les zips dans le dépôt, je les branche. |
| three.quarks (MIT) | Validé, mais npm et jsDelivr bloqués ici et le dépôt GitHub ne contient que les sources TypeScript (build impossible sans npm). Remplacé par un système de particules maison poolé (2 draw calls pour toutes les particules). Échange possible plus tard sans toucher à la logique. |
