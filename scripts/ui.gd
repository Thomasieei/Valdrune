class_name Ui




const BLEU := Color(0.13, 0.42, 1.0)
const CYAN := Color(0.25, 0.85, 1.0)
const FOND := Color(0.035, 0.06, 0.17, 0.97)
const FOND_CASE := Color(0.06, 0.09, 0.24)
const VERT := Color(0.2, 0.78, 0.25)
const ROUGE := Color(0.85, 0.12, 0.15)
const OR := Color(0.95, 0.68, 0.12)
const ROSE := Color(0.85, 0.15, 0.55)
const VIOLET := Color(0.5, 0.25, 0.95)

static var police: FontFile
static var police_titre: FontFile
static var _textures := {}

static func preparer() -> Theme:
	police = load("res://assets/polices/AlegreyaSans-ExtraBold.ttf")
	police_titre = load("res://assets/polices/AlegreyaSans-ExtraBold.ttf")
	var t := Theme.new()
	t.default_font = police
	t.default_font_size = 20
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.95))
	t.set_constant("outline_size", "Label", 6)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.95))
	t.set_constant("outline_size", "Button", 6)
	return t

static func tex(nom: String) -> Texture2D:
	if not _textures.has(nom):
		var p := "res://assets/ui/%s.png" % nom
		if not ResourceLoader.exists(p):
			p = "res://assets/ui/items/%s.png" % nom
		_textures[nom] = load(p) if ResourceLoader.exists(p) else null
	return _textures[nom]

static func boite(fond: Color, bord: Color, epaisseur := 2, coin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(epaisseur)
	s.set_corner_radius_all(coin)
	s.anti_aliasing = true
	return s

static func label(t: String, taille := 20, c := Color.WHITE, contour := 6) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("outline_size", contour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func bouton(t: String, couleur: Color, taille := Vector2(220, 52), police_t := 22) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = taille
	b.size = taille
	b.add_theme_font_size_override("font_size", police_t)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 0.85))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.65))
	var n := boite(couleur.darkened(0.15), couleur.lightened(0.45), 3, 10)
	n.shadow_color = Color(0, 0, 0, 0.45)
	n.shadow_size = 4
	n.shadow_offset = Vector2(0, 3)
	var p := boite(couleur.darkened(0.4), couleur.lightened(0.6), 3, 10)
	var d := boite(Color(0.16, 0.16, 0.2), Color(0.35, 0.35, 0.42), 2, 10)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.pressed.connect(func (): Fx.son("click", -6.0))
	return b


