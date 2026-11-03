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
const MAX_SHOWN := 30   # chaque ouvrier affecté est VRAIMENT là (jusqu'à 30 par chantier)
static var inst: WorkersView

func _ready() -> void:
	inst = self

var _shown := {"scierie": [], "mine": [], "ferme": []}
var _labels := {}
var _acc := 2.5

func _process(delta: float) -> void:
	_acc += delta
	if _acc < (0.6 if _pending() else 3.0) or Kingdom.inst == null or gathered:
		return
	_acc = 0.0
	for bid in SITES:
		var want := mini(int(Kingdom.bld(bid).get("ouvriers", 0)), MAX_SHOWN)
		var list: Array = _shown[bid]
		list = list.filter(func(v): return is_instance_valid(v))
		var made := 0
		while list.size() < want and made < 3:   # au plus 3 nouveaux par passage : jamais de saccade
			list.append(_spawn(bid, list.size()))
			made += 1
		while list.size() > want:
			var v: Node3D = list.pop_back()
			if v.has_meta("arbre") and is_instance_valid(v.get_meta("arbre")):
				v.get_meta("arbre").queue_free()
			v.queue_free()
		_shown[bid] = list
		_label(bid, int(Kingdom.bld(bid).get("ouvriers", 0)))

func _pending() -> bool:
	for bid in SITES:
		if (_shown[bid] as Array).size() < mini(int(Kingdom.bld(bid).get("ouvriers", 0)), MAX_SHOWN):
			return true
	return false

## Postes de travail répartis sur tout le chantier (lisière, front de taille, rangs des champs)
func _site(bid: String, i: int) -> Array:
	match bid:
		"scierie":
			var c: Vector2 = Layout.LUMBER + Vector2(-16.0 - (i % 6) * 4.5, -14.0 + int(i / 6) * 6.5)
			return [c, -PI / 2.0]
		"mine":
			var c2: Vector2 = Layout.MINE + Vector2(-12.0 + (i % 8) * 3.2, 12.0 + int(i / 8) * 3.4)
			return [c2, PI + 0.3]
		_:
			var f: Vector2 = Layout.FIELDS_MIN + Vector2(10.0 + (i % 8) * 11.0, 12.0 + int(i / 8) * 18.0)
			return [f, (i * 1.7)]

func _spawn(bid: String, i: int) -> Villager:
	var st: Array = _site(bid, i)
	var p: Vector2 = st[0]
	var v := Villager.new()
	v.spec = {"outfit": "paysan_h" if i % 3 != 2 else "paysan_f", "female": i % 3 == 2, "beard": i % 2 == 0, "hair": "Hair_Buzzed" if i % 3 != 2 else "Hair_Buns", "tint": {"scierie": Color(0.55, 0.72, 0.45), "mine": Color(0.58, 0.58, 0.64), "ferme": Color(0.98, 0.86, 0.55)}[bid]}   # tenue du métier
	v.anim_name = SITES[bid]["anim"]
	get_parent().add_child(v)
	v.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	v.rotation.y = st[1]
	var names: Array = Kingdom.data()["pnj"]["noms_h"]
	v.set_meta("talk", {"id": "%s_%d" % [bid, i], "nom": names[(i * 7 + bid.length()) % names.size()], "role": "bucheron" if bid == "scierie" else ("mineur" if bid == "mine" else "paysan")})
	_tool(v, SITES[bid]["outil"])
	if bid == "scierie":
		var tree := Kit.nature(get_parent(), "oak", Vector3(p.x - 1.7, Terrain.height_at(p.x - 1.7, p.y) - 0.1, p.y), randf() * TAU, 1.8)
		v.set_meta("arbre", tree)
	v.set_meta("poste", Vector3(p.x, Terrain.height_at(p.x, p.y), p.y))
	v.set_meta("poste_rot", st[1])
	return v

func count(bid: String) -> int:
	return (_shown[bid] as Array).filter(func(v): return is_instance_valid(v)).size()

# ------------------------------------------------------------------ rassemblement
var gathered := false
## Tous les travailleurs viennent se ranger devant le souverain, par métier
func gather() -> void:
	var p := Combat.player
	gathered = true
	var fwd: Vector3 = p.forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var col := 0
	for bid in ["scierie", "ferme", "mine"]:
		var list: Array = (_shown[bid] as Array).filter(func(v): return is_instance_valid(v))
		for i in list.size():
			var v: Villager = list[i]
			var at: Vector3 = p.global_position + fwd * (4.0 + int(i / 10) * 1.4) + right * ((col - 1) * 9.0 + (i % 10 - 4.5) * 0.85)
			at.y = Powers.ground(at + Vector3.UP)
			v.global_position = at
			v.visible = true
			v.process_mode = Node.PROCESS_MODE_INHERIT
			v.look_at(Vector3(p.global_position.x, at.y, p.global_position.z), Vector3.UP)
			v.rotate_y(PI)
			v.react("Idle", 999.0)
		col += 1
	Magic.halo(p.global_position + Vector3.UP, 3.0, Color(1.0, 0.85, 0.5), 0.6)
	if Hud.inst:
		Hud.inst.discover("Rassemblement !", "%d bûcherons · %d aux champs · %d mineurs" % [count("scierie"), count("ferme"), count("mine")])

## Retour au chantier
func dismiss() -> void:
	gathered = false
	for bid in _shown:
		for v in _shown[bid]:
			if is_instance_valid(v):
				v.global_position = v.get_meta("poste")
				v.rotation.y = v.get_meta("poste_rot")
				v.react(SITES[bid]["anim"], 0.1)

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
