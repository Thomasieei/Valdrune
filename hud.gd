extends CanvasLayer
class_name Hud
# Interface douce : boutons ronds, cartes arrondies semi-transparentes, mini-carte réelle, dialogues

const GOLD := Color("#f2c35a")
const SOFT := Color("#f4ead6")
var main: Node
var root: Control
var overlay: Control
var joy := {"id": -1, "base": Vector2.ZERO, "pos": Vector2.ZERO, "vec": Vector2.ZERO}
var buttons := {}
var touches := {}
var icons := {}
var goal_lbl: RichTextLabel
var hint_lbl: RichTextLabel
var toasts: VBoxContainer
var red: ColorRect
var minimap: TextureRect
var region_lbl: Label
var region_dot := Color.WHITE
var fps_lbl: Label
var panel: Control
var panel_open := false
var panel_extra: Array = []
var main_mode := "attack"
var main_col := GOLD
var main_text := "ATTAQUE"
var main_icon := "skull"
var tex := {}
var f_title: FontFile
var theme_ui: Theme
var circle_sh: Shader
var map_sh: Shader
var map_tex: ImageTexture
var title: Control
var mc := Vector2.ZERO
var cur_panel := ""
var ah_tab := "buy"
var ah_cat := "all"
var ah_tier := 0
var ah_sel = null
var ah_price := 0
var bag_sel := -1
var eq_sel := ""
var drag_guard := false
var map_dungeon := false
var panel_title := ""
var scroll_mem := {}
var cur_scroll: ScrollContainer

func T(n: String) -> Texture2D:
	if not tex.has(n): tex[n] = load("res://ui/%s.png" % n)
	return tex[n]

func flat(bg: Color, r := 16, border := Color(0, 0, 0, 0), bw := 0, pad := Vector4(16, 10, 16, 10), shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(r)
	s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	if bw > 0: s.border_color = border; s.set_border_width_all(bw)
	if shadow > 0: s.shadow_color = Color(0, 0, 0, 0.35); s.shadow_size = shadow
	s.anti_aliasing = true
	return s

func _make_theme() -> void:
	f_title = load("res://ui/serif_bold.ttf")
	theme_ui = Theme.new()
	var bpad := Vector4(22, 10, 22, 12)
	theme_ui.set_stylebox("normal", "Button", flat(Color("#2c5f66"), 14, Color(0.95, 0.78, 0.45, 0.55), 2, bpad))
	theme_ui.set_stylebox("hover", "Button", flat(Color("#367480"), 14, Color(0.95, 0.78, 0.45, 0.7), 2, bpad))
	theme_ui.set_stylebox("pressed", "Button", flat(Color("#3f8a5c"), 14, Color(0.95, 0.85, 0.5, 0.9), 2, bpad))
	theme_ui.set_stylebox("disabled", "Button", flat(Color(0.22, 0.24, 0.26, 0.85), 14, Color(1, 1, 1, 0.12), 2, bpad))
	theme_ui.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_ui.set_font("font", "Button", f_title); theme_ui.set_font_size("font_size", "Button", 21)
	theme_ui.set_color("font_color", "Button", Color("#ffe6a8")); theme_ui.set_color("font_hover_color", "Button", Color("#fff2c8"))
	theme_ui.set_color("font_pressed_color", "Button", Color.WHITE); theme_ui.set_color("font_disabled_color", "Button", Color(0.62, 0.62, 0.6))
	theme_ui.set_stylebox("scroll", "VScrollBar", flat(Color(1, 1, 1, 0.06), 6, Color(0, 0, 0, 0), 0, Vector4(3, 3, 3, 3)))
	theme_ui.set_stylebox("grabber", "VScrollBar", flat(Color(0.95, 0.78, 0.45, 0.55), 6, Color(0, 0, 0, 0), 0, Vector4(5, 12, 5, 12)))
	theme_ui.set_stylebox("grabber_highlight", "VScrollBar", flat(Color(0.95, 0.78, 0.45, 0.8), 6, Color(0, 0, 0, 0), 0, Vector4(5, 12, 5, 12)))
	theme_ui.set_stylebox("grabber_pressed", "VScrollBar", flat(Color(1, 0.85, 0.5, 0.95), 6, Color(0, 0, 0, 0), 0, Vector4(5, 12, 5, 12)))
	theme_ui.set_constant("icon_max_width", "Button", 40)
	theme_ui.set_font("bold_font", "RichTextLabel", f_title)
	theme_ui.set_color("default_color", "RichTextLabel", SOFT)
	root.theme = theme_ui
	circle_sh = Shader.new()
	circle_sh.code = """shader_type canvas_item;
uniform float gray = 0.0;
uniform float zoom = 1.0;
void fragment(){
	vec2 uv = (UV - 0.5) / zoom + 0.5;
	vec4 c = texture(TEXTURE, uv);
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = mix(c.rgb, vec3(g) * 0.55, gray);
	float r = length(UV - 0.5) * 2.0;
	c.a *= 1.0 - smoothstep(0.93, 0.99, r);
	COLOR = c;
}"""
	map_sh = Shader.new()
	map_sh.code = """shader_type canvas_item;
uniform vec2 center = vec2(0.5);
uniform float span = 0.4;
void fragment(){
	vec2 uv = center + (UV - 0.5) * span;
	vec4 c = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) c = vec4(0.1, 0.12, 0.1, 1.0);
	float r = length(UV - 0.5) * 2.0;
	c.a *= 1.0 - smoothstep(0.95, 1.0, r);
	COLOR = c;
}"""

var skill_kind := ""
func refresh_skills() -> void:
	var k: String = Game.S.get("weapon_kind", "epee")
	if k == skill_kind or not icons.has("s0"): return
	skill_kind = k
	for i in 4: icons["s%d" % i].texture = T(Player.skills()[i].icon)

func icon_rect(tex_name: String, size: Vector2, zoom := 1.0) -> TextureRect:
	var t := TextureRect.new(); t.texture = T(tex_name); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = size; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new(); m.shader = circle_sh; m.set_shader_parameter("zoom", zoom); t.material = m
	root.add_child(t); return t

func setup(m: Node) -> void:
	main = m
	TX_DISC = _mk_circle(64, 0.0); TX_RING = _mk_circle(128, 0.955); TX_RING2 = _mk_circle(32, 0.72)
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	_make_theme()
	root.draw.connect(_draw_under)
	icons.portrait = icon_rect("sk_dual_swords", Vector2(64, 64), 1.15)
	var gp := PanelContainer.new(); gp.add_theme_stylebox_override("panel", flat(Color(0.05, 0.07, 0.1, 0.62), 14, Color(0.95, 0.78, 0.45, 0.25), 1, Vector4(14, 8, 14, 10)))
	gp.position = Vector2(12, 92); gp.custom_minimum_size = Vector2(380, 0); gp.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(gp)
	var qv := VBoxContainer.new(); qv.add_theme_constant_override("separation", 2); gp.add_child(qv)
	var qh := _label("QUÊTE", 14, GOLD); qh.add_theme_font_override("font", f_title); qv.add_child(qh)
	goal_lbl = RichTextLabel.new(); goal_lbl.bbcode_enabled = true; goal_lbl.fit_content = true; goal_lbl.scroll_active = false
	goal_lbl.add_theme_font_size_override("normal_font_size", 17); goal_lbl.add_theme_font_size_override("bold_font_size", 18)
	goal_lbl.custom_minimum_size = Vector2(352, 0); goal_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; qv.add_child(goal_lbl)
	hint_lbl = RichTextLabel.new(); hint_lbl.bbcode_enabled = true; hint_lbl.fit_content = true; hint_lbl.scroll_active = false
	hint_lbl.add_theme_font_size_override("normal_font_size", 18); hint_lbl.add_theme_constant_override("outline_size", 6); hint_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_lbl.custom_minimum_size = Vector2(520, 0); hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hint_lbl)
	toasts = VBoxContainer.new(); toasts.custom_minimum_size = Vector2(560, 0); toasts.alignment = BoxContainer.ALIGNMENT_CENTER; toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(toasts)
	minimap = TextureRect.new(); minimap.size = Vector2(176, 176); minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mm := ShaderMaterial.new(); mm.shader = map_sh; minimap.material = mm; root.add_child(minimap)
	region_lbl = _label("", 15, SOFT); region_lbl.add_theme_font_override("font", f_title); region_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; region_lbl.size = Vector2(220, 22); root.add_child(region_lbl)
	for i in 4: icons["s%d" % i] = icon_rect(Player.skills()[i].icon, Vector2(70, 70), 1.12)
	icons.attack = icon_rect("sk_sword_bash_orange", Vector2(96, 96), 1.1)
	icons.bag = icon_rect("it_loot_common", Vector2(50, 50), 0.9)
	overlay = Control.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.draw.connect(_draw_over); root.add_child(overlay)
	red = ColorRect.new(); red.color = Color(0.8, 0, 0, 0.0); red.set_anchors_preset(Control.PRESET_FULL_RECT); red.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(red)
	fps_lbl = _label("", 12, Color(0.8, 1, 0.8, 0.6)); root.add_child(fps_lbl)
	for n in ["main", "dodge", "s0", "s1", "s2", "s3", "potion", "mount", "bag", "menu", "zoom", "shop", "ile", "map"]: buttons[n] = {"rect": Rect2(), "held": false}
	get_viewport().size_changed.connect(_layout); _layout()

func build_map(img: Image) -> void:
	map_tex = ImageTexture.create_from_image(img); minimap.texture = map_tex

var map_origin := Vector2.ZERO
var map_ppm := 0.5
var map_offs := Vector2(26, 26)
func set_map_mode(img: Image, inst: bool, origin := Vector2.ZERO, ppm := 0.5, offs := Vector2(26, 26)) -> void:
	map_dungeon = inst; map_origin = origin; map_ppm = ppm; map_offs = offs; build_map(img)

# position monde → coordonnées de texture de carte (0..1) ; mètres couverts par la texture
func map_uv(p: Vector2) -> Vector2:
	if map_dungeon: return (map_offs + (p - map_origin) * map_ppm) / 64.0
	return (p + Vector2(128, 128)) / 256.0
func map_meters() -> float: return 64.0 / map_ppm if map_dungeon else 256.0

func _label(t: String, size: int, c: Color) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85)); l.add_theme_constant_override("outline_size", 5); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func vs() -> Vector2: return root.get_viewport_rect().size

func _layout() -> void:
	var s := vs()
	icons.portrait.position = Vector2(14, 14)
	minimap.position = Vector2(s.x - 192, 14)
	region_lbl.position = Vector2(s.x - 214, 194)
	buttons.map.rect = Rect2(minimap.position, minimap.size)
	toasts.position = Vector2((s.x - 560) * 0.5, 64)
	fps_lbl.position = Vector2(s.x * 0.5 - 30, s.y - 18)
	mc = Vector2(s.x - 112, s.y - 112)
	buttons.main.rect = Rect2(mc - Vector2(72, 72), Vector2(144, 144))
	var angs := [168.0, 136.0, 104.0, 72.0]
	for i in 4:
		var a := deg_to_rad(angs[i]); var c := mc + Vector2(cos(a), -sin(a)) * 150.0
		buttons["s%d" % i].rect = Rect2(c - Vector2(37, 37), Vector2(74, 74))
		icons["s%d" % i].position = c - Vector2(35, 35)
	buttons.dodge.rect = Rect2(mc + Vector2(-158, 52) - Vector2(34, 34), Vector2(68, 68))
	buttons.potion.rect = Rect2(mc + Vector2(-248, 58) - Vector2(30, 30), Vector2(60, 60))
	buttons.mount.rect = Rect2(mc + Vector2(-248, -28) - Vector2(30, 30), Vector2(60, 60))
	buttons.bag.rect = Rect2(Vector2(s.x - 252, 20), Vector2(52, 52))
	buttons.menu.rect = Rect2(Vector2(s.x - 252, 80), Vector2(52, 52))
	buttons.zoom.rect = Rect2(Vector2(s.x - 252, 140), Vector2(52, 52))
	buttons.shop.rect = Rect2(Vector2(s.x - 252, 200), Vector2(52, 52))
	buttons.ile.rect = Rect2(Vector2(s.x - 252, 268), Vector2(52, 52))
	icons.bag.position = buttons.bag.rect.position + Vector2(1, 1)
	icons.attack.position = mc - Vector2(48, 48)
	hint_lbl.position = Vector2(s.x - 560 - 40, mc.y - 220)

func _input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed): drag_guard = false
	if panel_open and cur_panel != "bag": return
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position
		if ev.pressed:
			if panel_open:   # inventaire ouvert : seul le joystick (moitié gauche, hors fiche) reste actif
				if p.x < vs().x * 0.3 and not bag_card_rect.has_point(p) and joy.id == -1:
					joy.id = ev.index; joy.base = p; joy.pos = p; joy.vec = Vector2.ZERO; touches[ev.index] = "joy"
				return
			for n in buttons:
				var r: Rect2 = buttons[n].rect
				if r.size.x > 0 and p.distance_to(r.get_center()) < r.size.x * 0.5 + 10:
					touches[ev.index] = n; buttons[n].held = true; _press(n); get_viewport().set_input_as_handled(); return
			if p.x < vs().x * 0.5 and joy.id == -1:
				joy.id = ev.index; joy.base = p; joy.pos = p; joy.vec = Vector2.ZERO; touches[ev.index] = "joy"
		else:
			var role = touches.get(ev.index, "")
			if role == "joy": joy.id = -1; joy.vec = Vector2.ZERO
			elif role != "": buttons[role].held = false
			touches.erase(ev.index)
	elif ev is InputEventScreenDrag:
		if ev.index == joy.id:
			joy.pos = ev.position
			var d: Vector2 = joy.pos - joy.base; var r := 64.0
			if d.length() > r: joy.base += d.normalized() * (d.length() - r); d = d.normalized() * r
			joy.vec = d / r

func _press(n: String) -> void:
	match n:
		"dodge": main.player.dodge()
		"s0": main.player.use_skill(0)
		"s1": main.player.use_skill(1)
		"s2": main.player.use_skill(2)
		"s3": main.player.use_skill(3)
		"potion": main.player.drink()
		"mount": main.player.summon_mount()
		"bag": show_bag()
		"menu": show_menu()
		"zoom": main.cycle_zoom()
		"shop": show_boutique()
		"ile":
			if Game.S.island.owned:
				if main.island: main.leave_island()
				else: main.go_island()
		"map": show_map()

func move_vec() -> Vector2:
	var v := joy.vec as Vector2
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): k.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): k.x += 1
	if Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): k.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): k.y += 1
	if k.length() > 0: v = k.normalized()
	return v

func main_held() -> bool: return buttons.main.held or Input.is_key_pressed(KEY_SPACE)

