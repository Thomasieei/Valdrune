class_name Hero
extends Unit
## Le Chasseur : combat rapide, parkour (sprint, double saut, course murale, escalade),
## épée dégainée / rangée, mains nues, Pas de l'ombre en chaîne, Arise de masse, statistiques.

const HAND_T := Transform3D(Vector3(2.17677, -3.47315, -99.91596), Vector3(12.59394, -99.13401, 3.72034), Vector3(-99.17991, -12.66434, -1.72051), Vector3(32.77142, 14.16435, 1.68576))
const BACK_T := Transform3D(Vector3(89.44272, 44.52306, 4.20682), Vector3(1.99800, 5.41905, -99.83307), Vector3(-44.67671, 89.37747, 3.95738), Vector3(-5.33661, -5.92753, -15.15445))

var mp := 100.0
var max_mp := 100.0
var move_input := Vector2.ZERO
var cam_yaw := 0.0
var main
var combo := 0
var combo_t := 0.0
var cd := {"attack": 0.0, "step": 0.0, "arise": 0.0, "roll": 0.0, "jump": 0.0, "tele": 0.0, "swap": 0.0}
const CD_MAX := {"attack": 0.32, "step": 7.0, "arise": 10.0, "roll": 1.6, "jump": 0.22, "tele": 12.0, "swap": 15.0}
const MP_COST := {"step": 22.0, "arise": 30.0, "tele": 35.0, "swap": 20.0}
# grimoire : niveau des pouvoirs (0 = verrouillé)
var powers := {"step": 1, "arise": 1, "tele": 1, "plunge": 1, "perfect": 1, "swap": 0}
var wall_n := Vector3.ZERO
var wall_leaps := 0
var plunging := false
var perfect_window := 0.0
var counter_ready := false
var pending: Array = []
var regen_t := 0.0
var sword: Node3D
var hand_mount: Node3D
var back_mount: Node3D
var armed := false
var unarmed_mode := false
var calm_t := 0.0
# parkour
var air_jumps := 1
var airborne := false
var fall_peak_v := 0.0
var roll_t := 0.0
var roll_dir := Vector3.ZERO
var sprint_t := 0.0
var sprinting := false
var climbing := false
var mantle_t := 0.0
var speed_fx: CPUParticles3D
# statistiques
var level := 1
var xp := 0.0
var points := 0
var stats := {"force": 0, "agilite": 0, "vitesse": 0, "domaine": 0}
var blade_mult := 1.0
var domain_ring: MeshInstance3D

func xp_next() -> float:
	return 80.0 + 45.0 * level * level

func domain_r() -> float:
	return 12.0 + 3.0 * stats["domaine"]

func max_shadows() -> int:
	return 4 + int(stats["domaine"] / 2)

func run_speed() -> float:
	return 7.4 * (1.0 + 0.05 * stats["agilite"])

func sprint_speed() -> float:
	return 11.5 * (1.0 + 0.05 * stats["agilite"])

func atk_speed() -> float:
	return 1.5 * (1.0 + 0.07 * stats["vitesse"])

func power() -> float:
	return 26.0 * (1.0 + 0.1 * stats["force"]) * blade_mult * (0.6 if unarmed_mode else 1.0)

func setup_hero() -> void:
	display_name = "Chasseur"
	max_hp = 420; hp = max_hp; dmg = 26; body_r = 0.45; arm = 0.85; speed = 7.4
	setup_model("res://assets/hero.glb", 1.0, Color(1, 1, 1), 0.2)
	collision_layer = 4
	collision_mask = 1 | 2
	loops.append_array(["Celebrate", "Slide"])
	for n in loops:
		if ap and ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	if ap and ap.has_animation("ClimbLoop"):
		ap.get_animation("ClimbLoop").length = 2.1
	_setup_sword()
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.78, 0.86, 1.0)
	fill.light_energy = 1.3
	fill.omni_range = 9.0
	fill.position = Vector3(0, 2.6, 0)
	add_child(fill)
	speed_fx = CPUParticles3D.new()
	speed_fx.amount = 40
	speed_fx.lifetime = 0.35
	speed_fx.emitting = false
	speed_fx.local_coords = false
	speed_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	speed_fx.emission_box_extents = Vector3(0.6, 0.9, 0.6)
	speed_fx.gravity = Vector3.ZERO
	speed_fx.scale_amount_min = 0.03
	speed_fx.scale_amount_max = 0.05
	var bm := BoxMesh.new()
	bm.size = Vector3(0.2, 0.2, 6.0)
	bm.material = FX.mat(Color(0.6, 0.8, 1.0), 2.0, 0.5)
	speed_fx.mesh = bm
	speed_fx.position.y = 1.0
	add_child(speed_fx)
	domain_ring = FX.ground_disc(domain_r(), Color(0.5, 0.2, 1.0), 0.07, true)
	add_child(domain_ring)
	domain_ring.visible = false
	play("Idle", 0.0)

