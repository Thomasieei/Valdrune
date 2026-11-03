class_name DwarfRealm
extends Node3D
## Royaume des Nains — Karak Dûm : une vallée enneigée au-delà du portail, une forteresse taillée
## dans la montagne (rempart, tours à braseros, statues géantes des ancêtres, porte de bronze),
## une cour de forges où l'on frappe le fer, et la salle du trône où le roi Thorvald reçoit… ou pas.
## Construite à la première traversée du portail (aucun coût au chargement du jeu).

const O := Vector3(0.0, 200.0, 1400.0)   # loin de la carte et au-dessus de tout relief : aucun conflit
const STEP := 4.0
const N := 81                              # 320 m de côté
const GATE_Z := -62.0
static var inst: DwarfRealm
static var inside := false
var gate_open := false
var _doors: Array = []
var _snow: CPUParticles3D
var _env_saved := {}
var _challenged := 0.0
var _busy := false

static func arrival() -> Vector3:
	return O + Vector3(0, 0.3, 78)

## Relief local de la vallée (mètres au-dessus de O.y)
static func h(x: float, z: float) -> float:
	var r := Vector2(x, z * 0.85).length()
	var y := 0.0
	y += smoothstep(78.0, 150.0, r) * 62.0
	# la montagne de la forteresse, au nord ; la cour (-66..-122) reste plate et encaissée
	var cliff := smoothstep(-52.0, -64.0, z) * smoothstep(34.0, 46.0, absf(x))
	y = maxf(y, cliff * 48.0)
	y = maxf(y, smoothstep(-122.0, -132.0, z) * 60.0)
	var n := sin(x * 0.13) * cos(z * 0.11) * 1.4 + sin(x * 0.041 + z * 0.057) * 3.0
	y += n * smoothstep(20.0, 90.0, r)
	if z < -58.0 and z > -124.0 and absf(x) < 34.0:
		y = 0.0   # cour de la forteresse
	if z > -64.0 and z < 96.0:
		y = lerpf(y, 0.0, 1.0 - smoothstep(5.0, 10.0, absf(x)))   # route pavée jusqu'à la porte, à plat
	return y

static func ground(x: float, z: float) -> float:
	return O.y + h(x, z)

# ------------------------------------------------------------------ voyage
static func travel(world: Node3D) -> void:
	if inst == null:
		inst = DwarfRealm.new()
		inst.name = "RoyaumeNains"
		world.add_child(inst)
	inst._enter(world)

var _built := false

func _fade(cb: Callable) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	get_tree().current_scene.add_child(cl)
	var r := ColorRect.new()
	r.color = Color(0.85, 0.92, 1.0, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)
	var tw := cl.create_tween()
	tw.tween_property(r, "color:a", 1.0, 0.45)
	tw.tween_callback(cb)
	tw.tween_interval(0.25)
	tw.tween_property(r, "color:a", 0.0, 0.7)
	tw.tween_callback(cl.queue_free)

func _enter(world: Node3D) -> void:
	_fade(func():
		if not _built:
			_built = true
			_build()   # écran blanc pendant la construction : aucune saccade visible
		inside = true
		var p := Combat.player
		p.global_position = arrival() + Vector3.UP * 0.4
		p.velocity = Vector3.ZERO
		p.rotation.y = PI
		if world.get("rig"):
			world.rig.yaw = 0.0
		_bring_followers(p.global_position)
		_env(true)
		_snow.emitting = true
		if Hud.inst:
			Hud.inst.discover("Karak Dûm", "Royaume des Nains")
		GameState.get_inst().set_flag("visite_nains"))

func leave() -> void:
	_fade(func():
		inside = false
		var p := Combat.player
		var q := Layout.PORTAL + Vector2(0, -7)
		p.global_position = Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.4, q.y)
		p.velocity = Vector3.ZERO
		_bring_followers(p.global_position)
		_env(false)
		_snow.emitting = false
		if Hud.inst:
			Hud.inst.discover("Valmont", "Retour au royaume"))

func _bring_followers(at: Vector3) -> void:
	var i := 0
	if Combat.companion and is_instance_valid(Combat.companion) and Combat.companion.visible:
		Combat.companion.teleport(at + Vector3(1.6, 0.3, 1.2))
	for s in Escort.members:
		if is_instance_valid(s):
			i += 1
			s.global_position = at + Vector3(-1.5 * i, 0.4, 2.0)

