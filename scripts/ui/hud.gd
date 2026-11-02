class_name Hud
extends Control
## Interface de combat : vie / mana / expérience, or, cible, messages, et la grappe de boutons d'action.

var player: Player
var pc: PlayerCombat
var prog: Progression
var btn_attack: ActionButton
var btn_dodge: ActionButton
var btn_spells := {}
var btn_potion_soin: ActionButton
var btn_potion_mana: ActionButton
var _msg: Label
var _msg_t := 0.0
var _target_name := ""
var _sig := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog = Progression.get_inst()
	btn_attack = ActionButton.new().setup("epee", 78.0, Color(1.0, 0.85, 0.45))
	btn_dodge = ActionButton.new().setup("esquive", 44.0, Color(0.85, 0.85, 0.85))
	for id in SpellDB.ORDER:
		var d: Dictionary = SpellDB.DEFS[id]
		btn_spells[id] = ActionButton.new().setup(d["icone"], 46.0, d["couleur"])
	btn_potion_soin = ActionButton.new().setup("potion_soin", 32.0, Color(1, 0.45, 0.45))
	btn_potion_mana = ActionButton.new().setup("potion_mana", 32.0, Color(0.45, 0.65, 1))
	for b in [btn_attack, btn_dodge, btn_potion_soin, btn_potion_mana] + btn_spells.values():
		add_child(b)
	_msg = Label.new()
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.add_theme_font_size_override("font_size", 34)
	_msg.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_msg.add_theme_constant_override("outline_size", 10)
	_msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_msg)
	btn_attack.pressed.connect(func(): pc.attack())
	btn_dodge.pressed.connect(func(): pc.dodge())
	for id in btn_spells:
		var sid: String = id
		btn_spells[id].pressed.connect(func(): pc.cast(sid))
	btn_potion_soin.pressed.connect(func(): pc.drink("soin"))
	btn_potion_mana.pressed.connect(func(): pc.drink("mana"))

func bind(p: Player) -> void:
	player = p
	pc = p.combat
	pc.message.connect(show_message)

func buttons() -> Array:
	return [btn_attack, btn_dodge, btn_potion_soin, btn_potion_mana] + btn_spells.values()

func show_message(t: String, col: Color) -> void:
	_msg.text = t
	_msg.add_theme_color_override("font_color", col)
	_msg_t = 3.0

func _layout() -> void:
	var s := get_viewport_rect().size
	var ac := Vector2(s.x - 150, s.y - 150)
	btn_attack.position = ac - btn_attack.size * 0.5
	btn_dodge.position = ac + Vector2(-165, 82) - btn_dodge.size * 0.5
	var i := 0
	for id in SpellDB.ORDER:
		var a := deg_to_rad(-172.0 + i * 31.0)
		var p := ac + Vector2(cos(a), sin(a)) * 162.0
		btn_spells[id].position = p - btn_spells[id].size * 0.5
		i += 1
	btn_potion_soin.position = Vector2(s.x - 60, 120) - btn_potion_soin.size * 0.5
	btn_potion_mana.position = Vector2(s.x - 60, 196) - btn_potion_mana.size * 0.5
	_msg.position = Vector2(s.x * 0.5 - 400, s.y * 0.2)
	_msg.size = Vector2(800, 120)

func _process(delta: float) -> void:
	if pc == null:
		return
	_layout()
	for id in btn_spells:
		var b: ActionButton = btn_spells[id]
		var d: Dictionary = SpellDB.DEFS[id]
		var left := pc.cooldown_left(id)
		b.cooldown = left / float(d["recharge"])
		b.cd_text = ("%.0f" % ceilf(left)) if left > 1.0 else ""
		b.locked_text = "" if pc.spell_unlocked(id) else "Niv %d" % d["niveau"]
		b.dim = pc.mana < float(d["mana"]) and b.locked_text == ""
		b.refresh()
	btn_potion_soin.count = prog.potions_soin
	btn_potion_mana.count = prog.potions_mana
	for b in [btn_potion_soin, btn_potion_mana, btn_attack, btn_dodge]:
		b.refresh()
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t, 0.0, 1.0)
	var t := pc.target
	var sig := "%d|%d|%d|%d|%d|%d|%s|%d" % [player.cbt.hp, pc.mana, prog.xp, prog.gold, prog.level, int(player.cbt.shield), t.get_instance_id() if t and Combat.alive(t) else 0, int(t.cbt.hp) if t and Combat.alive(t) else 0]
	if sig != _sig:
		_sig = sig
		queue_redraw()

