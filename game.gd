extends Node
# VALDRUNE — état global, données de jeu, sauvegarde, sons

# ——— Code couleur des tiers (lisible d'un coup d'œil, façon Albion) ———
const TIER_COL := [Color(1, 1, 1), Color("#c8c8c8"), Color("#62d24e"), Color("#33c4dc"), Color("#4d78ff"), Color("#ff3d3d")]
const TIER_ZONE := ["", "Zone grise", "Zone verte", "Zone cyan", "Zone bleue", "Zone rouge"]
const MAX_TIER := 5
const RING := [0.0, 13.0, 26.0, 39.0, 52.0, 65.0, 78.0]   # rayon intérieur de chaque tier (camp = 0..13)

const RES := {
	"wood": {"name": "Bois", "tool": "hache", "verb": "COUPER", "dir": "au nord", "angle": -PI / 2,
		"tiers": ["", "Bouleau", "Châtaignier", "Pin noir", "Cèdre", "Chêne sanglant"]},
	"ore": {"name": "Minerai", "tool": "pioche", "verb": "MINER", "dir": "au sud-est", "angle": PI / 6,
		"tiers": ["", "Cuivre", "Étain", "Fer", "Titane", "Runite"]},
	"fiber": {"name": "Fibre", "tool": "faucille", "verb": "CUEILLIR", "dir": "au sud-ouest", "angle": 5 * PI / 6,
		"tiers": ["", "Coton", "Lin", "Chanvre", "Soie-ciel", "Fil d'ombre"]},
}
const RES_KEYS := ["wood", "ore", "fiber"]
const TOOL_OF := {"wood": "hache", "ore": "pioche", "fiber": "faucille"}
const TOOL_NAME := {"hache": "Hache", "pioche": "Pioche", "faucille": "Faucille", "epee": "Arme", "armure": "Armure", "bottes": "Bottes", "bouclier": "Bouclier"}
const TOOL_MODEL := {"hache": "res://assets/weapons/axe_1handed.gltf", "pioche": "res://assets/tools/pioche.tscn", "faucille": "res://assets/tools/faucille.tscn"}
const W := "res://assets/weapons/%s.gltf"
# Familles d'armes : chaque tier a son propre modèle 3D
const WEAPON_KINDS := {
	"epee": {"name": "Épée", "dmg": 1.0, "rate": 1.0, "skill": 1.0, "cd": 0.0, "desc": "Équilibrée", "models": ["", "sword_A", "sword_B", "sword_C", "sword_D", "sword_E"]},
	"hache": {"name": "Hache de guerre", "dmg": 1.28, "rate": 0.82, "skill": 1.0, "cd": 0.0, "desc": "+28 % dégâts · coups plus lents", "models": ["", "axe_1handed", "axe_A", "axe_C", "axe_2handed", "halberd"]},
	"baton": {"name": "Bâton de mage", "dmg": 0.8, "rate": 1.0, "skill": 1.4, "cd": 0.2, "desc": "Sorts +40 % dégâts · recharge −20 %", "models": ["", "staff_A", "wand_A", "staff", "staff_B", "staff_B"]},
	# armes à distance : on tire de loin (portée en mètres), avec de vrais projectiles
	"arc": {"name": "Arc", "dmg": 0.8, "rate": 1.1, "skill": 1.1, "cd": 0.05, "range": 14.0, "proj": "arrow", "two": true, "desc": "Tir à 14 m · tire vite · recharge −5 %", "models": ["", "bow", "bow", "bow_withString", "bow_withString", "bow_withString"]},
	"arbalete": {"name": "Arbalète", "dmg": 1.3, "rate": 0.68, "skill": 1.15, "cd": 0.0, "range": 12.0, "proj": "bolt", "desc": "Tir lourd à 12 m · carreaux qui transpercent", "models": ["", "crossbow_1handed", "crossbow_1handed", "crossbow_1handed", "crossbow_2handed", "crossbow_2handed"]},
	"dompteur": {"name": "Bâton du Dompteur", "dmg": 0.85, "rate": 1.0, "skill": 1.0, "cd": 0.0, "range": 13.0, "proj": "spirit", "classe": true, "desc": "Esprits sauvages à 13 m · invoque 3 familiers au combat", "models": ["", "staff_A", "staff", "staff_B", "staff_B", "staff_B"]},
	"grimoire": {"name": "Grimoire", "dmg": 0.75, "rate": 0.95, "skill": 1.5, "cd": 0.15, "range": 13.0, "proj": "orb", "desc": "Orbes magiques à 13 m · sorts +50 % · recharge −15 %", "models": ["", "spellbook_closed", "spellbook_closed", "spellbook_open", "spellbook_open", "spellbook_open"]},
}
# ——— Classe Dompteur : familiers (animaux apprivoisés) ———
const PET_RAR := [
	{"n": "Commun", "c": "#cfcfcf", "m": 1.0}, {"n": "Peu commun", "c": "#62d24e", "m": 1.3}, {"n": "Rare", "c": "#4d9bff", "m": 1.7},
	{"n": "Épique", "c": "#c77dff", "m": 2.3}, {"n": "Légendaire", "c": "#ffb02e", "m": 3.2}]
const PETS := {
	"renard": {"name": "Renard", "model": "fox", "scale": 0.3, "hp": 0.7, "dmg": 1.1, "cd": 0.8, "speed": 7.5, "skill": "Morsures éclair", "sk": "frenzy", "skcd": 6.0, "desc": "Très rapide : 3 morsures d'affilée toutes les 6 s"},
	"loup": {"name": "Loup", "model": "wolf", "scale": 0.42, "hp": 1.0, "dmg": 1.0, "cd": 1.0, "speed": 7.0, "skill": "Hurlement", "sk": "howl", "skcd": 10.0, "desc": "Hurle : +25 % de dégâts pour toi pendant 6 s"},
	"cerf": {"name": "Cerf", "model": "stag", "scale": 0.5, "hp": 1.2, "dmg": 0.7, "cd": 1.4, "speed": 6.5, "skill": "Souffle des bois", "sk": "heal", "skcd": 5.0, "desc": "Soigne le héros (6 % de sa vie) toutes les 5 s"},
	"taureau": {"name": "Taureau", "model": "bull", "scale": 0.46, "hp": 2.2, "dmg": 1.2, "cd": 1.6, "speed": 6.0, "skill": "Charge", "sk": "charge", "skcd": 8.0, "desc": "Fonce et renverse tout ; les monstres s'acharnent sur lui"},
	"loup_givre": {"name": "Loup de givre", "model": "wolf", "scale": 0.46, "tint": Color(0.6, 0.85, 1.45), "hp": 1.1, "dmg": 1.15, "cd": 1.0, "speed": 7.0, "skill": "Souffle glacé", "sk": "frost", "skcd": 7.0, "desc": "Gèle une zone : dégâts et monstres ralentis", "rare": true},
	"renard_feu": {"name": "Renard de feu", "model": "fox", "scale": 0.34, "tint": Color(1.7, 0.7, 0.35), "hp": 0.8, "dmg": 1.3, "cd": 0.8, "speed": 7.5, "skill": "Explosion de flammes", "sk": "fire", "skcd": 6.0, "desc": "Fait exploser les flammes autour de sa cible", "rare": true},
	"cerf_or": {"name": "Cerf d'or", "model": "stag", "scale": 0.56, "tint": Color(1.45, 1.2, 0.5), "hp": 1.4, "dmg": 0.8, "cd": 1.3, "speed": 6.5, "skill": "Bénédiction", "sk": "bless", "skcd": 7.0, "desc": "Soigne beaucoup et pose un bouclier sur le héros", "rare": true},
	"loup_noir": {"name": "Loup Noir Ancien", "model": "wolf", "scale": 0.6, "tint": Color(1.7, 1.35, 2.3), "hp": 1.6, "dmg": 1.5, "cd": 1.0, "speed": 7.0, "skill": "Meute fantôme", "sk": "pack", "skcd": 12.0, "desc": "Frappe tous les ennemis autour de lui à répétition", "boss": true},
	"taureau_guerre": {"name": "Taureau de Guerre", "model": "bull", "scale": 0.6, "tint": Color(0.5, 0.15, 0.12), "hp": 3.0, "dmg": 1.5, "cd": 1.5, "speed": 6.0, "skill": "Séisme", "sk": "quake", "skcd": 10.0, "desc": "Frappe le sol : énorme zone qui repousse tout", "boss": true},
}
const PET_DUR := 40.0        # secondes de présence au combat
const PET_CD := 60.0         # recharge de l'invocation
const PET_MAX := 40
const CLASS_PRICE := 800
# ================= ÉVEIL : les paliers qui propulsent le héros =================
# Chaque palier se gagne en battant le Gardien de l'Éveil. Il donne +18 % dégâts, +18 % vie, +3 % critique,
# et surtout la DOMINATION : face à un joueur d'un palier plus bas, tu frappes bien plus fort et tu encaisses bien moins.
const EVEIL_MAX := 5
const EVEIL_NAMES := ["", "Éveillé", "Ascendant", "Transcendant", "Avatar", "Légende vivante"]
const EVEIL_COL := ["#ffffff", "#7dd8ff", "#7dff8a", "#c77dff", "#ff9a3c", "#ff3d5a"]
const EVEIL_CD := 1800          # 1 tentative gratuite toutes les 30 min
func eveil() -> int: return int(S.get("eveil", 0))
func eveil_reqs(n: int) -> Array:
	# [texte, rempli ?]
	return [["Arme T%d ou mieux" % n, int(S.gear.get("epee", 0)) >= n],
		["Puissance %d (tu as %d)" % [power_needed(n) + 300 * (n - 1), power()], power() >= power_needed(n) + 300 * (n - 1)],
		["Palier %s obtenu" % ["", "—", "I", "II", "III", "IV"][n], eveil() >= n - 1]]
func eveil_ready() -> bool:
	var n := eveil() + 1
	if n > EVEIL_MAX: return false
	for r in eveil_reqs(n):
		if not r[1]: return false
	return true
func eveil_wait() -> int: return max(0, EVEIL_CD - (now() - int(S.get("eveil_try", 0))))
# multiplicateur de domination (dégâts infligés par un éveil a sur un éveil d)
static func dom(a: int, d: int) -> float: return clamp(1.0 + 0.45 * (a - d), 0.2, 3.0)
# éveil d'un combattant « joueur » (-1 = monstre : pas de domination)
func ev_of(n) -> int:
	if n == null or not is_instance_valid(n): return -1
	if n is Player: return eveil()
	if n is Bot: return int(n.eveil)
	if n is Enemy and n.def.has("eveil"): return int(n.def.eveil)
	return -1

# ================= ARÈNE CLASSÉE =================
const RANKS := [[0, "Bronze", "#c98a4a"], [1100, "Argent", "#cfd6de"], [1250, "Or", "#ffcf3a"], [1400, "Platine", "#7fe0d0"], [1600, "Diamant", "#7fb8ff"], [1850, "Champion", "#ff5a7a"]]
const RANK_CROWNS := [0, 20, 40, 80, 150, 300]
const PVP_FREE := 8              # combats classés gratuits par jour
func pvp() -> Dictionary:
	if typeof(S.get("pvp")) != TYPE_DICTIONARY: S["pvp"] = {"elo": 1000, "w": 0, "l": 0, "glory": 0, "day": "", "n": 0, "bonus": 0, "best": 0, "fw": ""}
	var d: String = Time.get_date_string_from_system()
	if S.pvp.day != d: S.pvp.day = d; S.pvp.n = 0
	return S.pvp
static func rank_of(elo: int) -> int:
	var r := 0
	for i in RANKS.size():
		if elo >= int(RANKS[i][0]): r = i
	return r
