class_name PlayerCombat
extends Node
## Combat du seigneur : combo à l'épée (3 coups), esquive roulée, 4 sorts, ciblage automatique,
## potions, mort et retour au château. Les boutons de l'interface appellent ces fonctions.

signal message(text: String, col: Color)

var player: Player
var prog: Progression
var mana := 50.0
var target: Node3D = null
var cooldowns := {}       # sort -> instant de fin
var _combo := 0
var _attack_until := 0.0
var _combo_window := 0.0
var _queued := false
var _hit_at := 0.0
var _hit_pending := false
var _dodge_until := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector3.ZERO
var _cast_spell := ""
var _cast_end := 0.0
var _shield_fx: Node3D
var _marker: MeshInstance3D
var _target_acc := 0.0
var _dead_until := 0.0
var _potion_cd := 0.0
## Compteurs d'actions (le tutoriel narratif s'en sert pour savoir ce que le joueur a appris)
var stats := {"coups": 0, "combo": 0, "esquives": 0, "sorts": 0, "potions": 0, "morts": 0}
## Point de réapparition (l'histoire le déplace pendant l'introduction)
static var respawn_point := Vector2(0, -70)
## Sorts chargés : maintenir le bouton charge le sort (puissance, rayon, coût), glisser vise, « Annuler » annule.
const CHARGE_TIME := 1.1
var charging := ""
var _charge_t0 := 0.0
var aim := Vector3.ZERO          # direction visée (monde), ZERO = visée automatique
var _c := 0.0                    # charge du sort en cours de résolution
var _aim_used := Vector3.ZERO
var _reticle: MeshInstance3D
var _ret_mat: ShaderMaterial
var _charge_fx: Node3D
var incarnation_until := 0.0
var cd_total := {}               # durée de recharge effective par sort (affichage)
## Chambre des Arcanes : entraînement libre (mana gratuit, recharge courte)
static var practice := false
static var respawn_text := "Vous reprenez vos esprits aux portes du château"

const COMBO := [
	{"anim": "b/Sword_Regular_A", "dur": 0.55, "hit": 0.22, "mult": 1.0},
	{"anim": "b/Sword_Regular_B", "dur": 0.55, "hit": 0.22, "mult": 1.1},
	{"anim": "b/Sword_Regular_C", "dur": 0.75, "hit": 0.32, "mult": 1.6},
]

func now() -> float:
	return Time.get_ticks_msec() / 1000.0

func setup(p: Player) -> void:
	player = p
	prog = Progression.get_inst()
	player.cbt.max_hp = prog.max_hp()
	player.cbt.hp = player.cbt.max_hp
	mana = prog.max_mana()
	prog.leveled_up.connect(_on_level_up)
	player.cbt.damaged.connect(_on_hurt)
	player.cbt.died.connect(_on_death)
	_marker = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.7)
	_marker.mesh = q
	var m: StandardMaterial3D = FX.pmat("circle_05", true, false, Color(1.0, 0.35, 0.25))
	_marker.material_override = m
	_marker.rotation = Vector3(-PI / 2.0, 0, 0)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	FX.root.add_child(_marker)

func busy() -> bool:
	return now() < _attack_until or now() < _dodge_until or _cast_spell != "" or player.cbt.dead

func spell_unlocked(id: String) -> bool:
	if SpellDB.is_power(id):
		return prog.pouvoirs.has(id)
	return prog.level >= int(SpellDB.DEFS[id]["niveau"])

func cooldown_left(id: String) -> float:
	return maxf(0.0, cooldowns.get(id, 0.0) - now())

# ------------------------------------------------------------------ ÉPÉE
func attack() -> void:
	if player.cbt.dead or now() < _dodge_until or _cast_spell != "":
		return
	if now() < _attack_until:
		if now() >= _combo_window:
			_queued = true
		return
	if now() > _attack_until + 0.45:
		_combo = 0
	_start_swing()

func _start_swing() -> void:
	var c: Dictionary = COMBO[_combo]
	_face_target(5.0)
	player.action(c["anim"], c["dur"], 1.25)
	_attack_until = now() + c["dur"]
	_combo_window = now() + c["dur"] * 0.45
	_hit_at = now() + c["hit"]
	_hit_pending = true
	_queued = false
	stats["coups"] += 1
	if _combo == 2:
		stats["combo"] += 1
	Sfx.play("coup", -3.0)

