class_name Story
extends Node
## Metteur en scène de l'introduction « La naissance du royaume ».
## Étapes (GameState.story) : debut → suivre → embuscade → colosse → apres_colosse → guidage → porte → roi
## → assaut → roi_apres → libre. Chaque étape est sauvegardée ; en relançant le jeu on reprend
## au dernier point de passage sûr. Le tutoriel est intégré au récit (conseils discrets, boutons dévoilés au fil
## de l'histoire, ralenti la première fois qu'une attaque dangereuse vise le joueur).

signal step_changed(step: String)

static var inst: Story

var world: Node3D
var player: Player
var hud: Hud
var dlg: Dialogue
var elian: Companion
var king: Node3D
var gs: GameState
var step := ""
var enemies: Array = []
var boss: Monster
var _t := 0.0
var _acc := 0.0
var _slowmo_done := false
var _slowmo_real_end := 0.0
var _slowmo_dodges := 0
var _start_pos := Vector3.ZERO
var _first_kill := false
var _fight_t := 0.0
var _wave := 0
var _discovered := {}

const PORTAL_START := Vector2(34, 212)
const AMBUSH := Vector2(29, 148)
const KING_POS := Vector3(0, Castle.FLOOR + 0.9, -156.4)
const THRONE_TALK := Vector3(0, Castle.FLOOR, -149.0)
const GATE_TALK := Vector2(0, -79)
## Route du guidage : de l'embuscade jusqu'à la porte du château (sur la route pavée)
const ROAD_TO_GATE := [Vector2(27, 128), Vector2(26, 112), Vector2(28, 86), Vector2(26, 70), Vector2(23, 58), Vector2(16, 44), Vector2(7, 22), Vector2(2, 2), Vector2(0, -12), Vector2(2, -30), Vector2(0, -48), Vector2(0, -66), Vector2(0, -77)]
const GUIDE_LINES := {
	1: "La route du sud… Avant, les caravanes passaient par ici chaque semaine.",
	3: "Le pont de la Claire ! Après lui, nous sommes sur les terres de Valmont.",
	6: "Voilà le bourg. Les gens ont peur, depuis que Vargas rôde.",
	8: "La place du marché. Il y avait foule, avant la guerre…",
	11: "Le château de Valmont. La porte est gardée jour et nuit.",
}
const DISCOVERIES := [
	[Vector2(24, 62), 9.0, "Le pont de la Claire", "Frontière sud du royaume"],
	[Vector2(0, -20), 16.0, "Le bourg de Valmont", "Marché, artisans et maisons des habitants"],
	[Vector2(0, -84), 10.0, "Château de Valmont", "Siège du roi Aldric III"],
]

func _init() -> void:
	inst = self

func setup(w: Node3D, p: Player, h: Hud, d: Dialogue) -> void:
	world = w
	player = p
	hud = h
	dlg = d
	gs = GameState.get_inst()
	dlg.finished.connect(_on_dialogue_done)
	Monster.on_special = _on_special
	_spawn_king()
	_resume()

static func done() -> bool:
	return GameState.get_inst().story == "libre"

# ------------------------------------------------------------------ reprise au bon endroit
func _resume() -> void:
	var s := gs.story
	match s:
		"debut", "suivre", "embuscade", "colosse":
			_go("debut")
		"apres_colosse", "guidage":
			_place_player(Vector2(28, 138), PI)
			_spawn_elian(Vector3(27, 0, 134))
			_reveal_all_buttons()
			_go("guidage")
		"porte", "roi":
			_place_player(Vector2(0, -95), PI)
			_spawn_elian(Vector3(1.5, 0, -97))
			_reveal_all_buttons()
			_go("roi")
		"assaut":
			_place_player(Vector2(0, -122), 0.0)
			_spawn_elian(Vector3(2, 0, -122))
			_reveal_all_buttons()
			_go("assaut")
		"roi_apres":
			_place_player(Vector2(0, -122), PI)
			_spawn_elian(Vector3(2, 0, -122))
			_reveal_all_buttons()
			_go("roi_apres")
		_:
			_reveal_all_buttons()
			Spawner.paused = false
			if not gs.companions.has("elian") or gs.companions["elian"].get("etat", "present") == "present":
				_spawn_elian(player.global_position + Vector3(2, 0, 2))
				elian.follow()
			elif elian == null:
				_spawn_elian(player.global_position + Vector3(2, 0, 2))
				elian.set_absent(true)
			hud.btn_kingdom.visible = true
			step = "libre"
			Kingdom.start(world)

