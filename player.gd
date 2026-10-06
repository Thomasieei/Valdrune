extends CharacterBody3D
class_name Player
# Le héros : déplacement nerveux, combo d'épée, esquive, tourbillon, récolte

const SPEED := 6.4
const REACH := 2.3
var main: Node
var ch: Dictionary = {}
var ap: AnimationPlayer
var hand: Node3D
var hand_path := ""
var yaw := 0.0
var hp := 100.0
var max_hp := 100.0
var dead := false
var lock := 0.0            # animation d'action en cours (pas de déplacement libre)
var move_lock := 0.0
var swing_cd := 0.0
var combo := 0
var combo_t := 0.0
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.ZERO
var invuln := 0.0
var skill_cd := [0.0, 0.0, 0.0, 0.0]
# Chaque famille d'arme a ses 4 sorts (débloqués aux tiers 1, 2, 3, 4)
const SKILL_SETS := {
	"epee": [
		{"name": "Ruée", "icon": "sk_lightning_dash_cyan", "cd": 7.0, "req": 1, "fn": "rush", "desc": "Fonce sur l'ennemi en frappant tout sur ton passage"},
		{"name": "Tourbillon", "icon": "sk_whirlwind_orange", "cd": 6.0, "req": 2, "fn": "spin", "desc": "Tourne sur toi-même : frappe tout autour"},
		{"name": "Lame de vent", "icon": "sk_wind_slicer_green", "cd": 5.0, "req": 3, "fn": "wind_slicer", "desc": "Une lame d'air qui transperce toute une ligne d'ennemis"},
		{"name": "Bouclier de glace", "icon": "sk_ice_shield_white", "cd": 14.0, "req": 4, "fn": "ice_shield", "desc": "Absorbe les dégâts pendant 5 s"},
	],
	"hache": [
		{"name": "Bond fracassant", "icon": "sk_rock_blade_brown", "cd": 7.0, "req": 1, "fn": "leap", "desc": "Saute sur l'ennemi et frappe le sol autour"},
		{"name": "Entaille", "icon": "sk_rend_orange", "cd": 6.0, "req": 2, "fn": "rend", "desc": "Gros coup qui fait saigner (dégâts pendant 3 s)"},
		{"name": "Tourbillon sanglant", "icon": "sk_whirlwind_red", "cd": 8.0, "req": 3, "fn": "blood_spin", "desc": "Long tourbillon : 5 frappes autour de toi"},
		{"name": "Rage", "icon": "sk_augmentation_orange", "cd": 18.0, "req": 4, "fn": "rage", "desc": "+40 % de dégâts et coups plus rapides pendant 6 s"},
	],
	"arc": [
		{"name": "Volée", "icon": "sk_prismatic_knives_green", "cd": 6.0, "req": 1, "fn": "volley", "desc": "5 flèches en éventail"},
		{"name": "Flèche perçante", "icon": "sk_knife_impact_orange", "cd": 6.0, "req": 2, "fn": "pierce_shot", "desc": "Une flèche qui traverse toute une ligne d'ennemis"},
		{"name": "Pluie de flèches", "icon": "sk_shells_purple", "cd": 9.0, "req": 3, "fn": "arrow_rain", "desc": "Une averse de flèches sur la zone ciblée"},
		{"name": "Repli", "icon": "sk_lightning_dash_purple", "cd": 12.0, "req": 4, "fn": "retreat", "desc": "Bond en arrière, puis tirs très rapides pendant 4 s"},
	],
	"arbalete": [
		{"name": "Carreau explosif", "icon": "sk_grenade_red", "cd": 5.0, "req": 1, "fn": "boom_bolt", "desc": "Le carreau explose en zone à l'impact"},
		{"name": "Rafale", "icon": "sk_knife_reload_green", "cd": 7.0, "req": 2, "fn": "burst_fire", "desc": "4 carreaux tirés coup sur coup"},
		{"name": "Carreau gelé", "icon": "sk_ice_blade_cyan", "cd": 8.0, "req": 3, "fn": "frost_bolt", "desc": "Transperce et ralentit tous les ennemis touchés"},
		{"name": "Tir dévastateur", "icon": "sk_volt_cyan", "cd": 14.0, "req": 4, "fn": "heavy_shot", "desc": "Une seconde de visée, puis un tir énorme qui repousse tout"},
	],
	"grimoire": [
		{"name": "Orbe arcanique", "icon": "sk_arcane_pink", "cd": 4.5, "req": 1, "fn": "arcane_orb", "desc": "Un gros orbe lent qui explose en zone"},
		{"name": "Malédiction", "icon": "sk_spell_break_black", "cd": 7.0, "req": 2, "fn": "curse", "desc": "Maudit une zone : dégâts pendant 4 s"},
		{"name": "Drain de vie", "icon": "sk_beam_pink", "cd": 8.0, "req": 3, "fn": "life_drain", "desc": "Aspire la vie d'un ennemi et te soigne"},
		{"name": "Météore", "icon": "sk_fire_ball_purple", "cd": 14.0, "req": 4, "fn": "meteor", "desc": "Un météore s'écrase sur la zone après un court délai"},
	],
	"baton": [
		{"name": "Boule de feu", "icon": "sk_fire_ball_red", "cd": 4.5, "req": 1, "fn": "fireball", "desc": "Projectile qui explose en zone"},
		{"name": "Pic de glace", "icon": "sk_ice_strike_white", "cd": 6.0, "req": 2, "fn": "ice_strike", "desc": "Gèle une zone : dégâts et ennemis ralentis"},
		{"name": "Éclair en chaîne", "icon": "sk_lightning_purple", "cd": 7.0, "req": 3, "fn": "chain_lightning", "desc": "L'éclair rebondit sur 4 ennemis"},
		{"name": "Nova arcanique", "icon": "sk_arc_wave_pink", "cd": 12.0, "req": 4, "fn": "nova", "desc": "Énorme explosion autour de toi, repousse tout"},
	],
}
static func skills() -> Array: return SKILL_SETS.get(Game.S.get("weapon_kind", "epee"), SKILL_SETS.epee)
var rage_t := 0.0
var mounted := false
var mount_node: Node3D
var mount_ap: AnimationPlayer
var mount_cur := ""
var cast_t := 0.0
const CAST := 1.75
var rush_t := 0.0
var rush_dir := Vector3.ZERO
var rush_hit: Array = []
var shield_hp := 0.0
var shield_t := 0.0
var shield_mesh: MeshInstance3D
var potion_cd := 0.0
var gather_cd := 0.0
var gather_total := 1.0
var gather_vis := 0.0          # la barre et le cercle de récolte restent visibles un instant
var gather_nd := {}
var gather_ring: MeshInstance3D
var spin_t := 0.0
var hitstop := 0.0
var cur_anim := ""
var flash_mat: StandardMaterial3D
var input_vec := Vector2.ZERO

func setup(m: Node) -> void:
	main = m
	var col := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.42; cap.height = 1.8; col.shape = cap; col.position.y = 0.9; add_child(col)
	flash_mat = StandardMaterial3D.new(); flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; flash_mat.albedo_color = Color(1, 0.3, 0.25, 0.0); flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# silhouette dorée visible à travers les toits et les arbres (comme sur Albion) : on ne perd jamais son héros
	var gs := Shader.new()
	gs.code = "shader_type spatial;\nrender_mode unshaded, depth_test_disabled, cull_back, blend_mix;\nuniform float k = 0.0;\nvoid fragment() {\n\tfloat rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);\n\tALBEDO = mix(vec3(1.0, 0.78, 0.3), vec3(1.0, 0.95, 0.7), rim);\n\tALPHA = k * (0.38 + 0.6 * rim * rim);\n}\n"
	ghost = ShaderMaterial.new(); ghost.shader = gs; ghost.render_priority = 10
	flash_mat.next_pass = ghost
	refresh_gear(); hp = max_hp
	play("Idle_A")

	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(68.0)     # les collines se gravissent (les vraies falaises restent bloquées par la grille)

