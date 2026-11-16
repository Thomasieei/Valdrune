class_name Bench
extends Node
## Mesure des performances, sur le téléphone comme en CI.
## Un combat standard (4 ombres contre 8 monstres) est joué, puis chaque réglage est coupé
## l'un après l'autre : on voit ce qui coûte vraiment (ombres portées, lueur, particules,
## lumières, animations, barres de vie, résolution, monstres lointains).

const WARM := 45          # images ignorées après chaque changement
const MEASURE := 150      # images mesurées

var main
var results: Array = []
var spawned: Array = []
var panel: PanelContainer
var lbl: Label
var running := false
var grid: GridContainer

static func frame_stats() -> Dictionary:
	return {
		"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"dc": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"obj": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"prim": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}

func run(on_device: bool) -> void:
	if running:
		return
	running = true
	results.clear()
	_make_panel()
	_say("Préparation du combat de test…")
	var h: Hero = main.hero
	var keep_hp: float = h.max_hp
	var keep_cur: float = h.hp
	h.max_hp = 999999.0
	h.hp = 999999.0
	main.bench_running = true
	_spawn_fight()
	await _wait(60)
	await _measure("Normal")
	var moon: DirectionalLight3D = main.moon
	var had_shadow := moon.shadow_enabled
	moon.shadow_enabled = false
	await _measure("Sans ombres portées")
	moon.shadow_enabled = had_shadow
	var env: Environment = main.world_env.environment
	var had_glow := env.glow_enabled
	env.glow_enabled = false
	await _measure("Sans lueur (glow)")
	env.glow_enabled = had_glow
	FX.particles_on = false
	await _measure("Sans particules")
	FX.particles_on = true
	var lights := _all(main, "OmniLight3D")
	for l in lights:
		(l as Light3D).visible = false
	await _measure("Sans lumières ponctuelles")
	for l in lights:
		(l as Light3D).visible = true
	main.bars_hidden = true
	await _measure("Sans barres de vie / noms")
	main.bars_hidden = false
	var aps := _all(main, "AnimationPlayer")
	for a in aps:
		(a as AnimationPlayer).speed_scale = 0.0
	await _measure("Animations figées")
	for a in aps:
		(a as AnimationPlayer).speed_scale = 1.0
	var vp: Viewport = main.get_viewport()
	var sc: float = vp.scaling_3d_scale
	vp.scaling_3d_scale = 0.7
	await _measure("Résolution 3D 70 %")
	vp.scaling_3d_scale = sc
	var frozen: Array = []
	for m in main.mobs:
		var mm := m as Mob
		if mm.global_position.distance_to(h.global_position) > 30.0 and mm.process_mode != Node.PROCESS_MODE_DISABLED:
			mm.process_mode = Node.PROCESS_MODE_DISABLED
			frozen.append(mm)
	await _measure("Monstres lointains gelés (%d)" % frozen.size())
	for mm in frozen:
		if is_instance_valid(mm):
			(mm as Node).process_mode = Node.PROCESS_MODE_INHERIT
	_cleanup()
	h.max_hp = keep_hp
	h.hp = minf(keep_cur, keep_hp)
	main.bench_running = false
	_show(on_device)
	running = false

func _all(root: Node, cls: String) -> Array:
	return root.find_children("*", cls, true, false)

func _spawn_fight() -> void:
	var h: Hero = main.hero
	var fw: Vector3 = h.forward()
	var kinds := ["goblin", "goblin", "goblin", "orc", "shaman", "goblin", "orc", "shaman"]
	for i in kinds.size():
		var p: Vector3 = main.safe_point(h.global_position, h.global_position + fw * 7.0 + Vector3(randf_range(-4, 4), 0, randf_range(-3, 3)))
		var m: Mob = main.spawn_free_mob(kinds[i], p)
		m.max_hp = 999999.0
		m.hp = m.max_hp
		m.dmg = 0.0
		m.set_target(h)
		m.leash_r = 200.0
		spawned.append(m)
	# ombres de test si l'armée est vide
	if main.shadow_count() < 4:
		for i in 4 - main.shadow_count():
			var s: Mob = main.spawn_free_mob(["orc", "goblin", "shaman", "goblin"][i], main.safe_point(h.global_position, h.global_position - fw * 2.0 + Vector3(i - 1.5, 0, 0)))
			s.rise_as_shadow("")
			s.max_hp = 999999.0
			s.hp = s.max_hp
			spawned.append(s)

func _cleanup() -> void:
	for m in spawned:
		if is_instance_valid(m):
			main.mobs.erase(m)
			(m as Node).queue_free()
	spawned.clear()

func _wait(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame

func _measure(tag: String) -> void:
	_say("Mesure : %s" % tag)
	await _wait(WARM)
	var t0 := Time.get_ticks_usec()
	var last := t0
	var frames: Array = []
	var acc := {"proc": 0.0, "phys": 0.0, "dc": 0.0, "obj": 0.0, "prim": 0.0}
	for i in MEASURE:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		var s := frame_stats()
		for k in acc.keys():
			acc[k] = float(acc[k]) + float(s[k])
	frames.sort()
	var avg := float(Time.get_ticks_usec() - t0) / MEASURE / 1000.0
	var p95: float = frames[int(MEASURE * 0.95)]
	var r := {"tag": tag, "ms": avg, "p95": p95, "fps": 1000.0 / avg}
	for k in acc.keys():
		r[k] = float(acc[k]) / MEASURE
	results.append(r)
	print("BENCH %-34s fps=%5.1f ms=%6.1f p95=%6.1f proc=%5.1f phys=%5.1f dc=%4d obj=%4d prim=%7d" % [tag, r["fps"], avg, p95, r["proc"], r["phys"], int(r["dc"]), int(r["obj"]), int(r["prim"])])

func _make_panel() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", main._panel_style(Color(0.02, 0.03, 0.08, 0.93), Color(0.4, 0.9, 0.7)))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -560
	panel.offset_right = 560
	panel.offset_top = 70
	main.ui_layer.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 19)
	vb.add_child(lbl)
	grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 18)
	vb.add_child(grid)
	var close := Button.new()
	close.text = "Fermer"
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(func(): panel.queue_free())
	vb.add_child(close)

