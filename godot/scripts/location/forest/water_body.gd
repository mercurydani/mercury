class_name WaterBody
extends Node3D
## Ручей: течение несёт игроков и ящики к водопаду, глубина замедляет, в омуте можно утонуть.
## Хост-логика: на клиентах игроки управляются синхронизацией.

@export var current_speed: float = 1.6          # м/с в русле
@export var wade_slow: float = 0.28             # потеря скорости на метр глубины
@export var drown_depth: float = 2.3            # глубже — тонешь через drown_time
@export var drown_time: float = 1.6
## Сила течения по сложности (простая, средняя, сложная), множитель к current_speed
@export var current_by_tier: PackedFloat32Array = PackedFloat32Array([0.8, 1.0, 1.4])

var _orig_speed := {}
var _drown_t := {}
var multiplier := 1.0
var _loc: Node = null


func _ready() -> void:
	add_to_group("water")
	_loc = get_tree().get_first_node_in_group("location")


func set_tier(t: int) -> void:
	if current_by_tier.size() > t:
		multiplier = current_by_tier[t]


func depth_at(p: Vector3) -> float:
	return RavineTerrain.WATER_Y - RavineTerrain.height(p.x, p.z)


func flow_at(p: Vector3) -> Vector3:
	# Вдоль русла: направление +X плюс подруливание по изгибу
	var dm := RavineTerrain.meander(p.x + 1.0) - RavineTerrain.meander(p.x - 1.0)
	return Vector3(1.0, 0.0, dm * 0.5).normalized()


func _physics_process(delta: float) -> void:
	for n in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p == null or p.seated:
			continue
		var d := depth_at(p.global_position)
		if d > 0.15 and p.global_position.x < RavineTerrain.FALL_X + 6.0:
			if not _orig_speed.has(p):
				_orig_speed[p] = p.move_speed
			p.move_speed = _orig_speed[p] * clampf(1.0 - d * wade_slow, 0.35, 1.0)
			var pull := flow_at(p.global_position) * current_speed * multiplier * clampf(d / 1.0, 0.2, 1.8)
			p.linear_velocity += pull * delta * 2.2
			if d > drown_depth:
				_drown_t[p] = _drown_t.get(p, 0.0) + delta
				if _drown_t[p] > drown_time:
					_drown(p)
			else:
				_drown_t[p] = maxf(_drown_t.get(p, 0.0) - delta, 0.0)
		elif _orig_speed.has(p):
			p.move_speed = _orig_speed[p]
			_orig_speed.erase(p)
			_drown_t.erase(p)
	for n in get_tree().get_nodes_in_group("floaters"):
		var rb := n as RigidBody3D
		if rb == null:
			continue
		var d2 := depth_at(rb.global_position)
		if d2 > 0.0:
			var sub := clampf(RavineTerrain.WATER_Y - rb.global_position.y + 0.3, 0.0, 1.0)
			rb.apply_central_force(Vector3.UP * rb.mass * 9.8 * 1.6 * sub)
			rb.apply_central_force(flow_at(rb.global_position) * rb.mass * current_speed * multiplier * 4.0)
			rb.linear_velocity *= 1.0 - 0.8 * delta


func _drown(p: Player) -> void:
	_drown_t[p] = 0.0
	_spawn_duck_ring(p.global_position)
	if _orig_speed.has(p):
		p.move_speed = _orig_speed[p]
		_orig_speed.erase(p)
	if _loc and _loc.has_method("say"):
		_loc.say(tr("MSG_DROWNED"))
	if _loc and _loc.has_signal("player_fell"):
		_loc.player_fell.emit(p)
	p.respawn()


## Утиный круг всплывает на месте и качается на воде.
func _spawn_duck_ring(pos: Vector3) -> void:
	var ring := Node3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.7
	tm.rings = 24
	tm.ring_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = LocUtil.mat(Color(1.0, 0.85, 0.15), 0.4)
	ring.add_child(mi)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.3
	hs.height = 0.6
	head.mesh = hs
	head.material_override = LocUtil.mat(Color(1.0, 0.85, 0.15), 0.4)
	head.position = Vector3(0, 0.4, 0.55)
	ring.add_child(head)
	var beak := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 0.08, 0.3)
	beak.mesh = bm
	beak.material_override = LocUtil.mat(Color(0.95, 0.5, 0.1), 0.5)
	beak.position = Vector3(0, 0.38, 0.9)
	ring.add_child(beak)
	get_parent().add_child(ring)
	ring.global_position = Vector3(pos.x, RavineTerrain.WATER_Y + 0.05, pos.z)
	var tw := ring.create_tween().set_loops(8)
	tw.tween_property(ring, "rotation:z", 0.15, 0.5)
	tw.tween_property(ring, "rotation:z", -0.15, 0.5)
	get_tree().create_timer(8.0).timeout.connect(ring.queue_free)
