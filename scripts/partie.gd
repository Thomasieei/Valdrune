extends Node





signal change
signal message(texte: String, couleur: Color)
signal butin(objet: Dictionary)

const CHEMIN := "user://partie.json"
const RANGS := ["E", "D", "C", "B", "A", "S"]
const COULEURS_RANG := [Color(0.7, 0.72, 0.75), Color(0.4, 0.85, 0.45), Color(0.35, 0.65, 1.0),
	Color(0.72, 0.42, 1.0), Color(1.0, 0.62, 0.2), Color(1.0, 0.25, 0.3)]

const RARETES := ["Commun", "Rare", "Épique", "Légendaire", "Mythique", "Unique", "Shiny"]
const SIGLES := ["C", "R", "É", "L", "M", "U", "★"]
const COULEURS_RARETE := [Color(0.62, 0.66, 0.72), Color(0.3, 0.6, 1.0), Color(0.72, 0.35, 1.0),
	Color(1.0, 0.68, 0.15), Color(1.0, 0.25, 0.35), Color(1.0, 0.78, 0.28), Color(0.86, 0.42, 1.0)]
const MULT_RARETE := [1.0, 1.7, 2.9, 4.8, 8.0, 1.0, 1.0]
const UNIQUE := 5
const SHINY := 6



const ESPECES := {
	"gobelin": {"nom": "Gobelin", "modele": "goblin", "haut": 1.25, "rang": 0, "pv": 140, "temps": 20.0, "pieces": 6, "xp": 10, "eveil": 0.6, "icone": "sh_goblin"},
	"puglin": {"nom": "Puglin", "modele": "puglin", "haut": 1.3, "rang": 0, "pv": 380, "temps": 20.0, "pieces": 14, "xp": 18, "eveil": 0.55, "icone": "sh_puglin"},
	"gobelin_chef": {"nom": "Gobelin enragé", "modele": "goblin", "haut": 1.55, "rang": 1, "pv": 1100, "temps": 25.0, "pieces": 40, "xp": 40, "eveil": 0.45, "teinte": Color(1.0, 0.55, 0.45), "icone": "sh_goblin"},
	"puglin_brute": {"nom": "Puglin brutal", "modele": "puglin", "peau": "T_Puglin_BaseColor_2", "haut": 1.75, "rang": 1, "pv": 2800, "temps": 25.0, "pieces": 85, "xp": 70, "eveil": 0.4, "icone": "sh_puglin"},
	"orc": {"nom": "Orc pillard", "modele": "orc", "haut": 2.15, "rang": 2, "pv": 7000, "temps": 30.0, "pieces": 220, "xp": 160, "eveil": 0.3, "icone": "sh_orc"},
	"diablotin": {"nom": "Diablotin des marais", "modele": "imp", "peau": "T_Imp_BaseColor_2", "haut": 1.9, "rang": 2, "pv": 17000, "temps": 30.0, "pieces": 450, "xp": 300, "eveil": 0.27, "icone": "sh_imp"},
	"orc_guerrier": {"nom": "Seigneur orc", "modele": "orc_warrior", "haut": 2.5, "rang": 3, "pv": 45000, "temps": 35.0, "pieces": 1200, "xp": 650, "eveil": 0.2, "icone": "sh_orc_warrior"},
	"demon": {"nom": "Démon écarlate", "modele": "imp", "haut": 2.6, "rang": 3, "pv": 110000, "temps": 38.0, "pieces": 2600, "xp": 1300, "eveil": 0.17, "icone": "sh_imp"},
	"chevalier": {"nom": "Chevalier de sang", "modele": "igris", "haut": 4.0, "rang": 4, "pv": 300000, "temps": 45.0, "pieces": 8000, "xp": 3000, "eveil": 0.12, "boss": true, "icone": "sh_igris"},
	"seigneur_givre": {"nom": "Seigneur du givre", "modele": "imp", "peau": "T_Imp_BaseColor_3", "haut": 3.4, "rang": 4, "pv": 850000, "temps": 50.0, "pieces": 21000, "xp": 7000, "eveil": 0.1, "boss": true, "icone": "sh_imp"},

	"roi_gobelin": {"nom": "Kargash, roi gobelin", "modele": "goblin", "haut": 3.3, "rang": 0, "pv": 9000, "temps": 9999.0, "pieces": 900, "xp": 600, "eveil": 0.25, "teinte": Color(1.0, 0.82, 0.45), "boss": true, "lieu": "donjon", "icone": "sh_goblin"},

	"baran": {"nom": "Baran, roi des démons", "modele": "imp", "haut": 5.2, "rang": 3, "pv": 650000, "temps": 90.0, "pieces": 30000, "xp": 9000, "eveil": 0.001, "boss": true, "lieu": "evenement",
		"teinte": Color(0.55, 0.35, 0.45), "icone": "sh_baran", "rang_ombre": 5,
		"competence": {"nom": "Chaînes infernales", "cd": 12.0, "mult": 30.0}},
}
const PITIE := 5


