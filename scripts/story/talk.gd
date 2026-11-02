class_name Talk
## Dialogue universel avec les PNJ : un bouton « Parler » apparaît près d'un personnage ;
## les options dépendent de son rôle (garde, habitant, paysan, marchand, roi, compagnon…).
## Chaque PNJ se souvient : nombre de rencontres, sujets déjà abordés, relation, remise négociée,
## dernières nouvelles entendues — il ne répète pas indéfiniment la même chose.
## Les conversations sont construites au même format que data/dialogues.json et jouées par Dialogue.

const RANGE := 3.6

static func setup(world: Node3D) -> void:
	var d: Dictionary = Kingdom.data()["pnj"]
	var i := 0
	for n in world.get_tree().get_nodes_in_group("pnj"):
		if n.has_meta("talk"):
			continue
		var role := "habitant"
		var p := Vector2(n.global_position.x, n.global_position.z)
		if n is Guard:
			role = "garde"
		elif n is Farmer:
			role = "paysan"
		elif p.distance_to(Layout.LUMBER) < 30.0:
			role = "bucheron"
		elif p.distance_to(Layout.MINE) < 30.0:
			role = "mineur"
		elif p.distance_to(Layout.FARM) < 40.0:
			role = "paysan"
		var fem: bool = n is Villager and bool(n.spec.get("female", false))
		var names: Array = d["noms_f"] if fem else d["noms_h"]
		# nom stable d'une partie à l'autre : dérivé de la position d'origine
		var h := absi(int(p.x * 7.0) * 31 + int(p.y * 3.0) * 17)
		var nm: String = names[h % names.size()]
		var id := "%s_%d_%d" % [role, int(p.x), int(p.y)]
		if role == "garde" and p.distance_to(Vector2(-4.6, -81)) < 1.0:
			nm = "Garric"
			id = "garric"
		n.set_meta("talk", {"id": id, "nom": nm, "role": role})
		i += 1
	# deux marchands derrière les étals de la place
	for k in 2:
		var a := TAU * (k * 2) / 4.0 + PI / 4.0
		var q := Layout.TOWN + Vector2(cos(a), sin(a)) * 10.4
		var v := Villager.new()
		v.spec = {"outfit": "paysan_h" if k == 0 else "paysan_f", "female": k == 1, "hair": "Hair_Buns" if k == 1 else "Hair_SimpleParted", "beard": k == 0, "tint": Color(1.0, 0.85, 0.7)}
		v.anim_name = "Idle_Talking" if k == 0 else "Idle"
		v.position = Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
		v.rotation.y = atan2(-cos(a), -sin(a))
		world.add_child(v)
		v.set_meta("talk", {"id": "marchand_%d" % k, "nom": ["Bertrand", "Mahaut"][k], "role": "marchand"})

## PNJ le plus proche à qui l'on peut parler
static func nearest(pos: Vector3, tree: SceneTree) -> Node3D:
	var best: Node3D = null
	var bd := RANGE
	for n in tree.get_nodes_in_group("pnj"):
		if not n.visible or not n.has_meta("talk"):
			continue
		var d: float = n.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = n
	var c = Combat.companion
	if c and is_instance_valid(c) and c.present() and c.global_position.distance_to(pos) < bd and Story.done():
		best = c
	return best

static func node_of(id: String) -> Node3D:
	var tree := Engine.get_main_loop() as SceneTree
	for n in tree.get_nodes_in_group("pnj"):
		if n.has_meta("talk") and n.get_meta("talk")["id"] == id:
			return n
	return null

static func info(n: Node3D) -> Dictionary:
	if n is Companion:
		return {"id": "elian", "nom": "Elian", "role": "elian"}
	return n.get_meta("talk")

