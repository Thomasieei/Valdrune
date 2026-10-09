# Vérification 9.6

**71 vérifications réussies** : 30 vérifications de sauvegarde, commandes et partie en mouvement, plus les 41 vérifications de régression 9.5.

Le nouveau scénario utilise la vraie scène, le bouton Jouer, les collisions du personnage, les boucles des ennemis et les transitions. Les 30 vérifications ont été exécutées dans Godot 4.3 sans rendu, à pas de temps fixé de 60 Hz. Les 41 vérifications de régression ont également été exécutées avec rendu OpenGL Compatibility sur affichage virtuel ; les captures ont été inspectées. Toutes ces vérifications sont isolées des services en ligne par offline-test.

Aucune erreur GDScript n’a été observée. Les messages du moteur de rendu factice dans l’exécution sans rendu ne représentent pas des erreurs de script. L’environnement graphique utilise un rendu logiciel : son nombre d’images par seconde ne représente pas celui d’un téléphone.

## APK

- Nom : Valdrune 9.6 Test ; version 9.6, code 96 ; ARM64.
- Identifiant conservé : com.thomas.valdrune.preview ; même certificat que l’APK de test 9.5. Il peut mettre à jour cette application de test.
- Le jeu original com.thomas.valdrune reste distinct. Sa partie n’est pas automatiquement importée dans l’application de test.
- Vérifications : signature v1/v2/v3, certificat comparé à 9.5, intégrité ZIP et alignement.
- Tests et clé de signature exclus de l’APK.
- SHA-256 : `6ded9f255faef31d8b6992ae4282b0902fe5d7072cad4bd6c0de5854cb688ebc`.
- Aucun test sur téléphone physique et aucun achat réel n’ont été effectués pendant cette passe.

## Nouveau scénario

- ✔ Première sauvegarde complète créée
- ✔ Nouvelle progression sauvegardée sans supprimer la précédente
- ✔ Argent, équipement et ressources conservés après relecture
- ✔ Fichier interrompu : récupération réelle de la copie de secours
- ✔ Écriture complète interrompue avant remplacement : dernière progression récupérée
- ✔ Une écriture temporaire incomplète ne masque pas la bonne copie
- ✔ Une écriture impossible signale l’échec sans annoncer une réussite
- ✔ Une écriture impossible laisse la progression récupérable
- ✔ Ancienne sauvegarde partielle : équipement existant conservé et cases manquantes complétées
- ✔ Inventaire partiel complété sans perdre les ressources existantes
- ✔ Un élément endommagé ne fait pas perdre les objets valides
- ✔ Scénario sans connexion ni compte créé sur le serveur
- ✔ Bouton Jouer présent sur l’écran réel de démarrage
- ✔ Démarrage utilisable sans fenêtre automatique bloquant le joystick
- ✔ Objectif initial et progression de découverte initialisés
- ✔ Le personnage rejoint réellement le sol après une transition
- ✔ Joystick : déplacement réel sur la carte avec collisions actives
- ✔ Après mise en veille : aucun déplacement dû à un doigt resté bloqué
- ✔ Après interruption : attaque, clavier, touches et zoom relâchés
- ✔ Retour Android ferme le menu sans quitter la partie
- ✔ Ouvrir un menu ne conserve aucune commande de déplacement ou d’attaque
- ✔ Un coup reçu referme le menu pour permettre de réagir immédiatement
- ✔ Un dégât sans attaquant valide ne provoque pas d’erreur de combat
- ✔ Combat réel : approche de la cible puis coups qui touchent
- ✔ Combat réel : une cible de premier tier reste jouable avec l’équipement initial
- ✔ Combat continu : les attaques utilisent la cadence prévue sans se figer
- ✔ Donjon en fonctionnement : apparition sur le sol et entrée sans mort immédiate
- ✔ Première salle : survie possible le temps de réagir avec le héros initial
- ✔ Les ennemis du donjon engagent réellement le joueur
- ✔ Retour du donjon : collisions et sol du monde rétablis
