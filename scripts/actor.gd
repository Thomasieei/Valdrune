class_name Actor extends CharacterBody3D
## Acteur générique (joueur, alliés, invocations, monstres) : modèle KayKit + arbre d'animation en couches,
## statuts (étourdi, sommeil, racines, soulevé, hypnose, figé), IA simple, forme féline procédurale.

signal died(a)
const LIB: AnimationLibrary = preload("res://assets/anims.res")
const UPPER := ["spine","chest","head","upperarm.l","lowerarm.l","wrist.l","hand.l","handslot.l","upperarm.r","lowerarm.r","wrist.r","hand.r","handslot.r"]
const G := 22.0
const WALK := 2.4
const RUN := 5.6
const KIT := {
	"Knight": {"1h":["1H_Sword","Round_Shield"], "2h":["2H_Sword"], "dual":["1H_Sword","1H_Sword_Offhand"], "unarmed":[]},
	"Barbarian": {"2h":["2H_Axe"], "1h":["1H_Axe","Barbarian_Round_Shield"], "dual":["1H_Axe","1H_Axe_Offhand"], "unarmed":[]},
	"Mage": {"magic":["2H_Staff"], "1h":["1H_Wand","Spellbook_open"], "unarmed":[]},
	"Rogue_Hooded": {"dual":["Knife","Knife_Offhand"], "xbow":["2H_Crossbow"], "1h":["Knife"], "unarmed":[]},
	"Skeleton_Rogue": {"unarmed":[]}, "Skeleton_Mage": {"magic":[]},
}
const LOCO := {
	"unarmed":["Melee_Unarmed_Idle","Walking_A","Running_A"], "1h":["Idle_A","Walking_B","Running_A"],
	"2h":["Melee_2H_Idle","Walking_A","Running_B"], "dual":["Idle_A","Walking_C","Running_B"],
	"magic":["Idle_B","Walking_A","Running_A"], "xbow":["Idle_A","Walking_A","Running_HoldingRifle"],
	"sneak":["Crouching","Sneaking","Sneaking"],
}
# [anim, dmg, portée, angle°(360=zone), recul, corps_entier, projectile]
const ACT := {
	"unarmed": [["Melee_Unarmed_Attack_Punch_A",6,1.5,70,1,false,""],["Melee_Unarmed_Attack_Kick",9,1.6,70,3,true,""]],
	"1h": [["Melee_1H_Attack_Slice_Diagonal",12,1.8,80,1,false,""],["Melee_1H_Attack_Slice_Horizontal",12,1.9,100,1,false,""],["Melee_1H_Attack_Chop",16,1.8,60,3,false,""],["Melee_1H_Attack_Stab",20,2.1,40,5,true,""]],
	"2h": [["Melee_2H_Attack_Slice",20,2.2,100,2,false,""],["Melee_2H_Attack_Chop",26,2.2,60,4,true,""],["Melee_2H_Attack_Stab",30,2.4,40,7,true,""]],
	"dual": [["Melee_Dualwield_Attack_Slice",9,1.7,80,1,false,""],["Melee_Dualwield_Attack_Chop",11,1.7,70,1,false,""],["Melee_Dualwield_Attack_Stab",15,1.9,50,3,false,""]],
	"magic": [["Ranged_Magic_Shoot",14,0,0,2,false,"bolt"]],
	"xbow": [["Ranged_2H_Shoot",18,0,0,3,false,"bolt"]],
	"cat": [["claw",13,1.9,90,1,false,""],["claw",13,1.9,90,1,false,""],["claw2",20,2.1,70,4,false,""]],
}
const _BP := ["parameters/L0/blend_position","parameters/L1/blend_position","parameters/L2/blend_position","parameters/L3/blend_position","parameters/L4/blend_position","parameters/L5/blend_position","parameters/L6/blend_position"]

