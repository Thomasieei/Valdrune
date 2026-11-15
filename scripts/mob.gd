class_name Mob
extends Unit
## Monstres (team 1) et ombres invoquées (team 0). IA : garde -> poursuite -> combat -> retour.

var kind := "goblin"          # goblin / shaman / orc
var home := Vector3.ZERO
var aggro_r := 11.0
var leash_r := 26.0
var target: Unit
var main                      # référence au script principal (listes d'unités)
var atk_cd := 0.0
var atk_rate := 1.5
var skill_cd := 4.0
var skill2_cd := 8.0
var is_shadow := false
var corpse_time := 0.0
var arisen := false
var wander_t := 0.0
var wander_to := Vector3.ZERO
var pending: Array = []       # [temps, Callable]

func configure(k: String, shadow := false) -> void:
	kind = k
	is_shadow = shadow
	team = 0 if shadow else 1
	match kind:
		"goblin":
			display_name = "Gobelin"
			max_hp = 90; dmg = 9; speed = 3.7; body_r = 0.42; arm = 0.7; atk_rate = 1.4
			setup_model("res://assets/goblin.glb", 1.25, Color(1, 0.12, 0.1), 0.16)
		"shaman":
			display_name = "Gobelin chaman"
			max_hp = 65; dmg = 12; speed = 3.3; body_r = 0.42; arm = 0.7; atk_rate = 2.6
			setup_model("res://assets/goblin.glb", 1.15, Color(1, 0.12, 0.1), 0.16)
			_tint(Color(0.55, 1.0, 0.55), Color(0.1, 0.6, 0.2))
		"orc":
			display_name = "Orc brute"
			rank = "E+"
			max_hp = 320; dmg = 20; speed = 2.9; body_r = 0.75; arm = 0.9; atk_rate = 2.1
			setup_model("res://assets/orc.glb", 0.088, Color(1, 0.12, 0.1), 0.16)
			_hide_orc_weapon()
	hp = max_hp
	if shadow:
		_make_shadow()
		max_hp *= 0.8
		hp = max_hp
	make_hp_bar(2.15 if kind != "orc" else 2.75, Color(0.6, 0.35, 1.0) if shadow else Color(0.95, 0.2, 0.2))
	skill_cd = randf_range(2.0, 5.0)
	skill2_cd = randf_range(6.0, 10.0)
	play("Idle", 0.0)
	if ap:
		ap.seek(randf() * 1.5, true)

func _hide_orc_weapon() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var aabb := m.get_aabb()
		# l'arme (glaive) est un maillage long et fin séparé du corps
		if aabb.size.x > aabb.size.y * 1.6 or aabb.size.z > aabb.size.y * 1.6:
			m.visible = false

func _tint(albedo_mul: Color, glow: Color) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			var d := src.duplicate() as StandardMaterial3D
			d.albedo_color = d.albedo_color * albedo_mul
			d.emission_enabled = true
			d.emission = glow
			d.emission_energy_multiplier = 0.35
			m.set_surface_override_material(i, d)

func _make_shadow() -> void:
	display_name = "Ombre " + display_name.to_lower()
	rank = "Ombre"
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.06, 0.03, 0.12)
	sm.emission_enabled = true
	sm.emission = Color(0.35, 0.1, 0.85)
	sm.emission_energy_multiplier = 0.55
	sm.rim_enabled = true
	sm.rim = 1.0
	sm.rim_tint = 0.2
	sm.roughness = 0.4
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.visible:
			m.material_override = sm
	(ring.material_override as StandardMaterial3D).albedo_color = Color(0.55, 0.2, 1.0, 0.2)
	var eye := OmniLight3D.new()
	eye.light_color = Color(0.5, 0.2, 1)
	eye.light_energy = 1.2
	eye.omni_range = 2.5
	eye.position = Vector3(0, 1.6, 0.3)
	add_child(eye)

func later(t: float, c: Callable) -> void:
	pending.append([t, c])

func _physics_process(delta: float) -> void:
	for i in range(pending.size() - 1, -1, -1):
		pending[i][0] -= delta
		if pending[i][0] <= 0.0:
			var c: Callable = pending[i][1]
			pending.remove_at(i)
			if not dead:
				c.call()
	if dead:
		corpse_time += delta
		apply_gravity_and_slide(delta)
		return
	atk_cd -= delta
	skill_cd -= delta
	skill2_cd -= delta
	busy -= delta
	hit_stun -= delta
	_think(delta)
	apply_gravity_and_slide(delta)

func _enemies() -> Array:
	return main.units_of_team(1 - team)

