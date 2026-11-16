class_name Items
## Objets façon UMBRA : 7 raretés F→S, armes (modèle 3D en main), reliques, équipement.

const RAR := [
	{"k": "F", "n": "Commun", "c": "9ca3af"},
	{"k": "E", "n": "Peu commun", "c": "4ade80"},
	{"k": "D", "n": "Rare", "c": "38bdf8"},
	{"k": "C", "n": "Épique", "c": "c26bff"},
	{"k": "B", "n": "Légendaire", "c": "ffcc33"},
	{"k": "A", "n": "Mythique", "c": "ff3b5c"},
	{"k": "S", "n": "Suprême", "c": "ff7ad9"},
]
## Armes : mult = dégâts, spd = vitesse d'attaque propre au type, arc = ouverture du coup (degrés)
const WEAPONS := [
	{"id": "w1", "n": "Katana du Chasseur", "r": 0, "type": "épée", "model": "katana", "mult": 1.0, "spd": 1.0, "arc": 80, "glow": "", "st": {}, "d": "La lame de l'Association. Équilibrée, fiable."},
	{"id": "w2", "n": "Dague Murmure", "r": 1, "type": "dague", "model": "dague", "mult": 0.85, "spd": 1.45, "arc": 60, "glow": "", "st": {"crit": 8}, "d": "Frappe si vite qu'on n'entend qu'un souffle."},
	{"id": "w3", "n": "Hache Brise-Os", "r": 2, "type": "hache", "model": "hache", "mult": 1.7, "spd": 0.72, "arc": 130, "glow": "", "st": {}, "d": "Lente, mais chaque coup balaie tout devant toi."},
	{"id": "w4", "n": "Lame Écarlate", "r": 3, "type": "épée", "model": "lame", "mult": 1.9, "spd": 1.0, "arc": 85, "glow": "ff3b3b", "st": {"wdmg": 10}, "d": "Forgée dans le sang d'un chevalier tombé."},
	{"id": "w5", "n": "Croc du Venin", "r": 4, "type": "dague", "model": "dague", "mult": 2.1, "spd": 1.5, "arc": 60, "glow": "4ade80", "st": {"crit": 15}, "d": "Le poison de son fil ne pardonne pas."},
	{"id": "w6", "n": "Hache Sanglante", "r": 5, "type": "hache", "model": "hache", "mult": 3.6, "spd": 0.78, "arc": 140, "glow": "ff3b5c", "st": {"wdmg": 15}, "d": "Elle a soif. Elle a toujours soif."},
	{"id": "w7", "n": "Lame du Commandant", "r": 5, "type": "épée", "model": "lame", "mult": 3.3, "spd": 1.05, "arc": 90, "glow": "ff2020", "st": {"sdmg": 15}, "d": "L'épée d'Igris. Elle reconnaît désormais ta main."},
	{"id": "w8", "n": "Lame du Monarque d'Ombre", "r": 6, "type": "épée", "model": "lame", "mult": 5.5, "spd": 1.12, "arc": 100, "glow": "b46bff", "st": {"sdmg": 40, "all": 10}, "d": "L'arme suprême. Les ombres s'inclinent devant elle."},
]
const RELICS := [
	{"id": "r1", "n": "Trésor du Roi Avare", "r": 0, "st": {"gold": 15}, "d": "Les pièces d'un roi qui n'a jamais rien partagé."},
	{"id": "r2", "n": "Os du Premier Loup", "r": 0, "st": {"crit": 3}, "d": "Le premier chasseur. Sa morsure guide la tienne."},
	{"id": "r3", "n": "Pépite de Vie", "r": 1, "st": {"hp": 12}, "d": "Elle bat comme un cœur quand on la serre."},
	{"id": "r4", "n": "Boussole du Temps", "r": 1, "st": {"aspd": 6}, "d": "Son aiguille avance plus vite que les secondes."},
	{"id": "r5", "n": "Œuf de Braise", "r": 2, "st": {"wdmg": 18}, "d": "Il brûle de l'intérieur. Ton arme aussi."},
	{"id": "r6", "n": "Œuf de Givre", "r": 3, "st": {"mana": 25}, "d": "Des cristaux de mana poussent sur sa coquille."},
	{"id": "r7", "n": "Crâne du Nécromancien", "r": 4, "st": {"dom": 4}, "d": "Il murmure aux morts de se relever pour toi."},
	{"id": "r8", "n": "Grimoire des Ombres", "r": 5, "st": {"sdmg": 30}, "d": "Chaque page est le nom d'une ombre soumise."},
	{"id": "r9", "n": "Coffre du Roi-Liche", "r": 5, "st": {"luck": 15}, "d": "Il ne s'ouvre que pour les chanceux."},
	{"id": "r10", "n": "Œuf du Dragon Primordial", "r": 6, "st": {"all": 25}, "d": "Ce qui dort dedans est plus vieux que les mondes."},
]
const SLOTS := [["tete", "Tête"], ["cape", "Cape"], ["plastron", "Plastron"], ["bottes", "Bottes"]]
const ACCS := [
	{"id": "a1", "n": "Capuche du Rôdeur", "slot": "tete", "r": 0, "st": {"hp": 6, "crit": 1}},
	{"id": "a6", "n": "Cuirasse de Cuir", "slot": "plastron", "r": 0, "st": {"hp": 10}},
	{"id": "a4", "n": "Cape Déchirée", "slot": "cape", "r": 1, "st": {"aspd": 5, "gold": 10}},
	{"id": "a9", "n": "Bottes de Voyage", "slot": "bottes", "r": 1, "st": {"speed": 8}},
	{"id": "a2", "n": "Heaume du Gardien", "slot": "tete", "r": 2, "st": {"hp": 18, "wdmg": 8}},
	{"id": "a7", "n": "Plastron d'Os", "slot": "plastron", "r": 3, "st": {"hp": 25, "crit": 4}},
	{"id": "a5", "n": "Manteau de Nuit Éternelle", "slot": "cape", "r": 4, "st": {"all": 12, "luck": 8}},
	{"id": "a10", "n": "Bottes du Pas d'Ombre", "slot": "bottes", "r": 5, "st": {"speed": 15, "sdmg": 20}},
	{"id": "a3", "n": "Couronne du Monarque", "slot": "tete", "r": 5, "st": {"sdmg": 35, "dom": 3}},
	{"id": "a8", "n": "Armure Abyssale", "slot": "plastron", "r": 6, "st": {"hp": 60, "all": 20}},
]
const STAT_NAMES := {"gold": "Or gagné", "crit": "Critique", "hp": "PV", "aspd": "Vitesse d'attaque", "wdmg": "Dégâts d'arme", "mana": "Mana", "dom": "Domaine d'ombre", "sdmg": "Dégâts des ombres", "luck": "Chance de butin", "all": "Tous dégâts", "speed": "Vitesse"}
const STAT_UNIT := {"dom": " m", "luck": "", "crit": " %"}

