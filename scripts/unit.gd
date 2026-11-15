class_name Unit
extends CharacterBody3D
## Base commune : héros, monstres, ombres.

signal died(u: Unit)

const GRAVITY := 18.0
var team := 0                 # 0 = joueur + ombres, 1 = monstres
var display_name := ""
var rank := "E"
var max_hp := 100.0
var hp := 100.0
var dmg := 10.0
var body_r := 0.5             # cercle invisible (rayon de collision)
var arm := 0.75               # portée d'un bras au-delà des cercles
var speed := 3.5
var dead := false
var busy := 0.0               # temps restant d'une action verrouillée (attaque, sort)
var hit_stun := 0.0
var model: Node3D
var ap: AnimationPlayer
var ring: MeshInstance3D
var hp_bar: Node3D
var hp_fill: MeshInstance3D
var world: Node3D
var cur_anim := ""
var loops := ["Idle", "Walk", "Run", "Sprint", "SwordIdle"]

func setup_model(path: String, scale_f: float, ring_col: Color, ring_alpha: float) -> void:
	model = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * scale_f
	add_child(model)
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		ap = found[0] as AnimationPlayer
		for n in loops:
			if ap.has_animation(n):
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = body_r
	cap.height = maxf(1.7, body_r * 2.0 + 0.2)
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)
	collision_layer = 2
	collision_mask = 1 | 2
	ring = FX.ground_disc(body_r + 0.12, ring_col, ring_alpha, true)
	add_child(ring)

func make_hp_bar(h: float, col: Color) -> void:
	hp_bar = Node3D.new()
	hp_bar.position.y = h
	add_child(hp_bar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.1)
	bg.mesh = q
	var bm := FX.mat(Color(0, 0, 0), 0.0, 0.7)
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg.material_override = bm
	hp_bar.add_child(bg)
	hp_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.96, 0.07)
	hp_fill.mesh = q2
	var fm := FX.mat(col, 1.5, 1.0)
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fm.render_priority = 2
	hp_fill.material_override = fm
	hp_bar.add_child(hp_fill)
	var lb := Label3D.new()
	lb.text = "%s [%s]" % [display_name, rank]
	lb.font_size = 34
	lb.pixel_size = 0.005
	lb.outline_size = 8
	lb.modulate = col.lightened(0.4)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position.y = 0.17
	hp_bar.add_child(lb)

func update_hp_bar() -> void:
	if hp_fill:
		var f := clampf(hp / max_hp, 0.0, 1.0)
		hp_fill.scale.x = maxf(f, 0.001)

func play(anim: String, blend := 0.15, spd := 1.0, force := false) -> void:
	if ap == null or not ap.has_animation(anim):
		return
	if cur_anim == anim and not force and ap.is_playing():
		ap.speed_scale = spd
		return
	cur_anim = anim
	ap.play(anim, blend)
	ap.speed_scale = spd

func anim_len(anim: String) -> float:
	if ap and ap.has_animation(anim):
		return ap.get_animation(anim).length
	return 0.5

func face_to(p: Vector3, inst := false, delta := 0.016) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.01:
		return
	var y := atan2(d.x, d.z)
	model.rotation.y = y if inst else lerp_angle(model.rotation.y, y, 14.0 * delta)

func forward() -> Vector3:
	return Vector3(sin(model.rotation.y), 0, cos(model.rotation.y))

## Distance entre les bords des cercles (0 = cercles qui se touchent).
func gap_to(o: Unit) -> float:
	var d := global_position - o.global_position
	d.y = 0
	return d.length() - body_r - o.body_r

func in_reach(o: Unit, extra := 0.0) -> bool:
	return gap_to(o) <= arm + extra

func take_damage(amount: float, from: Unit, crit := false) -> void:
	if dead:
		return
	hp -= amount
	update_hp_bar()
	var col := Color(1, 0.95, 0.6) if team == 1 else Color(1, 0.3, 0.3)
	if crit:
		col = Color(0.75, 0.45, 1.0)
	FX.damage_number(world, global_position, ("%d!" % amount) if crit else str(int(amount)), col, crit)
	FX.burst(world, global_position + Vector3(0, 1.1, 0), Color(1, 0.3, 0.2) if team == 1 else Color(1, 0.1, 0.1), 10, 0.07, 3.0, 0.35, 6.0)
	if hp <= 0:
		die()
		return
	if from:
		var kb := global_position - from.global_position
		kb.y = 0
		velocity += kb.normalized() * 2.5
	on_hit(from)

func on_hit(_from: Unit) -> void:
	if busy <= 0.0 and ap and ap.has_animation("Hit"):
		hit_stun = 0.3
		play("Hit", 0.05, 1.2, true)

func die() -> void:
	dead = true
	hp = 0
	update_hp_bar()
	busy = 99.0
	play("Death", 0.1, 1.0, true)
	collision_layer = 0
	collision_mask = 1
	if hp_bar:
		hp_bar.visible = false
	if ring:
		ring.visible = false
	died.emit(self)

func apply_gravity_and_slide(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	velocity.x = move_toward(velocity.x, 0, 25.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 25.0 * delta)
	if global_position.y < -20:
		global_position.y = 3
