class_name Quartiers
extends Node3D

# Quartiers de rang : portiques colorés aux frontières, brume de la couleur du quartier, annonce à l'entrée.
const RAYONS := [75.0, 150.0, 225.0]
const COULS := [Color(0.35, 1.0, 0.5), Color(0.35, 0.65, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.3, 0.3)]
const BRUME := [Color(0.72, 0.82, 0.72), Color(0.66, 0.74, 0.9), Color(0.78, 0.66, 0.9), Color(0.92, 0.62, 0.62)]
const NOMS := ["QUARTIER E · DÉBUTANTS", "QUARTIER D · ENTRAÎNEMENT", "QUARTIER C · DANGEREUX", "QUARTIER B · MORTEL"]
const SOUS := ["Zone sûre : monstres faibles, parfait pour commencer", "Monstres plus costauds : monte en niveau avant d'avancer", "Élites et chefs : prépare tes ombres et tes potions", "Les plus puissants de la ville : reste prudent !"]
const LEVEL := ["Niv. 1-8", "Niv. 8-15", "Niv. 15-25", "Niv. 25+"]

var ville: Node3D
var _rang := -1
var _t := 0.0

func installer(v: Node3D, pts: Array) -> void:
	ville = v
	var dep: Vector3 = v.DEPART
	var poses: Array = []
	for r in 3:
		for p in pts:
			var d := Vector2(p.x - dep.x, p.z - dep.z).length()
			if absf(d - RAYONS[r]) > 7.0:
				continue
			if poses.any(func (o): return o[0].distance_to(p) < 34.0):
				continue
			poses.append([p, r])
	for o in poses:
		_portique(o[0], int(o[1]))

func _portique(p: Vector3, r: int) -> void:
	var dep: Vector3 = ville.DEPART
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	var v := Vector3(p.x - dep.x, 0, p.z - dep.z).normalized()
	n.rotation.y = atan2(v.x, v.z)
	var c: Color = COULS[r + 1]
	var emi := StandardMaterial3D.new()
	emi.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emi.albedo_color = c
	for sx in [-7.0, 7.0]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9, 12.0, 0.9)
		mi.mesh = b
		mi.material_override = emi
		mi.position = Vector3(sx, 6.0, 0)
		n.add_child(mi)
	var tr := MeshInstance3D.new()
	var bt := BoxMesh.new()
	bt.size = Vector3(15.0, 1.2, 1.0)
	tr.mesh = bt
	tr.material_override = emi
	tr.position = Vector3(0, 12.0, 0)
	n.add_child(tr)
	var vm := StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	vm.cull_mode = BaseMaterial3D.CULL_DISABLED
	vm.albedo_color = Color(c.r, c.g, c.b, 0.1)
	var nap := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(14.0, 11.0)
	nap.mesh = q
	nap.material_override = vm
	nap.position = Vector3(0, 6.0, 0)
	n.add_child(nap)
	var lb := Label3D.new()
	lb.text = "%s\n%s" % [NOMS[r + 1], LEVEL[r + 1]]
	lb.font = Ui.police
	lb.font_size = 38
	lb.outline_size = 10
	lb.pixel_size = 0.0018
	lb.fixed_size = true
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.modulate = c.lightened(0.25)
	lb.position = Vector3(0, 14.5, 0)
	lb.visibility_range_end = 220.0
	n.add_child(lb)
	for s in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.light_color = c
		l.light_energy = 1.4
		l.omni_range = 9.0
		l.position = Vector3(s * 6.0, 3.0, 1.0)
		n.add_child(l)

func _process(dt: float) -> void:
	if ville == null or ville.joueur == null:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.3
	if ville.donjon != null or ville.chateau != null or ville.abime != null or ville.chez_soi:
		_rang = -1
		return
	var r: int = ville.rang_zone(ville.joueur.global_position)
	if r != _rang:
		var premier := _rang < 0
		_rang = r
		if not premier or r > 0:
			ville.hud.annonce(NOMS[r], SOUS[r], COULS[r])
		var tw := create_tween()
		tw.tween_property(ville._env, "fog_light_color", BRUME[r], 2.0)