func _place_player(p: Vector2, yaw: float) -> void:
	player.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.3, p.y)
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	if player.rig:
		player.rig.yaw = yaw + PI

func _ground(v: Vector2) -> Vector3:
	return Vector3(v.x, Terrain.height_at(v.x, v.y) + 0.1, v.y)

func _spawn_elian(at: Vector3) -> void:
	if elian == null:
		elian = Companion.new()
		elian.name = "Elian"
		world.add_child(elian)
	at.y = Terrain.height_at(at.x, at.z) + 0.3
	elian.teleport(at)

func _spawn_king() -> void:
	king = Node3D.new()
	king.name = "RoiAldric"
	var m := CharBuilder.build({"outfit": "rodeur_h", "beard": true, "hair": "Hair_SimpleParted", "hair_color": Color(0.78, 0.76, 0.72), "tint": Color(0.75, 0.25, 0.28)})
	king.add_child(m)
	# couronne (anneau d'or) attachée à la tête
	var skel: Skeleton3D = m.get_node("Armature/Skeleton3D")
	var head := "Head" if skel.find_bone("Head") >= 0 else ("head" if skel.find_bone("head") >= 0 else "")
	if head != "":
		var att := BoneAttachment3D.new()
		att.bone_name = head
		skel.add_child(att)
		var crown := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.13
		cyl.bottom_radius = 0.115
		cyl.height = 0.09
		cyl.radial_segments = 10
		cyl.cap_top = false
		cyl.cap_bottom = false
		crown.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.78, 0.25)
		mat.metallic = 0.6
		mat.roughness = 0.35
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		crown.material_override = mat
		crown.position = Vector3(0, 0.2, 0.0)
		att.add_child(crown)
	var ap: AnimationPlayer = m.get_node("AnimationPlayer")
	ap.play("b/Idle_FoldArms" if ap.has_animation("b/Idle_FoldArms") else "Idle")
	world.add_child(king)
	king.global_position = KING_POS
	king.rotation.y = 0.0
	king.add_to_group("pnj")
	king.set_meta("talk", {"id": "roi", "nom": "Aldric III", "role": "roi"})

