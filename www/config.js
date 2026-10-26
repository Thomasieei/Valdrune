/* BUG 404 — configuration du multijoueur (Supabase Realtime)
   Renseigne l'URL du projet et la clé publique « anon » (Project Settings → API).
   Ne mets JAMAIS la clé « service_role » ici : l'APK est lisible par n'importe qui.
   Laissé vide : le jeu marche en partie d'entraînement contre les bots. */
window.BUG404_SUPABASE = {
  url: '',        // ex. 'https://abcdefgh.supabase.co'
  anonKey: '',    // ex. 'eyJhbGciOi...'
  channel: 'bug404',
};
