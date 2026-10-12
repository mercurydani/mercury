class_name SecretDoor
extends AnimatableBody3D
## Шкаф-дверь в тайную комнату: открывается рычагом-подсвечником (Interactable из группы "secret_switch").

@export var offset: Vector3 = Vector3(2.2, 0, 0)
@export var duration: float = 1.2

var _home := Vector3.ZERO
var opened := false


func _ready() -> void:
	sync_to_physics = true
	_home = position
	for n in get_tree().get_nodes_in_group("secret_switch"):
		(n as Interactable).interacted.connect(func(_p: Node3D) -> void: open())


func open() -> void:
	if opened:
		return
	opened = true
	var tw := create_tween()
	tw.tween_property(self, "position", _home + offset, duration).set_trans(Tween.TRANS_SINE)
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_SECRET"), 2.5)