# ——— Dessin regroupé : cercles et anneaux en textures, textes à la fin → très peu d'appels de dessin ———
var TX_DISC: ImageTexture
var TX_RING: ImageTexture
var TX_RING2: ImageTexture
var q_disc: Array = []
var q_ring: Array = []
var q_tex: Array = []
var q_txt: Array = []
func _mk_circle(size: int, inner: float) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			var a: float = clamp((1.0 - d) * size * 0.5, 0.0, 1.0)
			if inner > 0.0: a = min(a, clamp((d - inner) * size * 0.5, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
func _disc(ctr: Vector2, r: float, col: Color) -> void: q_disc.append([Rect2(ctr - Vector2(r, r), Vector2(r, r) * 2.0), col])
func _ringq(ctr: Vector2, r: float, col: Color) -> void: q_ring.append([Rect2(ctr - Vector2(r, r), Vector2(r, r) * 2.0), col, r < 16.0])
func _texq(t: Texture2D, rect: Rect2, col := Color.WHITE) -> void: q_tex.append([t, rect, col])
func _flush(c: CanvasItem) -> void:
	for d in q_disc: c.draw_texture_rect(TX_DISC, d[0], false, d[1])
	for d in q_ring:
		if not d[2]: c.draw_texture_rect(TX_RING, d[0], false, d[1])
	for d in q_ring:
		if d[2]: c.draw_texture_rect(TX_RING2, d[0], false, d[1])
	for d in q_tex: c.draw_texture_rect(d[0], d[1], false, d[2])
	for d in q_txt: c.draw_string_outline(d[0], d[1], d[2], HORIZONTAL_ALIGNMENT_LEFT, -1, d[3], 5, Color(0, 0, 0, 0.85))
	for d in q_txt: c.draw_string(d[0], d[1], d[2], HORIZONTAL_ALIGNMENT_LEFT, -1, d[3], d[4])
	q_disc.clear(); q_ring.clear(); q_tex.clear(); q_txt.clear()

func _glass(c: CanvasItem, ctr: Vector2, r: float, ring: Color, held := false) -> void:
	_disc(ctr, r, Color(0.04, 0.06, 0.09, 0.55 if not held else 0.78))
	_ringq(ctr, r, ring)

func _draw_under() -> void:
	var c := root
	batch_text = true
	if joy.id != -1:
		_disc(joy.base, 70, Color(0.04, 0.06, 0.09, 0.28)); _ringq(joy.base, 70, Color(1, 0.9, 0.7, 0.4))
		_disc(joy.base + joy.vec * 64.0, 30, Color(1, 0.93, 0.8, 0.75))
	else:
		var hp := Vector2(140, vs().y - 140)
		_ringq(hp, 64, Color(1, 1, 1, 0.14)); _disc(hp, 26, Color(1, 1, 1, 0.08))
	var P: Player = main.player
	_glass(c, mc, 72, main_col if main_mode != "attack" else Color(0.95, 0.78, 0.45, 0.8), buttons.main.held)
	for i in 4: _glass(c, buttons["s%d" % i].rect.get_center(), 37, Color(0.95, 0.78, 0.45, 0.55), buttons["s%d" % i].held)
	_glass(c, buttons.dodge.rect.get_center(), 34, Color(0.6, 0.85, 1.0, 0.6), buttons.dodge.held)
	_glass(c, buttons.potion.rect.get_center(), 30, Color(0.5, 1.0, 0.6, 0.6), buttons.potion.held)
	_glass(c, buttons.mount.rect.get_center(), 30, Color(0.95, 0.78, 0.45, 0.6) if not P.mounted else Color(0.6, 0.9, 1.0, 0.9), buttons.mount.held)
	_glass(c, buttons.bag.rect.get_center(), 26, Color(0.95, 0.78, 0.45, 0.5))
	_glass(c, buttons.menu.rect.get_center(), 26, Color(0.95, 0.78, 0.45, 0.5))
	var shc: Vector2 = buttons.shop.rect.get_center()
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
	_glass(c, shc, 26, Color(1.0, 0.7, 0.2, pulse))
	_texq(T("it_chest_open"), Rect2(shc - Vector2(19, 21), Vector2(38, 38)))
	_text(c, "BOUTIQUE", shc + Vector2(0, 40), 11, Color("#ffcf5a"), true, f_title)
	if Game.S.island.owned:
		var ic2: Vector2 = buttons.ile.rect.get_center()
		var danger: bool = main.raid_active()
		var pz := 0.6 + 0.4 * sin(Time.get_ticks_msec() * (0.012 if danger else 0.003))
		_glass(c, ic2, 26, Color(1.0, 0.25, 0.2, pz) if danger else Color(0.4, 0.8, 1.0, 0.7))
		_texq(T("it_treasure_map"), Rect2(ic2 - Vector2(18, 20), Vector2(36, 36)))
		_text(c, "RAID !" if danger else ("RETOUR" if main.island else "MON ÎLE"), ic2 + Vector2(0, 40), 11, Color("#ff7a6a") if danger else Color("#9fd4ff"), true, f_title)
	if main.island and main.island.raid_on:
		var gtxt := "Bandits : %d / 10 groupes" % main.island.groups_cleared()
		c.draw_style_box(flat(Color(0.25, 0.03, 0.03, 0.85), 12, Color("#ff5a4a"), 2), Rect2(12, 300, 260, 42))
		_text(c, gtxt, Vector2(142, 328), 19, Color("#ffd2c8"), true, f_title)
	var zc: Vector2 = buttons.zoom.rect.get_center()
	_glass(c, zc, 26, Color(0.95, 0.78, 0.45, 0.5))
	_ringq(zc + Vector2(-3, -3), 10, SOFT); c.draw_line(zc + Vector2(4, 4), zc + Vector2(11, 11), SOFT, 3.0, true)
	_text(c, {1.0: "1x", 1.3: "−", 0.8: "+"}.get(main.user_zoom, ""), zc + Vector2(-3, 1), 11, GOLD)
	_disc(Vector2(46, 46), 35, Color(0.04, 0.06, 0.09, 0.6))
	var bar := Rect2(86, 22, 230, 20)
	c.draw_style_box(flat(Color(0.03, 0.04, 0.06, 0.7), 10), bar.grow(3))
	var f: float = clamp(P.hp / P.max_hp, 0.0, 1.0)
	if f > 0.01: c.draw_style_box(flat(Color("#d9483a") if f > 0.3 else Color("#ff3b2f"), 9), Rect2(bar.position, Vector2(max(18.0, bar.size.x * f), bar.size.y)))
	if P.shield_hp > 0.0: c.draw_style_box(flat(Color(0.6, 0.9, 1.0, 0.55), 9), Rect2(bar.position, Vector2(max(18.0, bar.size.x * clamp(P.shield_hp / P.max_hp, 0.0, 1.0)), bar.size.y)))
	_text(c, "%d / %d" % [int(max(0, P.hp)), int(P.max_hp)], bar.get_center() + Vector2(0, 6), 15, Color.WHITE, true)
	_texq(T("it_coins"), Rect2(88, 48, 26, 26))
	_text(c, Game.fmt(Game.S.silver), Vector2(120, 68), 21, GOLD, false, f_title)
	_disc(minimap.position + minimap.size * 0.5, 92, Color(0.04, 0.06, 0.09, 0.6))
	_flush(c); batch_text = false

var batch_text := false
func _text(c: CanvasItem, t: String, pos: Vector2, size: int, col: Color, center := true, font: Font = null) -> void:
	var f: Font = font if font else ThemeDB.fallback_font
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := pos - Vector2(w * 0.5 if center else 0.0, 0)
	if batch_text: q_txt.append([f, p, t, size, col]); return
	c.draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.85))
	c.draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _pie(c: CanvasItem, ctr: Vector2, r: float, frac: float) -> void:
	if frac <= 0.0: return
	var pts := PackedVector2Array([ctr])
	for k in 33:
		var a := -PI / 2 + TAU * frac * float(k) / 32.0
		pts.append(ctr + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, Color(0, 0, 0, 0.6))

func _draw_over() -> void:
	var c := overlay; var P: Player = main.player
	batch_text = true
	icons.attack.visible = main_mode == "attack"
	if main_mode != "attack":
		_text(c, main_text, mc + Vector2(0, 8), 24 if main_text.length() < 8 else 19, main_col.lightened(0.25), true, f_title)
	else:
		_text(c, "ATTAQUE", mc + Vector2(0, 64), 15, GOLD, true, f_title)
	for i in 4:
		var sk: Dictionary = Player.skills()[i]; var ctr: Vector2 = buttons["s%d" % i].rect.get_center()
		var unlocked: bool = Game.S.gear.epee >= sk.req
		icons["s%d" % i].material.set_shader_parameter("gray", 0.0 if unlocked else 1.0)
		if not unlocked:
			_texq(T("ic_lock"), Rect2(ctr - Vector2(14, 16), Vector2(28, 28)))
			_text(c, "Arme T%d" % sk.req, ctr + Vector2(0, 30), 12, Color("#ffcf9a"))
		else:
			var cd: float = P.skill_cd[i]
			if cd > 0.0:
				_pie(c, ctr, 34, cd / sk.cd)
				_text(c, str(ceili(cd)), ctr + Vector2(0, 10), 26, Color.WHITE, true, f_title)
	var dc: Vector2 = buttons.dodge.rect.get_center()
	_texq(T("ic_ffwd"), Rect2(dc - Vector2(18, 18), Vector2(36, 36)), Color(0.75, 0.92, 1.0))
	_pie(c, dc, 32, P.dodge_cd / 1.0)
	var pc: Vector2 = buttons.potion.rect.get_center()
	_texq(T("ic_plus"), Rect2(pc - Vector2(15, 15), Vector2(30, 30)), Color(0.6, 1.0, 0.65))
	_pie(c, pc, 28, P.potion_cd / 8.0)
	_text(c, "×%d" % Game.S.potions, pc + Vector2(18, 30), 14, Color("#bfffc8"))
	# monture : icône, progression de l'invocation (1,75 s)
	var mc2: Vector2 = buttons.mount.rect.get_center()
	var mk: String = Game.S.get("mount_kind", "")
	var mtx: Texture2D = main.icons.get_icon("mount_" + mk) if Game.S.gear.get("monture", 0) > 0 else null
	if mtx: _texq(mtx, Rect2(mc2 - Vector2(26, 26), Vector2(52, 52)))
	else: _text(c, "—", mc2 + Vector2(0, 8), 22, Color(1, 1, 1, 0.4))
	_text(c, "DESCENDRE" if P.mounted else "MONTURE", mc2 + Vector2(0, 44), 11, GOLD, true, f_title)
	if P.cast_t > 0.0:
		_pie(c, mc2, 28, P.cast_t / Player.CAST)
		var bar := Rect2(vs().x * 0.5 - 140, vs().y * 0.62, 280, 16)
		c.draw_style_box(flat(Color(0.03, 0.04, 0.06, 0.8), 8), bar.grow(3))
		c.draw_style_box(flat(Color("#7fc0ff"), 7), Rect2(bar.position, Vector2(max(14.0, bar.size.x * (1.0 - P.cast_t / Player.CAST)), bar.size.y)))
		_text(c, "Invocation de la monture… %.1f s" % P.cast_t, bar.position + Vector2(140, -8), 16, Color("#cfe8ff"), true, f_title)
	var gc: Vector2 = buttons.menu.rect.get_center()
	_texq(T("ic_gear"), Rect2(gc - Vector2(15, 15), Vector2(30, 30)))
	_target_frame(c)
	_minimap_marks(c)

# Cadre de cible en haut de l'écran : qui tu combats (joueur JcJ ou boss), sa vie
var _sb_tf: StyleBoxFlat
var _sb_tb: StyleBoxFlat
var _sb_tfill: StyleBoxFlat
func _target_frame(c: CanvasItem) -> void:
	var tg = null
	var pt = main.pvp_target
	if pt != null and is_instance_valid(pt) and not pt.dead: tg = pt
	else:
		var b = main.boss_ref
		if b != null and is_instance_valid(b) and not b.dead and b.state != "idle": tg = b
	if tg == null: return
	if _sb_tf == null:
		_sb_tf = flat(Color(0.04, 0.05, 0.08, 0.82), 12, Color(1, 1, 1, 0.15), 2, Vector4(0, 0, 0, 0))
		_sb_tb = flat(Color(0.12, 0.08, 0.08, 0.95), 6); _sb_tfill = flat(Color("#e8452f"), 6)
	var is_pl: bool = tg is Bot
	var w := 380.0; var x := vs().x * 0.5 - w * 0.5; var y := 10.0
	_sb_tf.border_color = Color("#ff4a3a") if is_pl else Color("#d58bff")
	c.draw_style_box(_sb_tf, Rect2(x, y, w, 62))
	var nm: String = (tg.nm if is_pl else tg.def.name)
	var sub: String = ("JOUEUR JcJ · T%d" % tg.tier) if is_pl else ("Boss · T%d" % tg.tier)
	_text(c, nm, Vector2(x + 14, y + 24), 20, Color.WHITE, false, f_title)
	_text(c, sub, Vector2(x + w - 14 - sub.length() * 8.0, y + 24), 14, Color("#ff9a8a") if is_pl else Color("#e3b8ff"), false)
	var bar := Rect2(x + 12, y + 36, w - 24, 16)
	c.draw_style_box(_sb_tb, bar)
	var r: float = clamp(tg.hp / tg.max_hp, 0.0, 1.0)
	_sb_tfill.bg_color = Color("#e8452f") if is_pl else Color("#b04dff")
	if r > 0.01: c.draw_style_box(_sb_tfill, Rect2(bar.position, Vector2(max(12.0, bar.size.x * r), bar.size.y)))
	_text(c, "%d / %d" % [int(tg.hp), int(tg.max_hp)], bar.get_center() + Vector2(0, 6), 13, Color.WHITE, true)

# écran de chargement (changement de carte)
func loading(txt: String) -> void:
	var l := ColorRect.new(); l.color = Color(0.03, 0.04, 0.06, 1.0); l.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(l)
	var lb := _label(txt, 34, GOLD); lb.add_theme_font_override("font", f_title); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.set_anchors_preset(Control.PRESET_CENTER); lb.position = vs() * 0.5 - Vector2(400, 20); lb.custom_minimum_size = Vector2(800, 40); l.add_child(lb)

# Vignette rouge sur les bords de l'écran dans les zones dangereuses (T3+)
var danger_rect: TextureRect
func set_danger(k: float) -> void:
	if danger_rect == null:
		if k < 0.01: return
		var g := Gradient.new(); g.set_color(0, Color(0.6, 0.0, 0.0, 0.0)); g.set_color(1, Color(0.55, 0.0, 0.0, 0.85)); g.add_point(0.6, Color(0.6, 0.0, 0.0, 0.0))
		var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.5); gt.fill_to = Vector2(1.05, 1.05); gt.width = 128; gt.height = 128
		danger_rect = TextureRect.new(); danger_rect.texture = gt; danger_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; danger_rect.stretch_mode = TextureRect.STRETCH_SCALE
		danger_rect.set_anchors_preset(Control.PRESET_FULL_RECT); danger_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(danger_rect); root.move_child(danger_rect, 0)
	danger_rect.visible = k > 0.01
	danger_rect.modulate.a = k * (0.42 + 0.08 * sin(Time.get_ticks_msec() * 0.002))

func pvp_alert(b) -> void:
	region_banner("ATTAQUE JcJ !", b.tier, "%s (joueur T%d) veut ton équipement — bats-le ou fuis !" % [b.nm, b.tier])
	toast("S'il gagne, il te prend une pièce d'équipement. Esquive ses cercles et sa charge (ligne rouge).", Color("#ff9a7a"))
	Game.play("roar", -8.0, 1.5)

func _minimap_marks(c: CanvasItem) -> void:
	if map_tex == null: return
	var P: Player = main.player; var ctr := minimap.position + minimap.size * 0.5
	var span := 0.42; var k := minimap.size.x / (span * map_meters())
	var pp := Vector2(P.global_position.x, P.global_position.z)
	minimap.material.set_shader_parameter("center", map_uv(pp))
	minimap.material.set_shader_parameter("span", span)
	var R := minimap.size.x * 0.5 - 4
	# panneaux directionnels : les passages vers les autres cartes, même hors du cadre
	if not map_dungeon:
		for g in main.world.gates:
			var dq: Vector2 = (Vector2(g.pos.x, g.pos.z) - pp) * k
			var inside := dq.length() < R - 10.0
			var qg: Vector2 = ctr + (dq if inside else dq.normalized() * (R - 10.0))
			var cg: Color = Game.TIER_COL[Maps.TIERS[g.to][1]]
			_disc(qg, 8.0, Color(0, 0, 0, 0.75)); _disc(qg, 6.0, cg)
			_text(c, "T%d-T%d" % [Maps.TIERS[g.to][0], Maps.TIERS[g.to][1]], qg + Vector2(0, -10 if qg.y > ctr.y else 22), 12, cg.lightened(0.35), true, f_title)
	for e in main.enemies:
		if e.dead: continue
		var q: Vector2 = ctr + (Vector2(e.global_position.x, e.global_position.z) - pp) * k
		if q.distance_to(ctr) < R: _disc(q, 2.6 if not e.elite else 3.6, Color("#ff5a4a") if not e.elite else Color("#ffc940"))
	for n in main.npcs:
		if n.hidden: continue
		var q2: Vector2 = ctr + (Vector2(n.position.x, n.position.z) - pp) * k
		if q2.distance_to(ctr) < R: _disc(q2, 3.0 if n.act != "duel" else 4.0, Color("#7fd0ff") if n.act != "duel" else Color("#ff8a4a"))
	for bt in main.bots:
		if not is_instance_valid(bt) or bt.dead or not bt.visible: continue
		var qb2: Vector2 = ctr + (Vector2(bt.global_position.x, bt.global_position.z) - pp) * k
		if qb2.distance_to(ctr) < R: _disc(qb2, 3.2, Color.WHITE if bt.mode != "pvp" else Color("#ff3b2f")); _ringq(qb2, 3.8, Color(0, 0, 0, 0.6))
	for a in main.allies:
		if not is_instance_valid(a) or a.dead: continue
		var qa: Vector2 = ctr + (Vector2(a.global_position.x, a.global_position.z) - pp) * k
		if qa.distance_to(ctr) < R: _disc(qa, 3.2, Color("#5dff7a"))
	for en in main.dungeon_entries:
		var qe: Vector2 = ctr + (Vector2(en.pos.x, en.pos.z) - pp) * k
		if qe.distance_to(ctr) < R: _disc(qe, 5.0, Color("#b46bff")); _ringq(qe, 6.5, Color.WHITE)
	var wb = main.world_boss
	if wb and is_instance_valid(wb) and not wb.dead:
		var qb: Vector2 = ctr + (Vector2(wb.global_position.x, wb.global_position.z) - pp) * k
		if qb.distance_to(ctr) > R - 8: qb = ctr + (qb - ctr).normalized() * (R - 8)
		_disc(qb, 6.5, Color("#d58bff")); _ringq(qb, 8.5, Color(0.2, 0, 0.3))
	if main.in_instance(): pass
	else: _poi_marks(c, ctr, pp, k, R)
	var tg = main.goal_target
	if tg != null and not main.in_instance():
		var tq: Vector2 = ctr + (Vector2(tg.x, tg.z) - pp) * k
		if tq.distance_to(ctr) > R - 6: tq = ctr + (tq - ctr).normalized() * (R - 6)
		_ringq(tq, 6, Color("#ffd24a"))
	_mini_tail(c, ctr, P)
	_flush(c); batch_text = false

func _poi_marks(c: CanvasItem, ctr: Vector2, pp: Vector2, k: float, R: float) -> void:
	for poi in main.world.pois:
		var q3: Vector2 = ctr + (Vector2(poi.pos.x, poi.pos.z) - pp) * k
		if q3.distance_to(ctr) < R:
			_disc(q3, 4.0, Color("#ffe39a") if Game.S.disc.has(poi.id) else Color(1, 1, 1, 0.35))

