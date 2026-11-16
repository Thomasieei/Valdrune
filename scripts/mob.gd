class_name Mob
extends Unit
## Monstres (team 1), ombres (team 0), gardes neutres (team 2), boss.
## IA : garde -> poursuite -> encerclement -> sorts -> repli / appel à l'aide.

var kind := "goblin"
var home := Vector3.ZERO
var aggro_r := 11.0
var leash_r := 26.0
var target: Unit
var main
var atk_cd := 0.0
var atk_rate := 1.5
var skill_cd := 4.0
var skill2_cd := 8.0
var skill3_cd := 6.0
var is_shadow := false
var elite := false
var boss := false
var dormant := false
var corpse_time := 0.0
var arisen := false
var wander_t := 0.0
var wander_to := Vector3.ZERO
var pending: Array = []
var talk_cd := 0.0
var flee_t := 0.0
var fled_once := false
var phase := 1
var patrol: Array = []
var patrol_i := 0
var reward_gold := 8
var combo_i := 0
var room_id := -1
var order := "auto"          # ombres : auto / attack / follow / hold
var hold_pos := Vector3.ZERO
var selected := true
var fought := false
var recover_t := 0.0
var moving := false
# rôles d'ombre : tank / fire / heal / melee
var role := ""
var taunt_t := 0.0
var back_t := 0.0
var strafe_dir := 1.0
var strafe_t := 0.0
var squad: Dictionary = {}     # groupe de chasseurs partagé
var low_said := false
var chasers: Array = []       # civils : monstres qui les poursuivent
var stamina := 6.0
# rang des ombres (E..S) : tout en dépend (PV, dégâts, soins, provocation)
var grade := 0
var slv := 0                  # niveau d'amélioration de l'ombre (0..10)
var boost_t := 0.0
var cheer_t := 3.0
var cast_t := 0.0
var cast_total := 1.0
var cast_kind := ""
var cast_target = null
var cast_spot := Vector3.ZERO
var cast_bar: Node3D
var cast_fill: MeshInstance3D
var book: Node3D
const GRADES := ["E", "D", "C", "B", "A", "S"]
const GMUL := [0.5, 0.75, 1.0, 1.3, 1.7, 2.2]
const HEAL_PCT := [0.008, 0.014, 0.022, 0.032, 0.042, 0.055]
const TAUNT_P := [0.35, 0.55, 0.75, 0.9, 1.0, 1.0]
var sleeping_lod := false
var patrol_off := Vector3.ZERO
const HUNTER_HAND := Transform3D(Vector3(-0.38058, -0.04610, -118.25440), Vector3(-9.10295, -117.90413, 0.07526), Vector3(-117.90353, 9.10315, 0.37590), Vector3(40.22297, 8.74491, 1.63814))
const ROLE_NAME := {"tank": "Tank", "fire": "Mage de feu", "heal": "Soigneur", "melee": "Lame"}
const HUNTER_NAMES := ["Min-su", "Jae-won", "Hana", "Dong-hyuk", "Seo-yeon", "Tae-gyu", "Ji-ho", "Yu-na"]
const HL := {
	"engage": ["Contact ! Formation !", "Des monstres ! On les prend !", "Restez groupés, les gars !", "En position !"],
	"low": ["Allez les gars, on tient bon !", "Je fatigue... couvrez-moi !", "Tenez la ligne !"],
	"down": ["Non ! On a perdu un homme !", "Il est tombé ! Vengez-le !"],
	"win": ["Enfin, une bonne chose de faite.", "Pas mal, l'équipe.", "Rang E, mon œil... ils étaient coriaces."],
	"shadows": ["C'est... des ombres ? Qui es-tu ?", "Ces soldats noirs... ils sont avec toi ?", "J'ai jamais vu une compétence pareille."],
	"thanks": ["Merci pour le coup de main, chasseur !", "On te doit une fière chandelle.", "Joli coup ! Merci !"],
}
const IDLE_LINES := ["Tu sens ça ? Une odeur d'humain...", "Le chef veut plus de crânes.", "Ces humains et leurs tours... ridicule.", "J'ai faim. Encore.", "Chut ! Quelque chose bouge.", "La brèche s'ouvre bientôt. On sera libres.", "Encore une ronde... j'en ai marre."]

const LINES := {
	"aggro": ["Encore un chasseur. Ils finissent tous pareil.", "Tu sens la peur, humain. Et autre chose... de froid.", "Recule. Ce quartier est à nous depuis l'ouverture.", "On t'a vu venir. Le vent porte ton odeur.", "Ils t'ont envoyé seul ? Ton Association te méprise."],
	"hit": ["Tch... tu frappes juste.", "Pas mal. Pour un humain.", "Ça... ça brûle !", "Tu vas le payer !"],
	"death": ["Je reverrai... nos forêts...", "Ce n'est... qu'un début...", "La Brèche... se souviendra de toi..."],
	"flee": ["Il est trop fort ! À moi !", "Repli ! Prévenez le clan !"],
	"orc": ["Montre-moi ta force !", "Viens ! Que le plus fort vive !", "Ton épée est petite, humain."],
	"heal": ["Tiens bon, frère.", "Les esprits ne t'ont pas encore abandonné."],
	"kill": ["Un de moins.", "Repose-toi, chasseur. Tu as essayé."],
}

func configure(k: String, shadow := false) -> void:
	kind = k
	is_shadow = shadow
	team = 0 if shadow else 1
	match kind:
		"goblin":
			display_name = "Gobelin"
			max_hp = 90; dmg = 9; speed = 3.7; body_r = 0.42; arm = 0.7; atk_rate = 1.4
			setup_model("res://assets/goblin.glb", 1.25, Color(1, 0.12, 0.1), 0.16)
		"shaman":
			display_name = "Gobelin chaman"
			max_hp = 65; dmg = 12; speed = 3.3; body_r = 0.42; arm = 0.7; atk_rate = 2.6
			setup_model("res://assets/chaman.glb", 0.47, Color(1, 0.12, 0.1), 0.16)
			alias_anims({"Idle": "Animacion", "Walk": "Walk_Cycle", "Run": "Walk_Cycle", "Attack": "Attack", "Attack2": "Attack", "Cast": "Attack", "CastShoot": "Attack", "CastLoop": "Animacion", "Celebrate": "Animacion"})
		"orc":
			display_name = "Orc brute"
			rank = "E+"
			max_hp = 320; dmg = 20; speed = 2.9; body_r = 0.75; arm = 0.9; atk_rate = 2.1; reward_gold = 25
			setup_model("res://assets/orc.glb", 0.088 * (1.0 if shadow else 1.18), Color(1, 0.12, 0.1), 0.16)
			if not shadow:
				body_r = 0.88
				max_hp = 380
			_hide_orc_weapon()
		"guard":
			display_name = "Garde de l'Association"
			rank = "C"
			max_hp = 380; dmg = 22; speed = 3.4; body_r = 0.45; arm = 0.8; atk_rate = 1.3
			setup_model("res://assets/guard.glb", 1.0, Color(0.3, 0.6, 1.0), 0.12)
			team = 2
		"hunter":
			display_name = "Chasseur " + HUNTER_NAMES[randi() % HUNTER_NAMES.size()]
			rank = "D"
			max_hp = 300; dmg = 15; speed = 4.3; body_r = 0.42; arm = 0.8; atk_rate = 1.25
			setup_model("res://assets/hunter.glb", 1.0, Color(0.3, 0.8, 1.0), 0.12)
			_attach_hand_weapon("res://assets/katana.glb")
			team = 0
			aggro_r = 14.0
			leash_r = 45.0
		"orc_warrior":
			display_name = "Orc guerrier"
			rank = "D"
			max_hp = 520; dmg = 30; speed = 3.0; body_r = 0.8; arm = 1.25; atk_rate = 2.2; reward_gold = 40
			setup_model("res://assets/orc_warrior.glb", 1.05, Color(1, 0.12, 0.1), 0.16)
			for mi in model.find_children("*", "MeshInstance3D", true, false):
				var bb := (mi as MeshInstance3D).get_aabb()
				if bb.size.y < 0.03 * maxf(bb.size.x, bb.size.z):
					(mi as MeshInstance3D).visible = false
		"civil":
			var mdl: String = CityLife.CIV_MODELS[randi() % CityLife.CIV_MODELS.size()]
			display_name = "Passante" if mdl == "civ_woman" else "Passant"
			rank = "-"
			max_hp = 70; dmg = 0; speed = 1.4; body_r = 0.35; arm = 0.5; atk_rate = 99
			setup_model("res://assets/%s.glb" % mdl, 1.0, Color(1, 1, 1), 0.0)
			team = 3
		"police":
			display_name = "Agent de police"
			rank = "-"
			max_hp = 300; dmg = 0; speed = 1.7; body_r = 0.42; arm = 0.6; atk_rate = 99
			setup_model("res://assets/guard.glb", 1.0, Color(0.3, 0.5, 1.0), 0.0)
			team = 3
		"igris":
			display_name = "Commandant Écarlate"
			rank = "BOSS"
			boss = true
			max_hp = 2400; dmg = 34; speed = 4.6; body_r = 0.75; arm = 1.25; atk_rate = 1.5; reward_gold = 0
			setup_model("res://assets/igris.glb", 1.45, Color(1, 0.1, 0.1), 0.2)
			_attach_weapon("res://assets/sl_sword.glb", 1.3)
			var aura := FX.new_light(true)
			aura.light_color = Color(1, 0.12, 0.15)
			aura.light_energy = 1.6
			aura.omni_range = 6.0
			aura.position.y = 1.8
			add_child(aura)
	hp = max_hp
	if shadow:
		_make_shadow()
	var bar_h := 2.15
	if kind == "orc" or kind == "orc_warrior":
		bar_h = 2.75
	elif kind == "guard":
		bar_h = 2.25
	var bar_col := Color(0.95, 0.2, 0.2)
	if shadow:
		bar_col = Color(0.6, 0.35, 1.0)
	elif kind == "guard":
		bar_col = Color(0.35, 0.65, 1.0)
	elif kind == "hunter":
		bar_col = Color(0.3, 0.9, 0.6)
	if not boss and kind != "civil" and kind != "police":
		make_hp_bar(bar_h, bar_col)
	if kind == "civil" or kind == "police":
		ring.visible = false
	collision_layer = 2 if kind != "hunter" else 8
	collision_mask = (1 | 2 | 4 | 8) if kind != "hunter" else (1 | 2)
	if kind == "civil" or kind == "police":
		collision_layer = 16
		collision_mask = 1
	if kind == "orc":
		role = "tank"
	skill_cd = randf_range(2.0, 5.0)
	skill2_cd = randf_range(6.0, 10.0)
	play("Idle", 0.0)
	if ap:
		ap.seek(randf() * 1.5, true)