## Ciel d'hiver : brume bleutée, soleil bas et froid
func _env(on: bool) -> void:
	var w := get_tree().current_scene
	var we := w.find_children("*", "WorldEnvironment", true, false)
	var sun := w.find_child("Soleil", false, false) as DirectionalLight3D
	if we.is_empty():
		return
	var env: Environment = we[0].environment
	if on:
		_env_saved = {"fog": env.fog_light_color, "fd": env.fog_density, "ae": env.ambient_light_energy, "sun": sun.light_color if sun else Color.WHITE, "se": sun.light_energy if sun else 1.0}
		env.fog_light_color = Color(0.5, 0.57, 0.7)
		env.fog_density = 0.0024
		env.ambient_light_energy = 0.75
		if sun:
			sun.light_color = Color(1.0, 0.86, 0.72)   # soleil bas et chaud sur neige bleutée : contraste
			sun.light_energy = _env_saved["se"] * 0.95
	elif not _env_saved.is_empty():
		env.fog_light_color = _env_saved["fog"]
		env.fog_density = _env_saved["fd"]
		env.ambient_light_energy = _env_saved["ae"]
		if sun:
			sun.light_color = _env_saved["sun"]
			sun.light_energy = _env_saved["se"]

# ------------------------------------------------------------------ construction
func _build() -> void:
	_ground()
	var g := Geo.new()
	_road(g)
	_fortress(g)
	_court(g)
	_portal_back(g)
	g.commit(self, "KarakDum")
	_decor()
	_people()
	_snowfall()

func _ground() -> void:
	var H := PackedFloat32Array()
	H.resize(N * N)
	var half := (N - 1) * STEP * 0.5
	for j in N:
		for i in N:
			H[j * N + i] = h(-half + i * STEP, -half + j * STEP)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in N:
		for i in N:
			var k := j * N + i
			var hl := H[j * N + maxi(i - 1, 0)]
			var hr := H[j * N + mini(i + 1, N - 1)]
			var hu := H[maxi(j - 1, 0) * N + i]
			var hd := H[mini(j + 1, N - 1) * N + i]
			var nm := Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()
			var rock := smoothstep(0.12, 0.35, 1.0 - nm.y)
			st.set_color(Color(1, 1, 1, rock))
			st.set_normal(nm)
			st.add_vertex(Vector3(-half + i * STEP, H[k], -half + j * STEP))
	for j in N - 1:
		for i in N - 1:
			var a := j * N + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + N)
			st.add_index(a + 1); st.add_index(a + N + 1); st.add_index(a + N)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/snow.gdshader")
	mat.set_shader_parameter("roche", load("res://assets/textures/sol_roche.png"))
	mat.set_shader_parameter("roche_n", load("res://assets/textures/sol_roche_n.png"))
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.noise = FastNoiseLite.new()
	mat.set_shader_parameter("noise_tex", nt)
	mi.material_override = mat
	mi.position = O
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = N
	hm.map_depth = N
	hm.map_data = H
	cs.shape = hm
	cs.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(cs)
	body.position = O
	add_child(body)

func _road(g: Geo) -> void:
	for k in 39:
		var z := 90.0 - k * 4.0
		g.box("pierre_base", O + Vector3(0, -0.15, z), Vector3(8.0, 0.4, 4.05), 0.0, false)
	# bornes runiques le long de la route
	for k in 6:
		for s in [-1.0, 1.0]:
			var z := 70.0 - k * 22.0
			g.box("pierre_base", O + Vector3(s * 6.0, 1.0, z), Vector3(0.9, 2.0, 0.9), 0.0, true)
			g.box("rune", O + Vector3(s * 6.0, 1.4, z + 0.46), Vector3(0.4, 0.7, 0.05), 0.0, false)

