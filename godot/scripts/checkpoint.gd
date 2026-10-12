class_name Checkpoint
extends Area3D
## Чекпоинт паркура. Касание запоминает точку возврата (кнопка R).

signal reached(index: int)

@export var index: int = 0


func _ready() -> void:
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			(b as Player).set_checkpoint(global_position + Vector3(0, 0.5, 0), index)
			reached.emit(index))
