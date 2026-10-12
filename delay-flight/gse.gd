class_name GSE
# Аэродромная техника (единица = 3 м). Нос — в -Z, низ на y=0.
# Каждая модель собирается из скруглённых/детальных частей: колёса с дисками, арки, стёкла, зеркала, фары, мигалки.

static func _mat(col: Color, kind: String) -> StandardMaterial3D:
	var m := Rig.mat(col)
	match kind:
		"paint":
			m.roughness = 0.4
			m.metallic = 0.3
		"metal":
			m.roughness = 0.35
			m.metallic = 0.8
		"rubber":
			m.roughness = 0.97
		"glass":
			m.roughness = 0.06
			m.metallic = 0.85
		"plastic":
			m.roughness = 0.55
	return m

static func B(p: Node3D, size: Vector3, pos: Vector3, col: Color, kind: String = "paint", rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := Rig.box(p, size, pos, col, rot)
	mi.material_override = _mat(col, kind)
	return mi

static func C(p: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, col: Color, kind: String = "paint", rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := Rig.cyl(p, r_top, r_bot, h, pos, col, rot)
	mi.material_override = _mat(col, kind)
	return mi

static func S(p: Node3D, r: float, pos: Vector3, col: Color, squash: Vector3 = Vector3.ONE, kind: String = "paint", emit: float = 0.0) -> MeshInstance3D:
	var mi := Rig.sphere(p, r, pos, col, squash, emit)
	if emit <= 0.0:
		mi.material_override = _mat(col, kind)
	return mi

static func glow(p: Node3D, size: Vector3, pos: Vector3, col: Color, energy: float = 2.5) -> void:
	Rig.box(p, size, pos, col, Vector3.ZERO, energy)

# ---------- детали ----------
static func wheel(p: Node3D, pos: Vector3, r: float, w: float) -> void:
	C(p, r, r, w, pos, Color("131417"), "rubber", Vector3(0, 0, 90))
	for sx in [-1.0, 1.0]:
		Rig.torus(p, r * 0.8, r * 0.98, pos + Vector3(sx * w * 0.26, 0, 0), Color("0c0d0f"), Vector3(0, 0, 90)).scale = Vector3(1.0, 0.45, 1.0)
	C(p, r * 0.6, r * 0.6, w * 1.03, pos, Color("b4bcc7"), "metal", Vector3(0, 0, 90))
	C(p, r * 0.22, r * 0.22, w * 1.07, pos, Color("3a3f48"), "metal", Vector3(0, 0, 90))
	for k in 6:
		var a := TAU * k / 6.0
		S(p, r * 0.045, pos + Vector3(sign(pos.x) * w * 0.52, sin(a) * r * 0.4, cos(a) * r * 0.4), Color("e8ecf2"), Vector3.ONE, "metal")

static func fender(p: Node3D, pos: Vector3, r: float, w: float, col: Color) -> void:
	B(p, Vector3(w + 0.03, 0.025, r * 1.6), pos + Vector3(0, r * 1.12, 0), col)
	B(p, Vector3(w + 0.03, 0.025, r * 0.7), pos + Vector3(0, r * 0.98, -r * 0.95), col, "paint", Vector3(-35, 0, 0))
	B(p, Vector3(w + 0.03, 0.025, r * 0.7), pos + Vector3(0, r * 0.98, r * 0.95), col, "paint", Vector3(35, 0, 0))

static func mirror(p: Node3D, pos: Vector3, side: float) -> void:
	B(p, Vector3(0.1, 0.012, 0.012), pos + Vector3(side * 0.05, 0, 0), Color("22262c"), "metal")
	B(p, Vector3(0.012, 0.11, 0.07), pos + Vector3(side * 0.105, -0.04, 0), Color("1a1d22"), "plastic")

static func beacon(p: Node3D, pos: Vector3, col: Color = Color("ffa820")) -> void:
	C(p, 0.045, 0.05, 0.03, pos, Color("2a2d33"), "plastic")
	S(p, 0.045, pos + Vector3(0, 0.04, 0), col, Vector3(1.0, 0.9, 1.0), "plastic", 2.4)

static func hazard(p: Node3D, pos: Vector3, size: Vector3, along_x: bool = true, n: int = 8) -> void:
	var cell := (size.x if along_x else size.z) / n
	for k in n:
		var o := -((size.x if along_x else size.z) / 2.0) + cell * (k + 0.5)
		var sz := Vector3(cell, size.y, size.z) if along_x else Vector3(size.x, size.y, cell)
		var ps := pos + (Vector3(o, 0, 0) if along_x else Vector3(0, 0, o))
		B(p, sz, ps, Color("f2c230") if k % 2 == 0 else Color("1a1b1e"), "plastic")

static func headlights(p: Node3D, y: float, z: float, half_w: float) -> void:
	for sx in [-1.0, 1.0]:
		S(p, 0.05, Vector3(sx * half_w, y, z), Color("fff6dc"), Vector3(1.3, 0.8, 0.5), "plastic", 2.2)
		B(p, Vector3(0.025, 0.025, 0.02), Vector3(sx * (half_w + 0.07), y, z + 0.01), Color("ffb020"), "plastic")

static func taillights(p: Node3D, y: float, z: float, half_w: float) -> void:
	for sx in [-1.0, 1.0]:
		glow(p, Vector3(0.06, 0.04, 0.02), Vector3(sx * half_w, y, z), Color("ff2a1a"), 1.8)

static func sticker(p: Node3D, text: String, pos: Vector3, side: float, size: float, col: Color) -> void:
	var l := Rig.label(p, text, pos, 40, col, false)
	l.pixel_size = size
	l.outline_size = 0
	l.rotation_degrees.y = 90.0 * side

static func ladder(p: Node3D, pos: Vector3, h: float, w: float = 0.18, rungs: int = 6) -> void:
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.015, h, 0.015), pos + Vector3(sx * w / 2.0, h / 2.0, 0), Color("c8ced8"), "metal")
	for k in rungs:
		B(p, Vector3(w, 0.012, 0.012), pos + Vector3(0, 0.06 + k * (h - 0.1) / (rungs - 1), 0.0), Color("c8ced8"), "metal")

