class_name ForkliftGhost
extends AnimatableBody3D
## Погрузчик-призрак: сам ездит по маршруту (точки в локальных координатах родителя), без водителя.
## Кинематическое тело: толкает игрока и ящики. На поворотах разворачивается на месте.

@export var path: PackedVector3Array = PackedVector3Array()
@export var speed: float = 2.2
@export var turn_rate: float = 2.2
@export var push_message_key: String = "MSG_FORKLIFT"

var _i := 0
var _origin := Vector3.ZERO
var _warned := {}
@onready var beacon: Node3D = get_node_or_null("Beacon")
@onready var lamp: OmniLight3D = get_node_or_null("Beacon/Light")
var _t := 0.0


func _ready() -> void:
	sync_to_physics = true
	_origin = position
	if path.size() > 0:
		position = path[0]
		_i = 1 % path.size()


func _physics_process(delta: float) -> void:
	_t += delta
	if beacon:
		beacon.rotation.y += 6.0 * delta
	if lamp:
		lamp.light_energy = 1.4 + sin(_t * 8.0) * 0.9
	if path.size() < 2:
		return
	var target := path[_i]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var want := atan2(to.x, to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	if absf(diff) > 0.05:
		rotation.y += clampf(diff, -turn_rate * delta, turn_rate * delta)
		return
	var step := minf(speed * delta, dist)
	if dist > 0.001:
		position += to / dist * step
	if dist <= speed * delta + 0.01:
		_i = (_i + 1) % path.size()
	for p in get_tree().get_nodes_in_group("players"):
		var d: float = (p as Node3D).global_position.distance_to(global_position)
		if d < 4.0 and not _warned.has(p):
			_warned[p] = true
			var loc := get_tree().get_first_node_in_group("location")
			if loc and loc.has_method("say"):
				loc.say(tr(push_message_key), 2.5)
			get_tree().create_timer(8.0).timeout.connect(func() -> void: _warned.erase(p))
