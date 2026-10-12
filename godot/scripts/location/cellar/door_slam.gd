class_name DoorSlam
extends Node3D
## Дверь на верхней площадке: стоит открытой, пока игрок не спустится; потом захлопывается (старт потопа).
## Дочерний узел Leaf поворачивается вокруг оси Y.

signal slammed

@export var open_angle: float = 100.0
@export var trigger_depth: float = 4.0     # игрок ниже порога высоты узла на столько метров — закрываем
@export var fallback_time: float = 25.0

var closed := false
var _t := 0.0
@onready var leaf: Node3D = get_node_or_null("Leaf")


func _ready() -> void:
	add_to_group("door_slam")
	if leaf:
		leaf.rotation_degrees.y = open_angle


func _physics_process(delta: float) -> void:
	if closed:
		return
	_t += delta
	var go := _t > fallback_time
	for n in get_tree().get_nodes_in_group("players"):
		if (n as Node3D).global_position.y < global_position.y - trigger_depth * 0.5:
			go = true
	if go:
		_close()


func _close() -> void:
	closed = true
	if leaf:
		var tw := create_tween()
		tw.tween_property(leaf, "rotation_degrees:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_DOOR_SLAM"), 3.5)
	slammed.emit()
