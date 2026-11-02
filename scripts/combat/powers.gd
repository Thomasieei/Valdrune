class_name Powers
## Les 20 pouvoirs du souverain. Chaque pouvoir est une fonction qui s'appuie sur des briques communes :
## ciblage (point visé, ennemis d'une zone), contrôles des créatures (étourdir, soulever, projeter, attirer,
## agenouiller — Monster), effets visuels procéduraux (matériaux spectraux, sol, lumière, secousse) et dégâts
## élémentaires (Combatant). Les coûts, recharges, portées et durées viennent de SpellDB.

static var _mats := {}
static var eye_until := 0.0

# ------------------------------------------------------------------ briques communes
static func spectral_mat(col: Color, alpha := 0.6) -> Material:
	# énergie translucide animée (veines, contour lumineux) au lieu d'une matière opaque « en pâte »
	return Magic.energy(col, alpha * 0.55)

static func solid(col: Color, emit := 0.0) -> StandardMaterial3D:
	var key := "s|%s|%.1f" % [col.to_html(), emit]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.85
		if emit > 0.0:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = emit
		_mats[key] = m
	return _mats[key]

static func ground(p: Vector3) -> float:
	var gy := Terrain.height_at(p.x, p.z)
	var space := FX.root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, maxf(p.y, gy) + 2.0, p.z), Vector3(p.x, minf(p.y, gy) - 2.0, p.z), 1 | 2)
	var hit := space.intersect_ray(q)
	if hit and hit.position.y < p.y + 1.5:
		gy = maxf(gy, hit.position.y)
	return gy

## Point visé : ennemi dans la direction visée, sinon la cible courante, sinon devant le joueur
static func aim_point(pc: PlayerCombat, aim: Vector3, rng: float) -> Vector3:
	var pl := pc.player
	var dir := aim if aim != Vector3.ZERO else pl.forward()
	var t: Node3D = Combat.best_target(pl.global_position, dir, rng, 35.0)
	if aim == Vector3.ZERO and pc.target and Combat.alive(pc.target) and pc.target.global_position.distance_to(pl.global_position) <= rng:
		t = pc.target
	var p: Vector3
	if t:
		p = t.global_position
	else:
		p = pl.global_position + dir * minf(rng, 8.0)
	p.y = ground(p)
	return p

static func aim_target(pc: PlayerCombat, aim: Vector3, rng: float) -> Node3D:
	var pl := pc.player
	if aim == Vector3.ZERO and pc.target and Combat.alive(pc.target) and pc.target.global_position.distance_to(pl.global_position) <= rng:
		return pc.target
	return Combat.best_target(pl.global_position, aim if aim != Vector3.ZERO else pl.forward(), rng, 35.0)

static func _node(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	FX.root.add_child(n)
	n.global_position = pos
	return n

static func _box(parent: Node3D, size: Vector3, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _ring(parent: Node3D, r: float, col: Color, tex := "circle_05") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = q
	mi.material_override = FX.pmat(tex, true, false, col)
	mi.rotation = Vector3(-PI / 2.0, 0, 0)
	mi.position.y = 0.12
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _after(t: float, f: Callable) -> void:
	FX.root.get_tree().create_timer(t).timeout.connect(f)

static func _fade_free(n: Node3D, t: float, dur := 0.4) -> void:
	var tw := n.create_tween()
	tw.tween_interval(t)
	tw.tween_property(n, "scale", Vector3(0.01, 0.01, 0.01), dur)
	tw.tween_callback(n.queue_free)

static func _hurt(m: Node3D, dmg: float, pc: PlayerCombat, elem: String) -> void:
	if Combat.alive(m):
		m.cbt.take_damage(dmg, pc.player, elem)

# ------------------------------------------------------------------ point d'entrée
static func exec(pc: PlayerCombat, id: String, power: float, c: float, aim: Vector3) -> void:
	var d: Dictionary = SpellDB.DEFS[id]
	var pl := pc.player
	var anim: String = d.get("anim", "Spell_Simple_Shoot")
	pl.action(anim, 0.6, 1.3)
	var el: String = d.get("element", "arcane")
	var rk := Progression.get_inst().rank(id)
	var dur: float = float(d.get("duree", 0.0)) * (1.0 + 0.15 * (rk - 1)) * (1.0 + 0.4 * c)
	var r: float = float(d.get("rayon", 4.0)) * (1.0 + 0.35 * c)
	var rng: float = d["portee"]
	match id:
		"main_invisible": _main_invisible(pc, power, c, aim, rng, el)
		"ecrasement": _ecrasement(pc, power, aim_point(pc, aim, rng), r, dur, el)
		"arsenal": _arsenal(pc, power, 5 + int(round(3.0 * c)) + (rk - 1), el)
		"projection": _projection(pc, power, aim_target(pc, aim, rng), el)
		"singularite": _singularite(pc, power, aim_point(pc, aim, rng), r, dur, el)
		"dome": _dome(pc, r, dur)
		"mur": _mur(pc, power, aim, dur, el)
		"reflet": _reflet(pc, dur)
		"arret_temps": _arret(pc, r, dur)
		"chaines": _chaines(pc, power, aim_point(pc, aim, rng), r, dur, el)
		"meteore": _meteore(pc, power, aim_point(pc, aim, rng), r, el)
		"piliers": _piliers(pc, power, aim_point(pc, aim, rng), r, el)
		"orage": _orage(pc, power, aim_point(pc, aim, rng), r, dur, c, el)
		"main_titan": _main_titan(pc, power, aim_point(pc, aim, rng), r, el)
		"faille": _faille(pc, power, aim_point(pc, aim, rng), r, dur, el)
		"legion": _legion(pc, 3 + (1 if c >= 0.6 else 0) + (rk - 1), dur)
		"presence": _presence(pc, r, dur)
		"oeil": _oeil(pc, dur)
		"transposition": _transposition(pc, power, aim, rng, el)
		"incarnation": _incarnation(pc, dur)

# ================================================================== TÉLÉKINÉSIE
static func _beam(from: Node3D, to: Node3D, col: Color, t: float) -> void:
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 1.0)
	b.mesh = bm
	b.material_override = Magic.energy(col, 0.6, 0.0, 1.0)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FX.root.add_child(b)
	if is_instance_valid(to):
		Magic.halo(to.global_position + Vector3.UP, 3.0, col, 0.5)
		Magic.sparks(to.global_position + Vector3.UP, col, 16, 5.0)
	var tw := b.create_tween()
	tw.tween_method(func(_k: float):
		if not is_instance_valid(from) or not is_instance_valid(to):
			return
		var a := from.global_position + Vector3.UP * 1.4 + from.global_transform.basis.z * 0.5
		var z := to.global_position + Vector3.UP * 1.0
		var l := a.distance_to(z)
		if l < 0.1:
			return
		b.global_position = (a + z) * 0.5
		b.look_at(z, Vector3.UP)
		b.scale = Vector3(1.0 + sin(_k * 40.0) * 0.3, 1.0, l), 0.0, 1.0, t)
	tw.tween_callback(b.queue_free)

static func _main_invisible(pc: PlayerCombat, power: float, c: float, aim: Vector3, rng: float, el: String) -> void:
	var pl := pc.player
	var t := aim_target(pc, aim, rng)
	var fwd := aim if aim != Vector3.ZERO else pl.forward()
	if t:
		pl.rotation.y = atan2(t.global_position.x - pl.global_position.x, t.global_position.z - pl.global_position.z)
		fwd = pl.forward()
		_beam(pl, t, Color(0.7, 0.5, 1.0), 0.75)
		if t.lift(2.4 + c, 0.7):
			FX.cast_glow(t, Color(0.7, 0.5, 1.0))
			_after(0.7, func():
				if Combat.alive(t) and t.state == Monster.S.SOULEVE:
					t.throw(fwd * (11.0 + 10.0 * c) + Vector3.UP * 4.0, power, pl)
					Sfx.play("lourd", -8.0))
		else:
			_hurt(t, power, pc, el)
		Sfx.play("ok", -6.0)
		return
	# aucun ennemi : un objet du décor (tonneau, caisse) dans la direction visée
	var best: RigidBody3D = null
	var bd := rng
	for o in pl.get_tree().get_nodes_in_group("tk_objet"):
		var dv: Vector3 = o.global_position - pl.global_position
		var dist := dv.length()
		if dist < bd and fwd.dot(dv.normalized()) > 0.4:
			bd = dist
			best = o
	if best:
		var obj := best
		obj.freeze = true
		_beam(pl, obj, Color(0.7, 0.5, 1.0), 0.65)
		var tw := obj.create_tween()
		tw.tween_property(obj, "global_position", obj.global_position + Vector3.UP * 2.5, 0.55).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			obj.freeze = false
			obj.set_meta("degats", power)
			obj.apply_central_impulse((fwd * (14.0 + 10.0 * c) + Vector3.UP * 2.0) * obj.mass))
	else:
		pc.message.emit("Rien à saisir", Color(0.8, 0.75, 1.0))

