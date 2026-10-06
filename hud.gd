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

# bouton façon Albion : pilule de bois sombre cerclée d'or, léger relief
func _wood_btn(bg: Color) -> StyleBoxFlat:
	var st := flat(bg, 24, Color("#c79a4a"), 3, Vector4(22, 10, 22, 12))
	st.shadow_color = Color(0.2, 0.12, 0.05, 0.45); st.shadow_size = 3; st.shadow_offset = Vector2(0, 2)
	return st
func _red_btn() -> StyleBoxFlat:
	var st := flat(Color("#9a2a1c"), 24, Color("#f0c060"), 3, Vector4(22, 10, 22, 12))
	st.shadow_color = Color(0.2, 0.05, 0.02, 0.5); st.shadow_size = 3; st.shadow_offset = Vector2(0, 2)
	return st

func _make_theme() -> void:
	f_title = load("res://ui/serif_bold.ttf")
	theme_ui = Theme.new()
	var bpad := Vector4(22, 10, 22, 12)
	theme_ui.set_stylebox("normal", "Button", _wood_btn(Color("#3e2d1e")))
	theme_ui.set_stylebox("hover", "Button", _wood_btn(Color("#4d3926")))
	theme_ui.set_stylebox("pressed", "Button", _wood_btn(Color("#2c2015")))
	theme_ui.set_stylebox("disabled", "Button", flat(Color("#bfa97c"), 24, Color("#9a8158"), 2, bpad))
	theme_ui.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_ui.set_font("font", "Button", f_title); theme_ui.set_font_size("font_size", "Button", 21)
	theme_ui.set_color("font_color", "Button", Color("#ffe6a8")); theme_ui.set_color("font_hover_color", "Button", Color("#fff2c8"))
	theme_ui.set_color("font_pressed_color", "Button", Color.WHITE); theme_ui.set_color("font_disabled_color", "Button", Color("#7a6648"))
	theme_ui.set_stylebox("scroll", "VScrollBar", flat(Color(0.35, 0.24, 0.12, 0.18), 6, Color(0, 0, 0, 0), 0, Vector4(4, 4, 4, 4)))
	theme_ui.set_stylebox("grabber", "VScrollBar", flat(Color("#7a5530"), 7, Color(0, 0, 0, 0), 0, Vector4(6, 14, 6, 14)))
	theme_ui.set_stylebox("grabber_highlight", "VScrollBar", flat(Color("#946a3e"), 7, Color(0, 0, 0, 0), 0, Vector4(6, 14, 6, 14)))
	theme_ui.set_stylebox("grabber_pressed", "VScrollBar", flat(Color("#b07e48"), 7, Color(0, 0, 0, 0), 0, Vector4(6, 14, 6, 14)))
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
	gp.position = Vector2(12, 92); gp.custom_minimum_size = Vector2(300, 0); gp.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(gp)
	var qv := VBoxContainer.new(); qv.add_theme_constant_override("separation", 2); gp.add_child(qv)
	var qh := _label("OBJECTIF", 11, Color(0.95, 0.78, 0.45, 0.8)); qh.add_theme_font_override("font", f_title); qv.add_child(qh)
	goal_lbl = RichTextLabel.new(); goal_lbl.bbcode_enabled = true; goal_lbl.fit_content = true; goal_lbl.scroll_active = false
	goal_lbl.add_theme_font_size_override("normal_font_size", 14); goal_lbl.add_theme_font_size_override("bold_font_size", 15)
	goal_lbl.custom_minimum_size = Vector2(276, 0); goal_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; qv.add_child(goal_lbl)
	hint_lbl = RichTextLabel.new(); hint_lbl.bbcode_enabled = true; hint_lbl.fit_content = true; hint_lbl.scroll_active = false
	hint_lbl.add_theme_font_size_override("normal_font_size", 18); hint_lbl.add_theme_constant_override("outline_size", 6); hint_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint_lbl.custom_minimum_size = Vector2(520, 0); hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(hint_lbl)
	toasts = VBoxContainer.new(); toasts.custom_minimum_size = Vector2(560, 0); toasts.alignment = BoxContainer.ALIGNMENT_CENTER; toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(toasts)
	minimap = TextureRect.new(); minimap.size = Vector2(176, 176); minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mm := ShaderMaterial.new(); mm.shader = map_sh; minimap.material = mm; root.add_child(minimap)
	region_lbl = _label("", 15, SOFT); region_lbl.add_theme_font_override("font", f_title); region_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; region_lbl.size = Vector2(220, 22); root.add_child(region_lbl)
	for i in 4: icons["s%d" % i] = icon_rect(Player.skills()[i].icon, Vector2(70, 70), 1.12)
	icons.attack = icon_rect("sk_sword_bash_orange", Vector2(96, 96), 1.1)
	icons.bag = icon_rect("it_loot_common", Vector2(42, 42), 0.9)
	overlay = Control.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.draw.connect(_draw_over); root.add_child(overlay)
	red = ColorRect.new(); red.color = Color(0.8, 0, 0, 0.0); red.set_anchors_preset(Control.PRESET_FULL_RECT); red.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(red)
	fps_lbl = _label("", 12, Color(0.8, 1, 0.8, 0.6)); root.add_child(fps_lbl)
	for n in ["main", "dodge", "s0", "s1", "s2", "s3", "potion", "mount", "bag", "menu", "zoom", "shop", "ile", "map", "daily", "rank"]: buttons[n] = {"rect": Rect2(), "held": false}
	auto_btn = Button.new(); auto_btn.focus_mode = Control.FOCUS_NONE; auto_btn.custom_minimum_size = Vector2(92, 44)
	auto_btn.add_theme_font_override("font", f_title); auto_btn.add_theme_font_size_override("font_size", 16)
	auto_btn.pressed.connect(func(): show_auto()); root.add_child(auto_btn)
	chat_box = Button.new(); chat_box.focus_mode = Control.FOCUS_NONE; chat_box.custom_minimum_size = Vector2(300, 30); chat_box.size = Vector2(300, 30)
	var cst := flat(Color(0.03, 0.05, 0.08, 0.5), 12, Color(0.6, 0.8, 1.0, 0.18), 1, Vector4(10, 6, 10, 6))
	for k in ["normal", "hover", "pressed"]: chat_box.add_theme_stylebox_override(k, cst)
	chat_lbl = RichTextLabel.new(); chat_lbl.bbcode_enabled = true; chat_lbl.scroll_active = false; chat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_lbl.position = Vector2(10, 5); chat_lbl.size = Vector2(282, 22); chat_lbl.clip_contents = true; chat_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF; chat_lbl.add_theme_font_size_override("normal_font_size", 12); chat_lbl.add_theme_font_size_override("bold_font_size", 12)
	chat_lbl.add_theme_constant_override("outline_size", 4); chat_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	chat_box.add_child(chat_lbl); chat_box.pressed.connect(func(): show_chat()); root.add_child(chat_box)
	quest_box = gp; gp.resized.connect(_place_chat)
	get_viewport().size_changed.connect(_layout); _layout()
	refresh_auto()

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
	toasts.position = Vector2((s.x - 560) * 0.5, 94)
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
	# une seule rangée d'icônes discrètes en haut à droite (comme Albion)
	var row := ["menu", "bag", "shop", "daily", "rank", "ile", "zoom"]
	var xi := 0
	for nm in row:
		if nm == "ile" and not Game.S.island.owned: continue
		if nm in ["daily", "rank"] and main.tuto_i() < 9: buttons[nm].rect = Rect2(); continue
		buttons[nm].rect = Rect2(Vector2(s.x - 258 - xi * 64, 8), Vector2(52, 52)); xi += 1
	row_end_x = s.x - 258 - xi * 64
	icons.bag.position = buttons.bag.rect.position + Vector2(5, 5)
	icons.attack.position = mc - Vector2(48, 48)
	hint_lbl.position = Vector2(s.x - 560 - 40, mc.y - 220)
	if auto_btn: auto_btn.position = Vector2(row_end_x - 40, 12)
	_place_chat()

var pinch := {}
var pinch_d0 := 0.0
var pinch_z0 := 1.0
func _input(ev: InputEvent) -> void:
	# molette de la souris : zoom
	if ev is InputEventMouseButton and ev.pressed and not panel_open and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		main.user_zoom = clamp(main.user_zoom * (0.92 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.08), 0.75, 1.6)
	if main.builder and main.builder.active: return
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed): drag_guard = false
	if panel_open and cur_panel != "bag": return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not panel_open and not DisplayServer.is_touchscreen_available():
		if not chat_box.get_global_rect().has_point(ev.position): main.try_pick_player(ev.position)
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
			tap_from = p; tap_t = Time.get_ticks_msec()
			if p.x < vs().x * 0.5 and joy.id == -1:
				joy.id = ev.index; joy.base = p; joy.pos = p; joy.vec = Vector2.ZERO; touches[ev.index] = "joy"
			elif not chat_box.get_global_rect().has_point(p):
				touches[ev.index] = "tap"; pinch[ev.index] = p
				if pinch.size() == 2: pinch_d0 = 0.0
		else:
			var role = touches.get(ev.index, "")
			var quick: bool = Time.get_ticks_msec() - tap_t < 350 and p.distance_to(tap_from) < 18.0
			if role == "tap" and quick: main.try_pick_player(p)
			if role == "joy" and quick and not chat_box.get_global_rect().has_point(p): main.try_pick_player(p)
			if role == "tap": touches.erase(ev.index); pinch.erase(ev.index); pinch_d0 = 0.0; return
			if role == "joy": joy.id = -1; joy.vec = Vector2.ZERO
			elif role != "": buttons[role].held = false
			touches.erase(ev.index)
	elif ev is InputEventScreenDrag:
		# deux doigts sur la droite de l'écran : pincer pour zoomer
		if pinch.has(ev.index):
			pinch[ev.index] = ev.position
			if pinch.size() == 2:
				var ks: Array = pinch.keys()
				var d: float = (pinch[ks[0]] as Vector2).distance_to(pinch[ks[1]])
				if pinch_d0 <= 0.0: pinch_d0 = d; pinch_z0 = main.user_zoom
				elif d > 10.0: main.user_zoom = clamp(pinch_z0 * pinch_d0 / d, 0.75, 1.6)
				tap_t = 0
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
		"daily": show_daily()
		"rank": show_ranking()
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

func main_held() -> bool: return buttons.main.held or Input.is_key_pressed(KEY_SPACE) or main.auto_hold

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

# boutons ronds façon Albion : médaillon de fer cerclé d'or (comme les en-têtes des fenêtres)
func _glass(c: CanvasItem, ctr: Vector2, r: float, ring: Color, held := false) -> void:
	_disc(ctr, r * 0.9, Color(0.05, 0.05, 0.06, 0.55 if not held else 0.8))
	var k: float = r * 1.12
	_texq(T("medal_ring"), Rect2(ctr - Vector2(k, k), Vector2(k, k) * 2.0), Color(1, 1, 1, 0.95) if not held else Color(1.25, 1.15, 0.9, 1.0))
	if ring.a > 0.62: _ringq(ctr, r * 1.2, Color(ring.r, ring.g, ring.b, ring.a * 0.8))

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
	var bag_hint: bool = main.tuto_active() and main.TUTO[main.tuto_i()].k == "equip"
	_glass(c, buttons.bag.rect.get_center(), 26 if not bag_hint else 30, Color(1.0, 0.85, 0.3, 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)) if bag_hint else Color(0.95, 0.78, 0.45, 0.5))
	_glass(c, buttons.menu.rect.get_center(), 26, Color(0.95, 0.78, 0.45, 0.6))
	var shc: Vector2 = buttons.shop.rect.get_center()
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.004)
	_glass(c, shc, 26, Color(1.0, 0.7, 0.2, pulse))
	_texq(T("crown"), Rect2(shc - Vector2(18, 19), Vector2(36, 36)))
	# pendant l'introduction, on n'affiche QUOTIDIEN et CLASSEMENT qu'au bon moment (moins de boutons d'un coup)
	var hide_dr: bool = main.tuto_i() < 9
	if hide_dr != (buttons.daily.rect.size.x == 0) or (Game.S.island.owned != (buttons.ile.rect.size.x > 0)): _layout()
	if not hide_dr: _draw_daily_rank(c, pulse)

	if Game.S.island.owned:
		var ic2: Vector2 = buttons.ile.rect.get_center()
		var danger: bool = main.raid_active()
		var pz := 0.6 + 0.4 * sin(Time.get_ticks_msec() * (0.012 if danger else 0.003))
		_glass(c, ic2, 26, Color(1.0, 0.25, 0.2, pz) if danger else Color(0.4, 0.8, 1.0, 0.7))
		_texq(T("it_treasure_map"), Rect2(ic2 - Vector2(18, 19), Vector2(36, 36)))
	if main.island and main.island.raid_on:
		var gtxt := "Bandits : %d / 10 groupes" % main.island.groups_cleared()
		c.draw_style_box(flat(Color(0.25, 0.03, 0.03, 0.85), 12, Color("#ff5a4a"), 2), Rect2(12, 300, 260, 42))
		_text(c, gtxt, Vector2(142, 328), 19, Color("#ffd2c8"), true, f_title)
	var zc: Vector2 = buttons.zoom.rect.get_center()
	_glass(c, zc, 26, Color(0.95, 0.78, 0.45, 0.6))
	_ringq(zc + Vector2(-3, -3), 10, SOFT); c.draw_line(zc + Vector2(4, 4), zc + Vector2(11, 11), SOFT, 3.0, true)
	_text(c, "%.1f" % main.user_zoom, zc + Vector2(-3, 1), 10, GOLD)
	# une étiquette claire sous chaque icône du haut : on sait toujours où cliquer
	for nm in ROW_LBL:
		var rr: Rect2 = buttons[nm].rect
		if rr.size.x <= 0: continue
		var lt: String = ROW_LBL[nm]
		if nm == "rank": lt = "Rang #%d" % rank_cache
		if nm == "ile" and main.raid_active(): lt = "RAID !"
		_text(c, lt, rr.get_center() + Vector2(0, 44), 13, Color("#ff7a6a") if lt == "RAID !" else Color("#ffe6a8"), true, f_title)
	_disc(Vector2(46, 46), 35, Color(0.04, 0.06, 0.09, 0.6))
	var bar := Rect2(86, 22, 230, 20)
	c.draw_style_box(flat(Color(0.03, 0.04, 0.06, 0.7), 10), bar.grow(3))
	var f: float = clamp(P.hp / P.max_hp, 0.0, 1.0)
	if f > 0.01: c.draw_style_box(flat(Color("#d9483a") if f > 0.3 else Color("#ff3b2f"), 9), Rect2(bar.position, Vector2(max(18.0, bar.size.x * f), bar.size.y)))
	if P.shield_hp > 0.0: c.draw_style_box(flat(Color(0.6, 0.9, 1.0, 0.55), 9), Rect2(bar.position, Vector2(max(18.0, bar.size.x * clamp(P.shield_hp / P.max_hp, 0.0, 1.0)), bar.size.y)))
	_text(c, "%d / %d" % [int(max(0, P.hp)), int(P.max_hp)], bar.get_center() + Vector2(0, 6), 15, Color.WHITE, true)
	_texq(T("it_coins"), Rect2(88, 48, 26, 26))
	var stxt := Game.fmt(Game.S.silver)
	_text(c, stxt, Vector2(120, 68), 21, GOLD, false, f_title)
	var cx: float = 128.0 + f_title.get_string_size(stxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
	_texq(T("crown"), Rect2(cx, 47, 28, 28))
	_text(c, str(Game.crowns()), Vector2(cx + 32, 68), 21, Color("#ffe39a"), false, f_title)
	# puissance (PI) à côté de la barre de vie : le chiffre que tout le monde veut voir monter
	var pw := Game.power()
	if pw != pi_last:
		if pi_last > 0 and pw > pi_last: pi_flash = 2.0
		pi_last = pw; rank_cache = Game.my_rank()
	pi_flash = max(0.0, pi_flash - get_process_delta_time())
	var pic := Color("#c8a8ff").lerp(Color("#7dff8a"), clamp(pi_flash, 0.0, 1.0))
	_text(c, "PI %d" % pw, Vector2(326, 38), 18 + int(pi_flash * 3.0), pic, false, f_title)
	if main.red_mult() > 1.0:
		var rp := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		_text(c, "ZONE ROUGE", Vector2(420, 38), 15, Color(1.0, 0.3, 0.25, rp), false, f_title)
	if Game.is_premium(): _text(c, "PREMIUM", Vector2(326, 60), 12, Color("#ffcf5a"), false, f_title)
	if Game.boost_left() > 0: _text(c, "XP ×2", Vector2(396 if Game.is_premium() else 326, 60), 12, Color("#7dff8a"), false, f_title)
	_disc(minimap.position + minimap.size * 0.5, 92, Color(0.04, 0.06, 0.09, 0.6))
	# événement du monde : en cours (couleur) ou prochain (gris)
	if not main.in_instance():
		var ev: Dictionary = main.world_event()
		var ep := Vector2(vs().x - 96, 226)
		if ev.active:
			var E: Dictionary = main.WORLD_EVENTS[ev.key]
			_text(c, "★ %s · %s" % [E.name, Game.dur_txt(ev.left)], ep, 13, Color(E.col), true, f_title)
		else:
			_text(c, "%s dans %s" % [main.WORLD_EVENTS[ev.next].name, Game.dur_txt(ev.next_in)], ep, 11, Color(0.8, 0.82, 0.86, 0.75), true)
		# réputation dans ce royaume
		var lv: Array = Game.rep_level()
		var rp := Vector2(vs().x - 96, 248)
		_texq(T("mood_" + str(lv[2])), Rect2(rp + Vector2(-78, -15), Vector2(20, 20)))
		_text(c, "%s %+d" % [lv[1], Game.rep()], rp + Vector2(6, 0), 13, Color(str(lv[3])), true, f_title)
	_flush(c); batch_text = false

# barre de récolte à côté du héros : icône de l'outil, progression verte, charges restantes
func _gather_bar(c: CanvasItem, P: Player) -> void:
	if P.gather_vis <= 0.0 or P.gather_nd.is_empty() or panel_open: return
	var cam: Camera3D = main.cam
	if cam == null or cam.is_position_behind(P.global_position): return
	var sp: Vector2 = cam.unproject_position(P.global_position + Vector3(0, 1.2, 0)) + Vector2(-80, 46)
	var f: float = clamp(1.0 - P.gather_cd / P.gather_total, 0.0, 1.0)
	var a: float = clamp(P.gather_vis / 0.6, 0.0, 1.0)
	var tool: String = Game.TOOL_OF.get(str(P.gather_nd.get("type", "wood")), "hache")
	var ic: Vector2 = sp + Vector2(0, 7)
	c.draw_style_box(flat(Color(0.12, 0.14, 0.17, 0.9 * a), 6, Color(0.75, 0.8, 0.85, 0.9 * a), 2), Rect2(ic - Vector2(20, 20), Vector2(40, 40)))
	var tt: Texture2D = main.icons.get_icon(tool)
	if tt: c.draw_texture_rect(tt, Rect2(ic - Vector2(16, 16), Vector2(32, 32)), false, Color(1, 1, 1, a))
	var bar := Rect2(sp + Vector2(26, 2), Vector2(130, 10))
	c.draw_rect(bar.grow(2), Color(0.05, 0.05, 0.06, 0.85 * a))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), Color(0.35, 0.85, 0.3, a))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, 3)), Color(0.75, 1.0, 0.6, 0.6 * a))
	var ch: int = int(P.gather_nd.get("charges", 0)); var mx: int = int(P.gather_nd.get("max", ch))
	_text(c, "%d / %d" % [ch, mx], bar.position + Vector2(bar.size.x + 26, 11), 14, Color(1, 1, 1, a), true, f_title)

