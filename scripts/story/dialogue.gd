class_name Dialogue
extends Control
## Dialogue narratif tour par tour : le personnage parle, des réponses apparaissent, le joueur choisit,
## le personnage réagit. Les conversations viennent de data/dialogues.json (écrites à l'avance)
## ou sont construites à la volée (PNJ, conseil du royaume) avec le même format.
##
## Format d'un nœud : {who, text, text_if:[{cond,text}], fx:{...}, action, next | choices:[{text, tone, cond, fx, next}]}
## Conditions : "arrogance>=3", "flag:x", "!flag:x", "or>=50", "relation_elian<=-5", "niveau>=2"
## Effets : valeurs de personnalité, relation_<pnj>, loyaute_<compagnon>, faction_<f>, or, xp, flag, titre, promesse_<pnj>

signal finished(last_action: String)
signal action(name: String)

static var inst: Dialogue
static var active := false
static var _data := {}

const SPEAKERS := {
	"elian": ["Elian", Color(0.55, 0.85, 1.0)],
	"roi": ["Aldric III, roi de Valmont", Color(1.0, 0.82, 0.4)],
	"garde": ["Garric, garde de la porte", Color(0.75, 0.8, 0.95)],
	"colosse": ["Brokk le Colosse", Color(1.0, 0.45, 0.35)],
	"conseil": ["Conseil royal", Color(0.9, 0.85, 0.7)],
}
const TONES := {
	"bienveillance": ["Bienveillant", Color(0.5, 0.9, 0.55)], "arrogance": ["Arrogant", Color(1.0, 0.55, 0.35)],
	"mefiance": ["Méfiant", Color(0.75, 0.7, 1.0)], "autorite": ["Autoritaire", Color(1.0, 0.8, 0.35)],
	"indifference": ["Indifférent", Color(0.7, 0.7, 0.7)], "respect": ["Respectueux", Color(0.6, 0.85, 1.0)],
	"diplomatie": ["Diplomate", Color(0.55, 0.85, 0.9)], "provocation": ["Provocateur", Color(1.0, 0.45, 0.5)],
	"negociation": ["Négociation", Color(1.0, 0.9, 0.5)],
}

var _convo: Dictionary
var _node_id := ""
var _shown := 0.0
var _full := ""
var _last_action := ""
var _panel: Panel
var _name: Label
var _text: RichTextLabel
var _choices: GridContainer
var _scroll: ScrollContainer
var _close_btn: Button
var _cont: Label

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/dialogues.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data

func _ready() -> void:
	inst = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.88)
	sb.border_color = Color(1.0, 0.82, 0.45, 0.8)
	sb.border_width_top = 3
	sb.set_corner_radius_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 30)
	_panel.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.add_theme_font_size_override("normal_font_size", 28)
	_text.add_theme_color_override("default_color", Color(0.95, 0.94, 0.9))
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.scroll_active = false
	_panel.add_child(_text)
	# les réponses défilent si elles sont nombreuses (sinon « Au revoir » sortait de l'écran)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)
	_choices = GridContainer.new()
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 8)
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_choices)
	# bouton de fermeture toujours visible pour les conversations libres (PNJ)
	_close_btn = Button.new()
	_close_btn.text = "Fermer  X"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.add_theme_font_size_override("font_size", 22)
	var cb := StyleBoxFlat.new()
	cb.bg_color = Color(0.25, 0.08, 0.07, 0.95)
	cb.border_color = Color(1, 0.5, 0.4)
	cb.set_border_width_all(2)
	cb.set_corner_radius_all(10)
	cb.content_margin_left = 14
	cb.content_margin_right = 14
	_close_btn.add_theme_stylebox_override("normal", cb)
	_close_btn.add_theme_stylebox_override("hover", cb)
	_close_btn.add_theme_stylebox_override("pressed", cb)
	_close_btn.pressed.connect(func(): if active: _close())
	_panel.add_child(_close_btn)
	_cont = Label.new()
	_cont.text = "Toucher pour continuer ▸"
	_cont.add_theme_font_size_override("font_size", 22)
	_cont.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 0.85))
	_panel.add_child(_cont)
	_panel.gui_input.connect(_on_panel_input)