## Objets que la télékinésie peut saisir (corps physiques ; ils blessent les ennemis qu'ils percutent)
static func spawn_props(world: Node3D) -> void:
	var spots := [
		[Vector2(8, -26), "Prop_Barrel_1"], [Vector2(9.5, -25), "Prop_Crate_1"], [Vector2(-9, -30), "Prop_Barrel_2"], [Vector2(-11, -12), "Prop_Crate_1"],
		[Vector2(14, -6), "Prop_Barrel_1"], [Vector2(-6, -112), "Prop_Crate_1"], [Vector2(-4.5, -126), "Prop_Barrel_1"], [Vector2(22, -96), "Prop_Crate_1"],
		[Vector2(30, 205), "Prop_Barrel_2"], [Vector2(40, 210), "Prop_Crate_1"], [Vector2(-28, 96), "Prop_Barrel_1"], [Vector2(28, 140), "Prop_Crate_1"],
	]
	for sp in spots:
		var p: Vector2 = sp[0]
		var rb := RigidBody3D.new()
		rb.add_to_group("tk_objet")
		rb.collision_layer = 2
		rb.collision_mask = 1 | 2 | 16
		rb.mass = 40.0
		rb.contact_monitor = true
		rb.max_contacts_reported = 4
		rb.can_sleep = true
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.9, 1.1, 0.9)
		cs.shape = bs
		cs.position.y = 0.55
		rb.add_child(cs)
		Kit.village(rb, sp[1], Vector3.ZERO, randf() * TAU, 1.2)
		world.add_child(rb)
		rb.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.05, p.y)
		rb.body_entered.connect(func(b):
			if b is Monster and rb.has_meta("degats") and rb.linear_velocity.length() > 4.0:
				b.cbt.take_damage(float(rb.get_meta("degats")), Combat.player, "physique")
				b.knockback(rb.linear_velocity.normalized() * 6.0)
				FX.hit_spark(b.global_position + Vector3.UP, Color(0.8, 0.7, 1.0))
				rb.remove_meta("degats"))

static func _ecrasement(pc: PlayerCombat, power: float, at: Vector3, r: float, dur: float, el: String) -> void:
	var n := _node(at)
	Magic.rune(at, r * 1.1, Color(0.6, 0.3, 1.0), dur, 1.2)
	Magic.burst(at, Color(0.6, 0.3, 1.0), 1.4, true)
	var ring := _ring(n, r, Color(0.45, 0.2, 0.8, 0.9), "twirl_02")
	var tw := ring.create_tween()
	tw.set_loops(int(dur / 0.6) + 1)
	tw.tween_property(ring, "rotation:y", ring.rotation.y + PI, 0.6)
	var dark := _ring(n, r * 0.9, Color(0.15, 0.05, 0.3, 0.8))
	dark.material_override = FX.pmat("circle_05", false, false, Color(0.12, 0.04, 0.25, 0.7))
	var fall := FX.particles("spark_04", 40, 0.5, [Color(0.7, 0.5, 1, 1), Color(0.3, 0.1, 0.6, 0)], 0.25, false)
	fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fall.emission_sphere_radius = r
	fall.direction = Vector3.DOWN
	fall.spread = 5.0
	fall.initial_velocity_min = 12.0
	fall.initial_velocity_max = 16.0
	fall.gravity = Vector3(0, -20, 0)
	n.add_child(fall)
	fall.position.y = 5.0
	fall.emitting = true
	FX.shockwave(at, r)
	FX.impact_light(at, Color(0.5, 0.25, 1.0), 4.0, r * 2.5)
	pc.player.shake(0.35)
	var victims := Combat.in_radius(at, r)
	for m in victims:
		if m.stun(dur, false):
			var mdl: Node3D = m._model
			var sc: float = m.def["scale"]
			var t2 := mdl.create_tween()
			t2.tween_property(mdl, "scale", Vector3(1.25, 0.55, 1.25) * sc, 0.15)
			t2.tween_interval(maxf(0.1, dur - 0.3))
			t2.tween_property(mdl, "scale", Vector3.ONE * sc, 0.15)
	var ticks := 5
	for k in ticks:
		_after(dur * (k + 1) / ticks, func():
			for m in victims:
				_hurt(m, power / ticks * 1.6, pc, el))
	_fade_free(n, dur, 0.3)

