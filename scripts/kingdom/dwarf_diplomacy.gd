class_name DwarfDiplomacy
## Diplomatie avec Karak Dûm : la porte gardée (présent, duel d'honneur contre leur champion,
## intimidation, audience), le roi Thorvald (alliance commerciale, armes, guerriers, Vargas)
## et les nains de la cour (on ne les connaît pas : ils jugent le souverain sur sa réputation).

static func _gs() -> GameState:
	return GameState.get_inst()

static func respect() -> int:
	return int(_gs().factions.get("nains", 0))

static func _world() -> Node3D:
	return Justice.world()

static func gate_challenge(realm: DwarfRealm) -> void:
	var cap := Talk.node_of("capitaine_nain")
	if cap == null:
		return
	var w := _world()
	var known := respect() >= 15 or _gs().flag("nains_respect")
	var nodes := {}
	var choices := []
	if known:
		nodes["menu"] = {"who": "pnj", "nom": "Capitaine Brokkar", "text": "Le seigneur de Valmont ! Le roi a entendu parler de vous. Ouvrez la porte !", "next": "END", "action": "porte_naine"}
	else:
		choices.append({"text": "Je suis le souverain de Valmont. Je demande audience au roi.", "next": "refus"})
		choices.append({"text": "Un présent pour le roi Thorvald. (150 or)", "next": "END", "callback": func(): _gift(realm, cap)})
		choices.append({"text": "Duel d'honneur : moi contre votre champion. Si je gagne, vous ouvrez.", "next": "END", "callback": func(): _duel(realm, cap)})
		choices.append({"text": "Ouvrez cette porte. Ou je l'ouvre moi-même. (intimider)", "next": "END", "callback": func(): _intimidate(realm, cap)})
		choices.append({"text": "Je reviendrai.", "next": "END"})
		nodes["refus"] = {"who": "pnj", "nom": "Capitaine Brokkar", "text": "Le roi ne reçoit pas les inconnus, humain. Les tiens nous ont trahis jadis : Vargas paie ses chiens avec l'or volé à nos mines. Prouve ta valeur… ou ta bonne foi.", "next": "menu"}
		nodes["menu"] = {"who": "pnj", "nom": "Capitaine Brokkar", "text": "Halte, humain ! Personne ne franchit la porte de Karak Dûm sans la permission du roi. Qui es-tu ?", "choices": choices}
	if w.get("rig"):
		w.rig.frame_talk(Combat.player, cap)
	w.dlg.start({"start": "menu", "nodes": nodes, "fermable": true})
	if known:
		realm.open_gate()

static func _gift(realm: DwarfRealm, cap: Node3D) -> void:
	var prog := Progression.get_inst()
	if prog.gold < 150:
		FX.bark(cap, "Tu appelles ça un présent ? Ta bourse est vide, humain.", 2.2, 2.6)
		return
	prog.add_gold(-150)
	_gs().add("faction_nains", 12)
	FX.bark(cap, "Hm. De l'or honnête. Le roi appréciera. Ouvrez !", 2.2, 2.6)
	realm.open_gate()

static func _intimidate(realm: DwarfRealm, cap: Node3D) -> void:
	var c := clampf(0.15 + _gs().val("crainte") * 0.012 + Progression.get_inst().level * 0.02, 0.1, 0.8)
	Magic.halo(Combat.player.global_position + Vector3.UP, 3.2, Color(1.0, 0.8, 0.4), 0.6)
	FX.shockwave(Combat.player.global_position, 3.2)
	if randf() < c:
		_gs().add("faction_nains", -10)
		_gs().add("crainte", 2)
		FX.bark(cap, "… Par la barbe de mes ancêtres. Ouvrez. Mais le roi s'en souviendra.", 2.2, 3.0)
		realm.open_gate()
	else:
		_gs().add("faction_nains", -5)
		FX.bark(cap, "Ha ! Nos murs ont résisté aux dragons, humain. Repars d'où tu viens.", 2.2, 3.0)

