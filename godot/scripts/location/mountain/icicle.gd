class_name Icicle
extends Area3D
## Сосулька: когда игрок подходит под неё, через delay секунд падает и отталкивает попавшего (не вред). Потом отрастает.

@export var trigger_radius: float = 2.2
@export var delay: float = 0.7
@export var drop: float = 4.0
@export var regrow: float = 7.0

var _state := 0     # 0 висит, 1 ждёт, 2 падает, 3 отращивается
var _t := 0.0
var _home := Vector3.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_home = position


func _physics_process(delta: float) -> void:
	match _state:
		0:
			for n in get_tree().get_nodes_in_group("players"):
				var p := (n as Node3D).global_position
				var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
				if d < trigger_radius and p.y < global_position.y and global_position.y - p.y < drop + 3.0:
					_state = 1
					_t = delay
		1:
			_t -= delta
			position = _home + Vector3(sin(_t * 70.0) * 0.03, 0, 0)
			if _t <= 0.0:
				_state = 2
				_t = 0.0
		2:
			_t += delta
			position = _home - Vector3(0, minf(_t * _t * 12.0, drop), 0)
			for b in get_overlapping_bodies():
				if b is Player:
					(b as Player).linear_velocity += Vector3(randf_range(-1, 1), 3.0, randf_range(-1, 1)).normalized() * 6.0
					var loc := get_tree().get_first_node_in_group("location")
					if loc and loc.has_method("say"):
						loc.say(tr("MSG_ICICLE"), 2.0)
					_land()
					return
			if _t * _t * 12.0 >= drop:
				_land()
		3:
			_t -= delta
			if _t <= 0.0:
				position = _home
				visible = true
				_state = 0


func _land() -> void:
	visible = false
	_state = 3
	_t = regrow
