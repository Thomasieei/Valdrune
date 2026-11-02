class_name EyePanels
extends Control
## Œil du souverain : panneaux magiques flottants accrochés aux ennemis proches (3 au plus) —
## niveau estimé, puissance, PV, faiblesses, résistances, états. Apparition / disparition animées.

const ELEM_NAMES := {"feu": "Feu", "givre": "Givre", "foudre": "Foudre", "nature": "Nature", "arcane": "Arcane", "physique": "Physique"}
var _until := 0.0
var _panels: Array = []
var _acc := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var p := _make_panel()
		add_child(p)
		_panels.append(p)

func _make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.08, 0.86)
	sb.border_color = Color(0.4, 0.85, 1.0, 0.95)
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_corner_radius_all(6)
	sb.corner_radius_top_left = 0
	sb.corner_radius_bottom_right = 0
	sb.shadow_color = Color(0.3, 0.7, 1.0, 0.35)
	sb.shadow_size = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size = Vector2(250, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", 17)
	l.add_theme_font_size_override("bold_font_size", 19)
	l.add_theme_color_override("default_color", Color(0.88, 0.94, 1.0))
	p.add_child(l)
	p.visible = false
	p.modulate.a = 0.0
	return p

func open(dur: float) -> void:
	_until = Time.get_ticks_msec() / 1000.0 + dur
	_acc = 1.0

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var on := now < _until
	if not on:
		for p in _panels:
			if p.visible:
				p.modulate.a = maxf(0.0, p.modulate.a - delta * 4.0)
				if p.modulate.a <= 0.0:
					p.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	var pl := Combat.player
	if cam == null or pl == null:
		return
	_acc += delta
	var list := Combat.in_radius(pl.global_position, 30.0)
	list = list.filter(func(m): return not cam.is_position_behind(m.global_position))
	list.sort_custom(func(a, b): return a.global_position.distance_to(pl.global_position) < b.global_position.distance_to(pl.global_position))
	var vs := get_viewport_rect().size
	var placed: Array = []
	for i in _panels.size():
		var p: PanelContainer = _panels[i]
		if i >= list.size():
			p.modulate.a = maxf(0.0, p.modulate.a - delta * 4.0)
			if p.modulate.a <= 0.0:
				p.visible = false
			continue
		var m: Node3D = list[i]
		if not p.visible:
			p.visible = true
			p.scale = Vector2(0.6, 0.6)
		p.modulate.a = minf(1.0, p.modulate.a + delta * 5.0)
		p.scale = p.scale.lerp(Vector2.ONE, clampf(delta * 10.0, 0, 1))
		if _acc > 0.2 or p.get_meta("m", null) != m:
			p.set_meta("m", m)
			(p.get_child(0) as RichTextLabel).text = _text(m)
		var head: Vector3 = m.global_position + Vector3.UP * (2.4 * float(m.def["scale"]))
		var sp := cam.unproject_position(head)
		var sz := p.size * p.scale
		var pos := Vector2(clampf(sp.x + 30.0, 10.0, vs.x - sz.x - 180.0), clampf(sp.y - sz.y * 0.5, 120.0, vs.y - sz.y - 200.0))
		# pas de panneaux superposés : on décale sous le précédent
		for r in placed:
			if Rect2(pos, sz).intersects(r):
				pos.y = r.end.y + 6.0
		if pos.y + sz.y > vs.y - 20.0:
			pos.x = maxf(10.0, pos.x - sz.x - 12.0)
			pos.y = 120.0
		placed.append(Rect2(pos, sz))
		p.position = pos
	if _acc > 0.2:
		_acc = 0.0

static func level_of(m: Node3D) -> int:
	return maxi(1, int(round(float(m.def["xp"]) / 12.0)))

static func power_of(m: Node3D) -> int:
	return int(float(m.def["hp"]) * 0.5 + float(m.def["degats"]) * 6.0 + float(m.def["defense"]) * 10.0)

func _text(m: Node3D) -> String:
	var d: Dictionary = m.def
	var rank := "[color=#ffb347]BOSS[/color] " if d.get("boss", false) else ("[color=#ff9a3c]Élite[/color] " if d.get("elite", false) else "")
	var plv := Progression.get_inst().level
	var lv := level_of(m)
	var lvcol := "#ff6a5a" if lv > plv + 2 else ("#9cff9c" if lv < plv - 1 else "#ffe08a")
	var t := "[b]%s%s[/b]\n" % [rank, d["nom"]]
	t += "Niveau [color=%s]%d[/color]   Puissance [color=#c9a7ff]%d[/color]\n" % [lvcol, lv, power_of(m)]
	t += "PV %d / %d   Dégâts %d\n" % [int(m.cbt.hp), int(m.cbt.max_hp), int(d["degats"])]
	var weak := []
	var res := []
	var el: Dictionary = d.get("elements", {})
	for k in el:
		if float(el[k]) > 1.0:
			weak.append("%s ×%.1f" % [ELEM_NAMES.get(k, k), el[k]])
		elif float(el[k]) < 1.0:
			res.append("%s ×%.1f" % [ELEM_NAMES.get(k, k), el[k]])
	t += "[color=#7dffb0]Faiblesses :[/color] %s\n" % (", ".join(weak) if weak.size() > 0 else "aucune")
	t += "[color=#ff8a8a]Résistances :[/color] %s\n" % (", ".join(res) if res.size() > 0 else "aucune")
	var st := []
	if m.state == Monster.S.ETOURDI: st.append("étourdi")
	if m.state == Monster.S.SOULEVE: st.append("soulevé")
	if m.state == Monster.S.FUITE: st.append("effrayé")
	if m.cbt.is_rooted(): st.append("immobilisé")
	elif m.cbt.speed_mult() < 1.0: st.append("ralenti")
	if d.get("speciales", []).size() > 0:
		st.append("attaques au sol")
	t += "[color=#9fd8ff]États :[/color] %s" % (", ".join(st) if st.size() > 0 else "normal")
	return t
