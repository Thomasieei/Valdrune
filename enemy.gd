extends CharacterBody3D
class_name Enemy
# Monstres : squelettes, animaux sauvages, duellistes, boss de groupe.
# Approche, télégraphe rouge au sol, frappe ; recul et clignotement quand on les touche.

const SK := "res://assets/skeletons/"
const AN := "res://assets/animals/"
const ANIMAL_ANIMS := {"Idle_B": "Idle", "Running_A": "Gallop", "Walking_A": "Walk", "Hit_A": "Idle_HitReact_Left", "Hit_B": "Idle_HitReact_Left", "Death_A": "Death"}
const KINDS := {
	"minion": {"model": SK + "Skeleton_Minion.glb", "name": "Squelette", "hp": 1.0, "dmg": 1.0, "speed": 3.6, "range": 1.9, "wind": 0.6, "cd": 1.5, "weapon": SK + "Skeleton_Blade.gltf"},
	"warrior": {"model": SK + "Skeleton_Warrior.glb", "name": "Guerrier squelette", "hp": 1.7, "dmg": 1.35, "speed": 3.1, "range": 2.1, "wind": 0.75, "cd": 1.9, "weapon": SK + "Skeleton_Axe.gltf", "shield": SK + "Skeleton_Shield_Small_A.gltf"},
	"rogue": {"model": SK + "Skeleton_Rogue.glb", "name": "Rôdeur squelette", "hp": 0.85, "dmg": 0.9, "speed": 4.6, "range": 1.8, "wind": 0.45, "cd": 1.1, "weapon": SK + "Skeleton_Blade.gltf"},
	"mage": {"model": SK + "Skeleton_Mage.glb", "name": "Mage squelette", "hp": 0.8, "dmg": 1.1, "speed": 3.0, "range": 8.0, "wind": 0.8, "cd": 2.2, "weapon": SK + "Skeleton_Staff.gltf", "ranged": true},
	"boss": {"model": SK + "Skeleton_Warrior.glb", "name": "Seigneur d'Os", "hp": 14.0, "dmg": 1.7, "speed": 3.4, "range": 3.6, "wind": 0.9, "cd": 1.7, "weapon": SK + "Skeleton_Axe.gltf", "shield": SK + "Skeleton_Shield_Large_A.gltf", "scale": 2.1},
	# ——— Animaux sauvages ———
	"renard": {"animal": true, "model": AN + "fox.glb", "name": "Renard", "hp": 0.7, "dmg": 0.8, "speed": 5.2, "range": 1.6, "wind": 0.4, "cd": 1.0, "atk": "Attack", "scale": 0.28, "rad": 0.45, "h": 1.35, "aggro": 7.0},
	"loup": {"animal": true, "model": AN + "wolf.glb", "name": "Loup", "hp": 1.0, "dmg": 1.15, "speed": 5.6, "range": 2.1, "wind": 0.45, "cd": 1.15, "atk": "Attack", "scale": 0.41, "rad": 0.6, "h": 1.8, "aggro": 11.0},
	"cerf": {"animal": true, "model": AN + "stag.glb", "name": "Cerf", "hp": 1.4, "dmg": 1.2, "speed": 4.6, "range": 2.4, "wind": 0.55, "cd": 1.5, "atk": "Attack_Headbutt", "scale": 0.56, "rad": 0.7, "h": 2.8, "aggro": 6.0},
	"taureau": {"animal": true, "model": AN + "bull.glb", "name": "Taureau", "hp": 2.0, "dmg": 1.5, "speed": 4.4, "range": 2.6, "wind": 0.7, "cd": 1.8, "atk": "Attack_Headbutt", "scale": 0.46, "rad": 0.9, "h": 2.5, "aggro": 9.0},
	# ——— Boss de groupe (4 combattants minimum) ———
	"alpha": {"animal": true, "model": AN + "wolf.glb", "name": "Loup Noir Ancien", "hp": 55.0, "dmg": 2.6, "speed": 5.4, "range": 3.4, "wind": 0.85, "cd": 1.5, "atk": "Attack", "scale": 1.0, "rad": 1.6, "h": 4.2, "group": true, "tint": Color(1.7, 1.35, 2.3), "aggro": 14.0},
	"taureau_guerre": {"animal": true, "model": AN + "bull.glb", "name": "Taureau de Guerre", "hp": 65.0, "dmg": 2.8, "speed": 4.6, "range": 3.6, "wind": 0.95, "cd": 1.8, "atk": "Attack_Headbutt", "scale": 1.05, "rad": 1.9, "h": 5.2, "group": true, "tint": Color(0.45, 0.12, 0.1), "aggro": 14.0},
	"roi_cerf": {"animal": true, "model": AN + "stag.glb", "name": "Roi-Cerf", "hp": 60.0, "dmg": 2.5, "speed": 5.0, "range": 3.6, "wind": 0.9, "cd": 1.6, "atk": "Attack_Headbutt", "scale": 1.15, "rad": 1.7, "h": 5.6, "group": true, "tint": Color(0.85, 0.8, 0.55), "aggro": 14.0},
	# ——— Bandits (raids sur l'île) ———
	"bandit": {"model": "res://assets/heroes/Rogue.glb", "name": "Bandit", "hp": 1.8, "dmg": 1.25, "speed": 4.6, "range": 2.1, "wind": 0.5, "cd": 1.2, "aggro": 12.0},
	# ——— Duelliste (humain) ———
	"duel": {"model": "res://assets/heroes/Knight.glb", "name": "Duelliste", "hp": 7.0, "dmg": 1.55, "speed": 5.0, "range": 2.2, "wind": 0.42, "cd": 0.95, "duel": true},
}
var main: Node
var kind := "minion"
var def: Dictionary
var tier := 1
var hp := 10.0
var max_hp := 10.0
var dead := false
var radius := 0.5
var home := Vector3.ZERO
var state := "idle"
var t_state := 0.0
var atk_cd := 0.0
var stagger := 0.0
var knock := Vector3.ZERO
var ch: Dictionary
var ap: AnimationPlayer
var cur := ""
var flash_mat: StandardMaterial3D
var bar_mat: ShaderMaterial
var bar_root: Node3D
var name_lbl: Label3D
var tele: MeshInstance3D
var tele_pos := Vector3.ZERO
var wander_to := Vector3.ZERO
var camp: Dictionary
var is_boss := false
var phase := 0
var elite := false
var animal := false
var group_boss := false
var duel_info := {}
var tgt: Node3D
var shown_ratio := 1.0
var evade_cd := 0.0
var leash := 24.0
var immune_toast := 0.0
var body_h := 2.0
var slow_t := 0.0
var bleed_t := 0.0
var bleed_dps := 0.0
var bleed_tick := 0.0
var bleed_src: Node3D
var last_from: Node3D            # dernier à l'avoir frappé (le butin revient au tueur)
var flow_t := 0.0

