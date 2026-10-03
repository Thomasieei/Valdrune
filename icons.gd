extends Node
class_name Icons
# Miniatures générées à partir des vrais modèles 3D (rendu dans une SubViewport)

var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var tex := {}          # clé → Texture2D
var queue: Array = []
var busy := false
var main: Node

func setup(m: Node) -> void:
	main = m
	vp = SubViewport.new(); vp.size = Vector2i(160, 160); vp.transparent_bg = true; vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.85, 0.88, 0.95); e.ambient_light_energy = 0.75
	env.environment = e; vp.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, -30, 0); sun.light_energy = 1.35; vp.add_child(sun)
	var rim := DirectionalLight3D.new(); rim.rotation_degrees = Vector3(-20, 150, 0); rim.light_energy = 0.9; rim.light_color = Color(1.0, 0.92, 0.8); vp.add_child(rim)   # contre-jour : silhouettes nettes
	cam = Camera3D.new(); cam.fov = 28.0; vp.add_child(cam)
	holder = Node3D.new(); vp.add_child(holder)
	# file d'attente : ressources, armes, outils, vestes
	for t in range(1, 6):
		for k in ["wood", "ore", "fiber"]: queue.append({"key": "res_%s_%d" % [k, t], "kind": "res", "res": k, "tier": t})
		for wk in Game.WEAPON_KINDS: queue.append({"key": "arme_%s_%d" % [wk, t], "kind": "model", "path": Game.weapon_model(wk, t), "rot": Vector3(0, 0, 0.75), "tier": t})
		queue.append({"key": "bouclier_%d" % t, "kind": "model", "path": Game.shield_model(t), "rot": Vector3(0, -0.35, 0), "tier": t})
	for tool in ["hache", "pioche", "faucille"]: queue.append({"key": tool, "kind": "model", "path": Game.TOOL_MODEL[tool], "rot": Vector3(0, 0, 0.6)})
	# plastrons et bottes : la pièce seule (torse + bras / jambes), comme dans l'inventaire d'Albion
	for k in Game.ARMOR_KINDS:
		var am: String = Game.ARMOR_KINDS[k].model
		queue.append({"key": "armure_" + k, "kind": "piece", "model": am, "parts": [am + "_Body", am + "_ArmLeft", am + "_ArmRight"]})
	for k in Game.GEAR_KINDS.bottes:
		var bm: String = Game.GEAR_KINDS.bottes[k].model
		queue.append({"key": "bottes_" + k, "kind": "piece", "model": bm, "parts": [bm + "_LegLeft", bm + "_LegRight"]})
	queue.push_front({"key": "hero_head", "kind": "piece", "model": "Knight", "parts": ["Knight_Head"]})
	for cm in ["Knight", "Ranger", "Mage"]: queue.append({"key": "char_" + cm, "kind": "char", "model": cm})
	queue.push_front({"key": "potion", "kind": "model", "path": "res://assets/dungeon/bottle_C_green.gltf", "rot": Vector3(0, 0.4, 0)})
	queue.append({"key": "char_Rogue", "kind": "char", "model": "Rogue"})
	queue.append({"key": "char_Barbarian", "kind": "char", "model": "Barbarian"})
	for mk in Game.MOUNTS: queue.append({"key": "mount_" + mk, "kind": "animal", "model": Game.MOUNTS[mk].model, "tint": Game.MOUNTS[mk].get("tint", Color(1, 1, 1))})
	for sl in ["casque", "cape"]:
		for k in Game.GEAR_KINDS[sl]: queue.append({"key": "%s_%s" % [sl, k], "kind": "piece", "model": Game.GEAR_KINDS[sl][k].model, "parts": Game.GEAR_KINDS[sl][k].parts})
	for jk in Game.JUNK: queue.append({"key": "junk_" + jk, "kind": "model", "path": Game.JUNK[jk].model, "rot": Vector3(0.35, 0.5, 0), "tint": Game.JUNK[jk].get("tint", Color(1, 1, 1))})
	# les miniatures déjà faites (changement de carte) sont gardées en mémoire
	tex = Game.icon_cache
	# ressources : icônes dessinées à la main (plus lisibles que des miniatures 3D)
	for k in Game.RES_KEYS:
		for t in range(1, 6):
			var pth := "res://ui/res/res_%s_%d.png" % [k, t]
			if ResourceLoader.exists(pth): tex["res_%s_%d" % [k, t]] = load(pth)
	queue = queue.filter(func(j): return not tex.has(j.key))
	# d'abord ce qu'on voit tout de suite (sac, butin, poupée), ensuite le reste
	var first := queue.filter(func(j): return j.key == "potion" or j.key == "hero_head" or j.key.begins_with("junk_") or j.key.begins_with("armure_") or j.key.begins_with("bottes_") or j.key.ends_with("_1") or j.key in ["hache", "pioche", "faucille"])
	queue = first + queue.filter(func(j): return not (j in first))
	_next()

func get_icon(key: String) -> Texture2D:
	return tex.get(key, null)

func char_icon(model: String) -> Texture2D: return get_icon("char_" + model)

