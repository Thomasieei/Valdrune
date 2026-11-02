class_name DomeBarrier
extends Node3D
## Barrière du Dôme souverain : à chaque pas physique, les ennemis qui touchent la sphère en sont repoussés
## (indépendant du nombre d'images par seconde).

var radius := 4.5
var until := 0.0

func _physics_process(_delta: float) -> void:
	var c := global_position
	for e in Combat.in_radius(c, radius + 0.3):
		var dv: Vector3 = e.global_position - c
		dv.y = 0
		if dv.length() < 0.1:
			dv = Vector3.FORWARD
		var r: float = radius + 0.3 + float(e.def["rayon"])
		if dv.length() < r:
			e.global_position = Vector3(c.x, e.global_position.y, c.z) + dv.normalized() * r
			e.knockback(dv.normalized() * 2.0)