func slow(d: float) -> void:
	slow_t = max(slow_t, d)
	_tint_flash(Color(0.55, 0.85, 1.0))
func bleed(dps: float, d: float, src: Node3D) -> void:
	bleed_t = d; bleed_dps = dps; bleed_src = src
func _tint_flash(c: Color) -> void:
	flash_mat.albedo_color = Color(c.r, c.g, c.b, 0.6); create_tween().tween_property(flash_mat, "albedo_color:a", 0.0, 0.5)

static var bar_shader: Shader
static func _bar_shader() -> Shader:
	if bar_shader: return bar_shader
	bar_shader = Shader.new()
	bar_shader.code = """shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;
uniform float fill = 1.0;
uniform float trail = 1.0;
uniform vec4 col : source_color = vec4(0.91, 0.27, 0.18, 1.0);
void vertex(){
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment(){
	vec2 uv = UV;
	float edge = step(0.06, uv.y) * step(uv.y, 0.94) * step(0.012, uv.x) * step(uv.x, 0.988);
	vec3 c = vec3(0.05, 0.05, 0.06);
	if (edge > 0.5) {
		if (uv.x < fill) c = col.rgb * (0.85 + 0.3 * (1.0 - uv.y));
		else if (uv.x < trail) c = vec3(1.0, 0.92, 0.7);
		else c = vec3(0.16, 0.12, 0.12);
	}
	ALBEDO = c;
	ALPHA = 0.95;
}"""
	return bar_shader

