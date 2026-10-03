extends Node3D
class_name Island
# Île privée du joueur : logis des ouvriers, coffre journalier, champs, enclos d'élevage, quai.
# Construite loin du monde (x ≈ 1500). Les bandits l'attaquent deux fois par jour.

const ORIGIN := Vector3(1500, 0, 0)
const R := 34.0
const H := "res://assets/hex/"
const F := "res://assets/forest/"
const DG := "res://assets/dungeon/"

var main: Node
var lvl := 1
var spots: Array = []          # {pos, kind, i}
var spawn_pos := Vector3.ZERO
var exit_pos := Vector3.ZERO
var chest_pos := Vector3.ZERO
var fields: Array = []         # nodes of crops
var pen_animals: Array = []
var workers: Array = []
var sp_groups: Array = []      # groupes de bandits
var raid_on := false
var exit_open := true
var rng := RandomNumberGenerator.new()

func walkable(x: float, z: float) -> bool:
	var d := Vector2(x - ORIGIN.x, z - ORIGIN.z)
	if d.length() < R - 1.2: return true
	# le quai
	return d.x > -3.0 and d.x < 3.0 and d.y > R - 4.0 and d.y < R + 12.0

func _place(path: String, p: Vector3, rot := 0.0, s := 1.0) -> Node3D:
	var o: Node3D = load(path).instantiate(); o.position = p; o.rotation.y = rot; o.scale = Vector3.ONE * s; add_child(o); return o

func _block(p: Vector3, r: float) -> void:
	var b := StaticBody3D.new(); var c := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = r; cy.height = 4.0
	c.shape = cy; b.add_child(c); b.position = p + Vector3(0, 2, 0); add_child(b)