var batch_text := false
var row_end_x := 900.0
const ROW_LBL := {"menu": "Menu", "bag": "Sac", "shop": "Boutique", "daily": "Quêtes", "rank": "Rang", "ile": "Mon île", "zoom": "Vue"}
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
	_gather_bar(c, P)
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
		prof_box.custom_minimum_size = Vector2(300, 0); root.add_child(prof_box)
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
	prof_box.position = Vector2(vs().x * 0.5 - 200, vs().y - 112)   # en bas au centre : plus rien ne se chevauche à gauche
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
	if panel_open: return
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
	if panel_open and panel and is_instance_valid(panel) and last_build.is_valid() and cur_panel != "":
		next_footer = last_footer; next_side = last_side; open_panel(panel_title, last_build, last_w, last_h)

var next_footer := Callable()
var last_footer := Callable()
var next_side := ""      # "left" : fenêtre posée sur le côté, le jeu reste visible (atelier façon Albion)
var last_side := ""
func open_panel(title_txt: String, build: Callable, w := 860.0, h := -1.0) -> void:
	Game.crumb("écran : " + title_txt)
	close_panel()
	last_build = build; last_w = w; last_h = h
	var side: String = next_side; next_side = ""; last_side = side
	panel_open = true
	for n in buttons: buttons[n].held = false
	joy.id = -1; joy.vec = Vector2.ZERO; touches.clear()
	if side == "":
		var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.45); dim.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(dim); panel_extra.append(dim)
	var s := vs(); var hh: float = s.y - 60 if h < 0 else h
	if side != "": hh = s.y - 12
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", _frame_box())
	pc.position = Vector2((s.x - w) * 0.5, (s.y - hh) * 0.5) if side == "" else Vector2(8, 6); pc.custom_minimum_size = Vector2(w, hh); pc.size = pc.custom_minimum_size; root.add_child(pc); panel = pc
	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation", 6); pc.add_child(outer)
	# en-tête sur le bois : médaillon, titre crème, fermer
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 12); outer.add_child(top)
	top.add_child(_medallion(_panel_icon(title_txt), 64))
	var tl := _label(title_txt, 30, Color("#f6e3b4")); tl.add_theme_font_override("font", f_title); tl.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.9)); tl.add_theme_constant_override("outline_size", 6)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tl.clip_text = true; top.add_child(tl)
	top.add_child(_close_btn(_x_close))
	# le contenu sur le parchemin
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", _parch_tex()); pp.size_flags_vertical = Control.SIZE_EXPAND_FILL; outer.add_child(pp)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); pp.add_child(vb)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; vb.add_child(sc)
	sc.scroll_deadzone = 10; sc.scroll_started.connect(func(): drag_guard = true)
	var body := VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body.add_theme_constant_override("separation", 10); sc.add_child(body)
	var keep: int = scroll_mem.get(title_txt, 0) if title_txt == panel_title else 0
	panel_title = title_txt; cur_scroll = sc
	build.call(body)
	last_footer = next_footer
	if next_footer.is_valid():
		var ft: Callable = next_footer; next_footer = Callable()
		var fs := TextureRect.new(); fs.texture = T("orn_line"); fs.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fs.stretch_mode = TextureRect.STRETCH_SCALE
		fs.custom_minimum_size = Vector2(0, 12); fs.modulate = Color("#7a5530"); vb.add_child(fs)
		var fb := VBoxContainer.new(); vb.add_child(fb); ft.call(fb); _inkify(fb); _touch_scroll(fb)
	_inkify(body)
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
	if enabled and highlight:
		b.add_theme_stylebox_override("normal", _red_btn()); b.add_theme_stylebox_override("hover", _red_btn())
	if col != GOLD and not (enabled and highlight): b.add_theme_color_override("font_color", col)
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
var arm_tab := "craft"
var arm_tier := 1
func show_armurier(tab := "") -> void:
	if tab != "": arm_tab = tab
	next_side = "left"
	var smith := "Brokk"
	var tn = main.get("talk_npc")
	if tn != null and is_instance_valid(tn) and tn.act == "forge": smith = tn.nm
	open_panel("Forge de " + smith, func(body: VBoxContainer):
		cur_panel = "armurier"
		_workshop_head(body, "Barbarian", "Atelier de l'armurier", smith, {"hostile": "Fais vite, étranger. J'ai du travail.", "mefiant": "Hmm. Tu veux quoi ?", "neutre": "Qu'est-ce que je te forge aujourd'hui ?", "amical": "Ah, te voilà ! L'enclume est chaude.", "heros": "Pour toi, mon meilleur acier. Toujours."})
		var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); body.add_child(tabs)
		_tab_btn(tabs, "Fabriquer", arm_tab == "craft", func(): show_armurier("craft"))
		_tab_btn(tabs, "Acheter", arm_tab == "buy", func(): show_armurier("buy"))
		var tiers := HBoxContainer.new(); tiers.add_theme_constant_override("separation", 6); body.add_child(tiers)
		for tt in range(1, 6):
			var b := Button.new(); b.text = ROMAN[tt]; b.custom_minimum_size = Vector2(62, 42); b.add_theme_font_size_override("font_size", 19)
			var on := arm_tier == tt; var col: Color = Game.TIER_COL[tt]
			var st := flat(col.darkened(0.15) if on else Color("#f2e3c0"), 21, col.darkened(0.3), 3 if on else 2, Vector4(10, 3, 10, 5))
			b.add_theme_stylebox_override("normal", st); b.add_theme_stylebox_override("hover", st); b.add_theme_color_override("font_color", Color.WHITE if on else ink_col(col))
			b.set_meta("keep", true); b.pressed.connect(func(): arm_tier = tt; show_armurier()); tiers.add_child(b)
		var t: int = arm_tier
		body.add_child(_ink("Armes et armures — Tier %s" % ROMAN[t], 22, INK, true))
		for ci in Game.CRAFTS.size():
			var c: Dictionary = Game.CRAFTS[ci]
			var it := Game.craft_item(c, t)
			var p := PanelContainer.new(); p.set_meta("keep", true)
			var rs := flat(Color(0, 0, 0, 0), 0, Color("#bfa071"), 0, Vector4(4, 8, 4, 8)); rs.border_width_bottom = 1
			p.add_theme_stylebox_override("panel", rs); body.add_child(p)
			var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); p.add_child(h)
			h.add_child(aslot(main.icons.item_icon(it), t, 1, false, Callable(), 74, 0, null, it))
			var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 4); h.add_child(v)
			v.add_child(_ink(Game.item_name(it), 18, INK, true))
			if t > Game.unlocked(c.slot) + 1:
				v.add_child(rich("[color=#a0301c]Porte d'abord %s T%d[/color]" % [Game.SLOT_ART[c.slot], t - 1], 15))
				continue
			if arm_tab == "craft":
				var cost := Game.craft_cost(c, t)
				var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 8); v.add_child(mh)
				for k in cost: mh.add_child(_mat_chip(res_tex(k, t), int(Game.S.inv[k][t]), int(cost[k][1])))
				var sp2 := Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mh.add_child(sp2)
				var ok: bool = Game.has_cost(cost)
				var b := big_button("Fabriquer", ok, func(): main.craft_gear(ci, t), GOLD, true); b.custom_minimum_size = Vector2(130, 44); b.add_theme_font_size_override("font_size", 17); mh.add_child(b)
			else:
				var price := int(Game.item_price(it) * 1.3)
				var bh := HBoxContainer.new(); v.add_child(bh)
				var pr := _ah_price(price, ""); pr.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bh.add_child(pr)
				var b2 := big_button("Acheter", Game.S.silver >= price, func(): main.buy_gear(it), GOLD, true); b2.custom_minimum_size = Vector2(130, 44); b2.add_theme_font_size_override("font_size", 17); bh.add_child(b2)
	, 470)

# ——— Tannerie (fenêtre sur le côté, comme la forge) ———
func _artisan_name(act: String, fallback: String) -> String:
	var tn = main.get("talk_npc")
	if tn != null and is_instance_valid(tn) and tn.act == act: return tn.nm
	return fallback
func show_tannery() -> void:
	next_side = "left"
	var who := _artisan_name("tannery", "Garrick")
	open_panel("Tannerie de " + who, func(body: VBoxContainer):
		cur_panel = "tannery"
		_workshop_head(body, "Barbarian", "Atelier du tanneur", who, {"hostile": "Pas de peaux, pas d'affaires.", "mefiant": "Montre ce que t'as dépecé.", "neutre": "Belles peaux ? Je prends.", "amical": "Toujours un plaisir, chasseur !", "heros": "Pour toi, le meilleur prix du royaume."})
		var hides: int = int(Game.S.get("hides", 0)); var kn: int = int(Game.S.get("knife", 0))
		body.add_child(_ink("Tes peaux", 22, INK, true))
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); body.add_child(h)
		h.add_child(aslot(T("it_hunt"), 1, hides, false, Callable(), 72))
		var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
		v.add_child(rich("[b]%d peau%s[/b]  ·  %s argent pièce" % [hides, "x" if hides > 1 else "", Game.fmt(main.HIDE_PRICE)], 17))
		var bh := HBoxContainer.new(); bh.add_theme_constant_override("separation", 8); v.add_child(bh)
		var b1 := big_button("Vendre 5", hides >= 5, func(): main.sell_hides(5)); b1.custom_minimum_size = Vector2(120, 44); bh.add_child(b1)
		var b2 := big_button("Tout vendre", hides > 0, func(): main.sell_hides(hides), GOLD, true); b2.custom_minimum_size = Vector2(140, 44); bh.add_child(b2)
		body.add_child(_ink("Ton couteau à dépecer", 22, INK, true))
		if kn <= 0:
			body.add_child(rich("[color=#a0301c]Tu n'as pas encore de couteau.[/color] Brokk, l'armurier, t'en donnera un si tu l'aides avec les loups.", 16))
		else:
			body.add_child(rich("Couteau [b]T%d[/b] — %d %% de chance d'une peau en plus sur chaque bête." % [kn, (kn - 1) * 25], 16))
			if kn < 5:
				var c: Array = main.knife_cost(kn)
				var ok: bool = Game.S.silver >= c[0] and hides >= c[1]
				var uh := HBoxContainer.new(); uh.add_theme_constant_override("separation", 10); body.add_child(uh)
				var r := rich("Passer au [b]T%d[/b] : %s argent + %d peaux" % [kn + 1, Game.fmt(c[0]), c[1]], 16); r.size_flags_vertical = Control.SIZE_SHRINK_CENTER; uh.add_child(r)
				var ub := big_button("Améliorer", ok, func(): main.upgrade_knife(), GOLD, true); ub.custom_minimum_size = Vector2(140, 44); uh.add_child(ub)
			else: body.add_child(rich("[color=#2f6a2a]Ton couteau est au maximum.[/color]", 16))
	, 470)

# ——— Scierie ———
func show_sawmill() -> void:
	next_side = "left"
	var who := _artisan_name("sawmill", "Aubin")
	open_panel("Scierie de " + who, func(body: VBoxContainer):
		cur_panel = "sawmill"
		_workshop_head(body, "Ranger", "Atelier du scieur", who, {"hostile": "Pose ton bois et file.", "mefiant": "C'est du bois sec, au moins ?", "neutre": "Du bon bois ? Je le paie mieux que la marchande.", "amical": "Ah, mon bûcheron préféré !", "heros": "Tout le bois de la ville passe par toi, maintenant."})
		body.add_child(rich("Le scieur rachète ton bois [b]25 % plus cher[/b] que la marchande.", 16))
		var any := false
		for t in range(1, 6):
			var n: int = int(Game.S.inv.wood[t])
			if n <= 0: continue
			any = true
			var p := PanelContainer.new(); p.set_meta("keep", true)
			var rs := flat(Color(0, 0, 0, 0), 0, Color("#bfa071"), 0, Vector4(4, 8, 4, 8)); rs.border_width_bottom = 1
			p.add_theme_stylebox_override("panel", rs); body.add_child(p)
			var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); p.add_child(h)
			h.add_child(aslot(res_tex("wood", t), t, n, false, Callable(), 64))
			var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
			v.add_child(_ink(Game.res_name("wood", t), 17, INK, true))
			v.add_child(rich("%s argent la bûche" % Game.fmt(int(Game.res_price(t) * 1.25)), 15))
			var b := big_button("Vendre ×%d" % min(n, 10), true, func(): main.sell_wood_mill(t, min(n, 10)), GOLD, true); b.custom_minimum_size = Vector2(130, 44); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(b)
		if not any: body.add_child(rich("[color=#8a9298]Tu n'as pas de bois. Va couper des arbres avec ta hache.[/color]", 16))
	, 470)

# en-tête d'atelier : portrait de l'artisan, son métier, et ce qu'il te dit (selon ta réputation)
func _workshop_head(body: Control, model: String, what: String, who: String, lines: Dictionary) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 12); body.add_child(h)
	var pf := PanelContainer.new(); pf.add_theme_stylebox_override("panel", flat(Color("#2c2620"), 36, Color("#c79a4a"), 3, Vector4(4, 4, 4, 4))); pf.custom_minimum_size = Vector2(76, 76)
	var pt := TextureRect.new(); pt.texture = main.icons.char_icon(model); pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pf.add_child(pt); h.add_child(pf)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
	v.add_child(_ink(what, 14, INK_SOFT, true))
	v.add_child(_ink("Tenu par " + who, 18, INK, true))
	var lv: Array = Game.rep_level()
	var bub := PanelContainer.new(); bub.add_theme_stylebox_override("panel", flat(Color("#fbf3e0"), 10, Color("#bfa071"), 1, Vector4(10, 5, 10, 6))); bub.set_meta("keep", true)
	var bt := rich("[i]« %s »[/i]" % str(lines.get(str(lv[2]), lines.get("neutre", "…"))), 15); bub.add_child(bt); v.add_child(bub)

