class_name Kingdom
extends Node
## Simulation du royaume de Valmont : ressources, population, moral, impôts, bâtiments, armée, territoires,
## missions des compagnons/agents, événements à décisions, et effets visibles dans le monde.
## Toutes les valeurs vivent dans GameState.kingdom (sauvegardé). Les définitions (missions, bâtiments,
## territoires, événements, répliques des PNJ) sont dans data/royaume.json, modifiable sans toucher au code.
##
## Rythme : une « tranche » toutes les 10 s, 24 tranches = 1 jour (4 min). Les missions utilisent l'heure réelle :
## elles avancent même jeu fermé. Au retour, le royaume rattrape au plus 2 jours d'absence.

signal changed
signal mission_done(report: Dictionary)

const TICK := 10.0
const TICKS_PER_DAY := 24
const DAY_SEC := TICK * TICKS_PER_DAY
const RES := ["tresor", "nourriture", "bois", "pierre", "minerai"]
const IMPOTS := ["Aucun", "Léger", "Normal", "Lourd"]

static var inst: Kingdom
static var _data := {}

var world: Node3D
var _acc := 0.0
var _mis_acc := 0.0
var _pending_event := ""
var _extra_guards: Array = []
var _extra_people: Array = []
var _banners := {}
var _event_wait := 0.0

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/royaume.json", FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data

static func start(w: Node3D) -> Kingdom:
	if inst and is_instance_valid(inst):
		return inst
	var k := Kingdom.new()
	k.name = "Royaume"
	k.world = w
	w.add_child(k)
	return k

static func k() -> Dictionary:
	var gs := GameState.get_inst()
	if gs.kingdom.is_empty() or not gs.kingdom.has("batiments"):
		gs.kingdom = default_state()
		gs.mark()
	return gs.kingdom

static func default_state() -> Dictionary:
	var terr := {}
	var td: Dictionary = data()["territoires"]
	for id in td:
		terr[id] = td[id]["etat"]
	return {
		"jour": 1, "tranche": 0,
		"tresor": 120.0, "nourriture": 90.0, "bois": 40.0, "pierre": 30.0, "minerai": 10.0,
		"population": 64, "moral": 55.0, "impot": 1, "soldats": 6, "equipement": 1,
		"batiments": {
			"ferme": {"niv": 1, "ouvriers": 10}, "scierie": {"niv": 1, "ouvriers": 4}, "mine": {"niv": 1, "ouvriers": 3},
			"marche": {"niv": 1, "ouvriers": 3}, "maisons": {"niv": 1, "ouvriers": 0}, "caserne": {"niv": 1, "ouvriers": 0},
			"muraille": {"niv": 1, "ouvriers": 0},
		},
		"territoires": terr,
		"hier": {},
	}

# ------------------------------------------------------------------ accès
static func res(r: String) -> float:
	var s := k()
	match r:
		"impot", "soldats", "population", "equipement", "jour":
			return float(s.get(r, 0))
	return float(s.get(r, 0.0))

static func add(r: String, v: float) -> void:
	var s := k()
	match r:
		"population":
			s["population"] = maxi(10, int(s["population"]) + int(v))
		"soldats":
			s["soldats"] = clampi(int(s["soldats"]) + int(v), 0, max_soldiers())
		"impot":
			s["impot"] = clampi(int(s["impot"]) + int(v), 0, 3)
		"moral":
			s["moral"] = clampf(float(s["moral"]) + v, 0.0, 100.0)
		"equipement":
			s["equipement"] = clampi(int(s["equipement"]) + int(v), 1, 5)
		_:
			s[r] = maxf(0.0, float(s.get(r, 0.0)) + v)
	GameState.get_inst().mark()
	if inst:
		inst.changed.emit()
		inst._refresh_world()

static func bld(id: String) -> Dictionary:
	return k()["batiments"][id]

