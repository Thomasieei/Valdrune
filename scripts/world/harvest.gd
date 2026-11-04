class_name Harvest
extends Node
## Récolte par le souverain : aux champs, au camp de bûcherons et à la mine, un panneau montre le minuteur
## (« Récolte dans 32 s » / « Prête ! »). Prête : bouton « Récolter » (à la main) ou « Par la pensée »
## (télékinésie : double récolte, coûte de la mana). Les ouvriers voisins réagissent, la ressource entre au royaume.

const SPOTS := {
	"ferme": {"res": "nourriture", "n": 12, "nom": "Récolte", "verbe": "Récolter", "cd": 45.0, "anim": "b/Farm_Harvest", "col": Color(1.0, 0.85, 0.35)},
	"scierie": {"res": "bois", "n": 10, "nom": "Coupe du bois", "verbe": "Couper du bois", "cd": 40.0, "anim": "b/TreeChopping", "col": Color(0.6, 0.9, 0.45)},
	"mine": {"res": "pierre", "n": 8, "nom": "Front de taille", "verbe": "Piocher", "cd": 50.0, "anim": "b/Melee_Hook", "col": Color(0.75, 0.8, 0.9)},
}
var world: Node3D
var _ready_at := {}
var _labels := {}
var _pos := {}
var _acc := 0.0

static func build(w: Node3D) -> void:
	var h := Harvest.new()
	h.name = "Recoltes"
	h.world = w
	w.add_child(h)

func _ready() -> void:
	var at := {"ferme": Layout.FARM + Vector2(-14, 10), "scierie": Layout.LUMBER + Vector2(-10, 6), "mine": Layout.MINE + Vector2(-4, 18)}
	for k in SPOTS:
		var q: Vector2 = at[k]
		var p := Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
		_pos[k] = p
		_ready_at[k] = 0.0
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 56
		l.outline_size = 12
		l.pixel_size = 0.01
		l.modulate = SPOTS[k]["col"]
		l.visibility_range_end = 45.0
		add_child(l)
		l.global_position = p + Vector3(0, 3.2, 0)
		_labels[k] = l
		var r := Magic.rune(p + Vector3.UP * 0.05, 2.2, SPOTS[k]["col"], 1e9, 0.2)
		r.reparent(self)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	var p := Combat.player
	if p == null or Hud.inst == null:
		return
	for k in SPOTS:
		var left := float(_ready_at[k]) - _now()
		var l: Label3D = _labels[k]
		l.text = "%s\n%s" % [SPOTS[k]["nom"], "Prête !" if left <= 0.0 else "dans %d s" % int(ceil(left))]
		if left <= 0.0 and p.global_position.distance_to(_pos[k]) < 6.0 and not Dialogue.active:
			var kk: String = k
			if p.combat.mana >= 20.0:
				Hud.inst.show_prompt("main", "Par la pensée (x2)", func(): collect(kk, true), 0.4)
			else:
				Hud.inst.show_prompt("main", SPOTS[k]["verbe"], func(): collect(kk, false), 0.4)

func collect(k: String, mind: bool) -> void:
	if float(_ready_at[k]) > _now():
		return
	var s: Dictionary = SPOTS[k]
	var p := Combat.player
	_ready_at[k] = _now() + float(s["cd"])
	Hud.inst.hide_prompt()
	var n: int = s["n"] * (2 if mind else 1)
	var at: Vector3 = _pos[k]
	if mind:
		p.combat.mana -= 20.0
		p.action("Spell_Simple_Shoot", 1.0, 1.0)
		# les produits s'élèvent, tournoient autour du souverain puis filent au dépôt
		var prop: String = {"ferme": "Bag", "scierie": "FirewoodStack", "mine": "Barrel_Closed"}[k]
		for i in 4:
			var o := Kit.dungeon(world, prop, at + Vector3(randf_range(-2, 2), 0.2, randf_range(-2, 2)), randf() * TAU, 0.9)
			Magic.trail(o, Color(0.75, 0.6, 1.0), 0.3, "spark_04", 10)
			var tw := o.create_tween()
			tw.tween_property(o, "global_position", p.global_position + Vector3(cos(i * 1.6) * 1.6, 2.4 + i * 0.3, sin(i * 1.6) * 1.6), 0.7).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.5)
			tw.tween_property(o, "global_position", at + Vector3(0, 6, 0), 0.6)
			tw.tween_property(o, "scale", Vector3.ONE * 0.05, 0.2)
			tw.tween_callback(o.queue_free)
		Juice.onde(at, Color(0.75, 0.6, 1.0), 4.0, 0.5)
	else:
		p.action(s["anim"] if p.anim.has_animation(s["anim"]) else "Sword_Attack", 1.4, 1.0)
		Juice.dust(at, 16, 4.0)
		Magic.sparks(at + Vector3.UP, s["col"], 16, 5.0)
	Sfx.play("or", -4.0)
	if Kingdom.inst:
		Kingdom.add(s["res"], n)
	Progression.get_inst().add_xp(6)
	Hud.inst.show_message("+%d %s%s" % [n, s["res"], " (par la pensée)" if mind else ""], s["col"])
	# les ouvriers autour sont ravis que le souverain mette la main à la pâte
	var lines := ["Merci, mon seigneur !", "Le souverain travaille avec nous !", "Ha ! Quelle force !", "On n'a jamais vu ça !"]
	if mind:
		lines = ["Par tous les saints… il fait voler le travail !", "Incroyable !", "Merci, seigneur !"]
	var c := 0
	for v in get_tree().get_nodes_in_group("pnj"):
		if v is Villager and v.visible and v.global_position.distance_to(at) < 30.0 and c < 3:
			c += 1
			FX.bark(v, lines[randi() % lines.size()], 2.3, 2.4)
			v.react("b/Yes" if v._ap.has_animation("b/Yes") else "Idle", 1.5)
