extends CharacterBody3D
class_name Pet
# Familier du Dompteur : un animal apprivoisé qui surgit au combat pendant 40 s,
# attaque les monstres et lance sa propre compétence (selon son espèce et sa rareté).

const ATK := {"fox": "Attack", "wolf": "Attack", "stag": "Attack_Headbutt", "bull": "Attack_Headbutt", "horse": "Attack_Headbutt"}
var main: Node
var sp := "loup"
var def: Dictionary
var rar := 0
var rarm := 1.0
var slot := 0
var hp := 100.0
var max_hp := 100.0
var dead := false
var life := 40.0
var atk_cd := 0.5
var sk_cd := 2.0
var target: Node3D
var ap: AnimationPlayer
var model: Node3D
var cur := ""
var radius := 0.6
var flash_mat: StandardMaterial3D
var bar_mat: ShaderMaterial
var charge_t := 0.0
var charge_dir := Vector3.ZERO
var charge_hit: Array = []
var lbl: Label3D

func setup(m: Node, p: Dictionary, i: int) -> void:
	main = m; sp = str(p.sp); def = Game.PETS[sp]; rar = int(p.r); rarm = float(Game.PET_RAR[rar].m); slot = i
	life = Game.PET_DUR; _in_inst = m.in_instance()
	var t: int = max(1, int(Game.S.gear.get("epee", 1)))
	max_hp = Game.armor_hp(t) * float(def.hp) * (0.7 + 0.3 * rarm); hp = max_hp
	collision_layer = 0; collision_mask = 0
	model = load("res://assets/animals/%s.glb" % def.model).instantiate()
	var sc: float = float(def.scale) * (1.0 + 0.06 * rar)
	model.scale = Vector3.ONE * sc; add_child(model)
	radius = 0.5 + sc * 0.6
	ap = model.find_child("AnimationPlayer", true, false)
	for an in ["Idle", "Walk", "Gallop"]:
		if ap and ap.has_animation(an): ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
	flash_mat = StandardMaterial3D.new(); flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; flash_mat.albedo_color = Color(1, 1, 1, 0.0); flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mi in Chars.meshes(model):
		mi.material_overlay = flash_mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if def.has("tint"): _tint(model, def.tint)
	model.add_child(Chars.blob(radius * 1.6 / sc))
	# halo de la couleur de rareté sous ses pattes
	var col: Color = Game.pet_col(p)
	var halo := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = radius * 1.5; cm.bottom_radius = cm.top_radius; cm.height = 0.02; halo.mesh = cm
	var hm := StandardMaterial3D.new(); hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_color = Color(col.r, col.g, col.b, 0.5); halo.material_override = hm; halo.position.y = 0.05; halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(halo)
	lbl = Label3D.new(); lbl.font_size = 32; lbl.outline_size = 10; lbl.modulate = col.lightened(0.2); lbl.outline_modulate = Color(0, 0, 0, 0.85)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED; lbl.pixel_size = 0.0065; lbl.no_depth_test = true; lbl.position.y = radius * 2.0 + 1.2; add_child(lbl)
	var bar := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(0.9, 0.1); bar.mesh = q
	bar_mat = ShaderMaterial.new(); bar_mat.shader = Enemy._bar_shader(); bar_mat.set_shader_parameter("col", col); bar_mat.render_priority = 4
	bar.material_override = bar_mat; bar.position.y = radius * 2.0 + 0.95; bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(bar)
	_play("Idle")

