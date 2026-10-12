class_name Props
# Аэродромная техника и мелкие детали (собираются из примитивов; нос смотрит в -Z).

static func _wheels(p: Node3D, xs: Array, zs: Array, r: float) -> void:
	for x in xs:
		for z in zs:
			Rig.cyl(p, r, r, 0.18, Vector3(x, r, z), Color("15181f"), Vector3(0, 0, 90))
			Rig.cyl(p, r * 0.55, r * 0.55, 0.19, Vector3(x, r, z), Color("c8ced8"), Vector3(0, 0, 90))

static func _beacon(p: Node3D, pos: Vector3) -> void:
	Rig.cyl(p, 0.06, 0.06, 0.08, pos, Color("333b4a"))
	Rig.sphere(p, 0.07, pos + Vector3(0, 0.07, 0), Color("ffb020"), Vector3.ONE, 3.0)

# Багажный тягач с цепочкой тележек и чемоданами.
static func baggage_train(carts: int = 3) -> Node3D:
	var p := Node3D.new()
	Rig.box(p, Vector3(0.95, 0.35, 1.5), Vector3(0, 0.45, 0), Color("f2c030"))
	Rig.box(p, Vector3(0.95, 0.55, 0.65), Vector3(0, 0.95, -0.35), Color("f2c030"))
	Rig.box(p, Vector3(0.85, 0.35, 0.03), Vector3(0, 1.0, -0.68), Color(0.5, 0.8, 1.0, 0.8), Vector3.ZERO, 0.3)
	Rig.box(p, Vector3(1.0, 0.05, 0.8), Vector3(0, 1.25, -0.35), Color("2b3345"))
	_wheels(p, [-0.5, 0.5], [-0.55, 0.5], 0.22)
	_beacon(p, Vector3(0, 1.28, -0.35))
	for c in carts:
		var z := 1.3 + c * 1.75
		Rig.box(p, Vector3(0.9, 0.1, 1.55), Vector3(0, 0.38, z), Color("6b7385"))
		Rig.cyl(p, 0.025, 0.025, 0.9, Vector3(0, 0.35, z - 1.15), Color("333b4a"), Vector3(90, 0, 0))
		_wheels(p, [-0.45, 0.45], [z - 0.5, z + 0.5], 0.16)
		for k in 4:
			var b := Rig.item("bag")
			b.position = Vector3((k % 2 - 0.5) * 0.45, 0.43, z - 0.38 + (k / 2) * 0.76)
			b.rotation_degrees.y = randf_range(-12, 12)
			b.scale = Vector3.ONE * 1.5
			p.add_child(b)
	return p

static func fuel_truck() -> Node3D:
	var p := Node3D.new()
	Rig.cyl(p, 0.58, 0.58, 2.5, Vector3(0, 1.0, 0.55), Color("eceff3"), Vector3(90, 0, 0)).material_override.metallic = 0.3
	Rig.cyl(p, 0.59, 0.59, 0.3, Vector3(0, 1.0, 0.1), Color("e63946"), Vector3(90, 0, 0))
	Rig.cyl(p, 0.59, 0.59, 0.3, Vector3(0, 1.0, 1.1), Color("e63946"), Vector3(90, 0, 0))
	Rig.box(p, Vector3(1.0, 0.95, 0.9), Vector3(0, 0.85, -1.15), Color("e63946"))
	Rig.box(p, Vector3(0.9, 0.42, 0.04), Vector3(0, 1.08, -1.62), Color(0.5, 0.8, 1.0, 0.8), Vector3.ZERO, 0.3)
	Rig.box(p, Vector3(1.1, 0.2, 3.7), Vector3(0, 0.3, 0.1), Color("2b3345"))
	Rig.box(p, Vector3(0.9, 0.04, 0.5), Vector3(0, 1.62, 0.5), Color("aab4c3"))
	Rig.cyl(p, 0.12, 0.12, 0.1, Vector3(0, 1.6, 0.9), Color("aab4c3"))
	Rig.label(p, "ТОПЛИВО", Vector3(0.595, 1.05, 0.55), 36, Color("e63946"), false).rotation_degrees.y = 90
	Rig.label(p, "ТОПЛИВО", Vector3(-0.595, 1.05, 0.55), 36, Color("e63946"), false).rotation_degrees.y = -90
	_wheels(p, [-0.52, 0.52], [-1.2, 0.5, 1.4], 0.26)
	_beacon(p, Vector3(0, 1.62, -1.1))
	# шланг и катушка
	Rig.cyl(p, 0.03, 0.03, 1.8, Vector3(0.58, 0.65, 1.0), Color("2b2b2b"), Vector3(90, 0, 0))
	Rig.torus(p, 0.14, 0.2, Vector3(0.62, 0.7, 1.55), Color("2b2b2b"), Vector3(0, 0, 90))
	return p

