class_name Progression
## Progression du seigneur : niveau, expérience, caractéristiques, or, potions — sauvegardée sur le téléphone.

signal changed
signal leveled_up(level: int)

const SAVE := "user://seigneur.json"

static var inst: Progression

var level := 1
var xp := 0
var gold := 0
var potions_soin := 2
var potions_mana := 1
var force := 5
var intel := 5
var vitalite := 5
var _dirty := false

static func get_inst() -> Progression:
	if inst == null:
		inst = Progression.new()
		inst.load_game()
	return inst

func xp_to_next() -> int:
	return int(60.0 * pow(level, 1.55))

func max_hp() -> float:
	return 70.0 + vitalite * 8.0 + level * 6.0

func max_mana() -> float:
	return 40.0 + intel * 6.0

func mana_regen() -> float:
	return 2.5 + intel * 0.12

func melee_damage() -> float:
	return 8.0 + force * 1.6

func spell_power() -> float:
	return intel * 1.0

func add_xp(n: int) -> void:
	xp += n
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		force += 2
		intel += 2
		vitalite += 2
		leveled_up.emit(level)
	_dirty = true
	changed.emit()

func add_gold(n: int) -> void:
	gold = maxi(0, gold + n)
	_dirty = true
	changed.emit()

func add_potion(kind: String, n := 1) -> void:
	if kind == "mana":
		potions_mana += n
	else:
		potions_soin += n
	_dirty = true
	changed.emit()

func save_if_dirty() -> void:
	if not _dirty:
		return
	_dirty = false
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"level": level, "xp": xp, "gold": gold, "ps": potions_soin, "pm": potions_mana,
		"force": force, "intel": intel, "vit": vitalite}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	gold = int(d.get("gold", 0))
	potions_soin = int(d.get("ps", 2))
	potions_mana = int(d.get("pm", 1))
	force = int(d.get("force", 5))
	intel = int(d.get("intel", 5))
	vitalite = int(d.get("vit", 5))

func reset() -> void:
	level = 1; xp = 0; gold = 0; potions_soin = 2; potions_mana = 1; force = 5; intel = 5; vitalite = 5
	_dirty = true
	changed.emit()
