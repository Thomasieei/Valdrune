class_name Spinner
extends Node
## Fait tourner son parent (ailes du moulin).
@export var speed := 0.6
func _process(delta: float) -> void:
	(get_parent() as Node3D).rotate_object_local(Vector3.BACK, speed * delta)
