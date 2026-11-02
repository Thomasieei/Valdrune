class_name Batcher
## Fusionne les petits objets de décor statiques (tonneaux, meubles, rochers posés à la main…)
## en un seul maillage par matériau et par zone de 64 m : des centaines d'appels de rendu deviennent quelques-uns.

const CELL := 64.0

static func merge(root: Node3D) -> void:
	var groups := {}   # "cx|cz" -> {material -> SurfaceTool}
	var victims: Array = []
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n != root and (n.is_in_group("pnj") or n.name == "AilesMoulin" or n is Skeleton3D or n is AnimationPlayer):
			continue
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and n != root and n.mesh != null and n.skin == null and not (n.get_parent() is Skeleton3D):
			var mi: MeshInstance3D = n
			if not mi.is_inside_tree() or not mi.visible:
				continue
			if mi.material_override is ShaderMaterial:
				continue
			var xf := mi.global_transform
			var key := "%d|%d" % [int(floor(xf.origin.x / CELL)), int(floor(xf.origin.z / CELL))]
			if not groups.has(key):
				groups[key] = {}
			var g: Dictionary = groups[key]
			var mesh: Mesh = mi.mesh
			for si in mesh.get_surface_count():
				if mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
					continue
				var mat: Material = mi.get_active_material(si)
				if mat == null:
					mat = StandardMaterial3D.new()
				if not g.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					g[mat] = st
				var arrays := mesh.surface_get_arrays(si)
				var st: SurfaceTool = g[mat]
				_append(st, arrays, xf)
			victims.append(mi)
	for mi in victims:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for key in groups:
		var g: Dictionary = groups[key]
		var im := ImporterMesh.new()
		for mat in g:
			var st: SurfaceTool = g[mat]
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, mat)
		im.generate_lods(25.0, 60.0, [])
		var am := im.get_mesh()
		var out := MeshInstance3D.new()
		out.name = "Lot_" + key.replace("|", "_")
		out.mesh = am
		out.visibility_range_end = 150.0
		root.add_child(out)

static func _append(st: SurfaceTool, arrays: Array, xf: Transform3D) -> void:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm = arrays[Mesh.ARRAY_NORMAL]
	var uv = arrays[Mesh.ARRAY_TEX_UV]
	var col = arrays[Mesh.ARRAY_COLOR]
	var idx = arrays[Mesh.ARRAY_INDEX]
	var basis := xf.basis.inverse().transposed()
	var order: PackedInt32Array
	if idx != null and idx.size() > 0:
		order = idx
	else:
		order = PackedInt32Array(range(v.size()))
	var has_n: bool = nrm != null and nrm.size() == v.size()
	var has_uv: bool = uv != null and uv.size() == v.size()
	var has_c: bool = col != null and col.size() == v.size()
	for i in order:
		st.set_normal((basis * nrm[i]).normalized() if has_n else Vector3.UP)
		st.set_uv(uv[i] if has_uv else Vector2.ZERO)
		st.set_color(col[i] if has_c else Color.WHITE)
		st.add_vertex(xf * v[i])
