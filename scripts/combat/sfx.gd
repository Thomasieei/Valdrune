class_name Sfx
## Sons du jeu (Kenney, CC0) joués via un petit groupe de lecteurs réutilisés (aucune création en combat).

static var _players: Array = []
static var _i := 0
static var _streams := {}

const BANK := {
	"coup": ["knifeSlice", "knifeSlice2"],
	"touche": ["impactPunch_medium_000", "impactPunch_medium_001"],
	"lourd": ["impactSoft_heavy_000"],
	"bouclier": ["impactBell_heavy_000"],
	"givre": ["impactGlass_medium_000", "glass_002"],
	"feu": ["maximize_006"],
	"racines": ["chop"],
	"or": ["handleCoins", "handleCoins2"],
	"potion": ["drop_002"],
	"esquive": ["cloth1"],
	"degaine": ["drawKnife1"],
	"bloque": ["impactMetal_light_000"],
	"erreur": ["error_004"],
	"niveau": ["jingles_PIZZI01"],
	"mort": ["jingles_PIZZI04"],
	"ok": ["confirmation_001"],
}

static func setup(parent: Node) -> void:
	_players.clear()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		parent.add_child(p)
		_players.append(p)

static func play(name: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	if _players.is_empty() or not BANK.has(name):
		return
	var list: Array = BANK[name]
	var file: String = list[randi() % list.size()]
	if not _streams.has(file):
		_streams[file] = load("res://assets/sons/%s.ogg" % file)
	var p: AudioStreamPlayer = _players[_i]
	_i = (_i + 1) % _players.size()
	p.stream = _streams[file]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
