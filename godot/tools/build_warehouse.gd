@tool
extends SceneTree
## Генерирует res://scenes/locations/warehouse.tscn: локация 3 «Темнота» (заброшенный склад на промзоне, ночь).
## Запуск: godot --headless --path godot --script res://tools/build_warehouse.gd
##
## План (X на восток, Z на юг, ворота погрузки на южной стене у x=26):
##   ангар 68×40, стены 10 м, двускатная кровля с дырами (лунные пятна и лучи), фермы, три ряда стеллажей по X
##   (R1 z=-15, R2 z=-4, R3 z=7), проходы A0 и A1, свободная зона погрузки на востоке, контора-антресоль нет.
##   Лёгкая: кот в картонном форте у (8,12). Средняя: кот на полке R3 (y=4.2), на пандусе из зоны погрузки.
##   Сложная: кот на верху R1 (y=6.25): по полке R3 на запад, переход по галерее вдоль западной стены и подъём.
## Опасности: тир 0 электрощит у южной стены и погрузчик-призрак в зоне погрузки; тир 1 падающие ящики и бочки на колёсах;
## тир 2 второй погрузчик в проходе A1 и часть ламп выключена (мета tier_max=1 у «запасных» ламп).

const U := preload("res://scripts/location/loc_util.gd")

var root_node: Node3D
var rng := RandomNumberGenerator.new()
var _mesh_cache := {}
var _shape_cache := {}

const HX := 34.0       # половина длины ангара
const HZ := 20.0       # половина ширины
const WALL_H := 10.0
const RIDGE := 13.0
const SPAWN := Vector3(29.0, 0.0, 15.5)

const C_METAL := Color(0.44, 0.47, 0.5)
const C_RUST := Color(0.5, 0.3, 0.18)
const C_CONC := Color(0.45, 0.45, 0.43)
const C_BLUE := Color(0.14, 0.28, 0.55)
const C_ORANGE := Color(0.85, 0.42, 0.1)
const C_CARD := Color(0.7, 0.54, 0.34)
const C_YELLOW := Color(0.9, 0.75, 0.15)

var _moon_dir := Vector3.DOWN


func _init() -> void:
	rng.seed = 7007
	root_node = Node3D.new()
	root_node.name = "Warehouse"
	root_node.set_script(load("res://scripts/location/location.gd"))
	root_node.set("title_key", "LOC_WAREHOUSE")
	root_node.set("kill_height", -9.0)
	U.rounded = false
	_environment()
	_yard()
	_shell()
	_lamps()
	_racks()
	_clutter()
	_routes()
	_signs()
	_hazards()
	_cat()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/warehouse.tscn")
	root_node.free()
	quit(0 if err == OK else 1)


# ---------- кирпичики с кэшем мешей (без раздувания .tscn) ----------

func _bmesh(size: Vector3) -> BoxMesh:
	var key := "%0.3f_%0.3f_%0.3f" % [size.x, size.y, size.z]
	if not _mesh_cache.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_mesh_cache[key] = bm
	return _mesh_cache[key]


func _bshape(size: Vector3) -> BoxShape3D:
	var key := "%0.3f_%0.3f_%0.3f" % [size.x, size.y, size.z]
	if not _shape_cache.has(key):
		var bs := BoxShape3D.new()
		bs.size = size
		_shape_cache[key] = bs
	return _shape_cache[key]


## Коробка без коллизии (визуал). kind задаёт текстуру.
func _vb(parent: Node, nm: String, size: Vector3, col: Color, pos: Vector3, kind := "paint", rough := 0.85, metal := 0.0) -> MeshInstance3D:
	var old := U.kind
	U.kind = kind
	var mi := MeshInstance3D.new()
	mi.mesh = _bmesh(size)
	mi.material_override = U.mat(col, rough, metal)
	U.kind = old
	return U.add(parent, mi, nm, pos) as MeshInstance3D


