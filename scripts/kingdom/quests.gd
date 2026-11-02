class_name Quests
extends Node
## Quêtes personnelles : des habitants confient au seigneur des tâches qu'il accomplit lui-même
## (chasse, livraison, objet perdu, escorte). Un « ! » doré signale qui a du travail, un « ? » qui attend
## son rapport ; un rayon de lumière marque l'objectif et un bandeau en haut de l'écran suit la quête.

const MAX_ACTIVES := 3
static var inst: Quests

var _beacon: Node3D
var _beacon_lbl: Label3D
var _marks := {}           # pnj -> Label3D (! / ?)
var _pickups := {}         # quest id -> Node3D (objet à ramasser)
var _followers := {}       # quest id -> Villager (escorté)
var _acc := 0.0
var _ambushed := {}
var tracker: Label

const ITEMS_LIVRAISON := ["un panier de pain chaud", "une lettre scellée", "des herbes médicinales", "une hache réaffûtée", "un pot de miel", "une couverture tissée"]
const ITEMS_PERDUS := ["le médaillon de ma mère", "la hache de mon père", "un sac de grain", "ma bourse", "le livre de comptes", "une amulette de protection"]
const LIEUX := [
	{"nom": "le camp des bûcherons", "pos": Vector2(-120, -10)},
	{"nom": "l'entrée de la mine", "pos": Vector2(168, -165)},
	{"nom": "la ferme", "pos": Vector2(95, -5)},
	{"nom": "le vieux pont", "pos": Vector2(-48, 40)},
	{"nom": "l'esplanade du portail", "pos": Vector2(42, 228)},
	{"nom": "la lisière du Bois des Morts", "pos": Vector2(-140, 50)},
]
const CHASSE_TXT := {
	"puglin": "Les puglins de %s nous volent poules et récoltes. Faites-leur passer l'envie !",
	"zombie": "Des morts errent près de %s. Mes enfants n'osent plus sortir…",
	"bandit": "Des bandits rôdent vers %s. Ils ont dépouillé mon cousin la semaine dernière.",
	"imp": "Des diablotins sortent de %s la nuit. Ils mettent le feu aux granges !",
	"lanceur": "Des brigands armés de javelots tiennent %s. Plus personne ne passe.",
	"mercenaire": "Un mercenaire de Vargas a pris position vers %s. Il faut l'en déloger.",
	"chef_bandit": "Le chef des bandits se cache vers %s. Sa tête vaut de l'or !",
	"deserteur": "Un déserteur armé terrorise les passants vers %s.",
	"imp_brute": "Une brute infernale garde %s. Vous seul pouvez l'abattre.",
}

static func _st() -> Dictionary:
	var m := GameState.get_inst().mem("_quetes")
	if not m.has("actives"):
		m["actives"] = []
		m["faites"] = 0
		m["donneurs"] = {}
		m["n"] = 0
	return m

static func actives() -> Array:
	return _st()["actives"]

func _ready() -> void:
	inst = self
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	tracker = Label.new()
	tracker.add_theme_font_size_override("font_size", 22)
	tracker.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	tracker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	tracker.add_theme_constant_override("outline_size", 6)
	tracker.position = Vector2(24, 158)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tracker)
	_beacon = Node3D.new()
	var pil := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.6
	cm.height = 40.0
	cm.cap_top = false
	cm.cap_bottom = false
	pil.mesh = cm
	pil.material_override = Magic.energy(Color(1.0, 0.8, 0.3), 0.18)
	pil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pil.position.y = 20.0
	_beacon.add_child(pil)
	_beacon_lbl = Label3D.new()
	_beacon_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beacon_lbl.no_depth_test = true
	_beacon_lbl.fixed_size = true
	_beacon_lbl.pixel_size = 0.0018
	_beacon_lbl.font_size = 40
	_beacon_lbl.outline_size = 10
	_beacon_lbl.modulate = Color(1.0, 0.85, 0.4)
	_beacon_lbl.position.y = 4.0
	_beacon.add_child(_beacon_lbl)
	_beacon.visible = false
	add_child(_beacon)

# ------------------------------------------------------------------ donneurs de quêtes
static func is_giver(n: Node3D) -> bool:
	if not n.has_meta("talk") or not (n is Villager):
		return false
	var t: Dictionary = n.get_meta("talk")
	if not (t["role"] in ["habitant", "paysan", "bucheron", "mineur"]):
		return false
	return absi(String(t["id"]).hash()) % 3 == 0