var body_key := ""
func refresh_gear() -> void:
	if mounted: dismount()
	var K: Dictionary = Game.ARMOR_KINDS[Game.S.get("armor_kind", "plate")]
	var ratio: float = hp / max_hp if max_hp > 0 else 1.0
	Game.stats_dirty()
	max_hp = Game.stats().hp
	hp = max_hp * ratio if hp > 0 else max_hp
	# tenue : plastron (corps), bottes (jambes), casque et cape sont de vraies pièces visibles, teintées selon leur tier
	var bk: String = Game.kind_of("bottes"); var hk: String = Game.kind_of("casque"); var ck: String = Game.kind_of("cape")
	var key := "%s_%d|%s_%d|%s_%d|%s_%d" % [K.model, int(Game.S.gear.armure), bk, int(Game.S.gear.get("bottes", 0)), hk, int(Game.S.gear.get("casque", 0)), ck, int(Game.S.gear.get("cape", 0))]
	if key != body_key:
		body_key = key
		var old_rot := 0.0
		if ch.has("root") and is_instance_valid(ch.root): old_rot = ch.root.rotation.y; ch.root.queue_free()
		# squelette KayKit « nu » : on ne garde que la tête du héros, chaque pièce portée est greffée à part
		ch = Chars.make("res://assets/heroes/Knight.glb"); add_child(ch.root); ap = ch.ap; ch.root.rotation.y = old_rot
		var bl = ch.root.find_child("Blob", false, false)
		if bl: bl.visible = false
		for mi in Chars.meshes(ch.root):
			if mi.name != "Knight_Head": mi.get_parent().remove_child(mi); mi.free()
		var at := int(Game.S.gear.armure); var bt := int(Game.S.gear.get("bottes", 0))
		# torse + bras : plastron porté, sinon torse nu (peau + linge)
		for part in ["Body", "ArmLeft", "ArmRight"]:
			if at > 0: Chars.graft(ch, K.model, "%s_%s" % [K.model, part], _tier_tint(at))
			else: Chars.graft(ch, "Barbarian", "Barbarian_" + part, Color(1, 1, 1), NAKED_CLOTH)
		# jambes : bottes portées, sinon braies de lin et pieds nus
		var bm: String = Game.gear_def("bottes", bk).model
		for part in ["LegLeft", "LegRight"]:
			if bt > 0: Chars.graft(ch, bm, "%s_%s" % [bm, part], _tier_tint(bt))
			else: Chars.graft(ch, "Barbarian", "Barbarian_" + part, Color(1, 1, 1), NAKED_LEGS)
		if int(Game.S.gear.get("casque", 0)) > 0:
			var H := Game.gear_def("casque", hk)
			for nm in H.parts: Chars.graft(ch, H.model, nm, _tier_tint(int(Game.S.gear.casque)))
		if int(Game.S.gear.get("cape", 0)) > 0:
			var C := Game.gear_def("cape", ck)
			for nm in C.parts: Chars.graft(ch, C.model, nm, _tier_tint(int(Game.S.gear.cape)))
		var tint := _tier_tint(int(Game.S.gear.armure))
		for mi in Chars.meshes(ch.root):
			if mi.is_queued_for_deletion(): continue
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			mi.material_overlay = flash_mat
			if mi.has_meta("grafted") or mi.name == "Knight_Head": continue
			if tint != Color(1, 1, 1):
				for i in mi.mesh.get_surface_count():
					var src = mi.mesh.surface_get_material(i)
					if src is StandardMaterial3D:
						var m: StandardMaterial3D = src.duplicate(); m.albedo_color = tint; mi.set_surface_override_material(i, m)
		hand_path = ""; hand = null; off_path = ""; offhand = null; cur_anim = ""; play("Idle_A")
	set_hand(weapon_path())
	var two: bool = Game.wkind().get("two", false)
	set_offhand("" if two else Game.shield_model(Game.S.gear.get("bouclier", 1)))
	if main.hud: main.hud.refresh_skills()

const NAKED_CLOTH := Color("#d8c7a2")
const NAKED_LEGS := Color("#a8875c")
static func _tier_tint(t: int) -> Color: return Color(1, 1, 1).lerp(Game.TIER_COL[clamp(t, 0, 5)], 0.0 if t <= 1 else 0.28)

func weapon_path() -> String: return Game.weapon_model(Game.S.get("weapon_kind", "epee"), Game.S.gear.epee)

var offhand: Node3D
var off_path := ""
func set_offhand(path: String) -> void:
	if path == off_path: return
	off_path = path
	if offhand: offhand.get_parent().queue_free(); offhand = null
	offhand = Chars.attach(ch, "handslot.l", path, 1.0)
	if offhand: _glow(offhand, Game.S.gear.get("bouclier", 1))

# Les armes T4+ brillent légèrement de la couleur de leur tier
func _glow(n: Node3D, t: int) -> void:
	if t < 4: return
	var g := Sprite3D.new(); g.texture = Fx.soft_tex(); g.billboard = BaseMaterial3D.BILLBOARD_ENABLED; g.shaded = false
	g.pixel_size = 0.012; var c: Color = Game.TIER_COL[t]; c.a = 0.55; g.modulate = c; g.position.y = 0.5
	n.add_child(g)

func set_hand(path: String) -> void:
	if path == hand_path: return
	hand_path = path
	if hand: hand.get_parent().queue_free(); hand = null
	hand = Chars.attach(ch, "handslot.r", path, 1.0)
	if hand and path == weapon_path(): _glow(hand, Game.S.gear.epee)

func play(n: String, speed := 1.0, blend := 0.12, restart := false) -> void:
	if n == cur_anim and not restart:
		ap.speed_scale = speed; return
	cur_anim = n; ap.play(n, blend); ap.speed_scale = speed
	if restart: ap.seek(0.0, true)

func dmg() -> float: return Game.weapon_dmg(Game.S.gear.epee) * Game.wkind().dmg * Game.ench_mult(Game.ench("epee")) * (1.0 + 0.05 * int(Game.eqx("epee").lvl)) * (1.0 + Game.art_bonus("rage") + Game.weapon_bonus() + Game.mount_bonus("dmg") + Game.stats().dmg) * (1.4 if rage_t > 0.0 else 1.0) * (0.6 if Game.S.gear.epee <= 0 else 1.0)
func sdmg() -> float: return dmg() / Game.wkind().dmg * Game.wkind().skill * (1.0 + Game.stats().spell)   # dégâts des sorts
func speed() -> float: return SPEED * max(0.7, 1.0 + Game.stats().spd + Game.art_bonus("vent")) * ((1.0 + Game.mount_bonus("speed")) if mounted else 1.0)