func _mini_tail(c: CanvasItem, ctr: Vector2, P: Player) -> void:
	var y: float = P.yaw; var fwd := Vector2(sin(y), cos(y)); var rt := Vector2(fwd.y, -fwd.x)
	c.draw_colored_polygon(PackedVector2Array([ctr + fwd * 9, ctr - fwd * 6 + rt * 6, ctr - fwd * 6 - rt * 6]), Color.WHITE)
	_ringq(ctr, minimap.size.x * 0.5, Color(0.95, 0.78, 0.45, 0.85))
	_disc(region_lbl.position + Vector2(10, 12), 5, region_dot)

func update(_dt: float) -> void:
	fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	root.queue_redraw(); overlay.queue_redraw()

func set_main(mode: String, txt: String, col: Color, icon := "skull") -> void:
	main_mode = mode; main_text = txt; main_col = col; main_icon = icon

func set_region(name: String, tier: int) -> void:
	region_lbl.text = "%s · T%d" % [name, tier]; region_dot = Game.TIER_COL[tier]

func toast(t: String, col := SOFT, big := false) -> void:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", flat(Color(0.05, 0.07, 0.1, 0.7), 20, Color(1, 1, 1, 0.08), 1, Vector4(18, 6, 18, 8)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := _label(t, 19 if big else 16, col); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if big: l.add_theme_font_override("font", f_title)
	p.add_child(l); toasts.add_child(p)
	while toasts.get_child_count() > 3: toasts.get_child(0).free()
	p.modulate.a = 0.0
	var tw := p.create_tween(); tw.tween_property(p, "modulate:a", 1.0, 0.2); tw.tween_interval(2.6 if not big else 3.4); tw.tween_property(p, "modulate:a", 0.0, 0.5); tw.tween_callback(p.queue_free)

# ——— Barre d'XP de métier (apparaît 10 s sous la quête) ———
var prof_box: PanelContainer
var prof_tw: Tween
var prof_fill: ColorRect
var prof_lbl: RichTextLabel
var prof_ic: TextureRect
func prof_gain(tool: String, xp: int) -> void:
	var p := Game.prof(tool)
	_xp_show(main.icons.get_icon(tool), Game.TOOL_NAME[tool], int(p.lvl), int(p.xp), Game.prof_need(int(p.lvl)), xp, int(p.lvl) >= Game.PROF_MAX, "")

func weapon_gain(kind: String, xp: int) -> void:
	var w := Game.wxp(kind)
	var tx: Texture2D = main.icons.item_icon({"slot": "epee", "tier": max(1, Game.S.gear.epee), "kind": kind})
	_xp_show(tx, Game.WEAPON_KINDS[kind].name, int(w.lvl), int(w.xp), Game.weapon_need(int(w.lvl)), xp, int(w.lvl) >= Game.WXP_MAX, "  [color=#ffb07a]+%s %%[/color]" % ("%.1f" % (Game.weapon_bonus() * 100.0)).replace(".", ","))

func _xp_show(tex_: Texture2D, title_txt: String, lvl: int, cur: int, need: int, xp: int, maxed: bool, extra: String) -> void:
	if prof_box == null:
		prof_box = PanelContainer.new(); prof_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prof_box.add_theme_stylebox_override("panel", flat(Color(0.05, 0.07, 0.1, 0.72), 14, Color(0.95, 0.78, 0.45, 0.35), 1, Vector4(10, 6, 12, 8)))
		prof_box.position = Vector2(12, 222); prof_box.custom_minimum_size = Vector2(300, 0); root.add_child(prof_box)
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); h.mouse_filter = Control.MOUSE_FILTER_IGNORE; prof_box.add_child(h)
		prof_ic = TextureRect.new(); prof_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; prof_ic.custom_minimum_size = Vector2(44, 44); prof_ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(prof_ic)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(v)
		prof_lbl = RichTextLabel.new(); prof_lbl.bbcode_enabled = true; prof_lbl.fit_content = true; prof_lbl.scroll_active = false; prof_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prof_lbl.add_theme_font_size_override("normal_font_size", 16); prof_lbl.add_theme_font_size_override("bold_font_size", 17); prof_lbl.custom_minimum_size = Vector2(340, 0); prof_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF; v.add_child(prof_lbl)
		var bg := ColorRect.new(); bg.color = Color(0, 0, 0, 0.55); bg.custom_minimum_size = Vector2(230, 10); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(bg)
		prof_fill = ColorRect.new(); prof_fill.color = Color("#f2c35a"); prof_fill.size = Vector2(0, 10); prof_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; bg.add_child(prof_fill)
	prof_ic.texture = tex_
	prof_lbl.text = "[b]%s niv %d[/b]   [color=#9dffb0]+%d xp[/color]   [color=#a8b4bc]%s[/color]%s" % [title_txt, lvl, xp, "max" if maxed else "%d / %d" % [cur, need], extra]
	var w: float = 230.0 * (1.0 if maxed else clamp(float(cur) / need, 0.0, 1.0))
	create_tween().tween_property(prof_fill, "size:x", w, 0.25)
	prof_box.visible = true; prof_box.modulate.a = 1.0
	if prof_tw: prof_tw.kill()
	prof_tw = prof_box.create_tween(); prof_tw.tween_interval(10.0); prof_tw.tween_property(prof_box, "modulate:a", 0.0, 0.8)

func hurt_flash() -> void:
	red.color.a = 0.22; create_tween().tween_property(red, "color:a", 0.0, 0.35)

func celebrate(title_txt: String, sub: String, icon := "it_quest") -> void:
	var b := PanelContainer.new(); b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("panel", flat(Color(0.08, 0.1, 0.14, 0.88), 24, Color(0.95, 0.78, 0.45, 0.8), 2, Vector4(20, 10, 28, 12), 10))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); b.add_child(h)
	var ic := TextureRect.new(); ic.texture = T(icon); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.custom_minimum_size = Vector2(58, 58); h.add_child(ic)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(v)
	var a := _label(title_txt, 26, GOLD); a.add_theme_font_override("font", f_title); v.add_child(a)
	v.add_child(_label(sub, 17, SOFT))
	root.add_child(b); b.reset_size()
	b.position = Vector2((vs().x - b.size.x) * 0.5, -110.0)
	var tw := b.create_tween()
	tw.tween_property(b, "position:y", 90.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.3); tw.tween_property(b, "modulate:a", 0.0, 0.5); tw.tween_callback(b.queue_free)

var banner_node: Control
func region_banner(name: String, tier: int, sub := "") -> void:
	if banner_node and is_instance_valid(banner_node): banner_node.queue_free()
	var col: Color = Game.TIER_COL[tier]
	var v := VBoxContainer.new(); v.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.alignment = BoxContainer.ALIGNMENT_CENTER
	var a := _label(name, 44, SOFT); a.add_theme_font_override("font", f_title); a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; a.add_theme_constant_override("outline_size", 10); v.add_child(a)
	var warn := "Zone sûre — T1" if tier == 1 else "Attention : vous entrez en zone T%d" % tier
	if sub != "": warn = sub
	var b := _label(warn, 21, col); b.add_theme_font_override("font", f_title); b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; b.add_theme_constant_override("outline_size", 7); v.add_child(b)
	root.add_child(v); banner_node = v; v.reset_size(); v.position = Vector2((vs().x - v.size.x) * 0.5, vs().y * 0.26)
	v.modulate.a = 0.0
	var tw := v.create_tween(); tw.tween_property(v, "modulate:a", 1.0, 0.5); tw.tween_interval(2.4); tw.tween_property(v, "modulate:a", 0.0, 0.8); tw.tween_callback(v.queue_free)

# ——— Fenêtres ———
var last_build: Callable
var last_w := 860.0
var last_h := -1.0
func refresh_panel() -> void:
	if cur_panel == "bag": show_bag(); return
	if panel_open and panel and is_instance_valid(panel) and last_build.is_valid() and cur_panel != "": open_panel(panel_title, last_build, last_w, last_h)

func open_panel(title_txt: String, build: Callable, w := 860.0, h := -1.0) -> void:
	close_panel()
	last_build = build; last_w = w; last_h = h
	panel_open = true
	for n in buttons: buttons[n].held = false
	joy.id = -1; joy.vec = Vector2.ZERO; touches.clear()
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim); panel_extra.append(dim)
	var s := vs(); var hh: float = s.y - 60 if h < 0 else h
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", flat(Color(0.06, 0.08, 0.12, 0.94), 22, Color(0.95, 0.78, 0.45, 0.45), 2, Vector4(26, 16, 26, 18), 14))
	pc.position = Vector2((s.x - w) * 0.5, (s.y - hh) * 0.5); pc.custom_minimum_size = Vector2(w, hh); pc.size = pc.custom_minimum_size; root.add_child(pc); panel = pc
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 10); pc.add_child(vb)
	var top := HBoxContainer.new(); vb.add_child(top)
	var tl := _label(title_txt, 30, GOLD); tl.add_theme_font_override("font", f_title); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tl)
	var x := Button.new(); x.text = "✕"; x.custom_minimum_size = Vector2(54, 50); x.add_theme_font_override("font", ThemeDB.fallback_font); x.add_theme_font_size_override("font_size", 24); x.pressed.connect(_x_close); top.add_child(x)
	var sep := ColorRect.new(); sep.color = Color(0.95, 0.78, 0.45, 0.3); sep.custom_minimum_size = Vector2(0, 2); vb.add_child(sep)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; vb.add_child(sc)
	sc.scroll_deadzone = 10; sc.scroll_started.connect(func(): drag_guard = true)
	var body := VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 10); sc.add_child(body)
	var keep: int = scroll_mem.get(title_txt, 0) if title_txt == panel_title else 0
	panel_title = title_txt; cur_scroll = sc
	build.call(body)
	_touch_scroll(body)
	sc.scroll_vertical = keep
	if keep > 0: (func(): if is_instance_valid(sc): sc.scroll_vertical = keep).call_deferred()

# Défilement au doigt : les éléments laissent passer le glissé jusqu'au ScrollContainer,
# et un bouton n'est pas déclenché si le doigt a fait défiler la liste.
func _touch_scroll(n: Node) -> void:
	if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP: (n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	if n is BaseButton:
		var b := n as BaseButton
		for c in b.pressed.get_connections():
			var cb: Callable = c.callable; b.pressed.disconnect(cb); b.pressed.connect(_guarded.bind(cb))
	for ch in n.get_children(): _touch_scroll(ch)

func _guarded(cb: Callable) -> void:
	if drag_guard: return
	cb.call()

# Fermer un coffre sans tout prendre : le reste tombe au sol dans un sac (rien n'est perdu)
var loot_cur: Dictionary = {}
func _x_close() -> void:
	if cur_panel == "loot" and not loot_cur.is_empty() and not loot_cur.get("bag", false) and not loot_cur.has("beam") and not loot_cur.loot.is_empty():
		var pp: Vector3 = main.player.global_position
		main.drop_loot(pp, "elite", 1, loot_cur.loot.duplicate()); loot_cur.loot.clear()
		toast("Le reste du butin est posé au sol à côté de toi", Color("#ffe39a"))
	close_panel()

func close_panel() -> void:
	if cur_scroll and is_instance_valid(cur_scroll):
		scroll_mem[panel_title] = cur_scroll.scroll_vertical
		if cur_panel == "bag": bag_scroll = cur_scroll.scroll_vertical
	cur_scroll = null
	cur_panel = ""
	if panel and is_instance_valid(panel): panel.queue_free()
	for d in panel_extra:
		if is_instance_valid(d): d.queue_free()
	panel_extra.clear()
	panel = null; panel_open = false; bag_card_rect = Rect2()

func tier_tag(t: int) -> String:
	if t <= 0: return "[color=#8a9298]aucun[/color]"
	return "[color=#%s]T%d[/color]" % [Game.TIER_COL[t].to_html(false), t]
func res_text(k: String, t: int) -> String: return "[color=#%s]%s T%d[/color]" % [Game.TIER_COL[t].to_html(false), Game.RES[k].name, t]

func rich(t: String, size := 19) -> RichTextLabel:
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.scroll_active = false; r.text = t
	r.add_theme_font_size_override("normal_font_size", size); r.add_theme_font_size_override("bold_font_size", size + 1); r.add_theme_font_size_override("italics_font_size", size)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r

func big_button(t: String, enabled: bool, cb: Callable, col := GOLD, highlight := false) -> Button:
	var b := Button.new(); b.text = t; b.disabled = not enabled; b.custom_minimum_size = Vector2(190, 54)
	if enabled and highlight: b.add_theme_stylebox_override("normal", flat(Color("#3f8a5c"), 14, Color(0.95, 0.85, 0.5, 0.8), 2, Vector4(22, 10, 22, 12)))
	if col != GOLD: b.add_theme_color_override("font_color", col)
	b.pressed.connect(cb); return b

func row(parent: Control, left: Control, right: Control) -> void:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.05), 14, Color(1, 1, 1, 0.08), 1, Vector4(16, 10, 12, 10)))
	parent.add_child(p)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); p.add_child(h); h.add_child(left); right.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(right)

func show_forge(greet := "") -> void:
	show_armurier("craft")

# ——— Marchands d'outils (Bjorn, Gorm, Sylve) ———
func show_tools(tool: String) -> void:
	open_panel(Game.VENDOR_NAME[tool], func(body: VBoxContainer):
		cur_panel = "tools"
		var p := Game.prof(tool); var lv: int = p.lvl
		var cur := Game.equipped_item(tool)
		var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 14); body.add_child(head)
		head.add_child(slot_box(main.icons.get_icon(tool), int(cur.tier), 1, true, Callable(), 76))
		var need := Game.prof_need(lv)
		head.add_child(rich("[b]Ton outil : [color=%s]%s[/color][/b]\n%s niveau [b]%d[/b]  [color=#a8b4bc](%d / %d xp)[/color]   ·   ta bourse : [color=#ffd86b]%s[/color]\n[color=#a8b4bc]Le [b]tier[/b] se débloque avec ton niveau de métier. La [b]qualité[/b] rend l'outil plus rapide et donne des récoltes doubles.[/color]" % [Game.TOOL_Q[Game.toolq(tool)].col, Game.item_name(cur), Game.PROF_TITLE[tool], lv, p.xp, need, Game.fmt(Game.S.silver)], 17))
		# en-tête des qualités
		var hq := HBoxContainer.new(); hq.add_theme_constant_override("separation", 8); body.add_child(hq)
		var sp0 := Control.new(); sp0.custom_minimum_size = Vector2(150, 0); hq.add_child(sp0)
		for q in 4:
			var Q: Dictionary = Game.TOOL_Q[q]
			var l := rich("[center][b][color=%s]%s[/color][/b]\n[color=#a8b4bc]vitesse ×%s · double %d %%[/color][/center]" % [Q.col, Q.name, ("%.2f" % (1.0 / Q.speed)).replace(".", ","), int(Q.bonus * 100)], 14)
			l.custom_minimum_size = Vector2(220, 0); hq.add_child(l)
		for t in range(1, 6):
			var row_ := HBoxContainer.new(); row_.add_theme_constant_override("separation", 8)
			var pnl := PanelContainer.new(); pnl.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.04).lerp(Game.TIER_COL[t], 0.06), 12, Color(Game.TIER_COL[t].r, Game.TIER_COL[t].g, Game.TIER_COL[t].b, 0.35), 1, Vector4(10, 6, 10, 6))); pnl.add_child(row_); body.add_child(pnl)
			var left := HBoxContainer.new(); left.custom_minimum_size = Vector2(150, 0); left.add_theme_constant_override("separation", 8); row_.add_child(left)
			left.add_child(slot_box(main.icons.get_icon(tool), t, 1, false, Callable(), 54))
			var locked: bool = lv < Game.PROF_REQ[t]
			left.add_child(rich("[b]%s[/b]\n%s" % [hud_tier(t), ("[color=#ff8a7a]niv %d requis[/color]" % Game.PROF_REQ[t]) if locked else ("[color=#8dffa0]débloqué[/color]")], 15))
			for q in 4:
				var price := Game.tool_price(t, q); var owned: bool = int(cur.tier) == t and Game.toolq(tool) == q
				var txt: String = "✓ équipé" if owned else ("Bloqué" if locked else Game.fmt(price))
				var b := big_button(txt, not locked and not owned and Game.S.silver >= price, func(): main.buy_tool(tool, t, q), Color(Game.TOOL_Q[q].col).lightened(0.3), not locked and Game.S.silver >= price)
				b.custom_minimum_size = Vector2(220, 46); b.add_theme_font_size_override("font_size", 18); row_.add_child(b)
	, 1180)

func hud_tier(t: int) -> String: return "[color=#%s]%s T%d[/color]" % [Game.TIER_COL[t].to_html(false), ["", "Novice", "Apprenti", "Compagnon", "Adepte", "Expert"][t], t]

