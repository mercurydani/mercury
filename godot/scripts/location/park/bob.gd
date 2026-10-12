class_name Bob
extends Node3D
## Покачивание на воде: резиновые утки в фонтане.

@export var amp: float = 0.05
@export var rate: float = 1.6
var _y := 0.0
var _t := 0.0


func _ready() -> void:
	_y = position.y
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta * rate
	position.y = _y + sin(_t) * amp
	rotation.z = sin(_t * 0.8) * 0.06
