class_name Companion
extends CharacterBody3D
## Compagnon persistant (Elian) : suit le joueur, le guide, combat à ses côtés sans voler le combat
## (dégâts modestes, il « provoque » les ennemis pour soulager le joueur), tombe à terre au lieu de mourir,
## part en mission (il disparaît alors du monde jusqu'à son retour).
## Ses données (stats, loyauté, relation, XP, niveau, compétences) vivent dans GameState.companions[id].

enum M { SUIVRE, GUIDER, ATTENDRE, COMBAT, A_TERRE, ABSENT, IMMOBILE }

signal arrived(index: int)     # point de guidage atteint

const DEFAULTS := {
	"elian": {
		"nom": "Elian", "role": "Messager du roi", "personnalite": "Loyal, nerveux, curieux ; déteste l'injustice",
		"apparence": "Jeune homme blond, tunique bleu pâle", "niveau": 1, "xp": 0, "loyaute": 20, "relation": 0,
		"competences": {"combat": 2, "diplomatie": 4, "recherche": 3, "recolte": 2, "commandement": 1},
		"pv": 160, "etat": "present", "blessure_fin": 0.0,
	},
}

var id := "elian"
var mode := M.SUIVRE
var cbt: Combatant
var waypoints: Array = []      # Vector3 (guidage)
var wp_i := 0
var wait_dist := 9.0           # en guidage : attend le joueur s'il est plus loin que ça
var stand_at := Vector3.ZERO
var _ap: AnimationPlayer
var _cur := ""
var _model: Node3D
var _target: Node3D
var _atk_cd := 0.0
var _taunt_cd := 3.0
var _bark_cd := 0.0
var _down_until := 0.0
var _hit_at := -1.0
var _think := 0.0
var gravity := 12.0
var _stuck_t := 0.0
var _stuck_from := Vector3.ZERO
var _ghost_until := 0.0

static func data(cid: String) -> Dictionary:
	var gs := GameState.get_inst()
	if not gs.companions.has(cid):
		var d: Dictionary = DEFAULTS[cid].duplicate(true)
		# les choix faits avant que le compagnon ne rejoigne officiellement le joueur
		for k in ["relation", "loyaute"]:
			var pre := "pre_%s_%s" % [k, cid]
			if gs.flags.has(pre):
				d[k] = clampi(int(d[k]) + int(gs.flags[pre]), -100, 100)
				gs.flags.erase(pre)
		gs.companions[cid] = d
		gs.mark()
	return gs.companions[cid]

static func xp_to_next(lv: int) -> int:
	return 60 + lv * 50

## XP du compagnon (missions, combats) — chaque niveau renforce ses compétences
static func give_xp(cid: String, n: int) -> String:
	var d := data(cid)
	d["xp"] = int(d["xp"]) + n
	var out := ""
	while int(d["xp"]) >= xp_to_next(int(d["niveau"])):
		d["xp"] = int(d["xp"]) - xp_to_next(int(d["niveau"]))
		d["niveau"] = int(d["niveau"]) + 1
		d["pv"] = int(d["pv"]) + 20
		var comp: Dictionary = d["competences"]
		# il progresse dans ce qu'il pratique le plus (la plus haute), plus une autre au hasard
		var best := ""
		for k in comp:
			if best == "" or int(comp[k]) > int(comp[best]):
				best = k
		comp[best] = int(comp[best]) + 1
		var other: String = comp.keys()[randi() % comp.size()]
		comp[other] = int(comp[other]) + 1
		out = "%s passe niveau %d (%s +1, %s +1)" % [d["nom"], d["niveau"], best, other]
	GameState.get_inst().mark()
	return out

func _ready() -> void:
	add_to_group("compagnon")
	collision_layer = 0          # ne bloque pas le joueur
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
	var d := data(id)
	_model = CharBuilder.build({"outfit": "paysan_h", "hair": "Hair_SimpleParted", "hair_color": Color(0.85, 0.7, 0.35), "skin_light": true, "tint": Color(0.7, 0.85, 1.0), "hero": true})
	add_child(_model)
	_ap = _model.get_node("AnimationPlayer")
	var skel: Skeleton3D = _model.get_node("Armature/Skeleton3D")
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skel.add_child(att)
	var w := Kit.dungeon(att, "Sword", Vector3.ZERO, 0.0, 0.9)
	if w:
		w.rotation_degrees = Vector3(-90, 0, 0)
	cbt = Combatant.new()
	cbt.team = "joueur"
	cbt.display_name = String(d["nom"])
	cbt.max_hp = float(d["pv"])
	cbt.hp = cbt.max_hp
	cbt.defense = 1.0 + int(d["competences"]["combat"]) * 0.5
	add_child(cbt)
	cbt.died.connect(_on_down)
	FX.blob_shadow(self, 1.1)
	Combat.companion = self
	_play("Idle")