func _bone(sk: Skeleton3D, suffix: String) -> int:
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i)
		if bn.ends_with(suffix) or bn.contains(suffix + "_"):
			return i
	return -1

func _setup_sword() -> void:
	var skel_list := model.find_children("*", "Skeleton3D", true, false)
	if skel_list.is_empty():
		return
	var sk := skel_list[0] as Skeleton3D
	var bh := -1
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i)
		if (bn.ends_with("RightHand") or bn.contains("RightHand_")) and not (bn.contains("Thumb") or bn.contains("Index") or bn.contains("Middle") or bn.contains("Ring") or bn.contains("Pinky")):
			bh = i
			break
	var bs := _bone(sk, "Spine2")
	if bh < 0 or bs < 0:
		print("SWORD: os introuvables")
		return
	var a1 := BoneAttachment3D.new()
	sk.add_child(a1)
	a1.bone_idx = bh
	hand_mount = Node3D.new()
	a1.add_child(hand_mount)
	hand_mount.transform = HAND_T
	var a2 := BoneAttachment3D.new()
	sk.add_child(a2)
	a2.bone_idx = bs
	back_mount = Node3D.new()
	a2.add_child(back_mount)
	back_mount.transform = BACK_T
	sword = (load("res://assets/katana.glb") as PackedScene).instantiate()
	back_mount.add_child(sword)
	print("SWORD: main=", sk.get_bone_name(bh), " dos=", sk.get_bone_name(bs))

func set_armed(on: bool) -> void:
	if on and unarmed_mode:
		on = false
	if on == armed or sword == null:
		return
	armed = on
	main.sfx("draw" if on else "sheath", global_position, -4.0)
	var dest := hand_mount if on else back_mount
	sword.get_parent().remove_child(sword)
	dest.add_child(sword)
	FX.burst(main, global_position + Vector3(0, 1.3, 0), Color(0.45, 0.7, 1.0) if on else Color(0.5, 0.3, 0.9), 14, 0.06, 2.0, 0.3, 0.0)

func toggle_unarmed() -> void:
	unarmed_mode = not unarmed_mode
	if unarmed_mode:
		set_armed(false)
	main.system_msg("Mains nues : le Chasseur se bat aux poings." if unarmed_mode else "Épée autorisée : dégainée au combat.")

func later(t: float, c: Callable) -> void:
	pending.append([t, c])

func ready_skill(k: String) -> bool:
	return cd[k] <= 0.0 and mp >= MP_COST.get(k, 0.0) and not dead

func gain_xp(v: float) -> void:
	xp += v
	while xp >= xp_next():
		xp -= xp_next()
		level += 1
		points += 3
		if level >= 4 and powers["swap"] == 0:
			powers["swap"] = 1
			later(2.5, main.system_msg.bind("[ SYSTÈME ]\nNouveau pouvoir débloqué : ÉCHANGE D'OMBRE.\nConsulte ton Grimoire."))
		max_hp += 40
		hp = max_hp
		max_mp += 10
		mp = max_mp
		FX.arise_pillar(main, global_position)
		main.sfx("levelup")
		main.sfx("victory", null, -6.0)
		main.save_game()
		FX.damage_number(main, global_position + Vector3(0, 0.8, 0), "NIVEAU %d !" % level, Color(1, 0.85, 0.3), true)
		main.system_msg("[ SYSTÈME ]\nNiveau supérieur ! Niveau %d.\n+3 points de compétence à répartir." % level)

func add_stat(k: String) -> void:
	if points <= 0:
		return
	points -= 1
	stats[k] += 1
	if k == "domaine":
		(domain_ring.mesh as PlaneMesh).size = Vector2(domain_r() * 2.0, domain_r() * 2.0)