## Твёрдая коробка: StaticBody3D + общий меш и форма.
func _sb(parent: Node, nm: String, size: Vector3, col: Color, pos: Vector3, kind := "paint", rough := 0.85, metal := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	U.add(parent, body, nm, pos)
	_vb(body, "Mesh", size, col, Vector3.ZERO, kind, rough, metal)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(size)
	body.add_child(cs)
	return body


## Невидимый блок коллизии.
func _block(parent: Node, nm: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	U.add(parent, body, nm, pos)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(size)
	body.add_child(cs)
	return body


func _holder(nm: String, pos := Vector3.ZERO) -> Node3D:
	var h := Node3D.new()
	U.add(root_node, h, nm, pos)
	return h


func _hazard(n: Node, tier: int, tier_max := 2) -> void:
	n.add_to_group("hazard", true)
	n.set_meta("tier", tier)
	if tier_max < 2:
		n.set_meta("tier_max", tier_max)


func _emissive(col: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "em_%s_%s" % [col.to_html(), energy]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	_mesh_cache[key] = m
	return m


func _glow(parent: Node, nm: String, r: float, col: Color, pos: Vector3, energy := 2.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _emissive(col, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return U.add(parent, mi, nm, pos) as MeshInstance3D


# ---------- ночь ----------

func _environment() -> void:
	U.environment(root_node, Color(0.02, 0.03, 0.08), Color(0.2, 0.14, 0.15), Color(0.55, 0.68, 1.0), Vector3(-58, 28, 0), 0.006, 0.12)
	var sun := root_node.get_node("Sun") as DirectionalLight3D
	sun.light_energy = 0.55
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_blur = 1.2
	_moon_dir = (Basis.from_euler(sun.rotation) * Vector3(0, 0, -1)).normalized()
	var env := (root_node.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.tonemap_exposure = 1.1
	env.fog_light_color = Color(0.16, 0.13, 0.17)
	env.ssao_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	# Луна и звёзды
	var moon_pos := -_moon_dir * 700.0
	var moon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 26.0
	sm.height = 52.0
	moon.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(0.95, 0.97, 1.0)
	moon.material_override = mm
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(root_node, moon, "Moon", moon_pos)
	var stars := MultiMesh.new()
	stars.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(3.0, 3.0)
	var sm2 := StandardMaterial3D.new()
	sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm2.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm2.albedo_color = Color(1.0, 1.0, 0.95)
	qm.material = sm2
	stars.mesh = qm
	stars.instance_count = 380
	for i in 380:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.08, 1.0), rng.randf_range(-1, 1)).normalized()
		var s := rng.randf_range(0.4, 1.4)
		stars.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), d * 820.0))
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = stars
	smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(root_node, smi, "Stars")


# ---------- двор: асфальт, забор, фуры, контейнеры, лес по краям ----------

func _yard() -> void:
	var y := _holder("Yard")
	var old := U.kind
	U.kind = "bitumen"
	_sb(y, "Ground", Vector3(900, 1.0, 900), Color(0.2, 0.2, 0.22), Vector3(0, -0.5 - 0.02, 0), "bitumen", 0.9)
	U.kind = "grass"
	for i in 14:
		var a := TAU * i / 14.0
		_vb(y, "Meadow%d" % i, Vector3(rng.randf_range(40, 90), 0.05, rng.randf_range(30, 60)), Color(0.14, 0.2, 0.14), Vector3(cos(a) * 95.0, 0.03, sin(a) * 95.0), "grass", 0.95)
	# Бетонная площадка перед воротами, разметка, лужи
	_vb(y, "Apron", Vector3(70, 0.06, 26), Color(0.32, 0.32, 0.33), Vector3(8, 0.04, 33), "concrete", 0.9)
	for i in 8:
		_vb(y, "Line%d" % i, Vector3(0.18, 0.02, 6.0), Color(0.9, 0.78, 0.15), Vector3(-8.0 + i * 5.5, 0.08, 31.0))
	var puddle := StandardMaterial3D.new()
	puddle.albedo_color = Color(0.1, 0.13, 0.2, 0.75)
	puddle.metallic = 0.7
	puddle.roughness = 0.05
	puddle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 7:
		var pm := CylinderMesh.new()
		var r := rng.randf_range(1.2, 3.2)
		pm.top_radius = r
		pm.bottom_radius = r
		pm.height = 0.01
		pm.radial_segments = 18
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = puddle
		mi.scale = Vector3(rng.randf_range(1.0, 1.8), 1.0, 1.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.add(y, mi, "Puddle%d" % i, Vector3(rng.randf_range(0, 40), 0.1, rng.randf_range(24, 40)))
	# Забор: бетонные плиты со столбами и колючкой, ворота в проёме
	U.kind = "concrete"
	var fz := 58.0
	for i in 26:
		var x := -62.0 + i * 5.0
		if absf(x - 28.0) < 6.5:
			continue
		_sb(y, "FencePanel%d" % i, Vector3(4.8, 3.0, 0.2), Color(0.55, 0.54, 0.5), Vector3(x, 1.5, fz), "concrete")
		_vb(y, "FenceCap%d" % i, Vector3(4.9, 0.12, 0.3), Color(0.4, 0.4, 0.4), Vector3(x, 3.05, fz), "concrete")
		for k in 3:
			var wx := x - 2.2 + k * 2.2
			_vb(y, "Barb%d_%d" % [i, k], Vector3(0.03, 0.45, 0.03), Color(0.2, 0.2, 0.22), Vector3(wx, 3.35, fz), "metal")
		_vb(y, "Wire%d" % i, Vector3(4.8, 0.02, 0.02), Color(0.25, 0.25, 0.27), Vector3(x, 3.5, fz), "metal")
	# Створки ворот приоткрыты
	U.kind = "metal"
	_sb(y, "GateL", Vector3(0.12, 2.8, 3.0), Color(0.35, 0.42, 0.3), Vector3(24.0, 1.4, fz + 1.5), "metal")
	_sb(y, "GateR", Vector3(0.12, 2.8, 3.0), Color(0.35, 0.42, 0.3), Vector3(32.0, 1.4, fz + 1.5), "metal")
	# Прожектор на мачте у ворот: оранжевый натрий
	var pole := _holder("FloodPole", Vector3(18.0, 0, 26.0))
	_vb(pole, "Pole", Vector3(0.25, 11.0, 0.25), Color(0.3, 0.3, 0.32), Vector3(0, 5.5, 0), "metal")
	_vb(pole, "Arm", Vector3(2.2, 0.15, 0.15), Color(0.3, 0.3, 0.32), Vector3(0.9, 11.0, 0))
	_glow(pole, "Lamp", 0.3, Color(1.0, 0.65, 0.3), Vector3(1.9, 10.8, 0), 4.0)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.7, 0.4)
	fl.light_energy = 3.2
	fl.omni_range = 32.0
	fl.shadow_enabled = true
	U.add(pole, fl, "Light", Vector3(1.9, 10.4, 0))
	# Ещё один фонарь у восточного угла
	var pole2 := _holder("FloodPole2", Vector3(46.0, 0, 8.0))
	_vb(pole2, "Pole", Vector3(0.25, 10.0, 0.25), Color(0.3, 0.3, 0.32), Vector3(0, 5.0, 0), "metal")
	_glow(pole2, "Lamp", 0.3, Color(1.0, 0.65, 0.3), Vector3(0, 10.1, 0), 4.0)
	var fl2 := OmniLight3D.new()
	fl2.light_color = Color(1.0, 0.72, 0.45)
	fl2.light_energy = 2.4
	fl2.omni_range = 26.0
	U.add(pole2, fl2, "Light", Vector3(0, 9.8, 0))
	# Фура у погрузочной рампы и контейнеры
	_truck(y, Vector3(46.0, 0, -6.0), 90.0)
	_container(y, Vector3(-52.0, 0, 30.0), 0.0, Color(0.7, 0.2, 0.15))
	_container(y, Vector3(-52.0, 2.6, 30.0), 0.0, Color(0.15, 0.4, 0.6))
	_container(y, Vector3(-44.0, 0, 34.0), 20.0, Color(0.25, 0.5, 0.3))
	_container(y, Vector3(0.0, 0, 46.0), 0.0, Color(0.8, 0.6, 0.15))
	_container(y, Vector3(8.0, 0, 46.0), 0.0, Color(0.6, 0.6, 0.62))
	_container(y, Vector3(52.0, 0, 30.0), 90.0, Color(0.6, 0.2, 0.2))
	# Бочки и поддоны у стены, мусорные баки
	for i in 6:
		_barrel(y, Vector3(-30.0 + i * 0.75, 0.0, 22.2), [Color(0.15, 0.3, 0.6), Color(0.75, 0.2, 0.15), Color(0.2, 0.45, 0.25)][i % 3])
	for i in 3:
		_sb(y, "Dumpster%d" % i, Vector3(1.8, 1.2, 1.1), Color(0.15, 0.35, 0.2), Vector3(-10.0 + i * 2.2, 0.6, 22.0), "metal")
	# Далёкая промзона: трубы, градирня, ЛЭП, чёрный лес
	_far_industry()
	# Чёрный лес по кругу: ели и сухостой
	for i in 120:
		var a := rng.randf() * TAU
		var r := rng.randf_range(80.0, 240.0)
		var t := Node3D.new()
		t.set_script(load("res://scripts/location/forest/forest_prop.gd"))
		t.set("species", "spruce" if rng.randf() < 0.75 else "deadspruce")
		U.add(y, t, "Tree%d" % i, Vector3(cos(a) * r, 0.0, sin(a) * r))
		t.scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
		t.rotation_degrees.y = rng.randf() * 360.0
	U.kind = old


func _barrel(parent: Node, pos: Vector3, col: Color) -> void:
	var b := StaticBody3D.new()
	U.add(parent, b, "Barrel", pos + Vector3(0, 0.45, 0))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.9
	cm.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var old := U.kind
	U.kind = "metal"
	mi.material_override = U.mat(col, 0.5, 0.4)
	U.kind = old
	U.add(b, mi, "Mesh")
	for yy in [-0.2, 0.2]:
		var rm := CylinderMesh.new()
		rm.top_radius = 0.31
		rm.bottom_radius = 0.31
		rm.height = 0.03
		rm.radial_segments = 14
		var ri := MeshInstance3D.new()
		ri.mesh = rm
		ri.material_override = U.mat(col.darkened(0.3), 0.5, 0.4)
		U.add(b, ri, "Ring", Vector3(0, yy, 0))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.3
	sh.height = 0.9
	cs.shape = sh
	b.add_child(cs)


func _container(parent: Node, pos: Vector3, yaw: float, col: Color) -> void:
	var c := Node3D.new()
	U.add(parent, c, "Container", pos)
	c.rotation_degrees.y = yaw
	var body := _sb(c, "Body", Vector3(6.0, 2.5, 2.4), col, Vector3(0, 1.25, 0), "metal", 0.6, 0.2)
	for i in 14:
		_vb(c, "Rib%d" % i, Vector3(0.1, 2.4, 0.06), col.darkened(0.2), Vector3(-2.8 + i * 0.43, 1.25, 1.22), "metal")
		_vb(c, "RibB%d" % i, Vector3(0.1, 2.4, 0.06), col.darkened(0.2), Vector3(-2.8 + i * 0.43, 1.25, -1.22), "metal")
	_vb(c, "Door", Vector3(0.06, 2.3, 2.2), col.darkened(0.15), Vector3(3.02, 1.25, 0), "metal")
	for k in [-0.8, -0.3, 0.3, 0.8]:
		_vb(c, "Bar", Vector3(0.1, 2.2, 0.05), Color(0.6, 0.6, 0.62), Vector3(3.07, 1.25, k * 0.7), "metal")


func _truck(parent: Node, pos: Vector3, yaw: float) -> void:
	var t := Node3D.new()
	U.add(parent, t, "Truck", pos)
	t.rotation_degrees.y = yaw
	_sb(t, "Trailer", Vector3(2.5, 3.0, 11.0), Color(0.85, 0.86, 0.88), Vector3(0, 2.4, -3.0), "metal", 0.6, 0.2)
	_sb(t, "Chassis", Vector3(2.2, 0.35, 11.0), Color(0.15, 0.15, 0.17), Vector3(0, 0.75, -3.0), "metal")
	_sb(t, "Cab", Vector3(2.5, 2.4, 2.4), Color(0.7, 0.15, 0.12), Vector3(0, 1.9, 4.2), "metal", 0.5, 0.3)
	_vb(t, "Hood", Vector3(2.4, 1.0, 1.4), Color(0.7, 0.15, 0.12), Vector3(0, 1.3, 5.8), "metal", 0.5, 0.3)
	_vb(t, "Windshield", Vector3(2.3, 0.9, 0.05), Color(0.18, 0.25, 0.3), Vector3(0, 2.4, 5.43), "paint", 0.1, 0.5)
	_glow(t, "HeadL", 0.18, Color(1.0, 0.95, 0.75), Vector3(-0.8, 1.2, 6.55), 2.5)
	_glow(t, "HeadR", 0.18, Color(1.0, 0.95, 0.75), Vector3(0.8, 1.2, 6.55), 2.5)
	for z in [-7.0, -5.8, -0.5, 3.6]:
		for s in [-1.0, 1.0]:
			var w := CylinderMesh.new()
			w.top_radius = 0.55
			w.bottom_radius = 0.55
			w.height = 0.4
			w.radial_segments = 16
			var mi := MeshInstance3D.new()
			mi.mesh = w
			mi.material_override = U.mat(Color(0.07, 0.07, 0.08), 0.95)
			U.add(t, mi, "Wheel", Vector3(s * 1.1, 0.55, z))
			mi.rotation_degrees.z = 90


func _far_industry() -> void:
	var f := _holder("FarIndustry")
	var old := U.kind
	U.kind = "concrete"
	# Дымовые трубы и градирни с красными огнями
	for i in 5:
		var a := rng.randf_range(0.2, 2.9) + (PI if i % 2 == 0 else 0.0)
		var r := rng.randf_range(330.0, 480.0)
		var h := rng.randf_range(70.0, 130.0)
		var pos := Vector3(cos(a) * r, 0, sin(a) * r)
		var cm := CylinderMesh.new()
		cm.bottom_radius = 7.0
		cm.top_radius = 4.5
		cm.height = h
		cm.radial_segments = 12
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = U.mat(Color(0.14, 0.14, 0.17), 0.95)
		U.add(f, mi, "Chimney%d" % i, pos + Vector3(0, h * 0.5, 0))
		_glow(f, "Beacon%d" % i, 1.4, Color(1.0, 0.1, 0.05), pos + Vector3(0, h + 1.0, 0), 5.0)
	for i in 6:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(300.0, 450.0)
		var cm2 := CylinderMesh.new()
		cm2.bottom_radius = 24.0
		cm2.top_radius = 14.0
		cm2.height = 50.0
		cm2.radial_segments = 14
		var mi2 := MeshInstance3D.new()
		mi2.mesh = cm2
		mi2.material_override = U.mat(Color(0.12, 0.12, 0.15), 0.95)
		U.add(f, mi2, "Cooling%d" % i, Vector3(cos(a2) * r2, 25.0, sin(a2) * r2))
	# Огни города: рассыпанные тёплые точки на горизонте
	var lights := MultiMesh.new()
	lights.transform_format = MultiMesh.TRANSFORM_3D
	var qm := QuadMesh.new()
	qm.size = Vector2(5, 5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(1.0, 0.75, 0.4)
	qm.material = mat
	lights.mesh = qm
	lights.instance_count = 240
	for i in 240:
		var a3 := rng.randf_range(2.6, 3.6)
		var r3 := rng.randf_range(520.0, 700.0)
		lights.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(cos(a3) * r3, rng.randf_range(2.0, 25.0), sin(a3) * r3)))
	var lmi := MultiMeshInstance3D.new()
	lmi.multimesh = lights
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(f, lmi, "CityGlow")
	U.kind = old