func _tint(n: Node, c: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for k in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(k)
			if src is BaseMaterial3D:
				var mt: BaseMaterial3D = src.duplicate(); mt.albedo_color = mt.albedo_color * c; mi.set_surface_override_material(k, mt)
	for ch in n.get_children(): _tint(ch, c)

func _play(n: String, spd := 1.0, restart := false) -> void:
	if ap == null or not ap.has_animation(n): return
	if n == cur and not restart: ap.speed_scale = spd; return
	cur = n; ap.play(n, 0.15); ap.speed_scale = spd
	if restart: ap.seek(0.0, true)

func dmg() -> float:
	var t: int = max(1, int(Game.S.gear.get("epee", 1)))
	return Game.weapon_dmg(t) * float(def.dmg) * rarm * 0.55

func hurt(amount: float, _from: Node3D) -> void:
	if dead: return
	hp -= amount
	flash_mat.albedo_color = Color(1, 0.3, 0.25, 0.6); create_tween().tween_property(flash_mat, "albedo_color:a", 0.0, 0.25)
	Fx.number(main, global_position + Vector3(0, radius * 2.0 + 1.0, 0), str(int(amount)), Color("#ffb09a"))
	if hp <= 0.0: vanish(true)

# fin de l'invocation : il retourne dans la nature (ou tombe au combat)
func vanish(killed := false) -> void:
	if dead: return
	dead = true
	main.pets.erase(self)
	if killed: main.hud.toast("%s est épuisé et retourne dans la nature" % def.name, Color("#ffb09a"))
	Fx.burst(main, global_position + Vector3(0, 0.8, 0), Color(0.5, 1.0, 0.6), 22, 4.0, 0.4, 0.7, -1.0)
	var tw := create_tween(); tw.tween_property(model, "scale", model.scale * 0.01, 0.35); tw.tween_callback(queue_free)

func _process(_dt: float) -> void:
	if dead: return
	bar_mat.set_shader_parameter("fill", clamp(hp / max_hp, 0.0, 1.0)); bar_mat.set_shader_parameter("trail", clamp(hp / max_hp, 0.0, 1.0))
	lbl.text = "%s · %d s" % [def.name, ceili(life)]

func _physics_process(dt: float) -> void:
	if dead: return
	var P: Player = main.player
	life -= dt; atk_cd -= dt; sk_cd -= dt
	if life <= 0.0 or P.dead or main.in_instance() != _in_inst: vanish(); return
	if target == null or not is_instance_valid(target) or target.dead or Engine.get_physics_frames() % 15 == slot:
		target = main.combat_target(P.global_position, 15.0, true)
	var want := Vector3.ZERO; var face := Vector3.ZERO
	var spd: float = float(def.speed)
	if charge_t > 0.0:
		charge_t -= dt
		want = charge_dir * 16.0
		for e in main.enemies:
			if e.dead or e in charge_hit: continue
			if e.global_position.distance_to(global_position) < radius + e.radius + 0.8:
				charge_hit.append(e); e.take_hit(dmg() * 1.6, self, 6.0)
		face = charge_dir
	elif target and is_instance_valid(target) and not target.dead:
		var to: Vector3 = target.global_position - global_position; to.y = 0
		var reach: float = radius + target.radius + 0.7
		face = to
		if sk_cd <= 0.0 and to.length() < reach + 2.5: sk_cd = float(def.skcd); _skill(to)
		if to.length() > reach: want = to.normalized() * spd
		elif atk_cd <= 0.0:
			atk_cd = float(def.cd) * randf_range(0.9, 1.1)
			_play(ATK.get(def.model, "Attack"), 1.1, true)
			var e = target
			get_tree().create_timer(0.18).timeout.connect(func():
				if is_instance_valid(e) and not e.dead and not dead and global_position.distance_to(e.global_position) < reach + 1.0: e.take_hit(dmg() * randf_range(0.9, 1.1), self, 1.2))
	else:
		# suit le héros
		var ang: float = P.yaw + PI + (slot - 1) * 0.8
		var spot := P.global_position + Vector3(sin(ang), 0, cos(ang)) * 2.4
		var to2 := spot - global_position; to2.y = 0
		if to2.length() > 0.8: want = to2.normalized() * min(P.speed() * 1.2, to2.length() * 4.0 + 2.0)
		face = want
		if sk_cd <= 0.0 and def.sk in ["heal", "bless"] and P.hp < P.max_hp * 0.9: sk_cd = float(def.skcd); _skill(Vector3.ZERO)
	if global_position.distance_to(P.global_position) > 30.0:
		global_position = P.global_position + Vector3(sin(slot * 2.1) * 2.0, 0.0, cos(slot * 2.1) * 2.0)
	var nx := global_position + want * dt
	if main.world.walkable(nx.x, nx.z):
		global_position.x = nx.x; global_position.z = nx.z
	global_position.y = main.world.ground_y(global_position.x, global_position.z)
	if face.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(face.x, face.z), 1.0 - exp(-dt * 10.0))
	if cur.begins_with("Attack") and ap.is_playing() and ap.current_animation_position < ap.current_animation_length * 0.8: return
	var v := want.length()
	if v > 6.0: _play("Gallop", clamp(v / 8.0, 0.8, 1.4))
	elif v > 0.6: _play("Walk", clamp(v / 3.0, 0.8, 1.4))
	else: _play("Idle")

