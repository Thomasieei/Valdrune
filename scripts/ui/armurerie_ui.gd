class_name ArmurerieUI
extends Control
## Comptoir de la Forge de Valmont : acheter, équiper, réparer. Deux colonnes (arme principale / main gauche),
## une jauge de solidité par objet. Le jeu est en pause tant que le comptoir est ouvert.

const ACCENT := Color(1, 0.82, 0.45)
static var inst: ArmurerieUI
var _panel: Panel
var _list: VBoxContainer
var _gold: Label
var _note: Label
var _who := "Brand le forgeron"

static func open(who := "Brand le forgeron") -> void:
	if inst == null or not is_instance_valid(inst):
		var layer := CanvasLayer.new()
		layer.layer = 4
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).current_scene.add_child(layer)
		inst = ArmurerieUI.new()
		layer.add_child(inst)
	inst._who = who
	inst.visible = true
	inst.get_tree().paused = true
	inst._refresh()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _box(Color(0.11, 0.09, 0.08, 0.97), ACCENT, 3, 14))
	add_child(_panel)
	var v := VBoxContainer.new()
	v.name = "V"
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var title := Label.new()
	title.text = "FORGE DE VALMONT"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_gold = Label.new()
	_gold.add_theme_font_size_override("font_size", 26)
	_gold.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	top.add_child(_gold)
	var close := _button("Fermer")
	close.custom_minimum_size = Vector2(150, 52)
	close.pressed.connect(_close)
	top.add_child(close)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 20)
	_note.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	sc.add_child(_list)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	var s := get_viewport_rect().size
	_panel.position = Vector2(30, 20)
	_panel.size = s - Vector2(60, 40)
	var v: Control = _panel.get_node("V")
	v.position = Vector2(22, 16)
	v.size = _panel.size - Vector2(44, 32)

func _close() -> void:
	visible = false
	get_tree().paused = false

func _refresh(msg := "") -> void:
	Armes.load_game()
	var p := Progression.get_inst()
	_gold.text = "%d or   " % p.gold
	_note.text = msg if msg != "" else "%s : « Une lame qu'on n'entretient pas vous lâche au pire moment, seigneur. Je répare, je vends, je forge. »" % _who
	for c in _list.get_children():
		c.queue_free()
	for slot in [["main", "ARME PRINCIPALE"], ["gauche", "MAIN GAUCHE"]]:
		var h := Label.new()
		h.text = slot[1]
		h.add_theme_font_size_override("font_size", 24)
		h.add_theme_color_override("font_color", ACCENT)
		_list.add_child(h)
		for id in Armes.CATALOGUE:
			var cat: Dictionary = Armes.CATALOGUE[id]
			if cat["slot"] != slot[0]:
				continue
			_list.add_child(_row(id, cat))

func _row(id: String, cat: Dictionary) -> Control:
	var owned := Armes.possedees.has(id)
	var equipped := Armes.main == id or Armes.gauche == id
	var pan := PanelContainer.new()
	pan.add_theme_stylebox_override("panel", _box(Color(0.17, 0.14, 0.12) if not equipped else Color(0.25, 0.2, 0.12), ACCENT if equipped else Color(0.4, 0.35, 0.28), 2, 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	pan.add_child(h)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var nm := Label.new()
	var stat := ""
	if cat.has("mult"):
		stat = "  ·  dégâts x%.2f" % float(cat["mult"])
	elif cat.has("def"):
		stat = "  ·  défense +%d" % int(cat["def"])
	elif cat.has("crit"):
		stat = "  ·  critique %d %%" % int(float(cat["crit"]) * 100.0)
	nm.text = String(cat["nom"]) + stat + ("   [ÉQUIPÉ]" if equipped else "")
	nm.add_theme_font_size_override("font_size", 23)
	nm.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	info.add_child(nm)
	var ds := Label.new()
	ds.text = cat["desc"]
	ds.add_theme_font_size_override("font_size", 18)
	ds.add_theme_color_override("font_color", Color(0.75, 0.72, 0.66))
	info.add_child(ds)
	if owned and Armes.dur_max(id) > 0.0:
		var e := Armes.etat(id)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(320, 14)
		bar.show_percentage = false
		bar.value = e * 100.0
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.35, 0.85, 0.4) if e > 0.6 else (Color(1.0, 0.75, 0.3) if e > 0.3 else Color(1.0, 0.35, 0.3))
		fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), 0, 6))
		info.add_child(bar)
		var sl := Label.new()
		sl.text = "Solidité %d / %d" % [int(Armes.usure.get(id, Armes.dur_max(id))), int(Armes.dur_max(id))] + ("  — émoussée" if e < 0.3 and e > 0.0 else ("  — BRISÉE" if e <= 0.0 else ""))
		sl.add_theme_font_size_override("font_size", 17)
		sl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
		info.add_child(sl)
	var gold := Progression.get_inst().gold
	if not owned:
		var b := _button("Acheter %d or" % int(cat["prix"]), ACCENT, gold >= int(cat["prix"]))
		b.custom_minimum_size = Vector2(220, 56)
		b.pressed.connect(func():
			if Armes.buy(id):
				Sfx.play("coup", -6.0)
				_refresh("Marché conclu : %s est à vous, et déjà en main." % cat["nom"])
			else:
				_refresh("Pas assez d'or."))
		h.add_child(b)
	else:
		var cost := Armes.repair_cost(id)
		if Armes.dur_max(id) > 0.0:
			var r := _button("Réparer %d or" % cost if cost > 0 else "En parfait état", Color(0.6, 0.85, 1.0), cost > 0 and gold >= cost)
			r.custom_minimum_size = Vector2(220, 56)
			r.pressed.connect(func():
				if Armes.repair(id):
					Sfx.play("coup", -6.0)
					_refresh("%s : « Et voilà, comme neuve. »" % _who)
				else:
					_refresh("Pas assez d'or."))
			h.add_child(r)
		if not equipped:
			var eq := _button("Équiper", ACCENT)
			eq.custom_minimum_size = Vector2(150, 56)
			eq.pressed.connect(func():
				Armes.equip(id)
				_refresh())
			h.add_child(eq)
	return pan

func _button(t: String, c := ACCENT, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_stylebox_override("normal", _box(Color(0.16, 0.15, 0.17), c, 2, 8))
	b.add_theme_stylebox_override("hover", _box(Color(0.24, 0.21, 0.18), c, 2, 8))
	b.add_theme_stylebox_override("pressed", _box(Color(0.3, 0.26, 0.2), c, 2, 8))
	b.add_theme_stylebox_override("disabled", _box(Color(0.12, 0.12, 0.12), Color(0.35, 0.35, 0.35), 2, 8))
	b.disabled = not enabled
	return b

func _box(bg: Color, border: Color, bw: int, r: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s
