class_name AuraGuard
extends Node
## Parade de l'aura (façon manga) : un coup au corps à corps va toucher le souverain →
## le temps ralentit, l'aura arrête la lame, et le joueur peut PLAQUER l'agresseur contre un mur ou un arbre.
## Plaqué, l'ennemi est à sa merci : interroger, soumettre, relâcher pour qu'il raconte… ou achever.

static var inst: AuraGuard
static var enabled := true
const CD := 9.0
const SLOW := 0.22
var ready_at := 0.0
var pinned: Node3D = null
var _pin_pos := Vector3.ZERO
var _blocked: Node3D = null
var _freeze_acc := 0.0
var _rune: Node3D = null
var _glow: Node3D = null
var blocks := 0
var pins := 0

func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Appelé par un monstre au moment où son coup va porter sur le joueur. Vrai = coup arrêté.
static func try_block(m: Node3D) -> bool:
	return inst != null and inst._block(m)

func cooldown_left() -> float:
	return maxf(0.0, ready_at - now())

func _block(m: Node3D) -> bool:
	var p := Combat.player
	if not enabled or not Story.done() or p == null or p.cbt.dead or Dialogue.active or now() < ready_at or is_instance_valid(pinned):
		return false
	ready_at = now() + CD
	blocks += 1
	_blocked = m
	var to := (m.global_position - p.global_position)
	to.y = 0.0
	var hit := p.global_position + to.normalized() * 0.75 + Vector3.UP * 1.25
	# l'aura se matérialise : coque dorée, étincelles sur la lame, onde
	Magic.halo(p.global_position + Vector3.UP * 1.1, 2.6, Color(1.0, 0.85, 0.4), 0.6)
	Magic.sparks(hit, Color(1.0, 0.9, 0.55), 22, 7.0, 0.5)
	FX.hit_spark(hit, Color(1.0, 0.95, 0.7))
	FX.impact_light(hit, Color(1.0, 0.8, 0.4), 3.0, 6.0)
	Sfx.play("bouclier", -2.0)
	Sfx.play("bloque", -4.0)
	m.stun(1.6, true)
	FX.bark(m, ["Quoi ?!", "Ma lame… arrêtée ?!", "Impossible !", "Il ne bouge même pas…"][randi() % 4], 2.3, 1.6)
	# ralenti
	Engine.time_scale = SLOW
	var w := Justice.world()
	if w and w.get("rig"):
		w.rig.shake(0.25)
	if Hud.inst:
		if m.is_boss():
			Hud.inst.show_message("L'aura arrête le coup !", Color(1.0, 0.85, 0.45))
		else:
			Hud.inst.show_prompt("main", "PLAQUER", func(): pin(m), 1.5)
			Hud.inst.show_message("L'aura arrête le coup !", Color(1.0, 0.85, 0.45))
	get_tree().create_timer(1.5, true, false, true).timeout.connect(func():
		if not is_instance_valid(pinned):
			Engine.time_scale = 1.0
			if is_instance_valid(_blocked) and Combat.alive(_blocked) and _blocked == m:
				_repel(m)
		_blocked = null)
	return true

## Sans réponse : l'aura repousse l'agresseur
func _repel(m: Node3D) -> void:
	var p := Combat.player
	var d := m.global_position - p.global_position
	d.y = 0.0
	m.knockback(d.normalized() * 9.0 + Vector3.UP * 3.0)
	FX.shockwave(p.global_position, 2.2)

## Point d'appui le plus proche (mur, maison, arbre, rocher) derrière l'ennemi, vu du joueur
func _wall_for(m: Node3D) -> Dictionary:
	var p := Combat.player
	var space := m.get_world_3d().direct_space_state
	var from := m.global_position + Vector3.UP * 1.1
	var away := m.global_position - p.global_position
	away.y = 0.0
	away = away.normalized()
	var best := {}
	var bd := 9.0
	for k in 16:
		var a := TAU * k / 16.0
		var dir := Vector3(sin(a), 0, cos(a))
		if dir.dot(away) < -0.1:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 9.0, 2)
		q.exclude = [m.get_rid()]
		var hit := space.intersect_ray(q)
		if hit:
			var dd: float = from.distance_to(hit.position) - dir.dot(away) * 1.5
			if dd < bd:
				bd = dd
				best = hit
	return best

func pin(m: Node3D) -> void:
	if not Combat.alive(m):
		Engine.time_scale = 1.0
		return
	_blocked = null
	pinned = m
	pins += 1
	var p := Combat.player
	var hit := _wall_for(m)
	var dest: Vector3
	var against_wall := not hit.is_empty()
	if against_wall:
		dest = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * 0.45
		dest.y = maxf(Powers.ground(dest + Vector3.UP), (hit["position"] as Vector3).y - 1.1) + 0.55
	else:
		var away := m.global_position - p.global_position
		away.y = 0.0
		dest = m.global_position + away.normalized() * 3.5
		dest.y = Powers.ground(dest + Vector3.UP) + 0.45   # suspendu juste au-dessus du sol
	_pin_pos = dest
	m.stun(60.0, true)
	p.action("Spellcast_Shoot", 0.6, 1.0)
	Engine.time_scale = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(m, "global_position", dest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Engine.time_scale = 1.0
		FX.shockwave(dest - Vector3.UP * 0.5, 2.4)
		Magic.debris(dest, 14, 6.0)
		Magic.burst(dest, Color(1.0, 0.85, 0.45), 1.2, true)
		FX.impact_light(dest, Color(1.0, 0.8, 0.45), 4.0, 8.0)
		Sfx.play("lourd", 0.0)
		var w := Justice.world()
		if w and w.get("rig"):
			w.rig.shake(0.6)
		FX.bark(m, _plea(m), 2.3, 2.5)
		_rune = Magic.rune(Vector3(dest.x, Powers.ground(dest + Vector3.UP) + 0.05, dest.z), 1.4, Color(1.0, 0.8, 0.35), 120.0, 0.8)
		_glow = FX.charge_aura(m, Color(1.0, 0.8, 0.35))
		_interrogate(m, against_wall))

