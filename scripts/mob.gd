class_name Mob
extends Unit
## Monstres (team 1), ombres (team 0), gardes neutres (team 2), boss.
## IA : garde -> poursuite -> encerclement -> sorts -> repli / appel à l'aide.

var kind := "goblin"
var home := Vector3.ZERO
var aggro_r := 11.0
var leash_r := 26.0
var target: Unit
var main
var atk_cd := 0.0
var atk_rate := 1.5
var skill_cd := 4.0
var skill2_cd := 8.0
var skill3_cd := 6.0
var is_shadow := false
var elite := false
var boss := false
var dormant := false
var corpse_time := 0.0
var arisen := false
var wander_t := 0.0
var wander_to := Vector3.ZERO
var pending: Array = []
var talk_cd := 0.0
var flee_t := 0.0
var fled_once := false
var phase := 1
var patrol: Array = []
var patrol_i := 0
var reward_gold := 8
var combo_i := 0
var room_id := -1
var order := "auto"          # ombres : auto / attack / follow / hold
var hold_pos := Vector3.ZERO
var selected := true
var fought := false
var recover_t := 0.0
var moving := false

const LINES := {
	"aggro": ["Un humain ? Ici ? Quelle blague.", "Ta race n'est que nourriture.", "Approche, viande. Je vais t'apprendre ta place.", "Les humains rampent. Toi aussi, bientôt.", "Oh ? Le repas vient à nous."],
	"hit": ["Tu oses me toucher ?!", "Insecte !", "Ce n'est qu'une égratignure !", "Tu vas le regretter, humain.", "Pathétique... c'est tout ?"],
	"death": ["Impossible... un humain...", "Ce n'est... pas fini...", "Les autres... te dévoreront..."],
	"flee": ["À moi ! L'humain est fort !", "Repli ! Prévenez les autres !"],
	"orc": ["FAIBLE !", "JE VAIS T'ÉCRASER COMME UN VER !", "Un humain qui se croit guerrier... HA !"],
	"heal": ["Relève-toi, frère. Il n'est qu'humain.", "Les esprits nous soutiennent !"],
	"kill": ["Pathétique.", "Encore un humain de moins."],
}

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
			max_hp = 320; dmg = 20; speed = 2.9; body_r = 0.75; arm = 0.9; atk_rate = 2.1; reward_gold = 25
			setup_model("res://assets/orc.glb", 0.088, Color(1, 0.12, 0.1), 0.16)
			_hide_orc_weapon()
		"guard":
			display_name = "Garde de l'Association"
			rank = "C"
			max_hp = 380; dmg = 22; speed = 3.4; body_r = 0.45; arm = 0.8; atk_rate = 1.3
			setup_model("res://assets/guard.glb", 1.0, Color(0.3, 0.6, 1.0), 0.12)
			team = 2
		"igris":
			display_name = "Commandant Écarlate"
			rank = "BOSS"
			boss = true
			max_hp = 2400; dmg = 34; speed = 4.6; body_r = 0.75; arm = 1.25; atk_rate = 1.5; reward_gold = 0
			setup_model("res://assets/igris.glb", 1.45, Color(1, 0.1, 0.1), 0.2)
			_attach_weapon("res://assets/sl_sword.glb", 1.3)
			var aura := OmniLight3D.new()
			aura.light_color = Color(1, 0.12, 0.15)
			aura.light_energy = 1.6
			aura.omni_range = 6.0
			aura.position.y = 1.8
			add_child(aura)
	hp = max_hp
	if shadow:
		_make_shadow()
	var bar_h := 2.15
	if kind == "orc":
		bar_h = 2.75
	elif kind == "guard":
		bar_h = 2.25
	var bar_col := Color(0.95, 0.2, 0.2)
	if shadow:
		bar_col = Color(0.6, 0.35, 1.0)
	elif kind == "guard":
		bar_col = Color(0.35, 0.65, 1.0)
	if not boss:
		make_hp_bar(bar_h, bar_col)
	collision_layer = 2
	collision_mask = 1 | 2 | 4 | 8
	skill_cd = randf_range(2.0, 5.0)
	skill2_cd = randf_range(6.0, 10.0)
	play("Idle", 0.0)
	if ap:
		ap.seek(randf() * 1.5, true)