func pvp_left() -> int: return max(0, PVP_FREE - int(pvp().n)) + int(pvp().bonus)

static func npc_buy(t: int) -> int: return int(res_price(t) * 0.7)     # la marchande rachète à 70 % (l'hôtel des ventes paie mieux)
func is_dompteur() -> bool: return S.get("weapon_kind", "") == "dompteur"
func class_owned(k: String) -> bool: return typeof(S.get("classes")) == TYPE_DICTIONARY and S.classes.has(k)
func pets() -> Array:
	if typeof(S.get("pets")) != TYPE_ARRAY: S["pets"] = []
	return S.pets
func pet_eq() -> Array:
	if typeof(S.get("pet_eq")) != TYPE_ARRAY or S.pet_eq.size() != 3: S["pet_eq"] = ["", "", ""]
	return S.pet_eq
func pet_by_id(id: String) -> Dictionary:
	for p in pets():
		if str(p.id) == id: return p
	return {}
func pet_in_slot(i: int) -> Dictionary: return pet_by_id(str(pet_eq()[i])) if id_ok(str(pet_eq()[i])) else {}
static func id_ok(id: String) -> bool: return id != ""
static func pet_name(p: Dictionary) -> String: return "%s %s" % [PETS[p.sp].name, PET_RAR[int(p.r)].n.to_lower()]
static func pet_col(p: Dictionary) -> Color: return Color(PET_RAR[int(p.r)].c)
# puissance : rareté × espèce × l'arme du héros (le familier grandit avec toi)
func pet_power(p: Dictionary) -> int: return int(100.0 * float(PET_RAR[int(p.r)].m) * float(PETS[p.sp].dmg) * (1.0 + 0.6 * (int(S.gear.get("epee", 1)) - 1)))
static func roll_rarity(bonus := 0) -> int:
	var x := randf()
	var r := 0
	if x < 0.01: r = 4
	elif x < 0.06: r = 3
	elif x < 0.18: r = 2
	elif x < 0.45: r = 1
	return clamp(r + bonus, 0, 4)
func add_pet(sp: String, r: int) -> Dictionary:
	if pets().size() >= PET_MAX: return {}
	var p := {"id": "%d%d" % [Time.get_ticks_msec(), randi() % 1000], "sp": sp, "r": r}
	pets().append(p)
	for i in 3:
		if str(pet_eq()[i]) == "": pet_eq()[i] = p.id; break
	return p

static func ranged(kind: String) -> bool: return WEAPON_KINDS.get(kind, {}).has("range")
const SHIELD_MODEL := ["", "shield_A", "shield_round", "shield_square", "shield_C", "shield_spikes_color"]
static func weapon_model(kind: String, t: int) -> String: return "" if t <= 0 else W % WEAPON_KINDS[kind].models[clamp(t, 1, 5)]
static func shield_model(t: int) -> String: return "" if t <= 0 else W % SHIELD_MODEL[clamp(t, 1, 5)]
func wkind() -> Dictionary: return WEAPON_KINDS[S.get("weapon_kind", "epee")]
const SWORD_MODEL := ["", "res://assets/weapons/sword_A.gltf", "res://assets/weapons/sword_B.gltf", "res://assets/weapons/sword_C.gltf", "res://assets/weapons/sword_D.gltf", "res://assets/weapons/sword_E.gltf"]

# Recettes : coût d'un objet de tier t
const QTY := [0, 2.0, 4.0, 7.0, 12.0, 20.0]   # quantités de ressources : de plus en plus lourdes
static func recipe(item: String, t: int) -> Dictionary:
	var q: float = QTY[clamp(t, 1, 5)]
	var r := {}
	match item:
		"hache": r = {"wood": [max(1, t - 1), 5], "ore": [max(1, t - 1), 3]}
		"pioche": r = {"ore": [max(1, t - 1), 5], "wood": [max(1, t - 1), 3]}
		"faucille": r = {"fiber": [max(1, t - 1), 5], "wood": [max(1, t - 1), 3]}
		"epee": r = {"ore": [t, 6], "wood": [t, 3]}
		"armure": r = {"fiber": [t, 6], "ore": [t, 3]}
		"bottes": r = {"fiber": [t, 4], "wood": [t, 3]}
		"casque": r = {"ore": [t, 4], "fiber": [t, 2]}
		"cape": r = {"fiber": [t, 5], "wood": [t, 2]}
		"bouclier": r = {"ore": [t, 5], "wood": [t, 4]}
	for k in r: r[k][1] = int(ceil(r[k][1] * q))
	return r

# ——— Objets d'équipement (sac, hôtel des ventes) ———
const TIER_ADJ := ["", "du novice", "de l'apprenti", "du compagnon", "de l'adepte", "de l'expert"]
const SLOTS := ["epee", "bouclier", "casque", "armure", "cape", "bottes", "artefact", "monture", "hache", "pioche", "faucille"]
const COMBAT_SLOTS := ["epee", "bouclier", "casque", "armure", "cape", "bottes", "artefact"]
const SLOT_NAME := {"epee": "Arme", "bouclier": "Bouclier", "artefact": "Artefact", "monture": "Monture", "casque": "Casque", "armure": "Plastron", "cape": "Cape", "bottes": "Bottes", "hache": "Hache", "pioche": "Pioche", "faucille": "Faucille", "junk": "Bric-à-brac"}
# ——— Vrai stuff : chaque type de pièce a son profil (plus de vie, plus de dégâts, plus de vitesse…) ———
#   hp : part de vie (plastron = 1, les autres pièces ajoutent un petit %)   arm : armure par tier
#   speed / dmg / crit / cd / spell : bonus (vitesse, dégâts, critique, recharge, sorts)
const ARMOR_KINDS := {
	"plate": {"name": "Plastron de plates", "model": "Knight", "hp": 1.0, "arm": 8, "speed": -0.04, "cd": 0.0, "desc": "Beaucoup de vie et d'armure · un peu plus lent"},
	"cuir": {"name": "Veste de cuir", "model": "Ranger", "hp": 0.8, "arm": 4, "speed": 0.1, "cd": 0.0, "desc": "Vie moyenne · +10 % de vitesse"},
	"tissu": {"name": "Robe de mage", "model": "Mage", "hp": 0.65, "arm": 2, "speed": 0.0, "cd": 0.25, "spell": 0.15, "desc": "Peu de vie · compétences −25 % de recharge · sorts +15 %"},
	"barbare": {"name": "Harnais barbare", "model": "Barbarian", "hp": 0.85, "arm": 3, "speed": 0.0, "cd": 0.0, "dmg": 0.12, "desc": "Vie correcte · +12 % de dégâts"},
	"voleur": {"name": "Tenue d'assassin", "model": "Rogue", "hp": 0.72, "arm": 3, "speed": 0.05, "cd": 0.0, "crit": 0.1, "desc": "Peu de vie · +10 % de critique · +5 % de vitesse"},
}
const GEAR_KINDS := {
	"armure": ARMOR_KINDS,
	"casque": {
		"heaume": {"name": "Heaume", "model": "Knight", "parts": ["Knight_Helmet", "Knight_HelmetVisor"], "hp": 0.18, "arm": 4, "speed": -0.02, "desc": "Vie et armure · un peu lourd"},
		"ours": {"name": "Coiffe d'ours", "model": "Barbarian", "parts": ["Barbarian_BearHat"], "hp": 0.12, "arm": 2, "dmg": 0.08, "desc": "+8 % de dégâts"},
		"chapeau": {"name": "Chapeau d'arcaniste", "model": "Mage", "parts": ["Mage_Hat"], "hp": 0.08, "arm": 1, "cd": 0.12, "spell": 0.1, "desc": "Recharge −12 % · sorts +10 %"},
	},
	"cape": {
		"chevalier": {"name": "Cape du chevalier", "model": "Knight", "parts": ["Knight_Cape"], "hp": 0.14, "arm": 1, "desc": "+vie"},
		"arcane": {"name": "Cape de l'arcaniste", "model": "Mage", "parts": ["Mage_Cape"], "hp": 0.06, "spell": 0.12, "cd": 0.05, "desc": "Sorts +12 % · recharge −5 %"},
		"ombre": {"name": "Cape de l'ombre", "model": "Rogue", "parts": ["Rogue_Cape"], "hp": 0.06, "crit": 0.07, "desc": "+7 % de critique"},
		"rodeur": {"name": "Cape du rôdeur", "model": "Ranger", "parts": ["Ranger_Cape"], "hp": 0.07, "speed": 0.07, "desc": "+7 % de vitesse"},
	},
	"bottes": {
		"greves": {"name": "Grèves", "model": "Knight", "hp": 0.06, "arm": 3, "desc": "Bottes lourdes : armure"},
		"cuir": {"name": "Bottes de cuir", "model": "Ranger", "hp": 0.04, "arm": 1, "speed": 0.05, "desc": "+5 % de vitesse"},
		"sandales": {"name": "Chausses d'arcaniste", "model": "Mage", "hp": 0.03, "arm": 1, "cd": 0.08, "desc": "Recharge −8 %"},
	},
}
const KIND_KEY := {"epee": "weapon_kind", "armure": "armor_kind", "artefact": "artefact_kind", "monture": "mount_kind"}
const GK_SLOTS := ["casque", "cape", "bottes"]
const LEVEL_SLOTS := ["epee", "bouclier", "casque", "armure", "cape", "bottes"]
func kind_of(slot: String) -> String:
	if KIND_KEY.has(slot): return str(S.get(KIND_KEY[slot], ""))
	if slot in GK_SLOTS: return str(S.gk.get(slot, GEAR_KINDS[slot].keys()[0]))
	return ""
func set_kind(slot: String, k: String) -> void:
	if KIND_KEY.has(slot): S[KIND_KEY[slot]] = k
	elif slot in GK_SLOTS: S.gk[slot] = k
static func gear_def(slot: String, kind: String) -> Dictionary:
	if not GEAR_KINDS.has(slot): return {}
	var G: Dictionary = GEAR_KINDS[slot]
	return G.get(kind, G[G.keys()[0]])

# ——— Bonus aléatoires (selon le tier) et niveaux d'objet (gagnés en tuant des monstres) ———
const BX := {
	"vie": {"name": "Vie", "fmt": "+%d %% de vie", "base": 2.0, "per": 1.6},
	"degats": {"name": "Dégâts", "fmt": "+%d %% de dégâts", "base": 2.0, "per": 1.4},
	"armure": {"name": "Armure", "fmt": "+%d d'armure", "base": 2.0, "per": 2.5},
	"vitesse": {"name": "Vitesse", "fmt": "+%d %% de vitesse", "base": 1.0, "per": 0.8},
	"critique": {"name": "Critique", "fmt": "+%d %% de critique", "base": 1.0, "per": 0.9},
	"vol": {"name": "Vol de vie", "fmt": "%d %% de vol de vie", "base": 0.5, "per": 0.6},
}
static func roll_bx(it: Dictionary) -> Dictionary:
	if not it.slot in LEVEL_SLOTS or it.has("bx"): return it
	var t := int(it.tier)
	var n: int = [0, 0, 1, 1, 2, 2][clamp(t, 0, 5)] + (1 if t >= 3 and randf() < 0.3 else 0)
	var bx := {}
	var keys := BX.keys(); keys.shuffle()
	for i in n:
		var k: String = keys[i]
		bx[k] = max(1, int(round((BX[k].base + BX[k].per * t) * randf_range(0.7, 1.3))))
	it["bx"] = bx
	return it
const ILVL_MAX := 10
static func ilvl_need(l: int) -> int: return int(40 * pow(1.55, l))
func eqx(slot: String) -> Dictionary:
	if not S.eqx.has(slot): S.eqx[slot] = {"bx": {}, "lvl": 0, "xp": 0}
	return S.eqx[slot]
