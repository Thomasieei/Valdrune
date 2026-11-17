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

## Structure du code (IMPORTANT)
- **Ne jamais modifier `www/js/main.js`** : il est GÉNÉRÉ par `node tools/assembler.mjs` à partir de `www/js/src/` (ordre dans `src/ORDRE.txt`). Le build APK le régénère tout seul.
- `src/noyau/` : le jeu d'origine découpé par système (00-base, 01-place, 02-ombres, 06-donjon-combat-sorts, 09-ia-ennemis-boss, 11-boucle…).
- `src/v1/` : la vision « ville à protéger » — `ville.js` (habitants, raids), `ombres.js` (escouade, combats, mort, mana), `champions.js`, `captifs.js`, `compagnons.js`, `royaume.js`, `dialogues.js` (parole libre), `vie-ville.js` (cimetière, portails).
- Tout est dans la même portée (concaténation) : une fonction d'un fichier est visible des autres.
- Outils de test (raid forcé, etc.) : seulement si `localStorage['breche-debug'] = '1'`.

## Fait
- v1.0-a : gel des modes secondaires (portails arène/îles/Goulet cachés, cartes du menu Brèche masquées, invasions coupées).
- v1.0-b : crash des bots sur la Place corrigé (portails gelés) ; noms complets sur les plaques (la 1re lettre était remplacée par un badge, on lisait « HOMAS »).

- v1.0-c : ÉTAPE 1 VILLE — la Place devient la ville (mode `ville`) ; faux joueurs remplacés par 14 habitants nommés à métier (sauvegardés dans `J.ville`) ; raids de cultistes toutes les 2,5–4 min (1er à 40 s) depuis les anciens portails ; habitants qui fuient, meurent (définitif) ou sont enlevés par les Ravisseurs ; tuer un ravisseur libère l'habitant ; moral, journal, bilan de raid, nouveaux venus si < 10 habitants. Code : section « LA VILLE À PROTÉGER » en fin de main.js.

- v1.0-d : ombres toujours actives en V1 (plus besoin du code THOMAS83), bouton Ombres + touche O pour le panneau de commandement.

- v1.0-e : ÉTAPE 2 OMBRES — plus d’exécutions instantanées (vrais coups, 0,9× tes dégâts) ; ombres ciblables (PV = 50 % des tiens), détruites → réinvocation auto après 5 s pour 20 % de mana max (attend si mana insuffisante) ; ordres « Patrouiller la ville » (ronde de 8 points, attaque tout dans 11 m) et « Attaquer ma cible » ; dès le 2e raid un champion arrogant (×4 PV, ×3 dégâts) qui raille quand il détruit une ombre ; bourreau et défaites mémorisés par ombre (pour l’étape 3).

- v1.0-f : ÉTAPE 3 PERSONNALITÉS — champions arrogant / prudent / fanatique ; bouton « Parlementer » (< 5,5 m) : raisonner, intimider (chance selon rapport de force, PV restants, personnalité), venger une ombre, interroger sur un enlevé, duel d’honneur (ombres reculent, non ciblables) ; retraite visible (et peut entraîner tout le raid) ; reddition rare à 30 % PV si tu es bien plus fort (épargner / achever) ; rivaux mémorisés (`J.ville.rivaux`) qui reviennent plus forts (40 %).

- v1.0-g : ÉTAPE 4 SAUVETAGE — chaque enlevé est retenu dans un donjon précis (`g.lieu`), près du 4e gardien ; bouton « Libérer » ; il te suit, et rentre vivant si tu sors du donjon sans mourir (moral +12) ; sacrifié au bout de 45 min réelles (moral −10) ; l’interrogatoire du champion révèle le bon donjon ; métiers accordés au genre du prénom.

- v1.0-h : ÉTAPE 5 COMPAGNONS — 3 compagnons d’armes nommés (`J.ville.compagnons`) qui te suivent sur la Place et dans la Brèche (« Parler à » : venir en expédition / rester garder la ville) ; MORT DÉFINITIVE (journal, moral −8, deuil des autres) ; volontaire de remplacement 20 min après une perte ; le captif libéré est ciblable (45 % de tes PV) et peut mourir pendant l’évasion.

- v1.0-i : ÉTAPE 6 ROYAUME — bouton couronne (Place) : trésor de la ville (impôts par habitant/min × moral, perçus aussi hors ligne, 8 h max), impôt léger/normal/lourd (moral), fortifications 0–3 (raids plus petits et espacés), festin (+15 moral), te servir dans le trésor (moral −8), chronique. JUSTICE : affaires toutes les 4–7 min (vol, rixe, complicité avec la Brèche, désertion) avec vérité cachée ; enquête par une ombre (3 min, 90 % fiable) ; acquitter / amende / prison 20 min / bannir (définitif) ; la vérité éclate plus tard (innocent puni → moral −4 à −15 ; complice acquitté → raid massif +3). Niveaux des compagnons alignés sur le tien.

- v1.0-j : ÉTAPE 7 PAROLE LIBRE — « 💬 Parler librement » avec champions, compagnons, et « Interroger l’accusé·e » en justice. Sans clé : mode simple par mots-clés (menace, raisonner, duel, question, avoue…). Avec clé API Anthropic (saisie dans la fenêtre, stockée seulement sur le téléphone, modèle claude-haiku-5-5) : réponses libres en JSON {reponse, action} → actions réelles (retraite, combat, duel, suivre, garder, aveu). L’accusé connaît sa culpabilité cachée et ment s’il est coupable.

- v1.0-k : VILLE VIVANTE II — colonne de lumière rouge sur l’entrée du raid + direction relative à l’écran ; CIMETIÈRE (tombe nommée pour chaque habitant mort/sacrifié et compagnon tombé, coin ouest de la Place) ; PORTAILS À REFERMER toutes les 5–8 min hors raid : un habitant court te prévenir, le portail crache des monstres toutes les 14 s (vagues croissantes) tant qu’il est ouvert, bouton « Refermer » (4 s à moins de 3 m), récompense dégressive selon ta rapidité.

- v1.0-l : NETTOYAGE — main.js découpé en 29 fichiers (src/), assemblage automatique au build ; outils de test cachés derrière breche-debug ; corrections : duel jamais terminé si on quitte la Place (ombres bloquées en escorte), captif sans stats de combat, portails plafonnés à 14 monstres, liste des pillards calculée une fois par image ; lisibilité : plus de plaques sur les ombres, plaque compagnon allégée. Test intégré OK (raid + champion + duel + portail + affaire + sauvetage).

- v1.0-m : AUDIT — vérifs auto : fonctions appelées sans définition (0), UI.* manquants (0), ids DOM (0), sons (0), types de monstres (0), blocs dupliqués ≥ 4 lignes (0), animations (alias OK). Corrections : habitant emprisonné encore ciblé par les pillards ; clé API saisie dans la fenêtre (plus de prompt() natif, « aucune » pour l’effacer) ; ombre en garde = même moteur de combat que les autres ordres (doublon supprimé) ; constructeur d’habitant unique. Appel API testé : atteint api.anthropic.com (401 avec fausse clé → repli mode simple OK).

## Bugs connus
- (à remplir avec les retours de test de Thomas)

## Prochaines étapes
1. Thomas teste la ville (raids, enlèvements, morts) et donne ses retours.
1b. Ensuite : indicateur de direction du raid, enlevés à sauver dans la Brèche, deuil visible (tombes), ombres en patrouille (étape 2).
2. Découper `main.js` (7 400 lignes) en fichiers par système.
3. Polir combat + boss des 3 donjons ; équilibrer la progression T1–T4.
