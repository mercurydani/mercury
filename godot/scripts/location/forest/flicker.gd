class_name Flicker
extends OmniLight3D
## Живой огонь: свет костра мерцает.

@export var base_energy: float = 2.2
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	light_energy = base_energy * (0.85 + 0.25 * sin(_t * 13.0) * sin(_t * 7.3 + 1.0) + randf_range(-0.05, 0.05))
