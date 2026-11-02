class_name Loot
extends Node3D
## Butin au sol : pièces d'or et potions. Attiré vers le joueur quand il approche, ramassé automatiquement.

var kind := "or"     # "or", "soin", "mana"
var amount := 1
var _age := 0.0
var _vel := Vector3.ZERO
var _model: Node3D

static var _coin_mesh: Mesh
static var _coin_mat: StandardMaterial3D

static func drop(m: Node3D) -> void:
	var def: Dictionary = m.def
	var pos := m.global_position + Vector3.UP * 0.8
	var range_or: Array = def["or"]
	var n := randi_range(range_or[0], range_or[1])
	var piles := clampi(n / 4 + 1, 1, 5)
	for i in piles:
		_spawn(pos, "or", n / piles + (n % piles if i == 0 else 0))
	var b: Dictionary = def["butin"]
	if randf() < b.get("soin", 0.0):
		_spawn(pos, "soin", 1)
	if randf() < b.get("mana", 0.0):
		_spawn(pos, "mana", 1)

static func _spawn(pos: Vector3, k: String, a: int) -> void:
	var l := Loot.new()
	l.kind = k
	l.amount = a
	FX.root.add_child(l)
	l.global_position = pos
	l._vel = Vector3(randf_range(-2.5, 2.5), randf_range(3.5, 5.0), randf_range(-2.5, 2.5))

func _ready() -> void:
	if kind == "or":
		if _coin_mesh == null:
			var c := CylinderMesh.new()
			c.top_radius = 0.16
			c.bottom_radius = 0.16
			c.height = 0.05
			c.radial_segments = 10
			c.rings = 1
			_coin_mesh = c
			_coin_mat = FX.solid(Color(1.0, 0.8, 0.25), 0.8)
			_coin_mat.metallic = 0.6
		_model = MeshInstance3D.new()
		(_model as MeshInstance3D).mesh = _coin_mesh
		(_model as MeshInstance3D).material_override = _coin_mat
		_model.rotation.x = PI / 2.0
		add_child(_model)
	else:
		_model = Kit.dungeon(self, "Potion_Red" if kind == "soin" else "Potion_Blue", Vector3.ZERO, 0.0, 1.6)
	var glow := FX.particles("star_06", 4, 0.9, [Color(1, 0.9, 0.5, 0.9) if kind == "or" else (Color(1, 0.4, 0.4, 0.9) if kind == "soin" else Color(0.5, 0.7, 1, 0.9)), Color(1, 1, 1, 0)], 0.3, false)
	glow.gravity = Vector3(0, 0.6, 0)
	glow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glow.emission_sphere_radius = 0.25
	add_child(glow)

func _process(delta: float) -> void:
	_age += delta
	var gy := Terrain.height_at(global_position.x, global_position.z) + 0.25
	var p := Combat.player
	if _age > 0.6 and p and not p.cbt.dead:
		var to := p.global_position + Vector3.UP * 0.9 - global_position
		var d := to.length()
		if d < 0.7:
			_collect()
			return
		if d < 3.5:
			_vel = _vel.lerp(to.normalized() * 11.0, clampf(delta * 8.0, 0, 1))
			global_position += _vel * delta
			return
	_vel.y -= 14.0 * delta
	global_position += _vel * delta
	if global_position.y < gy:
		global_position.y = gy
		_vel = Vector3.ZERO
	if _model:
		_model.rotation.y += delta * 3.0
	if _age > 60.0:
		queue_free()

func _collect() -> void:
	var prog := Progression.get_inst()
	match kind:
		"or":
			prog.add_gold(amount)
			Sfx.play("or", -6.0)
			FX.damage_number(global_position + Vector3.UP * 0.6, "+%d or" % amount, Color(1.0, 0.85, 0.35))
		"soin":
			prog.add_potion("soin")
			Sfx.play("potion", -4.0)
			FX.damage_number(global_position + Vector3.UP * 0.6, "+1 potion de soin", Color(1.0, 0.5, 0.5))
		"mana":
			prog.add_potion("mana")
			Sfx.play("potion", -4.0)
			FX.damage_number(global_position + Vector3.UP * 0.6, "+1 potion de mana", Color(0.55, 0.75, 1.0))
	queue_free()
