class_name Rat
extends Node3D
## Крыса-воришка бегает между точками маршрута (локальные координаты родителя) и кусает игрока рядом: толчок и сообщение.

@export var path: PackedVector3Array = PackedVector3Array()
@export var speed: float = 2.6
@export var bite_range: float = 1.0
@export var cooldown: float = 3.0

var _i := 0
var _cd := 0.0


func _ready() -> void:
	if path.size() > 0:
		position = path[0]
		_i = 1 % path.size()


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	if path.size() > 1:
		var d := path[_i] - position
		if d.length() < 0.15:
			_i = (_i + 1) % path.size()
		else:
			position += d.normalized() * speed * delta
			rotation.y = atan2(d.x, d.z)
	if _cd > 0.0:
		return
	for n in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p and not p.seated and p.global_position.distance_to(global_position) < bite_range:
			_cd = cooldown
			p.linear_velocity += (p.global_position - global_position).normalized() * 4.0 + Vector3(0, 3.0, 0)
			var loc := get_tree().get_first_node_in_group("location")
			if loc and loc.has_method("say"):
				loc.say(tr("MSG_RAT"), 2.0)