func make_elite() -> void:
	elite = true
	display_name = "Élite " + display_name.to_lower()
	rank = "D"
	model.scale *= 1.3
	max_hp *= 2.4
	hp = max_hp
	dmg *= 1.5
	reward_gold *= 4
	(ring.material_override as StandardMaterial3D).albedo_color = Color(1, 0.65, 0.1, 0.22)
	if hp_bar:
		hp_bar.queue_free()
	make_hp_bar(2.6 if kind != "orc" else 3.3, Color(1, 0.6, 0.1))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.5, 0.1)
	glow.light_energy = 0.9
	glow.omni_range = 3.5
	glow.position.y = 1.2
	add_child(glow)

func _attach_weapon(path: String, length_scale: float) -> void:
	var skel_list := model.find_children("*", "Skeleton3D", true, false)
	if skel_list.is_empty():
		return
	var sk := skel_list[0] as Skeleton3D
	var bi := sk.find_bone("hand_r")
	if bi < 0:
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_idx = bi
	var w := (load(path) as PackedScene).instantiate() as Node3D
	att.add_child(w)
	var gs := sk.global_transform.basis.get_scale().x
	w.scale = Vector3.ONE * length_scale / maxf(gs, 0.0001)
	w.rotation_degrees = Vector3(0, 90, 90)

func _hide_orc_weapon() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var aabb := m.get_aabb()
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
	display_name = "Ombre " + display_name.to_lower().replace("élite ", "")
	if boss:
		display_name = "Igris, l'ombre écarlate"
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
	speed = maxf(speed, 6.5)
	var eye := OmniLight3D.new()
	eye.light_color = Color(0.5, 0.2, 1)
	eye.light_energy = 1.2
	eye.omni_range = 2.5
	eye.position = Vector3(0, 1.6, 0.3)
	add_child(eye)

func later(t: float, c: Callable) -> void:
	pending.append([t, c])

func say(cat: String, chance := 1.0) -> void:
	if is_shadow or kind == "guard" or talk_cd > 0.0 or randf() > chance:
		return
	var arr: Array = LINES.get(cat, [])
	if kind == "orc" and (cat == "aggro" or cat == "hit") and randf() < 0.6:
		arr = LINES["orc"]
	if arr.is_empty():
		return
	talk_cd = 5.0
	FX.speech(self, arr[randi() % arr.size()], Color(1, 0.8, 0.7), 2.4 if kind != "orc" else 3.0)

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
	if main.in_dialogue:
		var near: bool = global_position.distance_to(main.hero.global_position) < 6.0
		play("Talk" if (kind == "guard" or kind == "igris") and near else "Idle", 0.3)
		apply_gravity_and_slide(delta)
		return
	atk_cd -= delta
	skill_cd -= delta
	skill2_cd -= delta
	skill3_cd -= delta
	busy -= delta
	hit_stun -= delta
	talk_cd -= delta
	flee_t -= delta
	if not dormant:
		_think(delta)
	else:
		play("Idle", 0.3)
	apply_gravity_and_slide(delta)

func _enemies() -> Array:
	if team == 2:
		return []
	return main.units_of_team(1 - team)

func _allies() -> Array:
	return main.units_of_team(team)

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

func set_target(t: Unit) -> void:
	if target == null and t != null:
		say("aggro", 0.7)
	target = t