# ------------------------------------------------------------------ étapes
func _go(s: String) -> void:
	step = s
	_t = 0.0
	match s:
		"debut":
			Spawner.paused = true
			_place_player(PORTAL_START, PI)
			for k in ["attaque", "esquive", "sorts", "potions"]:
				hud.set_shown(k, gs.flag("tuto_" + k))
			hud.objective("")
			_portal_flash()
			_spawn_elian(Vector3(32, 0, 180))
			elian.guide([_ground(Vector2(33, 196)), _ground(PORTAL_START + Vector2(0, -2.6))], 999.0)
			hud.discover("Terres inconnues", "Le portail scellé s'est ouvert…")
		"suivre":
			hud.objective("Suivez Elian")
			elian.guide([_ground(Vector2(32, 195)), _ground(Vector2(32, 182)), _ground(Vector2(31, 165)), _ground(AMBUSH)], 10.0)
			_start_pos = player.global_position
			if not gs.flag("tuto_deplacer"):
				hud.hint("Glissez le pouce sur la gauche de l'écran pour marcher\n(ZQSD / WASD sur ordinateur)", "deplacer")
		"embuscade":
			hud.objective("Survivez à l'embuscade")
			elian.say("Des mercenaires de Vargas ! C'était un piège !", 3.0)
			_spawn_enemies([["mercenaire", Vector2(24, 132)], ["mercenaire", Vector2(31, 130)], ["mercenaire", Vector2(19, 138)]])
			_tuto_show("attaque")
			_tuto_show("esquive")
			if not gs.flag("tuto_epee"):
				hud.hint("Touchez l'épée pour frapper — la cible la plus proche est visée automatiquement", "epee")
				hud.pulse(hud.btn_attack)
			PlayerCombat.respawn_point = Vector2(30, 160)
			PlayerCombat.respawn_text = "Vous vous relevez, sonné… Elian vous a tiré à l'écart."
			_fight_t = 0.0
		"colosse":
			hud.objective("Abattez Brokk le Colosse")
			elian.say("Le Colosse de Vargas… Que les dieux nous gardent !", 3.5)
			boss = _spawn_monster("colosse", Vector2(26, 116))
			boss.leash = 70.0
			player.shake(0.4)
			_tuto_show("potions")
			_tuto_show("sorts")
			hud.discover("Brokk le Colosse", "Champion de Vargas le Brise-Bannières")
			if not gs.flag("tuto_zones"):
				hud.hint("Ses coups lourds s'annoncent au sol : sortez de la zone rouge avant qu'elle ne se remplisse", "zones", 7.0)
				gs.set_flag("tuto_zones")
		"apres_colosse":
			hud.objective("")
			hud.clear_hint()
			hud.pulse(null)
			elian.follow()
			_reveal_all_buttons()
			_after(1.6, func(): _say(elian, "apres_colosse"))
		"guidage":
			hud.objective("Suivez Elian jusqu'au château")
			PlayerCombat.respawn_point = Vector2(0, -70)
			PlayerCombat.respawn_text = "Vous reprenez vos esprits aux portes du château"
			var pts := []
			var start := 0
			var ep := Vector2(elian.global_position.x, elian.global_position.z)
			# reprend la route au point le plus proche d'Elian
			var bd := INF
			for i in ROAD_TO_GATE.size():
				var d := ep.distance_to(ROAD_TO_GATE[i])
				if d < bd:
					bd = d
					start = i
			for i in range(start, ROAD_TO_GATE.size()):
				pts.append(_ground(ROAD_TO_GATE[i]))
			elian.guide(pts, 11.0)
			if not elian.arrived.is_connected(_on_guide_point):
				elian.arrived.connect(_on_guide_point)
		"porte":
			hud.objective("Parlez au garde de la porte")
		"roi":
			hud.objective("Présentez-vous au roi Aldric")
			var pts := [_ground(Vector2(0, -92)), _ground(Vector2(0, -110)), _ground(Vector2(0, -124)), Vector3(0, Castle.FLOOR + 0.2, -131), Vector3(-2.5, Castle.FLOOR + 0.2, -147)]
			elian.guide(pts, 12.0)
		"assaut":
			hud.objective("Défendez la cour du château")
			_courtyard_guards(false)
			elian.guide([Vector3(0, Castle.FLOOR + 0.2, -131), _ground(Vector2(0, -118))], 30.0)
			PlayerCombat.respawn_point = Vector2(0, -122)
			PlayerCombat.respawn_text = "Un garde vous relève : « Tenez bon, la cour n'est pas perdue ! »"
			_wave = 0
		"roi_apres":
			hud.objective("Retournez voir le roi")
			_courtyard_guards(true)
			PlayerCombat.respawn_point = Vector2(0, -70)
			PlayerCombat.respawn_text = "Vous reprenez vos esprits aux portes du château"
			elian.guide([_ground(Vector2(0, -124)), Vector3(0, Castle.FLOOR + 0.2, -131), Vector3(2.5, Castle.FLOOR + 0.2, -147)], 30.0)
		"libre":
			hud.objective("")
			Spawner.paused = false
			elian.follow()
			Companion.data("elian")
			hud.btn_kingdom.visible = true
			hud.pulse(hud.btn_kingdom)
			hud.hint("Vous gouvernez désormais Valmont. Touchez la couronne pour ouvrir le bureau royal.", "royaume", 10.0)
			hud.discover("La naissance du royaume", gs.titre)
			Kingdom.start(world)
	if s != "libre" or gs.story != "libre":
		gs.story = s
		gs.save_game()
	step_changed.emit(s)

