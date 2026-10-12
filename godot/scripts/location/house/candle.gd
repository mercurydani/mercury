class_name Candle
extends Node3D
## Свеча: мерцает; сквозняк гасит её на время (blow_out). Группа "candle".

@export var base_energy: float = 0.9

var _out := 0.0
var _t := 0.0
@onready var light: OmniLight3D = get_node_or_null("Light")
@onready var flame: Node3D = get_node_or_null("Flame")


func _ready() -> void:
	add_to_group("candle")
	_t = randf() * 10.0


func blow_out(seconds: float) -> void:
	_out = seconds
	_apply(false)


func _apply(on: bool) -> void:
	if light:
		light.visible = on
	if flame:
		flame.visible = on


func _process(delta: float) -> void:
	_t += delta
	if _out > 0.0:
		_out -= delta
		if _out <= 0.0:
			_apply(true)
		return
	if light:
		light.light_energy = base_energy * (0.85 + 0.2 * sin(_t * 11.0) * sin(_t * 5.3) + randf_range(-0.04, 0.04))