func _layout() -> void:
	var s := get_viewport_rect().size
	var h := s.y * 0.40
	_panel.position = Vector2(30, s.y - h - 20)
	_panel.size = Vector2(s.x - 60, h)
	_name.position = Vector2(28, 14)
	var has_choices := _choices.get_child_count() > 0
	_scroll.visible = has_choices
	var tw := (_panel.size.x * 0.48) if has_choices else _panel.size.x - 56
	_text.position = Vector2(28, 58)
	_text.size = Vector2(tw, h - 80)
	_scroll.position = Vector2(_panel.size.x * 0.52, 16)
	_scroll.size = Vector2(_panel.size.x * 0.46, h - 32)
	_choices.custom_minimum_size = Vector2(_scroll.size.x - 12, 0)
	_close_btn.position = Vector2(_panel.size.x - 150, -52)
	_close_btn.size = Vector2(140, 46)
	_close_btn.visible = bool(_convo.get("fermable", false))
	_cont.position = Vector2(_panel.size.x - 300, h - 40)

## Ouvre une conversation du fichier de données, ou un dictionnaire construit à la volée.
func start(convo, start_node := "") -> void:
	if typeof(convo) == TYPE_STRING:
		_convo = data()[convo]
	else:
		_convo = convo
	_last_action = ""
	active = true
	visible = true
	_goto(start_node if start_node != "" else String(_convo["start"]))

func _goto(id: String) -> void:
	if id == "END" or id == "" or not _convo["nodes"].has(id):
		_close()
		return
	_node_id = id
	var n: Dictionary = _convo["nodes"][id]
	if n.has("fx"):
		apply_fx(n["fx"])
	if n.has("action"):
		_last_action = n["action"]
		action.emit(n["action"])
	var who: String = n.get("who", "conseil")
	var sp: Array = SPEAKERS.get(who, [who.capitalize(), Color(0.9, 0.9, 0.9)])
	_name.text = n.get("nom", sp[0])
	_name.add_theme_color_override("font_color", sp[1])
	var txt: String = n["text"]
	for v in n.get("text_if", []):
		if cond(v["cond"]):
			txt = v["text"]
			break
	_full = txt.replace("{titre}", GameState.get_inst().titre)
	_shown = 0.0
	_text.text = ""
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	_scroll.scroll_vertical = 0
	var visible_choices := 0
	for ch in n.get("choices", []):
		if ch.has("cond") and not cond(ch["cond"]):
			continue
		visible_choices += 1
		var b := Button.new()
		var tone: Array = TONES.get(ch.get("tone", ""), ["", Color.WHITE])
		b.text = ("[%s]  " % tone[0] if tone[0] != "" else "") + String(ch["text"])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.14, 0.13, 0.16, 0.95)
		bs.border_color = tone[1]
		bs.border_width_left = 6
		bs.set_corner_radius_all(8)
		bs.content_margin_left = 16
		bs.content_margin_right = 10
		b.add_theme_stylebox_override("normal", bs)
		var bh: StyleBoxFlat = bs.duplicate()
		bh.bg_color = Color(0.25, 0.22, 0.18, 0.98)
		b.add_theme_stylebox_override("hover", bh)
		b.add_theme_stylebox_override("pressed", bh)
		b.focus_mode = Control.FOCUS_NONE
		var choice: Dictionary = ch
		b.pressed.connect(func(): _pick(choice))
		_choices.add_child(b)
	_choices.columns = 2 if visible_choices > 4 else 1
	_cont.visible = visible_choices == 0
	_choices.visible = false
	_layout()

func _pick(ch: Dictionary) -> void:
	if _shown < _full.length():
		return
	Sfx.play("ok", -10.0)
	if ch.has("fx"):
		apply_fx(ch["fx"])
	if ch.has("action"):
		_last_action = ch["action"]
		action.emit(ch["action"])
	if ch.has("callback"):
		(ch["callback"] as Callable).call()
	_goto(String(ch.get("next", "END")))

func _on_panel_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		advance()

