class_name Player
extends RigidBody3D
## Смешной спасатель на RigidBody3D. Физика считается на хосте (сеть позже).

signal prompt_changed(text: String)

@export var move_speed: float = 7.0
@export var accel: float = 40.0
@export var jump_impulse: float = 7.0
@export var player_color: Color = Color(1.0, 0.55, 0.1)

var seated: bool = false
var seat: Node3D = null
var _camera: Camera3D
var _interact_area: Area3D
var _floor_ray: RayCast3D
var _current: Interactable = null


func _ready() -> void:
	lock_rotation = true
	can_sleep = false
	add_to_group("players")
	_camera = get_node_or_null("Camera") as Camera3D
	_interact_area = $InteractArea
	_floor_ray = $FloorRay


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if seated:
		state.linear_velocity = Vector3.ZERO
		return
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_yaw := _camera.global_rotation.y if _camera else 0.0
	var wish := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, cam_yaw) * move_speed
	var v := state.linear_velocity
	var horiz := Vector3(v.x, 0.0, v.z).move_toward(wish, accel * state.step)
	state.linear_velocity = Vector3(horiz.x, v.y, horiz.z)
	if wish.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-wish.x, -wish.z), 12.0 * state.step)
	if Input.is_action_just_pressed("jump") and _floor_ray.is_colliding():
		state.linear_velocity.y = jump_impulse


func _process(_delta: float) -> void:
	_update_camera()
	_update_interactable()
	if Input.is_action_just_pressed("interact") and _current:
		_current.interact(self)


func sit(seat_node: Node3D) -> void:
	seated = true
	seat = seat_node
	freeze = true
	global_position = seat_node.global_position
	rotation = Vector3(0.0, seat_node.global_rotation.y, 0.0)


func stand(exit_pos: Vector3) -> void:
	seated = false
	seat = null
	freeze = false
	global_position = exit_pos


func _update_camera() -> void:
	if _camera == null:
		return
	var target := global_position + Vector3(0.0, 9.0, 11.0)
	_camera.global_position = _camera.global_position.lerp(target, 0.1)
	_camera.look_at(global_position + Vector3(0.0, 1.0, 0.0))


func _update_interactable() -> void:
	var best: Interactable = null
	var best_d := INF
	for a in _interact_area.get_overlapping_areas():
		if a is Interactable:
			var d := global_position.distance_to(a.global_position)
			if d < best_d:
				best_d = d
				best = a
	if best != _current:
		_current = best
		prompt_changed.emit(_current.get_prompt() if _current else "")