## Variantes de gobelins : mêmes os, tempérament différent.
func make_variant(v: String) -> void:
	match v:
		"eclaireur":
			display_name = "Gobelin éclaireur"
			model.scale *= 0.85
			speed *= 1.35
			max_hp *= 0.7
			dmg *= 0.9
			skill_cd = 1.5
			_tint(Color(0.8, 0.9, 1.0), Color(0.1, 0.3, 0.6))
		"berserker":
			display_name = "Gobelin berserker"
			rank = "E+"
			model.scale *= 1.15
			dmg *= 1.6
			max_hp *= 1.25
			atk_rate *= 0.85
			reward_gold = int(reward_gold * 2)
			_tint(Color(1.0, 0.6, 0.55), Color(0.6, 0.05, 0.0))
	hp = max_hp
	if hp_bar:
		for c in hp_bar.get_children():
			if c is Label3D:
				(c as Label3D).text = "%s [%s]" % [display_name, rank]

func make_elite() -> void:
	elite = true
	display_name = "Élite " + display_name.to_lower()
	rank = "D"
	model.scale *= 1.3
	max_hp *= 2.4
	hp = max_hp
	dmg *= 1.5
	reward_gold *= 4
	(ring.material_override as StandardMaterial3D).albedo_color = Color(1, 0.65, 0.1, 0.22)
	if hp_bar:
		hp_bar.queue_free()
	make_hp_bar(2.6 if kind != "orc" else 3.3, Color(1, 0.6, 0.1))
	var glow := FX.new_light()
	glow.light_color = Color(1, 0.5, 0.1)
	glow.light_energy = 0.9
	glow.omni_range = 3.5
	glow.position.y = 1.2
	add_child(glow)

func _attach_weapon(path: String, length_scale: float) -> void:
	var skel_list := model.find_children("*", "Skeleton3D", true, false)
	if skel_list.is_empty():
		return
	var sk := skel_list[0] as Skeleton3D
	var bi := sk.find_bone("hand_r")
	if bi < 0:
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_idx = bi
	var w := (load(path) as PackedScene).instantiate() as Node3D
	att.add_child(w)
	var gs := sk.global_transform.basis.get_scale().x
	w.scale = Vector3.ONE * length_scale / maxf(gs, 0.0001)
	w.rotation_degrees = Vector3(0, 90, 90)

## Arme dans la main droite d'un squelette Mixamo (chasseurs).
func _attach_hand_weapon(path: String) -> void:
	var skel_list := model.find_children("*", "Skeleton3D", true, false)
	if skel_list.is_empty():
		return
	var sk := skel_list[0] as Skeleton3D
	var bi := -1
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).ends_with("RightHand"):
			bi = i
			break
	if bi < 0:
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_idx = bi
	var w := (load(path) as PackedScene).instantiate() as Node3D
	att.add_child(w)
	w.transform = HUNTER_HAND

func _hide_orc_weapon() -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var aabb := m.get_aabb()
		if aabb.size.x > aabb.size.y * 1.6 or aabb.size.z > aabb.size.y * 1.6:
			m.visible = false

func _tint(albedo_mul: Color, glow: Color) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i) as StandardMaterial3D
			if src == null:
				continue
			var d := src.duplicate() as StandardMaterial3D
			d.albedo_color = d.albedo_color * albedo_mul
			d.emission_enabled = true
			d.emission = glow
			d.emission_energy_multiplier = 0.35
			m.set_surface_override_material(i, d)

func _make_shadow() -> void:
	display_name = "Ombre " + display_name.to_lower().replace("élite ", "")
	if boss:
		display_name = "Igris, l'ombre écarlate"
	rank = "Ombre"
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.06, 0.03, 0.12)
	sm.emission_enabled = true
	sm.emission = Color(0.35, 0.1, 0.85)
	sm.emission_energy_multiplier = 0.55
	sm.rim_enabled = true
	sm.rim = 1.0
	sm.rim_tint = 0.2
	sm.roughness = 0.4
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.visible:
			m.material_override = sm
	(ring.material_override as StandardMaterial3D).albedo_color = Color(0.55, 0.2, 1.0, 0.2)
	speed = maxf(speed, 6.5)
	var eye := FX.new_light()
	eye.light_color = Color(0.5, 0.2, 1)
	eye.light_energy = 1.2
	eye.omni_range = 2.5
	eye.position = Vector3(0, 1.6, 0.3)
	add_child(eye)

func later(t: float, c: Callable) -> void:
	pending.append([t, c])

## Réplique de chasseur : une seule voix par groupe, jamais deux fois la même d'affilée.
func hsay(cat: String, chance := 1.0) -> bool:
	if kind != "hunter" or dead or randf() > chance or main.speech_cd > 0.0:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if float(squad.get("cd", 0.0)) > now and cat != "win":
		return false
	if main.hero.global_position.distance_to(global_position) > 22.0:
		return false
	var arr: Array = (HL[cat] as Array).duplicate()
	arr.erase(squad.get("last", ""))
	var line: String = arr[randi() % arr.size()]
	squad["last"] = line
	squad["cd"] = now + 6.0
	main.speech_cd = 2.0
	FX.speech(self, line, Color(0.7, 0.95, 1.0), 2.6)
	print("HUNTER_SAY ", line)
	return true

## Bavardage des monstres au repos : rare, jamais la même phrase deux fois de suite.
func idle_chatter() -> void:
	if talk_cd > 0.0 or main.speech_cd > 0.0 or main.hero.global_position.distance_to(global_position) > 14.0:
		return
	talk_cd = randf_range(25.0, 45.0)
	if randf() > 0.35:
		return
	var arr: Array = IDLE_LINES.duplicate()
	arr.erase(main.last_idle_line)
	var line: String = arr[randi() % arr.size()]
	main.last_idle_line = line
	main.speech_cd = 3.0
	FX.speech(self, line, Color(1, 0.8, 0.7), 2.8)