# matériau : petite icône + « possédé / requis » (rouge s'il en manque)
func _mat_chip(tx: Texture2D, have: int, need: int) -> Control:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0)
	var ic := TextureRect.new(); ic.texture = tx; ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; ic.custom_minimum_size = Vector2(36, 36); v.add_child(ic)
	var l := _ink("%d/%d" % [have, need], 13, Color("#2f6a2a") if have >= need else Color("#a0301c"), true); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l)
	return v

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
	return aslot(tx, tier, count, selected, cb, size, ench)
func _old_slot_box(tx: Texture2D, tier: int, count: int, selected: bool, cb: Callable, size := 74.0, ench := 0, beige := false) -> Button:
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

func bag_entries(with_food := true) -> Array:
	var out := []
	for i in Game.S.items.size():
		var it: Dictionary = Game.S.items[i].duplicate(); it["idx"] = i; out.append(it)
	for k in Game.RES_KEYS:
		for t in range(1, Game.MAX_TIER + 1):
			var n: int = Game.S.inv[k][t]
			if n > 0: out.append({"res": k, "tier": t, "qty": n})
	if with_food:
		var keys: Array = Game.S.get("food", {}).keys(); keys.sort()
		for key in keys:
			var pr: PackedStringArray = str(key).split(":")
			if Game.FOOD.has(pr[0]) and int(Game.S.food[key]) > 0: out.append({"food": pr[0], "fkey": key, "tier": int(pr[1]), "qty": int(Game.S.food[key])})
	return out

func entry_tex(e: Dictionary) -> Texture2D:
	if e.has("food"): return main.icons.get_icon("food_" + e.food)
	return res_tex(e.res, e.tier) if e.has("res") else main.icons.item_icon(e)

func entry_name(e: Dictionary) -> String:
	if e.has("food"): return Game.food_name(e.food)
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

# cadre de bois aux coins de fer (texture 9 parties)
var _frame_sb: StyleBoxTexture
func _frame_box() -> StyleBoxTexture:
	if _frame_sb: return _frame_sb
	var st := StyleBoxTexture.new(); st.texture = T("frame_wood")
	for sd in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: st.set_texture_margin(sd, 30); st.set_content_margin(sd, 24)
	st.set_content_margin(SIDE_TOP, 16); st.set_content_margin(SIDE_BOTTOM, 22)
	_frame_sb = st; return st
var _parch_sb: StyleBoxTexture
func _parch_tex() -> StyleBoxTexture:
	if _parch_sb: return _parch_sb
	var st := StyleBoxTexture.new(); st.texture = T("parch")
	for sd in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]: st.set_texture_margin(sd, 28); st.set_content_margin(sd, 16)
	_parch_sb = st; return st
# médaillon rond cerclé de fer et d'or, avec l'icône de l'écran
func _medallion(tx: Texture2D, size: float) -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(size, size); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := TextureRect.new(); bg.texture = T("medal"); bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bg.size = Vector2(size, size); bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(bg)
	if tx:
		var ic := TextureRect.new(); ic.texture = tx; ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(size * 0.2, size * 0.2); ic.size = Vector2(size * 0.6, size * 0.6); ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; c.add_child(ic)
	return c
const PANEL_ICONS := [["ventes", "it_coins"], ["Forge", "it_chest_open"], ["Quotidien", "it_quest"], ["Classement", "it_trophy"], ["Boutique", "crown"], ["Carte", "it_treasure_map"], ["Royaume", "it_treasure_map"],
	["Menu", "ic_gear"], ["Coffre", "it_chest_open"], ["COFFRE", "it_chest_open"], ["Expédition", "it_hunt"], ["Guide", "it_seal"], ["Chasse", "it_hunt"], ["Marché", "it_coins"], ["île", "it_treasure_map"], ["Île", "it_treasure_map"],
	["Enchant", "it_seal"], ["Compagnie", "it_hunt"], ["Discussion", "it_quest"], ["Défaite", "it_seal"], ["achat", "crown"]]
func _panel_icon(title_txt: String) -> Texture2D:
	for pi in PANEL_ICONS:
		if title_txt.contains(pi[0]): return T(pi[1])
	var tn = main.get("talk_npc")
	if tn != null and is_instance_valid(tn):
		var ci: Texture2D = main.icons.char_icon(tn.data.get("model", "Knight"))
		if ci: return ci
	return T("it_seal")

# bouton fermer : disque doré, croix sombre (comme Albion)
func _close_btn(cb: Callable) -> Button:
	var x := Button.new(); x.text = "✕"; x.custom_minimum_size = Vector2(56, 56); x.focus_mode = Control.FOCUS_NONE
	x.add_theme_font_override("font", ThemeDB.fallback_font); x.add_theme_font_size_override("font_size", 26)
	x.add_theme_color_override("font_color", Color("#3a2410")); x.add_theme_color_override("font_hover_color", Color("#1a1008")); x.add_theme_color_override("font_pressed_color", Color("#1a1008"))
	var xs := flat(Color("#f2c24a"), 28, Color("#5a3a18"), 4, Vector4(0, 0, 0, 0)); xs.shadow_color = Color(0, 0, 0, 0.35); xs.shadow_size = 3
	for k in ["normal", "hover", "pressed"]: x.add_theme_stylebox_override(k, xs)
	x.pressed.connect(cb); return x

# ——— Encrage : les écrans écrits pour un fond sombre deviennent lisibles sur parchemin ———
static func ink_col(c: Color) -> Color:
	if c.get_luminance() < 0.42: return c
	if c.s < 0.18: return INK if c.v > 0.9 else INK_SOFT
	return Color.from_hsv(c.h, clamp(c.s * 1.05 + 0.2, 0.0, 1.0), 0.40 if c.h > 0.08 and c.h < 0.2 else 0.46)
static var _rx_col: RegEx
static func ink_bb(t: String) -> String:
	if _rx_col == null: _rx_col = RegEx.create_from_string("\\[color=(#?[0-9a-fA-F]{3,8})\\]")
	var out := ""; var last := 0
	for m in _rx_col.search_all(t):
		var c := Color.from_string(m.get_string(1), Color.WHITE)
		out += t.substr(last, m.get_start() - last) + "[color=#%s]" % ink_col(c).to_html(false)
		last = m.get_end()
	return out + t.substr(last)
func _inkify(n: Node) -> void:
	if n.has_meta("keep"):
		if n is PanelContainer:
			for ch in n.get_children(): _inkify(ch)
		return
	if n is Button:
		var b := n as Button
		if b.has_theme_stylebox_override("normal"):
			var st = b.get_theme_stylebox("normal")
			if st is StyleBoxFlat:
				var bg: Color = (st as StyleBoxFlat).bg_color
				if bg.a >= 0.6 and bg.get_luminance() < 0.42: return     # case d'objet, bouton sombre : déjà lisible
				if bg.a < 0.5:
					var ns: StyleBoxFlat = (st as StyleBoxFlat).duplicate(); ns.bg_color = Color("#d9c193"); ns.border_color = Color("#9a7748"); ns.set_border_width_all(2)
					for k in ["normal", "hover"]: b.add_theme_stylebox_override(k, ns)
					if b.has_theme_color_override("font_color"): b.add_theme_color_override("font_color", ink_col(b.get_theme_color("font_color")))
					else: b.add_theme_color_override("font_color", INK)
		return
	if n is PanelContainer or n is Panel:
		var c := n as Control
		if c.has_theme_stylebox_override("panel"):
			var st = c.get_theme_stylebox("panel")
			if st is StyleBoxFlat:
				var bg: Color = (st as StyleBoxFlat).bg_color
				if bg.a >= 0.6 and bg.get_luminance() < 0.42: return     # carte sombre (vitrine…) : on n'y touche pas
				var ns: StyleBoxFlat = (st as StyleBoxFlat).duplicate()
				var tint := Color(bg.r, bg.g, bg.b)
				ns.bg_color = Color("#dfc99c").lerp(tint, 0.18 if tint.s > 0.25 else 0.0)
				var bc: Color = (st as StyleBoxFlat).border_color
				ns.border_color = Color("#a8875a") if bc.s < 0.25 else Color(ink_col(bc), 0.85)
				if ns.border_width_left < 1: ns.set_border_width_all(1)
				c.add_theme_stylebox_override("panel", ns)
	elif n is RichTextLabel:
		var r := n as RichTextLabel
		r.add_theme_color_override("default_color", INK); r.add_theme_constant_override("outline_size", 0)
		if r.bbcode_enabled: r.text = ink_bb(r.text)
	elif n is Label:
		var l := n as Label
		l.add_theme_color_override("font_color", ink_col(l.get_theme_color("font_color"))); l.add_theme_constant_override("outline_size", 0)
	elif n is LineEdit:
		var le := n as LineEdit
		le.add_theme_stylebox_override("normal", flat(Color("#f4e8cc"), 10, Color("#9a7748"), 2, Vector4(12, 8, 12, 8)))
		le.add_theme_color_override("font_color", INK); le.add_theme_color_override("font_placeholder_color", INK_SOFT)
	for ch in n.get_children(): _inkify(ch)

func _parch_box() -> StyleBoxFlat:
	var st := flat(PARCH, 18, Color("#7a5530"), 4, Vector4(14, 10, 14, 12), 18)
	st.shadow_color = Color(0, 0, 0, 0.55); st.border_blend = true
	return st

# Case d'objet style Albion : fond sombre, halo du tier, chiffre romain en pastille, quantité en bas
# Case d'objet façon Albion : fond teinté par le tier, cadre de métal biseauté, petit chiffre romain,
# quantité dans une pastille ronde. Tout reste fin et lisible, même petit.
const SLOT_BG := [Color("#3a3530"), Color("#4a4640"), Color("#2f5a2a"), Color("#1f5266"), Color("#283f86"), Color("#7a1f1c")]
func aslot(tx: Texture2D, tier: int, count: int, selected: bool, cb: Callable, size := 70.0, ench := 0, ghost: Texture2D = null, it := {}) -> Button:
	var b := Button.new(); b.custom_minimum_size = Vector2(size, size); b.focus_mode = Control.FOCUS_NONE
	var full := tier > 0 and tx != null
	var tcol: Color = Game.TIER_COL[clamp(tier, 0, Game.TIER_COL.size() - 1)]
	var bg: Color = SLOT_BG[clamp(tier, 0, 5)] if full else Color("#d3bd92")
	var st := flat(bg, 7, Color(0, 0, 0, 0), 0, Vector4(0, 0, 0, 0))
	if not full: st.border_color = Color("#b39a6c"); st.set_border_width_all(2)
	for k in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(k, st)
	var add := func(n: Control) -> void: n.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(n)
	if full:
		var gl := TextureRect.new(); gl.texture = glow_tex(); gl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gl.stretch_mode = TextureRect.STRETCH_SCALE
		gl.position = Vector2(2, 2); gl.size = Vector2(size - 4, size - 4); gl.modulate = Color(tcol.r, tcol.g, tcol.b, 0.45); add.call(gl)
		var vg := TextureRect.new(); vg.texture = T("slot_vig"); vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; vg.stretch_mode = TextureRect.STRETCH_SCALE
		vg.size = Vector2(size, size); add.call(vg)
		var tr := TextureRect.new(); tr.texture = tx; tr.material = icon_mat(); tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var pad: float = size * 0.09
		tr.position = Vector2(pad, pad); tr.size = Vector2(size - pad * 2, size - pad * 2); add.call(tr)
	elif ghost:
		var gh := TextureRect.new(); gh.texture = ghost; gh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; gh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gh.position = Vector2(size * 0.18, size * 0.18); gh.size = Vector2(size * 0.64, size * 0.64); gh.modulate = Color(0.42, 0.31, 0.17, 0.3); add.call(gh)
	# cadre de métal (doré si sélectionné, violet si enchanté)
	if full or selected:
		var fr := NinePatchRect.new(); fr.texture = T("slot_frame"); fr.patch_margin_left = 8; fr.patch_margin_top = 8; fr.patch_margin_right = 8; fr.patch_margin_bottom = 8
		fr.size = Vector2(size, size)
		if selected: fr.modulate = Color(1.6, 1.3, 0.55)
		elif ench > 0: fr.modulate = Color(1.25, 0.85, 1.5)
		add.call(fr)
	if full:
		var fs: int = clamp(int(size * 0.17), 11, 15)
		var tl := _label(ROMAN[clamp(tier, 0, 8)], fs, tcol.lightened(0.35)); tl.add_theme_font_override("font", f_title)
		tl.add_theme_constant_override("outline_size", 4); tl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95)); tl.position = Vector2(size * 0.09, size * 0.03); add.call(tl)
		if ench > 0:
			var el := _label("+%d" % ench, fs, Color("#e7b8ff")); el.add_theme_font_override("font", f_title); el.add_theme_constant_override("outline_size", 4); el.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			el.position = Vector2(size - fs * 2.0 - 4, size * 0.03); add.call(el)
		if count > 1:
			var txt: String = Game.fmt(count) if count >= 1000 else str(count)
			var cw: float = max(18.0, 8.0 + txt.length() * fs * 0.6)
			var cp := Panel.new(); cp.add_theme_stylebox_override("panel", flat(Color(0.06, 0.06, 0.07, 0.88), 9, Color(0.75, 0.78, 0.82, 0.7), 1, Vector4(0, 0, 0, 0)))
			cp.size = Vector2(cw, 18); cp.position = Vector2(size - cw - 4, size - 22); add.call(cp)
			var cl := _label(txt, fs - 1, Color.WHITE); cl.add_theme_constant_override("outline_size", 0); cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cl.size = Vector2(cw, 18); cl.position = Vector2(0, -1); cp.add_child(cl)
		if not it.is_empty(): _lvl_tag(b, it, size)
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
	for key in Game.S.get("food", {}):
		var pr: PackedStringArray = str(key).split(":")
		if Game.FOOD.has(pr[0]): v += Game.food_price(pr[0], int(pr[1])) * int(Game.S.food[key])
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
	if cur_panel != "bag": Game.crumb("sac")
	var keep: int = bag_scroll
	if cur_panel == "bag" and cur_scroll and is_instance_valid(cur_scroll): keep = cur_scroll.scroll_vertical
	close_panel()
	cur_panel = "bag"; panel_open = true; panel_title = "Sac"
	for n in buttons: buttons[n].held = false
	joy.id = -1; joy.vec = Vector2.ZERO; touches.clear()
	var entries := bag_entries()
	if bag_sel >= entries.size(): bag_sel = -1
	var s := vs()
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", _parch_tex())
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
			g.add_child(aslot(entry_tex(e), e.tier, e.get("qty", 1), i == bag_sel, func(): bag_sel = i; eq_sel = ""; show_bag(), 72, int(e.get("ench", 0)), null, e))
		else: g.add_child(aslot(null, 0, 0, false, Callable(), 72))
	_touch_scroll(g)
	sc.scroll_vertical = keep
	(func(): if is_instance_valid(sc): sc.scroll_vertical = keep).call_deferred()
	# — bas : trier, vendre le bric-à-brac, estimation —
	var bt := HBoxContainer.new(); bt.add_theme_constant_override("separation", 8); vb.add_child(bt)
	bt.add_child(_parch_btn("Équiper au mieux", func(): main.equip_best()))
	var ql: Array = main.quick_sell_list()
	var qv := 0
	for i in ql: qv += main.quick_price(Game.S.items[i])
	bt.add_child(_parch_btn(("Vente rapide (%d · %s)" % [ql.size(), Game.fmt(qv)]) if ql.size() > 0 else "Vente rapide", func(): main.quick_sell()))
	bt.add_child(_parch_btn("Trier", sort_bag))
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
		var sub: String = "Ressource" if e.has("res") else ("Nourriture" if e.has("food") else Game.SLOT_NAME[e.slot])
		var nm := rich("[b][color=#%s]%s[/color][/b]\n%s · [color=#%s]Tier %s[/color]%s" % [col.to_html(false), entry_name(e), sub, col.to_html(false), ROMAN[clamp(int(e.tier), 0, 8)], "  · [color=#9dffb0]porté[/color]" if equipped else ""], 18)
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER; nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hh.add_child(nm)
		cv.add_child(rich(item_info(e, equipped), 16))
		var bh := HFlowContainer.new(); bh.add_theme_constant_override("h_separation", 8); bh.add_theme_constant_override("v_separation", 8); cv.add_child(bh)
		if e.has("food"):
			var fk: String = e.fkey
			var be := big_button("Manger", true, func(): main.eat_food(fk); show_bag(), Color("#8fe06a"), true); be.custom_minimum_size = Vector2(130, 48); bh.add_child(be)
			var bs := big_button("Vendre 1 · %s" % Game.fmt(Game.food_price(e.food, e.tier)), true, func(): main.sell_food(fk); show_bag(), GOLD); bs.custom_minimum_size = Vector2(150, 48); bh.add_child(bs)
			if int(e.qty) > 1:
				var ba := big_button("Tout vendre", true, func(): bag_sel = -1; main.sell_food(fk, true); show_bag(), GOLD); ba.custom_minimum_size = Vector2(130, 48); bh.add_child(ba)
		elif equipped:
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
	var t := _label("Nv%d" % l, 11, Color("#9fe4ff")); t.add_theme_font_override("font", f_title); t.add_theme_constant_override("outline_size", 4); t.position = Vector2(size * 0.09, size - 18); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(t)

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
	if e.has("food"):
		return "×%d dans ton sac · se vend [color=#ffd86b]%s[/color] l'unité\nManger : rend [b]%d %%[/b] de ta vie. Cueilli à la main dans les buissons, les sous-bois et les potagers des fermes — ça repousse." % [e.qty, Game.fmt(Game.food_price(e.food, e.tier)), int(round(Game.food_heal(e.food, e.tier) * 100))]
	if e.has("res"):
		return "×%d en stock · valeur ≈ [color=#ffd86b]%s[/color] argent l'unité\nSert à la forge (Brokk) pour fabriquer les objets T%d." % [e.qty, Game.fmt(Game.res_price(e.tier)), e.tier]
	var t := int(e.tier); var lines := []
	var cur := Game.equipped_item(e.slot); var cv := _stat(cur); var v := _stat(e)
	var cmp := not equipped
	match e.slot:
		"epee":
			lines.append("Dégâts par coup : [b]%d[/b]%s" % [int(v), _diff(v, cv) if cmp else ""])
			lines.append("[color=#a8b4bc]%s[/color]" % Game.WEAPON_KINDS[e.get("kind", "epee")].desc)
			var wk: String = e.get("kind", "epee")
			if Game.ranged(wk): lines.append("[color=#ffd27a]Arme à distance : portée %d m[/color]" % int(Game.WEAPON_KINDS[wk].range))
			for sk in Player.SKILL_SETS.get(wk, Player.SKILL_SETS.epee):
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
	if on:
		b.add_theme_stylebox_override("normal", _red_btn()); b.add_theme_stylebox_override("hover", _red_btn())
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

