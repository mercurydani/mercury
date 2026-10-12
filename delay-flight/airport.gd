class_name Airport
extends Node3D
# АЭРОПОРТ: терминал с телетрапами, перрон, рулёжка, взлётная полоса, вышка, окрестности.
# Логика стоянок — в Cfg. Здесь только декорации и декоративные самолёты на полосе.

const RUNWAY_Z := 23.5

var flybys: Array = []
var fly_t := 3.0

func _ready() -> void:
	_ground()
	_terminal()
	_tower()
	_bridges()
	_belt()
	_kiosk(Cfg.COFFEE, "КОФЕ", Color("7a5230"), "coffee")
	_kiosk(Cfg.BURGER, "БУРГЕРЫ", Color("a13a2a"), "burger")
	for i in 3:
		_stand(i)
	_taxiway_and_runway()
	_scenery()

func _tex(base: Color, line: Color, size: int = 128, w: int = 3) -> ImageTexture:
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	img.fill(base)
	for i in size:
		for t in w:
			img.set_pixel(i, t, line)
			img.set_pixel(t, i, line)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _plane(size: Vector2, center: Vector3, mat: StandardMaterial3D) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _surface(base: Color, line: Color, tile: float, size: Vector2, rough: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(base, line)
	m.uv1_scale = Vector3(size.x / tile, size.y / tile, 1.0)
	m.roughness = rough
	return m

func _flat(col: Color, rough: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

func _ground() -> void:
	_plane(Vector2(260, 260), Vector3(12.8, -0.03, 60), _flat(Color("5f8f48")))                   # трава
	_plane(Vector2(90, 14.8), Vector3(12.8, 0.0, 7.4), _surface(Color("6b717c"), Color("585d67"), 2.6, Vector2(90, 14.8)))   # перрон
	_plane(Vector2(90, 3.0), Vector3(12.8, 0.006, 16.1), _flat(Color("3a3f49")))                  # рулёжка
	_plane(Vector2(90, 4.2), Vector3(12.8, 0.006, RUNWAY_Z), _flat(Color("2e323b")))              # полоса
	_plane(Vector2(90, 3.4), Vector3(12.8, 0.003, 19.3), _flat(Color("6a6f78")))                  # перемычка

func _terminal() -> void:
	var cx := 12.8
	Rig.box(self, Vector3(40, 5.2, 6.4), Vector3(cx, 2.6, -1.0), Color("d6dce5"))
	Rig.box(self, Vector3(40.4, 0.3, 6.8), Vector3(cx, 5.3, -1.0), Color("4b576b"))
	# остекление фасада
	for i in 30:
		var x := -5.5 + i * 1.28
		Rig.box(self, Vector3(1.05, 3.1, 0.06), Vector3(x, 2.0, 2.22), Color(0.25, 0.5, 0.75, 0.9), Vector3.ZERO, 0.35)
		Rig.box(self, Vector3(0.14, 3.3, 0.14), Vector3(x + 0.64, 2.0, 2.2), Color("f1f3f7"))
		Rig.box(self, Vector3(1.0, 0.6, 0.05), Vector3(x, 4.35, 2.22), Color(0.95, 0.85, 0.55, 1.0), Vector3.ZERO, 0.7)
	Rig.box(self, Vector3(40, 0.2, 0.2), Vector3(cx, 0.45, 2.25), Color("f1f3f7"))
	# козырёк над входами
	Rig.box(self, Vector3(40.4, 0.22, 2.0), Vector3(cx, 3.9, 3.2), Color("eef1f6"))
	Rig.box(self, Vector3(40.4, 0.12, 2.04), Vector3(cx, 3.75, 3.2), Color("4b576b"))
	for i in 17:
		Rig.cyl(self, 0.07, 0.07, 3.8, Vector3(-6.6 + i * 2.4, 1.9, 4.1), Color("c8d0db"))
	# вывеска
	Rig.box(self, Vector3(9.0, 1.1, 0.25), Vector3(cx, 5.1, 2.3), Color("1b2a52"))
	Rig.label(self, "АЭРОПОРТ", Vector3(cx, 5.1, 2.45), 160, Color("ffd24d"), false)
	Rig.label(self, "ВЫЛЕТ · DEPARTURES", Vector3(cx, 4.35, 2.4), 52, Color("e8eef5"), false)

func _bridges() -> void:
	for i in 3:
		var xc: float = Cfg.ROWS[i] * Cfg.K
		var bx := xc - 1.35
		Rig.box(self, Vector3(1.3, 0.5, 1.2), Vector3(bx, 1.75, 2.8), Color("bfc7d3"))
		Rig.box(self, Vector3(1.0, 1.65, 3.2), Vector3(bx, 2.15, 3.8), Color("d9dee6"))
		Rig.box(self, Vector3(0.9, 0.7, 0.04), Vector3(bx, 2.35, 5.42), Color(0.35, 0.6, 0.85, 0.9), Vector3.ZERO, 0.4)
		Rig.cyl(self, 0.65, 0.65, 0.35, Vector3(bx, 2.0, 5.4), Color("aab4c3"), Vector3(90, 0, 0))
		Rig.cyl(self, 0.12, 0.12, 1.4, Vector3(bx, 0.7, 5.0), Color("e0b020"))
		Rig.cyl(self, 0.28, 0.28, 0.12, Vector3(bx, 0.06, 5.0), Color("333b4a"))
		Rig.box(self, Vector3(1.8, 0.5, 0.08), Vector3(xc - 0.4, 3.5, 2.3), Color("1b2a52"))
		Rig.label(self, "ВЫХОД A%d" % (i + 1), Vector3(xc - 0.4, 3.5, 2.36), 40, Color("ffd24d"), false)

func _tower() -> void:
	var x := 27.0
	var z := -3.0
	Rig.cyl(self, 0.8, 1.1, 14.0, Vector3(x, 7.0, z), Color("c0c8d4"))
	Rig.cyl(self, 2.6, 1.7, 1.4, Vector3(x, 14.7, z), Color("5d6a7e"))
	Rig.cyl(self, 2.5, 2.5, 1.4, Vector3(x, 16.0, z), Color(0.45, 0.8, 1.0, 0.75), Vector3.ZERO, 0.35)
	Rig.cyl(self, 2.9, 2.9, 0.3, Vector3(x, 16.9, z), Color("333b4a"))
	Rig.cyl(self, 0.05, 0.05, 2.5, Vector3(x, 18.3, z), Color("333b4a"))
	Rig.sphere(self, 0.15, Vector3(x, 19.6, z), Color("ff2d2d"), Vector3.ONE, 3.0)

func _belt() -> void:
	var r := Cfg.BELT
	var c := Cfg.to3(r.get_center())
	var sz := Vector2(r.size.y * Cfg.K, r.size.x * Cfg.K)   # X, Z
	Rig.box(self, Vector3(sz.x + 0.6, 0.35, sz.y + 0.6), Vector3(c.x, 0.17, c.z), Color("1d222d"))
	Rig.box(self, Vector3(sz.x, 0.08, sz.y), Vector3(c.x, 0.37, c.z), Color("3a4254"))
	for k in 14:
		Rig.box(self, Vector3(sz.x - 0.1, 0.02, 0.06), Vector3(c.x, 0.42, c.z - sz.y / 2.0 + 0.2 + k * 0.33), Color("5a6478"))
	Rig.box(self, Vector3(0.12, 0.25, sz.y + 0.6), Vector3(c.x + sz.x / 2.0 + 0.35, 0.45, c.z), Color("e0b020"))
	Rig.box(self, Vector3(0.12, 0.25, sz.y + 0.6), Vector3(c.x - sz.x / 2.0 - 0.35, 0.45, c.z), Color("e0b020"))
	Rig.box(self, Vector3(sz.x + 0.8, 0.7, 0.1), Vector3(c.x, 2.2, c.z - sz.y / 2.0 - 0.6), Color("1b2a52"))
	Rig.cyl(self, 0.05, 0.05, 2.0, Vector3(c.x - sz.x / 2.0 - 0.3, 1.0, c.z - sz.y / 2.0 - 0.6), Color("333b4a"))
	Rig.cyl(self, 0.05, 0.05, 2.0, Vector3(c.x + sz.x / 2.0 + 0.3, 1.0, c.z - sz.y / 2.0 - 0.6), Color("333b4a"))
	Rig.label(self, "БАГАЖ", Vector3(c.x, 2.2, c.z - sz.y / 2.0 - 0.52), 50, Color("ffd24d"), false)

func _kiosk(p: Vector2, title: String, roof: Color, icon: String) -> void:
	var c := Cfg.to3(p)
	Rig.box(self, Vector3(2.8, 1.8, 1.5), Vector3(c.x, 0.9, c.z), Color("e8d2a8"))
	Rig.box(self, Vector3(2.2, 0.8, 0.06), Vector3(c.x, 1.05, c.z + 0.77), Color("5d4a3a"))
	Rig.box(self, Vector3(2.9, 0.08, 0.6), Vector3(c.x, 1.3, c.z + 0.95), Color("c8a77a"))
	for k in 8:
		var col := roof if k % 2 == 0 else Color("f4f4f4")
		Rig.box(self, Vector3(0.37, 0.07, 1.3), Vector3(c.x - 1.3 + k * 0.37, 2.0, c.z + 0.7), col, Vector3(18, 0, 0))
	Rig.box(self, Vector3(2.9, 0.1, 1.6), Vector3(c.x, 1.85, c.z), Color("6b4e32"))
	Rig.label(self, title, Vector3(c.x, 1.45, c.z + 1.0), 40, Color("ffffff"), false)
	var it := Rig.item(icon)
	it.position = Vector3(c.x, 1.9, c.z)
	it.scale = Vector3.ONE * 3.2
	add_child(it)

func _stand(i: int) -> void:
	var y: float = Cfg.ROWS[i]
	var xc := y * Cfg.K
	var z0 := Cfg.PX * Cfg.K
	Rig.box(self, Vector3(0.12, 0.02, 11.2), Vector3(xc, 0.012, 10.5), Color("f2c744"))
	Rig.box(self, Vector3(2.4, 0.02, 0.14), Vector3(xc, 0.012, 4.9), Color("e6ebf2"))
	for k in 30:
		var t := 4.8 + k * 0.32
		for dx in [-4.0, 4.0]:
			if k % 2 == 0:
				Rig.box(self, Vector3(0.07, 0.02, 0.2), Vector3(xc + dx, 0.011, t), Color("c0392b"))
	for k in range(0, 26, 2):
		var t := xc - 4.0 + k * 0.32
		Rig.box(self, Vector3(0.2, 0.02, 0.07), Vector3(t, 0.011, 14.4), Color("c0392b"))
	var num := Rig.label(self, "A%d" % (i + 1), Vector3(xc, 0.03, 3.9), 140, Color(0.95, 0.96, 0.98, 0.9), false)
	num.rotation_degrees = Vector3(-90, 180, 0)
	num.outline_size = 0
	for off in [Cfg.DOOR_OFF, Cfg.FUEL_OFF]:
		var p := Cfg.to3(Vector2(Cfg.PX, y) + off, 0.02)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.68
		tm.outer_radius = 0.78
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		var col := Color("ffd24d") if off == Cfg.DOOR_OFF else Color("ff9f43")
		ring.material_override = Rig.mat(col, 0.9, 0.9)
		ring.position = p
		ring.scale = Vector3(1, 0.05, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	# заправщик
	var tz := z0 + 1.0
	var tx := xc + 3.6
	Rig.cyl(self, 0.55, 0.55, 2.3, Vector3(tx, 1.0, tz), Color("e9edf2"), Vector3(90, 0, 0))
	Rig.cyl(self, 0.56, 0.56, 0.25, Vector3(tx, 1.0, tz - 0.4), Color("e63946"), Vector3(90, 0, 0))
	Rig.box(self, Vector3(0.95, 0.95, 0.9), Vector3(tx, 0.85, tz - 1.6), Color("e63946"))
	Rig.box(self, Vector3(0.9, 0.4, 0.04), Vector3(tx, 1.05, tz - 2.07), Color(0.5, 0.8, 1.0, 0.8))
	for wz in [-1.6, -0.2, 0.9]:
		for wx in [-0.48, 0.48]:
			Rig.cyl(self, 0.22, 0.22, 0.18, Vector3(tx + wx, 0.22, tz + wz), Color("15181f"), Vector3(0, 0, 90))
	Rig.sphere(self, 0.07, Vector3(tx, 1.7, tz - 1.6), Color("ffb020"), Vector3.ONE, 3.0)
	# багажная тележка
	var cx := xc + 2.7
	var cz := z0 + 3.9
	Rig.box(self, Vector3(1.0, 0.12, 2.0), Vector3(cx, 0.35, cz), Color("e0b020"))
	for wz in [-0.7, 0.7]:
		Rig.cyl(self, 0.14, 0.14, 0.1, Vector3(cx + 0.45, 0.14, cz + wz), Color("15181f"), Vector3(0, 0, 90))
		Rig.cyl(self, 0.14, 0.14, 0.1, Vector3(cx - 0.45, 0.14, cz + wz), Color("15181f"), Vector3(0, 0, 90))
	for k in 3:
		var b := Rig.item("bag")
		b.position = Vector3(cx + (k - 1) * 0.0, 0.42, cz - 0.6 + k * 0.6)
		b.scale = Vector3.ONE * 1.6
		add_child(b)
	# конусы
	for off in [Vector2(-3.6, 4.7), Vector2(3.6, 4.7), Vector2(-3.6, 14.2), Vector2(3.6, 14.2)]:
		var c := Vector3(xc + off.x, 0, off.y)
		Rig.cyl(self, 0.04, 0.22, 0.6, c + Vector3(0, 0.3, 0), Color("ff6a2a"))
		Rig.cyl(self, 0.1, 0.13, 0.1, c + Vector3(0, 0.35, 0), Color("f4f4f4"))
		Rig.box(self, Vector3(0.5, 0.03, 0.5), c + Vector3(0, 0.015, 0), Color("2b3345"))

func _taxiway_and_runway() -> void:
	Rig.box(self, Vector3(90, 0.012, 0.12), Vector3(12.8, 0.014, 16.0), Color("f2c744"))
	for i in 36:
		var x := -4.0 + i * 1.6
		Rig.sphere(self, 0.06, Vector3(x, 0.08, 14.65), Color("5aa9ff"), Vector3.ONE, 3.0)
		Rig.sphere(self, 0.06, Vector3(x, 0.08, 17.55), Color("5aa9ff"), Vector3.ONE, 3.0)
	# полоса: кромки, осевая, огни
	Rig.box(self, Vector3(90, 0.012, 0.14), Vector3(12.8, 0.016, RUNWAY_Z - 1.9), Color("eef1f6"))
	Rig.box(self, Vector3(90, 0.012, 0.14), Vector3(12.8, 0.016, RUNWAY_Z + 1.9), Color("eef1f6"))
	for i in 40:
		Rig.box(self, Vector3(1.4, 0.012, 0.12), Vector3(-10.0 + i * 2.6, 0.016, RUNWAY_Z), Color("eef1f6"))
	for i in 40:
		var x := -10.0 + i * 2.6
		Rig.sphere(self, 0.07, Vector3(x, 0.08, RUNWAY_Z - 2.2), Color("fff2b0"), Vector3.ONE, 2.5)
		Rig.sphere(self, 0.07, Vector3(x, 0.08, RUNWAY_Z + 2.2), Color("fff2b0"), Vector3.ONE, 2.5)
	for k in 6:
		Rig.box(self, Vector3(0.4, 0.012, 1.4), Vector3(-1.0 + k * 0.7, 0.016, RUNWAY_Z), Color("eef1f6"))
	var n9 := Rig.label(self, "09", Vector3(2.4, 0.03, RUNWAY_Z), 170, Color(0.95, 0.96, 0.98, 0.9), false)
	n9.rotation_degrees = Vector3(-90, 180, 0)
	n9.outline_size = 0

func _scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var x := -30.0 + i * 0.95
		var z := rng.randf_range(30.0, 40.0)
		var h := rng.randf_range(1.6, 3.4)
		Rig.cyl(self, 0.1, 0.14, h * 0.4, Vector3(x, h * 0.2, z), Color("5b3a22"))
		Rig.cyl(self, 0.02, h * 0.38, h, Vector3(x, h * 0.4 + h * 0.5, z), Color("2f6b3a").lerp(Color("3f8a45"), rng.randf()))
	for h in [Vector3(-10, 0, 70), Vector3(14, 0, 78), Vector3(38, 0, 72), Vector3(-34, 0, 80)]:
		var s := Rig.sphere(self, 1.0, h, Color("6f9f66").darkened(rng.randf() * 0.2), Vector3(26, 7.5, 12))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- самолёты на полосе ----------
func _process(delta: float) -> void:
	fly_t -= delta
	if fly_t <= 0.0:
		fly_t = randf_range(9.0, 18.0)
		_spawn_flyby()
	for f in flybys.duplicate():
		f.t += delta
		var node: Aircraft = f.node
		var u: float = f.t / f.dur
		var x: float
		var y: float
		if f.mode == "land":
			x = lerpf(-14.0, 42.0, ease_out(u))
			y = maxf(0.0, 3.2 * (1.0 - u / 0.22))
		else:
			x = lerpf(-14.0, 42.0, ease_in(u))
			y = maxf(0.0, (u - 0.5) * 18.0)
		if f.dir < 0:
			x = 12.8 * 2.0 - x
		node.position = Vector3(x, y, RUNWAY_Z + f.lane)
		if u >= 1.0:
			flybys.erase(f)
			node.queue_free()

func ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 2.2)

func ease_in(u: float) -> float:
	return pow(u, 2.0)

func _spawn_flyby() -> void:
	var a := Aircraft.new()
	a.ambient = true
	a.livery = [Color("e63946"), Color("2a9d8f"), Color("f4a261"), Color("6c5ce7"), Color("00a8e8")].pick_random()
	a.flight = ["SU 214", "S7 905", "U6 331", "DP 404"].pick_random()
	add_child(a)
	var dir := 1 if randf() < 0.5 else -1
	a.body.rotation.y = PI if dir > 0 else 0.0
	flybys.append({"node": a, "t": 0.0, "dur": randf_range(7.0, 9.0), "mode": ["land", "takeoff"].pick_random(), "dir": dir, "lane": -0.2 if dir > 0 else 0.4})