# ============================================================ boucle
func _physics_process(delta: float) -> void:
	for i in range(pending.size() - 1, -1, -1):
		pending[i][0] -= delta
		if pending[i][0] <= 0.0:
			var c: Callable = pending[i][1]
			pending.remove_at(i)
			if not dead:
				c.call()
	for k in cd.keys():
		cd[k] = maxf(cd[k] - delta, 0.0)
	busy -= delta
	hit_stun -= delta
	combo_t -= delta
	invuln -= delta
	perfect_window -= delta
	mp = minf(max_mp, mp + 6.0 * delta)
	regen_t -= delta
	if regen_t <= 0.0 and hp < max_hp and not dead:
		hp = minf(max_hp, hp + 10.0 * delta)
	if lifted:
		return
	if dead:
		apply_gravity_and_slide(delta)
		return
	if main.in_dialogue:
		play("Idle", 0.3)
		velocity.x = 0
		velocity.z = 0
		apply_gravity_and_slide(delta)
		return
	_combat_state(delta)
	if roll_t > 0.0:
		roll_t -= delta
		velocity.x = roll_dir.x * 13.0
		velocity.z = roll_dir.z * 13.0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	if mantle_t > 0.0:
		mantle_t -= delta
		move_and_slide()
		if mantle_t <= 0.0:
			velocity = Vector3.ZERO
		return
	var dir := _input_dir()
	var ml := minf(move_input.length(), 1.0)
	# sprint : joystick poussé à fond un court instant
	if ml > 0.9:
		sprint_t += delta
	else:
		sprint_t = 0.0
	sprinting = sprint_t > 0.45 and not climbing
	speed_fx.emitting = sprinting and is_on_floor()
	if climbing:
		_climb(delta, dir)
		return
	# mur devant pendant un saut / sprint : on grimpe (course murale)
	if dir != Vector3.ZERO and (airborne or sprinting) and _wall_ahead(dir, 1.1) and velocity.y > -6.0:
		climbing = true
		airborne = true
		wall_leaps = 0
		air_jumps = 1
		play("ClimbLoop", 0.08, 1.6, true)
		main.sfx("cloth", global_position)
		return
	var target_spd := (sprint_speed() if sprinting else (run_speed() if ml > 0.55 else 3.2)) * (1.0 if busy <= 0.0 else 0.0)
	if dir != Vector3.ZERO and hit_stun <= 0.0 and (busy <= 0.0 or airborne):
		var accel := 60.0 if is_on_floor() else 22.0
		velocity.x = move_toward(velocity.x, dir.x * target_spd, accel * delta)
		velocity.z = move_toward(velocity.z, dir.z * target_spd, accel * delta)
		face_to(global_position + dir, false, delta * 1.6)
	elif busy <= 0.0:
		var dec := 70.0 if is_on_floor() else 6.0
		velocity.x = move_toward(velocity.x, 0, dec * delta)
		velocity.z = move_toward(velocity.z, 0, dec * delta)
	velocity.y -= GRAVITY * delta
	fall_peak_v = minf(fall_peak_v, velocity.y)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(60.0)
	var hv := Vector3(velocity.x, 0, velocity.z)
	move_and_slide()
	_step_up(hv)
	if global_position.y < -40:
		global_position = main.spawn_point + Vector3(0, 2, 0)
	# atterrissage scénarisé
	if airborne and is_on_floor() and velocity.y <= 0.1:
		airborne = false
		air_jumps = 1
		if plunging:
			_plunge_impact()
		main.sfx("land", global_position, -6.0 if fall_peak_v > -8.0 else 0.0)
		if fall_peak_v < -17.0:
			play("Roll", 0.04, 2.4, true)
			busy = 0.35
			roll_dir = forward()
			roll_t = 0.25
			FX.burst(main, global_position, Color(0.8, 0.85, 1.0), 26, 0.1, 4.0, 0.5, 6.0)
			main.shake(0.25)
		elif fall_peak_v < -8.0:
			play("JumpLand", 0.04, 2.6, true)
			busy = 0.12
			FX.burst(main, global_position, Color(0.8, 0.85, 1.0), 10, 0.07, 2.0, 0.4, 5.0)
		fall_peak_v = 0.0
	elif not is_on_floor() and not airborne and velocity.y < -3.0:
		airborne = true
	# animation de déplacement
	if busy <= 0.0 and hit_stun <= 0.0:
		if airborne:
			if cur_anim != "JumpStart" and cur_anim != "Roll":
				play("JumpLoop", 0.15)
		elif dir != Vector3.ZERO:
			if sprinting:
				play("Sprint", 0.12, 1.25)
			elif ml > 0.55:
				play("Run", 0.12, 1.25)
			else:
				play("Walk", 0.15, 1.2)
		else:
			play("SwordIdle" if armed else "Idle", 0.2)

