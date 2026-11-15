class_name Hero
extends Unit
## Le Chasseur : épée, Pas de l'ombre, Arise.

const RUN := 6.2
const WALK := 3.0
var mp := 100.0
var max_mp := 100.0
var move_input := Vector2.ZERO
var cam_yaw := 0.0
var main
var combo := 0
var combo_t := 0.0
var cd := {"attack": 0.0, "step": 0.0, "arise": 0.0}
const CD_MAX := {"attack": 0.42, "step": 6.0, "arise": 9.0}
const MP_COST := {"step": 18.0, "arise": 30.0}
var pending: Array = []
var regen_t := 0.0
var sword: Node3D

func setup_hero() -> void:
	display_name = "Chasseur"
	max_hp = 420; hp = max_hp; dmg = 26; body_r = 0.45; arm = 0.85; speed = RUN
	setup_model("res://assets/hero.glb", 1.0, Color(1, 1, 1), 0.2)
	_attach_sword()
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.78, 0.86, 1.0)
	fill.light_energy = 1.3
	fill.omni_range = 9.0
	fill.position = Vector3(0, 2.6, 0)
	add_child(fill)
	play("Idle", 0.0)

func _attach_sword() -> void:
	var skel_list := model.find_children("*", "Skeleton3D", true, false)
	if skel_list.is_empty():
		return
	var sk := skel_list[0] as Skeleton3D
	var bi := -1
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i)
		if bn.ends_with("RightHand") or bn.contains("RightHand_"):
			if not (bn.contains("Thumb") or bn.contains("Index") or bn.contains("Middle") or bn.contains("Ring") or bn.contains("Pinky")):
				bi = i
				break
	if bi < 0:
		print("SWORD: main droite introuvable")
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_idx = bi
	var mount := Node3D.new()
	att.add_child(mount)
	sword = (load("res://assets/katana.glb") as PackedScene).instantiate()
	mount.add_child(sword)
	# lame dans l'axe de la main ; ajustée via les captures CI
	# compense l'échelle du squelette (souvent en centimètres)
	var gs := sk.global_transform.basis.get_scale().x
	var s := 1.0 / maxf(gs, 0.0001)
	mount.scale = Vector3.ONE * s * 0.95
	mount.rotation_degrees = Vector3(0, 0, 90)
	mount.position = Vector3(0, 0.09, 0.03) * s
	print("SWORD scale comp ", s)
	print("SWORD: attachée à ", sk.get_bone_name(bi))

func later(t: float, c: Callable) -> void:
	pending.append([t, c])

func ready_skill(k: String) -> bool:
	return cd[k] <= 0.0 and mp >= MP_COST.get(k, 0.0) and not dead

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
	mp = minf(max_mp, mp + 5.0 * delta)
	regen_t -= delta
	if regen_t <= 0.0 and hp < max_hp and not dead:
		hp = minf(max_hp, hp + 8.0 * delta)
	if dead:
		apply_gravity_and_slide(delta)
		return
	var ml := move_input.length()
	if busy <= 0.0 and hit_stun <= 0.0 and ml > 0.12:
		var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
		var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		var dir := (right * move_input.x - fwd * move_input.y).normalized()
		var spd := RUN if ml > 0.8 else WALK
		velocity.x = dir.x * spd * minf(ml, 1.0)
		velocity.z = dir.z * spd * minf(ml, 1.0)
		face_to(global_position + dir, false, delta)
		if ml > 0.8:
			play("Run", 0.18, 1.05)
		else:
			play("Walk", 0.18, clampf(ml * 1.8, 0.8, 1.4))
	elif busy <= 0.0 and hit_stun <= 0.0:
		play("SwordIdle" if combo_t > -3.0 else "Idle", 0.25)
	apply_gravity_and_slide(delta)

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

