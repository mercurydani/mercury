class_name Airport
extends Node3D
# АЭРОПОРТ в реальном масштабе (единица = 3 м): терминал ≈390 м с телетрапами, стоянки через 57 м,
# рулёжка, полоса 45 м, вышка, второй аэропорт вдали, шоссе, пригород, леса, небоскрёбы и горы.
# Повторяющиеся мелочи — через MultiMesh, разметка поднята над асфальтом (без мерцания).

const CX := 30.0
const TERM_W := 130.0
const RUNWAY_Z := 105.0
const GATES := [-8.0, 11.0, 30.0, 49.0, 68.0, 87.0]
const Y_APRON := 0.0
const Y_TAXI := 0.02
const Y_RWY := 0.03
const Y_PAINT := 0.08

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
	_decor_gates()
	_apron_details()
	_taxiways_and_runway()
	_service_road()
	_kenney_vehicles()
	_crew()
	_extras()
	_far_airport()
	_suburbs()
	var baked := Baker.bake(self)
	print("Airport: baked %d meshes" % baked)

# ---------- материалы и помощники ----------
func _plane(size: Vector2, center: Vector3, mat: StandardMaterial3D) -> void:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _flat(col: Color, rough: float = 0.9, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m

func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	return m

func _glass() -> StandardMaterial3D:
	var m := _flat(Color(0.1, 0.17, 0.26), 0.06, 0.9)
	return m

func _xf(pos: Vector3, size: Vector3, yaw: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(size), pos)

# Много одинаковых объектов одним вызовом отрисовки.
func _mm(mesh: Mesh, xfs: Array, mat: Material, shadow: bool = false) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _mm_colored(mesh: Mesh, xfs: Array, cols: Array, shadow: bool = false) -> void:
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
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _box_mesh() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b

func _sphere_mesh(r: float = 0.5) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 8
	s.rings = 4
	return s

func _ground() -> void:
	var cx := CX
	_plane(Vector2(3000, 3000), Vector3(cx, -0.06, 1000), Tex.material(Tex.grass(), Vector2(800, 800), 0.95))
	_plane(Vector2(620, 29), Vector3(cx, Y_APRON, 14.5), Tex.material(Tex.concrete(256, 0.5, 1), Vector2(620 / 1.7, 29 / 1.7), 0.7, 0.55))
	_plane(Vector2(620, 7.4), Vector3(cx, Y_TAXI, 34.0), Tex.material(Tex.asphalt(256, 0.27), Vector2(620 / 1.4, 7.4 / 1.4), 0.6, 0.6))
	for x in [-90.0, 150.0]:
		_plane(Vector2(7.4, 60.0), Vector3(x, Y_TAXI, 67.6), Tex.material(Tex.asphalt(256, 0.27), Vector2(5.0, 43.0), 0.6, 0.6))
	_plane(Vector2(1000, 15), Vector3(cx + 50.0, Y_RWY, RUNWAY_Z), Tex.material(Tex.asphalt(256, 0.21), Vector2(1000 / 1.4, 15 / 1.4), 0.55, 0.6))
	_plane(Vector2(1000, 7.4), Vector3(cx + 50.0, Y_TAXI, 150.0), Tex.material(Tex.asphalt(256, 0.27), Vector2(1000 / 1.4, 7.4 / 1.4), 0.6, 0.6))
	_plane(Vector2(400, 44), Vector3(cx, Y_APRON, 196.0), Tex.material(Tex.concrete(256, 0.5, 1), Vector2(400 / 1.7, 44 / 1.7), 0.7, 0.55))

# ---------- терминал ----------
func _terminal() -> void:
	var x0 := CX - TERM_W / 2.0
	var wall := _flat(Color("d9dde4"), 0.7)
	var b := Rig.box(self, Vector3(TERM_W, 7.2, 14.0), Vector3(CX, 3.6, -7.0), Color("d9dde4"))
	b.material_override = wall
	# стеклянный фасад с импостами
	var glass := Rig.box(self, Vector3(TERM_W - 2.0, 6.4, 0.12), Vector3(CX, 3.4, 0.08), Color.WHITE)
	glass.material_override = _glass()
	var mull: Array = []
	for i in int(TERM_W / 2.5) + 1:
		mull.append(_xf(Vector3(x0 + 1.0 + i * 2.5, 3.4, 0.16), Vector3(0.12, 6.5, 0.22)))
	_mm(_box_mesh(), mull, _flat(Color("e8ebf0"), 0.5, 0.4), true)
	var trans: Array = []
	for y in [1.6, 3.4, 5.0]:
		trans.append(_xf(Vector3(CX, y, 0.16), Vector3(TERM_W - 2.0, 0.1, 0.22)))
	_mm(_box_mesh(), trans, _flat(Color("e8ebf0"), 0.5, 0.4))
	# карниз и козырёк над перроном
	Rig.box(self, Vector3(TERM_W + 1.0, 0.5, 15.0), Vector3(CX, 7.45, -6.2), Color("39465c"))
	Rig.box(self, Vector3(TERM_W + 1.0, 0.35, 5.0), Vector3(CX, 4.3, 2.4), Color("eef1f6"))
	Rig.box(self, Vector3(TERM_W + 1.0, 0.18, 5.05), Vector3(CX, 4.1, 2.4), Color("2b3446"))
	var cols: Array = []
	for i in int(TERM_W / 7.5) + 1:
		cols.append(_xf(Vector3(x0 + 0.5 + i * 7.5, 2.1, 4.4), Vector3(0.28, 4.2, 0.28)))
	_mm(_box_mesh(), cols, _flat(Color("cfd5de"), 0.5, 0.3), true)
	# светильники под козырьком
	var lamps: Array = []
	for i in int(TERM_W / 3.0):
		lamps.append(_xf(Vector3(x0 + 1.5 + i * 3.0, 4.0, 2.4), Vector3(0.9, 0.05, 0.25)))
	_mm(_box_mesh(), lamps, _flat(Color("fff3d0"), 0.5, 0.0, 2.2))
	# входные группы с красными козырьками
	for x in [CX - 30.0, CX, CX + 30.0]:
		Rig.box(self, Vector3(6.0, 2.8, 0.1), Vector3(x, 1.5, 0.2), Color("14283f"))
		Rig.box(self, Vector3(6.4, 0.25, 1.8), Vector3(x, 3.0, 1.1), Color("c0392b"))

# Огромные объёмные буквы «АЭРОПОРТ» на крыше: каждая буква отдельной деталью, плоский цвет.
func _sign_letters() -> void:
	var fv := ThemeDB.fallback_font
	var y := 12.4
	# опорная ферма и подложка
	for sx in [-1.0, 1.0]:
		for k in 3:
			Rig.box(self, Vector3(0.35, 5.0, 0.35), Vector3(CX + sx * (21.0 - k * 6.0), 10.0, -1.0), Color("39465c"))
	Rig.box(self, Vector3(48.0, 7.6, 0.6), Vector3(CX, y, -1.4), Color("0d1830"))
	Rig.box(self, Vector3(48.4, 0.3, 0.8), Vector3(CX, y + 3.95, -1.3), Color("dfe5ee"), Vector3.ZERO, 0.5)
	Rig.box(self, Vector3(48.4, 0.3, 0.8), Vector3(CX, y - 3.95, -1.3), Color("dfe5ee"), Vector3.ZERO, 0.5)
	var word := "АЭРОПОРТ"
	var step := 5.0
	var x_start := CX - (word.length() - 1) * step / 2.0
	for i in word.length():
		var tm := TextMesh.new()
		tm.text = word[i]
		tm.font = fv
		tm.font_size = 256
		tm.pixel_size = 0.0235
		tm.depth = 0.9
		tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# лицо буквы: плоский тёплый белый, без освещения — одинаков у всех букв
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color("ffe08a")
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for o in [Vector2(0, 0), Vector2(0.09, 0), Vector2(-0.09, 0), Vector2(0, 0.09), Vector2(0, -0.09), Vector2(0.065, 0.065), Vector2(-0.065, -0.065), Vector2(0.065, -0.065), Vector2(-0.065, 0.065)]:
			var face := MeshInstance3D.new()
			face.mesh = tm
			face.material_override = fm
			face.position = Vector3(x_start + i * step + o.x, y + o.y, -0.7)
			face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(face)
		# тёмная тень-объём позади
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color("5a3d00")
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for o in [Vector2(0.18, -0.18), Vector2(0.27, -0.27), Vector2(0.09, -0.27), Vector2(0.27, -0.09)]:
			var back := MeshInstance3D.new()
			back.mesh = tm
			back.material_override = bm
			back.position = Vector3(x_start + i * step + o.x, y + o.y, -1.0)
			back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(back)
	# английский дубль на фасаде, строчка под козырьком
	var tm2 := TextMesh.new()
	tm2.text = "AIRPORT"
	tm2.font = fv
	tm2.font_size = 128
	tm2.pixel_size = 0.016
	tm2.depth = 0.12
	var m2 := MeshInstance3D.new()
	m2.mesh = tm2
	var mm2 := StandardMaterial3D.new()
	mm2.albedo_color = Color("eef2f8")
	mm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.material_override = mm2
	m2.position = Vector3(CX, 6.5, 0.4)
	add_child(m2)
	# прожекторы на вывеску
	var fl: Array = []
	for k in 12:
		fl.append(_xf(Vector3(CX - 22.0 + k * 4.0, 7.9, 1.2), Vector3(0.5, 0.2, 0.5)))
	_mm(_box_mesh(), fl, _flat(Color("fff6d0"), 0.4, 0.0, 3.0))

func _interior() -> void:
	var x0 := CX - TERM_W / 2.0
	Rig.box(self, Vector3(TERM_W - 2.0, 0.1, 9.0), Vector3(CX, 0.08, -4.5), Color("cfc8bb"))
	Rig.box(self, Vector3(TERM_W - 2.0, 0.15, 9.0), Vector3(CX, 4.2, -4.5), Color("eceae4"))
	var lights: Array = []
	var cols: Array = []
	for i in int(TERM_W / 2.2):
		lights.append(_xf(Vector3(x0 + 2.0 + i * 2.2, 4.1, -1.0), Vector3(1.4, 0.05, 0.3)))
		cols.append(_xf(Vector3(x0 + 3.0 + i * 4.4, 2.1, -3.0), Vector3(0.3, 4.2, 0.3)))
	_mm(_box_mesh(), lights, _flat(Color("fff6d8"), 0.5, 0.0, 2.6))
	_mm(_box_mesh(), cols, _flat(Color("dcd8d0"), 0.7))
	# стойки регистрации
	for i in 14:
		var x := x0 + 6.0 + i * 8.6
		Rig.box(self, Vector3(3.0, 0.5, 0.9), Vector3(x, 0.35, -5.5), Color("2b3a55"))
		Rig.box(self, Vector3(3.0, 0.05, 1.0), Vector3(x, 0.62, -5.5), Color("e8e6e0"))
		Rig.box(self, Vector3(2.4, 0.5, 0.05), Vector3(x, 2.3, -6.0), Color("1b2a52"))
	# большое табло вылетов — сплошное «ЗАДЕРЖАН»
	Rig.box(self, Vector3(14.0, 3.4, 0.2), Vector3(CX - 14.0, 2.6, -1.1), Color("070d18"))
	var rows := [["12:40", "SU 214", "СОЧИ", "ЗАДЕРЖАН"], ["12:55", "S7 905", "ПИТЕР", "ЗАДЕРЖАН"], ["13:10", "U6 331", "ПЕРМЬ", "ЗАДЕРЖАН"], ["13:30", "DP 404", "ОМСК", "ЗАДЕРЖАН!!"], ["??:??", "FV 77", "ТУДА", "ЖДИТЕ"]]
	var hl := Rig.label(self, "ВЫЛЕТ     РЕЙС      КУДА        СТАТУС", Vector3(CX - 14.0, 3.9, -0.95), 30, Color("ffd24d"), false)
	hl.pixel_size = 0.016
	hl.outline_size = 0
	for k in rows.size():
		var r: Array = rows[k]
		var l := Rig.label(self, "%s   %s   %s   %s" % r, Vector3(CX - 14.0, 3.35 - k * 0.55, -0.95), 30, Color("ff5a4d") if k < 4 else Color("7dff8a"), false)
		l.pixel_size = 0.016
		l.outline_size = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var pcols := [Color("c0392b"), Color("2980b9"), Color("27ae60"), Color("8e44ad"), Color("f39c12"), Color("34495e"), Color("e67e22")]
	var skins := [Color("e8b48a"), Color("c98e65"), Color("8d5a3c"), Color("f1c9a5")]
	for k in 140:
		var pp := Props.passenger(pcols[rng.randi() % pcols.size()], skins[rng.randi() % skins.size()])
		pp.scale = Vector3.ONE * 0.4
		pp.position = Vector3(rng.randf_range(x0 + 3.0, x0 + TERM_W - 3.0), 0.12, rng.randf_range(-3.2, -0.6))
		pp.rotation_degrees.y = rng.randf_range(0, 360)
		add_child(pp)

func _tower() -> void:
	var x := CX + 82.0
	var z := -10.0
	Rig.cyl(self, 1.5, 2.1, 30.0, Vector3(x, 15.0, z), Color("c0c8d4"))
	for k in 5:
		Rig.cyl(self, 1.52, 1.52, 1.0, Vector3(x, 5.0 + k * 5.6, z), Color("e63946") if k % 2 == 0 else Color("f4f4f4"))
	Rig.cyl(self, 5.0, 3.4, 2.6, Vector3(x, 31.3, z), Color("5d6a7e"))
	var g := Rig.cyl(self, 4.8, 4.8, 3.0, Vector3(x, 34.0, z), Color.WHITE)
	g.material_override = _glass()
	Rig.cyl(self, 5.4, 5.4, 0.6, Vector3(x, 35.8, z), Color("333b4a"))
	Rig.cyl(self, 0.1, 0.1, 5.0, Vector3(x, 38.5, z), Color("333b4a"))
	Rig.sphere(self, 0.3, Vector3(x, 41.2, z), Color("ff2d2d"), Vector3.ONE, 3.0)
	radar = Node3D.new()
	radar.set_meta("nobake", true)
	radar.position = Vector3(x + 3.4, 36.8, z)
	add_child(radar)
	Rig.cyl(self, 0.12, 0.12, 1.0, Vector3(x + 3.4, 36.4, z), Color("333b4a"))
	Rig.box(radar, Vector3(4.4, 1.4, 0.15), Vector3(0, 0.9, 0), Color("c8d0db"))
	Rig.box(radar, Vector3(0.2, 0.2, 1.2), Vector3(0, 0.9, 0.6), Color("333b4a"))
	Rig.label(self, "ДИСПЕТЧЕРСКАЯ", Vector3(x, 10.0, z + 2.2), 60, Color("2b3345"), false).outline_size = 0

func _bridge(xc: float, nose_z: float) -> void:
	var bx := xc - 3.0
	var shell := _flat(Color("d9dee6"), 0.5, 0.3)
	var tube := Rig.box(self, Vector3(1.7, 1.8, nose_z - 0.6), Vector3(bx, 3.1, (nose_z + 0.6) / 2.0), Color.WHITE)
	tube.material_override = shell
	var band := Rig.box(self, Vector3(1.72, 0.45, nose_z - 0.6), Vector3(bx, 3.35, (nose_z + 0.6) / 2.0), Color.WHITE)
	band.material_override = _glass()
	Rig.cyl(self, 1.1, 1.1, 0.6, Vector3(bx, 3.0, 0.5), Color("aab4c3"), Vector3(90, 0, 0))
	Rig.cyl(self, 1.1, 1.1, 0.6, Vector3(bx, 3.0, nose_z + 0.1), Color("aab4c3"), Vector3(90, 0, 0))
	for k in 4:
		Rig.cyl(self, 1.12, 1.12, 0.1, Vector3(bx, 3.0, nose_z - 0.35 + k * 0.15), Color("5d6a7e"), Vector3(90, 0, 0))
	Rig.box(self, Vector3(1.4, 2.0, 0.08), Vector3(bx, 3.0, nose_z + 0.42), Color("14283f"))
	# опора с тележкой
	Rig.cyl(self, 0.16, 0.16, 2.1, Vector3(bx, 1.05, nose_z - 1.2), Color("e0b020"))
	Rig.box(self, Vector3(1.2, 0.25, 0.7), Vector3(bx, 0.15, nose_z - 1.2), Color("333b4a"))
	for sx in [-1.0, 1.0]:
		Rig.cyl(self, 0.18, 0.18, 0.14, Vector3(bx + sx * 0.5, 0.18, nose_z - 1.2), Color("15181f"), Vector3(0, 0, 90))
	# табличка выхода
	Rig.box(self, Vector3(4.6, 0.9, 0.12), Vector3(xc - 1.5, 5.4, 0.3), Color("14284d"))

func _bridges() -> void:
	for i in GATES.size():
		var xc: float = GATES[i]
		_bridge(xc, 7.0)
		var gate_idx := i - 0
		var l := Rig.label(self, "ВЫХОД  A%d" % (i + 1), Vector3(xc - 1.5, 5.4, 0.4), 60, Color("ffd24d"), false)
		l.pixel_size = 0.012
		l.outline_size = 0

func _belts() -> void:
	for r: Rect2 in Cfg.BELTS:
		var c := Cfg.to3(r.get_center())
		var sz := Vector2(r.size.y * Cfg.K, r.size.x * Cfg.K)
		Rig.box(self, Vector3(sz.x + 0.6, 0.35, sz.y + 0.6), Vector3(c.x, 0.17, c.z), Color("1d222d"))
		Rig.box(self, Vector3(sz.x, 0.08, sz.y), Vector3(c.x, 0.37, c.z), Color("3a4254"))
		var rollers: Array = []
		for k in int(sz.y / 0.33):
			rollers.append(_xf(Vector3(c.x, 0.42, c.z - sz.y / 2.0 + 0.2 + k * 0.33), Vector3(sz.x - 0.1, 0.03, 0.07)))
		_mm(_box_mesh(), rollers, _flat(Color("5a6478"), 0.4, 0.5))
		for sx in [-1.0, 1.0]:
			Rig.box(self, Vector3(0.12, 0.25, sz.y + 0.6), Vector3(c.x + sx * (sz.x / 2.0 + 0.35), 0.45, c.z), Color("e0b020"))
		Rig.box(self, Vector3(sz.x + 1.6, 1.0, 0.14), Vector3(c.x, 2.4, c.z - sz.y / 2.0 - 0.6), Color("1b2a52"))
		Rig.cyl(self, 0.06, 0.06, 2.4, Vector3(c.x - sz.x / 2.0 - 0.6, 1.2, c.z - sz.y / 2.0 - 0.6), Color("333b4a"))
		Rig.cyl(self, 0.06, 0.06, 2.4, Vector3(c.x + sz.x / 2.0 + 0.6, 1.2, c.z - sz.y / 2.0 - 0.6), Color("333b4a"))
		var l := Rig.label(self, "БАГАЖ", Vector3(c.x, 2.4, c.z - sz.y / 2.0 - 0.52), 60, Color("ffd24d"), false)
		l.pixel_size = 0.011
		l.outline_size = 0

func _kiosk(p: Vector2, title: String, roof: Color, icon: String) -> void:
	var c := Cfg.to3(p)
	Rig.box(self, Vector3(3.2, 1.9, 1.7), Vector3(c.x, 0.95, c.z), Color("e8d2a8"))
	Rig.box(self, Vector3(2.5, 0.85, 0.06), Vector3(c.x, 1.1, c.z + 0.87), Color("2b2118"))
	Rig.box(self, Vector3(3.3, 0.08, 0.7), Vector3(c.x, 1.35, c.z + 1.05), Color("c8a77a"))
	var awn: Array = []
	var acols: Array = []
	for k in 8:
		awn.append(_xf(Vector3(c.x - 1.4 + k * 0.4, 2.05, c.z + 0.85), Vector3(0.4, 0.07, 1.5), 0.0))
		acols.append(roof if k % 2 == 0 else Color("f4f4f4"))
	_mm_colored(_box_mesh(), awn, acols, true)
	Rig.box(self, Vector3(3.3, 0.1, 1.8), Vector3(c.x, 1.95, c.z), Color("6b4e32"))
	var l := Rig.label(self, title, Vector3(c.x, 1.55, c.z + 1.1), 40, Color("ffffff"), false)
	l.pixel_size = 0.01
	var it := Rig.item(icon)
	it.position = Vector3(c.x, 2.0, c.z)
	it.scale = Vector3.ONE * 1.4
	add_child(it)

# ---------- стоянки ----------
func _stand(i: int) -> void:
	var y: float = Cfg.ROWS[i]
	var xc := y * Cfg.K
	var z0 := Cfg.PX * Cfg.K
	var paint := _flat(Color("f2c744"), 0.7)
	var white := _flat(Color("e9edf2"), 0.7)
	var red := _flat(Color("c0392b"), 0.7)
	# осевая заруливания, стоп-линия, зона безопасности
	_mm(_box_mesh(), [_xf(Vector3(xc, Y_PAINT, 20.5), Vector3(0.22, 0.03, 27.0))], paint)
	_mm(_box_mesh(), [_xf(Vector3(xc, Y_PAINT, 6.6), Vector3(4.0, 0.03, 0.25))], white)
	var dashes: Array = []
	var t := 6.0
	while t < z0 + 8.6:
		for dx in [-8.5, 8.5]:
			dashes.append(_xf(Vector3(xc + dx, Y_PAINT, t), Vector3(0.14, 0.03, 0.5)))
		t += 1.0
	var x := -8.5
	while x < 8.5:
		dashes.append(_xf(Vector3(xc + x, Y_PAINT, z0 + 8.6), Vector3(0.5, 0.03, 0.14)))
		x += 1.0
	_mm(_box_mesh(), dashes, red)
	# большой номер стоянки на асфальте
	var num := Rig.label(self, "A%d" % (i + 1), Vector3(xc, Y_PAINT + 0.01, 4.2), 200, Color(0.95, 0.96, 0.98, 0.92), false)
	num.rotation_degrees = Vector3(-90, 180, 0)
	num.outline_size = 0
	num.pixel_size = 0.02
	# метки зон работ
	for off in [Cfg.DOOR_OFF, Cfg.FUEL_OFF]:
		var p := Cfg.to3(Vector2(Cfg.PX, y) + off, Y_PAINT + 0.01)
		var tm := TorusMesh.new()
		tm.inner_radius = 0.82
		tm.outer_radius = 0.95
		var ring := MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = _flat(Color("ffd24d") if off == Cfg.DOOR_OFF else Color("ff9f43"), 0.8, 0.0, 0.9)
		ring.position = p
		ring.scale = Vector3(1, 0.04, 1)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	# заправщик у крыла, багажный поезд у люка, наземное питание, тягач
	var fuel := Props.fuel_truck()
	fuel.position = Vector3(xc + 6.8, 0, z0 + 0.8)
	add_child(fuel)
	var train := Props.baggage_train(3)
	train.position = Vector3(xc + 3.4, 0, z0 + 5.6)
	add_child(train)
	var gpu := Props.gpu_cart()
	gpu.position = Vector3(xc - 2.4, 0, 8.6)
	gpu.rotation_degrees.y = 25
	add_child(gpu)
	var tug := Assets.kenney("tractor", 1.25)
	if tug == null:
		tug = Props.pushback_tug()
	tug.position = Vector3(xc - 3.6, 0, 6.0)
	tug.rotation_degrees.y = 160.0
	add_child(tug)
	for off in [Vector2(-8.5, 5.4), Vector2(8.5, 5.4), Vector2(-8.5, z0 + 8.2), Vector2(8.5, z0 + 8.2)]:
		var c := Vector3(xc + off.x, 0, off.y)
		Rig.cyl(self, 0.02, 0.1, 0.3, c + Vector3(0, 0.15, 0), Color("ff6a2a"))
		Rig.cyl(self, 0.05, 0.06, 0.06, c + Vector3(0, 0.18, 0), Color("f4f4f4"))
		Rig.box(self, Vector3(0.25, 0.02, 0.25), c + Vector3(0, 0.01, 0), Color("2b3345"))

# Неигровые выходы: самолёты у телетрапов для масштаба.
func _decor_gates() -> void:
	for i in GATES.size():
		var xc: float = GATES[i]
		if abs(xc - 11.0) < 0.1 or abs(xc - 30.0) < 0.1 or abs(xc - 49.0) < 0.1:
			continue
		var a := Aircraft.new()
		a.ambient = true
		a.model_idx = (i * 2 + 1) % Assets.FLEET.size()
		add_child(a)
		a.position = Vector3(xc, 0, Cfg.PX * Cfg.K)
		a.body.rotation.y = -PI / 2.0
		var fuel := Props.fuel_truck()
		fuel.position = Vector3(xc + 6.8, 0, Cfg.PX * Cfg.K + 0.8)
		add_child(fuel)
		var train := Props.baggage_train(2)
		train.position = Vector3(xc + 3.4, 0, Cfg.PX * Cfg.K + 5.6)
		add_child(train)

func _apron_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var lids: Array = []
	var pits: Array = []
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 12
	for xc in GATES:
		for k in 2:
			lids.append(_xf(Vector3(xc + 4.6 + k * 1.4, Y_PAINT, Cfg.PX * Cfg.K + 0.6), Vector3(0.45, 0.03, 0.45)))
		for k in 3:
			pits.append(_xf(Vector3(xc + rng.randf_range(-6, 6), Y_PAINT, rng.randf_range(9.0, 21.0)), Vector3(0.4, 0.025, 0.4)))
	_mm(cyl, lids, _flat(Color("ffb347"), 0.5, 0.2))
	_mm(cyl, pits, _flat(Color("2b2f38"), 0.6, 0.6))
	# дренажные решётки
	var grates: Array = []
	for k in 30:
		grates.append(_xf(Vector3(-30.0 + k * 6.5, Y_PAINT, 23.8), Vector3(1.2, 0.025, 0.25)))
	_mm(_box_mesh(), grates, _flat(Color("1d2026"), 0.5, 0.6))
	# стоп-линии и «ёлочки» на служебной дороге
	var road: Array = []
	for k in 60:
		road.append(_xf(Vector3(-30.0 + k * 2.4, Y_PAINT, 25.7), Vector3(1.2, 0.03, 0.12)))
	_mm(_box_mesh(), road, _flat(Color("e9edf2"), 0.7))

func _taxiways_and_runway() -> void:
	var yel := _flat(Color("f2c744"), 0.7)
	var wht := _flat(Color("eef1f6"), 0.7)
	# рулёжка A: осевая и огни по краям
	_mm(_box_mesh(), [_xf(Vector3(CX, Y_PAINT, 34.0), Vector3(620.0, 0.03, 0.16))], yel)
	_mm(_box_mesh(), [_xf(Vector3(CX, Y_PAINT, 150.0), Vector3(1000.0, 0.03, 0.16))], yel)
	var blue: Array = []
	for z in [34.0, 150.0]:
		var x := -250.0
		while x < 350.0:
			blue.append(_xf(Vector3(x, 0.1, z - 3.6), Vector3(0.18, 0.18, 0.18)))
			blue.append(_xf(Vector3(x, 0.1, z + 3.6), Vector3(0.18, 0.18, 0.18)))
			x += 7.0
	_mm(_sphere_mesh(), blue, _flat(Color("4da3ff"), 0.4, 0.0, 3.0))
	# линия удержания перед полосой
	for k in 4:
		_mm(_box_mesh(), [_xf(Vector3(-90.0, Y_PAINT, 90.0 + k * 0.4), Vector3(7.0, 0.03, 0.1))], yel)
	# полоса: кромки, осевая, торцевые полосы, зона приземления, огни, PAPI
	var re: Array = []
	for sz in [-1.0, 1.0]:
		re.append(_xf(Vector3(CX + 50.0, Y_PAINT + 0.005, RUNWAY_Z + sz * 7.1), Vector3(1000.0, 0.03, 0.2)))
	_mm(_box_mesh(), re, wht)
	var cl: Array = []
	var x := -450.0
	while x < 550.0:
		cl.append(_xf(Vector3(x, Y_PAINT + 0.005, RUNWAY_Z), Vector3(6.0, 0.03, 0.3)))
		x += 12.0
	_mm(_box_mesh(), cl, wht)
	var thr: Array = []
	for k in 12:
		thr.append(_xf(Vector3(-140.0, Y_PAINT + 0.005, RUNWAY_Z - 6.0 + k * 1.1), Vector3(9.0, 0.03, 0.45)))
	_mm(_box_mesh(), thr, wht)
	var tdz: Array = []
	for k in 6:
		for sz in [-1.0, 1.0]:
			tdz.append(_xf(Vector3(-100.0 + k * 22.0 - 12.0 * 0.0, Y_PAINT + 0.005, RUNWAY_Z + sz * (3.2 + (k % 3) * 0.7)), Vector3(7.0 + (3 - k % 3) * 1.5, 0.03, 0.9)))
	_mm(_box_mesh(), tdz, wht)
	var rl: Array = []
	x = -450.0
	while x < 550.0:
		rl.append(_xf(Vector3(x, 0.1, RUNWAY_Z - 7.6), Vector3(0.22, 0.22, 0.22)))
		rl.append(_xf(Vector3(x, 0.1, RUNWAY_Z + 7.6), Vector3(0.22, 0.22, 0.22)))
		x += 9.0
	_mm(_sphere_mesh(), rl, _flat(Color("fff2b0"), 0.4, 0.0, 3.0))
	# огни приближения (столбы по оси за порогом)
	var poles: Array = []
	var plamps: Array = []
	for k in 30:
		var px := -142.0 - k * 10.0
		poles.append(_xf(Vector3(px, 0.6, RUNWAY_Z), Vector3(0.12, 1.2, 0.12)))
		plamps.append(_xf(Vector3(px, 1.25, RUNWAY_Z), Vector3(0.3, 0.12, 2.4 if k % 5 == 0 else 0.5)))
	_mm(_box_mesh(), poles, _flat(Color("9aa4b3"), 0.5, 0.5))
	_mm(_box_mesh(), plamps, _flat(Color("ffe9a8"), 0.4, 0.0, 3.0))
	# PAPI
	for k in 4:
		Rig.box(self, Vector3(0.6, 0.5, 0.5), Vector3(-120.0, 0.25, RUNWAY_Z - 9.0 - k * 1.0), Color("e63946") if k < 2 else Color("f4f4f4"), Vector3.ZERO, 1.4)
	var n9 := Rig.label(self, "09", Vector3(-112.0, Y_PAINT + 0.01, RUNWAY_Z), 400, Color(0.95, 0.96, 0.98, 0.95), false)
	n9.rotation_degrees = Vector3(-90, 180, 0)
	n9.outline_size = 0
	n9.pixel_size = 0.025
	# указатели рулёжки
	for g in [11.0, 30.0, 49.0]:
		var sgn := Props.taxi_sign("A%d" % int((g - 11.0) / 19.0 + 1.0))
		sgn.position = Vector3(g, 0, 38.9)
		sgn.rotation_degrees.y = 180
		add_child(sgn)

# Служебная дорога вдоль перрона: техника, контейнеры, автобусы — стоят в линию.
func _service_road() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var items := [
		["bus", -14.0], ["train", -2.0], ["bus", 40.0], ["stairs", 24.0], ["cat", 55.0], ["train", 66.0], ["cat", 4.0], ["stairs", 76.0],
	]
	for it in items:
		var n: Node3D
		match it[0]:
			"bus": n = Props.bus()
			"train": n = Props.baggage_train(3)
			"stairs": n = Props.stairs_truck()
			_: n = Props.catering_truck()
		n.position = Vector3(it[1], 0, 27.0)
		n.rotation_degrees.y = 90.0 if rng.randf() < 0.5 else -90.0
		add_child(n)
	# грузовые контейнеры ULD
	var uld: Array = []
	var ucol: Array = []
	for k in 16:
		uld.append(_xf(Vector3(-20.0 + (k % 8) * 1.0 + 60.0 * (k / 8), 0.4, 28.4 + (k % 2) * 0.9), Vector3(0.9, 0.8, 0.9)))
		ucol.append(Color("aab4c3").lerp(Color("6a7a90"), rng.randf()))
	_mm_colored(_box_mesh(), uld, ucol, true)

func _kenney_vehicles() -> void:
	var spots := [
		["firetruck", 3.2, Vector3(104.0, 0, 8.0), 90.0], ["ambulance", 2.0, Vector3(104.0, 0, 12.0), 90.0], ["delivery", 2.2, Vector3(104.0, 0, 16.0), 90.0],
		["taxi", 1.5, Vector3(-24.0, 0, 6.0), -90.0], ["police", 1.55, Vector3(-24.0, 0, 9.0), -90.0], ["van", 1.7, Vector3(-24.0, 0, 12.0), -90.0],
		["truck", 2.0, Vector3(-24.0, 0, 16.0), -90.0], ["garbage-truck", 2.1, Vector3(104.0, 0, 20.0), 90.0],
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
		[Vector2(-10.0, 26.0), Vector2(70.0, 26.0)],
		[Vector2(14.0, 3.0), Vector2(50.0, 3.0)],
		[Vector2(20.0, 8.0), Vector2(20.0, 18.0)],
		[Vector2(40.0, 8.0), Vector2(40.0, 18.0)],
		[Vector2(11.0 + 6.8, z0 + 2.8), Vector2(11.0 + 6.8, z0 + 4.8)],
		[Vector2(30.0 + 6.8, z0 + 2.8), Vector2(30.0 + 6.8, z0 + 4.8)],
		[Vector2(49.0 + 6.8, z0 + 2.8), Vector2(49.0 + 6.8, z0 + 4.8)],
		[Vector2(11.0, 5.4), Vector2(11.0, 5.4)],
		[Vector2(30.0, 5.4), Vector2(30.0, 5.4)],
		[Vector2(49.0, 5.4), Vector2(49.0, 5.4)],
		[Vector2(14.5, 12.0), Vector2(26.0, 12.0), Vector2(26.0, 22.0)],
		[Vector2(34.0, 22.0), Vector2(46.0, 22.0), Vector2(46.0, 12.0)],
		[Vector2(104.0, 11.0), Vector2(104.0, 11.0)],
		[Vector2(-23.0, 14.0), Vector2(-23.0, 14.0)],
		[Vector2(6.0, 18.0), Vector2(6.0, 8.0), Vector2(2.0, 12.0)],
		[Vector2(56.0, 8.0), Vector2(56.0, 20.0)],
	]
	for i in routes.size():
		var w := Assets.worker(vests[i % 4], hats[(i + 1) % 4], skins[(i + 2) % 4])
		if w == null:
			return
		w.set_meta("nobake", true)
		var pts: Array = routes[i]
		w.position = Vector3(pts[0].x, 0, pts[0].y)
		add_child(w)
		var ap := Assets.play(w, "Walk" if pts.size() > 1 else "Idle")
		crew.append({"node": w, "pts": pts, "i": 0, "wait": randf_range(0.0, 3.0), "ap": ap, "speed": randf_range(0.45, 0.65), "walking": pts.size() > 1})

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
		var step: Vector2 = d.normalized() * c.speed * delta
		w.position += Vector3(step.x, 0, step.y)
		w.rotation.y = lerp_angle(w.rotation.y, atan2(d.x, d.y), minf(1.0, delta * 8.0))

func _extras() -> void:
	# мачты освещения вдоль перрона
	for x in range(-30, 100, 20):
		var m := Props.light_mast(8.0)
		m.position = Vector3(x + 5.0, 0, 23.0)
		m.rotation_degrees.y = 180
		add_child(m)
	for p in [Vector3(130.0, 0, 41.0), Vector3(-70.0, 0, 41.0)]:
		var w := Props.windsock()
		w.position = p
		add_child(w)
	# флагштоки у терминала
	for x in [-38.0, 98.0]:
		Rig.cyl(self, 0.08, 0.1, 12.0, Vector3(x, 6.0, 9.0), Color("c8ced8"))
		Rig.box(self, Vector3(3.2, 1.9, 0.05), Vector3(x + 1.7, 11.0, 9.0), Color("e63946") if x < 20 else Color("2a6fd6"))
		Rig.box(self, Vector3(3.2, 0.63, 0.06), Vector3(x + 1.7, 11.0, 9.0), Color("f4f4f4"))
	# оборудование на крыше
	var ac: Array = []
	for x in range(-30, 92, 11):
		ac.append(_xf(Vector3(x, 8.2, -9.0), Vector3(4.6, 1.4, 3.2)))
	_mm(_box_mesh(), ac, _flat(Color("aab4c3"), 0.5, 0.3), true)
	# облака
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 40:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-600, 700), rng.randf_range(160, 320), rng.randf_range(300, 1500))
		add_child(c)
		for j in 6:
			var s := Rig.sphere(c, rng.randf_range(20.0, 40.0), Vector3(j * 28.0 - 70.0, rng.randf_range(-4, 4), rng.randf_range(-8, 8)), Color(1, 1, 1, 0.94), Vector3(1.0, 0.45, 0.8))
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(s.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

# ---------- далёкий аэропорт: второй терминал, ангары, цистерны, парковка, шоссе ----------
func _far_airport() -> void:
	var t := Assets.load_scene(Assets.TERMINAL)
	if t != null:
		var b := Assets.bounds(t)
		var k := 150.0 / maxf(b.size.x, 0.0001)
		var wrap := Node3D.new()
		wrap.add_child(t)
		t.scale = t.scale * k
		var c := b.get_center()
		t.position = Vector3(-c.x * k, -b.position.y * k, -c.z * k)
		wrap.position = Vector3(CX + 30.0, 0.0, 232.0)
		wrap.rotation_degrees.y = 180.0
		add_child(wrap)
	for p in [[CX - 70.0, 196.0, 0], [CX + 10.0, 196.0, 2], [CX + 80.0, 196.0, 1]]:
		var a := Aircraft.new()
		a.ambient = true
		a.model_idx = p[2]
		add_child(a)
		a.position = Vector3(p[0], 0, p[1])
		a.body.rotation.y = -PI / 2.0 + randf_range(-0.12, 0.12)
	for k in 8:
		var x := -160.0 + (k % 4) * 26.0
		var z := 270.0 + (k / 4) * 26.0
		Rig.cyl(self, 10.0, 10.0, 14.0, Vector3(x, 7.0, z), Color("e8ecf1"))
		Rig.cyl(self, 10.1, 10.1, 2.0, Vector3(x, 10.0, z), Color("e63946"))
		Rig.cyl(self, 10.2, 9.0, 1.0, Vector3(x, 14.2, z), Color("c8ced8"))
	for h in [[-190.0, 250.0, 60.0, 20.0, 40.0], [-120.0, 240.0, 46.0, 17.0, 34.0], [CX + 180.0, 250.0, 70.0, 22.0, 44.0], [CX + 270.0, 240.0, 52.0, 19.0, 38.0]]:
		Rig.box(self, Vector3(h[2], h[3], h[4]), Vector3(h[0], h[3] / 2.0, h[1]), Color("aeb7c4"))
		Rig.cyl(self, h[3] * 0.55, h[3] * 0.55, h[2], Vector3(h[0], h[3], h[1]), Color("8d97a6"), Vector3(0, 0, 90))
		Rig.box(self, Vector3(h[2] * 0.5, h[3] * 0.8, 0.3), Vector3(h[0], h[3] * 0.4, h[1] - h[4] / 2.0 - 0.1), Color("39465c"))
	var hl := Rig.label(self, "АНГАР №3", Vector3(-190.0, 13.0, 250.0 - 20.2), 200, Color("ffd24d"), false)
	hl.pixel_size = 0.04
	# шоссе, парковка
	_plane(Vector2(2400, 22), Vector3(CX, 0.01, 330.0), _flat(Color("2e3238"), 0.8))
	var lane: Array = []
	for i in 160:
		lane.append(_xf(Vector3(-1000.0 + i * 12.0, 0.05, 330.0), Vector3(5.0, 0.03, 0.4)))
	_mm(_box_mesh(), lane, _flat(Color("f4f4f4"), 0.7))
	_plane(Vector2(160, 70), Vector3(CX + 40.0, 0.012, 300.0), Tex.material(Tex.asphalt(256, 0.25), Vector2(110, 50), 0.6, 0.6))
	var cars := ["sedan", "suv", "hatchback-sports", "taxi", "van", "police", "delivery", "truck", "sedan-sports", "ambulance"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for r in 5:
		for k in 24:
			if rng.randf() < 0.3:
				continue
			var v := Assets.kenney(cars[rng.randi() % cars.size()], 1.6)
			if v == null:
				continue
			v.position = Vector3(CX - 30.0 + k * 3.0, 0, 280.0 + r * 9.0)
			v.rotation_degrees.y = 90.0 if r % 2 == 0 else -90.0
			add_child(v)
	for k in 36:
		var v := Assets.kenney(cars[rng.randi() % cars.size()], 1.6)
		if v == null:
			continue
		var lane_s := 1.0 if k % 2 == 0 else -1.0
		v.position = Vector3(rng.randf_range(-400.0, 450.0), 0, 330.0 + 4.5 * lane_s)
		v.rotation_degrees.y = 90.0 * lane_s
		add_child(v)

# ---------- пригород, лес, небоскрёбы, горы ----------
func _suburbs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var wall_cols := [Color("e8d9b8"), Color("cdb99a"), Color("d9a98a"), Color("b8c4cf"), Color("e6e1d4"), Color("c7d3b4")]
	var roof_cols := [Color("a8483a"), Color("6a4b3a"), Color("4a5568"), Color("8d3a2a"), Color("3c4a5c")]
	var bodies: Array = []
	var bcols: Array = []
	var roofs: Array = []
	var rcols: Array = []
	for gx in range(-700, 800, 10):
		for gz in range(420, 980, 11):
			if rng.randf() < 0.2:
				continue
			var x := gx + rng.randf_range(-1.6, 1.6)
			var z := gz + rng.randf_range(-1.6, 1.6)
			var w := rng.randf_range(2.6, 4.0)
			var d := rng.randf_range(3.0, 4.6)
			var h := rng.randf_range(1.4, 2.4) * (1.0 if rng.randf() < 0.85 else 2.6)
			var yaw := (PI / 2.0 if rng.randf() < 0.5 else 0.0)
			bodies.append(_xf(Vector3(x, h / 2.0, z), Vector3(w, h, d), yaw))
			bcols.append(wall_cols[rng.randi() % wall_cols.size()])
			var rh := rng.randf_range(0.8, 1.3)
			roofs.append(_xf(Vector3(x, h + rh / 2.0 - 0.02, z), Vector3(w * 1.1, rh, d * 1.08), yaw))
			rcols.append(roof_cols[rng.randi() % roof_cols.size()])
	var pm := PrismMesh.new()
	pm.size = Vector3.ONE
	_mm_colored(_box_mesh(), bodies, bcols)
	_mm_colored(pm, roofs, rcols)
	for gz in range(415, 985, 11):
		Rig.box(self, Vector3(1600.0, 0.04, 2.2), Vector3(CX, 0.02, gz + 5.5), Color("34383f"))
	# леса: ёлки и лиственные
	var trunks: Array = []
	var tcols: Array = []
	var cones: Array = []
	var ccols: Array = []
	var balls: Array = []
	var bcol2: Array = []
	for i in 5200:
		var x := rng.randf_range(-800.0, 900.0)
		var z := rng.randf_range(125.0, 1100.0)
		if z > 318.0 and z < 342.0:
			continue
		if z > 405.0 and z < 990.0 and rng.randf() < 0.9:
			continue
		if z > 170.0 and z < 320.0 and x > -230.0 and x < 320.0:
			continue
		if z < 160.0 and abs(x - CX) < 180.0 and z > 118.0 and z < 140.0:
			continue
		var h := rng.randf_range(4.0, 9.0)
		trunks.append(_xf(Vector3(x, h * 0.12, z), Vector3(0.35, h * 0.24, 0.35)))
		tcols.append(Color("5b3a22"))
		if rng.randf() < 0.6:
			cones.append(_xf(Vector3(x, h * 0.24 + h * 0.4, z), Vector3(h * 0.38, h * 0.8, h * 0.38)))
			ccols.append(Color("2f6b3a").lerp(Color("3f8a45"), rng.randf()))
		else:
			balls.append(_xf(Vector3(x, h * 0.5, z), Vector3(h * 0.55, h * 0.5, h * 0.55)))
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
	_mm_colored(tr, trunks, tcols)
	_mm_colored(cn, cones, ccols)
	_mm_colored(_sphere_mesh(), balls, bcol2)
	# небоскрёбы города на горизонте
	var tw: Array = []
	var twc: Array = []
	for i in 70:
		var x := rng.randf_range(-700.0, 800.0)
		var z := rng.randf_range(1150.0, 1400.0)
		var h := rng.randf_range(25.0, 100.0)
		var w := rng.randf_range(8.0, 18.0)
		tw.append(_xf(Vector3(x, h / 2.0, z), Vector3(w, h, w * rng.randf_range(0.8, 1.4))))
		twc.append(Color("9fb4c8").lerp(Color("4d6a89"), rng.randf()))
	_mm_colored(_box_mesh(), tw, twc, false)
	# горы
	for k in 10:
		var s := Rig.sphere(self, 1.0, Vector3(-900.0 + k * 220.0, -20.0, rng.randf_range(2100.0, 2500.0)), Color("6d8f78").lerp(Color("8aa09a"), rng.randf()), Vector3(rng.randf_range(260, 420), rng.randf_range(160, 300), rng.randf_range(160, 300)))
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- самолёты на полосе ----------
func _process(delta: float) -> void:
	_crew_update(delta)
	if radar != null:
		radar.rotation.y += delta * 1.6
	fly_t -= delta
	if fly_t <= 0.0:
		fly_t = randf_range(10.0, 20.0)
		_spawn_flyby()
	for f in flybys.duplicate():
		f.t += delta
		var node: Aircraft = f.node
		var u: float = f.t / f.dur
		var x: float
		var y: float
		if f.mode == "land":
			x = lerpf(-260.0, 360.0, ease_out(u))
			y = maxf(0.0, 14.0 * (1.0 - u / 0.2))
		else:
			x = lerpf(-260.0, 360.0, ease_in(u))
			y = maxf(0.0, (u - 0.55) * 160.0)
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
	flybys.append({"node": a, "t": 0.0, "dur": randf_range(14.0, 18.0), "mode": ["land", "takeoff"].pick_random(), "dir": dir, "lane": -1.2 if dir > 0 else 1.2})
