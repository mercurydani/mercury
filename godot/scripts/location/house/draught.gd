class_name Draught
extends Area3D
## Сквозняк: раз в period секунд задувает свечи в радиусе radius, если рядом игрок.

@export var period: float = 12.0
@export var radius: float = 9.0
@export var out_time: float = 8.0

var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_t = randf() * period * 0.5


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < period:
		return
	var near := false
	for n in get_tree().get_nodes_in_group("players"):
		if (n as Node3D).global_position.distance_to(global_position) < radius + 2.0:
			near = true
	if not near:
		return
	_t = 0.0
	var any := false
	for c in get_tree().get_nodes_in_group("candle"):
		if (c as Node3D).global_position.distance_to(global_position) < radius and c.has_method("blow_out"):
			c.blow_out(out_time)
			any = true
	if any:
		var loc := get_tree().get_first_node_in_group("location")
		if loc and loc.has_method("say"):
			loc.say(tr("MSG_DRAUGHT"), 2.4)
