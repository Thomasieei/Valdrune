class_name DecoFire
## Petit feu de cheminée (particules légères, coupées au-delà de 40 m)

static func at(root: Node3D, pos: Vector3) -> void:
	var fire := FX.particles("fire_01", 12, 0.7, [Color(1, 0.85, 0.45, 0.9), Color(1, 0.35, 0.1, 0)], 0.45, false)
	fire.direction = Vector3.UP
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.8
	fire.gravity = Vector3.ZERO
	fire.visibility_range_end = 40.0
	root.add_child(fire)
	fire.global_position = pos
	fire.emitting = true
