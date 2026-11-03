class_name CampParley
extends Node
## Pourparlers des camps : un camp d'êtres doués de parole n'attaque pas à vue.
## À l'approche, une sentinelle (ou le chef) vient au-devant du souverain : « Halte ! Qui va là ? ».
## Intimider, payer, recruter, défier le chef en duel d'honneur, attaquer… ou passer son chemin.

static var inst: CampParley
const PARLANTS := ["bandit", "lanceur", "mercenaire", "chef_bandit", "deserteur", "puglin", "lieutenant"]
const CHALLENGE_R := 24.0
var _acc := 0.0
var _busy := false
var _cool := {}            # gid -> instant avant une nouvelle interpellation
var _warned := {}          # gid -> le souverain a promis de passer son chemin
var duel_gid := ""
var duel_chef: Node3D = null
var _duel_ring: Array = []
var _duel_mark: Node3D = null

func _ready() -> void:
	inst = self

static func _st() -> Dictionary:
	return GameState.get_inst().mem("_camps")

## Camp « parlant » encore en pourparlers ?
static func is_peaceful(zone_id: String) -> bool:
	if zone_id == "" or zone_id.begins_with("evt_"):
		return false
	var gid := Spawner.group_of(zone_id)
	var kind := ""
	for z in Spawner.ZONES:
		if z["id"] == gid:
			kind = z["kind"]
	if not PARLANTS.has(kind):
		return false
	return String(_st().get(gid, "neutre")) == "treve"

static func set_status(gid: String, s: String) -> void:
	_st()[gid] = s
	GameState.get_inst().mark()

static func members(gid: String) -> Array:
	var out := []
	for sp in Spawner.spawners:
		if is_instance_valid(sp) and Spawner.group_of(sp.zone_id) == gid:
			for m in sp._alive:
				if Combat.alive(m):
					out.append(m)
	return out

static func zone(gid: String) -> Dictionary:
	for z in Spawner.ZONES:
		if z["id"] == gid:
			return z
	return {}

## Un membre d'un camp en pourparlers est frappé : tout le camp prend les armes
static func provoked(m: Node3D) -> void:
	if m.spawner == null:
		m.peaceful = false
		return
	var gid := Spawner.group_of(m.spawner.zone_id)
	if inst and gid == inst.duel_gid:
		return
	set_status(gid, "neutre")
	for o in members(gid):
		o.peaceful = false
		o._aggro()
	FX.bark(m, ["Aux armes !", "Il nous attaque !", "Trahison !"][randi() % 3], 2.3, 2.0)

## Par défaut, un camp attaque normalement. À l'approche d'un camp « qui parle », un bouton ✋ permet
## au souverain d'imposer une trêve et d'ouvrir les pourparlers AVANT le combat (ou de l'interrompre).
func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.3:
		return
	_acc = 0.0
	var p := Combat.player
	if p == null or p.cbt.dead or Dialogue.active or _busy or duel_gid != "":
		if duel_gid != "":
			_duel_tick()
		return
	var pp := Vector2(p.global_position.x, p.global_position.z)
	var near_gid := ""
	var near_d := 52.0
	for z in Spawner.ZONES:
		var gid: String = z["id"]
		if Spawner.group_of(gid) != gid or not PARLANTS.has(z["kind"]):
			continue
		var st: String = _st().get(gid, "neutre")
		if st in ["libere", "allie"]:
			continue
		var d := pp.distance_to(z["pos"])
		if st == "treve" and _warned.has(gid):
			if d < 9.0:
				_warned.erase(gid)
				var ms := members(gid)
				if ms.size() > 0:
					FX.bark(ms[0], "Tu avais dit que tu passais ton chemin !", 2.4, 2.4)
					provoked(ms[0])
			elif d > CHALLENGE_R + 20.0:
				_warned.erase(gid)
				set_status(gid, "neutre")
			continue
		if d < near_d and members(gid).size() > 0:
			near_d = d
			near_gid = gid
	if near_gid != "" and Hud.inst and not Hud.inst.choice_btns.size():
		var g := near_gid
		var ms2 := members(g)
		var fighting := ms2.any(func(m): return m.state in [Monster.S.POURSUITE, Monster.S.ATTAQUE])
		# première approche : les sentinelles viennent au-devant du souverain AVANT tout combat
		# jamais en plein combat : si le souverain se bat (ou vient d'être frappé), les sentinelles attendent
		var busy_fight: bool = Time.get_ticks_msec() / 1000.0 - float(Combat.player.last_hurt) < 6.0 or Combat.in_radius(Combat.player.global_position, 25.0).any(func(m): return m.state in [Monster.S.POURSUITE, Monster.S.ATTAQUE, Monster.S.FUITE, Monster.S.ETOURDI] or not ms2.has(m))
		if not fighting and not busy_fight and not _hailed.has(g) and near_d < 50.0 and String(_st().get(g, "neutre")) == "neutre":
			_hailed[g] = true
			_sentries(g, ms2)
			return
		Hud.inst.show_prompt("parler", "Parlementer", func(): parley(g), 0.45)
	# camp vaincu mais pas encore rasé : on peut y mettre le feu
	for z in Spawner.ZONES:
		var gz: String = z["id"]
		if Spawner.group_of(gz) != gz or not PARLANTS.has(z["kind"]):
			continue
		var stz: String = _st().get(gz, "neutre")
		if stz in ["rase", "allie", "libere"] or not _hailed.has(gz):
			continue
		if pp.distance_to(z["pos"]) < 16.0 and members(gz).is_empty() and Hud.inst and not Hud.inst.btn_prompt.visible:
			var g2 := gz
			Hud.inst.show_prompt("feu", "Raser le camp", func(): raze(g2), 0.45)

