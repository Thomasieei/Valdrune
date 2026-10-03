extends CharacterBody3D
class_name Bot
# « Faux joueur » : se promène, récolte, chasse les monstres, vend à l'hôtel des ventes, discute…
# Dans les zones T3+, certains sont hostiles : ils attaquent le héros et le dépouillent s'ils gagnent.

const NAMES := ["Kévin13", "xX_Draven_Xx", "LunaFox", "Nathou83", "MamieKiller", "Zeykor", "Ombre_Lame", "Lilou_Chan", "Bastos", "DarkSasuke77",
	"Tiboo", "Mystik", "Kaïros", "Saphira", "Le_Boucher", "Gaby_42", "Rekt_U", "Pandaroux", "Sylvanor", "Jojo_du_Var"]
const GUILDS := ["", "", "[ROI] ", "[Ombre] ", "[FR] ", "[Loups] ", "[Lame] "]
const CHAT := ["qq1 pour un donjon ?", "wtb épée T4 pas cher", "gg", "lag de fou là", "ce boss est cheaté mdr", "vends bois en masse, mp",
	"j'ai drop un coffre violet !!", "attention pvp dans le marais", "ça farm bien ici", "lol", "tour étage 10 qui vient ?", "quelqu'un a vu le boss de groupe ?",
	"les loups me spawnkill", "slt", "brb", "mon stuff est enfin +3", "t5 c'est hors de prix", "ez", "on est combien sur le serveur ?"]
const MODELS := ["Knight", "Barbarian", "Rogue", "Ranger", "Mage"]

var main: Node
var nm := ""
var tier := 1
var region := 1
var hostile := false
var hp := 100.0
var max_hp := 100.0
var dead := false
var radius := 0.45
var state := "idle"          # (interface ennemi) "idle" / "chase" quand il combat le héros
var mode := "walk"           # walk / gather / hunt / pvp / dead
var elite := false
var kind := "joueur"
var camp := {}
var is_boss := false
var group_boss := false
var duel_info := {}
var animal := false
var def := {}
var ch: Dictionary
var ap: AnimationPlayer
var cur := ""
var goal := Vector3.ZERO
var node_t: Dictionary = {}
var prey: Node3D
var act_t := 0.0
var atk_cd := 0.0
var think := 0.0
var chat_t := 0.0
var bubble: Label3D
var name_lbl: Label3D
var flash_mat: StandardMaterial3D
var stolen: Array = []
var respawn_t := 0.0
var tele: MeshInstance3D
var tele_pos := Vector3.ZERO
var wind := 0.0
var hits := 0
var bar_mat: ShaderMaterial
var bar: MeshInstance3D
var tag_lbl: Label3D
var ring: MeshInstance3D
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var dash_dmg := false
var dash_hit := false
var dodge_cd := 0.0
var skill_cd := 4.0
var potted := false
var strafe := 1.0
var strafe_t := 0.0
var charge_w := 0.0
var line_tele: MeshInstance3D

static var ring_mats := {}
static func _ring_mat(col: Color) -> StandardMaterial3D:
	var k := col.to_html()
	if ring_mats.has(k): return ring_mats[k]
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col; m.render_priority = 1; ring_mats[k] = m; return m