# ---------- техника ----------
static func fuel_truck() -> Node3D:
	var p := Node3D.new()
	var red := Color("c4271f")
	var white := Color("eef1f5")
	B(p, Vector3(0.62, 0.1, 3.3), Vector3(0, 0.36, 0), Color("1d2025"), "metal")
	# кабина «капотная без капота»: низ красный, верх белый
	B(p, Vector3(0.86, 0.36, 0.74), Vector3(0, 0.6, -1.22), red)
	B(p, Vector3(0.82, 0.42, 0.62), Vector3(0, 1.0, -1.18), white)
	B(p, Vector3(0.84, 0.04, 0.66), Vector3(0, 1.22, -1.18), Color("c9ced6"))
	B(p, Vector3(0.74, 0.3, 0.025), Vector3(0, 1.0, -1.5), Color("27425c"), "glass", Vector3(-10, 0, 0))
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.025, 0.26, 0.4), Vector3(sx * 0.415, 1.0, -1.2), Color("27425c"), "glass")
		B(p, Vector3(0.012, 0.4, 0.012), Vector3(sx * 0.42, 0.78, -1.03), Color("2a2d33"), "plastic")
		B(p, Vector3(0.012, 0.012, 0.18), Vector3(sx * 0.42, 0.9, -1.12), Color("2a2d33"), "plastic")
		B(p, Vector3(0.1, 0.03, 0.2), Vector3(sx * 0.46, 0.4, -1.2), Color("2a2d33"), "plastic")
		mirror(p, Vector3(sx * 0.42, 1.1, -1.5), sx)
	# решётка и бампер
	B(p, Vector3(0.66, 0.2, 0.02), Vector3(0, 0.62, -1.595), Color("1b1d21"), "plastic")
	for k in 4:
		B(p, Vector3(0.6, 0.014, 0.025), Vector3(0, 0.55 + k * 0.045, -1.6), Color("8d96a3"), "metal")
	B(p, Vector3(0.9, 0.1, 0.1), Vector3(0, 0.3, -1.62), Color("2a2d33"), "metal")
	headlights(p, 0.74, -1.6, 0.3)
	beacon(p, Vector3(0, 1.26, -1.1))
	# цистерна
	var tank := C(p, 0.37, 0.37, 1.95, Vector3(0, 1.0, 0.42), white, "metal", Vector3(90, 0, 0))
	for z in [-0.58, 1.42]:
		S(p, 0.37, Vector3(0, 1.0, z), white, Vector3(1.0, 1.0, 0.45), "metal")
	for z in [-0.1, 0.78]:
		C(p, 0.375, 0.375, 0.2, Vector3(0, 1.0, z), red, "paint", Vector3(90, 0, 0))
	B(p, Vector3(0.7, 0.08, 1.9), Vector3(0, 0.55, 0.42), Color("2a2d33"), "metal")
	# площадка с перилами и люки
	B(p, Vector3(0.44, 0.025, 1.7), Vector3(0, 1.4, 0.42), Color("8d96a3"), "metal")
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.012, 0.012, 1.7), Vector3(sx * 0.22, 1.5, 0.42), Color("e0b020"), "metal")
		for z in [-0.35, 0.1, 0.55, 1.0, 1.2]:
			B(p, Vector3(0.012, 0.1, 0.012), Vector3(sx * 0.22, 1.45, z), Color("e0b020"), "metal")
	for z in [-0.1, 0.45, 1.0]:
		C(p, 0.085, 0.095, 0.07, Vector3(0, 1.42, z), Color("aab2bd"), "metal")
		C(p, 0.03, 0.03, 0.03, Vector3(0, 1.47, z), Color("2a2d33"), "plastic")
	# боковые отсеки, шланг, катушка, рукава
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.12, 0.3, 1.1), Vector3(sx * 0.4, 0.58, 0.45), Color("9aa3af"), "paint")
		for k in 3:
			B(p, Vector3(0.005, 0.26, 0.006), Vector3(sx * 0.462, 0.58, 0.1 + k * 0.35), Color("5f6772"), "plastic")
		sticker(p, "ТОПЛИВО", Vector3(sx * 0.372, 1.04, 0.42), sx, 0.0042, Color("c4271f"))
		sticker(p, "ТС-1", Vector3(sx * 0.372, 0.86, 0.42), sx, 0.0028, Color("2b3345"))
	Rig.torus(p, 0.06, 0.12, Vector3(0.38, 0.8, 1.3), Color("26282c"), Vector3(0, 0, 90)).scale = Vector3(1.0, 0.7, 1.0)
	C(p, 0.025, 0.025, 0.75, Vector3(-0.34, 0.48, 1.55), Color("1d1d20"), "rubber", Vector3(90, 0, 0))
	# задний коллектор с вентилями
	B(p, Vector3(0.5, 0.2, 0.1), Vector3(0, 0.62, 1.66), Color("3a3f48"), "metal")
	for sx in [-0.17, 0.0, 0.17]:
		C(p, 0.03, 0.03, 0.12, Vector3(sx, 0.72, 1.7), Color("c4271f") if sx == 0.0 else Color("1d2025"), "metal")
		C(p, 0.06, 0.06, 0.012, Vector3(sx, 0.62, 1.74), Color("e0b020"), "metal", Vector3(90, 0, 0))
	ladder(p, Vector3(-0.28, 0.4, 1.7), 1.0, 0.2, 6)
	hazard(p, Vector3(0, 0.44, 1.7), Vector3(0.86, 0.06, 0.04), true, 10)
	taillights(p, 0.5, 1.7, 0.36)
	# ромб опасности «ТС-1»
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.012, 0.12, 0.12), Vector3(sx * 0.372, 0.68, 1.1), Color("ff7a1a"), "plastic", Vector3(45, 0, 0))
	# колёса и арки
	for z in [-1.18, 0.62, 1.12]:
		for sx in [-1.0, 1.0]:
			wheel(p, Vector3(sx * 0.4, 0.2, z), 0.2, 0.15)
		fender(p, Vector3(0, 0.2, z), 0.2, 0.9, Color("2a2d33"))
	return p