static func quest_of_giver(id: String) -> Dictionary:
	for q in actives():
		if q["giver"] == id:
			return q
	return {}

static func can_offer(n: Node3D) -> bool:
	if not is_giver(n) or not Story.done():
		return false
	var id: String = n.get_meta("talk")["id"]
	if not quest_of_giver(id).is_empty() or actives().size() >= MAX_ACTIVES:
		return false
	var last := float(_st()["donneurs"].get(id, -9999.0))
	return Time.get_unix_time_from_system() - last > 480.0

## Fabrique une quête adaptée au donneur et à l'état du monde
static func make(n: Node3D) -> Dictionary:
	var t: Dictionary = n.get_meta("talk")
	var here := Vector2(n.global_position.x, n.global_position.z)
	var st := _st()
	st["n"] = int(st["n"]) + 1
	var q := {"id": "q%d" % st["n"], "giver": t["id"], "giver_nom": t["nom"], "state": "en_cours"}
	var kinds := ["chasse", "livraison", "recuperation", "escorte"]
	var k: String = kinds[(absi(String(t["id"]).hash()) + int(st["faites"])) % kinds.size()]
	if k == "chasse":
		var best: Dictionary = {}
		var bd := 1e9
		for z in Spawner.ZONES:
			var sp := Spawner.by_id(z["id"])
			if sp == null or sp.liberated:
				continue
			var d := (z["pos"] as Vector2).distance_to(here)
			if d < bd and d > 40.0:
				bd = d
				best = z
		if best.is_empty():
			k = "livraison"
		else:
			var lieu := String(best["label"]).get_slice("(", 1).trim_suffix(")") if String(best["label"]).contains("(") else String(best["label"]).to_lower()
			q["type"] = "chasse"
			q["zone"] = best["id"]
			q["need"] = mini(int(best["n"]) + 1, 5)
			q["done"] = 0
			q["titre"] = "Chasse : %s" % best["label"]
			q["texte"] = CHASSE_TXT.get(best["kind"], "Des créatures menacent %s. Aidez-nous !") % lieu
			q["pos"] = [best["pos"].x, best["pos"].y]
			q["or"] = 60 + 15 * int(q["need"])
			q["xp"] = 40 + 12 * int(q["need"])
	if k == "livraison":
		var cands := []
		for o in n.get_tree().get_nodes_in_group("pnj"):
			if o != n and o is Villager and o.has_meta("talk") and not o.captive and o.get_meta("talk")["role"] in ["habitant", "paysan", "bucheron", "mineur", "marchand"]:
				if Vector2(o.global_position.x, o.global_position.z).distance_to(here) > 35.0:
					cands.append(o)
		if cands.is_empty():
			k = "recuperation"
		else:
			var o: Node3D = cands[absi(int(st["n"]) * 7919) % cands.size()]
			var item: String = ITEMS_LIVRAISON[int(st["n"]) % ITEMS_LIVRAISON.size()]
			q["type"] = "livraison"
			q["to_id"] = o.get_meta("talk")["id"]
			q["to_nom"] = o.get_meta("talk")["nom"]
			q["item"] = item
			q["titre"] = "Livraison pour %s" % q["to_nom"]
			q["texte"] = "Pourriez-vous porter %s à %s ? Je ne peux pas quitter mon ouvrage." % [item, q["to_nom"]]
			q["or"] = 35
			q["xp"] = 30
	if k == "recuperation":
		var l: Dictionary = LIEUX[(int(st["n"]) * 3) % LIEUX.size()]
		var item2: String = ITEMS_PERDUS[int(st["n"]) % ITEMS_PERDUS.size()]
		var a := float(int(st["n"]) * 2.4)
		var p: Vector2 = l["pos"] + Vector2(cos(a), sin(a)) * 6.0
		q["type"] = "recuperation"
		q["item"] = item2
		q["pos"] = [p.x, p.y]
		q["titre"] = "Objet perdu : %s" % item2
		q["texte"] = "J'ai perdu %s près de %s en fuyant des brigands. Pourriez-vous le retrouver ?" % [item2, l["nom"]]
		q["or"] = 50
		q["xp"] = 45
	if k == "escorte":
		var l2: Dictionary = LIEUX[(int(st["n"]) * 5 + 1) % 3]
		q["type"] = "escorte"
		q["pos"] = [l2["pos"].x, l2["pos"].y]
		q["dest_nom"] = l2["nom"]
		q["titre"] = "Escorte jusqu'à %s" % l2["nom"]
		q["texte"] = "Mon fils doit rejoindre %s, mais les routes ne sont plus sûres. Escortez-le, je vous en prie." % l2["nom"]
		q["or"] = 70
		q["xp"] = 60
	return q

