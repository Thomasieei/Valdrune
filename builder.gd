extends CanvasLayer
class_name Builder
# Mode Construction : poser au doigt n'importe quel modèle 3D du jeu, le déplacer, l'agrandir, le tourner.
# Tout est sauvegardé par carte ; « Exporter » copie le décor en texte pour qu'il devienne le décor officiel.

const GOLD := Color("#f2c35a")
const SOFT := Color("#f4ead6")
const MAGIC := "VALDRUNE-DECOR1:"
var main: Node
var active := false
var objs: Array = []          # {path, pos, rot, sc, yoff, solid, node, body}
var sel := -1
var focus := Vector3.ZERO
var zoom := 1.0
var undo_stack: Array = []
var ui: Control
var bar: HBoxContainer
var info: Label
var sl_size: HSlider
var sl_rot: HSlider
var sl_h: HSlider
var props_box: Control
var solid_btn: Button
var catalog: Control
var cat_id := "batiments"
var ring: MeshInstance3D
var touches := {}
var drag_obj := false
var pinch0 := 0.0
var ang0 := 0.0
var sc0 := 1.0
var rot0 := 0.0
var zoom0 := 1.0
var press_pos := Vector2.ZERO
var press_t := 0
var moved := false
var _sizes := {}
var _syncing := false
var cat_drag := false

func setup(m: Node) -> void:
	main = m; layer = 20
	ui = Control.new(); ui.set_anchors_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.visible = false; add_child(ui)
	ui.theme = main.hud.theme_ui
	_build_ui()
	ring = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.92; tm.outer_radius = 1.0; tm.rings = 32; tm.ring_segments = 4; ring.mesh = tm
	var rm := StandardMaterial3D.new(); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.albedo_color = Color(1.0, 0.85, 0.3); rm.no_depth_test = true; rm.render_priority = 3
	ring.material_override = rm; ring.scale = Vector3(1, 0.05, 1); ring.visible = false; ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(ring)
	load_map()

var note_lbl: Label
func note(t: String, col := Color("#ffe2a0"), _big := false) -> void:
	if note_lbl == null:
		note_lbl = Label.new(); note_lbl.add_theme_font_size_override("font_size", 19); note_lbl.add_theme_constant_override("outline_size", 8)
		note_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9)); note_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP); note_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH; note_lbl.position.y = 70; note_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note_lbl.custom_minimum_size = Vector2(760, 0); note_lbl.offset_left = -380; note_lbl.offset_right = 380
		add_child(note_lbl)
	note_lbl.text = t; note_lbl.add_theme_color_override("font_color", col); note_lbl.modulate.a = 1.0
	var tw := note_lbl.create_tween(); tw.tween_interval(3.5); tw.tween_property(note_lbl, "modulate:a", 0.0, 0.6)

func map_key() -> String: return str(main.world.map_id)

# ——— modèles ———
static func make(m: Node, path: String) -> Node3D:
	var n: Node3D = load(path).instantiate()
	if path.contains("/food/"):
		for mi in n.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).material_override = Crops.pix_mat()
		n.scale = Vector3.ONE * 3.0
	elif path.ends_with(".dae") and m and m.world:
		var g: Color = Color(World.REGIONS[1].get("g1", "#7db04c"))
		for mi in n.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).material_override = m.world.cliff_mat(g)
	elif path.contains("/animals/"):
		n.scale = Vector3.ONE * 0.5
		var ap: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		if ap and ap.has_animation("Idle"): ap.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR; ap.play("Idle")
	return n

func _aabb(path: String, n: Node3D) -> AABB:
	if n.has_meta("aabb"): return n.get_meta("aabb")
	if path.begins_with("@"): return AABB(Vector3(-0.8, 0, -0.8), Vector3(1.6, 2.2, 1.6))
	if _sizes.has(path): return _sizes[path]
	var bb := AABB(); var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var g: MeshInstance3D = mi
		var xf := n.global_transform.affine_inverse() * g.global_transform if g.is_inside_tree() else Transform3D.IDENTITY
		var b: AABB = xf * g.get_aabb()
		bb = b if first else bb.merge(b); first = false
	_sizes[path] = bb
	return bb

func _spawn(path: String, pos: Vector3, rot: float, sc: float, yoff: float, solid: bool) -> Dictionary:
	var n: Node3D
	if path.begins_with("@npc:"): n = _make_npc(path, pos, rot)
	elif path.begins_with("@res:") or path.begins_with("@camp:"): n = Node3D.new()
	elif path.begins_with("@"): n = Prefab.make(path)
	else:
		if not ResourceLoader.exists(path): return {}
		n = make(main, path)
	var base_sc: float = n.scale.x
	if not n.is_inside_tree(): main.world.add_child(n)
	var o := {"path": path, "pos": pos, "rot": rot, "sc": sc, "yoff": yoff, "solid": solid, "node": n, "body": null, "base": base_sc}
	objs.append(o)
	_apply(o)
	return o

# ——— PNJ, ressources et camps de monstres posés à la main ———
const NPC_DEFS := {
	"quest": ["L'Ancien · quêtes", "Mage", "Aldric"], "shop": ["Marchande", "Rogue", "Mara"], "forge": ["Armurier · forge", "Barbarian", "Brokk"],
	"tools:hache": ["Haches · bûcheron", "Barbarian", "Bjorn"], "tools:pioche": ["Pioches · mineur", "Knight", "Gorm"], "tools:faucille": ["Faucilles · herboriste", "Ranger", "Sylve"],
	"auction": ["Hôtel des ventes", "Rogue", "Corvin"], "travel": ["Passeur · voyages rapides", "Ranger", "Fenn"], "mercs": ["Capitaine des mercenaires", "Knight", "Rhéa"],
	"tannery": ["Tanneur", "Barbarian", "Garrick"], "sawmill": ["Scieur de long", "Ranger", "Aubin"], "guard": ["Garde de la ville", "Knight", "Roland"], "talk": ["Villageois", "Rogue", "Odette"],
	"enchant": ["Enchanteresse", "Mage", "Ysaline"],
}
const NPC_IDS := {"quest": "aldric", "shop": "mara", "enchant": "ysaline"}
var _npc_n := 0
func _make_npc(path: String, pos: Vector3, rot: float) -> Node3D:
	var key := path.substr(5)
	var d: Array = NPC_DEFS.get(key, NPC_DEFS.talk)
	var act := key.split(":")[0]
	_npc_n += 1
	var data := {"id": NPC_IDS[act] if NPC_IDS.has(act) else "ed_%s_%d" % [key.replace(":", "_"), _npc_n], "model": d[1], "name": d[2], "role": d[0], "pos": pos, "act": act, "yaw": rot}
	if act == "tools": data["tool"] = key.split(":")[1]
	var n := Npc.new(); main.world.add_child(n); n.setup(main, data); main.npcs.append(n)
	return n

