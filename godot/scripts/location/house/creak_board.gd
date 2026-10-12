class_name CreakBoard
extends Area3D
## Скрипучая половица: когда игрок наступает, поднимается шум. Раз в cooldown секунд на игрока.

@export var amount: float = 1.0
@export var cooldown: float = 3.0
@export var message_key: String = "MSG_CREAK"

var _cd := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body)


func _on_body(b: Node3D) -> void:
	if not (b is Player):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _cd.get(b, -99.0) + cooldown > now:
		return
	_cd[b] = now
	var d := get_tree().get_first_node_in_group("haunt")
	if d and d.has_method("add_noise"):
		d.add_noise(amount)
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr(message_key), 1.6)