const OBJETS := {
	"dague": {"nom": "Dague du chasseur", "type": "arme", "modele": "dague", "icone": "w2", "dps": 12.0},
	"katana": {"nom": "Katana silencieux", "type": "arme", "modele": "katana", "icone": "w1", "dps": 20.0},
	"hache": {"nom": "Hache de guerre", "type": "arme", "modele": "hache", "icone": "w3", "dps": 34.0},
	"lame": {"nom": "Lame runique", "type": "arme", "modele": "lame", "icone": "w4", "dps": 58.0},
	"monarque": {"nom": "Lame du monarque", "type": "arme", "modele": "sl_sword", "icone": "w8", "dps": 100.0},

	"croc_roi": {"nom": "Croc du roi gobelin", "type": "arme", "modele": "hache", "icone": "u_croc", "dps": 230.0, "effet": "unique",
		"attrs": {"ombres": 15.0, "pieces": 20.0}},
	"faux_neant": {"nom": "Lame du Néant", "type": "arme", "modele": "lame", "icone": "u_neant", "dps": 1500.0, "effet": "shiny",
		"attrs": {"ombres": 30.0, "crit": 10.0, "vitesse": 10.0}},
	"capuche": {"nom": "Capuche de l'ombre", "type": "tete", "icone": "a1", "stat": "arme", "val": 6.0},
	"heaume": {"nom": "Heaume d'acier", "type": "tete", "icone": "a2", "stat": "arme", "val": 9.0},
	"couronne": {"nom": "Couronne du roi déchu", "type": "tete", "icone": "a3", "stat": "arme", "val": 14.0},
	"masque": {"nom": "Masque tribal", "type": "tete", "icone": "a11", "stat": "eveil", "val": 3.0},
	"cape_jade": {"nom": "Cape de jade", "type": "cape", "icone": "a4", "stat": "ombres", "val": 8.0},
	"cape_or": {"nom": "Cape dorée", "type": "cape", "icone": "a5", "stat": "ombres", "val": 13.0},
	"plastron": {"nom": "Plastron de fer", "type": "armure", "icone": "a6", "stat": "pieces", "val": 8.0},
	"armure_spectre": {"nom": "Armure spectrale", "type": "armure", "icone": "a7", "stat": "ombres", "val": 10.0},
	"armure_rose": {"nom": "Armure de la reine", "type": "armure", "icone": "a8", "stat": "arme", "val": 11.0},
	"bottes": {"nom": "Bottes de pisteur", "type": "bottes", "icone": "a9", "stat": "eveil", "val": 2.5},
	"bottes_sang": {"nom": "Bottes de sang", "type": "bottes", "icone": "a10", "stat": "pieces", "val": 12.0},
	"bourse": {"nom": "Bourse sans fond", "type": "relique", "icone": "r1", "stat": "pieces", "val": 10.0},
	"os": {"nom": "Os ancien", "type": "relique", "icone": "r2", "stat": "ombres", "val": 7.0},
	"pepite": {"nom": "Pépite brute", "type": "relique", "icone": "r3", "stat": "pieces", "val": 6.0},
	"boussole": {"nom": "Boussole du chasseur", "type": "relique", "icone": "r4", "stat": "xp", "val": 10.0},
	"oeuf_rubis": {"nom": "Œuf de rubis", "type": "relique", "icone": "r5", "stat": "eveil", "val": 3.0},
	"oeuf_azur": {"nom": "Œuf d'azur", "type": "relique", "icone": "r6", "stat": "eveil", "val": 4.0},
	"crane": {"nom": "Crâne du roi", "type": "relique", "icone": "r7", "stat": "arme", "val": 9.0},
	"grimoire": {"nom": "Grimoire interdit", "type": "relique", "icone": "r8", "stat": "xp", "val": 15.0},
	"coffre": {"nom": "Coffre du pillard", "type": "relique", "icone": "r9", "stat": "pieces", "val": 14.0},
	"oeuf_jade": {"nom": "Œuf de jade", "type": "relique", "icone": "r10", "stat": "ombres", "val": 9.0},
}
const NOMS_STATS := {"arme": "Dégâts des armes", "ombres": "Dégâts des ombres", "pieces": "Pièces gagnées",
	"eveil": "Chance d'éveil", "xp": "Expérience", "vitesse": "Vitesse", "crit": "Coups critiques"}

