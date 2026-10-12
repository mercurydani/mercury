@tool
class_name YardTree
extends StaticBody3D
## Процедурное low-poly дерево для двора: берёза, тополь или липа.
## Ствол с ветками и неровная крона из нескольких «комков».

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
	var st := Geo.begin()
	var trunk_h := height * (0.6 if kind == Kind.POPLAR else 0.5)
	var r0 := 0.16 if kind == Kind.BIRCH else 0.24
	var bark := Color(0.9, 0.89, 0.84) if kind == Kind.BIRCH else Color(0.38, 0.3, 0.24)
	# Ствол с лёгким изгибом из трёх сегментов
	var pts := [Vector3.ZERO]
	for i in 3:
		var p: Vector3 = pts[-1] + Vector3(rng.randf_range(-0.15, 0.15), trunk_h / 3.0, rng.randf_range(-0.15, 0.15))
		pts.append(p)
	for i in 3:
		var rad := r0 * (1.0 - i * 0.22)
		Geo.rod(st, pts[i], pts[i + 1], rad, bark, 7)
	# Корни-утолщение
	Geo.prism(st, Vector3(0, 0, 0), r0 * 1.8, r0 * 1.05, 0.35, bark.darkened(0.1), 7)
	if kind == Kind.BIRCH:
		# Чёрные чечевички берёзы
		for i in 10:
			var t := rng.randf_range(0.1, 0.95)
			var p: Vector3 = (pts[0] as Vector3).lerp(pts[3], t)
			var ang := rng.randf() * TAU
			var d := Vector3(cos(ang), 0, sin(ang))
			Geo.box(st, p + d * r0 * 0.85, Vector3(0.12, 0.03, 0.06), Color(0.12, 0.12, 0.12), Transform3D.IDENTITY)
	# Ветки
	var top: Vector3 = pts[3]
	var branches := 5 if kind != Kind.POPLAR else 3
	for i in branches:
		var t := rng.randf_range(0.55, 0.95)
		var from: Vector3 = (pts[0] as Vector3).lerp(top, t)
		var ang := TAU * i / branches + rng.randf_range(-0.3, 0.3)
		var out := 1.6 if kind == Kind.LINDEN else (0.9 if kind == Kind.BIRCH else 0.5)
		var to := from + Vector3(cos(ang) * out, rng.randf_range(0.8, 1.6), sin(ang) * out)
		Geo.rod(st, from, to, r0 * 0.4, bark, 5)
	# Крона
	var greens := [Color(0.33, 0.52, 0.2), Color(0.4, 0.58, 0.24), Color(0.28, 0.46, 0.19), Color(0.45, 0.6, 0.22)]
	var blobs := 7 if kind == Kind.LINDEN else (6 if kind == Kind.BIRCH else 5)
	var crown_c := top + Vector3(0, height * (0.12 if kind != Kind.POPLAR else 0.2), 0)
	for i in blobs:
		var size := height * (0.2 if kind == Kind.LINDEN else 0.15)
		var spread := Vector3(height * 0.18, height * 0.1, height * 0.18)
		var rad := Vector3(size, size * 0.85, size) * rng.randf_range(0.75, 1.1)
		if kind == Kind.POPLAR:
			spread = Vector3(height * 0.07, height * 0.22, height * 0.07)
			rad = Vector3(size * 0.75, size * 1.4, size * 0.75) * rng.randf_range(0.8, 1.1)
		var off := Vector3(rng.randf_range(-1, 1) * spread.x, rng.randf_range(-1, 1) * spread.y, rng.randf_range(-1, 1) * spread.z)
		Geo.blob(st, crown_c + off, rad, greens[rng.randi() % greens.size()], rng, 5, 9, 0.2)
	var mi := MeshInstance3D.new()
	mi.mesh = Geo.finish(st)
	mi.material_override = Geo.material(0.95)
	mi.set_meta("generated", true)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r0 * 1.3
	cyl.height = trunk_h
	cs.shape = cyl
	cs.position = Vector3(0, trunk_h * 0.5, 0)
	cs.set_meta("generated", true)
	add_child(cs)
