class_name TouchControls
extends Control
## Joystick flottant à gauche, rotation de caméra à droite, pincement pour zoomer.
## Clavier/souris pour tester sur PC (ZQSD/WASD, Maj = sprint, clic droit = caméra, molette = zoom).

var player: Player
var rig: CameraRig
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look := {}         # index -> dernière position
var _pinch_d := 0.0
const R := 90.0

var _base: Panel
var _knob: Panel
var _fps: Label
var _sprint_btn: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_base = _circle(R * 2, Color(1, 1, 1, 0.16))
	_knob = _circle(R * 0.9, Color(1, 1, 1, 0.45))
	_base.visible = false
	_knob.visible = false
	add_child(_base)
	add_child(_knob)
	_fps = Label.new()
	_fps.position = Vector2(14, 10)
	_fps.add_theme_font_size_override("font_size", 18)
	_fps.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_fps.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(_fps)
	_sprint_btn = Button.new()
	_sprint_btn.text = "Courir"
	_sprint_btn.toggle_mode = true
	_sprint_btn.focus_mode = Control.FOCUS_NONE
	_sprint_btn.custom_minimum_size = Vector2(150, 70)
	_sprint_btn.add_theme_font_size_override("font_size", 24)
	_sprint_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_sprint_btn.position = Vector2(-190, -120)
	add_child(_sprint_btn)
	_sprint_btn.anchor_left = 1; _sprint_btn.anchor_right = 1; _sprint_btn.anchor_top = 1; _sprint_btn.anchor_bottom = 1
	_sprint_btn.offset_left = -190; _sprint_btn.offset_right = -40; _sprint_btn.offset_top = -120; _sprint_btn.offset_bottom = -50

func _circle(d: float, col: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(d / 2))
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _input(e: InputEvent) -> void:
	var w := get_viewport_rect().size.x
	if e is InputEventScreenTouch:
		if e.pressed:
			if e.position.x < w * 0.42 and _stick_id == -1:
				_stick_id = e.index
				_stick_origin = e.position
				_stick_vec = Vector2.ZERO
				_base.visible = true
				_knob.visible = true
				_base.position = _stick_origin - _base.size / 2
				_knob.position = _stick_origin - _knob.size / 2
			elif not _sprint_btn.get_global_rect().has_point(e.position):
				_look[e.index] = e.position
		else:
			if e.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
				_base.visible = false
				_knob.visible = false
			_look.erase(e.index)
			_pinch_d = 0.0
	elif e is InputEventScreenDrag:
		if e.index == _stick_id:
			var v: Vector2 = e.position - _stick_origin
			if v.length() > R:
				v = v.normalized() * R
			_stick_vec = v / R
			_knob.position = _stick_origin + v - _knob.size / 2
		elif _look.has(e.index):
			if _look.size() >= 2:
				var ks := _look.keys()
				_look[e.index] = e.position
				var d: float = (_look[ks[0]] as Vector2).distance_to(_look[ks[1]])
				if _pinch_d > 0.0 and rig:
					rig.zoom_by(_pinch_d / maxf(d, 1.0))
				_pinch_d = d
			else:
				if rig:
					rig.rotate_by(e.relative.x, e.relative.y)
				_look[e.index] = e.position
	elif e is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if rig:
			rig.rotate_by(e.relative.x, e.relative.y)
	elif e is InputEventMouseButton and e.pressed:
		if rig and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom_by(0.9)
		elif rig and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom_by(1.1)

func _process(_d: float) -> void:
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var v := _stick_vec
	if k.length() > 0:
		v = k.normalized()
	if player:
		player.input_dir = v
		player.sprint = _sprint_btn.button_pressed or Input.is_physical_key_pressed(KEY_SHIFT)
		if rig:
			player.cam_yaw = rig.yaw
	_fps.text = "%d FPS · %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1)]
