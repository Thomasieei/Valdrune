class_name Justice
## Autorité du seigneur sur ses sujets : agenouillement, récompense, protection d'une maison,
## bannissement, arrestation (deux gardes escortent réellement l'habitant jusqu'à la prison de la cour),
## puis libération, procès, travaux forcés ou exécution. Chaque acte pèse sur les jauges
## (bienveillance, autorité, crainte, confiance des habitants) et est consigné dans les rapports.

const CELL := Vector3(-31.0, 12.0, -119.0)     # cellule de la prison (cour du château, côté caserne)
const CELL_DOOR := Vector3(-31.0, 12.0, -115.4)
const EXIT_SOUTH := [Vector2(0, -20), Vector2(6, 20), Vector2(24, 62), Vector2(28, 90)]

static var _built := false

static func world() -> Node3D:
	return (Engine.get_main_loop() as SceneTree).current_scene

static func act(text: String) -> void:
	GameState.get_inst().report(text, "acte")

# ------------------------------------------------------------------ la prison (vrai bâtiment)
static func build_prison(parent: Node3D) -> void:
	if _built:
		return
	_built = true
	var root := Node3D.new()
	root.name = "Prison"
	parent.add_child(root)
	var stone := _tri("pierre_base", 0.35)
	var roofm := _tri("ardoise", 0.3)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.16, 0.18)
	iron.metallic = 0.3
	iron.roughness = 0.6
	var body := StaticBody3D.new()
	body.collision_layer = 2
	root.add_child(body)
	var c := CELL
	var boxes := [
		[Vector3(0, 0.1, 0), Vector3(6.4, 0.2, 7.4), stone],          # dalle
		[Vector3(0, 1.6, -3.5), Vector3(6.4, 3.2, 0.4), stone],        # mur du fond
		[Vector3(-3.0, 1.6, 0), Vector3(0.4, 3.2, 7.4), stone],        # côtés
		[Vector3(3.0, 1.6, 0), Vector3(0.4, 3.2, 7.4), stone],
		[Vector3(0, 3.35, 0), Vector3(6.8, 0.3, 7.8), roofm],          # toit
		[Vector3(0, 3.6, 3.75), Vector3(2.6, 0.5, 0.15), _tri("bois_sombre", 0.5)],   # enseigne
		[Vector3(0, 0.25, 3.6), Vector3(6.0, 0.15, 0.25), iron],       # traverse basse
		[Vector3(0, 3.05, 3.6), Vector3(6.0, 0.15, 0.25), iron],       # traverse haute
	]
	for b in boxes:
		_box(root, body, c + b[0], b[1], b[2], true)
	# barreaux de la façade (la porte est au milieu)
	for i in 21:
		var x := -2.8 + i * 0.28
		_box(root, body, c + Vector3(x, 1.65, 3.6), Vector3(0.07, 2.8, 0.07), iron, true)
	var lbl := Label3D.new()
	lbl.text = "PRISON"
	lbl.font_size = 96
	lbl.outline_size = 18
	lbl.pixel_size = 0.004
	lbl.modulate = Color(1, 0.88, 0.6)
	lbl.outline_modulate = Color(0.1, 0.06, 0.03)
	lbl.position = c + Vector3(0, 3.6, 3.85)
	root.add_child(lbl)
	# un seul maillage par matériau (une trentaine de pièces → 3 appels de rendu)
	var vis := Node3D.new()
	root.add_child(vis)
	for c2 in root.get_children():
		if c2 is MeshInstance3D:
			c2.reparent(vis)
	Batcher.merge(vis, false)
	# les prisonniers enregistrés reprennent leur place
	for pr in Kingdom.k()["prisonniers"]:
		_spawn_prisoner(pr)

