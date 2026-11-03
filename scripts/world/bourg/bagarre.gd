class_name Bagarre
extends Node
## Vie de la taverne : de temps en temps, deux clients éméchés se lèvent et se battent à mains nues.
## Le seigneur peut les calmer (lancer un sort près d'eux, ou leur parler), sinon la garde arrive au bout
## de 25 s, arrête le meneur et l'escorte à la prison du château (Justice.arrest).
## Ce nœud installe aussi les armes du joueur (Armes.setup) dès que le joueur existe.

static var inst: Bagarre
static var clients: Array = []      # [Villager, position, rotation, animation] clients assis de la taverne

const INSULTES := [["Tu as triché aux dés !", "Répète un peu, pour voir ?!"], ["C'est MA chope, ça !", "Elle était vide, ta chope !"],
	["Ta sœur a du goût… pour les autres.", "Tu vas le regretter !"], ["Tu dois trois pièces à tout le monde !", "Menteur !"]]
const COUPS := ["Punch_Jab", "Punch_Cross", "b/Melee_Hook", "Punch_Jab"]
const ENCAISSE := ["Hit_Head", "Hit_Chest", "b/Hit_Knockback", "Hit_Chest"]

var active := false
var fighters: Array = []      # [Villager, Villager]
var _next := 45.0
var _t := 0.0
var _beat := 0.0
var _turn := 0
var _mana := -1.0
var _armed := false
var _warned := false

func _ready() -> void:
	inst = self

static func register(v: Node3D, pos: Vector3, rot: float, anim: String) -> void:
	clients.append([v, pos, rot, anim])

func _process(delta: float) -> void:
	var p := Combat.player
	if p == null:
		return
	if not _armed:
		_armed = true
		Armes.setup(p)
	if not Town.specials.has("taverne"):
		return
	var tav: Vector2 = Town.specials["taverne"][0]
	var near := Vector2(p.global_position.x, p.global_position.z).distance_to(tav) < 45.0
	if not active:
		_next -= delta
		if _next <= 0.0:
			_next = randf_range(120.0, 240.0)
			if near and Story.done() and not Dialogue.active:
				_start()
		return
	_t += delta
	_beat -= delta
	# un sort lancé près de la rixe la calme net (la mana du seigneur baisse = un sort vient d'être lancé)
	var m: float = p.combat.mana
	if _mana >= 0.0 and m < _mana - 3.0 and p.global_position.distance_to((fighters[0] as Node3D).global_position) < 14.0:
		calm(true)
		return
	_mana = m
	if _beat <= 0.0:
		_beat = 1.05
		_exchange()
	if _t > 25.0:
		_guards()

func _start() -> void:
	var men := clients.filter(func(c): return is_instance_valid(c[0]) and c[0].is_in_group("pnj") and not bool(c[0].spec.get("female", false)) and not c[0].captive)
	if men.size() < 2:
		return
	men.shuffle()
	fighters = [men[0][0], men[1][0]]
	active = true
	_t = 0.0
	_beat = 1.6
	_mana = -1.0
	var sp: Dictionary = Town.plan.specials["taverne"]
	var base: Transform3D = sp["base"]
	var mid: Vector3 = base * Vector3(-0.4, 0.0, 0.6)
	var ax: Vector3 = base.basis.x
	var ins: Array = INSULTES[randi() % INSULTES.size()]
	for i in 2:
		var f: Villager = fighters[i]
		f.set_meta("bagarre", true)
		f.react("Sitting_Exit", 0.9)
		var to: Vector3 = mid + ax * (-0.7 if i == 0 else 0.7)
		var tw: Tween = f.create_tween()
		tw.tween_interval(0.8)
		tw.tween_property(f, "global_position", to, 0.7)
		var face := atan2((mid - to).x, (mid - to).z)
		tw.parallel().tween_property(f, "rotation:y", face, 0.4)
		f.anim_name = "Idle"
		f.get_tree().create_timer(0.6 + i * 1.2).timeout.connect(func(): if is_instance_valid(f): FX.bark(f, ins[i], 2.2, 2.4))
	var tavernier := Talk.node_of("tavernier")
	if tavernier:
		get_tree().create_timer(2.6).timeout.connect(func(): if is_instance_valid(tavernier): FX.bark(tavernier, "Pas dans ma taverne ! Gardes !", 2.2, 2.6))
	if p_near(25.0):
		Combat.player.combat.message.emit("Bagarre au Sanglier Doré ! Calmez-les (un sort ou un mot), sinon la garde s'en charge.", Color(1.0, 0.75, 0.35))

