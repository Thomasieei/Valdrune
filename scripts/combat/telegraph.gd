class_name Telegraph
extends MeshInstance3D
## Zone d'attaque au sol : se remplit pendant le temps d'avertissement, puis frappe.
## Formes : "cercle" (rayon), "cone" (rayon + angle), "ligne" (longueur x largeur, depuis l'origine vers l'avant).

signal struck

var shape := "cercle"
var radius := 3.0
var angle_deg := 70.0
var length := 8.0
var width := 2.2
var duration := 1.2
var _t := 0.0
var _mat: ShaderMaterial
static var _shader: Shader

static func spawn(parent: Node, pos: Vector3, yaw: float, shp: String, dur: float, r := 3.0, ang := 70.0, l := 8.0, w := 2.2) -> Telegraph:
	var t := Telegraph.new()
	t.shape = shp
	t.duration = dur
	t.radius = r
	t.angle_deg = ang
	t.length = l
	t.width = w
	parent.add_child(t)
	var gy := Terrain.height_at(pos.x, pos.z)
	if pos.y > gy + 0.6:
		gy = pos.y - 0.05   # sols du château
	t.global_position = Vector3(pos.x, gy + 0.09, pos.z)
	t.rotation.y = yaw
	return t

func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform float fill = 0.0;
uniform int shape = 0;      // 0 cercle, 1 cône, 2 ligne
uniform float half_angle = 0.6;
uniform vec4 col : source_color = vec4(1.0, 0.18, 0.1, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;   // -1..1
	float inside = 0.0;
	float prog = 0.0;
	if (shape == 0) {
		float r = length(p);
		inside = step(r, 1.0);
		prog = r;
		float edge = smoothstep(0.92, 1.0, r) * inside;
		ALPHA = inside * (0.18 + 0.55 * step(r, fill) * 0.6 + edge * 0.8);
	} else if (shape == 1) {
		vec2 q = vec2(p.x, -p.y * 0.5 + 0.5);   // origine au bord
		float r = length(vec2(p.x, (1.0 - UV.y)));
		float a = atan(p.x, 1.0 - UV.y);
		inside = step(r, 1.0) * step(abs(a), half_angle);
		float edge = (smoothstep(0.9, 1.0, r) + smoothstep(half_angle - 0.06, half_angle, abs(a))) * inside;
		ALPHA = inside * (0.18 + 0.5 * step(r, fill) + edge * 0.6);
	} else {
		float along = 1.0 - UV.y;
		inside = 1.0;
		float edge = smoothstep(0.9, 1.0, abs(p.x));
		ALPHA = 0.18 + 0.5 * step(along, fill) + edge * 0.6;
	}
	ALBEDO = col.rgb;
}"""
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	match shape:
		"cercle":
			q.size = Vector2(radius * 2.0, radius * 2.0)
			_mat.set_shader_parameter("shape", 0)
		"cone":
			q.size = Vector2(radius * 2.0, radius)
			q.center_offset = Vector3(0, 0, radius * 0.5)
			_mat.set_shader_parameter("shape", 1)
			_mat.set_shader_parameter("half_angle", deg_to_rad(angle_deg * 0.5))
		"ligne":
			q.size = Vector2(width, length)
			q.center_offset = Vector3(0, 0, length * 0.5)
			_mat.set_shader_parameter("shape", 2)
	mesh = q
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	_t += delta
	var f := clampf(_t / duration, 0.0, 1.0)
	_mat.set_shader_parameter("fill", f)
	if _t >= duration:
		struck.emit()
		var tw := create_tween()
		_mat.set_shader_parameter("col", Color(1.0, 0.85, 0.5))
		tw.tween_interval(0.12)
		tw.tween_callback(queue_free)
		set_process(false)

## Le point est-il dans la zone ?
func contains(p: Vector3) -> bool:
	var local := global_transform.affine_inverse() * p
	var v := Vector2(local.x, local.z)
	match shape:
		"cercle":
			return v.length() <= radius + 0.3
		"cone":
			if v.length() > radius + 0.3 or v.y < -0.3:
				return false
			return absf(rad_to_deg(atan2(v.x, v.y))) <= angle_deg * 0.5 + 6.0
		"ligne":
			return v.y >= -0.4 and v.y <= length + 0.4 and absf(v.x) <= width * 0.5 + 0.3
	return false