var _hailed := {}

## Les sentinelles s'avancent : « Halte ! Tu veux voir le chef ? »
func _sentries(gid: String, ms: Array) -> void:
	var p := Combat.player
	var guards := ms.filter(func(m): return not m.def.get("elite", false)).slice(0, 2)
	if guards.is_empty():
		guards = ms.slice(0, 1)
	for m in ms:
		m.peaceful = true
	set_status(gid, "treve")
	_busy = true
	var lead: Node3D = guards[0]
	for i in guards.size():
		var g: Node3D = guards[i]
		var to: Vector3 = p.global_position - g.global_position
		to.y = 0.0
		var dest: Vector3 = p.global_position - to.normalized() * 3.4 + to.normalized().cross(Vector3.UP) * (i * 1.6 - 0.8)
		dest.y = Powers.ground(dest + Vector3.UP)
		g._play("marche", 0.2)
		var tw := create_tween()
		tw.tween_property(g, "global_position", dest, clampf(g.global_position.distance_to(dest) / 4.5, 0.3, 3.0))
		tw.tween_callback(func():
			if Combat.alive(g):
				g.look_at(Vector3(p.global_position.x, g.global_position.y, p.global_position.z), Vector3.UP)
				g.rotate_y(PI)
				g._play("attente", 0.2))
	FX.bark(lead, "Halte ! Pas un pas de plus !", 2.4, 2.0)
	var label: String = zone(gid).get("label", "Camp")
	get_tree().create_timer(clampf(lead.global_position.distance_to(p.global_position) / 4.5, 0.4, 3.0) + 0.2).timeout.connect(func():
		_busy = false
		if not Combat.alive(lead):
			return
		var nodes := {"menu": {"who": "pnj", "nom": "Sentinelle — %s" % label, "text": "Halte ! Tu es sur nos terres. Qu'est-ce que tu veux ? Parler au chef, peut-être ?", "choices": [
			{"text": "Je veux parler à votre chef.", "next": "END", "callback": func(): _challenge(gid, members(gid))},
			{"text": "Je suis venu raser votre camp.", "next": "END", "callback": func():
				GameState.get_inst().add("crainte", 1)
				FX.bark(lead, "Alerte ! ALERTE !", 2.4, 2.0)
				provoked(lead)},
			{"text": "Je passe mon chemin.", "next": "END", "callback": func():
				_warned[gid] = true
				FX.bark(lead, "C'est ça. File.", 2.4, 1.8)},
		]}}
		var w := Justice.world()
		if w.get("rig"):
			w.rig.frame_talk(p, lead)
		w.dlg.start({"start": "menu", "nodes": nodes, "fermable": true}))

