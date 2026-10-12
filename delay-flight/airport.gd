class_name Airport
extends Node3D
# АЭРОПОРТ: терминал с телетрапами, перрон, рулёжка, взлётная полоса, вышка, окрестности.
# Логика стоянок — в Cfg. Здесь только декорации и декоративные самолёты на полосе.

const RUNWAY_Z := 23.5

var flybys: Array = []
var crew: Array = []
var radar: Node3D
var fly_t := 3.0

func _ready() -> void:
	_ground()
	_terminal()
	_interior()
	_tower()
	_bridges()
	_belt()
	_kiosk(Cfg.COFFEE, "КОФЕ", Color("7a5230"), "coffee")
	_kiosk(Cfg.BURGER, "БУРГЕРЫ", Color("a13a2a"), "burger")
	for i in 3:
		_stand(i)
	_taxiway_and_runway()
	_vehicles()
	_kenney_vehicles()
	_terminal_complex()
	_crew()
	_extras()
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
	_plane(Vector2(260, 260), Vector3(12.8, -0.03, 60), Tex.material(Tex.grass(), Vector2(60, 60), 0.95))
	_plane(Vector2(90, 14.8), Vector3(12.8, 0.0, 7.4), Tex.material(Tex.concrete(256, 0.5, 1), Vector2(90 / 3.2, 14.8 / 3.2), 0.92, 0.5))
	_plane(Vector2(90, 3.0), Vector3(12.8, 0.006, 16.1), Tex.material(Tex.asphalt(256, 0.26), Vector2(90 / 3.0, 1.0), 0.9, 0.9))
	_plane(Vector2(90, 4.2), Vector3(12.8, 0.006, RUNWAY_Z), Tex.material(Tex.asphalt(256, 0.2), Vector2(90 / 3.0, 1.4), 0.88, 0.9))
	_plane(Vector2(90, 3.4), Vector3(12.8, 0.003, 19.3), Tex.material(Tex.concrete(256, 0.5, 1), Vector2(90 / 3.2, 1.1), 0.92, 0.8))
	# следы шин в зоне касания
	for k in 6:
		Rig.box(self, Vector3(3.5, 0.008, 0.07), Vector3(2.5 + k * 0.4, 0.013, RUNWAY_Z - 0.7 + (k % 2) * 0.12), Color(0.08, 0.08, 0.09, 0.55))
		Rig.box(self, Vector3(3.5, 0.008, 0.07), Vector3(2.5 + k * 0.4, 0.013, RUNWAY_Z + 0.7 + (k % 2) * 0.12), Color(0.08, 0.08, 0.09, 0.55))

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

