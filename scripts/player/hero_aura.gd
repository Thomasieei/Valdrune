class_name HeroAura
extends Node3D
## Puissance du souverain rendue visible : plus il monte en niveau, plus son aura s'impose
## (braises dorées, puis halo au sol, puis éclairs d'énergie) — et les créatures bien plus faibles
## que lui n'osent plus l'approcher : elles fuient à sa vue.

var tier := -1
var _embers: CPUParticles3D
var _ring: MeshInstance3D
var _acc := 0.0

static func tier_of(level: int) -> int:
	return 0 if level < 6 else (1 if level < 12 else (2 if level < 18 else 3))

func _ready() -> void:
	_embers = FX.particles("spark_04", 16, 1.4, [Color(1, 0.9, 0.5, 0.0), Color(1, 0.8, 0.35, 0.9), Color(1, 0.6, 0.2, 0)], 0.16, false)
	_embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_embers.emission_sphere_radius = 0.6
	_embers.direction = Vector3.UP
	_embers.initial_velocity_min = 0.4
	_embers.initial_velocity_max = 1.2
	_embers.gravity = Vector3(0, 0.6, 0)
	_embers.position.y = 0.9
	add_child(_embers)
	_ring = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.2)
	_ring.mesh = q
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rune_circle.gdshader")
	m.set_shader_parameter("color", Color(1.0, 0.78, 0.35))
	m.set_shader_parameter("intensity", 0.45)
	m.set_shader_parameter("spin", 0.25)
	_ring.material_override = m
	_ring.rotation = Vector3(-PI / 2.0, 0, 0)
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_apply(tier_of(Progression.get_inst().level))
	Progression.get_inst().leveled_up.connect(func(lv: int):
		var t := tier_of(lv)
		if t != tier:
			_apply(t)
			if t > 0 and Hud.inst:
				Hud.inst.discover("Éveil du souverain", ["", "Votre aura s'éveille", "Votre puissance terrifie les faibles", "Une puissance écrasante"][t])
				Magic.pillar(global_position, Color(1.0, 0.8, 0.35), 16.0, 1.2, 2.5))

func _apply(t: int) -> void:
	tier = t
	_embers.emitting = t >= 1
	_embers.amount = [8, 10, 22, 36][t]
	_ring.visible = t >= 2
	(_ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.35 if t == 2 else 0.6)

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5 or tier < 2:
		return
	_acc = 0.0
	# domination : les créatures très inférieures fuient à l'approche du souverain
	var lv := Progression.get_inst().level
	for m in Combat.in_radius(global_position, 9.0 + 3.0 * tier):
		if m.is_boss() or m.def.get("elite", false) or m.kind == "mannequin":
			continue
		if EyePanels.level_of(m) <= lv - (8 - tier) and m.state != Monster.S.FUITE and randf() < 0.35:
			m.frighten(3.0)
	if tier >= 3 and randf() < 0.25:
		var a := randf() * TAU
		Magic.lightning(global_position + Vector3(0, 1.2, 0), global_position + Vector3(cos(a) * 1.4, 0.1, sin(a) * 1.4), Color(1.0, 0.8, 0.4), 0.05, 0.1)
