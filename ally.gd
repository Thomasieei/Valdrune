extends CharacterBody3D
class_name Ally
# Mercenaire : suit le héros, attaque ce qui le menace, le clerc soigne le groupe

const TYPES := {
	"guerrier": {"name": "Guerrier", "model": "Knight", "weapon": "sword_B", "shield": "shield_round", "hp": 1.3, "dmg": 0.55, "range": 2.1, "cd": 1.1, "desc": "Encaisse les coups, attire les monstres"},
	"rodeuse": {"name": "Rôdeuse", "model": "Rogue", "weapon": "dagger_A", "hp": 0.8, "dmg": 0.8, "range": 1.9, "cd": 0.75, "desc": "Frappe vite et fort"},
	"clerc": {"name": "Clerc", "model": "Mage", "weapon": "staff", "hp": 0.75, "dmg": 0.3, "range": 2.0, "cd": 1.3, "heal": true, "desc": "Soigne le groupe toutes les 5 s"},
}
const NAMES := ["Aron", "Bertille", "Cassian", "Doria", "Elric", "Faustine", "Gauvain", "Isaure", "Jory", "Maëlle", "Néris", "Oswin"]

var stuck_t := 0.0
var main: Node
var type := "guerrier"
var def: Dictionary
var tier := 1
var nm := ""
var hp := 100.0
var max_hp := 100.0
var dead := false
var ch: Dictionary
var ap: AnimationPlayer
var cur := ""
var slot := 0
var atk_cd := 0.0
var heal_cd := 3.0
var target: Node3D
var flash_mat: StandardMaterial3D
var bar: MeshInstance3D
var bar_mat: ShaderMaterial
var idle_t := 0.0

func setup(m: Node, d: Dictionary, i: int) -> void:
	main = m; type = d.type; tier = int(d.tier); nm = d.name; slot = i; def = TYPES[type]
	max_hp = Game.armor_hp(tier) * def.hp; hp = max_hp
	collision_layer = 0; collision_mask = 0
	ch = Chars.make("res://assets/heroes/%s.glb" % def.model); add_child(ch.root); ap = ch.ap
	Chars.attach(ch, "handslot.r", Game.W % def.weapon)
	if def.has("shield"): Chars.attach(ch, "handslot.l", Game.W % def.shield)
	var tint: Color = Color(1, 1, 1).lerp(Game.TIER_COL[tier], 0.0 if tier <= 1 else 0.25)
	flash_mat = StandardMaterial3D.new(); flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; flash_mat.albedo_color = Color(1, 0.3, 0.25, 0.0); flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in Chars.meshes(ch.root):
		mi.material_overlay = flash_mat
		if tint != Color(1, 1, 1):
			for k in mi.mesh.get_surface_count():
				var src = mi.mesh.surface_get_material(k)
				if src is StandardMaterial3D:
					var mt: StandardMaterial3D = src.duplicate(); mt.albedo_color = tint; mi.set_surface_override_material(k, mt)
	var l := Label3D.new(); l.text = "%s · %s T%d" % [nm, def.name, tier]; l.font_size = 34; l.outline_size = 10; l.modulate = Color("#9dffb0"); l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.0065; l.position.y = 2.55; l.no_depth_test = true; add_child(l)
	bar = MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(1.0, 0.11); bar.mesh = q
	bar_mat = ShaderMaterial.new(); bar_mat.shader = Enemy._bar_shader(); bar_mat.set_shader_parameter("col", Color("#4fd36a")); bar_mat.render_priority = 4
	bar.material_override = bar_mat; bar.position.y = 2.3; bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(bar)
	floor_snap_length = 0.6
	_play("Idle_A")

func _play(n: String, sp := 1.0, restart := false) -> void:
	if n == cur and not restart: ap.speed_scale = sp; return
	cur = n; ap.play(n, 0.15); ap.speed_scale = sp
	if restart: ap.seek(0.0, true)

func dmg() -> float: return Game.weapon_dmg(tier) * def.dmg

func hurt(amount: float, from: Node3D) -> void:
	if dead: return
	hp -= amount
	flash_mat.albedo_color.a = 0.6; create_tween().tween_property(flash_mat, "albedo_color:a", 0.0, 0.25)
	Fx.number(main, global_position + Vector3(0, 2.3, 0), str(int(amount)), Color("#ffb09a"))
	if hp <= 0.0:
		dead = true; hp = 0; _play("Death_A", 1.0, true)
		main.hud.toast("%s (%s) est tombé au combat…" % [nm, def.name], Color("#ff9a8a"))
		main.on_ally_death(self)
		var tw := create_tween(); tw.tween_interval(2.5); tw.tween_property(ch.root, "position:y", -1.6, 1.2); tw.tween_callback(queue_free)
	elif cur != "Throw": _play("Hit_A", 1.6, true)

