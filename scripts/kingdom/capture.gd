class_name Capture
## Capturer au lieu de tuer : un humain affaibli (bandit, mercenaire, déserteur…) peut être enchaîné.
## Il rejoint les cachots, où le seigneur l'interroge, le rançonne, l'enrôle… ou le juge.

const HUMAINS := ["bandit", "lanceur", "mercenaire", "deserteur", "chef_bandit", "lieutenant"]
const RANCON := {"bandit": 60, "lanceur": 60, "mercenaire": 120, "deserteur": 110, "chef_bandit": 250, "lieutenant": 180}
static var count := 0

static func capturable(m: Node3D) -> bool:
	return Combat.alive(m) and m.kind in HUMAINS and not m.is_boss() and m.cbt.hp <= m.cbt.max_hp * 0.4

## Ennemi capturable le plus proche (≤ 3,5 m)
static func nearest(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd := 4.5
	for m in Combat.in_radius(pos, 4.5):
		if capturable(m):
			var d: float = m.global_position.distance_to(pos)
			if d < bd:
				bd = d
				best = m
	return best

static func capture(m: Node3D) -> void:
	if not capturable(m):
		return
	var p := m.global_position
	m.kneel_cc(3.0)
	Magic.rune(p, 1.8, Color(1.0, 0.8, 0.35), 1.6, 1.4)
	Magic.halo(p + Vector3.UP, 3.0, Color(1.0, 0.8, 0.4), 0.5)
	Sfx.play("racines", -4.0)
	if Hud.inst:
		Hud.inst.show_message("%s se rend !" % m.def["nom"], Color(1.0, 0.85, 0.45))
	FX.bark(m, ["Pitié ! Je me rends !", "D'accord, d'accord… je me rends.", "Ne me tuez pas !"][randi() % 3], 2.3, 2.0)
	var kind: String = m.kind
	var nom: String = m.def["nom"]
	Powers._after(1.4, func():
		if not is_instance_valid(m):
			return
		Magic.pillar(m.global_position, Color(1.0, 0.8, 0.35), 4.0, 0.5, 0.8)
		Combat.unregister(m)
		if m.spawner and is_instance_valid(m.spawner):
			m.spawner.on_monster_died(m)
		m.queue_free()
		_jail(kind, nom))

static func _jail(kind: String, nom: String) -> void:
	count += 1
	var gs := GameState.get_inst()
	var noms: Array = Kingdom.data()["pnj"]["noms_h"]
	var prenom: String = noms[randi() % noms.size()]
	var rec := {"id": "captif_%d_%d" % [int(Time.get_unix_time_from_system()) % 100000, count], "nom": "%s (%s)" % [prenom, nom.to_lower()],
		"raison": "capturé les armes à la main", "outfit": "rodeur_h", "captif": true, "kind": kind}
	var prs: Array = Kingdom.k()["prisonniers"]
	prs.append(rec)
	Justice._spawn_prisoner(rec)
	gs.add("autorite", 1)
	gs.report("%s a été capturé et conduit aux cachots du château." % rec["nom"], "acte")
	gs.mark()
	if Hud.inst:
		Hud.inst.discover("Prisonnier capturé", "%s — aux cachots" % rec["nom"])

## Options supplémentaires face à un captif
static func add_options(nodes: Dictionary, choices: Array, n: Node3D, pr: Dictionary) -> void:
	if not pr.get("captif", false):
		return
	var gs := GameState.get_inst()
	var kind: String = pr.get("kind", "bandit")
	var ran: int = RANCON.get(kind, 60)
	var nom: String = pr["nom"]
	if not pr.get("interroge", false):
		var camp := _camp_info(kind)
		nodes["interro"] = {"who": "pnj", "nom": nom, "text": camp, "next": "END"}
		choices.insert(0, {"text": "Interroge-le : où sont ses complices ?", "tone": "autorite", "next": "interro", "callback": func():
			pr["interroge"] = true
			Progression.get_inst().add_gold(25)
			gs.add("autorite", 1)
			gs.report("Interrogatoire de %s : il a parlé." % nom, "acte")
			gs.mark()})
	nodes["rancon"] = {"who": "conseil", "nom": "L'intendant", "text": "Sa bande paiera %d pièces pour le revoir. Il quittera le royaume." % ran, "next": "END"}
	choices.insert(1, {"text": "Rançon : %d or" % ran, "tone": "diplomatie", "next": "rancon", "callback": func():
		Progression.get_inst().add_gold(ran)
		Justice._remove_record(pr["id"])
		gs.report("%s a été libéré contre une rançon de %d pièces." % [nom, ran], "acte")
		if is_instance_valid(n):
			Magic.pillar(n.global_position, Color(1.0, 0.85, 0.4), 3.0, 0.5, 0.6)
			n.queue_free()})
	if int(Kingdom.res("soldats")) >= Kingdom.max_soldiers():
		return   # casernes pleines : pas d'enrôlement possible
	nodes["enrole"] = {"who": "pnj", "nom": nom, "text": "Servir sous votre bannière ? … Plutôt ça que la corde. Vous ne le regretterez pas.", "next": "END"}
	choices.insert(2, {"text": "Rejoins mes rangs (+1 soldat)", "tone": "bienveillance", "next": "enrole", "callback": func():
		Kingdom.add("soldats", 1)
		Justice._remove_record(pr["id"])
		gs.add("confiance_habitants", -1)
		gs.report("%s a été enrôlé dans la garde." % nom, "acte")
		if is_instance_valid(n):
			n.queue_free()})

static func _camp_info(kind: String) -> String:
	var best: Dictionary = {}
	for z in Spawner.ZONES:
		var sp := Spawner.by_id(z["id"])
		if sp and not sp.liberated and z["kind"] in ["bandit", "chef_bandit", "lanceur", "mercenaire"]:
			best = z
			break
	if best.is_empty():
		return "Mes complices ? Il n'en reste plus… Vous les avez tous eus. Tenez, ma bourse, c'est tout ce que j'ai."
	return "D'accord, d'accord ! Les autres se terrent vers « %s ». Ils sont %d, peut-être plus. Tenez… ma bourse. Ne me frappez plus." % [best["label"], int(best["n"])]
