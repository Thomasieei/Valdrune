extends Node
## Grande Arène : combats permanents entre champions IA (rangs E, B, A, S) avec de vrais pouvoirs annoncés au sol,
## inscription auprès du Maître d'arène, appel du joueur à son tour, récompenses (or, renommée, artefact) ou frais de soins.

const RANKS := ["E", "B", "A", "S"]
const RCOL := {"E": Color(0.7, 0.7, 0.7), "B": Color(0.35, 0.6, 1), "A": Color(0.75, 0.35, 1), "S": Color(1, 0.8, 0.25)}
const STATS := {"E": [320, 0.8], "B": [650, 1.2], "A": [1050, 1.7], "S": [1700, 2.4]}
const GOLD := {"E": 60, "B": 150, "A": 360, "S": 900}
const FAME := {"E": 5, "B": 12, "A": 28, "S": 65}
const HEAL := {"E": 25, "B": 60, "A": 140, "S": 320}
const NAMES := ["Garen le Vif", "Mira des Cendres", "Torvald Brise-Os", "Lyss l'Ombre", "Brakka", "Séléné", "Oron le Juste", "Kael Tempête", "Ysolde", "Varn le Rouge", "Nyx", "Aldric", "Hilda Croc-de-Fer", "Faust", "Rhéa"]
const POWERS := ["foudre", "flamme", "ombre", "lame", "glace"]
const ARTEFACTS := {
	"E": [["Sablier fêlé", "dmg", 0.05], ["Anneau de fer", "hp", 40], ["Dent de loup", "dmg", 0.04]],
	"B": [["Talisman d'orage", "dmg", 0.08], ["Cotte bénie", "hp", 90], ["Plume de phénix", "hp", 70]],
	"A": [["Œil du Néant", "dmg", 0.14], ["Cœur de golem", "hp", 180], ["Lame-écho", "dmg", 0.12]],
	"S": [["Couronne du Champion", "dmg", 0.25], ["Égide céleste", "hp", 350]],
}
var w
var c := Vector3.ZERO
var state := "pause"          # pause, fight, result
var t := 4.0
var f1: Actor
var f2: Actor
var master: Node3D
var registered := false
var duel := false
var save := {"gold": 100, "fame": 0, "rank": 0, "wins": 0, "arts": []}

func start(center: Vector3) -> void:
	c = center
	_load()
	_apply_artefacts()
	# Maître d'arène devant la porte
	master = Node3D.new(); w.add_child(master)
	var m: Node3D = (load("res://assets/chars/Knight.glb") as PackedScene).instantiate(); master.add_child(m)
	for n in m.find_children("*", "AnimationPlayer", true, false): n.free()
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	for n in sk.get_children(): if n is BoneAttachment3D: n.visible = String(n.name) in ["Knight_Cape", "2H_Sword"]
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var src = mi.get_active_material(0)
		if src is StandardMaterial3D: var nm: StandardMaterial3D = src.duplicate(); nm.albedo_color = Color(1, 0.85, 0.55); mi.material_override = nm
	var ap := AnimationPlayer.new(); ap.add_animation_library("", Actor.LIB); m.add_child(ap); ap.root_node = ap.get_path_to(sk.get_parent()); ap.play("Melee_2H_Idle")
	master.position = c + Vector3(-52, 0, 6.5); master.rotation.y = -PI / 2
	var l := Label3D.new(); l.text = "Maître d'arène"; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.font_size = 40; l.outline_size = 10
	l.modulate = Color(1, 0.85, 0.4); l.pixel_size = 0.008; l.position.y = 2.9; master.add_child(l)

func _near_master() -> bool: return w.player.global_position.distance_to(master.global_position) < 4.0

func ctx_label() -> String:
	if not master or duel: return ""
	if _near_master(): return "INSCRIT" if registered else "S'INSCRIRE"
	return ""

func ctx_press() -> void:
	if registered or duel: return
	registered = true
	w.announce("Inscrit ! Rang %s — tu seras appelé après ce combat." % RANKS[save.rank], 4.0)

func hud() -> String:
	return "Or %d · Renommée %d (%s) · Rang %s" % [save.gold, save.fame, _title(), RANKS[save.rank]]

func _title() -> String:
	var f: int = save.fame
	return "Inconnu" if f < 10 else ("Remarqué" if f < 40 else ("Célèbre" if f < 120 else "Légende"))

func player_dueling() -> bool: return duel

# ---------- boucle des combats ----------
func _process(dt: float) -> void:
	t -= dt
	match state:
		"pause":
			if t <= 0: _next_match()
		"fight":
			_powers(dt)
			if duel and w.player.global_position.distance_to(c) > 44: _end(f2)   # sortir de l'arène = abandon
			elif f1 and f1.state == "dead": _end(f2)
			elif f2 and f2.state == "dead": _end(f1)
		"result":
			if t <= 0: _cleanup(); state = "pause"; t = 5.0

