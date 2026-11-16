class_name Pad extends Control
## Commandes tactiles multipoint : joystick à gauche, boutons d'action à droite.
var main
var stick := Vector2.ZERO
var labels := ["S1","S2","S3"]
var blocked_rect := Rect2()
var _jt := -1
var _jc := Vector2.ZERO
var _jp := Vector2.ZERO
var _held := {}   # touch index -> bouton
const R := 110.0
func _btns() -> Array:
	var s := size
	return [["atk", s + Vector2(-140, -140), 78, "ATTAQUE"], ["s1", s + Vector2(-300, -110), 50, labels[0]], ["s2", s + Vector2(-255, -250), 50, labels[1]],
		["s3", s + Vector2(-120, -300), 50, labels[2]], ["jump", s + Vector2(-420, -70), 44, "Saut"], ["dodge", s + Vector2(-430, -190), 44, "Esquive"],
		["block", s + Vector2(-60, -420), 44, "Parade"]]
func _ready() -> void: mouse_filter = MOUSE_FILTER_IGNORE
func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if ev.position.y < 72 or blocked_rect.has_point(ev.position): return
			for b in _btns():
				if ev.position.distance_to(b[1]) < b[2] + 14:
					_held[ev.index] = b[0]; _press(b[0], true); queue_redraw(); return
			if ev.position.x < size.x * 0.5 and _jt < 0:
				_jt = ev.index; _jc = ev.position; _jp = ev.position; queue_redraw()
		else:
			if ev.index == _jt: _jt = -1; stick = Vector2.ZERO; queue_redraw()
			if _held.has(ev.index): _press(_held[ev.index], false); _held.erase(ev.index); queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == _jt:
		_jp = ev.position
		var d: Vector2 = (_jp - _jc) / R
		stick = d.limit_length(1.0)
		queue_redraw()
func _press(b: String, on: bool) -> void:
	var p: Actor = main.player
	if b == "block": p.block(on); return
	if not on: return
	match b:
		"atk": p.attack()
		"s1": p.skill(1)
		"s2": p.skill(2)
		"s3": p.skill(3)
		"jump": p.jump()
		"dodge": p.dodge()
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
		draw_circle(b[1], b[2], Color(0.95, 0.65, 0.2, 0.85) if on else Color(0.08, 0.07, 0.1, 0.62))
		draw_arc(b[1], b[2], 0, TAU, 48, Color(1, 0.82, 0.35), 3)
		var fs := 22 if b[2] > 60 else 17
		var w := f.get_string_size(b[3], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string_outline(f, b[1] + Vector2(-w / 2, fs * 0.35), b[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
		draw_string(f, b[1] + Vector2(-w / 2, fs * 0.35), b[3], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
