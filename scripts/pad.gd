class_name Pad extends Control
## Commandes tactiles multipoint : joystick à gauche, attaque + 4 compétences + saut/esquive à droite.
var main
var stick := Vector2.ZERO
var labels := ["S1","S2","S3","S4"]
var cd := [0.0, 0.0, 0.0, 0.0]
var cd_max := [1.0, 1.0, 1.0, 1.0]
var chan := 0.0
var hp := 1.0
var posture := 1.0
var counter := false
var boss = null
var blocked_rect := Rect2()
var minimap_rect := Rect2()
var _free := {}   # doigts libres (ni joystick ni bouton) -> position, pour pincer
var _pinch_d := 0.0
var _jt := -1
var _jc := Vector2.ZERO
var _held := {}
const R := 110.0
func _btns() -> Array:
	var s := size
	return [["atk", s + Vector2(-140, -140), 78, "ATTAQUE"], ["s0", s + Vector2(-305, -95), 52, labels[0]], ["s1", s + Vector2(-290, -238), 52, labels[1]],
		["s2", s + Vector2(-178, -330), 52, labels[2]], ["s3", s + Vector2(-58, -318), 52, labels[3]],
		["jump", s + Vector2(-435, -62), 42, "Saut"], ["dodge", s + Vector2(-450, -180), 42, "Esquive"], ["block", s + Vector2(-420, -300), 42, "Parade"]]
func _ready() -> void: mouse_filter = MOUSE_FILTER_IGNORE
func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if blocked_rect.has_point(ev.position): return
			for b in _btns():
				if ev.position.distance_to(b[1]) < b[2] + 12:
					_held[ev.index] = b[0]; _press(b[0]); return
			if ev.position.x < size.x * 0.5 and _jt < 0:
				_jt = ev.index; _jc = ev.position
			else:
				_free[ev.index] = ev.position; _pinch_d = 0.0
		else:
			if ev.index == _jt: _jt = -1; stick = Vector2.ZERO
			if _held.get(ev.index, "") == "block": main.player.block(false)
			_held.erase(ev.index); _free.erase(ev.index); _pinch_d = 0.0
	elif ev is InputEventScreenDrag:
		if ev.index == _jt: stick = ((ev.position - _jc) / R).limit_length(1.0)
		elif _free.has(ev.index):
			_free[ev.index] = ev.position
			if _free.size() >= 2:
				var v: Array = _free.values()
				var d: float = v[0].distance_to(v[1])
				if _pinch_d > 0: main.cam_dist = clamp(main.cam_dist * _pinch_d / max(d, 1.0), 5.0, 26.0)
				_pinch_d = d
func _press(b: String) -> void:
	var p: Actor = main.player
	match b:
		"atk": p.attack()
		"jump": p.jump()
		"dodge": p.dodge()
		"block": p.block(true)
		_: main.K.cast(int(b.substr(1)))
func _draw() -> void:
	var f := get_theme_default_font()
	if _jt >= 0:
		draw_circle(_jc, R, Color(0, 0, 0, 0.28)); draw_arc(_jc, R, 0, TAU, 48, Color(1, 0.85, 0.4, 0.6), 3)
		draw_circle(_jc + stick * R, 42, Color(1, 0.85, 0.4, 0.75))
	else:
		var c := Vector2(170, size.y - 170)
		draw_arc(c, R, 0, TAU, 48, Color(1, 1, 1, 0.25), 3); draw_circle(c, 30, Color(1, 1, 1, 0.15))
	for b in _btns():
		var on: bool = _held.values().has(b[0])
		var glow: bool = b[0] == "atk" and counter
		draw_circle(b[1], b[2], Color(0.95, 0.65, 0.2, 0.85) if on or glow else Color(0.08, 0.07, 0.1, 0.62))
		if glow: draw_arc(b[1], b[2] + 8 + sin(Time.get_ticks_msec() * 0.015) * 4, 0, TAU, 48, Color(1, 0.9, 0.4), 5)
		var k := -1
		if b[0].begins_with("s"): k = int(b[0].substr(1))
		if k >= 0 and cd[k] > 0:
			var r: float = cd[k] / max(cd_max[k], 0.01)
			draw_colored_polygon(_pie(b[1], b[2], r), Color(0, 0, 0, 0.6))
		draw_arc(b[1], b[2], 0, TAU, 48, Color(1, 0.82, 0.35) if k < 0 or cd[k] <= 0 else Color(0.5, 0.45, 0.4), 3)
		var fs := 22 if b[2] > 60 else 15
		var txt: String = b[3] if k < 0 or cd[k] <= 0 else "%d" % ceil(cd[k])
		if b[0] == "atk" and counter: txt = "CONTRE !"
		if k >= 0 and cd[k] > 0: fs = 26
		_text(f, b[1], txt, fs, b[2] * 1.9)
	# barre de vie du joueur
	var hr := Rect2(16, 16, 300, 22)
	draw_rect(hr, Color(0, 0, 0, 0.6)); draw_rect(Rect2(hr.position, Vector2(hr.size.x * clamp(hp, 0, 1), hr.size.y)), Color(0.85, 0.15, 0.15) if hp < 0.3 else Color(0.25, 0.8, 0.3))
	draw_rect(hr, Color(1, 0.82, 0.35), false, 2)
	var pr := Rect2(16, 42, 200, 10)
	draw_rect(pr, Color(0, 0, 0, 0.6)); draw_rect(Rect2(pr.position, Vector2(pr.size.x * clamp(posture, 0, 1), pr.size.y)), Color(0.95, 0.8, 0.3))
	if boss:
		var br := Rect2(size.x * 0.5 - 300, 70, 600, 20)
		draw_rect(br, Color(0, 0, 0, 0.65)); draw_rect(Rect2(br.position, Vector2(br.size.x * boss.hp / boss.hp_max, br.size.y)), Color(0.6, 0.2, 0.75))
		draw_rect(br, Color(1, 0.82, 0.35), false, 2)
		_text(f, Vector2(size.x * 0.5, 54), boss.display_name + ("  — BOUCLIER" if boss.shield else "") + "  (phase %d)" % boss.phase, 20, 600)
	if chan > 0:
		var r := Rect2(size.x * 0.5 - 180, size.y - 120, 360, 22)
		draw_rect(r, Color(0, 0, 0, 0.6)); draw_rect(Rect2(r.position, Vector2(r.size.x * chan, r.size.y)), Color(0.85, 0.1, 0.2))
		draw_rect(r, Color(1, 0.8, 0.4), false, 2)
		_text(f, r.get_center() - Vector2(0, 30), "Étreinte — ne bouge pas", 18, 400)
func _text(f: Font, c: Vector2, t: String, fs: int, maxw: float) -> void:
	while fs > 10 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw: fs -= 1
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := c + Vector2(-w / 2, fs * 0.35)
	draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
func _pie(c: Vector2, r: float, frac: float) -> PackedVector2Array:
	var pts := PackedVector2Array([c])
	var n := 24
	for i in n + 1: pts.append(c + Vector2(0, -r).rotated(TAU * frac * i / n))
	return pts