const BUTIN_RANG := [
	["dague", "katana", "capuche", "cape_jade", "plastron", "bottes", "bourse", "pepite", "os"],
	["katana", "hache", "capuche", "heaume", "cape_jade", "plastron", "bottes", "masque", "bourse", "os", "boussole", "oeuf_rubis"],
	["hache", "lame", "heaume", "masque", "cape_or", "armure_spectre", "bottes_sang", "boussole", "oeuf_rubis", "crane", "coffre"],
	["lame", "monarque", "couronne", "cape_or", "armure_rose", "armure_spectre", "bottes_sang", "oeuf_azur", "crane", "grimoire", "coffre"],
	["monarque", "couronne", "armure_rose", "cape_or", "oeuf_azur", "oeuf_jade", "grimoire"],
]
const CHANCE_BUTIN := [0.1, 0.14, 0.2, 0.3, 1.0]

const POINTS := {"ombres": "Puissance des ombres", "arme": "Maîtrise d'arme", "vitesse": "Pas du chasseur",
	"legion": "Légion d'ombres", "pieces": "Flair du pillard", "eveil": "Appel des ombres"}
const EFFET_POINT := {"ombres": 5.0, "arme": 5.0, "vitesse": 2.0, "legion": 0.0, "pieces": 5.0, "eveil": 1.0}
const MAX_POINTS := {"vitesse": 25, "legion": 20, "eveil": 30}
const LEGION_PAR_PLACE := 5
const POINTS_PAR_NIVEAU := 3


const PROBA_ROLL := [0.5, 0.28, 0.14, 0.059, 0.02, 0.001]
const ROLLS := {
	"ombres": {"autel": "Autel des ombres", "pnj": "Esil, l'invocatrice", "monnaie": "eclat", "stat": "ombres",
		"valeurs": [10.0, 14.0, 18.0, 22.0, 26.0, 30.0], "unite": "%"},
	"arme": {"autel": "Forge des lames", "pnj": "Kang, le forgeron", "monnaie": "insigne", "stat": "arme",
		"valeurs": [10.0, 15.0, 20.0, 26.0, 33.0, 40.0], "unite": "%"},
	"chance": {"autel": "Roue de fortune", "pnj": "Mira, la diseuse", "monnaie": "trefle", "stat": "eveil",
		"valeurs": [2.0, 3.0, 4.0, 6.0, 8.0, 12.0], "unite": " pts", "stat2": "pieces", "valeurs2": [10.0, 20.0, 30.0, 45.0, 60.0, 100.0]},
}
const MONNAIES := {"eclat": {"nom": "Éclat d'ombre", "pluriel": "Éclats d'ombre", "couleur": Color(0.7, 0.45, 1.0)},
	"insigne": {"nom": "Insigne de lame", "pluriel": "Insignes de lame", "couleur": Color(1.0, 0.42, 0.35)},
	"trefle": {"nom": "Trèfle doré", "pluriel": "Trèfles dorés", "couleur": Color(0.4, 0.95, 0.5)}}
const CHANCE_ELITE := 0.12

var pieces := 0
var niveau := 1
var xp := 0
var inventaire: Array = []
var equipe := {}
var ombres: Array = []
var points := {"ombres": 0, "arme": 0, "vitesse": 0, "legion": 0, "pieces": 0, "eveil": 0}
var echecs_eveil := 0
var tues := {}
var rolls := {"ombres": -1, "arme": -1, "chance": -1}
var monnaies := {"eclat": 0, "insigne": 0, "trefle": 0}
var achats := {"eclat": 0, "insigne": 0, "trefle": 0}
var tirages := 0
var donjons := 0
var record_donjon := 0.0
var uniques_obtenus := {}

