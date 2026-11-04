class_name Interiors
extends Node
## Entrer dans les maisons du bourg : devant une porte, « Entrer » ; on passe dans un intérieur meublé
## (maison, atelier ou échoppe selon la maison), avec ses habitants, toujours le même pour une même porte.
## Les maisons déjà visitables du bourg (porte ouverte) restent telles quelles.

const I := Vector3(-3000, 300, 0)     # loin et au-dessus de tout relief
static var inst: Interiors
var world: Node3D
var inside := -1                        # index de la porte, -1 dehors
var _root: Node3D = null
var _door_out := Vector3.ZERO
var _face_out := Vector2.ZERO
var _exit_at := Vector3.ZERO
var _acc := 0.0
var _skip: Array = []                   # portes des maisons déjà visitables

static func build(w: Node3D) -> void:
	inst = Interiors.new()
	inst.name = "Interieurs"
	inst.world = w
	w.add_child(inst)

func _ready() -> void:
	await get_tree().process_frame
	var vz: Script = load("res://scripts/world/bourg/visit_zone.gd")
	for a in world.find_children("*", "Area3D", true, false):
		if a.get_script() == vz:
			_skip.append(Vector2(a.global_position.x, a.global_position.z))

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	var p := Combat.player
	if p == null or Hud.inst == null or Dialogue.active or p.cbt.dead:
		return
	if inside >= 0:
		if p.global_position.distance_to(_exit_at) < 1.8:
			Hud.inst.show_prompt("carte", "Sortir", func(): leave(), 0.4)
		if p.global_position.y < I.y - 5.0:
			p.global_position = _exit_at + Vector3(0, 0.5, -1.5)
		return
	if not Combat.in_radius(p.global_position, 14.0).is_empty():
		return
	var pp := Vector2(p.global_position.x, p.global_position.z)
	if pp.distance_to(Layout.TOWN) > 110.0:
		return
	var best := -1
	var bd := 2.4
	for i in Town.doors.size():
		var dp: Vector2 = Town.doors[i][0]
		var d := pp.distance_to(dp)
		if d < bd and not _skip.any(func(s): return (s as Vector2).distance_to(dp) < 5.0):
			bd = d
			best = i
	if best >= 0 and absf(p.global_position.y - Terrain.height_at(pp.x, pp.y)) < 2.0:
		var k := best
		Hud.inst.show_prompt("main", "Entrer", func(): enter(k), 0.4)

func _fade(cb: Callable) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	world.add_child(cl)
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)
	var tw := cl.create_tween()
	tw.tween_property(r, "color:a", 1.0, 0.25)
	tw.tween_callback(cb)
	tw.tween_interval(0.15)
	tw.tween_property(r, "color:a", 0.0, 0.35)
	tw.tween_callback(cl.queue_free)

func enter(k: int) -> void:
	if inside >= 0:
		return
	Hud.inst.hide_prompt()
	_door_out = Vector3(Town.doors[k][0].x, 0, Town.doors[k][0].y)
	_face_out = Town.doors[k][1]
	_fade(func():
		inside = k
		_build(k)
		var p := Combat.player
		p.global_position = _exit_at + Vector3(0, 0.4, -3.0)
		p.velocity = Vector3.ZERO
		p.rotation.y = PI
		if world.get("rig"):
			world.rig.inside = true
			world.rig.yaw = 0.0)

func leave() -> void:
	if inside < 0:
		return
	Hud.inst.hide_prompt()
	_fade(func():
		inside = -1
		if is_instance_valid(_root):
			_root.queue_free()
		_root = null
		var p := Combat.player
		var q := Vector2(_door_out.x, _door_out.z) + _face_out * 1.6
		p.global_position = Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.4, q.y)
		p.velocity = Vector3.ZERO
		p.rotation.y = atan2(_face_out.x, _face_out.y)
		if world.get("rig"):
			world.rig.inside = false
			world.rig.yaw = p.rotation.y + PI)

