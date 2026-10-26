# BUG 404 — notes pour brancher le multijoueur

Branche `bug-404`. Jeu HTML5 + Three.js embarqué dans une WebView Android (aucun Gradle).
Chaque push sur cette branche lance `.github/workflows/apk.yml`, qui construit `out/BUG404.apk`
et le publie dans une Release `bug404-v1.N`.

## Arborescence
- `www/index.html` : tout le jeu (CSS + JS dans le fichier, module ES).
- `www/config.js` : configuration Supabase (vide par défaut = mode entraînement contre bots).
- `www/lib/three/` : Three.js r160 local (build + GLTFLoader + SkeletonUtils + BufferGeometryUtils).
- `www/assets/*.txt` : modèles KayKit en GLB encodé base64 (décodés par `loadAll`).
- `www/assets/s/*.ogg` : sons Kenney.
- `android/` : manifeste, `MainActivity.java` (sert `www/` depuis les assets), icônes, `build.sh`.

## Brancher Supabase (seule chose à faire pour le vrai multijoueur)
1. Dans `www/config.js`, remplir `url` (https://xxxx.supabase.co) et `anonKey` (clé publique anon).
   Ne jamais mettre la clé service_role.
2. Aucune table n'est nécessaire : le jeu utilise uniquement **Realtime Broadcast** sur le canal
   `bug404` (configurable via `channel`). Vérifier que Realtime est activé sur le projet.
3. Pousser sur `bug-404` → l'APK se reconstruit.

## Comment marche le réseau (dans `www/index.html`, section « Réseau »)
- `supabaseTransport(cfg)` : client WebSocket Phoenix minimal (pas de librairie) vers
  `wss://<projet>.supabase.co/realtime/v1/websocket`, join `realtime:bug404`, envoi/réception
  d'évènements broadcast `m`, heartbeat toutes les 25 s, reconnexion auto.
- `makeBusRoot(transport, 8)` : reproduit l'API « room » (presence / peers / onPeers / join(name))
  par-dessus ce transport. Chaque client diffuse son objet « presence » au plus 8 fois/s,
  un peer sans nouvelles depuis 9 s est considéré parti.
- Salles : `lobby` (matchmaking) puis `m-<id>` par partie. L'hôte = le premier joueur de la file ;
  il simule toute la partie (règles, PNJ, bots) et diffuse l'état `w` dans sa presence.
- Si l'hôte part, la partie se termine pour les autres. Si un joueur part, un bot le remplace
  (et lui rend la main s'il revient).

## Pistes d'amélioration côté serveur
- Quota Realtime : 4 joueurs × 8 msg/s ≈ 32 envois/s par partie. Sur le plan gratuit, surveiller
  les limites de messages ; baisser le second paramètre de `makeBusRoot` si besoin.
- Anti-triche : les rôles circulent dans l'état diffusé par l'hôte. Pour un jeu public, déplacer
  l'hôte dans une Edge Function / un serveur autoritaire.
- Comptes, classement, historique de parties : tables Supabase à ajouter (rien n'existe encore).
- Chat vocal de proximité : nécessite WebRTC + un serveur de signalisation (pas implémenté).