# ---------------------------------------------------------- attaque de base (combo 3 coups)
func attack() -> void:
	if dead or cd["attack"] > 0.0 or busy > 0.15:
		return
	var t := nearest_enemy(5.5)
	if t:
		face_to(t.global_position, true)
		# s'approche jusqu'à la portée d'un bras (jamais collé)
		if not in_reach(t):
			var gap := gap_to(t) - arm * 0.7
			var d := (t.global_position - global_position)
			d.y = 0
			var dest := global_position + d.normalized() * minf(gap, 2.5)
			var tw := create_tween()
			tw.tween_property(self, "global_position", dest, 0.12)
	if combo_t <= 0.0:
		combo = 0
	combo = (combo % 3) + 1
	combo_t = 1.1
	var a := "Slash%d" % combo
	var l := anim_len(a)
	var spd := 1.25 if combo < 3 else 1.6
	busy = l / spd * (0.75 if combo < 3 else 0.6)
	cd["attack"] = CD_MAX["attack"]
	play(a, 0.06, spd, true)
	regen_t = 5.0
	later(l / spd * (0.35 if combo < 3 else 0.42), _slash_hit.bind(combo))

func _slash_hit(c: int) -> void:
	FX.slash_arc(main, global_position, model.rotation.y, Color(0.55, 0.8, 1.0), body_r + arm + 0.5, c == 2)
	var mult := 1.0 if c < 3 else 1.8
	var hits := 0
	for u in main.units_of_team(1):
		var e := u as Unit
		if e.dead:
			continue
		var to := e.global_position - global_position
		to.y = 0
		var ang := forward().angle_to(to.normalized())
		if gap_to(e) <= arm + 0.55 and ang < deg_to_rad(75 if c < 3 else 110):
			e.take_damage(dmg * mult * randf_range(0.9, 1.1), self, c == 3)
			hits += 1
	if hits > 0:
		main.shake(0.08 if c < 3 else 0.18)
		main.hit_stop(0.04 if c < 3 else 0.07)

# ---------------------------------------------------------- Pas de l'ombre
func shadow_step() -> bool:
	if not ready_skill("step") or busy > 0.3:
		return false
	var t := nearest_enemy(14.0)
	if t == null:
		main.system_msg("Aucune cible à portée.")
		return false
	cd["step"] = CD_MAX["step"]
	mp -= MP_COST["step"]
	regen_t = 5.0
	var start := global_position
	var behind := t.global_position - t.forward() * (t.body_r + body_r + arm * 0.6)
	behind.y = t.global_position.y
	FX.shadow_puff(main, start)
	global_position = behind
	face_to(t.global_position, true)
	FX.trail(main, start, behind, Color(0.5, 0.2, 1.0))
	FX.shadow_puff(main, behind)
	busy = 0.75
	play("Dash", 0.03, 1.9, true)
	later(0.22, _backstab.bind(t))
	return true

func _backstab(t: Unit) -> void:
	if t == null or t.dead:
		return
	FX.slash_arc(main, global_position, model.rotation.y, Color(0.6, 0.3, 1.0), body_r + arm + 0.6, false)
	FX.damage_number(main, t.global_position + Vector3(0, 0.5, 0), "DANS LE DOS", Color(0.7, 0.45, 1.0), false)
	t.take_damage(dmg * 2.6, self, true)
	main.shake(0.2)
	main.hit_stop(0.08)

# ---------------------------------------------------------- Arise
func arise() -> bool:
	if not ready_skill("arise") or busy > 0.3:
		return false
	var corpse: Mob = null
	var bd := 9.0
	for u in main.all_mobs():
		var m := u as Mob
		if m.dead and not m.arisen and m.corpse_time < 40.0:
			var d := global_position.distance_to(m.global_position)
			if d < bd:
				bd = d
				corpse = m
	if corpse == null:
		main.system_msg("Aucun cadavre à relever à proximité.")
		return false
	if main.shadow_count() >= 4:
		main.system_msg("Ton armée d'ombres est au complet (4/4).")
		return false
	cd["arise"] = CD_MAX["arise"]
	mp -= MP_COST["arise"]
	busy = 1.1
	face_to(corpse.global_position, true)
	play("Cast", 0.08, 0.55, true)
	FX.damage_number(main, global_position + Vector3(0, 0.6, 0), "ÉLÈVE-TOI.", Color(0.75, 0.5, 1.0), true)
	FX.arise_pillar(main, corpse.global_position)
	main.shake(0.12)
	later(0.55, _do_rise.bind(corpse))
	return true

func _do_rise(m: Mob) -> void:
	m.rise_as_shadow()
	main.on_shadow_raised(m)

func on_hit(from: Unit) -> void:
	regen_t = 6.0
	main.shake(0.1)
	if busy <= 0.0:
		hit_stun = 0.18
		play("Hit", 0.05, 1.4, true)

func die() -> void:
	super.die()
	main.on_hero_died()