var ah_query := ""
const AH_W := 1010.0
func show_auction(tab := "", cat := "") -> void:
	if tab != "": ah_tab = tab
	if cat != "": ah_cat = cat
	main.ah_refresh_stock()
	if ah_tab == "sell": next_footer = _ah_sell_footer
	open_panel("Hôtel des ventes", func(body: VBoxContainer):
		cur_panel = "auction"
		var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); body.add_child(tabs)
		_tab_btn(tabs, "Acheter", ah_tab == "buy", func(): ah_sel = null; show_auction("buy"))
		_tab_btn(tabs, "Vendre", ah_tab == "sell", func(): ah_sel = null; show_auction("sell"))
		_tab_btn(tabs, "Mes ventes (%d)" % Game.S.ah.listings.size(), ah_tab == "mine", func(): show_auction("mine"))
		_tab_btn(tabs, "Ordres d'achat (%d)" % main.ah_orders().size(), ah_tab == "orders", func(): show_auction("orders"))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.add_child(sp)
		tabs.add_child(_price_box(Game.S.silver))
		if ah_tab == "buy" or ah_tab == "sell": _ah_filters(body)
		match ah_tab:
			"buy":
				_vitrine(body)
				body.add_child(_ink("Acheter", 26, INK, true))
				_ah_head(body, ["Objet", "Prix", ""])
				var n := 0
				for i in Game.S.ah.stock.size():
					var e: Dictionary = Game.S.ah.stock[i]
					if not _ah_match(e): continue
					var why: String = Game.equip_block(e) if not e.has("res") else ""
					var sub := "[color=#%s]Tier %s[/color]" % [Game.TIER_COL[e.tier].to_html(false), ROMAN[clamp(int(e.tier), 0, 8)]]
					if e.has("seller"): sub += "  ·  [color=#2f5f8a]%s[/color]" % e.seller
					if why != "": sub += "\n[color=#a0301c]Verrouillé pour toi[/color]"
					var b := big_button("Acheter", Game.S.silver >= e.price, func(): main.ah_buy(i), GOLD, true); b.custom_minimum_size = Vector2(150, 50)
					_ah_trow(body, e, sub, _ah_price(int(e.price), avg_tag(e.price, main.real_price(e))), b, n)
					n += 1
				if n == 0: body.add_child(rich("[color=#8a9298]Rien ne correspond. Le stock se renouvelle toutes les 5 minutes.[/color]", 16))
			"sell":
				if ah_sel != null: _sell_editor(body)
				body.add_child(_ink("Vendre depuis l'inventaire", 26, INK, true))
				_ah_head(body, ["Objet", "Estimation", ""])
				var entries := bag_entries(false); var n2 := 0
				for e in entries:
					if not _ah_match(e): continue
					var lot := _lot(e)
					var b := big_button("Vendre", true, func(): ah_sel = e; ah_price = main.real_price(lot); show_auction("sell"), GOLD, true); b.custom_minimum_size = Vector2(150, 50)
					var sub := "[color=#%s]Tier %s[/color]%s" % [Game.TIER_COL[e.tier].to_html(false), ROMAN[clamp(int(e.tier), 0, 8)], ("  ·  lot de %d" % lot.qty) if lot.has("res") else ""]
					_ah_trow(body, lot, sub, _ah_price(main.real_price(lot), ""), b, n2)
					n2 += 1
				if n2 == 0: body.add_child(rich("[color=#8a9298]Rien à vendre ici.[/color]", 16))
			"mine":
				body.add_child(_ink("Mes ventes en cours", 26, INK, true))
				if Game.S.ah.listings.is_empty(): body.add_child(rich("[color=#8a9298]Aucune vente en cours. Va dans « Vendre » pour mettre un objet en vente.[/color]", 16))
				else: _ah_head(body, ["Objet", "Ton prix", "Résultat"])
				var k := 0
				for l in Game.S.ah.listings:
					var left: int = int(max(0.0, float(l.end) - main.now_s()))
					var ch := int(main.sell_chance(int(l.price), int(l.real)) * 100)
					var st := rich("[center]dans [b]%d s[/b]\n[color=#76593a]chance %d %%[/color][/center]" % [left, ch], 16); st.custom_minimum_size = Vector2(150, 0)
					_ah_trow(body, l, "[color=#%s]Tier %s[/color]" % [Game.TIER_COL[l.tier].to_html(false), ROMAN[clamp(int(l.tier), 0, 8)]], _ah_price(int(l.price), avg_tag(int(l.price), int(l.real))), st, k)
					k += 1
			"orders": _orders_tab(body)
	, min(AH_W, vs().x - 40))

func _ah_match(e: Dictionary) -> bool:
	if ah_cat != "all" and cat_of(e) != ah_cat: return false
	if ah_tier > 0 and int(e.tier) != ah_tier: return false
	if ah_query != "" and not entry_name(e).to_lower().contains(ah_query.to_lower()): return false
	return true

# barre de filtres : recherche, catégorie, niveau, remise à zéro (comme Albion)
func _ah_filters(body: Control) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); body.add_child(h)
	var le := LineEdit.new(); le.placeholder_text = "Recherche…"; le.text = ah_query; le.custom_minimum_size = Vector2(250, 48); le.add_theme_font_size_override("font_size", 19)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.text_submitted.connect(func(t: String): ah_query = t.strip_edges(); show_auction()); h.add_child(le)
	var go := big_button("Chercher", true, func(): ah_query = le.text.strip_edges(); show_auction()); go.custom_minimum_size = Vector2(120, 48); h.add_child(go)
	var oc := _parch_option(AH_CATS.map(func(c): return c[1]), AH_CATS.map(func(c): return c[0]).find(ah_cat))
	oc.item_selected.connect(func(i: int): ah_cat = AH_CATS[i][0]; show_auction()); h.add_child(oc)
	var tiers := ["Tous niveaux"]
	for t in range(1, 6): tiers.append("Tier %s" % ROMAN[t])
	var ot := _parch_option(tiers, ah_tier)
	ot.item_selected.connect(func(i: int): ah_tier = i; show_auction()); h.add_child(ot)
	var rs := big_button("↺", true, func(): ah_query = ""; ah_cat = "all"; ah_tier = 0; show_auction()); rs.custom_minimum_size = Vector2(52, 48)
	rs.add_theme_font_override("font", ThemeDB.fallback_font); h.add_child(rs)

func _parch_option(items: Array, sel: int) -> OptionButton:
	var o := OptionButton.new(); o.custom_minimum_size = Vector2(170, 48); o.focus_mode = Control.FOCUS_NONE
	for it in items: o.add_item(str(it))
	o.select(max(0, sel))
	var st := flat(Color("#f2e3c0"), 24, Color("#9a7748"), 2, Vector4(18, 6, 34, 8))
	for k in ["normal", "hover", "pressed"]: o.add_theme_stylebox_override(k, st)
	o.add_theme_color_override("font_color", INK); o.add_theme_color_override("font_hover_color", INK); o.add_theme_color_override("font_pressed_color", INK)
	o.add_theme_font_override("font", f_title); o.add_theme_font_size_override("font_size", 18)
	var pm := o.get_popup(); pm.add_theme_font_size_override("font_size", 22)
	pm.add_theme_stylebox_override("panel", flat(Color("#efe0bd"), 12, Color("#7a5530"), 3, Vector4(8, 8, 8, 8)))
	pm.add_theme_color_override("font_color", INK); pm.add_theme_color_override("font_hover_color", Color("#fff2c8"))
	pm.add_theme_stylebox_override("hover", flat(Color("#7a5530"), 8))
	o.set_meta("keep", true)
	return o

# en-tête des colonnes : pastilles sombres
func _ah_head(body: Control, cols: Array) -> void:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); body.add_child(h)
	var ws := [0.0, 210.0, 170.0]
	for i in cols.size():
		var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", flat(Color("#33414d"), 8, Color("#c9a45c"), 2, Vector4(12, 3, 12, 4)))
		if i == 0: p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else: p.custom_minimum_size = Vector2(ws[i], 0)
		var l := _label(str(cols[i]), 15, Color("#f4ead6")); l.add_theme_constant_override("outline_size", 0); p.add_child(l); h.add_child(p)

# une ligne du tableau : case + nom | prix | action ; lignes alternées, filet entre elles
func _ah_trow(body: Control, e: Dictionary, sub: String, mid: Control, act: Control, idx: int) -> void:
	var p := PanelContainer.new(); p.set_meta("keep", true)
	var st := flat(Color("#ead9b2") if idx % 2 == 0 else Color("#e2cfa5"), 6, Color(0, 0, 0, 0), 0, Vector4(8, 6, 8, 6))
	st.border_color = Color("#bfa071"); st.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", st); body.add_child(p)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 14); p.add_child(h)
	h.add_child(aslot(entry_tex(e), int(e.tier), int(e.get("qty", 1)), false, Callable(), 72, int(e.get("ench", 0)), null, e))
	var nm := rich("[b]%s[/b]\n%s" % [entry_name(e), sub], 18); nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(nm)
	mid.custom_minimum_size.x = 210; mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(mid)
	var ac := CenterContainer.new(); ac.custom_minimum_size = Vector2(170, 0); ac.add_child(act); h.add_child(ac)

func _ah_price(price: int, tag: String) -> Control:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); v.alignment = BoxContainer.ALIGNMENT_CENTER
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); v.add_child(h)
	var ci := TextureRect.new(); ci.texture = T("it_coins"); ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ci.custom_minimum_size = Vector2(24, 24); h.add_child(ci)
	h.add_child(_ink(Game.fmt(price), 21, INK, true))
	if tag != "": v.add_child(rich(tag, 13))
	return v

# pied de page de la vente : valeur totale + vente rapide
func _ah_sell_footer(vb: Control) -> void:
	var ql: Array = main.quick_sell_list()
	var qv := 0
	for i in ql: qv += main.quick_price(Game.S.items[i])
	var tot := 0
	for e in bag_entries(false): tot += main.real_price(_lot(e))
	var f := HBoxContainer.new(); f.add_theme_constant_override("separation", 12); vb.add_child(f)
	var r := rich("[b]Valeur de vente totale estimée :[/b] %s\n[b]Vente rapide (objets inutiles) :[/b] %d · %s" % [Game.fmt(tot), ql.size(), Game.fmt(qv)], 17)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER; f.add_child(r)
	var b := big_button("Vente rapide", ql.size() > 0, func(): main.quick_sell(); show_auction("sell"), GOLD, true); b.custom_minimum_size = Vector2(190, 52); f.add_child(b)

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

# étiquette « par rapport au prix moyen », comme sur Albion
static func avg_tag(price: int, real: int) -> String:
	var d := int(round((float(price) / max(1.0, float(real)) - 1.0) * 100.0))
	if abs(d) <= 2: return "[color=#d8dde0]≈ prix moyen[/color]"
	if d < 0: return "[color=#7dff8a]−%d %% sous la moyenne[/color]" % -d
	return "[color=#ff8a7a]+%d %% au-dessus[/color]" % d

# ——— Ordres d'achat : tu fixes ton prix, l'argent est réservé, les vendeurs viennent à toi ———
var ord_tier := 0
var ord_mult := 1.0
func _orders_tab(body: Control) -> void:
	var orders: Array = main.ah_orders()
	body.add_child(rich("[color=#a8b4bc]Place un ordre : l'argent est [b]réservé[/b] tout de suite. Les récolteurs te vendent leurs ressources au fil du temps — plus ton prix est haut, plus ça part vite. Annule quand tu veux : ce qui n'est pas livré t'est remboursé.[/color]", 15))
	if not orders.is_empty():
		body.add_child(_label("MES ORDRES", 15, Color("#ffb04a")))
		for i in orders.size():
			var o: Dictionary = orders[i]
			var e := {"res": o.res, "tier": int(o.tier), "qty": int(o.qty) - int(o.got)}
			var cb := big_button("Annuler", true, func(): main.ah_order_cancel(i), Color("#ff9a8a")); cb.custom_minimum_size = Vector2(120, 44)
			_ah_row(body, entry_tex(e), e, _price_box(int(o.unit) * (int(o.qty) - int(o.got)), cb), "   ·   livré [b]%d / %d[/b]   ·   %s / unité   ·   %s" % [int(o.got), int(o.qty), Game.fmt(int(o.unit)), avg_tag(int(o.unit), Game.res_price(int(o.tier)))])
	var t: int = ord_tier if ord_tier > 0 else clamp(Game.gear_level(), 1, 5)
	body.add_child(_label("NOUVEL ORDRE", 15, Color("#ffb04a")))
	var th := HBoxContainer.new(); th.add_theme_constant_override("separation", 6); body.add_child(th)
	th.add_child(_label("Tier :", 15, SOFT))
	for tt in range(1, 6):
		_chip(th, "T%d" % tt, tt == t, func(): ord_tier = tt; show_auction("orders"))
	var mh := HBoxContainer.new(); mh.add_theme_constant_override("separation", 6); body.add_child(mh)
	mh.add_child(_label("Ton prix :", 15, SOFT))
	for m in [[0.8, "−20 %"], [0.9, "−10 %"], [1.0, "moyen"], [1.15, "+15 %"], [1.3, "+30 %"]]:
		_chip(mh, m[1], is_equal_approx(ord_mult, m[0]), func(): ord_mult = m[0]; show_auction("orders"))
	for k in Game.RES_KEYS:
		var avg: int = Game.res_price(t)
		var unit: int = max(1, int(round(avg * ord_mult)))
		var e := {"res": k, "tier": t, "qty": 10}
		var bx := HBoxContainer.new(); bx.add_theme_constant_override("separation", 6)
		for q in [10, 50]:
			var b := big_button("×%d" % q, Game.S.silver >= unit * q, func(): main.ah_order(k, t, q, unit), GOLD, q == 10); b.custom_minimum_size = Vector2(84, 44); bx.add_child(b)
		_ah_row(body, entry_tex(e), e, bx, "   ·   moyenne [color=#ffd86b]%s[/color] / unité   ·   ton offre [b]%s[/b]  %s   ·   [color=#a8b4bc]%s[/color]" % [Game.fmt(avg), Game.fmt(unit), avg_tag(unit, avg), main.order_speed_txt(unit, avg)])

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
	h.add_child(rich("[b]%s[/b]  [color=#%s]T%d[/color]\nPrix moyen : [color=#ffd86b]%s[/color]   ·   ton prix : %s   ·   [color=#%s]Chance de vente : %d %%[/color]" % [entry_name(e), Game.TIER_COL[e.tier].to_html(false), e.tier, Game.fmt(real), avg_tag(ah_price, real), col.to_html(false), ch], 18))
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
		h.add_child(big_button("Guide du joueur", true, func(): show_guide(), GOLD, true))
		h.add_child(big_button("Effacer la partie", true, func(): _wipe(), Color("#ff9a8a")))
		var h2 := HBoxContainer.new(); h2.add_theme_constant_override("separation", 10); body.add_child(h2)
		var gfx_cb := func() -> void:
			Game.S["gfx"] = (Game.gfx() + 2) % 3; Game.save(); main.apply_gfx()
			toast("Graphismes : %s (l'herbe change au prochain chargement de carte)" % ["Rapide", "Équilibré", "Beau"][Game.gfx()], Color("#cfe8ff")); show_menu()
		h2.add_child(big_button("Graphismes : " + ["Rapide", "Équilibré", "Beau"][Game.gfx()], true, gfx_cb))
		h2.add_child(big_button("Signaler un bug", true, func(): show_report()))
		h2.add_child(big_button("Images/s : " + ("oui" if fps_lbl.visible else "non"), true, func(): fps_lbl.visible = not fps_lbl.visible; Game.S["show_fps"] = fps_lbl.visible; show_menu()))
		body.add_child(rich("[color=#7a848a]Graphismes : KayKit · Quaternius (Stylized Nature MegaKit, CC0) · Fantasy UI · icônes Viktor Hahn, frosty_rabbid, CraftPix, Cursed Loot.[/color]", 14))
	)