func _rebuild_special(o: Dictionary) -> void:
	var holder: Node3D = o.node
	for c in holder.get_children(): c.queue_free()
	if o.has("nd"): main.world.nodes.erase(o.nd); o.erase("nd")
	if o.has("sp"):
		for e in o.sp.members:
			if is_instance_valid(e): main.enemies.erase(e); e.queue_free()
		main.world.spawns.erase(o.sp); o.erase("sp")
	var parts: PackedStringArray = str(o.path).split(":")
	var p: Vector3 = o.pos
	if parts[0] == "@res":
		var nd: Dictionary = main.world._add_node(parts[1], int(parts[2]), Vector3(p.x, 0, p.z), holder)
		o["nd"] = nd
	else:
		var t: int = clamp(int(parts[1]), 1, 5)
		var sp := {"pos": Vector3(p.x, 0, p.z), "tier": t, "kinds": World.KINDS_BY_T[t], "members": [], "dead_at": -999.0}
		main.world.spawns.append(sp); o["sp"] = sp
		var fire := Prefab.make("@bench"); holder.add_child(fire); fire.global_position = Vector3(p.x + 2.0, main.world.ground_y(p.x + 2.0, p.z), p.z)
		var lb := Label3D.new(); lb.text = "Camp T%d" % t; lb.font_size = 40; lb.modulate = Color("#ff7a68"); lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lb.pixel_size = 0.008
		holder.add_child(lb); lb.global_position = Vector3(p.x, main.world.ground_y(p.x, p.z) + 2.5, p.z); lb.visible = active
		holder.set_meta("label", lb)

func _apply(o: Dictionary) -> void:
	var n: Node3D = o.node
	var p: Vector3 = o.pos
	p.y = main.world.ground_y(p.x, p.z) + float(o.yoff)
	var path: String = o.path
	if o.body and is_instance_valid(o.body): (o.body as Node).queue_free()
	o.body = null
	if path.begins_with("@npc:"):
		n.position = p; n.set("home", p); n.set("yaw", float(o.rot))
		if typeof(n.get("data")) == TYPE_DICTIONARY: n.data["yaw"] = float(o.rot)
		return
	if path.begins_with("@res:") or path.begins_with("@camp:"):
		n.position = Vector3.ZERO; _rebuild_special(o); return
	n.position = p; n.rotation = Vector3(0, o.rot, 0); n.scale = Vector3.ONE * float(o.sc) * float(o.base)
	if n.has_method("conform"): n.conform(main.world)
	if o.solid and n.has_meta("box"):
		var bx: Vector3 = n.get_meta("box") * float(o.sc)
		var bb2 := StaticBody3D.new(); var cs2 := CollisionShape3D.new(); var sh2 := BoxShape3D.new(); sh2.size = Vector3(bx.x, max(2.0, bx.y), bx.z)
		cs2.shape = sh2; cs2.position.y = sh2.size.y * 0.5; bb2.add_child(cs2); bb2.position = p; bb2.rotation.y = o.rot; main.world.add_child(bb2); o.body = bb2
		return
	if o.solid and n.has_meta("radius"):
		var bb3 := StaticBody3D.new(); var cs3 := CollisionShape3D.new(); var cy3 := CylinderShape3D.new(); cy3.radius = float(n.get_meta("radius")) * float(o.sc); cy3.height = 3.0
		cs3.shape = cy3; cs3.position.y = 1.5; bb3.add_child(cs3); bb3.position = p; main.world.add_child(bb3); o.body = bb3
		return
	if n.has_meta("flat"): return
	if o.solid:
		var bb := _aabb(o.path, n)
		var k: float = float(o.sc) * float(o.base)
		var r: float = max(bb.size.x, bb.size.z) * 0.5 * k * 0.75
		var h: float = max(0.5, bb.size.y * k)
		if r > 0.3:
			var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = r; cy.height = h
			cs.shape = cy; cs.position.y = h * 0.5; b.add_child(cs); b.position = p; main.world.add_child(b); o.body = b

func _remove(i: int) -> void:
	var o: Dictionary = objs[i]
	if str(o.path).begins_with("@npc:"): main.npcs.erase(o.node)
	if o.has("nd"): main.world.nodes.erase(o.nd)
	if o.has("sp"):
		for e in o.sp.members:
			if is_instance_valid(e): main.enemies.erase(e); e.queue_free()
		main.world.spawns.erase(o.sp)
	if is_instance_valid(o.node): (o.node as Node).queue_free()
	if o.body and is_instance_valid(o.body): (o.body as Node).queue_free()
	objs.remove_at(i)

# ——— sauvegarde / chargement ———
func _data() -> Array:
	var out := []
	for o in objs:
		out.append([str(o.path) if str(o.path).begins_with("@") else str(o.path).trim_prefix("res://assets/"), snappedf(o.pos.x, 0.01), snappedf(o.pos.z, 0.01), snappedf(o.rot, 0.01), snappedf(o.sc, 0.01), snappedf(o.yoff, 0.01), 1 if o.solid else 0])
	return out

func _load_data(arr: Array) -> void:
	for i in range(objs.size() - 1, -1, -1): _remove(i)
	for e in arr:
		if typeof(e) != TYPE_ARRAY or e.size() < 7: continue
		var pth := str(e[0])
		_spawn(pth if pth.begins_with("@") else "res://assets/" + pth, Vector3(float(e[1]), 0, float(e[2])), float(e[3]), float(e[4]), float(e[5]), int(e[6]) == 1)
	_grass_update()