func setup(m: Node, n: String, t: int, reg: int, host: bool) -> void:
	main = m; nm = n; tier = t; region = reg; hostile = host
	def = {"name": nm}
	max_hp = Game.armor_hp(t) * 2.6; hp = max_hp   # un vrai joueur encaisse : les combats JcJ durent un peu plus
	collision_layer = 0; collision_mask = 0
	var model: String = MODELS[randi() % MODELS.size()]
	ch = Chars.make("res://assets/heroes/%s.glb" % model); add_child(ch.root); ap = ch.ap
	var wk: String = ["epee", "hache", "baton"][randi() % 3] if model != "Mage" else "baton"
	Chars.attach(ch, "handslot.r", Game.weapon_model(wk, t))
	if wk != "baton" and randf() < 0.6: Chars.attach(ch, "handslot.l", Game.shield_model(t))
	var tint: Color = Color(1, 1, 1).lerp(Game.TIER_COL[t], 0.0 if t <= 1 else 0.26)
	flash_mat = StandardMaterial3D.new(); flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; flash_mat.albedo_color = Color(1, 1, 1, 0.0); flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in Chars.meshes(ch.root):
		mi.material_overlay = flash_mat
		if tint != Color(1, 1, 1):
			for k in mi.mesh.get_surface_count():
				var src = mi.mesh.surface_get_material(k)
				if src is StandardMaterial3D:
					var mt: StandardMaterial3D = src.duplicate(); mt.albedo_color = tint; mi.set_surface_override_material(k, mt)
	var guild: String = GUILDS[randi() % GUILDS.size()]
	# Un JOUEUR se reconnaît d'un coup d'œil : nom blanc cerclé de couleur, mention « Joueur », anneau au sol
	# (bleu = pacifique, rouge = JcJ). Les monstres, eux, ont un nom de la couleur du tier et pas d'anneau.
	name_lbl = Label3D.new(); name_lbl.text = "%s%s" % [guild, nm]; name_lbl.font_size = 38; name_lbl.outline_size = 14
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; name_lbl.pixel_size = 0.0065; name_lbl.position.y = 2.62; name_lbl.no_depth_test = true; add_child(name_lbl)
	tag_lbl = Label3D.new(); tag_lbl.font_size = 26; tag_lbl.outline_size = 8; tag_lbl.outline_modulate = Color(0, 0, 0, 0.85)
	tag_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; tag_lbl.pixel_size = 0.0065; tag_lbl.position.y = 2.4; tag_lbl.no_depth_test = true; add_child(tag_lbl)
	ring = MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.6; tm.outer_radius = 0.82; tm.rings = 24; tm.ring_segments = 4; ring.mesh = tm
	ring.scale = Vector3(1, 0.06, 1); ring.position.y = 0.06; ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(ring)
	_style()
	bar = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1.0, 0.1); bar.mesh = q
	bar_mat = ShaderMaterial.new(); bar_mat.shader = Enemy._bar_shader(); bar_mat.set_shader_parameter("col", Color("#4fa8ff") if not hostile else Color("#e8452f")); bar_mat.render_priority = 4
	bar.material_override = bar_mat; bar.position.y = 2.22; bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(bar)
	bubble = Label3D.new(); bubble.font_size = 30; bubble.outline_size = 8; bubble.modulate = Color("#fff6d8"); bubble.outline_modulate = Color(0.1, 0.1, 0.15, 0.95)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED; bubble.pixel_size = 0.0065; bubble.position.y = 2.8; bubble.no_depth_test = true; bubble.visible = false; add_child(bubble)
	chat_t = randf_range(10.0, 60.0)
	floor_snap_length = 0.6
	_style()
	_new_goal()

# couleurs selon l'état : pacifique (bleu), hostile (rouge clair), en combat contre toi (rouge vif)
func _style() -> void:
	var fighting := mode == "pvp"
	var col := Color("#3f9cff") if not hostile and not fighting else (Color("#ff4a3a") if fighting else Color("#ff8a5a"))
	name_lbl.modulate = Color(1, 1, 1); name_lbl.outline_modulate = Color(col.r * 0.55, col.g * 0.55, col.b * 0.55, 0.95)
	tag_lbl.text = ("JOUEUR · T%d" % tier) if not hostile and not fighting else (("JcJ · T%d · t'attaque !" % tier) if fighting else ("JOUEUR JcJ · T%d" % tier))
	tag_lbl.modulate = col.lightened(0.35)
	ring.material_override = _ring_mat(Color(col.r, col.g, col.b, 0.85 if fighting else 0.55))
	if bar: bar.visible = fighting or hp < max_hp

func gear_drop() -> Dictionary: return Game.random_item(tier)

func _play(n: String, sp := 1.0, restart := false) -> void:
	if n == cur and not restart: ap.speed_scale = sp; return
	cur = n; ap.play(n, 0.15); ap.speed_scale = sp
	if restart: ap.seek(0.0, true)

func say(t: String) -> void:
	bubble.text = "« %s »" % t; bubble.visible = true
	get_tree().create_timer(4.5).timeout.connect(func(): if is_instance_valid(bubble): bubble.visible = false)

func _new_goal() -> void:
	var R: Dictionary = World.REGIONS[region]
	for k in 30:
		var p := Vector3(clamp(R.c.x + randf_range(-60, 60), -100.0, 100.0), 0, clamp(R.c.y + randf_range(-60, 60), -100.0, 100.0))
		if main.world.region_at(p.x, p.z) == region and main.world.walkable(p.x, p.z): goal = p; return
	goal = Vector3(R.c.x, 0, R.c.y)

