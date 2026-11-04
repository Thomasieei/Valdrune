class_name Villager
extends Node3D
## Habitant : occupé à une activité sur place, ou marchant sur un trajet au sol.

var spec := {}
var anim_name := "Idle"
var path: Array = []      # points Vector2 (x, z)
var speed := 1.35
var work_anim := ""        # animation de travail à l'arrivée (champs, bûcheronnage)
var _i := 0
var _ap: AnimationPlayer
var _cur := ""
var _wait := 0.0
var captive := false        # tenu par des gardes / en prison : ne suit plus sa routine
var _anim_until := 0.0
var _leave: Array = []      # trajet de départ (bannissement), puis disparition

func _ready() -> void:
	add_to_group("pnj")
	var m := CharBuilder.build(spec)
	add_child(m)
	# habitants : pas d'ombre dynamique (chaque personnage = ~10 000 triangles redessinés dans la passe d'ombre),
	# une tache d'ombre au sol suffit
	for mi in m.find_children("*", "GeometryInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FX.blob_shadow(self, 0.9)
	_ap = m.get_node("AnimationPlayer")
	if path.size() > 0:
		var p: Vector2 = path[0]
		position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		_play("Walk")
	else:
		_play(anim_name)
		_ap.seek(randf() * 3.0, true)

func _play(a: String) -> void:
	if not _ap.has_animation(a):
		a = "Idle"
	if a != _cur:
		_cur = a
		_ap.play(a, 0.3)

## Petites réactions sociales réutilisables
func react(a: String, dur: float) -> void:
	if not _ap.has_animation(a):
		return
	_cur = a
	_ap.play(a, 0.2)
	_anim_until = Time.get_ticks_msec() / 1000.0 + dur

func kneel(dur := 5.0) -> void:
	react("Fixing_Kneeling", dur)

func nod() -> void:
	react("b/Yes", 2.0)

func leave(points: Array) -> void:
	_leave = points
	captive = true
	path = []

## Niveau de détail de l'animation (économie CPU sur téléphone) : 0 = plein, 1 = 8 images/s
var _lod := 0
var _lod_acc := 0.0
## 0 = plein, 1 = plein à 8 images/s, 2 = silhouette (quelques dizaines de triangles, le vrai modèle masqué)
var _sil: Node3D = null
static var _sil_mesh: Array = []
static var _sil_mats := {}
func set_lod(l: int) -> void:
	if l == _lod or _ap == null:
		return
	_lod = l
	var model: Node3D = get_child(0) if get_child_count() > 0 else null
	if l == 2:
		if _sil == null:
			_sil = _make_silhouette()
		_sil.visible = true
		if model:
			model.visible = false
		_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		return
	if _sil:
		_sil.visible = false
	if model:
		model.visible = true
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL if l == 1 else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

func _make_silhouette() -> Node3D:
	if _sil_mesh.is_empty():
		var body := CapsuleMesh.new()
		body.radius = 0.27
		body.height = 1.3
		body.radial_segments = 6
		body.rings = 1
		var head := SphereMesh.new()
		head.radius = 0.15
		head.height = 0.3
		head.radial_segments = 6
		head.rings = 3
		_sil_mesh = [body, head]
	var col: Color = spec.get("tint", Color(0.8, 0.7, 0.6))
	var key := col.to_html()
	if not _sil_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col.darkened(0.25)
		m.roughness = 1.0
		_sil_mats[key] = m
		var mh := StandardMaterial3D.new()
		mh.albedo_color = Color(0.85, 0.68, 0.55)
		mh.roughness = 1.0
		_sil_mats[key + "t"] = mh
	var n := Node3D.new()
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _sil_mesh[k]
		mi.material_override = _sil_mats[key] if k == 0 else _sil_mats[key + "t"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 0.72 if k == 0 else 1.55
		n.add_child(mi)
	add_child(n)
	return n

func _process(delta: float) -> void:
	if _lod == 2:
		pass   # silhouette : pas d'animation (le déplacement continue plus bas)
	elif _lod == 1:
		_lod_acc += delta
		if _lod_acc > 0.125:
			_ap.advance(_lod_acc)
			_lod_acc = 0.0
	if _leave.size() > 0:
		var t3: Vector2 = _leave[0]
		var here3 := Vector2(position.x, position.z)
		var d3 := t3 - here3
		if d3.length() < 0.6:
			_leave.remove_at(0)
			if _leave.is_empty():
				queue_free()
			return
		_play("Walk")
		here3 += d3.normalized() * speed * 1.2 * delta
		position = Vector3(here3.x, Terrain.height_at(here3.x, here3.y), here3.y)
		rotation.y = atan2(d3.x, d3.y)
		return
	if _anim_until > 0.0:
		if Time.get_ticks_msec() / 1000.0 < _anim_until:
			return
		_anim_until = 0.0
		_cur = ""
		_play(anim_name if path.size() < 2 else "Walk")
	if captive:
		return
	if path.size() < 2:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var t: Vector2 = path[_i]
	var here := Vector2(position.x, position.z)
	var to := t - here
	if to.length() < 0.4:
		_i = (_i + 1) % path.size()
		if work_anim != "":
			_play(work_anim)
			_wait = randf_range(6.0, 12.0)
		else:
			_play("Idle")
			_wait = randf_range(1.5, 4.0)
		return
	_play("Walk")
	var d := to.normalized()
	here += d * speed * delta
	position = Vector3(here.x, Terrain.height_at(here.x, here.y), here.y)
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), clampf(delta * 6.0, 0, 1))