func _grass_update() -> void:
	var shapes: Array = []
	for o in objs:
		var pth := str(o.path)
		if not pth.begins_with("@") or pth.begins_with("@npc") or pth.begins_with("@res") or pth.begins_with("@camp"): continue
		var n: Node3D = o.node
		if not is_instance_valid(n) or not n.has_meta("aabb"): continue
		if n.has_meta("road"):
			var rt = n
			var gx: Transform3D = n.global_transform
			for i in rt.pts.size() - 1:
				var a3 := gx * Vector3(rt.pts[i].x, 0, rt.pts[i].y); var b3 := gx * Vector3(rt.pts[i + 1].x, 0, rt.pts[i + 1].y)
				var a2 := Vector2(a3.x, a3.z); var b2 := Vector2(b3.x, b3.z)
				shapes.append({"c": (a2 + b2) * 0.5, "half": Vector2((b2 - a2).length() * 0.5 + 0.5, float(rt.w) * float(o.sc) * 0.5 + 0.2), "rot": -(b2 - a2).angle(), "round": false})
			continue
		var ab: AABB = n.get_meta("aabb"); var k: float = float(o.sc) * float(o.base)
		shapes.append({"c": Vector2(o.pos.x, o.pos.z) + Vector2(ab.position.x + ab.size.x * 0.5, ab.position.z + ab.size.z * 0.5).rotated(-float(o.rot)) * k, "half": Vector2(ab.size.x, ab.size.z) * 0.5 * k, "rot": float(o.rot), "round": pth.begins_with("@plaza") or n.has_meta("radius")})
	main.world.grass_mask(shapes)

func save() -> void:
	_grass_update()
	if typeof(Game.S.get("build")) != TYPE_DICTIONARY: Game.S["build"] = {}
	Game.S.build[map_key()] = _data(); Game.save()

func load_map() -> void:
	var saved = Game.S.get("build", {}).get(map_key(), null) if typeof(Game.S.get("build")) == TYPE_DICTIONARY else null
	if saved is Array: _load_data(saved); return
	# décor officiel livré avec le jeu (ce que Thomas a construit et envoyé)
	var f := "res://decor/map_%s.json" % map_key()
	if FileAccess.file_exists(f):
		var d = JSON.parse_string(FileAccess.get_file_as_string(f))
		if d is Array: _load_data(d)

func _push_undo() -> void:
	undo_stack.append(_data())
	if undo_stack.size() > 40: undo_stack.pop_front()

func undo() -> void:
	if undo_stack.is_empty(): note("Rien à annuler", Color("#a8b4bc")); return
	_load_data(undo_stack.pop_back()); select(-1); save()

func export_text() -> String:
	var raw := JSON.stringify({"map": int(map_key()), "objs": _data()}).to_utf8_buffer()
	return MAGIC + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP)) + ":" + str(raw.size())

func import_text(t: String) -> String:
	t = t.strip_edges()
	if not t.begins_with(MAGIC): return "Ce texte n'est pas un décor Valdrune."
	var parts := t.substr(MAGIC.length()).split(":")
	if parts.size() < 2: return "Texte incomplet."
	var raw := Marshalls.base64_to_raw(parts[0]).decompress(int(parts[1]), FileAccess.COMPRESSION_GZIP)
	var d = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or not d.has("objs"): return "Texte abîmé."
	if int(d.get("map", 0)) != int(map_key()): return "Ce décor est celui de la carte %d (tu es sur la carte %s)." % [int(d.map), map_key()]
	_push_undo(); _load_data(d.objs); save()
	return ""

# ——— entrer / sortir ———
func toggle() -> void:
	if active: stop()
	else: start()

func start() -> void:
	if main.in_instance(): main.hud.toast("Le mode Construction marche sur les cartes du royaume (pas en donjon / île / tour)", Color("#ffb07a")); return
	active = true; main.hud.close_panel(); main.hud.visible = false; ui.visible = true
	focus = main.player.global_position; focus.y = 0; zoom = 1.0
	if main.auto_on: main.toggle_auto()
	select(-1); _refresh()
	if not Game.S.tips.has("build"):
		Game.S.tips["build"] = 1
		note("Glisse pour te déplacer · pince pour zoomer · « + Objet » pour poser · touche un objet pour le choisir", Color("#ffe2a0"), true)

func stop() -> void:
	draw_stop(); gen_close()
	active = false; ui.visible = false; main.hud.visible = true; ring.visible = false; catalog.visible = false
	save(); main._cam_update(1.0, true)

# ——— sélection ———
func select(i: int) -> void:
	sel = i
	props_box.visible = sel >= 0
	_refresh()

func _refresh() -> void:
	if not active: return
	info.text = "MODE CONSTRUCTION · %d objet(s) sur cette carte" % objs.size()
	if sel >= 0 and sel < objs.size():
		var o: Dictionary = objs[sel]
		info.text += "   ·   choisi : " + (_title_of(str(o.path)) if str(o.path).begins_with("@") else str(o.path).get_file().get_basename().replace("_", " "))
		_syncing = true
		sl_size.value = o.sc; sl_rot.value = rad_to_deg(wrapf(o.rot, -PI, PI)); sl_h.value = o.yoff
		_syncing = false
		solid_btn.text = "Solide : oui" if o.solid else "Solide : non"
	_update_ring()

func _update_ring() -> void:
	if sel < 0 or sel >= objs.size(): ring.visible = false; return
	var o: Dictionary = objs[sel]
	var bb := _aabb(o.path, o.node)
	var r: float = max(0.6, max(bb.size.x, bb.size.z) * 0.5 * float(o.sc) * float(o.base) + 0.25)
	ring.visible = true; ring.scale = Vector3(r, 0.05 * r, r)
	ring.global_position = _anchor(o) + Vector3(0, 0.08, 0)

func _process(_dt: float) -> void:
	if active and sel >= 0: _update_ring()
	if active and gen_box and gen_box.visible: _gen_ring_upd()

# ——— interface ———
func _btn(t: String, cb: Callable, col := GOLD, w := 128.0) -> Button:
	var b := Button.new(); b.text = t; b.custom_minimum_size = Vector2(w, 54); b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17); b.add_theme_color_override("font_color", col)
	b.pressed.connect(cb); return b

func _slider(parent: Control, title: String, mn: float, mx: float, step: float, cb: Callable) -> HSlider:
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); parent.add_child(hb)
	var l := Label.new(); l.text = title; l.custom_minimum_size = Vector2(84, 0); l.add_theme_font_size_override("font_size", 16); l.add_theme_color_override("font_color", SOFT); hb.add_child(l)
	var s := HSlider.new(); s.min_value = mn; s.max_value = mx; s.step = step; s.custom_minimum_size = Vector2(250, 44); s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v):
		if not _syncing: cb.call(v))
	s.drag_started.connect(_push_undo)
	hb.add_child(s); return s

