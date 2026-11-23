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
	var v := Vector3(p.x - dep.x, 0, p.z - dep.z).normalized()
	var mi := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(26.0, 0.04, 0.7)
	mi.mesh = bx
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = COULS[r + 1]
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 90.0
	add_child(mi)
	mi.global_position = p + Vector3(0, 0.06, 0)
	mi.rotation.y = atan2(v.x, v.z) + PI / 2.0

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
