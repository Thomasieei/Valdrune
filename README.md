# Valdrune

Jeu mobile Android (Godot 4.3) façon Albion Online, assets KayKit.

**Version actuelle : 9.7** Ouvrir `project.godot` avec Godot 4.3.

Les combats disposent d’un ciblage tactile, d’une cadence plus lente et d’une fenêtre de riposte. Les familiers sont réinitialisés lors des transitions, les animaux ennemis sont agrandis et les chemins de la première carte sont dégagés. Les donjons utilisent trois variantes et un gardien à deux phases.

## APK de test

`Valdrune_v9.6_test.apk` est fourni séparément. Il s’installe sous le nom **Valdrune 9.6 Test**, identifiant `com.thomas.valdrune.preview`, à côté de l’application existante. Il utilise sa propre partie et ne récupère pas automatiquement les données privées de l’ancien APK. Ne pas désinstaller le jeu existant pour installer ce test.

Le certificat du premier APK n’est plus disponible. Le preset `Android` conserve l’identifiant original ; le preset `Android Preview` permet de reconstruire le test avec la nouvelle clé de test, fournie séparément et à conserver pour les prochaines mises à jour. Ce certificat de développement n’est pas un certificat de publication.

## Vérifications

Voir `CHANGELOG_v9.6.md` pour les modifications, `VERIFICATION_JEU_v9.6.md` pour les tests et `POUR_CHATGPT.md` pour la configuration existante. La boutique Stripe reste en pause.

La scène `tests/gameplay_v95.tscn` réalise les vérifications du jeu sans connexion aux services en ligne. Sur Linux, utiliser un dossier de données distinct :

```bash
XDG_DATA_HOME="$PWD/.qa-data" godot --headless --path . res://tests/gameplay_v95.tscn -- offline-test
```

Les résultats sont enregistrés dans `tests/artifacts`. Les tests sont exclus de l’export Android.

La version 9.6 garde la signature et l’identifiant du test 9.5. Voir `AVANT_COMMERCIALISATION.md` pour les points encore nécessaires avant un lancement payant.