static func baggage_tug() -> Node3D:
	var p := Node3D.new()
	var yel := Color("f0b61c")
	B(p, Vector3(0.5, 0.1, 1.0), Vector3(0, 0.24, 0), Color("23262b"), "metal")
	B(p, Vector3(0.48, 0.22, 0.46), Vector3(0, 0.4, -0.3), yel)
	B(p, Vector3(0.5, 0.025, 0.5), Vector3(0, 0.52, -0.3), Color("23262b"), "plastic")
	S(p, 0.05, Vector3(0, 0.47, -0.55), Color("fff2cc"), Vector3(1.8, 0.8, 0.5), "plastic", 1.8)
	B(p, Vector3(0.46, 0.2, 0.34), Vector3(0, 0.38, 0.28), yel)
	# кабина-каркас, сиденье, руль, крыша
	for sx in [-1.0, 1.0]:
		for z in [-0.08, 0.4]:
			B(p, Vector3(0.02, 0.5, 0.02), Vector3(sx * 0.22, 0.75, z), Color("2a2d33"), "metal")
	B(p, Vector3(0.52, 0.025, 0.56), Vector3(0, 1.0, 0.16), yel)
	B(p, Vector3(0.34, 0.07, 0.26), Vector3(0, 0.58, 0.22), Color("1d2026"), "plastic")
	B(p, Vector3(0.34, 0.2, 0.05), Vector3(0, 0.7, 0.36), Color("1d2026"), "plastic")
	Rig.torus(p, 0.04, 0.055, Vector3(0, 0.72, -0.08), Color("1d2026"), Vector3(70, 0, 0))
	B(p, Vector3(0.16, 0.014, 0.1), Vector3(0, 0.6, -0.1), Color("2a2d33"), "plastic")
	beacon(p, Vector3(0, 1.03, 0.16))
	B(p, Vector3(0.06, 0.06, 0.1), Vector3(0, 0.26, 0.55), Color("9aa3af"), "metal")    # сцепное
	taillights(p, 0.36, 0.46, 0.2)
	for sx in [-1.0, 1.0]:
		wheel(p, Vector3(sx * 0.27, 0.13, -0.34), 0.13, 0.1)
		wheel(p, Vector3(sx * 0.27, 0.13, 0.32), 0.13, 0.1)
	sticker(p, "ЭЛЕКТРО", Vector3(0.245, 0.42, 0.28), 1.0, 0.0022, Color("1b2a52"))
	return p