# XP de combat donnée à tout l'équipement porté ; renvoie les pièces qui montent de niveau
func gear_xp(amount: int) -> Array:
	var ups := []
	for sl in LEVEL_SLOTS:
		if int(S.gear.get(sl, 0)) <= 0: continue
		var x := eqx(sl)
		if int(x.lvl) >= ILVL_MAX: continue
		x.xp = int(x.xp) + amount
		while int(x.lvl) < ILVL_MAX and int(x.xp) >= ilvl_need(int(x.lvl)):
			x.xp = int(x.xp) - ilvl_need(int(x.lvl)); x.lvl = int(x.lvl) + 1; ups.append(sl)
	if not ups.is_empty(): _st.clear()
	return ups

# ——— Statistiques du héros (calculées une fois, recalculées quand l'équipement change) ———
var _st := {}
func stats_dirty() -> void: _st.clear()
func stats() -> Dictionary:
	if not _st.is_empty(): return _st
	var st := {"hp": 0.0, "arm": 0.0, "dmg": 0.0, "spd": 0.0, "crit": 0.05, "cd": 0.0, "spell": 0.0, "steal": 0.0, "vie": 0.0}
	for sl in ["armure", "casque", "cape", "bottes", "bouclier", "epee"]:
		var t := int(S.gear.get(sl, 0))
		if t <= 0: continue
		var x := eqx(sl); var lv: float = 1.0 + 0.05 * int(x.lvl); var em := ench_mult(ench(sl))
		if sl == "bouclier":
			st.hp += shield_hp(t) * lv * em; st.arm += 3.0 * t * lv * em
		elif sl != "epee":
			var K := gear_def(sl, kind_of(sl))
			var sc: float = 1.0 if sl == "armure" else (0.5 + 0.125 * t)
			st.hp += armor_hp(t) * float(K.get("hp", 0.0)) * lv * em
			st.arm += float(K.get("arm", 0)) * t * lv * em
			st.dmg += float(K.get("dmg", 0.0)) * sc; st.spd += float(K.get("speed", 0.0)) * sc; st.crit += float(K.get("crit", 0.0)) * sc
			st.cd += float(K.get("cd", 0.0)) * sc; st.spell += float(K.get("spell", 0.0)) * sc
		for k in x.bx:
			var v := float(x.bx[k])
			match k:
				"vie": st.vie += v / 100.0
				"degats": st.dmg += v / 100.0
				"armure": st.arm += v
				"vitesse": st.spd += v / 100.0
				"critique": st.crit += v / 100.0
				"vol": st.steal += v / 100.0
	var bt := int(S.gear.get("bottes", 0))
	if bt > 0: st.spd += 0.06 * (bt - 1) + 0.025 * ench("bottes")
	var ev := eveil()
	st.dmg += 0.18 * ev; st.crit += 0.03 * ev
	st.hp *= 1.0 + st.vie + art_bonus("vie") + mount_bonus("hp") + 0.18 * ev
	st.hp = max(st.hp, 60.0)
	st.steal += art_bonus("sang") * 0.5
	st.cd = min(st.cd, 0.6)
	st["red"] = st.arm / (st.arm + 120.0)    # réduction des dégâts grâce à l'armure
	_st = st
	return st
const BAG_SIZE := 24
func bag_size() -> int: return BAG_SIZE + int(S.get("bag_bonus", 0)) + (8 if build_done_any("banque") else 0)
# Artefacts : uniquement gagnés en duel, en donjon ou sur les boss de groupe
const ARTEFACTS := {
	"rage": {"name": "Idole de rage", "icon": "art_rage", "desc": "+%d %% de dégâts", "per": 6},
	"vie": {"name": "Calice de vie", "icon": "art_vie", "desc": "+%d %% de vie", "per": 8},
	"vent": {"name": "Sablier du vent", "icon": "art_vent", "desc": "+%d %% de vitesse", "per": 4},
	"sang": {"name": "Crâne de sang", "icon": "art_sang", "desc": "Vol de vie : %d %% des dégâts", "per": 2},
	"fortune": {"name": "Anneau de fortune", "icon": "art_fortune", "desc": "+%d %% d'argent gagné", "per": 10},
}
func art_bonus(kind: String) -> float:
	if S.gear.get("artefact", 0) <= 0 or S.get("artefact_kind", "") != kind: return 0.0
	return ARTEFACTS[kind].per * S.gear.artefact / 100.0 * ench_mult(ench("artefact"))
static func art_desc(kind: String, t: int) -> String: return ARTEFACTS[kind].desc % (ARTEFACTS[kind].per * t)
static func random_artefact(t: int) -> Dictionary: return {"slot": "artefact", "tier": t, "kind": ARTEFACTS.keys()[randi() % ARTEFACTS.size()]}
# Puissance d'équipement (affichée au joueur, sert de repère pour donjons et duels)
func power() -> int:
	var p := 0.0
	for s in COMBAT_SLOTS: p += S.gear.get(s, 0) * (150.0 if s == "artefact" else 100.0) * ench_mult(ench(s))
	return int(p) + 300 * eveil()
static func power_needed(t: int) -> int: return 560 * t

# ================= PROGRESSION : couronnes, premium, boosts, quotidien, classement =================
static func now() -> int: return int(Time.get_unix_time_from_system())
var paid_crowns := 0         # Cache of the server wallet; never written to Game.S.
var paid_premium_until := 0
func earned_crowns() -> int: return maxi(0, int(S.get("crowns", 0)))
func crowns() -> int: return earned_crowns() + maxi(0, paid_crowns)
func add_crowns(n: int) -> void: S["crowns"] = earned_crowns() + n; save()
func spend_crowns(n: int) -> bool:
	# This method only spends earned crowns. Paid crowns go through Net.
	if n < 0 or earned_crowns() < n: return false
	S["crowns"] = earned_crowns() - n; save(); return true
func premium_left() -> int: return max(0, maxi(int(S.get("premium_until", 0)), paid_premium_until) - now())
func is_premium() -> bool: return premium_left() > 0
func boost_left() -> int: return max(0, int(S.get("boost_until", 0)) - now())
func add_time(key: String, sec: int) -> void:
	var base := int(S.get(key, 0))
	if key == "premium_until": base = maxi(base, paid_premium_until)
	S[key] = max(base, now()) + sec; save()
# multiplicateurs : Premium +50 % XP et argent, boost +100 % XP
func xp_mult() -> float: return 1.0 + (0.5 if is_premium() else 0.0) + (1.0 if boost_left() > 0 else 0.0)
func silver_mult() -> float: return 1.0 + (0.5 if is_premium() else 0.0)
static func dur_txt(sec: int) -> String:
	if sec >= 86400: return "%d j %d h" % [sec / 86400, (sec % 86400) / 3600]
	if sec >= 3600: return "%d h %02d" % [sec / 3600, (sec % 3600) / 60]
	return "%d min" % max(1, sec / 60)

# connexion quotidienne : 7 jours, la récompense grossit, le 7e jour est énorme
const LOGIN_REWARDS := [
	{"silver": 500, "txt": "500 argent"}, {"potions": 5, "txt": "5 potions"}, {"crowns": 20, "txt": "20 couronnes"},
	{"silver": 3000, "txt": "3 000 argent"}, {"boost": 3600, "txt": "Boost XP ×2 · 1 h"}, {"crowns": 40, "txt": "40 couronnes"},
	{"crowns": 100, "premium": 86400, "txt": "100 couronnes + 1 jour Premium"}]
func login_state() -> Dictionary:
	if typeof(S.get("login")) != TYPE_DICTIONARY: S["login"] = {"day": -1, "streak": 0, "claimed": -1}
	return S.login
func login_can_claim() -> bool: return int(login_state().claimed) != day_index()
func login_next_index() -> int:
	var L := login_state()
	var cont: bool = int(L.claimed) == day_index() - 1
	return (int(L.streak) % 7) if cont else 0
func login_claim() -> Dictionary:
	var L := login_state()
	if not login_can_claim(): return {}
	var i := login_next_index()
	L.streak = i + 1; L.claimed = day_index()
	var r: Dictionary = LOGIN_REWARDS[i]
	grant(r)
	return r
func grant(r: Dictionary) -> void:
	if r.has("silver"): S.silver += int(r.silver)
	if r.has("potions"): S.potions += int(r.potions)
	if r.has("crowns"): S["crowns"] = earned_crowns() + int(r.crowns)
	if r.has("boost"): add_time("boost_until", int(r.boost))
	if r.has("premium"): add_time("premium_until", int(r.premium))
	save()

# EXPÉDITIONS : tes mercenaires partent en mission, même quand le jeu est fermé
const EXPED := [[3600, "1 heure"], [4 * 3600, "4 heures"], [8 * 3600, "8 heures"], [12 * 3600, "12 heures"]]
func exped() -> Dictionary: return S.get("exped", {}) if typeof(S.get("exped", {})) == TYPE_DICTIONARY else {}
func exped_left() -> int:
	var e := exped()
	if e.is_empty(): return -1
	return max(0, int(e.start) + int(e.dur) - now())
func exped_ready() -> bool: return exped_left() == 0
func exped_start(i: int) -> void:
	S["exped"] = {"start": now(), "dur": int(EXPED[i][0]), "tier": clamp(int(S.gear.get("epee", 1)), 1, 5), "label": EXPED[i][1]}; save()
func exped_collect() -> Dictionary:
	var e := exped()
	if e.is_empty() or not exped_ready(): return {}
	var h: float = float(e.dur) / 3600.0; var t: int = int(e.tier)
	var mult: float = silver_mult()
	var loot: Array = [{"silver": int(money(t) * 140.0 * h * mult)}]
	for k in RES_KEYS: loot.append({"res": k, "tier": t, "qty": int(8 * h * mult) + 2})
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for k in int(h / 2.0) + 1:
		if rng.randf() < 0.55: loot.append({"item": random_item(t)})
	if rng.randf() < 0.08 * h: loot.append({"item": random_artefact(t)})
	loot.append({"potion": int(h) + 1})
	var crowns_won := int(2 * h)
	S["crowns"] = earned_crowns() + crowns_won
	S["exped"] = {}; save()
	return {"loot": loot, "crowns": crowns_won, "label": e.label}

# ================= RÉPUTATION : chaque royaume (carte) a son opinion de toi =================
# −100 … +100 · on arrive en étranger mal vu, il faut gagner la confiance des habitants
const REP_LV := [[-100, "Hostile", "hostile", "#ff5a4a"], [-40, "Méfiant", "mefiant", "#ff9a3a"], [0, "Neutre", "neutre", "#ffd24a"], [30, "Amical", "amical", "#7dff8a"], [70, "Héros", "heros", "#ffcf3a"]]
func rep(map := -1) -> int:
	if typeof(S.get("rep")) != TYPE_DICTIONARY: S["rep"] = {}
	var k := str(map if map > 0 else int(S.get("map", 1)))
	if not S.rep.has(k): S.rep[k] = -45 if not S.has("rep_old") else -20
	return int(S.rep[k])
func rep_level(v := 99999) -> Array:
	if v == 99999: v = rep()
	var out: Array = REP_LV[0]
	for l in REP_LV:
		if v >= int(l[0]): out = l
	return out
func rep_add(n: int, map := -1) -> Array:
	var before: Array = rep_level(rep(map))
	var k := str(map if map > 0 else int(S.get("map", 1)))
	S.rep[k] = clamp(rep(map) + n, -100, 100); save()
	var after: Array = rep_level(rep(map))
	return [before, after]