## Toucher : termine le texte en cours, sinon passe au nœud suivant (s'il n'y a pas de choix).
func advance() -> void:
	if _shown < _full.length():
		_shown = _full.length()
		return
	var n: Dictionary = _convo["nodes"][_node_id]
	if n.get("choices", []).is_empty() or _choices.get_child_count() == 0:
		_goto(String(n.get("next", "END")))

## Clavier : choisir la réponse n° i si le texte est affiché
func choose_visible(i: int) -> void:
	if _shown < _full.length() or not _choices.visible:
		return
	if i < _choices.get_child_count():
		(_choices.get_child(i) as Button).pressed.emit()

## Pour les tests automatiques : choisir la réponse n° i (parmi les réponses visibles)
func choose(i: int) -> bool:
	_shown = _full.length()
	var n: Dictionary = _convo["nodes"][_node_id]
	var vis := []
	for ch in n.get("choices", []):
		if not ch.has("cond") or cond(ch["cond"]):
			vis.append(ch)
	if vis.is_empty():
		advance()
		return false
	_pick(vis[clampi(i, 0, vis.size() - 1)])
	return true

func _close() -> void:
	visible = false
	active = false
	GameState.get_inst().save_game()
	Progression.get_inst().save_if_dirty()
	finished.emit(_last_action)

func _process(delta: float) -> void:
	if not visible:
		return
	_layout()
	if _shown < _full.length():
		_shown = minf(_full.length(), _shown + delta * 55.0)
		_text.text = _full.substr(0, int(_shown))
	elif not _choices.visible:
		_text.text = _full
		_choices.visible = true

# ------------------------------------------------------------ conditions et effets
static func cond(c: String) -> bool:
	c = c.strip_edges()
	if c == "":
		return true
	if c.begins_with("!"):
		return not cond(c.substr(1))
	var gs := GameState.get_inst()
	if c.begins_with("flag:"):
		return gs.flag(c.substr(5))
	for op in [">=", "<=", ">", "<", "=="]:
		var i := c.find(op)
		if i > 0:
			var k := c.substr(0, i).strip_edges()
			var v := float(c.substr(i + op.length()).strip_edges())
			var cur := _value(k)
			match op:
				">=": return cur >= v
				"<=": return cur <= v
				">": return cur > v
				"<": return cur < v
				"==": return cur == v
	return false

static func _value(k: String) -> float:
	var gs := GameState.get_inst()
	var prog := Progression.get_inst()
	if k == "or":
		return prog.gold
	if k == "niveau":
		return prog.level
	if k.begins_with("k_"):
		return Kingdom.res(k.substr(2))
	if k.begins_with("relation_"):
		var id := k.substr(9)
		if gs.companions.has(id):
			return float(gs.companions[id].get("relation", 0))
		return float(gs.mem(id).get("relation", 0)) + float(gs.flags.get("pre_" + k, 0))
	return float(gs.val(k))

static func apply_fx(fx: Dictionary, quiet := false) -> void:
	var gs := GameState.get_inst()
	for k in fx:
		var v = fx[k]
		if k.begins_with("k_"):
			Kingdom.add(k.substr(2), float(v))
			continue
		match k:
			"xp_agent":
				pass
			"potions_soin", "potions_mana":
				Progression.get_inst().add_potion(k.substr(8), int(v))
			"or":
				Progression.get_inst().add_gold(int(v))
				if Hud.inst and not quiet:
					Hud.inst.show_message("%+d or" % int(v), Color(1, 0.85, 0.35))
			"xp":
				Progression.get_inst().add_xp(int(v))
			"flag":
				gs.set_flag(String(v))
			"titre":
				gs.titre = String(v)
				gs.mark()
			_:
				if k.begins_with("relation_"):
					var id: String = k.substr(9)
					if gs.companions.has(id) or Companion.DEFAULTS.has(id):
						gs.add(k, int(v))
					else:
						var m := gs.mem(id)
						m["relation"] = int(m.get("relation", 0)) + int(v)
						gs.mark()
				elif k.begins_with("promesse_"):
					var m := gs.mem(k.substr(9))
					var pr: Array = m.get("promesses", [])
					if int(v) > 0:
						pr.append("recompense")
					else:
						pr.erase("recompense")
					m["promesses"] = pr
					gs.mark()
				else:
					gs.add(k, int(v))
