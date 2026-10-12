class_name Cobweb
extends Area3D
## Паутина: липнет, пока игрок внутри (скорость падает). Возвращается при выходе.

@export var slow: float = 0.45
@export var message_key: String = "MSG_WEB"

var _orig := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1


func _physics_process(_delta: float) -> void:
	var inside := {}
	for b in get_overlapping_bodies():
		if b is Player:
			inside[b] = true
			if not _orig.has(b):
				_orig[b] = (b as Player).move_speed
				(b as Player).move_speed = _orig[b] * slow
				var loc := get_tree().get_first_node_in_group("location")
				if loc and loc.has_method("say"):
					loc.say(tr(message_key), 1.8)
	for p in _orig.keys():
		if not inside.has(p):
			if is_instance_valid(p):
				(p as Player).move_speed = _orig[p]
			_orig.erase(p)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		for p in _orig.keys():
			if is_instance_valid(p):
				(p as Player).move_speed = _orig[p]
		_orig.clear()
