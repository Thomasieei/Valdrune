extends Node3D
## Scène principale du royaume.

var player: Player
var rig: CameraRig
var hud: Hud
var events: WorldEvents
var quests: Quests
var dlg: Dialogue
var kui: KingdomUI
var aui: ArcanesUI
var _arc_near := false
var story: Story
var _talking: Node3D
var _talk_acc := 0.0
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
		["Optimisation du décor", func(): _batch()],
	]
	for i in steps.size():
		_step_label.text = steps[i][0] + "…"
		_bar.value = float(i) / steps.size() * 100.0
		await get_tree().process_frame
		await get_tree().process_frame
		steps[i][1].call()
	print("monde construit en ", Time.get_ticks_msec() - t0, " ms")
	_step_label.text = "Préparation des effets visuels…"
	_bar.value = 95.0
	await _warmup()
	_bar.value = 100.0
	_spawn()
	_set_inside(false)
	await get_tree().process_frame
	_loading.queue_free()

## Préchauffage des shaders : on fait voir TOUT le monde (extérieur, intérieur éclairé, personnages)
## à une caméra cachée derrière l'écran de chargement, pour que les shaders soient compilés
## pendant le chargement et pas en pleine partie (c'était la cause des gros pics de ms).
func _warmup() -> void:
	var saved := {}
	for n in find_children("*", "GeometryInstance3D", true, false):
		saved[n] = [n.visibility_range_begin, n.visibility_range_end]
		n.visibility_range_begin = 0.0
		n.visibility_range_end = 0.0
	var cam := Camera3D.new()
	cam.far = 2000.0
	add_child(cam)
	cam.current = true
	var views := [
		[Vector3(0, 420, 120), Vector3(0, 0, -20)],
		[Vector3(0, Castle.FLOOR + 6.0, -131.0), Vector3(0, Castle.FLOOR + 2.0, -150.0)],
		[Vector3(14, Castle.FLOOR + 4.0, -131.0), Vector3(14, Castle.FLOOR, -150.0)],
		[Vector3(-14, Castle.FLOOR + 4.0, -131.0), Vector3(-14, Castle.FLOOR, -150.0)],
		[Vector3(0, 20, -40), Vector3(0, 12, -100)],
		[Vector3(80, 25, 30), Vector3(110, 3, -10)],
	]
	for l in Castle.interior_lights:
		l.visible = true
	# tous les effets de combat (sorts, impacts, zones d'attaque) compilés pendant le chargement :
	# sinon le premier lancer de chaque sort provoque un gel sur téléphone
	FX.root = self
	var fxp := Vector3(0, 80, 0)
	var dummy := Node3D.new()
	add_child(dummy)
	dummy.global_position = fxp
	FX.explosion(fxp, 3.0)
	FX.frost_nova(fxp + Vector3(3, 0, 0), 5.0)
	FX.shockwave(fxp + Vector3(-3, 0, 0), 4.0)
	FX.frost_mark(dummy, 1.5)
	FX.roots(dummy, 1.5)
	var sh := FX.shield(dummy)
	var fb := FX.fireball()
	dummy.add_child(fb)
	FX.charge_aura(dummy, Color(1, 0.6, 0.2))
	FX.power_burst(dummy, Color(0.6, 0.9, 1))
	FX.hit_spark(fxp)
	FX.slash(fxp, 0.0)
	FX.cast_glow(dummy, Color(1, 0.5, 0.2))
	FX.damage_number(fxp, "12", Color.WHITE)
	FX.bark(dummy, "…")
	# effets des pouvoirs (runes, halos, éclairs, débris, piliers, énergie, traces) : sinon gel au premier usage
	Magic.rune(fxp + Vector3(2, 0, 2), 1.5, Color(1, 0.8, 0.4), 1.0)
	Magic.halo(fxp, 2.0, Color(0.7, 0.5, 1.0), 0.5)
	Magic.sparks(fxp, Color(1, 0.9, 0.5), 8)
	Magic.debris(fxp, 6)
	Magic.burst(fxp, Color(0.8, 0.6, 1.0), 1.0, true)
	Magic.lightning(fxp, fxp + Vector3(0, 4, 0), Color(0.7, 0.85, 1.0))
	Magic.pillar(fxp + Vector3(-2, 0, 2), Color(1, 0.8, 0.4), 4.0, 0.6)
	Magic.trail(dummy, Color(0.75, 0.55, 1.0))
	FX._scorch_mark(fxp, 1.5)
	Juice.onde(fxp, Color(1, 0.8, 0.4), 2.0)
	Juice.lueur(fxp, Color(1, 0.6, 0.2), 1.5)
	Juice.arc(fxp, 0.0, 2.0, Color.WHITE)
	Juice.dust(fxp, 4)
	FX.impact_light(fxp, Color(1, 0.8, 0.4), 2.0, 4.0)
	var tele := Telegraph.spawn(self, fxp + Vector3(0, 0, 3), 0.0, "cercle", 1.5, 3.0)
	views.push_front([fxp + Vector3(0, 4, 12), fxp])
	for v in views:
		cam.position = v[0]
		cam.look_at(v[1])
		await get_tree().process_frame
		await get_tree().process_frame
	for n in saved:
		if is_instance_valid(n):
			n.visibility_range_begin = saved[n][0]
			n.visibility_range_end = saved[n][1]
	cam.queue_free()
	dummy.queue_free()
	if is_instance_valid(tele):
		tele.queue_free()

