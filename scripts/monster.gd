class_name Monster extends Actor
## Monstres à IA de combat : attaques annoncées au sol (à esquiver), placement en cercle, flanc/dos,
## anticipation (visée devant le joueur, esquive quand le joueur arme un coup), repli, laisse de camp.
##   brute   : tank lent, garde frontale (-60 %), coups larges annoncés, vulnérable de dos et après un coup
##   archer  : garde ses distances, tire en anticipant, piège au sol là où le joueur VA être
##   rodeur  : cherche ton dos, fente en ligne, esquive tes attaques, se replie
##   boss    : Seigneur Ossuaire — 3 phases, charge à faire rater contre les piliers, bouclier, pluie d'os

var kind := "brute"
var home := Vector3.ZERO
var aware := false
var token := false              # autorisé à attaquer (le directeur limite les assaillants simultanés)
var slot := Vector3.INF         # place attribuée autour du joueur
var cds := {}
var open_t := 0.0               # fenêtre de vulnérabilité après une grosse attaque
var phase := 1
var shield := false
var charging := 0.0
var charge_dir := Vector3.ZERO
var minions: Array = []
var bar: MeshInstance3D
var bar_mat: ShaderMaterial
var dodge_cd := 0.0
var display_name := ""

func init_mob(k: String, at: Vector3) -> void:
	kind = k; home = at; brain = "mob"
	match k:
		"brute":
			display_name = "Brute d'os"; hp_max = 340; dmg_mul = 1.0; speed_mul = 0.82; turn_rate = 3.2
			tint(Color(0.95, 0.9, 0.8)); set_size(1.2)
		"archer":
			display_name = "Archer squelette"; hp_max = 150; speed_mul = 0.95; turn_rate = 9
		"rodeur":
			display_name = "Rôdeur des tombes"; hp_max = 170; speed_mul = 1.35; turn_rate = 9
			tint(Color(0.7, 0.55, 0.95), 0.15); set_size(0.92)
		"boss":
			display_name = "Seigneur Ossuaire"; hp_max = 3200; speed_mul = 0.9; turn_rate = 2.2
			set_style("2h"); tint(Color(0.38, 0.32, 0.45), 0.25); set_size(2.2)
	hp = hp_max
	var q := QuadMesh.new(); q.size = Vector2(1.3 * (1.6 if k == "boss" else 1.0), 0.16)
	bar = MeshInstance3D.new(); bar.mesh = q; bar_mat = ShaderMaterial.new(); bar_mat.shader = preload("res://scripts/hpbar.gdshader")
	bar.material_override = bar_mat; bar.position.y = 2.25 * size_k; bar.visible = false; add_child(bar)
	if k != "boss": hold("Skeletons_Inactive_Standing_Pose") if k != "archer" else hold("Idle_B")

func cd(n: String) -> bool: return cds.get(n, 0.0) <= 0.0
func set_cd(n: String, t: float) -> void: cds[n] = t

func p() -> Actor: return w.player

# ---------- dégâts : garde frontale, dos, bouclier ----------
func hurt(dmg: float, from: Vector3, force: float, by: Actor = null) -> void:
	if state == "dead": return
	if shield:
		w.burst(global_position + Vector3.UP * 2, Color(1, 0.85, 0.3), 6); w.flash_text(global_position, "BOUCLIER", Color(1, 0.85, 0.3)); return
	if not aware: wake()
	var d := (from - global_position); d.y = 0; d = d.normalized()
	var facing := fwd().dot(d)
	if facing < -0.35:
		dmg *= 1.5; w.flash_text(global_position, "DOS !", Color(1, 0.6, 0.2))
	elif kind == "brute" and facing > 0.4 and open_t <= 0 and busy <= 0:
		dmg *= 0.4; w.flash_text(global_position, "PARÉ", Color(0.8, 0.8, 0.9)); force = 0
	if open_t > 0: dmg *= 1.6
	if kind in ["brute", "boss"]: force = min(force, 3.0) if charging <= 0 else 0.0
	super.hurt(dmg, from, force, by)
	bar.visible = true
	_check_phase()

func wake() -> void:
	if aware: return
	aware = true; hold(""); state = "loco"
	busy = shot("Skeletons_Taunt" if kind != "archer" else "Ranged_Magic_Raise", true) * 0.6; root_lock = busy
	w.flash_text(global_position, "!", Color(1, 0.3, 0.2))
	if kind == "boss": w.boss_intro(self)

func die() -> void:
	super.die(); bar.visible = false
	for m in minions: if is_instance_valid(m) and m.state != "dead": m.die()
	w.on_mob_dead(self)

