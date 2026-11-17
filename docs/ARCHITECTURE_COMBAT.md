# Souverain des Ombres — Architecture du système de combat

Ce document traduit la bible (docs/BIBLE_COMBAT.md) en un système concret pour notre moteur réel :
**Three.js dans une WebView Android** (pas Godot). Tout ce qui suit est dimensionné pour ce moteur.

Légende : **[D]** principe documenté (sources en fin de document) · **[H]** hypothèse de conception · **[T]** paramètre à tester sur téléphone.

---

## 0. Audit de l'existant (v0.231)

| Élément | État | Verdict |
|---|---|---|
| Coups du héros | cadence fixe 0,85/0,9/1,2 s, un seul type d'attaque | à refondre : rapide + lourde |
| Défense | parade tenue + parade parfaite 0,4 s, dash invulnérable | trop généreuse : pas de ressource, fenêtre trop large |
| Ressources | mana (sorts), points d'ombre (combo) | manque l'**endurance** |
| Ennemis | poursuite → attaque, jeton d'attaque, sorts à runes, garde/brisure | IA plate : pas de perception, pas d'intention, pas de défense |
| Dégâts | appliqués à un instant de l'animation, portée + cône | correct, à formaliser en phases |
| Caméra | libre, basse, recul au pincement | conforme |
| Lisibilité | éventail rouge, blanc = parer, orange = imparable, cadre de cible | conforme |

## 1. Ce qui produit vraiment de la profondeur (analyse)

1. **Lecture → décision → exécution** [D] : un combat est profond si chaque menace a un signal lisible, plusieurs réponses valables, et un coût d'erreur. (Naughty Dog a allongé les signaux d'attaque de TLOU2 et ajouté l'esquive pour rendre le corps-à-corps tactique.)
2. **Ressource partagée entre attaque et défense** [D] : la posture de Sekiro fonctionne parce qu'attaquer et dévier remplissent la même jauge ennemie ; une parade ratée devient une garde (filet de sécurité), donc on est récompensé sans être puni à l'excès.
3. **Engagement** [D] : une attaque doit avoir préparation / actif / récupération ; la récupération est la fenêtre de punition. Sans elle, pas de contre-jeu.
4. **Pression coordonnée** [D] : jetons d'attaque (DOOM 2016, TLOU2) — 1 mêlée, 1 lourde, 1-2 distance simultanées par cible ; sans jeton l'ennemi garde la pression (se place, menace) au lieu de rester spectateur.
5. **Tampon d'entrée** [D] : 0,1–0,15 s mémorise une intention trop précoce ; au-delà, le contrôle devient « mou ».

### Contradictions à arbitrer
- **Réactivité vs poids** : on garde le poids dans la *récupération* (annulable seulement par l'esquive, à coût d'endurance) et pas dans la *préparation* du joueur (courte). Les ennemis, eux, ont des préparations longues (lisibles).
- **Profondeur vs lisibilité sur 6 pouces** : un seul code couleur au sol (rouge = parable, orange = esquive seulement, runes = zone/sort) ; pas d'icône flottante en plus.
- **Fenêtre de parade 0,15–0,25 s vs latence tactile** [T] : le tactile ajoute ~50–80 ms ; on part sur 0,22 s et on mesure.
- **IA intelligente vs CPU Android** : décision à 4–6 Hz par ennemi (pas à chaque image), perception par distances au carré, pas de lancer de rayons.

## 2. Le système proposé (cohérent, pas un assemblage)

**Cœur : la garde.** Le joueur et les ennemis ont une **Garde** (posture). Frapper, parer et contourner l'attaquent ; bloquer la protège mais l'use. Garde vide = **Brisé** → fenêtre d'exécution. Tout le reste s'articule autour.

**Ressources du héros**
- **PV** : la survie.
- **Endurance** (vert, 100) : esquive −25, blocage tenu −8/s et −coup encaissé×0,6, attaque lourde −20. Se recharge 30/s après 0,6 s sans dépense. À 0 : esquive impossible, garde cassée au coup suivant. [H][T]
- **Mana** (violet) : pouvoirs d'ombre (Télékinésie, ARISE).
- **Points d'ombre** (◆×5) : gagnés en touchant, parant, esquivant parfaitement ; dépensés par la Lame rapide.

