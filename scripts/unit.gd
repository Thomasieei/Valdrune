class_name Unit
extends CharacterBody3D
## Base commune : héros, monstres, ombres.

signal died(u: Unit)

const GRAVITY := 18.0
## Barre de vie toujours face caméra, remplie de gauche à droite selon « fill ».
static var BAR_SHADER: Shader = _bar_shader()
static func _bar_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float fill = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	if (UV.x > fill) { discard; }
	ALBEDO = col.rgb * (0.85 + 0.3 * (1.0 - UV.y));
}
"""
	return sh
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
var invuln := 0.0
var lifted := false
var flash_mat: StandardMaterial3D
var model: Node3D
var ap: AnimationPlayer
var ring: MeshInstance3D
var hp_bar: Node3D
var hp_fill: MeshInstance3D
var world: Node3D
var cur_anim := ""
var loops := ["Idle", "Walk", "Run", "Sprint", "SwordIdle", "CastLoop", "Block", "TeleHold", "Choke", "Cheer"]

func setup_model(path: String, scale_f: float, ring_col: Color, ring_alpha: float) -> void:
	model = (load(path) as PackedScene).instantiate()
	model.scale = Vector3.ONE * scale_f
	add_child(model)
	_make_opaque()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 75.0
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

## Les matériaux importés en « transparent » rendaient les persos translucides : on force l'opaque (découpe alpha).
func _make_opaque() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as BaseMaterial3D
			if src and src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var d := src.duplicate() as BaseMaterial3D
				d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				d.alpha_scissor_threshold = 0.45
				m.set_surface_override_material(i, d)

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
	bg.visibility_range_end = 32.0
	hp_bar.add_child(bg)
	hp_fill = MeshInstance3D.new()
	hp_fill.visibility_range_end = 32.0
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.96, 0.07)
	hp_fill.mesh = q2
	var sh := ShaderMaterial.new()
	sh.shader = BAR_SHADER
	sh.set_shader_parameter("col", col)
	sh.set_shader_parameter("fill", 1.0)
	sh.render_priority = 2
	hp_fill.material_override = sh
	hp_bar.add_child(hp_fill)
	var lb := Label3D.new()
	lb.text = "%s [%s]" % [display_name, rank]
	lb.font_size = 34
	lb.pixel_size = 0.0008
	lb.fixed_size = true
	lb.outline_size = 8
	lb.modulate = col.lightened(0.4)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position.y = 0.17
	lb.visibility_range_end = 16.0
	hp_bar.add_child(lb)

func update_hp_bar() -> void:
	if hp_fill:
		var f := clampf(hp / max_hp, 0.0, 1.0)
		(hp_fill.material_override as ShaderMaterial).set_shader_parameter("fill", f)

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
	if invuln > 0.0:
		FX.damage_number(world, global_position, "ESQUIVE", Color(0.7, 0.9, 1.0), false)
		on_dodged(from)
		return
	hp -= amount
	_flash()
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

func on_dodged(_from: Unit) -> void:
	pass

## Éclair blanc sur le modèle quand il est touché.
func _flash() -> void:
	if model == null:
		return
	if flash_mat == null:
		flash_mat = StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flash_mat.albedo_color = Color(1, 1, 1, 0)
	# la surcouche n'existe que pendant l'éclair (sinon chaque modèle touché est dessiné deux fois en permanence)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var gi := mi as MeshInstance3D
		if gi.material_overlay == null:
			gi.material_overlay = flash_mat
	flash_mat.albedo_color = Color(1, 0.92, 0.85, 0.42)
	var tw := create_tween()
	tw.tween_property(flash_mat, "albedo_color:a", 0.0, 0.14)
	tw.tween_callback(_unflash)

func _unflash() -> void:
	if model == null or (flash_mat and flash_mat.albedo_color.a > 0.01):
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_overlay == flash_mat:
			(mi as MeshInstance3D).material_overlay = null

func on_hit(_from: Unit) -> void:
	if busy <= 0.0 and ap and ap.has_animation("Hit"):
		hit_stun = 0.3
		play("Hit", 0.05, 1.2, true)

## Animations manquantes : on réutilise celles du modèle (ex. chaman : Animacion → Idle).
func alias_anims(m: Dictionary) -> void:
	if ap == null:
		return
	var libs := ap.get_animation_library_list()
	if libs.is_empty():
		return
	var lib := ap.get_animation_library(libs[0])
	for k in m.keys():
		if ap.has_animation(k):
			continue
		var src := ""
		for cand in ap.get_animation_list():
			if cand == m[k] or cand.ends_with(m[k]):
				src = cand
				break
		if src != "":
			var a := ap.get_animation(src).duplicate() as Animation
			if k in ["Idle", "Walk", "Run", "CastLoop"]:
				a.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(k, a)

## Sans animation de mort : le modèle bascule au sol.
func fall_over() -> void:
	if model == null:
		return
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", -PI * 0.48, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", 0.15, 0.45)

func stand_up() -> void:
	if model == null or absf(model.rotation.x) < 0.1:
		return
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(model, "position:y", 0.0, 0.6)

func die() -> void:
	dead = true
	hp = 0
	update_hp_bar()
	busy = 99.0
	if ap == null or not ap.has_animation("Death"):
		fall_over()
	play("Death", 0.1, 1.0, true)
	collision_layer = 0
	collision_mask = 1
	if hp_bar:
		hp_bar.visible = false
	if ring:
		ring.visible = false
	died.emit(self)

const STEP_H := 0.45

func apply_gravity_and_slide(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(60.0)
	var hv := Vector3(velocity.x, 0, velocity.z)
	move_and_slide()
	# montée de marches (trottoirs, bordures) : si on bute contre un obstacle bas, on passe dessus
	if hv.length() > 0.4 and is_on_wall():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var n := c.get_normal()
			var h := c.get_position().y - global_position.y
			if n.y < 0.86 and h > 0.02 and h < STEP_H and hv.normalized().dot(-Vector3(n.x, 0, n.z).normalized()) > 0.3:
				var up := Vector3(0, STEP_H + 0.05, 0)
				var fwd := hv.normalized() * 0.18
				if not test_move(global_transform, up) and not test_move(global_transform.translated(up), fwd):
					global_position += up + fwd
					apply_floor_snap()
				break
	velocity.x = move_toward(velocity.x, 0, 25.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 25.0 * delta)
	if global_position.y < -20:
		global_position.y = 3
