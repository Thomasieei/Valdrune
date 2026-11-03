class_name Soldier
extends CharacterBody3D
## Soldat de Valmont, vrai combattant : garde rapprochée (escorte, éclaireur, garde d'un lieu),
## intervention contre les bandits, escorte de prisonniers, retour au poste.
## Il peut mourir : la garnison du royaume perd alors réellement un soldat.

enum M { POSTE, ESCORTE, ECLAIREUR, GARDER, ALLER, RETOUR, ESCORTE_PRISONNIER }

signal arrived

var nom := "Soldat"
var mode := M.POSTE
var home := Vector3.ZERO          # poste d'origine (retour)
var goal := Vector3.ZERO          # destination (ALLER / GARDER)
var slot := 0                     # place dans la formation d'escorte
var source_guard: Node3D = null   # garde décoratif remplacé (réaffiché au retour)
var prisoner: Node3D = null
var passive := false          # ordre « ne pas attaquer » : il suit sans engager le combat
var patrol: Array = []        # ronde : points (Vector3) parcourus en boucle en mode GARDER
var _patrol_i := 0
var free_on_return := true
var spectral := false             # guerrier spectral (Légion du souverain) : temporaire, sans effet sur la garnison
var lifetime := 0.0
var _route: Array = []
var cbt: Combatant
var _ap: AnimationPlayer
var _cur := ""
var _target: Node3D
var _atk_cd := 0.0
var _hit_at := -1.0
var _think := 0.0
var _bark_cd := 0.0
var gravity := 12.0
var _stuck_t := 0.0
var _stuck_from := Vector3.ZERO
var _ghost_until := 0.0

static var all: Array = []

func _ready() -> void:
	add_to_group("soldat")
	collision_layer = 0
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.88
	add_child(cs)
	var m := CharBuilder.build({"outfit": "rodeur_h", "skin_light": randf() > 0.4, "tint": Color(0.55, 0.62, 0.95), "beard": randf() > 0.6})
	add_child(m)
	_ap = m.get_node("AnimationPlayer")
	var skel: Skeleton3D = m.get_node("Armature/Skeleton3D")
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skel.add_child(att)
	var w := Kit.dungeon(att, "Sword", Vector3.ZERO, 0.0, 1.05)
	w.rotation_degrees = Vector3(-90, 0, 0)
	var att2 := BoneAttachment3D.new()
	att2.bone_name = "lowerarm_l"
	skel.add_child(att2)
	var sh := Kit.dungeon(att2, "Shield", Vector3(0.0, 0.18, 0.08), 0.0, 1.5)
	sh.rotation_degrees = Vector3(0, 90, 90)
	cbt = Combatant.new()
	cbt.team = "joueur"
	cbt.display_name = nom
	var eq := int(Kingdom.res("equipement")) if Kingdom.inst else 1
	cbt.max_hp = 110.0 + eq * 20.0
	cbt.hp = cbt.max_hp
	cbt.defense = 1.0 + eq
	add_child(cbt)
	cbt.died.connect(_on_died)
	FX.blob_shadow(self, 1.1)
	Combat.add_ally(self)
	all.append(self)
	if spectral:
		var sm := Powers.spectral_mat(Color(0.45, 0.75, 1.0), 0.55)
		for mi in find_children("*", "MeshInstance3D", true, false):
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cbt.max_hp *= 0.8
		cbt.hp = cbt.max_hp
		remove_from_group("soldat")
	set_meta("talk", {"id": "soldat_" + nom.to_lower(), "nom": nom, "role": "soldat"})
	_play("Idle")

func _exit_tree() -> void:
	Combat.remove_ally(self)
	all.erase(self)

func _play(a: String, blend := 0.2, speed := 1.0) -> void:
	if not _ap.has_animation(a):
		return
	if a == _cur and a != "Sword_Attack":
		_ap.speed_scale = speed
		return
	_cur = a
	_ap.play(a, blend)
	_ap.speed_scale = speed

func say(t: String, dur := 2.5) -> void:
	FX.bark(self, t, 2.25, dur)

