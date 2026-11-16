extends Node
## Les 3 classes : Chronomancien, Druide, Vampire. 4 compétences chacune, évolutives (niveau 1 à 5).

const CLS := {
	"chrono": {"name":"Chronomancien", "char":"Knight", "style":"1h", "tint":Color(1, 1, 1), "cd":[16, 12, 14, 20],
		"sk":["Arrêt du temps", "Portail céleste", "Lumière sacrée", "Lame divine"]},
	"druid": {"name":"Druide", "char":"Mage", "style":"magic", "tint":Color(0.6, 1.0, 0.55), "cd":[2, 20, 10, 26],
		"sk":["Forme féline", "Esprits", "Tempête", "Sommeil"], "cat":["Forme humaine", "Célérité", "Attaque surprise", "Lacération"], "catcd":[1, 14, 8, 5]},
	"vampire": {"name":"Vampire", "char":"Rogue_Hooded", "style":"dual", "tint":Color(0.78, 0.32, 0.4), "cd":[22, 14, 15, 22],
		"sk":["Armée des morts", "Vitesse vampirique", "Étreinte", "Hypnose"]},
}
var w
var cls := "chrono"
var lvl := 1
var fast := false
var cd := [0.0, 0.0, 0.0, 0.0]
var cd_max := [1.0, 1.0, 1.0, 1.0]
var vspeed_t := 0.0
var vstep := 0
var channel := 0.0
var channel_max := 1.0
var _tick := 0.0
var angel: Actor
var pets: Array = []
var army: Array = []

func p() -> Actor: return w.player

func labels() -> Array:
	var c: Dictionary = CLS[cls]
	return c["cat"] if p().is_cat() else c["sk"]

func apply_class() -> void:
	var c: Dictionary = CLS[cls]
	var a := p()
	if a.is_cat(): a.set_cat(false)
	a.set_char(c["char"]); a.set_style(c["style"])
	if c["tint"] != Color(1, 1, 1): a.tint(c["tint"])
	a.speed_mul = 1.0; a.dmg_mul = 1.0 + 0.15 * (lvl - 1)
	a.hp_max = 600 + 80 * (lvl - 1); a.hp = a.hp_max
	cd = [0.0, 0.0, 0.0, 0.0]; vspeed_t = 0; channel = 0
	a.shot("Spawn_Air", true)

func cast(i: int) -> void:
	var a := p()
	if cd[i] > 0 or not a.can_act(): return
	var c: Dictionary = CLS[cls]
	var base: Array = c["catcd"] if a.is_cat() else c["cd"]
	var k: float = base[i] * (1.0 - 0.05 * (lvl - 1)) * (0.15 if fast else 1.0)
	var ok: bool = call("_%s_%d" % ["cat" if a.is_cat() else cls, i + 1], a)
	if ok != false: cd[i] = k; cd_max[i] = k

func _process(dt: float) -> void:
	for i in 4: cd[i] = max(cd[i] - dt, 0)
	vspeed_t = max(vspeed_t - dt, 0)
	if channel > 0: _channel(dt)

func L() -> int: return lvl

# ================= CHRONOMANCIEN =================
func _chrono_1(a: Actor) -> bool:
	var dur := 2.0 + 0.3 * (L() - 1)
	a.shot("Ranged_Magic_Raise", false)
	w.time_stop(a, dur)
	return true