func _build_ui() -> void:
	var H: Hud = main.hud
	var top := PanelContainer.new(); top.add_theme_stylebox_override("panel", H.flat(Color(0.05, 0.07, 0.1, 0.8), 12, Color(0.95, 0.78, 0.45, 0.35), 1, Vector4(14, 6, 14, 6)))
	top.position = Vector2(10, 8); ui.add_child(top)
	info = Label.new(); info.add_theme_font_size_override("font_size", 17); info.add_theme_color_override("font_color", GOLD); top.add_child(info)
	var bp := PanelContainer.new(); bp.add_theme_stylebox_override("panel", H.flat(Color(0.05, 0.07, 0.1, 0.85), 14, Color(0.95, 0.78, 0.45, 0.35), 1, Vector4(8, 6, 8, 6)))
	bp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); bp.grow_horizontal = Control.GROW_DIRECTION_BOTH; bp.grow_vertical = Control.GROW_DIRECTION_BEGIN; bp.position.y -= 8
	ui.add_child(bp)
	bar = HBoxContainer.new(); bar.add_theme_constant_override("separation", 6); bp.add_child(bar)
	bar.add_child(_btn("+ Objet", func(): show_catalog(), Color("#9be86a")))
	bar.add_child(_btn("✏ Tracer", func(): draw_start("pave"), Color("#ffd27a")))
	bar.add_child(_btn("🏘 Village", func(): gen_open(), Color("#ffd27a")))
	bar.add_child(_btn("Dupliquer", dup))
	bar.add_child(_btn("Supprimer", del, Color("#ff9a8a")))
	bar.add_child(_btn("Annuler", undo))
	bar.add_child(_btn("Héros", func(): focus = main.player.global_position; focus.y = 0))
	bar.add_child(_btn("Exporter", export_dialog, Color("#9fd4ff")))
	bar.add_child(_btn("Terminer", stop, Color("#ffd27a")))
	# propriétés de l'objet choisi (à droite)
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", H.flat(Color(0.05, 0.07, 0.1, 0.85), 14, Color(0.95, 0.78, 0.45, 0.35), 1, Vector4(12, 8, 12, 8)))
	pp.set_anchors_preset(Control.PRESET_TOP_RIGHT); pp.grow_horizontal = Control.GROW_DIRECTION_BEGIN; pp.position = Vector2(-10, 8)
	ui.add_child(pp); props_box = pp
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 4); pp.add_child(pv)
	sl_size = _slider(pv, "Taille", 0.1, 6.0, 0.01, func(v): _set_prop("sc", v))
	sl_rot = _slider(pv, "Rotation", -180.0, 180.0, 1.0, func(v): _set_prop("rot", deg_to_rad(v)))
	sl_h = _slider(pv, "Hauteur", -4.0, 8.0, 0.05, func(v): _set_prop("yoff", v))
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 6); pv.add_child(ph)
	solid_btn = _btn("Solide : oui", func():
		if sel >= 0: _push_undo(); objs[sel].solid = not objs[sel].solid; _apply(objs[sel]); save(); _refresh(), GOLD, 150)
	ph.add_child(solid_btn)
	ph.add_child(_btn("↺ 45°", func(): if sel >= 0: _push_undo(); _set_prop("rot", objs[sel].rot + PI / 4.0); _refresh(), GOLD, 90))
	ph.add_child(_btn("Au sol", func(): if sel >= 0: _push_undo(); _set_prop("yoff", 0.0); _refresh(), GOLD, 100))
	pp.visible = false
	# catalogue (plein écran)
	catalog = PanelContainer.new(); catalog.add_theme_stylebox_override("panel", H.flat(Color(0.05, 0.07, 0.1, 0.96), 18, Color(0.95, 0.78, 0.45, 0.45), 2, Vector4(16, 12, 16, 12)))
	catalog.set_anchors_preset(Control.PRESET_FULL_RECT); catalog.offset_left = 30; catalog.offset_right = -30; catalog.offset_top = 20; catalog.offset_bottom = -20
	catalog.visible = false; ui.add_child(catalog)
	_build_draw_ui()
	_build_gen_ui()

func _set_prop(k: String, v: float) -> void:
	if sel < 0 or sel >= objs.size(): return
	objs[sel][k] = v; _apply(objs[sel]); _update_ring()
	_save_later()

var _save_pending := false
func _save_later() -> void:
	if _save_pending: return
	_save_pending = true
	get_tree().create_timer(1.0).timeout.connect(func(): _save_pending = false; save())

func dup() -> void:
	if sel < 0: note("Choisis d'abord un objet (touche-le)", Color("#a8b4bc")); return
	_push_undo()
	var o: Dictionary = objs[sel]
	var n := _spawn(o.path, o.pos + Vector3(1.5, 0, 1.5) * max(1.0, float(o.sc)), o.rot, o.sc, o.yoff, o.solid)
	if not n.is_empty(): select(objs.size() - 1); save()

func del() -> void:
	if sel < 0: return
	_push_undo(); _remove(sel); select(-1); save()

func add(path: String) -> void:
	_push_undo()
	var p := focus
	var solid := not (path.contains("Grass") or path.contains("/food/") or path.contains("Floor") or path.contains("Bush_1") or path.begins_with("@path") or path.begins_with("@plaza") or path.begins_with("@npc") or path.begins_with("@res") or path.begins_with("@camp"))
	var o := _spawn(path, p, 0.0, 1.0, 0.0, solid)
	if not o.is_empty(): select(objs.size() - 1); save()

