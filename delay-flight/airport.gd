class_name Airport
extends Node3D
# Декорации в 3D: терминал, вышка, перрон, багажный зал, киоски, рулёжка.

const K := Cfg.K

func _ready() -> void:
	_ground()
	_terminal()
	_tower()
	_hall()
	_kiosk(Cfg.COFFEE, "КОФЕ", Color("7a5230"), "coffee")
	_kiosk(Cfg.BURGER, "БУРГЕРЫ", Color("a13a2a"), "burger")
	for i in 3:
		_stand(i, float(Cfg.ROWS[i]))
	_taxiway()

func _p(x: float, y: float, h: float = 0.0) -> Vector3:
	return Vector3(x * K, h, y * K)

func _grid_texture() -> ImageTexture:
	var img := Image.create(128, 128, true, Image.FORMAT_RGB8)
	img.fill(Color("3d4452"))
	for i in 128:
		for t in 3:
			img.set_pixel(i, t, Color("3a4150"))
			img.set_pixel(t, i, Color("3a4150"))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _ground() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 40)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = _grid_texture()
	m.uv1_scale = Vector3(60.0 / 2.4, 40.0 / 2.4, 1.0)
	m.roughness = 0.95
	mi.material_override = m
	mi.position = Vector3(12.8, 0, 7.2)
	add_child(mi)

func _terminal() -> void:
	Rig.box(self, Vector3(27, 2.8, 3.2), Vector3(12.8, 1.4, 0.4), Color("c8d0db"))
	Rig.box(self, Vector3(27.4, 0.2, 3.6), Vector3(12.8, 2.9, 0.4), Color("5d6a7e"))
	Rig.box(self, Vector3(27, 0.35, 3.3), Vector3(12.8, 0.17, 0.42), Color("8d98a8"))
	for i in 21:
		var x := 0.6 + i * 1.22
		Rig.box(self, Vector3(0.9, 1.0, 0.06), Vector3(x, 1.5, 2.02), Color("2f5d8a"), Vector3.ZERO, 0.25)
		Rig.box(self, Vector3(0.9, 0.35, 0.065), Vector3(x, 1.95, 2.03), Color("5aa9ff"), Vector3.ZERO, 0.3)
	Rig.box(self, Vector3(6.4, 0.55, 0.2), Vector3(12.8, 2.45, 2.1), Color("1b2a52"))
	Rig.label(self, "ВЫЛЕТ · DEPARTURES", Vector3(12.8, 2.45, 2.25), 40, Color("ffd24d"), false)
	for x in [9.0, 16.6]:
		Rig.box(self, Vector3(1.4, 1.2, 0.08), Vector3(x, 0.7, 2.03), Color("1d3a5c"))

func _tower() -> void:
	var x := 1010.0 * K
	Rig.cyl(self, 0.38, 0.45, 4.6, Vector3(x, 2.3, 0.6), Color("aab4c3"))
	Rig.cyl(self, 1.1, 0.8, 0.9, Vector3(x, 4.9, 0.6), Color("5d6a7e"))
	Rig.cyl(self, 1.02, 1.02, 0.5, Vector3(x, 5.05, 0.6), Color(0.5, 0.82, 1.0, 0.8), Vector3.ZERO, 0.3)
	Rig.cyl(self, 1.25, 1.25, 0.14, Vector3(x, 5.5, 0.6), Color("333b4a"))
	Rig.cyl(self, 0.03, 0.03, 0.9, Vector3(x, 6.0, 0.6), Color("333b4a"))
	Rig.sphere(self, 0.09, Vector3(x, 6.5, 0.6), Color("ff2d2d"), Vector3.ONE, 3.0)

func _hall() -> void:
	var r := Cfg.BELT
	Rig.box(self, Vector3(3.5, 0.08, 12.4), Vector3(1.75, 0.04, 7.9), Color("9aa6b6"))
	Rig.box(self, Vector3(0.3, 1.6, 12.4), Vector3(0.15, 0.8, 7.9), Color("7d8a9d"))
	Rig.box(self, Vector3(3.5, 0.5, 0.2), Vector3(1.75, 0.25, 2.0), Color("6b7789"))
	Rig.box(self, Vector3(3.5, 0.5, 0.2), Vector3(1.75, 0.25, 13.8), Color("6b7789"))
	for i in 5:
		Rig.box(self, Vector3(0.1, 0.9, 0.9), Vector3(0.33, 1.2, 3.0 + i * 2.3), Color("2f5d8a"), Vector3.ZERO, 0.25)
	var c := r.get_center() * K
	Rig.box(self, Vector3(r.size.x * K + 0.3, 0.3, r.size.y * K + 0.3), Vector3(c.x, 0.15, c.y), Color("1d222d"))
	Rig.box(self, Vector3(r.size.x * K, 0.06, r.size.y * K), Vector3(c.x, 0.32, c.y), Color("3a4254"))
	for k in 12:
		Rig.box(self, Vector3(r.size.x * K - 0.1, 0.02, 0.05), Vector3(c.x, 0.36, r.position.y * K + 0.2 + k * 0.4), Color("5a6478"))
	Rig.box(self, Vector3(2.7, 0.5, 0.12), Vector3(c.x, 1.3, r.position.y * K - 0.9), Color("1b2a52"))
	Rig.box(self, Vector3(0.08, 1.1, 0.08), Vector3(c.x - 1.2, 0.55, r.position.y * K - 0.9), Color("333b4a"))
	Rig.box(self, Vector3(0.08, 1.1, 0.08), Vector3(c.x + 1.2, 0.55, r.position.y * K - 0.9), Color("333b4a"))
	Rig.label(self, "БАГАЖ", Vector3(c.x, 1.3, r.position.y * K - 0.82), 44, Color("ffd24d"), false)