var _fenetre := []
var _t := 0.0
var _uid := 1
var _sauver_t := 0.0

func _ready() -> void:
	charger()
	if inventaire.is_empty():
		var d := ajouter_objet("dague", 0, false)
		equipe["arme"] = d["uid"]

func _process(dt: float) -> void:
	_t += dt
	_sauver_t += dt
	if _sauver_t > 8.0:
		_sauver_t = 0.0
		sauver()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		sauver()


func base(o: Dictionary) -> Dictionary:
	return OBJETS[o["base"]]

func objet(uid: int) -> Dictionary:
	for o in inventaire:
		if o["uid"] == uid:
			return o
	return {}

func ajouter_objet(b: String, rarete: int, annoncer := true) -> Dictionary:
	var o := {"uid": _uid, "base": b, "rarete": rarete, "niv": 0}
	_uid += 1
	inventaire.append(o)
	if annoncer:
		butin.emit(o)
	change.emit()
	return o

func emplacement_de(o: Dictionary) -> String:
	for e in equipe:
		if equipe[e] == o["uid"]:
			return e
	return ""

func est_equipe(o: Dictionary) -> bool:
	return emplacement_de(o) != ""


func emplacement_pour(o: Dictionary) -> String:
	var t: String = base(o)["type"]
	if t != "relique":
		return t
	var pire := ""
	var pv := INF
	for e in ["relique1", "relique2", "relique3"]:
		if not equipe.has(e):
			return e
		var v := valeur(objet(equipe[e]))
		if v < pv:
			pv = v
			pire = e
	return pire

func equiper(o: Dictionary) -> void:
	if est_equipe(o):
		return
	equipe[emplacement_pour(o)] = o["uid"]
	change.emit()
	sauver()

func desequiper(o: Dictionary) -> void:
	var e := emplacement_de(o)
	if e == "arme" or e == "":
		return
	equipe.erase(e)
	change.emit()


func valeur(o: Dictionary) -> float:
	if o.is_empty():
		return 0.0
	var b := base(o)
	var k: float = MULT_RARETE[o["rarete"]] * pow(1.22, o["niv"])
	return (b["dps"] if b["type"] == "arme" else b["val"]) * k

func cout_amelioration(o: Dictionary) -> int:
	var b := base(o)
	var poids: float = b.get("dps", 0.0) / 12.0 if b["type"] == "arme" else b.get("val", 5.0) / 8.0
	if o["rarete"] >= UNIQUE:
		poids *= 0.4
	return int(round(20.0 * pow(1.45, o["niv"]) * (1.0 + o["rarete"] * 0.8) * poids))

func ameliorer(o: Dictionary) -> bool:
	var c := cout_amelioration(o)
	if pieces < c:
		return false
	pieces -= c
	o["niv"] += 1
	change.emit()
	sauver()
	return true

func prix_vente(o: Dictionary) -> int:
	return int(cout_amelioration(o) * 0.35) + 4

func vendre(o: Dictionary) -> bool:
	if est_equipe(o):
		return false
	pieces += prix_vente(o)
	inventaire.erase(o)
	change.emit()
	return true


func equiper_le_meilleur(types: Array) -> void:
	for t in types:
		var l := inventaire.filter(func (o): return base(o)["type"] == t)
		l.sort_custom(func (a, b): return valeur(a) > valeur(b))
		if t == "relique":
			for k in 3:
				if k < l.size():
					equipe["relique%d" % (k + 1)] = l[k]["uid"]
		elif not l.is_empty():
			equipe[t] = l[0]["uid"]
	change.emit()
	sauver()

func arme() -> Dictionary:
	return objet(equipe.get("arme", -1))



func bonus(stat: String) -> float:
	var b := 0.0
	for e in equipe:
		var o := objet(equipe[e])
		if o.is_empty():
			continue
		var bo := base(o)
		if bo.get("stat", "") == stat:
			b += valeur(o)
		var at: Dictionary = bo.get("attrs", {})
		if at.has(stat):
			b += float(at[stat]) * (1.0 + 0.08 * o["niv"])
	if points.has(stat):
		b += points[stat] * EFFET_POINT[stat]
	for k in ROLLS:
		var r: int = rolls[k]
		if r < 0:
			continue
		if ROLLS[k]["stat"] == stat:
			b += ROLLS[k]["valeurs"][r]
		if ROLLS[k].get("stat2", "") == stat:
			b += ROLLS[k]["valeurs2"][r]
	return b