func _physics_process(dt: float) -> void:
	if rapid_t > 0.0: rapid_t -= dt
	if hitstop > 0.0:
		hitstop -= dt; ap.speed_scale = 0.0
		if hitstop <= 0.0: ap.speed_scale = 1.0 if lock <= 0.0 else 2.2
		return
	for v in ["lock", "move_lock", "swing_cd", "dodge_cd", "invuln", "potion_cd", "gather_cd", "combo_t"]:
		set(v, max(0.0, get(v) - dt))
	for i in 4: skill_cd[i] = max(0.0, skill_cd[i] - dt)
	if gather_vis > 0.0:
		gather_vis = max(0.0, gather_vis - dt)
		if gather_ring:
			var gm := gather_ring.material_override as StandardMaterial3D
			gm.albedo_color.a = clamp(gather_vis / 0.6, 0.0, 1.0) * 0.75
			gather_ring.visible = gather_vis > 0.0
	if rage_t > 0.0:
		rage_t -= dt
		if rage_t <= 0.0: flash_mat.albedo_color = Color(1, 0.3, 0.25, 0.0)
	if shield_t > 0.0:
		shield_t -= dt
		if shield_mesh: shield_mesh.rotation.y += dt * 1.5; shield_mesh.scale = Vector3.ONE * (1.0 + sin(shield_t * 8.0) * 0.03)
		if shield_t <= 0.0 or shield_hp <= 0.0: _shield_off()
	if combo_t <= 0.0: combo = 0
	if cast_t > 0.0:
		cast_t -= dt
		if input_vec.length() > 0.2 or dead: cast_t = 0.0; main.hud.toast("Invocation annulée (tu as bougé)", Color("#ffb07a"))
		elif cast_t <= 0.0: _mount()
	if not is_on_floor(): velocity.y -= 30.0 * dt
	else: velocity.y = -1.0
	if dead:
		velocity.x = 0; velocity.z = 0; move_and_slide(); return
	var mv := Vector3(input_vec.x, 0, input_vec.y)
	var want := Vector3.ZERO
	if rush_t > 0.0:
		rush_t -= dt
		want = rush_dir * 27.0
		for e in main.enemies:
			if e.dead or e in rush_hit: continue
			if e.global_position.distance_to(global_position) < 1.6 + e.radius:
				rush_hit.append(e); e.take_hit(sdmg() * 1.5, self, 3.5); hitstop = 0.05; main.shake(0.18); Game.play("hit", -2.0, 1.2)
				Fx.burst(main, e.global_position + Vector3(0, 1.0, 0), Color(0.5, 0.9, 1.0), 14, 5.0, 0.3, 0.4)
		if rush_t <= 0.0: velocity *= 0.3
	elif dodge_t > 0.0:
		dodge_t -= dt
		want = dodge_dir * 15.0 * (0.55 + dodge_t * 1.6)
	elif spin_t > 0.0:
		spin_t -= dt; ch.root.rotation.y += dt * 26.0
		want = mv * SPEED * 0.6
		if spin_t <= 0.0: ch.root.rotation.y = yaw
	elif move_lock <= 0.0 and mv.length() > 0.08:
		want = mv.normalized() * speed() * min(1.0, mv.length() * 1.25)
		yaw = atan2(mv.x, mv.z)
	# réactivité : accélération quasi instantanée, freinage court
	var k := 1.0 - exp(-dt * (22.0 if want.length() > 0.1 else 16.0))
	velocity.x = lerp(velocity.x, want.x, k); velocity.z = lerp(velocity.z, want.z, k)
	_block_water(dt)
	move_and_slide()
	_climb_assist(want, dt)
	_ghost_update(dt)
	if spin_t <= 0.0:
		ch.root.rotation.y = lerp_angle(ch.root.rotation.y, yaw, 1.0 - exp(-dt * 20.0))
	if mounted:
		mount_node.rotation.y = ch.root.rotation.y
		var msp := Vector2(velocity.x, velocity.z).length()
		var an := "Gallop" if msp > 7.0 else ("Walk" if msp > 0.6 else "Idle")
		if an != mount_cur: mount_cur = an; mount_ap.play(an, 0.2)
		mount_ap.speed_scale = clamp(msp / 9.0, 0.7, 1.5) if an == "Gallop" else 1.0
		return
	# animation de déplacement
	if lock <= 0.0 and dodge_t <= 0.0 and spin_t <= 0.0 and rush_t <= 0.0:
		var sp := Vector2(velocity.x, velocity.z).length()
		if sp > 0.6: play("Running_A", clamp(sp / SPEED * 1.15, 0.7, 1.35), 0.1)
		else: play("Idle_A", 1.0, 0.18)

func face(p: Vector3) -> void:
	yaw = atan2(p.x - global_position.x, p.z - global_position.z)

# ——— Combat ———
func attack(target: Node3D) -> void:
	if mounted: dismount()
	cast_t = 0.0
	if swing_cd > 0.0 or dead or dodge_t > 0.0 or spin_t > 0.0: return
	set_hand(weapon_path())
	if Game.ranged(Game.S.get("weapon_kind", "epee")): _shoot(target); return
	if target: face(target.global_position); ch.root.rotation.y = yaw
	combo = (combo % 3) + 1; combo_t = 1.1
	var heavy := combo == 3
	swing_cd = (0.52 if heavy else 0.36) / Game.wkind().rate * (0.7 if rage_t > 0.0 else 1.0)
	lock = 0.3; move_lock = 0.16
	play("Throw", 2.4 if not heavy else 1.9, 0.05, true)
	Game.play("swing", -6.0, 1.15 if not heavy else 0.85)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	velocity += fwd * (3.0 if heavy else 1.6)   # petit élan vers l'avant
	get_tree().create_timer(0.11).timeout.connect(func():
		if dead: return
		Fx.slash(main, global_position + Vector3(0, 1.05, 0) + fwd * 0.4, yaw, Color(1, 0.92, 0.7) if not heavy else Color(1, 0.7, 0.35), 2.3 if heavy else 1.9, combo == 2)
		var hit := 0
		for e in main.enemies:
			if e.dead: continue
			var to: Vector3 = e.global_position - global_position; to.y = 0
			var d := to.length()
			if d > REACH + e.radius + (0.4 if heavy else 0.0): continue
			if d > 0.6 and fwd.dot(to / d) < 0.15: continue
			e.take_hit(dmg() * (1.7 if heavy else 1.0) * randf_range(0.92, 1.08), self, 5.5 if heavy else 2.4)
			hit += 1
		if hit > 0:
			hitstop = 0.085 if heavy else 0.055
			main.shake(0.22 if heavy else 0.12)
			Game.play("hit", -2.0, 0.85 if heavy else 1.0)
	)

# ——— Armes à distance ———
var rapid_t := 0.0
func _shoot(target: Node3D) -> void:
	var W := Game.wkind()
	var dir := Vector3(sin(yaw), 0, cos(yaw))
	if target:
		dir = target.global_position - global_position; dir.y = 0; dir = dir.normalized()
	yaw = atan2(dir.x, dir.z); ch.root.rotation.y = yaw
	combo = (combo % 3) + 1; combo_t = 1.3
	var heavy := combo == 3
	swing_cd = 0.5 / W.rate * (0.7 if rage_t > 0.0 else 1.0) * (0.55 if rapid_t > 0.0 else 1.0)
	lock = 0.22; move_lock = 0.1
	var book: bool = W.proj == "orb"
	play("Use_Item" if book else "Throw", 2.6, 0.05, true)
	Game.play("swing", -8.0, 1.6 if W.proj == "arrow" else (1.0 if W.proj == "bolt" else 0.7))
	var dm := dmg() * (1.5 if heavy else 1.0)
	get_tree().create_timer(0.1).timeout.connect(func():
		if dead: return
		var sh := Shot.new(); main.add_child(sh)
		sh.launch(main, self, global_position + Vector3(0, 1.15, 0) + dir * 0.7, dir, dm, W.proj, {"range": float(W.range) + 2.0, "pierce": W.proj == "bolt" and heavy}))

func _ranged_dir(r: float) -> Vector3:
	var dir := _aim(r); yaw = atan2(dir.x, dir.z); ch.root.rotation.y = yaw
	lock = 0.28; move_lock = 0.14
	return dir

func _fire(dir: Vector3, dm: float, kind: String, opts := {}) -> void:
	var sh := Shot.new(); main.add_child(sh)
	sh.launch(main, self, global_position + Vector3(0, 1.15, 0) + dir * 0.7, dir, dm, kind, opts)

func volley() -> void:
	var dir := _ranged_dir(15.0); play("Throw", 2.2, 0.04, true); Game.play("swing", -3.0, 1.7)
	for k in 5:
		var a := (k - 2) * 0.2
		_fire(dir.rotated(Vector3.UP, a), sdmg() * 0.95, "arrow", {"range": 16.0})

func pierce_shot() -> void:
	var dir := _ranged_dir(18.0); play("Throw", 1.8, 0.04, true); Game.play("swing", 0.0, 1.9)
	_fire(dir, sdmg() * 2.4, "arrow", {"range": 22.0, "pierce": true, "speed": 36.0, "glow": Color(1.0, 0.7, 0.3), "push": 3.0})

