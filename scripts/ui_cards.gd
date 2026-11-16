class_name UICards
## Cartes illustrées façon UMBRA : cadre et lueur de la couleur du rang, vignette, lettre de rang,
## pastille « équipé », pastille de rôle, petite barre de vie.

static var _glow: GradientTexture2D

static func rar_color(i: int) -> Color:
	return Color(str(Items.RAR[clampi(i, 0, 6)]["c"]))

## Rang d'ombre E..S → couleur de rareté (E = vert « peu commun » ... S = rose suprême).
static func grade_color(g: int) -> Color:
	return rar_color(clampi(g + 1, 1, 6))

static func glow_tex() -> GradientTexture2D:
	if _glow == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.45)
		_glow.fill_to = Vector2(0.5, 1.0)
		_glow.width = 128
		_glow.height = 128
	return _glow

static func card(tex: Texture2D, col: Color, letter: String, title: String, sub: String, equipped := false, selected := false, role_tex: Texture2D = null, hp_ratio := -1.0, w := 108.0, h := 138.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r * 0.12 + 0.03, col.g * 0.12 + 0.03, col.b * 0.14 + 0.06, 0.96)
	sb.border_color = col.lightened(0.25) if selected else col.darkened(0.15)
	sb.set_border_width_all(4 if selected else 2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(col.r, col.g, col.b, 0.55 if selected else 0.25)
	sb.shadow_size = 10 if selected else 4
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var glow := TextureRect.new()
	glow.texture = glow_tex()
	glow.modulate = Color(col.r, col.g, col.b, 0.9)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.position = Vector2(4, 4)
	glow.size = Vector2(w - 8, h * 0.72)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glow)
	if tex:
		var ic := TextureRect.new()
		ic.texture = tex
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(8, 10)
		ic.size = Vector2(w - 16, h * 0.58)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
	if title != "":
		var nl := Label.new()
		nl.text = title
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.clip_text = true
		nl.add_theme_font_size_override("font_size", 12)
		nl.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
		nl.add_theme_constant_override("outline_size", 4)
		nl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		nl.position = Vector2(3, h - 40)
		nl.size = Vector2(w - 6, 18)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nl)
	if sub != "":
		var sl := Label.new()
		sl.text = sub
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.add_theme_font_size_override("font_size", 11)
		sl.add_theme_color_override("font_color", col.lightened(0.45))
		sl.position = Vector2(3, h - 22)
		sl.size = Vector2(w - 6, 16)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(sl)
	if letter != "":
		var bp := Panel.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = col
		bs.set_corner_radius_all(7)
		bs.border_color = Color(0, 0, 0, 0.6)
		bs.set_border_width_all(1)
		bp.add_theme_stylebox_override("panel", bs)
		bp.position = Vector2(5, 5)
		bp.size = Vector2(24, 24)
		bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ll := Label.new()
		ll.text = letter
		ll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ll.size = Vector2(24, 24)
		ll.add_theme_font_size_override("font_size", 15)
		ll.add_theme_color_override("font_color", Color(0.05, 0.03, 0.08))
		bp.add_child(ll)
		b.add_child(bp)
	if equipped:
		var ep := Panel.new()
		var es := StyleBoxFlat.new()
		es.bg_color = Color(0.2, 0.8, 0.35)
		es.set_corner_radius_all(11)
		es.border_color = Color(1, 1, 1, 0.8)
		es.set_border_width_all(2)
		ep.add_theme_stylebox_override("panel", es)
		ep.position = Vector2(w - 27, 5)
		ep.size = Vector2(22, 22)
		ep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var el := Label.new()
		el.text = "✓"
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		el.size = Vector2(22, 22)
		el.add_theme_font_size_override("font_size", 14)
		ep.add_child(el)
		b.add_child(ep)
	if role_tex:
		var rt := TextureRect.new()
		rt.texture = role_tex
		rt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rt.position = Vector2(w - 34, h * 0.5)
		rt.size = Vector2(30, 30)
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(rt)
	if hp_ratio >= 0.0:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.7)
		bg.position = Vector2(10, h - 46)
		bg.size = Vector2(w - 20, 5)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bg)
		var fg := ColorRect.new()
		fg.color = Color(0.3, 0.95, 0.45) if hp_ratio > 0.5 else (Color(1, 0.8, 0.2) if hp_ratio > 0.25 else Color(1, 0.3, 0.25))
		fg.position = Vector2(10, h - 46)
		fg.size = Vector2((w - 20) * clampf(hp_ratio, 0, 1), 5)
		fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(fg)
	return b

## Emplacement vide (cadre pointillé discret).
static func empty_slot(label: String, w := 70.0, h := 86.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.1, 0.6)
	sb.border_color = Color(0.4, 0.4, 0.55, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.text = label
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(0.6, 0.62, 0.75))
	return b

## Petite pastille icône + texte (ressources, coûts).
static func chip(tex: Texture2D, txt: String, col := Color(1, 1, 1), size := 22) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.custom_minimum_size = Vector2(size, size)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(t)
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", int(size * 0.75))
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	h.add_child(l)
	return h
