extends Node3D
class_name Tower
# Tour infinie : une salle ronde par étage, un boss, des coffres scellés.
# À la mort du boss, chaque coffre s'illumine de la couleur de sa rareté.

const ORIGIN := Vector3(900, 0, 0)
const R := 13.0
const DG := "res://assets/dungeon/"
const RARITY := [
	{"name": "Commun", "col": Color("#4fe36a"), "silver": 5, "items": 0, "potions": 0, "res": 3},
	{"name": "Rare", "col": Color("#4d9bff"), "silver": 14, "items": 1, "potions": 1, "res": 5},
	{"name": "Épique", "col": Color("#b45cff"), "silver": 40, "items": 2, "potions": 1, "res": 8},
	{"name": "LÉGENDAIRE", "col": Color("#ffb02e"), "silver": 120, "items": 3, "potions": 2, "res": 12},
]
const BOSSES := ["warrior", "loup", "duel", "taureau", "boss", "cerf", "rogue"]
const DUEL_MODELS := ["Knight", "Barbarian", "Rogue", "Ranger", "Mage"]

var main: Node
var floor_n := 1
var tier := 1
var boss: Enemy
var chests: Array = []     # {node, pos, rarity, loot: Array, opened, beam, field}
var exit_pos := Vector3.ZERO
var next_pos := Vector3.ZERO
var spawn_pos := Vector3.ZERO
var cleared := false
var exit_open := false     # (interface commune avec le donjon)
var sp_dict := {"members": [], "dungeon": true}
var rng := RandomNumberGenerator.new()
var portals: Node3D

static func tier_of(n: int) -> int: return clamp(1 + int((n - 1) / 5), 1, 5)
static func power_of(n: int) -> float:
	var m := 1.0 + 0.18 * ((n - 1) % 5)
	if n > 25: m *= pow(1.12, n - 25)
	return m
# un coffre par étage ; deux tous les 5 étages, trois tous les 10
static func chest_count(n: int) -> int: return 1 + (1 if n % 5 == 0 else 0) + (1 if n % 10 == 0 else 0)

func walkable(x: float, z: float) -> bool:
	return Vector2(x - ORIGIN.x, z - ORIGIN.z).length() < R - 0.7

func build(m: Node, n: int) -> void:
	main = m; floor_n = n; tier = tier_of(n); rng.randomize()
	spawn_pos = ORIGIN + Vector3(3.0, 0, R - 3.5)
	_room()
	_boss()
	_chests()
	portals = Node3D.new(); add_child(portals)
	_portal(exit_pos, Color(0.6, 0.85, 1.0), "SORTIE")   # on peut toujours ressortir

func _add(o: Node3D, path: String, p: Vector3, rot := 0.0, s := Vector3.ONE) -> Node3D:
	var n: Node3D = load(path).instantiate(); n.position = p; n.rotation.y = rot; n.scale = s; o.add_child(n); return n