var w                          # monde (main.gd)
var char_name := ""
var styles: Array = []
var style := "unarmed"
var team := 0
var hp := 100.0
var hp_max := 100.0
var dmg_mul := 1.0
var speed_mul := 1.0
var model: Node3D
var skel: Skeleton3D
var tree: AnimationTree
var bt: AnimationNodeBlendTree
var cat: Node3D                # forme féline (procédurale)
var _hold := 0
var move_in := Vector2.ZERO
var aim_target: Actor = null
var busy := 0.0
var root_lock := 0.0
var combo := 0
var combo_t := 0.0
var state := "loco"            # loco, air, launched, down, dead, hold, block, sneak, sleep, lift
var state_t := 0.0
var air_t := 0.0
var fall_v := 0.0
var dodge_v := Vector3.ZERO
var iframes := 0.0
var face := 0.0
var _queued := false
# statuts
var stun_t := 0.0
var root_t := 0.0
var sleep_t := 0.0
var lift_t := 0.0
var hyp_t := 0.0
var shield_t := 0.0
var taunt_t := 0.0
var taunt_by: Actor = null
var frozen := false
var stored := 0.0
var on_hit_heal: Actor = null  # chaque coup donné soigne cet acteur
var heal_amt := 0.0
var life_t := -1.0             # invocation à durée limitée
var brain := ""                # "" joueur ; "melee", "ranged", "heal", "tank"
var ai_t := 0.0
var target: Actor = null
var owner_a: Actor = null
var tag: Label3D
var turn_rate := 14.0          # vitesse de rotation (les gros monstres tournent lentement : on peut les contourner)
var atk_t := 0.0               # >0 juste après le début d'une attaque (lu par l'IA ennemie pour esquiver)
var size_k := 1.0
var parry_t := 0.0             # fenêtre de parade parfaite (juste après l'appui sur Parade)
var dodge_t := 9.0             # temps depuis le début de la dernière esquive
var counter_ready := 0.0       # contre-attaque disponible (après esquive / parade parfaite)
var counter_target: Actor = null
var posture := 100.0
var duel_vs: Actor = null      # duel d'arène : n'attaque et ne touche que cet adversaire
var fighter = null             # données de combattant d'arène (rang, nom, pouvoir)           # endurance de garde : à 0, garde brisée
var col_shape: CollisionShape3D

func set_size(k: float) -> void:
	size_k = k; model.scale = Vector3.ONE * k
	var cap: CapsuleShape3D = col_shape.shape; cap.radius = 0.38 * k; cap.height = 1.7 * k; col_shape.position.y = 0.85 * k
	tag.position.y = 2.5 * k

func setup(cname: String, world, t := 0) -> void:
	w = world; team = t
	var col := CollisionShape3D.new(); var cap := CapsuleShape3D.new()
	cap.radius = 0.38; cap.height = 1.7; col.shape = cap; col.position.y = 0.85
	add_child(col); col_shape = col
	floor_snap_length = 0.3
	collision_layer = 2; collision_mask = 3
	platform_floor_layers = 1; platform_wall_layers = 0
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	tag = Label3D.new(); tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED; tag.no_depth_test = true
	tag.font_size = 40; tag.outline_size = 10; tag.pixel_size = 0.006; tag.position.y = 2.5; add_child(tag)
	set_char(cname)

func set_char(cname: String) -> void:
	if model: model.queue_free()
	char_name = cname
	model = (load("res://assets/chars/%s.glb" % cname) as PackedScene).instantiate()
	add_child(model)
	for n in model.find_children("*", "AnimationPlayer", true, false): n.free()
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	styles = KIT[cname].keys()
	_build_tree()
	set_style(styles[0])
	if cat: set_cat(false)

func tint(c: Color, glow := 0.0) -> void:
	for m in skel.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var src: Material = mi.get_active_material(0)
		if src is StandardMaterial3D:
			var nm: StandardMaterial3D = src.duplicate(); nm.albedo_color = c
			if glow > 0: nm.emission_enabled = true; nm.emission = c; nm.emission_energy_multiplier = glow
			mi.material_override = nm

func set_style(s: String) -> void:
	style = s
	var show: Array = KIT[char_name].get(s, [])
	var all := {}
	for k in KIT[char_name].values(): for x in k: all[x] = true
	for extra in ["Badge_Shield","Rectangle_Shield","Spike_Shield","Mug","Spellbook","1H_Crossbow","Throwable","1H_Wand","Knife","1H_Sword_Offhand","2H_Sword","Round_Shield"]: all[extra] = true
	for n in skel.get_children():
		if n is BoneAttachment3D and all.has(String(n.name)): n.visible = show.has(String(n.name))
	if LOCO.has(s): tree.set("parameters/loco/transition_request", s)
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
	return LIB.get_animation(n).length if LIB.has_animation(n) else 0.45