func attrs_texte(o: Dictionary) -> Array:
	var l := []
	var at: Dictionary = base(o).get("attrs", {})
	for k in at:
		l.append("%s : +%.0f %%" % [NOMS_STATS[k], float(at[k]) * (1.0 + 0.08 * o["niv"])])
	return l

func vitesse() -> float:
	return 1.0 + bonus("vitesse") / 100.0

func chance_crit() -> float:
	return 0.15 + bonus("crit") / 100.0

func bonus_niveau() -> float:
	return 1.0 + (niveau - 1) * 0.06

func dps_joueur() -> float:
	var a := arme()
	var base_dps := valeur(a) if not a.is_empty() else 8.0
	return base_dps * (1.0 + bonus("arme") / 100.0) * bonus_niveau()

func dps_ombre(o: Dictionary) -> float:
	var e: Dictionary = ESPECES[o["espece"]]
	var temps: float = minf(float(e["temps"]), 45.0)
	var k := 0.35
	if e.get("lieu", "") == "evenement":
		k = 0.6
	return float(e["pv"]) / temps * k * pow(1.7, int(o["etoiles"])) * (1.0 + bonus("ombres") / 100.0)

func rang_ombre(o: Dictionary) -> int:
	var e: Dictionary = ESPECES[o["espece"]]
	return int(e.get("rang_ombre", e["rang"]))

func places_ombres() -> int:
	return mini(4 + (niveau - 1) / 8, 8) + points["legion"] / LEGION_PAR_PLACE

func ombres_equipees() -> Array:
	return ombres.filter(func (o): return o.get("eq", false))

func dps_total() -> float:
	var d := dps_joueur()
	for o in ombres_equipees():
		d += dps_ombre(o)
	return d

func xp_requise() -> int:
	return int(40.0 * pow(1.28, niveau - 1))

func points_libres() -> int:
	var u := 0
	for k in points:
		u += points[k]
	return (niveau - 1) * POINTS_PAR_NIVEAU - u

func depenser_point(k: String, n := 1) -> void:
	n = mini(n, points_libres())
	if MAX_POINTS.has(k):
		n = mini(n, MAX_POINTS[k] - points[k])
	if n > 0:
		points[k] += n
		change.emit()

func reinitialiser_points() -> void:
	for k in points:
		points[k] = 0
	change.emit()


func stats_monstre(espece: String, elite := false, mult := 1.0) -> Dictionary:
	var e: Dictionary = ESPECES[espece]
	var k := 4.0 if elite else 1.0
	return {"pv": float(e["pv"]) * k * mult, "temps": float(e["temps"]) * (1.25 if elite else 1.0),
		"pieces": float(e["pieces"]) * (5.0 if elite else 1.0) * mult, "xp": float(e["xp"]) * (3.0 if elite else 1.0) * mult}

func verdict(espece: String, elite := false, mult := 1.0) -> Dictionary:
	var st := stats_monstre(espece, elite, mult)
	var t: float = st["pv"] / dps_total()
	var r: float = t / st["temps"]
	if r <= 0.6:
		return {"texte": "Facile", "couleur": Color(0.45, 0.95, 0.45), "possible": true, "temps": t}
	if r <= 1.0:
		return {"texte": "Serré", "couleur": Color(1.0, 0.75, 0.25), "possible": true, "temps": t}
	return {"texte": "Trop fort", "couleur": Color(1.0, 0.3, 0.3), "possible": false, "temps": t}


signal niveau_gagne(n: int)
signal monnaie_gagnee(m: String, n: int)


