@tool
extends SceneTree
## Генерирует res://scenes/locations/port.tscn: локация 5 «Ржавые гавани» (порт и контейнерная, вечер, мягкий жёлтый свет).
## Запуск: godot --headless --path godot --script res://tools/build_port.gd
##
## План (X на восток, Z на юг): причал №1 (z 30..56, спавн), канал 22 м, остров-контейнерная (z -12..8), портальный кран с
## контейнером-паромом между ними (рычаги на обоих берегах), штабель контейнеров с лестницей-пандусами, понтон на восток к лодке.
## Коты: простая — в открытом контейнере на причале; средняя — на верху штабеля; сложная — на палубе лодки (понтон в прилив тонет).
## Опасности: тир 0 кран с рычагом; тир 1 чайки; тир 2 прилив, больше чаек, кран быстрее.

const U := preload("res://scripts/location/loc_util.gd")

var root_node: Node3D
var rng := RandomNumberGenerator.new()
var _cache := {}

const SPAWN := Vector3(0.0, 0.0, 46.0)
const QUAY_Z0 := 30.0
const ISLE_Z1 := 8.0
const WATER_Y := -1.1
const FERRY_A := Vector3(0.0, 0.0, 24.9)
const FERRY_B := Vector3(0.0, 0.0, 13.1)

const C_RUST := Color(0.5, 0.3, 0.18)
const C_CREAM := Color(0.93, 0.88, 0.75)
const C_RED := Color(0.72, 0.22, 0.18)
const C_STEEL := Color(0.45, 0.5, 0.55)
const C_YELLOW := Color(0.88, 0.7, 0.2)
const CONT_COLS := [Color(0.62, 0.22, 0.16), Color(0.2, 0.36, 0.5), Color(0.25, 0.45, 0.32), Color(0.85, 0.5, 0.2), Color(0.7, 0.6, 0.3), Color(0.5, 0.52, 0.5)]


func _init() -> void:
	rng.seed = 1385
	root_node = Node3D.new()
	root_node.name = "Port"
	root_node.set_script(load("res://scripts/location/location.gd"))
	root_node.set("title_key", "LOC_PORT")
	root_node.set("kill_height", -1.8)
	U.rounded = false
	_environment()
	_water()
	_land()
	_quay()
	_island()
	_stacks()
	_gantry()
	_pontoon_and_boat()
	_far_shore()
	_props()
	_lamps()
	_gulls()
	_signs()
	_cat()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/port.tscn")
	root_node.free()
	quit(0 if err == OK else 1)


# ---------- кирпичики с кэшем ----------

func _bmesh(size: Vector3) -> BoxMesh:
	var key := "m%0.3f_%0.3f_%0.3f" % [size.x, size.y, size.z]
	if not _cache.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_cache[key] = bm
	return _cache[key]


func _bshape(size: Vector3) -> BoxShape3D:
	var key := "s%0.3f_%0.3f_%0.3f" % [size.x, size.y, size.z]
	if not _cache.has(key):
		var bs := BoxShape3D.new()
		bs.size = size
		_cache[key] = bs
	return _cache[key]


func _vb(parent: Node, nm: String, size: Vector3, col: Color, pos: Vector3, kind := "paint", rough := 0.85, metal := 0.0) -> MeshInstance3D:
	var old := U.kind
	U.kind = kind
	var mi := MeshInstance3D.new()
	mi.mesh = _bmesh(size)
	mi.material_override = U.mat(col, rough, metal)
	U.kind = old
	return U.add(parent, mi, nm, pos) as MeshInstance3D


func _sb(parent: Node, nm: String, size: Vector3, col: Color, pos: Vector3, kind := "paint", rough := 0.85, metal := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	U.add(parent, body, nm, pos)
	_vb(body, "Mesh", size, col, Vector3.ZERO, kind, rough, metal)
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
	var key := "e%s_%s" % [col.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


func _glow(parent: Node, nm: String, r: float, col: Color, pos: Vector3, energy := 2.0) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _emissive(col, energy)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return U.add(parent, mi, nm, pos) as MeshInstance3D


func _cyl(parent: Node, nm: String, r0: float, r1: float, h: float, col: Color, pos: Vector3, kind := "paint", seg := 16, solid := false) -> Node3D:
	var old := U.kind
	U.kind = kind
	var cm := CylinderMesh.new()
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	var holder: Node3D
	if solid:
		holder = StaticBody3D.new()
		U.add(parent, holder, nm, pos)
		U.mesh(holder, "Mesh", cm, col)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r0, r1)
		sh.height = h
		cs.shape = sh
		holder.add_child(cs)
	else:
		holder = U.mesh(parent, nm, cm, col, pos)
	U.kind = old
	return holder


## Наклонный настил от a (низ) к b (верх): коллизия и накладки-ступени, перила.
func _slab(parent: Node, nm: String, a: Vector3, b: Vector3, w: float, col: Color, rails := true) -> StaticBody3D:
	var d := b - a
	var flat := Vector3(d.x, 0, d.z)
	var th := 0.2
	var holder := StaticBody3D.new()
	U.add(parent, holder, nm, (a + b) * 0.5 - Vector3(0, th * 0.5, 0))
	holder.basis = Basis(Vector3.UP, atan2(flat.x, flat.z)) * Basis(Vector3.RIGHT, -atan2(d.y, flat.length()))
	var size := Vector3(w, th, d.length())
	_vb(holder, "Mesh", size, col, Vector3.ZERO, "wood", 0.8)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(size)
	holder.add_child(cs)
	var n := int(d.length() / 0.6)
	for i in n:
		_vb(holder, "Slat%d" % i, Vector3(w - 0.1, 0.03, 0.08), col.darkened(0.25), Vector3(0, th * 0.5 + 0.015, -d.length() * 0.5 + 0.3 + i * 0.6), "wood")
	if rails:
		for sg in [-1.0, 1.0]:
			_vb(holder, "Rail", Vector3(0.06, 0.06, d.length()), C_STEEL, Vector3(sg * (w * 0.5 + 0.02), th * 0.5 + 1.0, 0), "metal", 0.5, 0.4)
			for i in int(d.length() / 1.8) + 1:
				_vb(holder, "Post", Vector3(0.06, 1.0, 0.06), C_STEEL, Vector3(sg * (w * 0.5 + 0.02), th * 0.5 + 0.5, -d.length() * 0.5 + i * 1.8), "metal", 0.5, 0.4)
	return holder


# ---------- контейнеры ----------

func _st_box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var v := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)]
	var faces := [[0, 2, 1, 0, 3, 2], [4, 5, 6, 4, 6, 7], [0, 4, 7, 0, 7, 3], [1, 2, 6, 1, 6, 5], [3, 7, 6, 3, 6, 2], [0, 1, 5, 0, 5, 4]]
	st.set_color(col)
	for f in faces:
		for i in f:
			st.add_vertex(v[i])