static func base_of(it: Dictionary) -> Dictionary:
	var lst: Array = WEAPONS if it["t"] == "w" else (RELICS if it["t"] == "r" else ACCS)
	for b in lst:
		if b["id"] == it["id"]:
			return b
	return lst[0]

static func rarity(it: Dictionary) -> int:
	return int(base_of(it)["r"])

static func color(it: Dictionary) -> Color:
	return Color(str(RAR[rarity(it)]["c"]))

## Niveau d'amélioration (0 à 10) : +12 % par niveau sur toutes les statistiques.
static func lv(it: Dictionary) -> int:
	return int(it.get("lv", 0))

static func stars(it: Dictionary) -> int:
	return int(it.get("star", 0))

static func lv_mult(it: Dictionary) -> float:
	return (1.0 + 0.12 * lv(it)) * (1.0 + 0.15 * stars(it))

const W := {"wdmg": 1.0, "all": 1.5, "crit": 1.2, "hp": 0.6, "aspd": 1.2, "sdmg": 1.0, "mana": 0.4, "dom": 4.0, "luck": 0.5, "gold": 0.3, "speed": 0.6}

## Score de puissance (pour comparer et trier).
static func power(it: Dictionary) -> float:
	if it.is_empty():
		return 0.0
	if it["t"] == "w":
		var w := weapon_of(it)
		var s := 0.0
		for k in stats(it).keys():
			s += float(stats(it)[k]) * float(W.get(k, 0.5))
		return float(w["mult"]) * float(w["spd"]) * 100.0 + s
	var p := 0.0
	var st := stats(it)
	for k in st.keys():
		p += float(st[k]) * float(W.get(k, 0.5))
	return p