# ---------- cerveau ----------
func _think() -> void:
	for k in cds.keys(): cds[k] -= 0.15
	open_t = max(open_t - 0.15, 0); dodge_cd -= 0.15
	bar_mat.set_shader_parameter("fill", hp / hp_max)
	move_in = Vector2.ZERO
	if incap() or charging > 0: return
	var pl := p()
	var to := pl.global_position - global_position; to.y = 0
	var dist := to.length()
	if not aware:
		if dist < 13 and pl.state != "dead": wake()
		return
	if pl.state == "dead" or global_position.distance_to(home) > 34:
		# laisse : retour au camp, régénération
		aware = false; aim_target = null; hp = hp_max; bar.visible = false
		var hd := home - global_position; hd.y = 0
		if hd.length() > 1: move_in = Vector2(hd.x, hd.z).normalized()
		return
	if busy > 0 or root_lock > 0: return
	match kind:
		"brute": _brute(pl, to, dist)
		"archer": _archer(pl, to, dist)
		"rodeur": _rodeur(pl, to, dist)
		"boss": _boss(pl, to, dist)

func _go(target: Vector3, mag := 1.0) -> void:
	var d := target - global_position; d.y = 0
	if d.length() > 0.6: move_in = Vector2(d.x, d.z).normalized() * clamp(d.length() / 2.0, 0.35, 1.0) * mag

func _commit(t: float) -> void:
	# l'attaque est lancée : il ne tourne plus → le joueur peut se décaler / passer dans le dos
	aim_target = null; move_in = Vector2.ZERO; root_lock = t + 0.25; busy = t + 0.25

# ---------- brute ----------
func _brute(pl: Actor, to: Vector3, dist: float) -> void:
	aim_target = pl
	if not token or dist > 3.4:
		_go(slot if slot != Vector3.INF else pl.global_position, 0.8); return
	if cd("atk"):
		var dir := to.normalized()
		if randf() < 0.6:
			var T := 0.95
			_commit(T); w.tele_cone(self, global_position, dir, 3.6, 55.0, T, 45, 3)
			delay(T - 0.4, func(): shot("Melee_2H_Attack_Slice" if randf() < 0.5 else "Melee_1H_Attack_Chop", true))
		else:
			var T := 1.15
			_commit(T); w.tele_circle(self, global_position, 3.2, T, 55, 8)
			delay(T - 0.45, func(): shot("Melee_2H_Attack_Chop", true))
		delay(T_end(), func(): open_t = 1.1; w.flash_text(global_position, "OUVERT", Color(0.6, 1, 0.5)))
		set_cd("atk", randf_range(2.2, 3.0))
	else:
		_go(pl.global_position + (global_position - pl.global_position).normalized() * 2.4, 0.5)

func T_end() -> float: return busy

# ---------- archer ----------
func _archer(pl: Actor, to: Vector3, dist: float) -> void:
	aim_target = pl
	if dist < 4.5:
		if dodge_cd <= 0 and randf() < 0.35:
			dodge_cd = 4; dodge_v = -to.normalized() * 9; busy = shot("Dodge_Backward", true) * 0.7; iframes = 0.3; return
		_go(global_position - to.normalized() * 5.0); return
	if dist > 11: _go(pl.global_position, 0.9); return
	if slot != Vector3.INF and slot.distance_to(global_position) > 2.5: _go(slot, 0.7)
	if cd("trap") and dist < 11:
		var pred := pl.global_position + pl.velocity * 0.9
		_commit(0.7); shot("Ranged_Magic_Raise", true)
		w.tele_circle(self, pred, 2.3, 1.3, 40, 4)
		set_cd("trap", randf_range(6, 9)); set_cd("shot", 1.5); return
	if cd("shot"):
		# tir avec anticipation : vise là où sera le joueur à l'arrivée du projectile
		var flight := dist / 13.0
		var aimp := pl.global_position + Vector3(pl.velocity.x, 0, pl.velocity.z) * flight
		busy = shot("Ranged_Magic_Shoot", false) * 0.8
		delay(0.3, func(): w.mob_bolt(self, aimp, 13.0, 20))
		set_cd("shot", randf_range(1.6, 2.4))

# ---------- rôdeur ----------
func _rodeur(pl: Actor, to: Vector3, dist: float) -> void:
	aim_target = pl
	# anticipation : esquive latérale quand le joueur arme un coup à portée
	if pl.atk_t > 0 and dist < 3.2 and dodge_cd <= 0 and randf() < 0.55:
		dodge_cd = 3.0
		var side := to.normalized().cross(Vector3.UP) * (1 if randf() < 0.5 else -1)
		dodge_v = side * 10; iframes = 0.35
		busy = shot("Dodge_Left" if side.dot(fwd().cross(Vector3.UP)) > 0 else "Dodge_Right", true) * 0.7
		w.flash_text(global_position, "ESQUIVE", Color(0.8, 0.7, 1)); return
	var behind := pl.global_position - pl.fwd() * 2.6
	if not token:
		_go(slot if slot != Vector3.INF else behind, 0.9); return
	if cd("lunge") and dist < 7.5:
		var dir := to.normalized(); var T := 0.6
		_commit(T); shot("Melee_Dualwield_Attack_Stab", true)
		w.tele_line(self, global_position, dir, 7.0, 1.4, T, 0, 0)
		delay(T, func():
			dodge_v = dir * 15.0; iframes = 0.3
			delay(0.18, func(): _line_hit(dir, 3.0, 35)))
		set_cd("lunge", randf_range(3.5, 5.0))
		delay(T + 0.6, func(): retreat_t = 1.4)
		return
	if retreat_t > 0:
		retreat_t -= 0.15; _go(global_position - to.normalized() * 4.0); return
	_go(behind, 1.0)

