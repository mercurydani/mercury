class_name RescueCat
extends Node3D
## Кот, которого надо спасти. Рядом с ним [E] — спасти (заглушка: отнесём в фургон позже).
## Хвост качается, глаза моргают, над головой «Мяу!?».

signal rescued(player: Node3D)

@onready var tail: Node3D = get_node_or_null("Visual/Tail")
@onready var bubble: Label3D = get_node_or_null("Bubble")
@onready var eyes: Node3D = get_node_or_null("Visual/Eyes")
var _t := 0.0
var done := false


func _ready() -> void:
	var trig := get_node_or_null("Trigger") as Interactable
	if trig:
		trig.interacted.connect(_on_interact)
	if bubble:
		bubble.visible = false
		bubble.text = tr("CAT_MEOW")


func _on_interact(p: Node3D) -> void:
	if done:
		return
	done = true
	rescued.emit(p)
	if bubble:
		bubble.text = "♥"
		bubble.visible = true
	var trig := get_node_or_null("Trigger") as Interactable
	if trig:
		trig.monitorable = false


func _process(delta: float) -> void:
	_t += delta
	if tail:
		tail.rotation.y = sin(_t * 2.6) * 0.5
		tail.rotation.z = 0.25 + sin(_t * 1.3) * 0.1
	if eyes:
		eyes.scale.y = 0.1 if fmod(_t, 3.4) < 0.12 else 1.0
	if bubble and not done:
		var near := false
		for p in get_tree().get_nodes_in_group("players"):
			if (p as Node3D).global_position.distance_to(global_position) < 7.0:
				near = true
		bubble.visible = near and fmod(_t, 2.4) < 1.4