func _nearest_enemy(r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for u in _enemies():
		var e := u as Unit
		if e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best

func _think(delta: float) -> void:
	if busy > 0.0 or hit_stun > 0.0:
		return
	if target and (target.dead or (not is_shadow and target.global_position.distance_to(home) > leash_r + 6.0)):
		target = null
	if target == null:
		target = _nearest_enemy(aggro_r if not is_shadow else 14.0)
	if target == null:
		_idle_behaviour(delta)
		return
	var d := global_position.distance_to(target.global_position)
	if not is_shadow and global_position.distance_to(home) > leash_r:
		target = null
		return
	face_to(target.global_position, false, delta)
	if _try_skills(d):
		return
	var want_gap := arm * 0.8
	if kind == "shaman" and not is_shadow:
		want_gap = 5.5
	var gap := gap_to(target)
	if gap > want_gap + 0.25:
		_move_towards(target.global_position, speed * (1.25 if gap > 4.0 else 1.0), delta)
	elif kind == "shaman" and not is_shadow and gap < 3.5:
		_move_towards(global_position + (global_position - target.global_position), speed, delta)
	else:
		play("Idle", 0.2)
		if in_reach(target) and atk_cd <= 0.0:
			_basic_attack()

func _idle_behaviour(delta: float) -> void:
	if is_shadow and main.hero:
		var h: Unit = main.hero
		var slot := h.global_position + Vector3(sin(get_instance_id() % 7), 0, cos(get_instance_id() % 7)) * 2.6
		if global_position.distance_to(slot) > 1.2:
			_move_towards(slot, maxf(speed, global_position.distance_to(slot) * 1.3), delta)
		else:
			play("Idle", 0.25)
			face_to(h.global_position + h.forward() * 5.0, false, delta)
		return
	if global_position.distance_to(home) > 2.0:
		_move_towards(home, speed * 0.7, delta)
		return
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(3.0, 7.0)
		wander_to = home + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	if global_position.distance_to(wander_to) > 0.6:
		_move_towards(wander_to, speed * 0.35, delta)
	else:
		play("Idle", 0.3)

func _move_towards(p: Vector3, spd: float, delta: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.05:
		return
	d = d.normalized()
	velocity.x = d.x * spd
	velocity.z = d.z * spd
	face_to(global_position + d, false, delta)
	play("Run" if spd > speed * 0.9 else "Walk", 0.2, clampf(spd / 3.5, 0.7, 1.4))

func _basic_attack() -> void:
	atk_cd = atk_rate
	var a := "Attack"
	if kind == "goblin" and randf() < 0.35:
		a = "Attack2"
	if kind == "shaman" and not is_shadow:
		a = "Attack2"
	var l := anim_len(a)
	busy = l * 0.95
	play(a, 0.08, 1.0, true)
	later(l * 0.45, _basic_hit.bind(target))

func _basic_hit(t: Unit) -> void:
	if t and not t.dead and in_reach(t, 0.35):
		t.take_damage(dmg * randf_range(0.85, 1.15), self)
		FX.slash_arc(main, global_position, model.rotation.y, Color(1, 0.35, 0.2) if team == 1 else Color(0.6, 0.3, 1.0), body_r + arm, randf() < 0.5)

## Sorts spécifiques à chaque monstre. Renvoie true si un sort part.
func _try_skills(d: float) -> bool:
	match kind:
		"goblin":
			# Bond sauvage : saute sur la cible et frappe la zone
			if skill_cd <= 0.0 and d > 3.5 and d < 10.0:
				skill_cd = 7.5
				var spot := target.global_position
				FX.telegraph(main, spot, 1.7, 0.75)
				busy = 1.35
				face_to(spot, true)
				play("Leap", 0.08, 1.0, true)
				later(0.45, _leap_to.bind(spot))
				return true
		"shaman":
			# Orbe de feu (projectile)
			if skill_cd <= 0.0 and d < 13.0:
				skill_cd = 3.4
				busy = 0.7
				play("Cast", 0.08, 1.0, true)
				later(0.3, _fire_orb.bind(target))
				return true
			# Flaque toxique : zone au sol qui fait des dégâts
			if skill2_cd <= 0.0 and d < 12.0:
				skill2_cd = 9.0
				busy = 0.9
				play("Cast", 0.08, 0.8, true)
				var spot := target.global_position
				FX.telegraph(main, spot, 2.2, 1.1, Color(0.4, 1.0, 0.2))
				later(1.1, _poison_pool.bind(spot))
				return true
		"orc":
			# Fracas : coup au sol devant lui, zone rouge
			if skill_cd <= 0.0 and d < 4.5:
				skill_cd = 8.0
				busy = 1.9
				play("Slam", 0.1, 1.6, true)
				var spot := global_position + forward() * 1.8
				FX.telegraph(main, spot, 2.6, 1.0)
				later(1.0, _slam.bind(spot))
				return true
			# Rugissement : enragé sous 50 % PV
			if skill2_cd <= 0.0 and hp < max_hp * 0.5:
				skill2_cd = 16.0
				busy = 0.8
				play("Roar", 0.1, 0.7, true)
				speed *= 1.35
				atk_rate *= 0.7
				FX.burst(main, global_position + Vector3(0, 1.5, 0), Color(1, 0.2, 0.1), 40, 0.2, 5.0, 0.7, 0.0)
				FX.damage_number(main, global_position + Vector3(0, 0.6, 0), "ENRAGÉ", Color(1, 0.3, 0.2), true)
				return true
	return false

func _leap_to(spot: Vector3) -> void:
	var start := global_position
	var dir := spot - start
	dir.y = 0
	var land := spot - dir.normalized() * (body_r + 0.6)
	var tw := create_tween()
	tw.tween_method(_leap_step.bind(start, land), 0.0, 1.0, 0.4)
	tw.tween_callback(_leap_land.bind(spot))

func _leap_step(f: float, start: Vector3, land: Vector3) -> void:
	var p := start.lerp(land, f)
	p.y = start.y + sin(f * PI) * 2.0
	global_position = p

func _leap_land(spot: Vector3) -> void:
	if dead:
		return
	FX.burst(main, spot, Color(1, 0.4, 0.2), 30, 0.12, 4.0, 0.5, 6.0)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(spot) < 1.7 + e.body_r:
			e.take_damage(dmg * 1.6, self)
	main.shake(0.15)

func _fire_orb(t: Unit) -> void:
	if t == null or t.dead:
		return
	var o := FX.orb(main, global_position + Vector3(0, 1.3, 0) + forward() * 0.5, Color(1, 0.45, 0.1))
	var tw := o.create_tween()
	var dest := t.global_position + Vector3(0, 1.0, 0)
	var tt := clampf(o.global_position.distance_to(dest) / 14.0, 0.2, 1.0)
	tw.tween_property(o, "global_position", dest, tt)
	tw.tween_callback(_orb_hit.bind(o, t, dest))

func _orb_hit(o: Node3D, t: Unit, dest: Vector3) -> void:
	FX.burst(main, o.global_position, Color(1, 0.5, 0.1), 20, 0.1, 3.0, 0.4, 3.0)
	if t and not t.dead and t.global_position.distance_to(dest - Vector3(0, 1, 0)) < 1.6 + t.body_r:
		t.take_damage(dmg, self)
	o.queue_free()

func _poison_pool(spot: Vector3) -> void:
	var pool := FX.ground_disc(2.2, Color(0.35, 1.0, 0.15), 0.45, false)
	main.add_child(pool)
	pool.global_position = spot + Vector3(0, 0.06, 0)
	for k in 6:
		later(0.5 * k, _poison_tick.bind(spot))
	var tw := pool.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(pool, "scale", Vector3(0.01, 1, 0.01), 0.3)
	tw.tween_callback(pool.queue_free)

func _poison_tick(spot: Vector3) -> void:
	FX.burst(main, spot, Color(0.4, 1.0, 0.2), 6, 0.08, 1.0, 0.6, -1.0)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(spot) < 2.2:
			e.take_damage(dmg * 0.3, self)

func _slam(spot: Vector3) -> void:
	FX.burst(main, spot, Color(1, 0.55, 0.25), 45, 0.18, 5.0, 0.6, 9.0)
	main.shake(0.35)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(spot) < 2.6 + e.body_r:
			e.take_damage(dmg * 1.8, self)

func on_hit(from: Unit) -> void:
	if target == null and from:
		target = from
	super.on_hit(from)

## Relève par l'Arise : le cadavre se relève en ombre.
func rise_as_shadow() -> void:
	arisen = true
	dead = false
	is_shadow = true
	team = 0
	display_name = display_name.replace("Ombre ", "")
	_make_shadow()
	max_hp = max_hp * 0.8
	hp = max_hp
	if hp_bar:
		hp_bar.queue_free()
	make_hp_bar(2.15 if kind != "orc" else 2.75, Color(0.6, 0.35, 1.0))
	ring.visible = true
	collision_layer = 2
	collision_mask = 1 | 2
	target = null
	busy = 1.6
	if ap and ap.has_animation("Death"):
		cur_anim = "Death"
		ap.play_backwards("Death", 0.0)
		ap.speed_scale = 1.6
	later(1.6, play.bind("Idle", 0.2, 1.0, true))