func arrow_rain() -> void:
	var e = main._nearest_enemy(global_position, 15.0)
	var c: Vector3 = e.global_position if e else global_position + Vector3(sin(yaw), 0, cos(yaw)) * 7.0
	_ranged_dir(15.0); play("Use_Item", 1.8, 0.04, true); Game.play("swing", -2.0, 1.5)
	Fx.disc(main, Vector3(c.x, main.world.height(c.x, c.z), c.z), 3.4, Color(0.75, 0.55, 1.0, 0.45), 1.3)
	for k in 5:
		get_tree().create_timer(0.35 + k * 0.22).timeout.connect(func():
			for j in 4:
				var q := c + Vector3(randf_range(-2.6, 2.6), 0, randf_range(-2.6, 2.6))
				Fx.burst(main, q + Vector3(0, 0.3, 0), Color(0.85, 0.75, 1.0), 5, 3.0, 0.18, 0.3, 6.0)
			if _hit_circle(c, 3.4, sdmg() * 0.5, 0.8) > 0: Game.play("hit", -6.0, 1.4))

func retreat() -> void:
	var back := -_aim(10.0); var tgt := global_position + back * 5.0
	if not main.world.walkable(tgt.x, tgt.z): tgt = global_position + back * 2.0
	invuln = 0.5; lock = 0.4; move_lock = 0.4; play("Jump_Full_Short", 1.8, 0.04, true); Game.play("dodge", -2.0, 1.2)
	var tw := create_tween(); tw.tween_property(self, "global_position", Vector3(tgt.x, main.world.height(tgt.x, tgt.z) + 0.2, tgt.z), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	rapid_t = 4.0
	Fx.burst(main, global_position + Vector3(0, 0.4, 0), Color(0.7, 0.6, 1.0), 18, 4.0, 0.3, 0.5, 0.0)
	main.hud.toast("Tirs rapides pendant 4 s !", Color("#c9a8ff"))

func boom_bolt() -> void:
	var dir := _ranged_dir(14.0); play("Throw", 2.0, 0.04, true); Game.play("swing", -1.0, 0.9)
	_fire(dir, sdmg() * 1.9, "bolt", {"range": 15.0, "boom": 2.6, "glow": Color(1.0, 0.5, 0.2)})

func burst_fire() -> void:
	_ranged_dir(14.0)
	for k in 4:
		get_tree().create_timer(k * 0.13).timeout.connect(func():
			if dead: return
			var dir := _aim(14.0); yaw = atan2(dir.x, dir.z); ch.root.rotation.y = yaw
			play("Throw", 3.0, 0.02, true); Game.play("swing", -5.0, 1.1)
			_fire(dir, sdmg() * 0.8, "bolt", {"range": 15.0}))

func frost_bolt() -> void:
	var dir := _ranged_dir(14.0); play("Throw", 2.0, 0.04, true); Game.play("craft", -6.0, 1.7)
	_fire(dir, sdmg() * 1.6, "bolt", {"range": 18.0, "pierce": true, "slow": 3.0, "glow": Color(0.6, 0.9, 1.0)})

func heavy_shot() -> void:
	var dir := _ranged_dir(16.0); lock = 0.75; move_lock = 0.75
	play("Use_Item", 1.0, 0.04, true); Game.play("craft", -4.0, 0.7)
	Fx.burst(main, global_position + Vector3(0, 1.1, 0) + dir * 0.6, Color(0.6, 0.95, 1.0), 20, 1.5, 0.25, 0.5, -1.0)
	get_tree().create_timer(0.55).timeout.connect(func():
		if dead: return
		var d2 := _aim(16.0); yaw = atan2(d2.x, d2.z); ch.root.rotation.y = yaw
		play("Throw", 2.0, 0.02, true); Game.play("hit", 0.0, 0.5); main.shake(0.3)
		_fire(d2, sdmg() * 4.0, "bolt", {"range": 22.0, "pierce": true, "speed": 40.0, "push": 8.0, "glow": Color(0.6, 0.95, 1.0), "big": true}))

func arcane_orb() -> void:
	var dir := _ranged_dir(15.0); play("Use_Item", 2.0, 0.04, true); Game.play("roar", -14.0, 2.2)
	_fire(dir, sdmg() * 2.0, "orb", {"range": 16.0, "boom": 3.0, "speed": 11.0, "big": true})

func curse() -> void:
	var e = main._nearest_enemy(global_position, 14.0)
	var c: Vector3 = e.global_position if e else global_position + Vector3(sin(yaw), 0, cos(yaw)) * 6.0
	_ranged_dir(14.0); play("Use_Item", 1.6, 0.04, true); Game.play("roar", -12.0, 0.6)
	Fx.disc(main, Vector3(c.x, main.world.height(c.x, c.z), c.z), 3.2, Color(0.35, 0.1, 0.45, 0.6), 4.0, false)
	for en in main.enemies.duplicate():
		if en.dead: continue
		if Vector2(en.global_position.x - c.x, en.global_position.z - c.z).length() < 3.2 + en.radius:
			if en.has_method("bleed"): en.bleed(sdmg() * 0.55, 4.0, self)
			else: en.take_hit(sdmg() * 1.6, self, 0.5)
	Fx.burst(main, c + Vector3(0, 0.4, 0), Color(0.55, 0.2, 0.75), 30, 3.0, 0.35, 0.9, -2.0)

func life_drain() -> void:
	var e = main._nearest_enemy(global_position, 12.0)
	_ranged_dir(12.0); play("Use_Item", 1.2, 0.04, true); lock = 1.0; move_lock = 0.6
	if e == null: return
	Game.play("craft", -8.0, 0.6)
	for k in 5:
		get_tree().create_timer(0.1 + k * 0.2).timeout.connect(func():
			if dead or e == null or not is_instance_valid(e) or e.dead: return
			var a := global_position + Vector3(0, 1.2, 0); var b: Vector3 = e.global_position + Vector3(0, 1.0, 0)
			_beam(a, b, Color(1.0, 0.35, 0.6))
			var amount := sdmg() * 0.65
			e.take_hit(amount, self, 0.2)
			hp = min(max_hp, hp + amount * 0.5)
			Fx.burst(main, global_position + Vector3(0, 1.0, 0), Color(0.6, 1.0, 0.6), 4, 1.5, 0.2, 0.4, -2.0))

func _beam(a: Vector3, b: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new(); var im := ImmediateMesh.new(); mi.mesh = im
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = col; m.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, m)
	for k in 7:
		var p := a.lerp(b, k / 6.0) + Vector3(0, sin(k * 1.3 + Time.get_ticks_msec() * 0.02) * 0.12, 0)
		im.surface_add_vertex(p)
	im.surface_end(); main.add_child(mi)
	var tw := mi.create_tween(); tw.tween_interval(0.18); tw.tween_callback(mi.queue_free)

func meteor() -> void:
	var e = main._nearest_enemy(global_position, 15.0)
	var c: Vector3 = e.global_position if e else global_position + Vector3(sin(yaw), 0, cos(yaw)) * 7.0
	c.y = main.world.height(c.x, c.z)
	_ranged_dir(15.0); play("Use_Item", 1.3, 0.04, true); Game.play("roar", -10.0, 1.6)
	Fx.disc(main, c, 4.5, Color(1.0, 0.35, 0.9, 0.5), 0.85)
	var orb := Shot.new(); main.add_child(orb)
	orb.launch(main, self, c + Vector3(-3.0, 14.0, 2.0), (Vector3(3.0, -14.0, -2.0)).normalized(), 0.0, "orb", {"range": 14.5, "speed": 17.0, "big": true, "fx_only": true})
	get_tree().create_timer(0.85).timeout.connect(func():
		_hit_circle(c, 4.5, sdmg() * 3.2, 6.0); main.shake(0.45); hitstop = 0.08
		Fx.burst(main, c + Vector3(0, 0.6, 0), Color(1.0, 0.45, 0.9), 50, 9.0, 0.5, 0.7)
		Fx.disc(main, c, 4.5, Color(1.0, 0.5, 0.95, 0.6), 0.35, false)
		Game.play("hit", 0.0, 0.5); Game.play("roar", -12.0, 2.4))

func dodge() -> void:
	if dodge_cd > 0.0 or dead: return
	if mounted: dismount()
	rush_t = 0.0
	var mv := Vector3(input_vec.x, 0, input_vec.y)
	dodge_dir = mv.normalized() if mv.length() > 0.1 else Vector3(sin(yaw), 0, cos(yaw))
	yaw = atan2(dodge_dir.x, dodge_dir.z)
	dodge_t = 0.28 + 0.02 * (Game.S.gear.get("bottes", 1) - 1); dodge_cd = 1.0; invuln = 0.38; lock = 0.0; move_lock = 0.0
	play("Jump_Full_Short", 2.2, 0.05, true)
	Game.play("dodge", -4.0)
	Fx.burst(main, global_position + Vector3(0, 0.2, 0), Color(0.85, 0.8, 0.7, 0.8), 10, 2.5, 0.5, 0.45, 2.0)

func use_skill(i: int) -> void:
	if dead: return
	if mounted: dismount()
	cast_t = 0.0
	var sk: Dictionary = skills()[i]
	if Game.S.gear.epee < sk.req:
		main.hud.toast("%s : débloquée avec une arme T%d (forge)" % [sk.name, sk.req], Color("#ffb07a")); Game.play("error"); return
	if skill_cd[i] > 0.0: return
	skill_cd[i] = sk.cd * max(0.4, 1.0 - Game.stats().cd - Game.wkind().cd)
	call(sk.fn)

func _aim(r: float) -> Vector3:
	var e = main._nearest_enemy(global_position, r)
	if e: var d: Vector3 = e.global_position - global_position; d.y = 0; return d.normalized()
	var mv := Vector3(input_vec.x, 0, input_vec.y)
	if mv.length() > 0.1: return mv.normalized()
	return Vector3(sin(yaw), 0, cos(yaw))

func rush() -> void:
	rush_dir = _aim(9.0); yaw = atan2(rush_dir.x, rush_dir.z); ch.root.rotation.y = yaw
	rush_t = 0.22; invuln = 0.3; rush_hit = []; lock = 0.3
	play("Throw", 2.0, 0.04, true); Game.play("dodge", -1.0, 1.3)
	Fx.slash(main, global_position + Vector3(0, 1.0, 0) + rush_dir * 2.5, yaw, Color(0.5, 0.9, 1.0), 2.6)
	Fx.burst(main, global_position + Vector3(0, 0.6, 0), Color(0.5, 0.9, 1.0), 16, 3.0, 0.35, 0.5, 0.0)

func fireball() -> void:
	var dir := _aim(15.0); yaw = atan2(dir.x, dir.z); ch.root.rotation.y = yaw
	lock = 0.3; move_lock = 0.15; play("Throw", 2.0, 0.04, true); Game.play("swing", -2.0, 0.6)
	var fb := Fireball.new(); main.add_child(fb); fb.launch(main, global_position + Vector3(0, 1.2, 0) + dir * 0.8, dir, sdmg() * 2.0)

func ice_shield() -> void:
	shield_hp = max_hp * 0.4; shield_t = 5.0
	if not shield_mesh:
		shield_mesh = MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 1.15; sm.height = 2.3; shield_mesh.mesh = sm
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.55, 0.85, 1.0, 0.28); m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		shield_mesh.material_override = m; shield_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; shield_mesh.position.y = 1.0; add_child(shield_mesh)
	shield_mesh.visible = true
	Game.play("craft", -4.0, 1.4)
	Fx.burst(main, global_position + Vector3(0, 1.0, 0), Color(0.7, 0.95, 1.0), 24, 4.0, 0.3, 0.6, 0.0)