static func stats(it: Dictionary) -> Dictionary:
	var out := {}
	var st: Dictionary = base_of(it).get("st", {})
	for k in st.keys():
		out[k] = float(st[k]) * lv_mult(it)
	return out

## Arme effective (multiplicateur de dégâts augmenté par le niveau).
static func weapon_of(it: Dictionary) -> Dictionary:
	var w: Dictionary = base_of(it).duplicate()
	w["mult"] = float(w["mult"]) * (1.0 + 0.08 * lv(it)) * (1.0 + 0.1 * stars(it))
	return w

static func upgrade_cost(it: Dictionary) -> Array:
	var l := lv(it)
	return [int(60 * (l + 1) * (rarity(it) + 1)), 1 + l + rarity(it)]

static func icon(it: Dictionary) -> Texture2D:
	var p := "res://assets/ui/items/%s.png" % it["id"]
	if ResourceLoader.exists(p):
		return load(p)
	return null

static func sell_price(it: Dictionary) -> int:
	return int(30 * pow(3.0, rarity(it)))

static func dismantle_value(it: Dictionary) -> int:
	return 1 + rarity(it) * 2

static func describe(it: Dictionary) -> String:
	var b := base_of(it)
	var t := ""
	if it["t"] == "w":
		t += "%s — dégâts x%.2f, vitesse x%.2f, ouverture %d°\n" % [str(b["type"]).capitalize(), float(b["mult"]) * (1.0 + 0.08 * lv(it)), float(b["spd"]), int(b["arc"])]
	elif it["t"] == "a":
		for s in SLOTS:
			if s[0] == b["slot"]:
				t += "Emplacement : %s\n" % s[1]
	var st2 := stats(it)
	for k in st2.keys():
		var unit: String = STAT_UNIT.get(k, " %")
		t += "+%s%s %s\n" % [str(snappedf(float(st2[k]), 0.1)), unit, STAT_NAMES.get(k, k)]
	if b.has("d"):
		t += "« %s »" % b["d"]
	return t

## Tirage pondéré d'une rareté ; la chance pousse vers le haut.
static func roll_rank(weights: Array, luck: float) -> int:
	var w: Array = []
	var tot := 0.0
	for i in weights.size():
		var x: float = float(weights[i]) * pow(1.0 + luck / 100.0, i)
		w.append(x)
		tot += x
	var r := randf() * tot
	for i in w.size():
		if r < w[i]:
			return i
		r -= w[i]
	return 0

## Génère un objet d'une rareté donnée (type au hasard).
static func roll_item(rank: int, uid: int) -> Dictionary:
	var kinds := ["w", "r", "r", "a", "a"]
	for tries in 12:
		var t: String = kinds[randi() % kinds.size()]
		var lst: Array = WEAPONS if t == "w" else (RELICS if t == "r" else ACCS)
		var cands: Array = []
		for b in lst:
			if int(b["r"]) == rank and b["id"] != "w7":
				cands.append(b)
		if not cands.is_empty():
			return {"uid": uid, "t": t, "id": cands[randi() % cands.size()]["id"]}
	return {"uid": uid, "t": "r", "id": "r1"}