func _think(delta: float) -> void:
	if team == 2:
		_patrol(delta)
		return
	if is_shadow:
		_shadow_think(delta)
		return
	if busy > 0.0 or hit_stun > 0.0:
		return
	if target and (target.dead or (not is_shadow and not boss and target.global_position.distance_to(home) > leash_r + 6.0)):
		if target.dead and target == main.hero:
			say("kill")
		target = null
	if target == null:
		set_target(_nearest_enemy(aggro_r if not is_shadow else 14.0))
	if target == null:
		_idle_behaviour(delta)
		return
	var d := global_position.distance_to(target.global_position)
	if not is_shadow and not boss and global_position.distance_to(home) > leash_r:
		target = null
		return
	# repli intelligent : un gobelin blessé fuit et appelle à l'aide
	if flee_t > 0.0:
		_move_towards(global_position + (global_position - target.global_position).normalized() * 3.0, speed * 1.1, delta)
		return
	if kind == "goblin" and not is_shadow and not fled_once and hp < max_hp * 0.25 and randf() < 0.5:
		fled_once = true
		flee_t = 2.2
		say("flee")
		for u in _allies():
			var a := u as Mob
			if a != null and not a.dead and a.target == null and a.global_position.distance_to(global_position) < 16.0:
				a.dormant = false
				a.set_target(target)
		return
	face_to(target.global_position, false, delta)
	if _try_skills(d):
		return
	var want_gap := arm * 0.8
	if kind == "shaman" and not is_shadow:
		want_gap = 5.5
	var gap := gap_to(target)
	if gap > want_gap + 0.25:
		_move_towards(_flank_point(), speed * (1.25 if gap > 4.0 else 1.0), delta)
	elif kind == "shaman" and not is_shadow and gap < 3.5:
		_move_towards(global_position + (global_position - target.global_position), speed, delta)
	else:
		play("Idle", 0.2)
		if in_reach(target) and atk_cd <= 0.0:
			_basic_attack()

# ---------------------------------------------------------------- ombres : intelligence
func _shadow_think(delta: float) -> void:
	var h: Hero = main.hero
	if recover_t > 0.0:
		recover_t -= delta
		global_position = h.global_position - h.forward() * 2.0
		if recover_t <= 0.0:
			_reemerge()
		return
	if busy > 0.0 or hit_stun > 0.0:
		return
	# blessée : elle rentre dans l'ombre du héros pour se régénérer
	if hp < max_hp * 0.25 and not boss:
		recover_t = 8.0
		visible = false
		collision_layer = 0
		FX.shadow_puff(main, global_position)
		main.system_msg("%s se replie dans ton ombre." % display_name)
		return
	var dom: float = h.domain_r()
	match order:
		"follow":
			target = null
			_follow(delta)
			return
		"hold":
			if target == null or target.dead or target.global_position.distance_to(hold_pos) > 9.0:
				target = _nearest_from(hold_pos, 9.0)
			if target == null:
				if global_position.distance_to(hold_pos) > 1.0:
					_move_towards(hold_pos, speed, delta)
				else:
					play("Idle", 0.3)
				return
		"attack":
			var f = main.focus_target
			if f != null and is_instance_valid(f) and not (f as Unit).dead:
				target = f as Unit
			elif target == null or target.dead:
				order = "auto"
		_:
			if target == null or target.dead or target.global_position.distance_to(h.global_position) > dom + 3.0:
				target = _protect_target(dom)
	if target == null or target.dead:
		target = null
		if fought:
			fought = false
			_celebrate()
			return
		_follow(delta)
		return
	fought = true
	face_to(target.global_position, false, delta)
	if _try_skills(global_position.distance_to(target.global_position)):
		return
	if gap_to(target) > arm * 0.8 + 0.25:
		_move_towards(target.global_position, speed * 1.2, delta)
	else:
		play("Idle", 0.2)
		if in_reach(target) and atk_cd <= 0.0:
			_basic_attack()

## Priorité : les ennemis qui attaquent le héros, puis le plus proche dans le domaine.
func _protect_target(dom: float) -> Unit:
	var h: Unit = main.hero
	var best: Unit = null
	var bd := 1e9
	for u in _enemies():
		var e := u as Unit
		if e.dead or e.global_position.distance_to(h.global_position) > dom:
			continue
		var d := e.global_position.distance_to(global_position)
		if e is Mob and (e as Mob).target == h:
			d -= 8.0
		if d < bd:
			bd = d
			best = e
	return best

