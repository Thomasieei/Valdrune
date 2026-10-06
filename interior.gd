extends Node3D
class_name Interior
# Intérieur d'une maison : on entre par la porte, on fouille le coffre… au risque de se faire prendre.
# Construit loin du monde (x ≈ 900), comme les donjons : le monde renvoie une hauteur 0 et demande walkable() ici.

const ORIGIN := Vector3(900, 0, 0)
const RW := 10.0          # largeur de la pièce
const RD := 8.0           # profondeur
var main: Node
var house: Dictionary
var hid := ""
var spawn_pos := Vector3.ZERO
var exit_pos := Vector3.ZERO
var chest_pos := Vector3.ZERO
var chest: Node3D
var owner_npc: Npc
var owner_home := false

func walkable(x: float, z: float) -> bool:
	return abs(x - ORIGIN.x) < RW * 0.5 - 0.5 and z - ORIGIN.z > -RD * 0.5 + 0.5 and z - ORIGIN.z < RD * 0.5 + 0.2

func build(m: Node, h: Dictionary, key: String, seed_v: int) -> void:
	main = m; house = h; hid = key
	var r := RandomNumberGenerator.new(); r.seed = seed_v
	position = Vector3.ZERO
	var wood := StandardMaterial3D.new(); wood.albedo_texture = load("res://assets/village/T_WoodTrim_BaseColor.png"); wood.albedo_color = Color("#b58a62"); wood.uv1_triplanar = true; wood.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var plaster := StandardMaterial3D.new(); plaster.albedo_texture = load("res://assets/village/T_Plaster_BaseColor.png"); plaster.albedo_color = Color("#efe4cc"); plaster.uv1_triplanar = true; plaster.uv1_scale = Vector3(0.4, 0.4, 0.4)
	var beam := StandardMaterial3D.new(); beam.albedo_color = Color("#5a3d26"); beam.roughness = 0.9
	var box := func(sz: Vector3, pos: Vector3, mat: Material, solid: bool) -> void:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm; mi.position = ORIGIN + pos; mi.material_override = mat; add_child(mi)
		if solid:
			var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = sz; cs.shape = sh; b.add_child(cs); b.position = ORIGIN + pos; add_child(b)
	# fond sombre autour de la pièce (on n'est plus dehors)
	var bg := MeshInstance3D.new(); var bp := PlaneMesh.new(); bp.size = Vector2(80, 80); bg.mesh = bp
	var bgm := StandardMaterial3D.new(); bgm.albedo_color = Color("#120c08"); bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bg.material_override = bgm
	bg.position = ORIGIN + Vector3(0, -0.45, 0); add_child(bg)
	# plancher (sol solide) et murs ; le mur de devant est bas (vue en coupe, comme Albion)
	box.call(Vector3(RW + 0.6, 0.4, RD + 0.6), Vector3(0, -0.2, 0), wood, true)
	box.call(Vector3(RW, 3.2, 0.3), Vector3(0, 1.6, -RD * 0.5), plaster, true)
	box.call(Vector3(0.3, 3.2, RD), Vector3(-RW * 0.5, 1.6, 0), plaster, true)
	box.call(Vector3(0.3, 3.2, RD), Vector3(RW * 0.5, 1.6, 0), plaster, true)
	box.call(Vector3(RW * 0.5 - 0.9, 0.9, 0.3), Vector3(-(RW * 0.25 + 0.45), 0.45, RD * 0.5), plaster, true)
	box.call(Vector3(RW * 0.5 - 0.9, 0.9, 0.3), Vector3(RW * 0.25 + 0.45, 0.45, RD * 0.5), plaster, true)
	for x: float in [-RW * 0.5, -RW * 0.17, RW * 0.17, RW * 0.5]:
		box.call(Vector3(0.25, 3.3, 0.25), Vector3(x, 1.65, -RD * 0.5 + 0.1), beam, false)
	box.call(Vector3(RW, 0.25, 0.3), Vector3(0, 3.2, -RD * 0.5 + 0.05), beam, false)
	# tapis
	var rug := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(3.6, 2.4); rug.mesh = pm
	var rm := StandardMaterial3D.new(); rm.albedo_color = [Color("#8a2a24"), Color("#2a4a7a"), Color("#4a6a2a")][r.randi() % 3]; rug.material_override = rm; rug.position = ORIGIN + Vector3(0, 0.02, 0.4); add_child(rug)
	# mobilier : table, lit, cheminée, tonneaux, étagère
	var DG := "res://assets/dungeon/"
	_deco(DG + "table_medium_decorated_A.gltf", Vector3(-2.4, 0, 0.6), 0.0, 0.85, Vector3(1.0, 1.0, 0.6))
	_deco(DG + "candle_triple.gltf", Vector3(-2.4, 0.95, 0.6), 0.0, 0.9, Vector3.ZERO)
	_bed(Vector3(3.3, 0, -1.6), r)
	_deco(DG + "barrel_large.gltf", Vector3(3.8, 0, 2.6), 0.0, 0.45, Vector3(0.6, 1.0, 0.6))
	_deco(DG + "crates_stacked.gltf", Vector3(-4.0, 0, 2.5), 0.0, 0.7, Vector3(0.8, 1.0, 0.8))
	_deco(World._V + "Prop_Chimney.gltf", Vector3(-3.6, 0, -RD * 0.5 + 0.7), 0.0, 1.0, Vector3(1.4, 2.0, 0.8))
	var fire := OmniLight3D.new(); fire.light_color = Color("#ffb060"); fire.light_energy = 2.2; fire.omni_range = 9.0; fire.position = ORIGIN + Vector3(-2.0, 2.2, -1.0); add_child(fire)
	# le coffre, contre le mur du fond
	chest_pos = ORIGIN + Vector3(0.8, 0, -RD * 0.5 + 0.9)
	chest = load(DG + "chest.gltf").instantiate(); chest.position = chest_pos; chest.scale = Vector3.ONE * 0.9; add_child(chest)
	spawn_pos = ORIGIN + Vector3(0, 0, RD * 0.5 - 1.0)
	exit_pos = ORIGIN + Vector3(0, 0, RD * 0.5 - 0.2)
	var lbl := Label3D.new(); lbl.text = "SORTIE"; lbl.font_size = 40; lbl.outline_size = 10; lbl.modulate = Color("#ffe9b8"); lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.008; lbl.position = exit_pos + Vector3(0, 1.4, 0.4); add_child(lbl)
	# l'habitant est parfois chez lui
	owner_home = r.randf() < 0.45
	if owner_home:
		owner_npc = Npc.new(); main.add_child(owner_npc)
		var nm: String = World.RESIDENT_NAMES[r.randi() % World.RESIDENT_NAMES.size()]
		owner_npc.setup(main, {"id": "habitant_" + key, "model": ["Rogue", "Ranger", "Barbarian"][r.randi() % 3], "name": nm, "role": "Habitant (chez lui)", "pos": ORIGIN + Vector3(-2.4, 0, -0.6), "act": "talk", "yaw": 0.0})
		main.npcs.append(owner_npc)