func shot(n: String, full := true) -> float:
	if cat and cat.visible: cat.act(n); return _len(n)
	if not LIB.has_animation(n): return 0.0
	var node := "fb" if full else "up"
	(bt.get_node(node + "a") as AnimationNodeAnimation).animation = n
	tree.set("parameters/%s/request" % node, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	tree.set("parameters/%s/request" % node, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return _len(n)

func hold(n: String) -> void:
	if cat and cat.visible: cat.pose(n); return
	if n == "":
		tree.set("parameters/mode/transition_request", "loco"); return
	_hold = 1 - _hold
	(bt.get_node("h%d" % _hold) as AnimationNodeAnimation).animation = n
	tree.set("parameters/mode/transition_request", "h%d" % _hold)

func stop_shots() -> void:
	tree.set("parameters/fb/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	tree.set("parameters/up/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)

func play_any(n: String) -> void:
	if cat and cat.visible: set_cat(false)
	if state == "dead": revive()
	stop_shots()
	if LIB.get_animation(n).loop_mode != Animation.LOOP_NONE or n.ends_with("_Pose"):
		hold(n); state = "hold"
	else:
		hold(""); state = "loco"; busy = shot(n, true); root_lock = busy

# ---------- forme féline ----------
func set_cat(on: bool) -> void:
	if on and not cat:
		cat = preload("res://scripts/cat.gd").new(); add_child(cat)
	if not cat: return
	cat.visible = on; model.visible = not on
	tree.active = not on
	if on: style = "cat"; combo = 0
	else: set_style(styles[0])

func is_cat() -> bool: return cat != null and cat.visible

# ---------- commandes ----------
func incap() -> bool:
	return stun_t > 0 or sleep_t > 0 or lift_t > 0 or frozen or state in ["dead","launched","down"]

func can_act() -> bool:
	return not incap() and state in ["loco", "hold", "sneak", "block"] and busy <= 0.0

func jump() -> void:
	if not is_on_floor() or not can_act() or root_t > 0: return
	if state == "hold": hold("")
	velocity.y = 8.0; state = "air"; air_t = 0.0
	shot("Jump_Start", true); hold("Jump_Idle")
	w.sfx("jump", global_position)

func dodge() -> void:
	if not is_on_floor() or incap() or root_t > 0 or busy > 0.15: return
	if state in ["hold","block","sneak"]: hold(""); state = "loco"
	var dir := Vector3(move_in.x, 0, move_in.y)
	var n := "Dodge_Forward"
	if dir.length() < 0.2:
		dir = -fwd(); n = "Dodge_Backward"
	elif aim_target:
		var l := global_transform.basis.inverse() * dir
		n = "Dodge_Left" if l.x < -0.5 else ("Dodge_Right" if l.x > 0.5 else ("Dodge_Backward" if l.z < 0 else "Dodge_Forward"))
	else:
		face = atan2(dir.x, dir.z); rotation.y = face
	dodge_v = dir.normalized() * 10.0
	busy = shot(n, true) * 0.8; root_lock = busy; iframes = 0.35; dodge_t = 0.0
	w.sfx("dash", global_position)

func attack() -> void:
	if counter_ready > 0 and is_instance_valid(counter_target) and counter_target.state != "dead" and not incap():
		w.counter(self, counter_target); return
	if state == "block": return
	if not can_act():
		if busy < 0.18 and busy > 0 and brain == "": _queued = true
		return
	if state in ["hold","sneak"]: hold(""); state = "loco"
	var list: Array = ACT[style]
	if combo_t <= 0.0: combo = 0
	var a: Array = list[combo % list.size()]
	combo += 1
	if brain == "" and w.on_basic(self, combo): return
	do_act(a)

func block(on: bool) -> void:
	if on: parry_t = 0.3
	if on and can_act():
		hold("Melee_Blocking"); state = "block"
	elif not on and state == "block":
		hold(""); state = "loco"

func do_act(a: Array) -> float:
	face_target()
	var moving := move_in.length() > 0.2
	var full: bool = a[5] or not moving
	var L := shot(a[0], full)
	var spd: float = 1.0 / max(speed_mul, 0.5)
	busy = L * 0.72 * spd; combo_t = L + 0.35
	if full: root_lock = busy
	var hit_at := L * 0.42 * spd
	atk_t = hit_at
	var kind: String = a[6]
	if kind != "": delay(hit_at, func(): w.projectile(self, kind, a))
	elif a[1] > 0: delay(hit_at, func(): melee(a[1], a[2], a[3], a[4]))
	return L

func delay(t: float, f: Callable) -> void:
	get_tree().create_timer(t, false).timeout.connect(func(): if is_instance_valid(self) and state != "dead": f.call())

func foe(o: Actor) -> bool:
	if o == self or o.state == "dead": return false
	if duel_vs: return o == duel_vs
	if o.duel_vs: return false
	if hyp_t > 0 or o.hyp_t > 0: return (o.team == 1 and team == 1) or o.team != team
	return o.team != team

func melee(dmg: float, rng: float, ang: float, force: float, stun_s := 0.0) -> int:
	var n := 0
	for o in w.actors:
		if not foe(o): continue
		var d: Vector3 = o.global_position - global_position; d.y = 0
		if d.length() > rng + 0.4: continue
		if ang < 360 and rad_to_deg(fwd().angle_to(d.normalized())) > ang * 0.5: continue
		o.hurt(dmg * dmg_mul, global_position, force, self)
		if stun_s > 0: o.stun(stun_s)
		n += 1
	w.sfx("hit" if n > 0 else "swing", global_position)
	return n

# ---------- dégâts & statuts ----------
func hurt(dmg: float, from: Vector3, force: float, by: Actor = null) -> void:
	if state == "dead": return
	if brain == "" and team == 0 and by and by.team != 0 and w.defend(self, by, dmg, from, force): return
	if iframes > 0: return
	if by and is_instance_valid(by) and by.on_hit_heal and is_instance_valid(by.on_hit_heal): by.on_hit_heal.heal(by.heal_amt)
	if frozen:
		stored += dmg; w.number(global_position, dmg, Color(0.6, 0.85, 1), 0.7); return
	if shield_t > 0:
		w.burst(global_position + Vector3.UP, Color(1, 0.95, 0.6), 8); return
	if sleep_t > 0:
		sleep_t = 0.0; root_t = max(root_t, 2.0); hold(""); state = "loco"; w.roots(self)
	var d := global_position - from; d.y = 0; d = d.normalized()
	var front := fwd().dot(-d) > 0.3
	if state == "block" and front:
		dmg *= 0.15; shot("Melee_Block_Hit", true); dodge_v = d * 2.5
		w.number(global_position, dmg, Color(0.7, 0.7, 0.7)); hp -= dmg; return
	hp -= dmg
	w.number(global_position, dmg, Color(1, 0.85, 0.2) if force < 6 else Color(1, 0.35, 0.2), 1.0 if dmg < 60 else 1.6)
	w.burst(global_position + Vector3.UP * 1.0, Color(1, 0.3, 0.2), 8)
	if hp <= 0: die(); return
	if lift_t > 0 or (root_t > 0 and force < 6): return
	busy = 0.0; _queued = false
	if force >= 6.0 and root_t <= 0:
		stop_shots(); state = "launched"; state_t = 0.0
		velocity = d * force * 0.9 + Vector3.UP * force * 0.55
		face = atan2(-d.x, -d.z); rotation.y = face
		hold("Death_B")
	elif stun_t <= 0 and brain != "" or force > 2:
		if root_t <= 0: dodge_v = d * (1.5 + force)
		busy = shot("Hit_A" if front else "Hit_B", true) * 0.6; root_lock = busy
		if state in ["hold","sneak"]: hold(""); state = "loco"

func heal(v: float) -> void:
	if state == "dead": return
	var h: float = min(v, hp_max - hp); hp += h
	if h >= 1: w.number(global_position, h, Color(0.35, 1, 0.45), 0.9)

func stun(t: float) -> void:
	if state == "dead": return
	stun_t = max(stun_t, t); stop_shots(); busy = 0
	if state in ["loco","hold","block","sneak"]: hold("Hit_B"); state = "hold"

func put_sleep(t: float) -> void:
	if state == "dead": return
	sleep_t = t; stop_shots(); busy = 0; state = "sleep"; hold("Lie_Down")
	delay(1.0, func(): if sleep_t > 0: hold("Lie_Idle"))

func lift(t: float) -> void:
	if state == "dead": return
	lift_t = t; stop_shots(); state = "lift"; hold("Jump_Idle"); velocity = Vector3(0, 5, 0)

func freeze(on: bool) -> void:
	frozen = on
	if tree and not is_cat(): tree.active = not on
	if cat: cat.set_process(not on)
	if not on and stored > 0:
		var s := stored; stored = 0
		w.number(global_position, s, Color(0.4, 0.9, 1), 2.0); w.burst(global_position + Vector3.UP, Color(0.5, 0.9, 1), 20)
		hp -= s
		if hp <= 0: die()
		else: hurt(0.01, global_position - fwd(), 7)

func die() -> void:
	hp = 0; state = "dead"; stop_shots(); velocity.x = 0; velocity.z = 0
	stun_t = 0; sleep_t = 0; lift_t = 0; root_t = 0; hyp_t = 0
	if is_cat(): cat.pose("dead")
	else: hold("Skeletons_Death" if char_name.begins_with("Skeleton") else ("Death_A" if randf() < 0.5 else "Death_B"))
	died.emit(self)

func revive() -> void:
	hp = hp_max; state = "loco"; hold("")
	busy = shot("Lie_StandUp", true); root_lock = busy

# ---------- IA ----------
func fwd() -> Vector3: return Vector3(sin(rotation.y), 0, cos(rotation.y))

func nearest_foe(r: float) -> Actor:
	if duel_vs and is_instance_valid(duel_vs) and duel_vs.state != "dead": return duel_vs
	if taunt_t > 0 and is_instance_valid(taunt_by) and taunt_by.state != "dead": return taunt_by
	var best: Actor = null; var bd := r
	for o in w.actors:
		if foe(o):
			var dd := global_position.distance_to(o.global_position)
			if dd < bd: bd = dd; best = o
	return best

func face_target() -> void:
	if turn_rate < 10: return
	var t := aim_target if aim_target else nearest_foe(3.5)
	if t:
		var d := t.global_position - global_position
		face = atan2(d.x, d.z); rotation.y = face
	elif move_in.length() > 0.2:
		face = atan2(move_in.x, move_in.y); rotation.y = face

func _think() -> void:
	move_in = Vector2.ZERO
	if incap(): return
	if brain == "heal":
		if owner_a and is_instance_valid(owner_a):
			var d := owner_a.global_position - global_position; d.y = 0
			if d.length() > 3.0: move_in = Vector2(d.x, d.z).normalized() * 0.7
		return
	target = nearest_foe(30.0)
	if not target:
		if owner_a and is_instance_valid(owner_a) and global_position.distance_to(owner_a.global_position) > 3.5:
			var d := owner_a.global_position - global_position; move_in = Vector2(d.x, d.z).normalized()
		return
	var d := target.global_position - global_position; d.y = 0
	var rng := 7.0 if brain == "ranged" else 1.5
	if d.length() > rng: move_in = Vector2(d.x, d.z).normalized() * (0.6 if team == 1 else 1.0)
	elif can_act() and randf() < (0.55 if team == 1 else 0.9):
		face = atan2(d.x, d.z); rotation.y = face
		attack()

# ---------- physique ----------
func _physics_process(dt: float) -> void:
	if frozen: return
	busy = max(busy - dt, 0); root_lock = max(root_lock - dt, 0); iframes = max(iframes - dt, 0); atk_t = max(atk_t - dt, 0)
	combo_t = max(combo_t - dt, 0); state_t += dt
	parry_t = max(parry_t - dt, 0); dodge_t += dt; counter_ready = max(counter_ready - dt, 0)
	if state != "block": posture = min(100.0, posture + 18.0 * dt)
	shield_t = max(shield_t - dt, 0); taunt_t = max(taunt_t - dt, 0); hyp_t = max(hyp_t - dt, 0)
	if root_t > 0: root_t -= dt
	if stun_t > 0:
		stun_t -= dt
		if stun_t <= 0 and state == "hold": hold(""); state = "loco"
	if sleep_t > 0:
		sleep_t -= dt
		if sleep_t <= 0: state = "loco"; hold(""); busy = shot("Lie_StandUp", true); root_lock = busy; root_t = max(root_t, 2.0); w.roots(self)
	if lift_t > 0:
		lift_t -= dt
		velocity = Vector3(0, (2.2 - global_position.y) * 4.0, 0)
		rotation.y += dt * 2.0
		if lift_t <= 0: state = "air"; hold("Jump_Idle")
	if life_t > 0:
		life_t -= dt
		if life_t <= 0: die(); get_tree().create_timer(2.0).timeout.connect(func(): w.remove_actor(self)); return
	if brain != "":
		ai_t -= dt
		if ai_t <= 0: ai_t = 0.15; _think()
	if _queued and busy <= 0: _queued = false; attack()
	var on_floor := is_on_floor()
	if not on_floor and lift_t <= 0: velocity.y -= G * dt; air_t += dt
	var want := Vector3(move_in.x, 0, move_in.y)
	var m := want.length()
	var spd := 0.0
	match state:
		"dead", "sleep", "lift":
			want = Vector3.ZERO
		"launched":
			want = Vector3.ZERO
			if on_floor and state_t > 0.25:
				velocity.x *= 0.8; velocity.z *= 0.8
				state = "down"; state_t = 0.0; w.sfx("land", global_position)
		"down":
			want = Vector3.ZERO; velocity.x = 0; velocity.z = 0
			if state_t > 0.9: state = "loco"; hold(""); busy = shot("Lie_StandUp", true); root_lock = busy
		"air":
			spd = RUN * 0.8
			if on_floor and air_t > 0.1:
				state = "loco"; hold("")
				if fall_v < -15: hurt(10, global_position + fwd(), 2)
				else: shot("Jump_Land", false)
				w.sfx("land", global_position)
		"hold":
			if m > 0.2 and stun_t <= 0: hold(""); state = "loco"
		"block":
			spd = WALK * 0.5
		_:
			spd = WALK if m < 0.65 else RUN
			if state == "sneak": spd = WALK * 0.8
			if state == "loco" and not on_floor and air_t > 0.35:
				state = "air"; hold("Jump_Idle")
	if on_floor: air_t = 0.0
	fall_v = velocity.y
	spd *= speed_mul
	if root_lock > 0 or root_t > 0 or stun_t > 0: spd = 0.0
	elif busy > 0: spd *= 0.55
	var hv: Vector3 = want.normalized() * spd * clamp(m * 1.4, 0, 1) if m > 0.1 else Vector3.ZERO
	if state not in ["launched", "dead", "down", "lift"]:
		velocity.x = lerp(velocity.x, hv.x + dodge_v.x, 0.35)
		velocity.z = lerp(velocity.z, hv.z + dodge_v.z, 0.35)
	dodge_v = dodge_v.move_toward(Vector3.ZERO, 30 * dt)
	move_and_slide()
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
	if lift_t <= 0: rotation.y = lerp_angle(rotation.y, face, 1.0 - exp(-turn_rate * dt))
	if is_cat(): cat.tick(hs.length(), dt)
	else:
		for p in _BP: tree.set(p, bp)
	var s := ""
	if sleep_t > 0: s = "Zzz"
	elif stun_t > 0: s = "ÉTOURDI"
	elif hyp_t > 0: s = "HYPNOSE"
	elif root_t > 0: s = "ENRACINÉ"
	elif lift_t > 0: s = "SOULEVÉ"
	if tag.text != s:
		tag.text = s
		tag.modulate = {"Zzz": Color(0.7, 0.8, 1), "ÉTOURDI": Color(1, 0.9, 0.3), "HYPNOSE": Color(0.9, 0.4, 1), "ENRACINÉ": Color(0.6, 0.9, 0.3), "SOULEVÉ": Color(1, 0.4, 0.4)}.get(s, Color.WHITE)