func setup(m: Node, k: String, t: int, pos: Vector3, c: Dictionary, is_elite := false, extra := {}) -> void:
	main = m; kind = k; def = KINDS[k].duplicate(); tier = t; home = pos; camp = c; is_boss = k == "boss"; elite = is_elite
	for key in extra: def[key] = extra[key]
	animal = def.get("animal", false); group_boss = def.get("group", false)
	if group_boss: is_boss = true; leash = 18.0; def.speed = 4.2; def.aggro = 7.0
	if def.get("duel", false): duel_info = extra; leash = 32.0
	if elite: def.hp *= 2.6; def.dmg *= 1.3; def.scale = def.get("scale", 1.0) * 1.28; def.name = "Élite · " + def.name
	if def.get("chief", false):
		# chef de guerre : un vrai boss de région, gros, lent à tomber, qui tape fort
		elite = false; is_boss = true; leash = 22.0
		def.hp *= 9.0; def.dmg *= 1.6; def.scale = def.get("scale", 1.0) * 1.75; def.name = "Chef de guerre · " + def.name
	max_hp = Game.mob_hp(t) * def.hp; hp = max_hp
	var sc: float = def.get("scale", 1.0)
	var el: float = 1.28 if elite else 1.0
	radius = 0.5 * sc if not animal else def.rad * el
	body_h = 2.25 * sc if not animal else def.h * el
	var col := CollisionShape3D.new(); var cap := CapsuleShape3D.new(); cap.radius = 0.42 * sc if not animal else radius * 0.8; cap.height = max(1.7 * sc if not animal else body_h * 0.6, cap.radius * 2.0 + 0.1); col.shape = cap; col.position.y = cap.height * 0.5; add_child(col)
	if animal:
		var model: Node3D = load(def.model).instantiate(); model.scale = Vector3.ONE * sc; add_child(model)
		ap = model.find_child("AnimationPlayer", true, false)
		for an in ["Idle", "Walk", "Gallop"]:
			if ap.has_animation(an): ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		ch = {"root": model, "ap": ap, "skel": null}
		for mi in Chars.meshes(model): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bl := Chars.blob(radius * 1.6 / sc); model.add_child(bl)
		if def.has("tint"): _tint_all(model, def.tint)
		elif t >= 4: _tint_all(model, Color(1, 1, 1).lerp(Game.TIER_COL[t], 0.22))
	else:
		ch = Chars.make(def.model); ch.root.scale = Vector3.ONE * sc; add_child(ch.root); ap = ch.ap
		Chars.attach(ch, "handslot.r", def.get("weapon", ""))
		if def.has("shield"): Chars.attach(ch, "handslot.l", def.shield)
	flash_mat = StandardMaterial3D.new(); flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; flash_mat.albedo_color = Color(1, 1, 1, 0.0); flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in Chars.meshes(ch.root):
		mi.material_overlay = flash_mat
		if k == "boss" and mi.name.contains("Eyes"):
			var em := StandardMaterial3D.new(); em.albedo_color = Color(1, 0.2, 0.1); em.emission_enabled = true; em.emission = Color(1, 0.15, 0.05); em.emission_energy_multiplier = 3.0; mi.material_override = em
	var colr: Color = Game.TIER_COL[t]
	if elite or group_boss or duel_info.size() > 0:
		var aura := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = max(0.9, radius * 1.6); cm.bottom_radius = cm.top_radius; cm.height = 0.02; aura.mesh = cm
		var am := StandardMaterial3D.new(); am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		am.albedo_color = Color(1.0, 0.75, 0.2, 0.45) if not group_boss else Color(0.75, 0.2, 1.0, 0.5); am.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		aura.material_override = am; aura.position.y = 0.06; aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(aura)
	# plaque de nom (couleur du tier) + barre de vie qui descend à chaque coup
	var big := is_boss or duel_info.size() > 0
	var bar_h: float = body_h + 0.2
	bar_root = Node3D.new(); bar_root.position.y = bar_h; add_child(bar_root)
	name_lbl = Label3D.new(); name_lbl.text = "%s T%d" % [def.name, t] + ("  · GROUPE 4+" if group_boss else ""); name_lbl.font_size = 40 if not big else 56; name_lbl.outline_size = 12
	# code couleur clair : monstres en ROUGE (élites en or, boss de groupe en violet) · joueurs en bleu · PNJ en or pâle
	name_lbl.modulate = Color("#ff7a68") if not elite else Color("#ffc940")
	if group_boss: name_lbl.modulate = Color("#d58bff")
	name_lbl.outline_modulate = Color(0, 0, 0, 0.9)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; name_lbl.pixel_size = 0.007; name_lbl.position.y = 0.3; name_lbl.no_depth_test = true; name_lbl.render_priority = 5; bar_root.add_child(name_lbl)
	var bar := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1.3, 0.16) * (1.7 if big else 1.0); bar.mesh = q
	bar_mat = ShaderMaterial.new(); bar_mat.shader = _bar_shader(); bar_mat.render_priority = 4
	if group_boss: bar_mat.set_shader_parameter("col", Color("#b04dff"))
	bar.material_override = bar_mat; bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; bar_root.add_child(bar)
	bar_root.visible = big
	position = pos
	rotation.y = randf() * TAU
	play("Idle_B")
	wander_to = pos
	floor_snap_length = 0.6