var _in_inst := false

# compétence propre à l'espèce
func _skill(to: Vector3) -> void:
	var P: Player = main.player
	var c: Vector3 = target.global_position if target and is_instance_valid(target) else global_position
	match str(def.sk):
		"frenzy":
			for k in 3:
				get_tree().create_timer(0.12 + k * 0.18).timeout.connect(func():
					if is_instance_valid(target) and not target.dead and not dead:
						target.take_hit(dmg() * 0.8, self, 0.6); Fx.slash(main, target.global_position + Vector3(0, 0.8, 0), randf() * TAU, Color(1, 0.75, 0.4), 1.4))
			_word("Morsures !")
		"howl":
			P.rage_t = max(P.rage_t, 6.0)
			Fx.burst(main, global_position + Vector3(0, 1.2, 0), Color(0.8, 0.85, 1.0), 26, 5.0, 0.5, 0.8, -1.0)
			Fx.disc(main, global_position, 6.0, Color(0.7, 0.8, 1.0, 0.4), 0.5, false); _word("Hurlement !")
		"heal", "bless":
			var h: float = P.max_hp * (0.06 if def.sk == "heal" else 0.12) * (0.8 + 0.2 * rarm)
			P.hp = min(P.max_hp, P.hp + h)
			Fx.number(main, P.global_position + Vector3(0, 2.4, 0), "+%d" % int(h), Color("#7dff8a"), true)
			Fx.burst(main, P.global_position + Vector3(0, 1.0, 0), Color(0.5, 1.0, 0.55), 18, 3.0, 0.4, 0.7, -2.0)
			if def.sk == "bless":
				P.ice_shield(); P.shield_hp = P.max_hp * 0.15 * rarm; P.shield_t = 4.0
			_word("Soin !" if def.sk == "heal" else "Bénédiction !")
		"charge":
			if to.length() > 0.5:
				charge_dir = to.normalized(); charge_t = 0.45; charge_hit = []
				# les monstres autour s'acharnent sur lui
				for e in main.enemies:
					if not e.dead and e.global_position.distance_to(global_position) < 9.0: e.tgt = self
				_word("Charge !")
		"frost", "fire", "quake", "pack":
			var r := {"frost": 3.6, "fire": 3.2, "quake": 6.0, "pack": 4.5}[def.sk] as float
			var col := {"frost": Color(0.6, 0.9, 1.0), "fire": Color(1.0, 0.5, 0.15), "quake": Color(0.85, 0.7, 0.5), "pack": Color(0.75, 0.55, 1.0)}[def.sk] as Color
			var hits := 3 if def.sk == "pack" else 1
			if def.sk in ["quake", "pack"]: c = global_position
			for k in hits:
				get_tree().create_timer(0.1 + k * 0.35).timeout.connect(func():
					if dead: return
					Fx.disc(main, Vector3(c.x, main.world.height(c.x, c.z), c.z), r, Color(col.r, col.g, col.b, 0.55), 0.4, false)
					Fx.burst(main, c + Vector3(0, 0.5, 0), col, 24, 5.0, 0.4, 0.6, 2.0)
					for e in main.enemies.duplicate():
						if not e.dead and Vector2(e.global_position.x - c.x, e.global_position.z - c.z).length() < r + e.radius:
							e.take_hit(dmg() * (1.4 if def.sk != "pack" else 0.9), self, 6.0 if def.sk == "quake" else 1.5)
							if def.sk == "frost" and e.has_method("slow"): e.slow(2.5))
			if def.sk == "quake": main.shake(0.3)
			_word(str(def.skill) + " !")

func _word(t: String) -> void:
	Fx.number(main, global_position + Vector3(0, radius * 2.0 + 1.6, 0), t, Color(Game.PET_RAR[rar].c), true)
