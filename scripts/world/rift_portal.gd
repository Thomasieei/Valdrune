class_name RiftPortal
extends Node3D
## Portail de faille (repris du portail de Brèche Écarlate) : dais de pierre, cercle de runes, deux piliers,
## anneau d'énergie dressé, tourbillon animé, clé de voûte en cristal, éclats en orbite, braseros.
## Couleur = rang du donjon. Une zone au centre déclenche l'entrée.

signal entered
var col := Color(1, 0.3, 0.25)
var scale_k := 1.0
var _ring: MeshInstance3D
var _key: MeshInstance3D
var _shards: Array = []
var _zone: Area3D

static func _emissive(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m

func _ready() -> void:
	var stone := Geo.mat("pierre_base")
	# dais à deux marches
	for k in 2:
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 5.2 if k == 0 else 5.9
		cm.bottom_radius = 5.6 if k == 0 else 6.2
		cm.height = 0.45 if k == 0 else 0.2
		cm.radial_segments = 28
		d.mesh = cm
		d.material_override = stone
		d.position.y = 0.22 if k == 0 else 0.1
		d.scale = Vector3.ONE * scale_k
		add_child(d)
	var rune := Magic.rune(global_position + Vector3.UP * 0.5 * scale_k, 5.0 * scale_k, col, 1e9, 0.12)
	rune.reparent(self)
	# piliers et bannières
	for s in [-1.0, 1.0]:
		var p := Kit.dungeon(self, "Pillar", Vector3(s * 3.6, 0.45, 0) * scale_k, 0.0, 1.0 * scale_k)
		p.scale.y = 1.25 * scale_k
		Kit.dungeon(self, "Banner", Vector3(s * 4.8, 0.45, -0.3) * scale_k, 0.0, 1.1 * scale_k)
	# anneau dressé et tourbillon
	var c := Vector3(0, 3.6, 0) * scale_k
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.55
	tm.outer_radius = 2.95
	tm.rings = 40
	tm.ring_segments = 10
	_ring.mesh = tm
	_ring.material_override = _emissive(col.lightened(0.2), 3.0)
	_ring.rotation.x = PI / 2.0
	_ring.position = c
	_ring.scale = Vector3.ONE * scale_k
	add_child(_ring)
	var arch := MeshInstance3D.new()
	var am := TorusMesh.new()
	am.inner_radius = 3.0
	am.outer_radius = 3.8
	am.rings = 32
	am.ring_segments = 8
	arch.mesh = am
	arch.material_override = stone
	arch.rotation.x = PI / 2.0
	arch.position = c
	arch.scale = Vector3.ONE * scale_k
	add_child(arch)
	var v := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(5.3, 5.3)
	v.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/vortex.gdshader")
	sm.set_shader_parameter("c1", col.darkened(0.75))
	sm.set_shader_parameter("c2", col)
	sm.set_shader_parameter("core", col.lightened(0.7))
	sm.set_shader_parameter("rim", col.lightened(0.3))
	v.material_override = sm
	v.position = c
	v.scale = Vector3.ONE * scale_k
	v.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(v)
	# clé de voûte en cristal et éclats en orbite
	_key = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.9, 1.6, 0.9)
	_key.mesh = pm
	_key.material_override = _emissive(col.lightened(0.4), 2.4)
	_key.position = Vector3(0, 8.3, 0) * scale_k
	add_child(_key)
	for i in 4:
		var e := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.25, 0.45)
		e.mesh = bm
		e.material_override = _key.material_override
		e.set_meta("o", [TAU * i / 6.0, randf_range(4.0, 4.8), randf_range(1.5, 5.5), randf_range(0.4, 0.7)])
		add_child(e)
		_shards.append(e)
	# braseros
	for s in [-1.0, 1.0]:
		var bq := Vector3(s * 4.3, 0.45, 3.4) * scale_k
		Kit.dungeon(self, "Firewood", bq, 0.0, 1.1)
		var f := FX.particles("flame_01", 6, 0.6, [Color(1, 0.9, 0.5, 0.0), col.lightened(0.3), Color(0.3, 0.05, 0.05, 0)], 0.7, false)
		f.direction = Vector3.UP
		f.initial_velocity_min = 0.6
		f.initial_velocity_max = 1.4
		f.visibility_range_end = 70.0
		add_child(f)
		f.position = bq + Vector3(0, 0.3, 0)
		f.emitting = true
	# pas de lumière dynamique (coûteuse sur téléphone) : l'anneau et le tourbillon sont lumineux par eux-mêmes
	# zone d'entrée : on traverse le tourbillon
	_zone = Area3D.new()
	_zone.collision_mask = 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.6, 4.0, 2.4) * scale_k
	cs.shape = bs
	_zone.add_child(cs)
	_zone.position = Vector3(0, 2.0, 0) * scale_k
	add_child(_zone)
	_zone.body_entered.connect(func(b):
		if b == Combat.player:
			entered.emit())

func _process(delta: float) -> void:
	var p := Combat.player
	if p and p.global_position.distance_to(global_position) > 90.0:
		return   # loin : pas d'animation (économie)
	var t := Time.get_ticks_msec() / 1000.0
	_ring.rotation.y += delta * 0.4
	_key.rotation.y = t * 1.2
	for e in _shards:
		var o: Array = e.get_meta("o")
		var a: float = o[0] + t * o[3]
		e.position = Vector3(cos(a) * o[1], o[2] + sin(t * 2.0 + o[0]) * 0.4, sin(a) * o[1] * 0.5) * scale_k
		e.rotation = Vector3(t, t * 0.7, 0)