# ---------- ангар: пол, стены, кровля, фермы ----------

func _shell() -> void:
	var s := _holder("Shell")
	var old := U.kind
	# Пол: бетон со швами, масляные пятна
	U.kind = "concrete"
	_sb(s, "Floor", Vector3(HX * 2 + 2, 0.4, HZ * 2 + 2), Color(0.4, 0.4, 0.4), Vector3(0, -0.2, 0), "concrete", 0.85)
	for i in 11:
		_vb(s, "Seam%d" % i, Vector3(0.05, 0.01, HZ * 2), Color(0.18, 0.18, 0.18), Vector3(-30.0 + i * 6.0, 0.005, 0))
	for i in 7:
		_vb(s, "SeamZ%d" % i, Vector3(HX * 2, 0.01, 0.05), Color(0.18, 0.18, 0.18), Vector3(0, 0.005, -18.0 + i * 6.0))
	for i in 10:
		var st := _vb(s, "Oil%d" % i, Vector3(rng.randf_range(0.8, 2.4), 0.012, rng.randf_range(0.8, 2.0)), Color(0.06, 0.06, 0.07), Vector3(rng.randf_range(-30, 30), 0.012, rng.randf_range(-16, 16)), "paint", 0.2)
	# Жёлтая разметка проходов
	for z in [-10.0, 1.5]:
		for sgn in [-1.0, 1.0]:
			_vb(s, "AisleLine", Vector3(40.0, 0.012, 0.1), Color(0.85, 0.7, 0.1), Vector3(-9.0, 0.014, z + sgn * 2.8))
	# Стены: бетонный цоколь + рифлёный профнастил, окна под крышей
	U.kind = "metal"
	var wall_col := Color(0.4, 0.43, 0.42)
	# Южная стена с воротами x ∈ [22, 30]
	_wall(s, "WallS1", Vector3(-HX, 0, HZ), Vector3(22.0, 0, HZ), wall_col)
	_wall(s, "WallS2", Vector3(30.0, 0, HZ), Vector3(HX, 0, HZ), wall_col)
	_sb(s, "GateHead", Vector3(8.0, WALL_H - 3.4, 0.4), wall_col, Vector3(26.0, 3.4 + (WALL_H - 3.4) * 0.5, HZ), "metal")
	# Рулонные ворота: свёрнутый барабан сверху, створка приподнята
	_vb(s, "DoorRoll", Vector3(7.6, 0.6, 0.6), Color(0.35, 0.37, 0.4), Vector3(26.0, 3.1, HZ - 0.3), "metal")
	for i in 5:
		_vb(s, "Slat%d" % i, Vector3(7.6, 0.14, 0.08), Color(0.4, 0.42, 0.45), Vector3(26.0, 2.7 - i * 0.2, HZ - 0.15), "metal")
	_wall(s, "WallN", Vector3(-HX, 0, -HZ), Vector3(HX, 0, -HZ), wall_col)
	_wall(s, "WallW", Vector3(-HX, 0, -HZ), Vector3(-HX, 0, HZ), wall_col)
	_wall(s, "WallE", Vector3(HX, 0, -HZ), Vector3(HX, 0, HZ), wall_col)
	# Окна-щели под карнизом (светят луной), разбитые стёкла
	U.kind = "paint"
	for i in 10:
		var x := -30.0 + i * 6.5
		_vb(s, "WinGlassS%d" % i, Vector3(3.2, 1.3, 0.05), Color(0.35, 0.5, 0.65, 0.35), Vector3(x, 8.4, HZ - 0.05), "paint", 0.1)
		_vb(s, "WinGlassN%d" % i, Vector3(3.2, 1.3, 0.05), Color(0.35, 0.5, 0.65, 0.35), Vector3(x, 8.4, -HZ + 0.05), "paint", 0.1)
	# Кровля, фермы
	_roof(s)
	U.kind = old