func price_mult() -> float: return {"hostile": 1.3, "mefiant": 1.15, "neutre": 1.0, "amical": 0.92, "heros": 0.85}[rep_level()[2]]

# quêtes du jour : 3 objectifs tirés chaque jour
const DQ_POOL := [
	{"id": "kill", "txt": "Tue %d monstres", "n": [25, 40, 60]},
	{"id": "gather", "txt": "Récolte %d ressources", "n": [60, 100, 160]},
	{"id": "elite", "txt": "Tue %d monstres d'élite", "n": [3, 5, 8]},
	{"id": "dungeon", "txt": "Termine %d donjon", "n": [1, 1, 2]},
	{"id": "food", "txt": "Cueille %d fruits ou légumes", "n": [10, 20, 30]},
	{"id": "silver", "txt": "Gagne %d argent", "n": [2000, 6000, 15000]}]
func daily_quests() -> Array:
	if typeof(S.get("dq")) != TYPE_DICTIONARY or int(S.dq.get("day", -1)) != day_index():
		var rng := RandomNumberGenerator.new(); rng.seed = day_index() * 7919
		var pool := DQ_POOL.duplicate(); var list: Array = []
		var lvl: int = clamp(gear_level() - 1, 0, 2)
		for k in 3:
			var q: Dictionary = pool.pop_at(rng.randi() % pool.size())
			list.append({"id": q.id, "txt": q.txt % q.n[lvl], "goal": q.n[lvl], "n": 0, "claimed": false, "crowns": 10 + 5 * k, "silver": int(money(gear_level()) * 400)})
		S["dq"] = {"day": day_index(), "list": list, "bonus": false}
	return S.dq.list
func dq_progress(id: String, n := 1) -> String:
	var done := ""
	for q in daily_quests():
		if q.id == id and int(q.n) < int(q.goal):
			q.n = min(int(q.goal), int(q.n) + n)
			if int(q.n) >= int(q.goal): done = q.txt
	return done
func dq_ready() -> int:
	var c := 0
	for q in daily_quests():
		if int(q.n) >= int(q.goal) and not q.claimed: c += 1
	return c

# classement de puissance : 100 aventuriers qui progressent aussi chaque jour
const RANK_NAMES := ["Kaelith", "Morvane", "Thorgal", "Ysolde", "Brennic", "Aldwen", "Sorcha", "Varek", "Lunessa", "Grimbald", "Elowen", "Draven", "Isolde", "Ragnar", "Seraphe", "Corwin", "Mirelle", "Tybalt", "Nyssa", "Haldor",
	"Fenric", "Aurelie", "Bastien", "Celestin", "Doriane", "Eldric", "Faelan", "Gwenaël", "Hugon", "Ilyana", "Jorund", "Kassia", "Leofric", "Maelis", "Norrin", "Oriane", "Perceval", "Quintus", "Rozenn", "Sigurd"]
func ranking() -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = 424242
	var days: int = max(0, day_index() - int(S.get("rank_day0", day_index())))
	if not S.has("rank_day0"): S["rank_day0"] = day_index()
	var out: Array = []
	for i in 100:
		var base: float = 9000.0 * pow(0.965, i) + rng.randf_range(-60, 60)
		var p: int = int(base * (1.0 + 0.012 * days))
		var nm: String = RANK_NAMES[i % RANK_NAMES.size()] + ("" if i < RANK_NAMES.size() else str(rng.randi_range(2, 99)))
		out.append({"nm": nm, "pwr": max(200, p), "me": false, "guild": ["Lames d'Argent", "Ordre du Cerf", "Les Corbeaux", "Couronne Noire", ""][rng.randi() % 5]})
	out.append({"nm": "Toi", "pwr": power(), "me": true, "guild": str(S.guild.get("name", ""))})
	out.sort_custom(func(a, b): return a.pwr > b.pwr)
	return out
func my_rank() -> int:
	var r := ranking()
	for i in r.size():
		if r[i].me: return i + 1
	return r.size()

static func item_name(it: Dictionary) -> String:
	var base := ""
	match it.slot:
		"epee": base = WEAPON_KINDS[it.get("kind", "epee")].name
		"bouclier": base = "Bouclier"
		"armure": base = ARMOR_KINDS.get(it.get("kind", "plate"), ARMOR_KINDS.plate).name
		"bottes", "casque", "cape": base = gear_def(it.slot, it.get("kind", "")).name
		"artefact": base = ARTEFACTS[it.get("kind", "rage")].name
		"monture": return MOUNTS[it.get("kind", "ane")].name
		"junk": return JUNK.get(it.get("kind", "os"), JUNK.os).name
		_:
			base = TOOL_NAME[it.slot]
			if it.slot in TOOL_SLOTS: return "%s T%d · %s" % [base, int(it.tier), TOOL_Q[clamp(int(it.get("q", 0)), 0, 3)].name]
	var e := int(it.get("ench", 0))
	if it.has("nm") and str(it.nm) != "": return "%s%s" % [it.nm, (" +%d" % e) if e > 0 else ""]
	return "%s %s%s" % [base, TIER_ADJ[clamp(int(it.tier), 0, 5)], (" +%d" % e) if e > 0 else ""]

# Objet aléatoire (butin, hôtel des ventes)
static func random_item(t: int, with_tools := false) -> Dictionary:
	var pool := ["epee", "epee", "bouclier", "armure", "armure", "bottes", "casque", "casque", "cape"]
	if with_tools: pool += ["hache", "pioche", "faucille"]
	var slot: String = pool[randi() % pool.size()]
	var it := {"slot": slot, "tier": t}
	if slot == "epee":
		var wks: Array = WEAPON_KINDS.keys().filter(func(k): return not WEAPON_KINDS[k].get("classe", false))
		it["kind"] = wks[randi() % wks.size()]
	elif GEAR_KINDS.has(slot): it["kind"] = GEAR_KINDS[slot].keys()[randi() % GEAR_KINDS[slot].size()]
	return roll_bx(it)

# ——— Bric-à-brac : objets sans usage, qui se revendent (un peu) chez la marchande ———
const JUNK := {
	"os": {"name": "Os rongé", "v": 0.6, "model": "res://assets/halloween/bone_A.gltf"},
	"crane": {"name": "Crâne fêlé", "v": 1.2, "model": "res://assets/halloween/skull.gltf"},
	"cotes": {"name": "Cage thoracique", "v": 2.2, "model": "res://assets/halloween/ribcage.gltf"},
	"fiole": {"name": "Fiole vide", "v": 0.8, "model": "res://assets/dungeon/bottle_C_green.gltf", "tint": Color(0.75, 0.8, 0.8)},
	"bougie": {"name": "Bougie fondue", "v": 0.5, "model": "res://assets/dungeon/candle_triple.gltf"},
	"citrouille": {"name": "Citrouille gâtée", "v": 0.4, "model": "res://assets/halloween/pumpkin_yellow_small.gltf"},
	"lame": {"name": "Lame brisée", "v": 1.8, "model": "res://assets/dungeon/sword_shield_broken.gltf"},
	"pieces": {"name": "Pièces anciennes", "v": 5.0, "model": "res://assets/dungeon/coin_stack_large.gltf"},
	"peau": {"name": "Peau de bête", "v": 1.5, "model": "res://assets/hex/sack.gltf", "tint": Color(0.7, 0.5, 0.35)},
	"croc": {"name": "Croc acéré", "v": 1.1, "model": "res://assets/halloween/bone_A.gltf", "tint": Color(1.0, 0.95, 0.75)},
}
const JUNK_SKEL := ["os", "os", "crane", "crane", "fiole", "bougie", "lame", "cotes", "pieces"]
const JUNK_BEAST := ["peau", "peau", "croc", "croc", "os"]
const JUNK_MAN := ["fiole", "citrouille", "lame", "bougie", "pieces"]
static func junk_price(it: Dictionary) -> int: return int(JUNK.get(it.get("kind", "os"), JUNK.os).v * money(int(it.tier)) * 3.0) + 1
static func random_junk(t: int, pool: Array) -> Dictionary: return {"slot": "junk", "tier": t, "kind": pool[randi() % pool.size()]}

# ——— Butin : chaque source a sa table, avec du bon… et beaucoup de banal ———
# Entrées au format des coffres : {item}, {silver}, {potion}, {res, tier, qty}
static func _pick(w: Dictionary) -> String:
	var tot := 0.0
	for k in w: tot += w[k]
	var r := randf() * tot
	for k in w:
		r -= w[k]
		if r <= 0.0: return k
	return w.keys()[0]

static func roll_loot(src: String, t: int, family := "skel") -> Array:
	t = clamp(t, 1, MAX_TIER)
	var pool: Array = JUNK_SKEL if family == "skel" else (JUNK_BEAST if family == "beast" else JUNK_MAN)
	var n: int = {"mob": randi_range(1, 2), "elite": randi_range(2, 3), "chest": randi_range(2, 4), "hidden": randi_range(3, 4), "boss": randi_range(4, 6), "dungeon": randi_range(4, 6), "group": randi_range(5, 7), "pvp": randi_range(2, 4)}.get(src, 2)
	var w: Dictionary = {
		"mob": {"junk": 50, "silver": 22, "res": 16, "potion": 7, "item": 3},
		"elite": {"junk": 32, "silver": 28, "res": 20, "potion": 8, "item": 12},
		"chest": {"junk": 25, "silver": 30, "res": 25, "potion": 10, "item": 10},
		"hidden": {"junk": 15, "silver": 35, "res": 25, "potion": 10, "item": 15},
		"boss": {"junk": 18, "silver": 26, "res": 26, "potion": 10, "item": 20},
		"dungeon": {"junk": 14, "silver": 26, "res": 26, "potion": 10, "item": 24},
		"group": {"junk": 10, "silver": 25, "res": 25, "potion": 10, "item": 30},
		"pvp": {"junk": 25, "silver": 35, "res": 20, "potion": 10, "item": 10},
	}.get(src, {"junk": 1})
	var mult: float = {"mob": 2.0, "elite": 5.0, "chest": 6.0, "hidden": 12.0, "boss": 18.0, "dungeon": 22.0, "group": 30.0, "pvp": 10.0}.get(src, 3.0)
	var out := []
	var has_silver := false
	for i in n:
		var k := _pick(w)
		match k:
			"junk": out.append({"item": random_junk(t, pool)})
			"silver":
				if has_silver: out.append({"item": random_junk(t, pool)}); continue
				has_silver = true; out.append({"silver": int(money(t) * mult * randf_range(0.5, 1.3)) + 1})
			"res": out.append({"res": RES_KEYS[randi() % 3], "tier": t, "qty": randi_range(1, 2 + int(mult / 4.0))})
			"potion": out.append({"potion": 1 if mult < 15.0 else randi_range(1, 2)})
			"item":
				var it_t: int = t if randf() > 0.25 else max(1, t - 1)
				if src in ["dungeon", "group"] and randf() < 0.25: it_t = min(MAX_TIER, t + 1)
				out.append({"item": random_item(it_t) if randf() > 0.06 else random_artefact(it_t)})
	# les grosses sources garantissent au moins un objet
	if src in ["boss", "dungeon", "group", "hidden"] and not out.any(func(e): return e.has("item") and e.item.slot != "junk"):
		out.append({"item": random_item(t)})
	if src == "group": out.append({"item": random_artefact(min(MAX_TIER, t + (1 if randf() < 0.3 else 0)))})
	return out