func _chrono_2(a: Actor) -> bool:
	var dir := Vector3(a.move_in.x, 0, a.move_in.y)
	if dir.length() < 0.2: dir = a.fwd()
	var dist := 4.0 + L()
	var from := a.global_position
	var to := from + dir.normalized() * dist
	w.portal(from); w.portal(to)
	a.global_position = to; a.iframes = 0.4
	a.shot("Spawn_Ground", true)
	# ange gardien
	if is_instance_valid(angel) and angel.state != "dead": w.remove_actor(angel)
	angel = w.spawn("Knight", to + a.fwd().rotated(Vector3.UP, 1.4) * 1.3, 0)
	angel.set_style("2h"); angel.tint(Color(1.0, 0.95, 0.8), 0.25)
	angel.brain = "melee"; angel.owner_a = a; angel.life_t = 16.0 + 3 * L()
	angel.hp_max = 120 + 70 * (L() - 1); angel.hp = angel.hp_max
	angel.dmg_mul = 0.9 + 0.3 * (L() - 1); angel.speed_mul = 1.35
	w.wings(angel)
	angel.shot("Spawn_Air", true)
	for o in w.actors:
		if o.team == 1 and o.global_position.distance_to(to) < 9: o.taunt_by = angel; o.taunt_t = 3.0 + 0.5 * L()
	a.shield_t = 2.0 + 0.3 * L(); w.bubble(a, a.shield_t)
	return true

func _chrono_3(a: Actor) -> bool:
	a.shot("Ranged_Magic_Summon", false)
	var pct := 0.25 + 0.05 * (L() - 1)
	for o in w.actors:
		if o.team == 0 and o.state != "dead" and o.global_position.distance_to(a.global_position) < 9:
			o.heal(o.hp_max * pct); w.burst(o.global_position + Vector3.UP * 0.4, Color(0.4, 1, 0.5), 18)
	w.ring(a.global_position, 9.0, Color(0.4, 1, 0.5))
	return true

func _chrono_4(a: Actor) -> bool:
	var c: Vector3 = w.cluster(a, 10.0)
	if c == Vector3.INF: c = a.global_position + a.fwd() * 4
	a.shot("Ranged_Magic_Raise", true)
	w.divine_blade(c, 3.0 + 0.4 * (L() - 1), 60 + 25 * (L() - 1), 1.3 + 0.15 * (L() - 1))
	return true

# ================= DRUIDE =================
func _druid_1(a: Actor) -> bool:
	a.set_cat(true); a.speed_mul = 1.25; a.dmg_mul = 1.2 + 0.15 * (L() - 1)
	w.burst(a.global_position + Vector3.UP * 0.8, Color(0.4, 1, 0.5), 30); w.sfx("dash", a.global_position)
	w.refresh_labels()
	return true

func _cat_1(a: Actor) -> bool:
	a.set_cat(false); a.speed_mul = 1.0; a.dmg_mul = 1.0 + 0.15 * (L() - 1)
	var c: Dictionary = CLS[cls]; if c["tint"] != Color(1, 1, 1): a.tint(c["tint"])
	w.burst(a.global_position + Vector3.UP * 0.8, Color(0.4, 1, 0.5), 30)
	w.refresh_labels()
	return true

func _cat_2(a: Actor) -> bool:
	a.speed_mul = 1.25 * 1.7
	w.ring(a.global_position, 2.0, Color(0.6, 1, 0.4))
	var dur := 5.0 + L()
	a.delay(dur, func(): if a.is_cat(): a.speed_mul = 1.25)
	return true

func _cat_3(a: Actor) -> bool:
	var tg: Array = []
	for o in w.actors:
		if a.foe(o) and o.global_position.distance_to(a.global_position) < 9: tg.append(o)
	if tg.is_empty(): return false
	tg.sort_custom(func(x, y): return x.global_position.distance_to(a.global_position) < y.global_position.distance_to(a.global_position))
	tg = tg.slice(0, min(4, L()))
	var dmg := 35.0 + 12 * (L() - 1); var st: float = min(1.0 + 0.2 * (L() - 1), 1.7)
	a.busy = 0.3 * tg.size() + 0.2; a.root_lock = a.busy; a.iframes = a.busy
	for i in tg.size():
		var o: Actor = tg[i]
		a.delay(0.25 * i, func():
			if o.state == "dead": return
			var d := (o.global_position - a.global_position).normalized()
			a.global_position = o.global_position - d * 1.0; a.face = atan2(d.x, d.z); a.rotation.y = a.face
			a.shot("claw2"); o.hurt(dmg * a.dmg_mul, a.global_position, 3, a); o.stun(st)
			w.burst(o.global_position + Vector3.UP, Color(0.6, 1, 0.4), 14); w.sfx("hit", o.global_position))
	return true

