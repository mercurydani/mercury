class_name Avalanche
extends Node3D
## Лавинки: по таймеру с маркеров Spawn* скатываются снежные шары. Перед этим слышен гул (сообщение). Шар сбивает игрока.

@export var period: float = 22.0
@export var warn: float = 2.0
@export var speed: float = 4.0
@export var radius: float = 1.2

var _t := 0.0
var _warned := false


func _ready() -> void:
	_t = randf() * period * 0.4


func _physics_process(delta: float) -> void:
	_t += delta
	if not _warned and _t > period - warn:
		_warned = true
		var loc := get_tree().get_first_node_in_group("location")
		if loc and loc.has_method("say"):
			for n in get_tree().get_nodes_in_group("players"):
				if (n as Node3D).global_position.distance_to(global_position) < 90.0:
					loc.say(tr("MSG_AVALANCHE_WARN"), 2.2)
					break
	if _t >= period:
		_t = 0.0
		_warned = false
		spawn_now()


func spawn_now() -> void:
	for c in get_children():
		if c is Marker3D:
			_ball((c as Node3D).global_position)


func _ball(pos: Vector3) -> void:
	var rb := RigidBody3D.new()
	rb.mass = 80.0
	rb.collision_layer = 1
	rb.collision_mask = 1
	rb.contact_monitor = true
	rb.max_contacts_reported = 4
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	rb.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = LocUtil.mat(Color(0.96, 0.97, 1.0), 0.95)
	rb.add_child(mi)
	var host := get_tree().get_first_node_in_group("location")
	host.add_child(rb)
	rb.global_position = pos
	rb.linear_velocity = Vector3(0, 0, 0)
	rb.body_entered.connect(func(b: Node) -> void:
		if b is Player:
			(b as Player).linear_velocity += (b.global_position - rb.global_position).normalized() * 9.0 + Vector3(0, 4.0, 0)
			var loc := get_tree().get_first_node_in_group("location")
			if loc and loc.has_method("say"):
				loc.say(tr("MSG_AVALANCHE_HIT"), 2.2))
	get_tree().create_timer(14.0).timeout.connect(rb.queue_free)
