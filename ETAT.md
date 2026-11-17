# Brèche Écarlate — ÉTAT DU PROJET
_À lire au début de chaque session, à mettre à jour à la fin._

## Vision (Thomas, 17/11/2026)
Une ville parfaite à PROTÉGER, jeu solo. Habitants nommés qui peuvent mourir ou être enlevés, conséquences réelles (deuil, moral).
Ombres envoyées en patrouille / attaque, qui peuvent mourir et dont la réinvocation coûte de la mana.
Monstres à personnalité (arrogant / prudent) : parlementer, provocation, retraite. Expéditions lointaines en équipe avec mort définitive.
Royaume : économie, justice (juger / enfermer / bannir). Dialogues à conséquences.
Ordre : 1 ville vivante → 2 ombres → 3 monstres à personnalité → 4 expéditions → 5 royaume → 6 dialogues IA.

## Cap : version 1.0 recentrée
Place des Cendres + Brèche rouge (3 donjons, 4 boss, coffres colorés), loot, marchand, runes, groupe avec bots.
Tout le reste est **gelé** par `const V1 = true;` (haut de `www/js/main.js`) : arène, Goulet, îles, taverne/missions,
Sanctuaire, Terres Écarlates/Ancestrales, invasions, ombres, mode agression. Rien n'est supprimé.
Règle : on ne rallume un système que quand la 1.0 est solide, et un seul à la fois.

## Fait
- v1.0-a : gel des modes secondaires (portails arène/îles/Goulet cachés, cartes du menu Brèche masquées, invasions coupées).
- v1.0-b : crash des bots sur la Place corrigé (portails gelés) ; noms complets sur les plaques (la 1re lettre était remplacée par un badge, on lisait « HOMAS »).

- v1.0-c : ÉTAPE 1 VILLE — la Place devient la ville (mode `ville`) ; faux joueurs remplacés par 14 habitants nommés à métier (sauvegardés dans `J.ville`) ; raids de cultistes toutes les 2,5–4 min (1er à 40 s) depuis les anciens portails ; habitants qui fuient, meurent (définitif) ou sont enlevés par les Ravisseurs ; tuer un ravisseur libère l'habitant ; moral, journal, bilan de raid, nouveaux venus si < 10 habitants. Code : section « LA VILLE À PROTÉGER » en fin de main.js.

- v1.0-d : ombres toujours actives en V1 (plus besoin du code THOMAS83), bouton Ombres + touche O pour le panneau de commandement.

- v1.0-e : ÉTAPE 2 OMBRES — plus d’exécutions instantanées (vrais coups, 0,9× tes dégâts) ; ombres ciblables (PV = 50 % des tiens), détruites → réinvocation auto après 5 s pour 20 % de mana max (attend si mana insuffisante) ; ordres « Patrouiller la ville » (ronde de 8 points, attaque tout dans 11 m) et « Attaquer ma cible » ; dès le 2e raid un champion arrogant (×4 PV, ×3 dégâts) qui raille quand il détruit une ombre ; bourreau et défaites mémorisés par ombre (pour l’étape 3).

## Bugs connus
- (à remplir avec les retours de test de Thomas)

## Prochaines étapes
1. Thomas teste la ville (raids, enlèvements, morts) et donne ses retours.
1b. Ensuite : indicateur de direction du raid, enlevés à sauver dans la Brèche, deuil visible (tombes), ombres en patrouille (étape 2).
2. Découper `main.js` (7 400 lignes) en fichiers par système.
3. Polir combat + boss des 3 donjons ; équilibrer la progression T1–T4.