static func panneau(titre: String, icone: String, taille: Vector2, fermer: Callable) -> Control:
	var p := Panel.new()
	p.size = taille
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var s := boite(FOND, BLEU, 4, 16)
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 18
	p.add_theme_stylebox_override("panel", s)

	var inner := Panel.new()
	inner.position = Vector2(14, 70)
	inner.size = taille - Vector2(28, 84)
	inner.add_theme_stylebox_override("panel", boite(Color(0.05, 0.08, 0.22), Color(0.2, 0.45, 0.95, 0.7), 2, 12))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.name = "Interieur"
	p.add_child(inner)

	var g := Gradient.new()
	g.set_color(0, Color(0.12, 0.25, 0.85))
	g.set_color(1, Color(0.3, 0.9, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 8
	var bandeau := TextureRect.new()
	bandeau.texture = gt
	bandeau.stretch_mode = TextureRect.STRETCH_SCALE
	bandeau.position = Vector2(60, 12)
	bandeau.size = Vector2(taille.x - 150, 48)
	bandeau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bandeau)
	var ic := TextureRect.new()
	ic.texture = tex(icone)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(10, -6)
	ic.size = Vector2(80, 80)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(ic)
	var t := label(titre, 34, Color.WHITE, 9)
	t.position = Vector2(98, 10)
	p.add_child(t)
	var x := hexagone("", "", 64.0, ROUGE, "X")
	x.position = Vector2(taille.x - 78, 4)
	x.pressed.connect(fermer)
	p.add_child(x)
	return p


static func hexagone(texte: String, icone: String, taille: float, couleur := BLEU, symbole := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(taille, taille)
	b.size = Vector2(taille, taille)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.set_meta("alerte", false)
	b.draw.connect(func ():
		var c := b.size / 2.0
		var r := taille / 2.0 * (0.92 if b.button_pressed or b.is_pressed() else 1.0)
		var pts := PackedVector2Array()
		for k in 6:
			var a := PI / 6.0 + k * TAU / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		b.draw_colored_polygon(pts, Color(0.03, 0.06, 0.2, 0.92) if symbole == "" else couleur.darkened(0.2))
		var inner := PackedVector2Array()
		for k in 6:
			var a2 := PI / 6.0 + k * TAU / 6.0
			inner.append(c + Vector2(cos(a2), sin(a2)) * (r - 6))
		b.draw_colored_polygon(inner, Color(0.06, 0.14, 0.42, 0.9) if symbole == "" else couleur)
		pts.append(pts[0])
		b.draw_polyline(pts, couleur.lightened(0.35) if symbole == "" else Color(1, 0.75, 0.75), 3.0, true)
		if symbole != "":
			var e := r * 0.36
			b.draw_line(c - Vector2(e, e), c + Vector2(e, e), Color.WHITE, 6.0, true)
			b.draw_line(c + Vector2(- e, e), c + Vector2(e, -e), Color.WHITE, 6.0, true)
			return
		var t := tex(icone)
		if t:
			var ti := r * 1.05
			b.draw_texture_rect(t, Rect2(c - Vector2(ti, ti) / 2.0 - Vector2(0, r * 0.16), Vector2(ti, ti)), false)
		if texte != "":
			var fs := 17
			while fs > 12 and police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > taille * 0.98:
				fs -= 1
			var w := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var p := c + Vector2(- w / 2.0, r * 0.68)
			b.draw_string_outline(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
			b.draw_string(police, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if b.get_meta("alerte"):
			var pa := c + Vector2(r * 0.62, -r * 0.62)
			b.draw_circle(pa, 13, Color(0.9, 0.1, 0.12))
			b.draw_arc(pa, 13, 0, TAU, 24, Color.WHITE, 2.0, true)
			b.draw_string(police, pa + Vector2(-4, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE))
	b.pressed.connect(func (): Fx.son("click", -6.0))
	return b




static func carte(nom: String, icone: String, sigle: String, couleur: Color, equipe: bool, sous := "", taille := Vector2(160, 176), effet := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = taille
	b.size = taille
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	if effet != "":
		b.set_meta("phase", 0.0)
		b.ready.connect(func ():
			var tw := b.create_tween().set_loops()
			tw.tween_method(func (v):
				b.set_meta("phase", v)
				b.queue_redraw(), 0.0, 1.0, 2.2 if effet == "shiny" else 3.0))
	b.draw.connect(func ():
		var r := Rect2(Vector2.ZERO, b.size)
		var ph: float = b.get_meta("phase", 0.0)
		var fond := FOND_CASE
		if effet == "unique":
			fond = Color(0.14, 0.06, 0.22)
		elif effet == "shiny":
			fond = Color(0.16, 0.04, 0.26)
		elif effet == "rouge":
			fond = Color(0.2, 0.03, 0.06)
		var s := boite(fond, couleur, 3, 10)
		b.draw_style_box(s, r)
		var lueur := couleur
		if effet == "unique":
			lueur = Color(0.7, 0.3, 1.0)

		for k in 10:
			var h := r.size.y * 0.55 * (k + 1) / 10.0
			b.draw_rect(Rect2(4, r.size.y - h, r.size.x - 8, h / 10.0 + 1), Color(lueur.r, lueur.g, lueur.b, 0.045 * (10 - k) * (1.4 if effet != "" else 1.0)))
		if effet == "unique":

			b.draw_style_box(boite(Color(0, 0, 0, 0), Color(0.7, 0.3, 1.0, 0.9), 2, 8), r.grow(-5))
		elif effet == "shiny" or effet == "rouge":

			var x := -r.size.x * 0.6 + ph * r.size.x * 2.2
			var pts := PackedVector2Array([Vector2(x, r.size.y - 4), Vector2(x + 28, r.size.y - 4), Vector2(x + 28 + r.size.y * 0.5, 4), Vector2(x + r.size.y * 0.5, 4)])
			var ok := true
			for pt in pts:
				if pt.x < 4 or pt.x > r.size.x - 4:
					ok = false
			if ok:
				b.draw_colored_polygon(pts, Color(1, 0.85, 1, 0.18) if effet == "shiny" else Color(1, 0.6, 0.6, 0.15))
			if effet == "shiny":
				for k in 5:
					var a := ph * TAU + k * 1.3
					var p := Vector2(r.size.x * (0.2 + 0.15 * k), r.size.y * (0.25 + 0.1 * ((k * 3) % 5)))
					var t2 := 2.5 + 3.5 * absf(sin(a))
					b.draw_line(p - Vector2(t2, 0), p + Vector2(t2, 0), Color(1, 0.9, 1, 0.9), 2.0)
					b.draw_line(p - Vector2(0, t2), p + Vector2(0, t2), Color(1, 0.9, 1, 0.9), 2.0)
		var t := tex(icone)
		if t:
			var ti := minf(r.size.x, r.size.y) * (0.43 if sous != "" and r.size.y < 120 else 0.62)
			b.draw_texture_rect(t, Rect2(Vector2((r.size.x - ti) / 2.0, 22), Vector2(ti, ti)), false)
		b.draw_string_outline(police, Vector2(10, 32), sigle, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 7, Color.BLACK)
		b.draw_string(police, Vector2(10, 32), sigle, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, couleur.lightened(0.25))
		var fs := 17
		while fs > 11 and police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 12:
			fs -= 1
		var w := police.get_string_size(nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		b.draw_string_outline(police, Vector2((r.size.x - w) / 2.0, r.size.y - (28 if sous != "" else 12)), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
		b.draw_string(police, Vector2((r.size.x - w) / 2.0, r.size.y - (28 if sous != "" else 12)), nom, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if sous != "":
			var w2 := police.get_string_size(sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			b.draw_string_outline(police, Vector2((r.size.x - w2) / 2.0, r.size.y - 9), sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color.BLACK)
			b.draw_string(police, Vector2((r.size.x - w2) / 2.0, r.size.y - 9), sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, couleur.lightened(0.35))
		if equipe:
			var c := Vector2(r.size.x - 24, 22)
			b.draw_circle(c, 15, Color(0.05, 0.35, 0.1))
			b.draw_polyline(PackedVector2Array([c + Vector2(-8, 0), c + Vector2(-2, 7), c + Vector2(9, -7)]), Color(0.35, 1.0, 0.35), 5.0, true))
	b.pressed.connect(func (): Fx.son("select", -8.0))
	return b


static func detail(titre: String, couleur: Color, lignes: Array, boutons: Array) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var s := boite(Color(0.07, 0.03, 0.14, 0.98), Color(0.55, 0.3, 1.0), 3, 12)
	s.shadow_color = Color(0, 0, 0, 0.7)
	s.shadow_size = 14
	p.add_theme_stylebox_override("panel", s)
	var v := VBoxContainer.new()
	v.position = Vector2(16, 12)
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := label(titre, 26, Color.WHITE, 7)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.x = 268
	v.add_child(t)
	for l in lignes:
		var li := label(l[0], 19, l[1], 5)
		li.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		li.custom_minimum_size.x = 268
		v.add_child(li)
	var sep := ColorRect.new()
	sep.color = Color(couleur.r, couleur.g, couleur.b, 0.6)
	sep.custom_minimum_size = Vector2(268, 2)
	v.add_child(sep)
	for b in boutons:
		var bt := bouton(b[0], b[1], Vector2(268, 46), 21)
		bt.disabled = b.size() > 3 and b[3]
		bt.pressed.connect(b[2])
		v.add_child(bt)
	p.size = Vector2(300, 24 + 34 + lignes.size() * 29 + 10 + boutons.size() * 52)
	return p