**Six compétences du héros (classe : Souverain des ombres, archétype assassin-contrôleur)**
| # | Compétence | Rôle tactique | Risque / contre |
|---|---|---|---|
| 1 | Attaque rapide (toucher ⚔️) | pression, interrompt les préparations légères | peu de dégâts de garde |
| 2 | Attaque lourde (maintenir ⚔️ 0,35 s) | brise la garde, recul | récupération longue : ratée = punie |
| 3 | Parade (🛡️) | bloquer (coût endurance) ; au bon moment 0,22 s → riposte | inutile contre l'orange |
| 4 | Dash | esquive avec invulnérabilité 0,2 s, esquive parfaite → ouverture | coûte 25 d'endurance |
| 5 | Lame rapide | dépense les points, ruée multi-cibles | gaspillée si la cible pare/esquive |
| 6 | Télékinésie | contrôle : interrompt, soulève (×1,5 dégâts), remplit la garde | longue recharge ; les lourds y résistent |
| + | ARISE | relever un vaincu (10 %→, ×2 si exécuté) | coût mana, temps d'incantation |

**Synergies voulues (décisions, pas rotation)** : parade parfaite → riposte → garde fragile → lourde → brisé → exécution ; esquive parfaite → coup critique garanti ; télékinésie → ennemi en l'air → lame ; lourde ratée = ouverture adverse. **Anti-boucle** : un ennemi brisé ou soulevé devient insensible au même contrôle pendant 4 s (pas de chaîne infinie).

## 3. Commandes, caméra, ciblage, locomotion
- Joystick gauche flottant ; caméra au doigt droit libre (jamais automatique), pincer pour reculer (angle conservé).
- Cible : la première attaque prend la plus proche dans le cône avant ; toucher un ennemi la fixe ; anneau rouge au sol + cadre de cible (PV, mana, garde, incantation).
- Locomotion avec inertie (accélération 9, freinage 12), orientation vers la cible pendant les attaques.
- Tampon d'entrée 0,15 s sur attaque/esquive/parade. [D][T]

## 4. États de combat (héros et ennemis, même machine)
`LIBRE → PRÉPARATION → ACTIF → RÉCUPÉRATION → LIBRE`, plus `GARDE`, `ESQUIVE`, `SONNÉ`, `BRISÉ`, `EN L'AIR`, `MORT`.
- Dégâts uniquement pendant **ACTIF**, une fois par cible et par coup (pas de double coup).
- Interruptions : RÉCUPÉRATION annulable par ESQUIVE (héros) ; PRÉPARATION ennemie interrompue par : coup lourd, télékinésie, parade parfaite de l'attaque précédente, attaque rapide **si** la préparation est « légère ».
- Priorités d'animation : MORT > BRISÉ > EN L'AIR > SONNÉ > ACTION > LOCOMOTION.
- Portées/collisions : arc (angle + portée) par attaque, rayon de corps par créature ; pas de physique, distances 2D.

## 5. Architecture de l'IA (couches, 5 Hz)
1. **Perception** : distance, angle (dans le dos ?), action visible du héros (attaque en préparation, garde levée, esquive) avec **délai de réaction** 0,25–0,45 s selon le profil — jamais d'accès direct aux entrées.
2. **Situation** : PV, garde, endurance propre, alliés proches, menace dans le dos, jeton disponible.
3. **Intention par scores d'utilité** : `ATTAQUER, LOURDE, BLOQUER, RECULER, CONTOURNER, PUNIR, SORT, PROTÉGER_ALLIÉ, FEINTE, ATTENDRE`. Score = base(profil) × facteurs de situation × bruit ±10 %.
4. **Exécution** : chaque intention est une petite séquence (aller au créneau, préparer, frapper…).
5. **Évaluation** : l'ennemi retient ce qui a marché (ex. « le joueur esquive tôt » → plus de feintes), mémoire courte de 3 échanges.
6. **Coordination** (directeur) : jetons par cible : 1 mêlée, 1 lourd/imparable, 1 sort ; créneaux d'encerclement à 4–5 m ; un ennemi visible peut prendre le jeton d'un ennemi hors écran.