func _input_dir() -> Vector3:
	if move_input.length() < 0.12:
		return Vector3.ZERO
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	return (right * move_input.x - fwd * move_input.y).normalized()

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q)

func _wall_ahead(dir: Vector3, h: float) -> bool:
	var hit := _ray(global_position + Vector3(0, h, 0), global_position + Vector3(0, h, 0) + dir * 0.95)
	if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.3:
		wall_n = hit["normal"]
		return true
	return false

## Mur le plus proche autour du héros (pour le rebond mural en l'air).
func _any_wall() -> bool:
	for k in 8:
		var a := k * TAU / 8.0
		if _wall_ahead(Vector3(sin(a), 0, cos(a)), 1.0):
			return true
	return false

## Course verticale le long du mur, puis rétablissement sur le toit.
func _climb(_delta: float, dir: Vector3) -> void:
	if cur_anim == "Roll" and ap.is_playing() and velocity.y > 4.0:
		velocity.y -= GRAVITY * _delta
		move_and_slide()
		return
	var into := dir != Vector3.ZERO and _wall_ahead(dir, 1.1)
	if not into:
		climbing = false
		velocity.y = maxf(velocity.y, 2.0)
		return
	face_to(global_position + dir, true)
	if not _wall_ahead(dir, 2.1):
		climbing = false
		play("Climb", 0.05, 1.8, true)
		velocity = Vector3(0, 6.5, 0) + dir * 4.0
		mantle_t = 0.32
		main.quest_add("climb", 1)
		later(0.33, _after_mantle)
		return
	if velocity.y < 8.5 * (1.0 + 0.04 * stats["agilite"]):
		velocity = Vector3(0, 8.5 * (1.0 + 0.04 * stats["agilite"]), 0) + dir * 0.6
	else:
		velocity.y -= GRAVITY * 0.5 * _delta
		velocity += dir * 0.3
	if cur_anim != "ClimbLoop" and cur_anim != "Roll":
		play("ClimbLoop", 0.08, 1.6, true)
	move_and_slide()

func _after_mantle() -> void:
	FX.burst(main, global_position, Color(0.8, 0.85, 1.0), 12, 0.07, 2.0, 0.4, 5.0)

func _step_up(hv: Vector3) -> void:
	if hv.length() > 0.4 and is_on_wall():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var n := c.get_normal()
			var h := c.get_position().y - global_position.y
			if n.y < 0.86 and h > 0.02 and h < STEP_H and hv.normalized().dot(-Vector3(n.x, 0, n.z).normalized()) > 0.3:
				var up := Vector3(0, STEP_H + 0.05, 0)
				var fw := hv.normalized() * 0.18
				if not test_move(global_transform, up) and not test_move(global_transform.translated(up), fw):
					global_position += up + fw
					apply_floor_snap()
				break

# ============================================================ combat : état armé
func _combat_state(delta: float) -> void:
	var e := nearest_enemy(14.0)
	if e:
		calm_t = 0.0
		domain_ring.visible = true
		if not unarmed_mode and not armed and e.global_position.distance_to(global_position) < 10.0:
			set_armed(true)
	else:
		calm_t += delta
		if calm_t > 5.0 and armed:
			set_armed(false)
		if calm_t > 2.0:
			domain_ring.visible = false