func _shield_off() -> void:
	shield_t = 0.0; shield_hp = 0.0
	if shield_mesh: shield_mesh.visible = false

func spin() -> void:
	spin_t = 0.55; lock = 0.55
	play("Idle_B", 1.0, 0.05)
	Game.play("swing", 0.0, 0.7)
	Fx.disc(main, global_position, 3.6, Color(1, 0.85, 0.5, 0.55), 0.35, false)
	for i in 3:
		get_tree().create_timer(0.08 + i * 0.16).timeout.connect(func():
			Fx.slash(main, global_position + Vector3(0, 1.0, 0), yaw + i * 2.1, Color(1, 0.8, 0.45), 2.8, i % 2 == 0)
			var hit := false
			for e in main.enemies:
				if e.dead: continue
				if e.global_position.distance_to(global_position) < 3.6 + e.radius:
					e.take_hit(sdmg() * 0.9, self, 4.0); hit = true
			if hit: hitstop = 0.04; main.shake(0.15); Game.play("hit", -3.0, 1.2)
		)

func drink() -> void:
	if potion_cd > 0.0 or dead or hp >= max_hp: return
	if Game.S.potions <= 0:
		main.hud.toast("Plus de potions : achète-en au MARCHÉ du camp", Color("#ff8a7a")); Game.play("error"); return
	Game.S.potions -= 1; potion_cd = 8.0
	var heal := max_hp * 0.45; hp = min(max_hp, hp + heal)
	Fx.number(main, global_position + Vector3(0, 2.4, 0), "+%d" % int(heal), Color("#7dff8a"), true)
	Fx.burst(main, global_position + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.5, 1.0), 18, 2.5, 0.35, 0.8, -2.0)
	Game.play("pickup", -2.0, 0.8)

var last_attacker: Node3D
func hurt(amount: float, from: Node3D) -> void:
	if dead or invuln > 0.0 or (main.builder and main.builder.active): return
	last_attacker = from
	amount *= 1.0 - Game.stats().red   # armure de tout l'équipement
	if cast_t > 0.0: cast_t = 0.0; main.hud.toast("Invocation interrompue !", Color("#ff9a8a"))
	if shield_hp > 0.0:
		var ab: float = min(shield_hp, amount); shield_hp -= ab; amount -= ab
		Fx.number(main, global_position + Vector3(0, 2.3, 0), "absorbé", Color("#9fe4ff"))
		if shield_hp <= 0.0: _shield_off()
		if amount <= 0.0: return
	hp -= amount
	flash_mat.albedo_color.a = 0.6
	create_tween().tween_property(flash_mat, "albedo_color:a", 0.0, 0.25)
	Fx.number(main, global_position + Vector3(0, 2.3, 0), str(int(amount)), Color("#ff5a4a"))
	main.shake(0.25); main.hud.hurt_flash()
	Game.play("hurt", -3.0)
	if from:
		var push: Vector3 = (global_position - from.global_position); push.y = 0
		velocity += push.normalized() * 5.0
	if hp <= 0.0: die()
	elif lock <= 0.0 and not mounted: play("Hit_A", 1.6, 0.05, true); lock = 0.22

func die() -> void:
	if mounted: dismount()
	dead = true; hp = 0; play("Death_A", 1.0, 0.1, true)
	Game.play("death", 0.0, 0.8)
	main.on_player_death()

func revive(pos: Vector3) -> void:
	dead = false; hp = max_hp; global_position = pos; velocity = Vector3.ZERO; lock = 0; play("Idle_A", 1.0, 0.0, true)

# ——— Sorts de l'épée / de la hache / du bâton ———
func _hit_circle(c: Vector3, r: float, amount: float, push := 3.0) -> int:
	var n := 0
	for e in main.enemies.duplicate():
		if e.dead: continue
		if Vector2(e.global_position.x - c.x, e.global_position.z - c.z).length() < r + e.radius:
			e.take_hit(amount * randf_range(0.92, 1.08), self, push); n += 1
	return n

func wind_slicer() -> void:
	var dir := _aim(14.0); yaw = atan2(dir.x, dir.z); ch.root.rotation.y = yaw
	lock = 0.3; move_lock = 0.15; play("Throw", 2.2, 0.04, true); Game.play("swing", -1.0, 1.4)
	var start := global_position + Vector3(0, 1.0, 0)
	var hit := []
	for k in 8:
		get_tree().create_timer(k * 0.04).timeout.connect(func():
			var p: Vector3 = start + dir * (1.5 + k * 1.6)
			Fx.slash(main, p, yaw, Color(0.6, 1.0, 0.7), 1.6, k % 2 == 0)
			for e in main.enemies.duplicate():
				if e.dead or e in hit: continue
				if Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() < 1.5 + e.radius:
					hit.append(e); e.take_hit(sdmg() * 1.7, self, 3.0))