static func baggage_cart() -> Node3D:
	var p := Node3D.new()
	B(p, Vector3(0.5, 0.06, 1.1), Vector3(0, 0.17, 0), Color("2a2f38"), "metal")
	B(p, Vector3(0.62, 0.035, 1.2), Vector3(0, 0.23, 0), Color("98a1ad"), "metal")
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.02, 0.1, 1.2), Vector3(sx * 0.31, 0.28, 0), Color("c8ced8"), "metal")
		for z in [-0.58, 0.0, 0.58]:
			B(p, Vector3(0.02, 0.5, 0.02), Vector3(sx * 0.3, 0.5, z), Color("c8ced8"), "metal")
	B(p, Vector3(0.62, 0.015, 0.02), Vector3(0, 0.75, -0.58), Color("c8ced8"), "metal")
	B(p, Vector3(0.62, 0.015, 0.02), Vector3(0, 0.75, 0.58), Color("c8ced8"), "metal")
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.015, 0.015, 1.18), Vector3(sx * 0.3, 0.75, 0), Color("c8ced8"), "metal")
		# полосатый подкат
	# дышло
	B(p, Vector3(0.025, 0.025, 0.55), Vector3(-0.1, 0.17, -0.88), Color("1d2025"), "metal", Vector3(0, 10, 0))
	B(p, Vector3(0.025, 0.025, 0.55), Vector3(0.1, 0.17, -0.88), Color("1d2025"), "metal", Vector3(0, -10, 0))
	for sx in [-1.0, 1.0]:
		wheel(p, Vector3(sx * 0.25, 0.08, -0.4), 0.08, 0.07)
		wheel(p, Vector3(sx * 0.25, 0.08, 0.4), 0.08, 0.07)
	# чемоданы
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := [Color("b5651d"), Color("2b4a7a"), Color("7a1f2b"), Color("2f2f33"), Color("4a7a3a"), Color("c8a64a")]
	for k in 8:
		var b := Rig.item("bag")
		b.scale = Vector3.ONE * 0.55
		b.position = Vector3(rng.randf_range(-0.2, 0.2), 0.245 + (0.14 if k >= 5 else 0.0), -0.4 + (k % 5) * 0.2)
		b.rotation_degrees.y = rng.randf_range(-20, 20)
		p.add_child(b)
	return p