func _fighter(rank: String, at: Vector3, opp: Actor) -> Actor:
	var a: Actor = w.spawn(["Knight", "Barbarian", "Mage", "Rogue_Hooded"][randi() % 4], at, 2)
	var st: Array = STATS[rank]
	a.hp_max = st[0]; a.hp = a.hp_max; a.dmg_mul = st[1]; a.speed_mul = 1.0 + 0.08 * RANKS.find(rank)
	a.brain = "ranged" if a.char_name == "Mage" else "melee"
	if a.char_name == "Mage": a.set_style("magic")
	elif a.char_name == "Rogue_Hooded": a.set_style("dual")
	a.fighter = {"rank": rank, "name": NAMES[randi() % NAMES.size()], "power": POWERS[randi() % POWERS.size()], "cd": 4.0, "dodge": 0.0}
	var tag := Label3D.new(); tag.text = "[%s] %s" % [rank, a.fighter.name]; tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 34; tag.outline_size = 9; tag.modulate = RCOL[rank]; tag.pixel_size = 0.007; tag.position.y = 2.9; tag.no_depth_test = true; a.add_child(tag)
	var aura := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.7; tm.outer_radius = 0.85; tm.rings = 24; tm.ring_segments = 4
	aura.mesh = tm; aura.material_override = w._unlit(RCOL[rank]); aura.scale = Vector3(1, 0.1, 1); aura.position.y = 0.06; a.add_child(aura)
	return a

func _next_match() -> void:
	if registered:
		registered = false; duel = true
		var rk: String = RANKS[save.rank]
		w.player.global_position = c + Vector3(-14, 0, 0); w.player.hp = w.player.hp_max; w.player.posture = 100
		f1 = w.player
		f2 = _fighter(rk, c + Vector3(14, 0, 0), f1)
		f2.duel_vs = f1; f1.duel_vs = f2
		w.announce("À toi de combattre ! Rang %s contre %s" % [rk, f2.fighter.name], 4.0)
	else:
		var rk: String = RANKS[[0, 0, 1, 1, 2, 3][randi() % 6]]
		f1 = _fighter(rk, c + Vector3(-12, 0, randf_range(-4, 4)), null)
		f2 = _fighter(rk, c + Vector3(12, 0, randf_range(-4, 4)), null)
		f1.team = 2; f2.team = 3
		f1.duel_vs = f2; f2.duel_vs = f1
		w.announce("Combat de rang %s : %s contre %s" % [rk, f1.fighter.name, f2.fighter.name], 3.5)
	for a in [f1, f2]:
		if a != w.player: a.busy = a.shot("Skeletons_Taunt", true); a.root_lock = a.busy
	w.ring(c, 38.0, Color(1, 0.85, 0.3)); w.shake(0.2)
	state = "fight"

func _end(winner: Actor) -> void:
	state = "result"; t = 4.0
	if duel:
		if winner == w.player: _player_won()
		else: player_lost()
	else:
		w.announce("Victoire de %s !" % winner.fighter.name, 3.0)
		if winner.state != "dead": winner.hold("Cheering"); winner.state = "hold"; winner.duel_vs = null

func _player_won() -> void:
	var rk: String = RANKS[save.rank]
	var art: Array = ARTEFACTS[rk][randi() % ARTEFACTS[rk].size()]
	save.gold += GOLD[rk]; save.fame += FAME[rk]; save.arts.append(art[0]); save.wins += 1
	var up := ""
	if save.wins >= 2 and save.rank < 3: save.rank += 1; save.wins = 0; up = " — PROMU RANG %s !" % RANKS[save.rank]
	_apply_artefacts(); _save()
	w.announce("VICTOIRE ! +%d or · +%d renommée · %s%s" % [GOLD[rk], FAME[rk], art[0], up], 5.0)
	w.player.hold("Cheering"); w.player.state = "hold"
	w.burst(w.player.global_position + Vector3.UP, Color(1, 0.85, 0.3), 40); w.ring(w.player.global_position, 6, Color(1, 0.85, 0.3))
	duel = false; w.player.duel_vs = null

func player_lost() -> void:
	if not duel: return
	var rk: String = RANKS[save.rank]
	var cost: int = min(HEAL[rk], save.gold)
	save.gold -= cost; _save()
	w.announce("Défaite… Soins du guérisseur : -%d or" % cost, 5.0)
	duel = false; w.player.duel_vs = null
	if f2 and is_instance_valid(f2): f2.duel_vs = null
	state = "result"; t = 4.0
	get_tree().create_timer(2.5).timeout.connect(func():
		w.player.global_position = c + Vector3(-50, 0, 3); w.player.revive(); w.player.hp = w.player.hp_max)

