class_name Player
extends RigidBody3D
## Смешной спасатель на RigidBody3D. Физика считается на хосте (сеть позже).

signal prompt_changed(text: String)
signal checkpoint_reached(index: int)

@export var move_speed: float = 6.5
@export var accel: float = 40.0
@export var air_accel: float = 18.0
@export var jump_velocity: float = 7.0
@export var player_color: Color = Color(1.0, 0.55, 0.1)

var seated: bool = false
var seat: Node3D = null
var respawn_point: Vector3
var checkpoint_index: int = -1
var _camera: Camera3D
var _interact_area: Area3D
var _floor_ray: RayCast3D
var _anim: AnimationPlayer
var _current: Interactable = null
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
@export var mouse_sens: float = 0.0025
@export var eye_height: float = 1.6


func _ready() -> void:
	lock_rotation = true
	can_sleep = false
	add_to_group("players")
	respawn_point = global_position
	_camera = get_node_or_null("Camera") as Camera3D
	if _camera:
		_camera.top_level = true
		_camera.current = true
		var mdl := get_node_or_null("Model") as Node3D
		if mdl:
			mdl.visible = false
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_interact_area = $InteractArea
	_floor_ray = $FloorRay
	_anim = find_child("AnimationPlayer", true, false) as AnimationPlayer
	var helmet := get_node_or_null("Model/Helmet") as MeshInstance3D
	if helmet:
		var m := StandardMaterial3D.new()
		m.albedo_color = player_color
		helmet.material_override = m


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if seated:
		state.linear_velocity = Vector3.ZERO
		return
	var on_floor := _floor_ray.is_colliding()
	var carry := Vector3.ZERO
	if on_floor and _floor_ray.get_collider() is MovingPlatform:
		carry = (_floor_ray.get_collider() as MovingPlatform).platform_velocity
		carry.y = 0.0
	var dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, _cam_yaw) * move_speed
	var v := state.linear_velocity
	var a := accel if on_floor else air_accel
	var horiz := Vector3(v.x, 0.0, v.z).move_toward(wish + carry, a * state.step)
	state.linear_velocity = Vector3(horiz.x, v.y, horiz.z)
	if wish.length() > 0.1:
		var model := get_node_or_null("Model") as Node3D
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(wish.x, wish.z), 12.0 * state.step)
	if Input.is_action_just_pressed("jump") and on_floor:
		state.linear_velocity.y = jump_velocity


func _process(_delta: float) -> void:
	_update_camera()
	_update_interactable()
	_update_anim()
	if Input.is_action_just_pressed("interact") and _current:
		_current.interact(self)
	if Input.is_action_just_pressed("respawn") and not seated:
		respawn()


func set_checkpoint(point: Vector3, index: int) -> void:
	if index > checkpoint_index:
		checkpoint_index = index
		respawn_point = point
		checkpoint_reached.emit(index)


func respawn() -> void:
	linear_velocity = Vector3.ZERO
	global_position = respawn_point


func sit(seat_node: Node3D) -> void:
	seated = true
	seat = seat_node
	freeze = true
	global_position = seat_node.global_position
	visible = false


func stand(exit_pos: Vector3) -> void:
	seated = false
	seat = null
	freeze = false
	visible = true
	global_position = exit_pos


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cam_yaw -= e.relative.x * mouse_sens
		_cam_pitch = clampf(_cam_pitch - e.relative.y * mouse_sens, -1.5, 1.5)
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_camera() -> void:
	if _camera == null:
		return
	if Input.is_action_pressed("cam_left"):
		_cam_yaw += 0.03
	if Input.is_action_pressed("cam_right"):
		_cam_yaw -= 0.03
	_camera.global_position = global_position + Vector3(0.0, eye_height, 0.0)
	_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _update_anim() -> void:
	if _anim == null:
		return
	var want := "idle"
	if not _floor_ray.is_colliding():
		want = "jump"
	elif Vector2(linear_velocity.x, linear_velocity.z).length() > 0.5:
		want = "walk"
	if _anim.current_animation != want and _anim.has_animation(want):
		_anim.play(want, 0.15)


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