static func baggage_train(carts: int = 3) -> Node3D:
	var p := Node3D.new()
	p.add_child(baggage_tug())
	for k in carts:
		var c := baggage_cart()
		c.position = Vector3(0, 0, 1.4 + k * 1.3)
		p.add_child(c)
	return p

# Ленточный погрузчик: подъёмный конвейер к багажному люку (нос конвейера смотрит в -Z).
static func belt_loader() -> Node3D:
	var p := Node3D.new()
	var wht := Color("e9edf1")
	var org := Color("f08a1c")
	B(p, Vector3(0.62, 0.12, 1.5), Vector3(0, 0.3, 0.3), Color("23262b"), "metal")
	B(p, Vector3(0.58, 0.34, 0.44), Vector3(0.0, 0.56, 0.78), org)
	B(p, Vector3(0.52, 0.05, 0.4), Vector3(0, 0.77, 0.78), Color("c9ced6"))
	B(p, Vector3(0.48, 0.22, 0.02), Vector3(0, 0.6, 0.55), Color("27425c"), "glass")
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.02, 0.2, 0.3), Vector3(sx * 0.29, 0.6, 0.78), Color("27425c"), "glass")
	headlights(p, 0.46, 1.01, 0.2)
	beacon(p, Vector3(0.18, 0.82, 0.78))
	# конвейер: от основания к носу, с подъёмом
	var base := Vector3(0, 0.62, 0.35)
	var tip := Vector3(0, 1.15, -1.9)
	var d := tip - base
	var len := d.length()
	var mid := (base + tip) / 2.0
	var pitch := rad_to_deg(atan2(d.y, -d.z))
	var holder := Node3D.new()
	holder.position = mid
	holder.rotation_degrees = Vector3(pitch, 0, 0)
	p.add_child(holder)
	B(holder, Vector3(0.5, 0.05, len), Vector3(0, 0, 0), Color("1d1f23"), "rubber")
	for sx in [-1.0, 1.0]:
		B(holder, Vector3(0.035, 0.12, len), Vector3(sx * 0.27, 0.05, 0), org)
		B(holder, Vector3(0.03, 0.05, len), Vector3(sx * 0.27, 0.12, 0), Color("c9ced6"), "metal")
	for k in 22:
		B(holder, Vector3(0.46, 0.012, 0.025), Vector3(0, 0.03, -len / 2.0 + 0.06 + k * (len - 0.1) / 21.0), Color("3c4048"), "rubber")
	B(holder, Vector3(0.56, 0.1, 0.05), Vector3(0, 0.0, -len / 2.0), Color("24262a"), "rubber")
	# подъёмные стойки и распорка
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.04, 0.5, 0.04), Vector3(sx * 0.27, 0.58, -0.7), Color("c9ced6"), "metal", Vector3(18, 0, 0))
		B(p, Vector3(0.04, 0.04, 0.9), Vector3(sx * 0.28, 0.5, -0.1), Color("23262b"), "metal", Vector3(-15, 0, 0))
	hazard(p, Vector3(0, 0.38, -0.4), Vector3(0.6, 0.06, 0.05), true, 8)
	for z in [0.78, -0.2]:
		for sx in [-1.0, 1.0]:
			wheel(p, Vector3(sx * 0.33, 0.17, z), 0.17, 0.12)
	sticker(p, "БАГАЖ", Vector3(0.3, 0.55, 0.78), 1.0, 0.0025, Color("1b2a52"))
	return p

