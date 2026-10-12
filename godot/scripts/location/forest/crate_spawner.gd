class_name CrateSpawner
extends Node3D
## Выше по течению «уносит ящики»: деревянные ящики плывут по ручью и бьют по ногам.

@export var interval: float = 6.0
@export var max_crates: int = 5

var _t := 2.0
var _crates: Array[RigidBody3D] = []


func _physics_process(delta: float) -> void:
	_t -= delta
	_crates = _crates.filter(func(c: RigidBody3D) -> bool: return is_instance_valid(c))
	if _t > 0.0 or _crates.size() >= max_crates:
		return
	_t = interval * randf_range(0.7, 1.3)
	var c := RigidBody3D.new()
	c.mass = 8.0
	c.collision_layer = 1
	c.collision_mask = 1
	c.linear_damp = 0.4
	c.add_to_group("floaters")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 0.7, 0.7)
	cs.shape = sh
	c.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.9, 0.7, 0.7)
	mi.mesh = bm
	mi.material_override = LocUtil.mat(Color(0.7, 0.55, 0.35), 0.9)
	c.add_child(mi)
	for i in 3:
		var slat := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.94, 0.05, 0.74)
		slat.mesh = sm
		slat.material_override = LocUtil.mat(Color(0.5, 0.38, 0.22), 0.9)
		slat.position = Vector3(0, -0.22 + i * 0.22, 0)
		c.add_child(slat)
	get_parent().add_child(c)
	var x := global_position.x
	c.global_position = Vector3(x, RavineTerrain.WATER_Y + 0.2, RavineTerrain.meander(x) + randf_range(-1.2, 1.2))
	c.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	_crates.append(c)
	c.tree_exited.connect(func() -> void: pass)
	get_tree().create_timer(40.0).timeout.connect(func() -> void:
		if is_instance_valid(c):
			c.queue_free())