func build(m: Node, level: int) -> void:
	main = m; lvl = level; rng.seed = 77
	var O := ORIGIN
	# sol : disque d'herbe bordé de sable
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 64
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		for ring in [[0.0, R - 6.0, Color("#3f7a2e"), Color("#4a8a36")], [R - 6.0, R - 2.5, Color("#4a8a36"), Color("#d8c48a")], [R - 2.5, R + 1.5, Color("#e2cf96"), Color("#d9c287")]]:
			var r0: float = ring[0]; var r1: float = ring[1]
			var y0 := 0.0 if r0 < R - 2.5 else -(r0 - (R - 2.5)) * 0.35
			var y1 := 0.0 if r1 < R - 2.5 else -(r1 - (R - 2.5)) * 0.35
			var v := [Vector3(cos(a0) * r0, y0, sin(a0) * r0), Vector3(cos(a1) * r0, y0, sin(a1) * r0), Vector3(cos(a0) * r1, y1, sin(a0) * r1), Vector3(cos(a1) * r1, y1, sin(a1) * r1)]
			var c0: Color = ring[2]; var c1: Color = ring[3]
			for k in [[0, c0], [2, c1], [1, c0], [1, c0], [2, c1], [3, c1]]:
				st.set_color(k[1]); st.add_vertex(O + v[k[0]])
	st.generate_normals()
	var ground := MeshInstance3D.new(); ground.mesh = st.commit()
	var gm := StandardMaterial3D.new(); gm.vertex_color_use_as_albedo = true; gm.vertex_color_is_srgb = true; gm.roughness = 1.0; ground.material_override = gm; add_child(ground)
	var slab := StaticBody3D.new(); var sc := CollisionShape3D.new(); var cyl := CylinderShape3D.new(); cyl.radius = R + 2.0; cyl.height = 1.0
	sc.shape = cyl; slab.add_child(sc); slab.position = O + Vector3(0, -0.5, 0); add_child(slab)
	# mer tout autour
	var sea := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(260, 260); sea.mesh = pm
	var sh := Shader.new(); sh.code = """shader_type spatial;
render_mode cull_disabled, shadows_disabled;
void fragment(){
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(wp.xz - vec2(1500.0, 0.0));
	float w = sin(wp.x * 0.8 + TIME * 1.2) * sin(wp.z * 0.6 - TIME) * 0.5 + 0.5;
	vec3 col = mix(vec3(0.3, 0.8, 0.85), vec3(0.08, 0.3, 0.6), smoothstep(34.0, 60.0, d)) + w * 0.06;
	float foam = smoothstep(37.5, 35.0, d) * (0.6 + 0.4 * sin(TIME * 2.0 + wp.x));
	ALBEDO = mix(col, vec3(1.0), foam * 0.7); ROUGHNESS = 0.08; SPECULAR = 0.7;
}"""
	var smat := ShaderMaterial.new(); smat.shader = sh; sea.material_override = smat; sea.position = O + Vector3(0, -0.45, 0); add_child(sea)
	# quai + bateau
	var pier := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(4.2, 0.3, 14.0); pier.mesh = bm
	var wmat := StandardMaterial3D.new(); wmat.albedo_color = Color("#8a5a34"); pier.material_override = wmat; pier.position = O + Vector3(0, 0.12, R + 4.5); add_child(pier)
	var pb := StaticBody3D.new(); var pc := CollisionShape3D.new(); var pbx := BoxShape3D.new(); pbx.size = bm.size; pc.shape = pbx; pb.add_child(pc); pb.position = pier.position; add_child(pb)
	add_child(World.make_boat(O + Vector3(5.2, -0.3, R + 6.0), 0.0))
	spawn_pos = O + Vector3(0, 0, R + 3.0)
	exit_pos = O + Vector3(0, 0, R + 9.0)
	spots.append({"pos": exit_pos, "kind": "boat"})
	# logis des ouvriers + coffre
	_place(H + "building_home_B_blue.gltf", O + Vector3(-6, 0, -10), 0.4, 5.5); _block(O + Vector3(-6, 0, -10), 3.2)
	_place(H + "building_lumbermill_blue.gltf", O + Vector3(8, 0, -13), -0.3, 4.6); _block(O + Vector3(8, 0, -13), 3.0)
	main.world.label("LOGIS DES OUVRIERS", O + Vector3(-6, 7.5, -10), Color("#ffe2a0"), 54)
	chest_pos = O + Vector3(-1, 0, -5)
	_place(DG + "chest_gold.gltf", chest_pos, 0.0, 1.5); _block(chest_pos, 0.8)
	spots.append({"pos": chest_pos, "kind": "chest"})
	spots.append({"pos": O + Vector3(-3, 0, -6.5), "kind": "house"})
	main.world._light(chest_pos + Vector3(0, 1.4, 0), Color("#ffd24a"), 2.0, 3.0)
	# ressources travaillées par les ouvriers (décor)
	for i in 7: _place(F + ["Tree_1_A_Color1.gltf", "Tree_2_A_Color1.gltf", "Tree_3_A_Color1.gltf"][i % 3], O + Vector3(-24 + i * 2.7, 0, -14 + (i % 2) * 3.0), i, 1.2)
	for i in 4: _place(F + "Rock_3_E_Color1.gltf", O + Vector3(18 + (i % 2) * 3.0, 0, -6 + i * 2.6), i, 1.0)
	for i in 6: _place(F + "Bush_2_B_Color1.gltf", O + Vector3(-22 + (i % 3) * 2.5, 0, 4 + int(i / 3) * 2.5), i, 1.4)
	_place(H + "resource_lumber.gltf", O + Vector3(-14, 0, -8), 0.3, 4.0)
	_place(H + "resource_stone.gltf", O + Vector3(15, 0, -2), 0.3, 4.0)
	_place(H + "wheelbarrow.gltf", O + Vector3(2, 0, -9), 0.6, 4.0)
	_place(H + "sack.gltf", O + Vector3(1.5, 0, -6.5), 0.0, 4.0)
	# 3 ouvriers animés
	for w in [[Vector3(-20, 0, -11), "Throw"], [Vector3(16, 0, -3), "Throw"], [Vector3(-19, 0, 6.5), "PickUp"]]:
		var ch := Chars.make("res://assets/heroes/%s.glb" % ["Barbarian", "Knight", "Ranger"][workers.size()]); ch.root.position = O + w[0]; add_child(ch.root)
		Chars.attach(ch, "handslot.r", [Game.TOOL_MODEL.hache, Game.TOOL_MODEL.pioche, Game.TOOL_MODEL.faucille][workers.size()])
		ch.ap.play(w[1]); ch.ap.get_animation(w[1]).loop_mode = Animation.LOOP_NONE
		workers.append({"ch": ch, "anim": w[1], "t": randf() * 2.0})
		var l := Label3D.new(); l.text = "Ouvrier"; l.font_size = 34; l.outline_size = 10; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.0065; l.position = O + w[0] + Vector3(0, 2.4, 0); l.modulate = Color("#c9e6ff"); add_child(l)
	# champs (4 parcelles) clôturés
	for i in 4:
		var p := O + Vector3(4 + (i % 2) * 7.0, 0, 6 + int(i / 2) * 7.0)
		var crop := _place(H + "building_grain.gltf", p, 0.0, 2.6)
		fields.append(crop)
		spots.append({"pos": p, "kind": "field", "i": i})
	for k in 6: _place(H + "fence_wood_straight.gltf", O + Vector3(1.5 + k * 2.3, 0, 2.2), PI / 2, 2.0)
	_place("res://assets/halloween/pumpkin_orange.gltf", O + Vector3(17, 0, 7), 0.4, 1.4)
	_place("res://assets/halloween/pumpkin_yellow_small.gltf", O + Vector3(17.5, 0, 9), 0.8, 1.4)
	main.world.label("CHAMPS", O + Vector3(7.5, 3.0, 9.5), Color("#e9ffb0"), 46)
	# enclos d'élevage
	var pc2 := O + Vector3(-14, 0, 17)
	for k in 5:
		_place(H + "fence_wood_straight.gltf", pc2 + Vector3(-5.5 + k * 2.3, 0, -4.5), PI / 2, 2.0)
		_place(H + "fence_wood_straight.gltf", pc2 + Vector3(-5.5 + k * 2.3, 0, 4.5), PI / 2, 2.0)
	for k in 4:
		_place(H + "fence_wood_straight.gltf", pc2 + Vector3(-6.6, 0, -3.4 + k * 2.3), 0.0, 2.0)
	main.world.label("ENCLOS D'ÉLEVAGE", pc2 + Vector3(0, 3.2, -4.5), Color("#ffd8a8"), 46)
	spots.append({"pos": pc2 + Vector3(6.5, 0, 0), "kind": "pen"})
	_res_nodes()
	_grass()
	refresh()

