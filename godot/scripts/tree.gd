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
	var g := GeoMesh.new()
	var st := g.s("bark")
	var trunk_h := height * (0.6 if kind == Kind.POPLAR else 0.5)
	var r0 := 0.17 if kind == Kind.BIRCH else 0.26
	var bark := Color(0.95, 0.94, 0.9) if kind == Kind.BIRCH else Color(0.5, 0.4, 0.32)
	# Ствол с лёгким изгибом из нескольких сегментов, сужается кверху
	var pts := [Vector3.ZERO]
	var segs := 5
	for i in segs:
		var p: Vector3 = pts[-1] + Vector3(rng.randf_range(-0.1, 0.1), trunk_h / segs, rng.randf_range(-0.1, 0.1))
		pts.append(p)
	st.set_smooth_group(0)
	for i in segs:
		Geo.rod(st, pts[i], pts[i + 1], r0 * (1.0 - i * 0.12), bark, 12)
	Geo.prism(st, Vector3.ZERO, r0 * 1.9, r0 * 1.0, 0.45, bark.darkened(0.12), 12)
	st.set_smooth_group(-1)
	if kind == Kind.BIRCH:
		# Чёрные чечевички берёзы
		var dark := g.s("plain")
		for i in 26:
			var t := rng.randf_range(0.05, 0.98)
			var seg_i := mini(int(t * segs), segs - 1)
			var p: Vector3 = (pts[seg_i] as Vector3).lerp(pts[seg_i + 1], t * segs - seg_i)
			var ang := rng.randf() * TAU
			var d := Vector3(cos(ang), 0, sin(ang))
			var rad := r0 * (1.0 - seg_i * 0.12) + 0.004
			Geo.box(dark, Vector3.ZERO, Vector3(rng.randf_range(0.06, 0.16), rng.randf_range(0.02, 0.05), 0.02), Color(0.1, 0.1, 0.1), Transform3D(Basis(Vector3.UP, PI * 0.5 - ang), p + d * rad))
	# Ветки двух уровней
	var top: Vector3 = pts[-1]
	var tips := []
	var branches := 7 if kind != Kind.POPLAR else 5
	for i in branches:
		var t := rng.randf_range(0.5, 0.97)
		var from: Vector3 = (pts[0] as Vector3).lerp(top, t)
		var ang := TAU * i / branches + rng.randf_range(-0.3, 0.3)
		var out := 2.0 if kind == Kind.LINDEN else (1.2 if kind == Kind.BIRCH else 0.6)
		var to := from + Vector3(cos(ang) * out, rng.randf_range(1.0, 1.8), sin(ang) * out)
		Geo.rod(st, from, to, r0 * 0.38, bark, 8)
		tips.append(to)
		for k in 2:
			var sub := to + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.3, 0.9), rng.randf_range(-0.8, 0.8)) * (0.6 if kind == Kind.POPLAR else 1.0)
			Geo.rod(st, to.lerp(from, 0.3), sub, r0 * 0.18, bark, 6)
			tips.append(sub)
	tips.append(top + Vector3(0, height * 0.12, 0))
	# Крона: тёмное ядро + карточки с листьями вокруг кончиков веток
	var core := g.s("foliage")
	var lv := g.s("leaves")
	var crown_c := top + Vector3(0, height * (0.12 if kind != Kind.POPLAR else 0.22), 0)
	var cr := Vector3(height * 0.22, height * 0.18, height * 0.22)
	if kind == Kind.LINDEN:
		cr = Vector3(height * 0.3, height * 0.22, height * 0.3)
	elif kind == Kind.POPLAR:
		cr = Vector3(height * 0.11, height * 0.3, height * 0.11)
	Geo.blob(core, crown_c, cr * 0.72, Color(0.16, 0.26, 0.1), rng, 7, 12, 0.15)
	var tint := [Color(1, 1, 1), Color(0.9, 1.0, 0.85), Color(1.05, 1.0, 0.8), Color(0.85, 0.95, 0.85)]
	var cards := 70 if kind == Kind.LINDEN else 55
	for i in cards:
		# Точка на поверхности эллипсоида кроны, ближе к веткам
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1), rng.randf_range(-1, 1)).normalized()
		var p := crown_c + dir * cr * rng.randf_range(0.55, 1.0)
		var size := rng.randf_range(1.1, 1.9) * (height / 8.0)
		var bs := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
		Geo.card(lv, p, bs.scaled(Vector3(size, size, size)), tint[rng.randi() % tint.size()])
		Geo.card(lv, p, (bs * Basis(Vector3.UP, PI * 0.5)).scaled(Vector3(size, size, size)), tint[rng.randi() % tint.size()])
	var mi := MeshInstance3D.new()
	mi.mesh = g.build()
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