func p_near(d: float) -> bool:
	return Combat.player and fighters.size() > 0 and is_instance_valid(fighters[0]) and Combat.player.global_position.distance_to(fighters[0].global_position) < d

## Un échange de coups : l'un frappe, l'autre encaisse ; parfois un coup qui fait reculer
func _exchange() -> void:
	if fighters.size() < 2 or not is_instance_valid(fighters[0]) or not is_instance_valid(fighters[1]):
		_end()
		return
	var a: Villager = fighters[_turn % 2]
	var d: Villager = fighters[(_turn + 1) % 2]
	var k := randi() % COUPS.size()
	a.react(COUPS[k], 0.9)
	var hit_at := d.global_position + Vector3.UP * 1.5
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(d):
			d.react(ENCAISSE[k], 0.7)
			FX.hit_spark(hit_at, Color(1.0, 0.95, 0.85))
			if p_near(18.0):
				Sfx.play("coup", -10.0))
	if randf() < 0.3:
		_turn += 1   # celui qui vient d'encaisser riposte
	_turn += 1

## Le seigneur ramène le calme (sort ou parole)
func calm(by_spell: bool) -> void:
	if not active:
		return
	for f in fighters:
		if is_instance_valid(f):
			if by_spell:
				FX.frost_mark(f, 1.2)
			f.react("Fixing_Kneeling", 2.6)
			FX.bark(f, ["Pardon, seigneur !", "C'est lui qui a commencé…", "On se calme, on se calme !"][randi() % 3], 2.2, 2.4)
	GameState.get_inst().add("autorite", 1)
	GameState.get_inst().report("Vous avez calmé une rixe au Sanglier Doré.", "acte")
	get_tree().create_timer(2.8).timeout.connect(_end)
	active = false

## La garde intervient : le meneur part en prison, l'autre retourne s'asseoir
func _guards() -> void:
	active = false
	var lead: Villager = fighters[0]
	if is_instance_valid(lead) and lead.has_meta("talk"):
		lead.remove_meta("bagarre")
		clients = clients.filter(func(c): return c[0] != lead)
		Justice.arrest(lead, "rixe à la taverne")
		fighters = [fighters[1]]
	_end()

func _end() -> void:
	active = false
	for f in fighters:
		if not is_instance_valid(f) or f.captive:
			continue
		f.remove_meta("bagarre")
		for c in clients:
			if c[0] == f:
				var tw: Tween = f.create_tween()
				tw.tween_property(f, "global_position", c[1], 0.8)
				tw.parallel().tween_property(f, "rotation:y", c[2], 0.5)
				f.anim_name = c[3]
				f.react("Walk", 0.8)
	fighters = []

## Options de dialogue avec un bagarreur
static func add_options(nodes: Dictionary, choices: Array, who: String, label: String, n: Node3D) -> void:
	if inst == null or not inst.active:
		return
	nodes["calme"] = {"who": who, "nom": label, "text": "D'accord, d'accord… Je me rassois, seigneur.", "next": "END"}
	choices.push_front({"text": "Ça suffit ! Rasseyez-vous.", "next": "calme", "callback": func(): inst.calm(false)})
	nodes["arrete"] = {"who": who, "nom": label, "text": "Non ! Pas la prison !", "next": "END"}
	choices.push_front({"text": "Gardes ! Emmenez-le.", "next": "arrete", "callback": func():
		inst.fighters.erase(n)
		inst.fighters.push_front(n)
		inst._guards()})
