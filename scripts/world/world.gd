extends Node3D
## Scène principale du royaume.

var player: Player
var rig: CameraRig
var _inside := false

var _loading: CanvasLayer
var _bar: ProgressBar
var _step_label: Label

func _ready() -> void:
	_show_loading()
	var t0 := Time.get_ticks_msec()
	var steps := [
		["Le ciel et la lumière", func(): Ambiance.setup(self)],
		["Les terres et les rivières", func(): Terrain.build(self)],
		["Les routes et les ponts", func(): Roads.build(self)],
		["Le château", func(): Castle.build(self)],
		["Le bourg", func(): Town.build(self)],
		["Les champs", func(): Fields.build(self)],
		["La ferme, la mine et le portail", func(): Places.build(self)],
		["Les forêts", func(): Vegetation.build(self)],
	]
	for i in steps.size():
		_step_label.text = steps[i][0] + "…"
		_bar.value = float(i) / steps.size() * 100.0
		await get_tree().process_frame
		await get_tree().process_frame
		steps[i][1].call()
	print("monde construit en ", Time.get_ticks_msec() - t0, " ms")
	_bar.value = 100.0
	_spawn()
	await get_tree().process_frame
	_loading.queue_free()

func _show_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 10
	add_child(_loading)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(700, 300)
	box.position = Vector2(-350, -150)
	bg.add_child(box)
	var title := Label.new()
	title.text = "ROYAUME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.05))
	title.add_theme_constant_override("outline_size", 18)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Les terres du seigneur"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	box.add_child(sp)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(600, 22)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.98, 0.78, 0.35)
	fill.set_corner_radius_all(10)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(10)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", 24)
	_step_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.86))
	box.add_child(_step_label)

func _spawn() -> void:
	player = Player.new()
	player.name = "Joueur"
	var start := Vector2(0, -60)
	var args := OS.get_cmdline_user_args()
	player.position = Vector3(start.x, Layout.height(start.x, start.y) + 0.3, start.y)
	player.rotation.y = PI   # regarde vers le château (nord)
	add_child(player)
	rig = CameraRig.new()
	rig.target = player
	add_child(rig)
	var ui := CanvasLayer.new()
	add_child(ui)
	var tc := TouchControls.new()
	tc.player = player
	tc.rig = rig
	ui.add_child(tc)
	var zone := find_child("ZoneDonjon", true, false) as Area3D
	if zone:
		zone.body_entered.connect(func(b): if b == player: _set_inside(true))
		zone.body_exited.connect(func(b): if b == player: _set_inside(false))
	if args.size() > 0 and args[0] == "--tour":
		var tour = load("res://scripts/tools/tour.gd").new()
		tour.world = self
		add_child(tour)

## Qualité adaptative : si le téléphone peine (< 26 FPS pendant 4 s), on allège par paliers.
var quality := 0
var _q_acc := 0.0
var _q_low := 0.0

func _process(delta: float) -> void:
	if player == null or "--tour" in OS.get_cmdline_user_args():
		return
	_q_acc += delta
	if _q_acc < 1.0:
		return
	_q_acc = 0.0
	var fps := Engine.get_frames_per_second()
	_q_low = _q_low + 1.0 if fps < 26 else 0.0
	if _q_low >= 4.0 and quality < 3:
		_q_low = 0.0
		quality += 1
		_apply_quality()

func _apply_quality() -> void:
	var sun := find_child("Soleil", false, false) as DirectionalLight3D
	var we: WorldEnvironment
	for c in get_children():
		if c is WorldEnvironment:
			we = c
	match quality:
		1:
			if sun: sun.directional_shadow_max_distance = 40.0
			if we: we.environment.glow_enabled = false
		2:
			if sun: sun.shadow_enabled = false
		3:
			for n in find_child("Vegetation", true, false).get_children():
				n.visibility_range_end *= 0.6
	print("qualité réduite → niveau ", quality)

func _set_inside(v: bool) -> void:
	_inside = v
	rig.inside = v
	for l in Castle.interior_lights:
		l.visible = v