## Lance une conversation en tournant le joueur (et la caméra) vers celui qui parle
func _say(who: Node3D, convo: String) -> void:
	if world.has_method("focus_on"):
		world.focus_on(who)
	dlg.start(convo)

func _after(sec: float, f: Callable) -> void:
	get_tree().create_timer(sec).timeout.connect(f)

func _process(delta: float) -> void:
	if player == null or step == "libre" or step == "":
		_slowmo_tick()
		return
	_t += delta
	_slowmo_tick()
	_acc += delta
	if _acc < 0.1:
		return
	var dt := _acc
	_acc = 0.0
	_tutorial_tick()
	_discover_tick()
	var pp := player.global_position
	match step:
		"debut":
			if not Dialogue.active and elian.global_position.distance_to(pp) < 5.0 and _t > 1.0:
				elian.stand(elian.global_position)
				_say(elian, "intro")
		"suivre":
			if Vector2(elian.global_position.x, elian.global_position.z).distance_to(AMBUSH) < 2.0:
				_go("embuscade")
		"embuscade":
			_fight_t += dt
			_clean_enemies()
			if enemies.is_empty() and _fight_t > 1.0:
				elian.say("Il en vient un autre… un géant !", 3.0)
				_go("colosse")
		"colosse":
			if boss and boss.cbt.dead:
				boss = null
				gs.set_flag("colosse_vaincu")
				_go("apres_colosse")
		"guidage":
			if Vector2(pp.x, pp.z).distance_to(GATE_TALK) < 7.0 and not Dialogue.active:
				elian.stand(_ground(Vector2(2.5, -79)))
				_go("porte")
				_say(Castle.guards[0] if Castle.guards.size() > 0 else elian, "garde_porte")
		"roi":
			if pp.distance_to(THRONE_TALK) < 5.5 and absf(pp.y - Castle.FLOOR) < 1.5 and not Dialogue.active and _t > 0.5:
				elian.stand(Vector3(-2.5, Castle.FLOOR + 0.2, -147))
				player.velocity = Vector3.ZERO
				_say(king, "roi")
		"assaut":
			_clean_enemies()
			if _wave == 0 and pp.z > -126.5:
				_wave = 1
				elian.say("Ils sont partout ! Restez près de moi !", 3.0)
				_spawn_enemies([["mercenaire", Vector2(30, -108)], ["mercenaire", Vector2(26, -116)], ["lanceur", Vector2(36, -100)], ["lanceur", Vector2(34, -122)], ["mercenaire", Vector2(-24, -110)]], 60.0)
			elif _wave == 1 and enemies.is_empty():
				_wave = 2
				hud.discover("Lieutenant Harsk", "Bras droit de Vargas")
				_spawn_enemies([["lieutenant", Vector2(0, -95)], ["mercenaire", Vector2(-6, -94)], ["mercenaire", Vector2(6, -94)]], 60.0)
			elif _wave == 2 and enemies.is_empty():
				_wave = 3
				gs.set_flag("cour_defendue")
				gs.add("reputation", 5)
				gs.add("confiance_habitants", 3)
				elian.say("Ils fuient ! La cour est à nous !", 3.0)
				_go("roi_apres")
		"roi_apres":
			if pp.distance_to(THRONE_TALK) < 5.5 and absf(pp.y - Castle.FLOOR) < 1.5 and not Dialogue.active and _t > 0.5:
				_say(king, "roi_apres")

