class_name Shaders



static var _cache := {}

const CODE_OMBRE := "\nshader_type spatial;\nrender_mode cull_back, diffuse_burley, specular_schlick_ggx;\nuniform vec4 contour : source_color = vec4(0.42, 0.18, 1.0, 1.0);\nuniform float force = 0.75;\nvoid fragment() {\n\t// silhouette d'encre : seul un liseré fin s'allume sur les bords\n\tfloat f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);\n\tfloat pulse = 0.85 + 0.15 * sin(TIME * 3.0 + VERTEX.y * 2.0);\n\tALBEDO = vec3(0.006, 0.005, 0.010);\n\tROUGHNESS = 1.0;\n\tSPECULAR = 0.0;\n\tEMISSION = contour.rgb * (f * force * 1.8 * pulse + 0.14);\n}\n"
















const CODE_HALO := "\nshader_type spatial;\nrender_mode blend_add, unshaded, cull_back, depth_draw_never;\nuniform vec4 couleur : source_color = vec4(1.0, 0.75, 0.2, 1.0);\nuniform float force = 1.4;\nvoid fragment() {\n\tfloat f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);\n\tfloat p = 0.75 + 0.25 * sin(TIME * 4.0);\n\tALBEDO = couleur.rgb * f * force * p;\n}\n"












const CODE_PORTAIL := "\nshader_type spatial;\nrender_mode blend_add, unshaded, cull_disabled, depth_draw_never;\nuniform vec4 c1 : source_color = vec4(0.15, 0.45, 1.0, 1.0);\nuniform vec4 c2 : source_color = vec4(0.65, 0.25, 1.0, 1.0);\nfloat bruit(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }\nfloat lisse(vec2 p) {\n\tvec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);\n\treturn mix(mix(bruit(i), bruit(i + vec2(1, 0)), f.x), mix(bruit(i + vec2(0, 1)), bruit(i + vec2(1, 1)), f.x), f.y);\n}\nvoid fragment() {\n\tvec2 uv = UV * 2.0 - 1.0;\n\tfloat r = length(uv);\n\tif (r > 1.0) discard;\n\tfloat a = atan(uv.y, uv.x);\n\tfloat spirale = lisse(vec2(a * 3.0 + r * 6.0 - TIME * 2.2, r * 4.0 - TIME * 0.8));\n\tfloat bord = smoothstep(0.78, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));\n\tfloat coeur = (1.0 - r) * 0.55;\n\tvec3 c = mix(c1.rgb, c2.rgb, spirale);\n\tALBEDO = c * (spirale * 0.9 + coeur) + vec3(0.7, 0.85, 1.0) * bord * 2.2;\n}\n"























const CODE_BARRIERE := "\nshader_type spatial;\nrender_mode blend_add, unshaded, cull_disabled, depth_draw_never;\nuniform vec4 couleur : source_color = vec4(0.85, 0.15, 0.35, 1.0);\nuniform float ouvert = 0.0;\nvoid fragment() {\n\tfloat lignes = pow(abs(sin((UV.y * 18.0 - TIME * 2.5) * 3.14159)), 18.0);\n\tfloat hex = pow(abs(sin(UV.x * 40.0) * sin(UV.y * 22.0 + TIME)), 6.0) * 0.4;\n\tfloat bas = 1.0 - UV.y;\n\tfloat a = (0.18 + lignes * 0.6 + hex) * (0.4 + bas * 0.8) * (1.0 - ouvert);\n\tALBEDO = couleur.rgb * a * 1.6;\n}\n"














const CODE_COLONNE := "\nshader_type spatial;\nrender_mode blend_add, unshaded, cull_disabled, depth_draw_never;\nuniform vec4 couleur : source_color = vec4(0.7, 0.25, 1.0, 1.0);\nvoid fragment() {\n\tfloat bord = pow(1.0 - abs(UV.x * 2.0 - 1.0), 1.5);\n\tfloat monte = 0.7 + 0.3 * sin(UV.y * 30.0 - TIME * 4.0);\n\tfloat haut = 1.0 - smoothstep(0.55, 1.0, UV.y);\n\tfloat bas = smoothstep(0.0, 0.12, UV.y);\n\tALBEDO = couleur.rgb * bord * monte * haut * bas * 2.4;\n}\n"












static func _shader(nom: String, code: String) -> Shader:
	if not _cache.has(nom):
		var s := Shader.new()
		s.code = code
		_cache[nom] = s
	return _cache[nom]

static func ombre(contour: Color) -> ShaderMaterial:
	var cle := "ombre_%s" % contour.to_html()
	if not _cache.has(cle):
		var m := ShaderMaterial.new()
		m.shader = _shader("ombre", CODE_OMBRE)
		m.set_shader_parameter("contour", contour)
		_cache[cle] = m
	return _cache[cle]

static func halo(c: Color, force := 1.4) -> ShaderMaterial:
	var cle := "halo_%s_%.1f" % [c.to_html(), force]
	if not _cache.has(cle):
		var m := ShaderMaterial.new()
		m.shader = _shader("halo", CODE_HALO)
		m.set_shader_parameter("couleur", c)
		m.set_shader_parameter("force", force)
		_cache[cle] = m
	return _cache[cle]

static func portail(c1: Color, c2: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("portail", CODE_PORTAIL)
	m.set_shader_parameter("c1", c1)
	m.set_shader_parameter("c2", c2)
	return m

static func barriere(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("barriere", CODE_BARRIERE)
	m.set_shader_parameter("couleur", c)
	return m

static func colonne(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("colonne", CODE_COLONNE)
	m.set_shader_parameter("couleur", c)
	return m


static func entourer(modele: Node, c: Color, force := 1.4) -> void:
	var m := halo(c, force)
	for mi in modele.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			(mi as MeshInstance3D).material_overlay = m