func _kiosk(p: Vector2, title: String, roof: Color, icon: String) -> void:
	var c := p * K
	Rig.box(self, Vector3(2.6, 1.3, 1.3), Vector3(c.x, 0.65, c.y), Color("e8d2a8"))
	Rig.box(self, Vector3(2.0, 0.55, 0.06), Vector3(c.x, 0.8, c.y + 0.66), Color("5d4a3a"))
	Rig.box(self, Vector3(2.7, 0.08, 0.5), Vector3(c.x, 1.0, c.y + 0.78), Color("c8a77a"))
	for k in 8:
		var col := roof if k % 2 == 0 else Color("f4f4f4")
		Rig.box(self, Vector3(0.34, 0.07, 1.1), Vector3(c.x - 1.2 + k * 0.34, 1.52, c.y + 0.55), col, Vector3(18, 0, 0))
	Rig.box(self, Vector3(2.7, 0.08, 1.4), Vector3(c.x, 1.34, c.y), Color("6b4e32"))
	Rig.label(self, title, Vector3(c.x, 1.1, c.y + 0.95), 34, Color("ffffff"), false)
	var it := Rig.item(icon)
	it.position = Vector3(c.x, 1.4, c.y)
	it.scale = Vector3.ONE * 3.0
	add_child(it)

func _stand(i: int, y: float) -> void:
	var z := y * K
	Rig.box(self, Vector3(16.0, 0.02, 0.1), Vector3(14.6, 0.01, z), Color("f2c744"))
	Rig.box(self, Vector3(0.12, 0.02, 1.9), Vector3((Cfg.PX - 188.0) * K, 0.012, z), Color("e6ebf2"))
	for k in range(0, 46, 2):
		var x := (Cfg.PX - 200.0 + k * 10.0) * K
		for dz in [-2.12, 2.12]:
			Rig.box(self, Vector3(0.22, 0.02, 0.07), Vector3(x, 0.011, z + dz), Color("c0392b"))
	var num := Rig.label(self, "A%d" % (i + 1), Vector3(9.4, 0.03, z - 0.8), 120, Color(0.9, 0.93, 0.97, 0.85), false)
	num.rotation_degrees = Vector3(-90, 0, 0)
	num.outline_size = 0
	for p in [Vector2(Cfg.PX - 130.0, y), Vector2(Cfg.PX + 80.0, y)]:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.66
		tm.outer_radius = 0.76
		ring.mesh = tm
		var col := Color("ffd24d") if p.x < Cfg.PX else Color("ff9f43")
		ring.material_override = Rig.mat(col, 0.9, 0.8)
		ring.position = Vector3(p.x * K, 0.02, p.y * K)
		ring.scale = Vector3(1, 0.05, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	Rig.cyl(self, 0.22, 0.22, 0.03, Vector3((Cfg.PX + 80.0) * K, 0.02, z), Color("2b3345"))
	Rig.cyl(self, 0.14, 0.14, 0.04, Vector3((Cfg.PX + 80.0) * K, 0.03, z), Color("ffb347"))
	for off in [Vector2(-3.9, -2.0), Vector2(-3.9, 2.0), Vector2(3.8, -2.0), Vector2(3.8, 2.0)]:
		var c := Vector3(Cfg.PX * K + off.x, 0, z + off.y)
		Rig.cyl(self, 0.03, 0.2, 0.5, c + Vector3(0, 0.25, 0), Color("ff6a2a"))
		Rig.cyl(self, 0.1, 0.12, 0.08, c + Vector3(0, 0.3, 0), Color("f4f4f4"))
		Rig.box(self, Vector3(0.5, 0.03, 0.5), c + Vector3(0, 0.015, 0), Color("2b3345"))

func _taxiway() -> void:
	Rig.box(self, Vector3(3.1, 0.03, 14.5), Vector3(24.1, 0.015, 7.7), Color("3a4150"))
	Rig.box(self, Vector3(0.12, 0.035, 14.5), Vector3(24.1, 0.02, 7.7), Color("f2c744"))
	for i in 16:
		for x in [22.65, 25.55]:
			Rig.sphere(self, 0.07, Vector3(x, 0.07, 1.6 + i * 0.85), Color("5aa9ff"), Vector3.ONE, 3.0)