static func _arsenal(pc: PlayerCombat, power: float, count: int, el: String) -> void:
	var pl := pc.player
	var swords := []
	for i in count:
		var holder := Node3D.new()
		FX.root.add_child(holder)
		var s := Kit.dungeon(holder, "Sword", Vector3.ZERO, 0.0, 1.4)
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			mi.material_override = spectral_mat(Color(0.5, 0.8, 1.0), 0.75)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.rotation_degrees = Vector3(180, 0, 0)
		Magic.trail(holder, Color(0.5, 0.8, 1.0), 0.35, "spark_04", 14)
		holder.scale = Vector3.ONE * 0.05
		swords.append(holder)
	# les épées apparaissent en couronne au-dessus du souverain, pointe vers le bas
	var t0 := Time.get_ticks_msec() / 1000.0
	for i in swords.size():
		var h: Node3D = swords[i]
		var k := i
		var tw := h.create_tween()
		tw.tween_property(h, "scale", Vector3.ONE, 0.25)
		tw.tween_method(func(_u: float):
			if not is_instance_valid(pl):
				return
			var a := TAU * k / count + (Time.get_ticks_msec() / 1000.0 - t0) * 2.2
			h.global_position = pl.global_position + Vector3(cos(a) * 1.6, 2.4 + sin(a * 2.0) * 0.15, sin(a) * 1.6), 0.0, 1.0, 0.55 + k * 0.12)
		tw.tween_callback(func(): _launch_sword(pc, h, power, el))
	FX.cast_glow(pl, Color(0.5, 0.8, 1.0))
	Magic.rune(pl.global_position, 2.6, Color(0.5, 0.8, 1.0), 1.6, 1.5)
	Sfx.play("ok", -4.0)

static func _launch_sword(pc: PlayerCombat, h: Node3D, power: float, el: String) -> void:
	var pl := pc.player
	var t: Node3D = Combat.best_target(pl.global_position, pl.forward(), 20.0, 80.0)
	var dest: Vector3 = (t.global_position + Vector3.UP * 1.0) if t else (pl.global_position + pl.forward() * 14.0 + Vector3.UP)
	h.look_at(dest, Vector3.UP)
	h.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
	var tw := h.create_tween()
	tw.tween_property(h, "global_position", dest, 0.18)
	tw.tween_callback(func():
		Magic.halo(dest, 2.5, Color(0.6, 0.85, 1.0), 0.25)
		if t and Combat.alive(t):
			_hurt(t, power, pc, el)
			Magic.sparks(dest, Color(0.6, 0.85, 1.0), 14, 7.0)
			Sfx.play("touche", -6.0)
		h.queue_free())

static func _projection(pc: PlayerCombat, power: float, t: Node3D, el: String) -> void:
	var pl := pc.player
	if t == null:
		pc.message.emit("Aucune cible à portée", Color(1, 0.8, 0.4))
		return
	pl.rotation.y = atan2(t.global_position.x - pl.global_position.x, t.global_position.z - pl.global_position.z)
	_beam(pl, t, Color(0.85, 0.5, 1.0), 0.6)
	if not t.lift(3.0, 1.0):
		_hurt(t, power * 0.7, pc, el)
		return
	var dest := pl.global_position + pl.forward() * 3.0
	var tw := t.create_tween()
	tw.tween_property(t, "global_position", Vector3(dest.x, t.global_position.y + 3.0, dest.z), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if Combat.alive(t):
			t._ground_ref = Powers.ground(t.global_position)
			t.throw(Vector3(0, -26.0, 0), power, pl)
			_after(0.18, func():
				Magic.burst(Vector3(dest.x, Powers.ground(dest), dest.z), Color(0.85, 0.5, 1.0), 1.6, true)
				pl.shake(0.4)
				FX.hitstop(0.08)
				for m in Combat.in_radius(dest, 3.0):
					if m != t:
						_hurt(m, power * 0.4, pc, el)))