static func bus() -> Node3D:
	var p := Node3D.new()
	Rig.box(p, Vector3(1.3, 0.9, 3.8), Vector3(0, 0.75, 0), Color("e8ecf1"))
	Rig.box(p, Vector3(1.32, 0.12, 3.82), Vector3(0, 1.28, 0), Color("e63946"))
	Rig.box(p, Vector3(1.32, 0.12, 3.82), Vector3(0, 0.38, 0), Color("e63946"))
	for k in 6:
		for sx in [-1.0, 1.0]:
			Rig.box(p, Vector3(0.03, 0.4, 0.5), Vector3(0.66 * sx, 1.0, -1.45 + k * 0.58), Color(0.35, 0.6, 0.85, 0.9), Vector3.ZERO, 0.3)
	Rig.box(p, Vector3(1.1, 0.5, 0.04), Vector3(0, 1.0, -1.9), Color(0.35, 0.6, 0.85, 0.9), Vector3.ZERO, 0.3)
	_wheels(p, [-0.6, 0.6], [-1.2, 1.2], 0.3)
	Rig.label(p, "ПЕРРОН-ЭКСПРЕСС", Vector3(0.665, 0.75, 0.0), 40, Color("2b3345"), false).rotation_degrees.y = 90
	return p

static func stairs_truck() -> Node3D:
	var p := Node3D.new()
	Rig.box(p, Vector3(1.0, 0.5, 1.8), Vector3(0, 0.55, 0), Color("4a78c2"))
	Rig.box(p, Vector3(1.0, 0.6, 0.6), Vector3(0, 0.95, -0.6), Color("4a78c2"))
	for k in 9:
		Rig.box(p, Vector3(0.8, 0.05, 0.22), Vector3(0, 0.85 + k * 0.16, 0.2 + k * 0.2), Color("c8ced8"))
	Rig.box(p, Vector3(0.9, 0.06, 0.8), Vector3(0, 2.3, 2.1), Color("c8ced8"))
	for sx in [-1.0, 1.0]:
		Rig.box(p, Vector3(0.04, 0.05, 2.4), Vector3(0.43 * sx, 1.9, 1.15), Color("e0b020"), Vector3(-35, 0, 0))
	_wheels(p, [-0.5, 0.5], [-0.6, 0.6], 0.25)
	return p

static func catering_truck() -> Node3D:
	var p := Node3D.new()
	Rig.box(p, Vector3(1.1, 0.35, 3.2), Vector3(0, 0.5, 0), Color("e8ecf1"))
	Rig.box(p, Vector3(1.0, 0.7, 0.9), Vector3(0, 0.95, -1.1), Color("3a6fc4"))
	Rig.box(p, Vector3(1.5, 1.0, 2.0), Vector3(0, 1.8, 0.5), Color("f4f6f9"))
	Rig.box(p, Vector3(1.52, 0.06, 2.02), Vector3(0, 2.32, 0.5), Color("3a6fc4"))
	Rig.label(p, "КЕЙТЕРИНГ", Vector3(0.755, 1.8, 0.5), 40, Color("3a6fc4"), false).rotation_degrees.y = 90
	_wheels(p, [-0.5, 0.5], [-1.1, 0.9, 1.4], 0.25)
	return p

static func gpu_cart() -> Node3D:
	var p := Node3D.new()
	Rig.box(p, Vector3(0.7, 0.6, 1.0), Vector3(0, 0.5, 0), Color("e0b020"))
	Rig.box(p, Vector3(0.5, 0.2, 0.04), Vector3(0, 0.6, -0.52), Color("1b2a52"))
	_wheels(p, [-0.3, 0.3], [-0.3, 0.3], 0.14)
	Rig.cyl(p, 0.025, 0.025, 1.4, Vector3(0.3, 0.2, -0.9), Color("e0b020"), Vector3(90, 0, 0))
	return p

