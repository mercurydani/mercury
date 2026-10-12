class_name Sway
extends Node3D
## Покачивание на ветру: флажки, бельё, провода. Усиливается во время порывов (группа "wind").

@export var amplitude_deg: float = 6.0
@export var speed: float = 2.0
@export var phase: float = 0.0
@export var axis: Vector3 = Vector3(0, 0, 1)

var _base: Basis
var _t: float = 0.0


func _ready() -> void:
	_base = basis
	_t = phase


func _process(delta: float) -> void:
	var k := 0.15
	for w in get_tree().get_nodes_in_group("wind"):
		k = maxf(k, (w as WindGust).intensity())
	_t += delta * speed * (0.6 + k)
	var a := deg_to_rad(amplitude_deg) * (0.4 + k * 1.6) * sin(_t)
	basis = _base * Basis(axis.normalized(), a)