static func workers_total() -> int:
	var n := 0
	for id in k()["batiments"]:
		n += int(k()["batiments"][id].get("ouvriers", 0))
	return n

static func idle_people() -> int:
	return int(k()["population"]) - int(k()["soldats"]) - workers_total()

static func max_pop() -> int:
	return 50 + int(bld("maisons")["niv"]) * 30

static func max_soldiers() -> int:
	return 6 + int(bld("caserne")["niv"]) * 6

static func territory_ok(id: String) -> bool:
	return String(k()["territoires"].get(id, "controle")) == "controle"

## Production par jour d'un bâtiment (avec bonus/malus)
static func production(id: String) -> float:
	var d: Dictionary = data()["batiments"][id]
	var b := bld(id)
	var p: float = int(b.get("ouvriers", 0)) * (float(d["base"]) + float(d["par_niv"]) * (int(b["niv"]) - 1))
	var moral_f := 0.75 + float(k()["moral"]) / 200.0
	p *= moral_f
	if id == "mine" and not territory_ok("collines_mine"):
		p *= 0.5
	if id == "scierie" and not territory_ok("bois_morts"):
		p *= 0.8
	if id == "marche":
		p *= 1.0 + clampf(float(GameState.get_inst().factions.get("marchands", 0)) / 100.0, -0.5, 0.6)
	return p

static func tax_income() -> float:
	return int(k()["population"]) * [0.0, 0.35, 0.7, 1.15][int(k()["impot"])]

static func army_upkeep() -> float:
	return int(k()["soldats"]) * (0.9 + 0.3 * int(k()["equipement"]))

static func food_need() -> float:
	return int(k()["population"]) * 0.2 + int(k()["soldats"]) * 0.3

static func daily_balance() -> Dictionary:
	return {
		"tresor": tax_income() + production("marche") - army_upkeep(),
		"nourriture": production("ferme") * 1.0 - food_need(),
		"bois": production("scierie"),
		"pierre": production("mine"),
		"minerai": production("mine") * 0.45,
	}

static func moral_target() -> float:
	var s := k()
	var t: float = 55.0 + [10.0, 4.0, -4.0, -14.0][int(s["impot"])]
	if float(s["nourriture"]) <= 1.0:
		t -= 20.0
	t += GameState.get_inst().val("confiance_habitants") * 0.4
	t += (int(bld("muraille")["niv"]) - 1) * 3.0
	t += 4.0 if int(s["soldats"]) * 10 >= int(s["population"]) else -4.0
	for id in s["territoires"]:
		if s["territoires"][id] != "controle":
			t -= 1.5
	if idle_people() > 12:
		t -= 3.0
	return clampf(t, 5.0, 95.0)

# ------------------------------------------------------------------ cycle
func _ready() -> void:
	inst = self
	k()
	var gs := GameState.get_inst()
	# rattrapage de l'absence (2 jours maximum)
	if gs.last_saved_unix > 0.0:
		var away := Time.get_unix_time_from_system() - gs.last_saved_unix
		var ticks := clampi(int(away / TICK), 0, TICKS_PER_DAY * 2)
		for i in ticks:
			_tick(true)
		if ticks >= TICKS_PER_DAY / 2:
			gs.report("Pendant votre absence, le royaume a vécu %d jour(s)." % maxi(1, ticks / TICKS_PER_DAY), "info")
	_check_missions()
	_refresh_world()

func _process(delta: float) -> void:
	_acc += delta
	_mis_acc += delta
	if _acc >= TICK:
		_acc -= TICK
		_tick(false)
	if _mis_acc >= 2.0:
		_mis_acc = 0.0
		_check_missions()
		_try_present_event(2.0)