func _room() -> void:
	# sol en dalles, coupé en rond
	var mm := {}
	for ix in range(-4, 4):
		for iz in range(-4, 4):
			var p := ORIGIN + Vector3(ix * 4.0 + 2.0, 0, iz * 4.0 + 2.0)
			if Vector2(p.x - ORIGIN.x, p.z - ORIGIN.z).length() > R + 1.5: continue
			var key := DG + ("floor_tile_large_rocks.gltf" if rng.randf() < 0.06 else "floor_tile_large.gltf")
			if not mm.has(key): mm[key] = []
			mm[key].append(Transform3D(Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5), p))
	# mur circulaire : 24 pans, bas du côté caméra
	var seg := 24
	for i in seg:
		var a := TAU * i / seg
		var p := ORIGIN + Vector3(cos(a), 0, sin(a)) * (R + 0.4)
		var south := sin(a) > 0.25
		var rot := -a + PI * 0.5
		var key := DG + ("wall_cracked.gltf" if rng.randf() < 0.2 else "wall.gltf")
		if not mm.has(key): mm[key] = []
		mm[key].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(0.95, 0.22 if south else 1.0, 1.0)), p))
		var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(3.8, 4.0, 1.0)
		cs.shape = bx; body.add_child(cs); body.position = p + Vector3(0, 2.0, 0); body.rotation.y = rot; add_child(body)
		if not south and i % 3 == 0:
			var torch := _add(self, DG + "torch_mounted.gltf", ORIGIN + Vector3(cos(a), 0, sin(a)) * (R - 0.25) + Vector3(0, 1.8, 0), rot + PI)
			main.world._light(torch.position + Vector3(0, 0.6, 0) - Vector3(cos(a), 0, sin(a)) * 0.3, Color("#7fc0ff"), 2.2, 3.0)
	for key in mm: _multi(key, mm[key])
	# colonnes et bannières
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		if sin(a) > 0.5: continue
		_add(self, DG + "pillar_decorated.gltf", ORIGIN + Vector3(cos(a), 0, sin(a)) * (R - 2.2), -a, Vector3.ONE * 0.6)
	_add(self, DG + "banner_patternC_red.gltf", ORIGIN + Vector3(-4.5, 0, -R + 1.2))
	_add(self, DG + "banner_patternC_red.gltf", ORIGIN + Vector3(4.5, 0, -R + 1.2))
	# cercle runique au centre
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 3.6; tm.outer_radius = 3.9; tm.rings = 48; ring.mesh = tm
	var rm := StandardMaterial3D.new(); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.albedo_color = Color(0.4, 0.75, 1.0, 0.7); rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material_override = rm; ring.scale = Vector3(1, 0.05, 1); ring.position = ORIGIN + Vector3(0, 0.08, 0); add_child(ring)
	# vide autour + dalle physique
	var void_mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(300, 300); void_mi.mesh = pm
	var vm := StandardMaterial3D.new(); vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; vm.albedo_color = Color(0.02, 0.03, 0.06); void_mi.material_override = vm
	void_mi.position = ORIGIN + Vector3(0, -2.0, 0); add_child(void_mi)
	var slab := StaticBody3D.new(); var sc := CollisionShape3D.new(); var sb := BoxShape3D.new(); sb.size = Vector3(R * 2 + 6, 1.0, R * 2 + 6)
	sc.shape = sb; slab.add_child(sc); slab.position = ORIGIN + Vector3(0, -0.45, 0); add_child(slab)
	# numéro d'étage au sol
	var lab := Label3D.new(); lab.text = "ÉTAGE %d" % floor_n; lab.font_size = 120; lab.outline_size = 18; lab.modulate = Game.TIER_COL[tier].lightened(0.2); lab.outline_modulate = Color(0, 0, 0, 0.8)
	lab.pixel_size = 0.012; lab.rotation.x = -PI / 2; lab.position = ORIGIN + Vector3(0, 0.06, 6.5); add_child(lab)
	exit_pos = ORIGIN + Vector3(0, 0, R - 2.0)
	next_pos = ORIGIN + Vector3(0, 0, -R + 3.2)

func _multi(path: String, xforms: Array) -> void:
	var sc: Node3D = load(path).instantiate()
	var meshes: Array = []
	main.world._collect(sc, Transform3D.IDENTITY, meshes)
	for m in meshes:
		var mmesh := MultiMesh.new(); mmesh.transform_format = MultiMesh.TRANSFORM_3D; mmesh.mesh = m[0]; mmesh.instance_count = xforms.size()
		for i in xforms.size(): mmesh.set_instance_transform(i, xforms[i] * m[1])
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mmesh; add_child(mmi)
	sc.free()