## Стена от a до b: цоколь 1.2 м из бетона и профнастил выше, с окном-щелью на y 7.8..9.0 (дыра в коллизии).
func _wall(parent: Node, nm: String, a: Vector3, b: Vector3, col: Color) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var len := d.length()
	var yaw := atan2(d.x, d.z)
	var w := Node3D.new()
	U.add(parent, w, nm, mid)
	w.rotation.y = yaw + PI * 0.5
	var along_x := absf(d.x) > absf(d.z)
	# профиль: вдоль локальной X (после поворота длина лежит по X)
	_sb(w, "Plinth", Vector3(len, 1.2, 0.5), Color(0.5, 0.5, 0.48), Vector3(0, 0.6, 0), "concrete")
	_sb(w, "Sheet", Vector3(len, 6.6, 0.3), col, Vector3(0, 4.5, 0), "metal", 0.6, 0.3)
	_sb(w, "Head", Vector3(len, WALL_H - 9.0, 0.3), col, Vector3(0, 9.0 + (WALL_H - 9.0) * 0.5, 0), "metal", 0.6, 0.3)
	# ребра жёсткости профнастила (визуал)
	var n := int(len / 1.2)
	for i in n:
		_vb(w, "Rib%d" % i, Vector3(0.12, 6.6, 0.08), col.darkened(0.15), Vector3(-len * 0.5 + 0.6 + i * 1.2, 4.5, 0.19), "metal", 0.6, 0.3)
	# ржавые подтёки
	for i in int(len / 6.0):
		_vb(w, "Rust%d" % i, Vector3(0.5, rng.randf_range(1.5, 3.5), 0.02), C_RUST.darkened(0.3), Vector3(-len * 0.5 + rng.randf_range(1, len - 1), rng.randf_range(2.5, 5.0), 0.2), "paint", 0.9)


func _roof(parent: Node) -> void:
	var r := _holder("Roof")
	var old := U.kind
	U.kind = "metal"
	var slope := atan2(RIDGE - WALL_H, HZ)
	var plen := sqrt(HZ * HZ + (RIDGE - WALL_H) * (RIDGE - WALL_H))
	var bays := 11
	var bay := (HX * 2.0) / bays
	# дыры: [номер пролёта, сторона(+1 юг/-1 север), от 0..1 по скату, до 0..1]
	var holes := [[2, 1, 0.35, 0.6], [5, 1, 0.25, 0.5], [8, -1, 0.3, 0.55], [3, -1, 0.5, 0.75], [9, 1, 0.55, 0.8], [6, -1, 0.15, 0.4]]
	for b in bays:
		var x0 := -HX + b * bay
		for side in [1.0, -1.0]:
			var cuts := [0.0, 1.0]
			for h in holes:
				if h[0] == b and h[1] == int(side):
					cuts = [0.0, h[2], h[3], 1.0]
			var k := 0
			while k < cuts.size():
				var t0: float = cuts[k]
				var t1: float = cuts[k + 1]
				# t=0 у конька, t=1 у карниза
				var zc: float = ((t0 + t1) * 0.5) * HZ * side
				var yc: float = RIDGE - ((t0 + t1) * 0.5) * (RIDGE - WALL_H)
				var panel := _sb(r, "Roof%d_%d_%d" % [b, int(side), k], Vector3(bay - 0.05, 0.15, (t1 - t0) * plen), Color(0.38, 0.4, 0.42), Vector3(x0 + bay * 0.5, yc + 0.08, zc), "metal", 0.6, 0.3)
				panel.rotation.x = -slope * side
				k += 2
	# фермы: стропила, затяжка, стойка, раскосы
	var steel := Color(0.3, 0.3, 0.32)
	for i in bays + 1:
		var x := -HX + i * bay
		var t := _holder("Truss%d" % i, Vector3(x, 0, 0))
		U.rod(t, "RafterS", Vector3(0, WALL_H - 0.1, HZ), Vector3(0, RIDGE - 0.1, 0), 0.1, steel, 0.6, 0.4)
		U.rod(t, "RafterN", Vector3(0, WALL_H - 0.1, -HZ), Vector3(0, RIDGE - 0.1, 0), 0.1, steel, 0.6, 0.4)
		U.rod(t, "Tie", Vector3(0, WALL_H - 0.5, HZ), Vector3(0, WALL_H - 0.5, -HZ), 0.08, steel, 0.6, 0.4)
		U.rod(t, "King", Vector3(0, WALL_H - 0.5, 0), Vector3(0, RIDGE - 0.1, 0), 0.07, steel, 0.6, 0.4)
		for sgn in [-1.0, 1.0]:
			U.rod(t, "Web", Vector3(0, WALL_H - 0.5, sgn * HZ * 0.5), Vector3(0, RIDGE - 0.1 - (RIDGE - WALL_H) * 0.5 + 0.0, sgn * HZ * 0.25), 0.05, steel, 0.6, 0.4)
	# прогоны вдоль ангара
	for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
		var y := RIDGE - absf(z) / HZ * (RIDGE - WALL_H) - 0.15
		U.rod(r, "Purlin%d" % int(z), Vector3(-HX, y, z), Vector3(HX, y, z), 0.06, steel, 0.6, 0.4)
	# лучи луны сквозь дыры (визуально): конусы вдоль направления света
	U.kind = "paint"
	for h in holes:
		var t_mid: float = (h[2] + h[3]) * 0.5
		var hx: float = -HX + (h[0] + 0.5) * bay
		var hz: float = t_mid * HZ * h[1]
		var hy: float = RIDGE - t_mid * (RIDGE - WALL_H)
		var h_len := hy / absf(_moon_dir.y) * 0.98
		var cone := CylinderMesh.new()
		cone.top_radius = 1.0
		cone.bottom_radius = 1.9
		cone.height = h_len
		cone.radial_segments = 12
		cone.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm.albedo_color = Color(0.45, 0.55, 0.85, 0.07)
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = bm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var centre := Vector3(hx, hy, hz) + _moon_dir * h_len * 0.5
		U.add(r, mi, "Shaft", centre)
		var up := -_moon_dir
		var xa := up.cross(Vector3.RIGHT).normalized()
		var za := xa.cross(up)
		mi.basis = Basis(xa, up, za)
	U.kind = old


# ---------- лампы под фермами ----------

