class_name SlideZone
extends Area3D
## Мокрая скользкая поверхность: у игрока падает управляемость и его тянет вниз по склону.
## Работает через публичные поля Player (accel), сам player.gd не трогаем.

@export var downhill: Vector3 = Vector3(1, 0, 0)
@export var pull: float = 5.0
@export var grip: float = 5.0
@export var message_key: String = "MSG_SLIPPERY"

var _inside := {}
var _normal_accel := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b: Node3D) -> void:
	if b is Player and not _inside.has(b):
		_inside[b] = true
		_normal_accel[b] = (b as Player).accel
		(b as Player).accel = grip
		var loc := get_tree().get_first_node_in_group("location")
		if loc and loc.has_method("say"):
			loc.say(tr(message_key), 2.0)


func _on_exit(b: Node3D) -> void:
	if _inside.has(b):
		(b as Player).accel = _normal_accel[b]
		_inside.erase(b)
		_normal_accel.erase(b)


func _physics_process(delta: float) -> void:
	for b in _inside:
		var p := b as Player
		p.linear_velocity += downhill.normalized() * pull * delta


func _exit_tree() -> void:
	for b in _inside:
		if is_instance_valid(b):
			(b as Player).accel = _normal_accel[b]