# ——— catalogue ———
func show_catalog() -> void:
	for c in catalog.get_children(): c.queue_free()
	catalog.visible = true
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); catalog.add_child(vb)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 6); vb.add_child(top)
	var tl := Label.new(); tl.text = "Choisis un modèle"; tl.add_theme_font_size_override("font_size", 24); tl.add_theme_color_override("font_color", GOLD); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(tl)
	top.add_child(_btn("✕", func(): catalog.visible = false, SOFT, 60))
	var tabs := HFlowContainer.new(); tabs.add_theme_constant_override("h_separation", 6); tabs.add_theme_constant_override("v_separation", 6); vb.add_child(tabs)
	var cur: Array = []
	for c in _cats():
		var b := _btn(c[1], func(): cat_id = c[0]; show_catalog(), Color("#20180a") if c[0] == cat_id else SOFT, 0)
		b.custom_minimum_size = Vector2(0, 42)
		if c[0] == cat_id:
			b.add_theme_stylebox_override("normal", main.hud.flat(GOLD, 14, Color(0, 0, 0, 0), 0, Vector4(12, 4, 12, 4))); cur = c[2]
		tabs.add_child(b)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; vb.add_child(sc)
	sc.scroll_deadzone = 12; sc.scroll_started.connect(func(): cat_drag = true)
	var g := GridContainer.new(); g.columns = 8; g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8); sc.add_child(g)
	var need: Array = []
	for path in cur:
		if str(path).begins_with("@camp"):
			var tb := Button.new(); tb.custom_minimum_size = Vector2(124, 124); tb.focus_mode = Control.FOCUS_NONE
			tb.add_theme_stylebox_override("normal", main.hud.flat(Color("#3a2c1c"), 12, Color("#c79a4a"), 2, Vector4(4, 4, 4, 4)))
			var it := TextureRect.new(); it.texture = main.hud.T(_icon_of(path)); it.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; it.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			it.position = Vector2(32, 8); it.size = Vector2(60, 60); it.mouse_filter = Control.MOUSE_FILTER_IGNORE; tb.add_child(it)
			var tl2 := Label.new(); tl2.text = _title_of(path); tl2.add_theme_font_size_override("font_size", 13); tl2.add_theme_color_override("font_color", SOFT)
			tl2.position = Vector2(4, 70); tl2.size = Vector2(116, 50); tl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl2.mouse_filter = Control.MOUSE_FILTER_IGNORE; tb.add_child(tl2)
			tb.mouse_filter = Control.MOUSE_FILTER_PASS
			tb.button_down.connect(func(): cat_drag = false)
			tb.pressed.connect(func():
				if cat_drag: return
				catalog.visible = false; add(path))
			g.add_child(tb)
			continue
		var b := Button.new(); b.custom_minimum_size = Vector2(124, 124); b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", main.hud.flat(Color("#2c2620"), 12, Color("#c79a4a"), 2, Vector4(4, 4, 4, 4)))
		var key := "cat:" + str(path)
		var tx: Texture2D = main.icons.tex.get(key, null)
		if tx == null: need.append(path)
		var tr := TextureRect.new(); tr.texture = tx; tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(6, 4); tr.size = Vector2(112, 92); tr.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(tr)
		var l := Label.new(); l.text = _title_of(path) if str(path).begins_with("@") else str(path).get_file().get_basename().replace("_", " ").replace("Color1", "").left(18); l.add_theme_font_size_override("font_size", 12 if str(path).begins_with("@") else 11)
		l.add_theme_color_override("font_color", SOFT); l.position = Vector2(4, 100); l.size = Vector2(116, 20); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.clip_text = true; l.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(l)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.button_down.connect(func(): cat_drag = false)
		b.pressed.connect(func():
			if cat_drag: return
			catalog.visible = false; add(path))
		g.add_child(b)
	if not need.is_empty(): main.icons.request_build(need, func(): if catalog.visible: show_catalog())

# catégories : bâtiments tout faits, chemins, PNJ, ressources, monstres, puis les pièces détachées
func _cats() -> Array:
	var b: Array = []; var pa: Array = []; var np: Array = []; var rs: Array = []; var mo: Array = []
	for e in Prefab.BUILDINGS: b.append(e[0])
	b.append("res://assets/halloween/lantern_standing.gltf")
	for e in Prefab.PATHS: pa.append(e[0])
	for k in NPC_DEFS: np.append("@npc:" + k)
	for k in ["wood", "ore", "fiber"]:
		for t in range(1, 6): rs.append("@res:%s:%d" % [k, t])
	for t in range(1, 6): mo.append("@camp:%d" % t)
	return [["batiments", "Bâtiments", b], ["chemins", "Chemins", pa], ["pnj", "PNJ", np], ["ressources", "Ressources", rs], ["monstres", "Monstres", mo]] + Catalog.CATS
func _title_of(path: String) -> String:
	if path.begins_with("@npc:"): return str(NPC_DEFS.get(path.substr(5), ["PNJ"])[0])
	if path.begins_with("@res:"):
		var p := path.split(":"); return "%s T%s" % [{"wood": "Arbre", "ore": "Minerai", "fiber": "Fibre"}[p[1]], p[2]]
	if path.begins_with("@camp:"): return "Camp de monstres T" + path.substr(6)
	if path.begins_with("@road:"): return "Chemin dessiné (" + ("pavés" if path.split(":")[1] == "pave" else "terre") + ")"
	return Prefab.title_of(path)
func _icon_of(path: String) -> String:
	if path.begins_with("@npc:"): return "it_quest"
	if path.begins_with("@res:"): return "it_loot_common"
	if path.begins_with("@camp:"): return "it_hunt"
	for arr in [Prefab.BUILDINGS, Prefab.PATHS]:
		for e in arr:
			if e[0] == path: return e[2]
	return "it_seal"

# ——— export ———
func export_dialog() -> void:
	save()
	var t := export_text()
	DisplayServer.clipboard_set(t)
	for c in catalog.get_children(): c.queue_free()
	catalog.visible = true
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 10); catalog.add_child(vb)
	var tl := Label.new(); tl.text = "Exporter / importer le décor"; tl.add_theme_font_size_override("font_size", 24); tl.add_theme_color_override("font_color", GOLD); vb.add_child(tl)
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = true; r.add_theme_font_size_override("normal_font_size", 17)
	r.text = "[b]Le décor de cette carte (%d objets) est copié ![/b]\nColle-le simplement dans la discussion avec Claude (appui long → Coller). Il deviendra le décor officiel du jeu.\n[color=#a8b4bc]Pour recharger un décor : colle un texte VALDRUNE-DECOR1 ci-dessous puis « Importer ».[/color]" % objs.size()
	vb.add_child(r)
	var te := TextEdit.new(); te.text = t; te.custom_minimum_size = Vector2(0, 160); te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY; te.add_theme_font_size_override("font_size", 12); vb.add_child(te)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); vb.add_child(hb)
	hb.add_child(_btn("Copier à nouveau", func(): DisplayServer.clipboard_set(t); note("Copié !", Color("#9be86a")), GOLD, 200))
	var res := Label.new(); res.add_theme_font_size_override("font_size", 16)
	hb.add_child(_btn("Importer", func():
		var e := import_text(te.text)
		res.text = e if e != "" else "Décor importé !"
		res.add_theme_color_override("font_color", Color("#ff8a7a") if e != "" else Color("#9be86a"))
		_refresh(), Color("#9fd4ff"), 160))
	hb.add_child(_btn("Fermer", func(): catalog.visible = false, SOFT, 140))
	hb.add_child(res)