static func pushback_tug() -> Node3D:
	var p := Node3D.new()
	B(p, Vector3(0.9, 0.3, 1.55), Vector3(0, 0.34, 0), Color("f0b61c"))
	B(p, Vector3(0.7, 0.36, 0.7), Vector3(0, 0.67, 0.22), Color("f0b61c"))
	B(p, Vector3(0.64, 0.2, 0.02), Vector3(0, 0.7, -0.14), Color("27425c"), "glass")
	B(p, Vector3(0.72, 0.03, 0.72), Vector3(0, 0.87, 0.22), Color("2a2d33"))
	B(p, Vector3(0.92, 0.12, 0.2), Vector3(0, 0.22, -0.82), Color("23262b"), "metal")
	B(p, Vector3(0.06, 0.06, 1.7), Vector3(0, 0.22, -1.65), Color("2a2d33"), "metal")     # водило
	B(p, Vector3(0.22, 0.08, 0.1), Vector3(0, 0.22, -2.5), Color("c4271f"), "metal")
	hazard(p, Vector3(0, 0.3, -0.84), Vector3(0.9, 0.06, 0.03), true, 8)
	headlights(p, 0.42, -0.79, 0.34)
	beacon(p, Vector3(0, 0.92, 0.22))
	for sx in [-1.0, 1.0]:
		wheel(p, Vector3(sx * 0.48, 0.2, -0.45), 0.2, 0.2)
		wheel(p, Vector3(sx * 0.48, 0.2, 0.5), 0.2, 0.2)
	return p

static func gpu_cart() -> Node3D:
	var p := Node3D.new()
	B(p, Vector3(0.42, 0.4, 0.8), Vector3(0, 0.38, 0), Color("f0b61c"))
	for k in 5:
		B(p, Vector3(0.43, 0.012, 0.03), Vector3(0, 0.3 + k * 0.05, -0.2), Color("3a3f48"), "plastic")
	B(p, Vector3(0.38, 0.02, 0.5), Vector3(0, 0.6, 0.1), Color("23262b"), "plastic")
	B(p, Vector3(0.02, 0.28, 0.02), Vector3(0.18, 0.56, 0.42), Color("2a2d33"), "metal")
	B(p, Vector3(0.38, 0.015, 0.02), Vector3(0, 0.7, 0.42), Color("2a2d33"), "metal")
	Rig.torus(p, 0.07, 0.11, Vector3(-0.23, 0.45, 0.1), Color("1b1b1d"), Vector3(0, 0, 90))
	for sx in [-1.0, 1.0]:
		wheel(p, Vector3(sx * 0.23, 0.1, 0.25), 0.1, 0.07)
	B(p, Vector3(0.04, 0.04, 0.3), Vector3(0, 0.18, -0.55), Color("23262b"), "metal")
	sticker(p, "28V · 400Hz", Vector3(0.215, 0.5, 0.0), 1.0, 0.0018, Color("1b2a52"))
	return p