static func pushback_tug() -> Node3D:
	var p := Node3D.new()
	Rig.box(p, Vector3(1.1, 0.4, 2.0), Vector3(0, 0.38, 0), Color("5a6475"))
	Rig.box(p, Vector3(0.9, 0.55, 0.8), Vector3(0, 0.88, -0.2), Color("f2c030"))
	Rig.box(p, Vector3(0.8, 0.3, 0.03), Vector3(0, 0.95, -0.62), Color(0.5, 0.8, 1.0, 0.8), Vector3.ZERO, 0.3)
	_wheels(p, [-0.55, 0.55], [-0.7, 0.7], 0.2)
	_beacon(p, Vector3(0, 1.18, -0.2))
	return p

static func light_mast(h: float = 6.0) -> Node3D:
	var p := Node3D.new()
	Rig.cyl(p, 0.07, 0.13, h, Vector3(0, h / 2.0, 0), Color("8d97a6"))
	Rig.box(p, Vector3(1.0, 0.12, 0.35), Vector3(0, h, 0), Color("333b4a"))
	for k in 4:
		Rig.box(p, Vector3(0.2, 0.1, 0.25), Vector3(-0.38 + k * 0.25, h - 0.08, 0.05), Color("fff6d0"), Vector3(18, 0, 0), 3.0)
	return p

static func windsock() -> Node3D:
	var p := Node3D.new()
	Rig.cyl(p, 0.04, 0.05, 4.0, Vector3(0, 2.0, 0), Color("c8ced8"))
	var arm := Node3D.new()
	arm.position = Vector3(0, 4.0, 0)
	arm.rotation_degrees.y = 25
	p.add_child(arm)
	Rig.torus(arm, 0.28, 0.32, Vector3(0, 0, 0), Color("c8ced8"), Vector3(0, 0, 90))
	for k in 5:
		var r1 := 0.3 - k * 0.04
		Rig.cyl(arm, r1 - 0.04, r1, 0.3, Vector3(0.18 + k * 0.3, -0.03 * k, 0), Color("ff6a2a") if k % 2 == 0 else Color("f4f4f4"), Vector3(0, 0, 90))
	return p

static func taxi_sign(text: String) -> Node3D:
	var p := Node3D.new()
	Rig.box(p, Vector3(0.9, 0.5, 0.06), Vector3(0, 0.65, 0), Color("f2c030"))
	Rig.cyl(p, 0.03, 0.03, 0.4, Vector3(-0.3, 0.2, 0), Color("333b4a"))
	Rig.cyl(p, 0.03, 0.03, 0.4, Vector3(0.3, 0.2, 0), Color("333b4a"))
	var l := Rig.label(p, text, Vector3(0, 0.65, 0.04), 60, Color("111111"), false)
	l.outline_size = 0
	return p

static func fence(length: float) -> Node3D:
	var p := Node3D.new()
	var n := int(length / 1.5)
	for k in n + 1:
		Rig.cyl(p, 0.04, 0.04, 2.0, Vector3(k * 1.5, 1.0, 0), Color("8d97a6"))
	Rig.box(p, Vector3(length, 0.04, 0.04), Vector3(length / 2.0, 1.9, 0), Color("8d97a6"))
	Rig.box(p, Vector3(length, 0.04, 0.04), Vector3(length / 2.0, 0.1, 0), Color("8d97a6"))
	var mesh := Rig.box(p, Vector3(length, 1.8, 0.015), Vector3(length / 2.0, 1.0, 0), Color(0.7, 0.75, 0.8, 0.35))
	return p

# Мини-пассажир за стеклом терминала.
static func passenger(col: Color, skin: Color) -> Node3D:
	var p := Node3D.new()
	Rig.capsule(p, 0.17, 0.9, Vector3(0, 0.55, 0), col)
	Rig.sphere(p, 0.15, Vector3(0, 1.17, 0), skin)
	if randf() < 0.4:
		Rig.sphere(p, 0.16, Vector3(0, 1.22, -0.02), Color("3a2a1a"), Vector3(1.0, 0.6, 1.0))
	if randf() < 0.5:
		var b := Rig.item("bag")
		b.position = Vector3(0.28, 0.0, 0.05)
		b.scale = Vector3.ONE * 2.0
		p.add_child(b)
	return p
