class_name Portail


static func creer(c1: Color, c2: Color, rayon := 2.0) -> Node3D:
	var n := Node3D.new()
	var disque := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(rayon * 2.0, rayon * 2.0)
	disque.mesh = q
	disque.material_override = Shaders.portail(c1, c2)
	disque.scale = Vector3(1.0, 1.35, 1.0)
	disque.position.y = rayon * 1.35 + 0.1
	disque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(disque)
	var anneau := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = rayon * 0.96
	t.outer_radius = rayon * 1.08
	t.rings = 48
	t.ring_segments = 8
	anneau.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = c1.lightened(0.3)
	m.emission_enabled = true
	m.emission = c1.lightened(0.2)
	m.emission_energy_multiplier = 3.0
	m.metallic = 0.6
	anneau.material_override = m
	anneau.rotation_degrees = Vector3(90, 0, 0)
	anneau.scale = Vector3(1.0, 1.0, 1.35)
	anneau.position = disque.position
	anneau.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(anneau)

	var socle := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = rayon * 1.25
	cy.bottom_radius = rayon * 1.4
	cy.height = 0.25
	socle.mesh = cy
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.16, 0.16, 0.22)
	ms.roughness = 0.7
	ms.emission_enabled = true
	ms.emission = c2 * 0.25
	socle.material_override = ms
	socle.position.y = 0.12
	socle.scale = Vector3(1, 1, 0.45)
	n.add_child(socle)
	var l := OmniLight3D.new()
	l.light_color = c1.lerp(c2, 0.5)
	l.light_energy = 2.5
	l.omni_range = rayon * 5.0
	l.position = Vector3(0, rayon * 1.3, 0.8)
	n.add_child(l)
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = rayon
	pm.emission_ring_inner_radius = rayon * 0.9
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, 0.5, 0)
	var g := Gradient.new()
	g.set_color(0, Color(c1.r, c1.g, c1.b, 1.0))
	g.set_color(1, Color(c2.r, c2.g, c2.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	var mp := StandardMaterial3D.new()
	mp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mp.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mp.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mp.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mp.vertex_color_use_as_albedo = true
	mp.albedo_texture = load("res://assets/fx/etincelle.png")
	qm.material = mp
	p.draw_pass_1 = qm
	p.position = disque.position
	p.scale = Vector3(1.0, 1.35, 1.0)
	n.add_child(p)
	return n
