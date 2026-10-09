# Valdrune 9.6 — stabilité et prise en main

- Sauvegarde écrite dans un fichier temporaire complet, puis remplacée après validation ; copie de secours de la dernière progression valide. Une écriture interrompue peut être récupérée au démarrage. Une écriture impossible reste signalée comme non sauvegardée.
- Anciennes sauvegardes partielles : les cases d’équipement et d’inventaire manquantes sont complétées en conservant les valeurs existantes et les objets valides.
- Remise à zéro du joystick, des boutons maintenus, des touches enregistrées et du pincement à l’ouverture/fermeture des menus et lors d’une interruption de l’application.
- Retour Android : ferme le menu ouvert, libère une cible sélectionnée ou ouvre le menu ; il ne ferme plus automatiquement le jeu.
- Démarrage : le guide, le rapport et les récompenses ne s’ouvrent plus automatiquement par-dessus une partie qui vient de commencer. L’objectif initial reste affiché et le guide reste accessible dans Menu.
- Un coup reçu referme un menu qui cachait le combat pour laisser le joueur réagir. L’inventaire conserve son fonctionnement permettant le déplacement.
- Les dégâts sans attaquant valide ne provoquent plus une erreur dans le combat des ennemis.

Les améliorations 9.5 sont conservées : ciblage, cadence des combats, familiers, variantes de donjons, quêtes et chemins.

Aucun tarif, catalogue ou backend de paiement n’a été modifié. Stripe reste en pause. Les 71 vérifications décrites dans VERIFICATION_JEU_v9.6.md passent ; cela ne prouve pas l’absence de tous les bugs ou les performances d’un téléphone.
