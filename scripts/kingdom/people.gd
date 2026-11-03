class_name People
## Les gens du royaume, à la main du souverain : les appeler à soi, les faire s'affronter en duel
## (au premier sang ou à mort), les emprisonner, les bannir, les exécuter.

const FORCE := {"garde": 3.0, "soldat": 3.2, "bucheron": 2.0, "mineur": 2.0, "paysan": 1.4, "habitant": 1.0, "marchand": 0.9, "crieur": 0.8, "elian": 4.0}

## Tout le monde (sauf prisonniers et visiteurs étrangers)
static func all() -> Array:
	var out: Array = []
	var tree := Engine.get_main_loop() as SceneTree
	for n in tree.get_nodes_in_group("pnj"):
		if not is_instance_valid(n) or not n.has_meta("talk"):
			continue
		var r: String = n.get_meta("talk")["role"]
		if r in ["prisonnier", "roi", "nain", "roi_nain", "garde_nain", "escorte_prison"] or (n is Villager and n.captive):
			continue
		out.append(n)
	for s in Escort.members + Army.alive():
		if is_instance_valid(s) and not out.has(s):
			out.append(s)
	return out

static func nom(n: Node3D) -> String:
	if n is Soldier:
		return String(n.nom)
	if n is Companion:
		return "Elian"
	return String(n.get_meta("talk")["nom"])

static func role(n: Node3D) -> String:
	if n is Soldier:
		return "soldat"
	if n is Companion:
		return "elian"
	return String(n.get_meta("talk")["role"])

static func role_label(r: String) -> String:
	return {"garde": "Garde", "soldat": "Soldat", "bucheron": "Bûcheron", "mineur": "Mineur", "paysan": "Paysan", "habitant": "Habitant", "marchand": "Marchand", "crieur": "Crieur", "elian": "Compagnon"}.get(r, r.capitalize())

## Appeler quelqu'un à soi (il arrive par un éclat de lumière)
static func summon(n: Node3D) -> void:
	var p := Combat.player
	var at := p.global_position - p.global_transform.basis.z * -2.2 + p.global_transform.basis.x * randf_range(-1.2, 1.2)
	at.y = Powers.ground(at + Vector3.UP)
	Magic.pillar(n.global_position, Color(0.7, 0.85, 1.0), 4.0, 0.4, 0.6)
	n.global_position = at
	n.visible = true
	n.process_mode = Node.PROCESS_MODE_INHERIT
	n.look_at(Vector3(p.global_position.x, at.y, p.global_position.z), Vector3.UP)
	n.rotate_y(PI)
	if n is Villager:
		(n as Villager).path = []
		(n as Villager).react("b/Yes", 1.5)
	Magic.pillar(at, Color(0.7, 0.85, 1.0), 4.0, 0.5, 0.7)
	Magic.rune(at + Vector3.UP * 0.05, 1.2, Color(0.7, 0.85, 1.0), 1.2, 1.0)
	FX.bark(n, ["Vous m'avez appelé, mon seigneur ?", "À vos ordres !", "Me voici !"][randi() % 3], 2.3, 2.0)

static func _anim(n: Node3D, a: String, dur := 1.0) -> void:
	if n is Villager:
		(n as Villager).react(a, dur)
	elif n.has_method("_play"):
		n._play(a, 0.1)

static func remove(n: Node3D, raison: String) -> void:
	var gs := GameState.get_inst()
	if n.has_meta("talk"):
		var bl: Array = gs.flags.get("bannis", [])
		bl.append(n.get_meta("talk")["id"])
		gs.flags["bannis"] = bl
	if Kingdom.inst:
		Kingdom.add("population", -1)
	gs.report(raison, "acte")
	gs.mark()

## Exécution sur place
static func execute(n: Node3D) -> void:
	var gs := GameState.get_inst()
	gs.add("crainte", 6)
	gs.add("bienveillance", -5)
	gs.add("confiance_habitants", -4)
	FX.bark(n, ["Pitié !", "Non, mon seigneur !", "Je n'ai rien fait !"][randi() % 3], 2.3, 1.6)
	Magic.pillar(n.global_position, Color(1.0, 0.6, 0.3), 5.0, 0.5, 1.0)
	Magic.burst(n.global_position + Vector3.UP, Color(1.0, 0.6, 0.3), 1.2, true)
	_anim(n, "Death01", 3.0)
	if n is Soldier:
		n.cbt.take_damage(999999.0, Combat.player, "magie")
	else:
		remove(n, "%s a été exécuté(e) sur ordre du souverain." % nom(n))
		n.get_tree().create_timer(2.5).timeout.connect(func():
			if is_instance_valid(n):
				n.queue_free())
	# ceux qui ont vu la scène ont peur
	for o in all():
		if o != n and o is Villager and o.global_position.distance_to(n.global_position) < 15.0:
			FX.bark(o, ["Quelle horreur…", "Le seigneur est sans pitié…", "Tais-toi, ou tu seras le prochain."][randi() % 3], 2.3, 2.4)
			break

