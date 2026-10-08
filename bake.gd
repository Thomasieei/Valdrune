extends Node
# Outil : godot --path . res://bake.tscn
#  1) fabrique les modèles d'outils manquants (pioche, faucille) → assets/tools/*.tscn
#  2) écrit toutes les miniatures dans ui/gen/
func _ready() -> void:
	_save(_pickaxe(), "res://assets/tools/pioche.tscn")
	_save(_sickle(), "res://assets/tools/faucille.tscn")
	var ic := Icons.new(); ic.baking = true; add_child(ic); ic.setup(self)

func _save(n: Node3D, path: String) -> void:
	for c in n.get_children(): _own(c, n)
	var ps := PackedScene.new(); ps.pack(n); ResourceSaver.save(ps, path)
func _own(c: Node, root: Node) -> void:
	c.owner = root
	for k in c.get_children(): _own(k, root)

func _mat(col: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = col; m.roughness = rough; m.metallic = metal; m.cull_mode = BaseMaterial3D.CULL_DISABLED; return m

func _handle(root: Node3D, y0: float, y1: float, r: float) -> void:
	var h := MeshInstance3D.new(); h.name = "Handle"; var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r * 1.1; cm.height = y1 - y0; cm.radial_segments = 8; h.mesh = cm
	h.material_override = _mat(Color("#8a5a32")); h.position.y = (y0 + y1) * 0.5; root.add_child(h)
	var g := MeshInstance3D.new(); g.name = "Grip"; var gm := CylinderMesh.new(); gm.top_radius = r * 1.25; gm.bottom_radius = r * 1.25; gm.height = 0.22; gm.radial_segments = 8; g.mesh = gm
	g.material_override = _mat(Color("#3f6fb0")); g.position.y = y0 + 0.16; root.add_child(g)

# pioche : manche + fer recourbé à deux pointes
func _pickaxe() -> Node3D:
	var root := Node3D.new(); root.name = "Pioche"
	_handle(root, -0.27, 0.95, 0.045)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in 13:
		var t := float(i) / 12.0 * 2.0 - 1.0            # -1 … 1
		var x := t * 0.5; var y := 0.86 - 0.12 * t * t
		var w: float = 0.075 * (1.0 - abs(t)) + 0.012
		pts.append([Vector3(x, y + w, 0), Vector3(x, y - w, 0), w])
	for i in 12:
		var a: Array = pts[i]; var b: Array = pts[i + 1]
		for dz in [-1.0, 1.0]:
			var za: float = float(a[2]) * 0.6 * dz; var zb: float = float(b[2]) * 0.6 * dz
			var q := [a[0] + Vector3(0, 0, za), b[0] + Vector3(0, 0, zb), b[1] + Vector3(0, 0, zb), a[1] + Vector3(0, 0, za)]
			for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(q[k])
		# dessus / dessous
		for edge in [0, 1]:
			var q2 := [a[edge] + Vector3(0, 0, -float(a[2]) * 0.6), b[edge] + Vector3(0, 0, -float(b[2]) * 0.6), b[edge] + Vector3(0, 0, float(b[2]) * 0.6), a[edge] + Vector3(0, 0, float(a[2]) * 0.6)]
			for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(q2[k])
	st.generate_normals()
	var head := MeshInstance3D.new(); head.name = "Head"; head.mesh = st.commit(); head.material_override = _mat(Color("#a7adb6"), 0.45, 0.5); root.add_child(head)
	var col := MeshInstance3D.new(); col.name = "Collar"; var bm := BoxMesh.new(); bm.size = Vector3(0.12, 0.16, 0.12); col.mesh = bm; col.material_override = _mat(Color("#6e6a66"), 0.5, 0.4); col.position.y = 0.86; root.add_child(col)
	return root

# faucille : petit manche + lame en croissant
func _sickle() -> Node3D:
	var root := Node3D.new(); root.name = "Faucille"
	_handle(root, -0.27, 0.32, 0.042)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector2(-0.2, 0.42); var R := 0.32
	var n := 18
	var outer: Array = []; var inner: Array = []
	for i in n + 1:
		var t := float(i) / n
		var a := deg_to_rad(lerp(-25.0, 205.0, t))
		var w := 0.085 * (1.0 - t) + 0.008
		var o := c + Vector2(cos(a), sin(a)) * R
		var inn := c + Vector2(cos(a), sin(a)) * (R - w)
		outer.append(Vector3(o.x, o.y, 0)); inner.append(Vector3(inn.x, inn.y, 0))
	for i in n:
		for dz in [-0.012, 0.012]:
			var q := [outer[i] + Vector3(0, 0, dz), outer[i + 1] + Vector3(0, 0, dz), inner[i + 1] + Vector3(0, 0, dz * 0.2), inner[i] + Vector3(0, 0, dz * 0.2)]
			for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(q[k])
		var q2 := [outer[i] + Vector3(0, 0, -0.012), outer[i + 1] + Vector3(0, 0, -0.012), outer[i + 1] + Vector3(0, 0, 0.012), outer[i] + Vector3(0, 0, 0.012)]
		for k in [0, 1, 2, 0, 2, 3]: st.add_vertex(q2[k])
	st.generate_normals()
	var blade := MeshInstance3D.new(); blade.name = "Blade"; blade.mesh = st.commit(); blade.material_override = _mat(Color("#c9ced6"), 0.35, 0.6); root.add_child(blade)
	var col := MeshInstance3D.new(); col.name = "Collar"; var cm := CylinderMesh.new(); cm.top_radius = 0.055; cm.bottom_radius = 0.055; cm.height = 0.08; col.mesh = cm; col.material_override = _mat(Color("#6e6a66"), 0.5, 0.4); col.position.y = 0.33; root.add_child(col)
	return root
