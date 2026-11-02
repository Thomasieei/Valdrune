class_name MonsterDB
## Définition des créatures. Ajouter une créature = ajouter une entrée ici (aucun code à réécrire).
## model : "bestiary:<fichier>" (créatures Quaternius animées par l'UAL) ou "humain:<tenue>" (squelette universel).
## comportement : "agressif" (poursuit jusqu'au bout), "lache" (fuit sous 35 % de vie), "meute" (alerte ses congénères)

const DEFS := {
	"puglin": {
		"nom": "Puglin pillard", "model": "bestiary:Puglin", "skins": ["T_Puglin_BaseColor_1", "T_Puglin_BaseColor_2", "T_Puglin_BaseColor_3"],
		"scale": 1.0, "rayon": 0.35, "hp": 34, "degats": 6, "defense": 0, "vitesse": 3.6, "course": 5.4,
		"detection": 13.0, "portee": 1.5, "cadence": 1.3, "impact": 0.45,
		"comportement": "lache", "xp": 14, "or": [2, 6], "butin": {"soin": 0.12, "mana": 0.08},
		"anims": {"attente": "Idle", "marche": "Walk", "course": "Jog_Fwd", "attaque": "Punch_Jab", "touche": "Hit_Chest", "mort": "Death01"},
	},
	"zombie": {
		"nom": "Mort errant", "model": "humain:paysan_h", "teinte": Color(0.55, 0.68, 0.5),
		"scale": 1.0, "rayon": 0.4, "hp": 60, "degats": 10, "defense": 1, "vitesse": 1.3, "course": 2.3,
		"detection": 11.0, "portee": 1.6, "cadence": 1.8, "impact": 0.55,
		"comportement": "agressif", "xp": 22, "or": [3, 9], "butin": {"soin": 0.15, "mana": 0.12},
		"anims": {"attente": "b/Zombie_Idle", "marche": "b/Zombie_Walk_Fwd", "course": "b/Zombie_Walk_Fwd", "attaque": "b/Zombie_Scratch", "touche": "Hit_Chest", "mort": "Death01"},
	},
	"imp": {
		"nom": "Diablotin", "model": "bestiary:Imp", "skins": ["T_Imp_BaseColor_1", "T_Imp_BaseColor_2"],
		"scale": 1.0, "rayon": 0.4, "hp": 75, "degats": 13, "defense": 2, "vitesse": 2.6, "course": 5.0,
		"detection": 15.0, "portee": 1.9, "cadence": 1.5, "impact": 0.5,
		"comportement": "meute", "xp": 34, "or": [5, 14], "butin": {"soin": 0.2, "mana": 0.15},
		"anims": {"attente": "Idle", "marche": "Walk", "course": "Jog_Fwd", "attaque": "Sword_Attack", "touche": "Hit_Chest", "mort": "Death01"},
	},
	"imp_brute": {
		"nom": "Brute infernale", "model": "bestiary:Imp", "skins": ["T_Imp_BaseColor_3"],
		"scale": 1.6, "rayon": 0.65, "hp": 260, "degats": 24, "defense": 4, "vitesse": 2.0, "course": 3.6,
		"detection": 16.0, "portee": 2.8, "cadence": 2.2, "impact": 0.6,
		"comportement": "agressif", "xp": 120, "or": [30, 60], "butin": {"soin": 0.8, "mana": 0.6},
		"anims": {"attente": "Idle", "marche": "Walk", "course": "Walk", "attaque": "Sword_Attack", "touche": "Hit_Chest", "mort": "Death01"},
		"elite": true,
	},
}