func dmg() -> float: return Game.weapon_dmg(tier) * 0.9
# armure d'un joueur équipé du tier (plastron + casque + bottes)
func armor_red() -> float: var a := 15.0 * tier; return a / (a + 120.0)

# ——— dégâts reçus (monstres ou héros) ———
func take_hit(amount: float, from: Node3D, _push: float) -> void:
	if dead: return
	if from is Player:
		# JcJ : l'armure du joueur IA et la règle « dégâts JcJ réduits » rendent les combats plus longs
		var st: Dictionary = Game.stats()
		if randf() < st.crit: amount *= 1.6
		amount *= 0.55 * (1.0 - armor_red())
		if st.steal > 0.0: from.hp = min(from.max_hp, from.hp + amount * st.steal)
	hp -= amount
	flash_mat.albedo_color.a = 0.8; create_tween().tween_property(flash_mat, "albedo_color:a", 0.0, 0.2)
	Fx.number(main, global_position + Vector3(0, 2.2, 0), str(int(amount)), Color.WHITE)
	if from == main.player and mode != "pvp": _start_pvp()
	if hp <= 0.0: _die(from)
func hurt(amount: float, from: Node3D) -> void: take_hit(amount, from, 0.0)

func _start_pvp() -> void:
	mode = "pvp"; state = "chase"; potted = false; skill_cd = randf_range(2.0, 4.0)
	if not self in main.enemies: main.enemies.append(self)
	bar_mat.set_shader_parameter("col", Color("#e8452f")); _style()
	main.pvp_target = self

func _end_pvp() -> void:
	main.enemies.erase(self); state = "idle"; mode = "walk"; _cancel_tele(); dash_t = 0.0
	bar_mat.set_shader_parameter("col", Color("#4fa8ff") if not hostile else Color("#e8452f")); _style()
	if main.pvp_target == self: main.pvp_target = null

func _die(killer: Node3D) -> void:
	dead = true; mode = "dead"; state = "dead"; _cancel_tele()
	_play("Death_A", 1.0, true); bubble.visible = false
	main.enemies.erase(self)
	main.on_bot_death(self, killer)
	if main.pvp_target == self: main.pvp_target = null
	respawn_t = 80.0
	var tw := create_tween(); tw.tween_interval(2.5); tw.tween_property(ch.root, "position:y", -1.6, 1.0); tw.tween_callback(func(): visible = false)

func _respawn() -> void:
	dead = false; hp = max_hp; mode = "walk"; state = "idle"; visible = true; ch.root.position.y = 0.0; _style()
	_new_goal(); var p := goal
	global_position = p + Vector3(0, main.world.height(p.x, p.z) + 0.5, 0); _new_goal()

func _cancel_tele() -> void:
	if tele and is_instance_valid(tele): tele.queue_free()
	if line_tele and is_instance_valid(line_tele): line_tele.queue_free()
	tele = null; wind = 0.0; line_tele = null; charge_w = 0.0

