class_name GameState
extends RefCounted
## État persistant de la partie (hors stats de combat, gérées par Progression) :
## étape de l'histoire, valeurs de personnalité/réputation, mémoire des PNJ, factions,
## compagnons, missions, royaume, rapports. Sauvegardé dans user://royaume_etat.json.

signal changed

const SAVE := "user://royaume_etat.json"
const VERSION := 1

static var inst: GameState

var story := "debut"          # étape de l'histoire
var flags := {}               # drapeaux narratifs
var values := {               # personnalité et réputation du joueur (−100..100 environ)
	"bienveillance": 0, "arrogance": 0, "autorite": 0, "mefiance": 0,
	"reputation": 0, "confiance_habitants": 0, "crainte": 0,
}
var titre := "Étranger"
var npc := {}                 # id -> {"vu": n, "sujets": [..], "relation": int, "promesses": [..]}
var factions := {
	"couronne": 10, "gobelins": -30, "nains": 0, "vargas": -80, "marchands": 5,
}
var companions := {}          # id -> données (voir Companion)
var missions: Array = []      # missions en cours / terminées
var kingdom := {}             # état du royaume (voir Kingdom)
var reports: Array = []       # rapports (texte, date)
var events_seen := {}         # événements déjà proposés
var last_saved_unix := 0.0
var _dirty := false

static func get_inst() -> GameState:
	if inst == null:
		inst = GameState.new()
		inst.load_game()
	return inst

# ------------------------------------------------------------ valeurs
func val(k: String) -> int:
	if values.has(k):
		return int(values[k])
	if k.begins_with("faction_"):
		return int(factions.get(k.substr(8), 0))
	if k.begins_with("loyaute_"):
		var c: Dictionary = companions.get(k.substr(8), {})
		return int(c.get("loyaute", 0))
	return 0

func add(k: String, d: int) -> void:
	if values.has(k):
		values[k] = clampi(int(values[k]) + d, -100, 100)
	elif k.begins_with("faction_"):
		var f := k.substr(8)
		factions[f] = clampi(int(factions.get(f, 0)) + d, -100, 100)
	elif k.begins_with("loyaute_") or k.begins_with("relation_"):
		var cid := k.get_slice("_", 1)
		if companions.has(cid):
			var key := "loyaute" if k.begins_with("loyaute_") else "relation"
			companions[cid][key] = clampi(int(companions[cid].get(key, 0)) + d, -100, 100)
		else:
			flags["pre_" + k] = int(flags.get("pre_" + k, 0)) + d
	mark()

func flag(f: String) -> bool:
	return bool(flags.get(f, false))

func set_flag(f: String, v = true) -> void:
	flags[f] = v
	mark()

## Trait dominant du joueur (pour adapter les dialogues)
func dominant() -> String:
	var best := "neutre"
	var bv := 3
	for k in ["bienveillance", "arrogance", "autorite", "mefiance"]:
		if int(values[k]) > bv:
			bv = int(values[k])
			best = k
	return best

# ------------------------------------------------------------ mémoire PNJ
func mem(id: String) -> Dictionary:
	if not npc.has(id):
		npc[id] = {"vu": 0, "sujets": [], "relation": 0}
	return npc[id]

func report(text: String, kind := "info") -> void:
	var n := int(flags.get("_seq", 0)) + 1
	flags["_seq"] = n
	reports.push_front({"t": text, "k": kind, "jour": int(kingdom.get("jour", 1)), "n": n})
	if reports.size() > 40:
		reports.resize(40)
	mark()

# ------------------------------------------------------------ sauvegarde
func mark() -> void:
	_dirty = true
	changed.emit()

func save_if_dirty() -> void:
	if _dirty:
		save_game()

func save_game() -> void:
	_dirty = false
	last_saved_unix = Time.get_unix_time_from_system()
	var data := {"v": VERSION, "story": story, "flags": flags, "values": values, "titre": titre, "npc": npc,
		"factions": factions, "companions": companions, "missions": missions, "kingdom": kingdom,
		"reports": reports, "events_seen": events_seen, "t": last_saved_unix}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	story = d.get("story", "debut")
	flags = d.get("flags", {})
	for k in d.get("values", {}):
		values[k] = int(d["values"][k])
	titre = d.get("titre", "Étranger")
	npc = d.get("npc", {})
	for k in d.get("factions", {}):
		factions[k] = int(d["factions"][k])
	companions = d.get("companions", {})
	missions = d.get("missions", [])
	kingdom = d.get("kingdom", {})
	reports = d.get("reports", [])
	events_seen = d.get("events_seen", {})
	last_saved_unix = float(d.get("t", 0.0))

func reset() -> void:
	story = "debut"
	flags = {}
	for k in values:
		values[k] = 0
	titre = "Étranger"
	npc = {}
	factions = {"couronne": 10, "gobelins": -30, "nains": 0, "vargas": -80, "marchands": 5}
	companions = {}
	missions = []
	kingdom = {}
	reports = []
	events_seen = {}
	mark()
