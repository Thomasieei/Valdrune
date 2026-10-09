# Valdrune 9.6 — jeu corrigé et connexions conservées

Les améliorations du jeu sont décrites dans `CHANGELOG_v9.6.md` ; 71 vérifications passent. Ouvrir `project.godot` avec Godot 4.3. La boutique Stripe reste en pause à la demande du propriétaire. Aucun nouveau changement serveur ou tarifaire n’a été effectué pour la version 9.6.

## Supabase installé

Projet existant **Jeu**, référence `xtbolgcxyegdwpvpcupc`, URL `https://xtbolgcxyegdwpvpcupc.supabase.co`. L'application utilise uniquement la clé publique déjà présente ; les clés secrètes restent côté serveur.

- Connexion invitée activée, session renouvelée avec son refresh token.
- `valdrune_profiles` : pseudo, puissance et carte ; écriture limitée au propriétaire.
- `valdrune_cloud_saves` : copie privée de `Game.S`, isolée entre utilisateurs.
- `valdrune_chat` : canaux monde/commerce ; nom fourni par le serveur, limitation de fréquence.
- `valdrune_wallets`, `valdrune_orders`, `valdrune_spends` : lecture du propriétaire, écritures financières réservées au serveur.
- Les deux migrations dans `supabase/migrations` sont déjà appliquées. `SUPABASE_SETUP.sql` sert uniquement à initialiser une NOUVELLE base ; ne pas le relancer sur le projet existant.

Les comptes et tables des autres jeux n'ont pas été réutilisés. Leur webhook d'origine a été rétabli à son contenu initial.

## Boutique Stripe : code installé, configuration du bon compte manquante

Le compte Stripe connecté **Eclat rouge** (`acct_1U9gLI2a80QQbpq2`) est actif. La clé `STRIPE_SECRET_KEY` déjà présente sur Supabase appartient à un AUTRE compte (`acct_1UBBNn2VlyTa7Chp`), qui ne peut pas encaisser. Elle est conservée pour les autres jeux et n'est plus utilisée par Valdrune.

Le backend Valdrune refuse une clé associée au mauvais compte. Il attend :

1. `VALDRUNE_STRIPE_RESTRICTED_KEY` ou `VALDRUNE_STRIPE_SECRET_KEY` dans les secrets Supabase, provenant d'Eclat rouge. Privilégier une clé restreinte permettant de lire le compte, lire/créer/expirer les Checkout Sessions, lire les webhooks et les ressources nécessaires aux prix intégrés. Ne jamais mettre cette clé dans Godot, une sauvegarde ou le ZIP.
2. Un webhook du compte Eclat rouge vers `https://xtbolgcxyegdwpvpcupc.supabase.co/functions/v1/valdrune-stripe-webhook`, version API `2026-08-26.dahlia`, pour `checkout.session.completed`, `checkout.session.async_payment_succeeded`, `checkout.session.async_payment_failed`, `checkout.session.expired`, `charge.refunded`.
3. Son secret de signature dans `VALDRUNE_STRIPE_WEBHOOK_SECRET`. Une configuration privée déjà réservée au service serveur peut aussi stocker ces secrets sous `valdrune_stripe_api_key` et `valdrune_stripe_webhook_signing_secret`.

Ces dernières écritures sont bloquées par les permissions de la connexion Stripe actuelle. Aucun paiement réel n'a été réalisé. Le code ne considère pas la boutique prête tant que cette configuration manque.

## Fonctions Edge déployées et fournies

- `valdrune-commerce` : authentification, synchronisation du portefeuille, création de Checkout à tarif serveur, achats en couronnes et validation des livraisons.
- `valdrune-stripe-webhook` : contrôle de signature avant toute attribution ; confirmation des achats et remboursements idempotents.
- `valdrune-payment-return` : page de retour au jeu, sans logique d'attribution.

Le catalogue contient les 45 offres originales (6 offres en euros, 39 en couronnes). Les prix et les effets sont conservés. Les couronnes achetées ne sont accordées qu'après confirmation serveur ; ouvrir ou fermer la page de paiement n'accorde rien. Les reçus persistants évitent de redonner le butin après une reconnexion. Un cheval du pack reste en attente si le sac est plein.

## Limites conservées

La progression et les couronnes gagnées en jeu restent locales afin de préserver le fonctionnement existant hors connexion : cela n'est pas un système anti-triche complet. La copie cloud n'ajoute pas un compte email/Google ni une restauration sur un nouveau téléphone. Ne pas désinstaller l'application ou perdre la session invitée pour un compte contenant des achats sans prévoir une récupération de compte.

Les bots, l'arène et les combats simulés restent ceux du projet. Cette connexion ne crée pas des combats réseau en temps réel. Le certificat du premier APK reste manquant. `Valdrune_v9.6_test.apk` est fourni séparément, avec un identifiant distinct qui conserve l’application existante. La nouvelle clé de test est également conservée séparément ; ne pas changer cette clé pour les prochains APK Preview. Le preset Android original garde `com.thomas.valdrune`, le preset Android Preview utilise `com.thomas.valdrune.preview`. Ce test ne reprend pas automatiquement l’ancienne partie.

Voir `VERIFICATION_CONNEXIONS.md` pour les vérifications et les points non testés.