# ——— doigts : déplacer la vue, choisir, glisser, pincer ———
func ground_at(sp: Vector2) -> Vector3:
	var cam: Camera3D = main.cam
	var o := cam.project_ray_origin(sp); var d := cam.project_ray_normal(sp)
	var t := 0.0; var prev := o
	while t < 260.0:
		var p := o + d * t
		if p.y <= main.world.ground_y(p.x, p.z):
			var a := 0.0; var b := 1.0
			for i in 12:
				var m := (a + b) * 0.5; var q := prev.lerp(p, m)
				if q.y <= main.world.ground_y(q.x, q.z): b = m
				else: a = m
			return prev.lerp(p, b)
		prev = p; t += 0.6
	return o + d * 40.0

# point d'ancrage réel d'un objet (les ressources et camps ont un support placé à l'origine)
func _anchor(o: Dictionary) -> Vector3:
	var p: Vector3 = o.pos
	return Vector3(p.x, main.world.ground_y(p.x, p.z) + float(o.yoff), p.z)

func pick(sp: Vector2) -> int:
	var cam: Camera3D = main.cam
	var best := -1; var bd := 80.0
	for i in objs.size():
		var o: Dictionary = objs[i]
		var n: Node3D = o.node
		var bb := _aabb(o.path, n)
		var k: float = float(o.sc) * float(o.base)
		var c: Vector3 = _anchor(o) + Vector3(0, bb.get_center().y * k, 0)
		if cam.is_position_behind(c): continue
		var d := cam.unproject_position(c).distance_to(sp)
		var rad: float = max(40.0, 30.0 * max(bb.size.x, bb.size.z) * k / max(0.5, zoom))
		if d < rad and d < bd + rad * 0.3: bd = d; best = i
	return best

func _unhandled_input(ev: InputEvent) -> void:
	if not active or catalog.visible: return
	if draw_kind != "" and _draw_input(ev): get_viewport().set_input_as_handled(); return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			touches[ev.index] = ev.position
			if touches.size() == 1:
				press_pos = ev.position; press_t = Time.get_ticks_msec(); moved = false
				var i := pick(ev.position)
				drag_obj = i >= 0 and i == sel
				if drag_obj: _push_undo()
			elif touches.size() == 2:
				var ps: Array = touches.values()
				pinch0 = (ps[0] as Vector2).distance_to(ps[1]); ang0 = ((ps[1] as Vector2) - ps[0]).angle(); zoom0 = zoom
				if sel >= 0: _push_undo(); sc0 = objs[sel].sc; rot0 = objs[sel].rot
				drag_obj = false
		else:
			touches.erase(ev.index)
			if touches.is_empty():
				if not moved and Time.get_ticks_msec() - press_t < 400:
					select(pick(ev.position))
				elif drag_obj: save()
				drag_obj = false
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		if not touches.has(ev.index): return
		var prevp: Vector2 = touches[ev.index]
		touches[ev.index] = ev.position
		if ev.position.distance_to(press_pos) > 10.0: moved = true
		if touches.size() == 1:
			if drag_obj and sel >= 0:
				var g := ground_at(ev.position)
				objs[sel].pos = Vector3(g.x, 0, g.z); _apply(objs[sel]); _update_ring()
			else:
				# glisser la vue
				var cam: Camera3D = main.cam
				var a := ground_at(prevp); var b := ground_at(ev.position)
				var dlt := a - b; dlt.y = 0
				if dlt.length() < 30.0: focus += dlt
		elif touches.size() == 2:
			var ps: Array = touches.values()
			var dist: float = (ps[0] as Vector2).distance_to(ps[1]); var ang: float = ((ps[1] as Vector2) - ps[0]).angle()
			if pinch0 > 10.0:
				if sel >= 0:
					objs[sel].sc = clamp(sc0 * dist / pinch0, 0.1, 8.0)
					objs[sel].rot = rot0 - (ang - ang0)
					_apply(objs[sel]); _update_ring(); _refresh(); _save_later()
				else: zoom = clamp(zoom0 * pinch0 / dist, 0.35, 3.0)
		get_viewport().set_input_as_handled()

# ——— caméra du mode construction ———
func cam_target() -> Array:
	return [focus, Vector3(0, 21.0, 8.5) * zoom]


# ================= TRACER UN CHEMIN AU DOIGT =================
var draw_kind := ""
var draw_w := 3.0
var draw_box: Control
var draw_kind_btns := {}
var draw_w_btn: Button
var drawing := false
var draw_pts: Array = []
var draw_prev: Node3D

func _build_draw_ui() -> void:
	var H: Hud = main.hud
	var bp := PanelContainer.new(); bp.add_theme_stylebox_override("panel", H.flat(Color(0.05, 0.07, 0.1, 0.88), 14, Color(0.95, 0.78, 0.45, 0.5), 2, Vector4(8, 6, 8, 6)))
	bp.set_anchors_preset(Control.PRESET_CENTER_TOP); bp.grow_horizontal = Control.GROW_DIRECTION_BOTH; bp.position.y = 56
	ui.add_child(bp); draw_box = bp
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); bp.add_child(h)
	var l := Label.new(); l.text = "✏ Dessine au doigt :"; l.add_theme_font_size_override("font_size", 17); l.add_theme_color_override("font_color", GOLD); h.add_child(l)
	for kd in [["pave", "Pavés"], ["dirt", "Terre"]]:
		var b := _btn(kd[1], func(): draw_kind = kd[0]; _draw_sync(), GOLD, 100); h.add_child(b); draw_kind_btns[kd[0]] = b
	draw_w_btn = _btn("Largeur 3 m", func(): draw_w = [2.0, 3.0, 4.0, 5.0, 6.0][([2.0, 3.0, 4.0, 5.0, 6.0].find(draw_w) + 1) % 5]; _draw_sync(), GOLD, 140); h.add_child(draw_w_btn)
	h.add_child(_btn("Fini", draw_stop, Color("#9be86a"), 90))
	bp.visible = false

func _draw_sync() -> void:
	for k in draw_kind_btns: (draw_kind_btns[k] as Button).modulate = Color(1, 1, 1) if k == draw_kind else Color(0.55, 0.55, 0.55)
	draw_w_btn.text = "Largeur %d m" % int(draw_w)

