# Brèche Écarlate — projet source

Jeu mobile 3D (Three.js r160 + assets KayKit / Kenney / Quaternius, licence CC0).
Place publique avec joueurs-bots, donjons de la Brèche (3 difficultés, 4 boss), Sanctuaire d'Émeraude (raid à 5),
arène classée (1v1 / 2v2 / 3v3 / létale), invasions, îles, classes rares (Ombres, Orage, Assassin), rangs, enchantements, parchemins.

## Arborescence
- `www/` : le jeu complet (HTML5, aucun build nécessaire)
  - `index.html` : page + tout le CSS
  - `js/data.js` : données (tiers, armes, sorts, boss, rangs, parchemins, codes bêta…)
  - `js/items.js` : objets, stats, butin, enchantement
  - `js/engine.js` : rendu Three.js, caméra, acteurs, effets, sons, musique
  - `js/world.js` : construction des zones (Place, donjons, arène, île, Sanctuaire)
  - `js/ui.js` : interface (HUD, menus, fiches objet, marché, classements…)
  - `js/main.js` : boucle de jeu, joueur, IA, modes, sauvegarde
  - `assets/` : modèles 3D (GLB recomposés en JSON), sons, musique, polices
  - `vendor/three/` : Three.js en local (fonctionne hors ligne)
- `android/` : coque Android (WebView) + `build.sh` qui construit l'APK sans Gradle
- `.github/workflows/apk.yml` : construit et publie l'APK à chaque push (Releases `breche-ecarlate-v1.N`)

## Lancer le jeu sur PC
Dans le dossier `www/` : `python3 -m http.server 8000` puis ouvrir http://localhost:8000
(un serveur est nécessaire : les modules JS ne se chargent pas en double-cliquant le fichier).

## Construire l'APK
- Automatique : pousser sur la branche `breche-ecarlate` du dépôt GitHub → l'APK apparaît dans les Releases.
- À la main : avoir le SDK Android (build-tools + platform 34) et Java, puis `ANDROID_HOME=... bash android/build.sh` → `out/BrecheEcarlate.apk`.

⚠️ `android/breche.keystore` est la clé de signature de l'appli (mot de passe dans `build.sh`).
Garde-la : sans elle, les mises à jour ne s'installeront plus par-dessus l'ancienne version.

Sauvegarde du joueur : `localStorage`, clé `breche-ecarlate-v1`.
