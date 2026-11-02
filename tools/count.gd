extends SceneTree
func tris(m: Mesh) -> int:
	var t := 0
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null and idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return t
func _init():
	var w := Node3D.new()
	root.add_child(w)
	await process_frame
	Ambiance.setup(w); Terrain.build(w); Roads.build(w); Castle.build(w); Town.build(w); Fields.build(w); Places.build(w); Vegetation.build(w)
	for nm in ["Mobilier", "CourDecor", "BourgDecor", "LieuxDecor"]:
		var n = w.get_node_or_null(nm)
		if n: Batcher.merge(n)
	await process_frame
	var per := {}
	for c in w.get_children():
		var t := 0
		var cnt := 0
		for n in c.find_children("*", "MeshInstance3D", true, false) + ([c] if c is MeshInstance3D else []):
			if n.mesh: t += tris(n.mesh); cnt += 1
		for n in c.find_children("*", "MultiMeshInstance3D", true, false):
			if n.multimesh and n.multimesh.mesh: t += tris(n.multimesh.mesh) * n.multimesh.instance_count; cnt += 1
		var k: String = c.get_class() if c.get_class() in ["Node3D"] and c.name.begins_with("@") else String(c.name).split("_")[0]
		if c is Guard or c is Villager: k = "PNJ"
		if not per.has(k): per[k] = [0, 0]
		per[k][0] += t; per[k][1] += cnt
	var keys := per.keys()
	keys.sort_custom(func(a, b): return per[a][0] > per[b][0])
	for k in keys: print("%-18s %9d tris  %5d meshes" % [k, per[k][0], per[k][1]])
	var c1 = CharBuilder.build({"outfit": "rodeur_h"})
	root.add_child(c1)
	for n in c1.find_children("*", "MeshInstance3D", true, false): print("perso rodeur: ", tris(n.mesh), " surfaces=", n.mesh.get_surface_count())
	quit()