func _resolve_hit() -> void:
	var c: Dictionary = COMBO[_combo]
	var fwd := player.forward()
	var origin := player.global_position + Vector3.UP * 1.0
	FX.slash(origin + fwd * 1.1, player.rotation.y, _combo == 1)
	var hit_any := false
	for m in Combat.in_radius(player.global_position, 2.9):
		var d: Vector3 = m.global_position - player.global_position
		d.y = 0
		if d.length() < 0.8 or fwd.dot(d.normalized()) > 0.25:
			var dmg := prog.melee_damage() * float(c["mult"])
			m.cbt.take_damage(dmg, player)
			FX.hit_spark(m.global_position + Vector3.UP * 1.0)
			hit_any = true
			if m.cbt.dead == false:
				m.velocity += d.normalized() * 3.0
	if hit_any:
		Sfx.play("touche", -2.0)
		player.shake(0.12 if _combo < 2 else 0.25)

# ------------------------------------------------------------------ ESQUIVE
func dodge() -> void:
	if player.cbt.dead or now() < _dodge_cd or _cast_spell != "":
		return
	var dir := player.move_dir()
	if dir.length() < 0.1:
		dir = -player.forward()
	_dodge_dir = dir.normalized()
	player.rotation.y = atan2(_dodge_dir.x, _dodge_dir.z)
	_dodge_until = now() + 0.5
	_dodge_cd = now() + 0.9
	_attack_until = 0.0
	player.cbt.invulnerable_until = now() + 0.42
	player.action("Roll", 0.5, 1.35)
	stats["esquives"] += 1
	Sfx.play("esquive")

# ------------------------------------------------------------------ SORTS
## Lancement immédiat (appui court, clavier, tests)
func cast(id: String) -> void:
	_cast_with(id, 0.0, Vector3.ZERO)

func incarnated() -> bool:
	return now() < incarnation_until

func mana_cost(id: String, c: float) -> float:
	if practice:
		return 0.0
	var m := float(SpellDB.DEFS[id]["mana"]) * (1.0 + 0.6 * c)
	return m * (0.7 if incarnated() else 1.0)

func recharge_of(id: String) -> float:
	if practice:
		return 0.4
	var r := float(SpellDB.DEFS[id]["recharge"]) * (1.0 - 0.1 * (prog.rank(id) - 1))
	return r * (0.6 if incarnated() else 1.0)

func can_cast(id: String, feedback := true) -> bool:
	var d: Dictionary = SpellDB.DEFS[id]
	if player.cbt.dead or charging != "":
		return false
	if not spell_unlocked(id):
		if feedback:
			message.emit("%s : débloqué au niveau %d" % [d["nom"], d["niveau"]], Color(1, 0.8, 0.4))
			Sfx.play("erreur", -6.0)
		return false
	if cooldown_left(id) > 0.0:
		return false
	if mana < mana_cost(id, 0.0):
		if feedback:
			message.emit("Pas assez de mana", Color(0.5, 0.7, 1.0))
			Sfx.play("erreur", -6.0)
		return false
	return true

## Début de charge (bouton maintenu)
func begin_charge(id: String) -> bool:
	if not can_cast(id):
		return false
	charging = id
	_charge_t0 = now()
	aim = Vector3.ZERO
	_attack_until = 0.0
	player.action("Spell_Simple_Idle", 60.0, 1.0)
	_charge_fx = FX.charge_aura(player, SpellDB.DEFS[id]["couleur"])
	Sfx.play("ok", -14.0)
	_show_reticle(true)
	return true

func charge_level() -> float:
	if charging == "":
		return 0.0
	return clampf((now() - _charge_t0) / CHARGE_TIME, 0.0, 1.0)

## Visée : vecteur de glissé du doigt (repère écran, -1..1) → direction monde selon la caméra
func set_aim(v: Vector2) -> void:
	if v.length() < 0.3:
		aim = Vector3.ZERO
	else:
		aim = Vector3(v.x, 0, v.y).normalized().rotated(Vector3.UP, player.cam_yaw)

func release_charge() -> void:
	if charging == "":
		return
	var id := charging
	var c := charge_level()
	var d: Dictionary = SpellDB.DEFS[id]
	# la charge coûte du mana : on charge seulement ce qu'on peut payer
	var extra := mana_cost(id, 1.0) - mana_cost(id, 0.0)
	if extra > 0.0:
		c = minf(c, maxf(0.0, (mana - mana_cost(id, 0.0)) / extra))
	_stop_charge()
	if not _cast_with(id, c, aim):
		player.end_action()

