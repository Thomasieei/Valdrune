# Brèche Écarlate — ÉTAT DU PROJET
_À lire au début de chaque session, à mettre à jour à la fin._

## Cap : version 1.0 recentrée
Place des Cendres + Brèche rouge (3 donjons, 4 boss, coffres colorés), loot, marchand, runes, groupe avec bots.
Tout le reste est **gelé** par `const V1 = true;` (haut de `www/js/main.js`) : arène, Goulet, îles, taverne/missions,
Sanctuaire, Terres Écarlates/Ancestrales, invasions, ombres, mode agression. Rien n'est supprimé.
Règle : on ne rallume un système que quand la 1.0 est solide, et un seul à la fois.

## Fait
- v1.0-a : gel des modes secondaires (portails arène/îles/Goulet cachés, cartes du menu Brèche masquées, invasions coupées).
- v1.0-b : crash des bots sur la Place corrigé (portails gelés) ; noms complets sur les plaques (la 1re lettre était remplacée par un badge, on lisait « HOMAS »).

## Bugs connus
- (à remplir avec les retours de test de Thomas)

## Prochaines étapes
1. Thomas teste la 1.0 et liste bugs + moment le plus fun.
2. Découper `main.js` (7 400 lignes) en fichiers par système.
3. Polir combat + boss des 3 donjons ; équilibrer la progression T1–T4.