func _tick(silent: bool) -> void:
	var s := k()
	var bal := daily_balance()
	for r in bal:
		s[r] = maxf(0.0, float(s[r]) + float(bal[r]) / TICKS_PER_DAY)
	s["moral"] = clampf(lerpf(float(s["moral"]), moral_target(), 0.2 / TICKS_PER_DAY * 4.0), 0.0, 100.0)
	s["tranche"] = int(s["tranche"]) + 1
	if int(s["tranche"]) >= TICKS_PER_DAY:
		s["tranche"] = 0
		_new_day(silent)
	GameState.get_inst().mark()
	if not silent:
		GameState.get_inst().save_if_dirty()
		changed.emit()

func _new_day(silent: bool) -> void:
	var s := k()
	var gs := GameState.get_inst()
	s["jour"] = int(s["jour"]) + 1
	var pop := int(s["population"])
	var m := float(s["moral"])
	var dp := 0
	if float(s["nourriture"]) <= 1.0:
		dp = -3
		gs.report("Jour %d : la faim frappe le bourg. Des familles partent." % s["jour"], "alerte")
	elif m >= 60.0 and pop < max_pop():
		dp = 2 + int((m - 60.0) / 15.0)
	elif m < 30.0:
		dp = -2
		gs.report("Jour %d : le moral est au plus bas, des habitants quittent Valmont." % s["jour"], "alerte")
	s["population"] = clampi(pop + dp, 10, max_pop())
	if int(s["population"]) - int(s["soldats"]) < workers_total():
		_trim_workers()
	if dp > 0 and not silent:
		gs.report("Jour %d : %d nouveaux habitants se sont installés." % [s["jour"], dp], "info")
	# un événement par jour au plus (pas pendant le rattrapage)
	if not silent and _pending_event == "" and randf() < 0.6:
		_pending_event = _pick_event()
	_refresh_world()

func _trim_workers() -> void:
	var excess := workers_total() - (int(k()["population"]) - int(k()["soldats"]))
	for id in ["marche", "mine", "scierie", "ferme"]:
		while excess > 0 and int(bld(id)["ouvriers"]) > 0:
			bld(id)["ouvriers"] = int(bld(id)["ouvriers"]) - 1
			excess -= 1

# ------------------------------------------------------------------ actions du joueur (interface)
static func cost_of(id: String) -> Dictionary:
	var d: Dictionary = data()["batiments"][id]
	var lv := int(bld(id)["niv"])
	var out := {}
	for r in d["cout"]:
		out[r] = int(float(d["cout"][r]) * (1.0 + 0.6 * (lv - 1)))
	return out

static func can_pay(c: Dictionary) -> bool:
	for r in c:
		if res(r) < float(c[r]):
			return false
	return true

static func pay(c: Dictionary) -> void:
	for r in c:
		k()[r] = float(k()[r]) - float(c[r])

static func upgrade_block_reason(id: String) -> String:
	var d: Dictionary = data()["batiments"][id]
	var lv := int(bld(id)["niv"])
	if lv >= 5:
		return "Niveau maximal"
	if lv == 1 and d.has("requis_niv2") and not Dialogue.cond(String(d["requis_niv2"])):
		return "Il faut d'abord retrouver les plans (mission de recherche)"
	if not can_pay(cost_of(id)):
		return "Ressources insuffisantes"
	return ""

static func upgrade(id: String) -> bool:
	if upgrade_block_reason(id) != "":
		return false
	pay(cost_of(id))
	bld(id)["niv"] = int(bld(id)["niv"]) + 1
	var gs := GameState.get_inst()
	gs.report("%s amélioré(e) au niveau %d." % [data()["batiments"][id]["nom"], bld(id)["niv"]], "batiment")
	gs.add("reputation", 1)
	_after_change()
	return true

static func set_workers(id: String, delta: int) -> void:
	var b := bld(id)
	var mx := int(data()["batiments"][id]["ouvriers_max"]) + (int(b["niv"]) - 1) * 2
	var n := clampi(int(b["ouvriers"]) + delta, 0, mx)
	if delta > 0 and idle_people() <= 0:
		return
	b["ouvriers"] = n
	_after_change()