func _boss() -> void:
	var k: String = BOSSES[(floor_n - 1) % BOSSES.size()]
	var p := ORIGIN + Vector3(0, 0, -1.5)
	var extra := {}
	if k == "duel":
		var mdl: String = DUEL_MODELS[rng.randi() % DUEL_MODELS.size()]
		var wk: String = ["epee", "hache", "baton"][rng.randi() % 3]
		extra = {"model": "res://assets/heroes/%s.glb" % mdl, "weapon": Game.weapon_model(wk, tier), "name": "Champion de la Tour", "id": "tour"}
		if mdl in ["Knight", "Barbarian"]: extra["shield"] = Game.shield_model(tier)
	boss = main._spawn_enemy(k, tier, p, sp_dict, false, extra)
	var pw := power_of(floor_n)
	var big := 1.0 if k == "boss" else 1.5
	boss.def.hp *= (7.0 if k != "boss" else 0.6) * pw; boss.max_hp = Game.mob_hp(tier) * boss.def.hp; boss.hp = boss.max_hp
	boss.def.dmg *= 1.25 * sqrt(pw); boss.is_boss = true; boss.leash = 30.0
	boss.duel_info = {}   # pas d'esquive spéciale ni de règle de duel ici
	boss.name_lbl.text = "Gardien de l'étage %d · T%d" % [floor_n, tier]; boss.name_lbl.modulate = Color("#8fd0ff"); boss.name_lbl.font_size = 56
	boss.ch.root.scale *= big; boss.radius *= big; boss.bar_root.position.y *= big; boss.bar_root.visible = true
	boss.bar_mat.set_shader_parameter("col", Color("#4d9bff"))
	if floor_n >= 3:
		var add: String = "minion" if not boss.animal else "loup"
		for i in min(4, 1 + int(floor_n / 4)):
			var q := ORIGIN + Vector3(cos(i * 2.4) * 6.0, 0, sin(i * 2.4) * 4.0 - 1.0)
			main._spawn_enemy(add, tier, q, sp_dict, false)

func _chests() -> void:
	var n := chest_count(floor_n)
	for i in n:
		var x := (i - (n - 1) * 0.5) * 3.2
		var p := ORIGIN + Vector3(x, 0, -R + 7.0)
		var c := _add(self, DG + "chest_gold.gltf", p, 0.0, Vector3.ONE * 1.3)
		# champ de force bleu tant que le boss vit
		var field := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.1; cm.bottom_radius = 1.1; cm.height = 2.2; cm.cap_top = false; cm.cap_bottom = false; field.mesh = cm
		var fm := StandardMaterial3D.new(); fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.albedo_color = Color(0.3, 0.6, 1.0, 0.35); fm.cull_mode = BaseMaterial3D.CULL_DISABLED; field.material_override = fm; field.position = p + Vector3(0, 1.1, 0)
		field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(field)
		var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = 0.8; cy.height = 1.2; cs.shape = cy; cs.position.y = 0.6; body.add_child(cs); body.position = p; add_child(body)
		chests.append({"node": c, "pos": p, "rarity": _roll_rarity(), "loot": [], "opened": false, "field": field, "lit": false})

func _roll_rarity() -> int:
	var f := float(floor_n)
	var w := [max(8.0, 62.0 - f * 2.2), 28.0 + f * 0.4, 8.0 + f * 1.3, 2.0 + f * 0.55]
	var tot := 0.0
	for x in w: tot += x
	var r := rng.randf() * tot
	for i in 4:
		r -= w[i]
		if r <= 0.0: return i
	return 0

# Le boss est tombé : les coffres se libèrent et s'illuminent
func on_boss_dead() -> void:
	if cleared: return
	cleared = true; exit_open = true
	var best := 0
	for c in chests:
		best = max(best, c.rarity)
		c.loot = _make_loot(c.rarity)
		var tw: Tween = c.field.create_tween(); tw.tween_property(c.field, "scale", Vector3(1.6, 0.01, 1.6), 0.5); tw.tween_callback(c.field.queue_free)
		_light_chest(c)
	_portals()
	Game.S.tower.best = max(int(Game.S.tower.get("best", 0)), floor_n)
	return