func _physics_process(dt: float) -> void:
	if dead:
		respawn_t -= dt
		if respawn_t <= 0.0: _respawn()
		return
	var P: Player = main.player
	var dp: float = global_position.distance_to(P.global_position)
	if main.in_instance() or dp > 90.0:
		# loin du héros : simulation légère, invisible, animation coupée
		visible = false; ap.active = false
		if mode == "pvp": _end_pvp()
		var to := goal - global_position; to.y = 0
		if to.length() < 2.0: _new_goal()
		else: global_position += to.normalized() * 3.0 * dt
		global_position.y = main.world.ground_y(global_position.x, global_position.z) + 0.1 if global_position.x < 300 else global_position.y
		return
	visible = true; ap.active = true
	think -= dt; atk_cd -= dt; chat_t -= dt; dodge_cd -= dt; skill_cd -= dt
	if chat_t <= 0.0:
		chat_t = randf_range(35.0, 90.0)
		if dp < 40.0: say(CHAT[randi() % CHAT.size()])
	if hp < max_hp and mode != "pvp" and mode != "hunt": hp = min(max_hp, hp + max_hp * 0.03 * dt)
	bar_mat.set_shader_parameter("fill", hp / max_hp); bar_mat.set_shader_parameter("trail", hp / max_hp)
	if Engine.get_physics_frames() % 20 == 0: bar.visible = mode == "pvp" or hp < max_hp * 0.98
	var want := Vector3.ZERO
	var face := Vector3.ZERO
	# agression JcJ : seulement sur les cartes T2 et plus, jamais en ville
	if hostile and mode != "pvp" and not P.dead and dp < 15.0 and think <= 0.0:
		if main.world.map_id >= 2 and not main.world.in_town(P.global_position) and main.pvp_target == null and randf() < 0.35:
			_start_pvp(); say(["ton stuff est à moi", "dommage pour toi", "gg ez", "file tout"][randi() % 4])
			main.hud.pvp_alert(self)
	if think <= 0.0 and mode != "pvp": think = 1.0; _choose()
	match mode:
		"pvp":
			if P.dead or dp > 34.0: _end_pvp()
			else: want = _pvp(P, dt)
			face = P.global_position - global_position; face.y = 0
		"hunt":
			if prey == null or not is_instance_valid(prey) or prey.dead: mode = "walk"; prey = null
			else:
				var to: Vector3 = prey.global_position - global_position; to.y = 0; face = to
				if to.length() > 2.0 + prey.radius: want = to.normalized() * 5.2
				elif atk_cd <= 0.0:
					atk_cd = 0.95; _play("Throw", 2.0, true)
					var e = prey
					get_tree().create_timer(0.15).timeout.connect(func(): if is_instance_valid(e) and not e.dead and not dead: e.take_hit(dmg() * randf_range(0.85, 1.1), self, 1.5))
		"gather":
			if node_t.is_empty() or node_t.charges <= 0: mode = "walk"; node_t = {}
			else:
				var to: Vector3 = node_t.pos - global_position; to.y = 0; face = to
				if to.length() > 1.9: want = to.normalized() * 4.2
				else:
					act_t -= dt
					if act_t <= 0.0:
						act_t = 2.4; _play("Throw" if node_t.type != "fiber" else "PickUp", 1.4, true)
						main.world.harvest(node_t); hits += 1
						if hits >= 3: hits = 0; mode = "walk"; node_t = {}
		_:
			var to: Vector3 = goal - global_position; to.y = 0
			if to.length() < 1.5: _new_goal()
			else: want = to.normalized() * 3.6
			face = want
	velocity.x = want.x; velocity.z = want.z
	var nx := global_position + Vector3(velocity.x, 0, velocity.z) * 0.15
	if not main.world.walkable(nx.x, nx.z):
		velocity.x = 0.0; velocity.z = 0.0
		if mode == "walk": _new_goal()
	global_position.x += velocity.x * dt; global_position.z += velocity.z * dt
	global_position.y = main.world.ground_y(global_position.x, global_position.z)
	if face.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(face.x, face.z), 1.0 - exp(-dt * 10.0))
	if cur in ["Throw", "PickUp", "Hit_A"] and ap.is_playing() and ap.current_animation_position < ap.current_animation_length * 0.85: return
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp > 0.6: _play("Running_A" if sp > 4.0 else "Walking_A", clamp(sp / 4.5, 0.7, 1.3))
	else: _play("Idle_A")

func _choose() -> void:
	if mode in ["hunt", "gather"]: return
	var roll := randf()
	if roll < 0.45:
		# chasser un monstre proche de son niveau
		var best: Node3D = null; var bd := 22.0
		for e in main.enemies:
			if e is Bot or e.dead or e.group_boss or e.duel_info.size() > 0 or e.tier > tier: continue
			var d: float = e.global_position.distance_to(global_position)
			if d < bd: bd = d; best = e
		if best: prey = best; mode = "hunt"; return
	if roll < 0.8:
		var bn := {}; var bd2 := 35.0
		for nd in main.world.nodes:
			if nd.charges <= 0 or nd.tier > tier: continue
			var d2: float = nd.pos.distance_to(global_position)
			if d2 < bd2: bd2 = d2; bn = nd
		if not bn.is_empty(): node_t = bn; mode = "gather"; act_t = 0.5; hits = 0