func _bar(p: Vector2, w: float, h: float, frac: float, col: Color, txt: String) -> void:
	draw_rect(Rect2(p - Vector2(2, 2), Vector2(w + 4, h + 4)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(p, Vector2(w, h)), Color(0.12, 0.12, 0.14, 0.9))
	draw_rect(Rect2(p, Vector2(w * clampf(frac, 0, 1), h)), col)
	draw_rect(Rect2(p, Vector2(w * clampf(frac, 0, 1), h * 0.4)), Color(1, 1, 1, 0.15))
	if txt != "":
		var f := get_theme_default_font()
		var fs := int(h * 0.8)
		draw_string_outline(f, p + Vector2(8, h * 0.82), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.9))
		draw_string(f, p + Vector2(8, h * 0.82), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

func _draw() -> void:
	if pc == null:
		return
	var f := get_theme_default_font()
	var base := Vector2(22, 44)
	# médaillon de niveau
	draw_circle(base + Vector2(34, 34), 36, Color(0.1, 0.09, 0.12, 0.85))
	draw_arc(base + Vector2(34, 34), 36, 0, TAU, 40, Color(1, 0.82, 0.4), 3.0)
	var lv := str(prog.level)
	var w := f.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	draw_string(f, base + Vector2(34 - w * 0.5, 46), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 0.9, 0.6))
	var cbt := player.cbt
	_bar(base + Vector2(80, 6), 300, 24, cbt.hp / cbt.max_hp, Color(0.85, 0.2, 0.2), "%d / %d" % [cbt.hp, cbt.max_hp])
	if cbt.has_shield():
		draw_rect(Rect2(base + Vector2(80, 6), Vector2(300 * clampf(cbt.shield / cbt.max_hp, 0, 1), 6)), Color(0.5, 0.9, 1.0))
	_bar(base + Vector2(80, 36), 240, 18, pc.mana / prog.max_mana(), Color(0.25, 0.45, 0.95), "%d / %d" % [pc.mana, prog.max_mana()])
	_bar(base + Vector2(80, 60), 240, 8, float(prog.xp) / prog.xp_to_next(), Color(1.0, 0.8, 0.3), "")
	# or
	var gp := base + Vector2(344, 50)
	draw_circle(gp, 11, Color(1, 0.8, 0.25))
	draw_circle(gp, 7, Color(0.9, 0.65, 0.15))
	draw_string_outline(f, gp + Vector2(18, 9), str(prog.gold), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 4, Color(0, 0, 0, 0.9))
	draw_string(f, gp + Vector2(18, 9), str(prog.gold), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.9, 0.55))
	# cible
	var t := pc.target
	if t and Combat.alive(t):
		var s := get_viewport_rect().size
		var tw := 340.0
		var tp := Vector2(s.x * 0.5 - tw * 0.5, 26)
		var name: String = t.def["nom"]
		var nw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		draw_string_outline(f, tp + Vector2(tw * 0.5 - nw * 0.5, 0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 5, Color(0, 0, 0, 0.9))
		draw_string(f, tp + Vector2(tw * 0.5 - nw * 0.5, 0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.75, 0.6) if not t.def.get("elite", false) else Color(1, 0.6, 0.2))
		_bar(tp + Vector2(0, 8), tw, 16, t.cbt.hp / t.cbt.max_hp, Color(0.8, 0.25, 0.2), "")
		var st := ""
		if t.cbt.is_rooted():
			st = "immobilisé"
		elif t.cbt.speed_mult() < 1.0:
			st = "ralenti"
		if st != "":
			draw_string(f, tp + Vector2(tw + 10, 22), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.95, 1))
