# FRACTURE : Lame Zéro — prototype combat (étape 2)

Branche `fracture` du dépôt Valdrune. Chaque push construit l'APK `FRACTURE.apk` dans les Releases (tag `fracture-v0.N`).

## GDD court

**Pitch.** Action-RPG mobile façon SAO. Un seul doigt. Tu ne tapes pas des boutons : tu **dessines tes coups**.

**Le Tracé-Rupture (cœur du jeu)**
| Geste | Effet |
|---|---|
| **Tracer** (glisser) | Relier les failles lumineuses de l'ennemi dans l'ordre affiché (1 → 2 → 3 → 4). |
| **Relâcher** | La lame suit exactement ton tracé. Ordre + courbes + timing = multiplicateurs. |
| **Tapoter** | Esquive instantanée (gauche/droite selon le côté tapé), i-frames 0,32 s. |
| **Maintenir** (doigt immobile 0,22 s) | Garde (−70 % dégâts, coûte 1 endurance). Résonance pleine + maintien 0,55 s = Résonance armée (×1,8). |
| **Tracer À TRAVERS une ligne rouge** | Parade. Fenêtre −300/+70 ms, parfaite −90/+50 ms → ralenti, +1 endurance, +Résonance. |

- **Rupture parfaite** = toutes les failles, bon ordre, courbes frôlées (point doré), relâché quand l'anneau se referme (±90 ms) → ×1,5 de plus, hitstop 120 ms, ralenti, ouvre une **Riposte** (fenêtre +1 faille, ×1,3). Une seule riposte d'affilée.
- **Lignes violettes** = imparables : esquive obligatoire (garde = −40 % seulement).
- **Endurance** : 3 losanges. Chaque tracé (hors parade) ou esquive en coûte 1. Recharge 0,9 s/losange. À zéro : tracés ×0,5, pas de parfait.
- **Ressenti** : hitstop par coup, ralentis, tremblement, flash, ondes de choc, étincelles, vibrations natives, sons synthétisés à chaque faille touchée (gamme montante), musique étouffée pendant les ralentis.

**Lames-Mémoire (chacune change le geste)**
| Lame | Effet | Le geste change | Résonance |
|---|---|---|---|
| BRAISE | Brûlure sur chaque faille | Boucle autour d'une faille → Brasier ×1,6 | Le tracé explose |
| CHAÎNE | Liens ×2,2 plus rentables | Repasser sur une faille = coup bonus (×2 max) | Écho qui rejoue tous les coups |
| MIROIR | Lame fantôme symétrique | Trace un seul côté, le reflet frappe l'autre | Triple reflet |
| CHRONO | Temps ×0,4 pendant le tracé | Lent et précis, mais >1,2 s = 2 endurance ; fenêtres parfaites ×1,6 | Temps figé + fenêtre gratuite |

**Contenu du prototype** : tutoriel interactif (≈45 s) → Grunt d'os (failles ×2) → Lame Jumelle (combos, feintes, courbes) → Le Gardien Fêlé (boss, 2 phases, attaque en croix à parer d'un seul tracé, lignes violettes).

**Score de style** : dégâts × combo + Précision, Combo max, Temps, Dégâts évités, Victoire → rang D / C / B / A / S / SS. Le meilleur run est sauvegardé et **rejouable** (replay exact, vitesse ×½ / ×1 / ×2).

## Architecture technique

```
www/
  index.html      UI (DOM) : menus, HUD, popups, résultats
  js/main.js      boot, boucle, menus, présentation de l'état, événements → son/VFX/vibration, replay, perfs
  js/sim.js       SIMULATION DÉTERMINISTE : gestes, failles, parade, IA ennemies, score, tutoriel
  js/render.js    three.js : arène néon, cel-shading + contour, chargement KayKit, caméra logique
  js/fx.js        couche écran orthographique : failles, rubans, lignes, particules, flash (tout poolé)
  js/audio.js     Web Audio : SFX + 2 musiques procédurales + pont vibration Android
  assets/m/*.txt  GLB KayKit allégés (animations inutiles retirées), encodés base64
android/          WebView natif sans Gradle (build.sh), pont JS `AndroidHaptics.vibrate`
```

- **Pas fixe 60 Hz** découplé du rendu, **RNG seedée**, entrées horodatées au pas → le replay est une simple réexécution des entrées : quelques Ko par combat, et la même base servira au **duel fantôme classé** (étape 4).
- Caméra **logique** (sans tremblement) pour toutes les projections de gameplay ; la caméra rendue ajoute shake/punch.
- Toute la logique en temps de jeu (hitstop, ralentis, Chrono) ; la reconnaissance des gestes en temps réel.

## Budget de performance

| Poste | Budget | Mesuré (scène boss) |
|---|---|---|
| Draw calls | ≤ 80 | 47–66 (ville = 1 draw call instancié, particules = 2) |
| Triangles | ≤ 60 k | 24–26 k |
| Textures | ≤ 20 | 13 (atlas KayKit 1 par perso) |
| Mémoire JS | ≤ 120 Mo | 48–51 Mo |
| CPU par frame | ≤ 6 ms | 3–4 ms (Chromium headless) |
| Post-process | aucun | aucun (glow = sprites additifs) |
| Résolution | dpr 1,6 max | **auto** : descend à 0,85 si < 47 fps, remonte si > 58 fps |

⚠️ Les fps mesurés dans mon environnement (10–15) viennent du **rendu logiciel sans GPU** — non représentatifs. Le vrai chiffre se lit sur ton Xiaomi : Pause → INFOS PERFS (fps, ms CPU, draw calls, tris, dpr).

## Backlog priorisé

1. **Retours de ton test** (ressenti du tracé, tailles des failles, fenêtres de parade) — priorité absolue.
2. Équilibrage : HP, fenêtres, coût d'endurance, seuils de rang (le bot de test gagne trop vite).
3. Étape 3 — Hub/quartier néon (Quaternius + rubberduck dès que j'ai les zips), transition < 1 s vers le combat.
4. Étape 4 — Arbre de compétences court + modules passifs, duel classé contre fantômes de replays, saison/classement.
5. Étape 5 — Polish : animations de lame dédiées, plus de patterns de boss, Kenney SFX si dispo, persos anime (phase 2).