# ------------------------------------------------------------------ dialogue
static func add_options(nodes: Dictionary, choices: Array, who: String, label: String, n: Node3D, id: String) -> void:
	var gs := GameState.get_inst()
	# 1) on rend une quête terminée
	var mine := quest_of_giver(id)
	if not mine.is_empty() and mine["state"] == "a_rendre":
		nodes["q_rendre"] = {"who": who, "nom": label, "text": _thanks(mine), "next": "END"}
		var qq := mine
		choices.insert(0, {"text": "★ " + _done_line(mine), "next": "q_rendre", "callback": func(): complete(qq)})
	elif not mine.is_empty():
		nodes["q_suivi"] = {"who": who, "nom": label, "text": "Alors, %s ? %s" % [gs.titre, _progress(mine)], "next": "menu"}
		choices.insert(0, {"text": "À propos de votre demande…", "next": "q_suivi"})
	# 2) livraison destinée à ce PNJ
	for q in actives():
		if q.get("type", "") == "livraison" and q.get("to_id", "") == id and q["state"] == "en_cours":
			var q2: Dictionary = q
			nodes["q_livre"] = {"who": who, "nom": label, "text": "%s, de la part de %s ? Comme c'est aimable ! Dites-lui merci pour moi." % [String(q2["item"]).capitalize(), q2["giver_nom"]], "next": "menu"}
			choices.insert(0, {"text": "★ Je vous apporte %s" % q2["item"], "next": "q_livre", "callback": func():
				q2["state"] = "a_rendre"
				GameState.get_inst().mark()
				_hint("Livré ! Retournez voir %s." % q2["giver_nom"])})
	# 3) nouvelle quête proposée
	if can_offer(n):
		var q3 := make(n)
		nodes["q_offre"] = {"who": who, "nom": label, "text": q3["texte"] + "\n(Récompense : %d or, %d XP)" % [q3["or"], q3["xp"]], "choices": [
			{"text": "J'accepte. Comptez sur moi.", "next": "q_ok", "callback": func(): accept(q3)},
			{"text": "Pas maintenant.", "next": "menu"}]}
		nodes["q_ok"] = {"who": who, "nom": label, "text": "Merci, %s ! Que les dieux vous gardent." % gs.titre, "next": "END"}
		choices.insert(0, {"text": "! Avez-vous du travail pour moi ?", "next": "q_offre"})

static func _done_line(q: Dictionary) -> String:
	match q["type"]:
		"chasse": return "C'est fait : la menace est éliminée."
		"livraison": return "Votre colis est livré."
		"recuperation": return "J'ai retrouvé %s." % q["item"]
		"escorte": return "Votre fils est arrivé sain et sauf."
	return "C'est fait."

static func _thanks(q: Dictionary) -> String:
	return "Vraiment ? Merci, %s ! On se souviendra de vous au bourg. Voici %d pièces, c'est tout ce que j'ai." % [GameState.get_inst().titre, q["or"]]

static func _progress(q: Dictionary) -> String:
	match q["type"]:
		"chasse": return "Il en reste %d à abattre." % (int(q["need"]) - int(q["done"]))
		"livraison": return "%s attend toujours %s." % [q["to_nom"], q["item"]]
		"recuperation": return "Je prie pour que %s n'ait pas été volé…" % q["item"]
		"escorte": return "Mon fils vous attend, il est prêt à partir."
	return ""

static func accept(q: Dictionary) -> void:
	actives().append(q)
	_st()["donneurs"][q["giver"]] = Time.get_unix_time_from_system()
	GameState.get_inst().mark()
	if Hud.inst:
		Hud.inst.discover("Nouvelle quête", q["titre"])
	if inst:
		inst._spawn_for(q)

static func complete(q: Dictionary) -> void:
	actives().erase(q)
	var st := _st()
	st["faites"] = int(st["faites"]) + 1
	Progression.get_inst().add_gold(int(q["or"]))
	Progression.get_inst().add_xp(int(q["xp"]))
	var gs := GameState.get_inst()
	gs.add("confiance_habitants", 2)
	gs.add("reputation", 1)
	var m := gs.mem(String(q["giver"]))
	m["relation"] = int(m.get("relation", 0)) + 3
	gs.report("Quête accomplie pour %s : %s (+%d or)." % [q["giver_nom"], q["titre"], q["or"]], "acte")
	gs.mark()
	if Hud.inst:
		Hud.inst.discover("Quête accomplie", "%s   +%d or  +%d XP" % [q["titre"], q["or"], q["xp"]])
	if Combat.player:
		Magic.pillar(Combat.player.global_position, Color(1.0, 0.85, 0.4), 5.0, 0.8, 1.0)
	Sfx.play("niveau", -6.0)