# ——— Guide du joueur : tout ce qu'il faut savoir, et le plan de la ville ———
var guide_tab := "debut"
const GUIDE_TABS := [["debut", "Bien débuter"], ["tiers", "Tiers & expérience"], ["ville", "Plan de la ville"], ["combat", "Combat & groupe"]]
const NPC_COL := {"shop": "#ffd24a", "tools": "#9be86a", "forge": "#ff8a4a", "auction": "#6ab8ff", "mercs": "#5dff7a", "travel": "#c58bff", "quest": "#ffe9a8", "talk": "#d0d8e0", "enchant": "#e08bff"}
const NPC_DO := {"shop": "potions, nourriture, revente", "tools": "vend les outils (hache, pioche, faucille)", "forge": "armes et armures : achat et fabrication", "auction": "acheter / vendre aux autres joueurs",
	"mercs": "engage des mercenaires pour les boss", "travel": "voyages rapides vers les autres régions", "quest": "quêtes et conseils", "enchant": "enchantement +1 à +5"}

func show_guide(tab := "") -> void:
	if tab != "": guide_tab = tab
	open_panel("Guide du joueur", func(body: VBoxContainer):
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); body.add_child(h)
		for t in GUIDE_TABS:
			var b := big_button(t[1], true, func(): show_guide(t[0]), GOLD, guide_tab == t[0]); b.custom_minimum_size = Vector2(150, 48); h.add_child(b)
		match guide_tab:
			"debut": body.add_child(rich(_guide_debut(), 17))
			"tiers": body.add_child(rich(_guide_tiers(), 17))
			"ville": _guide_town(body)
			"combat": body.add_child(rich(_guide_combat(), 17))
	, 900)

func _guide_debut() -> String:
	return "[b][color=#ffd27a]Le but[/color][/b]\nRécolte des ressources, fabrique-toi un meilleur équipement, monte en tier (T1 → T5) et va affronter des monstres, des boss et des donjons de plus en plus durs.\n\n" + \
		"[b][color=#ffd27a]Tes 5 premières minutes[/color][/b]\n" + \
		"1. Parle à [color=#ffe9a8]Aldric[/color] (le « ! » doré, près de la fontaine) : il te donne ta première quête.\n" + \
		"2. Récolte du [b]bois[/b], du [b]minerai[/b] et de la [b]fibre[/b] autour de la ville avec le gros bouton.\n" + \
		"3. Va à la [color=#ff8a4a]FORGE[/color] voir Brokk : il fabrique armes et armures avec tes ressources.\n" + \
		"4. Combats les monstres de ton tier pour gagner de l'[b]expérience d'arme et d'armure[/b].\n" + \
		"5. Vends ce dont tu n'as pas besoin à [color=#6ab8ff]l'Hôtel des ventes[/color] (sur la place).\n\n" + \
		"[b][color=#ffd27a]La réputation[/color][/b]\nÀ ton arrivée, les habitants te détestent (visage [color=#ff5a4a]rouge[/color] au-dessus de leur tête). Aide-les (« [color=#ffd24a]![/color] » jaune = quête, « [color=#7dff8a]?[/color] » vert = à rendre) pour passer à [color=#ff9a3a]Méfiant[/color], [color=#ffd24a]Neutre[/color], [color=#7dff8a]Amical[/color] puis [color=#ffcf3a]Héros[/color]. Plus ils t'aiment, moins c'est cher — et Amical ouvre l'enchantement, Héros la quête secrète.\n\n" + \
		"[b][color=#ffd27a]Les commandes[/color][/b]\n• Pouce à gauche : bouger. • Gros bouton : attaquer, récolter, parler, ouvrir.\n• Touche la mini-carte : carte du monde. • AUTO : le héros joue seul (réglable : quoi récolter, quels tiers).\n• Le bandeau en haut te dit toujours quoi faire ensuite (cercle doré sur la carte)."

func _guide_tiers() -> String:
	var t := "[b][color=#ffd27a]Comment marchent les tiers ?[/color][/b]\nChaque objet a un tier ([color=#%s]T1[/color] à [color=#%s]T5[/color]). Plus le tier est haut, plus il est fort — mais [b]il faut de l'expérience pour le porter[/b], pas seulement l'avoir dans le sac :\n" % [Game.TIER_COL[1].to_html(false), Game.TIER_COL[5].to_html(false)]
	t += "• [b]Arme[/b] : maîtrise de l'arme (monte en tuant des monstres avec elle).\n• [b]Casque, plastron, cape, bottes, bouclier[/b] : maîtrise d'armure (monte à chaque combat).\n• [b]Outils[/b] : niveau du métier (bûcheron, mineur, herboriste) en récoltant.\n• Et il faut avoir porté le tier d'avant (T2 avant T3…).\n\n"
	t += "[b][color=#ffd27a]Ta progression[/color][/b]\n[table=6][cell][b]Maîtrise[/b]   [/cell][cell][b]Niveau[/b]   [/cell]"
	for ti in range(2, 6): t += "[cell]%s   [/cell]" % tier_tag(ti)
	var wk: String = Game.S.get("weapon_kind", "epee")
	var rows := [[Game.WEAPON_KINDS[wk].name, int(Game.wxp(wk).lvl), Game.WREQ], ["Armure", int(Game.wxp("armure").lvl), Game.WREQ]]
	for tl in Game.TOOL_SLOTS: rows.append([Game.PROF_TITLE[tl], int(Game.prof(tl).lvl), Game.PROF_REQ])
	for r in rows:
		t += "[cell]%s[/cell][cell]%d[/cell]" % [r[0], r[1]]
		for ti in range(2, 6):
			var need: int = r[2][ti]
			t += "[cell]%s[/cell]" % (("[color=#7dff8a]✔ %d[/color]" % need) if r[1] >= need else ("[color=#ff9a8a]niv %d[/color]" % need))
	t += "[/table]\n\n[color=#a8b4bc]Monter est [b]long[/b] : compte quelques heures pour le T3, une quinzaine pour le T4 et des dizaines pour le T5. Les monstres et ressources [b]en dessous de ton tier ne rapportent que 35 %[/b] de l'expérience : il faut aller là où c'est dangereux. Premium (+50 %) et boosts (×2) accélèrent tout. Les objets portés gagnent aussi des niveaux (+5 % par niveau).[/color]"
	return t

func _guide_combat() -> String:
	return "[b][color=#ffd27a]Combat[/color][/b]\n• Esquive les [color=#ff7a6a]cercles rouges[/color] au sol : ce sont les attaques qui arrivent.\n• Tes compétences se débloquent avec le tier de ton arme (voir Menu).\n• Les potions se boivent automatiquement quand ta vie est basse.\n\n" + \
		"[b][color=#ffd27a]Où aller ?[/color][/b]\n• Les régions ont un tier : n'y va pas trop tôt (le nom de la région l'indique sur la carte).\n• [color=#c58bff]Portails violets[/color] : donjons aléatoires, le meilleur butin.\n• [color=#ff8a4a]VS[/color] : duellistes. [color=#d58bff]Boss de groupe[/color] : il faut être 4 — engage des mercenaires chez Rhéa.\n\n" + \
		"[b][color=#ff6a5a]Zones rouges[/color][/b] (régions T3+ des cartes 2 à 4) : XP et argent ×1,5, mais si tu meurs ton équipement reste sur ta tombe — 5 minutes pour revenir le chercher.\n" + \
		"[b][color=#ffd27a]Événements[/color][/b] : toutes les 30 min (à l'heure pile et à la demie) — Pluie d'or, Vent du savoir, Grande récolte ou La Horde. Le prochain est affiché sous la mini-carte.\n" + \
		"[b][color=#9fe0ff]Expéditions[/color][/b] : chez Rhéa (camp des mercenaires) ou dans QUOTIDIEN — tes hommes rapportent du butin même jeu fermé.\n\n" + \
		"[b][color=#ffd27a]Joueurs, guilde, duels[/color][/b]\n• Touche un joueur pour voir sa fiche : chuchoter, inviter en groupe, défier en duel.\n• Le chat (en bas à droite) a les canaux Monde, Guilde, Groupe et messages privés."

func _guide_town(body: VBoxContainer) -> void:
	var T = main.world.town
	if T == null:
		body.add_child(rich("Pas de ville sur cette carte.", 17)); return
	body.add_child(rich("[color=#a8b4bc]Chaque personnage a SON endroit. Le point blanc, c'est toi.[/color]", 15))
	var sz := 520.0
	var holder := Control.new(); holder.custom_minimum_size = Vector2(sz, sz); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; body.add_child(holder)
	var bb: Rect2 = T.bbox.grow(-14.0)
	var side: float = max(bb.size.x, bb.size.y)
	var org: Vector2 = bb.get_center() - Vector2(side, side) * 0.5
	var k: float = sz / side
	var P := func(q: Vector2) -> Vector2: return (q - org) * k
	var lst: Array = []
	var seen := {}
	for n in main.npcs:
		if not NPC_DO.has(n.act) or n.hidden or seen.has(n.nm): continue
		var q0: Vector2 = P.call(Vector2(n.home.x, n.home.z))
		if q0.x < 0 or q0.y < 0 or q0.x > sz or q0.y > sz: continue
		seen[n.nm] = 1; lst.append(n)
	var cv := Control.new(); cv.size = Vector2(sz, sz); cv.clip_contents = true; holder.add_child(cv)
	cv.draw.connect(func():
		cv.draw_rect(Rect2(Vector2.ZERO, Vector2(sz, sz)), Color("#3d5a32"))
		for st in T.streets:
			var pts := PackedVector2Array()
			for q: Vector2 in st.pts: pts.append(P.call(q))
			cv.draw_polyline(pts, Color("#b8a888") if st.main else Color("#8a7458"), max(3.0, float(st.half) * 2.0 * k), true)
		cv.draw_circle(P.call(T.V), (TownGen.PLAZA_R + 1.2) * k, Color("#c8bca4"))
		cv.draw_circle(P.call(T.V), 2.6 * k, Color("#5aa8e0"))
		for hm in T.homes:
			var c: Vector2 = hm.get("hc", hm.c); var ax := Vector2(cos(hm.rot), -sin(hm.rot)); var az := Vector2(sin(hm.rot), cos(hm.rot))
			if hm.get("plot", false):
				var pc: Vector2 = hm.c; var pw: float = float(hm.pw) * 0.5; var pd: float = float(hm.pd) * 0.5
				cv.draw_polyline(PackedVector2Array([P.call(pc - ax * pw - az * pd), P.call(pc + ax * pw - az * pd), P.call(pc + ax * pw + az * pd), P.call(pc - ax * pw + az * pd), P.call(pc - ax * pw - az * pd)]), Color(0.75, 0.72, 0.6, 0.6), 1.5)
			var hw: float = float(hm.w) * 0.5
			var col := Color("#b85a3c") if hm.kind == "house" else Color("#e0a040")
			cv.draw_colored_polygon(PackedVector2Array([P.call(c - ax * hw - az * 4.0), P.call(c + ax * hw - az * 4.0), P.call(c + ax * hw + az * 4.0), P.call(c - ax * hw + az * 4.0)]), col)
			if hm.kind != "house":
				_text(cv, {"forge": "FORGE", "inn": "AUBERGE", "mercs": "MERCENAIRES", "auction": "VENTES"}.get(hm.kind, ""), P.call(c) + Vector2(0, 5), 12, Color("#fff4d8"), true, f_title)
		for i in lst.size():
			var n = lst[i]
			var q: Vector2 = P.call(Vector2(n.home.x, n.home.z))
			var nc := Color(NPC_COL.get(n.act, "#ffffff"))
			cv.draw_circle(q, 10, Color(0, 0, 0, 0.75)); cv.draw_circle(q, 8, nc)
			_text(cv, str(i + 1), q + Vector2(0, 5), 13, Color(0.05, 0.05, 0.08), true, f_title)
		var pp: Vector2 = P.call(Vector2(main.player.global_position.x, main.player.global_position.z))
		cv.draw_circle(pp, 6, Color.WHITE); cv.draw_arc(pp, 9, 0, TAU, 20, Color(0, 0, 0, 0.7), 2))
	var leg := "[b]Qui fait quoi[/b]\n"
	for i in lst.size():
		var n = lst[i]
		leg += "[color=%s][b]%d[/b][/color]  [b]%s[/b] — %s : %s\n" % [NPC_COL.get(n.act, "#ffffff"), i + 1, n.nm, n.role, NPC_DO[n.act]]
	body.add_child(rich(leg, 16))

var pi_last := 0
var pi_flash := 0.0
var rank_cache := 0

# ——— Rapport de bug : ce qui s'est passé juste avant, à copier et m'envoyer ———
func show_report(after_crash := false) -> void:
	var rep_txt := Game.bug_report()
	open_panel("Signaler un bug", func(body: VBoxContainer):
		if after_crash: body.add_child(rich("[color=#ffb07a][b]Le jeu s'est fermé brutalement la dernière fois.[/b][/color] Copie ce rapport et envoie-le : il dit ce que tu faisais juste avant.", 17))
		else: body.add_child(rich("Copie ce rapport et envoie-le avec une phrase sur ce qui s'est passé.", 17))
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); body.add_child(h)
		h.add_child(big_button("Copier le rapport", true, func(): DisplayServer.clipboard_set(rep_txt); toast("Rapport copié — colle-le dans ton message", Color("#7dff8a"), true), GOLD, true))
		h.add_child(big_button("Fermer", true, func(): close_panel()))
		var t := rich("[color=#a8b4bc][font_size=13]%s[/font_size][/color]" % rep_txt.replace("[", "(").replace("]", ")"), 13)
		body.add_child(t)
	, 900)

# ——— Après une défaite : ce qui t'a manqué, et comment devenir plus fort ———
func show_defeat(who: String, need: int) -> void:
	var me := Game.power()
	open_panel("Défaite", func(body: VBoxContainer):
		body.add_child(rich("[center][font_size=24][b]%s était trop fort pour toi.[/b][/font_size]\nTa puissance : [color=#c8a8ff][b]%d[/b][/color]   ·   puissance conseillée : [color=#ff9a8a][b]%d[/b][/color]\n[font_size=22]Il te manquait [color=#ff9a8a][b]%d de puissance[/b][/color].[/font_size][/center]" % [who, me, need, need - me], 18))
		var tips := "[b]Pour devenir plus fort :[/b]\n• Monte ta [b]maîtrise d'arme et d'armure[/b] pour pouvoir porter le tier suivant.\n• Fabrique un meilleur équipement à la [color=#ff8a4a]forge[/color] et fais-le [color=#e7a8ff]enchanter[/color].\n• Équipe un [b]artefact[/b] (duels, donjons, boss de groupe)."
		if not Game.is_premium(): tips += "\n• [color=#ffcf5a]Premium[/color] : +50 %% d'expérience et d'argent — tu progresses bien plus vite."
		body.add_child(rich(tips, 17))
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); h.alignment = BoxContainer.ALIGNMENT_CENTER; body.add_child(h)
		h.add_child(big_button("Ma progression", true, func(): show_guide("tiers")))
		h.add_child(big_button("Classement", true, func(): show_ranking()))
		h.add_child(big_button("Devenir plus fort", true, func(): show_boutique("premium"), GOLD, true))
	, 760, 470)