func say(cat: String, chance := 1.0) -> void:
	if is_shadow or kind == "guard" or kind == "hunter" or talk_cd > 0.0 or randf() > chance:
		return
	var arr: Array = LINES.get(cat, [])
	if kind == "orc" and (cat == "aggro" or cat == "hit") and randf() < 0.6:
		arr = LINES["orc"]
	if arr.is_empty() or main.speech_cd > 0.0:
		return
	main.speech_cd = 2.2
	talk_cd = 5.0
	FX.speech(self, arr[randi() % arr.size()], Color(1, 0.8, 0.7), 2.4 if kind != "orc" else 3.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
	for i in range(pending.size() - 1, -1, -1):
		pending[i][0] -= delta
		if pending[i][0] <= 0.0:
			var c: Callable = pending[i][1]
			pending.remove_at(i)
			if not dead:
				c.call()
	if lifted:
		return
	if dead:
		corpse_time += delta
		if corpse_time < 1.5 or not is_on_floor():
			apply_gravity_and_slide(delta)
		return
	# niveau de détail : loin du héros, un monstre sans combat se met en veille (ni IA, ni physique, ni animation)
	if not is_shadow and not boss and target == null:
		var far := global_position.distance_squared_to(main.hero.global_position) > 2025.0
		if far != sleeping_lod:
			sleeping_lod = far
			if ap:
				if far:
					ap.pause()
				else:
					ap.play()
		if far:
			return
	if main.in_dialogue:
		var near: bool = global_position.distance_to(main.hero.global_position) < 6.0
		play("Talk" if (kind == "guard" or kind == "igris") and near else "Idle", 0.3)
		apply_gravity_and_slide(delta)
		return
	atk_cd -= delta
	skill_cd -= delta
	skill2_cd -= delta
	skill3_cd -= delta
	busy -= delta
	hit_stun -= delta
	talk_cd -= delta
	flee_t -= delta
	taunt_t -= delta
	invuln -= delta
	if not dormant:
		_think(delta)
	else:
		play("Idle", 0.3)
	apply_gravity_and_slide(delta)

func _enemies() -> Array:
	if team == 2:
		return []
	return main.units_of_team(1 - team)

func _allies() -> Array:
	return main.units_of_team(team)

func _nearest_enemy(r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for u in _enemies():
		var e := u as Unit
		if e.dead:
			continue
		var d := global_position.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best

func set_target(t: Unit) -> void:
	if target == null and t != null:
		if team == 1 and t == main.hero and (elite or kind == "orc" or kind == "shaman" or randf() < 0.3):
			main.try_parley(self)
		say("aggro", 0.2)
		if kind == "hunter":
			fought = true
			low_said = false
			hsay("engage", 0.8)
			for a in squad.get("members", []):
				var am := a as Mob
				if is_instance_valid(am) and am != self and not am.dead and am.target == null:
					am.target = t
					am.fought = true
	target = t

func _think(delta: float) -> void:
	if kind == "civil":
		_civ_think(delta)
		return
	if kind == "police":
		if busy <= 0.0:
			_patrol(delta)
		return
	if team == 2:
		_patrol(delta)
		return
	if is_shadow:
		_shadow_think(delta)
		return
	if busy > 0.0 or hit_stun > 0.0:
		return
	if not is_instance_valid(target):
		target = null
	if target and (target.dead or (not is_shadow and not boss and target.global_position.distance_to(home) > leash_r + 6.0)):
		if target.dead and target == main.hero:
			say("kill")
		target = null
	if target == null and kind == "hunter" and fought:
		fought = false
		_hunter_victory()
		return
	if target == null:
		set_target(_nearest_enemy(aggro_r if not is_shadow else 14.0))
	if target == null:
		_idle_behaviour(delta)
		return
	var d := global_position.distance_to(target.global_position)
	if not is_shadow and not boss and global_position.distance_to(home) > leash_r:
		target = null
		return
	# repli intelligent : un gobelin blessé fuit et appelle à l'aide
	if flee_t > 0.0:
		_move_towards(global_position + (global_position - target.global_position).normalized() * 3.0, speed * 1.1, delta)
		return
	if kind == "goblin" and not is_shadow and not fled_once and hp < max_hp * 0.25 and randf() < 0.5:
		fled_once = true
		flee_t = 2.2
		say("flee")
		for u in _allies():
			var a := u as Mob
			if a != null and not a.dead and a.target == null and a.global_position.distance_to(global_position) < 16.0:
				a.dormant = false
				a.set_target(target)
		return
	if kind == "hunter" and not low_said and hp < max_hp * 0.35:
		low_said = true
		hsay("low")
	face_to(target.global_position, false, delta)
	if back_t > 0.0:
		back_t -= delta
		_strafe(global_position - target.global_position, speed * 0.8, delta)
		return
	if _try_skills(d):
		return
	# positionnement : le chaman reste derrière son tank, l'orc s'interpose devant ses alliés
	if kind == "shaman" and not is_shadow:
		var tank := _ally_tank()
		if tank:
			var behind := tank.global_position + (tank.global_position - target.global_position).normalized() * 3.5
			behind.y = global_position.y
			if global_position.distance_to(behind) > 1.5 and gap_to(target) > 3.0:
				_move_towards(behind, speed, delta)
				return
	if kind == "orc" and not is_shadow and gap_to(target) > arm + 0.4:
		var cover := _cover_point()
		if cover != Vector3.INF:
			_move_towards(cover, speed * 1.1, delta)
			return
	var want_gap := arm * 0.8
	if kind == "shaman" and not is_shadow:
		want_gap = 6.5
	var gap := gap_to(target)
	if gap > want_gap + 0.25:
		_move_towards(_flank_point(), speed * (1.25 if gap > 4.0 else 1.0), delta)
	elif kind == "shaman" and not is_shadow and gap < 3.5:
		_move_towards(global_position + (global_position - target.global_position), speed, delta)
	else:
		if in_reach(target) and atk_cd <= 0.0:
			_basic_attack()
		elif atk_cd > 0.45 and not boss:
			# entre deux coups : tourne autour de la cible au lieu d'attendre bêtement
			strafe_t -= delta
			if strafe_t <= 0.0:
				strafe_t = randf_range(0.8, 1.8)
				strafe_dir = -strafe_dir if randf() < 0.6 else strafe_dir
			var rel := global_position - target.global_position
			rel.y = 0
			_strafe(Vector3(-rel.z, 0, rel.x) * strafe_dir, speed * 0.42, delta)
		else:
			play("Idle", 0.2)

func _ally_tank() -> Mob:
	for u in _allies():
		var a := u as Mob
		if a and a != self and not a.dead and a.kind == "orc" and a.global_position.distance_to(global_position) < 14.0:
			return a
	return null

## Point entre la cible et les alliés fragiles (chamans) : l'orc bloque le passage.
func _cover_point() -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for u in _allies():
		var a := u as Mob
		if a and not a.dead and a.kind == "shaman" and a.global_position.distance_to(global_position) < 14.0:
			acc += a.global_position
			n += 1
	if n == 0:
		return target.global_position
	var c := acc / n
	return target.global_position + (c - target.global_position).normalized() * (target.body_r + body_r + arm * 0.7)

## Déplacement en gardant la cible en face (pas latéraux, recul).
func _strafe(dir: Vector3, spd: float, delta: float) -> void:
	dir.y = 0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	if target:
		face_to(target.global_position, false, delta)
	play("Walk", 0.2, 0.9)

# ---------------------------------------------------------------- ombres : intelligence
func _shadow_think(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
	var h: Hero = main.hero
	if recover_t > 0.0:
		recover_t -= delta
		global_position = h.global_position - h.forward() * 2.0
		if recover_t <= 0.0:
			_reemerge()
		return
	boost_t -= delta
	if cast_t > 0.0:
		_cast_update(delta)
		return
	if busy > 0.0 or hit_stun > 0.0:
		return
	# blessée : elle rentre dans l'ombre du héros pour se régénérer
	if hp < max_hp * 0.2 and not boss:
		recover_t = 8.0
		visible = false
		collision_layer = 0
		FX.shadow_puff(main, global_position)
		main.system_msg("%s se replie dans ton ombre." % display_name)
		return
	if role == "heal" and _heal_skills():
		return
	var dom: float = h.domain_r()
	var mode: String = main.army_mode
	match order:
		"follow":
			target = null
			_follow(delta)
			return
		"hold":
			if target == null or target.dead or target.global_position.distance_to(hold_pos) > 9.0:
				target = _nearest_from(hold_pos, 9.0)
			if target == null:
				if global_position.distance_to(hold_pos) > 1.0:
					_move_towards(hold_pos, speed, delta)
				else:
					play("Idle", 0.3)
				return
		"attack":
			var f = main.focus_target
			if f != null and is_instance_valid(f) and not (f as Unit).dead:
				target = f as Unit
			elif target == null or target.dead:
				order = "auto"
		_:
			if mode == "stay":
				target = null
				_stay(delta)
				return
			var reach := dom + 3.0 if mode != "attack" else 32.0
			if target == null or target.dead or target.global_position.distance_to(h.global_position) > reach:
				target = _pick_target(reach) if mode == "attack" else _protect_target(dom)
	if target == null or target.dead:
		target = null
		if fought:
			fought = false
			_celebrate()
			return
		_follow(delta)
		return
	fought = true
	_role_combat(delta)

## Cible choisie selon le rôle quand le Monarque envoie l'armée.
func _pick_target(r: float) -> Unit:
	var h: Unit = main.hero
	var best: Unit = null
	var bs := -1e9
	for u in _enemies():
		var e := u as Unit
		if e.dead or e.global_position.distance_to(h.global_position) > r:
			continue
		var d := e.global_position.distance_to(global_position)
		var sc := -d
		var em := e as Mob
		match role:
			"tank":
				# le tank prend ce qui menace le héros et les soigneurs
				sc = -e.global_position.distance_to(h.global_position)
				if em and em.target == h:
					sc += 6.0
			"fire":
				sc = -d * 0.4 - e.hp / maxf(e.max_hp, 1.0) * 6.0
			"melee":
				if em and em.target is Mob and (em.target as Mob).role == "tank":
					sc += 5.0
		if em and em.kind == "shaman" and role != "tank":
			sc += 3.0
		if sc > bs:
			bs = sc
			best = e
	return best

## « Restez » : formation derrière le héros, ils encouragent de loin.
func _stay(delta: float) -> void:
	_follow(delta)
	cheer_t -= delta
	if cheer_t <= 0.0:
		cheer_t = randf_range(5.0, 10.0)
		var foe := _nearest_enemy(22.0)
		if foe and not moving and randf() < 0.55:
			busy = 1.6
			face_to(foe.global_position, true)
			play("Cheer" if ap and ap.has_animation("Cheer") else "Celebrate", 0.15, 1.0, true)
			if randf() < 0.25 and main.speech_cd <= 0.0:
				main.speech_cd = 4.0
				FX.speech(self, ["Montre-leur, Monarque !", "Gloire à notre Seigneur !", "Ils tremblent devant toi !", "...!"][randi() % 4], Color(0.75, 0.6, 1.0), 2.2, 1.8)

## Combat selon le rôle : chacun a sa place.
func _role_combat(delta: float) -> void:
	var h: Unit = main.hero
	var d := global_position.distance_to(target.global_position)
	var spd := speed * (1.7 if boost_t > 0.0 else 1.15)
	var to_h := h.global_position - target.global_position
	to_h.y = 0
	to_h = to_h.normalized() if to_h.length() > 0.1 else -target.forward()
	var right := Vector3(to_h.z, 0, -to_h.x)
	var idx: int = main.shadow_list().find(self)
	match role:
		"fire":
			if _fire_skills(d):
				return
			# ligne arrière, côté héros, écartés les uns des autres
			var slot := target.global_position + to_h * 8.5 + right * (2.2 if idx % 2 == 0 else -2.2)
			if global_position.distance_to(slot) > 1.4:
				_move_towards(slot, spd, delta)
			else:
				face_to(target.global_position, false, delta)
				play("Idle", 0.2)
			return
		"heal":
			# reste en retrait derrière le héros, hors de portée des monstres
			var back := h.global_position + to_h * 3.5 + right * 1.5
			var near_foe := _nearest_enemy(5.0)
			if near_foe:
				var away := global_position - near_foe.global_position
				away.y = 0
				_move_towards(global_position + away.normalized() * 3.0, spd, delta)
			elif global_position.distance_to(back) > 1.5:
				_move_towards(back, spd, delta)
			else:
				face_to(target.global_position, false, delta)
				play("Idle", 0.2)
			return
		"tank":
			if _tank_skills():
				return
			# se place face à l'ennemi, côté héros : le corps entre le monstre et le Monarque
			var guard_pt := target.global_position + to_h * (target.body_r + body_r + arm * 0.6)
			if gap_to(target) > arm * 0.8 + 0.25 or global_position.distance_to(guard_pt) > 1.6:
				_move_towards(guard_pt, spd, delta)
				return
			face_to(target.global_position, false, delta)
			if atk_cd <= 0.0 and in_reach(target):
				_basic_attack()
			else:
				play("Block" if ap and ap.has_animation("Block") else "Idle", 0.2)
			return
	if boss and _try_skills(d):
		return
	if back_t > 0.0:
		back_t -= delta
		_strafe(global_position - target.global_position, speed * 0.8, delta)
		return
	# lames : contournent et frappent dans le dos, puis se dégagent (pas de mêlée brouillonne)
	var goal := target.global_position
	if target is Mob and (target as Mob).target != self:
		var side := 1.0 if idx % 2 == 0 else -1.0
		goal = target.global_position - target.forward() * (target.body_r + body_r + 0.4) + target.forward().cross(Vector3.UP) * side * 0.7
	if gap_to(target) > arm * 0.8 + 0.25:
		_move_towards(goal, spd, delta)
	else:
		face_to(target.global_position, false, delta)
		play("Idle", 0.2)
		if in_reach(target) and atk_cd <= 0.0:
			_basic_attack()
			if randf() < 0.3:
				later(0.6, _set_back.bind(0.45))

# ---------------------------------------------------------------- pouvoirs des rôles
func _tank_skills() -> bool:
	var threat := 0
	for u in _enemies():
		var e := u as Mob
		if e != null and not e.dead and e.target != self and e.global_position.distance_to(global_position) < 9.0:
			threat += 1
	if skill_cd <= 0.0 and threat > 0:
		skill_cd = 11.0 - grade
		busy = 1.1
		play("Roar" if ap and ap.has_animation("Roar") else "Cheer", 0.08, 1.0, true)
		later(0.35, _taunt)
		return true
	if skill2_cd <= 0.0 and global_position.distance_to(target.global_position) < 4.0:
		skill2_cd = 9.0
		busy = 1.5
		play("Slam" if ap and ap.has_animation("Slam") else "Attack", 0.08, 1.4, true)
		later(0.6, _tank_slam)
		return true
	return false

func _taunt() -> void:
	taunt_t = 5.0
	FX.taunt_aura(self, 9.0, 5.0)
	FX.speech(self, ["À MOI !", "C'EST MOI QU'IL FAUT FRAPPER !", "VENEZ !"][randi() % 3] if is_shadow else "VENEZ À MOI, VERMINES !", Color(1, 0.35, 0.3), 2.8 if kind == "orc" else 2.4, 1.8)
	main.sfx("slam", global_position, -4.0)
	main.shake(0.12)
	var n := 0
	var chance: float = TAUNT_P[grade] if is_shadow else 0.8
	for u in _enemies():
		var e := u as Mob
		if e != null and not e.dead and not e.boss and e.global_position.distance_to(global_position) < 9.0:
			if randf() > chance:
				FX.damage_number(main, e.global_position + Vector3(0, 0.6, 0), "IGNORE", Color(0.8, 0.8, 0.8), false)
				continue
			e.target = self
			e.dormant = false
			n += 1
			FX.burst(main, e.global_position + Vector3(0, 2.2, 0), Color(1, 0.15, 0.1), 8, 0.06, 1.0, 0.4, 0.0)
	print("TAUNT %s -> %d" % [display_name, n])

func _tank_slam() -> void:
	var p := global_position
	FX.burst(main, p + Vector3(0, 0.4, 0), Color(1, 0.12, 0.08), 60, 0.2, 7.0, 0.6, 4.0)
	for k in 3:
		FX.slash_arc(main, p, model.rotation.y + k * 2.09, Color(1, 0.15, 0.1), 3.3, k % 2 == 0)
	var rg := FX.ground_disc(1.0, Color(1, 0.2, 0.1), 0.8, true)
	main.add_child(rg)
	rg.global_position = p + Vector3(0, 0.08, 0)
	var tw := rg.create_tween()
	tw.tween_property(rg, "scale", Vector3(3.6, 1, 3.6), 0.3)
	tw.tween_callback(rg.queue_free)
	_slam(p, 3.4, 1.7)

func _fire_skills(d: float) -> bool:
	if skill2_cd <= 0.0 and d < 14.0:
		var spots: Array = []
		for u in _enemies():
			var e := u as Unit
			if not e.dead and e.global_position.distance_to(target.global_position) < 7.0 and spots.size() < 5:
				spots.append(e.global_position)
		if spots.size() >= 2 or (target is Mob and (target as Mob).elite):
			while spots.size() < 4:
				spots.append(target.global_position + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5)))
			skill2_cd = 12.0
			busy = 1.4
			play("Cast", 0.08, 0.6, true)
			FX.speech(self, "Pluie de feu !", Color(1, 0.6, 0.3), 2.4, 1.6)
			FX.burst(main, global_position + Vector3(0, 2.4, 0), Color(1, 0.5, 0.1), 30, 0.1, 3.0, 0.8, -2.0)
			FX.fire_rain(main, spots, _fire_splash.bind(1.1, 2.2))
			print("FIRE_RAIN ", spots.size())
			return true
	if skill_cd <= 0.0 and d < 14.0:
		skill_cd = 3.4 - grade * 0.3
		busy = 0.9
		play("CastShoot" if ap and ap.has_animation("CastShoot") else "Cast", 0.08, 0.8, true)
		var from := global_position + Vector3(0, 1.4, 0) + forward() * 0.6
		FX.fireball(main, from, target.global_position + Vector3(0, 0.9, 0), _fire_splash.bind(1.5, 1.8), 0.4)
		main.sfx("orb", global_position, -4.0)
		return true
	return false

func _fire_splash(p: Vector3, mult: float, r: float) -> void:
	main.sfx("slam", p, -6.0)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() < r + e.body_r and absf(e.global_position.y - p.y) < 2.5:
			e.take_damage(dmg * mult * randf_range(0.9, 1.1), self)

## Soigneur : ne soigne que les ombres et le Monarque, seulement s'ils en ont vraiment besoin.
## Incantation avec barre, bras levé et grimoire ; puissance selon le rang de l'ombre.
func _heal_skills() -> bool:
	if busy > 0.0 or cast_t > 0.0:
		return false
	var worst: Unit = null
	var wr := 1.0
	var hurt := 0
	for u in main.units_of_team(0):
		var a := u as Unit
		if a.dead or (a is Mob and not (a as Mob).is_shadow) or a.global_position.distance_to(global_position) > 15.0:
			continue
		var r := a.hp / a.max_hp
		if r < 0.7:
			hurt += 1
		if r < wr:
			wr = r
			worst = a
	if worst == null:
		return false
	var heal_cd_mul := 1.0 - grade * 0.08
	if skill2_cd <= 0.0 and ((hurt >= 2 and wr < 0.7) or wr < 0.5):
		skill2_cd = 13.0 * heal_cd_mul
		_start_cast("zone", worst, 1.7 - grade * 0.15)
		return true
	if skill3_cd <= 0.0 and wr < 0.55:
		skill3_cd = 6.0 * heal_cd_mul
		_start_cast("single", worst, 1.2 - grade * 0.1)
		return true
	return false

func _start_cast(kind_c: String, who: Unit, t: float) -> void:
	cast_kind = kind_c
	cast_target = who
	cast_spot = who.global_position
	cast_t = t
	cast_total = t
	face_to(who.global_position, true)
	play("CastLoop" if ap and ap.has_animation("CastLoop") else "Cast", 0.12, 1.0, true)
	_show_cast_bar(true)
	if book:
		book.visible = true
	if kind_c == "zone":
		FX.telegraph(main, cast_spot, 3.0, t, Color(0.3, 1.0, 0.45))

func _cast_update(delta: float) -> void:
	cast_t -= delta
	if cast_fill:
		(cast_fill.material_override as ShaderMaterial).set_shader_parameter("fill", 1.0 - cast_t / cast_total)
	if cast_t > 0.0:
		return
	_show_cast_bar(false)
	busy = 0.5
	play("CastShoot" if ap and ap.has_animation("CastShoot") else "Cast", 0.06, 1.0, true)
	var w = cast_target
	if cast_kind == "zone":
		_heal_zone(cast_spot)
	elif is_instance_valid(w) and not (w as Unit).dead:
		_heal_single(w as Unit)

func _show_cast_bar(on: bool) -> void:
	if cast_bar == null:
		cast_bar = Node3D.new()
		cast_bar.position.y = 2.45
		add_child(cast_bar)
		var bg := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.9, 0.09)
		bg.mesh = q
		var bm := FX.mat(Color(0, 0, 0), 0.0, 0.75)
		bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bg.material_override = bm
		cast_bar.add_child(bg)
		cast_fill = MeshInstance3D.new()
		var q2 := QuadMesh.new()
		q2.size = Vector2(0.86, 0.06)
		cast_fill.mesh = q2
		var sh := ShaderMaterial.new()
		sh.shader = BAR_SHADER
		sh.set_shader_parameter("col", Color(0.35, 1.0, 0.5))
		sh.set_shader_parameter("fill", 0.0)
		sh.render_priority = 2
		cast_fill.material_override = sh
		cast_bar.add_child(cast_fill)
		var lb := Label3D.new()
		lb.text = "Soin"
		lb.font_size = 28
		lb.pixel_size = 0.0008
		lb.fixed_size = true
		lb.outline_size = 6
		lb.modulate = Color(0.6, 1.0, 0.7)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position.y = 0.13
		cast_bar.add_child(lb)
	cast_bar.visible = on
	if book:
		book.visible = on or role == "heal"