func _on_guide_point(i: int) -> void:
	if step != "guidage":
		return
	var line = GUIDE_LINES.get(i + (ROAD_TO_GATE.size() - elian.waypoints.size()), "")
	if line != "":
		elian.say(line, 4.0)

func _discover_tick() -> void:
	var pp := Vector2(player.global_position.x, player.global_position.z)
	for d in DISCOVERIES:
		var key: String = d[2]
		if not _discovered.has(key) and pp.distance_to(d[0]) < float(d[1]):
			_discovered[key] = true
			if not gs.flag("vu_" + key):
				gs.set_flag("vu_" + key)
				hud.discover(d[2], d[3])

func _on_dialogue_done(last_action: String) -> void:
	match last_action:
		"suivre_elian":
			_go("suivre")
		"guidage":
			_go("guidage")
		"porte_ouverte":
			_go("roi")
		"assaut":
			step = "alerte"
			_after(0.4, func(): _say(king, "alerte"))
		"defendre":
			_go("assaut")
		"fin_intro":
			_go("libre")

# ------------------------------------------------------------------ ennemis
func _spawn_monster(kind: String, at: Vector2, leash := 40.0) -> Monster:
	var m := Monster.new()
	m.kind = kind
	m.no_respawn = true
	m.leash = leash
	m.position = Vector3(at.x, Terrain.height_at(at.x, at.y) + 0.2, at.y)
	world.add_child(m)
	m.look_at(Vector3(player.global_position.x, m.global_position.y, player.global_position.z), Vector3.UP, true)
	m._aggro()
	m.mort.connect(_on_enemy_dead)
	return m

func _spawn_enemies(list: Array, leash := 40.0) -> void:
	for e in list:
		enemies.append(_spawn_monster(e[0], e[1], leash))

func _clean_enemies() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var m = enemies[i]
		if not is_instance_valid(m) or m.cbt.dead:
			enemies.remove_at(i)
		elif m.state == Monster.S.RETOUR or m.state == Monster.S.ERRANCE:
			m._aggro()   # pas de retraite pendant les combats scénarisés

func _on_enemy_dead(_m: Monster) -> void:
	if not _first_kill:
		_first_kill = true
		if step == "embuscade" and not gs.flag("tuto_sort"):
			_tuto_show("sorts")
			hud.hint("Vous avez aussi la magie : touchez la flamme pour lancer un Trait de feu", "sort")
			hud.pulse(hud.btn_spells[SpellDB.ORDER[0]])

## Mort du joueur pendant un combat scénarisé : l'ennemi reprend des forces, c'est dur mais juste.
func on_player_died() -> void:
	if step == "colosse" and boss and not boss.cbt.dead:
		_after(3.5, func():
			if boss and not boss.cbt.dead:
				boss.cbt.hp = boss.cbt.max_hp
				boss.global_position = Vector3(26, Terrain.height_at(26, 116) + 0.2, 116))

# ------------------------------------------------------------------ tutoriel intégré
func _tuto_show(k: String) -> void:
	hud.set_shown(k, true)
	if not gs.flag("tuto_" + k):
		gs.set_flag("tuto_" + k)

func _reveal_all_buttons() -> void:
	for k in ["attaque", "esquive", "sorts", "potions"]:
		_tuto_show(k)

