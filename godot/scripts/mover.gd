class_name MovingPlatform
extends AnimatableBody3D
## Платформа, которая ездит туда-сюда между стартом и start + offset.
## platform_velocity читает игрок, чтобы его «везло» вместе с платформой.

@export var offset: Vector3 = Vector3(6, 0, 0)
@export var period: float = 4.0

var platform_velocity: Vector3 = Vector3.ZERO
var _start: Vector3
var _t: float = 0.0


func _ready() -> void:
	_start = position


func _physics_process(delta: float) -> void:
	_t += delta
	var k := (1.0 - cos(_t / period * TAU)) * 0.5
	var new_pos := _start + offset * k
	platform_velocity = (new_pos - position) / delta
	position = new_pos