func _nearest_from(p: Vector3, r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(p) < bd:
			bd = e.global_position.distance_to(p)
			best = e
	return best

## Formation derrière le héros, sans jamais le gêner ; voyage par l'ombre si trop loin.
func _follow(delta: float) -> void:
	var h: Hero = main.hero
	var shadows: Array = main.shadow_list()
	var idx := maxi(shadows.find(self), 0)
	var fwd := h.forward()
	var right := Vector3(fwd.z, 0, -fwd.x)
	# formation en V sur les côtés (jamais entre la caméra et le héros)
	var side := -1.0 if idx % 2 == 0 else 1.0
	var rank_i := idx / 2
	var slot := h.global_position - fwd * (0.8 + rank_i * 1.3) + right * side * (2.3 + rank_i * 1.1)
	var dist := Vector2(slot.x - global_position.x, slot.z - global_position.z).length()
	if dist > 18.0:
		FX.shadow_puff(main, global_position)
		global_position = slot + Vector3(0, 0.3, 0)
		FX.shadow_puff(main, global_position)
		moving = false
		return
	if moving and dist < 0.6:
		moving = false
	elif not moving and dist > 1.8:
		moving = true
	if moving:
		var spd := clampf(dist * 2.4, 3.0, h.sprint_speed() + 1.5)
		var d := slot - global_position
		d.y = 0
		d = d.normalized()
		velocity.x = d.x * spd
		velocity.z = d.z * spd
		face_to(global_position + d, false, delta)
		play("Run" if spd > 4.0 else "Walk", 0.25, clampf(spd / 6.0, 0.8, 1.6))
	else:
		face_to(global_position + fwd * 5.0, false, delta)
		play("Idle", 0.3)

func _celebrate() -> void:
	if randf() > 0.65:
		return
	busy = 2.4
	play("Celebrate", 0.15, 1.0, true)
	FX.burst(main, global_position + Vector3(0, 1.8, 0), Color(0.55, 0.25, 1.0), 16, 0.07, 2.0, 0.6, -1.0)
	if randf() < 0.35:
		FX.speech(self, ["Pour le Monarque !", "Victoire !", "...!", "Gloire à notre Seigneur !"][randi() % 4], Color(0.75, 0.6, 1.0), 2.4 if not boss else 3.4)

func _reemerge() -> void:
	var h: Unit = main.hero
	hp = max_hp
	update_hp_bar()
	visible = true
	collision_layer = 8
	global_position = h.global_position - h.forward() * 2.2 + Vector3(0, 0.3, 0)
	FX.shadow_puff(main, global_position)
	busy = 1.2
	cur_anim = "Death"
	if ap and ap.has_animation("Death"):
		ap.play_backwards("Death", 0.0)
		ap.speed_scale = 2.0

## Encerclement : chaque monstre prend une place différente autour de la cible.
func _flank_point() -> Vector3:
	if is_shadow or boss:
		return target.global_position
	var mates: Array = []
	for u in _allies():
		var a := u as Mob
		if a != null and not a.dead and a.target == target and a.kind != "shaman":
			mates.append(a)
	if mates.size() <= 1:
		return target.global_position
	var k := mates.find(self)
	var base := atan2(global_position.x - target.global_position.x, global_position.z - target.global_position.z)
	var spread := (k - (mates.size() - 1) * 0.5) * 0.9
	var r := target.body_r + body_r + arm * 0.7
	return target.global_position + Vector3(sin(base + spread), 0, cos(base + spread)) * r

func _patrol(delta: float) -> void:
	if patrol.is_empty():
		play("Idle", 0.3)
		return
	var p: Vector3 = patrol[patrol_i % patrol.size()]
	if global_position.distance_to(p) < 0.8:
		wander_t -= delta
		play("Idle", 0.3)
		if wander_t <= 0.0:
			wander_t = randf_range(1.5, 3.5)
			patrol_i += 1
	else:
		_move_towards(p, 1.8, delta)

func _idle_behaviour(delta: float) -> void:
	if is_shadow and main.hero:
		var h: Unit = main.hero
		var slot := h.global_position + Vector3(sin(get_instance_id() % 7), 0, cos(get_instance_id() % 7)) * (2.6 if not boss else 3.4)
		if global_position.distance_to(slot) > 1.2:
			if global_position.distance_to(slot) > 30.0:
				global_position = slot
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
	if kind == "guard" and randf() < 0.5:
		a = "Attack2"
	if kind == "igris":
		combo_i = (combo_i + 1) % 3
		a = ["Attack", "Attack2", "Slash3"][combo_i]
	var spd := 1.0
	if kind == "igris" and a == "Slash3":
		spd = 1.6
	var l := anim_len(a) / spd
	busy = l * 0.95
	play(a, 0.08, spd, true)
	later(l * (0.45 if a != "Slash3" else 0.4), _basic_hit.bind(target))

func _basic_hit(t: Unit) -> void:
	if t and not t.dead and in_reach(t, 0.35):
		t.take_damage(dmg * randf_range(0.85, 1.15), self)
	var col := Color(1, 0.35, 0.2) if team == 1 else Color(0.6, 0.3, 1.0)
	if boss and team == 1:
		col = Color(1, 0.1, 0.15)
	FX.slash_arc(main, global_position, model.rotation.y, col, body_r + arm, randf() < 0.5)

## Sorts spécifiques. Renvoie true si un sort part.
func _try_skills(d: float) -> bool:
	match kind:
		"goblin":
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
			if skill3_cd <= 0.0:
				for u in _allies():
					var a := u as Unit
					if a != self and not a.dead and a.hp < a.max_hp * 0.55 and a.global_position.distance_to(global_position) < 11.0:
						skill3_cd = 8.0
						busy = 0.7
						face_to(a.global_position, true)
						play("Cast", 0.08, 0.8, true)
						say("heal", 0.8)
						later(0.35, _heal.bind(a))
						return true
			if skill_cd <= 0.0 and d < 13.0:
				skill_cd = 3.4
				busy = 0.7
				play("Cast", 0.08, 1.0, true)
				later(0.3, _fire_orb.bind(target))
				return true
			if skill2_cd <= 0.0 and d < 12.0:
				skill2_cd = 9.0
				busy = 0.9
				play("Cast", 0.08, 0.8, true)
				var spot := target.global_position
				FX.telegraph(main, spot, 2.2, 1.1, Color(0.4, 1.0, 0.2))
				later(1.1, _poison_pool.bind(spot))
				return true
		"orc":
			if skill_cd <= 0.0 and d < 4.5:
				skill_cd = 8.0
				busy = 1.9
				play("Slam", 0.1, 1.6, true)
				var spot := global_position + forward() * 1.8
				FX.telegraph(main, spot, 2.6, 1.0)
				later(1.0, _slam.bind(spot, 2.6, 1.8))
				return true
			if skill2_cd <= 0.0 and hp < max_hp * 0.5:
				skill2_cd = 16.0
				busy = 0.8
				play("Roar", 0.1, 0.7, true)
				speed *= 1.35
				atk_rate *= 0.7
				FX.burst(main, global_position + Vector3(0, 1.5, 0), Color(1, 0.2, 0.1), 40, 0.2, 5.0, 0.7, 0.0)
				FX.speech(self, "RAAAAH ! TU VAS PAYER !", Color(1, 0.4, 0.3), 3.0)
				return true
		"igris":
			return _boss_skills(d)
	return false

# ---------------------------------------------------------------- boss
func _boss_skills(d: float) -> bool:
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		busy = 1.6
		play("Taunt", 0.1, 1.2, true)
		FX.speech(self, "Tu... fais saigner un chevalier ? IMPOSSIBLE ! Je vais te montrer la colère de mon Roi !", Color(1, 0.35, 0.3), 3.6, 4.0)
		speed *= 1.3
		atk_rate *= 0.75
		dmg *= 1.15
		var red := OmniLight3D.new()
		red.light_color = Color(1, 0.05, 0.05)
		red.light_energy = 3.5
		red.omni_range = 9.0
		red.position.y = 1.5
		add_child(red)
		FX.burst(main, global_position + Vector3(0, 1.6, 0), Color(1, 0.1, 0.1), 70, 0.25, 6.0, 0.9, 0.0)
		main.shake(0.4)
		main.boss_phase2(self)
		return true
	# Charge écarlate : ligne rouge puis ruée
	if skill_cd <= 0.0 and d > 4.0 and d < 18.0:
		skill_cd = 9.0 if phase == 1 else 6.5
		var from := global_position
		var dir := target.global_position - from
		dir.y = 0
		var to := from + dir.normalized() * minf(dir.length() + 3.0, 18.0)
		FX.telegraph_line(main, from, to, 2.4, 0.9)
		face_to(to, true)
		busy = 1.6
		play("Taunt", 0.05, 2.0, true)
		later(0.9, _charge.bind(from, to))
		return true
	# Tourbillon écarlate : zone circulaire autour de lui
	if skill2_cd <= 0.0 and d < 6.0:
		skill2_cd = 12.0 if phase == 1 else 8.0
		FX.telegraph(main, global_position, 4.6, 1.2)
		busy = 2.0
		play("Block", 0.05, 1.0, true)
		later(1.2, _whirl)
		return true
	return false

func _charge(from: Vector3, to: Vector3) -> void:
	play("Dash", 0.03, 2.2, true)
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(to.x, global_position.y, to.z), 0.32)
	FX.trail(main, from, to, Color(1, 0.1, 0.15))
	var dir := to - from
	dir.y = 0
	var L := dir.length()
	dir = dir.normalized()
	for u in _enemies():
		var e := u as Unit
		if e.dead:
			continue
		var rel := e.global_position - from
		rel.y = 0
		var along := rel.dot(dir)
		var side := absf(rel.cross(dir).y)
		if along > -0.5 and along < L + 0.5 and side < 1.2 + e.body_r:
			e.take_damage(dmg * 2.0, self)
	main.shake(0.3)