func _cleanup() -> void:
	for a in [f1, f2]:
		if a and is_instance_valid(a) and a != w.player: w.remove_actor(a)
	f1 = null; f2 = null

# ---------- pouvoirs des champions (annoncés au sol, évitables) ----------
func _powers(dt: float) -> void:
	for a in [f1, f2]:
		if not a or a == w.player or not is_instance_valid(a) or a.state == "dead" or not a.fighter: continue
		var o: Actor = a.duel_vs
		if not o or not is_instance_valid(o) or o.state == "dead": continue
		var fd: Dictionary = a.fighter
		fd.cd -= dt; fd.dodge -= dt
		# esquive intelligente : sort des zones annoncées par l'adversaire
		if fd.dodge <= 0 and w.danger_at(a.global_position, a) and a.is_on_floor() and not a.incap():
			fd.dodge = 1.2 - 0.2 * RANKS.find(fd.rank)
			var away: Vector3 = (a.global_position - o.global_position).normalized().rotated(Vector3.UP, 1.2 if randf() < 0.5 else -1.2)
			a.move_in = Vector2(away.x, away.z); a.busy = 0; a.dodge()
			continue
		if fd.cd > 0 or not a.can_act(): continue
		var r := RANKS.find(fd.rank)
		fd.cd = randf_range(5.0, 7.0) - r * 0.8
		var op := o.global_position + Vector3(o.velocity.x, 0, o.velocity.z) * 0.6
		var k: float = 1.0 + r * 0.35
		match fd.power:
			"foudre":
				a.busy = a.shot("Ranged_Magic_Raise", true); a.root_lock = a.busy
				for i in 2 + r:
					a.delay(i * 0.35, func():
						var q := o.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
						w.tele_circle(a, q, 1.8 + r * 0.2, 0.9, 30 * k, 3)
						a.delay(0.9, func(): w.lightning(q)))
			"flamme":
				a.busy = a.shot("Ranged_Magic_Summon", true); a.root_lock = a.busy + 0.6
				w.tele_circle(a, a.global_position, 4.0 + r, 1.1, 45 * k, 9)
				a.delay(1.1, func(): w.ring(a.global_position, 4.0 + r, Color(1, 0.45, 0.1)); w.burst(a.global_position + Vector3.UP, Color(1, 0.5, 0.1), 40))
			"ombre":
				var dir: Vector3 = (op - a.global_position).normalized()
				w.tele_line(a, a.global_position, dir, 9.0, 1.6, 0.6, 40 * k, 4)
				a.busy = 0.9; a.root_lock = 0.9
				a.delay(0.6, func():
					w.afterimage(a); var np: Vector3 = a.global_position + dir * 8.5
					if np.distance_to(c) > 36: np = c + (np - c).normalized() * 36
					a.global_position = np; a.shot("Melee_Dualwield_Attack_Stab", true))
			"lame":
				a.busy = a.shot("Ranged_Magic_Raise", true); a.root_lock = a.busy
				w.tele_circle(a, op, 3.0 + r * 0.4, 1.2, 0, 0)
				w.divine_blade(op, 3.0 + r * 0.4, 50 * k, 1.0, a)
			"glace":
				var dir2: Vector3 = (op - a.global_position).normalized()
				a.busy = a.shot("Ranged_Magic_Spellcasting_Long", true); a.root_lock = 1.0
				w.tele_cone(a, a.global_position, dir2, 7.0 + r, 35.0, 0.9, 40 * k, 2)
				a.delay(0.9, func():
					w.burst(a.global_position + dir2 * 4 + Vector3.UP, Color(0.6, 0.9, 1), 40)
					if o.state != "dead" and (o.global_position - a.global_position).length() < 7 + r: o.stun(0.8 + r * 0.2))

# ---------- artefacts & sauvegarde ----------
func _apply_artefacts() -> void:
	var p: Actor = w.player
	if not p: return
	var dm := 0.0; var hp := 0.0
	for n in save.arts:
		for rk in ARTEFACTS:
			for art in ARTEFACTS[rk]:
				if art[0] == n:
					if art[1] == "dmg": dm += art[2]
					else: hp += art[2]
	p.set_meta("art_dmg", dm); p.set_meta("art_hp", hp)
	p.dmg_mul = (1.0 + 0.15 * (w.K.lvl - 1)) * (1.0 + dm)
	p.hp_max = 600 + 80 * (w.K.lvl - 1) + hp

func _save() -> void:
	var f := FileAccess.open("user://bruneval.json", FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(save))

func _load() -> void:
	if not FileAccess.file_exists("user://bruneval.json"): return
	var d = JSON.parse_string(FileAccess.get_file_as_string("user://bruneval.json"))
	if d is Dictionary:
		for k in d: save[k] = d[k]
		save.rank = int(save.rank); save.gold = int(save.gold); save.fame = int(save.fame); save.wins = int(save.wins)
