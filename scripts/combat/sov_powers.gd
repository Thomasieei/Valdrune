class_name SovPowers
## Pouvoirs de décision du souverain : Possession, Lames spectrales, Onde de force.
## Chaque pouvoir pose une question au joueur (que faire de ce corps, comment mener les lames) :
## la puissance n'est pas un bouton, c'est un choix.

const VIOLET := Color(0.75, 0.3, 1.0)
const CYAN := Color(0.55, 0.95, 0.95)
const OR_PALE := Color(0.95, 0.9, 0.6)

# ================================================================== POSSESSION
static func possession(pc: PlayerCombat, power: float, aim: Vector3, rng: float, dur: float, rk: int) -> void:
	var pl := pc.player
	var t := Powers.aim_target(pc, aim, rng)
	if t == null:
		pc.message.emit("Aucune âme à saisir", Color(0.85, 0.7, 1.0))
		return
	if t.is_boss() or t.def.get("elite", false) and rk < 3:
		FX.bark(t, ["Mon esprit est à moi !", "Sors de ma tête, sorcier !"][randi() % 2], 2.6 * float(t.def["scale"]), 2.2)
		Powers._hurt(t, power, pc, "arcane")
		Juice.onde(t.global_position, VIOLET, 2.5, 0.4)
		return
	pl.rotation.y = atan2(t.global_position.x - pl.global_position.x, t.global_position.z - pl.global_position.z)
	pl.action("Spell_Simple_Shoot", 6.0, 1.0)
	Powers._beam(pl, t, VIOLET, 1.2)
	t.stun(6.0, true)
	FX.cast_glow(t, VIOLET)
	Magic.rune(t.global_position, 1.8, VIOLET, 6.0, 2.4)
	Juice.lueur(t.global_position, VIOLET, 3.0, 1.0, 1.4)
	FX.bark(t, ["… maître …", "Ma… tête…", "Je… vous… sers…"][randi() % 3], 2.4 * float(t.def["scale"]), 2.4)
	Sfx.play("possession", -2.0)
	if Hud.inst == null:
		_turn(pc, t, power, dur)
		return
	Hud.inst.show_choices([
		["possession", "Retourner", func(): _turn(pc, t, power, dur)],
		["onde", "Faire exploser", func(): _detonate(pc, t, power)],
		["couronne", "Semer la terreur", func(): _terror(pc, t, dur)],
	], 6.0, func(): _turn(pc, t, power, dur))

## Le corps possédé se bat pour le souverain ; ses anciens frères se retournent contre lui. Puis il s'effondre.
static func _turn(pc: PlayerCombat, t: Node3D, power: float, dur: float) -> void:
	if not Combat.alive(t):
		return
	t.set_meta("possede", true)
	t.peaceful = false
	t._stun_end = 0.0
	t._ap.speed_scale = 1.0
	t._cur = ""
	t.home = t.global_position     # le possédé n'est plus tenu par son camp
	t.leash = 60.0
	t._go(Monster.S.POURSUITE)
	t.cbt.heal(t.cbt.max_hp)
	var trail := Magic.trail(t, VIOLET, 0.4, "spark_04", 16)
	var until := Time.get_ticks_msec() / 1000.0 + dur
	FX.bark(t, ["Pour le souverain !", "Traîtres ! À moi !", "Je vous emporte avec moi !"][randi() % 3], 2.6 * float(t.def["scale"]), 2.4)
	if Hud.inst:
		Hud.inst.show_message("Possession : %s combat pour vous (%d s)" % [t.def["nom"], int(dur)], VIOLET)
	var tick := func(self_ref: Callable) -> void:
		if not Combat.alive(t):
			return
		var now := Time.get_ticks_msec() / 1000.0
		if now >= until:
			Juice.onde(t.global_position, VIOLET, 3.0, 0.5)
			FX.bark(t, "… libre…", 2.4, 1.5)
			t.remove_meta("possede")
			if is_instance_valid(trail):
				trail.queue_free()
			t.cbt.take_damage(t.cbt.max_hp * 10.0, pc.player, "arcane")
			return
		var foe: Node3D = null
		var bd := 16.0
		for m in Combat.monsters:
			if m == t or not Combat.alive(m) or m.has_meta("possede"):
				continue
			var d: float = m.global_position.distance_to(t.global_position)
			if d < bd:
				bd = d
				foe = m
			if d < 10.0:
				if m.global_position.distance_to(m.home) > m.leash * 0.7:
					m.home = m.global_position
				m.force_target = t
				m.force_until = now + 1.2
				m.peaceful = false
				m._aggro()
		if foe:
			t.force_target = foe
			t.force_until = now + 1.2
		Powers._after(0.5, func(): self_ref.call(self_ref))
	tick.call(tick)