func cancel_charge() -> void:
	if charging == "":
		return
	_stop_charge()
	player.end_action()
	message.emit("Sort annulé", Color(0.8, 0.8, 0.85))
	Sfx.play("erreur", -12.0)

func _stop_charge() -> void:
	charging = ""
	_show_reticle(false)
	if is_instance_valid(_charge_fx):
		_charge_fx.queue_free()
	_charge_fx = null

func _cast_with(id: String, c: float, aim_dir: Vector3) -> bool:
	var d: Dictionary = SpellDB.DEFS[id]
	if not can_cast(id):
		return false
	if busy() and now() < _dodge_until:
		return false
	if aim_dir != Vector3.ZERO and id in ["trait_feu", "racines"]:
		var t := Combat.best_target(player.global_position, aim_dir, float(d["portee"]), 30.0)
		if t:
			target = t
		player.rotation.y = atan2(aim_dir.x, aim_dir.z)
	if id == "racines":
		if aim_dir == Vector3.ZERO:
			_refresh_target(false)
		if target == null or target.global_position.distance_to(player.global_position) > d["portee"]:
			message.emit("Aucune cible à portée", Color(1, 0.8, 0.4))
			Sfx.play("erreur", -6.0)
			return false
	_attack_until = 0.0
	mana -= mana_cost(id, c)
	_c = c
	_aim_used = aim_dir
	cd_total[id] = recharge_of(id)
	cooldowns[id] = now() + cd_total[id]
	FX.cast_glow(player, d["couleur"])
	if c >= 0.9:
		_intimidate(d["couleur"])
	if d["incantation"] > 0.0:
		_cast_spell = id
		_cast_end = now() + d["incantation"]
		player.action("Spell_Simple_Enter", d["incantation"] + 0.1, 1.0)
	else:
		_effect(id)
	return true

func _effect(id: String) -> void:
	var d: Dictionary = SpellDB.DEFS[id]
	var c := _c
	var power: float = (d.get("degats", 0.0) + prog.spell_power() * d["ratio"]) * (1.0 + 1.2 * c)
	power *= 1.0 + 0.25 * (prog.rank(id) - 1)
	if incarnated():
		power *= 1.5
	stats["sorts"] += 1
	if c >= 0.9:
		stats["sorts_charges"] = int(stats.get("sorts_charges", 0)) + 1
	match id:
		"trait_feu":
			if _aim_used == Vector3.ZERO:
				_refresh_target(false)
				_face_target(30.0)
			player.action("Spell_Simple_Shoot", 0.45, 1.3)
			var bolt := Projectile.new()
			bolt.damage = power
			bolt.splash = float(d["rayon"]) * (1.0 + 0.7 * c)
			bolt.charge = c
			bolt.source = player
			bolt.target = target if target and Combat.alive(target) and target.global_position.distance_to(player.global_position) < d["portee"] else null
			bolt.dir = player.forward()
			FX.root.add_child(bolt)
			bolt.global_position = player.global_position + Vector3.UP * 1.35 + player.forward() * 0.8
			Sfx.play("feu", -4.0 + 4.0 * c, 0.05)
			player.shake(0.1 + 0.25 * c)
		"egide":
			player.action("Spell_Simple_Shoot", 0.4, 1.0)
			player.cbt.give_shield(power, float(d["duree"]) * (1.0 + 0.5 * c))
			if is_instance_valid(_shield_fx):
				_shield_fx.queue_free()
			_shield_fx = FX.shield(player)
			Sfx.play("bouclier", -6.0)
			if c >= 0.6:
				# égide chargée : l'onde repousse les ennemis proches
				FX.shockwave(player.global_position, 3.5 + 2.0 * c)
				for m in Combat.in_radius(player.global_position, 3.5 + 2.0 * c):
					var dv: Vector3 = m.global_position - player.global_position
					dv.y = 0
					m.knockback(dv.normalized() * (6.0 + 6.0 * c))
				player.shake(0.3)
		"nova_givre":
			# frappe au sol : le seigneur retombe genou à terre, la glace jaillit autour de lui
			player.action("b/NinjaJump_Land", 0.6, 1.4)
			var r := float(d["portee"]) * (1.0 + 0.5 * c)
			FX.frost_nova(player.global_position, r)
			FX.shockwave(player.global_position, r * 0.8)
			Sfx.play("givre", -3.0 + 3.0 * c)
			Sfx.play("lourd", -8.0 + 4.0 * c)
			player.shake(0.25 + 0.3 * c)
			var hit := 0
			for m in Combat.in_radius(player.global_position, r):
				m.cbt.take_damage(power, player, "givre")
				m.cbt.apply_slow(d["ralenti"] * (1.0 - 0.4 * c), float(d["duree"]) * (1.0 + 0.5 * c))
				FX.frost_mark(m, float(d["duree"]) * (1.0 + 0.5 * c))
				hit += 1
			if hit > 0:
				FX.hitstop(0.05 + 0.07 * c)
		"racines":
			if target and Combat.alive(target):
				_face_target(30.0)
				player.action("Spell_Simple_Shoot", 0.45, 1.0)
				var dur := float(d["duree"]) * (1.0 + 0.6 * c)
				# chargées, les racines saisissent aussi les ennemis proches de la cible
				var victims := [target]
				if c >= 0.6:
					for m in Combat.in_radius(target.global_position, 2.5 + 2.0 * c):
						if m != target:
							victims.append(m)
				for v in victims:
					v.cbt.apply_root(dur)
					v.cbt.take_damage(power, player, "nature")
					FX.roots(v, dur)
					var tgt: Node3D = v
					for k in 3:
						get_tree().create_timer(0.8 * (k + 1)).timeout.connect(func(): if Combat.alive(tgt): tgt.cbt.take_damage(power * 0.5, player, "magie"))
				Sfx.play("racines", -2.0)
				player.shake(0.1 + 0.2 * c)
		_:
			Powers.exec(self, id, power, c, _aim_used)