func _deco(path: String, p: Vector3, rot: float, s: float, solid: Vector3) -> void:
	var n: Node3D = load(path).instantiate(); n.position = ORIGIN + p; n.rotation.y = rot; n.scale = Vector3.ONE * s; add_child(n)
	if solid != Vector3.ZERO:
		var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = solid; cs.shape = sh; cs.position.y = solid.y * 0.5; b.add_child(cs); b.position = ORIGIN + p; add_child(b)

func _bed(p: Vector3, r: RandomNumberGenerator) -> void:
	var frame := StandardMaterial3D.new(); frame.albedo_color = Color("#6a4a2e")
	var sheet := StandardMaterial3D.new(); sheet.albedo_color = [Color("#c8433a"), Color("#3a6ab0"), Color("#d8c070")][r.randi() % 3]
	var pil := StandardMaterial3D.new(); pil.albedo_color = Color("#f4ecd8")
	for pt in [[Vector3(1.6, 0.45, 2.4), Vector3(0, 0.22, 0), frame], [Vector3(1.5, 0.18, 1.8), Vector3(0, 0.52, 0.25), sheet], [Vector3(1.2, 0.18, 0.45), Vector3(0, 0.55, -0.85), pil], [Vector3(1.6, 0.9, 0.12), Vector3(0, 0.45, -1.2), frame]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = pt[0]; mi.mesh = bm; mi.position = ORIGIN + p + pt[1]; mi.material_override = pt[2]; add_child(mi)
	var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = Vector3(1.6, 0.8, 2.4); cs.shape = sh; cs.position.y = 0.4; b.add_child(cs); b.position = ORIGIN + p; add_child(b)

func cleanup() -> void:
	if owner_npc and is_instance_valid(owner_npc):
		main.npcs.erase(owner_npc); owner_npc.queue_free()
