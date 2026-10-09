# Vérification du jeu 9.5

Les 41 vérifications de la scène d’intégration ont réussi dans Godot 4.3 avec rendu OpenGL Compatibility, affichage virtuel 1280 × 600 et services en ligne désactivés par `offline-test`. Les captures ciblage_v95.png et gardien_v95.png ont été inspectées.

Le scénario charge le vrai monde, les personnages et les interfaces ; il vérifie les transitions, l’annulation des actions différées, le ciblage, la priorité du bouton ATTAQUE, les cadences, le dompteur en donjon/arène/tour, le gardien, le verrouillage du trésor, les marqueurs de quête et le dégagement des routes. Les mouvements et ennemis sont figés lorsque nécessaire pour rendre les assertions reproductibles.

Aucune erreur de script n’a été observée. Le rendu logiciel de cet environnement ne représente pas les performances d’un téléphone. L’APK n’a pas été installé sur un téléphone Android pendant ces vérifications.

## APK

- Version 9.5, code 95 ; Android 5.0 minimum, cible Android 14, ARM64.
- Application Valdrune 9.5 Test ; identifiant com.thomas.valdrune.preview.
- Signature v1, v2 et v3 vérifiée avec apksigner ; alignement et intégrité ZIP vérifiés.
- Le certificat du premier APK manque : ce test conserve l’ancienne application et utilise une partie distincte. La nouvelle clé de test est fournie séparément pour rendre les prochaines mises à jour possibles.
- SHA-256 : `50ff1705e81ee8247db07c8411b5f97d3177d96800bd6381190740c3418feee9`.

## Résultats

- ✔ Vérification isolée des services en ligne
- ✔ Bouton de ciblage disponible sur mobile
- ✔ Carte et ressources du jeu chargées
- ✔ Un appui d’attaque ne déclenche pas un portail
- ✔ Le mode AUTO ne peut pas entrer seul dans un portail
- ✔ La cible choisie prime sur le monstre le plus proche
- ✔ Une cible hors de portée n’est pas remplacée silencieusement
- ✔ Anneau de sélection visible
- ✔ Loup visuellement agrandi
- ✔ Corps et barre de vie adaptés à l’animal agrandi
- ✔ Attaques ennemies annoncées et espacées
- ✔ Un toucher sur l’animal le sélectionne
- ✔ Une cible verrouillée garde la priorité sur les entrées et PNJ
- ✔ Attaque de base ralentit le rythme du combat
- ✔ Un coup différé est annulé lors d’un changement de zone
- ✔ Recharge des sorts allongée et rafale de sorts empêchée
- ✔ Les projectiles disparaissent au changement de zone
- ✔ L’esquive conserve une vraie recharge
- ✔ Un ancien bond ne ramène pas le héros après un TP
- ✔ Une petite différence de hauteur ne provoque aucun TP
- ✔ Une chute brève n’est pas corrigée prématurément
- ✔ Une chute persistante est corrigée verticalement sur le sol proche
- ✔ La berge n’est plus atteinte par un saut automatique
- ✔ Invocation de familier fonctionnelle avant la transition
- ✔ Dompteur réinitialisé à l’entrée du donjon
- ✔ Donjon complet avec une variante de défi
- ✔ Gardien plus résistant et doté de phases
- ✔ Chaque salle réagit avec son propre groupe
- ✔ Le gardien change de tactique à mi-vie
- ✔ Renforts du gardien au bon tier et comptés dans le nettoyage
- ✔ Le trésor reste scellé tant qu’il reste des ennemis
- ✔ Le trésor se libère après nettoyage du donjon
- ✔ Invocations réinitialisées à la sortie de l’arène
- ✔ Invocations disponibles à l’entrée de la tour
- ✔ Invocations réinitialisées entre deux étages
- ✔ PNJ de quête présent
- ✔ Point d’exclamation pour une quête disponible
- ✔ Point d’interrogation quand la récompense est prête
- ✔ Le marqueur ne se superpose plus au nom du service
- ✔ Arbres récoltables dégagés des chemins et services de la carte 1
- ✔ Une ancienne réapparition ne déclenche plus de TP tardif