# ——— Brokk : boutique d'armes + artisanat ———
var arm_tab := "buy"
var arm_tier := 1
func show_armurier(tab := "") -> void:
	if tab != "": arm_tab = tab
	open_panel("Brokk — armurier & forge", func(body: VBoxContainer):
		cur_panel = "armurier"
		var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); body.add_child(tabs)
		_tab_btn(tabs, "Acheter", arm_tab == "buy", func(): show_armurier("buy"))
		_tab_btn(tabs, "Fabriquer", arm_tab == "craft", func(): show_armurier("craft"))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(sp)
		tabs.add_child(_price_box(Game.S.silver))
		var tiers := HBoxContainer.new(); tiers.add_theme_constant_override("separation", 6); body.add_child(tiers)
		tiers.add_child(_label("Tier :", 15, SOFT))
		for t in range(1, 6):
			var b := Button.new(); b.text = "T%d" % t; b.custom_minimum_size = Vector2(62, 38); b.add_theme_font_size_override("font_size", 17)
			var on := arm_tier == t; var col: Color = Game.TIER_COL[t]
			var st := flat(Color(col.r, col.g, col.b, 0.85) if on else Color(1, 1, 1, 0.06), 18, Color(col.r, col.g, col.b, 0.8), 2, Vector4(10, 3, 10, 5))
			b.add_theme_stylebox_override("normal", st); b.add_theme_stylebox_override("hover", st); b.add_theme_color_override("font_color", Color("#15100a") if on else col)
			b.pressed.connect(func(): arm_tier = t; show_armurier()); tiers.add_child(b)
		var t: int = arm_tier
		if arm_tab == "craft":
			body.add_child(rich("[color=#a8b4bc]Bois + minerai → armes et boucliers · fibre → robes et vestes. Les objets fabriqués vont dans ton sac : équipe-les… ou revends-les à l'hôtel des ventes. Plus le tier est haut, plus ils valent cher.[/color]", 15))
		var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10); body.add_child(grid)
		for ci in Game.CRAFTS.size():
			var c: Dictionary = Game.CRAFTS[ci]
			var it := Game.craft_item(c, t)
			var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.045), 14, Color(Game.TIER_COL[t].r, Game.TIER_COL[t].g, Game.TIER_COL[t].b, 0.4), 1, Vector4(10, 8, 10, 8)))
			var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); card.add_child(h)
			h.add_child(slot_box(main.icons.item_icon(it), t, 1, false, Callable(), 70))
			var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
			v.add_child(rich("[b][color=#%s]%s[/color][/b]  [color=#a8b4bc]valeur %s[/color]" % [Game.TIER_COL[t].to_html(false), Game.item_name(it), Game.fmt(Game.item_price(it))], 17))
			if t > Game.unlocked(c.slot) + 1:
				v.add_child(rich("[color=#ff8a7a]Verrouillé : porte d'abord %s T%d[/color]" % [Game.SLOT_ART[c.slot], t - 1], 15))
				var lb := big_button("Tier verrouillé", false, func(): Game.play("error")); lb.custom_minimum_size = Vector2(0, 42); v.add_child(lb)
			elif arm_tab == "craft":
				var cost := Game.craft_cost(c, t); var parts := []
				for k in cost:
					var have: int = Game.S.inv[k][t]
					parts.append("%s [color=%s]%d/%d[/color]" % [res_text(k, t), "#8dffa0" if have >= cost[k][1] else "#ff8a7a", have, cost[k][1]])
				v.add_child(rich("  ".join(parts), 15))
				var b := big_button("Fabriquer", Game.has_cost(cost), func(): main.craft_gear(ci, t), GOLD, true); b.custom_minimum_size = Vector2(0, 42); v.add_child(b)
			else:
				var price := int(Game.item_price(it) * 1.3)
				var b2 := big_button("Acheter · %s" % Game.fmt(price), Game.S.silver >= price, func(): main.buy_gear(it), GOLD, true); b2.custom_minimum_size = Vector2(0, 42); v.add_child(b2)
			grid.add_child(card)
	, 1100)

# Miniature de l'objet tel qu'il sortira de la forge
func _forge_icon(item: String, t: int, kind: String) -> Texture2D:
	var it := {"slot": item, "tier": max(1, t)}
	if kind != "": it["kind"] = kind
	var tx: Texture2D = main.icons.item_icon(it)
	if tx == null: tx = main.icons.get_icon(item)
	return _small(tx)

# icône réduite (pour les boutons)
var small_cache := {}
func _small(tx: Texture2D, size := 40) -> Texture2D:
	if tx == null: return null
	var key := "%d_%d" % [tx.get_instance_id(), size]
	if small_cache.has(key): return small_cache[key]
	var img := tx.get_image()
	if img == null: return tx
	img = img.duplicate(); if img.is_compressed(): img.decompress()
	img.resize(size, size, Image.INTERPOLATE_BILINEAR)
	var out := ImageTexture.create_from_image(img); small_cache[key] = out; return out

func _with_icon(tx: Texture2D, tier: int, right: Control) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(slot_box(tx, tier, 1, false, Callable(), 62))
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(right)
	return h

func show_shop(greet := "") -> void:
	open_panel("Marché", func(body: VBoxContainer):
		cur_panel = "shop"
		if greet != "": body.add_child(rich("[i][color=#d8c8a8]« %s »[/color][/i]" % greet, 18))
		body.add_child(rich("Ta bourse : [color=#ffd86b][b]%s[/b][/color] pièces" % Game.fmt(Game.S.silver), 20))
		row(body, _with_icon(main.icons.get_icon("potion"), 0, rich("[b]Potion de soin[/b] — rend 45 %% de la vie · [color=#ffd86b]40 pièces[/color] · tu en as %d" % Game.S.potions, 19)), big_button("Acheter", Game.S.silver >= 40, func(): main.buy_potion(), GOLD, true))
		var jn := 0; var jv := 0
		for it in Game.S.items:
			if it.slot == "junk": jn += 1; jv += Game.junk_price(it)
		if jn > 0: row(body, _with_icon(main.icons.get_icon("junk_os"), 0, rich("[b]Bric-à-brac[/b] ×%d — os, fioles, peaux… · [color=#ffd86b]%s pièces[/color] le tout" % [jn, Game.fmt(jv)], 19)), big_button("Tout vendre", true, func(): main.sell_junk(-1), GOLD, true))
		body.add_child(rich("[b]Vendre[/b] [color=#a8b4bc](garde ce qu'il faut pour la forge !)[/color]", 19))
		var any := false
		for k in Game.RES_KEYS:
			for t in range(1, Game.MAX_TIER + 1):
				var n: int = Game.S.inv[k][t]
				if n <= 0: continue
				any = true
				row(body, _with_icon(res_tex(k, t), t, rich("%s · %s ×%d — %s pièces l'unité" % [res_text(k, t), Game.RES[k].tiers[t], n, Game.fmt(Game.res_price(t))], 19)), big_button("Vendre ×%d" % min(n, 5), true, func(): main.sell(k, t, min(n, 5))))
		if not any: body.add_child(rich("[color=#8a9298]Rien à vendre pour l'instant.[/color]", 17))
	)

# ——— Cases d'inventaire ———
func slot_box(tx: Texture2D, tier: int, count: int, selected: bool, cb: Callable, size := 74.0, ench := 0, beige := false) -> Button:
	var b := Button.new(); b.custom_minimum_size = Vector2(size, size); b.focus_mode = Control.FOCUS_NONE
	var col: Color = Game.TIER_COL[tier] if tier > 0 else Color(1, 1, 1, 0.12)
	var bg := Color(0.03, 0.04, 0.05, 0.95).lerp(Color(col.r, col.g, col.b, 0.95), 0.16 if tier > 0 else 0.0)
	if beige: bg = Color("#e9dcc0") if tier > 0 else Color("#d8c9a8")
	var st := flat(bg, 10, Color(col.r, col.g, col.b, 0.9 if tier > 0 else 0.15) if not beige else Color("#8a6a3a"), 3 if selected else 2, Vector4(0, 0, 0, 0))
	if selected: st.bg_color = Color(0.12, 0.13, 0.1, 0.98); st.border_color = Color("#ffe39a")
	for k in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(k, st)
	if tier > 0 and not beige:
		# halo radial de la couleur du tier derrière l'objet
		var gl := TextureRect.new(); gl.texture = glow_tex(); gl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gl.stretch_mode = TextureRect.STRETCH_SCALE
		gl.position = Vector2(3, 3); gl.size = Vector2(size - 6, size - 6); gl.modulate = Color(col.r, col.g, col.b, 0.75); gl.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(gl)
	if tx:
		var tr := TextureRect.new(); tr.texture = tx; tr.material = icon_mat(); tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(5, 5); tr.size = Vector2(size - 10, size - 10); tr.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(tr)
	if tier > 0:
		var tl := _label("T%d" % tier, 14, col if not beige else col.darkened(0.35)); tl.add_theme_font_override("font", f_title); tl.position = Vector2(5, 1); b.add_child(tl)
	if count > 1:
		var cl := _label(str(count), 15, Color.WHITE); cl.position = Vector2(size - 8 - 9 * str(count).length(), size - 22); b.add_child(cl)
	if ench > 0:
		var el := _label("+%d" % ench, 15, Color("#e7a8ff")); el.add_theme_font_override("font", f_title); el.position = Vector2(size - 26, 1); b.add_child(el)
	if cb.is_valid(): b.pressed.connect(cb)
	else: b.disabled = true
	return b

# Style « icône de jeu » : contour sombre, couleurs plus saturées, léger relief
var _icon_mat: ShaderMaterial
func icon_mat() -> ShaderMaterial:
	if _icon_mat: return _icon_mat
	var sh := Shader.new(); sh.code = """shader_type canvas_item;
void fragment(){
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * 2.2;
	float a = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.785398;
		a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
	}
	float g = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 col = mix(vec3(g), c.rgb, 1.35);
	col = (col - 0.5) * 1.12 + 0.55;
	float hl = smoothstep(0.6, 0.0, UV.y) * 0.12;
	col += hl;
	vec4 outline = vec4(0.06, 0.04, 0.02, a * 0.95);
	COLOR = mix(outline, vec4(clamp(col, 0.0, 1.0), 1.0), c.a);
}"""
	_icon_mat = ShaderMaterial.new(); _icon_mat.shader = sh
	return _icon_mat

var _glow: Texture2D
func glow_tex() -> Texture2D:
	if _glow: return _glow
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0.75)); g.set_color(1, Color(1, 1, 1, 0.0)); g.add_point(0.55, Color(1, 1, 1, 0.22))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(0.5, 0.55); gt.fill_to = Vector2(1.0, 0.55); gt.width = 64; gt.height = 64
	_glow = gt; return _glow

func res_tex(k: String, t: int) -> Texture2D: return main.icons.get_icon("res_%s_%d" % [k, t])

func bag_entries() -> Array:
	var out := []
	for i in Game.S.items.size():
		var it: Dictionary = Game.S.items[i].duplicate(); it["idx"] = i; out.append(it)
	for k in Game.RES_KEYS:
		for t in range(1, Game.MAX_TIER + 1):
			var n: int = Game.S.inv[k][t]
			if n > 0: out.append({"res": k, "tier": t, "qty": n})
	return out

func entry_tex(e: Dictionary) -> Texture2D:
	return res_tex(e.res, e.tier) if e.has("res") else main.icons.item_icon(e)

func entry_name(e: Dictionary) -> String:
	return Game.res_name(e.res, e.tier) if e.has("res") else Game.item_name(e)

# ——— Inventaire façon Albion : parchemin à droite, poupée d'équipement, sac en grille ———
# Le monde reste visible à gauche (on peut même bouger), la fiche d'un objet s'ouvre à côté.
const PARCH := Color("#e8d4a8")
const INK := Color("#3a2614")
const INK_SOFT := Color("#76593a")
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII"]
const DOLL := [["artefact", "casque", "cape"], ["epee", "armure", "bouclier"], ["potion", "bottes", "monture"]]
const BAG_W := 456.0
var bag_scroll := 0
var bag_card_rect := Rect2()

func _parch_box() -> StyleBoxFlat:
	var st := flat(PARCH, 18, Color("#7a5530"), 4, Vector4(14, 10, 14, 12), 18)
	st.shadow_color = Color(0, 0, 0, 0.55); st.border_blend = true
	return st

# Case d'objet style Albion : fond sombre, halo du tier, chiffre romain en pastille, quantité en bas
func aslot(tx: Texture2D, tier: int, count: int, selected: bool, cb: Callable, size := 70.0, ench := 0, ghost: Texture2D = null, it := {}) -> Button:
	var b := Button.new(); b.custom_minimum_size = Vector2(size, size); b.focus_mode = Control.FOCUS_NONE
	var full := tier > 0 and tx != null
	var col: Color = Game.TIER_COL[clamp(tier, 0, Game.TIER_COL.size() - 1)] if tier > 0 else Color("#a88b5e")
	var st := flat(Color("#2c2620") if full else Color("#d6c095"), 10, col.lerp(Color(0.1, 0.08, 0.05), 0.15) if full else Color("#b0956a"), 3, Vector4(0, 0, 0, 0))
	if not full: st.shadow_color = Color(0.35, 0.25, 0.12, 0.35); st.shadow_size = 2; st.shadow_offset = Vector2(0, -1)
	if ench > 0 and full: st.border_color = Color("#c98bff")
	if selected: st.border_color = Color("#ffe08a"); st.border_width_left = 4; st.border_width_right = 4; st.border_width_top = 4; st.border_width_bottom = 4
	for k in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(k, st)
	if full:
		var gl := TextureRect.new(); gl.texture = glow_tex(); gl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gl.stretch_mode = TextureRect.STRETCH_SCALE
		gl.position = Vector2(4, 4); gl.size = Vector2(size - 8, size - 8); gl.modulate = Color(col.r, col.g, col.b, 0.6); gl.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(gl)
		var tr := TextureRect.new(); tr.texture = tx; tr.material = icon_mat(); tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(6, 6); tr.size = Vector2(size - 12, size - 12); tr.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(tr)
		# pastille du tier en chiffres romains
		var pill := Panel.new(); var ps := flat(Color(0.08, 0.1, 0.14, 0.92), 11, col, 2, Vector4(0, 0, 0, 0)); pill.add_theme_stylebox_override("panel", ps)
		pill.position = Vector2(3, 3); pill.size = Vector2(26 if tier < 4 else 30, 20); pill.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(pill)
		var tl := _label(ROMAN[clamp(tier, 0, 8)], 13, Color.WHITE); tl.add_theme_font_override("font", f_title); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.size = pill.size; tl.position = Vector2(0, -1); pill.add_child(tl)
		if ench > 0:
			var el := _label("+%d" % ench, 14, Color("#e7a8ff")); el.add_theme_font_override("font", f_title); el.add_theme_constant_override("outline_size", 5); el.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			el.position = Vector2(size - 26, 1); b.add_child(el)
		if count > 1:
			var cl := _label(Game.fmt(count) if count >= 10000 else str(count), 14, Color.WHITE); cl.add_theme_constant_override("outline_size", 5); cl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; cl.size = Vector2(size - 8, 18); cl.position = Vector2(0, size - 21); b.add_child(cl)
		if not it.is_empty(): _lvl_tag(b, it, size)
	elif ghost:
		var gh := TextureRect.new(); gh.texture = ghost; gh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gh.position = Vector2(12, 12); gh.size = Vector2(size - 24, size - 24); gh.modulate = Color(0.42, 0.31, 0.17, 0.32); gh.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(gh)
	if cb.is_valid(): b.pressed.connect(cb)
	return b

func _ghost(slot: String) -> Texture2D:
	match slot:
		"potion": return main.icons.get_icon("potion")
		"artefact": return load("res://ui/art_rage.png")
		"bottes": return main.icons.get_icon("bottes_greves")
		"monture": return main.icons.get_icon("mount_ane")
		"casque", "cape": return main.icons.get_icon("%s_%s" % [slot, Game.GEAR_KINDS[slot].keys()[0]])
	return main.icons.item_icon({"slot": slot, "tier": 2, "kind": {"epee": "epee", "armure": "plate"}.get(slot, "")})

func _ink(t: String, size: int, c := INK, title := false) -> Label:
	var l := _label(t, size, c)
	if title: l.add_theme_font_override("font", f_title)
	l.add_theme_constant_override("outline_size", 0)
	return l

func bag_value() -> int:
	var v := 0
	for it in Game.S.items: v += Game.item_price(it)
	for k in Game.RES_KEYS:
		for t in range(1, Game.MAX_TIER + 1): v += Game.S.inv[k][t] * Game.res_price(t)
	return v

const SORT_ORDER := ["epee", "bouclier", "casque", "armure", "cape", "bottes", "artefact", "monture", "hache", "pioche", "faucille", "junk"]
func sort_bag() -> void:
	Game.S.items.sort_custom(func(a, b):
		var ia := SORT_ORDER.find(a.slot); var ib := SORT_ORDER.find(b.slot)
		if ia != ib: return ia < ib
		if int(a.tier) != int(b.tier): return int(a.tier) > int(b.tier)
		return int(a.get("ench", 0)) > int(b.get("ench", 0)))
	bag_sel = -1; Game.play("pickup", -6.0); Game.save(); show_bag()

