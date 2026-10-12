class_name Gull
extends Node3D
## Чайка кружит над причалом и пикирует на игрока поблизости: клюёт и подбрасывает (не убивает).

@export var center: Vector3 = Vector3.ZERO
@export var radius: float = 12.0
@export var height: float = 7.0
@export var speed: float = 0.6
@export var range_m: float = 14.0
@export var cooldown: float = 5.0

var _a := 0.0
var _dive := 0.0
var _cd := 3.0
var _target: Player
@onready var wing_l: Node3D = get_node_or_null("WingL")
@onready var wing_r: Node3D = get_node_or_null("WingR")


func _ready() -> void:
	_a = randf() * TAU


func _physics_process(delta: float) -> void:
	_a += speed * delta
	var base := center + Vector3(cos(_a) * radius, height + sin(_a * 3.0) * 0.6, sin(_a) * radius)
	_cd -= delta
	if _dive > 0.0 and is_instance_valid(_target):
		_dive -= delta
		var tgt := _target.global_position + Vector3(0, 1.0, 0)
		var np := global_position.move_toward(tgt, 14.0 * delta)
		if np != global_position:
			look_at(np + (np - global_position), Vector3.UP)
		global_position = np
		if global_position.distance_to(tgt) < 0.9:
			_target.linear_velocity += (tgt - base).normalized() * 3.0 + Vector3(0, 6.5, 0)
			_dive = 0.0
			var loc := get_tree().get_first_node_in_group("location")
			if loc and loc.has_method("say"):
				loc.say(tr("MSG_GULL"), 2.0)
		return
	var prev := global_position
	global_position = global_position.lerp(base, minf(delta * 3.0, 1.0))
	var v := global_position - prev
	if v.length() > 0.001:
		look_at(global_position + v, Vector3.UP)
	var flap := sin(Time.get_ticks_msec() * 0.012) * 0.6
	if wing_l:
		wing_l.rotation.z = flap
	if wing_r:
		wing_r.rotation.z = -flap
	if _cd <= 0.0:
		for n in get_tree().get_nodes_in_group("players"):
			var p := n as Player
			if p and p.global_position.distance_to(global_position) < range_m and not p.seated:
				_target = p
				_dive = 2.5
				_cd = cooldown
				break