func gagner(espece: String, elite := false, mult := 1.0) -> int:
	var e: Dictionary = ESPECES[espece]
	var st := stats_monstre(espece, elite, mult)
	var gain := int(round(st["pieces"] * (1.0 + bonus("pieces") / 100.0)))
	pieces += gain
	tues[espece] = int(tues.get(espece, 0)) + 1
	xp += int(round(st["xp"] * (1.0 + bonus("xp") / 100.0)))
	while xp >= xp_requise():
		xp -= xp_requise()
		niveau += 1
		message.emit("Niveau %d !  +%d points de compétence" % [niveau, POINTS_PAR_NIVEAU], Color(1.0, 0.85, 0.3))
		niveau_gagne.emit(niveau)
	var r: int = e["rang"]
	var chance: float = CHANCE_BUTIN[mini(r, CHANCE_BUTIN.size() - 1)] * (3.0 if elite else 1.0)
	if e.get("lieu", "") == "":
		if randf() < chance:
			var liste: Array = BUTIN_RANG[mini(r, BUTIN_RANG.size() - 1)]
			var tirage := randf()
			var rarete := 0
			for seuil in [0.45, 0.78, 0.93, 0.985]:
				if tirage > seuil:
					rarete += 1
			rarete = mini(rarete + (1 if r >= 3 else 0) + (1 if elite else 0), 4)
			ajouter_objet(liste.pick_random(), rarete)

	var n := 0
	if elite:
		n = 1 + r
	elif randf() < 0.06 + r * 0.03:
		n = 1
	if e.get("boss", false):
		n += 2 + r
	if n > 0:
		donner_monnaie(MONNAIES.keys().pick_random(), n)
	change.emit()
	return gain

func donner_monnaie(m: String, n: int) -> void:
	monnaies[m] = int(monnaies[m]) + n
	monnaie_gagnee.emit(m, n)
	change.emit()


func butin_unique(b: String) -> bool:
	var deja := int(uniques_obtenus.get(b, 0))
	if deja > 0 and randf() > 0.35:
		return false
	uniques_obtenus[b] = deja + 1
	var r := UNIQUE if OBJETS[b].get("effet", "") == "unique" else SHINY
	ajouter_objet(b, r)
	sauver()
	return true


func prix_monnaie(m: String) -> int:
	return int(round(60.0 * pow(1.18, niveau) * pow(1.08, int(achats[m]))))

func acheter_monnaie(m: String) -> bool:
	var p := prix_monnaie(m)
	if pieces < p:
		return false
	pieces -= p
	achats[m] = int(achats[m]) + 1
	monnaies[m] = int(monnaies[m]) + 1
	change.emit()
	return true

func tirer_rang() -> int:
	var x := randf()
	var cumul := 0.0
	for k in range(PROBA_ROLL.size() - 1, -1, -1):
		cumul += PROBA_ROLL[k]
		if x < cumul:
			return k
	return 0


func roll(k: String) -> Dictionary:
	var m: String = ROLLS[k]["monnaie"]
	if int(monnaies[m]) <= 0:
		return {}
	monnaies[m] = int(monnaies[m]) - 1
	tirages += 1
	var r := tirer_rang()
	var mieux: bool = r > int(rolls[k])
	if mieux:
		rolls[k] = r
	change.emit()
	sauver()
	return {"rang": r, "mieux": mieux}


func compter(v: float, source: String) -> void:
	_fenetre.append([_t, v, source == "ombres"])


func direct() -> Array:
	while not _fenetre.is_empty() and _fenetre[0][0] < _t - 3.0:
		_fenetre.pop_front()
	var j := 0.0
	var o := 0.0
	for x in _fenetre:
		if x[2]:
			o += x[1]
		else:
			j += x[1]
	return [j / 3.0, o / 3.0]



func chance_eveil(espece: String) -> float:
	var e: Dictionary = ESPECES[espece]
	if e.get("lieu", "") == "evenement":
		return float(e["eveil"]) * (1.0 + bonus("eveil") / 100.0)
	return minf(1.0, float(e["eveil"]) + bonus("eveil") / 100.0)

var force_eveil := false

func eveiller(espece: String) -> Dictionary:
	var e: Dictionary = ESPECES[espece]
	var evenement: bool = e.get("lieu", "") == "evenement"
	var ok := randf() < chance_eveil(espece) or force_eveil or (echecs_eveil >= PITIE and not evenement)
	if not ok:
		if not evenement:
			echecs_eveil += 1
		change.emit()
		return {}
	if not evenement:
		echecs_eveil = 0
	var o := {"uid": _uid, "espece": espece, "etoiles": 0, "eq": ombres_equipees().size() < places_ombres()}
	_uid += 1
	ombres.append(o)
	_fusionner(espece)
	change.emit()
	sauver()
	return o