## Duel entre deux personnes du royaume (mise en scène : échanges de coups, puis le perdant tombe)
static func duel(a: Node3D, b: Node3D, a_mort: bool) -> void:
	var p := Combat.player
	var mid := p.global_position - p.global_transform.basis.z * -4.0
	mid.y = Powers.ground(mid + Vector3.UP)
	for k in 2:
		var n: Node3D = [a, b][k]
		var at := mid + Vector3((k * 2 - 1) * 1.3, 0, 0)
		at.y = Powers.ground(at + Vector3.UP)
		if n is Villager:
			(n as Villager).path = []
			(n as Villager).captive = true
		if n is Soldier:
			n.passive = true
			n.mode = Soldier.M.GARDER
			n.goal = at
		n.global_position = at
		n.visible = true
		n.process_mode = Node.PROCESS_MODE_INHERIT
		var other: Node3D = [b, a][k]
		n.look_at(Vector3(other.global_position.x, at.y, other.global_position.z), Vector3.UP)
		n.rotate_y(PI)
	var ring := Magic.rune(mid + Vector3.UP * 0.05, 3.0, Color(1.0, 0.7, 0.3), 9.0, 0.3)
	FX.bark(a, "En garde !", 2.3, 1.6)
	var fa: float = FORCE.get(role(a), 1.0)
	var fb: float = FORCE.get(role(b), 1.0)
	var a_wins := randf() < fa / (fa + fb)
	var w := Justice.world()
	if w.get("rig"):
		w.rig.frame_talk(p, a, true)
	var tree := p.get_tree()
	for k in 6:
		var atk: Node3D = [a, b][k % 2]
		var def: Node3D = [b, a][k % 2]
		tree.create_timer(0.8 + k * 0.9).timeout.connect(func():
			if not is_instance_valid(atk) or not is_instance_valid(def):
				return
			_anim(atk, "Sword_Attack" if atk is Soldier or role(atk) == "garde" else "Punch_Jab", 0.8)
			tree.create_timer(0.35).timeout.connect(func():
				if is_instance_valid(def):
					_anim(def, "Hit_Chest", 0.5)
					FX.hit_spark(def.global_position + Vector3.UP * 1.2)
					Juice.impact(def.global_position, Color(1.0, 0.8, 0.5), k >= 4)
					Sfx.play("touche", -3.0)))
	tree.create_timer(0.8 + 6 * 0.9 + 0.4).timeout.connect(func():
		var win: Node3D = a if a_wins else b
		var lose: Node3D = b if a_wins else a
		if w.get("rig"):
			w.rig.cine_off()
		if is_instance_valid(ring):
			ring.queue_free()
		for n in [a, b]:
			if is_instance_valid(n) and n is Villager:
				(n as Villager).captive = false
			if is_instance_valid(n) and n is Soldier:
				n.passive = false
		if not is_instance_valid(win) or not is_instance_valid(lose):
			return
		FX.bark(win, ["Victoire !", "Pour le souverain !", "Relève-toi… si tu peux."][randi() % 3], 2.3, 2.2)
		if a_mort:
			GameState.get_inst().add("crainte", 3)
			_anim(lose, "Death01", 3.0)
			if lose is Soldier:
				lose.cbt.take_damage(999999.0, null, "magie")
			else:
				remove(lose, "%s est mort(e) en duel contre %s, sur ordre du souverain." % [nom(lose), nom(win)])
				tree.create_timer(2.5).timeout.connect(func():
					if is_instance_valid(lose):
						lose.queue_free())
		else:
			_anim(lose, "Fixing_Kneeling", 3.0)
			GameState.get_inst().report("Duel : %s l'emporte sur %s." % [nom(win), nom(lose)], "acte")
		if Hud.inst:
			Hud.inst.show_message("%s remporte le duel !" % nom(win), Color(1.0, 0.85, 0.45)))