func show_bag() -> void:
	var keep: int = bag_scroll
	if cur_panel == "bag" and cur_scroll and is_instance_valid(cur_scroll): keep = cur_scroll.scroll_vertical
	close_panel()
	cur_panel = "bag"; panel_open = true; panel_title = "Sac"
	for n in buttons: buttons[n].held = false
	joy.id = -1; joy.vec = Vector2.ZERO; touches.clear()
	var entries := bag_entries()
	if bag_sel >= entries.size(): bag_sel = -1
	var s := vs()
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", _parch_box())
	pc.position = Vector2(s.x - BAG_W - 8, 6); pc.custom_minimum_size = Vector2(BAG_W, s.y - 12); pc.size = pc.custom_minimum_size
	root.add_child(pc); panel = pc
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); pc.add_child(vb)
	# — en-tête : portrait, nom, puissance, fermer —
	var hd := HBoxContainer.new(); hd.add_theme_constant_override("separation", 10); vb.add_child(hd)
	var pf := PanelContainer.new(); pf.add_theme_stylebox_override("panel", flat(Color("#2c2620"), 30, Color("#c79a4a"), 3, Vector4(4, 4, 4, 4)))
	pf.custom_minimum_size = Vector2(60, 60); hd.add_child(pf)
	var pt := TextureRect.new(); pt.texture = main.icons.get_icon("hero_head"); pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pt.material = icon_mat(); pf.add_child(pt)
	var nv := VBoxContainer.new(); nv.add_theme_constant_override("separation", -4); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hd.add_child(nv)
	nv.add_child(_ink("%s :" % str(Game.S.get("pname", "Aventurier")), 15, INK_SOFT))
	var tr := HBoxContainer.new(); tr.add_theme_constant_override("separation", 10); nv.add_child(tr)
	tr.add_child(_ink("Inventaire", 30, INK, true))
	var ip := _ink("PI %d" % Game.power(), 17, Color("#5a3d8a"), true); ip.size_flags_vertical = Control.SIZE_SHRINK_END; tr.add_child(ip)
	var x := Button.new(); x.text = "✕"; x.custom_minimum_size = Vector2(52, 52); x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_override("font", ThemeDB.fallback_font); x.add_theme_font_size_override("font_size", 24); x.add_theme_color_override("font_color", Color("#ffe08a"))
	var xs := flat(Color("#3a2c1c"), 26, Color("#c79a4a"), 3, Vector4(0, 0, 0, 0))
	for k in ["normal", "hover", "pressed"]: x.add_theme_stylebox_override(k, xs)
	x.pressed.connect(close_panel); hd.add_child(x)
	# — poupée d'équipement 3×3 + outils et caractéristiques à droite —
	var mid := HBoxContainer.new(); mid.add_theme_constant_override("separation", 14); vb.add_child(mid)
	var dg := GridContainer.new(); dg.columns = 3; dg.add_theme_constant_override("h_separation", 8); dg.add_theme_constant_override("v_separation", 8); mid.add_child(dg)
	for rw in DOLL:
		for slot in rw:
			if slot == "potion":
				var np: int = Game.S.potions
				dg.add_child(aslot(main.icons.get_icon("potion") if np > 0 else null, 1 if np > 0 else 0, np, eq_sel == "potion", func(): eq_sel = "potion"; bag_sel = -1; show_bag(), 68, 0, _ghost("potion")))
				continue
			var it := Game.equipped_item(slot)
			var tx: Texture2D = main.icons.item_icon(it)
			dg.add_child(aslot(tx, int(it.tier), 1, eq_sel == slot, func(): eq_sel = slot; bag_sel = -1; show_bag(), 68, int(it.get("ench", 0)), _ghost(slot), it))
	var side := VBoxContainer.new(); side.add_theme_constant_override("separation", 4); side.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mid.add_child(side)
	side.add_child(_ink("OUTILS", 13, INK_SOFT, true))
	var th := HBoxContainer.new(); th.add_theme_constant_override("separation", 6); side.add_child(th)
	for slot in ["hache", "pioche", "faucille"]:
		var it := Game.equipped_item(slot)
		th.add_child(aslot(main.icons.item_icon(it), int(it.tier), 1, eq_sel == slot, func(): eq_sel = slot; bag_sel = -1; show_bag(), 54, 0, _ghost(slot), it))
	var st: Dictionary = Game.stats(); var P: Player = main.player
	var sr := RichTextLabel.new(); sr.bbcode_enabled = true; sr.fit_content = true; sr.scroll_active = false; sr.custom_minimum_size = Vector2(170, 0)
	sr.add_theme_font_size_override("normal_font_size", 14); sr.add_theme_font_size_override("bold_font_size", 15); sr.add_theme_color_override("default_color", INK)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sr.text = "Vie [b]%d[/b]\nDégâts [b]%d[/b]\nArmure [b]%d[/b] [color=#76593a](−%d %%)[/color]\nVitesse [b]%+d %%[/b]\nCritique [b]%d %%[/b]\nRecharge [b]−%d %%[/b]%s" % [int(P.max_hp), int(P.dmg()), int(st.arm), int(st.red * 100), int(round(st.spd * 100)), int(round(st.crit * 100)), int(round((st.cd + Game.wkind().cd) * 100)), ("\nVol de vie [b]%d %%[/b]" % int(round(st.steal * 100))) if st.steal > 0 else ""]
	side.add_child(sr)
	# — argent et remplissage du sac —
	var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 8); vb.add_child(mh)
	var ci := TextureRect.new(); ci.texture = T("it_coins"); ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ci.custom_minimum_size = Vector2(28, 28); mh.add_child(ci)
	mh.add_child(_ink(Game.fmt(Game.S.silver), 20, INK, true))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mh.add_child(sp)
	var used := entries.size(); var cap := Game.bag_size(); var fr: float = clamp(float(used) / max(1, cap), 0.0, 1.0)
	var wb := VBoxContainer.new(); wb.add_theme_constant_override("separation", 1); mh.add_child(wb)
	var wl := _ink("Sac %d / %d · %d %%" % [used, cap, int(fr * 100)], 13, Color("#a0301c") if fr >= 0.95 else INK_SOFT); wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; wb.add_child(wl)
	var bar := ColorRect.new(); bar.color = Color("#b49a6c"); bar.custom_minimum_size = Vector2(150, 7); wb.add_child(bar)
	var fill := ColorRect.new(); fill.color = Color("#d0402a") if fr >= 0.95 else (Color("#d9a43a") if fr > 0.75 else Color("#4f9a3c")); fill.size = Vector2(150 * fr, 7); bar.add_child(fill)
	# — grille du sac —
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 10; sc.scroll_started.connect(func(): drag_guard = true); vb.add_child(sc); cur_scroll = sc
	var g := GridContainer.new(); g.columns = 5; g.add_theme_constant_override("h_separation", 7); g.add_theme_constant_override("v_separation", 7); sc.add_child(g)
	for i in max(cap, used):
		if i < used:
			var e: Dictionary = entries[i]
			g.add_child(aslot(entry_tex(e), e.tier, e.get("qty", 1), i == bag_sel, func(): bag_sel = i; eq_sel = ""; show_bag(), 78, int(e.get("ench", 0)), null, e))
		else: g.add_child(aslot(null, 0, 0, false, Callable(), 78))
	_touch_scroll(g)
	sc.scroll_vertical = keep
	(func(): if is_instance_valid(sc): sc.scroll_vertical = keep).call_deferred()
	# — bas : trier, vendre le bric-à-brac, estimation —
	var bt := HBoxContainer.new(); bt.add_theme_constant_override("separation", 8); vb.add_child(bt)
	bt.add_child(_parch_btn("Trier", sort_bag))
	var nj: int = Game.S.items.filter(func(q): return q.slot == "junk").size()
	if nj > 0: bt.add_child(_parch_btn("Vendre bric-à-brac (%d)" % nj, func(): main.sell_junk(-1); show_bag()))
	var sp2 := Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bt.add_child(sp2)
	var ev := _ink("Estimation : %s" % Game.fmt(bag_value()), 13, INK_SOFT); ev.size_flags_vertical = Control.SIZE_SHRINK_CENTER; bt.add_child(ev)
	_bag_card(entries, pc.position.x)

func _parch_btn(t: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = t; b.focus_mode = Control.FOCUS_NONE; b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_override("font", f_title); b.add_theme_font_size_override("font_size", 16); b.add_theme_color_override("font_color", Color("#ffe6a8"))
	var st := flat(Color("#4a3520"), 21, Color("#c79a4a"), 2, Vector4(16, 4, 16, 4))
	for k in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(k, st)
	b.pressed.connect(cb); return b

# Fiche de l'objet touché, posée à gauche du parchemin (le jeu reste visible derrière)
func _bag_card(entries: Array, px: float) -> void:
	bag_card_rect = Rect2()
	var sel = null; var equipped := false
	if eq_sel == "potion":
		sel = {"potion": true}
	elif eq_sel != "": sel = Game.equipped_item(eq_sel); equipped = true
	elif bag_sel >= 0 and bag_sel < entries.size(): sel = entries[bag_sel]
	if sel == null: return
	var W := 420.0
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", flat(Color(0.07, 0.07, 0.08, 0.95), 16, Color("#c79a4a"), 2, Vector4(16, 12, 16, 14), 14))
	card.position = Vector2(px - W - 10, 10); card.custom_minimum_size = Vector2(W, 0); root.add_child(card); panel_extra.append(card)
	var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 8); cv.custom_minimum_size = Vector2(W - 32, 0); card.add_child(cv)
	var close := func(): eq_sel = ""; bag_sel = -1; show_bag()
	if sel.has("potion"):
		var hh := HBoxContainer.new(); hh.add_theme_constant_override("separation", 12); cv.add_child(hh)
		hh.add_child(aslot(main.icons.get_icon("potion"), 1, Game.S.potions, true, Callable(), 80))
		hh.add_child(rich("[b]Potion de soin[/b]\n[color=#a8b4bc]×%d dans ta ceinture[/color]" % Game.S.potions, 18))
		cv.add_child(rich("Rend [b]45 %[/b] de la vie. Bouton vert en bas à droite pendant le combat (8 s de recharge).\n[color=#a8b4bc]Achète-en chez la marchande de chaque ville.[/color]", 16))
		cv.add_child(big_button("Fermer", true, close))
	elif equipped and int(sel.tier) <= 0:
		cv.add_child(rich("[b]%s[/b] — emplacement vide\n[color=#a8b4bc]Touche un objet de ton sac pour l'équiper, ou fabrique-le à la forge.%s[/color]" % [Game.SLOT_NAME[eq_sel], " Les artefacts se gagnent en duel, en donjon et sur les boss de groupe." if eq_sel == "artefact" else ""], 17))
		cv.add_child(big_button("Fermer", true, close))
	else:
		var e: Dictionary = sel
		var hh := HBoxContainer.new(); hh.add_theme_constant_override("separation", 12); cv.add_child(hh)
		hh.add_child(aslot(entry_tex(e), e.tier, e.get("qty", 1), true, Callable(), 84, int(e.get("ench", 0)), null, e))
		var col: Color = Game.TIER_COL[e.tier]
		var sub: String = "Ressource" if e.has("res") else Game.SLOT_NAME[e.slot]
		var nm := rich("[b][color=#%s]%s[/color][/b]\n%s · [color=#%s]Tier %s[/color]%s" % [col.to_html(false), entry_name(e), sub, col.to_html(false), ROMAN[clamp(int(e.tier), 0, 8)], "  · [color=#9dffb0]porté[/color]" if equipped else ""], 18)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER; nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hh.add_child(nm)
		cv.add_child(rich(item_info(e, equipped), 16))
		var bh := HFlowContainer.new(); bh.add_theme_constant_override("h_separation", 8); bh.add_theme_constant_override("v_separation", 8); cv.add_child(bh)
		if equipped:
			var ub := big_button("Déséquiper", true, func(): _unequip(eq_sel), GOLD, true); ub.custom_minimum_size = Vector2(160, 48); bh.add_child(ub)
		else:
			if not e.has("res") and not e.get("bebe", false) and e.slot != "junk":
				var why: String = Game.equip_block(e)
				if why != "": cv.add_child(rich("[color=#ff8a7a]Verrouillé : %s[/color]" % why, 15))
				var b1 := big_button("Équiper", why == "", func(): bag_sel = -1; eq_sel = ""; main.equip_from_bag(e.idx), GOLD, true); b1.custom_minimum_size = Vector2(140, 48); bh.add_child(b1)
			if not e.has("res") and e.slot == "junk":
				var bj := big_button("Vendre · %s" % Game.fmt(Game.junk_price(e)), true, func(): bag_sel = -1; main.sell_junk(e.idx); show_bag(), GOLD, true); bj.custom_minimum_size = Vector2(160, 48); bh.add_child(bj)
			var b2 := big_button("Hôtel des ventes", true, func(): ah_tab = "sell"; ah_sel = e; ah_price = main.real_price(_lot(e)); show_auction("sell")); b2.custom_minimum_size = Vector2(160, 48); bh.add_child(b2)
		var bx := big_button("✕", true, close); bx.custom_minimum_size = Vector2(52, 48); bx.add_theme_font_override("font", ThemeDB.fallback_font); bh.add_child(bx)
	card.reset_size()
	bag_card_rect = Rect2(card.position, card.size)
	(func():
		if is_instance_valid(card): card.reset_size(); bag_card_rect = Rect2(card.position, card.size)).call_deferred()

# petit « Nv 3 » en bas à gauche des objets qui ont pris des niveaux
func _lvl_tag(b: Control, it: Dictionary, size: float) -> void:
	var l := int(it.get("lvl", 0))
	if l <= 0: return
	var t := _label("Nv%d" % l, 13, Color("#9fe4ff")); t.add_theme_font_override("font", f_title); t.position = Vector2(5, size - 20); b.add_child(t)

func _unequip(slot: String) -> void:
	if not Game.unequip(slot):
		toast("Ton sac est plein : fais de la place d'abord" if Game.S.gear.get(slot, 0) > 0 else "Rien à retirer", Color("#ff9a8a")); Game.play("error"); return
	main.player.refresh_gear(); Game.play("pickup", -4.0); Game.save(); main.update_goal(); show_bag()

# Ce que fait l'objet, comparé à ce que tu portes
func _stat(it: Dictionary) -> float:
	var t := int(it.tier); var em := Game.ench_mult(int(it.get("ench", 0)))
	match it.slot:
		"epee": return Game.weapon_dmg(t) * Game.WEAPON_KINDS[it.get("kind", "epee")].dmg * em if t > 0 else 0.0
		"armure", "casque", "cape": return Game.armor_hp(t) * float(Game.gear_def(it.slot, it.get("kind", "")).get("hp", 0.0)) * em * (1.0 + 0.05 * int(it.get("lvl", 0))) if t > 0 else 0.0
		"bouclier": return Game.shield_hp(t) * em
		"bottes": return 6.0 * (t - 1) + 2.5 * int(it.get("ench", 0)) if t > 0 else -6.0
	return float(t)

func _diff(v: float, cur: float, unit := "") -> String:
	var d := v - cur
	if abs(d) < 0.5: return "  [color=#a8b4bc](=)[/color]"
	return "  [color=%s](%s%d%s)[/color]" % ["#8dffa0" if d > 0 else "#ff8a7a", "+" if d > 0 else "", int(round(d)), unit]

func item_info(e: Dictionary, equipped: bool) -> String:
	if e.has("res"):
		return "×%d en stock · valeur ≈ [color=#ffd86b]%s[/color] argent l'unité\nSert à la forge (Brokk) pour fabriquer les objets T%d." % [e.qty, Game.fmt(Game.res_price(e.tier)), e.tier]
	var t := int(e.tier); var lines := []
	var cur := Game.equipped_item(e.slot); var cv := _stat(cur); var v := _stat(e)
	var cmp := not equipped
	match e.slot:
		"epee":
			lines.append("Dégâts par coup : [b]%d[/b]%s" % [int(v), _diff(v, cv) if cmp else ""])
			lines.append("[color=#a8b4bc]%s[/color]" % Game.WEAPON_KINDS[e.get("kind", "epee")].desc)
			for sk in Player.skills():
				if sk.req == t: lines.append("[color=#9fe4ff]Débloque : %s[/color]" % sk.name)
		"armure":
			lines.append("Vie : [b]%d[/b]%s" % [int(v), _diff(v, cv) if cmp else ""])
			lines.append("Armure : [b]%d[/b]" % int(float(Game.gear_def("armure", e.get("kind", "plate")).get("arm", 0)) * t))
			lines.append("[color=#a8b4bc]%s · change ton apparence[/color]" % Game.gear_def("armure", e.get("kind", "plate")).desc)
		"casque", "cape":
			var K: Dictionary = Game.gear_def(e.slot, e.get("kind", ""))
			lines.append("Vie : [b]+%d[/b]%s   ·   Armure : [b]%d[/b]" % [int(v), _diff(v, cv) if cmp else "", int(float(K.get("arm", 0)) * t)])
			lines.append("[color=#a8b4bc]%s · visible sur ton héros[/color]" % K.desc)
		"bouclier":
			lines.append("Vie : [b]+%d[/b]%s" % [int(v), _diff(v, cv) if cmp else ""])
			lines.append("Dégâts reçus : [b]−%d %%[/b]" % int(Game.shield_block(t) * 100))
		"bottes":
			lines.append("Vitesse : [b]+%d %%[/b]%s" % [int(v), _diff(v, cv, " %") if cmp else ""])
			var KB: Dictionary = Game.gear_def("bottes", e.get("kind", "greves"))
			lines.append("[color=#a8b4bc]%s : %s[/color]" % [KB.name, KB.desc])
			lines.append("[color=#a8b4bc]Esquive un peu plus longue[/color]")
		"monture":
			lines.append("[b]%s[/b]" % Game.mount_desc(e.get("kind", "ane")))
			lines.append("[color=#a8b4bc]Équipe-la, puis touche le bouton MONTURE : 1,75 s d'invocation (immobile, hors combat).[/color]")
			if Game.MOUNTS[e.get("kind", "ane")].tier >= 5: lines.append("[color=#ffb04a]Monture T5 : bonus de dégâts ET de vie[/color]")
		"junk":
			lines.append("[color=#a8b4bc]Bric-à-brac : ne sert à rien… mais la marchande te le rachète tout de suite.[/color]")
		"artefact":
			lines.append("[b]%s[/b]" % Game.art_desc(e.get("kind", "rage"), t))
			if cmp and int(cur.tier) > 0: lines.append("[color=#a8b4bc]Porté : %s T%d — %s[/color]" % [Game.item_name(cur), cur.tier, Game.art_desc(cur.get("kind", "rage"), int(cur.tier))])
			lines.append("[color=#c9a8ff]Objet rare : duels, donjons, boss de groupe[/color]")
		_:
			var Q: Dictionary = Game.TOOL_Q[clamp(int(e.get("q", 0)), 0, 3)]
			lines.append("Qualité [b][color=%s]%s[/color][/b] : vitesse ×%s · récolte double %d %%" % [Q.col, Q.name, ("%.2f" % (1.0 / Q.speed)).replace(".", ","), int(Q.bonus * 100)])
			lines.append("Récolte : %s jusqu'au [b]T%d[/b]%s" % [Game.RES[{"hache": "wood", "pioche": "ore", "faucille": "fiber"}[e.slot]].name.to_lower(), t, _diff(v, cv) if cmp else ""])
	if int(e.get("ench", 0)) > 0: lines.append("[color=#e7a8ff]Enchanté +%d : +%d %% de puissance[/color]" % [int(e.ench), 12 * int(e.ench)])
	for k in e.get("bx", {}):
		lines.append("[color=#8dffa0]• %s[/color]" % (Game.BX[k].fmt % int(e.bx[k])))
	if e.slot in Game.LEVEL_SLOTS and int(e.tier) > 0:
		var lv := int(e.get("lvl", 0))
		lines.append("[color=#9fe4ff]Niveau %d / %d%s · se renforce en tuant des monstres (+5 %% par niveau)[/color]" % [lv, Game.ILVL_MAX, ("  (%d / %d xp)" % [int(e.get("xp", 0)), Game.ilvl_need(lv)]) if lv < Game.ILVL_MAX else ""])
	lines.append("Valeur ≈ [color=#ffd86b][b]%s[/b][/color] argent" % Game.fmt(Game.item_price(e)))
	return "\n".join(lines)