func _whirl() -> void:
	play("Heavy", 0.05, 2.6, true)
	FX.burst(main, global_position + Vector3(0, 1.0, 0), Color(1, 0.15, 0.15), 60, 0.2, 7.0, 0.6, 2.0)
	for k in 3:
		FX.slash_arc(main, global_position, model.rotation.y + k * 2.1, Color(1, 0.1, 0.15), 4.2, k % 2 == 0)
	_slam(global_position, 4.6, 1.6)

# ---------------------------------------------------------------- sorts des monstres
func _heal(a: Unit) -> void:
	if a == null or a.dead:
		return
	FX.trail(main, global_position, a.global_position, Color(0.4, 1.0, 0.4))
	FX.burst(main, a.global_position + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.4), 25, 0.1, 2.0, 0.6, -1.5)
	a.hp = minf(a.max_hp, a.hp + a.max_hp * 0.3)
	a.update_hp_bar()
	FX.damage_number(main, a.global_position, "+%d" % int(a.max_hp * 0.3), Color(0.4, 1.0, 0.4))

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

func _slam(spot: Vector3, radius: float, mult: float) -> void:
	FX.burst(main, spot, Color(1, 0.55, 0.25), 45, 0.18, 5.0, 0.6, 9.0)
	main.shake(0.35)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(spot) < radius + e.body_r:
			e.take_damage(dmg * mult, self)