func _exit_tree() -> void:
	if Combat.companion == self:
		Combat.companion = null

func _play(a: String, blend := 0.2, speed := 1.0) -> void:
	if not _ap.has_animation(a):
		return
	if a == _cur and a != "Sword_Attack":
		_ap.speed_scale = speed
		return
	_cur = a
	_ap.play(a, blend)
	_ap.speed_scale = speed

func say(text: String, dur := 3.2) -> void:
	FX.bark(self, text, 2.25, dur)

func guide(points: Array, wait := 9.0) -> void:
	waypoints = points
	wp_i = 0
	# reprend au point de passage le plus proche (pas de demi-tour inutile)
	var bd := INF
	for i in points.size():
		var d: float = (points[i] as Vector3).distance_to(global_position)
		if d < bd:
			bd = d
			wp_i = i
	wait_dist = wait
	mode = M.GUIDER

func follow() -> void:
	mode = M.SUIVRE

func stand(p: Vector3) -> void:
	stand_at = p
	mode = M.IMMOBILE

func teleport(p: Vector3) -> void:
	global_position = p
	velocity = Vector3.ZERO

func present() -> bool:
	return visible and mode != M.ABSENT

func set_absent(v: bool) -> void:
	visible = not v
	process_mode = Node.PROCESS_MODE_DISABLED if v else Node.PROCESS_MODE_INHERIT
	if v:
		mode = M.ABSENT
	elif mode == M.ABSENT:
		mode = M.SUIVRE
		var p := Combat.player
		if p:
			teleport(p.global_position - p.global_transform.basis.z * -2.0 + Vector3(1.5, 0.3, 0))

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _physics_process(delta: float) -> void:
	var p := Combat.player
	if p == null:
		return
	var now := _now()
	_atk_cd -= delta
	_taunt_cd -= delta
	_bark_cd -= delta
	var move := Vector3.ZERO
	var spd := 5.2
	if mode == M.A_TERRE:
		if now > _down_until:
			cbt.dead = false
			cbt.hp = cbt.max_hp * 0.45
			mode = M.SUIVRE
			say("Je… je suis encore debout !")
		_gravity(delta)
		return
	# combat : il rejoint la mêlée si un ennemi s'en prend au joueur (ou à lui)
	_think -= delta
	if _think <= 0.0:
		_think = 0.3
		if mode != M.IMMOBILE:
			_target = _pick_target()
	var fighting := _target != null and Combat.alive(_target) and mode != M.IMMOBILE
	if fighting:
		var to := _target.global_position - global_position
		to.y = 0
		var dist := to.length()
		var reach := 1.6 + float(_target.def["rayon"])
		if _hit_at > 0.0 and now >= _hit_at:
			_hit_at = -1.0
			if Combat.alive(_target) and dist < reach + 0.8:
				var d := data(id)
				var dmg := 5.0 + int(d["competences"]["combat"]) * 1.5 + int(d["niveau"]) * 1.0
				_target.cbt.take_damage(dmg, self)
				FX.hit_spark(_target.global_position + Vector3.UP * 1.1)
				Sfx.play("epee", -10.0)
		if dist > reach:
			move = to
			spd = 5.6
		elif _atk_cd <= 0.0:
			_atk_cd = 1.5
			_hit_at = now + 0.35
			_face(to, 1.0, 1.0)
			_play("Sword_Attack", 0.1)
			_ap.seek(0.0, true)
		# provocation : il attire l'ennemi le plus dangereux pour donner du répit au joueur
		if _taunt_cd <= 0.0 and dist < 9.0:
			_taunt_cd = 9.0
			_target.force_target = self
			_target.force_until = now + 3.5
			if _bark_cd <= 0.0:
				_bark_cd = 6.0
				say(["Par ici, brute !", "Hé ! C'est moi que tu veux ?", "Laissez-le respirer !"][randi() % 3], 2.2)
	else:
		match mode:
			M.SUIVRE:
				var behind := p.global_position + p.global_transform.basis.z * -2.2 + p.global_transform.basis.x * 1.4
				var to := behind - global_position
				to.y = 0
				if to.length() > 1.2:
					move = to
					spd = clampf(to.length() * 1.6, 2.4, 7.5)
				if to.length() > 45.0:
					teleport(behind + Vector3.UP * 0.5)
			M.GUIDER:
				# point de passage déjà dépassé (raccourci, téléportation) : on passe au suivant
				while wp_i < waypoints.size() - 1 and global_position.distance_to(waypoints[wp_i + 1]) < global_position.distance_to(waypoints[wp_i]):
					wp_i += 1
				if wp_i < waypoints.size():
					var w: Vector3 = waypoints[wp_i]
					var to := w - global_position
					to.y = 0
					var pd := p.global_position.distance_to(global_position)
					if to.length() < 1.2:
						arrived.emit(wp_i)
						wp_i += 1
					elif pd > wait_dist and _player_behind(p):
						# il attend le joueur en se retournant vers lui
						_face(p.global_position - global_position, delta, 6.0)
						if _bark_cd <= 0.0 and pd > wait_dist + 6.0:
							_bark_cd = 9.0
							say(["Par ici !", "Suivez-moi, ce n'est plus très loin !", "Ne traînez pas !"][randi() % 3], 2.5)
					else:
						move = to
						spd = 4.6 if pd < wait_dist else 6.5
			M.IMMOBILE:
				var to := stand_at - global_position
				to.y = 0
				if to.length() > 0.6:
					move = to
					spd = 3.5
				else:
					_face(p.global_position - global_position, delta, 4.0)
	move.y = 0
	if move.length() > 0.15:
		var dir := move.normalized()
		_face(dir, delta, 9.0)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
		if _now() > _hit_at + 0.6 or _hit_at < 0.0:
			_play("Jog_Fwd" if spd > 3.8 else "Walk", 0.2, clampf(spd / 5.0, 0.8, 1.4) if spd > 3.8 else 1.0)
	else:
		velocity.x = 0
		velocity.z = 0
		if _cur != "Sword_Attack" or not _ap.is_playing():
			_play("Sword_Idle" if fighting else "Idle")
	_gravity(delta)

