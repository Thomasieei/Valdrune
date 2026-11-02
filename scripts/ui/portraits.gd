class_name Portraits
extends Node
## Portraits des serviteurs : chaque personnage est rendu une fois (buste, lumière chaude) dans
## un petit monde séparé, puis l'image sert sur les cartes du bureau royal.

static var inst: Portraits
var _cache := {}
var _pending := {}

func _process(_d: float) -> void:
	for vp in _pending.keys():
		_pending[vp] -= 1
		if _pending[vp] <= 0:
			_pending.erase(vp)
			if is_instance_valid(vp):
				vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

static func get_tex(id: String) -> Texture2D:
	if inst == null:
		inst = Portraits.new()
		inst.name = "Portraits"
		inst.process_mode = Node.PROCESS_MODE_ALWAYS
		(Engine.get_main_loop() as SceneTree).current_scene.add_child(inst)
	return inst._portrait(id)

static func spec_of(id: String) -> Dictionary:
	if id == "elian":
		return {"outfit": "paysan_h", "hair": "Hair_SimpleParted", "hair_color": Color(0.85, 0.7, 0.35), "skin_light": true, "tint": Color(0.7, 0.85, 1.0)}
	var n := Talk.node_of(id)
	if n is Villager:
		return (n as Villager).spec
	if n is Guard:
		return {"outfit": "rodeur_h", "skin_light": true, "tint": Color(0.55, 0.62, 0.95), "beard": true}
	return {"outfit": "paysan_h", "hair": "Hair_Buzzed", "beard": true}

func _portrait(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var vp := SubViewport.new()
	vp.size = Vector2i(220, 260)
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.13, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.52)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.85, 0.65)
	key.light_energy = 1.4
	key.rotation_degrees = Vector3(-25, 35, 0)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.65, 1.0)
	rim.light_energy = 0.9
	rim.rotation_degrees = Vector3(-10, 200, 0)
	vp.add_child(rim)
	var m := CharBuilder.build(spec_of(id))
	vp.add_child(m)
	var ap := m.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap and ap.has_animation("Idle"):
		ap.play("Idle")
		ap.seek(0.5, true)
		ap.pause()
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(0.0, 1.55, 1.55)
	cam.look_at(Vector3(0, 1.45, 0), Vector3.UP)
	cam.current = true
	m.rotation.y = 0.35
	# quelques images suffisent : ensuite on fige le portrait (aucun coût par la suite)
	_pending[vp] = 10
	var t := vp.get_texture()
	_cache[id] = t
	return t
