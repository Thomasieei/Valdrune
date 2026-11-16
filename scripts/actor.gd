class_name Actor extends CharacterBody3D
## Acteur générique (joueur, PNJ, monstre) : modèle KayKit + arbre d'animation en couches.
## Couches : locomotion (par style) -> états tenus (h0/h1) -> action corps entier (fb) -> action haut du corps (up).

signal died(a)
const LIB: AnimationLibrary = preload("res://assets/anims.res")
const UPPER := ["spine","chest","head","upperarm.l","lowerarm.l","wrist.l","hand.l","handslot.l","upperarm.r","lowerarm.r","wrist.r","hand.r","handslot.r"]
const G := 22.0
const WALK := 2.4
const RUN := 5.6

# Armes par perso et par style (noms des BoneAttachment KayKit)
const KIT := {
	"Knight": {"1h":["1H_Sword","Round_Shield"], "2h":["2H_Sword"], "dual":["1H_Sword","1H_Sword_Offhand"], "unarmed":[]},
	"Barbarian": {"2h":["2H_Axe"], "1h":["1H_Axe","Barbarian_Round_Shield"], "dual":["1H_Axe","1H_Axe_Offhand"], "unarmed":[]},
	"Mage": {"magic":["2H_Staff"], "1h":["1H_Wand","Spellbook_open"], "unarmed":[]},
	"Rogue_Hooded": {"dual":["Knife","Knife_Offhand"], "xbow":["2H_Crossbow"], "1h":["Knife"], "unarmed":[]},
}
# Locomotion par style : idle, marche, course
const LOCO := {
	"unarmed":["Melee_Unarmed_Idle","Walking_A","Running_A"], "1h":["Idle_A","Walking_B","Running_A"],
	"2h":["Melee_2H_Idle","Walking_A","Running_B"], "dual":["Idle_A","Walking_C","Running_B"],
	"magic":["Idle_B","Walking_A","Running_A"], "xbow":["Idle_A","Walking_A","Running_HoldingRifle"],
	"sneak":["Crouching","Sneaking","Sneaking"],
}
# Actions : [anim, dmg, portée, angle°(360=zone), recul, corps_entier, projectile]
const ACT := {
	"unarmed": {"atk":[["Melee_Unarmed_Attack_Punch_A",6,1.4,70,1,false,""],["Melee_Unarmed_Attack_Kick",9,1.6,70,4,true,""]],
		"s1":["Throw",8,0,0,2,false,"rock"], "s2":["Skeletons_Taunt",0,0,0,0,true,""], "s3":["Melee_Unarmed_Attack_Kick",14,1.7,80,9,true,""]},
	"1h": {"atk":[["Melee_1H_Attack_Slice_Diagonal",12,1.7,75,1,false,""],["Melee_1H_Attack_Slice_Horizontal",12,1.8,90,1,false,""],["Melee_1H_Attack_Chop",16,1.7,60,3,false,""],["Melee_1H_Attack_Stab",20,2.0,40,5,true,""]],
		"s1":["Melee_1H_Attack_Jump_Chop",34,2.3,80,10,true,""], "s2":["Melee_Block_Attack",14,1.6,80,8,true,""], "s3":["Skeletons_Taunt",0,0,0,0,true,""]},
	"2h": {"atk":[["Melee_2H_Attack_Slice",20,2.2,100,2,false,""],["Melee_2H_Attack_Chop",26,2.2,60,4,true,""],["Melee_2H_Attack_Stab",30,2.4,40,7,true,""]],
		"s1":["Melee_2H_Attack_Spin",38,2.6,360,9,true,""], "s2":["Melee_2H_Attack_Spinning",12,2.4,360,3,true,""], "s3":["Skeletons_Taunt_Longer",0,0,0,0,true,""]},
	"dual": {"atk":[["Melee_Dualwield_Attack_Slice",9,1.6,80,1,false,""],["Melee_Dualwield_Attack_Chop",11,1.6,70,1,false,""],["Melee_Dualwield_Attack_Stab",15,1.8,50,3,false,""]],
		"s1":["Dodge_Forward",22,2.2,60,4,true,"blink"], "s2":["Throw",14,0,0,2,false,"knife"], "s3":["Crouching",0,0,0,0,true,"sneak"]},
	"magic": {"atk":[["Ranged_Magic_Shoot",14,0,0,2,false,"bolt"]],
		"s1":["Ranged_Magic_Spellcasting_Long",8,6.0,25,0,true,"beam"], "s2":["Ranged_Magic_Raise",30,3.2,360,11,true,"nova"], "s3":["Ranged_Magic_Summon",0,0,0,0,true,"summon"]},
	"xbow": {"atk":[["Ranged_2H_Shoot",18,0,0,3,false,"bolt"]],
		"s1":["Ranged_2H_Reload",0,0,0,0,false,""], "s2":["Throw",26,0,0,10,false,"bomb"], "s3":["Dodge_Backward",0,0,0,0,true,"leap"]},
}

