class_name Contracts
## Tableau des contrats (crieur public) : primes sur les repaires du royaume.
## Un contrat = éliminer N créatures d'un repaire ; récompense en or, XP, popularité.

static func _st() -> Dictionary:
	var m := GameState.get_inst().mem("_contrats")
	if not m.has("actifs"):
		m["actifs"] = {}
		m["faits"] = []
	return m

static func reward_of(z: Dictionary) -> Dictionary:
	var d: Dictionary = MonsterDB.DEFS[z["kind"]]
	var unit := float(d["xp"])
	var need := int(z["n"]) + (0 if d.get("elite", false) else 1)
	return {"need": need, "or": int(unit * need * 2.2 / 5.0) * 5 + 20, "xp": int(unit * need * 0.8)}

## Contrats proposés : repaires pas encore traités, du plus proche au plus lointain du bourg
static func offers() -> Array:
	var st := _st()
	var out := []
	for z in Spawner.ZONES:
		var id: String = z["id"]
		if st["actifs"].has(id) or id in st["faits"]:
			continue
		var sp := Spawner.by_id(id)
		if sp and sp.liberated:
			continue
		out.append(z)
	out.sort_custom(func(a, b): return (a["pos"] as Vector2).distance_to(Layout.TOWN) < (b["pos"] as Vector2).distance_to(Layout.TOWN))
	return out.slice(0, 3)

static func accept(z: Dictionary) -> void:
	var r := reward_of(z)
	_st()["actifs"][z["id"]] = {"kills": 0, "need": r["need"], "or": r["or"], "xp": r["xp"], "label": z["label"]}
	GameState.get_inst().mark()
	_hud_hint("Contrat accepté : %s (0/%d)" % [z["label"], r["need"]])

static func on_kill(zone_id: String) -> void:
	var st := _st()
	if not st["actifs"].has(zone_id):
		return
	var c: Dictionary = st["actifs"][zone_id]
	c["kills"] = int(c["kills"]) + 1
	if int(c["kills"]) >= int(c["need"]):
		st["actifs"].erase(zone_id)
		(st["faits"] as Array).append(zone_id)
		Progression.get_inst().add_gold(int(c["or"]))
		Progression.get_inst().add_xp(int(c["xp"]))
		GameState.get_inst().add("confiance_habitants", 2)
		GameState.get_inst().report("Contrat rempli : %s. Prime de %d or versée par le crieur." % [c["label"], c["or"]], "acte")
		var w := Justice.world()
		if w and w.get("hud"):
			w.hud.discover("Contrat rempli", "%s  +%d or  +%d XP" % [c["label"], c["or"], c["xp"]])
	else:
		_hud_hint("%s : %d/%d" % [c["label"], c["kills"], c["need"]])
	GameState.get_inst().mark()

static func _hud_hint(t: String) -> void:
	var w := Justice.world()
	if w and w.get("hud"):
		w.hud.hint(t, "", 3.0)

## Options du crieur dans le dialogue
static func add_options(nodes: Dictionary, choices: Array, who: String, label: String) -> void:
	var st := _st()
	var lines := []
	for id in st["actifs"]:
		var c: Dictionary = st["actifs"][id]
		lines.append("• %s — %d/%d" % [c["label"], c["kills"], c["need"]])
	var offs := offers()
	var txt := "Avis à la population ! Primes royales pour qui nettoie nos routes."
	if lines.size() > 0:
		txt += "\nVos contrats en cours :\n" + "\n".join(lines)
	if offs.is_empty():
		txt += "\nPlus aucun contrat pour l'instant. Les routes sont sûres… pour le moment."
	var sub := []
	for z in offs:
		var r := reward_of(z)
		var zz: Dictionary = z
		var nid := "contrat_" + String(z["id"])
		nodes[nid] = {"who": who, "nom": label, "text": "Marché conclu. Rapportez-moi la preuve : %d de ces créatures. %d or et %d XP à la clé." % [r["need"], r["or"], r["xp"]], "next": "menu"}
		sub.append({"text": "%s (%d or)" % [z["label"], r["or"]], "next": nid, "callback": func(): accept(zz)})
	sub.append({"text": "Retour", "next": "menu"})
	nodes["contrats"] = {"who": who, "nom": label, "text": txt, "choices": sub}
	choices.insert(0, {"text": "Les contrats de primes", "next": "contrats"})