static func on_kill(zone_id: String) -> void:
	for q in actives():
		if q.get("type", "") == "chasse" and q.get("zone", "") == zone_id and q["state"] == "en_cours":
			q["done"] = int(q["done"]) + 1
			if int(q["done"]) >= int(q["need"]):
				q["state"] = "a_rendre"
				_hint("Chasse terminée ! Retournez voir %s." % q["giver_nom"])
			else:
				_hint("%s : %d/%d" % [q["titre"], q["done"], q["need"]])
			GameState.get_inst().mark()

static func _hint(t: String) -> void:
	if Hud.inst:
		Hud.inst.show_message(t, Color(1.0, 0.85, 0.45))

# ------------------------------------------------------------------ objets, escortés, marqueurs, suivi
func _spawn_for(q: Dictionary) -> void:
	if q["state"] != "en_cours":
		return
	if q["type"] == "recuperation" and not _pickups.has(q["id"]):
		var p := Vector3(float(q["pos"][0]), 0, float(q["pos"][1]))
		# jamais dans l'eau : on cherche la terre ferme la plus proche
		for k in 24:
			if Terrain.height_at(p.x, p.z) > Layout.WATER + 0.5 and Layout.river_dist(Vector2(p.x, p.z)) > Layout.RIVER_W + 1.5:
				break
			p += Vector3(cos(k * 0.9), 0, sin(k * 0.9)) * 2.5
		q["pos"] = [p.x, p.z]
		p.y = Terrain.height_at(p.x, p.z)
		var n := Node3D.new()
		get_parent().add_child(n)
		n.global_position = p
		Kit.dungeon(n, "ChestSmall", Vector3.ZERO, 0.0, 1.0)
		var glow := FX.particles("spark_04", 10, 1.2, [Color(1, 0.9, 0.5, 1), Color(1, 0.7, 0.2, 0)], 0.25, false)
		glow.direction = Vector3.UP
		glow.gravity = Vector3.ZERO
		glow.initial_velocity_min = 0.5
		glow.initial_velocity_max = 1.2
		n.add_child(glow)
		glow.position.y = 0.5
		glow.emitting = true
		_pickups[q["id"]] = n
	if q["type"] == "escorte" and not _followers.has(q["id"]):
		var g := Talk.node_of(String(q["giver"]))
		var v := Villager.new()
		v.spec = {"outfit": "paysan_h", "hair": "Hair_SimpleParted", "tint": Color(0.9, 0.95, 1.0)}
		get_parent().add_child(v)
		var at: Vector3 = g.global_position + Vector3(1.2, 0, 1.2) if g else (Combat.player.global_position + Vector3(2, 0, 0))
		v.global_position = Vector3(at.x, Powers.ground(at + Vector3.UP), at.z)
		v.captive = true
		v.set_meta("talk", {"id": "escorte_" + String(q["id"]), "nom": "Colin", "role": "escorte"})
		_followers[q["id"]] = v