func _process(_dt: float) -> void:
	bar_mat.set_shader_parameter("fill", clamp(hp / max_hp, 0.0, 1.0)); bar_mat.set_shader_parameter("trail", clamp(hp / max_hp, 0.0, 1.0))

func _physics_process(dt: float) -> void:
	if dead: return
	var P: Player = main.player
	if main.arena != null: velocity = Vector3.ZERO; _play("Idle_A"); return      # l'arène se joue seul
	atk_cd -= dt; heal_cd -= dt
	# soins du clerc
	if def.get("heal", false) and heal_cd <= 0.0:
		heal_cd = 5.0
		var healed := false
		for u in [P] + main.allies:
			if not is_instance_valid(u) or u.dead or u.hp >= u.max_hp: continue
			if u.global_position.distance_to(global_position) > 14.0: continue
			var h: float = u.max_hp * 0.08; u.hp = min(u.max_hp, u.hp + h); healed = true
			Fx.number(main, u.global_position + Vector3(0, 2.5, 0), "+%d" % int(h), Color("#7dff8a"))
		if healed: Fx.burst(main, global_position + Vector3(0, 1.2, 0), Color(0.5, 1.0, 0.6), 14, 3.0, 0.4, 0.6, -2.0)
	# cible : un monstre en combat près du héros (jamais pendant un duel : c'est un 1 contre 1)
	if main.duel_enemy == null and (target == null or not is_instance_valid(target) or target.dead or Engine.get_physics_frames() % 20 == slot):
		target = null; var bd := 13.0
		for e in main.enemies:
			if e.dead or e.state == "idle" or e.state == "return": continue
			var d: float = e.global_position.distance_to(P.global_position)
			if d < bd: bd = d; target = e
	if main.duel_enemy != null: target = null
	elif main.selected_enemy != null and is_instance_valid(main.selected_enemy) and not main.selected_enemy.dead and main.selected_enemy.state != "idle" and P.global_position.distance_to(main.selected_enemy.global_position) < 15.0: target = main.selected_enemy
	if global_position.distance_to(P.global_position) > 32.0 and not P.dead:
		# resté trop loin (téléportation, donjon…) : il rejoint le héros
		var sp0 := P.global_position + Vector3(sin(slot * 2.1) * 2.2, 0.0, cos(slot * 2.1) * 2.2); global_position = sp0; velocity = Vector3.ZERO
	var want := Vector3.ZERO
	var look_at_p := Vector3.ZERO
	if target and is_instance_valid(target) and not target.dead:
		var to: Vector3 = target.global_position - global_position; to.y = 0
		var reach: float = def.range + target.radius
		if to.length() > reach * 0.9: want = to.normalized() * 6.0
		elif atk_cd <= 0.0:
			atk_cd = float(def.cd) * randf_range(0.9, 1.1); _play("Throw", 2.0, true)
			var e = target
			var epoch: int = P.action_epoch
			get_tree().create_timer(0.12).timeout.connect(func():
				if epoch != main.player.action_epoch or not is_instance_valid(e) or e.dead or dead: return
				if global_position.distance_to(e.global_position) <= reach + 1.0: e.take_hit(dmg() * randf_range(0.9, 1.1), self, 1.5))
		look_at_p = to
	else:
		# suit le héros en formation
		var ang: float = P.yaw + PI + (slot - 1) * 0.9
		var spot := P.global_position + Vector3(sin(ang), 0, cos(ang)) * 2.6
		var to2 := spot - global_position; to2.y = 0
		if to2.length() > 0.7: want = to2.normalized() * min(P.speed() * 1.15, to2.length() * 4.0 + 2.0)
	velocity.x = want.x; velocity.z = want.z
	var nx := global_position + Vector3(velocity.x, 0, velocity.z) * 0.12
	if not main.world.walkable(nx.x, nx.z):
		velocity.x = 0.0; velocity.z = 0.0
		# bloqué par une falaise alors que le héros s'éloigne : il le rejoint
		stuck_t += dt
		if stuck_t > 2.5 and global_position.distance_to(P.global_position) > 7.0:
			stuck_t = 0.0; global_position = P.global_position + Vector3(sin(slot * 2.1) * 1.8, 0.0, cos(slot * 2.1) * 1.8)
	else: stuck_t = 0.0
	# déplacement « collé au sol » sans moteur physique (bien moins coûteux sur mobile)
	global_position.x += velocity.x * dt; global_position.z += velocity.z * dt
	global_position.y = main.world.ground_y(global_position.x, global_position.z)
	var face := want if want.length() > 0.3 else look_at_p
	if face.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(face.x, face.z), 1.0 - exp(-dt * 10.0))
	if cur == "Throw" and ap.is_playing() and ap.current_animation_position < ap.current_animation_length * 0.8: return
	if cur == "Hit_A" and ap.is_playing(): return
	var sp := Vector2(velocity.x, velocity.z).length()
	if sp > 0.6: _play("Running_A", clamp(sp / 6.0, 0.7, 1.3))
	else: _play("Idle_A")