func _cat_4(a: Actor) -> bool:
	a.shot("claw2"); a.busy = 0.35
	a.melee(18 + 6 * (L() - 1), 2.3, 360, 2)
	w.ring(a.global_position, 2.3, Color(1, 0.75, 0.3))
	return true

func _druid_2(a: Actor) -> bool:
	for x in pets: if is_instance_valid(x): w.remove_actor(x)
	pets.clear()
	a.shot("Ranged_Magic_Summon", true)
	var defs := [["Mage", "heal", Color(0.55, 1, 0.7), 0.62], ["Barbarian", "tank", Color(0.75, 0.6, 0.4), 0.8], ["cat", "melee", Color.WHITE, 0.6], ["Rogue_Hooded", "ranged", Color(1, 0.65, 0.35), 0.68]]
	for i in 4:
		var d: Array = defs[i]
		var pos := a.global_position + Vector3(cos(i * TAU / 4), 0, sin(i * TAU / 4)) * 1.8
		var e: Actor = w.spawn("Barbarian" if d[0] == "cat" else d[0], pos, 0)
		if d[0] == "cat":
			e.set_cat(true); e.cat.scale = Vector3.ONE * d[3]
		else:
			e.model.scale = Vector3.ONE * d[3]; e.tint(d[2], 0.25)
			if d[1] == "ranged": e.set_style("xbow")
		e.brain = "melee" if d[1] == "tank" else d[1]; e.owner_a = a; e.life_t = 30.0
		e.hp_max = (260 if d[1] == "tank" else 90) * (1 + 0.35 * (L() - 1)); e.hp = e.hp_max
		e.dmg_mul = 0.5 + 0.2 * (L() - 1)
		w.burst(pos + Vector3.UP * 0.5, d[2], 16)
		pets.append(e)
		if d[1] == "tank":
			for o in w.actors: if o.team == 1: o.taunt_by = e; o.taunt_t = 4.0
		if d[1] == "heal": _heal_loop(e, a)
	return true

func _heal_loop(e: Actor, a: Actor) -> void:
	e.delay(5.0, func():
		if not is_instance_valid(a) or e.state == "dead": return
		e.shot("Ranged_Magic_Summon", true)
		a.heal(a.hp_max * (0.2 + 0.03 * (L() - 1)))
		w.beam_between(e, a, Color(0.4, 1, 0.5))
		_heal_loop(e, a))

func _druid_3(a: Actor) -> bool:
	var c: Vector3 = w.cluster(a, 11.0)
	if c == Vector3.INF: c = a.global_position + a.fwd() * 5
	a.shot("Ranged_Magic_Spellcasting_Long", true); a.root_lock = 0.9
	w.ring(c, 3.2, Color(0.6, 0.7, 1))
	var n := 5 + L()
	for k in n:
		a.delay(0.5 + k * 2.4 / n, func():
			var q := c + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
			w.lightning(q)
			for o in w.actors:
				if a.foe(o) and o.global_position.distance_to(q) < 1.6: o.hurt((22 + 8 * (L() - 1)) * a.dmg_mul, q, 2, a); o.stun(0.3))
	return true

func _druid_4(a: Actor) -> bool:
	a.shot("Ranged_Magic_Summon", true)
	w.ring(a.global_position, 30.0, Color(0.6, 0.55, 1))
	for o in w.actors:
		if o.team == 1 and o.state != "dead": o.put_sleep(8.0 + 0.5 * (L() - 1))
	return true