func item_icon(it: Dictionary) -> Texture2D:
	if int(it.get("tier", 1)) <= 0: return null
	match it.slot:
		"artefact": return load("res://ui/%s.png" % Game.ARTEFACTS[it.get("kind", "rage")].icon)
		"monture": return get_icon("mount_" + it.get("kind", "ane"))
		"epee": return get_icon("arme_%s_%d" % [it.get("kind", "epee"), int(it.tier)])
		"bouclier": return get_icon("bouclier_%d" % int(it.tier))
		"armure": return get_icon("armure_" + it.get("kind", "plate"))
		"casque", "cape": return get_icon("%s_%s" % [it.slot, it.get("kind", Game.GEAR_KINDS[it.slot].keys()[0])])
		"bottes":
			var bt = get_icon("bottes_" + str(it.get("kind", "greves")))
			return bt if bt else load("res://ui/boots_%d.png" % clamp(int(it.tier), 1, 5))
		"junk": return get_icon("junk_" + it.get("kind", "os"))
		_: return get_icon(it.slot)

func _next() -> void:
	if queue.is_empty():
		busy = false
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED   # plus rien à dessiner : on coupe ce rendu en plus
		for c in holder.get_children(): c.queue_free()
		if main.hud: main.hud.refresh_panel()   # les miniatures sont prêtes : on rafraîchit la fenêtre ouverte
		return
	busy = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var job: Dictionary = queue.pop_front()
	for c in holder.get_children(): c.queue_free()
	var node: Node3D
	match job.kind:
		"res":
			var path: String = World.NODE_MODEL[job.res][job.tier]
			node = load(path).instantiate()
			var col: Color = Game.TIER_COL[job.tier]
			if job.res == "ore":
				node.scale = Vector3.ONE * 0.5
				for i in 4:
					var cr := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.22; cm.height = 1.0; cm.radial_segments = 6; cr.mesh = cm
					var mm := StandardMaterial3D.new(); mm.albedo_color = col; mm.emission_enabled = true; mm.emission = col; mm.emission_energy_multiplier = 0.6; cr.material_override = mm
					var a := i * TAU / 4.0; cr.position = Vector3(cos(a) * 0.5, 0.6, sin(a) * 0.5); cr.rotation = Vector3(cos(a) * 0.5, 0, -sin(a) * 0.5); node.add_child(cr)
			elif job.res == "fiber":
				_tint(node, Color(1, 1, 1).lerp(col, 0.55))
			elif job.tier == 3: _tint(node, Color("#ffb070"))
		"model":
			node = load(job.path).instantiate(); node.rotation = job.rot
			if job.get("tint", Color(1, 1, 1)) != Color(1, 1, 1): _tint_mul(node, job.tint)
		"animal":
			node = load("res://assets/animals/%s.glb" % job.model).instantiate()
			var aap: AnimationPlayer = node.find_child("AnimationPlayer", true, false)
			if aap and aap.has_animation("Idle"): aap.play("Idle"); aap.seek(0.3, true); aap.pause()
			node.rotation.y = 0.9
			if job.tint != Color(1, 1, 1): _tint_mul(node, job.tint)
		"char":
			var ch := Chars.make("res://assets/heroes/%s.glb" % job.model); node = ch.root
			ch.ap.play("Idle_A"); ch.ap.seek(0.4, true)
		"piece":
			# une seule pièce d'équipement du modèle (casque, cape…), le reste est caché
			var ch2 := Chars.make("res://assets/heroes/%s.glb" % job.model); node = ch2.root
			ch2.ap.play("Idle_A"); ch2.ap.seek(0.4, true)
			var cape: bool = job.key.begins_with("cape")
			for mi in Chars.meshes(node):
				mi.visible = mi.name in job.parts or (cape and mi.name.ends_with("_Body"))
				if cape and mi.name.ends_with("_Body"): mi.material_override = _dark_mat()
			var blb = node.find_child("Blob", false, false)
			if blb: blb.visible = false
			node.rotation.y = PI + 0.6 if cape else 0.5
	holder.add_child(node)
	await get_tree().process_frame
	# cadrage automatique sur la boîte englobante
	var bb := _aabb(node)
	var c := bb.get_center(); var r: float = max(bb.size.x, bb.size.y, bb.size.z) * 0.54
	var dir := Vector3(0.55, 0.45, 1.0).normalized()
	if job.kind == "char": dir = Vector3(0.2, 0.15, 1.0).normalized(); r = bb.size.y * 0.58
	if job.kind == "piece": dir = Vector3(0.25, 0.2, 1.0).normalized(); r = max(bb.size.x, bb.size.y) * 0.62
	if job.kind == "model": dir = Vector3(0, 0.1, 1.0).normalized()
	cam.position = c + dir * (r / tan(deg_to_rad(cam.fov * 0.5)))
	cam.look_at(c, Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	tex[job.key] = ImageTexture.create_from_image(img)
	_next()

var _dm: StandardMaterial3D
func _dark_mat() -> StandardMaterial3D:
	if _dm == null: _dm = StandardMaterial3D.new(); _dm.albedo_color = Color(0.18, 0.2, 0.24)
	return _dm

func _aabb(n: Node) -> AABB:
	var acc := [null]
	_acc(n, acc)
	return acc[0] if acc[0] != null else AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)

func _acc(n: Node, acc: Array) -> void:
	if n is MeshInstance3D and n.mesh and n.visible:
		var a: AABB = n.global_transform * n.mesh.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
	for c in n.get_children(): _acc(c, acc)

func _tint_mul(n: Node, c: Color) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var src = n.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				var m: BaseMaterial3D = src.duplicate(); m.albedo_color = m.albedo_color * c; n.set_surface_override_material(i, m)
	for ch in n.get_children(): _tint_mul(ch, c)

func _tint(n: Node, c: Color) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var src = n.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var m: StandardMaterial3D = src.duplicate(); m.albedo_color = c; n.set_surface_override_material(i, m)
	for ch in n.get_children(): _tint(ch, c)