func _heal_single(a: Unit) -> void:
	var amt: float = a.max_hp * HEAL_PCT[grade] * 11.0
	FX.trail(main, global_position + Vector3(0, 0.4, 0), a.global_position + Vector3(0, 0.2, 0), Color(0.4, 1.0, 0.5))
	FX.heal_zone(main, a.global_position, 1.0, 0.6)
	FX.burst(main, a.global_position + Vector3(0, 1.0, 0), Color(0.45, 1.0, 0.55), 26, 0.08, 1.8, 0.8, -2.0)
	a.hp = minf(a.max_hp, a.hp + amt)
	a.update_hp_bar()
	FX.damage_number(main, a.global_position, "+%d" % int(amt), Color(0.4, 1.0, 0.5))
	main.sfx("levelup", a.global_position, -14.0)

func _heal_zone(spot: Vector3) -> void:
	FX.heal_zone(main, spot, 3.0, 5.0)
	main.sfx("levelup", spot, -10.0)
	print("HEAL_ZONE rang=%s" % GRADES[grade])
	for k in 10:
		later(0.5 * k + 0.3, _heal_tick.bind(spot))

func _heal_tick(spot: Vector3) -> void:
	for u in main.units_of_team(0):
		var a := u as Unit
		if a.dead or (a is Mob and not (a as Mob).is_shadow):
			continue
		if a.global_position.distance_to(spot) < 3.2 and a.hp < a.max_hp:
			var v: float = a.max_hp * HEAL_PCT[grade]
			a.hp = minf(a.max_hp, a.hp + v)
			a.update_hp_bar()
			FX.damage_number(main, a.global_position, "+%d" % maxi(int(v), 1), Color(0.4, 1.0, 0.5))