## Construit la conversation (menu + sous-nœuds) pour ce PNJ, selon son rôle et sa mémoire.
static func build(n: Node3D) -> Dictionary:
	var t := info(n)
	var id: String = t["id"]
	var role: String = t["role"]
	var nom: String = t["nom"]
	var gs := GameState.get_inst()
	var m := gs.mem(id)
	var rd: Dictionary = Kingdom.data()["pnj"]["roles"].get(role, Kingdom.data()["pnj"]["roles"]["habitant"])
	var who := "elian" if role == "elian" else ("roi" if role == "roi" else ("garde" if role == "garde" else "pnj"))
	var label := nom if role in ["elian", "roi"] else "%s, %s" % [nom, String(rd["titre"]).to_lower()]
	var rel := int(m.get("relation", 0))
	if role == "elian" and gs.companions.has("elian"):
		rel = int(gs.companions["elian"].get("relation", 0))
	var vu := int(m.get("vu", 0))
	var greet := ""
	if role == "roi":
		greet = "Intendant. Que puis-je pour vous ?" if vu > 0 else "Ah, %s. Approchez." % gs.titre
	elif role == "elian":
		greet = ["Oui ?", "Je vous écoute.", "Un ordre, %s ?" % gs.titre][vu % 3] if rel >= -5 else "… Qu'est-ce que vous voulez ?"
	elif rel <= -6:
		greet = "Encore vous… Faites vite."
	elif vu == 0:
		greet = "Bonjour, %s. On parle beaucoup de vous au bourg." % gs.titre if Story.done() else "Bonjour, étranger."
	elif vu < 4:
		greet = "Rebonjour, %s !" % gs.titre
	else:
		greet = "Ah, %s ! Toujours un plaisir." % gs.titre if rel >= 3 else "Rebonjour, %s." % gs.titre
	m["vu"] = vu + 1
	gs.mark()
	var nodes := {}
	var choices := []
	# --- discuter : un sujet jamais abordé (mémoire)
	var said: Array = m.get("sujets", [])
	var pool: Array = rd.get("discuter", [])
	var fresh := []
	for i in pool.size():
		if not said.has("d%d" % i):
			fresh.append(i)
	if fresh.size() > 0:
		var pick: int = fresh[0]
		nodes["discuter"] = {"who": who, "nom": label, "text": pool[pick], "next": "menu"}
		choices.append({"text": "Discuter", "next": "discuter", "callback": func():
			said.append("d%d" % pick)
			m["sujets"] = said
			m["relation"] = int(m.get("relation", 0)) + (1 if said.size() <= 2 else 0)
			gs.mark()})
	else:
		nodes["discuter"] = {"who": who, "nom": label, "text": "Je crois que je vous ai tout dit, %s. Revenez quand il se sera passé quelque chose." % gs.titre, "next": "menu"}
		choices.append({"text": "Discuter", "next": "discuter"})
	# --- à propos de lui (une seule fois)
	if not said.has("soi"):
		var soi: Array = rd.get("soi", ["Il n'y a pas grand-chose à dire sur moi."])
		nodes["soi"] = {"who": who, "nom": label, "text": soi[absi(id.hash()) % soi.size()], "next": "menu"}
		choices.append({"text": "Parlez-moi de vous", "next": "soi", "callback": func():
			said.append("soi")
			m["sujets"] = said
			gs.mark()})
	# --- le royaume (avis selon l'état réel du royaume)
	nodes["royaume"] = {"who": who, "nom": label, "text": _kingdom_opinion(role), "next": "menu"}
	choices.append({"text": "Que pensez-vous du royaume ?", "next": "royaume"})
	# --- nouvelles récentes (seulement celles qu'il n'a pas déjà racontées)
	var seen := int(m.get("nouvelles", 0))
	var news := []
	for r in gs.reports:
		if int(r.get("n", 0)) > seen and news.size() < 2:
			news.append(r)
	if news.size() > 0:
		var txt := "On raconte que… " + _short(String(news[0]["t"]))
		if news.size() > 1:
			txt += "\nEt aussi : " + _short(String(news[1]["t"]))
		var top := int(news[0].get("n", 0))
		nodes["nouvelles"] = {"who": who, "nom": label, "text": txt, "next": "menu"}
		choices.append({"text": "Des nouvelles ?", "next": "nouvelles", "callback": func():
			m["nouvelles"] = top
			gs.mark()})
	# --- commerce et négociation (marchands)
	if rd.get("commerce", false):
		_shop(nodes, choices, who, label, m)
	# --- recrutement
	var rec: String = rd.get("recrue", "")
	if rec != "" and Story.done() and not m.get("recrute", false):
		_recruit(nodes, choices, who, label, m, id, nom, role, rec)
	# --- missions (Elian)
	if role == "elian" and Story.done():
		nodes["missions"] = {"who": who, "nom": label, "text": "Je peux partir en mission quand vous voulez : conquête, recherche, diplomatie, récolte… Tout est au bureau royal.", "next": "END",
			"action": "ouvrir_missions"}
		choices.append({"text": "Parlons des missions", "next": "missions"})
		var c: Dictionary = gs.companions.get("elian", {})
		nodes["etat"] = {"who": who, "nom": label, "text": _elian_mood(c), "next": "menu"}
		choices.append({"text": "Comment te sens-tu ?", "next": "etat"})
	# --- le roi : demande de conseil
	if role == "roi" and Story.done():
		nodes["conseil"] = {"who": who, "nom": label, "text": _king_advice(), "next": "menu"}
		choices.append({"text": "Un conseil, Majesté ?", "next": "conseil"})
	choices.append({"text": "Au revoir", "next": "END"})
	nodes["menu"] = {"who": who, "nom": label, "text": greet, "choices": choices}
	return {"start": "menu", "nodes": nodes}