## Intérieur meublé : toujours le même pour une même porte
func _build(k: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = k * 7919 + 13
	_root = Node3D.new()
	_root.name = "Interieur_%d" % k
	world.add_child(_root)
	var kind: String = ["maison", "maison", "atelier", "echoppe", "maison"][k % 5]
	var w := rng.randf_range(7.0, 9.0)
	var d := rng.randf_range(6.0, 7.5)
	var g := Geo.new()
	g.box("parquet", I + Vector3(0, -0.25, 0), Vector3(w, 0.5, d), 0.0, true)
	var wall := "crepi" if kind != "atelier" else "pierre_base"
	g.box(wall, I + Vector3(0, 1.6, -d * 0.5 - 0.15), Vector3(w + 0.3, 3.2, 0.3), 0.0, true)
	for s in [-1.0, 1.0]:
		g.box(wall, I + Vector3(s * (w * 0.5 + 0.15), 1.6, 0), Vector3(0.3, 3.2, d + 0.3), 0.0, true)
		g.box(wall, I + Vector3(s * (w * 0.25 + 0.6), 1.6, d * 0.5 + 0.15), Vector3(w * 0.5 - 1.2, 3.2, 0.3), 0.0, true)
		g.box("bois_sombre", I + Vector3(s * (w * 0.5 - 0.1), 1.6, 0), Vector3(0.2, 3.2, 0.2), 0.0, false)
	g.box(wall, I + Vector3(0, 2.75, d * 0.5 + 0.15), Vector3(1.4, 0.9, 0.3), 0.0, true)
	for z in [-d * 0.25, d * 0.25]:
		g.box("bois_sombre", I + Vector3(0, 3.1, z), Vector3(w, 0.2, 0.25), 0.0, false)
	g.commit(_root, "Murs")
	_exit_at = I + Vector3(0, 0, d * 0.5 - 0.5)
	Kit.dungeon(_root, "Door_Wooden_Left", I + Vector3(-0.6, 0, d * 0.5 + 0.2), 0.0, 0.9)
	var place := func(name: String, pos: Vector3, rot := 0.0, sc := 1.0) -> void:
		Kit.dungeon(_root, name, I + pos, rot, sc)
	match kind:
		"maison":
			place.call("Table_Big", Vector3(0, 0, -0.5), PI / 2.0)
			place.call("Chair", Vector3(-1.0, 0, -0.5), PI / 2.0)
			place.call("Chair", Vector3(1.0, 0, -0.5), -PI / 2.0)
			for k2 in 3:
				place.call(["Bowl_Full", "Bread", "Mug"][k2], Vector3((k2 - 1) * 0.4, 0.82, -0.5))
			place.call("Fireplace", Vector3(-w * 0.5 + 0.6, 0, -d * 0.5 + 1.2), PI / 2.0)
			place.call("Shelf", Vector3(w * 0.5 - 0.4, 0, -1.0), -PI / 2.0)
			place.call("Carpet_Red", Vector3(0, 0.01, 1.0), 0.0, 1.2)
			# lit : cadre de bois et couverture
			var gb := Geo.new()
			gb.box("bois_sombre", I + Vector3(w * 0.5 - 1.2, 0.25, -d * 0.5 + 1.2), Vector3(1.4, 0.5, 2.2), 0.0, true)
			gb.box("tissu_rouge", I + Vector3(w * 0.5 - 1.2, 0.55, -d * 0.5 + 1.3), Vector3(1.3, 0.12, 1.8), 0.0, false)
			gb.box("tissu_blanc", I + Vector3(w * 0.5 - 1.2, 0.6, -d * 0.5 + 0.35), Vector3(1.1, 0.15, 0.4), 0.0, false)
			gb.commit(_root, "Lit")
		"atelier":
			place.call("Table_Big", Vector3(0, 0, -d * 0.5 + 1.2))
			place.call("WeaponRack_Big", Vector3(-w * 0.5 + 0.4, 0, -0.5), PI / 2.0)
			place.call("Barrel_Big", Vector3(w * 0.5 - 0.8, 0, -d * 0.5 + 0.8))
			place.call("Barrel_Closed", Vector3(w * 0.5 - 0.8, 0, -d * 0.5 + 1.9))
			place.call("FirewoodStack", Vector3(w * 0.5 - 0.8, 0, 1.0))
			place.call("Sword", Vector3(0.3, 0.82, -d * 0.5 + 1.2), 0.4)
			place.call("Bucket", Vector3(-1.2, 0, 1.2))
		"echoppe":
			var gc := Geo.new()
			gc.box("bois", I + Vector3(0, 0.5, -0.8), Vector3(w * 0.6, 1.0, 0.8), 0.0, true)
			gc.commit(_root, "Comptoir")
			for s in [-1.0, 0.0, 1.0]:
				place.call("Shelf", Vector3(s * 2.2, 0, -d * 0.5 + 0.35))
			for k2 in 4:
				place.call(["Potion_Red", "Potion_Blue", "Jar_Full", "Potion_Green"][k2], Vector3(-1.2 + k2 * 0.8, 1.02, -0.8))
			place.call("Barrel_Open", Vector3(-w * 0.5 + 0.8, 0, 1.2))
			place.call("Bag", Vector3(w * 0.5 - 0.8, 0, 1.0))
	place.call("Candlestick_Triple", Vector3(w * 0.5 - 0.6, 0, d * 0.5 - 0.8))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.45)
	l.light_energy = 1.8
	l.omni_range = maxf(w, d) * 1.2
	_root.add_child(l)
	l.global_position = I + Vector3(0, 2.6, 0)
	# habitants
	var noms_h := ["Bertrand", "Mathieu", "Hugues", "Aubin", "Gervais", "Lambert"]
	var noms_f := ["Jeanne", "Isabeau", "Guillemette", "Aude", "Perrine", "Mahaut"]
	var n := 1 + (1 if rng.randf() < 0.55 else 0)
	for i in n:
		var fem := rng.randf() < 0.5
		var v := Villager.new()
		v.spec = {"outfit": "paysan_f" if fem else "paysan_h", "female": fem, "hair": "Hair_Long" if fem else "Hair_SimpleParted", "beard": not fem and rng.randf() < 0.5, "tint": Color(0.85, 0.75, 0.6)}
		v.anim_name = ["Idle_Talking", "Idle", "b/Idle_FoldArms"][rng.randi() % 3] if kind != "atelier" else "Interact"
		_root.add_child(v)
		v.global_position = I + Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0, rng.randf_range(-d * 0.3, 0.2))
		v.rotation.y = rng.randf() * TAU
		var nom: String = (noms_f if fem else noms_h)[rng.randi() % 6]
		var role := "habitant" if kind == "maison" else ("marchand" if kind == "echoppe" else "habitant")
		v.set_meta("talk", {"id": "interieur_%d_%d" % [k, i], "nom": nom, "role": role})
