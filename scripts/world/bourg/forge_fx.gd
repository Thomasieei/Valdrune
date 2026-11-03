extends Node3D
## Vie de la forge : braise qui gronde (lumière vacillante, flammes), fumée épaisse de la cheminée,
## gerbes d'étincelles au rythme du marteau, vapeur du bac de trempe. Rien n'est calculé loin du joueur.

var anvil := Vector3.ZERO
var furnace := Vector3.ZERO
var chimney := Vector3.ZERO
var trough := Vector3.ZERO
var _t := 0.0
var _steam := 0.0
var _light: OmniLight3D

func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.18)
	_light.light_energy = 2.6
	_light.omni_range = 9.0
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 35.0
	_light.distance_fade_length = 8.0
	_light.set_script(load("res://scripts/world/flicker.gd"))
	add_child(_light)
	_light.global_position = furnace + Vector3(0, 0.6, 0.8)
	var fire := FX.particles("flame_01", 16, 0.7, [Color(1, 0.9, 0.5, 0.0), Color(1, 0.5, 0.15, 0.9), Color(0.4, 0.1, 0.05, 0)], 0.5, false)
	fire.direction = Vector3.UP
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.8
	fire.gravity = Vector3(0, 0.6, 0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fire.emission_box_extents = Vector3(0.5, 0.05, 0.3)
	fire.visibility_range_end = 60.0
	add_child(fire)
	fire.global_position = furnace + Vector3(0, 0.4, -0.4)
	fire.emitting = true
	var sm := FX.particles("smoke_02", 8, 6.0, [Color(0.35, 0.33, 0.33, 0.55), Color(0.55, 0.55, 0.58, 0.0)], 2.2, false, false)
	sm.direction = Vector3(0.15, 1, 0)
	sm.spread = 12.0
	sm.initial_velocity_min = 0.8
	sm.initial_velocity_max = 1.3
	sm.gravity = Vector3(0.2, 0.08, 0)
	sm.visibility_range_end = 220.0
	add_child(sm)
	sm.global_position = chimney
	sm.emitting = true

func _process(delta: float) -> void:
	var p := Combat.player
	if p == null or p.global_position.distance_to(anvil) > 40.0:
		return
	_t += delta
	if _t >= 0.9:
		# coup de marteau : gerbe d'étincelles et tintement
		_t = 0.0
		FX.hit_spark(anvil, Color(1.0, 0.7, 0.25))
		if randf() < 0.5:
			FX.hit_spark(anvil + Vector3(randf_range(-0.2, 0.2), 0.05, randf_range(-0.2, 0.2)), Color(1.0, 0.85, 0.4))
		if p.global_position.distance_to(anvil) < 14.0:
			Sfx.play("coup", -16.0)
	_steam -= delta
	if _steam <= 0.0:
		_steam = randf_range(6.0, 11.0)
		var st := FX.particles("smoke_02", 10, 1.6, [Color(0.95, 0.95, 1.0, 0.5), Color(1, 1, 1, 0.0)], 0.9, true, false)
		st.direction = Vector3.UP
		st.initial_velocity_min = 0.8
		st.initial_velocity_max = 1.6
		st.gravity = Vector3(0, 0.3, 0)
		add_child(st)
		st.global_position = trough
		st.emitting = true
		get_tree().create_timer(2.5).timeout.connect(st.queue_free)