func _tint_all(n: Node, c: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				var mt: BaseMaterial3D = src.duplicate(); mt.albedo_color = mt.albedo_color * c; mi.set_surface_override_material(i, mt)
	for chn in n.get_children(): _tint_all(chn, c)

func play(n: String, speed := 1.0, blend := 0.15, restart := false) -> void:
	if animal:
		if n == "Interact" or n == "Use_Item" or n == "Throw": n = def.atk
		else: n = ANIMAL_ANIMS.get(n, n)
	if n == cur and not restart: ap.speed_scale = speed; return
	cur = n; ap.play(n, blend); ap.speed_scale = speed
	if restart: ap.seek(0.0, true)

func _process(dt: float) -> void:
	if slow_t > 0.0: slow_t -= dt
	if bleed_t > 0.0 and not dead:
		bleed_t -= dt; bleed_tick -= dt
		if bleed_tick <= 0.0:
			bleed_tick = 0.5; var src: Node3D = bleed_src if is_instance_valid(bleed_src) else main.player
			take_hit(bleed_dps * 0.5, src, 0.0)
	# la barre suit la vie en temps réel ; la partie claire montre le dernier coup
	if not bar_root.visible: return
	var r: float = clamp(hp / max_hp, 0.0, 1.0)
	shown_ratio = move_toward(shown_ratio, r, dt * 0.8) if shown_ratio > r else r
	bar_mat.set_shader_parameter("fill", r); bar_mat.set_shader_parameter("trail", shown_ratio)
	if immune_toast > 0.0: immune_toast -= dt

func take_hit(amount: float, from: Node3D, push: float) -> void:
	if dead or state == "wait": return
	if group_boss and main.group_near(global_position, 26.0) < 4:
		Fx.number(main, global_position + Vector3(0, body_h + 0.4, 0), "IMMUNISÉ", Color("#d58bff"))
		if immune_toast <= 0.0:
			immune_toast = 4.0; main.hud.toast("Boss de groupe : il faut être au moins 4 (toi + 3 mercenaires) pour le blesser", Color("#d58bff"), true)
		if state == "idle": aggro()
		return
	if duel_info.size() > 0 and evade_cd <= 0.0 and state != "windup" and randf() < 0.22:
		# le duelliste esquive parfois
		evade_cd = 2.2; var away: Vector3 = global_position - from.global_position; away.y = 0
		knock = away.normalized() * 13.0; Fx.number(main, global_position + Vector3(0, 2.3, 0), "esquive !", Color("#9fe4ff"))
		Fx.burst(main, global_position + Vector3(0, 0.3, 0), Color(0.85, 0.85, 0.9), 10, 3.0, 0.4, 0.4)
		return
	var crit_hit := false
	if from is Player:
		# coup critique (×1,6) et vol de vie, selon l'équipement
		var st: Dictionary = Game.stats()
		if randf() < st.crit: amount *= 1.6; crit_hit = true
		if st.steal > 0.0:
			var P: Player = from; P.hp = min(P.max_hp, P.hp + amount * st.steal)
	hp -= amount
	if from != null and is_instance_valid(from): last_from = from
	var by_me: bool = from == main.player or from is Ally
	bar_root.visible = true
	flash_mat.albedo_color.a = 0.85
	create_tween().tween_property(flash_mat, "albedo_color:a", 0.0, 0.18)
	if by_me:
		var crit := crit_hit or amount > Game.weapon_dmg(max(1, Game.S.gear.epee)) * 1.4
		Fx.number(main, global_position + Vector3(0, body_h, 0), str(int(amount)), Color("#ffe066") if crit else Color.WHITE, crit)
		Fx.burst(main, global_position + Vector3(0, 1.1, 0), Color(1, 0.95, 0.85) if not animal else Color(0.85, 0.2, 0.15), 10, 4.5, 0.22, 0.4)
	elif global_position.distance_to(main.player.global_position) < 16.0:
		# coups des autres joueurs : petits chiffres gris, discrets
		Fx.number(main, global_position + Vector3(0, body_h, 0), str(int(amount)), Color(0.72, 0.74, 0.78), false, true)
	var dir: Vector3 = global_position - from.global_position; dir.y = 0
	if not is_boss: knock = dir.normalized() * push
	else: knock = dir.normalized() * push * 0.15
	if state == "idle": aggro()
	if hp <= 0.0: die(); return
	if not is_boss and state != "windup":
		stagger = 0.22; play("Hit_A" if randf() < 0.5 else "Hit_B", 1.6, 0.04, true)
	elif state == "windup" and not is_boss and push > 4.0 and duel_info.is_empty():
		# un coup lourd interrompt l'attaque
		_cancel_tele(); state = "chase"; stagger = 0.35; play("Hit_B", 1.4, 0.04, true)

func aggro() -> void:
	if state == "idle":
		state = "chase"
		if is_boss: main.on_boss_aggro(self)
		for e in camp.get("members", []):
			if is_instance_valid(e) and not e.dead and e.state == "idle": e.state = "chase"

func die() -> void:
	dead = true; state = "dead"; _cancel_tele(); bar_root.visible = false
	collision_layer = 0; collision_mask = 1
	play("Death_A", 1.0, 0.05, true)
	var mine: bool = last_from == null or not is_instance_valid(last_from) or last_from == main.player or last_from is Ally
	Game.play_at("death", global_position, -3.0, 1.1 if not is_boss else 0.6, mine)
	main.on_enemy_death(self)
	var tw := create_tween(); tw.tween_interval(2.4); tw.tween_property(ch.root, "position:y", -1.6, 1.4); tw.tween_callback(func(): main.enemies.erase(self); queue_free())

func _cancel_tele() -> void:
	if tele and is_instance_valid(tele): tele.queue_free()
	tele = null

# cible : le héros, ou un mercenaire plus proche
func _pick_target() -> void:
	var P: Player = main.player
	var best: Node3D = P if not P.dead else null
	var bd: float = global_position.distance_to(P.global_position) if best else 1e9
	if duel_info.is_empty():
		for a in main.allies:
			if not is_instance_valid(a) or a.dead: continue
			var d: float = global_position.distance_to(a.global_position) - 1.5   # léger biais vers le héros
			if d < bd: bd = d; best = a
		for b in main.bots:
			if not is_instance_valid(b) or b.dead or not b.visible: continue
			var d2: float = global_position.distance_to(b.global_position) - 1.0
			if d2 < bd and (state != "idle" or d2 < 6.0): bd = d2; best = b
	tgt = best

func _physics_process(dt: float) -> void:
	if not main.in_instance(): velocity.y = 0.0
	elif not is_on_floor(): velocity.y -= 30.0 * dt
	else: velocity.y = -1.0
	if dead:
		velocity.x = 0; velocity.z = 0
		if main.in_instance(): move_and_slide()
		return
	evade_cd -= dt
	if state != "windup" and (tgt == null or Engine.get_physics_frames() % 15 == 0): _pick_target()
	var P: Player = main.player
	var T = tgt if tgt and is_instance_valid(tgt) else P
	var tdead: bool = T.dead
	var to: Vector3 = T.global_position - global_position; to.y = 0
	var dist := to.length()
	var pd: float = global_position.distance_to(P.global_position)
	atk_cd -= dt; t_state += dt
	var want := Vector3.ZERO
	knock = knock.lerp(Vector3.ZERO, min(1.0, dt * 9.0))
	if stagger > 0.0:
		stagger -= dt
	else:
		match state:
			"idle":
				if pd < def.get("aggro", 9.0) * (0.5 if P.mounted else 1.0) and not P.dead and duel_info.is_empty() and _sees(P.global_position): aggro()
				elif global_position.distance_to(wander_to) > 0.8:
					want = (wander_to - global_position).normalized() * 1.3; want.y = 0
				elif randf() < dt * 0.25:
					wander_to = home + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			"chase":
				var see: bool = _sees(T.global_position)
				if tdead or global_position.distance_to(home) > leash or (group_boss and dist > 16.0):
					state = "return"
				elif not see:
					# un mur entre nous : on contourne par les salles et les couloirs (pas d'attaque à travers les murs)
					want = main.world.dungeon.steer(global_position) * def.speed
				elif dist > def.range * 0.92:
					want = to.normalized() * def.speed
				elif atk_cd <= 0.0:
					_start_attack(T)
				else:
					rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-dt * 10.0))
				if def.get("ranged", false) and dist < 4.5: want = -to.normalized() * def.speed * 0.8
			"return":
				if duel_info.size() > 0: main.duel_reset(self); return     # duel fini (fuite, mort) : on ne le fait pas marcher jusqu'à chez lui
				want = (home - global_position); want.y = 0
				if not _sees(home):
					# en donjon : il reste là où il est plutôt que de foncer dans un mur
					state = "idle"; home = global_position; wander_to = home; hp = max_hp; want = Vector3.ZERO
				if want.length() < 1.0:
					state = "idle"; hp = max_hp; bar_root.visible = is_boss or duel_info.size() > 0
					if duel_info.size() > 0: main.duel_reset(self)
				want = want.normalized() * def.speed * 1.2
			"windup":
				rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-dt * (4.0 if not def.get("ranged", false) else 10.0)))
				if t_state >= def.wind: _strike(T)
			"recover":
				if t_state > 0.35: state = "chase"
			"wait":
				rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), 1.0 - exp(-dt * 8.0))
	if want.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(want.x, want.z), 1.0 - exp(-dt * 10.0))
	if slow_t > 0.0: want *= 0.45
	velocity.x = want.x + knock.x; velocity.z = want.z + knock.z
	var hv := Vector3(velocity.x, 0, velocity.z)
	# en donjon on regarde plus loin devant (la largeur du corps) : le monstre ne rentre plus dans les murs
	var look: float = (radius + 0.7) if main.in_instance() else 0.0
	var nx := global_position + hv * 0.12 + (hv.normalized() * look if hv.length() > 0.1 else Vector3.ZERO)
	if not main.world.walkable(nx.x, nx.z):
		# glisse le long du bord au lieu de rester collé
		if main.world.walkable(nx.x, global_position.z): velocity.z = 0.0
		elif main.world.walkable(global_position.x, nx.z): velocity.x = 0.0
		else: velocity.x = 0.0; velocity.z = 0.0
		knock = Vector3.ZERO
	if main.in_instance(): move_and_slide()
	else:
		# dehors : déplacement collé au sol, sans moteur physique (beaucoup moins coûteux)
		global_position.x += velocity.x * dt; global_position.z += velocity.z * dt
		global_position.y = main.world.ground_y(global_position.x, global_position.z)
	if stagger <= 0.0 and state != "windup" and state != "recover":
		var sp := Vector2(velocity.x, velocity.z).length()
		if sp > 0.5: play("Running_A" if sp > 2.0 else "Walking_A", clamp(sp / (4.0 if not animal else 5.0), 0.6, 1.4))
		else: play("Idle_B")

