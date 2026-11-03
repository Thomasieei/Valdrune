class_name MissionReturn
extends Node
## Retour de mission mis en scène : l'agent revient au pas de course vers son seigneur,
## s'agenouille (« Maître, nous avons terminé la mission ») puis fait son rapport dans un dialogue.

var queue: Array = []          # rapports en attente
var _cur: Dictionary = {}
var _n: Node3D = null
var _phase := ""
var _t := 0.0
var _connected := false
static var inst: MissionReturn

func _ready() -> void:
	inst = self

func _process(delta: float) -> void:
	if not _connected and Kingdom.inst:
		Kingdom.inst.mission_done.connect(func(r): queue.append(r))
		_connected = true
	var p := Combat.player
	if p == null:
		return
	if _phase == "":
		if queue.is_empty() or Dialogue.active or KingdomUI.is_open() or not Combat.in_radius(p.global_position, 18.0).is_empty() or Justice.in_cellar(p.global_position):
			return
		_start(queue.pop_front())
		return
	_t += delta
	if not is_instance_valid(_n):
		_report()
		return
	match _phase:
		"arrive":
			var to := p.global_position - _n.global_position
			to.y = 0.0
			if to.length() < (3.4 if _n is Companion else 2.4) or _t > 14.0:
				_phase = "salut"
				_t = 0.0
				_n.look_at(Vector3(p.global_position.x, _n.global_position.y, p.global_position.z), Vector3.UP)
				_n.rotate_y(PI)
				_say(_line())
				if _n is Villager:
					(_n as Villager).react("Fixing_Kneeling", 2.2)
				elif _n.has_method("_play"):
					_n._play("Fixing_Kneeling", 0.2)
			elif _n is Villager:
				var d := to.normalized()
				_n.global_position += d * 4.2 * delta
				_n.global_position.y = Powers.ground(_n.global_position + Vector3.UP * 0.6)
				_n.rotation.y = atan2(d.x, d.z)
				(_n as Villager)._play("Jog_Fwd")
		"salut":
			if _t > 2.2:
				_report()

## Appel d'un serviteur : il accourt jusqu'au seigneur, salue, puis attend ses ordres
static func summon(aid: String) -> void:
	if inst:
		inst.queue.push_front({"agent": aid, "appel": true, "statut": "appel"})

func _start(r: Dictionary) -> void:
	_cur = r
	_t = 0.0
	var aid: String = r.get("agent", "")
	var p := Combat.player
	var behind := p.global_position + p.global_transform.basis.z * 14.0
	behind.y = Powers.ground(behind + Vector3.UP * 2.0)
	if aid == "elian" and Combat.companion and is_instance_valid(Combat.companion):
		_n = Combat.companion
		if _n.mode == Companion.M.ABSENT:
			_n.set_absent(false)
		_n.teleport(behind + Vector3.UP * 0.3)
		_n.follow()
	else:
		_n = Talk.node_of(aid)
		if _n is Villager:
			(_n as Villager).captive = true
			_n.visible = true
			_n.process_mode = Node.PROCESS_MODE_INHERIT
			_n.global_position = behind
	if _n == null:
		_report()
		return
	_phase = "arrive"
	if Hud.inst:
		Hud.inst.show_message(("%s accourt" if _cur.get("appel", false) else "%s revient de mission") % _name(), Color(0.9, 0.85, 0.5))

func _name() -> String:
	var c: Dictionary = GameState.get_inst().companions.get(String(_cur.get("agent", "")), {})
	return String(c.get("nom", "Votre agent"))

func _line() -> String:
	if _cur.get("appel", false):
		return ["Vous m'avez fait appeler, %s ?", "Me voici, %s. Vos ordres ?", "À vos ordres, %s !"][randi() % 3] % GameState.get_inst().titre
	var ok: bool = _cur.get("statut", "") == "reussie"
	var t := GameState.get_inst().titre
	return ("Maître, nous avons terminé la mission ! " if ok else "Maître… la mission a échoué. ") + "Voici mon rapport, %s." % t

func _say(t: String) -> void:
	if _n and _n.has_method("say"):
		_n.say(t, 2.6)
	else:
		FX.bark(_n, t, 2.3, 2.6)

func _report() -> void:
	if Dialogue.active:
		# une autre conversation est en cours (pourparlers, marchand…) : le rapport attend son tour
		get_tree().create_timer(1.0).timeout.connect(_report)
		return
	var aid: String = _cur.get("agent", "")
	if _cur.get("appel", false):
		var w0 := Justice.world()
		var n0 := _n
		if _n is Villager:
			(_n as Villager).captive = false
		_phase = ""
		_n = null
		_cur = {}
		if w0 and w0.get("dlg") and is_instance_valid(n0):
			w0._talking = n0
			w0.dlg.start(Talk.build(n0))
		return
	var who := "elian" if aid == "elian" else "pnj"
	var ok: bool = _cur.get("statut", "") == "reussie"
	var text: String = String(_cur.get("rapport", "Mission terminée."))
	var nodes := {
		"r": {"who": who, "nom": _name(), "text": text, "choices": [
			{"text": "Beau travail. Repose-toi." if ok else "Ce n'est pas ta faute. Soigne-toi.", "next": "END", "callback": func():
				var c: Dictionary = GameState.get_inst().companions.get(aid, {})
				if not c.is_empty():
					c["loyaute"] = clampi(int(c.get("loyaute", 0)) + 1, -100, 100)
					GameState.get_inst().mark()},
			{"text": "Ouvrir le bureau des missions", "next": "END", "callback": func():
				var w := Justice.world()
				if w and w.get("kui"):
					w.kui.open("missions")},
		]},
	}
	var w := Justice.world()
	if w and w.get("dlg"):
		w.dlg.start({"start": "r", "nodes": nodes, "fermable": true})
	if is_instance_valid(_n) and _n is Villager:
		(_n as Villager).captive = false
	_phase = ""
	_n = null
	_cur = {}
