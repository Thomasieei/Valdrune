# TestBot

Bot testeur pour les jeux Android de Thomas. Il joue à ta place pour trouver ce qui casse :
il se déplace (joystick ou toucher), lance les sorts quand ils sont rechargés, ramasse les coffres,
ferme les popups de gain (jamais les boutons d'achat) et note quand le jeu plante ou ne répond plus.

- Les yeux : vue de l'écran (MediaProjection), image réduite à ~400 px, détection par couleur.
- Les mains : service d'accessibilité, vrais gestes (joystick maintenu + touchers en même temps).
- Apprentissage par jeu : coffre, ennemi, perso, sorts, joystick, zones à ignorer.

APK : publié automatiquement dans les Releases (tag `testbot-v1.N`) à chaque push sur cette branche.