func on_hit(from: Unit) -> void:
	dormant = false
	if target == null and from:
		set_target(from)
	say("hit", 0.25)
	if boss:
		return
	super.on_hit(from)

func die() -> void:
	if not is_shadow and kind != "guard":
		if boss:
			FX.speech(self, "Mon... Roi... ? Ce n'était... pas vous... ?", Color(1, 0.5, 0.45), 3.6, 5.0)
		else:
			say("death", 0.5)
	super.die()

## Relève par l'Arise : le cadavre se relève en ombre.
func rise_as_shadow() -> void:
	arisen = true
	dead = false
	is_shadow = true
	dormant = false
	team = 0
	_make_shadow()
	max_hp = max_hp * (0.8 if not boss else 0.35)
	hp = max_hp
	if hp_bar:
		hp_bar.queue_free()
		hp_bar = null
	make_hp_bar(2.15 if kind != "orc" else 2.75, Color(0.6, 0.35, 1.0))
	for c in hp_bar.get_children():
		if c is Label3D:
			c.visible = false
	if boss:
		hp_bar.position.y = 3.3
		dmg *= 0.8
	ring.visible = true
	collision_layer = 8
	collision_mask = 1 | 2
	target = null
	order = "auto"
	busy = 1.6
	if ap and ap.has_animation("Death"):
		cur_anim = "Death"
		ap.play_backwards("Death", 0.0)
		ap.speed_scale = 1.6
	later(1.6, play.bind("Idle", 0.2, 1.0, true))