func _interior() -> void:
	# пол и потолок зала, стойки регистрации, колонны, свет
	Rig.box(self, Vector3(40, 0.1, 5.4), Vector3(12.8, 0.07, -0.6), Color("c9c2b6"))
	Rig.box(self, Vector3(40, 0.12, 5.4), Vector3(12.8, 3.55, -0.6), Color("e8e6e0"))
	for i in 24:
		var x := -6.0 + i * 1.7
		Rig.box(self, Vector3(1.2, 0.04, 0.3), Vector3(x, 3.47, 0.4), Color("fff6d8"), Vector3.ZERO, 2.2)
		Rig.box(self, Vector3(0.28, 3.5, 0.28), Vector3(x + 0.85, 1.75, -0.2), Color("dcd8d0"))
	for i in 7:
		var x := -4.0 + i * 5.1
		Rig.box(self, Vector3(2.6, 0.9, 0.7), Vector3(x, 0.5, -1.3), Color("2b3a55"))
		Rig.box(self, Vector3(2.6, 0.06, 0.8), Vector3(x, 0.98, -1.3), Color("e8e6e0"))
		Rig.box(self, Vector3(1.8, 0.6, 0.06), Vector3(x, 2.4, -1.6), Color("1b2a52"))
		Rig.label(self, "СТОЙКА %d" % (i + 1), Vector3(x, 2.4, -1.56), 34, Color("ffd24d"), false)
	# табло вылетов: всё «ЗАДЕРЖАН» — тематическая шутка
	var board := Rig.box(self, Vector3(6.2, 2.0, 0.12), Vector3(8.0, 2.3, 1.7), Color("0b1220"))
	Rig.label(self, "ВЫЛЕТ     РЕЙС      КУДА        СТАТУС", Vector3(8.0, 3.1, 1.78), 34, Color("ffd24d"), false)
	var rows := [["12:40", "SU 214", "СОЧИ", "ЗАДЕРЖАН"], ["12:55", "S7 905", "ПИТЕР", "ЗАДЕРЖАН"], ["13:10", "U6 331", "ПЕРМЬ", "ЗАДЕРЖАН"], ["13:30", "DP 404", "ОМСК", "ЗАДЕРЖАН!!"], ["??:??", "FV 77", "ТУДА", "ЖДИТЕ"]]
	for k in rows.size():
		var r: Array = rows[k]
		var col := Color("ff5a4d") if k < 4 else Color("7dff8a")
		Rig.label(self, "%s   %s   %s   %s" % r, Vector3(8.0, 2.7 - k * 0.32, 1.78), 30, col, false)
	# пассажиры за стеклом
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var cols := [Color("c0392b"), Color("2980b9"), Color("27ae60"), Color("8e44ad"), Color("f39c12"), Color("34495e"), Color("e67e22")]
	var skins := [Color("e8b48a"), Color("c98e65"), Color("8d5a3c"), Color("f1c9a5")]
	for k in 46:
		var pp := Props.passenger(cols[rng.randi() % cols.size()], skins[rng.randi() % skins.size()])
		pp.position = Vector3(rng.randf_range(-5.0, 31.0), 0.12, rng.randf_range(0.5, 1.7))
		pp.rotation_degrees.y = rng.randf_range(0, 360)
		add_child(pp)

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
	radar = Node3D.new()
	radar.position = Vector3(x + 1.6, 17.3, z)
	add_child(radar)
	Rig.cyl(self, 0.06, 0.06, 0.5, Vector3(x + 1.6, 17.15, z), Color("333b4a"))
	Rig.box(radar, Vector3(2.0, 0.7, 0.08), Vector3(0, 0.45, 0), Color("c8ced8"))
	Rig.box(radar, Vector3(0.1, 0.1, 0.6), Vector3(0, 0.45, 0.3), Color("333b4a"))

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
	# заправщик и багажный поезд у стоянки
	var fuel := Props.fuel_truck()
	fuel.position = Vector3(xc + 3.65, 0, z0 + 0.8)
	add_child(fuel)
	var train := Props.baggage_train(2)
	train.position = Vector3(xc + 2.55, 0, z0 + 2.6)
	train.rotation_degrees.y = 0
	add_child(train)
	if i == 1:
		var tug := Assets.kenney("tractor", 2.2)
		if tug == null:
			tug = Props.pushback_tug()
		tug.position = Vector3(xc - 2.2, 0, z0 + 5.4)
		tug.rotation_degrees.y = 200.0
		add_child(tug)
	if i == 2:
		var gpu := Props.gpu_cart()
		gpu.position = Vector3(xc - 1.6, 0, z0 - 3.0)
		gpu.rotation_degrees.y = 25
		add_child(gpu)
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

func _vehicles() -> void:
	var bus := Props.bus()
	bus.position = Vector3(1.2, 0, 12.4)
	add_child(bus)
	var cat := Props.catering_truck()
	cat.position = Vector3(25.3, 0, 9.0)
	add_child(cat)
	var stairs := Props.stairs_truck()
	stairs.position = Vector3(25.3, 0, 13.0)
	stairs.rotation_degrees.y = 180
	add_child(stairs)

func _kenney_vehicles() -> void:
	var spots := [
		["firetruck", 4.4, Vector3(27.4, 0, 5.0), 90.0], ["ambulance", 3.6, Vector3(27.4, 0, 9.6), 90.0],
		["taxi", 3.2, Vector3(-2.0, 0, 5.2), -90.0], ["police", 3.3, Vector3(-2.0, 0, 8.6), -90.0],
		["van", 3.6, Vector3(-2.0, 0, 12.0), -90.0], ["delivery", 4.2, Vector3(27.4, 0, 13.8), 90.0],
	]
	for s in spots:
		var v := Assets.kenney(s[0], s[1])
		if v == null:
			continue
		v.position = s[2]
		v.rotation_degrees.y = s[3]
		add_child(v)