func leap() -> void:
	var e = main._nearest_enemy(global_position, 10.0)
	var tgt: Vector3 = e.global_position if e else global_position + Vector3(sin(yaw), 0, cos(yaw)) * 5.0
	var to := tgt - global_position; to.y = 0
	if to.length() > 1.2: tgt = global_position + to - to.normalized() * 1.2
	yaw = atan2(to.x, to.z); ch.root.rotation.y = yaw
	invuln = 0.5; lock = 0.55; move_lock = 0.55; play("Jump_Full_Short", 1.6, 0.04, true); Game.play("dodge", -2.0, 0.8)
	var tw := create_tween(); tw.tween_property(self, "global_position", Vector3(tgt.x, main.world.height(tgt.x, tgt.z) + 0.2, tgt.z), 0.4).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		var c := global_position
		_hit_circle(c, 3.5, sdmg() * 2.0, 4.5); main.shake(0.35); hitstop = 0.08
		Fx.disc(main, c, 3.5, Color(0.8, 0.6, 0.35, 0.6), 0.3, false); Fx.burst(main, c + Vector3(0, 0.3, 0), Color(0.75, 0.6, 0.45), 26, 6.0, 0.4, 0.6)
		Game.play("hit", 0.0, 0.6))

func rend() -> void:
	var dir := _aim(4.0); yaw = atan2(dir.x, dir.z); ch.root.rotation.y = yaw
	lock = 0.4; move_lock = 0.25; play("Throw", 1.6, 0.04, true); Game.play("swing", 0.0, 0.7)
	get_tree().create_timer(0.15).timeout.connect(func():
		Fx.slash(main, global_position + Vector3(0, 1.0, 0) + dir * 0.5, yaw, Color(1, 0.35, 0.25), 2.6, true)
		for e in main.enemies.duplicate():
			if e.dead: continue
			var to: Vector3 = e.global_position - global_position; to.y = 0
			if to.length() < 2.8 + e.radius and dir.dot(to.normalized()) > 0.2:
				e.take_hit(sdmg() * 2.0, self, 4.0)
				if e.has_method("bleed"): e.bleed(sdmg() * 0.35, 3.0, self)
		hitstop = 0.07; main.shake(0.2))

func blood_spin() -> void:
	spin_t = 1.0; lock = 1.0
	play("Idle_B", 1.0, 0.05); Game.play("swing", 0.0, 0.6)
	Fx.disc(main, global_position, 3.8, Color(1, 0.3, 0.25, 0.55), 0.4, false)
	for i in 5:
		get_tree().create_timer(0.08 + i * 0.18).timeout.connect(func():
			Fx.slash(main, global_position + Vector3(0, 1.0, 0), yaw + i * 1.3, Color(1, 0.3, 0.25), 3.0, i % 2 == 0)
			if _hit_circle(global_position, 3.8, sdmg() * 0.75, 3.0) > 0: hitstop = 0.03; main.shake(0.12); Game.play("hit", -3.0, 1.1))

func rage() -> void:
	rage_t = 6.0; flash_mat.albedo_color = Color(1, 0.2, 0.1, 0.35)
	Game.play("roar", -6.0, 1.4); Fx.burst(main, global_position + Vector3(0, 1.0, 0), Color(1, 0.3, 0.15), 30, 5.0, 0.4, 0.7, -2.0)
	main.hud.toast("RAGE ! +40 % de dégâts pendant 6 s", Color("#ff7a5a"))

func ice_strike() -> void:
	var e = main._nearest_enemy(global_position, 13.0)
	var c: Vector3 = e.global_position if e else global_position + Vector3(sin(yaw), 0, cos(yaw)) * 5.0
	lock = 0.3; move_lock = 0.15; play("Use_Item", 1.8, 0.04, true); Game.play("craft", -6.0, 1.6)
	Fx.disc(main, c, 3.0, Color(0.6, 0.9, 1.0, 0.45), 0.45)
	get_tree().create_timer(0.45).timeout.connect(func():
		for en in main.enemies.duplicate():
			if en.dead: continue
			if Vector2(en.global_position.x - c.x, en.global_position.z - c.z).length() < 3.0 + en.radius:
				en.take_hit(sdmg() * 2.2, self, 1.0)
				if en.has_method("slow"): en.slow(3.0)
		Fx.burst(main, c + Vector3(0, 0.5, 0), Color(0.75, 0.95, 1.0), 30, 6.0, 0.4, 0.7); main.shake(0.15))

func chain_lightning() -> void:
	var first = main._nearest_enemy(global_position, 12.0)
	lock = 0.3; move_lock = 0.15; play("Use_Item", 2.0, 0.04, true); Game.play("mine", -2.0, 1.8)
	if first == null: return
	var from := global_position + Vector3(0, 1.2, 0); var hit := []; var cur = first; var amount := sdmg() * 1.8
	for k in 4:
		if cur == null: break
		hit.append(cur)
		var to: Vector3 = cur.global_position + Vector3(0, 1.0, 0)
		_bolt(from, to); cur.take_hit(amount, self, 1.5); amount *= 0.8; from = to
		var nxt = null; var bd := 7.0
		for e in main.enemies:
			if e.dead or e in hit: continue
			var d: float = e.global_position.distance_to(cur.global_position)
			if d < bd: bd = d; nxt = e
		cur = nxt