# ——— Quotidien : connexion 7 jours + 3 quêtes du jour ———
func show_daily() -> void:
	open_panel("Quotidien", func(body: VBoxContainer):
		cur_panel = "daily"
		body.add_child(rich("[b][color=#ffd27a]Connexion quotidienne[/color][/b]  [color=#a8b4bc]reviens chaque jour : le 7e jour est énorme. Rater un jour remet la série à zéro.[/color]", 17))
		var row7 := HBoxContainer.new(); row7.add_theme_constant_override("separation", 8); body.add_child(row7)
		var nxt := Game.login_next_index(); var can := Game.login_can_claim()
		var done_n: int = nxt if can else int(Game.login_state().streak)
		for i in 7:
			var r: Dictionary = Game.LOGIN_REWARDS[i]
			var got: bool = i < done_n
			var today: bool = can and i == nxt
			var pc := PanelContainer.new(); pc.custom_minimum_size = Vector2(104, 112)
			pc.add_theme_stylebox_override("panel", flat(Color(0.2, 0.5, 0.25, 0.85) if got else (Color(0.4, 0.3, 0.08, 0.95) if today else Color(1, 1, 1, 0.06)), 12, Color("#ffcf5a") if today else Color(1, 1, 1, 0.15), 2 if today else 1, Vector4(6, 6, 6, 6)))
			pc.add_child(rich("[center][b]Jour %d[/b]\n%s\n%s[/center]" % [i + 1, ("[img=30x30]res://ui/crown.png[/img]" if r.has("crowns") else "[img=30x30]res://ui/it_coins.png[/img]"), ("[color=#7dff8a]✔[/color]" if got else "[font_size=12]%s[/font_size]" % r.txt)], 14))
			row7.add_child(pc)
		var claim := func() -> void:
			var r := Game.login_claim()
			main.tuto_event("daily")
			if not r.is_empty(): celebrate("CONNEXION · JOUR %d" % int(Game.login_state().streak), r.txt, "it_chest_open"); Game.play("coin")
			show_daily()
		var cb := big_button("Récupérer le jour %d" % (nxt + 1) if can else "Reviens demain !", can, claim, GOLD, can)
		body.add_child(cb)
		body.add_child(rich("\n[b][color=#ffd27a]Quêtes du jour[/color][/b]  [color=#a8b4bc]nouvelles quêtes chaque jour à minuit[/color]", 17))
		for i in Game.daily_quests().size():
			var q: Dictionary = Game.daily_quests()[i]
			var full: bool = int(q.n) >= int(q.goal)
			var left := rich("[b]%s[/b]   [color=%s]%s / %s[/color]\n[color=#a8b4bc]Récompense : [img=20x20]res://ui/crown.png[/img] %d couronnes + %s argent[/color]" % [q.txt, "#7dff8a" if full else "#ffd27a", Game.fmt(int(q.n)), Game.fmt(int(q.goal)), int(q.crowns), Game.fmt(int(q.silver))], 17)
			var take := func() -> void:
				q.claimed = true; Game.grant({"crowns": int(q.crowns), "silver": int(q.silver)})
				Game.rep_add(3)
				celebrate("QUÊTE DU JOUR", "+%d couronnes · +%s argent" % [int(q.crowns), Game.fmt(int(q.silver))], "it_quest"); Game.play("coin")
				show_daily()
			var bt := big_button("Reçu ✔" if q.claimed else ("Récupérer" if full else "En cours"), full and not q.claimed, take, GOLD, full and not q.claimed)
			row(body, left, bt)
		var allc := Game.daily_quests().all(func(x): return x.claimed)
		var bonus_done: bool = Game.S.dq.get("bonus", false)
		var bonus := func() -> void:
			Game.S.dq.bonus = true; Game.grant({"crowns": 30}); celebrate("JOURNÉE COMPLÈTE !", "+30 couronnes", "it_trophy"); show_daily()
		var bb := big_button("Bonus des 3 quêtes : 30 couronnes" if not bonus_done else "Bonus reçu ✔", allc and not bonus_done, bonus, GOLD, allc and not bonus_done)
		body.add_child(bb)
		if main.vq:
			var jt := "\n[b][color=#ffd27a]Quêtes des habitants[/color][/b]  [color=#a8b4bc]réputation : %s (%+d)[/color]\n" % [Game.rep_level()[1], Game.rep()]
			for ch in VQuests.Q:
				var q: Dictionary = main.vq.cur(ch)
				if q.is_empty(): jt += "[color=#7dff8a]✔[/color] %s : toutes les quêtes faites\n" % VQuests.ROLE_NAME[ch]; continue
				var stt: Dictionary = main.vq.state(ch)
				if stt.on: jt += "• [b]%s[/b] (%s) — %s\n" % [q.title, VQuests.ROLE_NAME[ch], main.vq.progress_text(ch)]
				elif Game.rep() < int(q.need): jt += "[color=#8a949c]• %s : réservé aux %s[/color]\n" % [VQuests.ROLE_NAME[ch], "héros" if int(q.need) >= 70 else "habitants mieux disposés"]
				else: jt += "[color=#ffd27a]• %s a une quête pour toi (« ! »)[/color]\n" % VQuests.ROLE_NAME[ch]
			body.add_child(rich(jt, 16))
		var el := Game.exped_left()
		var etxt := "Expédition : aucune en cours — envoie tes mercenaires (même jeu fermé)" if el < 0 else ("Expédition : [color=#7dff8a]revenue ! Butin à récupérer[/color]" if el == 0 else "Expédition : retour dans %s" % Game.dur_txt(el))
		body.add_child(rich("\n[b][color=#ffd27a]Expéditions[/color][/b]  " + etxt, 17))
		body.add_child(big_button("Ouvrir les expéditions", true, func(): show_expedition(), GOLD, el <= 0))
	, 900)

# ——— Expéditions : ça tourne même téléphone éteint ———
func show_expedition() -> void:
	open_panel("Expéditions", func(body: VBoxContainer):
		body.add_child(rich("[i][color=#d8c8a8]« Mes hommes partent en mission pour toi. Plus ils restent longtemps, plus ils rapportent — même pendant que tu dors. » — Rhéa[/color][/i]", 17))
		var left := Game.exped_left()
		if left < 0:
			body.add_child(rich("Choisis la durée. Le butin dépend du tier de ton arme ([b]T%d[/b]) : argent, ressources, objets, potions, couronnes.%s" % [clamp(int(Game.S.gear.get("epee", 1)), 1, 5), " [color=#ffcf5a]Premium : +50 %.[/color]" if Game.is_premium() else ""], 17))
			var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 12); g.add_theme_constant_override("v_separation", 10); body.add_child(g)
			for i in Game.EXPED.size():
				var b := big_button("Partir %s" % Game.EXPED[i][1], true, func(): Game.exped_start(i); Game.play("level", -6.0); toast("Expédition partie : retour dans %s" % Game.EXPED[i][1], Color("#9fe0ff"), true); show_expedition(), GOLD, i == 1)
				b.custom_minimum_size = Vector2(300, 56); g.add_child(b)
		elif left > 0:
			var e := Game.exped()
			body.add_child(rich("[center][font_size=24]Expédition de [b]%s[/b] en cours (T%d)[/font_size]\nRetour dans [b][color=#9fe0ff]%s[/color][/b][/center]" % [e.label, int(e.tier), Game.dur_txt(left)], 18))
			var bar := ProgressBar.new(); bar.custom_minimum_size = Vector2(0, 22); bar.max_value = float(e.dur); bar.value = float(e.dur) - left; bar.show_percentage = false; body.add_child(bar)
			body.add_child(rich("[color=#a8b4bc]Tu peux fermer le jeu : le temps continue de compter.[/color]", 15))
		else:
			body.add_child(rich("[center][font_size=26][b][color=#7dff8a]L'expédition est revenue ![/color][/b][/font_size][/center]", 18))
			var open_cb := func() -> void:
				var r := Game.exped_collect()
				if r.is_empty(): return
				close_panel(); toast("+%d couronnes rapportées par l'expédition" % r.crowns, Color("#ffe39a"), true)
				show_loot({"title": "Retour d'expédition (%s)" % r.label, "rarity": 2, "loot": r.loot, "pos": main.player.global_position, "opened": false})
			body.add_child(big_button("Ouvrir le butin", true, open_cb, GOLD, true))
	, 760)

# ——— Classement de puissance ———
func show_ranking() -> void:
	open_panel("Classement de puissance", func(body: VBoxContainer):
		var R := Game.ranking()
		var me := 0
		for i in R.size():
			if R[i].me: me = i
		rank_cache = me + 1
		var head := "Tu es [b][color=#ffe39a]#%d[/color][/b] sur %d avec [b][color=#c8a8ff]%d de puissance[/color][/b]." % [me + 1, R.size(), Game.power()]
		if me > 0: head += "\nIl te manque [b][color=#ff9a8a]%d[/color][/b] pour dépasser [b]%s[/b] (#%d)." % [int(R[me - 1].pwr) - Game.power() + 1, R[me - 1].nm, me]
		head += "\n[color=#a8b4bc]Les autres aventuriers progressent chaque jour : si tu t'arrêtes, tu recules. La puissance monte avec le tier, l'enchantement et l'artefact de chaque pièce portée.[/color]"
		body.add_child(rich(head, 17))
		var rows: Array = []
		for i in min(10, R.size()): rows.append(i)
		for i in range(max(0, me - 3), min(R.size(), me + 4)):
			if not i in rows: rows.append(i)
		var last := -1
		var t := "[table=4]"
		for i in rows:
			if last >= 0 and i > last + 1: t += "[cell][color=#6a7480]…[/color][/cell][cell][/cell][cell][/cell][cell][/cell]"
			var r: Dictionary = R[i]
			var col := "#ffe39a" if r.me else ("#ffcf5a" if i < 3 else "#e8e2d0")
			var medal: String = "★" if i < 3 else ""
			t += "[cell][color=%s][b]#%d[/b] %s   [/color][/cell][cell][color=%s]%s%s   [/color][/cell][cell][color=#8a949c]%s   [/color][/cell][cell][color=#c8a8ff][b]%d[/b][/color][/cell]" % [col, i + 1, medal, col, "► " if r.me else "", r.nm, r.guild, int(r.pwr)]
			last = i
		t += "[/table]"
		body.add_child(rich(t, 17))
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10); body.add_child(h)
		h.add_child(big_button("Devenir plus fort (Guide)", true, func(): show_guide("tiers")))
		h.add_child(big_button("Boutique", true, func(): show_boutique("premium"), GOLD, true))
	, 860)

func _toggle_sound() -> void:
	AudioServer.set_bus_volume_db(0, -80.0 if AudioServer.get_bus_volume_db(0) > -50 else 0.0); show_menu()
func _to_camp() -> void:
	close_panel(); main.teleport_camp()
func _wipe() -> void:
	Game.reset_save(); get_tree().reload_current_scene()

var map_tab := "region"
func show_map(tab := "") -> void:
	if tab != "": map_tab = tab
	if map_tab == "monde" and not map_dungeon: _show_world_map(); return
	var s := vs(); var sz: float = min(s.y - 170, 500.0)
	open_panel(("Carte de la tour" if main.tower else "Carte du donjon") if map_dungeon else Maps.label(main.world.map_id), func(body: VBoxContainer):
		if not map_dungeon:
			var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 8); tb.alignment = BoxContainer.ALIGNMENT_CENTER; body.add_child(tb)
			_chip(tb, "Région", true, func(): show_map("region")); _chip(tb, "Royaume", false, func(): show_map("monde"))
		var holder := Control.new(); holder.custom_minimum_size = Vector2(sz, sz); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; body.add_child(holder)
		var tr := TextureRect.new(); tr.texture = map_tex; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.size = Vector2(sz, sz); holder.add_child(tr)
		var marks := Control.new(); marks.size = Vector2(sz, sz); holder.add_child(marks)
		marks.draw.connect(func(): _draw_bigmap(marks, sz))
	, sz + 70, sz + 110)

# ——— Carte du royaume (façon Albion) : les 4 terres, leurs villes, leurs routes ———
const KINGDOMS := {1: {"g": Vector2(0, 1), "col": Color("#86b85a"), "col2": Color("#a6c86a")}, 2: {"g": Vector2(0, 0), "col": Color("#4f8a46"), "col2": Color("#6aa055")},
	3: {"g": Vector2(1, 0), "col": Color("#d2ad72"), "col2": Color("#e2c28a")}, 4: {"g": Vector2(1, -1), "col": Color("#8c8a92"), "col2": Color("#d8dce6")}}
const KTOWN := {1: ["Valdrune", Vector2(0, 66)], 2: ["Chênevert", Vector2(-10, 70)], 3: ["Ksar d'Ambre", Vector2(-64, 0)], 4: ["Fort-Gris", Vector2(0, 80)]}
var world_tex: Texture2D
func _kingdom_at(u: float, v: float, nz: FastNoiseLite) -> Array:
	# coordonnées monde-carte : chaque royaume occupe une case de 1×1, centrée en (g + 0.5)
	var best := 0; var bd := 99.0
	for id in KINGDOMS:
		var g: Vector2 = KINGDOMS[id].g
		var d := Vector2(u - (g.x + 0.5), v - (g.y + 0.5))
		var e: float = lerp(d.length(), max(abs(d.x), abs(d.y)), 0.45) + nz.get_noise_2d(u * 22.0, v * 22.0) * 0.11 + nz.get_noise_2d(u * 70.0, v * 70.0) * 0.03
		if e < bd: bd = e; best = id
	return [best, bd]
func _world_tex() -> Texture2D:
	if world_tex: return world_tex
	var R := 220; var img := Image.create(R, R, false, Image.FORMAT_RGB8)
	var nz := FastNoiseLite.new(); nz.seed = 31; nz.frequency = 0.05
	var nz2 := FastNoiseLite.new(); nz2.seed = 77; nz2.frequency = 0.02
	for j in R:
		for i in R:
			# l'image couvre x ∈ [-0.35, 2.35], y ∈ [-1.35, 2.35]
			var u: float = lerp(-0.35, 2.35, float(i) / R); var v: float = lerp(-1.35, 2.35, float(j) / R)
			var k := _kingdom_at(u, v, nz)
			var coast: float = float(k[1])
			var col: Color
			if coast > 0.47:
				var deep: float = clamp((coast - 0.47) * 4.0, 0.0, 1.0)
				col = Color("#3f7fae").lerp(Color("#1c3d66"), deep)
				col = col.lightened(nz2.get_noise_2d(i * 3.0, j * 3.0) * 0.05)
			else:
				var K: Dictionary = KINGDOMS[k[0]]
				var t: float = nz2.get_noise_2d(i * 2.0, j * 2.0) * 0.5 + 0.5
				col = (K.col as Color).lerp(K.col2, t)
				if k[0] == 4 and v < -0.6: col = col.lerp(Color("#eef2f8"), clamp((-0.6 - v) * 2.5, 0.0, 0.8))   # neiges du nord
				col = col.darkened(nz.get_noise_2d(i * 4.0, j * 4.0) * 0.12)
				if coast > 0.43: col = col.lerp(Color("#e8d8a8"), 0.6)   # plages
			img.set_pixel(i, j, col)
	world_tex = ImageTexture.create_from_image(img)
	return world_tex
func _show_world_map() -> void:
	var s := vs(); var sz: float = min(s.y - 170, 500.0)
	open_panel("Le Royaume", func(body: VBoxContainer):
		var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 8); tb.alignment = BoxContainer.ALIGNMENT_CENTER; body.add_child(tb)
		_chip(tb, "Région", false, func(): show_map("region")); _chip(tb, "Royaume", true, func(): show_map("monde"))
		var holder := Control.new(); holder.custom_minimum_size = Vector2(sz, sz); holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; body.add_child(holder)
		var tr := TextureRect.new(); tr.texture = _world_tex(); tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.size = Vector2(sz, sz); tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR; holder.add_child(tr)
		var marks := Control.new(); marks.size = Vector2(sz, sz); holder.add_child(marks)
		marks.draw.connect(func(): _draw_world(marks, sz))
		body.add_child(rich("[center][color=#a8b4bc]Chaque terre a ses tiers, sa ville et sa réputation. On voyage par les passages aux bords des cartes, ou avec le passeur de la ville.[/color][/center]", 14))
	, sz + 70, sz + 150)