func _lamp(parent: Node, pos: Vector3, energy: float, flicker := false) -> void:
	var l := Node3D.new()
	U.add(parent, l, "Lamp", pos)
	U.rod(l, "Cord", Vector3(0, 0, 0), Vector3(0, 1.6, 0), 0.015, Color(0.1, 0.1, 0.1))
	var old := U.kind
	U.kind = "metal"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 0.55
	cm.height = 0.35
	cm.radial_segments = 14
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = U.mat(Color(0.25, 0.4, 0.3), 0.5, 0.3)
	U.add(l, mi, "Shade", Vector3(0, 0.05, 0))
	U.kind = old
	_glow(l, "Bulb", 0.14, Color(1.0, 0.85, 0.55), Vector3(0, -0.08, 0), 3.0)
	var li := OmniLight3D.new()
	if flicker:
		li.set_script(load("res://scripts/location/forest/flicker.gd"))
		li.set("base_energy", energy)
	li.light_color = Color(1.0, 0.82, 0.55)
	li.light_energy = energy
	li.omni_range = 13.0
	li.omni_attenuation = 1.4
	li.shadow_enabled = false
	U.add(l, li, "Light", Vector3(0, -0.4, 0))


func _lamps() -> void:
	var main := _holder("Lamps")
	var aux := _holder("AuxLamps")
	_hazard(aux, 0, 1)
	# Основные: вдоль проходов, часть мёртвая (без света)
	var spots := [[-24.0, -9.5], [-6.0, -9.5], [12.0, -9.5], [-24.0, 1.5], [-6.0, 1.5], [12.0, 1.5], [22.0, 14.0], [28.0, -2.0]]
	for i in spots.size():
		_lamp(main, Vector3(spots[i][0], 8.1, spots[i][1]), 1.3, i % 3 == 1)
	# Запасные: гаснут на сложной
	var extra := [[-14.0, -9.5], [3.0, -9.5], [-14.0, 1.5], [3.0, 1.5], [16.0, 8.0], [-14.0, 14.0], [2.0, 14.0]]
	for p in extra:
		_lamp(aux, Vector3(p[0], 8.1, p[1]), 1.1)
	# Аварийные зелёные «ВЫХОД»
	for pos in [Vector3(-33.5, 3.0, -14.0), Vector3(26.0, 3.7, 19.3)]:
		var box := _vb(main, "ExitSign", Vector3(1.0, 0.35, 0.08), Color(0.1, 0.7, 0.3), pos, "paint")
		box.material_override = _emissive(Color(0.15, 0.9, 0.4), 2.0)
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 1.0, 0.5)
		l.light_energy = 0.6
		l.omni_range = 5.0
		U.add(main, l, "ExitLight", pos + Vector3(0.0, -0.4, 0.0))


# ---------- стеллажи ----------

func _rack(nm: String, cx: float, cz: float, bays: int, walk_y: float, full_h: float, seed_value: int, boxes := true) -> Node3D:
	var rk := Node3D.new()
	U.add(root_node, rk, nm, Vector3(cx, 0, cz))
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var bay_len := 3.0
	var length := bays * bay_len
	var levels := [0.25, 2.25, 4.25, 6.25]
	var depth := 1.2
	# Коллизия: сплошной блок до высоты walk_y (или всей стойки)
	_block(rk, "Block", Vector3(length, full_h if walk_y <= 0.0 else walk_y - 0.1, depth), Vector3(0, (full_h if walk_y <= 0.0 else walk_y - 0.1) * 0.5, 0))
	if walk_y > 0.0:
		_sb(rk, "WalkDeck", Vector3(length, 0.1, 1.5), Color(0.5, 0.48, 0.45), Vector3(0, walk_y - 0.05, 0), "wood")
	# Стойки
	for i in bays + 1:
		var x := -length * 0.5 + i * bay_len
		for z in [-depth * 0.5, depth * 0.5]:
			_vb(rk, "Upright", Vector3(0.1, 6.7, 0.1), C_BLUE, Vector3(x, 3.35, z), "metal", 0.5, 0.3)
	# Балки и настилы по уровням
	for lv in levels:
		for sgn in [-1.0, 1.0]:
			_vb(rk, "Beam", Vector3(length, 0.14, 0.07), C_ORANGE, Vector3(0, lv - 0.07, sgn * depth * 0.5), "metal", 0.5, 0.3)
		_vb(rk, "Boards", Vector3(length, 0.04, depth), Color(0.55, 0.45, 0.3), Vector3(0, lv - 0.02, 0), "wood")
	# Раскосы по торцам
	for end in [-1.0, 1.0]:
		for z in [-depth * 0.5, depth * 0.5]:
			U.rod(rk, "Brace", Vector3(end * length * 0.5, 0.2, z), Vector3(end * length * 0.5, 6.4, z * 1.0), 0.02, Color(0.3, 0.3, 0.32))
	# Содержимое: поддоны и коробки (визуал)
	if boxes:
		for lv_i in levels.size():
			var lv: float = levels[lv_i]
			if absf(lv - walk_y) < 0.2:
				continue
			for b in bays:
				if r.randf() < 0.2:
					continue
				var bx := -length * 0.5 + b * bay_len + bay_len * 0.5
				_pallet_load(rk, Vector3(bx - 0.75, lv, 0), r)
				if r.randf() < 0.75:
					_pallet_load(rk, Vector3(bx + 0.75, lv, 0), r)
	return rk


## Поддон с грузом: коробки/мешки/пластиковые ящики, иногда обтянут плёнкой.
func _pallet_load(parent: Node, base: Vector3, r: RandomNumberGenerator) -> void:
	_vb(parent, "Pallet", Vector3(1.1, 0.12, 1.0), Color(0.62, 0.48, 0.3), base + Vector3(0, 0.06, 0), "wood")
	var kind := r.randi() % 4
	var tall := r.randf_range(0.5, 1.5)
	match kind:
		0:
			for i in 2:
				for j in 2:
					_vb(parent, "Box", Vector3(0.5, tall, 0.45), C_CARD.darkened(r.randf_range(0.0, 0.25)), base + Vector3(-0.27 + i * 0.54, 0.12 + tall * 0.5, -0.24 + j * 0.48), "paint", 0.95)
		1:
			_vb(parent, "Stack", Vector3(1.0, tall, 0.9), Color(0.82, 0.8, 0.74), base + Vector3(0, 0.12 + tall * 0.5, 0), "paint", 0.95)
			_vb(parent, "Wrap", Vector3(1.04, tall + 0.02, 0.94), Color(0.7, 0.8, 0.9, 0.25), base + Vector3(0, 0.12 + tall * 0.5, 0), "paint", 0.1)
		2:
			for i in 3:
				_vb(parent, "Crate", Vector3(0.9, 0.35, 0.8), [Color(0.2, 0.4, 0.7), Color(0.75, 0.2, 0.15), Color(0.25, 0.5, 0.3)][r.randi() % 3], base + Vector3(0, 0.3 + i * 0.36, 0), "paint", 0.6)
		_:
			_vb(parent, "Big", Vector3(1.0, tall, 0.9), C_CARD.darkened(0.1), base + Vector3(0, 0.12 + tall * 0.5, 0), "paint", 0.95)
			_vb(parent, "Tape", Vector3(1.01, 0.05, 0.4), Color(0.8, 0.7, 0.4), base + Vector3(0, 0.12 + tall, 0), "paint", 0.5)