## Гофрированный контейнер (длина вдоль X), кэшируется по длине и цвету. Ребра, окантовка, двери с запорами.
func _cont_mesh(L: float, col: Color) -> ArrayMesh:
	var key := "c%0.2f_%s" % [L, col.to_html()]
	if _cache.has(key):
		return _cache[key]
	var W := 2.44
	var H := 2.59
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark := col.darkened(0.25)
	var n := int(L / 0.26)
	var step := L / n
	for sz in [-1.0, 1.0]:
		for i in n:
			var x0 := -L * 0.5 + i * step
			var x1 := x0 + step
			var off := 0.045 if i % 2 == 0 else -0.01
			var cc := col if (i * 7 + int(sz)) % 11 != 0 else col.darkened(0.12)
			var z: float = sz * (W * 0.5 - 0.02 + off)
			var a := Vector3(x0, -H * 0.5 + 0.08, z)
			var b := Vector3(x1, -H * 0.5 + 0.08, z)
			var c := Vector3(x1, H * 0.5 - 0.08, z)
			var d := Vector3(x0, H * 0.5 - 0.08, z)
			st.set_color(cc)
			if sz > 0:
				for p in [a, b, c, a, c, d]:
					st.add_vertex(p)
			else:
				for p in [a, c, b, a, d, c]:
					st.add_vertex(p)
	_st_box(st, Vector3(0, H * 0.5 - 0.04, 0), Vector3(L, 0.08, W), dark)
	_st_box(st, Vector3(0, -H * 0.5 + 0.04, 0), Vector3(L, 0.08, W), dark)
	_st_box(st, Vector3(0, 0, 0), Vector3(L - 0.1, H - 0.16, W - 0.12), col.darkened(0.1))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_st_box(st, Vector3(sx * (L * 0.5 - 0.06), 0, sz * (W * 0.5 - 0.06)), Vector3(0.12, H, 0.12), dark)
		# двери: две створки, штанги и запоры
		for k in 4:
			_st_box(st, Vector3(sx * (L * 0.5 + 0.015), 0, -0.9 + k * 0.6), Vector3(0.05, H - 0.2, 0.08), col.lightened(0.05))
		_st_box(st, Vector3(sx * (L * 0.5 + 0.04), 0, 0), Vector3(0.04, H - 0.3, 0.05), Color(0.25, 0.25, 0.25))
		_st_box(st, Vector3(sx * (L * 0.5 + 0.04), 0.3, 0.06), Vector3(0.05, 0.12, 0.1), Color(0.2, 0.2, 0.2))
	st.generate_normals()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


func _cont_mat() -> StandardMaterial3D:
	if _cache.has("contmat"):
		return _cache["contmat"]
	var old := U.kind
	U.kind = "metal"
	var m: StandardMaterial3D = U.mat(Color.WHITE, 0.7, 0.2).duplicate()
	U.kind = old
	m.vertex_color_use_as_albedo = true
	_cache["contmat"] = m
	return m


## Контейнер: низ на y, центр по X/Z; yaw в градусах. solid — есть коллизия.
func _container(parent: Node, nm: String, pos: Vector3, yaw: float, L: float, col: Color, solid := true) -> Node3D:
	var holder: Node3D
	if solid:
		holder = StaticBody3D.new()
	else:
		holder = Node3D.new()
	U.add(parent, holder, nm, pos + Vector3(0, 1.295, 0))
	holder.rotation_degrees.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = _cont_mesh(L, col)
	mi.material_override = _cont_mat()
	holder.add_child(mi)
	mi.name = "Mesh"
	if solid:
		var cs := CollisionShape3D.new()
		cs.shape = _bshape(Vector3(L, 2.59, 2.44))
		holder.add_child(cs)
	return holder


# ---------- закат над гаванью ----------