func _fusionner(espece: String) -> void:
	var fini := false
	while not fini:
		fini = true
		for et in 5:
			var memes := ombres.filter(func (x): return x["espece"] == espece and int(x["etoiles"]) == et)
			if memes.size() >= 3:
				var eq := memes.slice(0, 3).any(func (x): return x.get("eq", false))
				for k in 3:
					ombres.erase(memes[k])
				ombres.append({"uid": _uid, "espece": espece, "etoiles": et + 1, "eq": eq})
				_uid += 1
				message.emit("Fusion ! %s %s" % [ESPECES[espece]["nom"], "★".repeat(et + 1)], Color(0.75, 0.55, 1.0))
				fini = false
				break

func equiper_ombre(o: Dictionary, oui: bool) -> bool:
	if oui and ombres_equipees().size() >= places_ombres():
		return false
	o["eq"] = oui
	change.emit()
	return true

func meilleures_ombres() -> void:
	var l := ombres.duplicate()
	l.sort_custom(func (a, b): return dps_ombre(a) > dps_ombre(b))
	for k in l.size():
		l[k]["eq"] = k < places_ombres()
	sauver()
	change.emit()

func prix_ombre(o: Dictionary) -> int:
	return int(ESPECES[o["espece"]]["pieces"] * 3 * pow(3.0, o["etoiles"]))

func liberer_ombre(o: Dictionary) -> int:
	var gain := prix_ombre(o)
	pieces += gain
	ombres.erase(o)
	change.emit()
	return gain


func sauver() -> void:
	if OS.get_cmdline_user_args().has("--sans-sauvegarde"):
		return
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"v": 4, "pieces": pieces, "niveau": niveau, "xp": xp, "inventaire": inventaire,
			"equipe": equipe, "ombres": ombres, "points": points, "echecs": echecs_eveil, "tues": tues, "uid": _uid,
			"rolls": rolls, "monnaies": monnaies, "achats": achats, "tirages": tirages, "donjons": donjons,
			"record": record_donjon, "uniques": uniques_obtenus}))

func charger() -> void:
	if OS.get_cmdline_user_args().has("--sans-sauvegarde") or not FileAccess.file_exists(CHEMIN):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
	if typeof(d) != TYPE_DICTIONARY:
		return
	pieces = int(d.get("pieces", 0))
	niveau = int(d.get("niveau", 1))
	xp = int(d.get("xp", 0))
	echecs_eveil = int(d.get("echecs", 0))
	tues = d.get("tues", {})
	_uid = int(d.get("uid", 1))
	for k in points:
		points[k] = int(d.get("points", {}).get(k, 0))
	for k in rolls:
		rolls[k] = int(d.get("rolls", {}).get(k, -1))
	for k in monnaies:
		monnaies[k] = int(d.get("monnaies", {}).get(k, 0))
		achats[k] = int(d.get("achats", {}).get(k, 0))
	tirages = int(d.get("tirages", 0))
	donjons = int(d.get("donjons", 0))
	record_donjon = float(d.get("record", 0.0))
	uniques_obtenus = d.get("uniques", {})
	for o in d.get("inventaire", []):
		if OBJETS.has(o.get("base", "")):
			inventaire.append({"uid": int(o["uid"]), "base": o["base"], "rarete": int(o["rarete"]), "niv": int(o["niv"])})
			_uid = maxi(_uid, int(o["uid"]) + 1)
	for e in d.get("equipe", {}):
		equipe[e] = int(d["equipe"][e])
	for o in d.get("ombres", []):
		if ESPECES.has(o.get("espece", "")):
			ombres.append({"uid": _uid, "espece": o["espece"], "etoiles": int(o.get("etoiles", 0)), "eq": bool(o.get("eq", true))})
			_uid += 1

	if inventaire.is_empty() and d.has("niv_arme"):
		var a := ajouter_objet("dague", 0, false)
		a["niv"] = int(d["niv_arme"])
		equipe["arme"] = a["uid"]
	var eq := ombres_equipees()
	for k in range(eq.size() - 1, places_ombres() - 1, -1):
		eq[k]["eq"] = false