func _racks() -> void:
	# R1 (север): верхняя полка проходима, y=6.25
	_rack("RackR1", -14.0, -15.0, 12, 6.25, 6.7, 11)
	# R2 (середина): глухая стойка
	_rack("RackR2", -14.0, -4.0, 12, 0.0, 6.7, 12)
	# R3 (юг): средняя полка проходима, y=4.25; нижняя часть закрыта, самые верхние уровни пустые
	var r3 := _rack("RackR3", -14.0, 7.0, 12, 4.25, 6.7, 13)
	# Свободно стоящие стеллажи у стен: низкие
	_rack("RackW1", -30.0, -9.0, 2, 0.0, 6.7, 14)
	_rack("RackW2", 29.0, 18.2, 1, 0.0, 6.7, 15, false)


# ---------- мусор, форт кота, зона погрузки ----------

func _clutter() -> void:
	var c := _holder("Clutter")
	# Свободная зона погрузки: штабели поддонов, рулоны плёнки, пустая тара
	for i in 7:
		var p := Vector3(rng.randf_range(16.0, 32.0), 0, rng.randf_range(-14.0, 4.0))
		if p.distance_to(Vector3(20.0, 0, -4.0)) < 3.0:
			continue
		_pallet_stack(c, p, rng.randi_range(2, 5))
	# Рампа погрузки у восточной стены (визуал): жёлтая эстакада
	_sb(c, "DockRamp", Vector3(3.0, 1.2, 14.0), Color(0.5, 0.5, 0.48), Vector3(32.4, 0.6, -10.0), "concrete")
	for i in 7:
		_vb(c, "Hazard%d" % i, Vector3(3.02, 0.02, 0.5), C_YELLOW if i % 2 == 0 else Color(0.1, 0.1, 0.1), Vector3(32.4, 1.21, -15.5 + i * 1.0))
	# Картонный форт кота: короб с входом, обложен ящиками
	var f := _holder("CatFort", Vector3(8.0, 0, 12.0))
	_sb(f, "Back", Vector3(2.6, 1.6, 0.2), C_CARD, Vector3(0, 0.8, -1.2), "paint", 0.95)
	_sb(f, "SideL", Vector3(0.2, 1.6, 2.4), C_CARD.darkened(0.08), Vector3(-1.3, 0.8, 0), "paint", 0.95)
	_sb(f, "SideR", Vector3(0.2, 1.6, 2.4), C_CARD.darkened(0.12), Vector3(1.3, 0.8, 0), "paint", 0.95)
	_sb(f, "Roof", Vector3(2.8, 0.15, 2.6), C_CARD.darkened(0.2), Vector3(0, 1.65, 0), "paint", 0.95)
	_sb(f, "Blanket", Vector3(1.3, 0.1, 1.2), Color(0.75, 0.3, 0.3), Vector3(0, 0.05, -0.2), "paint", 1.0)
	_vb(f, "Window", Vector3(0.6, 0.4, 0.05), Color(0.1, 0.1, 0.1), Vector3(0.0, 1.1, -1.09), "paint")
	# Миска для кота
	_vb(f, "Bowl", Vector3(0.3, 0.07, 0.3), Color(0.8, 0.8, 0.85), Vector3(0.6, 0.04, 0.4), "metal")
	# Мусор и ящики вокруг
	for i in 5:
		_sb(c, "Junk%d" % i, Vector3(0.8, 0.7, 0.8), C_CARD.darkened(0.1 * (i % 3)), Vector3(rng.randf_range(2.0, 14.0), 0.35, rng.randf_range(11.0, 18.0)), "paint", 0.95)
	# Шины, катушки кабеля
	for i in 4:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2
		tm.outer_radius = 0.45
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = U.mat(Color(0.07, 0.07, 0.08), 0.95)
		U.add(c, mi, "Tire%d" % i, Vector3(-30.0 + i * 0.1, 0.2 + i * 0.35, 14.0))
	# Переносная лампа-«переноска» на проводе у входа
	_glow(c, "WorkLamp", 0.12, Color(1.0, 0.9, 0.6), Vector3(24.0, 0.2, 18.8), 3.0)
	# Лужа у ворот
	# Стол и стулья «охраны»: ржавый вагончик внутри у северной стены
	var cabin := _holder("GuardCabin", Vector3(-24.0, 0, -18.0))
	_sb(cabin, "Walls", Vector3(5.0, 2.4, 3.0), Color(0.55, 0.52, 0.4), Vector3(0, 1.2, 0), "metal")
	_vb(cabin, "Window", Vector3(1.4, 0.8, 0.05), Color(0.1, 0.12, 0.15), Vector3(0, 1.5, 1.52), "paint", 0.1, 0.5)
	_vb(cabin, "DoorFrame", Vector3(0.9, 1.9, 0.05), Color(0.3, 0.3, 0.28), Vector3(-1.7, 1.05, 1.52), "metal")


func _pallet_stack(parent: Node, pos: Vector3, n: int) -> void:
	var h := _holder("PalletStack")
	h.get_parent().remove_child(h)
	parent.add_child(h)
	h.position = pos
	var body := StaticBody3D.new()
	U.add(h, body, "Body")
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(1.2, 0.15 * n, 1.0))
	cs.position = Vector3(0, 0.075 * n, 0)
	body.add_child(cs)
	for i in n:
		_vb(h, "Pallet%d" % i, Vector3(1.2, 0.14, 1.0), Color(0.6, 0.46, 0.28).darkened(rng.randf_range(0.0, 0.2)), Vector3(rng.randf_range(-0.03, 0.03), 0.07 + i * 0.15, 0), "wood")


# ---------- пандусы, галерея ----------