var char_name := ""
var styles: Array = []
var style := "unarmed"
var team := 0
var hp := 100.0
var hp_max := 100.0
var model: Node3D
var skel: Skeleton3D
var tree: AnimationTree
var bt: AnimationNodeBlendTree
var _hold := 0
var move_in := Vector2.ZERO   # entrée (x,z) monde, longueur 0..1
var aim_target: Actor = null
var busy := 0.0               # verrou d'action (s)
var root_lock := 0.0          # immobilise pendant une action corps entier
var combo := 0
var combo_t := 0.0
var state := "loco"           # loco, air, launched, down, dead, hold, block, sneak
var state_t := 0.0
var air_t := 0.0
var fall_v := 0.0
var dodge_v := Vector3.ZERO
var iframes := 0.0
var face := 0.0
var fx: Node                  # référence au monde (effets)

func setup(cname: String, world_fx: Node, t := 0) -> void:
	fx = world_fx; team = t
	var col := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = 0.38; cap.height = 1.7; col.shape = cap; col.position.y = 0.85
	add_child(col)
	floor_snap_length = 0.3
	collision_layer = 2; collision_mask = 3
	platform_floor_layers = 1; platform_wall_layers = 0
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	set_char(cname)

func set_char(cname: String) -> void:
	if model: model.queue_free()
	char_name = cname
	model = (load("res://assets/chars/%s.glb" % cname) as PackedScene).instantiate()
	add_child(model)
	for n in model.find_children("*", "AnimationPlayer", true, false): n.free()
	skel = model.get_node("Rig/Skeleton3D")
	for m in skel.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	styles = KIT[cname].keys()
	_build_tree()
	set_style(styles[0])

func set_style(s: String) -> void:
	style = s
	var show: Array = KIT[char_name].get(s, [])
	var all := {}
	for k in KIT[char_name].values(): for w in k: all[w] = true
	for extra in ["Badge_Shield","Rectangle_Shield","Spike_Shield","Mug","Spellbook","1H_Crossbow","Throwable","1H_Wand","Knife"]: all[extra] = true
	for n in skel.get_children():
		if n is BoneAttachment3D and all.has(String(n.name)): n.visible = show.has(String(n.name))
	tree.set("parameters/loco/transition_request", s)
	combo = 0

# ---------- arbre d'animation ----------
func _anim(n: String) -> AnimationNodeAnimation:
	var a := AnimationNodeAnimation.new(); a.animation = n; return a

func _build_tree() -> void:
	tree = AnimationTree.new()
	tree.add_animation_library("", LIB)
	model.add_child(tree)
	tree.root_node = tree.get_path_to(skel.get_parent())
	bt = AnimationNodeBlendTree.new()
	var loco := AnimationNodeTransition.new(); loco.xfade_time = 0.25
	var keys := LOCO.keys()
	loco.input_count = keys.size()
	for i in keys.size():
		loco.set_input_name(i, keys[i])
		var bs := AnimationNodeBlendSpace2D.new()
		bs.blend_mode = AnimationNodeBlendSpace2D.BLEND_MODE_INTERPOLATED
		var l: Array = LOCO[keys[i]]
		bs.add_blend_point(_anim(l[0]), Vector2(0, 0))
		bs.add_blend_point(_anim(l[1]), Vector2(0, 0.45))
		bs.add_blend_point(_anim(l[2]), Vector2(0, 1))
		if keys[i] != "sneak":
			bs.add_blend_point(_anim("Walking_Backwards"), Vector2(0, -0.6))
			bs.add_blend_point(_anim("Running_Strafe_Left"), Vector2(-1, 0))
			bs.add_blend_point(_anim("Running_Strafe_Right"), Vector2(1, 0))
		else:
			bs.add_blend_point(_anim("Crawling"), Vector2(0, -0.6))
		bt.add_node("L%d" % i, bs)
	bt.add_node("loco", loco)
	for i in keys.size(): bt.connect_node("loco", i, "L%d" % i)
	var mode := AnimationNodeTransition.new(); mode.xfade_time = 0.18; mode.input_count = 3
	mode.set_input_name(0, "loco"); mode.set_input_name(1, "h0"); mode.set_input_name(2, "h1")
	bt.add_node("mode", mode); bt.add_node("h0", _anim("Idle_A")); bt.add_node("h1", _anim("Idle_A"))
	bt.connect_node("mode", 0, "loco"); bt.connect_node("mode", 1, "h0"); bt.connect_node("mode", 2, "h1")
	var fb := AnimationNodeOneShot.new(); fb.fadein_time = 0.08; fb.fadeout_time = 0.22
	bt.add_node("fb", fb); bt.add_node("fba", _anim("Hit_A"))
	bt.connect_node("fb", 0, "mode"); bt.connect_node("fb", 1, "fba")
	var up := AnimationNodeOneShot.new(); up.fadein_time = 0.06; up.fadeout_time = 0.18; up.filter_enabled = true
	for b in UPPER: up.set_filter_path(NodePath("Skeleton3D:" + b), true)
	bt.add_node("up", up); bt.add_node("upa", _anim("Hit_A"))
	bt.connect_node("up", 0, "fb"); bt.connect_node("up", 1, "upa")
	bt.connect_node("output", 0, "up")
	tree.tree_root = bt
	tree.active = true