# ——— Ressources sauvages de l'île : elles changent toutes les 30 minutes ———
# Le tier de la période est tiré au sort (plus l'île est grande, meilleures sont les chances) :
# on peut tomber sur du T2 pendant des heures… ou décrocher une période T5.
const RES_PERIOD := 1800.0
const RES_SPOTS := [Vector3(-26, 0, -2), Vector3(-27, 0, 3), Vector3(-24, 0, 9), Vector3(-29, 0, -8), Vector3(22, 0, -12), Vector3(26, 0, -6),
	Vector3(27, 0, 1), Vector3(24, 0, 6), Vector3(10, 0, -24), Vector3(16, 0, -21), Vector3(-6, 0, -25), Vector3(0, 0, -27)]
var res_nodes: Array = []
static func period_id() -> int: return int(Time.get_unix_time_from_system() / RES_PERIOD)
static func period_left() -> float: return RES_PERIOD - fmod(Time.get_unix_time_from_system(), RES_PERIOD)
static func roll_period_tier(level: int) -> int:
	var w := [0.0, 0.0, 55.0 - 6.0 * level, 28.0 + 1.0 * level, 12.0 + 3.0 * level, 3.0 + 2.0 * level]
	var tot := 0.0
	for x in w: tot += x
	var r := randf() * tot
	for t in range(2, 6):
		r -= w[t]
		if r <= 0.0: return t
	return 2
func res_state() -> Dictionary:
	var I: Dictionary = Game.S.island
	var pid := period_id()
	if typeof(I.get("res")) != TYPE_DICTIONARY or int(I.res.get("period", -1)) != pid:
		I["res"] = {"period": pid, "tier": roll_period_tier(int(I.lvl)), "left": {}}
	return I.res
func _res_nodes() -> void:
	var R0 := res_state(); var t: int = int(R0.tier)
	for i in RES_SPOTS.size():
		var k: String = Game.RES_KEYS[i % 3]
		var nd: Dictionary = main.world._add_node(k, t, ORIGIN + RES_SPOTS[i], self)
		nd["isl"] = i; nd.respawn = 99999.0
		var left: int = int(R0.left.get(str(i), nd.max))
		nd.charges = left
		if left <= 0: nd.model.scale = nd.base_scale * 0.25; nd.ring.visible = false; nd.badge.visible = false
		res_nodes.append(nd)
func clear_res() -> void:
	for nd in res_nodes: main.world.nodes.erase(nd)
	res_nodes.clear()