func _wm(u: float, v: float, sz: float) -> Vector2: return Vector2((u + 0.35) / 2.7, (v + 1.35) / 3.7) * sz
func _draw_world(c: Control, sz: float) -> void:
	var cur: int = main.world.map_id
	# routes entre les terres (les passages)
	for pr in [[1, 2], [2, 3], [3, 4]]:
		var a: Vector2 = KINGDOMS[pr[0]].g + Vector2(0.5, 0.5); var b: Vector2 = KINGDOMS[pr[1]].g + Vector2(0.5, 0.5)
		var pa := _wm(a.x, a.y, sz); var pb := _wm(b.x, b.y, sz)
		var n := 14
		for k in n:
			if k % 2 == 0: c.draw_line(pa.lerp(pb, float(k) / n), pa.lerp(pb, float(k + 1) / n), Color(0.45, 0.3, 0.15, 0.85), 3.0, true)
	for id in KINGDOMS:
		var g: Vector2 = KINGDOMS[id].g
		var ctr := _wm(g.x + 0.5, g.y + 0.5, sz)
		var tier: Array = Maps.TIERS[id]
		var nm: String = Maps.NAMES[id]
		var top := ctr + Vector2(0, -sz * 0.105)
		_text(c, nm.to_upper(), top, 16, Color("#fff4d8"), true, f_title)
		_text(c, "T%d – T%d" % [tier[0], tier[1]], top + Vector2(0, 17), 13, Game.TIER_COL[tier[1]].lightened(0.25), true, f_title)
		# ville
		var tp: Vector2 = KTOWN[id][1]
		var tq := _wm(g.x + (tp.x + 128.0) / 256.0, g.y + (tp.y + 128.0) / 256.0, sz)
		c.draw_rect(Rect2(tq - Vector2(7, 7), Vector2(14, 14)), Color("#fff4d8")); c.draw_rect(Rect2(tq - Vector2(7, 7), Vector2(14, 14)), Color("#3a2410"), false, 2.0)
		_text(c, KTOWN[id][0], tq + Vector2(0, 22), 12, Color("#ffe9b8"), true, f_title)
		# réputation de cette terre
		var lv: Array = Game.rep_level(Game.rep(id))
		c.draw_texture_rect(T("mood_" + str(lv[2])), Rect2(top + Vector2(-46, 24), Vector2(18, 18)), false)
		_text(c, "%s %+d" % [lv[1], Game.rep(id)], top + Vector2(8, 38), 12, Color(str(lv[3])), true, f_title)
		if id == cur:
			c.draw_arc(ctr, sz * 0.19, 0, TAU, 48, Color(1, 0.85, 0.3, 0.9), 3.0, true)
			var pp: Vector3 = main.player.global_position
			var me := _wm(g.x + (pp.x + 128.0) / 256.0, g.y + (pp.z + 128.0) / 256.0, sz)
			c.draw_circle(me, 7, Color.WHITE); c.draw_arc(me, 10, 0, TAU, 20, Color(0, 0, 0, 0.7), 2)
			_text(c, "Toi", me + Vector2(0, -12), 12, Color.WHITE, true, f_title)

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
const SHOP_TABS := [["une", "★ À la une"], ["couronnes", "Couronnes"], ["premium", "Premium & boosts"], ["montures", "Montures"], ["armes", "Armes"], ["equip", "Équipements"], ["ressources", "Ressources"], ["argent", "Argent"]]
# id, onglet, nom, description, icône, couleur, prix en couronnes (cr) ou en euros (eur, achat simulé), mise en avant
const OFFERS := [
	{"id": "pack_debut", "tab": "couronnes", "name": "Pack du débutant", "desc": "300 couronnes + Cheval de selle + 3 jours Premium · une seule fois", "icon": "mount_cheval", "col": "#ffcf5a", "eur": "0,99 €", "hot": true, "once": true},
	{"id": "c1", "tab": "couronnes", "name": "Poignée de couronnes", "desc": "120 couronnes", "icon": "crown", "col": "#ffd86b", "eur": "0,99 €", "gives": 120},
	{"id": "c2", "tab": "couronnes", "name": "Bourse de couronnes", "desc": "650 couronnes (+8 % offert)", "icon": "crown", "col": "#7fc8ff", "eur": "4,99 €", "gives": 650},
	{"id": "c3", "tab": "couronnes", "name": "Coffret de couronnes", "desc": "1 400 couronnes (+17 % offert)", "icon": "crown", "col": "#62d24e", "eur": "9,99 €", "gives": 1400, "hot": true},
	{"id": "c4", "tab": "couronnes", "name": "Coffre de couronnes", "desc": "3 000 couronnes (+25 % offert)", "icon": "crown", "col": "#c77dff", "eur": "19,99 €", "gives": 3000},
	{"id": "c5", "tab": "couronnes", "name": "Trésor du roi", "desc": "8 000 couronnes (+33 % offert)", "icon": "crown", "col": "#ff9a3c", "eur": "49,99 €", "gives": 8000},
	{"id": "premium30", "tab": "premium", "name": "Premium · 30 jours", "desc": "+50 % d'expérience partout, +50 % d'argent, nom doré", "icon": "it_trophy", "col": "#ffcf5a", "cr": 450, "hot": true},
	{"id": "premium7", "tab": "premium", "name": "Premium · 7 jours", "desc": "+50 % d'expérience partout, +50 % d'argent", "icon": "it_trophy", "col": "#ffe39a", "cr": 150},
	{"id": "boost1", "tab": "premium", "name": "Boost d'expérience · 1 h", "desc": "Expérience ×2 (armes, armure, métiers) — cumulable avec Premium", "icon": "it_seal", "col": "#7dff8a", "cr": 40},
	{"id": "boost24", "tab": "premium", "name": "Boost d'expérience · 24 h", "desc": "Expérience ×2 pendant une journée entière", "icon": "it_seal", "col": "#4fe36a", "cr": 250},
	{"id": "maitrise", "tab": "premium", "name": "Parchemin de guerre", "desc": "+3 niveaux de maîtrise d'arme ET d'armure", "icon": "it_trophy", "col": "#ffb07a", "cr": 180, "hot": true},
	{"id": "metier", "tab": "premium", "name": "Parchemin d'artisan", "desc": "+3 niveaux à tous les métiers", "icon": "pioche", "col": "#9dffb0", "cr": 150},
	{"id": "enchant", "tab": "premium", "name": "Parchemin d'enchantement", "desc": "+1 enchantement sur toutes les pièces portées", "icon": "art_rage", "col": "#e7a8ff", "cr": 220},
	{"id": "auto", "tab": "premium", "name": "Écuyer automatique", "desc": "Ton héros récolte et chasse tout seul (bouton AUTO)", "icon": "it_hunt", "col": "#7dff8a", "cr": 600},
	{"id": "sac", "tab": "premium", "name": "Sac agrandi", "desc": "+8 cases (jusqu'à +24)", "icon": "it_loot_rare", "col": "#e9dcc0", "cr": 120},
	{"id": "potions", "tab": "premium", "name": "Caisse de potions", "desc": "25 potions de soin", "icon": "potion", "col": "#7dff8a", "cr": 30},
	{"id": "leg", "tab": "premium", "name": "Coffre légendaire", "desc": "Un butin légendaire T5 à ouvrir", "icon": "it_chest_open", "col": "#ffb02e", "cr": 350},
	{"id": "garde", "tab": "premium", "name": "Garde d'élite", "desc": "3 mercenaires T5 rejoignent ton groupe", "icon": "char_Knight", "col": "#9fd4ff", "cr": 400},
	{"id": "pegase", "tab": "montures", "name": "Pégase d'Azur", "desc": "+170 % vitesse · +30 % dégâts · +30 % vie", "icon": "mount_pegase", "col": "#5fb0ff", "cr": 4000, "hot": true},
	{"id": "m_roi_cerf", "tab": "montures", "name": "Roi-Cerf doré", "desc": "Monture T5 : +120 % vitesse, +15 % dégâts", "icon": "mount_roi_cerf", "col": "#ffb02e", "cr": 2600},
	{"id": "m_taureau", "tab": "montures", "name": "Taureau cuirassé", "desc": "Monture T5 : +100 % vitesse, +12 % dégâts, +15 % vie", "icon": "mount_taureau", "col": "#ff6a5a", "cr": 2200},
	{"id": "m_loup", "tab": "montures", "name": "Loup de guerre", "desc": "Monture T4 : rapide, +8 % de vie", "icon": "mount_loup", "col": "#4d78ff", "cr": 900},
	{"id": "m_cheval", "tab": "montures", "name": "Cheval de selle", "desc": "Monture T2 : +75 % de vitesse", "icon": "mount_cheval", "col": "#62d24e", "cr": 150},
	{"id": "lame", "tab": "armes", "name": "Lame de l'Aube +5", "desc": "Épée T5 enchantée au maximum · maîtrise niv 24", "icon": "arme_epee_5", "col": "#ffb02e", "cr": 2400, "hot": true},
	{"id": "fendeuse", "tab": "armes", "name": "Fendeuse du Néant +5", "desc": "Hache T5 +5 · maîtrise niv 24", "icon": "arme_hache_5", "col": "#ff6a5a", "cr": 2400},
	{"id": "sceptre", "tab": "armes", "name": "Sceptre Astral +5", "desc": "Bâton T5 +5 · maîtrise niv 24", "icon": "arme_baton_5", "col": "#c77dff", "cr": 2400},
	{"id": "titan", "tab": "armes", "name": "Rempart du Titan +5", "desc": "Bouclier T5 +5 · armure niv 24", "icon": "bouclier_5", "col": "#9fd4ff", "cr": 1600},
	{"id": "set_plate", "tab": "equip", "name": "Plates du Dragon +5", "desc": "Armure de plates T5 +5 · armure niv 24", "icon": "armure_plate", "col": "#ff3d3d", "cr": 2000},
	{"id": "set_cuir", "tab": "equip", "name": "Cuir de l'Ombre +5", "desc": "Veste de cuir T5 +5 · armure niv 24", "icon": "armure_cuir", "col": "#4fe36a", "cr": 2000},
	{"id": "set_tissu", "tab": "equip", "name": "Robe Céleste +5", "desc": "Robe de mage T5 +5 · armure niv 24", "icon": "armure_tissu", "col": "#b45cff", "cr": 2000},
	{"id": "bottes", "tab": "equip", "name": "Bottes de Vent +5", "desc": "Bottes T5 +5 · armure niv 24", "icon": "boots_5", "col": "#7fe8ff", "cr": 1300},
	{"id": "art_rage", "tab": "equip", "name": "Idole de rage +3", "desc": "Artefact T5 : +30 % de dégâts", "icon": "art_rage", "col": "#ff7a4a", "cr": 1500},
	{"id": "art_vie", "tab": "equip", "name": "Calice de vie +3", "desc": "Artefact T5 : +40 % de vie", "icon": "art_vie", "col": "#7dff8a", "cr": 1500},
	{"id": "art_fortune", "tab": "equip", "name": "Anneau de fortune +3", "desc": "Artefact T5 : +50 % d'argent gagné", "icon": "art_fortune", "col": "#ffd24a", "cr": 1500},
	{"id": "res2", "tab": "ressources", "name": "Pack d'apprenti T2", "desc": "120 bois, minerai et fibre T2", "icon": "res_ore_2", "col": "#62d24e", "cr": 60},
	{"id": "res3", "tab": "ressources", "name": "Pack d'artisan T3", "desc": "120 bois, minerai et fibre T3", "icon": "res_ore_3", "col": "#33c4dc", "cr": 200},
	{"id": "res4", "tab": "ressources", "name": "Pack de maître T4", "desc": "120 bois, minerai et fibre T4", "icon": "res_ore_4", "col": "#4d78ff", "cr": 700},
	{"id": "res5", "tab": "ressources", "name": "Pack légendaire T5", "desc": "120 bois, minerai et fibre T5", "icon": "res_ore_5", "col": "#ff3d3d", "cr": 2000},
	{"id": "or1", "tab": "argent", "name": "Bourse d'argent", "desc": "100 000 argent", "icon": "it_coins", "col": "#ffd86b", "cr": 80},
	{"id": "or2", "tab": "argent", "name": "Coffre d'argent", "desc": "2 000 000 argent", "icon": "it_coins", "col": "#7fc8ff", "cr": 600},
	{"id": "or3", "tab": "argent", "name": "Trésor royal", "desc": "50 000 000 argent", "icon": "it_chest_open", "col": "#e58bff", "cr": 6000},
]
var shop_tab := "une"
func offer(id: String) -> Dictionary:
	for o in OFFERS:
		if o.id == id: return o
	return {}
# confirmation d'un achat en euros (SIMULÉ : aucun paiement réel)
func confirm_purchase(o: Dictionary) -> void:
	open_panel("Confirmer l'achat", func(body: VBoxContainer):
		body.add_child(rich("[center][font_size=26][b]%s[/b][/font_size]\n%s\n\n[font_size=30][color=#7dff8a][b]%s[/b][/color][/font_size][/center]" % [o.name, o.desc, o.eur], 19))
		body.add_child(rich("[center][color=#ffb07a]Version de test : l'achat est simulé, rien n'est débité.[/color][/center]", 15))
		var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 16); body.add_child(h)
		h.add_child(big_button("Annuler", true, func(): show_boutique()))
		h.add_child(big_button("Acheter · %s" % o.eur, true, func(): main.real_buy(o.id), GOLD, true))
	, 620, 380)
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
	var bought: bool = o.get("once", false) and Game.S.get(o.id, false)
	var txt := ""
	if o.has("eur"): txt = "Déjà acheté" if bought else o.eur
	else: txt = "%s  %d" % ["♛", int(o.cr)]
	var ok: bool = not bought and (o.has("eur") or Game.crowns() >= int(o.cr))
	var b := big_button(txt if o.has("eur") else "Acheter · %d couronnes" % int(o.cr), not bought, func(): main.shop_claim(o.id), GOLD, ok)
	if not o.has("eur") and not ok: b.add_theme_color_override("font_color", Color("#ff9a8a"))
	b.custom_minimum_size = Vector2(0, 46); b.add_theme_font_size_override("font_size", 19); v.add_child(b)
	return card

func show_boutique(tab := "") -> void:
	if tab != "": shop_tab = tab
	open_panel("Boutique royale", func(body: VBoxContainer):
		cur_panel = "boutique"
		var ban := PanelContainer.new(); ban.add_theme_stylebox_override("panel", flat(Color(0.32, 0.16, 0.04, 0.96), 14, Color("#ffcf5a"), 2, Vector4(16, 8, 16, 8))); body.add_child(ban)
		var prem := ("[color=#ffcf5a]Premium : %s[/color]" % Game.dur_txt(Game.premium_left())) if Game.is_premium() else "[color=#a8b4bc]Premium inactif[/color]"
		var bst := ("   ·   [color=#7dff8a]Boost XP ×2 : %s[/color]" % Game.dur_txt(Game.boost_left())) if Game.boost_left() > 0 else ""
		ban.add_child(rich("[center][img=28x28]res://ui/crown.png[/img] [b][color=#ffe39a]%d couronnes[/color][/b]   ·   [color=#ffd86b]argent : %s[/color]   ·   %s%s[/center]" % [Game.crowns(), Game.fmt(Game.S.silver), prem, bst], 18))
		var tabs := HFlowContainer.new(); tabs.add_theme_constant_override("h_separation", 6); tabs.add_theme_constant_override("v_separation", 6); body.add_child(tabs)
		for t in SHOP_TABS: _chip(tabs, t[1], shop_tab == t[0], func(): show_boutique(t[0]))
		var list: Array = []
		for o in OFFERS:
			if (shop_tab == "une" and o.get("hot", false)) or o.tab == shop_tab: list.append(o)
		var grid := GridContainer.new(); grid.columns = 2 if shop_tab == "une" else 3; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12); body.add_child(grid)
		for o in list: grid.add_child(_offer_card(o, shop_tab == "une"))
		if shop_tab in ["couronnes", "une"]:
			body.add_child(rich("[color=#8a949c]Les couronnes se gagnent aussi en jouant : connexion quotidienne, quêtes du jour, classement. Achats en euros : [b]simulés[/b] dans cette version de test (aucun paiement réel) — le vrai paiement passera par Google Play.[/color]", 14))
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
	# bulle façon manga : cadre blanc épais, nom en cartouche, visage d'humeur
	var pc := PanelContainer.new(); pc.add_theme_stylebox_override("panel", flat(Color("#fffcf2"), 14, Color("#15110c"), 5, Vector4(26, 14, 26, 16), 12))
	pc.custom_minimum_size = Vector2(w, 0); root.add_child(pc); panel = pc
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); pc.add_child(v)
	var hdr := HBoxContainer.new(); hdr.add_theme_constant_override("separation", 10); v.add_child(hdr)
	var mood: String = main.npc_mood(npc) if main.has_method("npc_mood") else "neutre"
	var fi := TextureRect.new(); fi.texture = T("mood_" + mood); fi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fi.custom_minimum_size = Vector2(40, 40); fi.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hdr.add_child(fi)
	var tag := PanelContainer.new(); tag.add_theme_stylebox_override("panel", flat(Color("#15110c"), 6, Color(0, 0, 0, 0), 0, Vector4(12, 2, 12, 4)))
	var nl := _label(npc.nm, 24, Color("#fff3d6")); nl.add_theme_font_override("font", f_title); nl.add_theme_constant_override("outline_size", 0); tag.add_child(nl); hdr.add_child(tag)
	hdr.add_child(_ink(npc.role, 16, INK_SOFT, true))
	var tx := rich(ink_bb(text), 19); tx.add_theme_color_override("default_color", INK); tx.custom_minimum_size = Vector2(w - 60, 0); v.add_child(tx)
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