func _len(n: String) -> float:
	return LIB.get_animation(n).length if LIB.has_animation(n) else 0.5

## Joue une action ponctuelle. full=true : corps entier ; sinon haut du corps (on peut courir en même temps).
func shot(n: String, full := true) -> float:
	if not LIB.has_animation(n): return 0.0
	var node := "fb" if full else "up"
	(bt.get_node(node + "a") as AnimationNodeAnimation).animation = n
	tree.set("parameters/%s/request" % node, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	tree.set("parameters/%s/request" % node, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return _len(n)

## Pose / boucle tenue (chute, sol, mort, parade, emote en boucle). "" = retour locomotion.
func hold(n: String) -> void:
	if n == "":
		tree.set("parameters/mode/transition_request", "loco"); return
	_hold = 1 - _hold
	(bt.get_node("h%d" % _hold) as AnimationNodeAnimation).animation = n
	tree.set("parameters/mode/transition_request", "h%d" % _hold)

func stop_shots() -> void:
	tree.set("parameters/fb/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	tree.set("parameters/up/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)

## Navigateur : joue n'importe quelle animation (boucle => tenue jusqu'au prochain mouvement)
func play_any(n: String) -> void:
	if state == "dead": revive()
	stop_shots()
	if LIB.get_animation(n).loop_mode != Animation.LOOP_NONE or n.ends_with("_Pose"):
		hold(n); state = "hold"
	else:
		hold(""); state = "loco"; busy = shot(n, true); root_lock = busy

# ---------- commandes ----------
func can_act() -> bool:
	return state in ["loco", "hold", "sneak", "block"] and busy <= 0.0

func jump() -> void:
	if not is_on_floor() or not can_act(): return
	if state == "hold": hold("")
	velocity.y = 8.0; state = "air"; air_t = 0.0
	shot("Jump_Start", true); hold("Jump_Idle")
	fx.sfx("jump", global_position)

func dodge() -> void:
	if not is_on_floor() or state in ["dead","launched","down"] or busy > 0.15: return
	if state in ["hold","block","sneak"]: hold(""); state = "loco"
	var dir := Vector3(move_in.x, 0, move_in.y)
	var n := "Dodge_Forward"
	if dir.length() < 0.2:
		dir = -_fwd(); n = "Dodge_Backward"
	elif aim_target:
		var l := global_transform.basis.inverse() * dir
		n = "Dodge_Left" if l.x < -0.5 else ("Dodge_Right" if l.x > 0.5 else ("Dodge_Backward" if l.z < 0 else "Dodge_Forward"))
	else:
		face = atan2(dir.x, dir.z); rotation.y = face
	dodge_v = dir.normalized() * 10.0
	busy = shot(n, true) * 0.8; root_lock = busy; iframes = 0.35
	fx.sfx("dash", global_position)

func attack() -> void:
	if state == "block": return
	if not can_act():
		if busy < 0.18 and busy > 0: _queued = true
		return
	if state in ["hold","sneak"]: hold(""); state = "loco"
	var list: Array = ACT[style]["atk"]
	if combo_t <= 0.0: combo = 0
	var a: Array = list[combo % list.size()]
	combo += 1
	_do(a)

var _queued := false
const _NL := [0,1,2,3,4,5,6]
const _BP := ["parameters/L0/blend_position","parameters/L1/blend_position","parameters/L2/blend_position","parameters/L3/blend_position","parameters/L4/blend_position","parameters/L5/blend_position","parameters/L6/blend_position"]

func skill(i: int) -> void:
	if not can_act(): return
	var a: Array = ACT[style]["s%d" % i]
	if a[6] == "sneak":
		if state == "sneak": state = "loco"; tree.set("parameters/loco/transition_request", style)
		else: state = "sneak"; tree.set("parameters/loco/transition_request", "sneak")
		return
	if state == "hold": hold(""); state = "loco"
	_do(a)

func block(on: bool) -> void:
	if on and can_act() and style in ["1h","2h","unarmed","dual"]:
		hold("Melee_Blocking"); state = "block"
	elif not on and state == "block":
		hold(""); state = "loco"

func _do(a: Array) -> void:
	_face_target()
	var moving := move_in.length() > 0.2
	var full: bool = a[5] or not moving
	var L := shot(a[0], full)
	busy = L * 0.72; combo_t = L + 0.35
	if full: root_lock = busy
	var hit_at := L * (0.42 if a[0] != "Melee_2H_Attack_Spinning" else 0.2)
	var kind: String = a[6]
	match kind:
		"blink":
			var t := _nearest_enemy(9.0)
			if t:
				global_position = t.global_position - t._fwd() * 1.1
				face = t.rotation.y; rotation.y = face
				fx.burst(global_position + Vector3.UP, Color(0.6, 0.3, 1.0), 18)
			_delay(hit_at * 0.6, func(): _melee(a))
		"leap":
			velocity.y = 6.0; dodge_v = -_fwd() * 9.0; state = "air"; hold("Jump_Idle")
		"summon":
			_delay(L * 0.6, func(): fx.burst(global_position + _fwd() * 1.5, Color(0.4, 0.8, 1), 40))
		"beam":
			for k in 6: _delay(0.25 + k * 0.22, func(): _melee(a); fx.beam(self, a[2]))
		"nova":
			_delay(hit_at, func(): _melee(a); fx.ring(global_position, a[2], Color(1, 0.55, 0.15)))
		"bolt", "knife", "rock", "bomb":
			_delay(hit_at, func(): fx.projectile(self, kind, a))
		_:
			if a[1] > 0: _delay(hit_at, func(): _melee(a))
			elif a[0].begins_with("Skeletons_Taunt"): fx.ring(global_position, 3.0, Color(1, 0.2, 0.2))
	if a[0] == "Melee_2H_Attack_Spinning":
		for k in 3: _delay(hit_at + 0.3 * (k + 1), func(): _melee(a))

func _delay(t: float, f: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(func(): if is_instance_valid(self) and state != "dead": f.call())

func _melee(a: Array) -> void:
	var hit_any := false
	for o in fx.actors:
		if o == self or o.team == team or o.state == "dead": continue
		var d: Vector3 = o.global_position - global_position; d.y = 0
		if d.length() > a[2] + 0.4: continue
		if a[3] < 360 and rad_to_deg(_fwd().angle_to(d.normalized())) > a[3] * 0.5: continue
		o.hurt(a[1], global_position, a[4]); hit_any = true
	if hit_any: fx.sfx("hit", global_position)
	else: fx.sfx("swing", global_position)

# ---------- dégâts ----------
func hurt(dmg: float, from: Vector3, force: float) -> void:
	if state == "dead" or iframes > 0: return
	var d := global_position - from; d.y = 0; d = d.normalized()
	var front := _fwd().dot(-d) > 0.3
	if state == "block" and front:
		dmg *= 0.15; shot("Melee_Block_Hit", true); dodge_v = d * 2.5
		fx.burst(global_position + Vector3.UP * 1.1 + _fwd() * 0.5, Color(1, 0.9, 0.5), 12)
		fx.number(global_position, dmg, Color(0.7, 0.7, 0.7)); hp -= dmg; return
	hp -= dmg
	fx.number(global_position, dmg, Color(1, 0.85, 0.2) if force < 6 else Color(1, 0.35, 0.2))
	fx.burst(global_position + Vector3.UP * 1.0, Color(1, 0.3, 0.2), 10)
	if hp <= 0: die(); return
	busy = 0.0; _queued = false
	if force >= 6.0:
		stop_shots(); state = "launched"; state_t = 0.0
		velocity = d * force * 0.9 + Vector3.UP * force * 0.55
		face = atan2(-d.x, -d.z); rotation.y = face
		hold("Death_B")
		fx.shake(0.25)
	else:
		dodge_v = d * (1.5 + force)
		busy = shot("Hit_A" if front else "Hit_B", true) * 0.6; root_lock = busy
		if state in ["hold","sneak"]: hold(""); state = "loco"

func die() -> void:
	hp = 0; state = "dead"; stop_shots(); velocity.x = 0; velocity.z = 0
	hold("Death_A" if randf() < 0.5 else "Death_B")
	died.emit(self)

func revive() -> void:
	hp = hp_max; state = "loco"; hold("")
	busy = shot("Lie_StandUp", true); root_lock = busy

# ---------- physique ----------
func _fwd() -> Vector3: return Vector3(sin(rotation.y), 0, cos(rotation.y))

func _nearest_enemy(r: float) -> Actor:
	var best: Actor = null; var bd := r
	for o in fx.actors:
		if o.team != team and o.state != "dead":
			var dd := global_position.distance_to(o.global_position)
			if dd < bd: bd = dd; best = o
	return best

func _face_target() -> void:
	var t := aim_target if aim_target else _nearest_enemy(3.5)
	if t:
		var d := t.global_position - global_position
		face = atan2(d.x, d.z); rotation.y = face
	elif move_in.length() > 0.2:
		face = atan2(move_in.x, move_in.y); rotation.y = face

func _physics_process(dt: float) -> void:
	busy = max(busy - dt, 0); root_lock = max(root_lock - dt, 0); iframes = max(iframes - dt, 0)
	combo_t = max(combo_t - dt, 0); state_t += dt
	if _queued and busy <= 0: _queued = false; attack()
	var on_floor := is_on_floor()
	if not on_floor: velocity.y -= G * dt; air_t += dt
	var want := Vector3(move_in.x, 0, move_in.y)
	var m := want.length()
	var spd := 0.0
	match state:
		"dead":
			want = Vector3.ZERO
		"launched":
			want = Vector3.ZERO
			if on_floor and state_t > 0.25:
				velocity.x *= 0.8; velocity.z *= 0.8
				if state_t > 0.25 and state != "down": state = "down"; state_t = 0.0; fx.sfx("land", global_position); fx.shake(0.15)
		"down":
			want = Vector3.ZERO; velocity.x = 0; velocity.z = 0
			if state_t > 0.9: state = "loco"; hold(""); busy = shot("Lie_StandUp", true); root_lock = busy
		"air":
			spd = RUN * 0.8
			if on_floor and air_t > 0.1:
				state = "loco"; hold("")
				if fall_v < -15: hurt(10, global_position + _fwd(), 2); fx.shake(0.2)
				else: shot("Jump_Land", false)
				fx.sfx("land", global_position)
		"hold":
			if m > 0.2: hold(""); state = "loco"
		"block":
			spd = WALK * 0.5
		_:
			spd = WALK if m < 0.65 else RUN
			if state == "sneak": spd = WALK * 0.8
			if state == "loco" and not on_floor and air_t > 0.35:
				state = "air"; hold("Jump_Idle")
	if on_floor: air_t = 0.0
	fall_v = velocity.y
	if root_lock > 0: spd = 0.0
	elif busy > 0: spd *= 0.55
	var hv: Vector3 = want.normalized() * spd * clamp(m * 1.4, 0, 1) if m > 0.1 else Vector3.ZERO
	if state not in ["launched", "dead", "down"]:
		velocity.x = lerp(velocity.x, hv.x + dodge_v.x, 0.35)
		velocity.z = lerp(velocity.z, hv.z + dodge_v.z, 0.35)
	dodge_v = dodge_v.move_toward(Vector3.ZERO, 30 * dt)
	move_and_slide()
	# orientation & blend
	var hs := Vector2(velocity.x, velocity.z)
	var bp := Vector2.ZERO
	if aim_target and state in ["loco","block","sneak"] and aim_target.state != "dead":
		var d := aim_target.global_position - global_position
		face = atan2(d.x, d.z)
		var l := global_transform.basis.inverse() * Vector3(hs.x, 0, hs.y) / RUN
		bp = Vector2(l.x, l.z)
	else:
		if hs.length() > 0.5 and root_lock <= 0 and state in ["loco","air","sneak","block"]: face = atan2(hs.x, hs.y)
		bp = Vector2(0, clamp(hs.length() / RUN, 0, 1))
	rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-14 * dt))
	for i in _NL: tree.set(_BP[i], bp)