func _lot(e: Dictionary) -> Dictionary:
	if e.has("res"): return {"res": e.res, "tier": e.tier, "qty": min(10, e.qty)}
	return e

# ——— Hôtel des ventes ———
const AH_CATS := [["all", "Tout"], ["arme", "Armes"], ["bouclier", "Boucliers"], ["artefact", "Artefacts"], ["monture", "Montures"], ["casque", "Casques"], ["veste", "Plastrons"], ["cape", "Capes"], ["chaussures", "Bottes"], ["outil", "Outils"], ["ressource", "Ressources"], ["divers", "Divers"]]
static func cat_of(e: Dictionary) -> String:
	if e.has("res"): return "ressource"
	return {"epee": "arme", "bouclier": "bouclier", "artefact": "artefact", "monture": "monture", "armure": "veste", "bottes": "chaussures", "casque": "casque", "cape": "cape", "junk": "divers"}.get(e.slot, "outil")

func _tab_btn(parent: Control, txt: String, on: bool, cb: Callable) -> void:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(150, 46); b.add_theme_font_size_override("font_size", 19)
	if on: b.add_theme_stylebox_override("normal", flat(Color("#3f8a5c"), 12, Color(0.95, 0.85, 0.5, 0.9), 2, Vector4(16, 6, 16, 8)))
	b.pressed.connect(cb); parent.add_child(b)

func _chip(parent: Control, txt: String, on: bool, cb: Callable) -> void:
	var b := Button.new(); b.text = txt; b.custom_minimum_size = Vector2(0, 38); b.add_theme_font_size_override("font_size", 16)
	var st := flat(Color(0.95, 0.78, 0.45, 0.85) if on else Color(1, 1, 1, 0.07), 19, Color(1, 1, 1, 0.12), 1, Vector4(16, 4, 16, 6))
	b.add_theme_stylebox_override("normal", st); b.add_theme_stylebox_override("hover", st)
	b.add_theme_color_override("font_color", Color("#20180a") if on else SOFT)
	b.pressed.connect(cb); parent.add_child(b)

func _tier_chip(parent: Control, t: int) -> void:
	var b := Button.new(); b.text = "Tous" if t == 0 else "T%d" % t; b.custom_minimum_size = Vector2(58 if t > 0 else 70, 36); b.add_theme_font_size_override("font_size", 16)
	var on := ah_tier == t; var col: Color = Game.TIER_COL[t] if t > 0 else GOLD
	var st := flat(Color(col.r, col.g, col.b, 0.85) if on else Color(1, 1, 1, 0.06), 18, Color(col.r, col.g, col.b, 0.8), 2, Vector4(10, 3, 10, 5))
	b.add_theme_stylebox_override("normal", st); b.add_theme_stylebox_override("hover", st)
	b.add_theme_color_override("font_color", Color("#15100a") if on else col)
	b.pressed.connect(func(): ah_tier = t; show_auction()); parent.add_child(b)

func _ah_row(body: Control, tx: Texture2D, e: Dictionary, right: Control, extra := "") -> void:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.045), 12, Color(1, 1, 1, 0.07), 1, Vector4(10, 6, 10, 6))); body.add_child(p)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); p.add_child(h)
	h.add_child(slot_box(tx, e.tier, e.get("qty", 1), false, Callable(), 60, int(e.get("ench", 0))))
	var col: Color = Game.TIER_COL[e.tier]
	var r := rich("[b]%s[/b]\n[color=#%s]Tier %d[/color]%s" % [entry_name(e), col.to_html(false), e.tier, extra], 18); r.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(r)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(right)

# couleur du prix : plus c'est cher, plus ça brille
static func money_col(n: int) -> Color:
	if n >= 1000000: return Color("#ff9a3c")
	if n >= 100000: return Color("#e58bff")
	if n >= 10000: return Color("#7fc8ff")
	return Color("#ffd86b")

func _price_box(price: int, btn: Button = null) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6)
	var ci := TextureRect.new(); ci.texture = T("it_coins"); ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ci.custom_minimum_size = Vector2(28, 28); h.add_child(ci)
	var l := _label(Game.fmt(price), 24 if price >= 100000 else 22, money_col(price)); l.add_theme_font_override("font", f_title); l.custom_minimum_size = Vector2(96, 0); h.add_child(l)
	if btn: h.add_child(btn)
	return h

func show_auction(tab := "", cat := "") -> void:
	if tab != "": ah_tab = tab
	if cat != "": ah_cat = cat
	main.ah_refresh_stock()
	open_panel("Hôtel des ventes", func(body: VBoxContainer):
		cur_panel = "auction"
		var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); body.add_child(tabs)
		_tab_btn(tabs, "Acheter", ah_tab == "buy", func(): ah_sel = null; show_auction("buy"))
		_tab_btn(tabs, "Vendre", ah_tab == "sell", func(): ah_sel = null; show_auction("sell"))
		_tab_btn(tabs, "Mes ventes (%d)" % Game.S.ah.listings.size(), ah_tab == "mine", func(): show_auction("mine"))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(sp)
		tabs.add_child(_price_box(Game.S.silver))
		if ah_tab != "mine":
			var cats := HFlowContainer.new(); cats.add_theme_constant_override("h_separation", 6); body.add_child(cats)
			for c in AH_CATS: _chip(cats, c[1], ah_cat == c[0], func(): show_auction("", c[0]))
			var tiers := HBoxContainer.new(); tiers.add_theme_constant_override("separation", 6); body.add_child(tiers)
			tiers.add_child(_label("Tier :", 15, SOFT))
			for t in range(0, 6): _tier_chip(tiers, t)
		match ah_tab:
			"buy":
				_vitrine(body)
				var n := 0
				for i in Game.S.ah.stock.size():
					var e: Dictionary = Game.S.ah.stock[i]
					if ah_cat != "all" and cat_of(e) != ah_cat: continue
					if ah_tier > 0 and int(e.tier) != ah_tier: continue
					n += 1
					var b := big_button("Acheter", Game.S.silver >= e.price, func(): main.ah_buy(i), GOLD, true); b.custom_minimum_size = Vector2(130, 46)
					_ah_row(body, entry_tex(e), e, _price_box(e.price, b), (("   ·   [color=#9fd4ff]vendu par %s[/color]" % e.seller) if e.has("seller") else "") + (("\n[color=#ff8a7a]Verrouillé pour toi : %s[/color]" % Game.equip_block(e)) if not e.has("res") and Game.equip_block(e) != "" else ""))
				if n == 0: body.add_child(rich("[color=#8a9298]Rien dans cette catégorie pour l'instant. Le stock se renouvelle toutes les 5 minutes.[/color]", 16))
			"sell":
				if ah_sel != null: _sell_editor(body)
				var entries := bag_entries(); var n2 := 0
				for e in entries:
					if ah_cat != "all" and cat_of(e) != ah_cat: continue
					if ah_tier > 0 and int(e.tier) != ah_tier: continue
					n2 += 1
					var lot := _lot(e)
					var b := big_button("Vendre", true, func(): ah_sel = e; ah_price = main.real_price(lot); show_auction("sell")); b.custom_minimum_size = Vector2(120, 46)
					_ah_row(body, entry_tex(lot), lot, _price_box(main.real_price(lot), b), "   ·   prix du marché" + (" (lot de %d)" % lot.qty if lot.has("res") else ""))
				if n2 == 0: body.add_child(rich("[color=#8a9298]Rien à vendre dans cette catégorie.[/color]", 16))
			"mine":
				if Game.S.ah.listings.is_empty(): body.add_child(rich("[color=#8a9298]Aucune vente en cours. Va dans « Vendre » pour mettre un objet en vente.[/color]", 16))
				for l in Game.S.ah.listings:
					var left: int = int(max(0.0, float(l.end) - main.now_s()))
					var ch := int(main.sell_chance(int(l.price), int(l.real)) * 100)
					_ah_row(body, entry_tex(l), l, _price_box(int(l.price)), "   ·   résultat dans %d s   ·   chance de vente %d %%" % [left, ch])
	, 880)

# « À la une » : l'objet le plus cher du moment, en grand
func _vitrine(body: Control) -> void:
	var best = null
	for e in Game.S.ah.stock:
		if e.has("res"): continue
		if best == null or e.price > best.price: best = e
	if best == null: return
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", flat(Color(0.18, 0.12, 0.05, 0.9), 16, money_col(best.price), 2, Vector4(14, 10, 16, 10))); body.add_child(p)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); p.add_child(h)
	h.add_child(slot_box(entry_tex(best), best.tier, 1, true, Callable(), 84, int(best.get("ench", 0))))
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_child(v)
	v.add_child(_label("À LA UNE", 14, Color("#ffb04a")))
	v.add_child(rich("[b][color=#%s]%s[/color][/b]%s" % [Game.TIER_COL[best.tier].to_html(false), Game.item_name(best), ("   [color=#9fd4ff]par %s[/color]" % best.seller) if best.has("seller") else ""], 20))
	var pr := _label(Game.fmt(best.price), 40, money_col(best.price)); pr.add_theme_font_override("font", f_title); pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(pr)
	var i: int = Game.S.ah.stock.find(best)
	var b := big_button("Acheter", Game.S.silver >= best.price, func(): main.ah_buy(i), GOLD, true); b.custom_minimum_size = Vector2(140, 52); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(b)

func _do_list() -> void:
	var lot: Dictionary = ah_sel.duplicate()
	if lot.has("res"): lot.qty = min(10, lot.qty)
	ah_sel = null; main.ah_list(lot, ah_price)

func _sell_editor(body: Control) -> void:
	var e: Dictionary = _lot(ah_sel)
	var real: int = main.real_price(e)
	var ch := int(main.sell_chance(ah_price, real) * 100)
	var col := Color("#8dffa0") if ch >= 60 else (Color("#ffd27a") if ch >= 30 else Color("#ff8a7a"))
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", flat(Color(0.95, 0.78, 0.45, 0.1), 14, Color(0.95, 0.78, 0.45, 0.6), 2, Vector4(14, 10, 14, 10))); body.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); p.add_child(v)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); v.add_child(h)
	h.add_child(slot_box(entry_tex(e), e.tier, e.get("qty", 1), true, Callable(), 64))
	h.add_child(rich("[b]%s[/b]  [color=#%s]T%d[/color]\nPrix du marché : [color=#ffd86b]%s[/color]   ·   [color=#%s]Chance de vente : %d %%[/color]" % [entry_name(e), Game.TIER_COL[e.tier].to_html(false), e.tier, Game.fmt(real), col.to_html(false), ch], 18))
	var h2 := HBoxContainer.new(); h2.add_theme_constant_override("separation", 8); v.add_child(h2)
	for d in [[-0.25, "−25 %"], [-0.1, "−10 %"], [0.1, "+10 %"], [0.25, "+25 %"]]:
		var b := Button.new(); b.text = d[1]; b.custom_minimum_size = Vector2(90, 46); b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(func(): ah_price = max(1, int(round(ah_price * (1.0 + d[0])))); show_auction("sell"))
		h2.add_child(b)
	h2.add_child(_price_box(ah_price))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h2.add_child(sp)
	h2.add_child(big_button("Mettre en vente", true, func(): _do_list(), GOLD, true))
	v.add_child(rich("[color=#a8b4bc]Plus ton prix dépasse le prix du marché, moins un acheteur se présentera. Si l'objet ne se vend pas, il revient dans ton sac. Taxe : 5 %.[/color]", 14))

func show_menu() -> void:
	open_panel("Menu", func(body: VBoxContainer):
		var sk_txt := "[b]Compétences[/b] [color=#a8b4bc](débloquées en améliorant ton arme)[/color]\n"
		for sk in Player.skills(): sk_txt += "[img=30x30]res://ui/%s.png[/img] [b]%s[/b] — Arme T%d — %s\n" % [sk.icon, sk.name, sk.req, sk.desc]
		body.add_child(rich(sk_txt, 17))
		body.add_child(rich("[b]Conseils[/b]\n• Pose ton pouce n'importe où à gauche pour bouger. Glisse le doigt pour faire défiler les menus.\n• Gros bouton : attaque, récolte, parle, ouvre — selon ce qui est près de toi.\n• Esquive les cercles rouges au sol. Touche la mini-carte pour voir la carte du monde.\n• [color=#c58bff]Portails violets[/color] : donjons aléatoires, le meilleur butin du jeu.\n• [color=#ff8a4a]VS[/color] : duellistes — gagne pour obtenir des artefacts.\n• [color=#d58bff]Boss de groupe[/color] : il faut être 4 — engage des mercenaires chez Rhéa (auberge).", 17))
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); body.add_child(h)
		h.add_child(big_button("Son : " + ("oui" if AudioServer.get_bus_volume_db(0) > -50 else "non"), true, func(): _toggle_sound()))
		h.add_child(big_button("Retour au village", true, func(): _to_camp()))
		h.add_child(big_button("Effacer la partie", true, func(): _wipe(), Color("#ff9a8a")))
		body.add_child(rich("[color=#7a848a]Graphismes : KayKit · Fantasy UI · icônes Viktor Hahn, frosty_rabbid, CraftPix, Cursed Loot.[/color]", 14))
	)

func _toggle_sound() -> void:
	AudioServer.set_bus_volume_db(0, -80.0 if AudioServer.get_bus_volume_db(0) > -50 else 0.0); show_menu()
func _to_camp() -> void:
	close_panel(); main.teleport_camp()
func _wipe() -> void:
	Game.reset_save(); get_tree().reload_current_scene()

func show_map() -> void:
	var s := vs(); var sz: float = min(s.y - 130, 540.0)
	open_panel(("Carte de la tour" if main.tower else "Carte du donjon") if map_dungeon else Maps.label(main.world.map_id), func(body: VBoxContainer):
		var holder := Control.new(); holder.custom_minimum_size = Vector2(sz, sz); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; body.add_child(holder)
		var tr := TextureRect.new(); tr.texture = map_tex; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.size = Vector2(sz, sz); holder.add_child(tr)
		var marks := Control.new(); marks.size = Vector2(sz, sz); holder.add_child(marks)
		marks.draw.connect(func(): _draw_bigmap(marks, sz))
	, sz + 70, sz + 110)