func _say(t: String) -> void:
	if lbl:
		lbl.text = "TEST DE PERFORMANCE — combat 4 ombres contre 8 monstres\n" + t

func _cell(t: String, col := Color(0.85, 0.9, 1.0)) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", col)
	grid.add_child(l)

func _show(_on_device: bool) -> void:
	var base: Dictionary = results[0]
	lbl.text = "TEST DE PERFORMANCE — fais une capture d'écran et envoie-la\nAppareil : %s  ·  %s" % [OS.get_model_name(), RenderingServer.get_video_adapter_name()]
	for h in ["Réglage", "FPS", "écart", "pire (ms)", "scripts (ms)", "physique (ms)", "appels / triangles"]:
		_cell(h, Color(0.5, 1.0, 0.8))
	for r in results:
		var gain := "réf."
		var col := Color(0.85, 0.9, 1.0)
		if r != base:
			var g := (float(r["fps"]) / float(base["fps"]) - 1.0) * 100.0
			gain = "%+d %%" % int(g)
			col = Color(0.5, 1.0, 0.55) if g > 8.0 else (Color(1, 0.6, 0.5) if g < -8.0 else col)
		_cell(str(r["tag"]))
		_cell("%.1f" % float(r["fps"]), col)
		_cell(gain, col)
		_cell("%.0f" % float(r["p95"]))
		_cell("%.1f" % float(r["proc"]))
		_cell("%.1f" % float(r["phys"]))
		_cell("%d / %dk" % [int(r["dc"]), int(r["prim"]) / 1000])