static func _singularite(pc: PlayerCombat, power: float, at: Vector3, r: float, dur: float, el: String) -> void:
	var n := _node(at + Vector3.UP * 1.2)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	sm.radial_segments = 16
	sm.rings = 8
	core.mesh = sm
	core.material_override = solid(Color(0.03, 0.0, 0.06))
	n.add_child(core)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4, 4)
	halo.mesh = q
	halo.material_override = FX.pmat("twirl_02", true, true, Color(0.6, 0.3, 1.0))
	n.add_child(halo)
	var ring := _ring(n, r, Color(0.5, 0.2, 0.9, 0.6), "twirl_02")
	ring.position.y = -1.1
	# disque d'accrétion : anneau d'énergie qui tourne vite autour du cœur noir
	var disc := MeshInstance3D.new()
	var tmh := TorusMesh.new()
	tmh.inner_radius = 0.9
	tmh.outer_radius = 2.2
	tmh.rings = 24
	tmh.ring_segments = 8
	disc.mesh = tmh
	disc.material_override = Magic.energy(Color(0.75, 0.35, 1.0), 0.45, 0.0, 1.0)
	disc.scale = Vector3(1, 0.12, 1)
	disc.rotation.x = 0.35
	n.add_child(disc)
	var td := disc.create_tween()
	td.tween_property(disc, "rotation:y", TAU * dur * 1.5, dur)
	Magic.rune(at, r, Color(0.6, 0.3, 1.0), dur, -1.5)
	var suck := FX.particles("spark_04", 50, 0.7, [Color(0.8, 0.6, 1, 1), Color(0.4, 0.1, 0.8, 0)], 0.2, false)
	suck.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	suck.emission_sphere_radius = r
	suck.radial_accel_min = -30.0
	suck.radial_accel_max = -22.0
	suck.gravity = Vector3.ZERO
	n.add_child(suck)
	suck.emitting = true
	var tw := n.create_tween()
	tw.set_parallel(true)
	tw.tween_property(halo, "rotation:z", TAU * 3.0, dur)
	tw.tween_property(ring, "rotation:y", -TAU * 2.0, dur)
	tw.tween_property(core, "scale", Vector3.ONE * 1.6, dur)
	tw.chain().tween_property(core, "scale", Vector3.ONE * 0.1, 0.15)
	# attraction continue (tween séparé : elle doit durer toute la vie du vortex)
	var tp := n.create_tween()
	tp.tween_method(func(_k: float):
		var dt := FX.root.get_process_delta_time()
		for m in Combat.in_radius(at, r * 1.2):
			m.pull(at, 7.0, dt)
		for o in FX.root.get_tree().get_nodes_in_group("tk_objet"):
			if o.global_position.distance_to(at) < r:
				o.apply_central_force((at - o.global_position).normalized() * o.mass * 25.0), 0.0, 1.0, dur)
	pc.player.shake(0.2)
	_after(dur, func():
		FX.explosion(at + Vector3.UP, r * 0.6)
		Magic.burst(at, Color(0.7, 0.4, 1.0), 2.2, true)
		FX.impact_light(at, Color(0.6, 0.3, 1.0), 7.0, r * 3.0)
		FX.hitstop(0.08)
		if Combat.player:
			Combat.player.shake(0.5)
		for m in Combat.in_radius(at, r * 0.8):
			_hurt(m, power, pc, el)
			var dv: Vector3 = m.global_position - at
			dv.y = 0
			m.knockback((dv.normalized() if dv.length() > 0.1 else Vector3.FORWARD) * 9.0)
		n.queue_free())