func _bolt(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new(); var im := ImmediateMesh.new(); mi.mesh = im
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(0.8, 0.6, 1.0); m.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, m)
	for k in 9:
		var p := a.lerp(b, k / 8.0)
		if k > 0 and k < 8: p += Vector3(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
		im.surface_add_vertex(p)
	im.surface_end(); main.add_child(mi)
	var tw := mi.create_tween(); tw.tween_interval(0.18); tw.tween_callback(mi.queue_free)
	Fx.burst(main, b, Color(0.8, 0.6, 1.0), 10, 4.0, 0.25, 0.3)

func nova() -> void:
	lock = 0.5; move_lock = 0.4; play("Use_Item", 1.4, 0.04, true); Game.play("roar", -8.0, 1.8)
	Fx.disc(main, global_position, 5.5, Color(1.0, 0.45, 0.9, 0.5), 0.35)
	get_tree().create_timer(0.35).timeout.connect(func():
		_hit_circle(global_position, 5.5, sdmg() * 2.6, 7.0); main.shake(0.4); hitstop = 0.08
		Fx.burst(main, global_position + Vector3(0, 0.8, 0), Color(1.0, 0.5, 0.95), 50, 9.0, 0.45, 0.7))

# ——— Monture : 1,75 s d'invocation, on la chevauche pour aller vite ———
func summon_mount() -> void:
	if dead: return
	if mounted: dismount(); return
	if cast_t > 0.0: return
	var M := Game.mount()
	if M.is_empty(): main.hud.toast("Pas de monture : achète-en une à l'hôtel des ventes (catégorie Montures)", Color("#ffb07a")); Game.play("error"); return
	if main.enemies.any(func(e): return not e.dead and e.state != "idle" and e.global_position.distance_to(global_position) < 9.0):
		main.hud.toast("Impossible d'invoquer en plein combat", Color("#ff9a8a")); Game.play("error"); return
	cast_t = CAST; velocity = Vector3.ZERO
	play("Use_Item", 0.8, 0.1, true); Game.play("craft", -8.0, 0.7)
	Fx.disc(main, global_position, 1.6, Color(0.6, 0.85, 1.0, 0.45), CAST, false)

func _mount() -> void:
	var M := Game.mount()
	if M.is_empty(): return
	var m: Node3D = load("res://assets/animals/%s.glb" % M.model).instantiate(); m.scale = Vector3.ONE * M.scale
	add_child(m); mount_node = m; mount_ap = m.find_child("AnimationPlayer", true, false); mount_cur = ""
	for an in ["Idle", "Walk", "Gallop"]:
		if mount_ap.has_animation(an): mount_ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	if M.has("tint"): _tint_mount(m, M.tint)
	if M.get("shop", false):
		# traînée d'étoiles bleues du Pégase
		var sp := CPUParticles3D.new(); sp.amount = 40; sp.lifetime = 1.2; sp.local_coords = false; sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 0.8
		sp.gravity = Vector3(0, 0.6, 0); sp.initial_velocity_min = 0.1; sp.initial_velocity_max = 0.5; sp.scale_amount_min = 0.12; sp.scale_amount_max = 0.25
		var pq := QuadMesh.new(); pq.material = Fx.add_mat(); sp.mesh = pq; sp.color = Color(0.6, 0.85, 1.0, 0.9); sp.position.y = 1.2; m.add_child(sp)
	mounted = true
	ch.root.position.y = M.seat
	cur_anim = ""; play("PickUp", 0.0, 0.0, true); ap.seek(0.55, true); ap.speed_scale = 0.0   # posture assise
	Fx.burst(main, global_position + Vector3(0, 0.8, 0), Color(0.7, 0.9, 1.0), 24, 4.0, 0.4, 0.6)
	Game.play("dodge", -4.0, 0.7)
	if hand: hand.visible = false
	if offhand: offhand.visible = false

func dismount() -> void:
	if not mounted: return
	mounted = false
	if mount_node: mount_node.queue_free(); mount_node = null
	ch.root.position.y = 0.0; cur_anim = ""; play("Idle_A", 1.0, 0.1)
	if hand: hand.visible = true
	if offhand: offhand.visible = true

func _tint_mount(n: Node, c: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				var mt: BaseMaterial3D = src.duplicate(); mt.albedo_color = mt.albedo_color * c; mi.set_surface_override_material(i, mt)
	for chn in n.get_children(): _tint_mount(chn, c)

# Surbrillance quand un métier passe un niveau
func level_glow(col := Color(1.0, 0.85, 0.35)) -> void:
	var pillar := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.9; cm.bottom_radius = 1.1; cm.height = 6.0; cm.cap_top = false; cm.cap_bottom = false; pillar.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.55); m.cull_mode = BaseMaterial3D.CULL_DISABLED; pillar.material_override = m; pillar.position.y = 3.0
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(pillar)
	var tw := pillar.create_tween(); tw.tween_property(m, "albedo_color:a", 0.0, 1.6); tw.parallel().tween_property(pillar, "scale", Vector3(1.6, 1.0, 1.6), 1.6); tw.tween_callback(pillar.queue_free)
	flash_mat.albedo_color = Color(col.r, col.g, col.b, 0.75)
	var tw2 := create_tween(); tw2.tween_property(flash_mat, "albedo_color:a", 0.0, 1.2); tw2.tween_callback(func(): flash_mat.albedo_color = Color(1, 0.3, 0.25, 0.0))
	Fx.burst(main, global_position + Vector3(0, 1.0, 0), col, 36, 6.0, 0.4, 1.0, -3.0)
	Fx.disc(main, global_position, 3.0, Color(col.r, col.g, col.b, 0.5), 0.6, false)

var guild_lbl: Label3D
func refresh_name() -> void:
	if guild_lbl == null:
		guild_lbl = Label3D.new(); guild_lbl.font_size = 34; guild_lbl.outline_size = 12; guild_lbl.modulate = Color("#9fe0ff"); guild_lbl.outline_modulate = Color(0, 0, 0, 0.8)
		guild_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; guild_lbl.pixel_size = 0.0065; guild_lbl.position.y = 2.6; guild_lbl.no_depth_test = true; add_child(guild_lbl)
	var S: Dictionary = Game.S.get("guild", {})
	guild_lbl.text = "[%s] %s" % [S.tag, str(Game.S.get("pname", "Aventurier"))] if S.has("tag") else ""
	guild_lbl.visible = guild_lbl.text != ""

func play_pick() -> void:
	if dead: return
	if mounted: dismount()
	lock = 0.35; move_lock = 0.35
	play("PickUp", 1.6, 0.06, true)

# grand cercle blanc au sol pendant la récolte (comme Albion)
func _gather_ring_on() -> void:
	if gather_ring == null:
		gather_ring = MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 3.55; tm.outer_radius = 3.7; tm.rings = 64; tm.ring_segments = 4; gather_ring.mesh = tm
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.75); gather_ring.material_override = m; gather_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gather_ring.scale = Vector3(1, 0.15, 1); gather_ring.position.y = 0.12; add_child(gather_ring)
	gather_ring.visible = true

# ——— Récolte ———
func gather(nd: Dictionary) -> void:
	if gather_cd > 0.0 or dead: return
	if mounted: dismount()
	var tool: String = Game.TOOL_OF[nd.type]
	set_hand(Game.TOOL_MODEL[tool])
	face(nd.pos); ch.root.rotation.y = yaw
	gather_cd = Game.gather_time(tool, nd.tier); gather_total = max(0.05, gather_cd); gather_vis = gather_cd + 1.4; gather_nd = nd
	_gather_ring_on()
	lock = min(0.55, gather_cd * 0.6); move_lock = 0.3
	play("Throw" if nd.type != "fiber" else "PickUp", clamp(1.3 / gather_cd * 1.2, 1.0, 2.4), 0.06, true)
	get_tree().create_timer(0.32).timeout.connect(func(): main.on_gather_hit(nd))


# ——— Boule de feu ———
# Projectile des armes à distance : flèche, carreau ou orbe magique
class Shot extends Node3D:
	var main: Node
	var owner_p: Node3D
	var dir := Vector3.ZERO
	var dmg := 0.0
	var dist := 0.0
	var kind := "arrow"
	var o := {}
	var hit_list: Array = []
	const MODELS := {"arrow": "res://assets/weapons/arrow_bow.gltf", "bolt": "res://assets/weapons/arrow_crossbow.gltf"}
	static var _orb_mat: StandardMaterial3D
	func launch(m: Node, who: Node3D, p: Vector3, d: Vector3, damage: float, k: String, opts := {}) -> void:
		main = m; owner_p = who; dir = d.normalized(); dmg = damage; kind = k; o = opts
		global_position = p
		var big: bool = o.get("big", false)
		if kind == "orb":
			if _orb_mat == null:
				_orb_mat = StandardMaterial3D.new(); _orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; _orb_mat.albedo_color = Color(0.95, 0.55, 1.0)
			var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.36 if big else 0.2; sm.height = sm.radius * 2.0; sm.radial_segments = 10; sm.rings = 6; mi.mesh = sm; mi.material_override = _orb_mat; add_child(mi)
			var gl := Sprite3D.new(); gl.texture = Fx.soft_tex(); gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; gl.pixel_size = 0.04 if big else 0.022; gl.modulate = Color(0.9, 0.4, 1.0, 0.8); gl.shaded = false; add_child(gl)
			var tr := CPUParticles3D.new(); tr.amount = 18 if big else 10; tr.lifetime = 0.35; tr.local_coords = false; tr.spread = 180.0
			tr.initial_velocity_min = 0.2; tr.initial_velocity_max = 0.8; tr.gravity = Vector3.ZERO; tr.scale_amount_min = 0.25; tr.scale_amount_max = 0.5 if big else 0.35
			var q := QuadMesh.new(); q.material = Fx.add_mat(); tr.mesh = q
			var g := Gradient.new(); g.set_color(0, Color(1, 0.6, 1, 0.9)); g.set_color(1, Color(0.5, 0.1, 0.9, 0)); tr.color_ramp = g; add_child(tr)
		else:
			var mdl: Node3D = load(MODELS[kind]).instantiate(); add_child(mdl)
			mdl.scale = Vector3.ONE * (1.6 if big else 1.25)
			look_at(global_position + dir, Vector3.UP); rotate_object_local(Vector3.UP, PI)
			for mi in mdl.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if o.has("glow"):
				var gc: Color = o.glow
				var gl := Sprite3D.new(); gl.texture = Fx.soft_tex(); gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; gl.pixel_size = 0.03 if big else 0.018; gl.modulate = Color(gc.r, gc.g, gc.b, 0.85); gl.shaded = false; add_child(gl)
	func _physics_process(dt: float) -> void:
		var step: float = float(o.get("speed", 26.0 if kind != "orb" else 16.0)) * dt
		global_position += dir * step; dist += step
		if dist > float(o.get("range", 15.0)): _end(); return
		# murs du donjon : le tir s'arrête
		if main.has_method("in_instance") and main.in_instance() and main.dungeon and not main.dungeon.walkable(global_position.x, global_position.z): _end(); return
		if o.get("fx_only", false): return
		for e in main.enemies.duplicate():
			if e.dead or e in hit_list: continue
			var to: Vector3 = e.global_position - global_position; to.y = 0
			if to.length() < 0.7 + e.radius:
				if o.has("boom"): _end(); return
				hit_list.append(e)
				e.take_hit(dmg * randf_range(0.93, 1.07), owner_p, float(o.get("push", 1.2)))
				if o.has("slow") and e.has_method("slow"): e.slow(float(o.slow))
				Fx.burst(main, global_position, Color(1, 0.9, 0.7) if kind != "orb" else Color(0.9, 0.5, 1.0), 6, 3.0, 0.2, 0.3, 4.0)
				Game.play("hit", -7.0, 1.3 if kind == "arrow" else 0.95)
				if not o.get("pierce", false): queue_free(); return
	func _end() -> void:
		if o.has("boom") and not o.get("fx_only", false):
			var c := global_position; var r: float = o.boom
			for e in main.enemies.duplicate():
				if not e.dead and Vector2(e.global_position.x - c.x, e.global_position.z - c.z).length() < r + e.radius:
					e.take_hit(dmg * randf_range(0.92, 1.08), owner_p, 3.5)
			var col := Color(1.0, 0.55, 0.2) if kind != "orb" else Color(0.95, 0.45, 1.0)
			Fx.burst(main, c, col, 26, 6.5, 0.5, 0.55, 3.0)
			Fx.disc(main, Vector3(c.x, main.world.height(c.x, c.z), c.z), r, Color(col.r, col.g, col.b, 0.55), 0.35, false)
			main.shake(0.2); Game.play("hit", -1.0, 0.7)
		queue_free()