func _batch() -> void:
	for nm in ["Mobilier", "CourDecor", "BourgDecor", "LieuxDecor", "Potagers", "CampsDecor"]:
		var n := find_child(nm, true, false) as Node3D
		if n:
			Batcher.merge(n, nm != "Potagers")

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
	FX.root = self
	Sfx.setup(self)
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
	player.rig = rig
	Spawner.build(self)
	Camps.build(self)
	BanditVillage.build(self)
	Frontier.build(self)
	Interiors.build(self)
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	hud.bind(player)
	var tc := TouchControls.new()
	tc.player = player
	tc.rig = rig
	tc.hud = hud
	ui.add_child(tc)
	# dialogues (au-dessus du HUD) et bureau royal (au-dessus de tout)
	var dl := CanvasLayer.new()
	dl.layer = 2
	add_child(dl)
	dlg = Dialogue.new()
	dl.add_child(dlg)
	var kl := CanvasLayer.new()
	kl.layer = 3
	kl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(kl)
	kui = KingdomUI.new()
	kl.add_child(kui)
	aui = ArcanesUI.new()
	kl.add_child(aui)
	var cui := CommandUI.new()
	kl.add_child(cui)
	var gui := GestionUI.new()
	kl.add_child(gui)
	var mob := get_node_or_null("Mobilier") as Node3D
	ArcanesUI.build_chamber(mob if mob else self)
	Powers.spawn_props(self)
	hud.btn_talk.pressed.connect(_talk)
	hud.btn_kingdom.pressed.connect(func(): if not Dialogue.active: kui.open())
	dlg.finished.connect(func(a):
		if rig and not is_instance_valid(AuraGuard.inst.pinned if AuraGuard.inst else null):
			rig.cine_off()
		if a == "ouvrir_missions":
			kui.open("missions")
		if is_instance_valid(_talking) and _talking is Companion and Story.done():
			_talking.follow()
		_talking = null)
	Talk.setup(self)
	Justice.build_prison(self)
	quests = Quests.new()
	quests.name = "Quetes"
	add_child(quests)
	var dg := Dungeons.new()
	dg.name = "Donjons"
	add_child(dg)
	var wv := WorkersView.new()
	wv.name = "Ouvriers"
	add_child(wv)
	var cp := CampParley.new()
	cp.name = "Pourparlers"
	add_child(cp)
	var ag := AuraGuard.new()
	ag.name = "ParadeAura"
	add_child(ag)
	var mr := MissionReturn.new()
	mr.name = "RetourMission"
	add_child(mr)
	events = WorldEvents.new()
	events.name = "Evenements"
	add_child(events)
	var vie := Vie.new()
	vie.name = "Vie"
	vie.world = self
	add_child(vie)
	# plus aucun personnage coincé dans un mur ou un objet
	await get_tree().physics_frame
	Place.fix_all(get_tree())
	print("PNJ replacés hors du décor : ", Place.moved)
	var zone := find_child("ZoneDonjon", true, false) as Area3D
	if zone:
		zone.body_entered.connect(func(b): if b == player: _set_inside(true))
		zone.body_exited.connect(func(b): if b == player: _set_inside(false))
	var test_mode := args.size() > 0 and args[0] in ["--combat", "--tour"]
	if not test_mode:
		if args.size() > 0 and args[0] == "--story":
			GameState.get_inst().reset()
			Progression.get_inst().reset()
			Spawner.paused = true
		if args.size() > 0 and args[0] in ["--vie", "--pouvoirs", "--fx"]:
			GameState.get_inst().reset()
			Progression.get_inst().reset()
			GameState.get_inst().story = "libre"
			GameState.get_inst().titre = "Intendant de Valmont"
		story = Story.new()
		story.name = "Histoire"
		add_child(story)
		story.setup(self, player, hud, dlg)
		player.cbt.died.connect(func(_s): story.on_player_died())
	if args.size() > 0 and args[0] == "--pouvoirs":
		var pt = load("res://scripts/tools/powers_test.gd").new()
		pt.world = self
		add_child(pt)
	if args.size() > 0 and args[0] == "--perf":
		var pp = load("res://scripts/tools/perf_probe.gd").new()
		pp.world = self
		add_child(pp)
	if args.size() > 0 and args[0] == "--fx":
		var fx_t = load("res://scripts/tools/fx_test.gd").new()
		fx_t.world = self
		add_child(fx_t)
	if args.size() > 0 and args[0] == "--vie":
		var lt = load("res://scripts/tools/life_test.gd").new()
		lt.world = self
		add_child(lt)
	if args.size() > 0 and args[0] == "--story":
		var stt = load("res://scripts/tools/story_test.gd").new()
		stt.world = self
		add_child(stt)
	if args.size() > 0 and args[0] == "--combat":
		var ct = load("res://scripts/tools/combat_test.gd").new()
		ct.world = self
		add_child(ct)
	if args.size() > 0 and args[0] == "--tour":
		var tour = load("res://scripts/tools/tour.gd").new()
		tour.world = self
		add_child(tour)