static func stairs_truck() -> Node3D:
	var p := Node3D.new()
	var blue := Color("2c63b8")
	B(p, Vector3(0.82, 0.1, 2.2), Vector3(0, 0.3, 0), Color("23262b"), "metal")
	B(p, Vector3(0.82, 0.4, 0.62), Vector3(0, 0.56, -0.82), blue)
	B(p, Vector3(0.78, 0.36, 0.5), Vector3(0, 0.94, -0.78), Color("e9edf1"))
	B(p, Vector3(0.7, 0.26, 0.02), Vector3(0, 0.96, -1.04), Color("27425c"), "glass", Vector3(-8, 0, 0))
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.02, 0.22, 0.34), Vector3(sx * 0.4, 0.96, -0.8), Color("27425c"), "glass")
	headlights(p, 0.6, -1.14, 0.3)
	beacon(p, Vector3(0, 1.15, -0.78))
	# лестница: ступени с подъёмом к верхней площадке, перила
	var steps := 11
	for k in steps:
		var z := 0.95 - k * 0.14
		var y := 0.38 + k * 0.09
		B(p, Vector3(0.62, 0.02, 0.15), Vector3(0, y, z + 0.45), Color("8d96a3"), "metal")
		B(p, Vector3(0.62, 0.07, 0.012), Vector3(0, y - 0.04, z + 0.53), Color("5d6572"), "plastic")
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.03, 0.04, 1.75), Vector3(sx * 0.33, 0.73, 0.04), blue, "paint", Vector3(30, 0, 0))
		B(p, Vector3(0.015, 0.015, 1.75), Vector3(sx * 0.33, 1.17, 0.04), Color("e0b020"), "metal", Vector3(30, 0, 0))
	B(p, Vector3(0.75, 0.03, 0.55), Vector3(0, 1.4, -0.55), Color("8d96a3"), "metal")
	B(p, Vector3(0.78, 0.03, 0.04), Vector3(0, 1.62, -0.8), Color("e0b020"), "metal")
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.02, 0.22, 0.55), Vector3(sx * 0.37, 1.5, -0.55), Color("e0b020"), "plastic")
	B(p, Vector3(0.5, 0.03, 0.2), Vector3(0, 1.52, -0.9), Color("1d1f23"), "rubber")
	for sx in [-1.0, 1.0]:
		wheel(p, Vector3(sx * 0.43, 0.19, -0.85), 0.19, 0.15)
		wheel(p, Vector3(sx * 0.43, 0.19, 0.6), 0.19, 0.15)
	return p

static func catering_truck() -> Node3D:
	var p := Node3D.new()
	var wht := Color("eef1f5")
	B(p, Vector3(0.8, 0.1, 3.0), Vector3(0, 0.3, 0), Color("23262b"), "metal")
	B(p, Vector3(0.84, 0.4, 0.64), Vector3(0, 0.56, -1.18), Color("2c7a6a"))
	B(p, Vector3(0.8, 0.38, 0.5), Vector3(0, 0.94, -1.14), wht)
	B(p, Vector3(0.72, 0.26, 0.02), Vector3(0, 0.96, -1.4), Color("27425c"), "glass")
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.02, 0.22, 0.34), Vector3(sx * 0.4, 0.96, -1.16), Color("27425c"), "glass")
	headlights(p, 0.6, -1.5, 0.3)
	beacon(p, Vector3(0, 1.15, -1.14))
	# кузов-«ножницы»
	B(p, Vector3(0.92, 0.72, 1.7), Vector3(0, 0.82, 0.5), wht)
	B(p, Vector3(0.94, 0.14, 1.72), Vector3(0, 0.9, 0.5), Color("2c7a6a"))
	B(p, Vector3(0.96, 0.025, 1.74), Vector3(0, 1.2, 0.5), Color("c9ced6"))
	for sx in [-1.0, 1.0]:
		B(p, Vector3(0.025, 0.55, 0.16), Vector3(sx * 0.46, 0.8, 0.5), Color("aab2bd"), "metal")
		B(p, Vector3(0.04, 0.04, 1.2), Vector3(sx * 0.4, 0.38, 0.5), Color("3a3f48"), "metal", Vector3(0, 0, 0))
		B(p, Vector3(0.025, 0.02, 0.5), Vector3(sx * 0.48, 0.62, 1.1), Color("3a3f48"), "metal", Vector3(0, 0, 30))
		B(p, Vector3(0.025, 0.02, 0.5), Vector3(sx * 0.48, 0.62, 1.1), Color("3a3f48"), "metal", Vector3(0, 0, -30))
	for z in [0.0, 0.5, 1.0]:
		for sx in [-1.0, 1.0]:
			wheel(p, Vector3(sx * 0.43, 0.2, z * 1.4 - 0.2), 0.2, 0.15)
	sticker(p, "КЕЙТЕРИНГ", Vector3(0.472, 0.85, 0.5), 1.0, 0.0034, Color("2c7a6a"))
	return p

