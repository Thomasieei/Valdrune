extends Area3D
## Zone d'une maison visitable : à l'entrée du joueur, on masque étages et toit, on allume l'intérieur
## et la caméra se rapproche ; à la sortie tout revient.

var upper: Node3D
var lights: Array = []
var _in := false

func _ready() -> void:
	body_entered.connect(func(b): if b is Player: _toggle(true, b))
	body_exited.connect(func(b): if b is Player: _toggle(false, b))

func _toggle(v: bool, p: Node) -> void:
	_in = v
	if is_instance_valid(upper):
		upper.visible = not v
	for l in lights:
		if is_instance_valid(l):
			l.visible = v
	var rig = p.get("rig")
	if rig:
		rig.inside = v
