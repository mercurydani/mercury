class_name WindGust
extends Area3D
## Порывы ветра: предупреждение, затем толчок всем игрокам в зоне. Хост-логика.
## Узлы группы "windy" (флаги, бельё, антенны) качаются сильнее во время порыва: см. sway.gd.

@export var direction: Vector3 = Vector3(0, 0, -1)
@export var strength: float = 9.0
## если задано — сила по сложности (простая, средняя, сложная)
@export var strength_by_tier: PackedFloat32Array = PackedFloat32Array()
@export var interval: Vector2 = Vector2(7.0, 11.0)
@export var warn_time: float = 1.8
@export var gust_time: float = 1.1

var gusting: bool = false
var warning: bool = false
var _t: float = 3.0
var _normal_accel := {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_t = randf_range(interval.x, interval.y)
	add_to_group("wind")


func _physics_process(delta: float) -> void:
	_t -= delta
	if gusting:
		for b in get_overlapping_bodies():
			if b is Player:
				(b as Player).linear_velocity += direction.normalized() * strength * delta
	if _t > 0.0:
		return
	if not warning and not gusting:
		warning = true
		_say("MSG_WIND_SOON")
		_t = warn_time
	elif warning:
		warning = false
		gusting = true
		_say("MSG_WIND")
		_slip(true)
		_t = gust_time
	else:
		gusting = false
		_slip(false)
		_t = randf_range(interval.x, interval.y)


func _slip(on: bool) -> void:
	for b in get_overlapping_bodies():
		if b is Player:
			if on:
				_normal_accel[b] = (b as Player).accel
				(b as Player).accel = 10.0
			elif _normal_accel.has(b):
				(b as Player).accel = _normal_accel[b]
	if not on:
		_normal_accel.clear()


func _say(key: String) -> void:
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr(key), 2.0)


## Нормированная «сила ветра» для анимации (0..1).
func intensity() -> float:
	if gusting:
		return 1.0
	if warning:
		return 0.5
	return 0.12