# ================= VAMPIRE =================
func _vampire_1(a: Actor) -> bool:
	for x in army: if is_instance_valid(x): w.remove_actor(x)
	army.clear()
	a.shot("Ranged_Magic_Summon", true)
	for i in 5:
		var pos := a.global_position + Vector3(cos(i * TAU / 5), 0, sin(i * TAU / 5)) * 2.2
		var e: Actor = w.spawn("Skeleton_Rogue", pos, 0)
		e.tint(Color(1.0, 0.45, 0.5), 0.35)
		e.brain = "melee"; e.owner_a = a; e.life_t = 20.0 + 4 * (L() - 1)
		e.hp_max = 60 + 25 * (L() - 1); e.hp = e.hp_max; e.dmg_mul = 0.7 + 0.2 * (L() - 1)
		e.on_hit_heal = a; e.heal_amt = 3 + L()
		e.busy = e.shot("Skeletons_Awaken_Floor", true); e.root_lock = e.busy
		w.burst(pos + Vector3.UP * 0.2, Color(0.7, 0.1, 0.15), 18)
		army.append(e)
	return true

func _vampire_2(a: Actor) -> bool:
	vspeed_t = 8.0 + L(); vstep = 0
	w.ring(a.global_position, 2.0, Color(0.9, 0.15, 0.25))
	return true

## Coups automatiques sous Vitesse vampirique : 1) éclair sur la cible 2) zone 3) recul + étourdissement
func on_basic(a: Actor, _combo: int) -> bool:
	if cls != "vampire" or vspeed_t <= 0: return false
	vstep = vstep % 3 + 1
	var dmg := (20.0 + 6 * (L() - 1))
	match vstep:
		1:
			var t := a.nearest_foe(8.0)
			if t:
				var d := (t.global_position - a.global_position).normalized()
				w.afterimage(a); a.global_position = t.global_position - d * 1.1
				a.face = atan2(d.x, d.z); a.rotation.y = a.face
			a.do_act(["Melee_Dualwield_Attack_Stab", dmg, 1.9, 70, 2, true, ""])
		2:
			a.do_act(["Melee_Dualwield_Attack_Slice", 0, 0, 0, 0, true, ""])
			a.delay(0.2, func(): a.melee(dmg, 1.6, 360, 2); w.ring(a.global_position, 1.6, Color(0.9, 0.15, 0.25)))
		3:
			a.do_act(["Melee_Dualwield_Attack_Chop", 0, 0, 0, 0, true, ""])
			a.delay(0.2, func():
				a.melee(dmg, 2.2, 120, 1, 1.3)
				w.afterimage(a); a.dodge_v = -a.fwd() * 12.0)
	return true

func _vampire_3(a: Actor) -> bool:
	channel_max = 3.3 + 0.2 * (L() - 1); channel = channel_max; _tick = 0
	a.hold("Ranged_Magic_Spellcasting_Long"); a.state = "hold"
	for o in w.actors:
		if a.foe(o) and o.global_position.distance_to(a.global_position) < 6.5: o.lift(channel_max)
	return true

func _channel(dt: float) -> void:
	var a := p()
	if a.move_in.length() > 0.3 or a.incap():
		channel = 0
		for o in w.actors: if o.lift_t > 0: o.lift_t = 0.01
		return
	channel -= dt; _tick -= dt
	if _tick <= 0:
		_tick = 0.3
		var prog := 1.0 + 1.5 * (1.0 - channel / channel_max)   # dégâts progressifs
		for o in w.actors:
			if o.lift_t > 0 and a.foe(o):
				var d := (6.0 + 3 * (L() - 1)) * prog
				o.hurt(d, a.global_position, 0, a); a.heal(d * 0.35)
				w.beam_between(a, o, Color(0.9, 0.1, 0.2))
	if channel <= 0: a.hold(""); a.state = "loco"

func _vampire_4(a: Actor) -> bool:
	a.shot("Skeletons_Taunt", true)
	w.ring(a.global_position, 10.0, Color(0.85, 0.3, 1))
	for o in w.actors:
		if o.team == 1 and o.state != "dead" and o.global_position.distance_to(a.global_position) < 10:
			o.hyp_t = 2.0 + 0.5 * (L() - 1); o.target = null; o.taunt_t = 0
	return true
