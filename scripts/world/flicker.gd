extends OmniLight3D
## Lueur vacillante d'un feu
var _base := -1.0
func _process(_d: float) -> void:
	if _base < 0.0:
		_base = light_energy
	var t := Time.get_ticks_msec() / 1000.0
	light_energy = _base * (0.82 + 0.12 * sin(t * 13.0) + 0.08 * sin(t * 31.0 + 1.7))