## Réduction de dégâts (tanks), parade (lames, chasseurs).
func take_damage(amount: float, from: Unit, crit := false) -> void:
	if dead:
		return
	if kind == "civil" and hp_bar == null:
		make_hp_bar(2.05, Color(0.95, 0.95, 0.95))
	if role == "tank":
		amount *= 0.45 if taunt_t > 0.0 else (0.6 if is_shadow else 0.75)
	if (role == "melee" or kind == "hunter" or (role == "tank" and not is_shadow)) and busy <= 0.0 and invuln <= 0.0 and from != null and randf() < (0.3 if role != "tank" else 0.22):
		var to_from := from.global_position - global_position
		to_from.y = 0
		if forward().dot(to_from.normalized()) > 0.3:
			busy = 0.45
			play("Block", 0.05, 1.4, true)
			FX.damage_number(world, global_position, "PARÉ", Color(0.75, 0.85, 1.0), false)
			FX.burst(world, global_position + Vector3(0, 1.3, 0) + forward() * 0.5, Color(1, 0.9, 0.6), 14, 0.05, 3.5, 0.25, 0.0)
			main.sfx("clang", global_position, -6.0)
			amount *= 0.2
			back_t = 0.3
	if kind == "hunter" and from == main.hero:
		return
	super.take_damage(amount, from, crit)

## Une attaque arrive : les lames et chasseurs peuvent esquiver sur le côté.
func incoming(from: Unit, t: float) -> void:
	if dead or busy > 0.0 or not (role == "melee" or kind == "hunter") or randf() > 0.4:
		return
	later(maxf(t - 0.22, 0.05), _sidestep.bind(from))

func _sidestep(fv) -> void:
	if not is_instance_valid(fv):
		return
	var from: Unit = fv as Unit
	var rel := global_position - from.global_position
	rel.y = 0
	var side := Vector3(-rel.z, 0, rel.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
	invuln = 0.4
	busy = 0.35
	var to := global_position + side * 1.8 + rel.normalized() * 0.4
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(to.x, global_position.y, to.z), 0.22).set_ease(Tween.EASE_OUT)
	play("Roll" if ap and ap.has_animation("Roll") else "Run", 0.05, 1.8, true)
	if is_shadow:
		FX.shadow_puff(main, global_position)
	else:
		FX.burst(main, global_position + Vector3(0, 0.3, 0), Color(0.8, 0.8, 0.8), 8, 0.08, 1.5, 0.3, 0.0)

## Priorité : les ennemis qui attaquent le héros, puis le plus proche dans le domaine.
func _protect_target(dom: float) -> Unit:
	var h: Unit = main.hero
	var best: Unit = null
	var bd := 1e9
	for u in _enemies():
		var e := u as Unit
		if e.dead or e.global_position.distance_to(h.global_position) > dom:
			continue
		var d := e.global_position.distance_to(global_position)
		if e is Mob and (e as Mob).target == h:
			d -= 8.0
		if d < bd:
			bd = d
			best = e
	return best

func _nearest_from(p: Vector3, r: float) -> Unit:
	var best: Unit = null
	var bd := r
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(p) < bd:
			bd = e.global_position.distance_to(p)
			best = e
	return best

## Formation derrière le héros, sans jamais le gêner ; voyage par l'ombre si trop loin.
func _follow(delta: float) -> void:
	var h: Hero = main.hero
	var shadows: Array = main.shadow_list()
	var idx := maxi(shadows.find(self), 0)
	var fwd := h.forward()
	var right := Vector3(fwd.z, 0, -fwd.x)
	# formation en V sur les côtés (jamais entre la caméra et le héros)
	var side := -1.0 if idx % 2 == 0 else 1.0
	var rank_i := idx / 2
	var slot := h.global_position - fwd * (0.8 + rank_i * 1.3) + right * side * (2.3 + rank_i * 1.1)
	if role == "tank":
		slot = h.global_position + fwd * 2.6 + right * side * (0.9 + rank_i * 1.2)
	elif role == "fire" or role == "heal":
		slot = h.global_position - fwd * (2.6 + rank_i * 0.8) + right * side * 1.4
	var dist := Vector2(slot.x - global_position.x, slot.z - global_position.z).length()
	if dist > 18.0:
		FX.shadow_puff(main, global_position)
		global_position = slot + Vector3(0, 0.3, 0)
		FX.shadow_puff(main, global_position)
		moving = false
		return
	if moving and dist < 0.6:
		moving = false
	elif not moving and dist > 1.8:
		moving = true
	if moving:
		var spd := clampf(dist * 2.4, 3.0, h.sprint_speed() + 1.5)
		var d := slot - global_position
		d.y = 0
		d = d.normalized()
		velocity.x = d.x * spd
		velocity.z = d.z * spd
		face_to(global_position + d, false, delta)
		play("Run" if spd > 4.0 else "Walk", 0.25, clampf(spd / 6.0, 0.8, 1.6))
	else:
		face_to(global_position + fwd * 5.0, false, delta)
		play("Idle", 0.3)

func _celebrate() -> void:
	if randf() > 0.65:
		return
	busy = 2.4
	play("Celebrate", 0.15, 1.0, true)
	FX.burst(main, global_position + Vector3(0, 1.8, 0), Color(0.55, 0.25, 1.0), 16, 0.07, 2.0, 0.6, -1.0)
	if randf() < 0.35:
		FX.speech(self, ["Pour le Monarque !", "Victoire !", "...!", "Gloire à notre Seigneur !"][randi() % 4], Color(0.75, 0.6, 1.0), 2.4 if not boss else 3.4)

func _reemerge() -> void:
	var h: Unit = main.hero
	hp = max_hp
	update_hp_bar()
	visible = true
	collision_layer = 8
	global_position = h.global_position - h.forward() * 2.2 + Vector3(0, 0.3, 0)
	FX.shadow_puff(main, global_position)
	busy = 1.2
	cur_anim = "Death"
	if ap and ap.has_animation("Death"):
		ap.play_backwards("Death", 0.0)
		ap.speed_scale = 2.0

