class_name CommandUI
extends Control
## Commandement rapide (façon « ombres ») : un bouton, des cartes pour chaque homme de la garde
## rapprochée et Elian ; on en choisit un, plusieurs ou tous, puis un ordre d'un seul geste.
## Le jeu continue pendant ce temps : c'est un panneau de combat, pas un menu.

static var inst: CommandUI
var _sel := {}            # instance_id -> vrai
var _panel: PanelContainer
var _cards: HBoxContainer
var _orders: GridContainer
var _info: Label

func _ready() -> void:
	inst = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	sb.border_color = Color(1.0, 0.8, 0.4, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var t := Label.new()
	t.text = "Commandement"
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var x := Button.new()
	x.text = "  Fermer  "
	x.add_theme_font_size_override("font_size", 20)
	x.pressed.connect(close)
	top.add_child(x)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.88))
	v.add_child(_info)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 10)
	v.add_child(_cards)
	_orders = GridContainer.new()
	_orders.columns = 4
	_orders.add_theme_constant_override("h_separation", 8)
	_orders.add_theme_constant_override("v_separation", 8)
	v.add_child(_orders)
	var orders := [
		["Attaquez !", "attaque"], ["Protégez-moi", "proteger"], ["Ne pas attaquer", "passif"], ["Gardez ce point", "garder"],
		["Patrouillez ici", "patrouille"], ["Rentrez au château", "renvoi"], ["Portail : 2 gardes", "portail"], ["Tous me rejoindre", "rappel"],
	]
	for o in orders:
		var b := Button.new()
		b.text = o[0]
		b.custom_minimum_size = Vector2(200, 54)
		b.add_theme_font_size_override("font_size", 19)
		var oid: String = o[1]
		b.pressed.connect(func(): order(oid))
		_orders.add_child(b)

static func is_open() -> bool:
	return inst != null and inst.visible

func open() -> void:
	visible = true
	_sel.clear()
	for u in units():
		_sel[u.get_instance_id()] = true
	refresh()

func close() -> void:
	visible = false

## Les hommes que l'on commande : garde rapprochée + Elian s'il est là
static func units() -> Array:
	var out: Array = []
	for s in Escort.members:
		if is_instance_valid(s) and not s.cbt.dead:
			out.append(s)
	var c = Combat.companion
	if c and is_instance_valid(c) and c.visible and Story.done():
		out.append(c)
	return out

func refresh() -> void:
	for ch in _cards.get_children():
		ch.queue_free()
	var us := units()
	var all := Button.new()
	all.text = "TOUS\n%d hommes" % us.size()
	all.custom_minimum_size = Vector2(120, 92)
	all.add_theme_font_size_override("font_size", 18)
	all.pressed.connect(func():
		var every := us.all(func(u): return _sel.has(u.get_instance_id()))
		_sel.clear()
		if not every:
			for u in us:
				_sel[u.get_instance_id()] = true
		refresh())
	_cards.add_child(all)
	for u in us:
		var b := Button.new()
		var nom: String = "Elian" if u is Companion else String(u.nom)
		var etat := ""
		if u is Soldier:
			etat = ("Passif" if u.passive else Escort.mode_name(u.mode)) if u.patrol.size() < 2 else "Ronde"
		else:
			etat = "Passif" if u.passive else "À vos côtés"
		var on: bool = _sel.has(u.get_instance_id())
		b.text = "%s %s\n%s\n%d/%d PV" % ["[x]" if on else "[ ]", nom, etat, int(u.cbt.hp), int(u.cbt.max_hp)]
		b.custom_minimum_size = Vector2(150, 92)
		b.add_theme_font_size_override("font_size", 16)
		b.modulate = Color(1, 1, 1) if on else Color(0.7, 0.7, 0.75)
		var id: int = u.get_instance_id()
		b.pressed.connect(func():
			if _sel.has(id):
				_sel.erase(id)
			else:
				_sel[id] = true
			refresh())
		_cards.add_child(b)
	_info.text = "Garde rapprochée : %d · Gardes disponibles au château : %d · Choisissez des hommes, puis un ordre." % [Escort.members.size(), Escort.available()] if us.size() > 0 else "Personne sous vos ordres. « Portail » fait venir deux gardes à vos côtés."
	var vs := get_viewport_rect().size
	_panel.size = Vector2(minf(vs.x - 40.0, 900.0), 0)
	_panel.position = Vector2(vs.x * 0.5 - _panel.size.x * 0.5, 90)

func selected() -> Array:
	return units().filter(func(u): return _sel.has(u.get_instance_id()))

func order(o: String) -> void:
	var p := Combat.player
	var us := selected()
	match o:
		"portail":
			var made := Escort.call_guards(2)
			if made > 0:
				var front := p.global_position - p.global_transform.basis.z * -3.0
				Magic.rune(front + Vector3.UP * 0.05, 2.4, Color(0.6, 0.8, 1.0), 2.2, 1.2)
				Magic.pillar(front, Color(0.6, 0.8, 1.0), 6.0, 0.8, 2.0)
				Sfx.play("ok", -2.0)
				var i := 0
				for s in Escort.members.slice(Escort.members.size() - made):
					s.global_position = front + Vector3(i * 1.4 - 0.7, 0.4, 0)
					s.say("À vos ordres !", 1.6)
					i += 1
			elif Hud.inst:
				Hud.inst.show_message("Plus aucun garde disponible au château", Color(1, 0.6, 0.5))
			_sel.clear()
			for u in units():
				_sel[u.get_instance_id()] = true
			refresh()
			return
		"rappel":
			for u in units():
				_sel[u.get_instance_id()] = true
			us = units()
	if us.is_empty():
		if Hud.inst:
			Hud.inst.show_message("Choisissez au moins un homme", Color(1, 0.8, 0.5))
		return
	for u in us:
		if u is Companion:
			u.passive = o == "passif"
			if o in ["attaque", "proteger", "rappel", "passif"]:
				u.follow()
			continue
		var s: Soldier = u
		s.patrol = []
		match o:
			"attaque":
				s.passive = false
				Escort.set_mode(s, Soldier.M.ECLAIREUR)
			"proteger", "rappel":
				s.passive = false
				Escort.set_mode(s, Soldier.M.ESCORTE)
			"passif":
				s.passive = true
				Escort.set_mode(s, Soldier.M.ESCORTE)
			"garder":
				s.passive = false
				Escort.set_mode(s, Soldier.M.GARDER)
				s.goal = p.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
			"patrouille":
				s.passive = false
				Escort.set_mode(s, Soldier.M.GARDER)
				var c := p.global_position
				var a0 := randf() * TAU
				for k in 4:
					var a := a0 + TAU * k / 4.0
					s.patrol.append(c + Vector3(cos(a), 0, sin(a)) * 9.0)
				s.goal = s.patrol[0]
			"renvoi":
				Escort.dismiss(s)
	var lines := {"attaque": "À l'attaque !", "proteger": "Nous vous couvrons !", "passif": "Lames au fourreau.", "garder": "Personne ne passera.", "patrouille": "On fait la ronde.", "renvoi": "Bien, mon seigneur.", "rappel": "On arrive !"}
	if us.size() > 0 and us[0].has_method("say"):
		us[0].say(lines.get(o, "À vos ordres !"), 1.8)
	Sfx.play("ok", -6.0)
	refresh()

func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 30 == 0:
		refresh()
