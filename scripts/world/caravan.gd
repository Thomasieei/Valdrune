class_name Caravan
extends Node3D
## Caravane marchande : un marchand mène sa charrette sur la grande route, du portail jusqu'au marché du bourg,
## vend sa marchandise (or pour le trésor), puis repart. Une fois le contact établi avec les nains,
## elle franchit réellement le portail et revient chargée de minerai.

var route: Array = []          # Vector2, du portail vers le bourg
var dwarven := false
var _pts: Array = []
var _i := 0
var _state := "aller"          # aller, vente, retour, portail
var _wait := 0.0
var _cart: Node3D
var _merchant: Victim
var _ap: AnimationPlayer
const SPEED := 1.9

func _ready() -> void:
	_cart = Node3D.new()
	add_child(_cart)
	# le modèle a ses brancards vers +Z : la charrette suit son marchand, brancards devant
	Kit.village(_cart, "Prop_Cart_1_Barrels", Vector3.ZERO, 0.0, 1.2)
	_merchant = Victim.new()
	_merchant.killed.connect(_looted)
	add_child(_merchant)
	var m := CharBuilder.build({"outfit": "paysan_h", "beard": true, "hair": "Hair_SimpleParted", "tint": Color(0.95, 0.8, 0.55)})
	_merchant.add_child(m)
	_ap = m.get_node("AnimationPlayer")
	_ap.play("Walk")
	_merchant.add_to_group("pnj")
	_merchant.set_meta("talk", {"id": "caravanier", "nom": "Odon le caravanier", "role": "marchand"})
	for q in route:
		_pts.append(q)
	var s: Vector2 = _pts[0]
	global_position = Vector3(s.x, Terrain.height_at(s.x, s.y), s.y)
	if dwarven:
		FX.shockwave(global_position, 3.0)

var under_attack := false
var looted := false

## Pillée : le marchand est tombé, la charrette brûle, l'or du voyage est perdu
func _looted() -> void:
	if looted:
		return
	looted = true
	_state = "pille"
	_ap.play("Death01")
	var loss := int(randf_range(25, 55))
	Kingdom.add("tresor", -loss)
	GameState.get_inst().report("La caravane d'Odon a été pillée par des bandits : %d or perdus pour le trésor." % loss, "alerte")
	if Hud.inst:
		Hud.inst.discover("Caravane pillée !", "Le marchand est tombé — %d or perdus" % loss)
	var fire := FX.particles("flame_01", 20, 0.9, [Color(1, 0.9, 0.5, 0.0), Color(1.0, 0.5, 0.15), Color(0.3, 0.1, 0.05, 0)], 1.1, false)
	fire.direction = Vector3.UP
	fire.initial_velocity_min = 1.0
	fire.initial_velocity_max = 2.0
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.8
	_cart.add_child(fire)
	fire.position = Vector3(0, 1.0, 0.5)
	fire.emitting = true
	var tw := create_tween()
	tw.tween_interval(40.0)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	if looted:
		return
	if under_attack:
		if _ap.current_animation != "Idle":
			_ap.play("Idle")
		return
	match _state:
		"vente", "portail":
			_wait -= delta
			if _wait <= 0.0:
				if _state == "vente":
					_pts.reverse()
					_i = 0
					_state = "retour"
					_ap.play("Walk")
				else:
					queue_free()
			return
	if _ap.current_animation != "Walk" and _state in ["aller", "retour"]:
		_ap.play("Walk")
	if _i >= _pts.size():
		_arrive()
		return
	var t: Vector2 = _pts[_i]
	var here := Vector2(global_position.x, global_position.z)
	var d := t - here
	if d.length() < 0.8:
		_i += 1
		return
	here += d.normalized() * SPEED * delta
	global_position = Vector3(here.x, Terrain.height_at(here.x, here.y), here.y)
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), clampf(delta * 3.0, 0, 1))
	# le marchand tire sa charrette entre les brancards
	_cart.position = Vector3(0, 0, -1.6)
	_merchant.position = Vector3(0, 0, 1.6)

func _arrive() -> void:
	var gs := GameState.get_inst()
	if _state == "aller":
		_state = "vente"
		_wait = 35.0
		_ap.play("Idle_Talking")
		var gain := int(randf_range(12, 26) * (1.0 + clampf(float(gs.factions.get("marchands", 0)) / 100.0, -0.5, 0.6)))
		if dwarven:
			gain += 15
			Kingdom.add("minerai", 12)
		Kingdom.add("tresor", gain)
		gs.report("Une caravane%s a vendu ses marchandises au bourg : +%d or au trésor%s." % [" naine" if dwarven else "", gain, ", +12 minerai" if dwarven else ""], "commerce")
	elif _state == "retour":
		_state = "portail"
		_wait = 1.0
		if dwarven:
			FX.shockwave(global_position, 3.0)
			FX.impact_light(global_position, Color(0.6, 0.75, 1.0), 4.0, 14.0)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.8)
