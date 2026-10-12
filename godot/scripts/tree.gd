@tool
class_name YardTree
extends StaticBody3D
## Процедурное low-poly дерево для двора: берёза, тополь или липа.

enum Kind { BIRCH, POPLAR, LINDEN }

@export var kind: Kind = Kind.BIRCH:
	set(v):
		kind = v
		_rebuild()
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		_rebuild()
@export var height: float = 7.0:
	set(v):
		height = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("generated"):
			remove_child(c)
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trunk_h := height * (0.55 if kind == Kind.POPLAR else 0.45)
	var trunk_col := Color(0.92, 0.9, 0.85) if kind == Kind.BIRCH else Color(0.42, 0.32, 0.24)
	var tm := CylinderMesh.new()
	tm.top_radius = 0.12 if kind == Kind.BIRCH else 0.18
	tm.bottom_radius = tm.top_radius * 1.4
	tm.height = trunk_h
	tm.radial_segments = 6
	tm.rings = 1
	_part(tm, Vector3(0, trunk_h * 0.5, 0), Vector3.ONE, trunk_col)
	if kind == Kind.BIRCH:
		for i in 4:
			var sm := CylinderMesh.new()
			sm.top_radius = tm.top_radius * 1.25
			sm.bottom_radius = sm.top_radius
			sm.height = 0.12
			sm.radial_segments = 6
			_part(sm, Vector3(0, trunk_h * (0.2 + 0.2 * i), 0), Vector3.ONE, Color(0.15, 0.15, 0.15))
	var green := [Color(0.35, 0.6, 0.25), Color(0.42, 0.66, 0.3), Color(0.3, 0.52, 0.22)]
	var blobs := 3 if kind != Kind.POPLAR else 2
	for i in blobs:
		var cm := SphereMesh.new()
		cm.radial_segments = 7
		cm.rings = 4
		var r := height * (0.22 if kind == Kind.LINDEN else 0.18) * rng.randf_range(0.8, 1.15)
		cm.radius = r
		cm.height = r * 2.0
		var stretch := Vector3(1, 2.4, 1) if kind == Kind.POPLAR else Vector3(1, 1.15, 1)
		var off := Vector3(rng.randf_range(-0.6, 0.6), trunk_h + r * stretch.y * 0.6 + i * r * 0.5, rng.randf_range(-0.6, 0.6))
		_part(cm, off, stretch, green[rng.randi() % 3])
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = trunk_h
	cs.shape = cyl
	cs.position = Vector3(0, trunk_h * 0.5, 0)
	cs.set_meta("generated", true)
	add_child(cs)


func _part(mesh: Mesh, pos: Vector3, s: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = s
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	mi.material_override = m
	mi.set_meta("generated", true)
	add_child(mi)