func _light_chest(c: Dictionary) -> void:
	var R0: Dictionary = RARITY[c.rarity]; var col: Color = R0.col
	var beam := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.3 + 0.15 * c.rarity; cm.bottom_radius = 0.7 + 0.2 * c.rarity; cm.height = 9.0 + 3.0 * c.rarity; cm.cap_top = false; cm.cap_bottom = false; beam.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.0); m.cull_mode = BaseMaterial3D.CULL_DISABLED; beam.material_override = m
	beam.position = c.pos + Vector3(0, cm.height * 0.5, 0); beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(beam)
	var delay := 0.4 + 0.5 * chests.find(c)
	var tw := beam.create_tween(); tw.tween_interval(delay); tw.tween_property(m, "albedo_color:a", 0.35 + 0.1 * c.rarity, 0.6)
	tw.tween_callback(func():
		Fx.burst(main, c.pos + Vector3(0, 1.0, 0), col, 20 + 12 * c.rarity, 5.0 + c.rarity, 0.4, 1.0, -2.0)
		if c.rarity >= 2: main.shake(0.15 + 0.1 * c.rarity)
		Game.play("level", -10.0 + c.rarity * 2.0, 0.8 + 0.15 * c.rarity))
	c["beam"] = beam
	var g := Sprite3D.new(); g.texture = Fx.soft_tex(); g.billboard = BaseMaterial3D.BILLBOARD_ENABLED; g.pixel_size = 0.04 + 0.015 * c.rarity; g.shaded = false
	g.modulate = Color(col.r, col.g, col.b, 0.65); g.position = c.pos + Vector3(0, 0.9, 0); add_child(g)
	var l := Label3D.new(); l.text = R0.name; l.font_size = 52 + 10 * c.rarity; l.outline_size = 14; l.modulate = col.lightened(0.25); l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.008; l.no_depth_test = true; l.position = c.pos + Vector3(0, 2.4, 0); add_child(l)
	c["label"] = l
	if c.rarity == 3:
		# rayons dorés qui tournent
		for k in 4:
			var ray := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.12, 0.02, 4.0); ray.mesh = bm; ray.material_override = m
			ray.position = c.pos + Vector3(0, 0.15, 0); ray.rotation.y = k * PI / 4.0; add_child(ray)
			var rt := ray.create_tween().set_loops(); rt.tween_property(ray, "rotation:y", ray.rotation.y + TAU, 6.0)

func _make_loot(r: int) -> Array:
	var R0: Dictionary = RARITY[r]; var out := []
	var pw := power_of(floor_n)
	out.append({"silver": int(Game.money(tier) * R0.silver * pw * rng.randf_range(0.9, 1.25))})
	for i in R0.items:
		var t: int = tier
		if r >= 1 and rng.randf() < [0.0, 0.15, 0.3, 0.55][r]: t = min(5, tier + 1)
		var it: Dictionary = Game.random_artefact(t) if (r == 3 and i == 0) else Game.random_item(t)
		if it.slot in Game.ENCH_SLOTS and r >= 2 and rng.randf() < (0.3 if r == 2 else 0.7): it["ench"] = rng.randi_range(1, r)
		out.append({"item": it})
	if R0.potions > 0: out.append({"potion": R0.potions})
	out.append({"res": Game.RES_KEYS[rng.randi() % 3], "tier": tier, "qty": R0.res})
	# un peu de tout : bric-à-brac, et parfois un objet en plus
	for k in rng.randi_range(1, 2): out.append({"item": Game.random_junk(tier, Game.JUNK_SKEL if rng.randf() < 0.6 else Game.JUNK_MAN)})
	if r == 0 and rng.randf() < 0.3: out.append({"item": Game.random_item(max(1, tier - 1))})
	out.shuffle()
	return out

func _portals() -> void:
	_portal(next_pos, Color(0.35, 0.65, 1.0), "ÉTAGE %d ▲" % (floor_n + 1))

func _portal(p: Vector3, col: Color, txt: String) -> void:
	var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.4; cm.bottom_radius = 1.4; cm.height = 0.05; disc.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(col.r, col.g, col.b, 0.75); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	disc.material_override = m; disc.position = p + Vector3(0, 0.1, 0); portals.add_child(disc)
	main.world._light(p + Vector3(0, 1.2, 0), col, 2.6, 4.0)
	var l := Label3D.new(); l.text = txt; l.font_size = 54; l.outline_size = 12; l.modulate = col.lightened(0.4); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.008; l.position = p + Vector3(0, 2.2, 0); l.no_depth_test = true; portals.add_child(l)

func near_chest(pp: Vector3) -> Dictionary:
	for c in chests:
		if Vector2(c.pos.x - pp.x, c.pos.z - pp.z).length() < 2.4: return c
	return {}

func map_image() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8); img.fill(Color(0.04, 0.05, 0.08))
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32 + 0.5, y - 32 + 0.5).length() / 1.5
			if d < R: img.set_pixel(x, y, Color(0.45, 0.5, 0.62))
	return img