## Raser un camp vaincu : tentes en flammes, fumée, butin ; le camp ne reviendra pas
func raze(gid: String) -> void:
	var z := zone(gid)
	var c: Vector2 = z["pos"]
	var r: float = float(z["r"])
	set_status(gid, "rase")
	for sp in Spawner.spawners:
		if is_instance_valid(sp) and Spawner.group_of(sp.zone_id) == gid:
			sp.liberated = true
	var root := Node3D.new()
	root.name = "CampEnFlammes"
	get_tree().current_scene.add_child(root)
	for k in 7:
		var a := TAU * k / 7.0
		var q := c + Vector2(cos(a), sin(a)) * r * randf_range(0.3, 0.9)
		var at := Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.4, q.y)
		var f := FX.particles("fire_01", 14, 0.9, [Color(1, 0.85, 0.45, 0.95), Color(1, 0.35, 0.1, 0.6), Color(0.2, 0.1, 0.05, 0)], 1.6, false)
		f.direction = Vector3.UP
		f.initial_velocity_min = 1.0
		f.initial_velocity_max = 2.5
		f.gravity = Vector3(0, 1.5, 0)
		root.add_child(f)
		f.global_position = at
		f.emitting = true
		var sm := FX.particles("smoke_02", 6, 3.5, [Color(0.2, 0.18, 0.16, 0.6), Color(0.3, 0.3, 0.3, 0)], 3.0, false, false)
		sm.direction = Vector3.UP
		sm.initial_velocity_min = 1.0
		sm.initial_velocity_max = 2.0
		root.add_child(sm)
		sm.global_position = at + Vector3.UP * 1.5
		sm.emitting = true
		FX._scorch_mark(at, 2.5)
	FX.impact_light(Vector3(c.x, Terrain.height_at(c.x, c.y) + 2.0, c.y), Color(1.0, 0.5, 0.2), 4.0, r * 3.0)
	var gold := 60 + int(r * 10.0)
	Progression.get_inst().add_gold(gold)
	GameState.get_inst().add("crainte", 3)
	GameState.get_inst().add("bienveillance", -1)
	GameState.get_inst().report("Le %s a été rasé par le souverain (+%d or de butin)." % [String(z["label"]).to_lower(), gold], "acte")
	if Hud.inst:
		Hud.inst.discover("Camp rasé", "%s part en fumée — +%d or" % [z["label"], gold])
	get_tree().create_timer(40.0).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free())

## Le souverain lève la main : trêve immédiate, le chef vient parlementer
func parley(gid: String) -> void:
	var ms := members(gid)
	if ms.is_empty():
		return
	set_status(gid, "treve")
	for m in ms:
		m.peaceful = true
		if m.state in [Monster.S.POURSUITE, Monster.S.ATTAQUE]:
			m._go(Monster.S.RETOUR)
	Magic.halo(Combat.player.global_position + Vector3.UP * 1.6, 1.8, Color(1.0, 0.9, 0.6), 0.5)
	Combat.player.action("b/Yes", 0.8, 1.0)
	_challenge(gid, ms)

## La sentinelle s'avance et interpelle le souverain
func _challenge(gid: String, ms: Array) -> void:
	_busy = true
	var chef: Node3D = ms[0]
	for m in ms:
		if m.def.get("elite", false) and not (chef.kind in ["chef_bandit", "deserteur", "mercenaire", "lieutenant"]) and m.kind != "geant":
			chef = m
		if m.kind == "chef_bandit":
			chef = m
	var p := Combat.player
	var to: Vector3 = p.global_position - chef.global_position
	to.y = 0.0
	var dest: Vector3 = p.global_position - to.normalized() * 3.6
	dest.y = Powers.ground(dest + Vector3.UP)
	chef.look_at(Vector3(p.global_position.x, chef.global_position.y, p.global_position.z), Vector3.UP)
	chef.rotate_y(PI)
	chef._play("marche", 0.2)
	FX.bark(chef, "Halte ! Qui va là ?", 2.4, 2.0)
	var tw := create_tween()
	tw.tween_property(chef, "global_position", dest, clampf(chef.global_position.distance_to(dest) / 4.0, 0.3, 2.5))
	tw.tween_callback(func():
		if not Combat.alive(chef):
			_busy = false
			return
		chef._play("attente", 0.2)
		_open(gid, chef, ms.size()))

func _strength(gid: String) -> float:
	var s := 0.0
	for m in members(gid):
		s += float(m.def["xp"])
	return s

func _chance(base: float, stat: float, gid: String) -> float:
	var lv := Progression.get_inst().level
	var ms := members(gid)
	var avg: float = _strength(gid) / maxf(1.0, ms.size())
	return clampf(base + stat * 0.01 + (lv * 20.0 - avg) / 250.0, 0.08, 0.92)