func _fortress(g: Geo) -> void:
	var z := GATE_Z
	# rempart massif de part et d'autre de la porte
	for s in [-1.0, 1.0]:
		g.box("pierre", O + Vector3(s * 23.0, 9.0, z), Vector3(34.0, 18.0, 7.0), 0.0, true)
		g.crenels("pierre", O + Vector3(s * 6.5, 18.0, z + 3.3), O + Vector3(s * 40.0, 18.0, z + 3.3), 0.8)
		# tours carrées à braseros
		var tx: float = s * 12.0
		g.box("pierre", O + Vector3(tx, 13.0, z + 1.5), Vector3(9.0, 26.0, 10.0), 0.0, true)
		g.box("pierre_claire", O + Vector3(tx, 26.4, z + 1.5), Vector3(10.0, 0.8, 11.0), 0.0, false)
		g.crenels("pierre_claire", O + Vector3(tx - 4.8, 27.2, z + 6.8), O + Vector3(tx + 4.8, 27.2, z + 6.8), 0.6, 2.0, 1.0, 1.2)
		g.cylinder("fer", O + Vector3(tx, 0, z + 1.5), 1.3, 27.0, 28.2, 10, false, true, "cuivre")
		g.box("bleu_royal", O + Vector3(tx, 16.0, z + 6.6), Vector3(4.0, 9.0, 0.15), 0.0, false)
		g.box("or", O + Vector3(tx, 16.5, z + 6.7), Vector3(1.4, 1.4, 0.1), 0.0, false)
		# bandeaux runiques dorés
		g.box("or", O + Vector3(tx, 18.0, z + 6.55), Vector3(9.2, 0.35, 0.1), 0.0, false)
		g.box("or", O + Vector3(tx, 8.0, z + 6.55), Vector3(9.2, 0.35, 0.1), 0.0, false)
	# arche de la porte
	g.box("pierre_claire", O + Vector3(0, 17.0, z), Vector3(16.0, 6.0, 8.0), 0.0, true)
	g.box("or", O + Vector3(0, 15.6, z + 4.05), Vector3(12.0, 1.0, 0.12), 0.0, false)
	for k in 5:
		g.box("rune", O + Vector3(-4.0 + k * 2.0, 15.6, z + 4.15), Vector3(0.6, 0.6, 0.05), 0.0, false)
	# vantaux de bronze (pivotent à l'ouverture)
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = O + Vector3(s * 6.0, 0.0, z + 1.0)
		add_child(pivot)
		var door := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(6.0, 14.0, 0.9)
		door.mesh = bm
		door.material_override = Geo.mat("bois_sombre")
		door.position = Vector3(-s * 3.0, 7.0, 0)
		pivot.add_child(door)
		for k in 4:
			var band := MeshInstance3D.new()
			var b2 := BoxMesh.new()
			b2.size = Vector3(6.1, 0.35, 1.0)
			band.mesh = b2
			band.material_override = Geo.mat("fer")
			band.position = Vector3(-s * 3.0, 2.0 + k * 3.5, 0)
			pivot.add_child(band)
		var body := StaticBody3D.new()
		body.collision_layer = 2
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bm.size
		cs.shape = sh
		cs.position = door.position
		body.add_child(cs)
		pivot.add_child(body)
		_doors.append([pivot, s])

func _court(g: Geo) -> void:
	var c := O + Vector3(0, 0, -94)
	g.box("pierre_base", c + Vector3(0, -0.15, 0), Vector3(66.0, 0.4, 62.0), 0.0, false)
	# grandes bannières bleu et or sur le mur du fond
	for k in 3:
		var bx := -16.0 + k * 16.0
		g.box("bleu_royal", c + Vector3(bx, 14.0, -29.4), Vector3(4.0, 12.0, 0.15), 0.0, false)
		g.box("or", c + Vector3(bx, 14.0, -29.3), Vector3(1.4, 1.4, 0.1), 0.0, false)
		g.box("or", c + Vector3(bx, 20.1, -29.35), Vector3(4.4, 0.3, 0.2), 0.0, false)
	# murs de la cour taillés dans la roche, piliers et bannières
	for s in [-1.0, 1.0]:
		g.box("pierre", c + Vector3(s * 34.0, 12.0, 0), Vector3(3.0, 24.0, 62.0), 0.0, true)
		for k in 5:
			g.box("pierre_claire", c + Vector3(s * 31.8, 9.0, -24.0 + k * 12.0), Vector3(2.2, 18.0, 2.2), 0.0, true)
	g.box("pierre", c + Vector3(0, 16.0, -31.0), Vector3(70.0, 32.0, 3.0), 0.0, true)
	# estrade du trône
	g.stairs("pierre_claire", c + Vector3(0, 0, -18.0), PI, 14.0, 0.4, 0.9, 4)
	g.box("pierre_claire", c + Vector3(0, 0.8, -24.5), Vector3(18.0, 1.6, 10.0), 0.0, true, "dallage")
	g.box("tissu_rouge", c + Vector3(0, 0.07, -2.0), Vector3(4.0, 0.06, 30.0), 0.0, false)
	g.box("or", c + Vector3(0, 0.05, -2.0), Vector3(4.5, 0.04, 30.2), 0.0, false)
	# forges : foyers de pierre et cheminées
	for f in [Vector3(-22, 0, 10), Vector3(22, 0, 10), Vector3(-22, 0, -8), Vector3(22, 0, -8)]:
		var q: Vector3 = c + f
		g.box("pierre_base", q + Vector3(0, 0.6, 0), Vector3(3.2, 1.2, 2.4), 0.0, true)
		g.box("fer", q + Vector3(0, 1.22, 0), Vector3(2.4, 0.06, 1.6), 0.0, false)
		g.box("pierre_base", q + Vector3(0, 4.5, -0.9), Vector3(1.6, 7.0, 1.0), 0.0, false)
		g.box("fer", q + Vector3(2.4, 0.5, 1.4), Vector3(0.6, 1.0, 0.6), 0.0, true)
		g.box("fer", q + Vector3(2.4, 1.05, 1.4), Vector3(1.2, 0.25, 0.5), 0.0, false)