## Encerclement : chaque monstre prend une place différente autour de la cible.
func _flank_point() -> Vector3:
	if is_shadow or boss:
		return target.global_position
	var mates: Array = []
	for u in _allies():
		var a := u as Mob
		if a != null and not a.dead and a.target == target and a.kind != "shaman":
			mates.append(a)
	if mates.size() <= 1:
		return target.global_position
	var k := mates.find(self)
	var base := atan2(global_position.x - target.global_position.x, global_position.z - target.global_position.z)
	var spread := (k - (mates.size() - 1) * 0.5) * 0.9
	var r := target.body_r + body_r + arm * 0.7
	return target.global_position + Vector3(sin(base + spread), 0, cos(base + spread)) * r

func _patrol(delta: float) -> void:
	if patrol.is_empty():
		play("Idle", 0.3)
		return
	var p: Vector3 = patrol[patrol_i % patrol.size()] + patrol_off
	if global_position.distance_to(p) < 0.8:
		wander_t -= delta
		play("Idle", 0.3)
		if wander_t <= 0.0:
			wander_t = randf_range(1.5, 3.5)
			patrol_i += 1
	else:
		_move_towards(p, 2.7 if kind == "hunter" else 1.8, delta)

func _idle_behaviour(delta: float) -> void:
	if not is_shadow and not patrol.is_empty():
		home = global_position
		if kind == "hunter":
			_hunter_notice()
		else:
			idle_chatter()
		_patrol(delta)
		return
	if not is_shadow and kind != "hunter":
		idle_chatter()
	if is_shadow and main.hero:
		var h: Unit = main.hero
		var slot := h.global_position + Vector3(sin(get_instance_id() % 7), 0, cos(get_instance_id() % 7)) * (2.6 if not boss else 3.4)
		if global_position.distance_to(slot) > 1.2:
			if global_position.distance_to(slot) > 30.0:
				global_position = slot
			_move_towards(slot, maxf(speed, global_position.distance_to(slot) * 1.3), delta)
		else:
			play("Idle", 0.25)
			face_to(h.global_position + h.forward() * 5.0, false, delta)
		return
	if global_position.distance_to(home) > 2.0:
		_move_towards(home, speed * 0.7, delta)
		return
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(3.0, 7.0)
		wander_to = home + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
	if global_position.distance_to(wander_to) > 0.6:
		_move_towards(wander_to, speed * 0.35, delta)
	else:
		play("Idle", 0.3)

func _move_towards(p: Vector3, spd: float, delta: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.05:
		return
	d = d.normalized()
	velocity.x = d.x * spd
	velocity.z = d.z * spd
	face_to(global_position + d, false, delta)
	play("Run" if spd > speed * 0.9 else "Walk", 0.2, clampf(spd / 3.5, 0.7, 1.4))

func _basic_attack() -> void:
	atk_cd = atk_rate
	var a := "Attack"
	if kind == "goblin" and randf() < 0.35:
		a = "Attack2"
	if kind == "shaman" and not is_shadow:
		a = "Attack2"
	if kind == "guard" and randf() < 0.5:
		a = "Attack2"
	if kind == "igris":
		combo_i = (combo_i + 1) % 3
		a = ["Attack", "Attack2", "Slash3"][combo_i]
	var spd := 1.0
	if kind == "igris" and a == "Slash3":
		spd = 1.6
	var l := anim_len(a) / spd
	busy = l * 0.95
	play(a, 0.08, spd, true)
	# préavis : éclat rouge sur l'arme avant l'impact (laisse le temps d'esquiver)
	if team == 1:
		FX.burst(main, global_position + Vector3(0, 1.5 if not boss else 2.4, 0) + forward() * 0.6, Color(1, 0.25, 0.15), 8, 0.06, 1.0, 0.25, 0.0)
	if target is Mob:
		(target as Mob).incoming(self, l * 0.45)
	if not is_shadow and not boss and kind != "orc" and randf() < 0.55:
		later(l * 0.95, _set_back.bind(randf_range(0.35, 0.6)))
	later(l * (0.45 if a != "Slash3" else 0.4), _basic_hit.bind(target))

func _set_back(t: float) -> void:
	back_t = t

func _basic_hit(tv) -> void:
	var t: Unit = tv as Unit if is_instance_valid(tv) else null
	if t != null and not t.dead and in_reach(t, 0.35):
		t.take_damage(dmg * randf_range(0.85, 1.15), self)
		main.sfx("hit3", global_position, -6.0)
	main.sfx("swing%d" % (1 + randi() % 2), global_position, -10.0)
	var col := Color(1, 0.35, 0.2) if team == 1 else (Color(0.5, 0.85, 1.0) if kind == "hunter" else Color(0.6, 0.3, 1.0))
	if boss and team == 1:
		col = Color(1, 0.1, 0.15)
	FX.slash_arc(main, global_position, model.rotation.y, col, body_r + arm, randf() < 0.5)

## Sorts spécifiques. Renvoie true si un sort part.
func _try_skills(d: float) -> bool:
	match kind:
		"goblin":
			if skill_cd <= 0.0 and d > 3.5 and d < 10.0:
				skill_cd = 7.5
				var spot := target.global_position
				FX.telegraph(main, spot, 1.7, 0.75)
				busy = 1.35
				face_to(spot, true)
				play("Leap", 0.08, 1.0, true)
				later(0.45, _leap_to.bind(spot))
				return true
		"shaman":
			if skill3_cd <= 0.0:
				for u in _allies():
					var a := u as Unit
					if a != self and not a.dead and a.hp < a.max_hp * 0.55 and a.global_position.distance_to(global_position) < 11.0:
						skill3_cd = 8.0
						busy = 0.7
						face_to(a.global_position, true)
						play("Cast", 0.08, 0.8, true)
						say("heal", 0.8)
						later(0.35, _heal.bind(a))
						return true
			if skill_cd <= 0.0 and d < 13.0:
				skill_cd = 3.4
				busy = 0.7
				play("Cast", 0.08, 1.0, true)
				later(0.3, _fire_orb.bind(target))
				return true
			if skill2_cd <= 0.0 and d < 12.0:
				skill2_cd = 9.0
				busy = 0.9
				play("Cast", 0.08, 0.8, true)
				var spot := target.global_position
				FX.telegraph(main, spot, 2.2, 1.1, Color(1.0, 0.85, 0.1))
				later(1.1, _poison_pool.bind(spot))
				return true
		"orc_warrior":
			# fendoir circulaire : zone rouge devant lui puis grand coup tournant
			if skill_cd <= 0.0 and d < 4.0:
				skill_cd = 7.0
				busy = 1.6
				var spot := global_position + forward() * 1.6
				FX.telegraph(main, spot, 3.0, 0.9)
				play("Slam", 0.08, 1.0, true)
				later(0.9, _slam.bind(spot, 3.0, 1.6))
				return true
			if skill2_cd <= 0.0 and d > 5.0 and d < 12.0:
				skill2_cd = 10.0
				var spot2 := target.global_position
				FX.telegraph(main, spot2, 2.2, 0.8)
				busy = 1.3
				face_to(spot2, true)
				play("Run", 0.05, 1.8, true)
				later(0.5, _leap_to.bind(spot2))
				return true
		"orc":
			if not is_shadow and skill3_cd <= 0.0 and d < 8.0:
				var foes := 0
				for u in _enemies():
					if u is Mob and not (u as Unit).dead and (u as Unit).global_position.distance_to(global_position) < 8.0:
						foes += 1
				if foes >= 1:
					skill3_cd = 14.0
					busy = 0.9
					play("Roar", 0.1, 1.0, true)
					later(0.3, _taunt)
					return true
			if skill_cd <= 0.0 and d < 4.5:
				skill_cd = 8.0
				busy = 1.9
				play("Slam", 0.1, 1.6, true)
				var spot := global_position + forward() * 1.8
				FX.telegraph(main, spot, 2.6, 1.0)
				later(1.0, _slam.bind(spot, 2.6, 1.8))
				return true
			if skill2_cd <= 0.0 and hp < max_hp * 0.5:
				skill2_cd = 16.0
				busy = 0.8
				play("Roar", 0.1, 0.7, true)
				speed *= 1.35
				atk_rate *= 0.7
				FX.burst(main, global_position + Vector3(0, 1.5, 0), Color(1, 0.2, 0.1), 40, 0.2, 5.0, 0.7, 0.0)
				FX.speech(self, "RAAAAH ! TU VAS PAYER !", Color(1, 0.4, 0.3), 3.0)
				return true
		"igris":
			return _boss_skills(d)
	return false

# ---------------------------------------------------------------- boss
func _boss_skills(d: float) -> bool:
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		busy = 1.6
		play("Taunt", 0.1, 1.2, true)
		FX.speech(self, "Tu... fais saigner un chevalier ? IMPOSSIBLE ! Je vais te montrer la colère de mon Roi !", Color(1, 0.35, 0.3), 3.6, 4.0)
		speed *= 1.3
		atk_rate *= 0.75
		dmg *= 1.15
		var red := FX.new_light(true)
		red.light_color = Color(1, 0.05, 0.05)
		red.light_energy = 3.5
		red.omni_range = 9.0
		red.position.y = 1.5
		add_child(red)
		FX.burst(main, global_position + Vector3(0, 1.6, 0), Color(1, 0.1, 0.1), 70, 0.25, 6.0, 0.9, 0.0)
		main.shake(0.4)
		main.boss_phase2(self)
		return true
	# Charge écarlate : ligne rouge puis ruée
	if skill_cd <= 0.0 and d > 4.0 and d < 18.0:
		skill_cd = 9.0 if phase == 1 else 6.5
		var from := global_position
		var dir := target.global_position - from
		dir.y = 0
		var to := from + dir.normalized() * minf(dir.length() + 3.0, 18.0)
		FX.telegraph_line(main, from, to, 2.4, 0.9)
		face_to(to, true)
		busy = 1.6
		play("Taunt", 0.05, 2.0, true)
		later(0.9, _charge.bind(from, to))
		return true
	# Tourbillon écarlate : zone circulaire autour de lui
	if skill2_cd <= 0.0 and d < 6.0:
		skill2_cd = 12.0 if phase == 1 else 8.0
		FX.telegraph(main, global_position, 4.6, 1.2)
		busy = 2.0
		play("Block", 0.05, 1.0, true)
		later(1.2, _whirl)
		return true
	return false

func _charge(from: Vector3, to: Vector3) -> void:
	play("Dash", 0.03, 2.2, true)
	main.sfx("dash", from)
	main.sfx("clang_heavy", to)
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(to.x, global_position.y, to.z), 0.32)
	FX.trail(main, from, to, Color(1, 0.1, 0.15))
	var dir := to - from
	dir.y = 0
	var L := dir.length()
	dir = dir.normalized()
	for u in _enemies():
		var e := u as Unit
		if e.dead:
			continue
		var rel := e.global_position - from
		rel.y = 0
		var along := rel.dot(dir)
		var side := absf(rel.cross(dir).y)
		if along > -0.5 and along < L + 0.5 and side < 1.2 + e.body_r:
			e.take_damage(dmg * 2.0, self)
	main.shake(0.3)

