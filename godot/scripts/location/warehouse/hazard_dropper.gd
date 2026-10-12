class_name HazardDropper
extends Area3D
## Зона-ловушка: при входе игрока роняет ящики со стеллажа или выкатывает бочки.
## kind: "crate" (падает сверху в точках drop_points) или "barrel" (катится из точек в направлении roll_dir).
## Точки и направление заданы в локальных координатах зоны. После срабатывания перезаряжается через cooldown.

@export var kind: String = "crate"
@export var drop_points: PackedVector3Array = PackedVector3Array()
@export var roll_dir: Vector3 = Vector3(1, 0, 0)
@export var roll_speed: float = 5.0
@export var cooldown: float = 9.0
@export var message_key: String = "MSG_CRATE"
@export var count: int = 3

var _armed := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_enter)


func _on_enter(b: Node3D) -> void:
	if not _armed or not (b is Player):
		return
	_armed = false
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr(message_key), 2.5)
	for i in count:
		if drop_points.is_empty():
			break
		_spawn(drop_points[i % drop_points.size()], i)
		await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(cooldown).timeout
	_armed = true


func _spawn(local_pos: Vector3, i: int) -> void:
	var rb := RigidBody3D.new()
	rb.collision_layer = 1
	rb.collision_mask = 1
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	if kind == "barrel":
		rb.mass = 14.0
		var sh := CylinderShape3D.new()
		sh.radius = 0.32
		sh.height = 0.9
		cs.shape = sh
		var cm := CylinderMesh.new()
		cm.top_radius = 0.32
		cm.bottom_radius = 0.32
		cm.height = 0.9
		cm.radial_segments = 14
		mi.mesh = cm
		var cols := [Color(0.15, 0.3, 0.6), Color(0.75, 0.2, 0.15), Color(0.2, 0.45, 0.25)]
		mi.material_override = LocUtil.mat(cols[i % 3], 0.5, 0.4)
	else:
		rb.mass = 10.0
		var sh2 := BoxShape3D.new()
		sh2.size = Vector3(0.8, 0.7, 0.8)
		cs.shape = sh2
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 0.7, 0.8)
		mi.mesh = bm
		mi.material_override = LocUtil.mat(Color(0.72, 0.55, 0.34).darkened(0.08 * (i % 3)), 0.9)
	rb.add_child(cs)
	rb.add_child(mi)
	rb.contact_monitor = true
	rb.max_contacts_reported = 3
	get_parent().add_child(rb)
	rb.global_position = to_global(local_pos)
	if kind == "barrel":
		rb.rotation_degrees.z = 90.0
		rb.linear_velocity = (global_transform.basis * roll_dir).normalized() * roll_speed
	rb.body_entered.connect(func(body: Node) -> void:
		if body is Player:
			(body as Player).linear_velocity += (body.global_position - rb.global_position).normalized() * 5.0 + Vector3(0, 2.0, 0))
	get_tree().create_timer(12.0).timeout.connect(rb.queue_free)