func _draw_bigmap(c: Control, sz: float) -> void:
	if map_dungeon:
		var P0: Player = main.player
		c.draw_circle(map_uv(Vector2(P0.global_position.x, P0.global_position.z)) * sz, 7, Color.WHITE); return
	var k := sz / 256.0
	for i in range(1, World.REGIONS.size()):
		var R: Dictionary = World.REGIONS[i]
		var rc: Vector2 = R.c
		if rc.distance_to(main.world.village) < 30.0: rc += (rc - main.world.village).normalized() * 30.0 if rc != main.world.village else Vector2(0, -30)
		_text(c, "%s (T%d)" % [R.name, R.tier], (rc + Vector2(128, 128)) * k, 16, Game.TIER_COL[R.tier], true, f_title)
	var V: Vector2 = main.world.village
	c.draw_circle((V + Vector2(128, 128)) * k, 8, Color("#ffe2a0")); _text(c, main.world.MAP.town.name, (V + Vector2(128, 128)) * k + Vector2(0, -12), 15, Color("#ffe2a0"), true, f_title)
	for g in main.world.gates:
		var qg: Vector2 = (Vector2(g.pos.x, g.pos.z) + Vector2(128, 128)) * k
		var cg: Color = Game.TIER_COL[Maps.TIERS[g.to][1]]
		c.draw_circle(qg, 9, Color(0, 0, 0, 0.6)); c.draw_circle(qg, 7, cg)
		var gt := "%s : %s (T%d-T%d)" % [g.dir, Maps.NAMES[g.to], Maps.TIERS[g.to][0], Maps.TIERS[g.to][1]]
		var gw: float = f_title.get_string_size(gt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var gp := qg + Vector2(0, -14 if qg.y > 40 else 26)
		gp.x = clamp(gp.x, gw * 0.5 + 4.0, sz - gw * 0.5 - 4.0)
		_text(c, gt, gp, 14, cg.lightened(0.3), true, f_title)
	for poi in main.world.pois:
		var q: Vector2 = (Vector2(poi.pos.x, poi.pos.z) + Vector2(128, 128)) * k
		var found: bool = Game.S.disc.has(poi.id)
		c.draw_circle(q, 5, Color("#ffe39a") if found else Color(1, 1, 1, 0.4))
		if found: _text(c, poi.name, q + Vector2(0, -9), 12, SOFT)
	for n in main.npcs:
		if n.act == "duel" and not n.hidden:
			var qd: Vector2 = (Vector2(n.home.x, n.home.z) + Vector2(128, 128)) * k
			c.draw_circle(qd, 5, Color("#ff8a4a"))
		elif n.act == "mercs":
			var qm: Vector2 = (Vector2(n.home.x, n.home.z) + Vector2(128, 128)) * k
			c.draw_circle(qm, 6, Color("#5dff7a")); _text(c, "Mercenaires", qm + Vector2(0, -9), 12, Color("#9dffb0"))
	for en in main.dungeon_entries:
		var qe: Vector2 = (Vector2(en.pos.x, en.pos.z) + Vector2(128, 128)) * k
		c.draw_circle(qe, 8, Color("#b46bff")); c.draw_arc(qe, 10, 0, TAU, 20, Color.WHITE, 2, true); _text(c, "Donjon T%d" % en.tier, qe + Vector2(0, 24), 13, Game.TIER_COL[en.tier])
	var wb = main.world_boss
	if wb and is_instance_valid(wb) and not wb.dead:
		var qb: Vector2 = (Vector2(wb.global_position.x, wb.global_position.z) + Vector2(128, 128)) * k
		c.draw_circle(qb, 10, Color("#d58bff")); _text(c, "%s T%d (groupe 4+)" % [wb.def.name, wb.tier], qb + Vector2(0, -14), 13, Color("#e8c8ff"))
	var P: Player = main.player; var pp := (Vector2(P.global_position.x, P.global_position.z) + Vector2(128, 128)) * k
	c.draw_circle(pp, 7, Color.WHITE); c.draw_arc(pp, 10, 0, TAU, 24, Color(0, 0, 0, 0.6), 2)
	var tg = main.goal_target
	if tg != null: c.draw_arc((Vector2(tg.x, tg.z) + Vector2(128, 128)) * k, 9, 0, TAU, 24, Color("#ffd24a"), 3)

# ——— Boutique royale (gratuite pour l'instant) ———
const SHOP_TABS := [["une", "★ À la une"], ["montures", "Montures"], ["armes", "Armes"], ["equip", "Équipements"], ["argent", "Argent"], ["ressources", "Ressources"], ["boosts", "Boosts"]]
# id, onglet, nom, description, icône, couleur, valeur affichée (barrée), mise en avant
const OFFERS := [
	{"id": "pegase", "tab": "montures", "name": "Pégase d'Azur", "desc": "+170 % vitesse · +30 % dégâts · +30 % vie", "icon": "mount_pegase", "col": "#5fb0ff", "val": 25000000, "hot": true},
	{"id": "m_roi_cerf", "tab": "montures", "name": "Roi-Cerf doré", "desc": "Monture T5 : +120 % vitesse, dégâts et vie", "icon": "mount_roi_cerf", "col": "#ffb02e", "val": 11000000},
	{"id": "m_taureau", "tab": "montures", "name": "Taureau cuirassé", "desc": "Monture T5 : +100 % vitesse, +12 % dégâts, +15 % vie", "icon": "mount_taureau", "col": "#ff6a5a", "val": 10000000},
	{"id": "m_loup", "tab": "montures", "name": "Loup de guerre", "desc": "Monture T4 : rapide, +8 % de vie", "icon": "mount_loup", "col": "#4d78ff", "val": 720000},
	{"id": "m_cheval", "tab": "montures", "name": "Cheval de selle", "desc": "Monture T2 : +75 % de vitesse", "icon": "mount_cheval", "col": "#62d24e", "val": 2800},
	{"id": "lame", "tab": "armes", "name": "Lame de l'Aube +5", "desc": "Épée T5 enchantée au maximum", "icon": "arme_epee_5", "col": "#ffb02e", "val": 9000000, "hot": true},
	{"id": "fendeuse", "tab": "armes", "name": "Fendeuse du Néant +5", "desc": "Hache T5 +5 : +28 % de dégâts bruts", "icon": "arme_hache_5", "col": "#ff6a5a", "val": 9000000},
	{"id": "sceptre", "tab": "armes", "name": "Sceptre Astral +5", "desc": "Bâton T5 +5 : sorts dévastateurs", "icon": "arme_baton_5", "col": "#c77dff", "val": 9000000},
	{"id": "titan", "tab": "armes", "name": "Rempart du Titan +5", "desc": "Bouclier T5 +5 : −20 % de dégâts reçus", "icon": "bouclier_5", "col": "#9fd4ff", "val": 6000000},
	{"id": "set_plate", "tab": "equip", "name": "Plates du Dragon +5", "desc": "Armure de plates T5 +5", "icon": "armure_plate", "col": "#ff3d3d", "val": 7500000},
	{"id": "set_cuir", "tab": "equip", "name": "Cuir de l'Ombre +5", "desc": "Veste de cuir T5 +5 : vitesse", "icon": "armure_cuir", "col": "#4fe36a", "val": 7500000},
	{"id": "set_tissu", "tab": "equip", "name": "Robe Céleste +5", "desc": "Robe de mage T5 +5 : recharges rapides", "icon": "armure_tissu", "col": "#b45cff", "val": 7500000},
	{"id": "bottes", "tab": "equip", "name": "Bottes de Vent +5", "desc": "Bottes T5 +5 : la vitesse ultime", "icon": "boots_5", "col": "#7fe8ff", "val": 4800000},
	{"id": "art_rage", "tab": "equip", "name": "Idole de rage +3", "desc": "Artefact T5 : +30 % de dégâts", "icon": "art_rage", "col": "#ff7a4a", "val": 6000000},
	{"id": "art_vie", "tab": "equip", "name": "Calice de vie +3", "desc": "Artefact T5 : +40 % de vie", "icon": "art_vie", "col": "#7dff8a", "val": 6000000},
	{"id": "art_fortune", "tab": "equip", "name": "Anneau de fortune +3", "desc": "Artefact T5 : +50 % d'argent gagné", "icon": "art_fortune", "col": "#ffd24a", "val": 6000000},
	{"id": "or1", "tab": "argent", "name": "Bourse d'argent", "desc": "100 000 argent", "icon": "it_coins", "col": "#ffd86b", "val": 100000},
	{"id": "or2", "tab": "argent", "name": "Coffre d'argent", "desc": "2 000 000 argent", "icon": "it_coins", "col": "#7fc8ff", "val": 2000000},
	{"id": "or3", "tab": "argent", "name": "Trésor royal", "desc": "50 000 000 argent", "icon": "it_chest_open", "col": "#e58bff", "val": 50000000, "hot": true},
	{"id": "or4", "tab": "argent", "name": "Fortune du roi", "desc": "500 000 000 argent", "icon": "it_trophy", "col": "#ff9a3c", "val": 500000000},
	{"id": "res2", "tab": "ressources", "name": "Pack d'apprenti T2", "desc": "120 bois, minerai et fibre T2", "icon": "res_ore_2", "col": "#62d24e", "val": 4300},
	{"id": "res3", "tab": "ressources", "name": "Pack d'artisan T3", "desc": "120 bois, minerai et fibre T3", "icon": "res_ore_3", "col": "#33c4dc", "val": 32000},
	{"id": "res4", "tab": "ressources", "name": "Pack de maître T4", "desc": "120 bois, minerai et fibre T4", "icon": "res_ore_4", "col": "#4d78ff", "val": 400000},
	{"id": "res5", "tab": "ressources", "name": "Pack légendaire T5", "desc": "120 bois, minerai et fibre T5", "icon": "res_ore_5", "col": "#ff3d3d", "val": 5000000, "hot": true},
	{"id": "leg", "tab": "boosts", "name": "Coffre légendaire", "desc": "Un butin légendaire T5 à ouvrir", "icon": "it_chest_open", "col": "#ffb02e", "val": 3000000, "hot": true},
	{"id": "enchant", "tab": "boosts", "name": "Parchemin d'enchantement", "desc": "+1 enchantement sur toutes les pièces portées", "icon": "art_rage", "col": "#e7a8ff", "val": 2000000},
	{"id": "metier", "tab": "boosts", "name": "Parchemin d'artisan", "desc": "+5 niveaux à tous les métiers", "icon": "pioche", "col": "#9dffb0", "val": 500000},
	{"id": "maitrise", "tab": "boosts", "name": "Parchemin de guerre", "desc": "+5 niveaux de maîtrise d'arme", "icon": "it_trophy", "col": "#ffb07a", "val": 500000},
	{"id": "potions", "tab": "boosts", "name": "Caisse de potions", "desc": "25 potions de soin", "icon": "potion", "col": "#7dff8a", "val": 1000},
	{"id": "sac", "tab": "boosts", "name": "Sac agrandi", "desc": "+8 cases (jusqu'à +24)", "icon": "it_loot_rare", "col": "#e9dcc0", "val": 250000},
	{"id": "garde", "tab": "boosts", "name": "Garde d'élite", "desc": "3 mercenaires T5 rejoignent ton groupe", "icon": "char_Knight", "col": "#9fd4ff", "val": 7500000},
]
var shop_tab := "une"
func _offer_tex(o: Dictionary) -> Texture2D:
	var k: String = o.icon
	if k == "char_Knight": return main.icons.char_icon("Knight")
	if k.begins_with("boots_"): return T(k)
	var t: Texture2D = main.icons.get_icon(k)
	if t == null and ResourceLoader.exists("res://ui/%s.png" % k): t = T(k)
	return t

func _offer_card(o: Dictionary, big: bool) -> PanelContainer:
	var col := Color(o.col)
	var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", flat(Color(0.06, 0.07, 0.1, 0.97).lerp(col, 0.14), 18, col, 3 if big else 2, Vector4(14, 12, 14, 12), 10 if big else 4))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); card.add_child(v)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 12); v.add_child(top)
	# icône sur halo de couleur
	var holder := Control.new(); var isz := 118.0 if big else 84.0; holder.custom_minimum_size = Vector2(isz, isz); top.add_child(holder)
	var gl := TextureRect.new(); gl.texture = glow_tex(); gl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gl.size = Vector2(isz, isz); gl.modulate = Color(col.r, col.g, col.b, 0.95); holder.add_child(gl)
	var ic := TextureRect.new(); ic.texture = _offer_tex(o); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; ic.position = Vector2(6, 6); ic.size = Vector2(isz - 12, isz - 12); holder.add_child(ic)
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.alignment = BoxContainer.ALIGNMENT_CENTER; top.add_child(info)
	if o.get("hot", false):
		var tag := PanelContainer.new(); tag.add_theme_stylebox_override("panel", flat(Color("#ff4a3a"), 8, Color(0, 0, 0, 0), 0, Vector4(8, 1, 8, 2))); tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tag.add_child(_label("POPULAIRE", 12, Color.WHITE)); info.add_child(tag)
	var nm := _label(o.name, 22 if big else 18, col.lightened(0.25)); nm.add_theme_font_override("font", f_title); info.add_child(nm)
	info.add_child(rich("[color=#c8ccd2]%s[/color]" % o.desc, 15))
	var pr := rich("[s][color=#8a8f98]valeur %s[/color][/s]   [b][color=#7dff8a]GRATUIT[/color][/b]" % Game.fmt(o.val), 15); info.add_child(pr)
	var b := big_button("Obtenir", true, func(): main.shop_claim(o.id), GOLD, true)
	b.custom_minimum_size = Vector2(0, 46); b.add_theme_font_size_override("font_size", 19); v.add_child(b)
	return card

func show_boutique(tab := "") -> void:
	if tab != "": shop_tab = tab
	open_panel("Boutique royale", func(body: VBoxContainer):
		cur_panel = "boutique"
		var ban := PanelContainer.new(); ban.add_theme_stylebox_override("panel", flat(Color(0.32, 0.16, 0.04, 0.96), 14, Color("#ffcf5a"), 2, Vector4(16, 8, 16, 8))); body.add_child(ban)
		ban.add_child(rich("[center][b][color=#ffe39a]✦ OFFRES DE LANCEMENT ✦[/color][/b]   ·   [color=#fff4d6]tout est [b][color=#7dff8a]GRATUIT[/color][/b] pour l'instant[/color]   ·   [color=#ffd86b]ta bourse : %s[/color][/center]" % Game.fmt(Game.S.silver), 18))
		var tabs := HFlowContainer.new(); tabs.add_theme_constant_override("h_separation", 6); tabs.add_theme_constant_override("v_separation", 6); body.add_child(tabs)
		for t in SHOP_TABS: _chip(tabs, t[1], shop_tab == t[0], func(): show_boutique(t[0]))
		var list: Array = []
		for o in OFFERS:
			if (shop_tab == "une" and o.get("hot", false)) or o.tab == shop_tab: list.append(o)
		var grid := GridContainer.new(); grid.columns = 2 if shop_tab == "une" else 3; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12); body.add_child(grid)
		for o in list: grid.add_child(_offer_card(o, shop_tab == "une"))
	, 1220)

# ——— Enchantement (Ysaline) ———
func show_enchant() -> void:
	open_panel("Sanctuaire des enchantements", func(body: VBoxContainer):
		cur_panel = "enchant"
		body.add_child(rich("[color=#a8b4bc]Chaque enchantement ajoute [color=#e7a8ff]+12 %% de puissance[/color] à la pièce portée (jusqu'à +5). Il reste gravé sur l'objet, même si tu le revends. Ta bourse : [color=#ffd86b][b]%s[/b][/color][/color]" % Game.fmt(Game.S.silver), 17))
		for slot in Game.ENCH_SLOTS:
			var it := Game.equipped_item(slot); var t := int(it.tier)
			if t <= 0:
				row(body, _with_icon(null, 0, rich("[b]%s[/b] — [color=#8a9298]rien d'équipé[/color]" % Game.SLOT_NAME[slot], 18)), Control.new()); continue
			var e := Game.ench(slot)
			var stars := ""
			for k in Game.ENCH_MAX: stars += "[color=%s]◆[/color]" % ("#e7a8ff" if k < e else "#3a3f48")
			var right: Control
			if e >= Game.ENCH_MAX: right = _label("MAXIMUM", 20, Color("#e7a8ff"))
			else:
				var cost := Game.ench_cost(slot, t, e + 1)
				var b := big_button("Enchanter +%d" % (e + 1), Game.S.silver >= cost, func(): main.enchant(slot), GOLD, true); b.custom_minimum_size = Vector2(190, 48)
				right = _price_box(cost, b)
			var tx: Texture2D = main.icons.item_icon(it)
			var h := _with_icon(tx, t, rich("[b]%s[/b]\n%s   [color=#a8b4bc]puissance +%d %%[/color]" % [Game.item_name(it), stars, 12 * e], 18))
			row(body, h, right)
	, 980)

# ——— Port et île ———
func _info_card(body: Control, col: Color, title_txt: String, text: String, btn: Button = null) -> void:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", flat(Color(0.06, 0.08, 0.12, 0.96).lerp(col, 0.12), 16, col, 2, Vector4(16, 12, 16, 12))); body.add_child(p)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); p.add_child(v)
	var t := _label(title_txt, 22, col.lightened(0.25)); t.add_theme_font_override("font", f_title); v.add_child(t)
	v.add_child(rich(text, 16))
	if btn: v.add_child(btn)

func show_harbor() -> void:
	open_panel("Capitaine Marlo — îles à vendre", func(body: VBoxContainer):
		cur_panel = "harbor"
		var I: Dictionary = Game.S.island
		body.add_child(rich("[i][color=#d8c8a8]« Une île à toi, moussaillon ! Des ouvriers qui récoltent pendant que tu dors… mais gare aux bandits. »[/color][/i]   ·   ta bourse : [color=#ffd86b]%s[/color]" % Game.fmt(Game.S.silver), 17))
		var prod: Array = Game.island_prod(1)
		var txt := "• [b]Logis des ouvriers[/b] : chaque nuit à minuit, ils remplissent ton coffre : [color=#4d78ff]%d de chaque ressource T4[/color] et [color=#ff3d3d]%d de chaque ressource T5[/color] (les ouvriers gardent 20 %%).\n• [b]4 champs[/b] à semer (récolte toutes les 3 h : argent + potions + fibre).\n• [b]Enclos d'élevage[/b] : 2 montures de la même espèce → un bébé toutes les 20 h, qui se revend très cher.\n• [color=#ff7a6a][b]Bandits[/b] : 2 attaques par jour, à une heure imprévisible. 15 min pour les repousser (10 groupes), sinon ils vident ton coffre.[/color] Des gardes peuvent défendre l'île en ton absence." % [prod[0][1], prod[1][1]]
		if I.owned:
			var b := big_button("Embarquer pour mon île", true, func(): close_panel(); main.go_island(), GOLD, true); b.custom_minimum_size = Vector2(0, 54)
			_info_card(body, Color("#5fb0ff"), "%s — niveau %d" % [Game.ISLAND_NAME[I.lvl], I.lvl], "Tu possèdes déjà ton île. Le bouton [b]MON ÎLE[/b] (à droite) t'y téléporte de n'importe où.", b)
		else:
			var b2 := big_button("Acheter l'île · %s" % Game.fmt(Game.ISLAND_PRICE), Game.S.silver >= Game.ISLAND_PRICE, func(): main.buy_island(), GOLD, true); b2.custom_minimum_size = Vector2(0, 56); b2.add_theme_font_size_override("font_size", 22)
			_info_card(body, Color("#ffb02e"), "Petite île de départ", txt, b2)
	, 920)