# Терминальный комплекс (CC-BY, soysascha) — за полосой, как «большой аэропорт» вдали.
func _terminal_complex() -> void:
	var m := Assets.load_scene(Assets.TERMINAL)
	if m == null:
		return
	var b := Assets.bounds(m)
	var k := 34.0 / maxf(b.size.x, 0.0001)
	var wrap := Node3D.new()
	wrap.add_child(m)
	m.scale = m.scale * k
	var c := b.get_center()
	m.position = Vector3(-c.x * k, -b.position.y * k, -c.z * k)
	wrap.position = Vector3(18.0, 0.0, 36.0)
	wrap.rotation_degrees.y = 180.0
	add_child(wrap)

# Живые рабочие (Quaternius, CC0) с анимациями ходьбы, работы, приветствий.
func _crew() -> void:
	var vests := [Color("ff7a1a"), Color("d7ef2a"), Color("ff4d2e"), Color("ffd24d")]
	var hats := [Color("ffd24d"), Color("f4f4f4"), Color("ff7a1a"), Color("2b6fd6")]
	var skins := [Color("e8b48a"), Color("c98e65"), Color("8d5a3c"), Color("f1c9a5")]
	var z0 := Cfg.PX * Cfg.K
	var routes := [
		[Vector2(2.0, 12.9), Vector2(23.5, 12.9)],
		[Vector2(3.4, 5.0), Vector2(3.4, 9.4), Vector2(6.9, 11.2)],
		[Vector2(8.8, 3.2), Vector2(17.0, 3.2), Vector2(24.0, 3.4)],
		[Vector2(5.2 + 2.9, z0 + 0.4), Vector2(5.2 + 2.9, z0 + 2.2)],
		[Vector2(12.8 + 2.9, z0 + 0.4), Vector2(12.8 + 2.9, z0 + 2.2)],
		[Vector2(20.4 + 2.9, z0 + 0.4), Vector2(20.4 + 2.9, z0 + 2.2)],
		[Vector2(26.2, 7.2), Vector2(26.2, 7.2)],
		[Vector2(0.9, 10.8), Vector2(0.9, 10.8)],
		[Vector2(16.4, 6.0), Vector2(16.4, 11.6)],
		[Vector2(9.2, 6.4), Vector2(9.2, 12.2), Vector2(10.4, 12.6)],
	]
	for i in routes.size():
		var w := Assets.worker(vests[i % 4], hats[(i + 1) % 4], skins[(i + 2) % 4])
		if w == null:
			return
		var pts: Array = routes[i]
		w.position = Vector3(pts[0].x, 0, pts[0].y)
		add_child(w)
		var ap := Assets.play(w, "Walk" if pts.size() > 1 else "Idle")
		crew.append({"node": w, "pts": pts, "i": 0, "wait": randf_range(0.0, 3.0), "ap": ap, "speed": randf_range(1.0, 1.5), "walking": pts.size() > 1})

func _crew_update(delta: float) -> void:
	for c in crew:
		var w: Node3D = c.node
		var pts: Array = c.pts
		if c.wait > 0.0:
			c.wait -= delta
			if c.wait <= 0.0 and pts.size() > 1:
				c.walking = true
				Assets.play(w, "Walk")
			continue
		if pts.size() < 2:
			c.wait = randf_range(3.0, 6.0)
			Assets.play(w, ["Idle", "Wave", "Interact", "Idle_Neutral"].pick_random())
			continue
		var tgt: Vector2 = pts[(c.i + 1) % pts.size()]
		var cur := Vector2(w.position.x, w.position.z)
		var d := tgt - cur
		if d.length() < 0.15:
			c.i = (c.i + 1) % pts.size()
			c.wait = randf_range(1.5, 5.0)
			c.walking = false
			Assets.play(w, ["Interact", "Idle", "Wave", "Idle_Neutral"].pick_random())
			continue
		var step: Vector2 = d.normalized() * c.speed * 1.2 * delta
		w.position += Vector3(step.x, 0, step.y)
		w.rotation.y = lerp_angle(w.rotation.y, atan2(d.x, d.y), minf(1.0, delta * 8.0))

