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
func cast(id: String) -> void:
	var d: Dictionary = SpellDB.DEFS[id]
	if player.cbt.dead:
		return
	if not spell_unlocked(id):
		message.emit("%s : débloqué au niveau %d" % [d["nom"], d["niveau"]], Color(1, 0.8, 0.4))
		Sfx.play("erreur", -6.0)
		return
	if cooldown_left(id) > 0.0:
		return
	if mana < d["mana"]:
		message.emit("Pas assez de mana", Color(0.5, 0.7, 1.0))
		Sfx.play("erreur", -6.0)
		return
	if busy() and now() < _dodge_until:
		return
	if id == "racines":
		_refresh_target(false)
		if target == null or target.global_position.distance_to(player.global_position) > d["portee"]:
			message.emit("Aucune cible à portée", Color(1, 0.8, 0.4))
			Sfx.play("erreur", -6.0)
			return
	_attack_until = 0.0
	mana -= d["mana"]
	cooldowns[id] = now() + d["recharge"]
	FX.cast_glow(player, d["couleur"])
	if d["incantation"] > 0.0:
		_cast_spell = id
		_cast_end = now() + d["incantation"]
		player.action("Spell_Simple_Enter", d["incantation"] + 0.1, 1.0)
	else:
		_effect(id)

func _effect(id: String) -> void:
	var d: Dictionary = SpellDB.DEFS[id]
	var power: float = d.get("degats", 0.0) + prog.spell_power() * d["ratio"]
	stats["sorts"] += 1
	match id:
		"trait_feu":
			_refresh_target(false)
			_face_target(30.0)
			player.action("Spell_Simple_Shoot", 0.45, 1.3)
			var bolt := Projectile.new()
			bolt.damage = power
			bolt.splash = d["rayon"]
			bolt.source = player
			bolt.target = target if target and target.global_position.distance_to(player.global_position) < d["portee"] else null
			bolt.dir = player.forward()
			FX.root.add_child(bolt)
			bolt.global_position = player.global_position + Vector3.UP * 1.35 + player.forward() * 0.8
			Sfx.play("feu", -4.0)
		"egide":
			player.action("Spell_Simple_Shoot", 0.4, 1.0)
			player.cbt.give_shield(power, d["duree"])
			if is_instance_valid(_shield_fx):
				_shield_fx.queue_free()
			_shield_fx = FX.shield(player)
			Sfx.play("bouclier", -6.0)
		"nova_givre":
			player.action("Spell_Simple_Shoot", 0.4, 1.0)
			FX.frost_nova(player.global_position, d["portee"])
			Sfx.play("givre", -3.0)
			for m in Combat.in_radius(player.global_position, d["portee"]):
				m.cbt.take_damage(power, player, "magie")
				m.cbt.apply_slow(d["ralenti"], d["duree"])
				FX.frost_mark(m, d["duree"])
		"racines":
			if target and Combat.alive(target):
				_face_target(30.0)
				player.action("Spell_Simple_Shoot", 0.45, 1.0)
				target.cbt.apply_root(d["duree"])
				target.cbt.take_damage(power, player, "magie")
				FX.roots(target, d["duree"])
				Sfx.play("racines", -2.0)
				var tgt := target
				for k in 3:
					get_tree().create_timer(0.8 * (k + 1)).timeout.connect(func(): if Combat.alive(tgt): tgt.cbt.take_damage(power * 0.5, player, "magie"))

func _on_hurt(_amount: float, _src: Node) -> void:
	if _cast_spell != "":
		var d: Dictionary = SpellDB.DEFS[_cast_spell]
		mana = minf(prog.max_mana(), mana + d["mana"] * 0.5)
		cooldowns[_cast_spell] = now() + 1.0
		_cast_spell = ""
		message.emit("Sort interrompu !", Color(1, 0.5, 0.4))
		player.action("Hit_Chest", 0.35, 1.0)
	elif not busy():
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
	player.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.3, p.y)
	player.velocity = Vector3.ZERO
	player.end_action()
	message.emit(respawn_text, Color(0.9, 0.9, 1))