static func _tri(name: String, sc: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = Geo.mat(name).duplicate()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * sc
	return m

static func _box(root: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, mat: Material, col: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	if col:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		body.add_child(cs)

static func _cell_spot(i: int) -> Vector3:
	return CELL + Vector3(-1.8 + (i % 3) * 1.8, 0.2, 2.4 - float(i / 3) * 1.3)

static func _spawn_prisoner(pr: Dictionary) -> Villager:
	var v := Villager.new()
	v.spec = {"female": pr.get("fem", false), "outfit": pr.get("outfit", "paysan_h"), "tint": Color(0.75, 0.72, 0.68)}
	v.anim_name = "Idle"
	world().add_child(v)
	var i: int = Kingdom.k()["prisonniers"].find(pr)
	v.global_position = _cell_spot(maxi(i, 0))
	v.rotation.y = 0.0
	v.captive = true
	v.set_meta("talk", {"id": pr["id"], "nom": pr["nom"], "role": "prisonnier"})
	return v

static func prisoner_record(id: String) -> Dictionary:
	for pr in Kingdom.k()["prisonniers"]:
		if pr["id"] == id:
			return pr
	return {}

# ------------------------------------------------------------------ actes envers un habitant
static func kneel(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var m := gs.mem(t["id"])
	m["agenouille"] = int(m.get("agenouille", 0)) + 1
	gs.add("autorite", 2)
	gs.add("crainte", 2)
	m["relation"] = int(m.get("relation", 0)) - (1 if int(m["agenouille"]) == 1 else 4)
	if int(m["agenouille"]) >= 2:
		gs.add("confiance_habitants", -1)
	if n.has_method("kneel"):
		n.kneel(5.0)
	elif n.has_method("react"):
		n.react("Fixing_Kneeling", 5.0)
	FX.bark(n, "Oui… mon seigneur." if int(m["agenouille"]) == 1 else "Encore… ? Comme vous voudrez.", 2.3, 3.0)
	act("Vous avez fait agenouiller %s devant vous." % t["nom"])

static func reward(n: Node3D) -> String:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var m := gs.mem(t["id"])
	var day := int(Kingdom.res("jour")) if Kingdom.inst else 0
	if int(m.get("recompense_jour", -1)) == day:
		return "Vous l'avez déjà récompensé aujourd'hui"
	var prog := Progression.get_inst()
	if prog.gold < 25:
		return "Il vous faut 25 pièces d'or"
	prog.add_gold(-25)
	m["recompense_jour"] = day
	m["relation"] = int(m.get("relation", 0)) + 6
	gs.add("bienveillance", 2)
	gs.add("confiance_habitants", 2)
	gs.add("reputation", 1)
	if n.has_method("nod"):
		n.nod()
	FX.bark(n, "Merci, {titre} ! Ma famille ne l'oubliera pas.".replace("{titre}", gs.titre), 2.3, 3.0)
	act("Vous avez donné 25 pièces d'or à %s et sa famille pour sa loyauté." % t["nom"])
	return ""

## Un soldat part réellement veiller sur la maison de l'habitant
static func protect_house(n: Node3D) -> String:
	if Escort.available() <= 0 and int(Kingdom.res("soldats")) < 3:
		return "Aucun soldat disponible"
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var m := gs.mem(t["id"])
	var s := Soldier.new()
	s.nom = Kingdom.data()["pnj"]["noms_h"][randi() % 12]
	s.home = Escort.GATE
	world().add_child(s)
	var p := Combat.player
	var from: Vector3 = p.global_position - p.global_transform.basis.z * 12.0 if p.global_position.distance_to(Escort.GATE) > 60.0 else Escort.GATE
	from.y = Terrain.height_at(from.x, from.z) + 0.3
	s.global_position = from
	var spot: Vector3 = n.global_position + Vector3(1.8, 0, 1.2)
	spot.y = Terrain.height_at(spot.x, spot.z)
	s.go_to(spot)
	s.get_tree().create_timer(180.0).timeout.connect(func(): if is_instance_valid(s): s.send_home())
	m["peur"] = false
	m["relation"] = int(m.get("relation", 0)) + 6
	gs.add("bienveillance", 2)
	gs.add("confiance_habitants", 3)
	act("Vous avez envoyé le soldat %s veiller sur la maison de %s." % [s.nom, t["nom"]])
	return ""

static func banish(n: Node3D, raison: String) -> void:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var bl: Array = gs.flags.get("bannis", [])
	bl.append(t["id"])
	gs.flags["bannis"] = bl
	gs.add("autorite", 3)
	gs.add("crainte", 4)
	gs.add("bienveillance", -3)
	gs.add("confiance_habitants", -3)
	if Kingdom.inst:
		Kingdom.add("population", -1)
	n.remove_from_group("pnj")
	n.remove_meta("talk")
	FX.bark(n, "Très bien… je pars.", 2.3, 3.0)
	if n is Villager:
		var pts := [Vector2(n.global_position.x, n.global_position.z)]
		pts.append_array(EXIT_SOUTH)
		n.leave(pts)
	else:
		n.queue_free()
	act("Vous avez banni %s du royaume (%s)." % [t["nom"], raison])

## Arrestation : deux gardes viennent chercher l'habitant et l'escortent jusqu'à la prison
static func arrest(n: Node3D, raison: String) -> void:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	gs.add("autorite", 3)
	gs.add("crainte", 5)
	gs.add("confiance_habitants", -2)
	var fem: bool = n is Villager and bool(n.spec.get("female", false))
	var outfit: String = String(n.spec.get("outfit", "paysan_h")) if n is Villager else "rodeur_h"
	var rec := {"id": t["id"], "nom": t["nom"], "role": t["role"], "raison": raison, "fem": fem, "outfit": outfit, "jour": int(Kingdom.res("jour")) if Kingdom.inst else 1}
	n.remove_from_group("pnj")
	n.set_meta("talk", {"id": t["id"], "nom": t["nom"], "role": "escorte_prison"})
	if n is Villager:
		n.captive = true
	FX.bark(n, "Quoi ?! Non, attendez !", 2.3, 3.0)
	act("Vous avez fait arrêter %s (%s)." % [t["nom"], raison])
	var guards := []
	var p := Combat.player
	for i in 2:
		var s := Soldier.new()
		s.nom = Kingdom.data()["pnj"]["noms_h"][(i * 5 + randi()) % 12]
		s.home = Escort.GATE
		s.slot = i
		world().add_child(s)
		var from: Vector3 = p.global_position - p.global_transform.basis.z * 8.0 + Vector3(i * 1.5, 0, 0)
		from.y = Terrain.height_at(from.x, from.z) + 0.3
		s.global_position = from
		var spot: Vector3 = n.global_position + Vector3(-1.0 + i * 2.0, 0, 0.8)
		s.go_to(spot)
		guards.append(s)
	var lead: Soldier = guards[0]
	lead.arrived.connect(func():
		if lead.mode != Soldier.M.GARDER and lead.mode != Soldier.M.ALLER:
			return
		lead.say("Au nom du seigneur, suis-nous.", 2.5)
		if n is Villager:
			n.react("Walk", 999.0)
		var path := _path_to_prison(n.global_position)
		for g in guards:
			if is_instance_valid(g):
				g.prisoner = n
				g.mode = Soldier.M.ESCORTE_PRISONNIER
				g.goal = path[0] + Vector3(g.slot * 1.4, 0, 0)
				g.set_meta("chemin", path)
		_walk_escort(guards, path, 0, n, rec), CONNECT_ONE_SHOT)

## Trajet à pied jusqu'à la prison : route du bourg, porte du château, cour
static func _path_to_prison(from: Vector3) -> Array:
	var pts := []
	if from.z > -86.0:
		for q in [Vector2(0, -48), Vector2(0, -70), Vector2(0, -92)]:
			if from.z > q.y:
				pts.append(Vector3(q.x, Terrain.height_at(q.x, q.y), q.y))
	pts.append(Vector3(-20, 12.0, -110))
	pts.append(CELL_DOOR + Vector3(0, 0, 1.5))
	return pts

static func _walk_escort(guards: Array, path: Array, i: int, n: Node3D, rec: Dictionary) -> void:
	var lead: Soldier = guards[0]
	if not is_instance_valid(lead) or lead.cbt.dead:
		return
	if i >= path.size():
		# arrivée : le prisonnier entre dans la cellule
		var prs: Array = Kingdom.k()["prisonniers"]
		prs.append(rec)
		GameState.get_inst().mark()
		if is_instance_valid(n):
			n.global_position = _cell_spot(prs.size() - 1)
			n.rotation.y = 0.0
			n.set_meta("talk", {"id": rec["id"], "nom": rec["nom"], "role": "prisonnier"})
			if n is Villager:
				n.react("Idle", 0.1)
		for g in guards:
			if is_instance_valid(g):
				g.prisoner = null
				g.send_home()
		GameState.get_inst().report("%s a été enfermé(e) à la prison du château." % rec["nom"], "acte")
		return
	for g in guards:
		if is_instance_valid(g):
			g.goal = path[i] + Vector3(g.slot * 1.4, 0, 0)
			g.mode = Soldier.M.ESCORTE_PRISONNIER
	lead.arrived.connect(func(): _walk_escort(guards, path, i + 1, n, rec), CONNECT_ONE_SHOT)

# ------------------------------------------------------------------ décisions sur un prisonnier
static func _remove_record(id: String) -> Dictionary:
	var prs: Array = Kingdom.k()["prisonniers"]
	for pr in prs:
		if pr["id"] == id:
			prs.erase(pr)
			GameState.get_inst().mark()
			return pr
	return {}

static func release(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	var pr := _remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("bienveillance", 2)
	gs.add("confiance_habitants", 2)
	var m := gs.mem(t["id"])
	m["relation"] = int(m.get("relation", 0)) + 3
	FX.bark(n, "Merci… merci, {titre}.".replace("{titre}", gs.titre), 2.3, 3.0)
	n.global_position = CELL_DOOR + Vector3(0, 0, 1.0)
	n.set_meta("talk", {"id": t["id"], "nom": t["nom"], "role": String(pr.get("role", "habitant"))})
	if n is Villager:
		n.leave([Vector2(-20, -110), Vector2(0, -92), Vector2(0, -60), Vector2(2, -30)])
	act("Vous avez libéré %s." % t["nom"])

static func forced_labor(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	_remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("autorite", 2)
	gs.add("crainte", 2)
	gs.add("confiance_habitants", -1)
	if Kingdom.inst:
		Kingdom.add("pierre", 15)
	FX.bark(n, "La mine… pour combien de temps ?", 2.3, 3.0)
	if n is Villager:
		n.global_position = CELL_DOOR + Vector3(0, 0, 1.0)
		n.leave([Vector2(-20, -110), Vector2(0, -92), Vector2(30, -92), Vector2(58, -120), Vector2(125, -140)])
	act("%s est condamné(e) aux travaux forcés à la mine." % t["nom"])

static func execute(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	_remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("bienveillance", -6)
	gs.add("crainte", 8)
	gs.add("autorite", 3)
	gs.add("confiance_habitants", -6)
	gs.add("reputation", -3)
	if Kingdom.inst:
		Kingdom.add("population", -1)
		Kingdom.add("moral", -4)
	n.remove_meta("talk")
	# mise en scène sobre : les gardes l'emmènent, il disparaît dans l'ombre de la caserne
	if n is Villager:
		n.global_position = CELL_DOOR + Vector3(0, 0, 1.0)
		n.leave([Vector2(-36, -108), Vector2(-40, -104)])
	act("Vous avez ordonné l'exécution de %s. Le bourg l'apprendra." % t["nom"])

static func exile_prisoner(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	_remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("autorite", 2)
	gs.add("crainte", 2)
	if Kingdom.inst:
		Kingdom.add("population", -1)
	var bl: Array = gs.flags.get("bannis", [])
	bl.append(t["id"])
	gs.flags["bannis"] = bl
	n.remove_meta("talk")
	if n is Villager:
		n.global_position = CELL_DOOR + Vector3(0, 0, 1.0)
		var pts := [Vector2(-20, -110), Vector2(0, -92)]
		pts.append_array(EXIT_SOUTH)
		n.leave(pts)
	act("%s est exilé(e) de Valmont après son procès." % t["nom"])

# ------------------------------------------------------------------ dialogues (options ajoutées par Talk)
static func add_options(nodes: Dictionary, choices: Array, who: String, label: String, n: Node3D, role: String) -> void:
	var gs := GameState.get_inst()
	var t: Dictionary = n.get_meta("talk")
	var m := gs.mem(t["id"])
	if role == "prisonnier":
		var pr := prisoner_record(t["id"])
		nodes["menu"]["text"] = "%s (motif : %s). Que décidez-vous, %s ?" % ["Pitié… je n'ai rien fait de mal" if gs.val("crainte") < 10 else "Je… je ferai ce que vous voudrez", pr.get("raison", "inconnu"), gs.titre]
		choices.clear()
		choices.append({"text": "Je te libère. Rentre chez toi.", "tone": "bienveillance", "next": "END", "callback": func(): release(n)})
		choices.append({"text": "Tu seras jugé publiquement.", "tone": "diplomatie", "next": "proces"})
		choices.append({"text": "Aux travaux forcés, à la mine.", "tone": "autorite", "next": "END", "callback": func(): forced_labor(n)})
		choices.append({"text": "Qu'on l'exécute.", "tone": "arrogance", "next": "exec"})
		choices.append({"text": "Pourrir ici te fera réfléchir.", "tone": "indifference", "next": "END"})
		nodes["proces"] = {"who": "conseil", "nom": "Procès devant le bourg", "text": "Les habitants se rassemblent dans la cour. %s est accusé(e) : %s. Le verdict vous appartient." % [t["nom"], pr.get("raison", "")],
			"choices": [
				{"text": "Innocent. Il est libre.", "tone": "bienveillance", "next": "END", "callback": func():
					gs.add("reputation", 2)
					release(n)},
				{"text": "Coupable : l'exil.", "tone": "autorite", "next": "END", "callback": func(): exile_prisoner(n)},
				{"text": "Coupable : il reste au cachot.", "tone": "autorite", "next": "END", "callback": func():
					gs.add("autorite", 1)
					act("Le procès de %s s'achève : il reste au cachot." % t["nom"])},
			]}
		nodes["exec"] = {"who": "conseil", "nom": "Le capitaine de la garde", "text": "Mon seigneur… vous êtes certain ? Le peuple s'en souviendra.",
			"choices": [
				{"text": "Exécutez l'ordre.", "tone": "autorite", "next": "END", "callback": func(): execute(n)},
				{"text": "Non. Pas aujourd'hui.", "tone": "bienveillance", "next": "END"},
			]}
		return
	if not Story.done() or role in ["roi", "elian", "soldat", "escorte_prison"]:
		return
	# demande d'aide : certains habitants ont peur des bandits
	if role in ["habitant", "paysan", "bucheron", "marchand"] and m.get("peur", false):
		nodes["peur"] = {"who": who, "nom": label, "text": String(Kingdom.data()["barks"]["peur_bandits"]).replace("{titre}", gs.titre),
			"choices": [
				{"text": "Je t'envoie un garde pour veiller sur ta maison.", "tone": "bienveillance", "next": "peur_ok", "callback": func():
					var e := protect_house(n)
					if e != "" and Hud.inst:
						Hud.inst.show_message(e, Color(1, 0.6, 0.5))},
				{"text": "Ferme bien ta porte. C'est tout.", "tone": "indifference", "next": "menu", "callback": func(): m["relation"] = int(m.get("relation", 0)) - 1},
			]}
		nodes["peur_ok"] = {"who": who, "nom": label, "text": "Merci, {titre}… je dormirai mieux ce soir.".replace("{titre}", gs.titre), "next": "menu"}
		choices.insert(0, {"text": "Tu sembles inquiet ?", "next": "peur"})
	var au: Dictionary = choices.pop_back()   # « Au revoir » reste en dernier
	choices.append({"text": "Ordres du seigneur…", "next": "ordres"})
	choices.append(au)
	var ord := []
	ord.append({"text": "À genoux devant ton seigneur !", "tone": "autorite", "next": "END", "callback": func(): kneel(n)})
	ord.append({"text": "Pour ta loyauté, voici 25 pièces pour ta famille.", "tone": "bienveillance", "cond": "or>=25", "next": "END", "callback": func():
		var e := reward(n)
		if e != "" and Hud.inst:
			Hud.inst.show_message(e, Color(1, 0.6, 0.5))})
	if n is Villager:
		ord.append({"text": "Quitte mon royaume. Tu es banni.", "tone": "arrogance", "next": "bannir"})
		ord.append({"text": "Gardes ! Arrêtez cet individu.", "tone": "autorite", "next": "arreter"})
	ord.append({"text": "Rien. Retourne à tes affaires.", "next": "menu"})
	nodes["ordres"] = {"who": who, "nom": label, "text": "Oui, {titre} ?".replace("{titre}", gs.titre), "choices": ord}
	var reasons := ["Tu m'as trahi.", "Je n'ai pas de comptes à te rendre.", "Tes paroles m'insultent.", "On t'a vu voler au marché."]
	var ban := []
	var arr := []
	for r in reasons:
		var rr: String = r
		ban.append({"text": rr, "next": "END", "callback": func(): banish(n, rr.trim_suffix("."))})
		arr.append({"text": rr, "next": "END", "callback": func(): arrest(n, rr.trim_suffix("."))})
	ban.append({"text": "… Non, oublie ça.", "next": "menu"})
	arr.append({"text": "… Non, oublie ça.", "next": "menu"})
	nodes["bannir"] = {"who": who, "nom": label, "text": "Banni ?! Mais pourquoi, {titre} ?".replace("{titre}", gs.titre), "choices": ban}
	nodes["arreter"] = {"who": who, "nom": label, "text": "M'arrêter ? Qu'est-ce que j'ai fait ?!", "choices": arr}
