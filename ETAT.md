# Souverain des Ombres — ÉTAT DU PROJET
_À lire au début de chaque session, à mettre à jour à la fin._

## La pépite (vision de Thomas)
Tes ombres sont ton armée ET ton économie, et tu les vois travailler (Solo Leveling + Age of Empires + WoW/Albion).
Relever des morts en ombres (rangs E→S, spécialités, maîtrise qui grandit en travaillant, mana à l'invocation, mort et réinvocation),
les envoyer couper / miner / construire / combattre, voir le royaume grandir en direct ; vrais donjons faits main ; humains à mort définitive.

## Règles
- Une brique à la fois, finie et belle avant la suivante. Ne pas mélanger les styles d'assets (Quaternius / Avramania uniquement).
- Code en modules ES séparés (`www/js/*.js`), un fichier par système.
- Tester dans le navigateur (`window.__s`, `G.accel` pour accélérer le temps en test).

## Structure
- `js/moteur.js` : rendu (2× net, ombres 2048, environnement), caméra « Roblox » (1 doigt tourne, pincer zoome, évite les arbres), joystick, sons, particules, textes flottants.
- `js/persos.js` : personnages Quaternius (corps : tête seule + tenue + coiffure sur le squelette universel), animations UAL (`assets/perso/anims.glb`, 30 clips allégés).
- `js/monde.js` : terrain, forêt instanciée (140 arbres), abattage réel (chute, tronc au sol, souche, repousse 90 s + 60 s), réserve de bois (la pile monte), feu de camp, décor.
- `js/ombres.js` : rangs E–S, maîtrise du bois, IA de bûcheron (chercher → aller → abattre/débiter → porter → déposer), suivre, repos.
- `js/main.js` : éveil (ARISE) des dépouilles, quête guidée, panneau des ombres, action contextuelle, sauvegarde `souverain-v1`.
- Assets : `assets/perso` (Quaternius Universal Base Characters + Outfits + UAL1/2), `assets/nature` (Avramania), `assets/sons` (Kenney), source : branche `royaume`.

## Fait
- v0.1 BRIQUE 1 : relever une ombre (cinématique ÉVEILLE-TOI, rang révélé), l'envoyer au bois, abattage visible, débitage, transport sur l'épaule, dépôt, pile qui grandit, maîtrise qui monte, quête guidée en 5 étapes. Le joueur peut aussi couper lui-même.

## Prochaines briques
2. Construction : scierie, mine, murs ; bâtiments visibles qui se construisent ; détruits = production arrêtée.
3. Vrai donjon fait main (pack donjon de `royaume`, à convertir FBX → GLB) avec boss à mécaniques, ombres puissantes à gagner.
4. Ombres de combat, défense, raids sur la base, mort et réinvocation (mana).
5. Humains (mort définitive, remplacés), dialogues, ennemis conscients.
6. Expansion : autres camps, zones, l'eau.

## Idées de Thomas (17/11) — feuille de route
- [FAIT v0.218] Deux caméras : ⚔️ Héros (3e pers.) / 👑 Souverain (vue AoE : glisser, pincer, tourner à 2 doigts, toucher ombre → toucher arbre/rocher/chantier = ordre ; placement au doigt).
- [FAIT v0.220] Échelle ×1,3, intérieurs visitables (toit/étage/murs côté caméra s’effacent, collisions murs, portes), niveaux 1→3 (scierie, camp, puits) avec échafaudages. À venir : mobilier intérieur, trône/âge qui plafonne les niveaux, dégâts de raid.

- [EN COURS v0.221] Menus enfantins : main 👆 qui guide les quêtes (gestes Souverain), retour hors-ligne, ombres qui signalent qu’elles n’ont plus rien à faire et reprennent leur métier après un chantier, contournement des murs, mobilier intérieur (pack donjon FBX converti). Reste : appui long = détails chiffrés, escalier vers l’étage.
- Puis brique 3 : donjon fait main.

## Vision long terme (Thomas, 17/11) — APRÈS bugs, carte et briques en cours
- **Or / minerai rare** : sert au commerce avec d'autres villes, à améliorer bâtiments et compétences, à faire monter les ombres de niveau, à payer chaque jour les ouvriers humains. Sources : donjons, filons rares (riches ou pauvres) parfois loin du camp.
- **Absence du joueur** : risque élevé de raids (pillards…) sur ressources, bâtiments, habitants. Le joueur peut intervenir en se déplaçant via une ombre.
- **Humains** : viennent si le village a de la réputation (ressources, habitations, nombre de bâtiments, puissance militaire, bonnes relations avec les autres villes). Ils ne travaillent pas sans lit ; horaires de travail réels, repas → nourriture indispensable ; confort et sécurité de la ville comptent.
- À approfondir avant de coder.

## Règle permanente : penser joueur
À chaque brique, se demander : que voit le joueur, que veut-il faire ensuite, qu'est-ce qui l'agace, comment comprend-il ce qu'il gagne ? Anticiper ses besoins plutôt que d'attendre qu'il les demande.

## Décisions de Thomas (17/11, 13h) — ordre de priorité choisi
1. [FAIT v0.224] Mode construction repensé : onglets 🏠 Ville / ⚒️ Métiers / ⚔️ Militaire, tuiles à grosse icône, bâtiments à venir visibles (verrouillés). Icône au-dessus de chaque bâtiment (catégorie/métier + étoiles). **Maison** : capacité d'habitants (👥 0/10, puis 0/20…).
2. [FAIT v0.224] Liste des ombres pensée téléphone : grille compacte, filtres par métier, ordres groupés (pas de défilement sans fin).
3. [FAIT v0.225] Combat du héros (4 pouvoirs : Lame, Télékinésie, Parade, ARISE 10 %→) — 3 pouvoirs en cercle autour du bouton (comme Brèche, vrais symboles) :
   - Lame rapide : enchaînement auto jusqu'à 4 ennemis (scène animée).
   - Télékinésie : soulève 1→3 ennemis au départ, évolue (plus nombreux, plus longtemps, plus de dégâts).
   - Blocage : maintenir = −15 % dégâts (évolutif) + contre-attaque ; parade au bon moment = 0 dégât + coup plus rapide/puissant.
   - Vie, compétences, progression du héros.
4. [EN COURS v0.225 : Diablotins carrière + Puglins clairière] Monstres gardiens (carrière, spots) : placements soignés, vie, butin, compétences, zone rouge au sol, squelette animé.
5. [FAIT v0.226] Camps de bandits vivants (ex. 5 : 1 guetteur, 2 jouent aux cartes, 1 dort sous tente/cabane…) — mises en scène, pas des ennemis posés.
6. Routes constructibles, plusieurs styles.
7. Carte agrandie (place pour camps et zones).
8. Bâtiments à débloquer : forge, boulangerie, boucherie, épicerie, entrepôt, taverne, tour de défense, caserne, archerie.
