class_name Beaute
extends Node

# Ambiance visuelle : neige qui tombe autour du joueur, vignette cinéma et lignes de vitesse (quand on sprinte).
const CODE := "
shader_type canvas_item;
uniform float vitesse = 0.0;
uniform float temps = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv);
	float a = smoothstep(0.38, 0.9, r) * 0.45;
	float ang = atan(uv.y, uv.x);
	float k = h(vec2(floor(ang * 46.0), floor(temps * 16.0)));
	float l = step(0.8, k) * smoothstep(0.3, 0.62, r) * vitesse;
	vec3 col = mix(vec3(0.02, 0.03, 0.09), vec3(0.85, 0.95, 1.0), l);
	COLOR = vec4(col, clamp(a + l * 0.3, 0.0, 0.8));
}
"

var ville: Node3D
var _neige: GPUParticles3D
var _mat: ShaderMaterial
var _t := 0.0

func installer(v: Node3D) -> void:
	ville = v
	_neige = GPUParticles3D.new()
	_neige.amount = 520
	_neige.lifetime = 9.0
	_neige.preprocess = 9.0
	_neige.local_coords = false
	_neige.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 50, 80))
	_neige.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(32, 0.5, 32)
	pm.direction = Vector3(0.3, -1.0, 0.1)
	pm.spread = 14.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 2.6
	pm.gravity = Vector3(0.5, -0.3, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	_neige.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = Fx.pastille()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.8)
	q.material = m
	_neige.draw_pass_1 = q
	add_child(_neige)
	var cl := CanvasLayer.new()
	cl.layer = 0
	add_child(cl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	cr.material = _mat
	cl.add_child(cr)

func _process(dt: float) -> void:
	if ville == null or ville.camera == null or ville.joueur == null:
		return
	_t += dt
	var dehors: bool = ville.donjon == null and ville.chateau == null and ville.abime == null and not ville.chez_soi and ville.arene == null
	_neige.emitting = dehors
	_neige.visible = dehors
	_neige.global_position = ville.camera.global_position + Vector3(0, 14.0, 0)
	var e: float = ville.joueur.elan
	_mat.set_shader_parameter("vitesse", clampf((e - 0.55) * 2.2, 0.0, 1.0))
	_mat.set_shader_parameter("temps", _t)