func _open(gid: String, chef: Node3D, n: int) -> void:
	var z := zone(gid)
	var gs := GameState.get_inst()
	var nom: String = chef.def["nom"]
	var label: String = z.get("label", "Camp")
	var price := int(round(25.0 * n + _strength(gid) * 1.5 / 5.0) * 5.0)
	var human: bool = chef.kind != "puglin"
	var who_line := "Halte ! Encore un pas et mes hommes te transpercent. Qui es-tu, et que viens-tu faire chez nous ?" if human else "Grrah ! Humain ! Krak voit toi. Pourquoi toi venir chez nous ?"
	var nodes := {}
	var c_intim := _chance(0.25, gs.val("crainte") + gs.val("autorite"), gid)
	var c_recr := _chance(0.15, gs.val("reputation") + gs.val("confiance_habitants"), gid)
	nodes["menu"] = {"who": "pnj", "nom": "%s — %s" % [nom, label], "text": who_line, "choices": [
		{"text": "Je suis le souverain de ces terres. Partez. (intimider · %d %%)" % int(c_intim * 100), "next": "END", "callback": func(): _intimidate(gid, chef, c_intim)},
		{"text": "Combien pour que vous quittiez mes terres ? (%d or)" % price, "next": "END", "callback": func(): _pay(gid, chef, price)},
		{"text": "Travaillez pour moi. (recruter · %d %%)" % int(c_recr * 100), "next": "END", "callback": func(): _recruit(gid, chef, c_recr)},
		{"text": "J'affronte ton chef, seul. S'il tombe, ce camp est à moi.", "next": "END", "callback": func(): _start_duel(gid, chef)},
		{"text": "Alors vous mourrez tous.", "next": "END", "callback": func():
			gs.add("crainte", 1)
			provoked(chef)},
		{"text": "Je passe mon chemin.", "next": "END", "callback": func():
			_warned[gid] = true   # trêve tant qu'on s'éloigne ; revenir au cœur du camp la rompt
			FX.bark(chef, "C'est ça. Et ne reviens pas.", 2.4, 2.2)},
	]}
	var w := Justice.world()
	if w.get("rig"):
		w.rig.frame_talk(Combat.player, chef)
	w.dlg.start({"start": "menu", "nodes": nodes, "fermable": true})
	_busy = false

## Le camp lève le camp : ses membres s'en vont (le repaire est libéré)
func _disband(gid: String, text: String, status: String) -> void:
	set_status(gid, status)
	for m in members(gid):
		m.peaceful = true
		m.frighten(6.0)
		var mm: Node3D = m
		Powers._after(4.0, func():
			if is_instance_valid(mm):
				Magic.pillar(mm.global_position, Color(1.0, 0.85, 0.5), 3.0, 0.4, 0.6)
				Combat.unregister(mm)
				mm.queue_free())
	for sp in Spawner.spawners:
		if is_instance_valid(sp) and Spawner.group_of(sp.zone_id) == gid:
			Powers._after(4.2, func(): if is_instance_valid(sp): sp.liberated = true)
	GameState.get_inst().report(text, "acte")
	if Hud.inst:
		Hud.inst.discover(String(zone(gid).get("label", "Camp")), text)

func _intimidate(gid: String, chef: Node3D, c: float) -> void:
	var gs := GameState.get_inst()
	Magic.halo(Combat.player.global_position + Vector3.UP, 3.0, Color(1.0, 0.8, 0.4), 0.6)
	FX.shockwave(Combat.player.global_position, 3.0)
	if randf() < c:
		gs.add("crainte", 2)
		FX.bark(chef, "D'accord… d'accord ! On s'en va !", 2.4, 2.4)
		_disband(gid, "Le camp a fui devant votre seule présence.", "libere")
	else:
		FX.bark(chef, "Tu ne me fais pas peur ! À l'attaque !", 2.4, 2.2)
		provoked(chef)

func _pay(gid: String, chef: Node3D, price: int) -> void:
	var prog := Progression.get_inst()
	if prog.gold < price:
		FX.bark(chef, "Tu te moques de moi ? Reviens avec de l'or… ou pas du tout.", 2.4, 2.6)
		_warned[gid] = true
		return
	prog.add_gold(-price)
	GameState.get_inst().add("bienveillance", 1)
	FX.bark(chef, "Marché conclu. On lève le camp.", 2.4, 2.2)
	_disband(gid, "Vous avez payé %d or : le camp quitte vos terres." % price, "libere")

func _recruit(gid: String, chef: Node3D, c: float) -> void:
	var gs := GameState.get_inst()
	if chef.kind == "puglin" or randf() >= c:
		FX.bark(chef, "Servir un seigneur ? Plutôt mourir !", 2.4, 2.2)
		provoked(chef)
		return
	var n := members(gid).size()
	if Kingdom.inst:
		Kingdom.add("soldats", n)
	gs.add("reputation", 2)
	FX.bark(chef, "À vos ordres… mon seigneur.", 2.4, 2.4)
	_disband(gid, "%d hommes du camp rejoignent votre garde." % n, "allie")