# ——— Cueillette : fruits et légumes (pack Low Poly Food) ———
# "plant" : buisson (fruits accrochés), potager (légumes dans une butte de terre), sol (champignons, courges)
const FOOD := {
	"pomme": {"name": "Pomme", "m": "apple", "plant": "buisson", "heal": 1.0},
	"fraise": {"name": "Fraise", "m": "strawberry", "plant": "buisson", "heal": 0.8},
	"cerise": {"name": "Cerises", "m": "cherryPair", "plant": "buisson", "heal": 0.9},
	"poire": {"name": "Poire", "m": "pear", "plant": "buisson", "heal": 1.0},
	"peche": {"name": "Pêche", "m": "peach", "plant": "buisson", "heal": 1.1},
	"orange": {"name": "Orange", "m": "orange", "plant": "buisson", "heal": 1.1},
	"citron": {"name": "Citron", "m": "lemon", "plant": "buisson", "heal": 0.9},
	"figue": {"name": "Figue", "m": "fig", "plant": "buisson", "heal": 1.1},
	"coco": {"name": "Noix de coco", "m": "coconut", "plant": "sol", "heal": 1.4},
	"mangue": {"name": "Mangue", "m": "mango", "plant": "buisson", "heal": 1.2},
	"kiwi": {"name": "Kiwi", "m": "kiwi", "plant": "buisson", "heal": 1.0},
	"banane": {"name": "Bananes", "m": "bananaBunch", "plant": "buisson", "heal": 1.3},
	"carotte": {"name": "Carotte", "m": "carrotWithStem", "plant": "potager", "heal": 1.0},
	"chou": {"name": "Chou", "m": "cabbage", "plant": "potager", "heal": 1.2},
	"tomate": {"name": "Tomate", "m": "tomatoWithStem", "plant": "potager", "heal": 0.9},
	"mais": {"name": "Maïs", "m": "cornWithLeafs", "plant": "potager", "heal": 1.1},
	"citrouille": {"name": "Citrouille", "m": "pumpkin", "plant": "sol", "heal": 1.5},
	"pasteque": {"name": "Pastèque", "m": "watermelon", "plant": "sol", "heal": 1.6},
	"melon": {"name": "Melon", "m": "melon", "plant": "sol", "heal": 1.4},
	"betterave": {"name": "Betterave", "m": "beetroot", "plant": "potager", "heal": 1.0},
	"oignon": {"name": "Oignon", "m": "onionRed", "plant": "potager", "heal": 0.9},
	"ail": {"name": "Ail", "m": "garlicBulb", "plant": "potager", "heal": 0.8},
	"aubergine": {"name": "Aubergine", "m": "eggplantWithStem", "plant": "potager", "heal": 1.1},
	"poivron": {"name": "Poivron", "m": "bellpepper", "plant": "potager", "heal": 1.0},
	"choufleur": {"name": "Chou-fleur", "m": "cauliflowerWithLeafs", "plant": "potager", "heal": 1.2},
	"brocoli": {"name": "Brocoli", "m": "broccoli", "plant": "potager", "heal": 1.0},
	"patate": {"name": "Pomme de terre", "m": "potato", "plant": "potager", "heal": 1.1},
	"salade": {"name": "Salade", "m": "lettuce", "plant": "potager", "heal": 0.8},
	"cepe": {"name": "Cèpe", "m": "mushroom01", "plant": "sol", "heal": 1.0},
	"girolle": {"name": "Girolle", "m": "mushroom02", "plant": "sol", "heal": 1.0},
	"amanite": {"name": "Champignon des marais", "m": "mushroom03", "plant": "sol", "heal": 1.2},
	"morille": {"name": "Morille noire", "m": "mushroom04", "plant": "sol", "heal": 1.3},
}
# ce qui pousse dans chaque type de région : [sauvage (buissons, sol)], [potagers des fermes]
const FOOD_BY_STYLE := {
	"meadow": [["pomme", "fraise", "cepe"], ["carotte", "chou", "tomate", "mais", "salade", "patate"]],
	"forest": [["cerise", "poire", "cepe", "girolle"], ["citrouille", "betterave", "chou", "carotte"]],
	"hills": [["poire", "peche", "pomme", "girolle"], ["mais", "oignon", "ail", "patate"]],
	"desert": [["figue", "coco", "citron", "mangue"], ["pasteque", "melon", "poivron", "oignon"]],
	"canyon": [["orange", "citron", "figue", "banane"], ["poivron", "ail", "melon", "tomate"]],
	"swamp": [["kiwi", "amanite", "morille"], ["aubergine", "choufleur", "brocoli", "oignon"]],
	"ash": [["morille", "amanite", "figue"], ["ail", "betterave", "choufleur", "patate"]],
}
static func food_key(k: String, t: int) -> String: return "%s:%d" % [k, t]
static func food_heal(k: String, t: int) -> float: return (0.07 + 0.025 * t) * float(FOOD[k].heal)   # part de la vie rendue
static func food_price(k: String, t: int) -> int: return int(money(t) * 1.2 * float(FOOD[k].heal)) + 1
static func food_name(k: String, _t := 1) -> String: return FOOD[k].name
func add_food(k: String, t: int, n: int) -> void:
	if typeof(S.get("food")) != TYPE_DICTIONARY: S["food"] = {}
	var key := food_key(k, t); S.food[key] = int(S.food.get(key, 0)) + n

static func res_name(k: String, t: int) -> String: return "%s (%s)" % [RES[k].tiers[t], RES[k].name]

# ——— Économie : chaque tier vaut beaucoup plus que le précédent ———
const ITEM_BASE := [0, 90, 700, 11000, 180000, 2500000]
const SLOT_MULT := {"monture": 4.0, "epee": 1.2, "armure": 1.0, "bouclier": 0.8, "bottes": 0.65, "casque": 0.6, "cape": 0.7, "artefact": 1.6, "hache": 0.45, "pioche": 0.45, "faucille": 0.45}
const MONEY := [0, 1.0, 5.0, 60.0, 800.0, 12000.0]   # échelle d'argent gagné par tier
static func money(t: int) -> float: return MONEY[clamp(t, 1, 5)]
# Prix « réel » du marché (sert de référence à l'hôtel des ventes)
static func item_value(slot: String, t: int, ench := 0) -> int:
	if t <= 0: return 0
	return int(ITEM_BASE[clamp(t, 1, 5)] * SLOT_MULT.get(slot, 1.0) * (1.0 + 0.6 * ench))
static func item_price(it: Dictionary) -> int:
	if it.slot == "junk": return junk_price(it)
	if it.get("bebe", false): return int(item_value("monture", int(it.tier)) * 2.5)
	if it.slot in TOOL_SLOTS: return int(tool_price(int(it.tier), int(it.get("q", 0))) * 0.6)
	return item_value(it.slot, int(it.tier), int(it.get("ench", 0)))

# Affichage de l'argent : 9 450 · 245,3 k · 3,20 M
static func fmt(n: float) -> String:
	var a: float = abs(n)
	if a >= 1000000.0: return ("%.2f M" % (n / 1000000.0)).replace(".", ",")
	if a >= 100000.0: return ("%.0f k" % (n / 1000.0))
	if a >= 10000.0: return ("%.1f k" % (n / 1000.0)).replace(".", ",")
	var s := str(int(n)); if a >= 1000.0: s = s.substr(0, s.length() - 3) + " " + s.substr(s.length() - 3)
	return s

# ——— Métiers de récolte : niveaux, XP ———
const PROF_OF := {"wood": "hache", "ore": "pioche", "fiber": "faucille"}
const PROF_REQ := [0, 1, 6, 13, 21, 29]          # niveau de métier requis pour récolter chaque tier
const PROF_MAX := 40
static func prof_need(lvl: int) -> int: return int(130 * pow(1.29, lvl - 1))   # lent : ~2 h pour le T3, ~12 h pour le T4, ~60 h pour le T5
func prof(tool: String) -> Dictionary:
	if not S.prof.has(tool): S.prof[tool] = {"lvl": 1, "xp": 0}
	return S.prof[tool]
# temps entre deux coups de récolte : lent au début, rapide avec le niveau
func gather_time(tool: String, t: int) -> float:
	return max(0.35, (1.6 + 0.3 * t) * pow(0.95, prof(tool).lvl - 1) * TOOL_Q[toolq(tool)].speed)
# ajoute de l'XP ; renvoie le nombre de niveaux gagnés
func add_prof_xp(tool: String, xp: int) -> int:
	var p := prof(tool); var ups := 0
	p.xp = int(p.xp) + int(xp * xp_mult())
	while int(p.lvl) < PROF_MAX and int(p.xp) >= prof_need(int(p.lvl)):
		p.xp = int(p.xp) - prof_need(int(p.lvl)); p.lvl = int(p.lvl) + 1; ups += 1
	return ups

# ——— Maîtrise d'arme : XP en tuant des monstres, +0,5 % de dégâts par niveau ———
const WXP_MAX := 50
static func weapon_need(lvl: int) -> int: return int(120 * pow(1.3, lvl - 1))   # lent : ~3 h pour le T3, ~14 h pour le T4, ~70 h pour le T5
func wxp(kind: String) -> Dictionary:
	if not S.wxp.has(kind): S.wxp[kind] = {"lvl": 1, "xp": 0}
	return S.wxp[kind]
func weapon_bonus() -> float: return 0.005 * (int(wxp(S.get("weapon_kind", "epee")).lvl) - 1)
func add_weapon_xp(kind: String, xp: int) -> int:
	var w := wxp(kind); var ups := 0
	w.xp = int(w.xp) + int(xp * xp_mult())
	while int(w.lvl) < WXP_MAX and int(w.xp) >= weapon_need(int(w.lvl)):
		w.xp = int(w.xp) - weapon_need(int(w.lvl)); w.lvl = int(w.lvl) + 1; ups += 1
	return ups

# ——— Montures : vitesse quand on les monte, petits bonus permanents ———
const MOUNTS := {
	"ane": {"name": "Âne de bât", "tier": 1, "model": "donkey", "scale": 0.6, "speed": 0.5, "dmg": 0.02, "hp": 0.0, "seat": 1.15},
	"cheval": {"name": "Cheval de selle", "tier": 2, "model": "horse", "scale": 0.62, "speed": 0.75, "dmg": 0.0, "hp": 0.04, "seat": 1.5},
	"cerf": {"name": "Cerf des bois", "tier": 3, "model": "stag", "scale": 0.6, "speed": 0.85, "dmg": 0.05, "hp": 0.0, "seat": 1.4},
	"loup": {"name": "Loup de guerre", "tier": 4, "model": "wolf", "scale": 0.8, "speed": 0.95, "dmg": 0.0, "hp": 0.08, "seat": 1.1},
	"taureau": {"name": "Taureau cuirassé", "tier": 5, "model": "bull", "scale": 0.6, "speed": 1.0, "dmg": 0.12, "hp": 0.15, "seat": 1.6, "tint": Color(0.75, 0.42, 0.38)},
	"pegase": {"name": "Pégase d'Azur", "tier": 5, "model": "horse", "scale": 0.72, "speed": 1.7, "dmg": 0.3, "hp": 0.3, "seat": 1.7, "tint": Color(1.1, 1.7, 2.6), "shop": true},
	"roi_cerf": {"name": "Roi-Cerf doré", "tier": 5, "model": "stag", "scale": 0.72, "speed": 1.2, "dmg": 0.15, "hp": 0.12, "seat": 1.65, "tint": Color(1.6, 1.35, 0.7)},
}
func mount() -> Dictionary: return MOUNTS.get(S.get("mount_kind", ""), {}) if S.gear.get("monture", 0) > 0 else {}
func mount_bonus(k: String) -> float:
	var b := float(mount().get(k, 0.0))
	if k == "speed" and not mount().is_empty() and build_done_any("ecurie"): b += 0.1
	return b