# ——— Combat JcJ lisible : approche, tourne autour, esquive, charge annoncée, potion ———
func _pvp(P: Player, dt: float) -> Vector3:
	var to: Vector3 = P.global_position - global_position; to.y = 0
	var d := to.length(); var u := to.normalized()
	if dash_t > 0.0:
		dash_t -= dt
		if dash_dmg and not dash_hit and d < 1.4:
			dash_hit = true; P.hurt(Game.mob_dmg(tier) * 1.9 * randf_range(0.9, 1.1), self); main.shake(0.2)
			Fx.burst(main, P.global_position + Vector3(0, 1.0, 0), Color(1, 0.5, 0.3), 16, 5.0, 0.3, 0.4)
		return dash_dir * (17.0 if dash_dmg else 11.0)
	if charge_w > 0.0:
		charge_w -= dt
		if charge_w <= 0.0:
			if line_tele and is_instance_valid(line_tele): dash_dir = -line_tele.global_transform.basis.z.normalized(); line_tele.queue_free()
			line_tele = null; dash_t = 0.55; dash_dmg = true; dash_hit = false; _play("Running_A", 2.0)
			Game.play_at("dodge", global_position, -2.0, 0.8, true)
		return Vector3.ZERO
	if wind > 0.0:
		wind -= dt
		if wind <= 0.0: _strike(P)
		return Vector3.ZERO
	# potion quand ça va mal (une fois)
	if hp < max_hp * 0.35 and not potted:
		potted = true; hp = min(max_hp, hp + max_hp * 0.4); say("pot !")
		Fx.burst(main, global_position + Vector3(0, 1.2, 0), Color(0.4, 1.0, 0.5), 20, 3.0, 0.3, 0.6, -2.0)
		Fx.number(main, global_position + Vector3(0, 2.4, 0), "+%d" % int(max_hp * 0.4), Color("#7dff8a"))
	# esquive quand tu frappes
	if P.lock > 0.05 and d < 3.4 and dodge_cd <= 0.0 and randf() < 0.4:
		dodge_cd = 2.8; dash_dir = Vector3(-u.z, 0, u.x) * (1.0 if randf() < 0.5 else -1.0); dash_t = 0.3; dash_dmg = false
		_play("Dodge_Left" if ap.has_animation("Dodge_Left") else "Running_A", 1.6, true)
		Fx.burst(main, global_position + Vector3(0, 0.3, 0), Color(0.85, 0.85, 0.9), 10, 3.0, 0.4, 0.4)
		Fx.number(main, global_position + Vector3(0, 2.3, 0), "esquive", Color("#9fe4ff"), false, true)
		return dash_dir * 11.0
	# charge : une ligne rouge annonce la ruée — sors de la ligne !
	if d > 5.0 and d < 11.0 and skill_cd <= 0.0:
		skill_cd = randf_range(6.0, 9.0); charge_w = 0.75
		line_tele = MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.6, 0.02, 10.0); line_tele.mesh = bm
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(1, 0.15, 0.1, 0.4)
		line_tele.material_override = m; line_tele.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.add_child(line_tele)
		line_tele.global_position = global_position + u * 5.0 + Vector3(0, 0.08, 0); line_tele.look_at(line_tele.global_position + u, Vector3.UP)
		_play("Idle_A"); say(["charge !", "bouge pas", "à moi !"][randi() % 3])
		return Vector3.ZERO
	if d > 2.3: return u * 5.4
	if atk_cd <= 0.0: _windup(P); return Vector3.ZERO
	# entre deux coups : il tourne autour de toi
	strafe_t -= dt
	if strafe_t <= 0.0: strafe_t = randf_range(0.8, 1.6); strafe = -strafe
	return Vector3(-u.z, 0, u.x) * 2.6 * strafe + (-u * 1.5 if d < 1.6 else Vector3.ZERO)

func _windup(P: Player) -> void:
	hits += 1
	var heavy := hits % 3 == 0
	wind = 0.55 if not heavy else 0.8
	_play("Throw", 1.3 if not heavy else 1.0, true)
	var fwd := (P.global_position - global_position); fwd.y = 0; fwd = fwd.normalized()
	tele_pos = global_position + fwd * 1.4 if not heavy else global_position
	tele = Fx.disc(main, tele_pos, 1.5 if not heavy else 3.2, Color(1, 0.15, 0.1, 0.38), wind)

func _strike(P: Player) -> void:
	var heavy := hits % 3 == 0
	var r: float = 1.5 if not heavy else 3.2
	_cancel_tele(); atk_cd = 0.9
	var d: float = Vector2(P.global_position.x - tele_pos.x, P.global_position.z - tele_pos.z).length()
	Fx.burst(main, tele_pos + Vector3(0, 0.3, 0), Color(1, 0.6, 0.4), 12, 4.0, 0.35, 0.4)
	if d < r + 0.35: P.hurt(Game.mob_dmg(tier) * (1.35 if not heavy else 2.2) * randf_range(0.9, 1.1), self)