func _portal_back(g: Geo) -> void:
	var p := arrival() + Vector3(0, -0.3, 10.0)
	for s in [-1.0, 1.0]:
		g.box("pierre_claire", p + Vector3(s * 3.6, 2.6, 0), Vector3(1.4, 5.2, 1.6), 0.0, true)
	g.box("pierre_claire", p + Vector3(0, 5.6, 0), Vector3(8.6, 1.2, 1.8), 0.0, false)
	var veil := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(5.8, 5.0)
	veil.mesh = q
	veil.material_override = Places.portal_mat if Places.portal_mat else Geo.mat("cristal")
	veil.position = p + Vector3(0, 2.6, 0)
	add_child(veil)
	var zone := Area3D.new()
	zone.collision_mask = 8   # couche du joueur
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(5.0, 3.0, 1.0)
	cs.shape = bs
	zone.add_child(cs)
	zone.position = p + Vector3(0, 1.5, 0)
	add_child(zone)
	zone.body_entered.connect(func(b):
		if b == Combat.player and inside:
			leave())
	var lbl := Label3D.new()
	lbl.text = "Vers Valmont"
	lbl.font_size = 56
	lbl.outline_size = 10
	lbl.pixel_size = 0.008
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lbl.position = p + Vector3(0, 6.8, 0)
	add_child(lbl)

func _fire(at: Vector3, big := false) -> void:
	var f := FX.particles("fire_01", 16 if big else 10, 0.7, [Color(1, 0.85, 0.45, 0.95), Color(1, 0.35, 0.1, 0)], 1.2 if big else 0.6, false)
	f.direction = Vector3.UP
	f.initial_velocity_min = 0.6
	f.initial_velocity_max = 1.4
	f.gravity = Vector3.ZERO
	add_child(f)
	f.global_position = at
	f.emitting = true