func show_island() -> void:
	open_panel("Logis des ouvriers", func(body: VBoxContainer):
		cur_panel = "island"
		var I: Dictionary = Game.S.island; var lvl: int = I.lvl
		var now := Time.get_unix_time_from_system()
		var prod: Array = Game.island_prod(lvl)
		_info_card(body, Color("#ffd27a"), "%s — niveau %d / 5" % [Game.ISLAND_NAME[lvl], lvl], "Chaque nuit à minuit : [color=#4d78ff]%d × chaque ressource T4[/color] + [color=#ff3d3d]%d × chaque ressource T5[/color] dans le coffre (après la part de 20 %% des ouvriers)." % [int(prod[0][1] * 0.8), int(prod[1][1] * 0.8)])
		if lvl < 5:
			var nprod: Array = Game.island_prod(lvl + 1)
			var bu := big_button("Agrandir l'île · %s" % Game.fmt(Game.ISLAND_UP[lvl + 1]), Game.S.silver >= Game.ISLAND_UP[lvl + 1], func(): main.upgrade_island(), GOLD, true); bu.custom_minimum_size = Vector2(0, 48)
			_info_card(body, Color("#62d24e"), "Prochain niveau : %s" % Game.ISLAND_NAME[lvl + 1], "Production : %d T4 + %d T5 par ressource et par jour. Bandits plus forts (T%d), butin meilleur." % [int(nprod[0][1] * 0.8), int(nprod[1][1] * 0.8), Game.bandit_tier(lvl + 1)], bu)
		var guarded: bool = float(I.guard_until) > now
		var gtxt := ("[color=#9dffb0]Gardes en poste encore %d h.[/color] " % int((float(I.guard_until) - now) / 3600.0)) if guarded else "[color=#ff8a7a]Aucun garde : si tu n'es pas là pendant un raid, tu perds tout le coffre.[/color] "
		gtxt += "Les gardes repoussent les bandits à ta place et mettent [b]la moitié de leur butin[/b] dans ton coffre."
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8)
		for dd in [1, 7]:
			var b := big_button("%d jour%s · %s" % [dd, "s" if dd > 1 else "", Game.fmt(Game.guard_price(lvl) * dd)], Game.S.silver >= Game.guard_price(lvl) * dd, func(): main.hire_guards(dd), GOLD, true); b.custom_minimum_size = Vector2(260, 46); hb.add_child(b)
		_info_card(body, Color("#9fd4ff"), "Gardes de l'île", gtxt); body.add_child(hb)
		var rt := ""
		for r in I.raids: rt += {"wait": "• Attaque à venir (heure inconnue)\n", "active": "• [color=#ff6a5a][b]ATTAQUE EN COURS ![/b][/color]\n", "won": "• Attaque repoussée par toi ✓\n", "guard": "• Attaque repoussée par les gardes ✓\n", "lost": "• [color=#ff8a7a]Île pillée ✗[/color]\n"}[r.st]
		_info_card(body, Color("#ff7a6a"), "Bandits aujourd'hui", rt if rt != "" else "Rien à signaler.")
	, 900)

func show_island_chest() -> void:
	var I: Dictionary = Game.S.island
	if I.chest.loot.is_empty(): toast("Le coffre est vide — tes ouvriers le remplissent chaque nuit à minuit", Color("#ffe39a")); return
	show_loot({"rarity": 2, "loot": I.chest.loot, "title": "Coffre de l'île", "pos": Vector3.ZERO, "opened": false})

func show_pen() -> void:
	open_panel("Enclos d'élevage", func(body: VBoxContainer):
		cur_panel = "pen"
		var I: Dictionary = Game.S.island; var now := Time.get_unix_time_from_system()
		body.add_child(rich("[color=#a8b4bc]Place [b]2 montures de la même espèce[/b] : toutes les 20 h, un bébé naît. Les bébés se revendent [b]2,5 fois[/b] plus cher à l'hôtel des ventes. Les montures rares tombent sur les gros boss (boss de groupe, gardiens de la Tour dès l'étage 10, donjons).[/color]", 16))
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); body.add_child(h)
		for k in 2:
			var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); h.add_child(v)
			if k < I.pen.size():
				var a: Dictionary = I.pen[k]
				v.add_child(slot_box(main.icons.get_icon("mount_" + a.kind), a.tier, 1, true, Callable(), 110))
				v.add_child(_label(Game.MOUNTS[a.kind].name, 15, SOFT))
				var b := big_button("Reprendre", true, func(): main.pen_remove(k)); b.custom_minimum_size = Vector2(130, 40); v.add_child(b)
			else:
				v.add_child(slot_box(null, 0, 0, false, Callable(), 110)); v.add_child(_label("Place libre", 15, Color("#8a9298")))
		var st := ""
		if I.pen.size() == 2 and I.pen[0].kind == I.pen[1].kind:
			var left: float = Game.BREED_TIME - (now - float(I.pen_t))
			if left <= 0:
				var bc := big_button("Récupérer le bébé !", true, func(): main.pen_collect(), GOLD, true); bc.custom_minimum_size = Vector2(260, 54); h.add_child(bc)
			else: st = "Naissance dans %d h %02d" % [int(left / 3600), int(fmod(left, 3600.0) / 60)]
		elif I.pen.size() == 2: st = "Les deux montures doivent être de la même espèce"
		if st != "": h.add_child(rich("[b]%s[/b]" % st, 18))
		body.add_child(_label("TES MONTURES (sac)", 15, GOLD))
		var g := GridContainer.new(); g.columns = 6; g.add_theme_constant_override("h_separation", 8); body.add_child(g)
		var any := false
		for i in Game.S.items.size():
			var it: Dictionary = Game.S.items[i]
			if it.slot != "monture" or it.get("bebe", false): continue
			any = true
			var v2 := VBoxContainer.new(); g.add_child(v2)
			v2.add_child(slot_box(main.icons.item_icon(it), it.tier, 1, false, func(): main.pen_add(i), 80))
			v2.add_child(_label("Placer", 13, Color("#9dffb0")))
		if not any: body.add_child(rich("[color=#8a9298]Aucune monture dans ton sac (déséquipe la tienne ou achète-en à l'hôtel des ventes).[/color]", 15))
	, 900)

# ——— Mercenaires (Rhéa) ———
func show_mercs() -> void:
	open_panel("Compagnie de Rhéa", func(body: VBoxContainer):
		cur_panel = "mercs"
		body.add_child(rich("[color=#a8b4bc]Engage jusqu'à 3 mercenaires : avec eux, tu formes un groupe de 4 — obligatoire pour blesser les boss de groupe. Ils te suivent partout (même en donjon), mais restent à l'écart pendant les duels. S'ils tombent, ils sont perdus.[/color]", 16))
		body.add_child(_label("TON GROUPE (%d / 3)" % Game.S.mercs.size(), 15, GOLD))
		if Game.S.mercs.is_empty(): body.add_child(rich("[color=#8a9298]Personne pour l'instant.[/color]", 16))
		for i in Game.S.mercs.size():
			var d: Dictionary = Game.S.mercs[i]; var T0: Dictionary = Ally.TYPES[d.type]
			var hp_txt := ""
			for a in main.allies:
				if is_instance_valid(a) and a.nm == d.name: hp_txt = " · vie %d / %d" % [int(a.hp), int(a.max_hp)]
			var bt := big_button("Renvoyer", true, func(): main.dismiss_merc(i), Color("#ffb09a")); bt.custom_minimum_size = Vector2(150, 48)
			row(body, _with_icon(main.icons.char_icon(T0.model), int(d.tier), rich("[b]%s[/b] — %s %s%s\n[color=#a8b4bc]%s[/color]" % [d.name, T0.name, tier_tag(int(d.tier)), hp_txt, T0.desc], 18)), bt)
		body.add_child(_label("ENGAGER", 15, GOLD))
		var maxt: int = clamp(Game.S.gear.epee, 1, 5)
		for ty in Ally.TYPES:
			var T1: Dictionary = Ally.TYPES[ty]
			var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(_with_icon(main.icons.char_icon(T1.model), 0, rich("[b]%s[/b]\n[color=#a8b4bc]%s[/color]" % [T1.name, T1.desc], 18)))
			var hb := HFlowContainer.new(); hb.add_theme_constant_override("h_separation", 6); hb.add_theme_constant_override("v_separation", 6); box.add_child(hb)
			for t in range(1, maxt + 1):
				var price: int = main.merc_price(t)
				var b := big_button("T%d · %s" % [t, Game.fmt(price)], Game.S.silver >= price and Game.S.mercs.size() < 3, func(): main.hire_merc(ty, t), Game.TIER_COL[t].lightened(0.3), true)
				b.custom_minimum_size = Vector2(130, 46); b.add_theme_font_size_override("font_size", 17); hb.add_child(b)
			var p2 := PanelContainer.new(); p2.add_theme_stylebox_override("panel", flat(Color(1, 1, 1, 0.05), 14, Color(1, 1, 1, 0.08), 1, Vector4(14, 10, 12, 10))); p2.add_child(box); body.add_child(p2)
		body.add_child(rich("[color=#8a9298]Tier maximum = tier de ton arme (T%d). Prix en argent, une seule fois.[/color]" % maxt, 14))
	, 900)

# ——— Butin d'un coffre : petites cases beiges, « Tout prendre » ———
func show_loot(c: Dictionary) -> void:
	var R0: Dictionary = Tower.RARITY[c.rarity]
	loot_cur = c
	open_panel(c.get("title", "Coffre %s" % R0.name.to_lower() if c.rarity < 3 else "COFFRE LÉGENDAIRE"), func(body: VBoxContainer):
		cur_panel = "loot"
		var band := ColorRect.new(); band.color = R0.col; band.custom_minimum_size = Vector2(0, 6); body.add_child(band)
		var tag: String = R0.name if c.has("beam") or not c.has("title") else "%d objet%s" % [c.loot.size(), "s" if c.loot.size() > 1 else ""]
		body.add_child(rich("[color=#%s][b]%s[/b][/color]   [color=#a8b4bc]Touche une case pour la prendre, ou prends tout d'un coup.[/color]" % [R0.col.to_html(false), tag], 18))
		var holder := PanelContainer.new(); holder.add_theme_stylebox_override("panel", flat(Color("#5a4228"), 16, Color("#c8a46a"), 3, Vector4(16, 14, 16, 14)))
		body.add_child(holder)
		var g := GridContainer.new(); g.columns = 6; g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10); holder.add_child(g)
		for i in max(6, c.loot.size()):
			if i < c.loot.size():
				var l: Dictionary = c.loot[i]
				var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
				var tx: Texture2D; var tier := 0; var cnt := 1; var nm := ""; var en := 0
				if l.has("silver"): tx = T("it_coins"); nm = "%s argent" % Game.fmt(l.silver)
				elif l.has("potion"): tx = main.icons.get_icon("potion"); cnt = int(l.potion); nm = "Potions"
				elif l.has("res"): tx = res_tex(l.res, l.tier); tier = l.tier; cnt = int(l.qty); nm = Game.RES[l.res].tiers[l.tier]
				else: tx = main.icons.item_icon(l.item); tier = l.item.tier; nm = Game.item_name(l.item); en = int(l.item.get("ench", 0))
				v.add_child(slot_box(tx, tier, cnt, false, func(): _take(c, i), 92, en, true))
				var lb := _label(nm, 12, Color("#f4e6c8")); lb.custom_minimum_size = Vector2(92, 0); lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(lb)
				g.add_child(v)
			else: g.add_child(slot_box(null, 0, 0, false, Callable(), 92, 0, true))
		var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_END; h.add_theme_constant_override("separation", 10); body.add_child(h)
		h.add_child(_label("Sac %d / %d" % [Game.bag_used(), Game.bag_size()], 17, SOFT))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
		var b := big_button("Tout prendre", not c.loot.is_empty(), func(): _take_all(c), GOLD, true); b.custom_minimum_size = Vector2(240, 58); b.add_theme_font_size_override("font_size", 24); h.add_child(b)
	, 760)

func _take_all(c: Dictionary) -> void:
	main.take_all(c)
	if c.loot.is_empty(): close_panel()
	else: show_loot(c)

func _take(c: Dictionary, i: int) -> void:
	if main.take_loot(c, i):
		Game.play("pickup", -4.0, 1.2)
		if c.loot.is_empty(): main._chest_emptied(c); close_panel(); Game.save(); return
	Game.save(); show_loot(c)

# petite fenêtre oui / non
func confirm(title_txt: String, text: String, yes: Callable) -> void:
	open_panel(title_txt, func(body: VBoxContainer):
		body.add_child(rich(text, 19))
		var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_END; h.add_theme_constant_override("separation", 10); body.add_child(h)
		h.add_child(big_button("Annuler", true, func(): close_panel()))
		h.add_child(big_button("Continuer", true, func(): close_panel(); yes.call(), GOLD, true))
	, 640, 280)

# Compte à rebours rouge 3 · 2 · 1 · GO
func countdown(done: Callable) -> void:
	var steps := ["3", "2", "1", "GO !"]
	for i in steps.size():
		get_tree().create_timer(0.6 + i * 1.0).timeout.connect(func():
			var l := _label(steps[i], 150 if i < 3 else 120, Color("#ff2f2f") if i < 3 else Color("#ffd24a"))
			l.add_theme_font_override("font", f_title); l.add_theme_constant_override("outline_size", 18); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			root.add_child(l); l.reset_size(); l.pivot_offset = l.size * 0.5; l.position = (vs() - l.size) * 0.5 - Vector2(0, 40)
			l.scale = Vector2(1.6, 1.6)
			var tw := l.create_tween(); tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK); tw.tween_interval(0.45); tw.tween_property(l, "modulate:a", 0.0, 0.25); tw.tween_callback(l.queue_free)
			Game.play("hit" if i < 3 else "level", -4.0, 0.7 if i < 3 else 1.0)
			if i == steps.size() - 1: done.call())

func show_dialog(npc: Npc, text: String, actions: Array) -> void:
	close_panel(); panel_open = true
	for n in buttons: buttons[n].held = false
	joy.id = -1; joy.vec = Vector2.ZERO; touches.clear()
	var s := vs(); var w: float = min(820.0, s.x - 80)
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", flat(Color(0.06, 0.08, 0.12, 0.92), 22, Color(0.95, 0.78, 0.45, 0.45), 2, Vector4(26, 14, 26, 16), 12))
	pc.custom_minimum_size = Vector2(w, 0); root.add_child(pc); panel = pc
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); pc.add_child(v)
	var hdr := HBoxContainer.new(); v.add_child(hdr)
	var nl := _label(npc.nm, 26, GOLD); nl.add_theme_font_override("font", f_title); hdr.add_child(nl)
	hdr.add_child(_label("  ·  " + npc.role, 17, Color("#a8c8e0")))
	var tx := rich(text, 19); tx.custom_minimum_size = Vector2(w - 60, 0); v.add_child(tx)
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_END; h.add_theme_constant_override("separation", 10); v.add_child(h)
	for a in actions: h.add_child(big_button(a[0], true, a[1], GOLD, a.size() > 2))
	pc.position = Vector2((s.x - w) * 0.5, s.y)
	_place_dialog.call_deferred(pc)
	pc.resized.connect(func(): _place_dialog(pc))   # le texte s'agrandit : on remonte la fenêtre pour garder les boutons visibles

func _place_dialog(pc: Control) -> void:
	if not is_instance_valid(pc): return
	pc.reset_size(); var s := vs()
	pc.position = Vector2((s.x - pc.size.x) * 0.5, s.y - pc.size.y - 20)

func show_title() -> void:
	panel_open = true
	title = Control.new(); title.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(title)
	var bg := ColorRect.new(); bg.color = Color(0.02, 0.03, 0.05, 0.5); bg.set_anchors_preset(Control.PRESET_FULL_RECT); title.add_child(bg)
	var cc := CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); title.add_child(cc)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 12); cc.add_child(v)
	var t := _label("VALDRUNE", 100, GOLD); t.add_theme_font_override("font", f_title); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; t.add_theme_constant_override("outline_size", 14); v.add_child(t)
	var oc := CenterContainer.new(); var orn := TextureRect.new(); orn.texture = T("orn_line"); orn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; orn.custom_minimum_size = Vector2(520, 58); oc.add_child(orn); v.add_child(oc)
	var st := _label("Explore · Récolte · Forge · Combats", 24, SOFT); st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(st)
	var b := big_button("Jouer", true, func(): _start(), GOLD, true); b.custom_minimum_size = Vector2(300, 74); b.add_theme_font_size_override("font_size", 32)
	var c := CenterContainer.new(); c.add_child(b); v.add_child(c)

func _start() -> void:
	title.queue_free(); panel_open = false
	main.on_start()