## Qualité adaptative : si le téléphone peine (< 28 FPS pendant 3 s), on allège par paliers.
var quality := 0
var _q_acc := 0.0
var _q_low := 0.0
var _q_high := 0.0
var _npc_acc := 0.0

func _process(delta: float) -> void:
	if player == null:
		return
	_npc_acc += delta
	if _npc_acc > 0.3:
		_npc_acc = 0.0
		_cull_npcs()
	_talk_acc += delta
	if _talk_acc > 0.25 and hud:
		_talk_acc = 0.0
		var foes := Combat.in_radius(player.global_position, 14.0).filter(func(m): return m.kind != "mannequin" and not m.peaceful)
		var can := not Dialogue.active and not player.cbt.dead and foes.is_empty()
		if story and story.step in ["debut", "suivre", "embuscade", "colosse", "alerte", "assaut"]:
			can = false
		var n: Node3D = Talk.nearest(player.global_position, get_tree()) if can else null
		if n and n.has_meta("talk") and n.get_meta("talk")["role"] == "roi" and not Story.done():
			n = null
		_arc_near = can and Story.done() and ArcanesUI.near(player.global_position) and (n == null or n.global_position.distance_to(player.global_position) > 2.0)
		var was := PlayerCombat.practice
		PlayerCombat.practice = ArcanesUI.in_chamber(player.global_position)
		if was and not PlayerCombat.practice:
			ArcanesUI.clear_dummies()   # on quitte la chambre : fin de l'entraînement
		_capt = Capture.nearest(player.global_position) if Story.done() and not Dialogue.active and not player.cbt.dead else null
		hud.btn_talk.visible = n != null or _arc_near or _capt != null
		if _capt:
			hud.btn_talk.label = "Capturer : " + String(_capt.def["nom"])
		elif _arc_near:
			hud.btn_talk.label = "Chambre des Arcanes"
		elif n:
			hud.btn_talk.label = "Parler à " + String(Talk.info(n)["nom"])
	var a := OS.get_cmdline_user_args()
	if "--tour" in a or "--combat" in a or "--story" in a or "--vie" in a or "--pouvoirs" in a or "--fx" in a or "--perf" in a:
		return
	_q_acc += delta
	if _q_acc < 1.0:
		return
	_q_acc = 0.0
	var fps := Engine.get_frames_per_second()
	# un pic isolé (chargement d'un camp, gros sort) ne doit pas dégrader l'image pour toute la partie :
	# on n'allège qu'après 5 s de suite sous 26 FPS, et on rend la qualité dès que ça redevient fluide
	_q_low = _q_low + 1.0 if fps < 26 else 0.0
	_q_high = _q_high + 1.0 if fps >= 50 else 0.0
	if _q_low >= 5.0 and quality < 4:
		_q_low = 0.0
		quality += 1
		_apply_quality()
	elif _q_high >= 12.0 and quality > 0:
		_q_high = 0.0
		quality -= 1
		_apply_quality()

## Le joueur se tourne vers son interlocuteur, la caméra se place derrière lui
func focus_on(n: Node3D) -> void:
	if n == null or player == null:
		return
	var d := n.global_position - player.global_position
	d.y = 0
	if d.length() < 0.1:
		return
	player.rotation.y = atan2(d.x, d.z)
	player.velocity = Vector3.ZERO
	if rig:
		rig.yaw = player.rotation.y + PI

