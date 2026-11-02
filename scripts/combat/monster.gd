class_name Monster
extends CharacterBody3D
## Créature générique pilotée par MonsterDB : errance, détection, poursuite, attaque, fuite, retour au repaire, mort et butin.

enum S { ERRANCE, POURSUITE, ATTAQUE, TOUCHE, FUITE, RETOUR, MORT, SPECIALE, RECUP, ESQUIVE }

signal mort(m: Monster)

## Appelé quand une créature lance une attaque spéciale télégraphiée (le tutoriel s'y branche)
static var on_special: Callable = Callable()
var force_target: Node3D = null
var force_until := 0.0
var no_respawn := false
var _sp: Dictionary = {}
var _tele: Telegraph
var _sp_cool := {}
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _charge_from := Vector3.ZERO
var _charge_to := Vector3.ZERO
var _kb := Vector3.ZERO
var _fear_until := 0.0

var kind := "puglin"
var def: Dictionary
var home := Vector3.ZERO
var leash := 30.0
var spawner: Node = null

var cbt: Combatant
var state := S.ERRANCE
var _ap: AnimationPlayer
var _cur := ""
var _t := 0.0             # minuterie d'état
var _cool := 0.0          # recharge d'attaque
var _hit_done := false
var _wander := Vector3.ZERO
var _bar: MeshInstance3D
var _bar_mat: ShaderMaterial
var _model: Node3D
var gravity := 12.0

static var _libs := {}
static var _bar_shader: Shader

func _ready() -> void:
	def = MonsterDB.DEFS[kind]
	collision_layer = 16
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var sc: float = def["scale"]
	cap.radius = def["rayon"]
	cap.height = 1.6 * sc
	cs.shape = cap
	cs.position.y = 0.8 * sc
	add_child(cs)
	cbt = Combatant.new()
	cbt.team = "monstre"
	cbt.max_hp = def["hp"]
	cbt.hp = def["hp"]
	cbt.defense = def["defense"]
	cbt.display_name = def["nom"]
	add_child(cbt)
	cbt.damaged.connect(_on_damaged)
	cbt.died.connect(_on_died)
	_build_model()
	FX.blob_shadow(self, 1.3 * sc)
	_make_bar()
	home = global_position
	_wander = home
	Combat.register(self)
	_play("attente")

func _exit_tree() -> void:
	Combat.unregister(self)

func _build_model() -> void:
	var m: String = def["model"]
	var sc: float = def["scale"]
	if m.begins_with("humain:"):
		var spec := {"outfit": m.get_slice(":", 1), "hair": def.get("cheveux", "Hair_Buzzed"), "tint": def.get("teinte", Color.WHITE), "hair_color": def.get("couleur_cheveux", Color(0.2, 0.22, 0.18)), "beard": def.get("barbe", false)}
		if def.has("pieces"):
			spec["pieces"] = def["pieces"]
		_model = CharBuilder.build(spec)
		_ap = _model.get_node("AnimationPlayer")
		var skel: Skeleton3D = _model.get_node("Armature/Skeleton3D")
		if def.has("arme"):
			var att := BoneAttachment3D.new()
			att.bone_name = "hand_r"
			skel.add_child(att)
			var w := Kit.dungeon(att, def["arme"], Vector3.ZERO, 0.0, def.get("arme_echelle", 1.1))
			w.rotation_degrees = Vector3(-90, 0, 0)
		if def.has("bouclier"):
			var att2 := BoneAttachment3D.new()
			att2.bone_name = "lowerarm_l"
			skel.add_child(att2)
			var sh := Kit.dungeon(att2, "Shield", Vector3(0.0, 0.18, 0.08), 0.0, 1.8)
			sh.rotation_degrees = Vector3(0, 90, 90)
	else:
		var file := m.get_slice(":", 1)
		_model = load("res://assets/monsters/%s.glb" % file).instantiate()
		var skel: Skeleton3D = _model.get_node("Armature/Skeleton3D")
		var skins: Array = def.get("skins", [])
		if skins.size() > 0:
			var tex: Texture2D = load("res://assets/monsters/tex/%s.png" % skins[randi() % skins.size()])
			for mi in skel.get_children():
				if mi is MeshInstance3D:
					for i in mi.mesh.get_surface_count():
						var mat = mi.mesh.surface_get_material(i)
						if mat is StandardMaterial3D and mat.albedo_texture != null:
							var key := "%d|%s" % [mat.get_instance_id(), tex.resource_path]
							if not _libs.has(key):
								var d: StandardMaterial3D = mat.duplicate()
								d.albedo_texture = tex
								d.normal_enabled = false
								d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
								d.emission_enabled = false
								_libs[key] = d
							mi.set_surface_override_material(i, _libs[key])
		for mi in skel.get_children():
			if mi is MeshInstance3D:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ap = AnimationPlayer.new()
		_model.add_child(_ap)
		var lk := "lib|" + file
		if not _libs.has(lk):
			var src: AnimationLibrary = CharBuilder._lib("res://assets/anims/UAL1_Standard.glb")
			_libs[lk] = AnimRetarget.library(src, skel, file, ["Idle", "Walk", "Jog_Fwd", "Punch_Jab", "Sword_Attack", "Hit_Chest", "Death01", "Punch_Cross"])
		_ap.add_animation_library("", _libs[lk])
	_model.scale = Vector3.ONE * sc
	add_child(_model)