## Démonstration de puissance (sort chargé à fond) : les ennemis faibles prennent peur et fuient
func _intimidate(col: Color) -> void:
	FX.power_burst(player, col)
	var lv := prog.level
	for m in Combat.in_radius(player.global_position, 14.0):
		if m.def.get("boss", false):
			continue
		var chance := 0.15 if m.def.get("elite", false) else 0.45
		chance += clampf((lv * 20.0 - float(m.def["xp"])) / 200.0, 0.0, 0.35)
		if m.cbt.hp < m.cbt.max_hp * 0.5:
			chance += 0.2
		if randf() < chance:
			m.frighten(3.0 + randf() * 2.0)

func _on_hurt(_amount: float, _src: Node) -> void:
	if _cast_spell != "":
		var d: Dictionary = SpellDB.DEFS[_cast_spell]
		mana = minf(prog.max_mana(), mana + d["mana"] * 0.5)
		cooldowns[_cast_spell] = now() + 1.0
		_cast_spell = ""
		message.emit("Sort interrompu !", Color(1, 0.5, 0.4))
		player.action("Hit_Chest", 0.35, 1.0)
	elif not busy() and charging == "":
		player.action("Hit_Chest", 0.3, 1.2)
	player.shake(0.2)

# ------------------------------------------------------------------ POTIONS
func drink(kind: String) -> void:
	if player.cbt.dead or now() < _potion_cd:
		return
	if kind == "soin":
		if prog.potions_soin <= 0:
			message.emit("Plus de potion de soin", Color(1, 0.6, 0.6))
			return
		prog.potions_soin -= 1
		player.cbt.heal(player.cbt.max_hp * 0.5)
		FX.damage_number(player.global_position + Vector3.UP * 2.2, "+%d PV" % int(player.cbt.max_hp * 0.5), Color(0.5, 1.0, 0.5))
	else:
		if prog.potions_mana <= 0:
			message.emit("Plus de potion de mana", Color(0.6, 0.7, 1))
			return
		prog.potions_mana -= 1
		mana = minf(prog.max_mana(), mana + prog.max_mana() * 0.6)
	_potion_cd = now() + 1.0
	stats["potions"] += 1
	prog.changed.emit()
	Sfx.play("potion")
	FX.cast_glow(player, Color(1, 0.4, 0.4) if kind == "soin" else Color(0.4, 0.6, 1))

# ------------------------------------------------------------------ CIBLAGE / BOUCLE
func _refresh_target(force := false) -> void:
	if not force and target and Combat.alive(target) and target.global_position.distance_to(player.global_position) < 20.0:
		return
	target = Combat.best_target(player.global_position, player.forward(), 18.0)

