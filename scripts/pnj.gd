class_name Pnj
extends Node3D


const COULEURS := {"ombres": Color(0.62, 0.3, 1.0), "arme": Color(1.0, 0.45, 0.25), "chance": Color(0.35, 1.0, 0.5)}

var autel := "ombres"
var _corps: Node3D
var _ap: AnimationPlayer
var _marque: Label3D
var _t := 0.0

func _ready() -> void:
	var r: Dictionary = Partie.ROLLS[autel]
	var c: Color = COULEURS[autel]
	var n: Node3D = {"ombres": Apparence.esil, "arme": Apparence.kang, "chance": Apparence.mira}[autel].call()
	_corps = Modele.preparer(n, "pnj_" + autel, 1.78 if autel != "arme" else 1.86)
	add_child(_corps)
	_ap = Modele.lecteur(_corps)
	Modele.jouer(_ap, "Idle_FoldArms" if autel == "arme" else "Idle")
	if _ap:
		_ap.seek(randf() * 2.0, true)
	var plaque := Label3D.new()
	plaque.text = "%s\n%s" % [r["pnj"], r["autel"]]
	plaque.font = Ui.police
	plaque.font_size = 30
	plaque.outline_size = 9
	plaque.pixel_size = 0.0018
	plaque.fixed_size = true
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plaque.modulate = c.lightened(0.35)
	plaque.position.y = 2.35
	plaque.visibility_range_end = 45.0
	add_child(plaque)
	_marque = Label3D.new()
	_marque.text = "!"
	_marque.font = Ui.police
	_marque.font_size = 64
	_marque.outline_size = 12
	_marque.pixel_size = 0.0022
	_marque.fixed_size = true
	_marque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marque.modulate = Color(1.0, 0.85, 0.2)
	_marque.position.y = 2.95
	add_child(_marque)
	_etal(c)

	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 0.7
	l.omni_range = 4.0
	l.position = Vector3(0, 0.5, -0.6)
	add_child(l)
	var rune := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(4.2, 4.2)
	rune.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/fx/magic_02.png")
	m.albedo_color = Color(c.r, c.g, c.b, 0.6)
	rune.material_override = m
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rune.position.y = 0.04
	rune.name = "Rune"
	add_child(rune)

	var corps := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45
	cyl.height = 1.8
	cs.shape = cyl
	cs.position.y = 0.9
	corps.add_child(cs)
	add_child(corps)

func _prop(nom: String, pos: Vector3, angle := 0.0, ech := 1.0) -> Node3D:
	var n: Node3D = load("res://assets/props/%s.gltf" % nom).instantiate()
	n.position = pos
	n.rotation.y = angle
	n.scale = Vector3.ONE * ech
	add_child(n)
	return n


func _etal(c: Color) -> void:
	match autel:
		"ombres":
			_prop("CandleStick_Stand", Vector3(-1.3, 0, -0.6), 0.0, 0.85)
			_prop("CandleStick_Stand", Vector3(1.3, 0, -0.6), 0.0, 0.85)
			_prop("Bookcase_2", Vector3(0, 0, -1.6), PI, 0.9)
			_prop("Book_Stack_1", Vector3(-1.0, 0, 0.6), 0.4)
			_prop("Scroll_1", Vector3(1.0, 0, 0.7), 1.1)
			var cristal := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(0.26, 0.5, 0.26)
			cristal.mesh = pm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.4, 0.15, 0.9)
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 0.9
			m.metallic = 0.3
			m.roughness = 0.15
			cristal.material_override = m
			cristal.position = Vector3(0, 1.55, -1.0)
			cristal.name = "Cristal"
			add_child(cristal)
		"arme":
			_prop("Anvil", Vector3(1.2, 0, 0.5), 0.3, 1.2)
			_prop("WeaponStand", Vector3(-1.4, 0, -0.7), 0.2, 1.1)
			_prop("Sword_Bronze", Vector3(1.25, 0.82, 0.5), 1.4, 0.9)
			_prop("Barrel", Vector3(-1.5, 0, 0.6), 0.0, 0.9)
		"chance":
			_prop("Stall_Empty", Vector3(0, 0, -1.1), PI, 1.0)
			_prop("Cauldron", Vector3(-1.3, 0, 0.5), 0.0, 1.0)
			_prop("Coin_Pile", Vector3(1.2, 0, 0.6), 0.0, 1.2)
			_prop("Coin_Pile_2", Vector3(1.6, 0, -0.1), 1.0, 1.0)
			_prop("Potion_1", Vector3(-0.9, 0, 1.0), 0.0, 1.2)

func _process(dt: float) -> void:
	_t += dt
	var m: String = Partie.ROLLS[autel]["monnaie"]
	_marque.visible = int(Partie.monnaies[m]) > 0
	_marque.position.y = 2.95 + sin(_t * 3.0) * 0.08
	var rune: Node3D = get_node_or_null("Rune")
	if rune:
		rune.rotation.y += dt * 0.25
	var cr: Node3D = get_node_or_null("Cristal")
	if cr:
		cr.rotation.y += dt * 1.2
		cr.position.y = 1.55 + sin(_t * 1.6) * 0.08
