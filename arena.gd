extends Node3D
class_name Arena
# Arène fermée (loin du monde, x ≈ 1300) : combats classés JcJ et Épreuves d'Éveil.
# Le monde lui délègue walkable() comme pour les donjons.

const ORIGIN := Vector3(1300, 0, 0)
const R := 15.0
var spawn_pos := ORIGIN + Vector3(0, 0, 9.0)
var foe_pos := ORIGIN + Vector3(0, 0, -9.0)

func walkable(x: float, z: float) -> bool:
	return Vector2(x - ORIGIN.x, z - ORIGIN.z).length() < R - 0.7

func sight(_a: Vector3, _b: Vector3, _r: float) -> bool: return true
func steer(_p: Vector3) -> Vector3: return Vector3.ZERO

func build(trial: bool) -> void:
	var stone := StandardMaterial3D.new(); stone.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png"); stone.uv1_triplanar = true; stone.uv1_scale = Vector3(0.35, 0.35, 0.35)
	stone.albedo_color = Color("#b9a98e") if not trial else Color("#8f86a6")
	# fond sombre
	var bg := MeshInstance3D.new(); var bp := PlaneMesh.new(); bp.size = Vector2(140, 140); bg.mesh = bp
	var bgm := StandardMaterial3D.new(); bgm.albedo_color = Color("#0d0b10") if trial else Color("#1a120a"); bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bg.material_override = bgm
	bg.position = ORIGIN + Vector3(0, -0.6, 0); add_child(bg)
	# sol : grand disque de pierre + collision
	var fl := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = R; cm.bottom_radius = R + 0.6; cm.height = 0.6; cm.radial_segments = 48; fl.mesh = cm
	fl.material_override = stone; fl.position = ORIGIN + Vector3(0, -0.3, 0); add_child(fl)
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = Vector3(R * 2.4, 0.6, R * 2.4); cs.shape = bs; body.add_child(cs); body.position = ORIGIN + Vector3(0, -0.3, 0); add_child(body)
	# motif au sol (cercle intérieur)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.96; tm.outer_radius = 1.0; tm.rings = 64; tm.ring_segments = 3; ring.mesh = tm
	var rm := StandardMaterial3D.new(); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.albedo_color = Color("#ffcf5a") if not trial else Color("#b46bff"); ring.material_override = rm
	ring.scale = Vector3(6.0, 0.02, 6.0); ring.position = ORIGIN + Vector3(0, 0.02, 0); add_child(ring)
	# colonnes, bannières et braseros tout autour
	for i in 12:
		var a := i * TAU / 12.0
		var p := ORIGIN + Vector3(cos(a), 0, sin(a)) * (R + 0.6)
		var pil: Node3D = load("res://assets/dungeon/pillar_decorated.gltf").instantiate(); pil.position = p; pil.scale = Vector3.ONE * 1.4; add_child(pil)
		if i % 3 == 0:
			var ban: Node3D = load("res://assets/dungeon/banner_patternA_red.gltf" if not trial else "res://assets/dungeon/banner_patternB_blue.gltf").instantiate()
			ban.position = ORIGIN + Vector3(cos(a), 0, sin(a)) * (R + 0.2); ban.rotation.y = -a - PI * 0.5; ban.scale = Vector3.ONE * 1.4; add_child(ban)
		if i % 2 == 1:
			var l := OmniLight3D.new(); l.light_color = Color("#ff9a40") if not trial else Color("#b080ff"); l.light_energy = 2.0; l.omni_range = 9.0
			l.position = ORIGIN + Vector3(cos(a), 0, sin(a)) * (R - 1.5) + Vector3(0, 2.5, 0); add_child(l)
	var top := OmniLight3D.new(); top.light_color = Color(1, 0.95, 0.85); top.light_energy = 1.2; top.omni_range = 30.0; top.position = ORIGIN + Vector3(0, 12, 0); add_child(top)