# ================================================================== DÉFENSE
static func _dome(pc: PlayerCombat, r: float, dur: float) -> void:
	var pl := pc.player
	var n := Node3D.new()
	pl.add_child(n)
	var sph := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	sph.mesh = sm
	sph.material_override = Magic.energy(Color(1.0, 0.82, 0.4), 0.06, 1.0, 1.0)
	Magic.rune(pl.global_position, r, Color(1.0, 0.8, 0.4), dur, 0.4)
	Magic.halo(pl.global_position + Vector3.UP, r * 2.0, Color(1.0, 0.85, 0.5), 0.4)
	sph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(sph)
	sph.position.y = 0.6
	sph.scale = Vector3.ONE * 0.05
	var tw := sph.create_tween()
	tw.tween_property(sph, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	pl.cbt.invulnerable_until = Combatant.now() + dur
	FX.impact_light(pl.global_position, Color(1, 0.85, 0.4), 4.0, r * 3.0)
	Sfx.play("bouclier", -2.0)
	# repousse ce qui tente d'entrer (à chaque pas physique)
	var bar := DomeBarrier.new()
	bar.radius = r
	n.add_child(bar)
	var tw2 := n.create_tween()
	tw2.tween_interval(dur)
	tw2.tween_property(sph, "scale", Vector3.ONE * 0.01, 0.25)
	tw2.tween_callback(n.queue_free)

static func _mur(pc: PlayerCombat, power: float, aim: Vector3, dur: float, el: String) -> void:
	var pl := pc.player
	var fwd := aim if aim != Vector3.ZERO else pl.forward()
	var at := pl.global_position + fwd * 4.0
	at.y = ground(at)
	var yaw := atan2(fwd.x, fwd.z)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	FX.root.add_child(body)
	body.global_position = at + Vector3.DOWN * 3.2
	body.rotation.y = yaw
	var size := Vector3(9.0, 3.2, 0.9)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	body.add_child(cs)
	var stone: StandardMaterial3D = Geo.mat("pierre_claire").duplicate()
	stone.uv1_triplanar = true
	stone.uv1_world_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.4
	_box(body, size, stone, Vector3(0, size.y * 0.5, 0))
	for k in 5:
		_box(body, Vector3(0.55, 0.9, 0.95), Magic.energy(Color(1.0, 0.75, 0.3), 0.8, 0.0, 1.0), Vector3(-3.6 + k * 1.8, size.y * 0.6, 0))
	_box(body, Vector3(9.2, 0.12, 0.96), Magic.energy(Color(1.0, 0.75, 0.35), 0.7, 0.0, 1.0), Vector3(0, size.y * 0.3, 0))
	for k in 4:
		Magic.debris(at + Vector3(fwd.z, 0, -fwd.x) * (-3.4 + k * 2.3), 6, 7.0)
	var tw := body.create_tween()
	tw.tween_property(body, "global_position:y", at.y, 0.35).set_ease(Tween.EASE_OUT)
	FX.shockwave(at, 4.5)
	pl.shake(0.4)
	Sfx.play("lourd", -2.0)
	var side := Vector3(fwd.z, 0, -fwd.x)
	for m in Combat.in_radius(at, 5.5):
		var local: Vector3 = m.global_position - at
		if absf(local.dot(fwd)) < 2.0 and absf(local.dot(side)) < 5.0:
			_hurt(m, power, pc, el)
			m.knockback(fwd * (8.0 if local.dot(fwd) >= 0.0 else -8.0))
	var tw2 := body.create_tween()
	tw2.tween_interval(dur)
	tw2.tween_property(body, "global_position:y", at.y - 3.4, 0.6)
	tw2.tween_callback(body.queue_free)

static func _reflet(pc: PlayerCombat, dur: float) -> void:
	var pl := pc.player
	pl.cbt.reflect_until = Combatant.now() + dur
	pl.cbt.reflect_ratio = 1.0
	var n := Node3D.new()
	pl.add_child(n)
	n.position.y = 1.1
	for k in 6:
		var a := TAU * k / 6.0
		var shard := _box(n, Vector3(0.9, 1.4, 0.05), Magic.energy(Color(0.7, 0.95, 1.0), 0.2, 1.0, 1.0), Vector3(cos(a) * 1.3, 0, sin(a) * 1.3))
		shard.rotation.y = -a + PI / 2.0
	var tw := n.create_tween()
	tw.tween_property(n, "rotation:y", TAU * dur * 0.5, dur)
	tw.tween_callback(n.queue_free)
	Sfx.play("bouclier", -4.0)

static func _arret(pc: PlayerCombat, r: float, dur: float) -> void:
	var pl := pc.player
	var at := pl.global_position
	var n := _node(at)
	var sph := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sph.mesh = sm
	sph.material_override = Magic.energy(Color(0.75, 0.85, 1.0), 0.05, 0.0, 1.0)
	Magic.rune(at, r, Color(0.75, 0.85, 1.0), dur, 0.15)
	n.add_child(sph)
	var tw := sph.create_tween()
	tw.tween_property(sph, "scale", Vector3.ONE * r, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur - 0.4)
	tw.tween_property(sph, "scale", Vector3.ONE * 0.1, 0.3)
	tw.tween_callback(n.queue_free)
	var clock := _ring(n, 3.0, Color(0.85, 0.85, 1.0, 0.9), "symbol_01")
	var tw2 := clock.create_tween()
	tw2.tween_property(clock, "rotation:y", -TAU, dur)
	FX.impact_light(at, Color(0.8, 0.85, 1.0), 6.0, r * 2.0)
	Sfx.play("givre", -4.0)
	for m in Combat.in_radius(at, r):
		m.stun(dur, true)
	# les attaques en préparation sont suspendues
	var frozen := []
	for t in FX.root.get_children():
		if t is Telegraph and t.global_position.distance_to(at) < r:
			t.set_process(false)
			frozen.append(t)
	_after(dur, func():
		for t in frozen:
			if is_instance_valid(t):
				t.set_process(true))

static func _chaines(pc: PlayerCombat, power: float, at: Vector3, r: float, dur: float, el: String) -> void:
	var victims := Combat.in_radius(at, r)
	victims.sort_custom(func(a, b): return a.global_position.distance_to(at) < b.global_position.distance_to(at))
	victims = victims.slice(0, 5)
	var gold := solid(Color(0.85, 0.65, 0.3), 0.8)
	for m in victims:
		_hurt(m, power, pc, el)
		m.stun(dur, false)
		var holder := _node(m.global_position)
		for k in 3:
			var a := TAU * k / 3.0
			var base := Vector3(cos(a) * 1.8, 0.0, sin(a) * 1.8)
			var top := Vector3(0, 1.0 * float(m.def["scale"]), 0)
			var links := 9
			for i in links:
				var lk := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.07
				tm.outer_radius = 0.16
				tm.rings = 8
				tm.ring_segments = 6
				lk.mesh = tm
				lk.material_override = gold
				lk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				holder.add_child(lk)
				var f := float(i) / (links - 1)
				lk.position = base.lerp(top, f) + Vector3(0, sin(f * PI) * 0.4, 0)
				lk.basis = Basis.looking_at((top - base).normalized(), Vector3.UP) * Basis(Vector3.FORWARD, PI / 2.0 * (i % 2)) * Basis(Vector3.RIGHT, PI / 2.0)
				lk.scale = Vector3.ONE * 0.01
				var tw := lk.create_tween()
				tw.tween_interval(i * 0.03)
				tw.tween_property(lk, "scale", Vector3.ONE, 0.12)
		Magic.rune(m.global_position, 2.0, Color(1.0, 0.75, 0.35), dur, 0.8)
		Magic.halo(m.global_position + Vector3.UP, 3.0, Color(1.0, 0.8, 0.4), 0.4)
		Magic.sparks(m.global_position + Vector3.UP, Color(1.0, 0.75, 0.3), 16, 6.0)
		_fade_free(holder, dur, 0.3)
	FX.impact_light(at, Color(1.0, 0.75, 0.35), 4.0, r * 2.0)
	Sfx.play("racines", -2.0)
	if victims.is_empty():
		pc.message.emit("Aucun ennemi dans la zone", Color(1, 0.8, 0.4))

# ================================================================== DESTRUCTION
static func _warn(at: Vector3, r: float, t: float, col: Color) -> Telegraph:
	var tele := Telegraph.spawn(FX.root, at, 0.0, "cercle", t, r)
	tele._mat.set_shader_parameter("col", col)
	return tele

static func _meteore(pc: PlayerCombat, power: float, at: Vector3, r: float, el: String) -> void:
	_warn(at, r, 0.9, Color(1.0, 0.55, 0.15))
	var rock := Node3D.new()
	FX.root.add_child(rock)
	var start := at + Vector3(-8, 34, -6)
	rock.global_position = start
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.1
	sm.height = 2.2
	sm.radial_segments = 10
	sm.rings = 6
	core.mesh = sm
	var lava := StandardMaterial3D.new()
	lava.albedo_color = Color(0.2, 0.08, 0.04)
	lava.emission_enabled = true
	lava.emission = Color(1.0, 0.4, 0.1)
	lava.emission_energy_multiplier = 2.5
	lava.emission_texture = load("res://assets/fx/fx_noise.png")
	core.material_override = lava
	rock.add_child(core)
	var shell := MeshInstance3D.new()
	var sm2 := SphereMesh.new()
	sm2.radius = 1.8
	sm2.height = 3.6
	shell.mesh = sm2
	shell.material_override = Magic.energy(Color(1.0, 0.5, 0.15), 0.25, 0.0, 1.0)
	rock.add_child(shell)
	var smoke := FX.particles("smoke_02", 24, 1.4, [Color(0.25, 0.2, 0.18, 0.8), Color(0.1, 0.1, 0.1, 0)], 3.0, false, false)
	smoke.local_coords = false
	smoke.gravity = Vector3(0, 1, 0)
	rock.add_child(smoke)
	smoke.emitting = true
	Magic.rune(at, r, Color(1.0, 0.5, 0.15), 1.1, 1.0)
	var trail := FX.particles("fire_01", 30, 0.6, [Color(1, 0.9, 0.5, 1), Color(1, 0.35, 0.1, 0.7), Color(0.2, 0.1, 0.05, 0)], 2.0, false)
	trail.gravity = Vector3.ZERO
	trail.spread = 20.0
	trail.initial_velocity_min = 1.0
	trail.initial_velocity_max = 3.0
	rock.add_child(trail)
	trail.emitting = true
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", at, 0.9).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		FX.explosion(at + Vector3.UP * 0.5, r)
		Magic.burst(at, Color(1.0, 0.5, 0.15), 2.8, true)
		Magic.debris(at, 22, 12.0)
		FX.impact_light(at, Color(1, 0.55, 0.2), 9.0, r * 4.0)
		_scorch(at, r * 1.3)
		FX.hitstop(0.1)
		if Combat.player:
			Combat.player.shake(0.7)
		Sfx.play("lourd", 2.0)
		for m in Combat.in_radius(at, r):
			_hurt(m, power, pc, el)
			var dv: Vector3 = m.global_position - at
			dv.y = 0
			m.knockback((dv.normalized() if dv.length() > 0.1 else Vector3.FORWARD) * 10.0)
		rock.queue_free())