### Profils
- **Gobelin** (rapide, fragile, opportuniste) : contourne, attaque dans le dos, recule face à une lourde, bondit sur un héros en récupération. Contre : attaque rapide, télékinésie, rester face à lui.
- **Pillard / orc défensif** : garde levée (bloque les rapides de face), riposte après blocage, punit les lourdes ratées, feinte occasionnelle. Contre : lourde au bon moment, contournement, parade de sa riposte.
- **Diablotin mage** (offensif) : garde ses distances, Flammes infernales (runes), recule si on colle. Contre : dash pour le rejoindre, interruption, télékinésie.
- **Boss orc (hache + bouclier)** : voir §6.

## 6. Boss : l'orc à la hache et au bouclier (45–90 s, sans sac à PV)
- **Posture bouclier** : bloque de face, pivote vers un joueur qui contourne (vitesse de rotation limitée → le contournement marche si rapide), charge si on reste loin, coup de bouclier qui repousse.
- **Ouverture** : garde brisée par lourdes/parades ; lourde ratée → il frappe dans la récupération.
- **Feinte** : amorce lisible (bras levé + éventail rouge qui s'arrête à mi-chemin), puis vraie frappe ; signal distinct (l'éventail clignote) pour rester lisible.
- **Changement de posture** (après 2 brisures ou ~50 % PV) : jette le bouclier, hache à deux mains : frappes au sol en onde (orange, esquive), rugissement (gagne de la garde), plus d'ouvertures après ses combos.
- **Dénouement** : plusieurs stratégies viables : parades parfaites, contournement + lourdes, télékinésie pour interrompre la charge.
- Modèle prévu : orc de la branche sl-city (Idle, Walk, Run, Attack, Slam, Hit, Death, Roar).

## 7. Impacts
Hit-stop 50–90 ms selon la force [D] ; recul glissé ; réaction différenciée (léger : rien sur l'ennemi en attaque ; moyen : sursaut ; lourd/critique : recul + vacillement) ; son par matériau (chair/métal/bouclier) ; arcs de lame ; vibration courte sur coup encaissé (si dispo).

## 8. Plan de tests mesurables
| Mesure | Cible | Méthode |
|---|---|---|
| Latence ressentie toucher → animation | < 100 ms | horodatage entrée/1re image d'action (log) |
| Images/s en combat (4 ennemis) | ≥ 50 (≥ 30 bas de gamme) | compteur en jeu |
| Variété d'actions par combat | ≥ 4 types utilisés | journal d'actions |
| Morts comprises | le joueur nomme sa cause | question après mort (« coup orange ? ») |
| Durée boss | 45–90 s pour un joueur moyen | chronomètre |
| Rejouabilité | 3 combats d'affilée sans récompense | ressenti de Thomas |

## 9. Ordre de réalisation
**Maintenant (tranche verticale 1)** : endurance, rapide/lourde, parade 0,22 s + garde tenue qui consomme, tampon 0,15 s, phases d'attaque formelles, IA à intentions pour Diablotin/Pillard/Puglin avec délai de réaction, anti-boucle de contrôle, arène d'entraînement près du camp.
**Ensuite** : boss orc ; gobelin (sl-city) ; vibration ; sons par matériau.
**Plus tard** : autres classes, PvP, équipement qui modifie les attaques.
**Risques** : latence tactile sur la parade (tester), lisibilité à 4+ ennemis, poids des modèles sur téléphones modestes.

## Sources
- DOOM 2016 / TLOU2 — jetons d'attaque : strayspark.studio (attack token system), gamedeveloper.com (Naughty Dog melee, GDC 2021)
- Sekiro — posture/déviation : superjumpmagazine.com, samurai-gamers.com
- Tampon d'entrée : gamedev.net (fenêtre 0,12 s), kindatechnical.com (80–150 ms)