# ——— Chantiers : la ville grandit. Les habitants bâtissent doucement, les joueurs accélèrent en apportant des ressources ———
const BUILDS := {
	"banque": {"name": "Banque royale", "perk": "+8 cases dans ton sac (dans tout le royaume)", "cost": {"wood": [2, 120], "ore": [2, 120], "fiber": [1, 80]}},
	"ecurie": {"name": "Écurie", "perk": "+10 % de vitesse sur toutes tes montures", "cost": {"wood": [1, 150], "fiber": [2, 100], "ore": [1, 60]}},
}
const BUILD_HOURLY := 0.004     # les habitants avancent seuls d'environ 0,4 % par heure (jusqu'à 60 %)
func _bkey(map: int, id: String) -> String: return "%d_%s" % [map, id]
func build_state(map: int, id: String) -> Dictionary:
	if typeof(S.get("builds")) != TYPE_DICTIONARY: S["builds"] = {}
	var k := _bkey(map, id)
	if not S.builds.has(k): S.builds[k] = {"g": {}, "town": 0.0, "t": Time.get_unix_time_from_system()}
	var st: Dictionary = S.builds[k]
	var now := Time.get_unix_time_from_system()
	var dt_h: float = max(0.0, now - float(st.get("t", now))) / 3600.0
	st.town = min(0.6, float(st.get("town", 0.0)) + dt_h * BUILD_HOURLY); st.t = now
	return st
func build_prog(map: int, id: String) -> float:
	var st := build_state(map, id)
	if st.get("done", false): return 1.0
	var c: Dictionary = BUILDS[id].cost
	var sum := 0.0
	for r in c: sum += min(1.0, float(st.g.get(r, 0)) / float(c[r][1]))
	return clamp(sum / c.size() + float(st.town) * 0.5, 0.0, 1.0)      # dons des joueurs + travail des habitants (jusqu'à 30 %)
func build_done_any(id: String) -> bool:
	if typeof(S.get("builds")) != TYPE_DICTIONARY: return false
	for k in S.builds:
		if str(k).ends_with("_" + id) and S.builds[k].get("done", false): return true
	return false
static func mount_desc(kind: String) -> String:
	var M: Dictionary = MOUNTS[kind]; var parts := ["+%d %% de vitesse montée" % int(M.speed * 100)]
	if M.dmg > 0: parts.append("+%d %% de dégâts" % int(M.dmg * 100))
	if M.hp > 0: parts.append("+%d %% de vie" % int(M.hp * 100))
	return " · ".join(parts)
static func random_mount(max_t: int) -> Dictionary:
	var ks := []
	for k in MOUNTS:
		if MOUNTS[k].tier <= max_t and not MOUNTS[k].get("shop", false): ks.append(k)
	var k: String = ks[randi() % ks.size()]
	return {"slot": "monture", "tier": MOUNTS[k].tier, "kind": k}

# ——— Outils de récolte : tier (débloqué par le métier) + qualité (achetée) ———
const TOOL_SLOTS := ["hache", "pioche", "faucille"]
const TOOL_Q := [
	{"name": "Commune", "col": "#4fe36a", "speed": 1.0, "bonus": 0.0, "mult": 1.0},
	{"name": "Rare", "col": "#4d9bff", "speed": 0.82, "bonus": 0.12, "mult": 4.0},
	{"name": "Épique", "col": "#b45cff", "speed": 0.66, "bonus": 0.25, "mult": 15.0},
	{"name": "Légendaire", "col": "#ffb02e", "speed": 0.5, "bonus": 0.4, "mult": 60.0},
]
const TOOL_BASE := [0, 60, 900, 9000, 120000, 1500000]
static func tool_price(t: int, q: int) -> int: return int(TOOL_BASE[clamp(t, 1, 5)] * TOOL_Q[clamp(q, 0, 3)].mult)
func toolq(tool: String) -> int: return int(S.toolq.get(tool, 0))
const VENDOR_OF := {"hache": "bjorn", "pioche": "gorm", "faucille": "sylve"}
const VENDOR_NAME := {"hache": "Bjorn le bûcheron", "pioche": "Gorm le mineur", "faucille": "Sylve l'herboriste"}
const PROF_TITLE := {"hache": "Bûcheron", "pioche": "Mineur", "faucille": "Cueilleur"}

# ——— Île privée ———
static func new_island() -> Dictionary:
	return {"owned": false, "lvl": 1, "chest": {"res": {}, "silver": 0, "items": []}, "last_day": -1,
		"raids": [], "raid_day": -1, "guard_until": 0, "pen": [], "pen_t": 0, "farm": [0, 0, 0, 0]}
const ISLAND_PRICE := 100000000
const ISLAND_UP := [0, 0, 250000000, 600000000, 1500000000, 4000000000]   # coût pour passer au niveau n
const ISLAND_NAME := ["", "Petite île", "Îlot boisé", "Île des marchands", "Grande île", "Île royale"]
# production journalière (avant la part des travailleurs) : [tier, quantité par ressource]
static func island_prod(lvl: int) -> Array:
	return [[4, 40 + 20 * lvl], [5, 10 + 12 * lvl]]
const WORKER_CUT := 0.2
static func guard_price(lvl: int) -> int: return 3000000 * lvl   # par jour
static func local_now() -> float: return Time.get_unix_time_from_system() + Time.get_time_zone_from_system().bias * 60.0
static func day_index() -> int: return int(floor(local_now() / 86400.0))
static func bandit_tier(lvl: int) -> int: return clamp(2 + lvl, 3, 5)
const FARM_TIME := 3.0 * 3600.0
const FARM_COST := 50000
const BREED_TIME := 20.0 * 3600.0

# ——— Artisanat chez Brokk : bois + minerai + fibre → armes et tenues ———
const CRAFTS := [
	{"id": "epee", "slot": "epee", "kind": "epee", "cost": {"ore": 6, "wood": 3}},
	{"id": "hache_g", "slot": "epee", "kind": "hache", "cost": {"ore": 5, "wood": 4}},
	{"id": "baton", "slot": "epee", "kind": "baton", "cost": {"wood": 6, "fiber": 3}},
	{"id": "arc", "slot": "epee", "kind": "arc", "cost": {"wood": 6, "fiber": 3}},
	{"id": "arbalete", "slot": "epee", "kind": "arbalete", "cost": {"wood": 5, "ore": 4}},
	{"id": "grimoire", "slot": "epee", "kind": "grimoire", "cost": {"fiber": 6, "wood": 3}},
	{"id": "dompteur", "slot": "epee", "kind": "dompteur", "cost": {"wood": 5, "fiber": 4}, "classe": "dompteur"},
	{"id": "bouclier", "slot": "bouclier", "kind": "", "cost": {"ore": 5, "wood": 4}},
	{"id": "heaume", "slot": "casque", "kind": "heaume", "cost": {"ore": 4, "fiber": 2}},
	{"id": "ours", "slot": "casque", "kind": "ours", "cost": {"fiber": 4, "wood": 2}},
	{"id": "chapeau", "slot": "casque", "kind": "chapeau", "cost": {"fiber": 5}},
	{"id": "plate", "slot": "armure", "kind": "plate", "cost": {"ore": 6, "fiber": 3}},
	{"id": "cuir", "slot": "armure", "kind": "cuir", "cost": {"fiber": 5, "wood": 4}},
	{"id": "tissu", "slot": "armure", "kind": "tissu", "cost": {"fiber": 8}},
	{"id": "barbare", "slot": "armure", "kind": "barbare", "cost": {"fiber": 5, "ore": 4}},
	{"id": "voleur", "slot": "armure", "kind": "voleur", "cost": {"fiber": 6, "wood": 3}},
	{"id": "cape_chevalier", "slot": "cape", "kind": "chevalier", "cost": {"fiber": 5, "ore": 2}},
	{"id": "cape_arcane", "slot": "cape", "kind": "arcane", "cost": {"fiber": 6}},
	{"id": "cape_ombre", "slot": "cape", "kind": "ombre", "cost": {"fiber": 5, "wood": 2}},
	{"id": "cape_rodeur", "slot": "cape", "kind": "rodeur", "cost": {"fiber": 4, "wood": 3}},
	{"id": "greves", "slot": "bottes", "kind": "greves", "cost": {"ore": 4, "fiber": 2}},
	{"id": "bottes_cuir", "slot": "bottes", "kind": "cuir", "cost": {"fiber": 4, "wood": 3}},
	{"id": "sandales", "slot": "bottes", "kind": "sandales", "cost": {"fiber": 5}},
]
static func craft_cost(c: Dictionary, t: int) -> Dictionary:
	var r := {}
	for k in c.cost: r[k] = [t, int(ceil(c.cost[k] * QTY[clamp(t, 1, 5)]))]
	return r
static func craft_item(c: Dictionary, t: int) -> Dictionary:
	var it := {"slot": c.slot, "tier": t}
	if c.kind != "": it["kind"] = c.kind
	return it

# ——— Enchantement (jusqu'à +5 par pièce) ———
const ENCH_MAX := 5
const ENCH_COST := [0, 0.15, 0.35, 0.7, 1.4, 2.8]   # × valeur de l'objet
const ENCH_SLOTS := ["epee", "bouclier", "casque", "armure", "cape", "bottes", "artefact"]
static func ench_cost(slot: String, t: int, next: int) -> int: return int(ITEM_BASE[clamp(t, 1, 5)] * SLOT_MULT.get(slot, 1.0) * ENCH_COST[clamp(next, 1, 5)]) + 50
func ench(slot: String) -> int: return int(S.ench.get(slot, 0)) if S.gear.get(slot, 0) > 0 else 0
static func ench_mult(e: int) -> float: return 1.0 + 0.12 * e

func bag_used() -> int:
	var n: int = S.items.size()
	for k in RES_KEYS:
		for t in range(1, MAX_TIER + 1):
			if S.inv[k][t] > 0: n += 1
	return n

# ——— Paliers : on débloque les tiers un par un (porter le T2 ouvre le T3…) ———
const UNLOCK_SLOTS := ["epee", "bouclier", "casque", "armure", "cape", "bottes"]
const SLOT_ART := {"epee": "une arme", "bouclier": "un bouclier", "casque": "un casque", "armure": "un plastron", "cape": "une cape", "bottes": "des bottes"}
const WREQ := [0, 1, 4, 10, 17, 24]       # maîtrise (arme ou armure) requise pour porter chaque tier
func unlocked(slot: String) -> int:
	if not S.has("unlock"): S["unlock"] = {}
	return max(int(S.unlock.get(slot, 1)), 1)
func unlock_note(slot: String, t: int) -> void:
	if slot in UNLOCK_SLOTS and t > unlocked(slot): S.unlock[slot] = t
# raison du blocage (vide = autorisé)
func equip_block(it: Dictionary) -> String:
	if not it.slot in UNLOCK_SLOTS: return ""
	var t := int(it.tier)
	# une seule règle, simple : le niveau de maîtrise (plus besoin d'avoir porté le tier d'avant)
	if it.slot == "epee":
		var k: String = it.get("kind", "epee")
		if int(wxp(k).lvl) < WREQ[clamp(t, 1, 5)]: return "Maîtrise %s niveau %d requise (tu es niveau %d)" % [WEAPON_KINDS[k].name.to_lower(), WREQ[t], int(wxp(k).lvl)]
	else:
		var al := int(wxp("armure").lvl)
		if al < WREQ[clamp(t, 1, 5)]: return "Maîtrise d'armure niveau %d requise (tu es niveau %d) — combats pour progresser" % [WREQ[t], al]
	return ""

func add_item(it: Dictionary) -> bool:
	if bag_used() >= bag_size(): return false
	S.items.append(it); return true