static func set_tax(lv: int) -> void:
	var old := int(k()["impot"])
	k()["impot"] = clampi(lv, 0, 3)
	if lv > old:
		GameState.get_inst().add("confiance_habitants", -1)
	elif lv < old:
		GameState.get_inst().add("confiance_habitants", 1)
	_after_change()

static func recruit_cost() -> int:
	return 20 + 5 * int(k()["equipement"])

static func recruit() -> String:
	if int(k()["soldats"]) >= max_soldiers():
		return "La caserne est pleine"
	if idle_people() <= 0:
		return "Aucun habitant disponible"
	if res("tresor") < recruit_cost():
		return "Pas assez d'or"
	k()["tresor"] = res("tresor") - recruit_cost()
	k()["soldats"] = int(k()["soldats"]) + 1
	_after_change()
	return ""

static func equip_cost() -> Dictionary:
	var lv := int(k()["equipement"])
	return {"tresor": 40 * lv, "minerai": 25 * lv}

static func equip() -> String:
	if int(k()["equipement"]) >= 5:
		return "Équipement maximal"
	if not can_pay(equip_cost()):
		return "Ressources insuffisantes"
	pay(equip_cost())
	k()["equipement"] = int(k()["equipement"]) + 1
	GameState.get_inst().report("La garde reçoit un meilleur équipement (niveau %d)." % k()["equipement"], "armee")
	_after_change()
	return ""

static func army_power() -> int:
	return int(k()["soldats"]) * (2 + int(k()["equipement"])) + int(bld("muraille")["niv"]) * 4

## Diplomatie directe (coûte de l'or, effet immédiat mais limité) — les ambassades passent par les missions
static func faction_action(f: String, act: String) -> String:
	var gs := GameState.get_inst()
	var day := int(k()["jour"])
	var key := "diplo_%s_%s" % [f, act]
	if int(gs.flags.get(key, -99)) == day:
		return "Déjà fait aujourd'hui"
	match act:
		"cadeau":
			if res("tresor") < 30:
				return "Pas assez d'or (30)"
			k()["tresor"] = res("tresor") - 30
			gs.add("faction_" + f, 6)
			gs.report("Présents envoyés : %s (+6)." % data()["factions"][f]["nom"], "diplomatie")
		"menace":
			if Kingdom.army_power() < 30:
				return "Votre armée n'impressionne personne (puissance 30 requise)"
			gs.add("faction_" + f, -8)
			gs.add("autorite", 2)
			if f == "gobelins":
				add("moral", 3)
			gs.report("Menace adressée : %s (-8)." % data()["factions"][f]["nom"], "diplomatie")
	gs.flags[key] = day
	_after_change()
	return ""

static func _after_change() -> void:
	GameState.get_inst().mark()
	if inst:
		inst.changed.emit()
		inst._refresh_world()

# ------------------------------------------------------------------ missions
## Agents disponibles : compagnons présents, non blessés, sans mission
static func agents() -> Array:
	var out := []
	var gs := GameState.get_inst()
	for id in gs.companions:
		out.append(id)
	return out

static func agent_free(id: String) -> bool:
	var c: Dictionary = GameState.get_inst().companions.get(id, {})
	if c.is_empty() or c.get("etat", "") == "mort":
		return false
	if c.get("etat", "present") == "mission":
		return false
	return Time.get_unix_time_from_system() >= float(c.get("blessure_fin", 0.0))

static func mission_def(id: String) -> Dictionary:
	for m in data()["missions"]:
		if m["id"] == id:
			return m
	return {}

static func mission_available(m: Dictionary) -> bool:
	if m.has("territoire") and territory_ok(String(m["territoire"])):
		return false
	if String(m.get("cond", "")) != "" and not Dialogue.cond(String(m["cond"])):
		return false
	for r in GameState.get_inst().missions:
		if r["tpl"] == m["id"] and r["statut"] == "en_cours":
			return false
	if m.get("unique", false) or m.has("territoire") or m["cat"] == "recherche":
		if m.has("recompenses") and m["recompenses"].has("flag") and GameState.get_inst().flag(String(m["recompenses"]["flag"])):
			return false
	return true