func _tutorial_tick() -> void:
	var st: Dictionary = player.combat.stats
	match hud.hint_key():
		"deplacer":
			if player.global_position.distance_to(_start_pos) > 4.0:
				gs.set_flag("tuto_deplacer")
				hud.hint("Glissez à droite de l'écran pour tourner la caméra, pincez pour zoomer", "camera", 5.0)
		"epee":
			if st["coups"] >= 3:
				gs.set_flag("tuto_epee")
				hud.hint("Maintenez l'épée : les coups s'enchaînent en combo (le 3e frappe plus fort)", "combo")
				hud.pulse(hud.btn_attack)
		"combo":
			if st["combo"] >= 1:
				gs.set_flag("tuto_combo")
				hud.clear_hint("combo")
				hud.pulse(null)
		"sort":
			if st["sorts"] >= 1:
				gs.set_flag("tuto_sort")
				hud.hint("Chaque sort coûte du mana (barre bleue) et a un temps de recharge", "sort2", 5.0)
				hud.pulse(null)
		"esquive":
			if st["esquives"] >= 1:
				gs.set_flag("tuto_esquive_ok")
				_end_slowmo()
				hud.hint("Bien joué ! Pendant la roulade, vous êtes intouchable", "esquive_ok", 4.0)
				hud.pulse(null)
		"potion":
			if st["potions"] >= 1:
				gs.set_flag("tuto_potion")
				hud.clear_hint("potion")
				hud.pulse(null)
	# potion : la première fois que la vie passe sous la moitié
	if not gs.flag("tuto_potion") and player.cbt.hp < player.cbt.max_hp * 0.5 and not player.cbt.dead and (step == "embuscade" or step == "colosse") and hud.hint_key() != "esquive":
		_tuto_show("potions")
		Progression.get_inst().potions_soin = maxi(Progression.get_inst().potions_soin, 1)
		hud.hint("Vous êtes blessé : touchez la fiole rouge pour boire une potion de soin", "potion")
		hud.pulse(hud.btn_potion_soin)

## Première attaque dangereuse qui vise le joueur : ralenti, le bouton d'esquive s'illumine.
func _on_special(m: Monster, tele: Telegraph) -> void:
	if _slowmo_done or gs.flag("tuto_esquive_ok") or Combat.player == null:
		return
	if not tele.contains(Combat.player.global_position):
		return
	_slowmo_done = true
	_tuto_show("esquive")
	Engine.time_scale = 0.25
	_slowmo_dodges = int(player.combat.stats["esquives"])
	_slowmo_real_end = Time.get_ticks_msec() / 1000.0 + 3.0
	hud.hint("Attaque puissante ! Touchez le bouton d'esquive pour rouler hors de la zone rouge", "esquive")
	hud.pulse(hud.btn_dodge)
	FX.bark(m, "!", 2.4 * float(m.def["scale"]), 1.0)

func _slowmo_tick() -> void:
	if Engine.time_scale < 1.0:
		if Time.get_ticks_msec() / 1000.0 > _slowmo_real_end or int(player.combat.stats["esquives"]) > _slowmo_dodges:
			_end_slowmo()

func _end_slowmo() -> void:
	Engine.time_scale = 1.0

# ------------------------------------------------------------------ mise en scène
func _portal_flash() -> void:
	var p := Vector3(Layout.PORTAL.x, Terrain.height_at(Layout.PORTAL.x, Layout.PORTAL.y) + 2.5, Layout.PORTAL.y)
	FX.explosion(p, 3.0)
	FX.shockwave(Vector3(PORTAL_START.x, Terrain.height_at(PORTAL_START.x, PORTAL_START.y), PORTAL_START.y), 4.0)
	player.shake(0.3)
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.75, 1.0)
	l.light_energy = 6.0
	l.omni_range = 18.0
	l.shadow_enabled = false
	world.add_child(l)
	l.global_position = p
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 2.5)
	tw.tween_callback(l.queue_free)

func _courtyard_guards(v: bool) -> void:
	for g in get_tree().get_nodes_in_group("garde_cour"):
		if v:
			if not g.is_in_group("pnj"):
				g.add_to_group("pnj")
		else:
			g.remove_from_group("pnj")
			g.visible = false
			g.process_mode = Node.PROCESS_MODE_DISABLED