func _plea(m: Node3D) -> String:
	if Capture.HUMAINS.has(m.kind):
		return ["Arrgh… lâchez-moi !", "Pitié… je ne savais pas qui vous étiez !", "Qu'est-ce que vous êtes ?!"][randi() % 3]
	return "…"

func _interrogate(m: Node3D, against_wall: bool) -> void:
	var w := Justice.world()
	if w == null or not Combat.alive(m):
		_release_pin()
		return
	var human: bool = Capture.HUMAINS.has(m.kind)
	var nom: String = m.def["nom"]
	var gs := GameState.get_inst()
	var intro := ("%s est plaqué contre le mur, écrasé par votre aura." if against_wall else "%s est cloué en l'air par votre aura, incapable de bouger.") % nom
	intro += " Les autres n'osent plus approcher."
	if human:
		intro += "\n« %s »" % ["C'est… c'est le chef qui nous paie ! Je ne fais qu'obéir !", "Je vous en supplie… j'ai une famille !", "Tuez-moi si vous voulez, je ne dirai rien !"][randi() % 3]
	else:
		intro += "\nLa créature se débat, puis gémit, terrorisée."
	var choices := []
	var nodes := {}
	if human:
		nodes["info"] = {"who": "pnj", "nom": nom, "text": Capture._camp_info(m.kind), "next": "menu"}
		choices.append({"text": "Qui t'envoie ? Parle.", "next": "info", "callback": func(): gs.add("autorite", 1)})
		choices.append({"text": "Tu vas me servir. (le soumettre)", "next": "END", "callback": func():
			gs.add("crainte", 1)
			_release_pin(false)
			Capture.capture(m, true)})
	choices.append({"text": "Va-t'en. Et raconte aux tiens qui je suis.", "next": "END", "callback": func():
		gs.add("crainte", 2)
		gs.add("bienveillance", 1)
		_release_pin(false)
		if Combat.alive(m):
			m.frighten(25.0)
			for o in Combat.in_radius(m.global_position, 14.0):
				if o != m and not o.is_boss() and randf() < 0.6:
					o.frighten(8.0)
			FX.bark(m, "Il… il nous laisse partir !", 2.3, 2.0)})
	choices.append({"text": "Achever.", "next": "END", "callback": func():
		gs.add("crainte", 2)
		gs.add("bienveillance", -1)
		_release_pin(false)
		if Combat.alive(m):
			Magic.pillar(m.global_position, Color(1.0, 0.75, 0.35), 5.0, 0.5, 1.0)
			Magic.burst(m.global_position + Vector3.UP, Color(1.0, 0.8, 0.4), 1.6, true)
			m.cbt.take_damage(999999.0, Combat.player, "magie")})
	nodes["menu"] = {"who": "pnj", "nom": nom, "text": intro, "choices": choices}
	if w.get("rig"):
		w.rig.frame_talk(Combat.player, m, true)
	w.dlg.start({"start": "menu", "nodes": nodes, "fermable": true})
	if not w.dlg.finished.is_connected(_on_dialog_end):
		w.dlg.finished.connect(_on_dialog_end)

func _on_dialog_end(_a: String) -> void:
	if is_instance_valid(pinned):
		_release_pin()

func _release_pin(drop := true) -> void:
	var m := pinned
	pinned = null
	for n in [_rune, _glow]:
		if is_instance_valid(n):
			n.queue_free()
	_rune = null
	_glow = null
	Engine.time_scale = 1.0
	var w := Justice.world()
	if w and w.get("rig"):
		w.rig.cine_off()
	if drop and Combat.alive(m):
		m.global_position.y = Powers.ground(m.global_position + Vector3.UP)
		m.stun(1.0, false)
	elif Combat.alive(m):
		m.global_position.y = Powers.ground(m.global_position + Vector3.UP)

func _process(delta: float) -> void:
	if is_instance_valid(pinned):
		if not Combat.alive(pinned):
			_release_pin(false)
			return
		pinned.global_position = _pin_pos + Vector3(0, sin(now() * 7.0) * 0.03, 0)
		# les autres ennemis n'osent plus approcher tant que le souverain interroge
		_freeze_acc += delta
		if _freeze_acc > 0.4:
			_freeze_acc = 0.0
			for o in Combat.in_radius(pinned.global_position, 22.0):
				if o != pinned and not o.is_boss():
					o.stun(0.8, true)