## Chance de réussite (0..1) : compétence de l'agent, difficulté, loyauté, soutien de l'armée pour les conquêtes
static func chance(m: Dictionary, agent_id: String) -> float:
	var c: Dictionary = GameState.get_inst().companions[agent_id]
	var skill := int(c["competences"].get(String(m["competence"]), 1))
	var p := 0.42 + skill * 0.08 - int(m["difficulte"]) * 0.11 + int(c["niveau"]) * 0.02
	p += clampf(float(c.get("loyaute", 0)) / 400.0, -0.1, 0.1)
	if m["cat"] == "conquete":
		p += clampf(army_power() / 300.0, 0.0, 0.15)
	return clampf(p, 0.08, 0.95)

static func start_mission(tpl: String, agent_id: String) -> String:
	var m := mission_def(tpl)
	if m.is_empty() or not mission_available(m):
		return "Mission indisponible"
	if not agent_free(agent_id):
		return "Agent indisponible"
	var gs := GameState.get_inst()
	var p := chance(m, agent_id)
	var now := Time.get_unix_time_from_system()
	gs.missions.append({"tpl": tpl, "agent": agent_id, "debut": now, "fin": now + float(m["duree"]), "chance": p, "statut": "en_cours"})
	gs.companions[agent_id]["etat"] = "mission"
	gs.report("%s part en mission : %s (%d %% de réussite)." % [gs.companions[agent_id]["nom"], m["nom"], int(p * 100)], "mission")
	if agent_id == "elian" and Combat.companion:
		Combat.companion.say("J'y vais ! Je reviens vite.", 2.5)
		var c = Combat.companion
		c.get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(c): c.set_absent(true))
	_after_change()
	gs.save_game()
	return ""

func _check_missions() -> void:
	var gs := GameState.get_inst()
	var now := Time.get_unix_time_from_system()
	for r in gs.missions:
		if r["statut"] == "en_cours" and now >= float(r["fin"]):
			_resolve(r)
	# les blessés guérissent, les absents reviennent
	for id in gs.companions:
		var c: Dictionary = gs.companions[id]
		if c.get("etat", "") == "blesse" and now >= float(c.get("blessure_fin", 0.0)):
			c["etat"] = "present"
			gs.report("%s est rétabli(e)." % c["nom"], "info")
			gs.mark()
	var e = Combat.companion
	if e and is_instance_valid(e):
		var st: String = gs.companions.get("elian", {}).get("etat", "present")
		var away: bool = st == "mission" or st == "blesse"
		if away != (e.mode == Companion.M.ABSENT):
			e.set_absent(away)
			if not away:
				e.say("Me revoilà !", 2.5)

