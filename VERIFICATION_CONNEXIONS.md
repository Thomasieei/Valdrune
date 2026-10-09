# Vérification Valdrune 9.4 — 8 octobre 2026

## Résultat

**Supabase connecté et testé. Boutique Stripe intégrée dans le code et déployée, mais encaissements bloqués jusqu'à installation de la clé et du webhook du compte Eclat rouge.**

## Vérifications réalisées

- Import du projet et compilation des scripts avec Godot 4.3 : aucune erreur GDScript.
- Vérification stricte TypeScript des trois fonctions Edge avec les dépendances épinglées : réussie.
- Requêtes réelles Supabase : comptes invités, profils, sauvegarde, lecture privée, chat partagé, portefeuille authentifié.
- Isolation : un compte ne lit pas la sauvegarde ni le portefeuille de l'autre. Écriture directe du solde et appels des RPC financières refusés aux clients.
- Webhooks sans signature refusés ; accès anonyme à la fonction commerciale refusé.
- 13 assertions PostgreSQL dans une transaction annulée : paiement non confirmé sans crédit ; montant incorrect refusé ; crédit et dépense uniques malgré répétitions ; livraison réservée au propriétaire ; reçu et sauvegarde validés ensemble ; remboursement unique ; solde négatif après remboursement empêchant une nouvelle dépense ; pack de départ unique ; annulation de dépense remboursée une seule fois.
- 6 assertions Godot : séparation couronnes gagnées/achetées, absence de duplication lors des récompenses, dépense locale sans toucher au portefeuille acheté, maintien du jeu hors ligne, conservation des jours premium.
- Test réseau avec le vrai script `net.gd` : profil, sauvegarde, classement lus ; état de boutique manquante correctement signalé.
- 775 références statiques et liens de ressources examinés : toutes les ressources nécessaires au jeu sont présentes. Le seul fichier absent dans l'archive d'origine est `tests/plan.gd`, utilisé exclusivement avec l'argument de développement `shot` pour les captures automatisées. Il n'est pas utilisé au lancement normal et n'a pas été remplacé par un fichier inventé.
- L'archive livrée conserve tous les fichiers d'origine. Les assets, scènes, cartes, réglages Godot et réglages d'export restent identiques octet pour octet. Seuls les quatre scripts liés aux connexions/boutique et les notes SQL/passation sont mis à jour ; les sources backend et ce rapport sont ajoutés.

## Limites de la vérification

Aucune transaction bancaire réalisée. Le parcours complet Checkout → paiement réel → notification Stripe n'est pas validé : la clé du bon compte et son webhook restent à installer. Les contrôles d'attribution ont été vérifiés en transaction PostgreSQL annulée, sans créer de solde acheté réel.

Le lancement sans écran vérifie les scripts ; il ne remplace pas un essai visuel et tactile sur téléphone. Le moteur sans rendu produit des avertissements de rendu factice. Aucun export Android signé ni test d'installation APK n'a été effectué dans cette demande.

Les jeux déjà présents dans le projet Supabase restent distincts. Les avertissements de sécurité du projet partagé qui concernent ces autres jeux ne constituent pas une validation de ces jeux.
