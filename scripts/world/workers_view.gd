class_name WorkersView
extends Node
## Les ouvriers affectés au bureau royal apparaissent vraiment sur leurs chantiers :
## bûcherons hache en main à la lisière, mineurs pioche en main à l'entrée de la mine, paysans dans les champs.
## Un panneau au-dessus de chaque chantier affiche l'effectif en direct.

const SITES := {
	"scierie": {"nom": "Camp de bûcherons", "anim": "b/TreeChopping", "outil": "hache"},
	"mine": {"nom": "Mine", "anim": "b/Melee_Hook", "outil": "pioche"},
	"ferme": {"nom": "Champs", "anim": "b/Farm_Harvest", "outil": "houe"},
}
const MAX_SHOWN := 6
var _shown := {"scierie": [], "mine": [], "ferme": []}
var _labels := {}
var _acc := 2.5

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 3.0 or Kingdom.inst == null:
		return
	_acc = 0.0
	for bid in SITES:
		var want := mini(int(Kingdom.bld(bid).get("ouvriers", 0)), MAX_SHOWN)
		var list: Array = _shown[bid]
		list = list.filter(func(v): return is_instance_valid(v))
		while list.size() < want:
			list.append(_spawn(bid, list.size()))
		while list.size() > want:
			var v: Node3D = list.pop_back()
			v.queue_free()
		_shown[bid] = list
		_label(bid, int(Kingdom.bld(bid).get("ouvriers", 0)))

func _site(bid: String, i: int) -> Array:
	match bid:
		"scierie":
			var c: Vector2 = Layout.LUMBER + Vector2(-20.0 - (i % 3) * 5.0, -8.0 + (i / 3) * 9.0)
			return [c, -PI / 2.0]
		"mine":
			var c2: Vector2 = Layout.MINE + Vector2(-8.0 + i * 2.6, 14.0 + (i % 2) * 2.0)
			return [c2, PI + 0.3]
		_:
			var f: Vector2 = (Layout.FIELDS_MIN + Layout.FIELDS_MAX) * 0.5 + Vector2(-14.0 + i * 6.0, (i % 2) * 8.0 - 4.0)
			return [f, randf() * TAU]

func _spawn(bid: String, i: int) -> Villager:
	var st: Array = _site(bid, i)
	var p: Vector2 = st[0]
	var v := Villager.new()
	v.spec = {"outfit": "paysan_h" if i % 3 != 2 else "paysan_f", "female": i % 3 == 2, "beard": i % 2 == 0, "hair": "Hair_Buzzed" if i % 3 != 2 else "Hair_Buns", "tint": [Color(0.85, 0.75, 0.65), Color(0.75, 0.8, 0.7), Color(0.8, 0.7, 0.6)][i % 3]}
	v.anim_name = SITES[bid]["anim"]
	get_parent().add_child(v)
	v.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	v.rotation.y = st[1]
	var names: Array = Kingdom.data()["pnj"]["noms_h"]
	v.set_meta("talk", {"id": "%s_%d" % [bid, i], "nom": names[(i * 7 + bid.length()) % names.size()], "role": "bucheron" if bid == "scierie" else ("mineur" if bid == "mine" else "paysan")})
	_tool(v, SITES[bid]["outil"])
	if bid == "scierie":
		Kit.nature(get_parent(), "oak", Vector3(p.x - 1.7, Terrain.height_at(p.x - 1.7, p.y) - 0.1, p.y), randf() * TAU, 1.8)
	return v

## Outil en main : manche de bois + fer (hache, pioche ou houe)
static func _tool(v: Villager, kind: String) -> void:
	var skel: Skeleton3D = v.get_child(0).get_node_or_null("Armature/Skeleton3D")
	if skel == null:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skel.add_child(att)
	var handle := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.045, 0.045, 0.85)
	handle.mesh = hb
	handle.material_override = Geo.mat("bois")
	handle.position = Vector3(0, 0, 0.25)
	att.add_child(handle)
	var head := MeshInstance3D.new()
	var bm := BoxMesh.new()
	match kind:
		"hache": bm.size = Vector3(0.03, 0.22, 0.16)
		"pioche": bm.size = Vector3(0.04, 0.5, 0.07)
		_: bm.size = Vector3(0.18, 0.03, 0.14)
	head.mesh = bm
	head.material_override = Geo.mat("fer")
	head.position = Vector3(0, 0.06 if kind == "hache" else 0.0, 0.64)
	att.add_child(head)

func _label(bid: String, n: int) -> void:
	if not _labels.has(bid):
		var l := Label3D.new()
		l.font_size = 48
		l.outline_size = 10
		l.pixel_size = 0.009
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(1.0, 0.92, 0.7)
		l.no_depth_test = false
		var c: Vector2 = Layout.LUMBER + Vector2(-14, 0) if bid == "scierie" else (Layout.MINE + Vector2(0, 10) if bid == "mine" else (Layout.FIELDS_MIN + Layout.FIELDS_MAX) * 0.5)
		get_parent().add_child(l)
		l.global_position = Vector3(c.x, Terrain.height_at(c.x, c.y) + 5.5, c.y)
		_labels[bid] = l
	(_labels[bid] as Label3D).text = "%s\n%d ouvrier%s" % [SITES[bid]["nom"], n, "s" if n > 1 else ""]