func _extras() -> void:
	# мачты освещения
	for x in [0.8, 9.0, 16.6, 24.8]:
		var m := Props.light_mast(7.0)
		m.position = Vector3(x, 0, 14.5)
		m.rotation_degrees.y = 180
		add_child(m)
	# рулёжные указатели
	for i in 3:
		var sgn := Props.taxi_sign("A%d  ←" % (i + 1))
		sgn.position = Vector3(Cfg.ROWS[i] * Cfg.K, 0, 17.95)
		sgn.rotation_degrees.y = 180
		add_child(sgn)
	# ветроуказатели
	for p in [Vector3(27.5, 0, 19.3), Vector3(-6.0, 0, 19.3)]:
		var w := Props.windsock()
		w.position = p
		add_child(w)
	# флагштоки у входа
	for x in [1.2, 24.4]:
		Rig.cyl(self, 0.05, 0.06, 6.0, Vector3(x, 3.0, 5.6), Color("c8ced8"))
		Rig.box(self, Vector3(1.3, 0.8, 0.03), Vector3(x + 0.7, 5.5, 5.6), Color("e63946") if x < 10 else Color("2a6fd6"))
		Rig.box(self, Vector3(1.3, 0.27, 0.035), Vector3(x + 0.7, 5.5, 5.6), Color("f4f4f4"))
	# крыша терминала: вентиляция, мачты, антенна
	for x in [-3.0, 4.0, 9.0, 20.0, 29.0]:
		Rig.box(self, Vector3(2.2, 0.8, 1.6), Vector3(x, 5.9, -1.5), Color("aab4c3"))
		Rig.cyl(self, 0.5, 0.5, 0.15, Vector3(x - 0.5, 6.35, -1.5), Color("333b4a"))
		Rig.cyl(self, 0.5, 0.5, 0.15, Vector3(x + 0.5, 6.35, -1.5), Color("333b4a"))
	Rig.cyl(self, 0.05, 0.05, 4.0, Vector3(14.0, 7.5, -1.8), Color("c8ced8"))
	Rig.sphere(self, 0.1, Vector3(14.0, 9.6, -1.8), Color("ff2d2d"), Vector3.ONE, 3.0)
	# ангар за полосой
	var hx := -9.0
	var hz := 31.0
	Rig.box(self, Vector3(14, 4.5, 9), Vector3(hx, 2.25, hz), Color("aeb7c4"))
	var roof := Rig.cyl(self, 4.5, 4.5, 14, Vector3(hx, 4.5, hz), Color("8d97a6"), Vector3(0, 0, 90))
	roof.scale = Vector3(1.0, 1.0, 1.0)
	Rig.box(self, Vector3(8, 4.4, 0.1), Vector3(hx, 2.2, hz - 4.55), Color("39465c"))
	Rig.label(self, "АНГАР №3", Vector3(hx, 5.0, hz - 4.6), 120, Color("ffd24d"), false)
	# облака
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 16:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-40, 70), rng.randf_range(22, 40), rng.randf_range(60, 150))
		add_child(c)
		for j in 5:
			var s := Rig.sphere(c, rng.randf_range(3.0, 6.0), Vector3(j * 4.0 - 8.0, rng.randf_range(-1, 1), rng.randf_range(-2, 2)), Color(1, 1, 1, 0.92), Vector3(1.0, 0.5, 0.8))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(s.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var x := -30.0 + i * 0.95
		var z := rng.randf_range(46.0, 58.0)
		var h := rng.randf_range(1.6, 3.4)
		Rig.cyl(self, 0.1, 0.14, h * 0.4, Vector3(x, h * 0.2, z), Color("5b3a22"))
		Rig.cyl(self, 0.02, h * 0.38, h, Vector3(x, h * 0.4 + h * 0.5, z), Color("2f6b3a").lerp(Color("3f8a45"), rng.randf()))
	for h in [Vector3(-10, 0, 70), Vector3(14, 0, 78), Vector3(38, 0, 72), Vector3(-34, 0, 80)]:
		var s := Rig.sphere(self, 1.0, h, Color("6f9f66").darkened(rng.randf() * 0.2), Vector3(26, 7.5, 12))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- самолёты на полосе ----------
func _process(delta: float) -> void:
	_crew_update(delta)
	if radar != null:
		radar.rotation.y += delta * 1.6
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
	a.model_idx = randi() % Assets.FLEET.size()
	a.livery = [Color("e63946"), Color("2a9d8f"), Color("f4a261"), Color("6c5ce7"), Color("00a8e8")].pick_random()
	a.flight = ["SU 214", "S7 905", "U6 331", "DP 404"].pick_random()
	add_child(a)
	var dir := 1 if randf() < 0.5 else -1
	a.body.rotation.y = PI if dir > 0 else 0.0
	flybys.append({"node": a, "t": 0.0, "dur": randf_range(7.0, 9.0), "mode": ["land", "takeoff"].pick_random(), "dir": dir, "lane": -0.2 if dir > 0 else 0.4})
