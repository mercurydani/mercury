class_name FallingPlatform
extends StaticBody3D
## Платформа, которая проваливается через delay секунд после того, как на неё встали,
## и возвращается через respawn секунд.

@export var delay: float = 0.6
@export var respawn: float = 3.0

var _home: Vector3
var _falling := false


func _ready() -> void:
	_home = position
	var sensor: Area3D = $Sensor
	sensor.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _falling or not body.is_in_group("players"):
		return
	_falling = true
	var tw := create_tween()
	tw.tween_property(self, "position", _home + Vector3(0, -0.1, 0), delay * 0.5)
	tw.tween_property(self, "position", _home, delay * 0.5)
	await tw.finished
	$Shape.set_deferred("disabled", true)
	var fall := create_tween()
	fall.tween_property(self, "position", _home + Vector3(0, -6, 0), 0.6)
	await get_tree().create_timer(respawn).timeout
	position = _home
	$Shape.set_deferred("disabled", false)
	_falling = false