func _decor() -> void:
	# braseros sur colonnes le long de la route (feu sans lumière : fluide)
	for k in 6:
		for sd in [-1.0, 1.0]:
			_fire(O + Vector3(sd * 6.0, 2.4, 70.0 - k * 22.0))
	var root := Node3D.new()
	root.name = "KarakDecor"
	add_child(root)
	var c := O + Vector3(0, 0, -94)
	# braseros des tours (deux vraies lumières seulement)
	for s in [-1.0, 1.0]:
		var at: Vector3 = O + Vector3(s * 12.0, 28.6, GATE_Z + 1.5)
		_fire(at, true)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 3.0
		l.omni_range = 26.0
		l.position = at + Vector3(0, 1, 0)
		add_child(l)
	# statues géantes des ancêtres, de part et d'autre de la porte
	var stone := Geo.mat("pierre_claire")
	for s in [-1.0, 1.0]:
		var st := CharBuilder.build({"outfit": "paysan_h", "beard": true, "hair": "Hair_Buzzed"})
		add_child(st)
		st.global_position = O + Vector3(s * 21.0, 0.0, GATE_Z + 6.5)
		st.scale = Vector3(4.2, 3.6, 4.2)
		st.rotation.y = 0.0
		for mi in st.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = stone
		var ap: AnimationPlayer = st.get_node("AnimationPlayer")
		var an := "b/Idle_Shield" if ap.has_animation("b/Idle_Shield") else "Idle"
		ap.play(an)
		ap.seek(0.4, true)
		ap.pause()
		g_socle(root, O + Vector3(s * 21.0, 0, GATE_Z + 6.5))
	# forges allumées, enclumes, râteliers, tonneaux
	for f in [Vector3(-22, 1.3, 10), Vector3(22, 1.3, 10), Vector3(-22, 1.3, -8), Vector3(22, 1.3, -8)]:
		_fire(c + f)
		Kit.dungeon(root, "WeaponRack_Big", c + f + Vector3(-3.0, -1.3, 1.2), PI * 0.5, 1.0)
		Kit.dungeon(root, "Barrel_Big", c + f + Vector3(3.6, -1.3, -1.6), 0.0, 1.0)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.55, 0.25)
	fl.light_energy = 2.2
	fl.omni_range = 30.0
	fl.position = c + Vector3(0, 6, 0)
	add_child(fl)
	# trône, bannières, torches, tapis
	Kit.dungeon(root, "Throne", c + Vector3(0, 1.6, -26.0), 0.0, 1.7)
	for k in 5:
		Kit.dungeon(root, "Banner", c + Vector3(-12.0 + k * 6.0, 6.0, -29.3), 0.0, 2.2)
	for k in 6:
		for s in [-1.0, 1.0]:
			Kit.dungeon(root, "Torch_Wall", c + Vector3(s * 32.4, 4.0, -24.0 + k * 9.0), -s * PI * 0.5, 1.4)
	Kit.dungeon(root, "Chest", c + Vector3(-6.5, 1.6, -26.0), 0.3, 1.2)
	Kit.dungeon(root, "Chest", c + Vector3(6.5, 1.6, -26.0), -0.3, 1.2)
	# vallée : pins enneigés et rochers
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for k in 140:
		var x := rng.randf_range(-140.0, 140.0)
		var z := rng.randf_range(-50.0, 140.0)
		if absf(x) < 12.0 and z > -60.0:
			continue
		if Vector2(x, z - 78.0).length() < 14.0:
			continue
		var y := h(x, z)
		if y > 40.0:
			continue
		Kit.nature(root, "pine" if rng.randf() < 0.8 else "rocks", O + Vector3(x, y, z), rng.randf() * TAU, rng.randf_range(1.6, 2.6))
	Batcher.merge(root)