func _whirl() -> void:
	play("Heavy", 0.05, 2.6, true)
	FX.burst(main, global_position + Vector3(0, 1.0, 0), Color(1, 0.15, 0.15), 60, 0.2, 7.0, 0.6, 2.0)
	for k in 3:
		FX.slash_arc(main, global_position, model.rotation.y + k * 2.1, Color(1, 0.1, 0.15), 4.2, k % 2 == 0)
	_slam(global_position, 4.6, 1.6)

# ---------------------------------------------------------------- sorts des monstres
func _heal(av) -> void:
	if not is_instance_valid(av) or (av as Unit).dead:
		return
	var a: Unit = av as Unit
	FX.trail(main, global_position, a.global_position, Color(0.4, 1.0, 0.4))
	FX.burst(main, a.global_position + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.4), 25, 0.1, 2.0, 0.6, -1.5)
	a.hp = minf(a.max_hp, a.hp + a.max_hp * 0.3)
	a.update_hp_bar()
	FX.damage_number(main, a.global_position, "+%d" % int(a.max_hp * 0.3), Color(0.4, 1.0, 0.4))

func _leap_to(spot: Vector3) -> void:
	var start := global_position
	var dir := spot - start
	dir.y = 0
	var land := spot - dir.normalized() * (body_r + 0.6)
	var tw := create_tween()
	tw.tween_method(_leap_step.bind(start, land), 0.0, 1.0, 0.4)
	tw.tween_callback(_leap_land.bind(spot))

func _leap_step(f: float, start: Vector3, land: Vector3) -> void:
	var p := start.lerp(land, f)
	p.y = start.y + sin(f * PI) * 2.0
	global_position = p

func _leap_land(spot: Vector3) -> void:
	if dead:
		return
	FX.burst(main, spot, Color(1, 0.4, 0.2), 30, 0.12, 4.0, 0.5, 6.0)
	main.sfx("land", spot)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(spot) < 1.7 + e.body_r:
			e.take_damage(dmg * 1.6, self)
	main.shake(0.15)

func _fire_orb(tv) -> void:
	if not is_instance_valid(tv) or (tv as Unit).dead:
		return
	var t: Unit = tv as Unit
	var o := FX.orb(main, global_position + Vector3(0, 1.3, 0) + forward() * 0.5, Color(1, 0.45, 0.1))
	main.sfx("orb", global_position, -6.0)
	var tw := o.create_tween()
	var dest := t.global_position + Vector3(0, 1.0, 0)
	var tt := clampf(o.global_position.distance_to(dest) / 14.0, 0.2, 1.0)
	tw.tween_property(o, "global_position", dest, tt)
	tw.tween_callback(_orb_hit.bind(o, t, dest))

func _orb_hit(o: Node3D, t, dest: Vector3) -> void:
	FX.burst(main, o.global_position, Color(1, 0.5, 0.1), 20, 0.1, 3.0, 0.4, 3.0)
	if is_instance_valid(t) and not t.dead and t.global_position.distance_to(dest - Vector3(0, 1, 0)) < 1.6 + t.body_r:
		t.take_damage(dmg, self)
	o.queue_free()

func _poison_pool(spot: Vector3) -> void:
	main.sfx("poison", spot, -2.0)
	var pool := FX.ground_disc(2.2, Color(0.95, 0.8, 0.1), 0.45, false)
	main.add_child(pool)
	pool.global_position = spot + Vector3(0, 0.06, 0)
	for k in 6:
		later(0.5 * k, _poison_tick.bind(spot))
	var tw := pool.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(pool, "scale", Vector3(0.01, 1, 0.01), 0.3)
	tw.tween_callback(pool.queue_free)

func _poison_tick(spot: Vector3) -> void:
	FX.burst(main, spot, Color(0.95, 0.85, 0.15), 6, 0.08, 1.0, 0.6, -1.0)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(spot) < 2.2:
			e.take_damage(dmg * 0.3, self)

func _slam(spot: Vector3, radius: float, mult: float) -> void:
	main.sfx("slam", spot, 2.0)
	FX.burst(main, spot, Color(1, 0.55, 0.25), 45, 0.18, 5.0, 0.6, 9.0)
	main.shake(0.35)
	for u in _enemies():
		var e := u as Unit
		if not e.dead and e.global_position.distance_to(spot) < radius + e.body_r:
			e.take_damage(dmg * mult, self)

func on_hit(from: Unit) -> void:
	dormant = false
	if from and (target == null or (target is Mob and (target as Mob).kind == "civil" and from == main.hero and randf() < 0.5)):
		set_target(from)
	say("hit", 0.08)
	if boss:
		return
	super.on_hit(from)

func die() -> void:
	if kind == "hunter":
		for a in squad.get("members", []):
			if is_instance_valid(a) and a != self and not (a as Mob).dead:
				main.speech_cd = 0.0
				squad["cd"] = 0.0
				(a as Mob).hsay("down")
				break
	elif not is_shadow and kind != "guard":
		if boss:
			FX.speech(self, "Mon... Roi... ? Ce n'était... pas vous... ?", Color(1, 0.5, 0.45), 3.6, 5.0)
		else:
			say("death", 0.5)
	super.die()

## Relève par l'Arise : le cadavre se relève en ombre.
func rise_as_shadow(forced_role := "", level := 0) -> void:
	slv = level
	arisen = true
	dead = false
	is_shadow = true
	dormant = false
	team = 0
	_make_shadow()
	max_hp = max_hp * (0.8 if not boss else 0.35) * (1.0 + 0.12 * float(main.shadow_lvl))
	dmg = dmg * (1.0 + 0.12 * float(main.shadow_lvl))
	hp = max_hp
	if hp_bar:
		hp_bar.queue_free()
		hp_bar = null
	make_hp_bar(2.15 if kind != "orc" else 2.75, Color(0.6, 0.35, 1.0))
	for c in hp_bar.get_children():
		if c is Label3D:
			c.visible = false
	if boss:
		hp_bar.position.y = 3.3
		dmg *= 0.8
	set_role(forced_role if forced_role != "" else _auto_role())
	ring.visible = true
	collision_layer = 8
	collision_mask = 1 | 2
	target = null
	order = "auto"
	busy = 1.6
	if ap and ap.has_animation("Death"):
		cur_anim = "Death"
		ap.play_backwards("Death", 0.0)
		ap.speed_scale = 1.6
	stand_up()
	later(1.6, play.bind("Idle", 0.2, 1.0, true))

## Grimoire de soin tenu dans la main gauche (couverture sombre, pages, runes vertes).
func _attach_book() -> void:
	var skl := model.find_children("*", "Skeleton3D", true, false)
	if skl.is_empty():
		return
	var sk := skl[0] as Skeleton3D
	var bi := -1
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		if n.ends_with("L Hand") or n.ends_with("LeftHand") or n == "hand_l":
			bi = i
			break
	if bi < 0:
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_idx = bi
	book = Node3D.new()
	att.add_child(book)
	var gs := sk.global_transform.basis.get_scale().x
	book.scale = Vector3.ONE / maxf(gs, 0.0001)
	var cover := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.05, 0.32)
	cover.mesh = bm
	cover.material_override = FX.mat(Color(0.12, 0.05, 0.2), 0.4, 1.0, false)
	book.add_child(cover)
	var pages := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.21, 0.055, 0.29)
	pages.mesh = pm
	pages.material_override = FX.mat(Color(0.9, 0.95, 0.8), 0.3, 1.0, false)
	pages.position.x = 0.01
	book.add_child(pages)
	var rune := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(0.16, 0.16)
	rune.mesh = rq
	var rm := FX.mat(Color(0.4, 1.0, 0.55), 3.0, 0.9)
	rm.albedo_texture = FX.soft_disc_tex(true)
	rune.material_override = rm
	rune.rotation_degrees.x = -90
	rune.position.y = 0.032
	book.add_child(rune)
	book.position = Vector3(0, 0.1, 0.08)