## Le joueur est-il en retard sur le trajet ? (sinon Elian ne l'attend pas : il le rattrape)
func _player_behind(p: Node3D) -> bool:
	var last: Vector3 = waypoints[waypoints.size() - 1]
	return p.global_position.distance_to(last) > global_position.distance_to(last) - 2.0

func _gravity(delta: float) -> void:
	_move_or_unstick(delta, Vector2(velocity.x, velocity.z).length() > 0.5)

func _pick_target() -> Node3D:
	var p := Combat.player
	var best: Node3D = null
	var bd := 16.0
	for m in Combat.monsters:
		if not Combat.alive(m):
			continue
		if m.state == Monster.S.ERRANCE or m.state == Monster.S.RETOUR:
			continue
		var d: float = m.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = m
	return best

func _face(dir: Vector3, delta: float, rate: float) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * rate, 0, 1))

func _on_down(_src: Node) -> void:
	# pas de mort définitive pendant l'histoire : il est mis à terre et se relève
	mode = M.A_TERRE
	_down_until = _now() + 9.0
	velocity = Vector3.ZERO
	_play("Death01", 0.1)
	say("Argh… je ne peux plus…", 2.5)
	for m in Combat.monsters:
		if is_instance_valid(m) and m.force_target == self:
			m.force_target = null

## Déplacement avec déblocage : sans pathfinding, un personnage peut buter contre une maison ;
## s'il n'avance plus pendant 1,5 s, il traverse l'obstacle quelques instants au lieu de rester coincé.
func _move_or_unstick(delta: float, wants_move: bool) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _ghost_until:
		global_position.x += velocity.x * delta
		global_position.z += velocity.z * delta
		var g := Terrain.height_at(global_position.x, global_position.z)
		global_position.y = maxf(g, global_position.y - 4.0 * delta) if global_position.y > g + 0.5 else g
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