func go_to(p: Vector3, m := M.ALLER) -> void:
	goal = p
	mode = m

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _physics_process(delta: float) -> void:
	if cbt.dead:
		return
	if spectral:
		lifetime -= delta
		if lifetime <= 0.0:
			_dissolve()
			return
	var p := Combat.player
	var now := _now()
	_atk_cd -= delta
	_bark_cd -= delta
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		_target = _pick_target() if mode != M.ESCORTE_PRISONNIER else null
	var move := Vector3.ZERO
	var spd := 4.8
	var fighting := _target != null and Combat.alive(_target)
	if fighting:
		var to := _target.global_position - global_position
		to.y = 0
		var dist := to.length()
		var reach := 1.6 + float(_target.def["rayon"])
		if _hit_at > 0.0 and now >= _hit_at:
			_hit_at = -1.0
			if Combat.alive(_target) and dist < reach + 0.8:
				var eq := int(Kingdom.res("equipement")) if Kingdom.inst else 1
				_target.cbt.take_damage(7.0 + eq * 3.0, self)
				FX.hit_spark(_target.global_position + Vector3.UP * 1.1)
				Sfx.play("epee", -12.0)
		if dist > reach:
			move = to
			spd = 5.6
		elif _atk_cd <= 0.0:
			_atk_cd = 1.4
			_hit_at = now + 0.4
			_face(to, 1.0, 1.0)
			_play("Sword_Attack", 0.1)
			_ap.seek(0.0, true)
		if _bark_cd <= 0.0 and randf() < 0.02:
			_bark_cd = 8.0
			say(["Pour Valmont !", "Tenez la ligne !", "À moi !"][randi() % 3], 1.8)
	else:
		match mode:
			M.ESCORTE, M.ECLAIREUR:
				if p:
					var dest: Vector3
					if mode == M.ECLAIREUR:
						var fw := Vector3(sin(p.cam_yaw + PI), 0, cos(p.cam_yaw + PI))
						dest = p.global_position - fw * 9.0 + Vector3(sin(slot * 2.1), 0, cos(slot * 2.1)) * 2.0
					else:
						var side := 1.0 if slot % 2 == 0 else -1.0
						var row := 1.6 + float(slot / 2) * 1.6
						dest = p.global_position - p.global_transform.basis.z * row + p.global_transform.basis.x * side * 1.5
					var to := dest - global_position
					to.y = 0
					if to.length() > 1.0:
						move = to
						spd = clampf(to.length() * 1.6, 2.4, 7.5)
					if to.length() > 50.0:
						global_position = dest + Vector3.UP * 0.5
			M.ALLER, M.RETOUR, M.GARDER, M.ESCORTE_PRISONNIER:
				var to := goal - global_position
				to.y = 0
				if to.length() > 0.9:
					move = to
					spd = 2.4 if mode == M.ESCORTE_PRISONNIER or (mode == M.GARDER and patrol.size() > 1) else 5.2
				elif mode == M.RETOUR:
					if _route.size() > 0:
						goal = _route.pop_front()
					else:
						_back_home()
						return
				elif mode == M.ALLER or mode == M.ESCORTE_PRISONNIER:
					arrived.emit()
					if mode == M.ALLER:
						mode = M.GARDER
				elif mode == M.GARDER and patrol.size() > 1:
					_patrol_i = (_patrol_i + 1) % patrol.size()
					goal = patrol[_patrol_i]
				elif mode == M.GARDER and p:
					_face(p.global_position - global_position, delta, 2.0)
	move.y = 0
	if move.length() > 0.15:
		var dir := move.normalized()
		_face(dir, delta, 9.0)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if _hit_at < 0.0 or now > _hit_at + 0.6:
			_play("Jog_Fwd" if spd > 3.6 else "Walk", 0.2)
	else:
		velocity.x = 0
		velocity.z = 0
		if _cur != "Sword_Attack" or not _ap.is_playing():
			_play("Sword_Idle" if fighting else "Idle")
	_move_or_unstick(delta, move.length() > 0.15)
	# le prisonnier marche entre ses gardes
	if mode == M.ESCORTE_PRISONNIER and is_instance_valid(prisoner) and slot == 0:
		var pp := global_position + global_transform.basis.z * 1.3
		pp.y = global_position.y
		var np := prisoner.global_position.lerp(pp, clampf(delta * 3.0, 0, 1))
		np.y = global_position.y   # toujours à hauteur de ses gardes (escaliers des cachots)
		prisoner.global_position = np
		prisoner.rotation.y = rotation.y

func _pick_target() -> Node3D:
	if passive:
		return null
	var center := global_position
	var r := 14.0
	if (mode == M.ESCORTE or mode == M.ECLAIREUR) and Combat.player:
		center = Combat.player.global_position
		r = 16.0
	var best: Node3D = null
	var bd := r
	for m in Combat.monsters:
		if not Combat.alive(m):
			continue
		var d: float = m.global_position.distance_to(center)
		if m.peaceful or m.duel or m.has_meta("possede"):
			continue
		if d < bd and (m.state != Monster.S.ERRANCE or d < 8.0):
			bd = d
			best = m
	return best