class Fireball extends Node3D:
	var main: Node
	var dir := Vector3.ZERO
	var dmg := 0.0
	var dist := 0.0
	var trail: CPUParticles3D
	func launch(m: Node, p: Vector3, d: Vector3, damage: float) -> void:
		main = m; dir = d; dmg = damage; global_position = p
		var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.32; sm.height = 0.64; mi.mesh = sm
		var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color = Color(1.0, 0.75, 0.3); mi.material_override = mat; add_child(mi)
		var gl := Sprite3D.new(); gl.texture = Fx.soft_tex(); gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; gl.pixel_size = 0.03; gl.modulate = Color(1, 0.6, 0.2, 0.8); gl.shaded = false; add_child(gl)
		trail = CPUParticles3D.new(); trail.amount = 30; trail.lifetime = 0.4; trail.local_coords = false; trail.direction = Vector3.UP; trail.spread = 180.0
		trail.initial_velocity_min = 0.3; trail.initial_velocity_max = 1.2; trail.gravity = Vector3(0, 1.5, 0); trail.scale_amount_min = 0.4; trail.scale_amount_max = 0.7
		var q := QuadMesh.new(); q.material = Fx.add_mat(); trail.mesh = q
		var g := Gradient.new(); g.set_color(0, Color(1, 0.7, 0.2, 1)); g.set_color(1, Color(1, 0.15, 0.0, 0)); trail.color_ramp = g
		add_child(trail)
	func _physics_process(dt: float) -> void:
		var step := 19.0 * dt; global_position += dir * step; dist += step
		var hit := dist > 15.0
		for e in main.enemies:
			if not e.dead and e.global_position.distance_to(global_position - Vector3(0, 0.8, 0)) < 1.0 + e.radius: hit = true; break
		if hit: _explode()
	func _explode() -> void:
		var c := global_position
		for e in main.enemies:
			if not e.dead and Vector2(e.global_position.x - c.x, e.global_position.z - c.z).length() < 2.8 + e.radius:
				e.take_hit(dmg * randf_range(0.92, 1.08), self, 4.0)
		Fx.burst(main, c, Color(1.0, 0.6, 0.2), 30, 7.0, 0.55, 0.6, 4.0)
		Fx.disc(main, Vector3(c.x, main.world.height(c.x, c.z), c.z), 2.8, Color(1.0, 0.5, 0.15, 0.6), 0.35, false)
		main.shake(0.25); Game.play("hit", 0.0, 0.6); Game.play("roar", -14.0, 2.5)
		queue_free()


# Pente trop raide pour la physique mais praticable : on aide le héros à monter (comme sur Albion, on ne reste jamais coincé)
var climb_t := 0.0
# silhouette : n'apparaît que quand une maison cache le héros
var ghost: ShaderMaterial
var ghost_k := 0.0
var ghost_t := 0.0
var ghost_on := false
func _ghost_update(dt: float) -> void:
	if ghost == null: return
	ghost_t -= dt
	if ghost_t <= 0.0:
		ghost_t = 0.15
		ghost_on = global_position.x < 300.0 and main.world.house_hides(global_position)
	var nk: float = move_toward(ghost_k, 1.0 if ghost_on else 0.0, dt * 4.0)
	if nk != ghost_k: ghost_k = nk; ghost.set_shader_parameter("k", ghost_k)

func _climb_assist(want: Vector3, dt: float) -> void:
	var p := global_position
	if p.x > 300.0 or want.length() < 1.0 or dead: climb_t = 0.0; return
	var got := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if got > want.length() * 0.55: climb_t = 0.0; return
	climb_t += dt
	if climb_t < 0.12: return
	var w: World = main.world
	var d := Vector3(want.x, 0, want.z).normalized()
	for r: float in [0.7, 1.1]:
		var q := p + d * r
		if not w.walkable(q.x, q.z): return
		var gy: float = w.ground_y(q.x, q.z)
		if gy - p.y < 2.2 and gy - p.y > -0.3:
			global_position = Vector3(p.x + d.x * min(r, want.length() * dt * 1.2 + 0.05), max(p.y, w.ground_y(p.x + d.x * 0.3, p.z + d.z * 0.3)) + 0.05, p.z + d.z * min(r, want.length() * dt * 1.2 + 0.05))
			global_position.y = max(global_position.y, w.ground_y(global_position.x, global_position.z) + 0.02)
			return

# L'eau profonde arrête le héros (on glisse le long de la berge)
var water_t := 0.0
func _block_water(dt: float) -> void:
	var w: World = main.world; var p := global_position; var look := 0.45
	if not w.walkable(p.x, p.z):
		# tombé à l'eau : on nage vers la berge la plus proche et on remonte tout seul
		water_t += dt
		var best := Vector3.ZERO; var bd := 99.0
		for i in 16:
			var a := TAU * i / 16.0
			for r in [1.0, 2.0, 3.5, 5.0, 7.0]:
				if w.walkable(p.x + cos(a) * r, p.z + sin(a) * r):
					if r < bd: bd = r; best = Vector3(cos(a), 0, sin(a))
					break
		if best != Vector3.ZERO:
			var inp := Vector3(velocity.x, 0, velocity.z)
			# on garde la direction du joueur si elle va vers la terre, sinon on aide
			var dirv := best if inp.length() < 0.5 or inp.normalized().dot(best) < 0.3 else inp.normalized()
			var sp: float = max(4.5, inp.length())
			velocity.x = dirv.x * sp; velocity.z = dirv.z * sp
			if bd <= 2.0 or is_on_wall() or water_t > 0.6:
				# la berge est trop raide : on grimpe dessus
				var tgt: Vector3 = p + best * min(bd + 0.6, 2.4)
				if w.walkable(tgt.x, tgt.z) and (is_on_wall() or water_t > 1.2):
					global_position = Vector3(tgt.x, w.height(tgt.x, tgt.z) + 0.25, tgt.z); velocity = Vector3.ZERO; water_t = 0.0
		return
	water_t = 0.0
	if w.walkable(p.x + velocity.x * dt + sign(velocity.x) * look, p.z + velocity.z * dt + sign(velocity.z) * look): return
	if w.walkable(p.x + velocity.x * dt + sign(velocity.x) * look, p.z): velocity.z = 0.0; return
	if w.walkable(p.x, p.z + velocity.z * dt + sign(velocity.z) * look): velocity.x = 0.0; return
	velocity.x = 0.0; velocity.z = 0.0
