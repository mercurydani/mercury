class_name Airport
extends Node3D
# АЭРОПОРТ: огромный терминал с телетрапами, широкие стоянки, рулёжки, полосы, вышка,
# далёкий второй аэропорт, шоссе, парковки, пригород, лес и небоскрёбы на горизонте.

const CX := 22.0           # центр терминала по X
const TERM_W := 66.0
const RUNWAY_Z := 28.5

var flybys: Array = []
var fly_t := 3.0
var radar: Node3D
var crew: Array = []

func _ready() -> void:
	_ground()
	_terminal()
	_sign_letters()
	_interior()
	_tower()
	_bridges()
	_belts()
	_kiosk(Cfg.COFFEE, "КОФЕ", Color("7a5230"), "coffee")
	_kiosk(Cfg.BURGER, "БУРГЕРЫ", Color("a13a2a"), "burger")
	for i in 3:
		_stand(i)
	_taxiways_and_runway()
	_vehicles()
	_kenney_vehicles()
	_crew()
	_extras()
	_far_airport()
	_suburbs()

# ---------- материалы и примитивы ----------
func _plane(size: Vector2, center: Vector3, mat: StandardMaterial3D) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _flat(col: Color, rough: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m

func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	return m

func _multi(mesh: Mesh, xfs: Array, cols: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _vc_mat()
	add_child(mi)

func _ground() -> void:
	_plane(Vector2(1400, 1400), Vector3(CX, -0.05, 500), Tex.material(Tex.grass(), Vector2(400, 400), 0.95))
	_plane(Vector2(220, 17.4), Vector3(CX, 0.0, 10.9), Tex.material(Tex.concrete(256, 0.5, 1), Vector2(220 / 3.2, 17.4 / 3.2), 0.92, 0.5))
	_plane(Vector2(220, 3.2), Vector3(CX, 0.006, 21.0), Tex.material(Tex.asphalt(256, 0.26), Vector2(220 / 3.0, 1.1), 0.9, 0.9))
	_plane(Vector2(220, 3.3), Vector3(CX, 0.003, 24.25), Tex.material(Tex.concrete(256, 0.5, 1), Vector2(220 / 3.2, 1.1), 0.92, 0.5))
	_plane(Vector2(220, 5.6), Vector3(CX, 0.006, RUNWAY_Z), Tex.material(Tex.asphalt(256, 0.2), Vector2(220 / 3.0, 1.9), 0.88, 0.9))
	_plane(Vector2(220, 3.2), Vector3(CX, 0.006, 41.5), Tex.material(Tex.asphalt(256, 0.26), Vector2(220 / 3.0, 1.1), 0.9, 0.9))
	_plane(Vector2(160, 16), Vector3(CX, 0.0, 53.0), Tex.material(Tex.concrete(256, 0.5, 1), Vector2(160 / 3.2, 5.0), 0.92, 0.5))
	for k in 6:
		Rig.box(self, Vector3(4.0, 0.008, 0.07), Vector3(-6.0 + k * 0.4, 0.013, RUNWAY_Z - 1.0 + (k % 2) * 0.12), Color(0.08, 0.08, 0.09, 0.55))

# ---------- терминал ----------
func _terminal() -> void:
	var x0 := CX - TERM_W / 2.0
	Rig.box(self, Vector3(TERM_W, 5.4, 6.4), Vector3(CX, 2.7, -1.0), Color("d6dce5"))
	Rig.box(self, Vector3(TERM_W + 0.4, 0.3, 6.8), Vector3(CX, 5.5, -1.0), Color("4b576b"))
	for i in int(TERM_W / 1.28):
		var x := x0 + 0.7 + i * 1.28
		Rig.box(self, Vector3(1.05, 3.2, 0.06), Vector3(x, 2.0, 2.22), Color(0.25, 0.5, 0.75, 0.9), Vector3.ZERO, 0.35)
		Rig.box(self, Vector3(0.14, 3.4, 0.14), Vector3(x + 0.64, 2.0, 2.2), Color("f1f3f7"))
		Rig.box(self, Vector3(1.0, 0.6, 0.05), Vector3(x, 4.45, 2.22), Color(0.95, 0.85, 0.55, 1.0), Vector3.ZERO, 0.7)
	Rig.box(self, Vector3(TERM_W, 0.2, 0.2), Vector3(CX, 0.45, 2.25), Color("f1f3f7"))
	Rig.box(self, Vector3(TERM_W + 0.4, 0.22, 2.0), Vector3(CX, 3.95, 3.2), Color("eef1f6"))
	Rig.box(self, Vector3(TERM_W + 0.4, 0.12, 2.04), Vector3(CX, 3.8, 3.2), Color("4b576b"))
	for i in int(TERM_W / 2.4) + 1:
		Rig.cyl(self, 0.07, 0.07, 3.9, Vector3(x0 + 1.2 + i * 2.4, 1.95, 4.1), Color("c8d0db"))
	# входные группы
	for x in [CX - 14.0, CX + 14.0]:
		Rig.box(self, Vector3(3.2, 2.6, 0.1), Vector3(x, 1.4, 2.28), Color("1d3a5c"))
		Rig.box(self, Vector3(3.4, 0.2, 1.4), Vector3(x, 2.9, 2.9), Color("c0392b"))

# Огромные объёмные буквы на крыше: «АЭРОПОРТ».
func _sign_letters() -> void:
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.9
	# каркас-подставка и подложка
	for sx in [-1.0, 1.0]:
		for k in 2:
			Rig.box(self, Vector3(0.3, 5.4, 0.3), Vector3(CX + sx * (13.5 - k * 4.0), 8.4, 1.6), Color("39465c"))
	Rig.box(self, Vector3(30.0, 5.4, 0.5), Vector3(CX, 8.9, 1.5), Color("0f1b36"))
	Rig.box(self, Vector3(30.4, 0.2, 0.62), Vector3(CX, 11.7, 1.5), Color("e8eef5"), Vector3.ZERO, 0.6)
	Rig.box(self, Vector3(30.4, 0.2, 0.62), Vector3(CX, 6.2, 1.5), Color("e8eef5"), Vector3.ZERO, 0.6)
	# буквы
	var tm := TextMesh.new()
	tm.text = "АЭРОПОРТ"
	tm.font = fv
	tm.font_size = 256
	tm.pixel_size = 0.036
	tm.depth = 0.7
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffd24d")
	m.emission_enabled = true
	m.emission = Color("ffb800")
	m.emission_energy_multiplier = 1.6
	mi.material_override = m
	mi.position = Vector3(CX, 8.9, 2.0)
	add_child(mi)
	# английский дубль под вывеской и подсветка
	var tm2 := TextMesh.new()
	tm2.text = "AIRPORT  ·  АЭРОПОРТ  ·  AIRPORT"
	tm2.font = fv
	tm2.font_size = 80
	tm2.pixel_size = 0.02
	tm2.depth = 0.15
	var mi2 := MeshInstance3D.new()
	mi2.mesh = tm2
	mi2.material_override = Rig.mat(Color("e8eef5"), 0.5, 0.6)
	mi2.position = Vector3(CX, 5.0, 2.32)
	add_child(mi2)
	for k in 9:
		Rig.box(self, Vector3(0.5, 0.3, 0.5), Vector3(CX - 12.0 + k * 3.0, 6.3, 3.0), Color("fff6d0"), Vector3(-30, 0, 0), 3.0)

func _interior() -> void:
	var x0 := CX - TERM_W / 2.0
	Rig.box(self, Vector3(TERM_W, 0.1, 5.4), Vector3(CX, 0.07, -0.6), Color("c9c2b6"))
	Rig.box(self, Vector3(TERM_W, 0.12, 5.4), Vector3(CX, 3.6, -0.6), Color("e8e6e0"))
	for i in int(TERM_W / 1.7):
		var x := x0 + 0.8 + i * 1.7
		Rig.box(self, Vector3(1.2, 0.04, 0.3), Vector3(x, 3.52, 0.4), Color("fff6d8"), Vector3.ZERO, 2.2)
		Rig.box(self, Vector3(0.28, 3.5, 0.28), Vector3(x + 0.85, 1.75, -0.2), Color("dcd8d0"))
	for i in 12:
		var x := x0 + 4.0 + i * 5.3
		Rig.box(self, Vector3(2.6, 0.9, 0.7), Vector3(x, 0.5, -1.3), Color("2b3a55"))
		Rig.box(self, Vector3(2.6, 0.06, 0.8), Vector3(x, 0.98, -1.3), Color("e8e6e0"))
		Rig.box(self, Vector3(1.8, 0.6, 0.06), Vector3(x, 2.4, -1.6), Color("1b2a52"))
		Rig.label(self, "СТОЙКА %d" % (i + 1), Vector3(x, 2.4, -1.56), 34, Color("ffd24d"), false)
	Rig.box(self, Vector3(6.2, 2.0, 0.12), Vector3(CX - 6.0, 2.3, 1.7), Color("0b1220"))
	Rig.label(self, "ВЫЛЕТ     РЕЙС      КУДА        СТАТУС", Vector3(CX - 6.0, 3.1, 1.78), 34, Color("ffd24d"), false)
	var rows := [["12:40", "SU 214", "СОЧИ", "ЗАДЕРЖАН"], ["12:55", "S7 905", "ПИТЕР", "ЗАДЕРЖАН"], ["13:10", "U6 331", "ПЕРМЬ", "ЗАДЕРЖАН"], ["13:30", "DP 404", "ОМСК", "ЗАДЕРЖАН!!"], ["??:??", "FV 77", "ТУДА", "ЖДИТЕ"]]
	for k in rows.size():
		var r: Array = rows[k]
		Rig.label(self, "%s   %s   %s   %s" % r, Vector3(CX - 6.0, 2.7 - k * 0.32, 1.78), 30, Color("ff5a4d") if k < 4 else Color("7dff8a"), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var cols := [Color("c0392b"), Color("2980b9"), Color("27ae60"), Color("8e44ad"), Color("f39c12"), Color("34495e"), Color("e67e22")]
	var skins := [Color("e8b48a"), Color("c98e65"), Color("8d5a3c"), Color("f1c9a5")]
	for k in 90:
		var pp := Props.passenger(cols[rng.randi() % cols.size()], skins[rng.randi() % skins.size()])
		pp.position = Vector3(rng.randf_range(x0 + 2.0, x0 + TERM_W - 2.0), 0.12, rng.randf_range(0.5, 1.7))
		pp.rotation_degrees.y = rng.randf_range(0, 360)
		add_child(pp)

func _tower() -> void:
	var x := CX + 38.0
	var z := -3.0
	Rig.cyl(self, 0.9, 1.3, 17.0, Vector3(x, 8.5, z), Color("c0c8d4"))
	for k in 5:
		Rig.cyl(self, 0.92 + k * 0.0, 0.92, 0.5, Vector3(x, 3.0 + k * 3.2, z), Color("e63946") if k % 2 == 0 else Color("f4f4f4"))
	Rig.cyl(self, 3.0, 2.0, 1.6, Vector3(x, 17.8, z), Color("5d6a7e"))
	Rig.cyl(self, 2.9, 2.9, 1.7, Vector3(x, 19.4, z), Color(0.45, 0.8, 1.0, 0.75), Vector3.ZERO, 0.35)
	Rig.cyl(self, 3.3, 3.3, 0.35, Vector3(x, 20.45, z), Color("333b4a"))
	Rig.cyl(self, 0.06, 0.06, 3.0, Vector3(x, 22.0, z), Color("333b4a"))
	Rig.sphere(self, 0.18, Vector3(x, 23.6, z), Color("ff2d2d"), Vector3.ONE, 3.0)
	radar = Node3D.new()
	radar.position = Vector3(x + 1.9, 20.9, z)
	add_child(radar)
	Rig.cyl(self, 0.07, 0.07, 0.6, Vector3(x + 1.9, 20.7, z), Color("333b4a"))
	Rig.box(radar, Vector3(2.4, 0.8, 0.09), Vector3(0, 0.5, 0), Color("c8d0db"))
	Rig.box(radar, Vector3(0.12, 0.12, 0.7), Vector3(0, 0.5, 0.35), Color("333b4a"))

func _bridges() -> void:
	for i in 3:
		var xc: float = Cfg.ROWS[i] * Cfg.K
		var bx := xc - 2.1
		Rig.box(self, Vector3(1.4, 0.6, 1.2), Vector3(bx, 1.9, 2.8), Color("bfc7d3"))
		Rig.box(self, Vector3(1.1, 2.0, 4.6), Vector3(bx, 2.7, 4.6), Color("d9dee6"))
		Rig.box(self, Vector3(1.0, 0.8, 0.04), Vector3(bx, 3.0, 6.92), Color(0.35, 0.6, 0.85, 0.9), Vector3.ZERO, 0.4)
		Rig.cyl(self, 0.75, 0.75, 0.4, Vector3(bx, 2.5, 6.9), Color("aab4c3"), Vector3(90, 0, 0))
		Rig.cyl(self, 0.13, 0.13, 1.8, Vector3(bx, 0.9, 6.2), Color("e0b020"))
		Rig.cyl(self, 0.32, 0.32, 0.13, Vector3(bx, 0.07, 6.2), Color("333b4a"))
		Rig.box(self, Vector3(2.4, 0.6, 0.1), Vector3(xc - 0.4, 4.4, 2.3), Color("1b2a52"))
		Rig.label(self, "ВЫХОД A%d" % (i + 1), Vector3(xc - 0.4, 4.4, 2.37), 44, Color("ffd24d"), false)

func _belts() -> void:
	for r: Rect2 in Cfg.BELTS:
		var c := Cfg.to3(r.get_center())
		var sz := Vector2(r.size.y * Cfg.K, r.size.x * Cfg.K)
		Rig.box(self, Vector3(sz.x + 0.6, 0.35, sz.y + 0.6), Vector3(c.x, 0.17, c.z), Color("1d222d"))
		Rig.box(self, Vector3(sz.x, 0.08, sz.y), Vector3(c.x, 0.37, c.z), Color("3a4254"))
		for k in 14:
			Rig.box(self, Vector3(sz.x - 0.1, 0.02, 0.06), Vector3(c.x, 0.42, c.z - sz.y / 2.0 + 0.2 + k * 0.33), Color("5a6478"))
		for sx in [-1.0, 1.0]:
			Rig.box(self, Vector3(0.12, 0.25, sz.y + 0.6), Vector3(c.x + sx * (sz.x / 2.0 + 0.35), 0.45, c.z), Color("e0b020"))
			Rig.cyl(self, 0.05, 0.05, 2.0, Vector3(c.x + sx * (sz.x / 2.0 + 0.3), 1.0, c.z - sz.y / 2.0 - 0.6), Color("333b4a"))
		Rig.box(self, Vector3(sz.x + 0.8, 0.7, 0.1), Vector3(c.x, 2.2, c.z - sz.y / 2.0 - 0.6), Color("1b2a52"))
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

# ---------- стоянки ----------
func _stand(i: int) -> void:
	var y: float = Cfg.ROWS[i]
	var xc := y * Cfg.K
	var z0 := Cfg.PX * Cfg.K
	Rig.box(self, Vector3(0.14, 0.02, 16.4), Vector3(xc, 0.012, 13.2), Color("f2c744"))
	Rig.box(self, Vector3(3.0, 0.02, 0.16), Vector3(xc, 0.012, 4.8), Color("e6ebf2"))
	for k in 50:
		var t := 4.6 + k * 0.5
		if t > z0 + 7.6:
			break
		for dx in [-7.0, 7.0]:
			Rig.box(self, Vector3(0.08, 0.02, 0.25), Vector3(xc + dx, 0.011, t), Color("c0392b"))
	for k in 28:
		Rig.box(self, Vector3(0.25, 0.02, 0.08), Vector3(xc - 7.0 + k * 0.5, 0.011, z0 + 7.6), Color("c0392b"))
	var num := Rig.label(self, "A%d" % (i + 1), Vector3(xc, 0.03, 3.9), 150, Color(0.95, 0.96, 0.98, 0.9), false)
	num.rotation_degrees = Vector3(-90, 180, 0)
	num.outline_size = 0
	for off in [Cfg.DOOR_OFF, Cfg.FUEL_OFF]:
		var p := Cfg.to3(Vector2(Cfg.PX, y) + off, 0.02)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.68
		tm.outer_radius = 0.78
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = Rig.mat(Color("ffd24d") if off == Cfg.DOOR_OFF else Color("ff9f43"), 0.9, 0.9)
		ring.position = p
		ring.scale = Vector3(1, 0.05, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	var fuel := Props.fuel_truck()
	fuel.position = Vector3(xc + 4.9, 0, z0 + 0.9)
	add_child(fuel)
	var train := Props.baggage_train(2)
	train.position = Vector3(xc + 2.7, 0, z0 + 4.6)
	add_child(train)
	if i == 1:
		var tug := Assets.kenney("tractor", 2.4)
		if tug == null:
			tug = Props.pushback_tug()
		tug.position = Vector3(xc - 3.3, 0, z0 + 7.8)
		tug.rotation_degrees.y = 200.0
		add_child(tug)
	if i == 2:
		var gpu := Props.gpu_cart()
		gpu.position = Vector3(xc - 3.6, 0, z0 - 5.0)
		gpu.rotation_degrees.y = 25
		add_child(gpu)
	for off in [Vector2(-7.0, 4.7), Vector2(7.0, 4.7), Vector2(-7.0, z0 + 7.4), Vector2(7.0, z0 + 7.4)]:
		var c := Vector3(xc + off.x, 0, off.y)
		Rig.cyl(self, 0.04, 0.22, 0.6, c + Vector3(0, 0.3, 0), Color("ff6a2a"))
		Rig.cyl(self, 0.1, 0.13, 0.1, c + Vector3(0, 0.35, 0), Color("f4f4f4"))
		Rig.box(self, Vector3(0.5, 0.03, 0.5), c + Vector3(0, 0.015, 0), Color("2b3345"))

func _taxiways_and_runway() -> void:
	var cl := CX
	for z in [21.0, 41.5]:
		Rig.box(self, Vector3(220, 0.012, 0.12), Vector3(cl, 0.014, z), Color("f2c744"))
		for i in 80:
			var x := -40.0 + i * 2.4
			Rig.sphere(self, 0.06, Vector3(x, 0.08, z - 1.5), Color("5aa9ff"), Vector3.ONE, 3.0)
			Rig.sphere(self, 0.06, Vector3(x, 0.08, z + 1.5), Color("5aa9ff"), Vector3.ONE, 3.0)
	Rig.box(self, Vector3(220, 0.012, 0.16), Vector3(cl, 0.016, RUNWAY_Z - 2.6), Color("eef1f6"))
	Rig.box(self, Vector3(220, 0.012, 0.16), Vector3(cl, 0.016, RUNWAY_Z + 2.6), Color("eef1f6"))
	for i in 70:
		Rig.box(self, Vector3(1.8, 0.012, 0.14), Vector3(-40.0 + i * 3.4, 0.016, RUNWAY_Z), Color("eef1f6"))
	for i in 70:
		var x := -40.0 + i * 3.4
		Rig.sphere(self, 0.08, Vector3(x, 0.08, RUNWAY_Z - 3.0), Color("fff2b0"), Vector3.ONE, 2.5)
		Rig.sphere(self, 0.08, Vector3(x, 0.08, RUNWAY_Z + 3.0), Color("fff2b0"), Vector3.ONE, 2.5)
	for k in 8:
		Rig.box(self, Vector3(0.5, 0.012, 1.8), Vector3(-12.0 + k * 0.9, 0.016, RUNWAY_Z - 0.0), Color("eef1f6"))
	var n9 := Rig.label(self, "09", Vector3(-3.0, 0.03, RUNWAY_Z), 220, Color(0.95, 0.96, 0.98, 0.9), false)
	n9.rotation_degrees = Vector3(-90, 180, 0)
	n9.outline_size = 0
	for i in 3:
		var sgn := Props.taxi_sign("A%d  ←" % (i + 1))
		sgn.position = Vector3(Cfg.ROWS[i] * Cfg.K, 0, 22.9)
		sgn.rotation_degrees.y = 180
		add_child(sgn)

# ---------- техника и мелочи ----------
func _vehicles() -> void:
	var bus := Props.bus()
	bus.position = Vector3(-1.6, 0, 14.2)
	add_child(bus)
	var cat := Props.catering_truck()
	cat.position = Vector3(48.3, 0, 9.0)
	add_child(cat)
	var stairs := Props.stairs_truck()
	stairs.position = Vector3(48.3, 0, 14.0)
	stairs.rotation_degrees.y = 180
	add_child(stairs)

func _kenney_vehicles() -> void:
	var spots := [
		["firetruck", 5.0, Vector3(50.8, 0, 5.4), 90.0], ["ambulance", 4.0, Vector3(50.8, 0, 9.8), 90.0],
		["delivery", 4.6, Vector3(50.8, 0, 14.4), 90.0],
		["taxi", 3.6, Vector3(-4.6, 0, 5.4), -90.0], ["police", 3.7, Vector3(-4.6, 0, 9.0), -90.0],
		["van", 4.0, Vector3(-4.6, 0, 12.6), -90.0],
	]
	for s in spots:
		var v := Assets.kenney(s[0], s[1])
		if v == null:
			continue
		v.position = s[2]
		v.rotation_degrees.y = s[3]
		add_child(v)

func _crew() -> void:
	var vests := [Color("ff7a1a"), Color("d7ef2a"), Color("ff4d2e"), Color("ffd24d")]
	var hats := [Color("ffd24d"), Color("f4f4f4"), Color("ff7a1a"), Color("2b6fd6")]
	var skins := [Color("e8b48a"), Color("c98e65"), Color("8d5a3c"), Color("f1c9a5")]
	var z0 := Cfg.PX * Cfg.K
	var routes := [
		[Vector2(1.0, 18.4), Vector2(44.0, 18.4)],
		[Vector2(3.4, 5.0), Vector2(3.4, 9.4), Vector2(6.8, 12.0)],
		[Vector2(4.0, 3.3), Vector2(22.0, 3.3), Vector2(44.0, 3.4)],
		[Vector2(8.0 + 4.9, z0 + 0.1), Vector2(8.0 + 4.9, z0 + 2.3)],
		[Vector2(22.5 + 4.9, z0 + 0.1), Vector2(22.5 + 4.9, z0 + 2.3)],
		[Vector2(37.0 + 4.9, z0 + 0.1), Vector2(37.0 + 4.9, z0 + 2.3)],
		[Vector2(47.2, 7.4), Vector2(47.2, 7.4)],
		[Vector2(44.4, 7.0), Vector2(44.4, 11.0), Vector2(46.0, 12.0)],
		[Vector2(15.2, 6.0), Vector2(15.2, 16.0)],
		[Vector2(29.8, 6.0), Vector2(29.8, 15.0), Vector2(31.0, 16.0)],
		[Vector2(-1.6, 9.8), Vector2(-1.6, 9.8)],
		[Vector2(17.6, 18.4), Vector2(30.0, 18.4), Vector2(30.0, 12.0)],
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
	for x in [-2.0, 15.2, 29.8, 46.0]:
		var m := Props.light_mast(8.0)
		m.position = Vector3(x, 0, 19.0)
		m.rotation_degrees.y = 180
		add_child(m)
	for p in [Vector3(64.0, 0, 25.0), Vector3(-20.0, 0, 25.0)]:
		var w := Props.windsock()
		w.position = p
		add_child(w)
	for x in [-9.0, 53.0]:
		Rig.cyl(self, 0.05, 0.06, 7.0, Vector3(x, 3.5, 6.0), Color("c8ced8"))
		Rig.box(self, Vector3(1.5, 0.9, 0.03), Vector3(x + 0.8, 6.4, 6.0), Color("e63946") if x < 20 else Color("2a6fd6"))
		Rig.box(self, Vector3(1.5, 0.3, 0.035), Vector3(x + 0.8, 6.4, 6.0), Color("f4f4f4"))
	for x in range(-8, 54, 9):
		Rig.box(self, Vector3(2.2, 0.8, 1.6), Vector3(x, 5.9, -2.2), Color("aab4c3"))
		Rig.cyl(self, 0.5, 0.5, 0.15, Vector3(x - 0.5, 6.35, -2.2), Color("333b4a"))
		Rig.cyl(self, 0.5, 0.5, 0.15, Vector3(x + 0.5, 6.35, -2.2), Color("333b4a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 26:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-80, 130), rng.randf_range(35, 70), rng.randf_range(120, 380))
		add_child(c)
		for j in 5:
			var s := Rig.sphere(c, rng.randf_range(5.0, 10.0), Vector3(j * 6.0 - 12.0, rng.randf_range(-1, 1), rng.randf_range(-2, 2)), Color(1, 1, 1, 0.92), Vector3(1.0, 0.5, 0.8))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(s.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# ---------- далёкий аэропорт: второй терминал, ангары, цистерны, парковка, шоссе ----------
func _far_airport() -> void:
	var t := Assets.load_scene(Assets.TERMINAL)
	if t != null:
		var b := Assets.bounds(t)
		var k := 52.0 / maxf(b.size.x, 0.0001)
		var wrap := Node3D.new()
		wrap.add_child(t)
		t.scale = t.scale * k
		var c := b.get_center()
		t.position = Vector3(-c.x * k, -b.position.y * k, -c.z * k)
		wrap.position = Vector3(CX + 6.0, 0.0, 66.0)
		wrap.rotation_degrees.y = 180.0
		add_child(wrap)
	# самолёты на дальнем перроне
	for p in [[CX - 22.0, 49.0, 0], [CX + 34.0, 49.0, 1]]:
		var a := Aircraft.new()
		a.ambient = true
		a.model_idx = p[2]
		add_child(a)
		a.position = Vector3(p[0], 0, p[1])
		a.body.rotation.y = -PI / 2.0 + randf_range(-0.1, 0.1)
	# топливная база
	for k in 6:
		var x := -38.0 + (k % 3) * 11.0
		var z := 80.0 + (k / 3) * 12.0
		Rig.cyl(self, 4.2, 4.2, 9.0, Vector3(x, 4.5, z), Color("e8ecf1"))
		Rig.cyl(self, 4.25, 4.25, 1.0, Vector3(x, 6.5, z), Color("e63946"))
		Rig.cyl(self, 4.3, 3.9, 0.6, Vector3(x, 9.2, z), Color("c8ced8"))
	# ангары и склады
	for h in [[-60.0, 72.0, 22.0, 9.0, 16.0], [-34.0, 60.0, 18.0, 7.0, 14.0], [CX + 60.0, 74.0, 26.0, 10.0, 18.0], [CX + 92.0, 64.0, 20.0, 8.0, 15.0]]:
		Rig.box(self, Vector3(h[2], h[3], h[4]), Vector3(h[0], h[3] / 2.0, h[1]), Color("aeb7c4"))
		var roof := Rig.cyl(self, h[3] * 0.55, h[3] * 0.55, h[2], Vector3(h[0], h[3], h[1]), Color("8d97a6"), Vector3(0, 0, 90))
		Rig.box(self, Vector3(h[2] * 0.5, h[3] * 0.8, 0.2), Vector3(h[0], h[3] * 0.4, h[1] - h[4] / 2.0 - 0.05), Color("39465c"))
	Rig.label(self, "АНГАР №3", Vector3(-60.0, 7.0, 72.0 - 8.2), 140, Color("ffd24d"), false)
	# дорога-шоссе с машинами и парковка
	Rig.box(self, Vector3(500, 0.06, 14), Vector3(CX, 0.03, 112.0), Color("30343c"))
	for i in 120:
		Rig.box(self, Vector3(2.4, 0.07, 0.25), Vector3(-200.0 + i * 5.0, 0.07, 112.0), Color("f4f4f4"))
	Rig.box(self, Vector3(500, 0.08, 0.3), Vector3(CX, 0.07, 105.5), Color("f2c744"))
	Rig.box(self, Vector3(500, 0.08, 0.3), Vector3(CX, 0.07, 118.5), Color("f2c744"))
	Rig.box(self, Vector3(70, 0.05, 26), Vector3(CX + 14.0, 0.03, 92.0), Color("3a3f49"))
	var cars := ["sedan", "suv", "hatchback-sports", "taxi", "van", "police", "delivery", "truck", "sedan-sports", "ambulance"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for r in 3:
		for k in 14:
			if rng.randf() < 0.3:
				continue
			var v := Assets.kenney(cars[rng.randi() % cars.size()], 3.6)
			if v == null:
				continue
			v.position = Vector3(CX - 8.0 + k * 4.4, 0, 84.0 + r * 8.0)
			v.rotation_degrees.y = 90.0 if r % 2 == 0 else -90.0
			add_child(v)
	for k in 22:
		var v := Assets.kenney(cars[rng.randi() % cars.size()], 3.8)
		if v == null:
			continue
		var lane := 1.0 if k % 2 == 0 else -1.0
		v.position = Vector3(rng.randf_range(-150.0, 190.0), 0, 112.0 + 2.9 * lane)
		v.rotation_degrees.y = 90.0 * lane
		add_child(v)

# ---------- пригород, лес, небоскрёбы, холмы ----------
func _suburbs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	# дома: корпус + крыша, цвета разные
	var wall_cols := [Color("e8d9b8"), Color("cdb99a"), Color("d9a98a"), Color("b8c4cf"), Color("e6e1d4"), Color("c7d3b4")]
	var roof_cols := [Color("a8483a"), Color("6a4b3a"), Color("4a5568"), Color("8d3a2a"), Color("3c4a5c")]
	var bodies: Array = []
	var bcols: Array = []
	var roofs: Array = []
	var rcols: Array = []
	for gx in range(-210, 260, 17):
		for gz in range(150, 330, 19):
			if rng.randf() < 0.18:
				continue
			var x := gx + rng.randf_range(-3.0, 3.0)
			var z := gz + rng.randf_range(-3.0, 3.0)
			var w := rng.randf_range(7.0, 11.0)
			var d := rng.randf_range(8.0, 12.0)
			var h := rng.randf_range(4.0, 7.0) * (1.0 if rng.randf() < 0.8 else 2.2)
			var yaw := (PI / 2.0 if rng.randf() < 0.5 else 0.0)
			var bt := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(w, h, d)), Vector3(x, h / 2.0, z))
			bodies.append(bt)
			bcols.append(wall_cols[rng.randi() % wall_cols.size()])
			var rh := rng.randf_range(2.0, 3.4)
			var rt := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(w * 1.12, rh, d * 1.08)), Vector3(x, h + rh / 2.0 - 0.02, z))
			roofs.append(rt)
			rcols.append(roof_cols[rng.randi() % roof_cols.size()])
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	var pm := PrismMesh.new()
	pm.size = Vector3.ONE
	_multi(bm, bodies, bcols)
	_multi(pm, roofs, rcols)
	# улицы
	for gz in range(140, 340, 19):
		Rig.box(self, Vector3(520, 0.05, 5.0), Vector3(CX, 0.02, gz + 9.5), Color("34383f"))
	# лес: конусы-ёлки и шарообразные деревья
	var trunks: Array = []
	var tcols: Array = []
	var cones: Array = []
	var ccols: Array = []
	var balls: Array = []
	var bcol2: Array = []
	for i in 2600:
		var x := rng.randf_range(-260.0, 300.0)
		var z := rng.randf_range(34.0, 420.0)
		if z > 100.0 and z < 124.0:
			continue   # шоссе
		if z > 140.0 and z < 340.0 and rng.randf() < 0.75:
			continue   # район застройки реже в деревьях
		if z < 60.0 and x > -45.0 and x < CX + 55.0:
			continue   # дальний перрон
		var h := rng.randf_range(6.0, 14.0)
		trunks.append(Transform3D(Basis().scaled(Vector3(0.7, h * 0.3, 0.7)), Vector3(x, h * 0.15, z)))
		tcols.append(Color("5b3a22"))
		if rng.randf() < 0.6:
			cones.append(Transform3D(Basis().scaled(Vector3(h * 0.5, h * 0.85, h * 0.5)), Vector3(x, h * 0.3 + h * 0.43, z)))
			ccols.append(Color("2f6b3a").lerp(Color("3f8a45"), rng.randf()))
		else:
			balls.append(Transform3D(Basis().scaled(Vector3(h * 0.6, h * 0.55, h * 0.6)), Vector3(x, h * 0.45, z)))
			bcol2.append(Color("4a8a3a").lerp(Color("78a83a"), rng.randf()))
	var tr := CylinderMesh.new()
	tr.top_radius = 0.5
	tr.bottom_radius = 0.5
	tr.height = 1.0
	tr.radial_segments = 6
	var cn := CylinderMesh.new()
	cn.top_radius = 0.0
	cn.bottom_radius = 0.5
	cn.height = 1.0
	cn.radial_segments = 8
	var sp := SphereMesh.new()
	sp.radius = 0.5
	sp.height = 1.0
	sp.radial_segments = 8
	sp.rings = 5
	_multi(tr, trunks, tcols)
	_multi(cn, cones, ccols)
	_multi(sp, balls, bcol2)
	# небоскрёбы на горизонте
	var tw: Array = []
	var twc: Array = []
	for i in 55:
		var x := rng.randf_range(-260.0, 300.0)
		var z := rng.randf_range(420.0, 520.0)
		var h := rng.randf_range(35.0, 130.0)
		var w := rng.randf_range(12.0, 26.0)
		tw.append(Transform3D(Basis().scaled(Vector3(w, h, w * rng.randf_range(0.8, 1.4))), Vector3(x, h / 2.0, z)))
		twc.append(Color("9fb4c8").lerp(Color("5d7a99"), rng.randf()))
	_multi(bm, tw, twc)
	# холмы и горы
	for k in 9:
		var s := Rig.sphere(self, 1.0, Vector3(-300.0 + k * 100.0, 0.0, rng.randf_range(640.0, 760.0)), Color("6d8f78").lerp(Color("7f9a8a"), rng.randf()), Vector3(rng.randf_range(90, 160), rng.randf_range(40, 90), rng.randf_range(60, 120)))
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
			x = lerpf(-60.0, 110.0, ease_out(u))
			y = maxf(0.0, 5.0 * (1.0 - u / 0.22))
		else:
			x = lerpf(-60.0, 110.0, ease_in(u))
			y = maxf(0.0, (u - 0.5) * 36.0)
		if f.dir < 0:
			x = CX * 2.0 - x
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
	flybys.append({"node": a, "t": 0.0, "dur": randf_range(8.0, 11.0), "mode": ["land", "takeoff"].pick_random(), "dir": dir, "lane": -0.4 if dir > 0 else 0.4})