# Touffes d'herbe et fleurs (un seul appel de dessin par modèle)
func _grass() -> void:
	for path in [F + "Grass_1_A_Color1.gltf", F + "Grass_2_B_Color1.gltf", F + "Bush_1_A_Color1.gltf"]:
		var xs: Array = []
		for i in (90 if not "Bush" in path else 14):
			var a := rng.randf() * TAU; var r := sqrt(rng.randf()) * (R - 4.0)
			var p := ORIGIN + Vector3(cos(a) * r, 0, sin(a) * r)
			var ok := true
			for s in spots:
				if Vector2(s.pos.x - p.x, s.pos.z - p.z).length() < 4.5: ok = false; break
			if ok: xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.1, 1.7)), p))
		var sc: Node3D = load(path).instantiate(); var meshes: Array = []
		main.world._collect(sc, Transform3D.IDENTITY, meshes)
		for m in meshes:
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = m[0]; mm.instance_count = xs.size()
			for i in xs.size(): mm.set_instance_transform(i, xs[i] * m[1])
			var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mmi)
		sc.free()

# Met à jour cultures et animaux de l'enclos
func refresh() -> void:
	var I: Dictionary = Game.S.island
	var now := Time.get_unix_time_from_system()
	for i in fields.size():
		var t0: float = float(I.farm[i])
		var g: float = 0.15 if t0 <= 0.0 else clamp((now - t0) / Game.FARM_TIME, 0.15, 1.0)
		fields[i].scale = Vector3(2.6, 2.6 * g, 2.6)
	for a in pen_animals: a.queue_free()
	pen_animals.clear()
	var pc2 := ORIGIN + Vector3(-14, 0, 17)
	for k in I.pen.size():
		var M: Dictionary = Game.MOUNTS.get(I.pen[k].kind, Game.MOUNTS.ane)
		var mdl: Node3D = load("res://assets/animals/%s.glb" % M.model).instantiate(); mdl.scale = Vector3.ONE * M.scale * 0.8
		mdl.position = pc2 + Vector3(-2.5 + k * 5.0, 0, 0); mdl.rotation.y = 0.6 + k
		var ap: AnimationPlayer = mdl.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("Idle"): ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR; ap.play("Idle")
		add_child(mdl); pen_animals.append(mdl)

func _process(dt: float) -> void:
	for w in workers:
		w.t -= dt
		if w.t <= 0.0: w.t = 2.2; w.ch.ap.play(w.anim, 0.1); w.ch.ap.seek(0.0, true)

func near(pp: Vector3) -> Dictionary:
	var best := {}; var bd := 2.8
	for s in spots:
		var d := Vector2(s.pos.x - pp.x, s.pos.z - pp.z).length()
		if d < bd: bd = d; best = s
	return best

# ——— Raid de bandits : 10 groupes, le 10e est un chef ———
func start_raid() -> void:
	if raid_on: return
	raid_on = true
	var t := Game.bandit_tier(lvl)
	var places := [Vector3(-24, 0, -4), Vector3(-18, 0, 12), Vector3(-6, 0, 24), Vector3(10, 0, 24), Vector3(22, 0, 14), Vector3(25, 0, -2),
		Vector3(20, 0, -18), Vector3(4, 0, -24), Vector3(-14, 0, -22), Vector3(2, 0, 2)]
	for gi in 10:
		var sp := {"members": [], "dungeon": true, "bandit_group": gi}
		var c: Vector3 = ORIGIN + places[gi]
		var n := 3 if gi < 9 else 1
		for k in n:
			var mdl: String = ["Rogue", "Barbarian", "Knight"][(gi + k) % 3]
			var wk: String = ["epee", "hache", "baton"][(gi * 2 + k) % 3]
			var extra := {"model": "res://assets/heroes/%s.glb" % mdl, "weapon": Game.weapon_model(wk, t), "name": "Bandit" if gi < 9 else "Chef des bandits"}
			var e: Enemy = main._spawn_enemy("bandit", t, c + World.polar(k * 2.1, 1.8 if n > 1 else 0.0), sp, false, extra)
			e.leash = 22.0
			if gi == 9:
				e.def.hp *= 6.0; e.max_hp = Game.mob_hp(t) * e.def.hp; e.hp = e.max_hp; e.def.dmg *= 1.6; e.is_boss = true
				e.ch.root.scale *= 1.7; e.radius *= 1.6; e.bar_root.position.y *= 1.6; e.bar_root.visible = true
				e.name_lbl.modulate = Color("#ff5a3a"); e.name_lbl.font_size = 58
		sp_groups.append(sp)

func groups_cleared() -> int:
	var n := 0
	for sp in sp_groups:
		if sp.members.all(func(m): return not is_instance_valid(m) or m.dead): n += 1
	return n

func map_image() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8); img.fill(Color(0.12, 0.35, 0.55))
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 0.9
			if d < R: img.set_pixel(x, y, Color(0.45, 0.68, 0.32) if d < R - 3 else Color(0.85, 0.78, 0.55))
	return img