# Équipe un objet du sac : l'ancien retourne dans le sac
func equip(idx: int) -> void:
	var it: Dictionary = S.items[idx]
	S.items.remove_at(idx)
	var sl: String = it.slot
	var old := equipped_item(sl)
	S.uniq[sl] = str(it.get("nm", ""))
	S.ench[sl] = int(it.get("ench", 0))
	S.gear[sl] = int(it.tier)
	if it.has("kind"): set_kind(sl, str(it.kind))
	if sl in TOOL_SLOTS: S.toolq[sl] = int(it.get("q", 0))
	if sl in LEVEL_SLOTS: S.eqx[sl] = {"bx": it.get("bx", {}).duplicate(), "lvl": int(it.get("lvl", 0)), "xp": int(it.get("xp", 0))}
	unlock_note(sl, int(it.tier))
	if int(old.tier) > 0: S.items.append(old)
	_st.clear()

# Déséquipe : la pièce retourne dans le sac (il faut de la place)
func unequip(slot: String) -> bool:
	if S.gear.get(slot, 0) <= 0: return false
	if bag_used() >= bag_size(): return false
	S.items.append(equipped_item(slot)); S.gear[slot] = 0; S.ench[slot] = 0; S.uniq[slot] = ""; S.eqx.erase(slot)
	_st.clear()
	return true

func equipped_item(slot: String) -> Dictionary:
	var it := {"slot": slot, "tier": int(S.gear.get(slot, 0))}
	if KIND_KEY.has(slot) or slot in GK_SLOTS:
		var k := kind_of(slot)
		if k != "": it["kind"] = k
	if ench(slot) > 0: it["ench"] = ench(slot)
	if str(S.uniq.get(slot, "")) != "" and it.tier > 0: it["nm"] = S.uniq[slot]
	if slot in TOOL_SLOTS: it["q"] = toolq(slot)
	if slot in LEVEL_SLOTS and S.eqx.has(slot) and it.tier > 0:
		var x: Dictionary = S.eqx[slot]
		if not x.bx.is_empty(): it["bx"] = x.bx.duplicate()
		if int(x.lvl) > 0 or int(x.xp) > 0: it["lvl"] = int(x.lvl); it["xp"] = int(x.xp)
	return it

# Valeurs de combat
static func weapon_dmg(t: int) -> float: return 14.0 * pow(1.65, t - 1)
static func armor_hp(t: int) -> float: return 120.0 * pow(1.6, t - 1)
static func shield_hp(t: int) -> float: return 0.0 if t <= 0 else 22.0 * pow(1.6, t - 1)
static func shield_block(t: int) -> float: return 0.04 * t   # réduction des dégâts reçus
static func mob_hp(t: int) -> float: return 46.0 * pow(1.7, t - 1)
static func mob_dmg(t: int) -> float: return 11.0 * pow(1.6, t - 1)   # un peu plus fort : l'armure réduit maintenant les dégâts
const RES_PRICE := [0, 5, 12, 90, 1100, 14000]
static func res_price(t: int) -> int: return RES_PRICE[clamp(t, 1, 5)]

# ——— État sauvegardé ———
var S := {}
const SAVE_PATH := "user://valdrune_save.json"

func default_state() -> Dictionary:
	var inv := {}
	for k in RES_KEYS: inv[k] = [0, 0, 0, 0, 0, 0]
	return {"v": 2, "silver": 60, "potions": 3, "inv": inv,
		"gear": {"hache": 1, "pioche": 1, "faucille": 1, "epee": 1, "armure": 1, "bottes": 1, "bouclier": 1, "artefact": 0, "monture": 0, "casque": 0, "cape": 0},
		"stats": {"kills": 0, "gathered": 0, "boss": 0}, "tips": {}, "disc": {}, "chests": {}, "met": {},
		"armor_kind": "plate", "weapon_kind": "epee", "artefact_kind": "", "mercs": [], "duels": {}, "prof": {}, "wxp": {}, "toolq": {}, "island": new_island(), "uniq": {}, "bag_bonus": 0, "mount_kind": "", "ench": {}, "tower": {"best": 0}, "items": [], "ah": {"stock": [], "stock_at": 0, "listings": []}, "unlock": {}, "map": 1, "gk": {"bottes": "greves"}, "eqx": {}, "food": {}, "guild": {}, "friends": [], "duel_wins": 0}

func _ready() -> void:
	_journal_start()
	S = default_state()
	var d := load_saved_state()
	if not d.is_empty():
		for k in d: S[k] = d[k]
		if not d.has("rep"): S["rep_old"] = true
		# JSON → entiers
		for k in RES_KEYS:
			var arr: Array = S.inv.get(k, [0, 0, 0, 0, 0, 0])
			for i in arr.size(): arr[i] = int(arr[i])
			S.inv[k] = arr
		for k in S.gear: S.gear[k] = int(S.gear[k])
		if not S.gear.has("bottes"): S.gear["bottes"] = 1
		if not S.gear.has("bouclier"): S.gear["bouclier"] = 1
		if not S.gear.has("artefact"): S.gear["artefact"] = 0
		if typeof(S.get("mercs")) != TYPE_ARRAY: S["mercs"] = []
		if typeof(S.get("duels")) != TYPE_DICTIONARY: S["duels"] = {}
		if not S.gear.has("monture"): S.gear["monture"] = 0
		if not S.has("mount_kind"): S["mount_kind"] = ""
		for key2 in ["prof", "ench", "wxp", "uniq", "toolq"]:
			if typeof(S.get(key2)) != TYPE_DICTIONARY: S[key2] = {}
		if typeof(S.get("tower")) != TYPE_DICTIONARY: S["tower"] = {"best": 0}
		if typeof(S.get("island")) != TYPE_DICTIONARY: S["island"] = new_island()
		for k3 in new_island():
			if not S.island.has(k3): S.island[k3] = new_island()[k3]
		for k2 in S.ench: S.ench[k2] = int(S.ench[k2])
		if not S.has("artefact_kind"): S["artefact_kind"] = ""
		if not WEAPON_KINDS.has(S.get("weapon_kind", "")): S["weapon_kind"] = "epee"
		for key in ["disc", "chests", "met", "tips"]:
			if typeof(S.get(key)) != TYPE_DICTIONARY: S[key] = {}
		if typeof(S.get("items")) != TYPE_ARRAY: S["items"] = []
		if typeof(S.get("ah")) != TYPE_DICTIONARY: S["ah"] = {"stock": [], "stock_at": 0, "listings": []}
		if not S.has("armor_kind"): S["armor_kind"] = "plate"
		for it in S.items:
			it.tier = int(it.tier)
			if it.has("q"): it.q = int(it.q)
			if it.has("ench"): it.ench = int(it.ench)
		S.silver = int(S.silver); S.potions = int(S.potions)
		if typeof(S.get("unlock")) != TYPE_DICTIONARY:
			S["unlock"] = {}
			for sl in ["epee", "bouclier", "armure", "bottes"]: S.unlock[sl] = max(1, int(S.gear.get(sl, 1)))
		for sl in S.unlock: S.unlock[sl] = int(S.unlock[sl])
		S["map"] = clamp(int(S.get("map", 1)), 1, 4)
		if typeof(S.get("gk")) != TYPE_DICTIONARY: S["gk"] = {"bottes": {"plate": "greves", "cuir": "cuir", "tissu": "sandales"}.get(S.get("armor_kind", "plate"), "greves")}
		if typeof(S.get("eqx")) != TYPE_DICTIONARY: S["eqx"] = {}
		for key3 in ["food", "guild"]:
			if typeof(S.get(key3)) != TYPE_DICTIONARY: S[key3] = {}
		for k4 in S.food: S.food[k4] = int(S.food[k4])
		if typeof(S.get("friends")) != TYPE_ARRAY: S["friends"] = []
		for sl in ["casque", "cape"]:
			if not S.gear.has(sl): S.gear[sl] = 0
		if not ARMOR_KINDS.has(S.get("armor_kind", "plate")): S["armor_kind"] = "plate"
	_init_sfx()

# Sauvegarde différée : écrire le JSON sur disque à chaque action faisait
# geler l'image sur téléphone. On marque « à sauver » et on écrit au plus
# toutes les 12 s, ou immédiatement quand l'appli passe en arrière-plan.
var _dirty := false
var _save_t := 0.0
func save() -> void:
	_dirty = true

var save_recovered := false

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK: return {}
	var data = json.data
	return data if data is Dictionary and data.get("v", 0) == 2 else {}

func _save_int(value, fallback: int) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]: return int(value)
	if value is String and value.is_valid_int(): return int(value)
	return fallback

func _merge_save_defaults(base: Dictionary, data: Dictionary) -> Dictionary:
	var out := base.duplicate(true)
	for key in data:
		var value = data[key]
		if not base.has(key): out[key] = value; continue
		var fallback = base[key]
		if fallback is Dictionary:
			if value is Dictionary: out[key] = _merge_save_defaults(fallback, value)
		elif fallback is Array:
			if value is Array: out[key] = value.duplicate(true)
		elif typeof(fallback) == TYPE_INT: out[key] = _save_int(value, int(fallback))
		elif typeof(value) == typeof(fallback): out[key] = value
	return out

func normalize_saved_state(data: Dictionary) -> Dictionary:
	var out := _merge_save_defaults(default_state(), data)
	for key in RES_KEYS:
		var raw: Array = out.inv[key]
		var counts: Array = []
		for i in 6: counts.append(max(0, _save_int(raw[i], 0)) if i < raw.size() else 0)
		out.inv[key] = counts
	for key in out.gear: out.gear[key] = clampi(_save_int(out.gear[key], 0), 0, 5)
	var items: Array = []
	for item in out.items:
		if not item is Dictionary or not out.gear.has(str(item.get("slot", ""))): continue
		var fixed: Dictionary = item.duplicate(true)
		fixed.tier = clampi(_save_int(item.get("tier", 1), 1), 1, 5)
		items.append(fixed)
	out.items = items
	for key in ["build", "decor_v", "vq", "rep"]:
		if out.has(key) and not out[key] is Dictionary: out[key] = {}
	return out

func load_saved_state(path := SAVE_PATH) -> Dictionary:
	save_recovered = false
	var data := _read_save(path)
	if data.is_empty():
		# The pending file may contain the newest complete write interrupted before rename.
		for candidate in [path + ".tmp", path + ".bak"]:
			data = _read_save(candidate)
			if not data.is_empty(): save_recovered = true; crumb("sauvegarde de secours récupérée"); break
	return normalize_saved_state(data) if not data.is_empty() else {}

func write_saved_state(path: String, data: Dictionary) -> bool:
	var pending := path + ".tmp"
	var text := JSON.stringify(data)
	var f := FileAccess.open(pending, FileAccess.WRITE)
	if f == null: return false
	f.store_string(text); f.flush()
	var err := f.get_error(); f.close()
	if err != OK or _read_save(pending).is_empty(): return false
	# Keep the last valid main file without overwriting a good backup with a damaged file.
	if not _read_save(path).is_empty():
		var backup := path + ".bak.tmp"
		if DirAccess.copy_absolute(path, backup) != OK: return false
		if DirAccess.rename_absolute(backup, path + ".bak") != OK: return false
	return DirAccess.rename_absolute(pending, path) == OK

func save_now() -> void:
	_save_t = 0.0
	_dirty = not write_saved_state(SAVE_PATH, S)
	if _dirty: crumb("sauvegarde différée : écriture indisponible")