func _process(delta: float) -> void:
	_acc += delta
	var p := Combat.player
	if p == null:
		return
	# escortés : suivent le seigneur
	for qid in _followers.keys():
		var v: Villager = _followers[qid]
		if not is_instance_valid(v):
			_followers.erase(qid)
			continue
		var to := p.global_position - v.global_position
		to.y = 0.0
		if to.length() > 2.6:
			var d := to.normalized()
			var spd := 5.0 if to.length() > 6.0 else 3.0
			v.global_position += d * spd * delta
			v.global_position.y = Powers.ground(v.global_position + Vector3.UP * 0.6)
			v.rotation.y = atan2(d.x, d.z)
			v._play("Jog_Fwd" if spd > 4.0 else "Walk")
			if to.length() > 40.0:
				v.global_position = p.global_position - p.global_transform.basis.z * -2.0
		else:
			v._play("Idle")
	if _acc < 0.4:
		return
	_acc = 0.0
	var pp := Vector2(p.global_position.x, p.global_position.z)
	for q in actives().duplicate():
		if q["state"] != "en_cours":
			continue
		if q["type"] == "recuperation":
			if not _pickups.has(q["id"]):
				_spawn_for(q)
			var n: Node3D = _pickups.get(q["id"])
			if n and pp.distance_to(Vector2(n.global_position.x, n.global_position.z)) < 2.2:
				Magic.burst(n.global_position, Color(1.0, 0.85, 0.4), 0.6)
				n.queue_free()
				_pickups.erase(q["id"])
				q["state"] = "a_rendre"
				GameState.get_inst().mark()
				_hint("Vous avez retrouvé %s ! Rapportez-le à %s." % [q["item"], q["giver_nom"]])
		elif q["type"] == "escorte":
			if not _followers.has(q["id"]):
				_spawn_for(q)
			var dest := Vector2(float(q["pos"][0]), float(q["pos"][1]))
			var v2: Villager = _followers.get(q["id"])
			# embuscade à mi-chemin
			if v2 and not _ambushed.has(q["id"]) and pp.distance_to(dest) < 70.0 and pp.distance_to(Layout.TOWN) > 45.0:
				_ambushed[q["id"]] = true
				var w := get_parent()
				if w.get("events"):
					w.events.trigger(p.global_position, -p.global_basis.z)
			if v2 and Vector2(v2.global_position.x, v2.global_position.z).distance_to(dest) < 9.0:
				FX.bark(v2, "Merci, seigneur ! Je suis arrivé.", 2.3, 2.5)
				v2.captive = false
				v2.path = [dest, dest + Vector2(3, 2)]
				_followers.erase(q["id"])
				q["state"] = "a_rendre"
				GameState.get_inst().mark()
				_hint("Escorte réussie ! Retournez voir %s." % q["giver_nom"])
	_update_marks()
	_update_tracker(pp)

func _target_of(q: Dictionary) -> Vector3:
	if q["state"] == "a_rendre":
		var g := Talk.node_of(String(q["giver"]))
		return g.global_position if g else Vector3.INF
	match q["type"]:
		"livraison":
			var o := Talk.node_of(String(q["to_id"]))
			return o.global_position if o else Vector3.INF
		_:
			var x := float(q["pos"][0])
			var z := float(q["pos"][1])
			return Vector3(x, Terrain.height_at(x, z), z)

func _update_tracker(pp: Vector2) -> void:
	var lines := []
	var best_t := Vector3.INF
	var bd := 1e9
	for q in actives():
		var t := _target_of(q)
		var d := pp.distance_to(Vector2(t.x, t.z)) if t != Vector3.INF else -1.0
		var obj := ""
		if q["state"] == "a_rendre":
			obj = "Retourner voir %s" % q["giver_nom"]
		else:
			match q["type"]:
				"chasse": obj = "%s (%d/%d)" % [q["titre"], q["done"], q["need"]]
				"livraison": obj = "Porter %s à %s" % [q["item"], q["to_nom"]]
				"recuperation": obj = "Retrouver %s" % q["item"]
				"escorte": obj = "Escorter Colin jusqu'à %s" % q["dest_nom"]
		lines.append("◆ %s%s" % [obj, ("  — %d m" % int(d)) if d >= 0.0 else ""])
		if d >= 0.0 and d < bd:
			bd = d
			best_t = t
	tracker.text = "\n".join(lines)
	tracker.visible = lines.size() > 0 and not Dialogue.active
	_beacon.visible = best_t != Vector3.INF and bd > 6.0
	if _beacon.visible:
		_beacon.global_position = best_t
		_beacon_lbl.text = "%d m" % int(bd)

func _update_marks() -> void:
	var seen := {}
	for n in get_tree().get_nodes_in_group("pnj"):
		if not n.has_meta("talk") or not n.visible:
			continue
		var id: String = n.get_meta("talk")["id"]
		var sym := ""
		var q := quest_of_giver(id)
		if not q.is_empty() and q["state"] == "a_rendre":
			sym = "?"
		elif can_offer(n):
			sym = "!"
		for q2 in actives():
			if q2.get("type", "") == "livraison" and q2.get("to_id", "") == id and q2["state"] == "en_cours":
				sym = "?"
		if sym == "":
			continue
		seen[n] = true
		var l: Label3D = _marks.get(n)
		if l == null or not is_instance_valid(l):
			l = Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.font_size = 120
			l.outline_size = 24
			l.pixel_size = 0.006
			l.modulate = Color(1.0, 0.82, 0.25)
			l.position.y = 2.45
			n.add_child(l)
			_marks[n] = l
		l.text = sym
		l.visible = true
	for n in _marks.keys():
		if not seen.has(n):
			if is_instance_valid(_marks[n]):
				_marks[n].visible = false