static func _piliers(pc: PlayerCombat, power: float, at: Vector3, r: float, el: String) -> void:
	var victims := Combat.in_radius(at, r).slice(0, 6)
	var spots := []
	for m in victims:
		spots.append(m.global_position)
	if spots.is_empty():
		for k in 4:
			spots.append(at + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
	var rockm: StandardMaterial3D = Geo.mat("pierre_base").duplicate()
	rockm.uv1_triplanar = true
	rockm.uv1_world_triplanar = true
	for i in spots.size():
		var p: Vector3 = spots[i]
		p.y = ground(p)
		var pil := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.85
		cm.height = 3.2
		cm.radial_segments = 6
		cm.rings = 1
		pil.mesh = cm
		pil.material_override = rockm
		FX.root.add_child(pil)
		pil.global_position = p + Vector3.DOWN * 1.8
		pil.rotation = Vector3(randf_range(-0.15, 0.15), randf() * TAU, randf_range(-0.15, 0.15))
		var tw := pil.create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(pil, "global_position:y", p.y + 1.4, 0.16).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.4)
		tw.tween_property(pil, "global_position:y", p.y - 1.8, 0.5)
		tw.tween_callback(pil.queue_free)
		Magic.debris(p, 8, 8.0)
		Magic.sparks(p + Vector3.UP * 0.3, Color(1.0, 0.7, 0.4), 10, 6.0)
		FX.shockwave(p, 1.5)
	Magic.rune(at, r, Color(1.0, 0.65, 0.3), 1.6, 0.9)
	for i in victims.size():
		var m: Node3D = victims[i]
		_after(i * 0.08, func():
			if Combat.alive(m):
				_hurt(m, power, pc, el)
				if m.lift(2.6, 0.45):
					pass)
	pc.player.shake(0.4)
	Sfx.play("lourd", -2.0)

static func _bolt(at: Vector3) -> void:
	var top := at + Vector3(randf_range(-2.0, 2.0), 20.0, randf_range(-2.0, 2.0))
	Magic.lightning(top, at + Vector3.UP * 0.1, Color(0.6, 0.75, 1.0), 0.16, 0.16)
	Magic.burst(at, Color(0.65, 0.8, 1.0), 0.8, false)
	FX.impact_light(at, Color(0.7, 0.85, 1.0), 9.0, 18.0)
	_scorch(at, 1.4)