func nearest_enemy(r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for u in main.units_of_team(1):
		var e := u as Unit
		if e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best

func focus_or_nearest(r: float) -> Unit:
	var f = main.focus_target
	if f != null and is_instance_valid(f) and not (f as Unit).dead and (f as Unit).global_position.distance_to(global_position) < r:
		return f as Unit
	return nearest_enemy(r)

# ============================================================ saut / esquive
func jump() -> void:
	if dead or cd["jump"] > 0.0 or main.in_dialogue:
		return
	if climbing:
		var d := _input_dir()
		if d != Vector3.ZERO and d.dot(-wall_n) > 0.4 and wall_leaps < 3:
			# bond vertical le long du mur
			wall_leaps += 1
			velocity = Vector3(0, 15.0 * (1.0 + 0.03 * stats["agilite"]), 0) - wall_n * 0.5
			play("Roll", 0.03, 2.4, true)
			main.sfx("jump", global_position, -4.0)
			FX.burst(main, global_position + Vector3(0, 1.0, 0) - wall_n * 0.3, Color(0.8, 0.85, 1.0), 14, 0.07, 2.0, 0.4, 3.0)
			cd["jump"] = CD_MAX["jump"]
			return
		_wall_kick()
		return
	if airborne and _any_wall():
		_wall_kick()
		return
	if is_on_floor() and not airborne:
		velocity.y = 9.0 * (1.0 + 0.03 * stats["agilite"])
		airborne = true
		busy = 0.0
		cd["jump"] = CD_MAX["jump"]
		play("JumpStart", 0.04, 2.6, true)
		main.sfx("jump", global_position, -8.0)
		FX.burst(main, global_position + Vector3(0, 0.1, 0), Color(0.7, 0.8, 1.0), 10, 0.06, 2.0, 0.4, 4.0)
	elif air_jumps > 0:
		air_jumps -= 1
		velocity.y = 8.5
		var d := _input_dir()
		if d != Vector3.ZERO:
			velocity.x = d.x * sprint_speed() * 0.8
			velocity.z = d.z * sprint_speed() * 0.8
		cd["jump"] = CD_MAX["jump"]
		play("Roll", 0.03, 2.6, true)
		main.sfx("dash", global_position, -8.0)
		FX.burst(main, global_position + Vector3(0, 0.8, 0), Color(0.6, 0.5, 1.0), 16, 0.07, 2.5, 0.4, 0.0)

## Rebond mural : on se repousse du mur, double saut rechargé (enchaînement entre deux murs).
func _wall_kick() -> void:
	climbing = false
	var out := wall_n
	out.y = 0
	out = out.normalized()
	velocity = out * 9.5 + Vector3(0, 10.5, 0)
	air_jumps = 1
	face_to(global_position + out, true)
	play("Roll", 0.03, 2.4, true)
	main.sfx("jump", global_position, -4.0)
	FX.burst(main, global_position + Vector3(0, 1.0, 0), Color(0.8, 0.85, 1.0), 14, 0.07, 2.5, 0.4, 3.0)
	cd["jump"] = CD_MAX["jump"]

func roll() -> void:
	if dead or cd["roll"] > 0.0 or roll_t > 0.0 or main.in_dialogue:
		return
	perfect_window = 0.25 if powers["perfect"] > 0 else 0.0
	cd["roll"] = CD_MAX["roll"]
	var dir := _input_dir()
	if dir == Vector3.ZERO:
		dir = forward()
	roll_dir = dir
	roll_t = 0.3
	invuln = 0.4
	busy = 0.38
	face_to(global_position + dir, true)
	play("Roll", 0.03, 3.0, true)
	main.sfx("cloth", global_position)
	main.sfx("dash", global_position, -6.0)
	FX.trail(main, global_position, global_position + dir * 4.0, Color(0.6, 0.8, 1.0))

func equip_blade() -> void:
	var holder := sword.get_parent()
	sword.queue_free()
	sword = (load("res://assets/sl_sword.glb") as PackedScene).instantiate()
	holder.add_child(sword)
	blade_mult = 1.45

# ============================================================ attaque (combo rapide, ruée vers la cible)
func attack() -> void:
	if dead or cd["attack"] > 0.0 or busy > 0.12 or main.in_dialogue:
		return
	if not unarmed_mode:
		set_armed(true)
	calm_t = 0.0
	if airborne and not climbing and powers["plunge"] > 0 and not plunging:
		var below := _ray(global_position, global_position + Vector3(0, -40, 0))
		if below.is_empty() or global_position.y - (below["position"] as Vector3).y > 1.6:
			plunging = true
			velocity = Vector3(velocity.x * 0.3, -30.0, velocity.z * 0.3)
			play("Slash3", 0.03, 2.2, true)
			main.sfx("dash", global_position)
			FX.trail(main, global_position, global_position + Vector3(0, -6, 0), Color(0.55, 0.8, 1.0))
			cd["attack"] = 0.5
			return
	var t := focus_or_nearest(8.0)
	if t:
		face_to(t.global_position, true)
		if not in_reach(t):
			var d := t.global_position - global_position
			d.y = 0
			var dest := global_position + d.normalized() * maxf(gap_to(t) - arm * 0.6, 0.0)
			FX.trail(main, global_position, dest, Color(0.55, 0.8, 1.0))
			var tw := create_tween()
			tw.tween_property(self, "global_position", Vector3(dest.x, global_position.y, dest.z), 0.09)
	if combo_t <= 0.0:
		combo = 0
	combo = (combo % 3) + 1
	combo_t = 0.9
	var a := ("Punch%d" if unarmed_mode else "Slash%d") % combo
	var l := anim_len(a)
	var spd := atk_speed() * (1.0 if combo < 3 else 1.35)
	if unarmed_mode:
		spd *= 1.4
	busy = l / spd * (0.7 if combo < 3 else 0.55)
	cd["attack"] = CD_MAX["attack"] / (1.0 + 0.07 * stats["vitesse"])
	play(a, 0.04, spd, true)
	main.sfx(("swing%d" % combo) if not unarmed_mode else "cloth", global_position, -3.0)
	regen_t = 5.0
	later(l / spd * (0.35 if combo < 3 else 0.4), _slash_hit.bind(combo))

func _slash_hit(c: int) -> void:
	var col := Color(0.55, 0.8, 1.0) if not unarmed_mode else Color(1.0, 0.85, 0.6)
	FX.slash_arc(main, global_position, model.rotation.y, col, body_r + arm + 0.5, c == 2)
	var mult := 1.0 if c < 3 else 1.9
	var crit := c == 3
	if counter_ready:
		counter_ready = false
		mult *= 2.5
		crit = true
		FX.damage_number(main, global_position + Vector3(0, 0.7, 0), "CONTRE !", Color(0.6, 0.85, 1.0), true)
	var hits := 0
	for u in main.units_of_team(1):
		var e := u as Unit
		if e.dead:
			continue
		var to := e.global_position - global_position
		to.y = 0
		var ang := forward().angle_to(to.normalized())
		if gap_to(e) <= arm + 0.6 and ang < deg_to_rad(80 if c < 3 else 120):
			e.take_damage(power() * mult * randf_range(0.9, 1.1), self, crit)
			if c == 3:
				e.velocity += to.normalized() * 7.0 + Vector3(0, 3.0, 0)
			hits += 1
	if hits > 0:
		main.sfx("hit%d" % (1 + randi() % 3), global_position, 0.0 if c < 3 else 3.0)
		if not unarmed_mode:
			main.sfx("clang", global_position, -10.0)
		main.shake(0.1 if c < 3 else 0.22)
		main.hit_stop(0.05 if c < 3 else 0.09)
		main.fov_kick(4.0 if c < 3 else 8.0)

func _plunge_impact() -> void:
	plunging = false
	busy = 0.3
	var r: float = 3.6 + 0.4 * powers["plunge"]
	FX.burst(main, global_position, Color(0.55, 0.8, 1.0), 50, 0.14, 7.0, 0.6, 8.0)
	FX.telegraph(main, global_position, r, 0.15, Color(0.5, 0.8, 1.0))
	main.sfx("slam", global_position)
	main.shake(0.4)
	main.fov_kick(10.0)
	for u in main.units_of_team(1):
		var e := u as Unit
		if e.dead or e.global_position.distance_to(global_position) > r + e.body_r:
			continue
		var to := e.global_position - global_position
		to.y = 0
		e.take_damage(power() * (2.0 + 0.3 * powers["plunge"]), self, true)
		e.velocity += to.normalized() * 8.0 + Vector3(0, 4.0, 0)
	main.hit_stop(0.08)

## Esquive parfaite : ralenti, et le prochain coup est un contre dévastateur.
func on_dodged(_from: Unit) -> void:
	if perfect_window > 0.0:
		perfect_window = 0.0
		counter_ready = true
		FX.damage_number(main, global_position + Vector3(0, 0.9, 0), "ESQUIVE PARFAITE", Color(0.6, 0.9, 1.0), true)
		FX.burst(main, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.75, 1.0), 30, 0.08, 3.0, 0.5, 0.0)
		main.sfx("shadow", global_position)
		main.slow_mo(0.3, 0.7)
		print("PERFECT_DODGE")

