class_name Monster
extends CharacterBody3D
## Créature générique pilotée par MonsterDB : errance, détection, poursuite, attaque, fuite, retour au repaire, mort et butin.

enum S { ERRANCE, POURSUITE, ATTAQUE, TOUCHE, FUITE, RETOUR, MORT }

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
		_model = CharBuilder.build({"outfit": m.get_slice(":", 1), "hair": "Hair_Buzzed", "tint": def.get("teinte", Color.WHITE), "hair_color": Color(0.2, 0.22, 0.18)})
		_ap = _model.get_node("AnimationPlayer")
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
	return Combat.player

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
		S.TOUCHE:
			if _t > 0.38:
				_go(S.POURSUITE if def["comportement"] != "lache" or cbt.hp > cbt.max_hp * 0.35 else S.FUITE)
		S.FUITE:
			spd = def["course"]
			move = -to_p
			if _t > 4.0:
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
	if move.length() > 0.2 and mult > 0.0:
		var dir := move.normalized()
		_face(dir, delta, 8.0)
		velocity.x = dir.x * spd * mult
		velocity.z = dir.z * spd * mult
		_play("course" if spd > def["vitesse"] + 0.1 else "marche", 0.2, mult)
	else:
		velocity.x = 0
		velocity.z = 0
		if state != S.ATTAQUE and state != S.TOUCHE:
			_play("attente")
	# éviter de s'empiler sur les congénères
	for o in Combat.monsters:
		if o != self and is_instance_valid(o):
			var d: Vector3 = global_position - o.global_position
			d.y = 0
			var l := d.length()
			if l < 1.0 and l > 0.01:
				velocity += d / l * (1.0 - l) * 3.0
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.5
	move_and_slide()
	var gy := Terrain.height_at(global_position.x, global_position.z)
	if global_position.y < gy - 1.0:
		global_position.y = gy + 0.2
	_bar_mat.set_shader_parameter("fill", cbt.hp / cbt.max_hp)
	_bar.visible = cbt.hp < cbt.max_hp

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
	var prog := Progression.get_inst()
	prog.add_xp(def["xp"])
	FX.damage_number(global_position + Vector3.UP * 2.4, "+%d XP" % def["xp"], Color(0.6, 0.9, 1.0))
	Loot.drop(self)
	if spawner:
		spawner.on_monster_died(self)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(self, "position:y", position.y - 1.6, 1.4)
	tw.tween_callback(queue_free)