var auto_btn: Button
# réglages de la chasse automatique : quoi récolter, quels tiers, combattre ou non
func show_auto() -> void:
	var C: Dictionary = main.auto_cfg()
	open_panel("Chasse automatique", func(body: Control):
		body.add_child(rich("Choisis ce que ton héros fait tout seul. Il passe par les ponts et contourne falaises et maisons.", 17))
		var r1 := HFlowContainer.new(); r1.add_theme_constant_override("h_separation", 8); r1.add_theme_constant_override("v_separation", 8); body.add_child(r1)
		for k in [["fight", "Combattre les monstres"], ["gather", "Récolter"]]:
			_chip(r1, ("✔ " if C.get(k[0], true) else "✘ ") + k[1], bool(C.get(k[0], true)), func(): C[k[0]] = not bool(C.get(k[0], true)); Game.save(); show_auto())
		body.add_child(rich("[b]Ressources[/b]", 18))
		var r2 := HFlowContainer.new(); r2.add_theme_constant_override("h_separation", 8); r2.add_theme_constant_override("v_separation", 8); body.add_child(r2)
		for k in [["wood", "Bois"], ["ore", "Minerai"], ["fiber", "Fibre"]]:
			_chip(r2, ("✔ " if C.get(k[0], true) else "✘ ") + k[1], bool(C.get(k[0], true)), func(): C[k[0]] = not bool(C.get(k[0], true)); Game.save(); show_auto())
		body.add_child(rich("[b]Tiers à récolter[/b] [color=#a8b4bc](touche pour cocher / décocher)[/color]", 18))
		var r3 := HFlowContainer.new(); r3.add_theme_constant_override("h_separation", 8); r3.add_theme_constant_override("v_separation", 8); body.add_child(r3)
		var tiers: Array = C.get("tiers", [1, 2, 3, 4, 5])
		for t in range(1, 6):
			var on: bool = t in tiers or float(t) in tiers
			_chip(r3, ("✔ T%d" if on else "T%d") % t, on, func():
				var arr: Array = []
				for x in tiers: arr.append(int(x))
				if t in arr: arr.erase(t)
				else: arr.append(t)
				arr.sort(); C["tiers"] = arr; Game.save(); show_auto())
		var on2: bool = main.auto_on
		var bb := big_button("ARRÊTER" if on2 else "DÉMARRER", true, func(): close_panel(); main.toggle_auto(), Color("#ff9a8a") if on2 else Color("#9be86a"), true)
		bb.custom_minimum_size = Vector2(260, 60); body.add_child(bb)
		, 760)

func refresh_auto() -> void:
	if auto_btn == null: return
	auto_btn.visible = bool(Game.S.get("auto_owned", false))
	var on: bool = main.auto_on
	auto_btn.text = "AUTO ●" if on else "AUTO"
	var st := flat(Color("#2f7a3a") if on else Color(0.05, 0.07, 0.1, 0.8), 26, Color("#7dff8a") if on else Color(0.95, 0.78, 0.45, 0.6), 2, Vector4(10, 4, 10, 4))
	for k in ["normal", "hover", "pressed"]: auto_btn.add_theme_stylebox_override(k, st)
	auto_btn.add_theme_color_override("font_color", Color.WHITE if on else GOLD)


# ================= SOCIAL : chat, fiche joueur, guilde =================
var chat_box: Button
var chat_lbl: RichTextLabel
var quest_box: Control
var tap_from := Vector2.ZERO
var tap_t := 0
var chat_tab := "monde"
var chat_to := ""
const CH_COL := {"monde": "#e8e2d0", "guilde": "#7dffb0", "prive": "#ff9be0", "systeme": "#ffd27a"}

func _place_chat() -> void:
	if chat_box == null: return
	var y := (quest_box.position.y + quest_box.size.y + 8.0) if quest_box and quest_box.visible else 100.0
	chat_box.position = Vector2(12, y)

func _fmt_line(l: Dictionary) -> String:
	var c: String = CH_COL.get(l.ch, "#ffffff")
	match l.ch:
		"systeme": return "[color=%s]%s[/color]" % [c, l.text]
		"prive":
			if l.from == "Toi": return "[color=%s][b]→ %s[/b] : %s[/color]" % [c, l.to, l.text]
			return "[color=%s][b]%s[/b] te chuchote : %s[/color]" % [c, l.from, l.text]
		"guilde": return "[color=%s][Guilde] [b]%s[/b] : %s[/color]" % [c, l.from, l.text]
	return "[color=#9fd4ff][b]%s[/b][/color] [color=%s]%s[/color]" % [l.from, c, l.text]

func refresh_chat() -> void:
	if chat_lbl == null or main.social == null: return
	var L: Array = main.social.lines
	var out := []
	for i in range(max(0, L.size() - 1), L.size()): out.append("[img=14x14]res://ui/it_quest.png[/img] " + _fmt_line(L[i]))
	chat_lbl.text = "\n".join(out)
	_place_chat()
	if cur_panel == "chat" and panel_open: _refresh_chat_panel()

var chat_log_lbl: RichTextLabel
var chat_scroll: ScrollContainer
func _refresh_chat_panel() -> void:
	if chat_log_lbl == null or not is_instance_valid(chat_log_lbl): return
	var L: Array = main.social.lines
	var out := []
	for l in L:
		var ok: bool = l.ch == "systeme" or (chat_tab == "monde" and l.ch in ["monde", "guilde", "prive"]) or l.ch == chat_tab
		if chat_tab == "prive" and chat_to != "" and l.ch == "prive" and not (l.from.ends_with(chat_to) or l.to == chat_to or l.to.ends_with(chat_to)): ok = false
		if ok: out.append(_fmt_line(l))
	chat_log_lbl.text = "\n".join(out.slice(max(0, out.size() - 40)))
	(func(): if is_instance_valid(chat_scroll): chat_scroll.scroll_vertical = 1000000).call_deferred()

func show_chat(tab := "", to := "") -> void:
	if tab != "": chat_tab = tab
	if to != "": chat_to = to
	main.social.unread = 0
	var S: Social = main.social
	open_panel("Discussion", func(body: Control):
		var tb := HBoxContainer.new(); tb.add_theme_constant_override("separation", 8); body.add_child(tb)
		for t in [["monde", "Monde"], ["guilde", "Guilde"], ["prive", "Privé"], ["amis", "Amis & groupe"]]:
			_tab_btn(tb, t[1], chat_tab == t[0], func(): chat_tab = t[0]; show_chat())
		if chat_tab == "guilde" and not S.in_guild():
			_guild_create(body); return
		if chat_tab == "amis":
			_friends_tab(body); return
		if chat_tab == "guilde":
			var g: Dictionary = Game.S.guild
			body.add_child(rich("[b][color=#7dffb0]%s [%s][/color][/b] · %d membre(s) · bonus d'argent [b]+%d %%[/b]" % [g.name, g.tag, g.members.size() + 1, int(S.guild_bonus() * 100)], 18))
			var mf := HFlowContainer.new(); mf.add_theme_constant_override("h_separation", 6); mf.add_theme_constant_override("v_separation", 6); body.add_child(mf)
			for n in g.members:
				var on := S.bot_by_name(n) != null
				_chip(mf, ("● " if on else "○ ") + n, false, func(): show_member(n))
			var lv := big_button("Quitter la guilde", true, func(): S.leave_guild(); show_chat("monde"), Color("#ff9a8a")); lv.custom_minimum_size = Vector2(200, 44); body.add_child(lv)
		if chat_tab == "prive":
			var pf := HFlowContainer.new(); pf.add_theme_constant_override("h_separation", 6); pf.add_theme_constant_override("v_separation", 6); body.add_child(pf)
			pf.add_child(_label("À :", 16, SOFT))
			for b in S.alive_bots():
				_chip(pf, b.nm, chat_to == b.nm, func(): chat_to = b.nm; show_chat())
		chat_scroll = ScrollContainer.new(); chat_scroll.custom_minimum_size = Vector2(0, 230); chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; body.add_child(chat_scroll)
		chat_log_lbl = rich("", 17); chat_scroll.add_child(chat_log_lbl)
		_refresh_chat_panel()
		var ih := HBoxContainer.new(); ih.add_theme_constant_override("separation", 8); body.add_child(ih)
		var le := LineEdit.new(); le.placeholder_text = {"monde": "Écrire à tout le monde…", "guilde": "Écrire à la guilde…", "prive": "Chuchoter à %s…" % chat_to if chat_to != "" else "Choisis un joueur ci-dessus"}.get(chat_tab, "")
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL; le.custom_minimum_size = Vector2(0, 50); le.add_theme_font_size_override("font_size", 19); le.max_length = 120
		ih.add_child(le)
		var send := func():
			S.say(chat_tab, le.text, chat_to); le.text = ""
		le.text_submitted.connect(func(_t): send.call())
		var bs := big_button("Envoyer", true, send, GOLD, true); bs.custom_minimum_size = Vector2(140, 50); ih.add_child(bs)
		var qf := HFlowContainer.new(); qf.add_theme_constant_override("h_separation", 6); qf.add_theme_constant_override("v_separation", 6); body.add_child(qf)
		for q in ["slt !", "gg", "qq1 donjon ?", "merci", "on farm ensemble ?", "vends du bois", "lol"]:
			_chip(qf, q, false, func(): S.say(chat_tab, q, chat_to))
		, 900)
	cur_panel = "chat"

func _guild_create(body: Control) -> void:
	body.add_child(rich("[b]Fonder une guilde[/b]\nUne guilde, c'est ta bande : un canal de discussion à part, un blason au-dessus de ta tête et [b]+1 %% d'argent gagné par membre[/b] (jusqu'à +10 %%). Invite des joueurs depuis leur fiche (touche-les à l'écran).\nCoût : [color=#ffd86b]%s[/color] argent." % Game.fmt(Social.GUILD_COST), 17))
	var nm := LineEdit.new(); nm.placeholder_text = "Nom de la guilde (ex : Les Loups du Var)"; nm.custom_minimum_size = Vector2(0, 50); nm.max_length = 22; nm.add_theme_font_size_override("font_size", 19); body.add_child(nm)
	var tg := LineEdit.new(); tg.placeholder_text = "Blason, 2 à 4 lettres (ex : LDV)"; tg.custom_minimum_size = Vector2(0, 50); tg.max_length = 4; tg.add_theme_font_size_override("font_size", 19); body.add_child(tg)
	var err := rich("", 16); body.add_child(err)
	body.add_child(big_button("Fonder la guilde", true, func():
		var e: String = main.social.create_guild(nm.text, tg.text)
		if e != "": err.text = "[color=#ff8a7a]%s[/color]" % e; Game.play("error")
		else: Game.play("level"); show_chat("guilde"), GOLD, true))

func _friends_tab(body: Control) -> void:
	var S: Social = main.social
	body.add_child(rich("[b]Ton groupe[/b] (%d / %d)" % [S.party.size(), Social.GROUP_MAX], 18))
	if S.party.is_empty(): body.add_child(rich("[color=#a8b4bc]Personne pour l'instant : touche un joueur et invite-le. Il te suivra et combattra avec toi.[/color]", 16))
	for b in S.party:
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); body.add_child(hb)
		hb.add_child(rich("[color=#7dffb0]%s[/color] · T%d · PI %d" % [b.display_name(), b.tier, b.pwr], 17))
		var bb := big_button("Renvoyer", true, func(): S.leave_group(b); show_chat("amis")); bb.custom_minimum_size = Vector2(140, 44); hb.add_child(bb)
	body.add_child(rich("[b]Amis[/b]", 18))
	if Game.S.friends.is_empty(): body.add_child(rich("[color=#a8b4bc]Ajoute des amis depuis leur fiche pour les retrouver ici.[/color]", 16))
	var ff := HFlowContainer.new(); ff.add_theme_constant_override("h_separation", 6); ff.add_theme_constant_override("v_separation", 6); body.add_child(ff)
	for n in Game.S.friends:
		var on := S.bot_by_name(n) != null
		_chip(ff, ("● " if on else "○ ") + str(n), false, func(): show_member(n))
	body.add_child(rich("[color=#a8b4bc]● connecté sur cette carte · ○ ailleurs dans le royaume[/color]", 14))

func show_member(n: String) -> void:
	var b: Bot = main.social.bot_by_name(n)
	if b: show_player_card(b)
	else: toast("%s n'est pas sur cette carte en ce moment" % n, Color("#a8b4bc"))

func show_player_card(b: Bot) -> void:
	var S: Social = main.social
	open_panel("Joueur", func(body: Control):
		var hh := HBoxContainer.new(); hh.add_theme_constant_override("separation", 14); body.add_child(hh)
		var pf := PanelContainer.new(); pf.add_theme_stylebox_override("panel", flat(Color("#2c2620"), 16, Game.TIER_COL[b.tier], 3, Vector4(4, 4, 4, 4))); pf.custom_minimum_size = Vector2(110, 130); hh.add_child(pf)
		var pt := TextureRect.new(); pt.texture = main.icons.char_icon(b.model); pt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; pf.add_child(pt)
		var col := "#ff8a5a" if b.hostile else ("#7dffb0" if b.party else "#9fd4ff")
		var state := "Joueur JcJ — peut t'attaquer hors des villes" if b.hostile else ("Dans ton groupe" if b.party else "Joueur pacifique")
		var info := rich("[b][font_size=26]%s[/font_size][/b]\n[color=%s]%s[/color]\n%s · [color=#%s]Tier %d[/color] · Puissance [b]%d[/b]%s" % [b.display_name(), col, state, {"epee": "Épéiste", "hache": "Hache", "baton": "Mage"}[b.wk], Game.TIER_COL[b.tier].to_html(false), b.tier, b.pwr, "  · [color=#ffd27a]★ Ami[/color]" if S.is_friend(b.nm) else ""], 18)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hh.add_child(info)
		var you := Game.power()
		var cmp := "[color=#7dffb0]plus faible que toi[/color]" if b.pwr < you * 0.9 else ("[color=#ff8a7a]plus fort que toi[/color]" if b.pwr > you * 1.1 else "[color=#ffd27a]à ta hauteur[/color]")
		body.add_child(rich("Vie [b]%d[/b] · Dégâts [b]%d[/b] · Armure [b]−%d %%[/b] · Monstres tués [b]%d[/b]\nTa puissance : %d → ce joueur est %s." % [int(b.max_hp), int(b.dmg()), int(b.armor_red() * 100), b.kills, you, cmp], 17))
		var bf := HFlowContainer.new(); bf.add_theme_constant_override("h_separation", 8); bf.add_theme_constant_override("v_separation", 8); body.add_child(bf)
		var add := func(t: String, cb: Callable, hl := false) -> void:
			var bt := big_button(t, true, cb, GOLD, hl); bt.custom_minimum_size = Vector2(196, 52); bf.add_child(bt)
		add.call("Chuchoter", func(): show_chat("prive", b.nm), true)
		if b.party: add.call("Renvoyer du groupe", func(): S.leave_group(b); close_panel())
		else: add.call("Inviter au groupe", func(): S.invite_group(b); close_panel())
		add.call("Défier en duel", func(): close_panel(); S.ask_duel(b))
		add.call("Retirer des amis" if S.is_friend(b.nm) else "Ajouter en ami", func(): S.toggle_friend(b.nm); show_player_card(b))
		if S.in_guild():
			if b.nm in Game.S.guild.members: add.call("Exclure de la guilde", func(): S.kick_guild(b.nm); show_player_card(b))
			else: add.call("Inviter dans ma guilde", func(): S.invite_guild(b); close_panel())
		else: add.call("Fonder une guilde…", func(): show_chat("guilde"))
		body.add_child(rich("[color=#a8b4bc]Les duels sont amicaux : on s'arrête à 1 PV, rien n'est volé. Le gagnant empoche une prime.[/color]", 14))
		, 760)
	cur_panel = "player"

func _draw_daily_rank(c: CanvasItem, pulse: float) -> void:
	var dc: Vector2 = buttons.daily.rect.get_center()
	var nd: int = Game.dq_ready() + (1 if Game.login_can_claim() else 0) + (1 if Game.exped_ready() else 0)
	_glass(c, dc, 26, Color(1.0, 0.85, 0.3, pulse) if nd > 0 else Color(0.95, 0.78, 0.45, 0.6))
	_texq(T("it_quest"), Rect2(dc - Vector2(18, 19), Vector2(36, 36)))
	if nd > 0: _disc(dc + Vector2(22, -22), 11, Color("#ff3b2f")); _text(c, str(nd), dc + Vector2(22, -17), 14, Color.WHITE, true, f_title)
	var rc: Vector2 = buttons.rank.rect.get_center()
	_glass(c, rc, 26, Color(0.95, 0.78, 0.45, 0.6))
	_texq(T("it_trophy"), Rect2(rc - Vector2(18, 19), Vector2(36, 36)))
