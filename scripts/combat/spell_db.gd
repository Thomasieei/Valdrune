class_name SpellDB
## Les sorts du seigneur. Ajouter un sort = une entrée ici + son effet dans PlayerCombat._effect().
## Tous les sorts se chargent en maintenant le bouton (plus de puissance, de rayon et de durée, coût +60 % à pleine charge).
## niveau : niveau requis · mana · recharge (s) · portee (m) · incantation (s, interrompue si on est frappé)

const ORDER := ["trait_feu", "egide", "nova_givre", "racines"]

const DEFS := {
	"trait_feu": {"nom": "Trait de feu", "niveau": 1, "mana": 10, "recharge": 1.1, "portee": 24.0, "incantation": 0.0,
		"degats": 16.0, "ratio": 1.6, "rayon": 2.2, "couleur": Color(1.0, 0.55, 0.15), "icone": "feu",
		"desc": "Comète de feu qui explose à l'impact et brûle les ennemis proches."},
	"egide": {"nom": "Égide", "niveau": 2, "mana": 18, "recharge": 14.0, "portee": 0.0, "incantation": 0.0,
		"absorbe": 30.0, "ratio": 3.0, "duree": 8.0, "couleur": Color(0.35, 0.8, 1.0), "icone": "bouclier",
		"desc": "Bulle runique qui absorbe les dégâts pendant 8 s."},
	"nova_givre": {"nom": "Nova de givre", "niveau": 3, "mana": 22, "recharge": 8.0, "portee": 6.5, "incantation": 0.0,
		"degats": 12.0, "ratio": 1.0, "ralenti": 0.45, "duree": 4.0, "couleur": Color(0.6, 0.9, 1.0), "icone": "givre",
		"desc": "Onde de glace autour de vous : dégâts et ralentissement de 55 % pendant 4 s."},
	"racines": {"nom": "Racines", "niveau": 4, "mana": 16, "recharge": 11.0, "portee": 16.0, "incantation": 0.0,
		"degats": 5.0, "ratio": 0.5, "duree": 3.0, "couleur": Color(0.5, 0.85, 0.3), "icone": "racines",
		"desc": "Des racines immobilisent la cible 3 s et l'étouffent."},
}