var _capt: Node3D = null
func _talk() -> void:
	if Dialogue.active:
		return
	if _capt and Capture.capturable(_capt):
		Capture.capture(_capt)
		_capt = null
		hud.btn_talk.visible = false
		return
	if _arc_near:
		aui.open()
		return
	var n := Talk.nearest(player.global_position, get_tree())
	if n == null:
		return
	_talking = n
	# le PNJ se tourne vers le joueur
	var d := player.global_position - n.global_position
	n.rotation.y = atan2(d.x, d.z)
	if n is Companion:
		n.stand(n.global_position)
	focus_on(n)
	if rig:
		rig.frame_talk(player, n)
	dlg.start(Talk.build(n))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if player:
			var a := OS.get_cmdline_user_args()
			if not ("--tour" in a or "--combat" in a):
				GameState.get_inst().save_game()
				Progression.get_inst().save_if_dirty()

## Les PNJ loin du joueur (ou de l'autre côté des murs du donjon) ne sont ni affichés ni animés.
func _cull_npcs() -> void:
	var pp := player.global_position
	for n in get_tree().get_nodes_in_group("pnj"):
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var inside_keep: bool = n.global_position.y > Castle.FLOOR - 0.2 and n.global_position.y < Castle.FLOOR + 3.0 and Layout.in_castle(Vector2(n.global_position.x, n.global_position.z)) and n.global_position.z < Castle.K_MAX.y and n.global_position.z > Castle.K_MIN.y and absf(n.global_position.x) < Castle.K_MAX.x
		var d := pp.distance_to(n.global_position)
		var show: bool = d < (42.0 if n is Villager else 60.0) and inside_keep == _inside
		if n.visible != show:
			n.visible = show
			n.process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
		if show and n is Villager:
			n.set_lod(0 if d < 16.0 or n.captive else 1)

func _apply_quality() -> void:
	var sun := find_child("Soleil", false, false) as DirectionalLight3D
	var vp := get_viewport()
	# ordre : ce qui coûte le plus et se voit le moins d'abord ; jamais d'image floue (≥ 0,8)
	# chaque palier est réversible (la qualité revient quand le téléphone respire)
	if sun:
		sun.shadow_enabled = quality < 1
	var veg := find_child("Vegetation", true, false)
	if veg:
		for n in veg.get_children():
			if n is GeometryInstance3D:
				if not n.has_meta("vr0"):
					n.set_meta("vr0", n.visibility_range_end)
				n.visibility_range_end = float(n.get_meta("vr0")) * (0.75 if quality >= 2 else 1.0)
	vp.scaling_3d_scale = [1.0, 1.0, 1.0, 0.9, 0.85][quality]
	print("qualité → niveau ", quality)

## Intérieur / extérieur : on n'affiche que ce qui peut être vu.
const OUTSIDE_ONLY := ["Vegetation", "Bourg", "BourgDecor", "Potagers", "Camps", "CampsDecor", "Villages", "VillagesDecor", "Champs", "Lieux", "LieuxDecor", "Gisements", "Ponts", "RoutesPavees", "Eau"]
const INSIDE_ONLY := ["DonjonInterieur", "Mobilier"]

## Dans les cachots : caméra rapprochée, monde extérieur masqué, torches allumées, soleil et ciel atténués
var _cellar := false
func set_cellar(v: bool) -> void:
	if v == _cellar:
		return
	_cellar = v
	if rig:
		rig.inside = v or _inside
	for nm in OUTSIDE_ONLY:
		var n := get_node_or_null(nm) as Node3D
		if n: n.visible = not v
	for l in Justice.lights:
		l.visible = v
	var sun := find_child("Soleil", false, false) as DirectionalLight3D
	if sun:
		if not sun.has_meta("e0"):
			sun.set_meta("e0", sun.light_energy)
		sun.light_energy = float(sun.get_meta("e0")) * (0.08 if v else 1.0)
	var we := find_children("*", "WorldEnvironment", true, false)
	if we.size() > 0 and we[0].environment:
		var env: Environment = we[0].environment
		if not env.has_meta("a0"):
			env.set_meta("a0", env.ambient_light_energy)
		env.ambient_light_energy = float(env.get_meta("a0")) * (0.25 if v else 1.0)

func _set_inside(v: bool) -> void:
	_inside = v
	if rig:
		rig.inside = v
	for l in Castle.interior_lights:
		l.visible = v
	for nm in OUTSIDE_ONLY:
		var n := get_node_or_null(nm) as Node3D
		if n: n.visible = not v
	for nm in INSIDE_ONLY:
		var n := get_node_or_null(nm) as Node3D
		if n: n.visible = v
	if player:
		_cull_npcs()