## Départ de charge : traînée d'ombre au sol et petit nuage noir.
func charge_fx() -> void:
	if dead:
		return
	FX.shadow_puff(main, global_position)
	play("Run", 0.05, 1.5, true)

## Réponse du monstre après la réplique du héros, avec un effet réel sur le combat.
func parley_reply(txt: String, which: String) -> void:
	if dead:
		return
	FX.speech(self, txt, Color(1, 0.8, 0.65), 2.8 if kind != "orc" else 3.3, 3.6)
	if which == "a":
		dmg *= 1.25
		speed *= 1.1
		reward_gold *= 2
		FX.damage_number(main, global_position + Vector3(0, 0.8, 0), "ENRAGÉ", Color(1, 0.4, 0.25), true)
		play("Roar" if ap and ap.has_animation("Roar") else "Celebrate", 0.1, 1.0, true)
		busy = 0.9
	else:
		dmg *= 0.85
		FX.damage_number(main, global_position + Vector3(0, 0.8, 0), "ÉBRANLÉ", Color(0.6, 0.8, 1.0), true)

# ---------------------------------------------------------------- civils
func _civ_think(delta: float) -> void:
	if busy > 0.0 or hit_stun > 0.0:
		return
	var h: Unit = main.hero
	if not chasers.is_empty():
		# poursuivi : court vers le chasseur, s'épuise, puis se recroqueville près de lui
		stamina -= delta
		var spd := 4.7 if stamina > 0.0 else 3.0
		var to_h := h.global_position - global_position
		to_h.y = 0
		if to_h.length() > 2.6:
			_move_towards(h.global_position, spd, delta)
		else:
			velocity.x = 0
			velocity.z = 0
			play("Cower", 0.15)
		return
	var foe: Unit = null
	for u in main.units_of_team(1):
		var e := u as Mob
		if e and not e.dead and not e.dormant and e.global_position.distance_to(global_position) < 9.0:
			foe = e
			break
	if foe:
		var away := global_position - foe.global_position
		away.y = 0
		_move_towards(global_position + away.normalized() * 4.0, 4.2, delta)
		if main.speech_cd <= 0.0 and randf() < 0.01:
			main.speech_cd = 3.0
			FX.speech(self, ["Un monstre !!", "Fuyez !", "Au secours !"][randi() % 3], Color(1, 0.9, 0.8), 2.2, 2.0)
		return
	if h.global_position.distance_to(global_position) < 4.5:
		main.life.civ_comment(self)
	# promenade tranquille, parfois au téléphone ou en train de discuter
	wander_t -= delta
	if wander_t <= 0.0:
		wander_t = randf_range(4.0, 9.0)
		if randf() < 0.3:
			busy = randf_range(3.0, 6.0)
			velocity = Vector3.ZERO
			play("Phone" if randf() < 0.5 else "Talk", 0.3)
			return
		wander_to = home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
	if global_position.distance_to(wander_to) > 0.8:
		_move_towards(wander_to, 1.15, delta)
	else:
		play("Idle", 0.3)

## Amélioration d'une ombre : +12 % PV et dégâts, et un rang de plus aux niveaux 5 et 10.
func level_up() -> void:
	slv += 1
	var old_g := grade
	var base_g: int = {"goblin": 0, "shaman": 0, "orc": 1, "orc_warrior": 1, "igris": 3}.get(kind, 0)
	grade = clampi(base_g + (1 if elite else 0) + int(main.shadow_lvl) / 3 + slv / 5, 0, 5)
	var mul: float = 1.12 * float(GMUL[grade]) / float(GMUL[old_g])
	max_hp *= mul
	dmg *= mul
	hp = max_hp
	update_hp_bar()
	if not boss:
		display_name = "Ombre %s (%s) [%s]" % [str({"orc": "orc", "goblin": "gobelin", "shaman": "chaman", "orc_warrior": "orc guerrier"}.get(kind, kind)), str(ROLE_NAME.get(role, role)), GRADES[grade]]
	if grade != old_g:
		FX.damage_number(main, global_position + Vector3(0, 0.8, 0), "RANG %s !" % GRADES[grade], Color(1, 0.85, 0.4), true)

func _auto_role() -> String:
	match kind:
		"orc":
			return "tank"
		"shaman":
			var nh := 0
			var nf := 0
			for m in main.shadow_list():
				if (m as Mob).role == "heal":
					nh += 1
				elif (m as Mob).role == "fire":
					nf += 1
			return "heal" if nh <= nf else "fire"
	return "melee"

func set_role(r: String) -> void:
	role = r
	match r:
		"tank":
			max_hp *= 1.7
			dmg *= 0.8
		"fire":
			max_hp *= 0.8
			dmg *= 1.35
		"heal":
			dmg *= 0.55
		"melee":
			atk_rate *= 0.8
	var base_g: int = {"goblin": 0, "shaman": 0, "orc": 1, "orc_warrior": 1, "igris": 3}.get(kind, 0)
	grade = clampi(base_g + (1 if elite else 0) + int(main.shadow_lvl) / 3 + slv / 5, 0, 5)
	max_hp *= GMUL[grade] * pow(1.12, slv)
	dmg *= GMUL[grade] * pow(1.12, slv)
	hp = max_hp
	update_hp_bar()
	if not boss:
		display_name = "Ombre %s (%s) [%s]" % [str({"orc": "orc", "goblin": "gobelin", "shaman": "chaman"}.get(kind, kind)), str(ROLE_NAME.get(r, r)), GRADES[grade]]
	else:
		display_name = "Igris, l'ombre écarlate [%s]" % GRADES[grade]
	if r == "heal":
		_attach_book()
	var c: Color = {"tank": Color(1, 0.25, 0.2), "fire": Color(1, 0.55, 0.1), "heal": Color(0.35, 1.0, 0.5), "melee": Color(0.6, 0.35, 1.0)}.get(r, Color(0.6, 0.35, 1.0))
	(ring.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.28)

# ---------------------------------------------------------------- chasseurs : fin de combat, gestes
func _hunter_victory() -> void:
	for u in _enemies():
		if not (u as Unit).dead and (u as Unit).global_position.distance_to(global_position) < 14.0:
			return
	if not squad.has("members"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if float(squad.get("win_t", 0.0)) > now:
		return
	squad["win_t"] = now + 10.0
	var alive: Array = []
	for a in squad["members"]:
		if is_instance_valid(a) and not (a as Mob).dead:
			alive.append(a)
	main.speech_cd = 0.0
	hsay("win")
	if main.hero.global_position.distance_to(global_position) < 12.0 and alive.size() >= 2:
		(alive[1] as Mob).later(2.6, (alive[1] as Mob)._thank_hero)
	# deux chasseurs se tapent dans la main, les autres célèbrent
	if alive.size() >= 2:
		var a := alive[0] as Mob
		var b := alive[1] as Mob
		a.later(0.8, a._high_five.bind(b))
		b.later(0.8, b._high_five.bind(a))
		for k in range(2, alive.size()):
			(alive[k] as Mob).later(0.6, (alive[k] as Mob)._cheer)
	else:
		later(0.5, _cheer)

func _thank_hero() -> void:
	if dead or main.hero.global_position.distance_to(global_position) > 14.0:
		return
	main.speech_cd = 0.0
	squad["cd"] = 0.0
	if hsay("thanks"):
		main.rep += 2
		face_to(main.hero.global_position, true)

func _high_five(ov) -> void:
	if not is_instance_valid(ov) or dead:
		return
	var other: Mob = ov as Mob
	var mid := (global_position + other.global_position) * 0.5
	var dir := global_position - mid
	dir.y = 0
	if dir.length() < 0.1:
		dir = Vector3(1, 0, 0)
	var spot := mid + dir.normalized() * 0.5
	var tw := create_tween()
	tw.tween_property(self, "global_position", Vector3(spot.x, global_position.y, spot.z), 0.5)
	busy = 2.8
	face_to(other.global_position, true)
	play("Walk", 0.15)
	later(0.5, _hf_anim.bind(other))

func _hf_anim(ov) -> void:
	if not is_instance_valid(ov):
		return
	var other: Mob = ov as Mob
	face_to(other.global_position, true)
	play("HighFive", 0.12, 1.0, true)
	if get_instance_id() < other.get_instance_id():
		later(0.55, _clap.bind(other))

func _clap(ov) -> void:
	if not is_instance_valid(ov):
		return
	var other: Mob = ov as Mob
	var p := (global_position + other.global_position) * 0.5 + Vector3(0, 1.95, 0)
	FX.burst(main, p, Color(1, 0.95, 0.7), 12, 0.05, 2.5, 0.3, 0.0)
	main.sfx("hit1", p, -4.0)
	print("HIGH_FIVE")

func _cheer() -> void:
	busy = 2.0
	play("Celebrate", 0.15, 1.0, true)

## Les chasseurs remarquent les ombres du héros (une fois par groupe).
func _hunter_notice() -> void:
	if squad.get("seen", false) or main.shadow_count() == 0:
		return
	if main.hero.global_position.distance_to(global_position) < 9.0:
		squad["seen"] = true
		face_to(main.hero.global_position, true)
		hsay("shadows")