static func bus() -> Node3D:
	var p := Node3D.new()
	var wht := Color("e8ecf1")
	B(p, Vector3(0.88, 0.8, 4.0), Vector3(0, 0.72, 0), wht)
	B(p, Vector3(0.9, 0.12, 4.02), Vector3(0, 0.38, 0), Color("c4271f"))
	B(p, Vector3(0.9, 0.06, 4.02), Vector3(0, 1.1, 0), Color("c4271f"))
	B(p, Vector3(0.84, 0.05, 3.9), Vector3(0, 1.14, 0), Color("c9ced6"))
	for sx in [-1.0, 1.0]:
		for k in 7:
			B(p, Vector3(0.012, 0.34, 0.42), Vector3(sx * 0.445, 0.86, -1.5 + k * 0.5), Color("27425c"), "glass")
		for z in [-1.2, 0.8]:
			B(p, Vector3(0.012, 0.7, 0.3), Vector3(sx * 0.446, 0.7, z), Color("27425c"), "glass")
	B(p, Vector3(0.78, 0.4, 0.02), Vector3(0, 0.88, -2.01), Color("27425c"), "glass")
	B(p, Vector3(0.4, 0.06, 0.012), Vector3(0, 1.06, -2.015), Color("ffb020"), "plastic")
	headlights(p, 0.52, -2.01, 0.34)
	taillights(p, 0.52, 2.01, 0.34)
	for x in [-0.2, 0.2]:
		B(p, Vector3(0.22, 0.08, 0.5), Vector3(x, 1.2, 0.4), Color("aab2bd"), "metal")
	for sx in [-1.0, 1.0]:
		mirror(p, Vector3(sx * 0.44, 0.92, -1.9), sx)
		sticker(p, "ПЕРРОН", Vector3(sx * 0.452, 0.56, 0.0), sx, 0.0036, Color("c4271f"))
		for z in [-1.4, 1.2, 1.6]:
			wheel(p, Vector3(sx * 0.4, 0.21, z), 0.21, 0.17)
	for z in [-1.4, 1.2, 1.6]:
		fender(p, Vector3(0, 0.21, z), 0.21, 0.92, Color("2a2d33"))
	return p

# Контейнер ULD (LD3) со скошенным углом.
static func uld() -> Node3D:
	var p := Node3D.new()
	var col := Color("aab3c0")
	B(p, Vector3(0.62, 0.55, 0.5), Vector3(0, 0.35, 0), col, "metal")
	B(p, Vector3(0.62, 0.18, 0.2), Vector3(0, 0.55, 0.15), col, "metal", Vector3(0, 0, 0))
	B(p, Vector3(0.64, 0.04, 0.54), Vector3(0, 0.07, 0), Color("3a3f48"), "metal")
	for k in 5:
		B(p, Vector3(0.012, 0.5, 0.52), Vector3(-0.28 + k * 0.14, 0.35, 0), Color("8d96a3"), "metal")
	B(p, Vector3(0.2, 0.03, 0.01), Vector3(0, 0.45, -0.255), Color("c4271f"), "plastic")
	return p

static func cone() -> Node3D:
	var p := Node3D.new()
	B(p, Vector3(0.2, 0.015, 0.2), Vector3(0, 0.008, 0), Color("1d2025"), "rubber")
	C(p, 0.015, 0.075, 0.28, Vector3(0, 0.15, 0), Color("ff6a22"), "plastic")
	C(p, 0.045, 0.058, 0.05, Vector3(0, 0.16, 0), Color("f4f4f4"), "plastic")
	C(p, 0.03, 0.04, 0.035, Vector3(0, 0.22, 0), Color("f4f4f4"), "plastic")
	return p
