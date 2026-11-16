extends Node3D
## Habitant léger (pas de physique) : marche le long d'un chemin ou regarde la rue.
const CH := ["Knight", "Barbarian", "Mage", "Rogue_Hooded"]
const PAL := [Color(0.95, 0.85, 0.7), Color(0.75, 0.85, 1.0), Color(1.0, 0.78, 0.7), Color(0.8, 0.95, 0.75), Color(0.9, 0.8, 0.95), Color(1, 1, 0.85)]
var path: PackedVector3Array
var i := 0
var dir := 1
var ap: AnimationPlayer
var pause := 0.0
func setup(p: PackedVector3Array, rng: RandomNumberGenerator) -> void:
	path = p
	var m: Node3D = (load("res://assets/chars/%s.glb" % CH[rng.randi_range(0, 3)]) as PackedScene).instantiate()
	add_child(m)
	for n in m.find_children("*", "AnimationPlayer", true, false): n.free()
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	for n in sk.get_children():
		if n is BoneAttachment3D and not (String(n.name).contains("Hat") or String(n.name).contains("Cape") or String(n.name).contains("Helmet")): n.visible = false
		elif n is BoneAttachment3D and String(n.name).contains("Helmet"): n.visible = false
	var tint: Color = PAL[rng.randi_range(0, PAL.size() - 1)]
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var src = mi.get_active_material(0)
		if src is StandardMaterial3D: var nm: StandardMaterial3D = src.duplicate(); nm.albedo_color = tint; mi.material_override = nm
	scale = Vector3.ONE * rng.randf_range(0.88, 1.0)
	ap = AnimationPlayer.new(); ap.add_animation_library("", Actor.LIB); m.add_child(ap)
	ap.root_node = ap.get_path_to(sk.get_parent())
	if path.size() <= 1:
		position = path[0]; rotation.y = rng.randf() * TAU
		ap.play(["Idle_A", "Cheering", "Waving", "Idle_B", "Think"][rng.randi_range(0, 4)])
		ap.seek(rng.randf() * 2.0)
		set_process(false)
	else:
		i = rng.randi_range(0, path.size() - 1)
		position = path[i].lerp(path[(i + 1) % path.size()], rng.randf()) + Vector3(rng.randf_range(-0.5, 0.5), 0, 0)
		dir = 1 if rng.randf() < 0.5 else -1
		ap.play("Walking_A"); ap.speed_scale = 0.9
func _process(dt: float) -> void:
	if pause > 0:
		pause -= dt
		if pause <= 0: ap.play("Walking_A", 0.3)
		return
	var t := path[i]; var d := t - position; d.y = 0
	if d.length() < 0.4:
		if path.size() == 2: dir = -dir; i = (i + dir + 2) % 2
		else: i = (i + 1) % path.size()
		if randf() < 0.25: pause = randf_range(2, 5); ap.play(["Idle_A", "Waving", "Interact"][randi() % 3], 0.3)
		return
	position += d.normalized() * 1.25 * dt
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 1.0 - exp(-8 * dt))