## Trace brûlée au sol (s'efface lentement)
static func _scorch(at: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = q
	mi.material_override = FX.pmat("scorch_02", false, false, Color(0.05, 0.04, 0.03, 0.85))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FX.root.add_child(mi)
	mi.global_position = at + Vector3.UP * 0.06
	mi.rotation = Vector3(-PI / 2.0, randf() * TAU, 0)
	var tw := mi.create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(mi, "transparency", 1.0, 2.0)
	tw.tween_callback(mi.queue_free)

static func _orage(pc: PlayerCombat, power: float, at: Vector3, r: float, dur: float, c: float, el: String) -> void:
	var strikes := 6 + int(round(3.0 * c))
	var cloud := _node(at + Vector3.UP * 14.0)
	var cl := FX.particles("smoke_02", 16, 2.0, [Color(0.15, 0.15, 0.2, 0.0), Color(0.12, 0.12, 0.16, 0.8), Color(0.1, 0.1, 0.12, 0)], 6.0, false, false)
	cl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cl.emission_sphere_radius = r
	cl.gravity = Vector3.ZERO
	cloud.add_child(cl)
	cl.emitting = true
	Magic.rune(at, r, Color(0.6, 0.75, 1.0), dur + 0.4, 0.7)
	_fade_free(cloud, dur + 0.8, 0.5)
	for k in strikes:
		_after(0.25 + dur * k / strikes, func():
			var targets := Combat.in_radius(at, r)
			var p: Vector3
			var t: Node3D = null
			if targets.size() > 0:
				t = targets[randi() % targets.size()]
				p = t.global_position
			else:
				p = at + Vector3(randf_range(-r, r) * 0.7, 0, randf_range(-r, r) * 0.7)
				p.y = ground(p)
			_bolt(p)
			Sfx.play("lourd", -10.0, 0.3)
			if t and Combat.alive(t):
				_hurt(t, power, pc, el)
				t.stun(0.45, true)
			if Combat.player:
				Combat.player.shake(0.12))

static func _main_titan(pc: PlayerCombat, power: float, at: Vector3, r: float, el: String) -> void:
	var hand := _node(at + Vector3.UP * 12.0)
	var mat := Magic.energy(Color(0.45, 0.7, 1.0), 0.3, 0.0, 1.0)
	Magic.rune(at, r * 1.15, Color(0.5, 0.75, 1.0), 1.6, 1.0)
	_box(hand, Vector3(3.4, 0.7, 3.2), mat)
	for f in 4:
		var finger := _box(hand, Vector3(0.6, 0.55, 2.6), mat, Vector3(-1.2 + f * 0.8, -0.2, 2.6))
		finger.rotation.x = -0.6
	var thumb := _box(hand, Vector3(0.7, 0.55, 2.0), mat, Vector3(2.0, -0.2, 0.6))
	thumb.rotation = Vector3(-0.4, -0.9, 0)
	hand.rotation.y = randf() * TAU
	hand.scale = Vector3.ONE * 0.1
	var victims := Combat.in_radius(at, r)
	var tw := hand.create_tween()
	tw.tween_property(hand, "scale", Vector3.ONE * 1.6, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(hand, "global_position:y", at.y + 5.0, 0.35)
	tw.tween_callback(func():
		for m in victims:
			if Combat.alive(m):
				m.lift(3.2, 1.0))
	tw.tween_method(func(_k: float):
		var dt := FX.root.get_process_delta_time()
		for m in victims:
			if Combat.alive(m):
				m.pull(at, 6.0, dt), 0.0, 1.0, 0.5)
	tw.tween_property(hand, "global_position:y", at.y + 0.6, 0.14).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		for m in victims:
			if Combat.alive(m):
				if m.state == Monster.S.SOULEVE:
					m.throw(Vector3(0, -30, 0), power, pc.player)
				else:
					_hurt(m, power, pc, el)
		Magic.burst(at, Color(0.55, 0.75, 1.0), 2.4, true)
		FX.impact_light(at, Color(0.55, 0.75, 1.0), 8.0, r * 3.0)
		FX.hitstop(0.1)
		if Combat.player:
			Combat.player.shake(0.7)
		Sfx.play("lourd", 2.0))
	tw.tween_interval(0.4)
	tw.tween_property(hand, "scale", Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(hand.queue_free)

static func _faille(pc: PlayerCombat, power: float, at: Vector3, r: float, dur: float, el: String) -> void:
	var n := _node(at)
	var rift := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 5.0)
	rift.mesh = q
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_add;
uniform vec4 col : source_color = vec4(1.0, 0.25, 0.6, 1.0);
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float w = 0.35 + 0.15 * sin(UV.y * 30.0 + TIME * 12.0);
	float a = smoothstep(w, 0.0, abs(p.x)) * smoothstep(1.0, 0.7, abs(p.y));
	ALBEDO = mix(col.rgb, vec3(1.0), smoothstep(0.1, 0.0, abs(p.x))) * a * 2.0;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	rift.material_override = m
	rift.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(rift)
	rift.position.y = 2.6
	rift.scale = Vector3(0.05, 1, 1)
	var cross := rift.duplicate()
	n.add_child(cross)
	cross.rotation.y = PI / 2.0
	var tw := n.create_tween()
	tw.set_parallel(true)
	tw.tween_property(rift, "scale", Vector3(1, 1, 1), 0.3)
	tw.tween_property(cross, "scale", Vector3(1, 1, 1), 0.3)
	_ring(n, r, Color(1.0, 0.25, 0.6, 0.5), "twirl_02")
	Magic.rune(at, r * 1.1, Color(1.0, 0.3, 0.65), dur + 0.3, -1.2)
	Magic.debris(at, 10, 6.0)
	var tw2 := n.create_tween()
	tw2.tween_method(func(_k: float):
		var dt := FX.root.get_process_delta_time()
		for e in Combat.in_radius(at, r * 1.3):
			e.pull(at, 8.0, dt), 0.0, 1.0, dur)
	tw2.tween_callback(func():
		FX.explosion(at + Vector3.UP * 1.5, r * 0.7)
		Magic.burst(at, Color(1.0, 0.3, 0.65), 2.6, true)
		FX.impact_light(at, Color(1.0, 0.3, 0.65), 10.0, r * 4.0)
		FX.hitstop(0.12)
		if Combat.player:
			Combat.player.shake(0.8)
		Sfx.play("lourd", 3.0)
		for e in Combat.in_radius(at, r):
			_hurt(e, power, pc, el)
			var dv: Vector3 = e.global_position - at
			dv.y = 0
			e.knockback((dv.normalized() if dv.length() > 0.1 else Vector3.FORWARD) * 12.0)
		n.queue_free())
	Sfx.play("ok", -2.0)

# ================================================================== SOUVERAIN
static func _legion(pc: PlayerCombat, count: int, dur: float) -> void:
	var pl := pc.player
	var names := ["Ombre", "Écho", "Spectre", "Revenant", "Fantôme", "Veilleur"]
	for i in count:
		var s := Soldier.new()
		s.spectral = true
		s.lifetime = dur
		s.nom = names[i % names.size()]
		s.slot = i
		var a := TAU * i / count
		var p := pl.global_position + Vector3(cos(a) * 2.5, 0, sin(a) * 2.5)
		p.y = ground(p)
		FX.root.add_child(s)
		s.global_position = p + Vector3.DOWN * 1.8
		s.mode = Soldier.M.ESCORTE
		var tw := s.create_tween()
		tw.tween_property(s, "global_position:y", p.y + 0.1, 0.5).set_ease(Tween.EASE_OUT)
		Magic.pillar(p, Color(0.5, 0.75, 1.0), 7.0, 0.8, 1.0)
		Magic.rune(p, 1.6, Color(0.5, 0.75, 1.0), 1.2, 1.5)
		FX.shockwave(p, 1.5)
		var col := FX.particles("light_01", 6, 0.6, [Color(0.6, 0.8, 1, 0.9), Color(0.3, 0.5, 1, 0)], 1.4)
		col.direction = Vector3.UP
		col.initial_velocity_min = 4.0
		col.initial_velocity_max = 6.0
		col.gravity = Vector3.ZERO
		FX.root.add_child(col)
		col.global_position = p
		col.emitting = true
		FX.root.get_tree().create_timer(1.0).timeout.connect(col.queue_free)
	FX.impact_light(pl.global_position, Color(0.5, 0.75, 1.0), 6.0, 12.0)
	pl.shake(0.3)
	Sfx.play("niveau", -6.0)

static func _presence(pc: PlayerCombat, r: float, dur: float) -> void:
	var pl := pc.player
	var n := Node3D.new()
	pl.add_child(n)
	var ring := _ring(n, r, Color(0.9, 0.2, 0.25, 0.55), "twirl_02")
	var tw := ring.create_tween()
	tw.tween_property(ring, "rotation:y", TAU, dur)
	var aura := FX.particles("smoke_02", 20, 1.2, [Color(0.6, 0.05, 0.1, 0.0), Color(0.5, 0.05, 0.1, 0.6), Color(0.2, 0.0, 0.05, 0)], 1.4, false, false)
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 0.8
	aura.direction = Vector3.UP
	aura.initial_velocity_min = 1.0
	aura.initial_velocity_max = 2.0
	aura.gravity = Vector3.ZERO
	aura.local_coords = false
	n.add_child(aura)
	aura.emitting = true
	FX.power_burst(pl, Color(0.9, 0.25, 0.2))
	Magic.rune(pl.global_position, r, Color(1.0, 0.2, 0.2), 1.4, 0.6)
	Magic.halo(pl.global_position + Vector3.UP, 7.0, Color(1.0, 0.25, 0.2), 0.5)
	pl.shake(0.3)
	var done := {}
	var tw2 := n.create_tween()
	tw2.tween_method(func(_k: float):
		if not is_instance_valid(pl):
			return
		for m in Combat.in_radius(pl.global_position, r):
			if done.has(m):
				if m.def.get("elite", false) or m.is_boss():
					m.cbt.apply_slow(0.7 if m.is_boss() else 0.5, 0.5)
				continue
			done[m] = true
			if m.is_boss():
				m.cbt.apply_slow(0.75, 2.0)
			elif m.def.get("elite", false):
				m.cbt.apply_slow(0.5, 2.0)
				m.stun(0.8, false)
			elif randf() < 0.5:
				m.frighten(4.0)
			else:
				m.kneel_cc(3.0), 0.0, 1.0, dur)
	tw2.tween_callback(n.queue_free)

static func _oeil(pc: PlayerCombat, dur: float) -> void:
	eye_until = Time.get_ticks_msec() / 1000.0 + dur
	FX.cast_glow(pc.player, Color(0.4, 0.9, 1.0))
	if Hud.inst:
		Hud.inst.eye.open(dur)
	Sfx.play("ok", -4.0)

static func _transposition(pc: PlayerCombat, power: float, aim: Vector3, rng: float, el: String) -> void:
	var pl := pc.player
	var t := aim_target(pc, aim, rng)
	var from := pl.global_position
	FX.shockwave(from, 1.5)
	Magic.pillar(from, Color(0.65, 0.45, 1.0), 4.0, 0.45, 0.8)
	FX.impact_light(from, Color(0.6, 0.4, 1.0), 4.0, 8.0)
	pl.cbt.invulnerable_until = Combatant.now() + 0.4
	if t and not t.is_boss():
		var tp: Vector3 = t.global_position
		# la créature d'abord, sinon le seigneur se retrouve juché sur elle et emporté avec
		t.global_position = from
		pl.global_position = tp + Vector3.UP * 0.2
		Magic.pillar(tp, Color(0.65, 0.45, 1.0), 4.0, 0.45, 0.8)
		_hurt(t, power, pc, el)
		t.stun(0.7, false)
		FX.shockwave(tp, 1.5)
	else:
		var dir := aim if aim != Vector3.ZERO else pl.forward()
		if t and t.is_boss():
			dir = (t.global_position - from).normalized()
		var dist := 9.0
		var space := pl.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.0, from + Vector3.UP * 1.0 + dir * dist, 1 | 2)
		var hit := space.intersect_ray(q)
		if hit:
			dist = maxf(0.0, from.distance_to(hit.position) - 0.8)
		var to := from + dir * dist
		to.y = ground(to) + 0.2
		pl.global_position = to
		FX.shockwave(to, 1.5)
	pl.velocity = Vector3.ZERO
	Sfx.play("esquive", -2.0)