static func _short(t: String) -> String:
	var first := t.split("\n")[0]
	return first if first.length() < 140 else first.substr(0, 137) + "…"

static func _kingdom_opinion(role: String) -> String:
	var s := Kingdom.k() if Story.done() else {}
	if s.is_empty():
		return "Valmont a connu des jours meilleurs. Vargas nous saigne, et le roi est seul."
	var lines := []
	var moral := float(s["moral"])
	if float(s["nourriture"]) < 25.0:
		lines.append("Les greniers sont presque vides. On a peur de l'hiver.")
	elif moral >= 65.0:
		lines.append("Les gens sourient de nouveau. Ça faisait longtemps.")
	elif moral < 35.0:
		lines.append("Les gens sont à bout. On murmure contre la couronne.")
	else:
		lines.append("On tient le coup. Ni bien, ni mal.")
	match int(s["impot"]):
		0: lines.append("Sans impôt, on respire… mais le trésor, lui, s'essouffle.")
		3: lines.append("L'impôt est lourd, %s. Trop lourd." % GameState.get_inst().titre)
	if role == "garde":
		lines.append("La garde compte %d lances, équipement de niveau %d." % [s["soldats"], s["equipement"]])
	elif role == "marchand":
		lines.append("Le trésor royal a %d pièces, dit-on. Le commerce reprend doucement." % int(s["tresor"]))
	elif role in ["paysan", "bucheron", "mineur"]:
		lines.append("Il nous faudrait plus de bras et de meilleurs outils.")
	var bad := 0
	for id in s["territoires"]:
		if s["territoires"][id] != "controle":
			bad += 1
	if bad > 0:
		lines.append("Et %d territoires restent aux mains des monstres." % bad)
	return " ".join(lines)

static func _elian_mood(c: Dictionary) -> String:
	var l := int(c.get("loyaute", 0))
	var r := int(c.get("relation", 0))
	var t := "Niveau %d. " % int(c.get("niveau", 1))
	if l >= 40 and r >= 15:
		t += "Je vous suivrais n'importe où. Vraiment."
	elif l >= 20:
		t += "Je suis fier de servir à vos côtés."
	elif r < -5:
		t += "Je fais mon devoir. Ne m'en demandez pas plus."
	else:
		t += "Ça va. J'apprends encore à vous connaître."
	return t

static func _king_advice() -> String:
	var s := Kingdom.k()
	if float(s["nourriture"]) < 30.0:
		return "Un peuple qui a faim n'écoute plus. Mettez des bras aux fermes."
	if float(s["moral"]) < 40.0:
		return "Le moral s'effondre. Baissez l'impôt ou offrez-leur une victoire."
	if not Kingdom.territory_ok("collines_mine"):
		return "La mine produit moitié moins tant que les puglins tiennent les collines. Envoyez quelqu'un."
	if int(s["soldats"]) < 8:
		return "Vargas reviendra. Il nous faut plus de lances, et mieux forgées."
	return "Vous vous débrouillez mieux que moi à votre âge. Continuez."