## Наклонный настил от a (низ) к b (верх) шириной w, с поперечными рейками и жёлтой каймой.
func _slab(parent: Node, nm: String, a: Vector3, b: Vector3, w: float, col: Color) -> StaticBody3D:
	var d := b - a
	var flat := Vector3(d.x, 0, d.z)
	var th := 0.2
	var holder := StaticBody3D.new()
	U.add(parent, holder, nm, (a + b) * 0.5 - Vector3(0, th * 0.5, 0))
	holder.basis = Basis(Vector3.UP, atan2(flat.x, flat.z)) * Basis(Vector3.RIGHT, -atan2(d.y, flat.length()))
	var size := Vector3(w, th, d.length())
	_vb(holder, "Mesh", size, col, Vector3.ZERO, "metal", 0.6, 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(size)
	holder.add_child(cs)
	var n := int(d.length() / 0.5)
	for i in n:
		_vb(holder, "Cleat%d" % i, Vector3(w - 0.1, 0.04, 0.07), Color(0.6, 0.6, 0.62), Vector3(0, th * 0.5 + 0.02, -d.length() * 0.5 + 0.3 + i * 0.5), "metal")
	for sg in [-1.0, 1.0]:
		_vb(holder, "Edge", Vector3(0.08, 0.05, d.length()), C_YELLOW, Vector3(sg * (w * 0.5 - 0.06), th * 0.5 + 0.03, 0))
		_vb(holder, "Rail", Vector3(0.05, 0.05, d.length()), Color(0.2, 0.35, 0.6), Vector3(sg * (w * 0.5 + 0.0), th * 0.5 + 1.0, 0))
		for i in int(d.length() / 1.6) + 1:
			_vb(holder, "Post", Vector3(0.05, 1.0, 0.05), Color(0.2, 0.35, 0.6), Vector3(sg * (w * 0.5), th * 0.5 + 0.5, -d.length() * 0.5 + i * 1.6))
	return holder


func _routes() -> void:
	var rt := _holder("Routes")
	# Пандус на полку R3 (средняя): от зоны погрузки (x=21) до торца полки (x=4, y=4.25), z=7
	_slab(rt, "RampR3", Vector3(21.0, 0.0, 7.0), Vector3(4.2, 4.25, 7.0), 1.5, Color(0.3, 0.32, 0.35))
	# Галерея вдоль западной стены на уровне полки R3 (y=4.25): x=-31.5, z от 7 до -13
	var gal := _sb(rt, "Gallery", Vector3(1.6, 0.12, 21.0), Color(0.3, 0.32, 0.35), Vector3(-31.6, 4.19, -3.4), "metal", 0.6, 0.3)
	for sg in [-1.0, 1.0]:
		var rx := -31.6 + sg * 0.8
		_vb(rt, "GalRail", Vector3(0.05, 0.05, 21.0), Color(0.2, 0.35, 0.6), Vector3(rx, 5.3, -3.4), "metal")
		for i in 14:
			_vb(rt, "GalPost", Vector3(0.05, 1.1, 0.05), Color(0.2, 0.35, 0.6), Vector3(rx, 4.75, 6.5 - i * 1.5))
	# Подъём с галереи на верх R1 (y=6.25): пандус вдоль стены от z=-12 до z=-15 не хватит, поэтому два марша
	_slab(rt, "RampTop", Vector3(-31.6, 4.25, -12.5), Vector3(-28.6, 6.25, -15.0), 1.5, Color(0.3, 0.32, 0.35))
	# Ступенька-мостик между полкой R3 (x=-32 торец) и галереей: настил на уровне 4.25
	_sb(rt, "ShelfBridge", Vector3(2.6, 0.12, 1.5), Color(0.3, 0.32, 0.35), Vector3(-31.3, 4.19, 7.0), "metal", 0.6, 0.3)


# ---------- таблички ----------

func _sign(parent: Node, pos: Vector3, key: String, yaw: float, col := Color(0.95, 0.85, 0.2)) -> void:
	var s := Node3D.new()
	U.add(parent, s, "Sign", pos)
	s.rotation_degrees.y = yaw
	var board := _vb(s, "Board", Vector3(1.4, 0.8, 0.05), col, Vector3.ZERO, "paint", 0.5)
	U.label(board, "Text", key, Vector3(0, 0, 0.04), 0.09, Color(0.1, 0.08, 0.06))


func _signs() -> void:
	var s := _holder("Signs")
	_sign(s, Vector3(22.0, 2.4, 19.7), "SIGN_WH_HELMET", 180.0, Color(0.95, 0.85, 0.2))
	_sign(s, Vector3(18.0, 2.0, 19.7), "SIGN_WH_VOLT", 180.0, Color(0.95, 0.4, 0.2))
	_sign(s, Vector3(-6.0, 2.4, 19.7), "SIGN_WH_NOSMOKE", 180.0, Color(0.9, 0.9, 0.9))
	_sign(s, Vector3(33.7, 2.4, 10.0), "SIGN_WH_DOCK", 90.0, Color(0.95, 0.85, 0.2))
	_sign(s, Vector3(20.5, 2.2, -4.0), "SIGN_WH_FORK", 90.0, Color(0.95, 0.85, 0.2))
	_sign(s, Vector3(-33.7, 2.4, -14.0), "SIGN_WH_EXIT", 90.0, Color(0.2, 0.7, 0.3))


# ---------- опасности ----------

func _forklift(parent: Node, nm: String, path: PackedVector3Array, speed: float) -> AnimatableBody3D:
	var f := AnimatableBody3D.new()
	f.set_script(load("res://scripts/location/warehouse/forklift_ghost.gd"))
	f.set("path", path)
	f.set("speed", speed)
	U.add(parent, f, nm, path[0])
	var old := U.kind
	U.kind = "metal"
	var yel := Color(0.95, 0.72, 0.1)
	_vb(f, "Body", Vector3(1.3, 0.9, 2.2), yel, Vector3(0, 0.75, -0.2), "metal", 0.5, 0.3)
	_vb(f, "Counter", Vector3(1.3, 1.0, 0.7), Color(0.15, 0.15, 0.17), Vector3(0, 0.85, -1.3), "metal")
	_vb(f, "Seat", Vector3(0.6, 0.15, 0.6), Color(0.1, 0.1, 0.12), Vector3(0, 1.3, -0.3), "paint")
	_vb(f, "Back", Vector3(0.6, 0.55, 0.12), Color(0.1, 0.1, 0.12), Vector3(0, 1.55, -0.6), "paint")
	for sx in [-0.55, 0.55]:
		U.rod(f, "CagePost", Vector3(sx, 1.2, 0.5), Vector3(sx, 2.35, 0.4), 0.04, Color(0.2, 0.2, 0.22))
		U.rod(f, "CagePostB", Vector3(sx, 1.2, -0.9), Vector3(sx, 2.35, -0.8), 0.04, Color(0.2, 0.2, 0.22))
	_vb(f, "CageRoof", Vector3(1.2, 0.06, 1.4), Color(0.2, 0.2, 0.22), Vector3(0, 2.37, -0.2), "metal")
	# Мачта и вилы
	for sx in [-0.35, 0.35]:
		_vb(f, "Mast", Vector3(0.1, 2.2, 0.1), Color(0.3, 0.3, 0.32), Vector3(sx, 1.2, 1.0), "metal")
	_vb(f, "Carriage", Vector3(1.0, 0.5, 0.1), Color(0.3, 0.3, 0.32), Vector3(0, 0.6, 1.08), "metal")
	for sx in [-0.3, 0.3]:
		_vb(f, "Fork", Vector3(0.12, 0.06, 1.3), Color(0.25, 0.25, 0.27), Vector3(sx, 0.2, 1.72), "metal")
	# Колёса
	for sx in [-0.62, 0.62]:
		for z in [0.5, -1.0]:
			var w := CylinderMesh.new()
			w.top_radius = 0.34
			w.bottom_radius = 0.34
			w.height = 0.24
			w.radial_segments = 14
			var mi := MeshInstance3D.new()
			mi.mesh = w
			mi.material_override = U.mat(Color(0.06, 0.06, 0.07), 0.95)
			U.add(f, mi, "Wheel", Vector3(sx, 0.34, z))
			mi.rotation_degrees.z = 90
	# Призрачные глаза-фары: большие белые с зрачками
	for sx in [-0.38, 0.38]:
		_glow(f, "Eye", 0.2, Color(0.85, 1.0, 0.9), Vector3(sx, 1.0, 0.92), 1.8)
		_glow(f, "Pupil", 0.09, Color(0.05, 0.1, 0.08), Vector3(sx, 1.0, 1.08), 0.2)
	# Зеленоватое свечение «призрака» снизу и маячок
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.5, 1.0, 0.75)
	gl.light_energy = 0.8
	gl.omni_range = 7.0
	U.add(f, gl, "GhostGlow", Vector3(0, 0.6, 0))
	var bc := Node3D.new()
	U.add(f, bc, "Beacon", Vector3(0, 2.55, -0.2))
	_glow(bc, "Dome", 0.14, Color(1.0, 0.55, 0.1), Vector3(0.0, 0.0, 0.0), 3.0)
	_glow(bc, "Flash", 0.06, Color(1.0, 0.9, 0.5), Vector3(0.1, 0.0, 0.0), 4.0)
	var bl := OmniLight3D.new()
	bl.light_color = Color(1.0, 0.6, 0.2)
	bl.omni_range = 6.0
	U.add(bc, bl, "Light", Vector3(0.3, 0, 0))
	# Коллизия
	var shapes := [[Vector3(1.3, 1.0, 2.2), Vector3(0, 0.8, -0.2)], [Vector3(1.3, 1.0, 0.7), Vector3(0, 0.85, -1.3)], [Vector3(1.0, 2.2, 0.2), Vector3(0, 1.2, 1.0)], [Vector3(0.8, 0.25, 1.4), Vector3(0, 0.25, 1.72)]]
	for sh in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = _bshape(sh[0])
		cs.position = sh[1]
		f.add_child(cs)
	U.kind = old
	return f