var _crumb_t := 0.0
var fps_acc := 0.0
var fps_n := 0
var fps_min := 999.0
func _process(dt: float) -> void:
	if _dirty:
		_save_t += dt
		if _save_t > 12.0: save_now()
	# mesure des performances (pour le rapport)
	var f := Engine.get_frames_per_second()
	fps_acc += f; fps_n += 1
	if fps_n > 120: fps_min = min(fps_min, f)
	_crumb_t += dt
	if _crumb_t > 10.0: _crumb_t = 0.0; _write_crumbs()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var mn = get_tree().current_scene if is_inside_tree() else null
		if mn and mn.get("net") and mn.net.online: mn.net.push_save()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PREDELETE:
		if _dirty: save_now()
		crumb("(application en pause / fermée)"); _write_crumbs()
		if what not in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_GO_BACK_REQUEST]: DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG_PATH))
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_flag()

# ================= JOURNAL DE BORD (pour retrouver ce qui a fait planter le jeu) =================
const FLAG_PATH := "user://en_cours.flag"
const CRUMB_PATH := "user://journal.txt"
const VERSION := "9.7"
var crumbs: Array = []
var crashed_last := false
var last_crumbs := ""
func crumb(t: String) -> void:
	var tm := Time.get_time_dict_from_system()
	crumbs.append("%02d:%02d:%02d %s" % [tm.hour, tm.minute, tm.second, t])
	if crumbs.size() > 40: crumbs.pop_front()
func _write_crumbs() -> void:
	var f := FileAccess.open(CRUMB_PATH, FileAccess.WRITE)
	if f: f.store_string("\n".join(crumbs) + "\nFPS moyen %d · min %d · mémoire %d Mo" % [int(fps_acc / max(1, fps_n)), int(fps_min if fps_min < 999 else 0), int(OS.get_static_memory_usage() / 1048576)])
func _set_flag() -> void:
	var f := FileAccess.open(FLAG_PATH, FileAccess.WRITE)
	if f: f.store_string(str(Time.get_unix_time_from_system()))
func _journal_start() -> void:
	crashed_last = FileAccess.file_exists(FLAG_PATH) and not OS.has_feature("editor")
	if FileAccess.file_exists(CRUMB_PATH):
		var f := FileAccess.open(CRUMB_PATH, FileAccess.READ)
		if f: last_crumbs = f.get_as_text()
	_set_flag(); crumb("démarrage v%s" % VERSION)
# erreurs du moteur relevées dans les journaux (session actuelle et précédente)
func engine_errors(max_lines := 30) -> String:
	var out: Array = []
	var d := DirAccess.open("user://logs")
	if d == null: return "(journal moteur indisponible)"
	var files: Array = []
	for fn in d.get_files():
		if fn.ends_with(".log"): files.append(fn)
	files.sort()
	for fn in files.slice(max(0, files.size() - 2)):
		var f := FileAccess.open("user://logs/" + fn, FileAccess.READ)
		if f == null: continue
		var lines := f.get_as_text().split("\n")
		for i in lines.size():
			var l: String = lines[i]
			if "SCRIPT ERROR" in l or "ERROR:" in l:
				var full: String = l.strip_edges() + ((" | " + lines[i + 1].strip_edges()) if i + 1 < lines.size() else "")
				var low := full.to_lower()
				if "alsa" in low or "audio" in low or "v-sync" in low or "tests/plan" in low or "pagedallocator" in low: continue
				out.append(full)
	if out.is_empty(): return "(aucune erreur enregistrée)"
	return "\n".join(out.slice(max(0, out.size() - max_lines)))
func bug_report() -> String:
	var t := "VALDRUNE v%s — rapport\nAppareil : %s · %s · écran %s\nGraphismes : %s · carte %d · PI %d\n" % [VERSION, OS.get_model_name(), OS.get_name(), str(DisplayServer.screen_get_size()), ["rapide", "équilibré", "beau"][gfx()], int(S.get("map", 1)), power()]
	t += "FPS moyen %d · min %d · mémoire %d Mo\n" % [int(fps_acc / max(1, fps_n)), int(fps_min if fps_min < 999 else 0), int(OS.get_static_memory_usage() / 1048576)]
	if crashed_last: t += "\n== Dernière partie (fermée brutalement) ==\n" + last_crumbs + "\n"
	t += "\n== Cette partie ==\n" + "\n".join(crumbs) + "\n\n== Erreurs ==\n" + engine_errors()
	return t
# qualité graphique : 0 rapide, 1 équilibré, 2 beau
func gfx() -> int: return clamp(int(S.get("gfx", 1)), 0, 2)

func reset_save() -> void:
	S = default_state(); save_now()

func has_cost(cost: Dictionary) -> bool:
	for k in cost:
		if S.inv[k][cost[k][0]] < cost[k][1]: return false
	return true

func pay(cost: Dictionary) -> void:
	for k in cost: S.inv[k][cost[k][0]] -= cost[k][1]

# Niveau de progression : plus petit tier d'équipement possédé
func gear_level() -> int:
	var m := 99
	for k in TOOL_SLOTS: m = min(m, S.gear[k])
	return m

# ——— Sons générés (aucun fichier audio nécessaire) ———
var sfx := {}
var players: Array[AudioStreamPlayer] = []
const RATE := 22050

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray(); data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clamp(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	return w

func _gen(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE); var s := PackedFloat32Array(); s.resize(n)
	var st := {"lp": 0.0, "ph": 0.0, "ph2": 0.0}
	for i in n: s[i] = f.call(float(i) / RATE, float(i) / n, st)
	return _wav(s)

func _init_sfx() -> void:
	# coup d'épée qui touche : choc sourd + craquement
	sfx.hit = _gen(0.22, func(t, k, st):
		st.ph += TAU * (120.0 - 70.0 * k) / RATE
		var n := randf_range(-1, 1); st.lp += (n - st.lp) * 0.35
		return (sin(st.ph) * 0.9 * exp(-k * 7.0) + st.lp * 0.8 * exp(-k * 12.0)))
	# moulinet dans le vide
	sfx.swing = _gen(0.18, func(t, k, st):
		var n := randf_range(-1, 1); st.lp += (n - st.lp) * (0.05 + 0.5 * k)
		return st.lp * sin(PI * k) * 0.9)
	sfx.chop = _gen(0.16, func(t, k, st):
		st.ph += TAU * 420.0 / RATE
		var n := randf_range(-1, 1); st.lp += (n - st.lp) * 0.5
		return (st.lp * 0.7 + sin(st.ph) * 0.4) * exp(-k * 9.0))
	sfx.mine = _gen(0.35, func(t, k, st):
		st.ph += TAU * 1250.0 / RATE; st.ph2 += TAU * 1870.0 / RATE
		var n := randf_range(-1, 1) * exp(-k * 30.0)
		return (sin(st.ph) * 0.5 + sin(st.ph2) * 0.3) * exp(-k * 6.0) + n * 0.5)
	sfx.cut = _gen(0.2, func(t, k, st):
		var n := randf_range(-1, 1); st.lp += (n - st.lp) * 0.7
		return st.lp * exp(-k * 8.0) * 0.6)
	sfx.coin = _gen(0.3, func(t, k, st):
		var fr := 1320.0 if k < 0.35 else 1760.0
		st.ph += TAU * fr / RATE
		return sin(st.ph) * 0.45 * exp(-fmod(k, 0.35) * 8.0))
	sfx.pickup = _gen(0.18, func(t, k, st):
		st.ph += TAU * (600.0 + 900.0 * k) / RATE
		return sin(st.ph) * 0.35 * (1.0 - k))
	sfx.craft = _gen(0.7, func(t, k, st):
		st.ph += TAU * 880.0 / RATE; st.ph2 += TAU * 1320.0 / RATE
		return (sin(st.ph) * 0.4 + sin(st.ph2) * 0.25) * exp(-k * 5.0))
	sfx.hurt = _gen(0.25, func(t, k, st):
		st.ph += TAU * (220.0 - 120.0 * k) / RATE
		var n := randf_range(-1, 1)
		return (sign(sin(st.ph)) * 0.25 + n * 0.2) * exp(-k * 6.0))
	sfx.level = _gen(0.9, func(t, k, st):
		var notes := [523.0, 659.0, 784.0, 1046.0]
		var i := int(min(3, k * 5.0)); st.ph += TAU * notes[i] / RATE
		return sin(st.ph) * 0.35 * (1.0 - k * 0.8))
	sfx.death = _gen(0.5, func(t, k, st):
		var n := randf_range(-1, 1); st.lp += (n - st.lp) * 0.2
		st.ph += TAU * (300.0 - 200.0 * k) / RATE
		return (st.lp * 0.8 + sin(st.ph) * 0.3) * exp(-k * 4.0) * (0.5 + 0.5 * sin(t * 90.0)))
	sfx.dodge = _gen(0.22, func(t, k, st):
		var n := randf_range(-1, 1); st.lp += (n - st.lp) * 0.12
		return st.lp * sin(PI * k) * 1.2)
	sfx.error = _gen(0.18, func(t, k, st):
		st.ph += TAU * 160.0 / RATE
		return sign(sin(st.ph)) * 0.18 * (1.0 - k))
	sfx.roar = _gen(1.0, func(t, k, st):
		var n := randf_range(-1, 1); st.lp += (n - st.lp) * 0.08
		st.ph += TAU * (90.0 + 30.0 * sin(t * 13.0)) / RATE
		return (st.lp * 1.4 + sin(st.ph) * 0.5) * sin(PI * k))
	for i in 8:
		var p := AudioStreamPlayer.new(); p.bus = "Master"; add_child(p); players.append(p)
	_music()

var _pi := 0
func play(name: String, vol := 0.0, pitch := 1.0) -> void:
	if not sfx.has(name): return
	var p := players[_pi]; _pi = (_pi + 1) % players.size()
	p.stream = sfx[name]; p.volume_db = vol; p.pitch_scale = pitch * randf_range(0.94, 1.06); p.play()

# Son spatialisé « à la main » : plus c'est loin, plus c'est doux ; au-delà de 24 m on n'entend rien.
# Les combats des autres joueurs sont nettement plus discrets que les tiens.
var listener := Vector3.ZERO
var icon_cache := {}
var traveling := false    # vrai pendant un changement de carte (pas d'écran titre)      # miniatures générées (survivent aux changements de carte)
func play_at(name: String, pos: Vector3, vol := 0.0, pitch := 1.0, mine := true) -> void:
	var d := pos.distance_to(listener)
	if d > 24.0: return
	var v := vol - d * 0.45 - (0.0 if mine else 11.0)
	if v < -34.0: return
	play(name, v, pitch * (1.0 if mine else 1.15))

# Musique d'ambiance douce générée (boucle de 16 s)
var music: AudioStreamPlayer
func _music() -> void:
	var dur := 16.0; var n := int(dur * RATE); var s := PackedFloat32Array(); s.resize(n)
	var chords := [[220.0, 277.2, 329.6], [196.0, 246.9, 293.7], [174.6, 220.0, 261.6], [196.0, 246.9, 329.6]]
	var mel := [659.3, 587.3, 523.3, 587.3, 659.3, 784.0, 659.3, 587.3, 523.3, 493.9, 440.0, 493.9, 523.3, 587.3, 523.3, 440.0]
	for i in n:
		var t := float(i) / RATE; var c: Array = chords[int(t / 4.0) % 4]
		var v := 0.0
		for f in c: v += sin(TAU * f * t) * 0.05 + sin(TAU * f * 0.5 * t) * 0.03
		var bt := fmod(t, 1.0); var m: float = mel[int(t) % 16]
		v += sin(TAU * m * t) * 0.06 * exp(-bt * 3.0) * (1.0 if int(t) % 2 == 0 or bt < 0.5 else 0.6)
		var ct := fmod(t, 4.0); v *= 0.75 + 0.25 * min(1.0, ct * 2.0)
		s[i] = v
	var w := _wav(s); w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
	music = AudioStreamPlayer.new(); music.stream = w; music.volume_db = -9.0; add_child(music); music.play()