# ============================================================ Autorité du Souverain (télékinésie)
func telekinesis() -> bool:
	if powers["tele"] <= 0 or not ready_skill("tele") or busy > 0.3 or main.in_dialogue:
		return false
	var lvl: int = powers["tele"]
	var r := 9.0 + lvl * 1.5
	var list: Array = []
	for u in main.units_of_team(1):
		var e := u as Unit
		if e.dead or e.global_position.distance_to(global_position) > r:
			continue
		var to := e.global_position - global_position
		to.y = 0
		if forward().angle_to(to.normalized()) < deg_to_rad(75) or to.length() < 3.0:
			list.append(e)
	if list.is_empty():
		main.system_msg("Aucune cible devant toi.")
		return false
	cd["tele"] = CD_MAX["tele"] - lvl
	mp -= MP_COST["tele"]
	busy = 1.45
	invuln = 0.3
	play("Telekinesis", 0.08, 1.0, true)
	main.sfx("shadow", global_position, 2.0)
	main.quest_add("skills", 1)
	FX.damage_number(main, global_position + Vector3(0, 0.7, 0), "AUTORITÉ DU SOUVERAIN", Color(0.65, 0.5, 1.0), false)
	for e in list:
		_lift(e as Unit, lvl)
	return true

func _lift(e: Unit, lvl: int) -> void:
	var start := e.global_position
	var top := start + Vector3(0, 2.8 if not (e is Mob and (e as Mob).boss) else 0.8, 0)
	e.lifted = true
	e.busy = 1.6
	e.hit_stun = 1.6
	e.velocity = Vector3.ZERO
	var aura := FX.ground_disc(e.body_r + 0.6, Color(0.6, 0.3, 1.0), 0.5, true)
	main.add_child(aura)
	aura.global_position = start + Vector3(0, 0.05, 0)
	FX.burst(main, start + Vector3(0, 0.5, 0), Color(0.6, 0.3, 1.0), 20, 0.08, 2.0, 0.6, -2.0)
	var tw := e.create_tween()
	tw.tween_property(e, "global_position", top, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(e.model, "rotation:x", deg_to_rad(randf_range(-35, 35)), 0.45)
	tw.tween_interval(0.65)
	tw.tween_property(e, "global_position", start, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(e.model, "rotation:x", 0.0, 0.16)
	tw.tween_callback(_lift_slam.bind(e, lvl, aura))

func _lift_slam(e: Unit, lvl: int, aura: Node3D) -> void:
	aura.queue_free()
	if not is_instance_valid(e):
		return
	e.lifted = false
	FX.burst(main, e.global_position, Color(0.6, 0.35, 1.0), 30, 0.12, 5.0, 0.5, 8.0)
	main.sfx("slam", e.global_position, -2.0)
	main.shake(0.25)
	if not e.dead:
		e.take_damage(power() * (1.6 + 0.3 * lvl), self, true)

# ============================================================ Échange d'ombre
func shadow_swap() -> bool:
	if powers["swap"] <= 0 or not ready_skill("swap") or main.in_dialogue:
		return false
	var sh: Array = main.shadow_list()
	if sh.is_empty():
		main.system_msg("Aucune ombre avec qui échanger.")
		return false
	var best := sh[0] as Mob
	var f = main.focus_target
	for m in sh:
		var mm := m as Mob
		if f != null and is_instance_valid(f):
			if mm.global_position.distance_to((f as Unit).global_position) < best.global_position.distance_to((f as Unit).global_position):
				best = mm
		elif mm.global_position.distance_to(global_position) > best.global_position.distance_to(global_position):
			best = mm
	cd["swap"] = CD_MAX["swap"] - 2.0 * (powers["swap"] - 1)
	mp -= MP_COST["swap"]
	var a := global_position
	var b := best.global_position
	FX.shadow_puff(main, a)
	FX.shadow_puff(main, b)
	FX.trail(main, a, b, Color(0.45, 0.15, 1.0))
	global_position = b + Vector3(0, 0.2, 0)
	best.global_position = a + Vector3(0, 0.2, 0)
	main.sfx("step_shadow", b)
	main.quest_add("skills", 1)
	return true

func power_cost(k: String) -> int:
	return 3 + 3 * int(powers[k])

func upgrade_power(k: String) -> bool:
	if powers[k] <= 0 or powers[k] >= 5 or main.essence < power_cost(k):
		return false
	main.essence -= power_cost(k)
	powers[k] += 1
	return true

# ============================================================ Pas de l'ombre : chaîne sur plusieurs ennemis
func shadow_step() -> bool:
	if not ready_skill("step") or busy > 0.3 or main.in_dialogue:
		return false
	var list: Array = []
	for u in main.units_of_team(1):
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(global_position) < domain_r():
			list.append(e)
	if list.is_empty():
		main.system_msg("Aucune cible dans ton domaine d'ombre.")
		return false
	var here := global_position
	list.sort_custom(func(a, b): return here.distance_to((a as Unit).global_position) < here.distance_to((b as Unit).global_position))
	var n := mini(list.size(), 2 + int(powers["step"]) + int(stats["domaine"] / 2) + int(stats["agilite"] / 3))
	if not unarmed_mode:
		set_armed(true)
	cd["step"] = CD_MAX["step"]
	mp -= MP_COST["step"]
	regen_t = 5.0
	invuln = 0.2 + n * 0.16
	busy = 0.15 + n * 0.16
	FX.shadow_puff(main, global_position)
	main.sfx("shadow", global_position)
	main.quest_add("skills", 1)
	model.visible = false
	for k in n:
		later(0.08 + k * 0.16, _step_hop.bind(list[k], k == n - 1))
	return true

func _step_hop(t: Unit, last: bool) -> void:
	if t == null or not is_instance_valid(t):
		model.visible = true
		return
	var start := global_position
	var behind := t.global_position - t.forward() * (t.body_r + body_r + arm * 0.55)
	behind.y = t.global_position.y
	FX.trail(main, start, behind, Color(0.45, 0.15, 1.0))
	global_position = behind
	face_to(t.global_position, true)
	model.visible = true
	FX.shadow_puff(main, behind)
	play("Dash", 0.0, 3.0, true)
	main.sfx("step_shadow", behind, -4.0)
	main.sfx("hit%d" % (1 + randi() % 3), behind)
	FX.slash_arc(main, global_position, model.rotation.y, Color(0.6, 0.3, 1.0), body_r + arm + 0.6, randf() < 0.5)
	if not t.dead:
		t.take_damage(power() * (2.1 + 0.2 * powers["step"]), self, true)
	main.shake(0.15)
	main.hit_stop(0.04)
	if last:
		FX.damage_number(main, global_position + Vector3(0, 0.6, 0), "PAS DE L'OMBRE", Color(0.7, 0.45, 1.0), false)
	else:
		later(0.1, _hide_model)

func _hide_model() -> void:
	model.visible = false

# ============================================================ Arise : relève tous les cadavres du domaine
func arise() -> bool:
	if not ready_skill("arise") or busy > 0.3 or main.in_dialogue:
		return false
	var corpses: Array = []
	for u in main.all_mobs():
		var m := u as Mob
		if m.dead and not m.arisen and m.corpse_time < 45.0 and m.kind != "guard" and m.global_position.distance_to(global_position) < domain_r():
			corpses.append(m)
	if corpses.is_empty():
		main.system_msg("Aucun cadavre dans ton domaine d'ombre.")
		return false
	var room: int = max_shadows() - int(main.shadow_count())
	var raised := 0
	cd["arise"] = CD_MAX["arise"] - (powers["arise"] - 1)
	mp -= MP_COST["arise"]
	busy = 1.0
	play("Cast", 0.06, 0.55, true)
	main.sfx("arise", global_position, 2.0)
	main.sfx("shadow", global_position)
	main.quest_add("skills", 1)
	FX.damage_number(main, global_position + Vector3(0, 0.6, 0), "ÉLÈVE-TOI.", Color(0.75, 0.5, 1.0), true)
	main.shake(0.15)
	for c in corpses:
		var m := c as Mob
		if raised >= room and not m.boss:
			continue
		raised += 1
		FX.arise_pillar(main, m.global_position)
		later(0.4 + raised * 0.12, _do_rise.bind(m))
	if raised == 0:
		main.system_msg("Ton armée d'ombres est au complet (%d/%d)." % [main.shadow_count(), max_shadows()])
	return true

func _do_rise(m: Mob) -> void:
	m.rise_as_shadow()
	main.on_shadow_raised(m)

func on_hit(_from: Unit) -> void:
	regen_t = 6.0
	main.shake(0.1)
	if busy <= 0.0 and not climbing and not airborne:
		hit_stun = 0.15
		play("Hit", 0.04, 1.6, true)

func die() -> void:
	super.die()
	main.on_hero_died()
