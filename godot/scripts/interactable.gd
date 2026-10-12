class_name Interactable
extends Area3D
## Зона взаимодействия. Игрок рядом жмёт [E], зона шлёт сигнал interacted.

signal interacted(player: Node3D)

@export var prompt_key: String = ""


func get_prompt() -> String:
	return tr("HINT_INTERACT") % tr(prompt_key)


func interact(player: Node3D) -> void:
	interacted.emit(player)
