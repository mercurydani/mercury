class_name CrackKill
extends Area3D
## Трещина во льду: провалившийся игрок возвращается на чекпоинт («ледяная статуя оттаивает у костра»).

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on)


func _on(b: Node3D) -> void:
	if not (b is Player):
		return
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_CRACK"), 2.5)
	if loc and loc.has_signal("player_fell"):
		loc.player_fell.emit(b)
	(b as Player).respawn()
