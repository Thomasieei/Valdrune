class_name SpectralBlades
extends Node3D
## Lames spectrales : une couronne d'épées fantômes autour du souverain, menée selon un ordre.
## garde : elles tournent serré, frappent qui approche et absorbent une part des coups.
## assaut : elles fondent une à une sur les ennemis proches et reviennent.
## ratisser : elles s'écartent en un grand cercle tournoyant qui fauche tout sur son passage.

var pc: PlayerCombat
var power := 20.0
var count := 6
var lifetime := 20.0
var mode := "garde"
var _blades: Array = []      # {n: Node3D, t: Node3D, phase: String, cd: float}
var _t0 := 0.0
var _hit_cd := {}
const COL := Color(0.55, 0.95, 0.95)

func _ready() -> void:
	_t0 = Time.get_ticks_msec() / 1000.0
	for i in count:
		var h := Node3D.new()
		add_child(h)
		var s := Kit.dungeon(h, "Sword", Vector3.ZERO, 0.0, 1.2)
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = Powers.spectral_mat(COL, 0.7)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.rotation_degrees = Vector3(90, 0, 0)   # pointe vers l'avant (-Z local)
		if i % 2 == 0:
			Magic.trail(h, COL, 0.3, "spark_04", 10)
		h.scale = Vector3.ONE * 0.05
		h.create_tween().tween_property(h, "scale", Vector3.ONE, 0.3)
		if pc:
			h.global_position = pc.player.global_position + Vector3.UP * 1.2
		_blades.append({"n": h, "t": null, "phase": "orbite", "cd": 0.0})

func set_mode(m: String) -> void:
	mode = m
	if pc and is_instance_valid(pc.player):
		Juice.onde(pc.player.global_position, COL, 3.0 if m == "garde" else 7.5, 0.4)
		pc.message.emit({"garde": "Lames : garde rapprochée", "assaut": "Lames : à l'assaut !", "ratisser": "Lames : ratissez tout !"}[m], COL)
	for b in _blades:
		b["phase"] = "orbite"
		b["t"] = null

func _hit(m: Node3D, mult: float, at: Vector3) -> void:
	if m.has_meta("possede"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_hit_cd.get(m.get_instance_id(), 0.0)):
		return
	_hit_cd[m.get_instance_id()] = now + 0.45
	Powers._hurt(m, power * mult, pc, "arcane")
	Magic.sparks(at, COL, 10, 6.0)
	Sfx.play("coup", -8.0)

func _process(delta: float) -> void:
	if pc == null or not is_instance_valid(pc.player):
		queue_free()
		return
	var pl := pc.player
	var now := Time.get_ticks_msec() / 1000.0
	var age := now - _t0
	if age > lifetime:
		for b in _blades:
			Magic.halo(b["n"].global_position, 1.2, COL, 0.25)
		queue_free()
		return
	var center := pl.global_position + Vector3.UP * 1.2
	if mode == "garde":
		if pl.cbt.now() >= pl.cbt.incoming_until or pl.cbt.incoming_mult >= 0.75:
			pl.cbt.incoming_mult = 0.75
			pl.cbt.incoming_until = pl.cbt.now() + 0.3
	var n := _blades.size()
	for i in n:
		var b: Dictionary = _blades[i]
		var h: Node3D = b["n"]
		var a := TAU * i / n
		match mode:
			"garde":
				var ang := a + age * 3.2
				var want := center + Vector3(cos(ang) * 1.7, sin(age * 4.0 + i) * 0.15, sin(ang) * 1.7)
				h.global_position = h.global_position.lerp(want, clampf(delta * 12.0, 0, 1))
				_orient(h, Vector3(-sin(ang), 0, cos(ang)))
				for m in Combat.in_radius(h.global_position, 1.2):
					_hit(m, 0.45, h.global_position)
			"ratisser":
				var ang := a + age * 2.6
				var R := 7.0
				var want := center + Vector3(cos(ang) * R, -0.2, sin(ang) * R)
				h.global_position = h.global_position.lerp(want, clampf(delta * 8.0, 0, 1))
				_orient(h, Vector3(-sin(ang), 0, cos(ang)))
				for m in Combat.in_radius(h.global_position, 1.6):
					_hit(m, 0.6, h.global_position)
			"assaut":
				var t: Node3D = b["t"]
				if b["phase"] == "orbite":
					var ang := a + age * 2.0
					h.global_position = h.global_position.lerp(center + Vector3(cos(ang) * 1.8, 0.6, sin(ang) * 1.8), clampf(delta * 10.0, 0, 1))
					_orient(h, Vector3.DOWN + Vector3(cos(ang), 0, sin(ang)) * 0.2)
					b["cd"] = float(b["cd"]) - delta
					if b["cd"] <= 0.0:
						var foe := _pick(h.global_position, i)
						if foe:
							b["t"] = foe
							b["phase"] = "fonce"
				elif b["phase"] == "fonce":
					if not Combat.alive(t):
						b["phase"] = "orbite"
						continue
					var dest: Vector3 = t.global_position + Vector3.UP
					var d := dest - h.global_position
					_orient(h, d)
					if d.length() < 0.8:
						_hit(t, 0.8, dest)
						Juice.impact(dest, COL, false)
						b["phase"] = "orbite"
						b["cd"] = 0.5 + randf() * 0.3
					else:
						h.global_position += d.normalized() * minf(d.length(), 28.0 * delta)

func _pick(from: Vector3, i: int) -> Node3D:
	var cands := Combat.in_radius(pc.player.global_position, 14.0)
	if cands.is_empty():
		return null
	cands.sort_custom(func(x, y): return x.global_position.distance_to(from) < y.global_position.distance_to(from))
	return cands[i % cands.size()]

func _orient(h: Node3D, dir: Vector3) -> void:
	if dir.length() < 0.01:
		return
	var tgt := h.global_position + dir.normalized()
	if absf(dir.normalized().y) > 0.98:
		h.look_at(tgt, Vector3.FORWARD)
	else:
		h.look_at(tgt, Vector3.UP)
