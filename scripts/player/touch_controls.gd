class_name TouchControls
extends Control
## Commandes tactiles multipoint : joystick flottant à gauche, caméra à droite (glisser),
## pincement pour zoomer, et boutons d'action (maintenir « attaque » enchaîne le combo).
## PC : ZQSD/WASD, clic droit = caméra, molette = zoom, J = attaque, K = esquive, 1-4 = sorts, H/G = potions.

var player: Player
var rig: CameraRig
var hud: Hud
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _look := {}         # index -> dernière position
var _btn_touch := {}    # index -> bouton tenu
var _pinch_d := 0.0
var _hold_acc := 0.0
const R := 90.0

var _base: Panel
var _knob: Panel
var _fps: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base = _circle(R * 2, Color(1, 1, 1, 0.14))
	_knob = _circle(R * 0.9, Color(1, 1, 1, 0.42))
	_base.visible = false
	_knob.visible = false
	add_child(_base)
	add_child(_knob)
	_fps = Label.new()
	_fps.add_theme_font_size_override("font_size", 16)
	_fps.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_fps.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(_fps)

func _circle(d: float, col: Color) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(d / 2))
	sb.border_color = Color(1, 1, 1, 0.3)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(d, d)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

func _button_at(pos: Vector2) -> ActionButton:
	if hud == null:
		return null
	for b in hud.buttons():
		if b.hit(pos):
			return b
	return null

func _release_all() -> void:
	for k in _btn_touch:
		_btn_touch[k].held = false
	_btn_touch.clear()
	_stick_id = -1
	_stick_vec = Vector2.ZERO
	_base.visible = false
	_knob.visible = false
	_look.clear()

func _input(e: InputEvent) -> void:
	var w := get_viewport_rect().size.x
	# pendant un dialogue ou dans le bureau royal, l'interface reçoit les touchers, pas le personnage
	if Dialogue.active or KingdomUI.is_open():
		if _stick_id != -1 or not _btn_touch.is_empty():
			_release_all()
		if e is InputEventKey and e.pressed and not e.echo and Dialogue.active and Dialogue.inst:
			if e.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
				Dialogue.inst.advance()
			elif e.physical_keycode >= KEY_1 and e.physical_keycode <= KEY_5:
				Dialogue.inst.choose_visible(e.physical_keycode - KEY_1)
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			var b := _button_at(e.position)
			if b:
				_btn_touch[e.index] = b
				b.held = true
				b.pressed.emit()
				_hold_acc = 0.0
				return
			if e.position.x < w * 0.42 and _stick_id == -1:
				_stick_id = e.index
				_stick_origin = e.position
				_stick_vec = Vector2.ZERO
				_base.visible = true
				_knob.visible = true
				_base.position = _stick_origin - _base.size / 2
				_knob.position = _stick_origin - _knob.size / 2
			else:
				_look[e.index] = e.position
		else:
			if _btn_touch.has(e.index):
				_btn_touch[e.index].held = false
				_btn_touch.erase(e.index)
			if e.index == _stick_id:
				_stick_id = -1
				_stick_vec = Vector2.ZERO
				_base.visible = false
				_knob.visible = false
			_look.erase(e.index)
			_pinch_d = 0.0
	elif e is InputEventScreenDrag:
		if _btn_touch.has(e.index):
			return
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
	elif e is InputEventKey and e.pressed and not e.echo and player:
		match e.physical_keycode:
			KEY_J: player.combat.attack()
			KEY_K: player.combat.dodge()
			KEY_1: player.combat.cast(SpellDB.ORDER[0])
			KEY_2: player.combat.cast(SpellDB.ORDER[1])
			KEY_3: player.combat.cast(SpellDB.ORDER[2])
			KEY_4: player.combat.cast(SpellDB.ORDER[3])
			KEY_H: player.combat.drink("soin")
			KEY_G: player.combat.drink("mana")
			KEY_E:
				if hud and hud.btn_talk.visible:
					hud.btn_talk.pressed.emit()
			KEY_TAB:
				if hud and hud.btn_kingdom.visible:
					hud.btn_kingdom.pressed.emit()

func _process(delta: float) -> void:
	var k := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var v := _stick_vec
	if k.length() > 0:
		v = k.normalized()
	if player:
		if Dialogue.active or KingdomUI.is_open():
			v = Vector2.ZERO
		player.input_dir = v
		player.sprint = Input.is_physical_key_pressed(KEY_SHIFT)
		if rig:
			player.cam_yaw = rig.yaw
		# maintenir le bouton d'attaque enchaîne les coups
		if hud and hud.btn_attack.held:
			_hold_acc += delta
			if _hold_acc > 0.12:
				_hold_acc = 0.0
				player.combat.attack()
	var q := ""
	var w = get_tree().current_scene
	if w and "quality" in w and w.quality > 0:
		q = " · qualité -%d" % w.quality
	_fps.text = "%d FPS%s" % [Engine.get_frames_per_second(), q]
	_fps.position = Vector2(get_viewport_rect().size.x - 170, 8)