func _sees(p: Vector3) -> bool:
	var inst = main.world.dungeon
	return inst == null or not inst.has_method("sight") or inst.sight(global_position, p, max(0.45, radius * 0.9))

func _start_attack(T) -> void:
	state = "windup"; t_state = 0.0
	var fwd: Vector3 = (T.global_position - global_position); fwd.y = 0; fwd = fwd.normalized()
	rotation.y = atan2(fwd.x, fwd.z)
	var anim := "Interact" if not def.get("ranged", false) else "Use_Item"
	if duel_info.size() > 0: anim = "Throw"
	play(anim, (0.9 if not is_boss else 0.7) * (1.6 if duel_info.size() > 0 else 1.0), 0.08, true)
	var sc: float = def.get("scale", 1.0)
	if def.get("ranged", false):
		tele_pos = T.global_position
		tele = Fx.disc(main, tele_pos, 1.6, Color(1, 0.15, 0.1, 0.38), def.wind)
	elif (is_boss or duel_info.size() > 0) and phase % 3 == 2:
		# grande attaque de zone : il faut s'éloigner
		tele_pos = global_position
		var r := 5.5 if is_boss else 3.8
		if group_boss: r = 4.0 + radius * 1.5
		tele = Fx.disc(main, tele_pos, r, Color(1, 0.1, 0.05, 0.38), def.wind * 1.3)
		t_state = -def.wind * 0.3
	else:
		tele_pos = global_position + fwd * def.range * 0.7
		tele = Fx.disc(main, tele_pos, def.range * 0.75 + (0.4 if is_boss else 0.25), Color(1, 0.15, 0.1, 0.38), def.wind)