func draw_start(kind: String) -> void:
	gen_close(); select(-1)
	draw_kind = kind; draw_box.visible = true; _draw_sync()
	note("Dessine le chemin avec UN doigt · 2 doigts pour bouger la vue · il se lisse et se colle au terrain tout seul", Color("#ffe2a0"))

func draw_stop() -> void:
	draw_kind = ""; drawing = false; draw_pts = []
	if draw_box: draw_box.visible = false
	_clear_preview()

func _clear_preview() -> void:
	if draw_prev and is_instance_valid(draw_prev): draw_prev.queue_free()
	draw_prev = null

func _g2(sp: Vector2) -> Vector2:
	var g := ground_at(sp); return Vector2(g.x, g.z)

func _draw_input(ev: InputEvent) -> bool:
	if ev is InputEventScreenTouch:
		if ev.pressed:
			touches[ev.index] = ev.position
			if touches.size() == 1:
				drawing = true; draw_pts = [_g2(ev.position)]; return true
			# deuxième doigt : on abandonne le trait, la vue reprend la main
			drawing = false; draw_pts = []; _clear_preview()
			touches.erase(ev.index)
			return false
		touches.erase(ev.index)
		if drawing:
			drawing = false; _draw_finish(); return true
		return false
	if ev is InputEventScreenDrag and drawing and touches.size() == 1:
		touches[ev.index] = ev.position
		var q := _g2(ev.position)
		if q.distance_to(draw_pts[draw_pts.size() - 1]) > 0.7:
			draw_pts.append(q)
			if draw_pts.size() % 3 == 0: _draw_preview()
		return true
	return false

func _draw_preview() -> void:
	_clear_preview()
	var pts := _smooth(draw_pts)
	if pts.size() < 2: return
	var c: Vector2 = pts[0]
	var rel: Array = []
	for q: Vector2 in pts: rel.append(q - c)
	draw_prev = Prefab.make(Prefab.road_path(draw_kind, draw_w, rel)); main.world.add_child(draw_prev)
	draw_prev.position = Vector3(c.x, main.world.ground_y(c.x, c.y), c.y); draw_prev.conform(main.world)

# l'« IA » du tracé : rééchantillonne, lisse les à-coups du doigt et raccorde aux chemins existants
static func _resample(pts: Array, step: float) -> Array:
	if pts.size() < 2: return pts
	var outp: Array = [pts[0]]; var acc := 0.0
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]; var b: Vector2 = pts[i]; var seg := a.distance_to(b)
		var t := step - acc
		while t <= seg:
			outp.append(a.lerp(b, t / seg)); t += step
		acc = seg - (t - step)
	if (outp[outp.size() - 1] as Vector2).distance_to(pts[pts.size() - 1]) > step * 0.4: outp.append(pts[pts.size() - 1])
	return outp

static func _smooth(raw: Array) -> Array:
	var pts := _resample(raw, 1.0)
	for it in 3:
		if pts.size() < 3: break
		var np: Array = [pts[0]]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]
			np.append(a.lerp(b, 0.25)); np.append(a.lerp(b, 0.75))
		np.append(pts[pts.size() - 1]); pts = np
	return _resample(pts, 1.2)

func _road_ends() -> Array:
	var ends: Array = []
	for o in objs:
		var n = o.node
		if is_instance_valid(n) and (n as Node3D).has_meta("road") and n.pts.size() >= 2:
			var gx: Transform3D = n.global_transform
			for q: Vector2 in [n.pts[0], n.pts[n.pts.size() - 1]]:
				var w3 := gx * Vector3(q.x, 0, q.y); ends.append(Vector2(w3.x, w3.z))
		if is_instance_valid(n) and str(o.path).begins_with("@plaza"):
			ends.append(Vector2(o.pos.x, o.pos.z))
	return ends

func _draw_finish() -> void:
	_clear_preview()
	if draw_pts.size() < 2: return
	var raw: Array = draw_pts.duplicate()
	# raccord : un bout posé près d'un autre chemin s'y accroche
	var ends := _road_ends()
	for idx in [0, raw.size() - 1]:
		var best := 3.0; var snap = null
		for e: Vector2 in ends:
			var d: float = (raw[idx] as Vector2).distance_to(e)
			if d < best: best = d; snap = e
		if snap != null: raw[idx] = snap
	var pts := _smooth(raw)
	var L := 0.0
	for i in range(1, pts.size()): L += (pts[i] as Vector2).distance_to(pts[i - 1])
	if L < 2.0: return
	var c := Vector2.ZERO
	for q: Vector2 in pts: c += q
	c /= pts.size()
	var rel: Array = []
	for q: Vector2 in pts: rel.append(q - c)
	_push_undo()
	_spawn(Prefab.road_path(draw_kind, draw_w, rel), Vector3(c.x, 0, c.y), 0.0, 1.0, 0.0, false)
	save(); _refresh()
	note("Chemin posé (%d m) · « Annuler » pour l'effacer" % int(L), Color("#9be86a"))

# ================= GÉNÉRATEUR DE VILLAGE =================
var gen_box: Control
var gen_list: VBoxContainer
var gen_ring: MeshInstance3D
var gen_p: Dictionary = {}

const GEN_ROWS := [["rayon", "Taille (rayon, m)", 18, 60, 4], ["maisons", "Maisons", 0, 40, 1], ["boutiques", "Boutiques", 0, 6, 1], ["rues", "Rues", 0, 4, 1],
	["villageois", "Villageois", 0, 12, 1], ["gardes", "Gardes", 0, 6, 1], ["arbres", "Arbres", 0, 80, 5], ["bois", "Arbres à couper", 0, 30, 1],
	["minerai", "Minerais", 0, 30, 1], ["fibre", "Fibres", 0, 30, 1], ["tier", "Tier ressources / monstres", 1, 5, 1], ["camps", "Camps de monstres", 0, 6, 1]]
const GEN_SVC := [["quest", "L'Ancien (quêtes)"], ["shop", "Marchande"], ["forge", "Forge"], ["tools", "Vendeurs d'outils"], ["auction", "Hôtel des ventes"],
	["travel", "Passeur"], ["mercs", "Mercenaires"], ["tannery", "Tanneur"], ["sawmill", "Scieur"], ["enchant", "Enchanteresse"]]