func _face_target(max_d: float) -> void:
	if target and Combat.alive(target):
		var d := target.global_position - player.global_position
		d.y = 0
		if d.length() < max_d:
			player.rotation.y = atan2(d.x, d.z)

## Charge « manga » : plus on maintient, plus l'aura enfle, la caméra recule, le sol vibre et se fend
var _manga_on := false
var _manga_t := 0.0
var _manga_dist0 := 8.0
var _manga_full := false
func _manga_charge(delta: float) -> void:
	var c := charge_level()
	var w := Justice.world()
	var rig = w.get("rig") if w else null
	if is_instance_valid(_charge_fx):
		_charge_fx.scale = Vector3.ONE * (1.0 + c * 1.4)
	if c < 0.35 or rig == null:
		return
	if not _manga_on:
		_manga_on = true
		_manga_dist0 = rig.dist_goal
	rig.dist_goal = lerpf(_manga_dist0, minf(_manga_dist0 + 4.5, rig.max_dist), c)
	rig.shake(0.04 + 0.1 * c)
	_manga_t += delta
	if _manga_t > (0.5 - 0.3 * c):
		_manga_t = 0.0
		var col: Color = SpellDB.DEFS[charging]["couleur"]
		Magic.sparks(player.global_position + Vector3.UP * 0.2, col, int(6 + 14 * c), 3.0 + 5.0 * c, 0.5)
		if c >= 1.0 and not _manga_full:
			_manga_full = true   # pleine puissance : une seule onde, pas de saturation
			FX.shockwave(player.global_position, 1.8)
			Magic.halo(player.global_position + Vector3.UP, 2.6, col, 0.5)
			Sfx.play("lourd", -6.0)

func _manga_off() -> void:
	_manga_on = false
	_manga_full = false
	var w := Justice.world()
	if w and w.get("rig"):
		w.rig.dist_goal = _manga_dist0

func _process(delta: float) -> void:
	if player == null:
		return
	var t := now()
	if player.cbt.dead:
		if t > _dead_until:
			_respawn()
		return
	if _hit_pending and t >= _hit_at:
		_hit_pending = false
		_resolve_hit()
	if _queued and t >= _attack_until - 0.05:
		_combo = (_combo + 1) % COMBO.size()
		_start_swing()
	if _cast_spell != "" and t >= _cast_end:
		var id := _cast_spell
		_cast_spell = ""
		_effect(id)
	mana = minf(prog.max_mana(), mana + prog.mana_regen() * delta)
	if charging != "":
		_update_reticle()
		_manga_charge(delta)
	elif _manga_on:
		_manga_off()
	if player.model:
		var lift := 0.0
		if incarnated():
			lift = 0.55 + sin(t * 2.5) * 0.08
		player.model.position.y = lerpf(player.model.position.y, lift, clampf(delta * 5.0, 0, 1))
	if not player.cbt.has_shield() and is_instance_valid(_shield_fx):
		_shield_fx.queue_free()
		_shield_fx = null
	# régénération hors combat
	if t - player.last_hurt > 6.0:
		player.cbt.heal(player.cbt.max_hp * 0.02 * delta)
	_target_acc += delta
	if _target_acc > 0.25:
		_target_acc = 0.0
		_refresh_target()
	if target and Combat.alive(target):
		_marker.visible = true
		var tp := target.global_position
		_marker.global_position = Vector3(tp.x, tp.y + 0.08, tp.z)
		_marker.rotate_object_local(Vector3.FORWARD, delta * 1.5)
		var sc: float = target.def["scale"]
		_marker.scale = Vector3.ONE * sc
	else:
		_marker.visible = false
		target = null
	if Engine.get_process_frames() % 300 == 0:
		prog.save_if_dirty()

func dodge_velocity() -> Vector3:
	if now() < _dodge_until:
		return _dodge_dir * 9.0
	return Vector3.INF

func move_scale() -> float:
	if _cast_spell != "":
		return 0.0
	if charging != "":
		return 0.45
	if now() < _attack_until:
		return 0.15
	return 1.0

func _on_level_up(lv: int) -> void:
	player.cbt.max_hp = prog.max_hp()
	player.cbt.hp = player.cbt.max_hp
	mana = prog.max_mana()
	FX.level_up(player)
	Sfx.play("niveau", -2.0)
	var txt := "Niveau %d !" % lv
	for id in SpellDB.ORDER:
		if int(SpellDB.DEFS[id]["niveau"]) == lv:
			txt += "\nNouveau sort : %s" % SpellDB.DEFS[id]["nom"]
	message.emit(txt, Color(1.0, 0.85, 0.35))
	prog.save_if_dirty()