static func g_socle(root: Node3D, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(7.0, 1.6, 7.0)
	mi.mesh = bm
	mi.material_override = Geo.mat("pierre")
	mi.position = at + Vector3(0, 0.8, 0)
	root.add_child(mi)

## Nains : gardes de la porte, forgerons, marchands, garde royale et le roi Thorvald
func _people() -> void:
	var c := O + Vector3(0, 0, -94)
	var dwarf := func(pos: Vector3, rot: float, anim: String, tint: Color, id: String, nom: String, role: String, weapon := "") -> Villager:
		var v := Villager.new()
		v.spec = {"outfit": "paysan_h", "beard": true, "hair": ["Hair_Buzzed", "Hair_SimpleParted"][absi(id.hash()) % 2], "tint": tint, "hair_color": [Color(0.55, 0.25, 0.1), Color(0.75, 0.7, 0.62), Color(0.2, 0.15, 0.1)][absi(id.hash()) % 3]}
		v.anim_name = anim
		add_child(v)
		v.global_position = pos
		v.rotation.y = rot
		v.scale = Vector3(0.92, 0.78, 0.92)
		if id != "":
			v.set_meta("talk", {"id": id, "nom": nom, "role": role})
		if weapon != "":
			var skel: Skeleton3D = v.get_child(0).get_node("Armature/Skeleton3D")
			var att := BoneAttachment3D.new()
			att.bone_name = "hand_r"
			skel.add_child(att)
			Kit.dungeon(att, weapon, Vector3.ZERO, 0.0, 1.2)
		return v
	# la garde de la porte (le capitaine interpelle les visiteurs)
	dwarf.call(O + Vector3(-3.5, 0, GATE_Z + 7.0), 0.0, "b/Idle_Shield", Color(0.62, 0.66, 0.78), "capitaine_nain", "Capitaine Brokkar", "garde_nain", "Spear")
	for s in [-1.0, 1.0]:
		dwarf.call(O + Vector3(s * 7.5, 0, GATE_Z + 6.0), 0.0, "b/Idle_Shield", Color(0.6, 0.64, 0.75), "", "", "", "Spear")
	# forgerons et apprentis
	var smiths := [[Vector3(-19.6, 0, 11.4), "Durin"], [Vector3(24.4, 0, 11.4), "Grimma"], [Vector3(-19.6, 0, -6.6), "Balin"], [Vector3(24.4, 0, -6.6), "Hilda"]]
	for i in smiths.size():
		var sm: Array = smiths[i]
		dwarf.call(c + (sm[0] as Vector3), PI * (1.0 if i % 2 == 0 else 0.0) + PI * 0.5, "b/Sword_Regular_A", Color(0.7, 0.55, 0.45), "forgeron_nain_%d" % i, sm[1], "nain", "Sword")
	# habitants de la cour
	var folks := [[Vector3(-8, 0, 16), "Idle_Talking"], [Vector3(-6.8, 0, 17.2), "Idle"], [Vector3(9, 0, 4), "b/Idle_FoldArms"], [Vector3(12, 0, 20), "Interact"], [Vector3(-12, 0, -2), "Idle_Talking"]]
	for i in folks.size():
		var fk: Array = folks[i]
		dwarf.call(c + (fk[0] as Vector3), randf() * TAU, fk[1], Color(0.75, 0.65, 0.55), "nain_%d" % i, ["Gimra", "Oin", "Nali", "Thrain", "Dagny"][i], "nain")
	# garde royale et roi
	for s in [-1.0, 1.0]:
		for k in 2:
			dwarf.call(c + Vector3(s * (4.0 + k * 3.0), 1.6, -22.0), 0.0, "b/Idle_Shield", Color(0.78, 0.68, 0.35), "", "", "", "Spear")
	var king: Villager = dwarf.call(c + Vector3(0, 1.75, -24.6), 0.0, "Idle", Color(0.95, 0.78, 0.3), "roi_nain", "Thorvald, Roi sous la Montagne", "roi_nain")
	king.scale = Vector3(1.0, 0.85, 1.0)

func _snowfall() -> void:
	_snow = CPUParticles3D.new()
	_snow.amount = 260
	_snow.lifetime = 6.0
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(28, 1, 28)
	_snow.direction = Vector3(0.2, -1, 0.1)
	_snow.spread = 12.0
	_snow.gravity = Vector3(0, -1.2, 0)
	_snow.initial_velocity_min = 1.0
	_snow.initial_velocity_max = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	q.material = FX.pmat("circle_05", false, true, Color(1, 1, 1, 0.9))
	_snow.mesh = q
	_snow.local_coords = false
	_snow.emitting = false
	add_child(_snow)

func _process(delta: float) -> void:
	if not inside:
		return
	var p := Combat.player
	if p == null:
		return
	_snow.global_position = p.global_position + Vector3(0, 12, 0)
	# le capitaine interpelle le souverain devant la porte close
	if not gate_open and not Dialogue.active and not _busy:
		var lp := p.global_position - O
		if lp.z < GATE_Z + 22.0 and lp.z > GATE_Z and absf(lp.x) < 14.0 and Time.get_ticks_msec() / 1000.0 > _challenged:
			_challenged = Time.get_ticks_msec() / 1000.0 + 40.0
			DwarfDiplomacy.gate_challenge(self)

func open_gate() -> void:
	if gate_open:
		return
	gate_open = true
	for d in _doors:
		var pivot: Node3D = d[0]
		var s: float = d[1]
		var tw := create_tween()
		tw.tween_property(pivot, "rotation:y", -s * deg_to_rad(95.0), 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	Sfx.play("lourd", 2.0)
	var w := get_tree().current_scene
	if w.get("rig"):
		w.rig.shake(0.5)
	if Hud.inst:
		Hud.inst.discover("La porte de Karak Dûm s'ouvre", "Le roi Thorvald vous attend")
