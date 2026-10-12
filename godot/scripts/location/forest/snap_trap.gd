class_name SnapTrap
extends Area3D
## Капкан охотников: ложная тревога. Щёлкает, подбрасывает пластиковые «зубы» и ничего не ломает.

var _armed := true
@onready var jaw_a: Node3D = get_node_or_null("JawA")
@onready var jaw_b: Node3D = get_node_or_null("JawB")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_enter)


func _on_enter(b: Node3D) -> void:
	if not _armed or not (b is Player):
		return
	_armed = false
	if jaw_a and jaw_b:
		var tw := create_tween()
		tw.tween_property(jaw_a, "rotation:x", 0.0, 0.08)
		tw.parallel().tween_property(jaw_b, "rotation:x", 0.0, 0.08)
	(b as Player).linear_velocity += Vector3(0, 4.5, 0)
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_TRAP"))
	await get_tree().create_timer(4.0).timeout
	if jaw_a and jaw_b:
		var tw2 := create_tween()
		tw2.tween_property(jaw_a, "rotation:x", -1.2, 0.5)
		tw2.parallel().tween_property(jaw_b, "rotation:x", 1.2, 0.5)
	_armed = true