func _resolve(r: Dictionary) -> void:
	var gs := GameState.get_inst()
	var m := mission_def(String(r["tpl"]))
	var aid: String = r["agent"]
	var c: Dictionary = gs.companions.get(aid, {})
	var ok := randf() < float(r["chance"])
	r["statut"] = "reussie" if ok else "echouee"
	var lines: Array = m["recits_ok"] if ok else m["recits_ko"]
	var text: String = "%s — %s.\n%s" % [m["nom"], "RÉUSSITE" if ok else "ÉCHEC", lines[randi() % lines.size()]]
	var xp := int(m["recompenses"].get("xp_agent", 40))
	if ok:
		var fx: Dictionary = m["recompenses"].duplicate()
		fx.erase("xp_agent")
		Dialogue.apply_fx(fx, true)
		text += "\nGains : " + _fx_text(fx)
		if m.has("territoire"):
			_liberate(String(m["territoire"]))
			text += "\nLe territoire « %s » est libéré." % data()["territoires"][m["territoire"]]["nom"]
		c["loyaute"] = clampi(int(c.get("loyaute", 0)) + 2, -100, 100)
		c["etat"] = "present"
	else:
		xp = int(xp * 0.4)
		if m.has("risques_fx"):
			Dialogue.apply_fx(m["risques_fx"], true)
			text += "\nConséquences : " + _fx_text(m["risques_fx"])
		c["loyaute"] = clampi(int(c.get("loyaute", 0)) - 1, -100, 100)
		# blessure, et pour les agents (pas Elian) mort possible sur les missions dangereuses
		var diff := int(m["difficulte"])
		var lethal := aid != "elian" and diff >= 4 and int(c["niveau"]) < 3 and randf() < 0.35
		if lethal:
			c["etat"] = "mort"
			text += "\n%s n'est pas revenu(e). Repose en paix." % c["nom"]
			var n := Talk.node_of(aid)
			if n:
				n.queue_free()
		elif randf() < 0.25 + diff * 0.12:
			c["etat"] = "blesse"
			c["blessure_fin"] = Time.get_unix_time_from_system() + 60.0 * diff
			text += "\n%s est blessé(e) et doit se reposer %d min." % [c["nom"], diff]
		else:
			c["etat"] = "present"
	if c.get("etat", "") != "mort":
		var lv := Companion.give_xp(aid, xp)
		text += "\n%s gagne %d XP." % [c["nom"], xp]
		if lv != "":
			text += "\n" + lv
	r["rapport"] = text
	gs.report(text, "mission")
	gs.save_game()
	mission_done.emit(r)
	if Hud.inst:
		Hud.inst.show_message("Mission %s : %s" % ["réussie" if ok else "échouée", m["nom"]], Color(0.6, 1, 0.6) if ok else Color(1, 0.6, 0.5))

static func _fx_text(fx: Dictionary) -> String:
	var parts := []
	var names := {"k_tresor": "or", "k_nourriture": "nourriture", "k_bois": "bois", "k_pierre": "pierre", "k_minerai": "minerai",
		"k_moral": "moral", "k_population": "habitants", "k_soldats": "soldats", "potions_soin": "potions de soin", "potions_mana": "potions de mana",
		"confiance_habitants": "confiance", "reputation": "réputation"}
	for key in fx:
		var v = fx[key]
		if key == "flag":
			continue
		if key == "xp_agent":
			parts.append("+%d XP pour l'agent" % int(v))
			continue
		var nm: String = names.get(key, key)
		if key.begins_with("faction_"):
			nm = "relation " + String(data()["factions"].get(key.substr(8), {}).get("nom", key.substr(8)))
		parts.append("%+d %s" % [int(v), nm])
	return ", ".join(parts) if parts.size() > 0 else "renseignements"

static func _liberate(tid: String) -> void:
	k()["territoires"][tid] = "controle"
	GameState.get_inst().set_flag("territoire_" + tid)
	GameState.get_inst().add("reputation", 3)
	if inst:
		inst._refresh_world()

# ------------------------------------------------------------------ événements à décisions
func _pick_event() -> String:
	var gs := GameState.get_inst()
	var day := int(k()["jour"])
	var pool := []
	for e in data()["evenements"]:
		var last := int(gs.events_seen.get(e["id"], -999))
		if day - last < int(e["recharge"]):
			continue
		if String(e["cond"]) != "" and not Dialogue.cond(String(e["cond"])):
			continue
		pool.append(e["id"])
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

## L'événement attend un moment calme (pas de combat, pas de dialogue, pas d'interface ouverte)
func _try_present_event(dt: float) -> void:
	if _pending_event == "":
		return
	if Dialogue.active or KingdomUI.is_open() or Dialogue.inst == null:
		return
	var p := Combat.player
	if p == null or p.cbt.dead or Combat.in_radius(p.global_position, 25.0).size() > 0:
		return
	_event_wait += dt
	if _event_wait < 4.0:
		return
	_event_wait = 0.0
	present_event(_pending_event)
	_pending_event = ""