func _make_bar() -> void:
	if _bar_shader == null:
		_bar_shader = Shader.new()
		_bar_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;
uniform float fill = 1.0;
uniform vec4 col : source_color = vec4(0.9, 0.2, 0.15, 1.0);
void vertex() { MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]); }
void fragment() {
	float edge = step(0.06, UV.y) * step(UV.y, 0.94) * step(0.015, UV.x) * step(UV.x, 0.985);
	vec3 c = UV.x < fill ? col.rgb : vec3(0.12);
	ALBEDO = mix(vec3(0.0), c, edge);
}"""
	_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.12) * (1.4 if def.get("elite", false) else 1.0)
	_bar.mesh = q
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = _bar_shader
	if def.get("elite", false):
		_bar_mat.set_shader_parameter("col", Color(0.95, 0.55, 0.1))
	_bar.material_override = _bar_mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.position = Vector3.UP * (2.05 * float(def["scale"]))
	_bar.visible = false
	add_child(_bar)

func _play(key: String, blend := 0.2, speed := 1.0) -> void:
	var a: String = def["anims"].get(key, key)
	if not _ap.has_animation(a):
		return
	if a == _cur and key != "attaque" and key != "touche":
		_ap.speed_scale = speed
		return
	_cur = a
	_ap.play(a, blend)
	_ap.speed_scale = speed
	if key == "attaque" or key == "touche":
		_ap.seek(0.0, true)

func _player() -> Node3D:
	if force_target and is_instance_valid(force_target) and Time.get_ticks_msec() / 1000.0 < force_until and not force_target.cbt.dead:
		return force_target
	# cible : le plus proche du camp de Valmont (le joueur est légèrement privilégié)
	var best: Node3D = Combat.player
	var bd := INF
	for f in Combat.friends():
		var d: float = f.global_position.distance_to(global_position) * (0.8 if f == Combat.player else 1.0)
		if d < bd:
			bd = d
			best = f
	return best

func _physics_process(delta: float) -> void:
	if state == S.MORT:
		return
	_t += delta
	_cool -= delta
	var p := _player()
	var to_p := Vector3.ZERO
	var dist := INF
	var p_dead := true
	if p:
		to_p = p.global_position - global_position
		to_p.y = 0
		dist = to_p.length()
		p_dead = p.cbt.dead
	var move := Vector3.ZERO
	var spd: float = def["vitesse"]
	match state:
		S.ERRANCE:
			if global_position.distance_to(_wander) < 1.0 or _t > 8.0:
				_t = 0.0
				_wander = home + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			move = (_wander - global_position)
			if _t < 2.5:
				move = Vector3.ZERO
			if not p_dead and dist < def["detection"]:
				_aggro()
		S.POURSUITE:
			spd = def["course"]
			move = to_p
			if p_dead:
				_go(S.RETOUR)
			elif global_position.distance_to(home) > leash:
				_go(S.RETOUR)
			elif _try_special(p, dist):
				pass
			elif dist <= def["portee"] and _cool <= 0.0:
				_go(S.ATTAQUE)
			elif dist <= def["portee"]:
				move = Vector3.ZERO
			if def["comportement"] == "lache" and cbt.hp < cbt.max_hp * 0.35 and _t > 0.5:
				_go(S.FUITE)
		S.ATTAQUE:
			_face(to_p, delta, 10.0)
			var dur: float = def["cadence"] * 0.8
			if not _hit_done and _t >= def["impact"]:
				_hit_done = true
				if p and not p_dead and dist <= float(def["portee"]) + 0.7:
					var fwd := global_transform.basis.z
					if fwd.dot(to_p.normalized()) > 0.3:
						p.cbt.take_damage(def["degats"], self)
						Sfx.play("touche", -4.0)
			if _t >= dur:
				_cool = def["cadence"]
				_go(S.POURSUITE)
		S.SPECIALE:
			if is_instance_valid(_tele) and _sp.get("suivre", false):
				_face(to_p, delta, 2.0)
		S.RECUP:
			if _sp.get("charge", false) and _t < 0.3:
				global_position = _charge_from.lerp(_charge_to, clampf(_t / 0.3, 0.0, 1.0))
			if _t > float(_sp.get("recup", 0.7)):
				_go(S.POURSUITE)
		S.ESQUIVE:
			move = _dodge_dir
			spd = 7.0
			if _t > 0.45:
				_go(S.POURSUITE)
		S.TOUCHE:
			if _t > 0.38:
				_go(S.POURSUITE if def["comportement"] != "lache" or cbt.hp > cbt.max_hp * 0.35 else S.FUITE)
		S.FUITE:
			spd = def["course"]
			move = -to_p
			if _t > 4.0 and Time.get_ticks_msec() / 1000.0 > _fear_until:
				_go(S.POURSUITE if dist < def["detection"] else S.RETOUR)
		S.RETOUR:
			spd = def["course"]
			move = home - global_position
			move.y = 0
			cbt.heal(cbt.max_hp * 0.25 * delta)
			if move.length() < 1.5:
				cbt.hp = cbt.max_hp
				_go(S.ERRANCE)
	move.y = 0
	var mult := cbt.speed_mult()
	if state == S.ESQUIVE:
		mult = 1.0
	if state == S.SPECIALE or (state == S.RECUP and _sp.get("charge", false)):
		move = Vector3.ZERO
	if move.length() > 0.2 and mult > 0.0:
		var dir := move.normalized()
		_face(dir, delta, 8.0)
		velocity.x = dir.x * spd * mult
		velocity.z = dir.z * spd * mult
		_play("course" if spd > def["vitesse"] + 0.1 else "marche", 0.2, mult)
	else:
		velocity.x = 0
		velocity.z = 0
		if state != S.ATTAQUE and state != S.TOUCHE and state != S.SPECIALE and state != S.RECUP and state != S.ESQUIVE:
			_play("attente")
	# éviter de s'empiler sur les congénères
	for o in Combat.monsters:
		if o != self and is_instance_valid(o):
			var d: Vector3 = global_position - o.global_position
			d.y = 0
			var l := d.length()
			if l < 1.0 and l > 0.01:
				velocity += d / l * (1.0 - l) * 3.0
	if _kb.length() > 0.2:
		velocity.x += _kb.x
		velocity.z += _kb.z
		_kb = _kb.lerp(Vector3.ZERO, clampf(delta * 6.0, 0, 1))
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.5
	move_and_slide()
	var gy := Terrain.height_at(global_position.x, global_position.z)
	if global_position.y < gy - 1.0:
		global_position.y = gy + 0.2
	_bar_mat.set_shader_parameter("fill", cbt.hp / cbt.max_hp)
	_bar.visible = cbt.hp < cbt.max_hp

## Attaques spéciales définies dans MonsterDB ("speciales") : zone au sol, temps d'avertissement, frappe.
func _try_special(p: Node3D, dist: float) -> bool:
	if p == null or not def.has("speciales"):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	for sp in def["speciales"]:
		var id: String = sp["id"]
		if now < float(_sp_cool.get(id, 0.0)):
			continue
		if dist < float(sp.get("min", 0.0)) or dist > float(sp.get("max", 99.0)):
			continue
		_sp_cool[id] = now + float(sp["recharge"])
		_start_special(sp, p)
		return true
	return false

func _start_special(sp: Dictionary, tgt: Node3D) -> void:
	_sp = sp
	var to := tgt.global_position - global_position
	to.y = 0
	var yaw := atan2(to.x, to.z)
	rotation.y = yaw
	var shp: String = sp["forme"]
	var center := global_position
	if sp.get("centre", "soi") == "cible":
		center = tgt.global_position
	var l: float = sp.get("longueur", 8.0)
	_tele = Telegraph.spawn(FX.root, center, yaw, shp, sp["avert"], sp.get("rayon", 3.0), sp.get("angle", 80.0), l, sp.get("largeur", 2.4))
	_tele.struck.connect(_resolve_special.bind(_tele))
	if sp.get("charge", false):
		_charge_from = global_position
		var end := global_position + Vector3(sin(yaw), 0, cos(yaw)) * (l - 0.5)
		end.y = Terrain.height_at(end.x, end.z) + 0.1
		if global_position.y > end.y + 0.6:
			end.y = global_position.y
		_charge_to = end
	_go(S.SPECIALE)
	velocity = Vector3.ZERO
	var prep: String = sp.get("anim_prep", "")
	if prep != "" and _ap.has_animation(prep):
		_cur = prep
		_ap.play(prep, 0.15)
		_ap.speed_scale = 0.6
	if sp.has("cri"):
		FX.damage_number(global_position + Vector3.UP * 3.0 * float(def["scale"]), String(sp["cri"]), Color(1, 0.5, 0.35))
	if on_special.is_valid():
		on_special.call(self, _tele)

func _resolve_special(tele: Telegraph) -> void:
	if state == S.MORT:
		return
	var a: String = _sp.get("anim", "")
	if a != "" and _ap.has_animation(a):
		_cur = a
		_ap.play(a, 0.05)
		_ap.seek(float(_sp.get("anim_seek", 0.0)), true)
		_ap.speed_scale = 1.4
	for t in Combat.friends():
		if tele.contains(t.global_position):
			t.cbt.take_damage(float(_sp["degats"]), self)
	match String(_sp.get("fx", "poussiere")):
		"poussiere":
			FX.shockwave(tele.global_position, float(_sp.get("rayon", 2.0)) if _sp["forme"] == "cercle" else 2.0)
		"impact":
			FX.hit_spark(tele.global_position + Vector3.UP * 0.5, Color(1, 0.7, 0.4))
	Sfx.play("lourd", -2.0)
	if Combat.player and Combat.player.global_position.distance_to(tele.global_position) < 14.0:
		Combat.player.shake(0.35)
	_go(S.RECUP)

## Recul physique (explosions, onde de l'égide). Les géants résistent.
func knockback(v: Vector3) -> void:
	if state == S.MORT:
		return
	var sc: float = def["scale"]
	var res := 0.25 if def.get("boss", false) else (0.6 if def.get("elite", false) else 1.0)
	_kb = v * res / maxf(1.0, sc * 0.8)

## Peur : l'ennemi fuit quelques secondes devant une démonstration de puissance
func frighten(dur: float) -> void:
	if state == S.MORT or state == S.SPECIALE:
		return
	_go(S.FUITE)
	_fear_until = Time.get_ticks_msec() / 1000.0 + dur
	var cry := "!!"
	if String(def["model"]).begins_with("humain:"):
		cry = ["Fuyez !", "C'est un démon !", "Repliez-vous !", "Pitié !"][randi() % 4]
	FX.bark(self, cry, 2.3 * float(def["scale"]), 1.6)

func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * rate, 0, 1))

func _go(s: int) -> void:
	state = s
	_t = 0.0
	match s:
		S.ATTAQUE:
			_hit_done = false
			velocity = Vector3.ZERO
			_play("attaque", 0.12, 1.15)
		S.TOUCHE:
			_play("touche", 0.08)

func _aggro() -> void:
	if state == S.MORT:
		return
	if state == S.ERRANCE or state == S.RETOUR:
		_go(S.POURSUITE)
		if def["comportement"] == "meute":
			for o in Combat.monsters:
				if o != self and Combat.alive(o) and o.kind == kind and o.global_position.distance_to(global_position) < 14.0:
					o._aggro()

func _on_damaged(_amount: float, _src: Node) -> void:
	if state == S.MORT:
		return
	_aggro()
	# certaines créatures esquivent les assauts répétés
	var now := Time.get_ticks_msec() / 1000.0
	if def.has("esquive") and state == S.POURSUITE and now > _dodge_cd and randf() < float(def["esquive"]):
		_dodge_cd = now + 3.0
		var side := global_transform.basis.x * (1.0 if randf() > 0.5 else -1.0)
		_dodge_dir = (side - global_transform.basis.z * 0.6).normalized()
		cbt.invulnerable_until = now + 0.4
		_go(S.ESQUIVE)
		if _ap.has_animation("Roll"):
			_cur = "Roll"
			_ap.play("Roll", 0.05)
			_ap.speed_scale = 1.3
		return
	if state == S.SPECIALE or state == S.ESQUIVE:
		return
	if state == S.FUITE and Time.get_ticks_msec() / 1000.0 < _fear_until:
		return   # terrorisé : il continue de fuir même s'il est touché
	if not def.get("elite", false) and state != S.ATTAQUE:
		_go(S.TOUCHE)
	if _model:
		var tw := _model.create_tween()
		var sc: float = def["scale"]
		tw.tween_property(_model, "scale", Vector3(1.08, 0.92, 1.08) * sc, 0.06)
		tw.tween_property(_model, "scale", Vector3.ONE * sc, 0.1)

func _on_died(_src: Node) -> void:
	state = S.MORT
	_bar.visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	_play("mort", 0.1)
	Combat.unregister(self)
	if is_instance_valid(_tele):
		_tele.queue_free()
	mort.emit(self)
	var prog := Progression.get_inst()
	prog.add_xp(def["xp"])
	FX.damage_number(global_position + Vector3.UP * 2.4, "+%d XP" % def["xp"], Color(0.6, 0.9, 1.0))
	Loot.drop(self)
	if spawner and not no_respawn:
		spawner.on_monster_died(self)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(self, "position:y", position.y - 1.6, 1.4)
	tw.tween_callback(queue_free)