var retreat_t := 0.0
var charge_hit: Array = []

func _line_hit(dir: Vector3, r: float, dmg: float) -> void:
	for o in w.actors:
		if foe(o) and o.global_position.distance_to(global_position) < r: o.hurt(dmg * dmg_mul, global_position - dir, 4, self)

# ---------- boss ----------
func _check_phase() -> void:
	if kind != "boss": return
	var r := hp / hp_max
	if phase == 1 and r < 0.6:
		phase = 2; w.flash_text(global_position, "PHASE 2", Color(0.9, 0.4, 1), 2.0)
		shield = true; w.bubble(self, 999.0)
		for i in 3:
			var m: Monster = w.spawn_mob("rodeur" if i == 0 else "archer", global_position + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 5)
			m.wake(); minions.append(m)
	elif phase == 2 and r < 0.25:
		phase = 3; speed_mul = 1.15; w.flash_text(global_position, "FUREUR", Color(1, 0.3, 0.2), 2.0)

func _boss(pl: Actor, to: Vector3, dist: float) -> void:
	aim_target = pl
	if shield:
		var alive := 0
		for m in minions: if is_instance_valid(m) and m.state != "dead": alive += 1
		if alive == 0: shield = false; w.unbubble(self); w.flash_text(global_position, "BOUCLIER BRISÉ", Color(1, 0.85, 0.3), 1.6); open_t = 3.0
	var k := 0.75 if phase == 3 else 1.0
	var dir := to.normalized()
	if phase >= 2 and cd("rain"):
		set_cd("rain", 11)
		for i in 5:
			delay(i * 0.45, func():
				var pr := pl.global_position + Vector3(pl.velocity.x, 0, pl.velocity.z) * 0.8
				w.tele_circle(self, pr, 2.0, 1.2 * k, 45, 3))
		busy = shot("Ranged_Magic_Summon", true); root_lock = busy; return
	if dist > 7 and cd("charge"):
		var T := 1.1 * k
		_commit(T); shot("Melee_2H_Idle", true)
		w.tele_line(self, global_position, dir, 18.0, 2.8, T, 0, 0)
		delay(T, func(): charging = 0.75; charge_dir = dir; charge_hit.clear(); shot("Running_B", true))
		set_cd("charge", 7.0); return
	if dist < 5.5:
		if cd("cleave"):
			var T := 1.0 * k
			_commit(T); w.tele_cone(self, global_position, dir, 5.8, 60.0, T, 70, 5)
			delay(T - 0.45, func(): shot("Melee_2H_Attack_Slice", true))
			set_cd("cleave", 2.6 * k)
			if phase == 3: delay(T + 0.2, func(): set_cd("slam", 0))
			return
		if cd("slam"):
			var T := 1.3 * k
			_commit(T); w.tele_circle(self, global_position, 5.2, T, 90, 10)
			delay(T - 0.5, func(): shot("Melee_2H_Attack_Chop", true); w.shake(0.35))
			set_cd("slam", 5.0 * k)
			delay(T + 0.2, func(): open_t = 1.4)
			return
	_go(pl.global_position, 0.9)

func _physics_process(dt: float) -> void:
	if charging > 0 and not frozen:
		charging -= dt
		velocity.x = charge_dir.x * 16; velocity.z = charge_dir.z * 16
		for o in w.actors:
			if foe(o) and not charge_hit.has(o) and o.global_position.distance_to(global_position) < 2.2 * size_k * 0.6:
				charge_hit.append(o); o.hurt(80, global_position - charge_dir, 10, self)
		move_and_slide()
		for i in get_slide_collision_count():
			var c := get_slide_collision(i).get_collider()
			if c is Node and (c as Node).is_in_group("pillar"):
				charging = 0; stun(2.5); open_t = 2.5; w.shake(0.5)
				w.flash_text(global_position, "SONNÉ !", Color(1, 0.9, 0.3), 1.8); w.burst(global_position + Vector3.UP * 2, Color(0.9, 0.85, 0.7), 30)
				break
		if charging <= 0: velocity = Vector3.ZERO; hold("")
		rotation.y = atan2(charge_dir.x, charge_dir.z); face = rotation.y
		return
	super._physics_process(dt)