func _build_gen_ui() -> void:
	var H: Hud = main.hud
	gen_box = PanelContainer.new(); gen_box.add_theme_stylebox_override("panel", H.flat(Color(0.05, 0.07, 0.1, 0.93), 16, Color(0.95, 0.78, 0.45, 0.5), 2, Vector4(12, 10, 12, 10)))
	gen_box.set_anchors_preset(Control.PRESET_LEFT_WIDE); gen_box.offset_left = 8; gen_box.offset_top = 8; gen_box.offset_bottom = -8; gen_box.custom_minimum_size = Vector2(430, 0)
	gen_box.visible = false; ui.add_child(gen_box)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 6); gen_box.add_child(vb)
	var t := Label.new(); t.text = "🏘 Générer un village"; t.add_theme_font_size_override("font_size", 22); t.add_theme_color_override("font_color", GOLD); vb.add_child(t)
	var hint := Label.new(); hint.text = "Il se construit dans le cercle doré : glisse la vue pour le placer."; hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", SOFT); hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; vb.add_child(hint)
	var sc := ScrollContainer.new(); sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; vb.add_child(sc)
	gen_list = VBoxContainer.new(); gen_list.add_theme_constant_override("separation", 4); gen_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(gen_list)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6); vb.add_child(hb)
	hb.add_child(_btn("Construire ici", gen_build, Color("#9be86a"), 200))
	hb.add_child(_btn("Fermer", gen_close, SOFT, 110))
	gen_ring = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.985; tm.outer_radius = 1.0; tm.rings = 96; tm.ring_segments = 4; gen_ring.mesh = tm
	var rm := StandardMaterial3D.new(); rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; rm.albedo_color = Color(1.0, 0.82, 0.3); rm.no_depth_test = true; rm.render_priority = 3
	gen_ring.material_override = rm; gen_ring.visible = false; gen_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; main.add_child(gen_ring)

func _gen_fill() -> void:
	for c in gen_list.get_children(): c.queue_free()
	for r in GEN_ROWS:
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); gen_list.add_child(h)
		var l := Label.new(); l.text = r[1]; l.add_theme_font_size_override("font_size", 16); l.add_theme_color_override("font_color", SOFT); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
		var v := Label.new(); v.text = str(gen_p[r[0]]); v.custom_minimum_size = Vector2(46, 0); v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_theme_font_size_override("font_size", 19); v.add_theme_color_override("font_color", GOLD)
		var key: String = r[0]
		var mn: int = r[2]; var mx: int = r[3]; var st: int = r[4]
		var minus := _btn("−", func(): gen_p[key] = clamp(int(gen_p[key]) - st, mn, mx); v.text = str(gen_p[key]); _gen_ring_upd(), SOFT, 52)
		var plus := _btn("+", func(): gen_p[key] = clamp(int(gen_p[key]) + st, mn, mx); v.text = str(gen_p[key]); _gen_ring_upd(), SOFT, 52)
		minus.custom_minimum_size.y = 44; plus.custom_minimum_size.y = 44
		h.add_child(minus); h.add_child(v); h.add_child(plus)
	var tg := HBoxContainer.new(); tg.add_theme_constant_override("separation", 6); gen_list.add_child(tg)
	var pv := _btn("", func(): pass, GOLD, 200); pv.custom_minimum_size.y = 44
	pv.text = "Rues : pavés" if int(gen_p.pave) == 1 else "Rues : terre"
	pv.pressed.connect(func(): gen_p.pave = 1 - int(gen_p.pave); pv.text = "Rues : pavés" if int(gen_p.pave) == 1 else "Rues : terre")
	tg.add_child(pv)
	var dv := _btn("", func(): pass, GOLD, 180); dv.custom_minimum_size.y = 44
	dv.text = "Décor : oui" if int(gen_p.decor) == 1 else "Décor : non"
	dv.pressed.connect(func(): gen_p.decor = 1 - int(gen_p.decor); dv.text = "Décor : oui" if int(gen_p.decor) == 1 else "Décor : non")
	tg.add_child(dv)
	var sl := Label.new(); sl.text = "PNJ de service (touche pour activer)"; sl.add_theme_font_size_override("font_size", 16); sl.add_theme_color_override("font_color", GOLD); gen_list.add_child(sl)
	var g := GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6); gen_list.add_child(g)
	for e in GEN_SVC:
		var key2: String = e[0]
		var b := _btn(e[1], func(): pass, GOLD, 196); b.custom_minimum_size.y = 44
		b.modulate = Color(1, 1, 1) if int(gen_p.svc.get(key2, 0)) == 1 else Color(0.5, 0.5, 0.5)
		b.pressed.connect(func(): gen_p.svc[key2] = 1 - int(gen_p.svc.get(key2, 0)); b.modulate = Color(1, 1, 1) if int(gen_p.svc[key2]) == 1 else Color(0.5, 0.5, 0.5))
		g.add_child(b)

func gen_open() -> void:
	draw_stop(); select(-1)
	if gen_p.is_empty(): gen_p = VillageGen.DEFAULTS.duplicate(true)
	_gen_fill(); gen_box.visible = true; bar.get_parent().visible = false; _gen_ring_upd()

func gen_close() -> void:
	if gen_box: gen_box.visible = false
	if bar: bar.get_parent().visible = true
	if gen_ring: gen_ring.visible = false

func _gen_center() -> Vector3:
	# le centre du cercle : ce que la caméra regarde, décalé pour rester visible à droite du panneau
	var vp := get_viewport().get_visible_rect().size
	return ground_at(Vector2(vp.x * 0.62, vp.y * 0.5))

func _gen_ring_upd() -> void:
	if gen_ring == null or not gen_box.visible: return
	var c := _gen_center(); var r := float(gen_p.rayon)
	gen_ring.visible = true; gen_ring.scale = Vector3(r, 1.0, r)
	gen_ring.global_position = Vector3(c.x, main.world.ground_y(c.x, c.z) + 0.3, c.z)

func gen_build() -> void:
	var c := _gen_center()
	var vg := VillageGen.new()
	var items: Array = vg.plan(main.world, Vector2(c.x, c.z), gen_p, int(Time.get_ticks_msec()))
	if items.is_empty(): note("Impossible ici (eau ou falaise) : déplace le cercle", Color("#ff9a8a")); return
	_push_undo()
	var n := 0
	for it in items:
		var p2: Vector2 = it[1]
		if not _spawn(it[0], Vector3(p2.x, 0, p2.y), float(it[2]), 1.0, 0.0, bool(it[3])).is_empty(): n += 1
	save(); _refresh(); gen_close()
	note("Village construit : %d objets · « Annuler » pour tout retirer, ou touche une pièce pour la modifier" % n, Color("#9be86a"))