static func _incarnation(pc: PlayerCombat, dur: float) -> void:
	var pl := pc.player
	var now := Combatant.now()
	pc.incarnation_until = now + dur
	pl.cbt.incoming_mult = 0.5
	pl.cbt.incoming_until = now + dur
	var n := Node3D.new()
	n.name = "Incarnation"
	pl.add_child(n)
	var ring := _ring(n, 1.8, Color(1.0, 0.8, 0.35, 0.8), "symbol_01")
	var tw := ring.create_tween()
	tw.tween_property(ring, "rotation:y", TAU * dur * 0.4, dur)
	var aura := FX.particles("flame_01", 30, 0.8, [Color(1, 0.85, 0.4, 0), Color(1, 0.75, 0.3, 0.8), Color(1, 0.5, 0.2, 0)], 0.6, false)
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 0.7
	aura.direction = Vector3.UP
	aura.initial_velocity_min = 1.5
	aura.initial_velocity_max = 3.0
	aura.gravity = Vector3.ZERO
	n.add_child(aura)
	aura.position.y = 1.0
	aura.emitting = true
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.8, 0.4)
	l.light_energy = 2.0
	l.omni_range = 6.0
	l.shadow_enabled = false
	n.add_child(l)
	l.position.y = 1.5
	FX.power_burst(pl, Color(1.0, 0.8, 0.35))
	Magic.pillar(pl.global_position, Color(1.0, 0.8, 0.35), 14.0, 0.9, 2.2)
	Magic.rune(pl.global_position, 4.5, Color(1.0, 0.8, 0.35), 2.0, 0.8)
	Magic.burst(pl.global_position, Color(1.0, 0.8, 0.35), 2.0, true)
	FX.hitstop(0.12)
	pl.shake(0.6)
	Sfx.play("niveau", 0.0)
	FX.root.get_tree().create_timer(dur).timeout.connect(n.queue_free)