func _face(dir: Vector3, delta: float, rate: float) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * rate, 0, 1))

## Renvoyer au poste : il marche jusqu'à son poste puis redevient le garde décoratif
func send_home() -> void:
	mode = M.RETOUR
	goal = home
	_route.clear()
	# depuis les cachots : remonter l'escalier au lieu de traverser les murs
	if Justice.in_cellar(global_position):
		_route = [Justice.STAIR_FOOT, Justice.STAIR_EDGE, Justice.STAIR_TOP, home]
		goal = Justice.STAIR_BOTTOM

func _back_home() -> void:
	if is_instance_valid(source_guard):
		source_guard.visible = true
		source_guard.process_mode = Node.PROCESS_MODE_INHERIT
		if not source_guard.is_in_group("pnj"):
			source_guard.add_to_group("pnj")
	if free_on_return:
		queue_free()
	else:
		mode = M.POSTE

func _dissolve() -> void:
	cbt.dead = true
	Combat.remove_ally(self)
	FX.shockwave(global_position, 1.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 1.6, 0.05), 0.35)
	tw.tween_callback(queue_free)

func _on_died(_src: Node) -> void:
	if spectral:
		_dissolve()
		return
	velocity = Vector3.ZERO
	_play("Death01", 0.1)
	collision_layer = 0
	Combat.remove_ally(self)
	var gs := GameState.get_inst()
	if Kingdom.inst:
		Kingdom.add("soldats", -1)
	gs.report("Le soldat %s est tombé au combat." % nom, "armee")
	Escort.forget(self)
	if is_instance_valid(source_guard):
		source_guard.queue_free()   # le poste reste vide : la garnison a réellement perdu un homme
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(self, "position:y", position.y - 1.5, 1.5)
	tw.tween_callback(queue_free)

## Déplacement avec déblocage : sans pathfinding, un personnage peut buter contre une maison ;
## s'il n'avance plus pendant 1,5 s, il traverse l'obstacle quelques instants au lieu de rester coincé.
var _seg_a := Vector3.INF
var _seg_goal := Vector3.INF

## Escorte de prisonnier / descente aux cachots : déplacement « sur rails » le long du trajet,
## sans physique (escaliers, tranchée, plafond des cachots) — impossible de passer sous la carte.
func _on_rails() -> bool:
	if mode == M.ESCORTE_PRISONNIER:
		return true
	if mode == M.RETOUR:
		return Justice.dug(Vector2(global_position.x, global_position.z))
	return false

func _rails(delta: float) -> void:
	if goal != _seg_goal:
		_seg_goal = goal
		_seg_a = global_position
	var to := goal - global_position
	to.y = 0.0
	var step := minf(to.length(), Vector2(velocity.x, velocity.z).length() * delta)
	if to.length() > 0.001:
		global_position += to.normalized() * step
	var tot := Vector2(goal.x - _seg_a.x, goal.z - _seg_a.z).length()
	var f := 1.0 if tot < 0.01 else clampf(1.0 - Vector2(goal.x - global_position.x, goal.z - global_position.z).length() / tot, 0.0, 1.0)
	if Justice.dug(Vector2(global_position.x, global_position.z)):
		global_position.y = lerpf(_seg_a.y, goal.y, f)
	else:
		global_position.y = Powers.ground(global_position + Vector3.UP * 0.6)
	velocity = Vector3.ZERO

func _move_or_unstick(delta: float, wants_move: bool) -> void:
	if _on_rails():
		_rails(delta)
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ghost_until:
		global_position.x += velocity.x * delta
		global_position.z += velocity.z * delta
		var g := Powers.ground(global_position + Vector3.UP * 0.5)
		global_position.y = g if absf(global_position.y - g) < 1.5 else lerpf(global_position.y, g, clampf(delta * 6.0, 0, 1))
		return
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.5
	move_and_slide()
	var gy := Terrain.height_at(global_position.x, global_position.z)
	if global_position.y < gy - 1.0:
		global_position.y = gy + 0.2
	if wants_move:
		_stuck_t += delta
		if _stuck_t > 1.5:
			if Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length() < 0.6:
				_ghost_until = now + 1.2
			_stuck_t = 0.0
			_stuck_from = global_position
	else:
		_stuck_t = 0.0
		_stuck_from = global_position