func present_event(id: String) -> void:
	for e in data()["evenements"]:
		if e["id"] == id:
			var gs := GameState.get_inst()
			gs.events_seen[id] = int(k()["jour"])
			gs.report("Événement : %s" % e["titre"], "evenement")
			if Hud.inst:
				Hud.inst.discover(String(e["titre"]), "Une décision vous attend")
			Dialogue.inst.start(e["convo"])
			return

## Pour les tests : forcer un événement
func queue_event(id: String) -> void:
	_pending_event = id

# ------------------------------------------------------------------ effets visibles dans le monde
func _refresh_world() -> void:
	if world == null:
		return
	var s := k()
	# gardes supplémentaires (au-delà des 6 de la garnison d'origine), en patrouille dans le bourg
	var want_g := clampi(int(s["soldats"]) - 6, 0, 6)
	while _extra_guards.size() < want_g:
		var i := _extra_guards.size()
		var g := Guard.new()
		var c := Layout.TOWN
		var a := TAU * i / 6.0
		var r := 13.0 + (i % 2) * 6.0
		var pts := []
		for kk in 4:
			var aa := a + kk * PI / 2.0
			var q := c + Vector2(cos(aa), sin(aa)) * r
			pts.append(Vector3(q.x, Terrain.height_at(q.x, q.y), q.y))
		g.patrol = pts
		g.speed = 1.3
		world.add_child(g)
		g.set_meta("talk", {"id": "garde_recrue_%d" % i, "nom": data()["pnj"]["noms_h"][(i + 5) % 12], "role": "garde"})
		_extra_guards.append(g)
	while _extra_guards.size() > want_g:
		_extra_guards.pop_back().queue_free()
	# habitants supplémentaires sur la place (1 pour 8 habitants au-delà de 64)
	var want_p := clampi((int(s["population"]) - 64) / 8, 0, 8)
	while _extra_people.size() < want_p:
		var i := _extra_people.size()
		var v := Villager.new()
		var fem := i % 2 == 1
		v.spec = {"female": fem, "outfit": "paysan_f" if fem else "paysan_h", "hair": ["Hair_Long", "Hair_Buns", "Hair_SimpleParted", "Hair_Buzzed"][i % 4], "beard": i % 3 == 0 and not fem}
		v.anim_name = ["Idle_Talking", "Idle", "b/Idle_FoldArms"][i % 3]
		var a := TAU * (i + 0.5) / 8.0
		var q := Layout.TOWN + Vector2(cos(a), sin(a)) * 5.5
		v.position = Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
		v.rotation.y = a + PI * 0.5
		world.add_child(v)
		v.set_meta("talk", {"id": "habitant_nouveau_%d" % i, "nom": (data()["pnj"]["noms_f"] if fem else data()["pnj"]["noms_h"])[(i * 3) % 8], "role": "habitant"})
		_extra_people.append(v)
	while _extra_people.size() > want_p:
		_extra_people.pop_back().queue_free()
	# repaires libérés : plus de créatures, une bannière de Valmont plantée sur place
	for id in s["territoires"]:
		var sp := Spawner.by_id(id)
		if sp == null:
			continue
		var free := String(s["territoires"][id]) == "controle"
		sp.liberated = free
		if free and not _banners.has(id):
			var b := Node3D.new()
			world.add_child(b)
			var p := sp.global_position
			b.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
			Kit.dungeon(b, "Banner", Vector3(0, 2.4, 0.1), 0.0, 1.6)
			var pole := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.06
			cm.bottom_radius = 0.07
			cm.height = 4.0
			pole.mesh = cm
			pole.position.y = 2.0
			b.add_child(pole)
			_banners[id] = b