static func _shop(nodes: Dictionary, choices: Array, who: String, label: String, m: Dictionary) -> void:
	var gs := GameState.get_inst()
	var prog := Progression.get_inst()
	var remise := float(m.get("remise", 1.0))
	if gs.factions.get("marchands", 0) >= 30:
		remise *= 0.9
	var ps := int(round(20 * remise))
	var pm := int(round(18 * remise))
	var buy := func(kind: String, price: int):
		if prog.gold < price:
			if Hud.inst:
				Hud.inst.show_message("Pas assez d'or", Color(1, 0.6, 0.5))
			Sfx.play("erreur", -6.0)
			return
		prog.add_gold(-price)
		prog.add_potion(kind, 1)
		Sfx.play("potion", -6.0)
		if Hud.inst:
			Hud.inst.show_message("Potion achetée (-%d or)" % price, Color(1, 0.85, 0.4))
	nodes["commerce"] = {"who": who, "nom": label, "text": "Potions de soin et de mana, fraîches du jour.%s" % (" (prix d'ami)" if remise < 1.0 else ""),
		"choices": [
			{"text": "Potion de soin — %d or" % ps, "next": "commerce", "callback": func(): buy.call("soin", ps)},
			{"text": "Potion de mana — %d or" % pm, "next": "commerce", "callback": func(): buy.call("mana", pm)},
			{"text": "Ce sera tout", "next": "menu"},
		]}
	choices.append({"text": "Commerce", "next": "commerce"})
	if not m.has("remise"):
		nodes["nego"] = {"who": who, "nom": label, "text": "Négocier ? Avec moi ? Voyons ce que vous proposez…",
			"choices": [
				{"text": "Je suis l'Intendant. Faites-moi un prix.", "tone": "autorite", "cond": "autorite>=3", "next": "nego_ok", "callback": func():
					m["remise"] = 0.8
					m["relation"] = int(m.get("relation", 0)) - 1
					gs.mark()},
				{"text": "Je viendrai souvent. Un geste pour un fidèle client ?", "tone": "diplomatie", "next": "nego_ami", "callback": func():
					m["remise"] = 0.9 if gs.val("bienveillance") >= 2 or gs.val("reputation") >= 5 else 1.0
					m["relation"] = int(m.get("relation", 0)) + 1
					gs.mark()},
				{"text": "Tes prix sont du vol.", "tone": "provocation", "next": "nego_ko", "callback": func():
					m["remise"] = 1.15
					m["relation"] = int(m.get("relation", 0)) - 3
					gs.mark()},
			]}
		nodes["nego_ok"] = {"who": who, "nom": label, "text": "… Bien, bien. Vingt pour cent de moins. Mais c'est bien parce que c'est vous.", "next": "menu"}
		nodes["nego_ami"] = {"who": who, "nom": label, "text": "Un client fidèle, j'aime ça. On verra ce que je peux faire.", "next": "menu"}
		nodes["nego_ko"] = {"who": who, "nom": label, "text": "Du vol ?! Pour vous, ce sera plus cher. Voilà.", "next": "menu"}
		choices.append({"text": "Négocier les prix", "next": "nego"})

static func _recruit(nodes: Dictionary, choices: Array, who: String, label: String, m: Dictionary, id: String, nom: String, role: String, rec: String) -> void:
	var gs := GameState.get_inst()
	var rel := int(m.get("relation", 0))
	if rel < 0:
		nodes["recrue"] = {"who": who, "nom": label, "text": "Vous servir ? Après la façon dont vous m'avez parlé ? Non merci.", "next": "menu"}
		choices.append({"text": "Rejoins-moi", "next": "recrue"})
		return
	if rec == "soldat":
		nodes["recrue"] = {"who": who, "nom": label, "text": "Rejoindre votre garde personnelle ? Il me faudrait une solde… disons 25 pièces pour l'équipement.",
			"choices": [
				{"text": "Voici 25 pièces. Bienvenue.", "cond": "or>=25", "next": "recrue_ok", "callback": func():
					Progression.get_inst().add_gold(-25)
					_make_agent(id, nom, role)
					m["recrute"] = true
					gs.mark()},
				{"text": "Plus tard.", "next": "menu"},
			]}
	else:
		nodes["recrue"] = {"who": who, "nom": label, "text": "Travailler pour la couronne ? Partir en mission ? … Pourquoi pas. Je connais le pays.",
			"choices": [
				{"text": "Alors c'est dit. Tu es des nôtres.", "next": "recrue_ok", "callback": func():
					_make_agent(id, nom, role)
					m["recrute"] = true
					gs.mark()},
				{"text": "J'y réfléchirai.", "next": "menu"},
			]}
	nodes["recrue_ok"] = {"who": who, "nom": label, "text": "À votre service, %s. Vous me trouverez au bureau royal quand vous aurez une mission." % gs.titre, "next": "menu"}
	choices.append({"text": "Rejoins-moi", "next": "recrue"})

## Un PNJ recruté devient un agent : il apparaît dans « Personnages » et peut partir en mission (mort possible)
static func _make_agent(id: String, nom: String, role: String) -> void:
	var gs := GameState.get_inst()
	var comp := {"combat": 2, "diplomatie": 1, "recherche": 1, "recolte": 2, "commandement": 1}
	match role:
		"garde": comp = {"combat": 4, "diplomatie": 1, "recherche": 1, "recolte": 1, "commandement": 2}
		"paysan", "bucheron", "mineur": comp = {"combat": 1, "diplomatie": 1, "recherche": 1, "recolte": 4, "commandement": 1}
		"habitant": comp = {"combat": 1, "diplomatie": 3, "recherche": 2, "recolte": 2, "commandement": 1}
	gs.companions[id] = {"nom": nom, "role": Kingdom.data()["pnj"]["roles"].get(role, {}).get("titre", role), "type": "agent",
		"personnalite": "", "apparence": "", "niveau": 1, "xp": 0, "loyaute": 10, "relation": int(gs.mem(id).get("relation", 0)),
		"competences": comp, "pv": 100, "etat": "present", "blessure_fin": 0.0}
	gs.report("%s rejoint vos agents (%s)." % [nom, gs.companions[id]["role"]], "personnage")
	gs.mark()
