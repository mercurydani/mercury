class_name BrokenTrampoline
extends Area3D
## Сломанный батут: подкидывает вполсилы и толкает в случайную сторону, а потом проседает.

@export var bounce: float = 6.0
@export var shove: float = 7.0
@export var message_key: String = "MSG_BROKEN"

var _cool := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_enter)


func _on_enter(b: Node3D) -> void:
	if _cool or not (b is Player):
		return
	_cool = true
	var a := randf() * TAU
	(b as Player).linear_velocity += Vector3(cos(a) * shove, bounce, sin(a) * shove)
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr(message_key), 2.0)
	await get_tree().create_timer(1.5).timeout
	_cool = false