func _environment() -> void:
	U.environment(root_node, Color(0.42, 0.52, 0.62), Color(0.98, 0.8, 0.58), Color(1.0, 0.78, 0.5), Vector3(-14, 55, 0), 0.0042, 0.52)
	var sun := root_node.get_node("Sun") as DirectionalLight3D
	sun.light_energy = 0.8
	sun.directional_shadow_max_distance = 170.0
	var env := (root_node.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_light_color = Color(0.85, 0.78, 0.68)
	env.glow_intensity = 0.6
	U.clouds(root_node, rng, 30, Vector3(0.55, 0.15, -0.8))


# ---------- вода ----------

func _water() -> void:
	var w := Node3D.new()
	U.add(root_node, w, "Water", Vector3(0, WATER_Y, 0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.36, 0.38, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.6
	m.roughness = 0.12
	m.normal_enabled = true
	var ntex := NoiseTexture2D.new()
	var nz := FastNoiseLite.new()
	nz.frequency = 0.02
	ntex.noise = nz
	ntex.as_normal_map = true
	ntex.seamless = true
	ntex.width = 256
	ntex.height = 256
	m.normal_texture = ntex
	m.normal_scale = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.05
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.add_child(mi)
	mi.name = "Surface"
	# Дно: тёмное, чтобы не было пустоты при отливе
	_vb(root_node, "Seabed", Vector3(900, 0.5, 900), Color(0.1, 0.14, 0.14), Vector3(0, -4.2, 0), "concrete")
	var tide := Node.new()
	tide.set_script(load("res://scripts/location/port/tide.gd"))
	tide.set("water_path", NodePath("../Water"))
	U.add(root_node, tide, "Tide")
	_hazard(tide, 2)


# ---------- земля и причал ----------

func _slab_block(parent: Node, nm: String, x0: float, x1: float, z0: float, z1: float, col: Color) -> void:
	var sx := x1 - x0
	var sz := z1 - z0
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	_sb(parent, nm, Vector3(sx, 6.0, sz), col, Vector3(cx, -3.0, cz), "concrete", 0.9)
	# Кромка с кранцами (шины) и рыжими подтёками
	for side in [[Vector3(sx, 0.3, 0.3), Vector3(cx, -0.15, z0 - 0.15)], [Vector3(sx, 0.3, 0.3), Vector3(cx, -0.15, z1 + 0.15)], [Vector3(0.3, 0.3, sz), Vector3(x0 - 0.15, -0.15, cz)], [Vector3(0.3, 0.3, sz), Vector3(x1 + 0.15, -0.15, cz)]]:
		_vb(parent, nm + "Curb", side[0], col.darkened(0.3), side[1], "concrete")
	var tires := int(sx / 3.0)
	for i in tires:
		var x := x0 + 1.5 + i * 3.0
		for zz in [z0 - 0.35, z1 + 0.35]:
			_tire(parent, Vector3(x, -0.6, zz), 90.0 if zz < cz else 90.0)


func _tire(parent: Node, pos: Vector3, rot_x: float) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.45
	tm.rings = 14
	tm.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = U.mat(Color(0.07, 0.07, 0.07), 0.9)
	U.add(parent, mi, "Tire", pos)
	mi.rotation_degrees.x = rot_x


func _land() -> void:
	pass


func _quay() -> void:
	var q := _holder("Quay")
	_slab_block(q, "QuayA", -36.0, 36.0, QUAY_Z0, 58.0, Color(0.62, 0.6, 0.56))
	# Асфальт-заплатки, рельсы портового крана и швы
	for i in 8:
		_vb(q, "Patch%d" % i, Vector3(rng.randf_range(3, 8), 0.02, rng.randf_range(3, 7)), Color(0.28, 0.28, 0.3), Vector3(rng.randf_range(-28, 28), 0.01, rng.randf_range(34, 54)), "bitumen")
	for sx in [-2.0, 2.0]:
		_vb(q, "CraneRail", Vector3(0.12, 0.08, 26.0), Color(0.4, 0.28, 0.2), Vector3(sx, 0.05, 44.0), "metal", 0.6, 0.4)
	for i in 26:
		_vb(q, "Sleeper", Vector3(4.6, 0.04, 0.2), Color(0.25, 0.2, 0.15), Vector3(0, 0.02, 31.5 + i), "wood")
	for i in 40:
		_vb(q, "Crack%d" % i, Vector3(rng.randf_range(0.8, 3.0), 0.01, 0.04), Color(0.18, 0.18, 0.18), Vector3(rng.randf_range(-30, 30), 0.02, rng.randf_range(32, 56)), "concrete").rotation_degrees.y = rng.randf() * 180.0
	for i in 40:
		_vb(q, "Weed%d" % i, Vector3(0.3, 0.2, 0.3), Color(0.3, 0.46, 0.22), Vector3(rng.randf_range(-33, 33), 0.1, rng.randf_range(31, 57)), "grass", 0.95).rotation_degrees.y = rng.randf() * 90.0
	# Швартовые тумбы с канатами по кромке
	for i in 8:
		_bollard(q, Vector3(-30.0 + i * 8.6, 0, QUAY_Z0 + 0.7))
	# Стальной склад-ангар позади
	var hg := Node3D.new()
	U.add(q, hg, "Shed", Vector3(0, 0, 57.0))
	_sb(hg, "Back", Vector3(40.0, 8.0, 0.6), Color(0.45, 0.35, 0.28), Vector3(0, 4.0, 0), "metal", 0.6, 0.3)
	for sx in [-20.0, 20.0]:
		_sb(hg, "Side", Vector3(0.6, 8.0, 8.0), Color(0.45, 0.35, 0.28), Vector3(sx, 4.0, -4.0), "metal", 0.6, 0.3)
	_vb(hg, "Roof", Vector3(41.0, 0.3, 9.0), Color(0.4, 0.3, 0.25), Vector3(0, 8.0, -4.0), "metal", 0.6, 0.3)


func _bollard(parent: Node, pos: Vector3) -> void:
	_cyl(parent, "Bollard", 0.28, 0.2, 0.7, Color(0.15, 0.15, 0.17), pos + Vector3(0, 0.35, 0), "metal", 10, true)
	_cyl(parent, "BollardCap", 0.34, 0.34, 0.1, Color(0.15, 0.15, 0.17), pos + Vector3(0, 0.74, 0), "metal", 10)
	var rope := U.rod(parent, "Rope", pos + Vector3(0, 0.3, 0.1), pos + Vector3(rng.randf_range(-1, 1), -0.8, 2.5 if pos.z < 20 else -2.5) * Vector3(1, 1, 1) * 0.0 + pos + Vector3(0, -0.2, -1.4), 0.05, Color(0.55, 0.45, 0.3))


# ---------- остров-контейнерная ----------

func _island() -> void:
	var q := _holder("Island")
	_slab_block(q, "IsleB", -16.0, 18.0, -12.0, ISLE_Z1, Color(0.6, 0.58, 0.54))
	for i in 30:
		_vb(q, "Weed%d" % i, Vector3(0.3, 0.2, 0.3), Color(0.3, 0.46, 0.22), Vector3(rng.randf_range(-15, 17), 0.1, rng.randf_range(-11, 7)), "grass", 0.95).rotation_degrees.y = rng.randf() * 90.0
	for i in 5:
		_bollard(q, Vector3(-14.0 + i * 7.5, 0, ISLE_Z1 - 0.6))
	# Лужи
	for i in 5:
		var p := Vector3(rng.randf_range(-12, 12), 0.015, rng.randf_range(-4, 6))
		var pm := CylinderMesh.new()
		pm.top_radius = rng.randf_range(0.8, 1.8)
		pm.bottom_radius = pm.top_radius
		pm.height = 0.01
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = U.mat(Color(0.25, 0.33, 0.35, 0.6), 0.05, 0.4)
		U.add(q, mi, "Puddle%d" % i, p)
	# Рычаг у парома на острове
	_lever(q, "LeverB", Vector3(4.5, 0, ISLE_Z1 - 1.8), 0.0)
	# Мобильный портовый кран-декор на востоке острова
	var mc := Node3D.new()
	U.add(q, mc, "HarborCrane", Vector3(14.0, 0, 3.0))
	_sb(mc, "Base", Vector3(3.2, 2.0, 3.2), C_YELLOW, Vector3(0, 1.0, 0), "paint")
	_cyl(mc, "Tower", 0.8, 0.6, 9.0, C_YELLOW, Vector3(0, 6.5, 0), "metal", 12)
	_vb(mc, "Cab", Vector3(1.6, 1.6, 1.8), Color(0.9, 0.85, 0.7), Vector3(0.5, 10.5, 0), "paint")
	U.rod(mc, "Boom", Vector3(0, 11.0, 0), Vector3(-9.0, 15.0, -4.0), 0.3, C_YELLOW, 0.6, 0.2)
	U.rod(mc, "Cable", Vector3(-9.0, 15.0, -4.0), Vector3(-9.0, 7.0, -4.0), 0.03, C_STEEL)
	_vb(mc, "Hook", Vector3(0.4, 0.5, 0.4), Color(0.15, 0.15, 0.15), Vector3(-9.0, 6.8, -4.0), "metal")
	_vb(mc, "Counter", Vector3(2.0, 1.6, 2.0), Color(0.3, 0.3, 0.3), Vector3(2.2, 10.5, 0), "metal")
	# Бочки, поддоны, ящики
	for i in 8:
		var bp := Vector3(rng.randf_range(-14, 8), 0, rng.randf_range(-11, -9))
		_barrel(q, bp, CONT_COLS[i % 6])
	for i in 4:
		_pallet(q, Vector3(rng.randf_range(-12, 14), 0, rng.randf_range(0, 6)), rng.randf() * 90.0)


func _barrel(parent: Node, pos: Vector3, col: Color) -> void:
	var b := _cyl(parent, "Barrel", 0.34, 0.34, 0.9, col, pos + Vector3(0, 0.45, 0), "metal", 12, true)
	for k in 3:
		_cyl(b, "Band", 0.355, 0.355, 0.04, col.darkened(0.4), Vector3(0, -0.3 + k * 0.3, 0), "metal", 12)


func _pallet(parent: Node, pos: Vector3, yaw: float) -> void:
	var p := _sb(parent, "Pallet", Vector3(1.2, 0.15, 1.0), Color(0.6, 0.45, 0.28), pos + Vector3(0, 0.075, 0), "wood")
	p.rotation_degrees.y = yaw
	var cr := _sb(p, "Crate", Vector3(1.0, 0.8, 0.8), Color(0.55, 0.4, 0.25), Vector3(0, 0.5, 0), "wood")


func _lever(parent: Node, nm: String, pos: Vector3, yaw: float) -> void:
	var l := U.trigger(parent, nm, "LEVER_FERRY", pos + Vector3(0, 0.9, 0), 1.8)
	l.add_to_group("ferry_lever", true)
	l.rotation_degrees.y = yaw
	_sb(l, "Post", Vector3(0.7, 1.0, 0.5), C_YELLOW, Vector3(0, -0.4, 0), "metal", 0.6, 0.2)
	_vb(l, "Panel", Vector3(0.6, 0.35, 0.1), Color(0.15, 0.15, 0.17), Vector3(0, 0.25, 0.22), "metal")
	var h := Node3D.new()
	U.add(l, h, "Handle", Vector3(0, 0.15, 0))
	U.rod(h, "Rod", Vector3.ZERO, Vector3(0, 0.7, 0), 0.05, Color(0.2, 0.2, 0.2), 0.5, 0.5)
	U.sphere(h, "Knob", 0.1, C_RED, Vector3(0, 0.75, 0))
	var lamp := U.sphere(l, "Lamp", 0.07, Color(1, 0.2, 0.15), Vector3(0.2, 0.28, 0.28))
	var sg := _vb(l, "Sign", Vector3(0.9, 0.5, 0.05), Color(0.95, 0.85, 0.3), Vector3(0, 1.0, -0.2), "paint")
	U.label(sg, "Text", "SIGN_PORT_LEVER", Vector3(0, 0, 0.04), 0.08, Color(0.1, 0.05, 0.05))


# ---------- штабель с пандусами ----------

func _stacks() -> void:
	var s := _holder("Stacks")
	# Нижний ряд и верхний уровень: G1 (12.2) и G3 (6.06), поверх G3 — G2
	_container(s, "G1", Vector3(-2.0, 0, -6.0), 0.0, 12.2, CONT_COLS[0])
	_container(s, "G3", Vector3(9.6, 0, -6.0), 0.0, 6.06, CONT_COLS[1])
	_container(s, "G2", Vector3(9.6, 2.59, -6.0), 0.0, 6.06, CONT_COLS[3])
	_slab(s, "RampG1", Vector3(-6.0, 0.0, 1.7), Vector3(-6.0, 2.6, -4.8), 2.0, Color(0.5, 0.42, 0.3))
	_slab(s, "RampG2", Vector3(0.0, 2.6, -6.0), Vector3(6.5, 5.18, -6.0), 2.0, Color(0.5, 0.42, 0.3))
	# Декор: ещё контейнеры вокруг, на высоте и без прохода
	_container(s, "D1", Vector3(-10.0, 0, -9.0), 90.0, 12.2, CONT_COLS[2])
	_container(s, "D2", Vector3(-10.0, 2.59, -9.0), 90.0, 12.2, CONT_COLS[4])
	_container(s, "D3", Vector3(2.0, 0, -10.0), 0.0, 12.2, CONT_COLS[5])
	_container(s, "D4", Vector3(-2.0, 2.59, -9.8), 0.0, 6.06, CONT_COLS[3])
	_container(s, "D5", Vector3(13.0, 0, -10.0), 0.0, 6.06, CONT_COLS[0])
	# Фонарь на верхнем контейнере
	_lamp_post(s, Vector3(12.0, 5.18, -6.0), true, 2.4)
	# Верёвочные перила на верху G2 и бочка
	_barrel(s, Vector3(11.6, 5.18, -5.2), CONT_COLS[1])
	# Лестница-скоба на торце G3 (декор)
	for i in 6:
		_vb(s, "Rung%d" % i, Vector3(0.5, 0.04, 0.04), C_STEEL, Vector3(12.8, 0.4 + i * 0.4, -6.0), "metal")
	# Открытый контейнер с котом на причале: пол, крыша, три стенки; открыт к воде (-z)
	var oc := Node3D.new()
	U.add(s, oc, "OpenContainer", Vector3(-14.0, 0, 52.0))
	var col := CONT_COLS[1]
	_sb(oc, "Floor", Vector3(2.44, 0.2, 6.06), col.darkened(0.3), Vector3(0, 0.1, 0), "wood")
	_sb(oc, "Roof", Vector3(2.44, 0.12, 6.06), col, Vector3(0, 2.55, 0), "metal", 0.6, 0.3)
	_sb(oc, "Back", Vector3(2.44, 2.59, 0.12), col, Vector3(0, 1.3, 3.0), "metal", 0.6, 0.3)
	for sx in [-1.16, 1.16]:
		_sb(oc, "Wall", Vector3(0.12, 2.59, 6.06), col, Vector3(sx, 1.3, 0), "metal", 0.6, 0.3)
	_vb(oc, "Ribs", Vector3(2.5, 2.4, 0.04), col.darkened(0.2), Vector3(0, 1.3, 2.93), "metal")
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.85, 0.55)
	li.light_energy = 0.8
	li.omni_range = 7.0
	U.add(oc, li, "Lantern", Vector3(0, 2.0, 1.5))
	U.sphere(oc, "Blanket", 0.5, Color(0.8, 0.3, 0.35), Vector3(0, 0.35, 2.0), 0.4)
	_barrel(oc, Vector3(-0.7, 0.1, 2.3), CONT_COLS[3])
	# Штабели на причале по сторонам (без прохода)
	var k := 0
	for sx in [-30.0, 30.0]:
		for row in 2:
			for lvl in 3 - row:
				_container(s, "Q%d" % k, Vector3(sx + (row * 2.0) * (1 if sx > 0 else -1), lvl * 2.59, 38.0 + row * 8.0), 90.0 if row == 0 else 0.0, 12.2, CONT_COLS[(k + lvl) % 6])
				k += 1


# ---------- портальный кран и паром ----------

func _gantry() -> void:
	var g := _holder("Gantry")
	var top := 15.0
	var z_a := 34.0
	var z_b := 5.0
	var yellow := C_YELLOW
	# Ноги и поперечины
	for sx in [-5.5, 5.5]:
		for z in [z_a, z_b]:
			_sb(g, "Leg", Vector3(0.9, top, 0.9), yellow, Vector3(sx, top * 0.5, z), "metal", 0.6, 0.2)
			U.rod(g, "Brace", Vector3(sx, 2.0, z), Vector3(sx * 0.7, top - 1.5, z), 0.18, yellow.darkened(0.2), 0.6, 0.2)
		_vb(g, "Girder", Vector3(0.9, 1.2, z_a - z_b + 1.4), yellow, Vector3(sx, top + 0.5, (z_a + z_b) * 0.5), "metal", 0.6, 0.2)
		_vb(g, "Rail", Vector3(0.2, 0.2, z_a - z_b + 1.4), C_STEEL, Vector3(sx * 0.8, top - 0.2, (z_a + z_b) * 0.5), "metal", 0.5, 0.5)
	for z in [z_a, z_b]:
		_vb(g, "Cross", Vector3(12.0, 0.8, 0.8), yellow, Vector3(0, top + 0.4, z), "metal", 0.6, 0.2)
	# Ржавые подтёки и вывеска «№1»
	for z in [z_a, z_b]:
		_vb(g, "Plate", Vector3(1.4, 0.9, 0.05), Color(0.15, 0.2, 0.3), Vector3(5.5, 3.0, z + 0.5 * (1 if z == z_a else -1) * 1.0 + (0.0)), "paint")
	var cab := Node3D.new()
	U.add(g, cab, "Cab", Vector3(5.4, top - 3.0, (z_a + z_b) * 0.5 + 6.0))
	_vb(cab, "Box", Vector3(2.0, 2.0, 2.4), Color(0.85, 0.8, 0.6), Vector3(0, 0, 0), "paint")
	_vb(cab, "Window", Vector3(0.05, 1.0, 1.6), Color(0.15, 0.25, 0.3), Vector3(-1.03, 0.2, 0), "paint", 0.1, 0.5)
	# Паром — контейнер на тросах
	var ferry := FerryCrane.new()
	ferry.set_script(load("res://scripts/location/port/ferry_crane.gd"))
	ferry.set("from_pos", FERRY_A)
	ferry.set("to_pos", FERRY_B)
	U.add(g, ferry, "Ferry", FERRY_A)
	# корпус: открытый сверху контейнер, верх на y=0
	var body := _vb(ferry, "Hull", Vector3(2.6, 1.2, 12.2), CONT_COLS[2], Vector3(0, -0.6, 0), "metal", 0.6, 0.3)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(2.6, 1.2, 12.2))
	cs.position = Vector3(0, -0.6, 0)
	ferry.add_child(cs)
	for sx in [-1.25, 1.25]:
		_vb(ferry, "RailSide", Vector3(0.08, 0.06, 12.2), C_STEEL, Vector3(sx, 0.95, 0), "metal", 0.5, 0.4)
		for z in [-5.6, -2.8, 0.0, 2.8, 5.6]:
			_vb(ferry, "RailPost", Vector3(0.06, 0.95, 0.06), C_STEEL, Vector3(sx, 0.475, z), "metal", 0.5, 0.4)
	# Тележка на рельсах, тросы и траверса
	_vb(ferry, "Trolley", Vector3(11.0, 0.9, 3.0), Color(0.3, 0.3, 0.32), Vector3(0, top - 0.4, 0), "metal", 0.6, 0.3)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			U.rod(ferry, "Cable", Vector3(sx * 1.0, top - 0.8, sz * 1.2), Vector3(sx * 1.2, 1.0, sz * 5.7), 0.035, Color(0.2, 0.2, 0.2), 0.6, 0.5)
	_vb(ferry, "Spreader", Vector3(2.6, 0.2, 12.2), Color(0.2, 0.2, 0.22), Vector3(0, 1.2, 0), "metal", 0.6, 0.4)
	var sgn := _vb(ferry, "FerrySign", Vector3(2.0, 0.5, 0.06), Color(0.95, 0.85, 0.3), Vector3(0, 1.6, 6.15), "paint")
	U.label(sgn, "Text", "SIGN_PORT_LEVER", Vector3(0, 0, 0.05), 0.07, Color(0.1, 0.05, 0.05))
	_hazard(ferry, 0)
	# рычаг на причале
	_lever(g, "LeverA", Vector3(3.2, 0, QUAY_Z0 + 2.5), 180.0)


# ---------- понтон и лодка ----------

func _pontoon_and_boat() -> void:
	var p := _holder("Pontoon")
	var y := -0.3
	var z := -2.0
	_slab(p, "ShoreRamp", Vector3(18.0, 0.0, z), Vector3(21.2, y, z), 2.4, Color(0.5, 0.45, 0.35), false)
	var deck := Node3D.new()
	deck.add_to_group("tide_deck", true)
	U.add(p, deck, "Deck", Vector3.ZERO)
	for i in 10:
		var x := 22.5 + i * 2.65
		var seg := _sb(deck, "Seg%d" % i, Vector3(2.5, 0.2, 2.4), Color(0.55, 0.4, 0.26).darkened(0.06 * (i % 3)), Vector3(x, y - 0.1, z), "wood")
		for k in 2:
			_cyl(seg, "Float%d" % k, 0.45, 0.45, 2.2, Color(0.2, 0.35, 0.55), Vector3(-0.6 + k * 1.2, -0.45, 0), "metal", 10).rotation_degrees.x = 90.0
		for sg in [-1.0, 1.0]:
			_vb(seg, "Rope", Vector3(2.5, 0.04, 0.04), Color(0.6, 0.5, 0.35), Vector3(0, 0.55, sg * 1.15), "wood")
			_vb(seg, "Post", Vector3(0.06, 0.55, 0.06), C_STEEL, Vector3(1.0, 0.3, sg * 1.15), "metal")
	# Трап к лодке: деревянный настил с поперечными рейками
	var bx := 50.0
	_slab(p, "Gangway", Vector3(bx - 1.2, y, z), Vector3(bx + 3.0, 0.5, z), 2.0, Color(0.55, 0.4, 0.26))
	# Лодка «Рыжий кот»: корпус, нос, палуба, рубка, мачта
	var b := Node3D.new()
	U.add(p, b, "Boat", Vector3(bx + 8.0, 0, z))
	_sb(b, "Hull", Vector3(12.0, 1.6, 4.4), Color(0.55, 0.15, 0.12), Vector3(0, -0.3, 0), "metal", 0.6, 0.3)
	_vb(b, "Stripe", Vector3(12.05, 0.25, 4.45), C_CREAM, Vector3(0, 0.25, 0), "paint")
	var pr := PrismMesh.new()
	pr.size = Vector3(1.6, 4.0, 4.4)
	var pi := MeshInstance3D.new()
	pi.mesh = pr
	pi.material_override = U.mat(Color(0.55, 0.15, 0.12), 0.6, 0.3)
	U.add(b, pi, "Bow", Vector3(8.0, -0.3, 0))
	pi.rotation_degrees.z = -90.0
	var bowc := StaticBody3D.new()
	U.add(b, bowc, "BowDeck", Vector3(8.0, 0.4, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(4.0, 0.2, 2.8))
	cs.position = Vector3(-0.4, 0, 0)
	bowc.add_child(cs)
	_vb(b, "BowDeckMesh", Vector3(3.6, 0.1, 3.0), Color(0.55, 0.4, 0.26), Vector3(7.4, 0.5, 0), "wood")
	_vb(b, "Deck", Vector3(11.8, 0.1, 4.2), Color(0.55, 0.4, 0.26), Vector3(0, 0.55, 0), "wood")
	_sb(b, "Cabin", Vector3(3.6, 2.2, 1.8), Color(0.9, 0.86, 0.74), Vector3(-3.6, 1.55, -1.3), "paint")
	_vb(b, "CabinRoof", Vector3(4.0, 0.15, 2.2), C_RED, Vector3(-3.6, 2.7, -1.3), "paint")
	for sg in [-1.0, 1.0]:
		_vb(b, "Window", Vector3(0.8, 0.7, 0.04), Color(0.15, 0.22, 0.28), Vector3(-3.6 + sg * 0.9, 1.9, -0.38), "paint", 0.1, 0.5)
		_vb(b, "WindowB", Vector3(0.8, 0.7, 0.04), Color(0.15, 0.22, 0.28), Vector3(-3.6 + sg * 0.9, 1.9, -2.22), "paint", 0.1, 0.5)
	_cyl(b, "Mast", 0.1, 0.07, 6.0, C_STEEL, Vector3(0.5, 3.5, 0), "metal", 8)
	U.rod(b, "Boom", Vector3(0.5, 4.4, 0), Vector3(-2.5, 3.6, 0), 0.06, C_STEEL)
	for sg in [-1.0, 1.0]:
		_vb(b, "Rail", Vector3(11.8, 0.05, 0.05), C_STEEL, Vector3(0, 1.1, sg * 2.1), "metal")
		for k in 8:
			_vb(b, "RailPost", Vector3(0.05, 0.55, 0.05), C_STEEL, Vector3(-5.0 + k * 1.3, 0.8, sg * 2.1), "metal")
	var bs := _vb(b, "Name", Vector3(2.2, 0.5, 0.05), Color(0.95, 0.9, 0.7), Vector3(0, -0.1, 2.23), "paint")
	U.label(bs, "Text", "SIGN_PORT_BOAT", Vector3(0, 0, 0.04), 0.18, Color(0.5, 0.1, 0.1))
	# Бочки, ящик и спасательный круг на палубе
	_barrel(b, Vector3(-0.8, 0.6, -1.4), CONT_COLS[3])
	_sb(b, "CrateDeck", Vector3(0.8, 0.8, 0.8), Color(0.55, 0.4, 0.25), Vector3(1.8, 1.0, 1.3), "wood")
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2
	ring.outer_radius = 0.38
	var rm := MeshInstance3D.new()
	rm.mesh = ring
	rm.material_override = U.mat(Color(0.9, 0.3, 0.1), 0.6)
	U.add(b, rm, "LifeRing", Vector3(-3.6, 1.9, -0.36))
	rm.rotation_degrees.x = 90.0
	# Табличка у понтона
	var sg2 := _vb(p, "PontoonSign", Vector3(1.6, 0.8, 0.06), Color(0.95, 0.4, 0.2), Vector3(19.5, 1.4, z + 1.8), "paint")
	U.label(sg2, "Text", "SIGN_PORT_PONTOON", Vector3(0, 0, 0.05), 0.1, Color(0.1, 0.05, 0.05))
	_vb(p, "PontoonSignPost", Vector3(0.08, 1.4, 0.08), C_STEEL, Vector3(19.5, 0.7, z + 1.8), "metal")


# ---------- берег напротив и окружение ----------

func _far_shore() -> void:
	var f := _holder("FarShore")
	# Северный берег и боковые берега: бетонные массивы, поверх контейнеры и склады без коллизий
	_vb(f, "North", Vector3(500.0, 6.0, 60.0), Color(0.5, 0.5, 0.48), Vector3(0, -3.0, -75.0), "concrete")
	_vb(f, "West", Vector3(80.0, 6.0, 300.0), Color(0.5, 0.5, 0.48), Vector3(-92.0, -3.0, 0.0), "concrete")
	_vb(f, "East", Vector3(120.0, 6.0, 300.0), Color(0.5, 0.5, 0.48), Vector3(130.0, -3.0, 20.0), "concrete")
	_vb(f, "South", Vector3(500.0, 6.0, 60.0), Color(0.5, 0.5, 0.48), Vector3(0, -3.0, 130.0), "concrete")
	for i in 70:
		var side := i % 3
		var p: Vector3
		if side == 0:
			p = Vector3(rng.randf_range(-190, 190), 0, rng.randf_range(-100, -52))
		elif side == 1:
			p = Vector3(rng.randf_range(-130, -54), 0, rng.randf_range(-60, 110))
		else:
			p = Vector3(rng.randf_range(92, 200), 0, rng.randf_range(-60, 120))
		var h := rng.randi_range(0, 2)
		for lvl in h + 1:
			_container(f, "Far%d_%d" % [i, lvl], p + Vector3(0, lvl * 2.59, 0), rng.randf() * 180.0 if lvl == 0 else 0.0, 12.2, CONT_COLS[rng.randi() % 6], false)
	# Склады
	for i in 12:
		var wx := -170.0 + i * 31.0
		var wz := -90.0 - rng.randf_range(0, 12)
		var wh := rng.randf_range(10.0, 15.0)
		_vb(f, "Warehouse%d" % i, Vector3(24.0, wh, 18.0), Color(0.55, 0.42, 0.34).lerp(Color(0.4, 0.45, 0.5), rng.randf()), Vector3(wx, wh * 0.5, wz), "metal", 0.6, 0.3)
		_vb(f, "WarehouseRoof%d" % i, Vector3(25.0, 0.5, 19.0), Color(0.35, 0.3, 0.3), Vector3(wx, wh + 0.2, wz), "metal")
	# Далёкие краны
	for i in 6:
		_far_crane(f, Vector3(-150.0 + i * 55.0, 0, -66.0 - (i % 2) * 8.0))
	# Холмы за портом и дымка (силуэты)
	for i in 14:
		var a := i * 0.45 - 3.0
		var hh := rng.randf_range(25.0, 60.0)
		var hm := SphereMesh.new()
		hm.radius = 80.0
		hm.height = hh * 2.0
		hm.radial_segments = 12
		hm.rings = 6
		var mi := MeshInstance3D.new()
		mi.mesh = hm
		mi.material_override = U.mat(Color(0.32, 0.38, 0.38), 1.0)
		U.add(f, mi, "Hill%d" % i, Vector3(-300.0 + i * 50.0, -hh * 0.3, -260.0 - (i % 3) * 20.0))


func _far_crane(parent: Node, pos: Vector3) -> void:
	var c := Node3D.new()
	U.add(parent, c, "FarCrane", pos)
	for sx in [-5.5, 5.5]:
		for sz in [-4.0, 4.0]:
			_vb(c, "Leg", Vector3(0.8, 28.0, 0.8), Color(0.8, 0.45, 0.15), Vector3(sx, 14.0, sz), "metal", 0.6, 0.2)
	_vb(c, "Top", Vector3(12.0, 1.2, 9.0), Color(0.8, 0.45, 0.15), Vector3(0, 28.4, 0), "metal")
	U.rod(c, "Boom", Vector3(0, 29.5, 0), Vector3(0, 33.0, 40.0), 0.9, Color(0.8, 0.45, 0.15), 0.6, 0.2)
	U.rod(c, "Stay", Vector3(0, 40.0, 0), Vector3(0, 33.0, 40.0), 0.15, C_STEEL)
	_vb(c, "Mast", Vector3(0.8, 12.0, 0.8), Color(0.8, 0.45, 0.15), Vector3(0, 34.0, 0), "metal")


func _props() -> void:
	var p := _holder("Props")
	# Лодки у причала, ржавые баржи и буи
	var spots := [Vector3(-20, 0, 24), Vector3(26, 0, 26), Vector3(-26, 0, -2), Vector3(-36, 0, 10)]
	for i in spots.size():
		_rowboat(p, spots[i], rng.randf() * 80.0 - 40.0, CONT_COLS[(i + 2) % 6])
	for i in 10:
		var bp := Vector3(rng.randf_range(-30, 38), WATER_Y + 0.1, rng.randf_range(9, 29))
		var bm := SphereMesh.new()
		bm.radius = 0.35
		bm.height = 0.8
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = U.mat([Color(0.85, 0.2, 0.15), Color(0.9, 0.85, 0.2)][i % 2], 0.5)
		U.add(p, mi, "Buoy%d" % i, bp)
	# Старые ящики, мотки каната, бочки и тросы на причале
	for i in 14:
		_barrel(p, Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(33, 54)), CONT_COLS[rng.randi() % 6])
	for i in 6:
		_pallet(p, Vector3(rng.randf_range(-24, 24), 0, rng.randf_range(34, 54)), rng.randf() * 90.0)
	for i in 5:
		var rp := Vector3(rng.randf_range(-20, 20), 0.15, rng.randf_range(32, 40))
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2
		tm.outer_radius = 0.55
		var mi2 := MeshInstance3D.new()
		mi2.mesh = tm
		mi2.material_override = U.mat(Color(0.6, 0.5, 0.35), 0.9)
		U.add(p, mi2, "RopeCoil%d" % i, rp)
	# Старый автокран и вагончик у спавна (декор у края)
	var tr := Node3D.new()
	U.add(p, tr, "Trailer", Vector3(22.0, 0, 50.0))
	_sb(tr, "Body", Vector3(5.0, 2.6, 2.4), Color(0.7, 0.68, 0.6), Vector3(0, 1.3, 0), "metal", 0.6, 0.2)
	_vb(tr, "Window", Vector3(1.2, 0.8, 0.05), Color(0.15, 0.22, 0.28), Vector3(-1.0, 1.7, 1.22), "paint", 0.1, 0.5)
	_vb(tr, "Door", Vector3(0.9, 1.9, 0.05), C_RUST, Vector3(1.4, 1.0, 1.22), "metal")
	_vb(tr, "Roof", Vector3(5.4, 0.15, 2.8), Color(0.45, 0.3, 0.25), Vector3(0, 2.65, 0), "metal")
	var tb := _vb(tr, "Board", Vector3(2.4, 0.6, 0.06), Color(0.95, 0.85, 0.3), Vector3(0, 2.4, 1.25), "paint")
	U.label(tb, "Text", "SIGN_PORT_QUAY", Vector3(0, 0, 0.05), 0.14, Color(0.1, 0.05, 0.05))


func _rowboat(parent: Node, pos: Vector3, yaw: float, col: Color) -> void:
	var b := Node3D.new()
	U.add(parent, b, "Rowboat", pos + Vector3(0, WATER_Y + 0.05, 0))
	b.rotation_degrees.y = yaw
	_vb(b, "Hull", Vector3(4.2, 0.6, 1.5), col, Vector3(0, 0.0, 0), "paint")
	var pr := PrismMesh.new()
	pr.size = Vector3(1.5, 1.2, 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = pr
	mi.material_override = U.mat(col, 0.7)
	U.add(b, mi, "Bow", Vector3(2.4, 0.0, 0))
	mi.rotation_degrees.z = -90.0
	_vb(b, "Seat", Vector3(0.3, 0.05, 1.3), Color(0.55, 0.4, 0.26), Vector3(0.3, 0.3, 0), "wood")
	_vb(b, "Oar", Vector3(1.8, 0.04, 0.06), Color(0.6, 0.45, 0.28), Vector3(0.0, 0.45, 0.7), "wood").rotation_degrees.y = 25.0


# ---------- фонари ----------

func _lamp_post(parent: Node, pos: Vector3, lit: bool, h := 6.0) -> void:
	var p := Node3D.new()
	U.add(parent, p, "LampPost", pos)
	_vb(p, "Post", Vector3(0.14, h, 0.14), Color(0.2, 0.22, 0.2), Vector3(0, h * 0.5, 0), "metal", 0.5, 0.5)
	_vb(p, "Arm", Vector3(1.1, 0.08, 0.08), Color(0.2, 0.22, 0.2), Vector3(0.5, h, 0), "metal")
	_glow(p, "Globe", 0.26, Color(1.0, 0.82, 0.5) if lit else Color(0.5, 0.45, 0.4), Vector3(1.0, h - 0.12, 0), 2.5 if lit else 0.3)
	if lit:
		var li := OmniLight3D.new()
		li.light_color = Color(1.0, 0.8, 0.5)
		li.light_energy = 1.1
		li.omni_range = 16.0
		U.add(p, li, "Light", Vector3(1.0, h - 0.5, 0))


func _lamps() -> void:
	var l := _holder("Lamps")
	var i := 0
	for x in [-24.0, -12.0, 12.0, 24.0]:
		_lamp_post(l, Vector3(x, 0, 40.0), i % 2 == 0)
		i += 1
	for x in [-12.0, 12.0]:
		_lamp_post(l, Vector3(x, 0, 33.0), true)
	for x in [-10.0, 10.0]:
		_lamp_post(l, Vector3(x, 0, -2.0), i % 2 == 0)
		i += 1
	_lamp_post(l, Vector3(16.0, 0, -9.0), true)
	_lamp_post(l, Vector3(-14.0, 0, 6.0), true)
	# Гирлянда на причале между тумбами и краном
	for k in 14:
		var t := float(k) / 13.0
		_glow(l, "Garland", 0.07, Color(1.0, [0.85, 0.5, 0.7][k % 3], 0.5), Vector3(lerpf(-12.0, 12.0, t), 5.5 - 0.7 * sin(t * PI), 36.0), 1.6)


# ---------- чайки ----------

func _gull(parent: Node, nm: String, center: Vector3, radius: float, tier: int) -> void:
	var g := Node3D.new()
	g.set_script(load("res://scripts/location/port/gull.gd"))
	g.set("center", center)
	g.set("radius", radius)
	U.add(parent, g, nm, center + Vector3(radius, 7.0, 0))
	var white := Color(0.95, 0.95, 0.92)
	U.sphere(g, "Body", 0.28, white, Vector3.ZERO, 0.7)
	g.get_node("Body").scale = Vector3(0.7, 0.6, 1.5)
	U.sphere(g, "Head", 0.16, white, Vector3(0, 0.12, 0.42), 1.0)
	U.box(g, "Beak", Vector3(0.06, 0.05, 0.2), Color(0.95, 0.6, 0.1), Vector3(0, 0.1, 0.62))
	for sg in [-1.0, 1.0]:
		U.sphere(g, "Eye", 0.025, Color(0.05, 0.05, 0.05), Vector3(sg * 0.08, 0.17, 0.52))
	var wl := Node3D.new()
	U.add(g, wl, "WingL", Vector3(0.2, 0.05, 0))
	U.box(wl, "Wing", Vector3(0.9, 0.04, 0.4), Color(0.75, 0.78, 0.8), Vector3(0.45, 0, 0))
	U.box(wl, "Tip", Vector3(0.25, 0.04, 0.3), Color(0.15, 0.15, 0.17), Vector3(1.0, 0, 0))
	var wr := Node3D.new()
	U.add(g, wr, "WingR", Vector3(-0.2, 0.05, 0))
	U.box(wr, "Wing", Vector3(0.9, 0.04, 0.4), Color(0.75, 0.78, 0.8), Vector3(-0.45, 0, 0))
	U.box(wr, "Tip", Vector3(0.25, 0.04, 0.3), Color(0.15, 0.15, 0.17), Vector3(-1.0, 0, 0))
	U.box(g, "Tail", Vector3(0.25, 0.03, 0.3), white, Vector3(0, 0.0, -0.5))
	_hazard(g, tier)


func _gulls() -> void:
	var gh := _holder("Gulls")
	for i in 3:
		_gull(gh, "Gull%d" % i, Vector3(-8.0 + i * 8.0, 0, 36.0), 10.0 + i * 2.0, 1)
	for i in 2:
		_gull(gh, "GullB%d" % i, Vector3(2.0 + i * 8.0, 0, 8.0), 9.0, 2)
	# Чайки-декор на тумбах, не двигаются
	for i in 6:
		var white := Color(0.95, 0.95, 0.92)
		var bp := Vector3(-30.0 + i * 8.6 + 0.0, 0.95, QUAY_Z0 + 0.7)
		var g := Node3D.new()
		U.add(gh, g, "Perch%d" % i, bp)
		g.rotation_degrees.y = rng.randf() * 360.0
		U.sphere(g, "Body", 0.2, white, Vector3.ZERO, 0.8).scale = Vector3(0.7, 0.8, 1.3)
		U.sphere(g, "Head", 0.12, white, Vector3(0, 0.18, 0.18))
		U.box(g, "Beak", Vector3(0.04, 0.04, 0.12), Color(0.95, 0.6, 0.1), Vector3(0, 0.17, 0.32))
		U.box(g, "Tail", Vector3(0.18, 0.03, 0.2), Color(0.6, 0.62, 0.65), Vector3(0, 0.0, -0.3))


# ---------- таблички ----------

func _signs() -> void:
	var s := _holder("Signs")
	var sg := _vb(s, "PortSign", Vector3(5.0, 2.0, 0.15), Color(0.2, 0.45, 0.6), Vector3(0, 6.0, 57.2), "paint")
	U.label(sg, "Text", "SIGN_PORT_NAME", Vector3(0, 0, -0.1), 0.45, Color(0.95, 0.9, 0.7)).rotation_degrees.y = 180.0
	var sq := _vb(s, "IsleSign", Vector3(3.2, 0.9, 0.06), Color(0.9, 0.8, 0.3), Vector3(-6.0, 1.8, 6.4), "paint")
	U.label(sq, "Text", "SIGN_PORT_ISLE", Vector3(0, 0, 0.05), 0.12, Color(0.15, 0.1, 0.05))
	_vb(s, "IsleSignPost", Vector3(0.1, 1.8, 0.1), C_STEEL, Vector3(-6.0, 0.9, 6.4), "metal")


# ---------- кот ----------

func _cat() -> void:
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	var m0 := Marker3D.new()
	U.add(spots, m0, "OpenContainer", Vector3(-14.0, 0.2, 54.0))
	m0.rotation_degrees.y = 0.0
	var m1 := Marker3D.new()
	U.add(spots, m1, "StackTop", Vector3(9.6, 5.18, -6.0))
	m1.rotation_degrees.y = 90.0
	var m2 := Marker3D.new()
	U.add(spots, m2, "Boat", Vector3(56.5, 0.6, -2.0))
	m2.rotation_degrees.y = 270.0
	CatBuilder.build(root_node, m0.position)


func _players_and_checkpoints() -> void:
	var holder := _holder("Players")
	U.player(holder, SPAWN + Vector3(0, 0.6, 0))
	var cps := _holder("Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, SPAWN + Vector3(2.0, 0.0, 0.0))
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(5.5, 0.0, 3.0))
	U.checkpoint(cps, "Checkpoint2", 2, Vector3(15.5, 0.0, -2.0))