## Duel d'honneur contre le champion de Karak Dûm (il se rend à 15 % de vie)
static func _duel(realm: DwarfRealm, cap: Node3D) -> void:
	FX.bark(cap, "Un duel ! Faites venir Hrolf !", 2.2, 2.4)
	var p := Combat.player
	var m := Monster.new()
	m.kind = "champion_nain"
	m.no_respawn = true
	var at := p.global_position + (cap.global_position - p.global_position).normalized() * 6.0
	at.y = DwarfRealm.ground(at.x - DwarfRealm.O.x, at.z - DwarfRealm.O.z) + 0.3
	m.position = at
	realm.add_child(m)
	m.duel = true
	m.cbt.hp_floor = m.cbt.max_hp * 0.15
	FX.bark(m, "Hrolf Poing-de-Fer ! Voyons ce que vaut ton épée, humain.", 2.2, 3.0)
	Magic.rune(Vector3((p.global_position.x + at.x) * 0.5, at.y - 0.25, (p.global_position.z + at.z) * 0.5), 5.0, Color(0.6, 0.8, 1.0), 120.0, 0.15)
	m._aggro()
	var done := [false]
	var tick := func(): pass
	tick = func():
		if done[0]:
			return
		if not is_instance_valid(m) or m.cbt.dead or Combat.player.cbt.dead:
			done[0] = true
			return
		if m.cbt.hp <= m.cbt.hp_floor + 0.5:
			done[0] = true
			m.kneel_cc(20.0)
			m.peaceful = true
			m.duel = false
			Combat.unregister(m)
			_gs().add("faction_nains", 20)
			_gs().set_flag("nains_respect")
			FX.bark(m, "Assez ! Assez… Tu frappes comme un nain. Ouvrez-lui la porte !", 2.2, 3.2)
			realm.open_gate()
			Powers._after(6.0, func():
				if is_instance_valid(m):
					m.queue_free())
			return
		Powers._after(0.3, tick)
	Powers._after(0.3, tick)

## Options de dialogue des nains selon leur rôle
static func add_options(nodes: Dictionary, choices: Array, who: String, label: String, role: String) -> void:
	var gs := _gs()
	if role == "roi_nain":
		choices.clear()
		var r := respect()
		nodes["alliance"] = {"who": who, "nom": label, "text": ("Une alliance… Tu as gagné notre respect, seigneur. Nos caravanes prendront la route de Valmont : du fer, de l'acier, de la bière. Et ton or circulera dans nos mines." if r >= 25 else "Une alliance ? Les humains parlent beaucoup. Prouve ta parole : chasse les bandits qui pillent nos convois, et reviens me voir."), "next": "menu"}
		choices.append({"text": "Je propose une alliance commerciale entre nos royaumes.", "next": "alliance", "callback": func():
			if respect() >= 25 and not gs.flag("contact_nains"):
				gs.set_flag("contact_nains")
				gs.add("faction_nains", 5)
				gs.report("Alliance commerciale scellée avec Karak Dûm : les caravanes naines viendront à Valmont.", "acte")})
		nodes["armes"] = {"who": who, "nom": label, "text": "De l'acier nain pour tes gardes ? Le meilleur du monde. Trois cents pièces, et tes hommes ne craindront plus aucune lame.", "choices": [
			{"text": "Marché conclu. (300 or)", "next": "menu", "callback": func():
				if Progression.get_inst().gold >= 300 and Kingdom.inst:
					Progression.get_inst().add_gold(-300)
					Kingdom.add("equipement", 1)
					gs.add("faction_nains", 3)
					gs.report("Acier nain acheté à Karak Dûm : l'équipement de la garde progresse.", "acte")
				elif Hud.inst:
					Hud.inst.show_message("Pas assez d'or", Color(1, 0.6, 0.5))},
			{"text": "Pas maintenant.", "next": "menu"}]}
		choices.append({"text": "Je veux de l'acier nain pour ma garde.", "next": "armes"})
		nodes["guerriers"] = {"who": who, "nom": label, "text": ("Trois de mes guerriers marcheront sous ta bannière. Cinq cents pièces : ils valent chaque pièce." if r >= 15 else "Mes guerriers ne servent pas un inconnu."), "choices": [
			{"text": "J'accepte. (500 or)", "next": "menu", "callback": func():
				if respect() >= 15 and Progression.get_inst().gold >= 500 and Kingdom.inst:
					Progression.get_inst().add_gold(-500)
					Kingdom.add("soldats", 3)
					gs.report("Trois guerriers nains rejoignent la garde de Valmont.", "acte")
				elif Hud.inst:
					Hud.inst.show_message("Le roi refuse (respect ou or insuffisant)", Color(1, 0.6, 0.5))},
			{"text": "Une autre fois.", "next": "menu"}]}
		choices.append({"text": "Prêtez-moi vos guerriers.", "next": "guerriers"})
		nodes["vargas"] = {"who": who, "nom": label, "text": "Vargas… Ce chien a pillé la mine des Ancêtres et volé la Couronne de Fer de mon père. Rapporte-la-moi, seigneur, et Karak Dûm marchera à tes côtés jusqu'à sa forteresse.", "next": "menu", "callback": func(): gs.set_flag("quete_couronne_fer")}
		choices.append({"text": "Parlons de Vargas.", "next": "vargas"})
		choices.append({"text": "Que la montagne vous garde, roi Thorvald.", "next": "END"})
		var greet := "Le seigneur de Valmont, dans ma salle du trône. Parle, et sois bref : le fer refroidit." if r < 25 else "Ah, mon ami de Valmont ! Bienvenue sous la Montagne."
		nodes["menu"] = {"who": who, "nom": label, "text": greet, "choices": choices}
	elif role == "garde_nain":
		pass