static func _detonate(pc: PlayerCombat, t: Node3D, power: float) -> void:
	if not Combat.alive(t):
		return
	var p: Vector3 = t.global_position
	Magic.rune(p, 2.6, VIOLET, 1.2, 4.0)
	FX.bark(t, "AAAH—", 2.4, 1.0)
	Powers._after(1.1, func():
		if not is_instance_valid(t):
			return
		p = t.global_position
		Juice.onde(p, VIOLET, 6.5, 0.6)
		Juice.lueur(p, VIOLET, 5.0, 0.7, 2.0)
		Magic.burst(p + Vector3.UP, VIOLET, 2.2, true)
		Magic.sparks(p + Vector3.UP, Color(0.9, 0.6, 1.0), 40, 12.0)
		FX.shockwave(p, 6.0)
		Juice.dust(p, 22, 7.0)
		if Combat.player:
			Combat.player.shake(0.6)
		Sfx.play("explosion", -2.0)
		for m in Combat.in_radius(p, 6.0):
			if m == t:
				continue
			Powers._hurt(m, power * 2.6, pc, "arcane")
			var dv: Vector3 = m.global_position - p
			dv.y = 0
			m.throw(dv.normalized() * 9.0 + Vector3.UP * 6.0, power * 0.5, pc.player)
		t.cbt.take_damage(t.cbt.max_hp * 10.0, pc.player, "arcane"))

static func _terror(pc: PlayerCombat, t: Node3D, dur: float) -> void:
	if not Combat.alive(t):
		return
	t._stun_end = 0.0
	t._ap.speed_scale = 1.0
	t._cur = ""
	FX.bark(t, ["IL EST DANS MA TÊTE ! FUYEZ !", "LE DÉMON ! IL VA TOUS NOUS PRENDRE !"][randi() % 2], 2.6 * float(t.def["scale"]), 3.0)
	Juice.onde(t.global_position, Color(0.9, 0.2, 0.25), 9.0, 0.7)
	t.frighten(dur)
	for m in Combat.in_radius(t.global_position, 12.0):
		if m != t and not m.is_boss():
			m.frighten(dur * 0.7)
	Sfx.play("ok", -6.0)

# ================================================================== LAMES SPECTRALES
static func lames(pc: PlayerCombat, power: float, c: float, dur: float, rk: int) -> void:
	var pl := pc.player
	var n := 5 + int(round(2.0 * c)) + (rk - 1)
	var b := SpectralBlades.new()
	b.pc = pc
	b.power = power
	b.count = n
	b.lifetime = dur
	FX.root.add_child(b)
	Magic.rune(pl.global_position, 2.4, CYAN, 1.2, 2.0)
	Juice.lueur(pl.global_position, CYAN, 2.5, 0.6)
	Sfx.play("lames", -3.0)
	if Hud.inst:
		Hud.inst.show_choices([
			["bouclier", "Garde", func(): b.set_mode("garde")],
			["lames", "Assaut", func(): b.set_mode("assaut")],
			["oeil", "Ratisser", func(): b.set_mode("ratisser")],
		], 5.0, func(): b.set_mode("garde"))

# ================================================================== ONDE DE FORCE
static func onde(pc: PlayerCombat, power: float, r: float, c: float, rk: int) -> void:
	var pl := pc.player
	var p := pl.global_position
	pl.action("b/NinjaJump_Land", 0.5, 1.3)
	var waves := 1 + (1 if rk >= 3 or c >= 0.95 else 0)
	for w in waves:
		Powers._after(w * 0.28, func():
			if not is_instance_valid(pl):
				return
			var q := pl.global_position
			var rr := r * (1.0 + 0.35 * w)
			Juice.onde(q, OR_PALE, rr, 0.5)
			Juice.onde(q, Color(1, 1, 1), rr * 0.6, 0.3)
			Juice.lueur(q, OR_PALE, rr * 0.7, 0.4, 1.3)
			Juice.dust(q, 26, 9.0)
			FX.shockwave(q, rr)
			pl.shake(0.35 + 0.15 * c)
			Sfx.play("onde", -3.0)
			for m in Combat.in_radius(q, rr):
				if m.has_meta("possede"):
					continue
				var dv: Vector3 = m.global_position - q
				dv.y = 0
				var k := 1.0 - clampf(dv.length() / rr, 0.0, 0.85)
				Powers._hurt(m, power * k, pc, "physique")
				if not m.is_boss():
					m.throw(dv.normalized() * (10.0 + 8.0 * c) * k + Vector3.UP * (4.0 + 3.0 * c), power * 0.4, pl)
			# les objets du décor volent aussi
			for o in pl.get_tree().get_nodes_in_group("tk_objet"):
				var dv: Vector3 = o.global_position - q
				if dv.length() < rr:
					o.apply_central_impulse((dv.normalized() * 10.0 + Vector3.UP * 4.0) * o.mass))
	FX.cast_glow(pl, OR_PALE)