func _strike(T) -> void:
	state = "recover"; t_state = 0.0; atk_cd = def.cd * randf_range(0.85, 1.15)
	var r: float = tele.scale.x if tele and is_instance_valid(tele) else 1.5
	_cancel_tele()
	if is_boss or duel_info.size() > 0: phase += 1
	# le son ne compte « pour toi » que si c'est toi (ou ton groupe) qui es visé
	var on_me: bool = T == main.player or T is Ally
	if def.get("ranged", false):
		Fx.burst(main, tele_pos + Vector3(0, 0.4, 0), Color(0.75, 0.35, 1.0), 22, 5.0, 0.4, 0.5)
		Game.play_at("mine", tele_pos, -6.0, 0.5, on_me)
	else:
		Fx.burst(main, tele_pos + Vector3(0, 0.3, 0), Color(0.85, 0.8, 0.7), 12, 4.0, 0.35, 0.4)
		Game.play_at("hit", tele_pos, -6.0, 0.7, on_me)
		if is_boss and on_me: main.shake(0.35)
	var dmg_v: float = Game.mob_dmg(tier) * def.dmg
	# tous ceux qui sont dans le cercle prennent le coup
	var victims: Array = [main.player]
	if duel_info.is_empty(): victims += main.allies + main.bots
	for v in victims:
		if not is_instance_valid(v) or v.dead: continue
		var d: float = Vector2(v.global_position.x - tele_pos.x, v.global_position.z - tele_pos.z).length()
		if d < r + 0.35: v.hurt(dmg_v * randf_range(0.9, 1.1), self)
	# le Seigneur d'Os invoque des renforts à 60 % et 30 %
	if kind == "boss" and ((hp < max_hp * 0.6 and phase < 100) or (hp < max_hp * 0.3 and phase < 200)):
		phase = 100 if hp >= max_hp * 0.3 else 200
		main.boss_summon(self)