func _on_death(_src: Node) -> void:
	stats["morts"] += 1
	if charging != "":
		_stop_charge()
	_dead_until = now() + 4.0
	_cast_spell = ""
	player.action("Death01", 4.0, 1.0)
	var lost := int(prog.gold * 0.1)
	prog.add_gold(-lost)
	message.emit("Vous êtes tombé…\nRetour au château (-%d or)" % lost, Color(1, 0.45, 0.4))
	Sfx.play("mort")

func _respawn() -> void:
	player.cbt.dead = false
	player.cbt.hp = player.cbt.max_hp
	mana = prog.max_mana()
	var p := respawn_point
	if DwarfRealm.inside:
		player.global_position = DwarfRealm.arrival() + Vector3.UP * 0.5
	else:
		player.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.3, p.y)
	player.velocity = Vector3.ZERO
	player.end_action()
	message.emit(respawn_text, Color(0.9, 0.9, 1))

# ------------------------------------------------------------------ réticule de visée au sol
func _show_reticle(v: bool) -> void:
	if _reticle == null:
		_reticle = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(1, 1)
		_reticle.mesh = q
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 col : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform int shape = 0; // 0 cercle, 1 ligne
uniform float t = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = 0.0;
	if (shape == 0) {
		float r = length(p);
		a = step(r, 1.0) * (0.12 + smoothstep(0.88, 0.97, r) * 0.7);
		a += step(r, 1.0) * step(abs(r - fract(t) ), 0.03) * 0.5;
	} else {
		float along = 1.0 - UV.y;
		a = 0.12 + smoothstep(0.8, 0.95, abs(p.x)) * 0.6;
		a += step(abs(along - fract(t)), 0.03) * 0.5;
		a *= smoothstep(1.0, 0.9, along) * 0.7 + 0.3;
	}
	ALBEDO = col.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}"""
		_ret_mat = ShaderMaterial.new()
		_ret_mat.shader = sh
		_reticle.material_override = _ret_mat
		_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		FX.root.add_child(_reticle)
	_reticle.visible = v

func _update_reticle() -> void:
	var d: Dictionary = SpellDB.DEFS[charging]
	var c := charge_level()
	var pp := player.global_position
	var y := pp.y + 0.12
	_ret_mat.set_shader_parameter("col", (d["couleur"] as Color).lerp(Color(1, 1, 0.8), c * 0.5))
	_ret_mat.set_shader_parameter("t", now() * (0.8 + c * 1.5))
	var dir := aim if aim != Vector3.ZERO else player.forward()
	match charging:
		"trait_feu":
			_ret_mat.set_shader_parameter("shape", 1)
			var l := float(d["portee"])
			_reticle.scale = Vector3(1.2 + c, 1, l)
			_reticle.global_position = Vector3(pp.x, y, pp.z) + dir * l * 0.5
			_reticle.rotation = Vector3(0, atan2(dir.x, dir.z), 0)
			if aim != Vector3.ZERO:
				player.rotation.y = atan2(aim.x, aim.z)
		"nova_givre", "egide":
			_ret_mat.set_shader_parameter("shape", 0)
			var r := float(d["portee"]) * (1.0 + 0.5 * c) if charging == "nova_givre" else 3.5 + 2.0 * c
			_reticle.scale = Vector3(r * 2.0, 1, r * 2.0)
			_reticle.global_position = Vector3(pp.x, y, pp.z)
			_reticle.rotation = Vector3.ZERO
		"racines":
			_ret_mat.set_shader_parameter("shape", 0)
			var t: Node3D = Combat.best_target(pp, dir, float(d["portee"]), 30.0) if aim != Vector3.ZERO else (target if target and Combat.alive(target) else Combat.best_target(pp, player.forward(), float(d["portee"])))
			if t:
				var r := 1.2 if c < 0.6 else 2.5 + 2.0 * c
				_reticle.scale = Vector3(r * 2.0, 1, r * 2.0)
				_reticle.global_position = Vector3(t.global_position.x, t.global_position.y + 0.12, t.global_position.z)
				_reticle.visible = true
			else:
				_reticle.visible = false