func _hazards() -> void:
	var hz := _holder("Hazards")
	# Тир 0: щит у южной стены между воротами и котом-фортом + погрузчик в зоне погрузки
	var panel := Area3D.new()
	panel.set_script(load("res://scripts/location/warehouse/shock_panel.gd"))
	U.add(hz, panel, "ShockPanel", Vector3(19.0, 1.0, 17.8))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(4.5, 3.0, 4.0))
	cs.position = Vector3(0, 0.5, 0)
	panel.add_child(cs)
	var cab := _vb(panel, "Cabinet", Vector3(1.8, 2.2, 0.5), Color(0.5, 0.52, 0.5), Vector3(0, 0.8, 1.7), "metal", 0.5, 0.3)
	_vb(panel, "Door", Vector3(1.6, 2.0, 0.04), Color(0.6, 0.62, 0.6), Vector3(0, 0.8, 1.42), "metal")
	_vb(panel, "Warn", Vector3(0.5, 0.5, 0.02), Color(0.95, 0.85, 0.15), Vector3(0, 1.4, 1.39), "paint")
	U.label(panel, "Bolt", "⚡", Vector3(0, 1.4, 1.38), 0.35, Color(0.1, 0.1, 0.1))
	for i in 5:
		U.rod(panel, "Cable%d" % i, Vector3(-0.7 + i * 0.35, 1.9, 1.5), Vector3(-0.9 + i * 0.5, 0.2, 0.9 + i * 0.1), 0.03, Color(0.1, 0.1, 0.1))
	var sp := CPUParticles3D.new()
	sp.amount = 6
	sp.lifetime = 0.5
	sp.emitting = false
	sp.direction = Vector3(0, 1, -0.6)
	sp.spread = 55.0
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 4.5
	sp.gravity = Vector3(0, -9.0, 0)
	sp.scale_amount_min = 0.5
	sp.scale_amount_max = 0.9
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _emissive(Color(1.0, 0.9, 0.5), 4.0)
	sp.mesh = sm
	U.add(panel, sp, "Sparks", Vector3(0, 0.6, 1.3))
	var pl := OmniLight3D.new()
	pl.light_color = Color(0.5, 0.7, 1.0)
	pl.light_energy = 0.15
	pl.omni_range = 7.0
	U.add(panel, pl, "Light", Vector3(0, 1.0, 0.6))
	_hazard(panel, 0)
	# Тир 0: погрузчик F1 катается поперёк зоны погрузки
	var f1 := _forklift(hz, "Forklift1", PackedVector3Array([Vector3(20.0, 0.0, 9.5), Vector3(20.0, 0.0, -13.0)]), 2.2)
	_hazard(f1, 0)
	# Тир 1: падающие ящики с торца стеллажа у подножия пандуса R3
	var dz := HazardDropper.new()
	dz.kind = "crate"
	dz.count = 3
	dz.drop_points = PackedVector3Array([Vector3(-1.0, 5.5, 0.0), Vector3(0.4, 6.2, -0.6), Vector3(1.4, 5.8, 0.4)])
	dz.message_key = "MSG_CRATE"
	dz.cooldown = 9.0
	U.add(hz, dz, "CrateDrop", Vector3(14.0, 1.0, 5.0))
	var dcs := CollisionShape3D.new()
	dcs.shape = _bshape(Vector3(5.0, 2.0, 3.0))
	dz.add_child(dcs)
	_hazard(dz, 1)
	# Тир 1: бочки на колёсах выкатываются у восточной стены и катятся по зоне погрузки
	var bz := HazardDropper.new()
	bz.kind = "barrel"
	bz.count = 4
	bz.drop_points = PackedVector3Array([Vector3(0, 0.2, -1.2), Vector3(0, 0.2, -0.4), Vector3(0, 0.2, 0.4), Vector3(0, 0.2, 1.2)])
	bz.roll_dir = Vector3(-1, 0, 0.12)
	bz.roll_speed = 6.0
	bz.message_key = "MSG_BARREL"
	bz.cooldown = 10.0
	U.add(hz, bz, "BarrelSpill", Vector3(29.0, 0.5, -3.0))
	var bcs := CollisionShape3D.new()
	bcs.shape = _bshape(Vector3(4.0, 2.0, 8.0))
	bz.add_child(bcs)
	_hazard(bz, 1)
	# Тир 2: быстрый погрузчик F2 в проходе A1
	var f2 := _forklift(hz, "Forklift2", PackedVector3Array([Vector3(14.0, 0.0, 1.5), Vector3(-26.0, 0.0, 1.5)]), 3.8)
	_hazard(f2, 2)


# ---------- кот ----------

func _cat() -> void:
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	var m0 := Marker3D.new()
	U.add(spots, m0, "Fort", Vector3(8.0, 0.1, 11.8))
	m0.rotation_degrees.y = 0
	var m1 := Marker3D.new()
	U.add(spots, m1, "ShelfR3", Vector3(-12.0, 4.3, 7.0))
	m1.rotation_degrees.y = 90
	var m2 := Marker3D.new()
	U.add(spots, m2, "TopR1", Vector3(-12.0, 6.3, -15.0))
	m2.rotation_degrees.y = 90
	CatBuilder.build(root_node, m0.position)
	# гнёзда кота: ящики вокруг мест на полках
	var nest1 := _holder("NestR3", Vector3(-12.0, 4.25, 7.0))
	_sb(nest1, "Back", Vector3(1.0, 0.7, 0.1), C_CARD, Vector3(0, 0.35, -0.6), "paint", 0.95)
	_vb(nest1, "Blanket", Vector3(0.9, 0.08, 0.8), Color(0.7, 0.3, 0.35), Vector3(0, 0.05, 0), "paint", 1.0)
	var nest2 := _holder("NestR1", Vector3(-12.0, 6.25, -15.0))
	_sb(nest2, "Back", Vector3(1.0, 0.7, 0.1), C_CARD, Vector3(0, 0.35, -0.6), "paint", 0.95)
	_vb(nest2, "Blanket", Vector3(0.9, 0.08, 0.8), Color(0.35, 0.5, 0.7), Vector3(0, 0.05, 0), "paint", 1.0)


func _players_and_checkpoints() -> void:
	var holder := _holder("Players")
	var p := U.player(holder, SPAWN + Vector3(0, 0.6, 0))
	# Лампочка на каске: тусклый тёплый свет вокруг игрока
	var hl := OmniLight3D.new()
	hl.name = "HelmetLamp"
	hl.light_color = Color(1.0, 0.92, 0.75)
	hl.light_energy = 0.9
	hl.omni_range = 7.0
	hl.omni_attenuation = 1.6
	hl.position = Vector3(0, 1.7, 0.2)
	p.add_child(hl)
	var cps := _holder("Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, SPAWN + Vector3(1.5, 0, 0))
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(3.2, 4.25, 7.0))
	U.checkpoint(cps, "Checkpoint2", 2, Vector3(-31.6, 4.25, -8.0))
