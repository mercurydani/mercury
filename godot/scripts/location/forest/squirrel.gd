class_name Squirrel
extends Node3D
## Злая белка на ветке: швыряется шишками в игроков поблизости. Шишка толкает и ругает, не убивает.

@export var range_m: float = 22.0
@export var interval: Vector2 = Vector2(2.6, 4.5)
@export var speed: float = 16.0

var _wait := 2.0
var _t := 0.0
@onready var tail: Node3D = get_node_or_null("Tail")
@onready var arm: Node3D = get_node_or_null("Arm")


func _ready() -> void:
	_wait = randf_range(interval.x, interval.y)


func _process(delta: float) -> void:
	_t += delta
	if tail:
		tail.rotation.z = sin(_t * 3.0) * 0.25
	var p := _nearest()
	if p:
		var dir := p.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 4.0 * delta)


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(interval.x, interval.y)
	var p := _nearest()
	if p == null or p.global_position.distance_to(global_position) > range_m:
		return
	_throw(p)


func _nearest() -> Player:
	var best: Player = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("players"):
		var d := (n as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = n as Player
	return best


func _throw(target: Player) -> void:
	if arm:
		var tw := create_tween()
		tw.tween_property(arm, "rotation:x", -2.2, 0.15)
		tw.tween_property(arm, "rotation:x", 0.0, 0.3)
	var cone := RigidBody3D.new()
	cone.mass = 0.3
	cone.collision_layer = 1
	cone.collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.16
	cs.shape = sh
	cone.add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.14
	cm.height = 0.32
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = LocUtil.mat(Color(0.45, 0.3, 0.16), 0.9)
	cone.add_child(mi)
	get_parent().add_child(cone)
	var from := global_position + Vector3(0, 0.5, 0)
	cone.global_position = from
	var to := target.global_position + Vector3(0, 1.0, 0) + target.linear_velocity * 0.4
	var flat := to - from
	var t := maxf(flat.length() / speed, 0.25)
	var vel := flat / t + Vector3(0, 0.5 * 9.8 * t, 0)
	cone.linear_velocity = vel
	cone.body_entered.connect(func(b: Node) -> void:
		if b is Player:
			(b as Player).linear_velocity += (b.global_position - cone.global_position).normalized() * 6.0 + Vector3(0, 2.5, 0)
			var loc := get_tree().get_first_node_in_group("location")
			if loc and loc.has_method("say"):
				loc.say(tr("MSG_SQUIRREL"), 2.0))
	cone.contact_monitor = true
	cone.max_contacts_reported = 3
	get_tree().create_timer(5.0).timeout.connect(cone.queue_free)