# ------------------------------------------------------------------ duel d'honneur
func _start_duel(gid: String, chef: Node3D) -> void:
	duel_gid = gid
	duel_chef = chef
	var p := Combat.player
	var mid: Vector3 = (p.global_position + chef.global_position) * 0.5
	FX.bark(chef, "Ha ! Très bien. Que personne n'intervienne !", 2.4, 2.4)
	_duel_mark = Magic.rune(Vector3(mid.x, Powers.ground(mid + Vector3.UP) + 0.05, mid.z), 6.0, Color(1.0, 0.75, 0.3), 600.0, 0.15)
	# les autres forment le cercle et regardent
	var others := members(gid).filter(func(m): return m != chef)
	for i in others.size():
		var m: Node3D = others[i]
		var a := TAU * i / maxf(1.0, others.size())
		var q := mid + Vector3(cos(a), 0, sin(a)) * 8.5
		q.y = Powers.ground(q + Vector3.UP)
		m.peaceful = true
		m.global_position = q
		m.look_at(Vector3(mid.x, q.y, mid.z), Vector3.UP)
		m.rotate_y(PI)
		_duel_ring.append(m)
	chef.peaceful = false
	chef.duel = true
	chef.cbt.hp_floor = chef.cbt.max_hp * 0.15
	chef._aggro()
	if Hud.inst:
		Hud.inst.show_message("Duel d'honneur ! Vos hommes ne bougeront pas.", Color(1.0, 0.8, 0.45))

func _duel_tick() -> void:
	var p := Combat.player
	if not is_instance_valid(duel_chef) or duel_chef.cbt.dead:
		_end_duel(true, false)
		return
	if p.cbt.dead:
		FX.bark(duel_chef, "Ha ! Le grand souverain… à terre !", 2.4, 2.6)
		_end_duel(false, false)
		return
	for m in _duel_ring:
		if Combat.alive(m) and randf() < 0.05:
			FX.bark(m, ["Vas-y chef !", "Écrase-le !", "Ouh !", "Il tient bon, l'animal…"][randi() % 4], 2.3, 1.4)
	if duel_chef.cbt.hp <= duel_chef.cbt.hp_floor + 0.5:
		_end_duel(true, true)

func _end_duel(won: bool, yielded: bool) -> void:
	var gid := duel_gid
	var chef := duel_chef
	duel_gid = ""
	duel_chef = null
	if is_instance_valid(_duel_mark):
		_duel_mark.queue_free()
	_duel_ring.clear()
	if not won:
		_cool[gid] = Time.get_ticks_msec() / 1000.0 + 90.0
		if Combat.alive(chef):
			chef.duel = false
			chef.cbt.hp_floor = 0.0
			chef.peaceful = true
			chef.cbt.hp = chef.cbt.max_hp
		return
	if yielded and Combat.alive(chef):
		chef.cbt.hp_floor = 0.0
		chef.duel = false
		chef.peaceful = true
		chef.kneel_cc(30.0)
		Magic.halo(chef.global_position + Vector3.UP, 2.4, Color(1.0, 0.8, 0.4), 0.6)
		FX.bark(chef, "Assez ! Je… je me rends.", 2.4, 2.4)
		var nodes := {"menu": {"who": "pnj", "nom": chef.def["nom"], "text": "Il pose un genou à terre, à bout de souffle. « Tu as gagné. Le camp est à toi… Que décides-tu de moi ? »", "choices": [
			{"text": "Relève-toi. Toi et tes hommes, vous me servirez.", "next": "END", "callback": func():
				GameState.get_inst().add("reputation", 2)
				if Kingdom.inst:
					Kingdom.add("soldats", members(gid).size())
				_disband(gid, "Vaincu en duel, le chef et ses hommes vous jurent fidélité.", "allie")},
			{"text": "Disparais, et que je ne te revoie jamais.", "next": "END", "callback": func():
				GameState.get_inst().add("bienveillance", 1)
				_disband(gid, "Vaincu en duel, le chef quitte vos terres avec ses hommes.", "libere")},
			{"text": "Un chef vaincu ne mérite pas de vivre. (achever)", "next": "END", "callback": func():
				GameState.get_inst().add("crainte", 3)
				if Combat.alive(chef):
					Magic.pillar(chef.global_position, Color(1.0, 0.7, 0.3), 5.0, 0.5, 1.0)
					chef.cbt.take_damage(999999.0, Combat.player, "magie")
				_disband(gid, "Vous avez exécuté le chef vaincu. Ses hommes s'enfuient, terrifiés.", "libere")},
		]}}
		var w := Justice.world()
		if w.get("rig"):
			w.rig.frame_talk(Combat.player, chef)
		w.dlg.start({"start": "menu", "nodes": nodes, "fermable": true})
	else:
		_disband(gid, "Le chef est tombé en duel : le camp se disperse.", "libere")
