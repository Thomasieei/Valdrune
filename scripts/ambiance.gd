class_name Ambiance
## Lumière et étalonnage communs : soleil chaud, ombres bleutées, brouillard de distance.

static func setup(parent: Node, interior := false) -> DirectionalLight3D:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.45, 0.66)
	sky_mat.sky_horizon_color = Color(0.70, 0.74, 0.76)
	sky_mat.ground_horizon_color = Color(0.58, 0.60, 0.60)
	sky_mat.ground_bottom_color = Color(0.32, 0.38, 0.33)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55 if not interior else 0.4
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_color = Color(0.74, 0.76, 0.80)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = not interior
	env.fog_light_color = Color(0.66, 0.70, 0.74)
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.0
	# mobile : pas de glow ni d'ajustements (passes plein écran coûteuses)
	env.glow_enabled = false
	env.adjustment_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Soleil"
	sun.light_color = Color(1.0, 0.88, 0.72)
	sun.light_energy = 1.3 if not interior else 0.6
	sun.rotation_degrees = Vector3(-34, -38, 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	# une seule cascade, ombres limitées aux 45 m autour de la caméra
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 32.0   # ombres proches seulement : gros gain sur téléphone
	parent.add_child(sun)
	return sun
