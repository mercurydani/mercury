@tool
extends SceneTree
## Генерирует res://scenes/locations/amusement.tscn: локация 4 «Карусель-гора» (заброшенный парк культуры и отдыха, закат).
## Запуск: godot --headless --path godot --script res://tools/build_amusement.gd
##
## План (X на восток, Z на юг, вход с юга z=+78, спавн у ворот):
##   аллея к фонтану с утками (0,45), карусель (-30,20), ящик-тир, батутная арена (-12,52), дорожка вагонеток,
##   станция американских горок (28..38, y=4) с подъёмом на вершину (62..68, y=14) и колесо обозрения (68,15,10).
## Коты: простая — на постаменте в центре карусели; средняя — в вагонетке на вершине горок; сложная — в кабинке колеса
## (мостик из проваливающихся досок от вершины горок).
## Опасности: тир 0 вращающаяся карусель (внутреннее кольцо стоит) и струи фонтана; тир 1 вагонетка без тормозов
## и сломанные батуты; тир 2 внутреннее кольцо крутится навстречу, вторая быстрая вагонетка, доски моста проваливаются.

const U := preload("res://scripts/location/loc_util.gd")

var root_node: Node3D
var rng := RandomNumberGenerator.new()
var _cache := {}

const GATE_Z := 78.0
const SPAWN := Vector3(0.0, 0.0, 70.0)
const CAROUSEL := Vector3(-30.0, 0.0, 20.0)
const FOUNTAIN := Vector3(0.0, 0.0, 45.0)
const WHEEL_HUB := Vector3(68.0, 15.0, 10.0)
const WHEEL_R := 12.0
const SUMMIT_Y := 14.0

const PASTEL := [Color(0.9, 0.45, 0.4), Color(0.95, 0.8, 0.35), Color(0.4, 0.7, 0.75), Color(0.55, 0.75, 0.45), Color(0.85, 0.55, 0.75)]
const C_RUST := Color(0.5, 0.3, 0.18)
const C_CREAM := Color(0.93, 0.88, 0.75)
const C_RED := Color(0.78, 0.2, 0.18)
const C_STEEL := Color(0.45, 0.5, 0.55)


func _init() -> void:
	rng.seed = 1964
	root_node = Node3D.new()
	root_node.name = "Amusement"
	root_node.set_script(load("res://scripts/location/location.gd"))
	root_node.set("title_key", "LOC_PARK")
	root_node.set("kill_height", -9.0)
	U.rounded = false
	_environment()
	_ground()
	_gate()
	_fountain()
	_carousel()
	_arena()
	_coaster()
	_wheel()
	_carts()
	_kiosks()
	_trees()
	_lamps()
	_signs()
	_cat()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/amusement.tscn")
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


# ---------- закат ----------

func _environment() -> void:
	U.environment(root_node, Color(0.34, 0.42, 0.75), Color(1.0, 0.62, 0.45), Color(1.0, 0.7, 0.42), Vector3(-9, -35, 0), 0.0035, 0.5)
	var sun := root_node.get_node("Sun") as DirectionalLight3D
	sun.light_energy = 0.75
	sun.directional_shadow_max_distance = 160.0
	var env := (root_node.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_light_color = Color(1.0, 0.7, 0.55)
	env.glow_intensity = 0.7
	U.clouds(root_node, rng, 34, Vector3(0.9, 0.12, 0.45))


# ---------- земля, дорожки, ограда ----------

func _ground() -> void:
	var g := _holder("Ground")
	_sb(g, "Grass", Vector3(900, 1.0, 900), Color(0.55, 0.62, 0.38), Vector3(0, -0.5, 0), "grass", 0.95)
	# Аллеи и площади: бетонные плиты со швами
	var paved := Color(0.62, 0.6, 0.56)
	_vb(g, "Avenue", Vector3(9.0, 0.08, 40.0), paved, Vector3(0, 0.04, 58.0), "concrete", 0.9)
	_vb(g, "Plaza", Vector3(30.0, 0.08, 26.0), paved, Vector3(0, 0.04, 45.0), "concrete", 0.9)
	_vb(g, "PathCarousel", Vector3(6.0, 0.08, 38.0), paved, Vector3(-15.0, 0.04, 28.0), "concrete", 0.9).rotation_degrees.y = -50.0
	_vb(g, "PathStation", Vector3(6.0, 0.08, 26.0), paved, Vector3(14.0, 0.04, 40.0), "concrete", 0.9).rotation_degrees.y = 60.0
	_vb(g, "PathNorth", Vector3(6.0, 0.08, 60.0), paved, Vector3(0, 0.04, 0.0), "concrete", 0.9)
	_cyl(g, "CarouselPad", 12.0, 12.0, 0.1, paved, CAROUSEL + Vector3(0, 0.03, 0), "concrete", 28)
	_cyl(g, "WheelPad", 14.0, 14.0, 0.1, paved, Vector3(68, 0.03, 10), "concrete", 28)
	# Трещины и сорняки: тёмные полосы и зелёные пятна на плитах
	for i in 70:
		var p := Vector3(rng.randf_range(-20, 20), 0.09, rng.randf_range(30, 74))
		_vb(g, "Crack%d" % i, Vector3(rng.randf_range(0.6, 2.4), 0.01, 0.04), Color(0.2, 0.2, 0.2), p).rotation_degrees.y = rng.randf() * 180.0
	for i in 60:
		var p2 := Vector3(rng.randf_range(-22, 22), 0.12, rng.randf_range(28, 76))
		_vb(g, "Weed%d" % i, Vector3(0.35, 0.22, 0.35), Color(0.3, 0.5, 0.22), p2, "grass", 0.95).rotation_degrees.y = rng.randf() * 90.0
	# Ограда с кирпичными столбами и чугунными пролётами
	for i in 24:
		var x := -84.0 + i * 7.2
		if absf(x) < 8.0:
			continue
		_fence_span(g, Vector3(x, 0, GATE_Z + 2.0))
	for i in 24:
		var z := -80.0 + i * 6.8
		_fence_span(g, Vector3(-86.0, 0, z), 90.0)
		_fence_span(g, Vector3(86.0, 0, z), 90.0)
	for i in 24:
		_fence_span(g, Vector3(-84.0 + i * 7.2, 0, -82.0))


func _fence_span(parent: Node, pos: Vector3, yaw := 0.0) -> void:
	var f := Node3D.new()
	U.add(parent, f, "Fence", pos)
	f.rotation_degrees.y = yaw
	_sb(f, "Pillar", Vector3(0.6, 2.6, 0.6), Color(0.62, 0.34, 0.26), Vector3(0, 1.3, 0), "brick")
	_vb(f, "Cap", Vector3(0.75, 0.12, 0.75), Color(0.7, 0.68, 0.62), Vector3(0, 2.65, 0), "concrete")
	_vb(f, "RailTop", Vector3(6.6, 0.07, 0.07), Color(0.12, 0.12, 0.13), Vector3(3.6, 2.1, 0), "metal", 0.5, 0.5)
	_vb(f, "RailLow", Vector3(6.6, 0.07, 0.07), Color(0.12, 0.12, 0.13), Vector3(3.6, 0.5, 0), "metal", 0.5, 0.5)
	for i in 13:
		_vb(f, "Bar", Vector3(0.04, 1.95, 0.04), Color(0.12, 0.12, 0.13), Vector3(0.55 + i * 0.5, 1.2, 0), "metal", 0.5, 0.5)
	var body := StaticBody3D.new()
	U.add(f, body, "Block", Vector3(3.6, 1.1, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(6.6, 2.2, 0.3))
	body.add_child(cs)


# ---------- ворота и билетные кассы ----------

func _gate() -> void:
	var gt := _holder("Gate", Vector3(0, 0, GATE_Z + 2.0))
	# Столбы и арка «ПАРК»
	for sx in [-7.0, 7.0]:
		_sb(gt, "GatePillar", Vector3(1.6, 8.0, 1.6), Color(0.9, 0.85, 0.7), Vector3(sx, 4.0, 0), "concrete")
		_vb(gt, "PillarCap", Vector3(2.0, 0.4, 2.0), Color(0.8, 0.3, 0.25), Vector3(sx, 8.2, 0), "paint")
		for k in 4:
			_vb(gt, "PillarStripe", Vector3(1.64, 0.25, 1.64), Color(0.8, 0.3, 0.25), Vector3(sx, 1.0 + k * 1.8, 0), "paint")
	_sb(gt, "Arch", Vector3(16.0, 2.4, 1.2), Color(0.9, 0.85, 0.7), Vector3(0, 8.4, 0), "concrete")
	var board := _vb(gt, "ArchBoard", Vector3(12.0, 1.7, 0.1), Color(0.18, 0.4, 0.6), Vector3(0, 8.4, 0.65), "paint", 0.6)
	U.label(board, "Text", "SIGN_PARK_NAME", Vector3(0, 0, 0.07), 0.38, Color(0.95, 0.9, 0.7))
	# Звёзды-лампочки по арке
	for i in 16:
		_glow(gt, "Bulb%d" % i, 0.1, Color(1.0, 0.85, 0.5), Vector3(-7.5 + i, 9.7, -0.7), 2.0)
	# Турникеты и кассы
	for k in 4:
		var tx := -4.0 + k * 2.6
		_vb(gt, "Turnstile%d" % k, Vector3(0.12, 1.0, 0.7), C_STEEL, Vector3(tx, 0.5, -3.0), "metal", 0.5, 0.5)
		for r in 3:
			_vb(gt, "Arm", Vector3(0.9, 0.06, 0.06), C_STEEL, Vector3(tx, 0.9, -3.0)).rotation_degrees.x = 120.0 * r
	for sx in [-12.0, 12.0]:
		var b := Node3D.new()
		U.add(gt, b, "TicketBooth", Vector3(sx, 0, -4.0))
		_sb(b, "Walls", Vector3(3.0, 2.8, 2.4), Color(0.95, 0.9, 0.78), Vector3(0, 1.4, 0), "concrete")
		_vb(b, "Window", Vector3(1.4, 0.9, 0.06), Color(0.15, 0.2, 0.25), Vector3(0, 1.6, 1.22), "paint", 0.1, 0.5)
		_vb(b, "Counter", Vector3(1.8, 0.1, 0.5), Color(0.5, 0.35, 0.22), Vector3(0, 1.1, 1.45), "wood")
		_vb(b, "Roof", Vector3(3.6, 0.2, 3.0), C_RED, Vector3(0, 2.95, 0), "paint")
		var tb := _vb(b, "Board", Vector3(1.6, 0.4, 0.05), Color(0.95, 0.85, 0.3), Vector3(0, 2.45, 1.25), "paint")
		U.label(tb, "Text", "SIGN_PARK_TICKET", Vector3(0, 0, 0.04), 0.14, Color(0.15, 0.1, 0.05))
	# Афиша с котом
	var poster := _vb(gt, "Poster", Vector3(2.4, 3.0, 0.08), Color(0.9, 0.8, 0.35), Vector3(-9.8, 2.0, -2.0), "paint")
	U.sphere(poster, "CatFace", 0.55, Color(0.95, 0.6, 0.2), Vector3(0, 0.3, 0.1), 0.9)
	for sx in [-1.0, 1.0]:
		U.cyl(poster, "CatEar", 0.18, 0.0, 0.35, Color(0.95, 0.6, 0.2), Vector3(sx * 0.35, 0.85, 0.1), 4)


# ---------- фонтан с утками ----------

func _fountain() -> void:
	var f := _holder("Fountain", FOUNTAIN)
	var stone := Color(0.75, 0.72, 0.65)
	_cyl(f, "Basin", 6.6, 6.6, 0.9, stone, Vector3(0, 0.45, 0), "concrete", 28, true)
	_cyl(f, "BasinInner", 6.0, 6.0, 0.05, Color(0.2, 0.3, 0.3), Vector3(0, 0.92, 0), "concrete", 28)
	var water := CylinderMesh.new()
	water.top_radius = 6.0
	water.bottom_radius = 6.0
	water.height = 0.02
	water.radial_segments = 28
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.3, 0.55, 0.5, 0.8)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.metallic = 0.5
	wm.roughness = 0.05
	var wi := MeshInstance3D.new()
	wi.mesh = water
	wi.material_override = wm
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(f, wi, "Water", Vector3(0, 0.78, 0))
	# Центральная колонна и золотой кот-статуя
	_cyl(f, "Column", 0.9, 0.7, 3.2, stone, Vector3(0, 1.6, 0), "concrete", 12, true)
	_cyl(f, "Bowl", 2.2, 1.0, 0.5, stone, Vector3(0, 3.2, 0), "concrete", 18)
	var gold := Color(0.95, 0.75, 0.2)
	U.sphere(f, "StatueBody", 0.6, gold, Vector3(0, 4.2, 0), 1.15)
	U.sphere(f, "StatueHead", 0.42, gold, Vector3(0, 5.0, 0.1), 0.95)
	for sx in [-1.0, 1.0]:
		U.cyl(f, "StatueEar", 0.14, 0.0, 0.3, gold, Vector3(sx * 0.25, 5.35, 0.1), 4)
	# Лапка машет (статичная)
	U.rod(f, "StatuePaw", Vector3(0.45, 4.3, 0.2), Vector3(0.8, 4.9, 0.25), 0.1, gold)
	# Струи
	var jet := Area3D.new()
	jet.set_script(load("res://scripts/location/park/fountain_jet.gd"))
	U.add(f, jet, "FountainJet", Vector3(0, 1.2, 0))
	var cs := CollisionShape3D.new()
	var csh := CylinderShape3D.new()
	csh.radius = 9.5
	csh.height = 3.0
	cs.shape = csh
	jet.add_child(cs)
	var jets := Node3D.new()
	U.add(jet, jets, "Jets")
	var jm := StandardMaterial3D.new()
	jm.albedo_color = Color(0.85, 0.95, 1.0, 0.45)
	jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	jm.emission_enabled = true
	jm.emission = Color(0.7, 0.85, 1.0)
	jm.emission_energy_multiplier = 0.4
	for i in 10:
		var a := TAU * i / 10.0
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 0.12
		cm.height = 3.6
		cm.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = jm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.add(jets, mi, "Jet%d" % i, Vector3(cos(a) * 5.0, 0.6 + 1.8, sin(a) * 5.0))
		mi.rotation_degrees = Vector3(sin(a) * 12.0, 0, -cos(a) * 12.0)
	_hazard(jet, 0)
	# Резиновые утки: обычные и огромные
	var spots := [[3.5, 0.2], [-2.5, 4.0], [4.5, -3.0], [-4.5, -2.0], [1.5, -5.0], [-1.0, 5.2], [5.2, 2.5]]
	for i in spots.size():
		_duck(f, Vector3(spots[i][0], 0.82, spots[i][1]), 0.45 if i % 3 else 0.85, rng.randf() * 360.0)
	# Скамейки по кругу
	for i in 8:
		var a2 := TAU * i / 8.0 + 0.2
		_bench(f, Vector3(cos(a2) * 8.6, 0, sin(a2) * 8.6), -rad_to_deg(a2) + 90.0)
	# Клумбы
	for i in 12:
		var a3 := TAU * i / 12.0
		U.sphere(f, "Flower%d" % i, 0.3, [Color(0.9, 0.3, 0.3), Color(0.95, 0.85, 0.3), Color(0.85, 0.5, 0.85)][i % 3], Vector3(cos(a3) * 10.2, 0.2, sin(a3) * 10.2), 0.8)


func _duck(parent: Node, pos: Vector3, scale: float, yaw: float) -> void:
	var d := Node3D.new()
	d.set_script(load("res://scripts/location/park/bob.gd"))
	U.add(parent, d, "Duck", pos)
	d.rotation_degrees.y = yaw
	var yel := Color(1.0, 0.85, 0.12)
	U.sphere(d, "Body", 0.35 * scale, yel, Vector3(0, 0.25 * scale, 0), 0.85)
	U.sphere(d, "Head", 0.22 * scale, yel, Vector3(0, 0.62 * scale, 0.18 * scale), 1.0)
	U.box(d, "Beak", Vector3(0.18, 0.07, 0.2) * scale, Color(0.95, 0.5, 0.1), Vector3(0, 0.58 * scale, 0.42 * scale))
	U.sphere(d, "Tail", 0.12 * scale, yel, Vector3(0, 0.38 * scale, -0.32 * scale), 0.8)
	for sx in [-1.0, 1.0]:
		U.sphere(d, "Eye", 0.04 * scale, Color(0.05, 0.05, 0.05), Vector3(sx * 0.1 * scale, 0.68 * scale, 0.34 * scale))


func _bench(parent: Node, pos: Vector3, yaw: float) -> void:
	var b := Node3D.new()
	U.add(parent, b, "Bench", pos)
	b.rotation_degrees.y = yaw
	var sb := StaticBody3D.new()
	U.add(b, sb, "Body", Vector3(0, 0.4, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(1.8, 0.8, 0.5))
	sb.add_child(cs)
	for i in 4:
		_vb(b, "Slat", Vector3(1.8, 0.05, 0.1), Color(0.6, 0.38, 0.22).darkened(rng.randf_range(0.0, 0.25)), Vector3(0, 0.45, -0.18 + i * 0.12), "wood")
	for i in 3:
		_vb(b, "BackSlat", Vector3(1.8, 0.1, 0.04), Color(0.6, 0.38, 0.22).darkened(rng.randf_range(0.0, 0.25)), Vector3(0, 0.62 + i * 0.14, -0.26), "wood")
	for sx in [-0.8, 0.8]:
		_vb(b, "Leg", Vector3(0.07, 0.8, 0.5), Color(0.15, 0.15, 0.16), Vector3(sx, 0.4, 0), "metal", 0.5, 0.5)


# ---------- карусель ----------

## Сектор диска: клиновая плита между радиусами r0..r1 и углами a0..a1, высота h (верх на y=top).
func _sector(parent: Node, nm: String, r0: float, r1: float, a0: float, a1: float, top: float, thick: float, col: Color) -> CarouselSector:
	var sec := CarouselSector.new()
	sec.set_script(load("res://scripts/location/park/carousel_sector.gd"))
	sec.name = nm
	var steps := 3
	var pts_top: Array[Vector3] = []
	var pts_bot: Array[Vector3] = []
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		pts_top.append(Vector3(sin(a) * r0, top, cos(a) * r0))
		pts_bot.append(Vector3(sin(a) * r0, top - thick, cos(a) * r0))
	for i in steps + 1:
		var a2 := lerpf(a1, a0, float(i) / steps)
		pts_top.append(Vector3(sin(a2) * r1, top, cos(a2) * r1))
		pts_bot.append(Vector3(sin(a2) * r1, top - thick, cos(a2) * r1))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(col)
	var n := pts_top.size()
	for i in n:
		var j := (i + 1) % n
		# верх (веер от первой точки) и бока
		if i > 0 and i < n - 1:
			st.add_vertex(pts_top[0])
			st.add_vertex(pts_top[i])
			st.add_vertex(pts_top[i + 1])
		st.add_vertex(pts_top[i])
		st.add_vertex(pts_bot[i])
		st.add_vertex(pts_bot[j])
		st.add_vertex(pts_top[i])
		st.add_vertex(pts_bot[j])
		st.add_vertex(pts_top[j])
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	sec.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var all: PackedVector3Array = PackedVector3Array()
	for p in pts_top:
		all.append(p)
	for p in pts_bot:
		all.append(p)
	shape.points = all
	cs.shape = shape
	sec.add_child(cs)
	var am := (a0 + a1) * 0.5
	var rm := (r0 + r1) * 0.5
	sec.centroid = Vector3(sin(am) * rm, top, cos(am) * rm)
	parent.add_child(sec)
	return sec


func _ring(parent: Node, nm: String, r0: float, r1: float, count: int, speed: float, cols: Array, horses: int, canopy: bool) -> Carousel:
	var c := Carousel.new()
	c.speed = speed
	U.add(parent, c, nm)
	for i in count:
		var a0 := TAU * i / count + 0.01
		var a1 := TAU * (i + 1) / count - 0.01
		_sector(c, "Sector%d" % i, r0, r1, a0, a1, 0.5, 0.4, cols[i % cols.size()])
	var spin := Node3D.new()
	U.add(c, spin, "Spin")
	# Лошадки на шестах: корпус, шея, голова, грива, хвост, седло
	for i in horses:
		var a := TAU * i / horses
		var rr := (r0 + r1) * 0.5
		var hp := Vector3(sin(a) * rr, 0, cos(a) * rr)
		_horse(spin, hp, a, PASTEL[i % PASTEL.size()], rng.randf_range(0.0, 0.6))
	if canopy:
		# Центральная колонна, зонтик-крыша с лампочками и фестоном
		_cyl(spin, "Pole", 0.35, 0.35, 5.0, Color(0.85, 0.8, 0.65), Vector3(0, 2.5, 0), "metal", 12)
		_cyl(spin, "Roof", 9.6, 0.4, 2.4, C_RED, Vector3(0, 6.2, 0), "paint", 24)
		_cyl(spin, "RoofRim", 9.7, 9.7, 0.3, C_CREAM, Vector3(0, 5.1, 0), "paint", 24)
		for i in 24:
			var a2 := TAU * i / 24.0
			_glow(spin, "RimBulb%d" % i, 0.11, Color(1.0, 0.85, 0.5), Vector3(sin(a2) * 9.7, 4.9, cos(a2) * 9.7), 2.2)
	return c


func _horse(parent: Node, pos: Vector3, yaw: float, col: Color, phase: float) -> void:
	var h := Node3D.new()
	U.add(parent, h, "Horse", pos)
	h.rotation.y = yaw + PI * 0.5
	U.rod(h, "Pole", Vector3(0, 0.5, 0), Vector3(0, 5.0, 0), 0.04, Color(0.9, 0.85, 0.6), 0.4, 0.6)
	var y := 1.5 + phase
	U.sphere(h, "Body", 0.5, col, Vector3(0, y, 0), 1.0).scale = Vector3(0.55, 0.6, 1.1)
	U.sphere(h, "Chest", 0.38, col, Vector3(0, y + 0.1, 0.55), 1.0)
	U.rod(h, "Neck", Vector3(0, y + 0.2, 0.6), Vector3(0, y + 0.85, 0.9), 0.17, col)
	U.sphere(h, "Head", 0.24, col, Vector3(0, y + 0.95, 1.05), 1.0).scale = Vector3(0.7, 0.8, 1.2)
	for sx in [-1.0, 1.0]:
		U.cyl(h, "Ear", 0.06, 0.0, 0.18, col, Vector3(sx * 0.1, y + 1.2, 0.95), 4)
		U.sphere(h, "Eye", 0.035, Color(0.05, 0.05, 0.05), Vector3(sx * 0.14, y + 1.0, 1.15))
	U.rod(h, "Mane", Vector3(0, y + 1.1, 0.95), Vector3(0, y + 0.3, 0.55), 0.06, Color(0.95, 0.9, 0.7))
	U.rod(h, "Tail", Vector3(0, y + 0.05, -0.55), Vector3(0, y - 0.7, -0.85), 0.07, Color(0.95, 0.9, 0.7))
	U.box(h, "Saddle", Vector3(0.5, 0.08, 0.45), Color(0.65, 0.15, 0.15), Vector3(0, y + 0.35, 0.0))
	for sx in [-0.2, 0.2]:
		for z in [0.4, -0.4]:
			U.rod(h, "Leg", Vector3(sx, y - 0.2, z), Vector3(sx + (0.1 if z > 0 else -0.05), y - 0.75, z + (0.2 if z > 0 else -0.2)), 0.07, col)


func _carousel() -> void:
	var cr := _holder("Carousel", CAROUSEL)
	var cols := [C_RED, C_CREAM, Color(0.35, 0.6, 0.7), C_CREAM]
	# Постамент в центре: неподвижный, на нём кот
	_cyl(cr, "Podium", 2.2, 5.8, 1.0, Color(0.85, 0.8, 0.65), Vector3(0, 0.5, 0), "concrete", 24, true)
	_cyl(cr, "PodiumTop", 2.1, 2.1, 0.05, C_RED, Vector3(0, 1.0, 0), "paint", 18)
	var nest := Node3D.new()
	U.add(cr, nest, "Nest", Vector3(0, 1.0, 0))
	U.sphere(nest, "Cushion", 0.5, Color(0.85, 0.3, 0.4), Vector3(0, 0.1, 0), 0.3)
	# Внешнее кольцо крутится всегда (тир 0)
	var outer := _ring(cr, "Outer", 5.5, 9.0, 12, 0.45, cols, 12, true)
	_hazard(outer, 0)
	# Внутреннее кольцо: до средней стоит, на сложной крутится навстречу
	var inner_static := _ring(cr, "InnerStatic", 4.0, 5.5, 8, 0.0, cols, 8, false)
	_hazard(inner_static, 0, 1)
	var inner_spin := _ring(cr, "InnerSpin", 4.0, 5.5, 8, -0.9, cols, 8, false)
	_hazard(inner_spin, 2)
	# Вывеска «не работает» и будка оператора
	var booth := Node3D.new()
	U.add(cr, booth, "Operator", Vector3(10.5, 0, 6.0))
	_sb(booth, "Walls", Vector3(1.6, 2.2, 1.6), Color(0.85, 0.5, 0.35), Vector3(0, 1.1, 0), "paint")
	_vb(booth, "Roof", Vector3(2.0, 0.15, 2.0), C_RED, Vector3(0, 2.3, 0), "paint")
	var ob := _vb(booth, "Board", Vector3(1.3, 0.6, 0.05), Color(0.95, 0.85, 0.3), Vector3(0, 1.5, 0.83), "paint")
	U.label(ob, "Text", "SIGN_PARK_OFF", Vector3(0, 0, 0.04), 0.1, Color(0.15, 0.1, 0.05))


# ---------- батутная арена ----------

func _arena() -> void:
	var a := _holder("Arena", Vector3(-12.0, 0, 56.0))
	# Площадка с сеткой по краю; 3×3 батута: рабочие (тир 0) и сломанные поверх них на средней
	_vb(a, "Floor", Vector3(16.0, 0.1, 16.0), Color(0.3, 0.3, 0.33), Vector3(0, 0.05, 0), "bitumen")
	for i in 4:
		for sx in [-8.0, 8.0]:
			_vb(a, "NetPost", Vector3(0.1, 3.0, 0.1), C_STEEL, Vector3(sx, 1.5, -6.0 + i * 4.0), "metal", 0.5, 0.4)
	for sx in [-8.0, 8.0]:
		_vb(a, "NetTop", Vector3(0.05, 0.05, 12.2), C_STEEL, Vector3(sx, 3.0, 0), "metal")
		var net := _vb(a, "Net", Vector3(0.02, 2.4, 12.0), Color(0.8, 0.8, 0.8, 0.35), Vector3(sx, 1.8, 0), "paint")
	var tcol := [Color(0.9, 0.3, 0.3), Color(0.3, 0.55, 0.85), Color(0.95, 0.8, 0.25)]
	var k := 0
	for ix in 3:
		for iz in 3:
			var p := Vector3(-4.5 + ix * 4.5, 0, -4.5 + iz * 4.5)
			var broken := (ix + iz) % 3 == 1
			var tr := Area3D.new()
			if broken:
				tr.set_script(load("res://scripts/location/park/broken_trampoline.gd"))
			else:
				tr.set_script(load("res://scripts/trampoline.gd"))
				tr.set("bounce_impulse", 12.0)
			U.add(a, tr, "Trampoline%d" % k, p + Vector3(0, 0.35, 0))
			var cs := CollisionShape3D.new()
			cs.shape = _bshape(Vector3(3.2, 0.6, 3.2))
			tr.add_child(cs)
			_cyl(tr, "Frame", 1.9, 1.9, 0.35, C_STEEL, Vector3(0, -0.05, 0), "metal", 16)
			var mat_col: Color = tcol[k % 3] if not broken else Color(0.35, 0.3, 0.3)
			_cyl(tr, "Mat", 1.6, 1.6, 0.05, mat_col, Vector3(0, 0.15, 0), "paint", 16)
			if broken:
				_hazard(tr, 1)
				_vb(tr, "Rip", Vector3(1.2, 0.02, 0.1), Color(0.05, 0.05, 0.05), Vector3(0, 0.19, 0.2))
			k += 1
	# Лавка и вывеска «Батуты»
	_bench(a, Vector3(0, 0, 9.0), 180.0)


# ---------- американские горки ----------

func _coaster() -> void:
	var c := _holder("Coaster")
	# Лестница на станцию и сама станция
	_slab(c, "StationRamp", Vector3(13.0, 0.0, 32.0), Vector3(28.0, 4.0, 32.0), 2.6, Color(0.55, 0.5, 0.42))
	_sb(c, "StationDeck", Vector3(12.0, 0.3, 5.5), Color(0.55, 0.5, 0.42), Vector3(33.0, 3.85, 32.0), "wood")
	for i in 4:
		_vb(c, "StationPost", Vector3(0.3, 3.8, 0.3), C_STEEL, Vector3(28.4 + i * 3.4, 1.9, 29.4), "metal", 0.5, 0.4)
		_vb(c, "StationPostB", Vector3(0.3, 3.8, 0.3), C_STEEL, Vector3(28.4 + i * 3.4, 1.9, 34.6), "metal", 0.5, 0.4)
	# Крыша станции: полосатая
	for i in 6:
		_vb(c, "RoofStripe%d" % i, Vector3(2.0, 0.2, 6.6), C_RED if i % 2 == 0 else C_CREAM, Vector3(27.5 + i * 2.1, 7.6, 32.0), "paint")
	for i in 4:
		_vb(c, "RoofPost", Vector3(0.2, 3.6, 0.2), C_STEEL, Vector3(28.0 + i * 3.8, 5.8, 29.4), "metal", 0.5, 0.4)
		_vb(c, "RoofPostB", Vector3(0.2, 3.6, 0.2), C_STEEL, Vector3(28.0 + i * 3.8, 5.8, 34.6), "metal", 0.5, 0.4)
	# Подъёмная горка до вершины: настил, рельсы-зубчатка, опоры
	var a := Vector3(39.0, 4.0, 32.0)
	var b := Vector3(62.0, SUMMIT_Y, 32.0)
	_slab(c, "LiftRamp", a, b, 2.2, Color(0.5, 0.45, 0.4))
	for i in 12:
		var t := float(i + 1) / 13.0
		var p := a.lerp(b, t)
		_vb(c, "LiftSupport%d" % i, Vector3(0.3, p.y, 0.3), C_STEEL, Vector3(p.x, p.y * 0.5 - 0.1, 29.4), "metal", 0.5, 0.4)
		_vb(c, "LiftSupportB%d" % i, Vector3(0.3, p.y, 0.3), C_STEEL, Vector3(p.x, p.y * 0.5 - 0.1, 34.6), "metal", 0.5, 0.4)
		_vb(c, "LiftBrace%d" % i, Vector3(0.12, 0.12, 5.4), C_STEEL, Vector3(p.x, p.y - 0.6, 32.0), "metal", 0.5, 0.4)
	# Вершина: площадка, ограждение, перила
	_sb(c, "Summit", Vector3(6.6, 0.3, 5.5), Color(0.5, 0.45, 0.4), Vector3(65.3, SUMMIT_Y - 0.15, 32.0), "wood")
	for i in 4:
		_vb(c, "SummitPost", Vector3(0.3, SUMMIT_Y, 0.3), C_STEEL, Vector3(62.4 + i * 1.9, SUMMIT_Y * 0.5, 29.4), "metal", 0.5, 0.4)
		_vb(c, "SummitPostB", Vector3(0.3, SUMMIT_Y, 0.3), C_STEEL, Vector3(62.4 + i * 1.9, SUMMIT_Y * 0.5, 34.6), "metal", 0.5, 0.4)
	_vb(c, "SummitRailE", Vector3(0.06, 0.06, 5.2), C_STEEL, Vector3(68.5, SUMMIT_Y + 1.0, 32.0), "metal", 0.5, 0.4)
	_vb(c, "SummitRailS", Vector3(6.0, 0.06, 0.06), C_STEEL, Vector3(65.3, SUMMIT_Y + 1.0, 34.7), "metal", 0.5, 0.4)
	# Вагонетка на вершине (там сидит кот): четыре сиденья
	var cart := Node3D.new()
	U.add(c, cart, "SummitCart", Vector3(66.0, SUMMIT_Y, 32.0))
	_sb(cart, "Body", Vector3(3.2, 0.6, 1.4), C_RED, Vector3(0, 0.4, 0), "metal", 0.5, 0.3)
	for i in 3:
		_vb(cart, "Seat%d" % i, Vector3(0.7, 0.6, 1.1), Color(0.95, 0.9, 0.7), Vector3(-1.0 + i * 1.0, 0.95, 0.0), "paint")
	_vb(cart, "Bar", Vector3(3.0, 0.08, 0.08), C_STEEL, Vector3(0, 1.4, 0.55), "metal")
	# Остальной трек: сплайн вокруг колеса и обратно к станции (визуал): рельсы, шпалы, опоры
	var pts: Array[Vector3] = [Vector3(68.4, SUMMIT_Y, 32.0), Vector3(76.0, 12.5, 30.0), Vector3(82.0, 8.0, 18.0), Vector3(80.0, 3.0, 4.0), Vector3(70.0, 1.5, -10.0), Vector3(54.0, 5.0, -12.0), Vector3(42.0, 9.0, -2.0), Vector3(36.0, 6.0, 14.0), Vector3(34.0, 4.2, 24.0), Vector3(33.0, 4.0, 29.0)]
	_track(c, pts)
	# Вывеска «Американские горки» над станцией
	var sb := _vb(c, "StationSign", Vector3(8.0, 1.4, 0.15), Color(0.2, 0.45, 0.65), Vector3(33.0, 9.4, 35.2), "paint", 0.6)
	U.label(sb, "Text", "SIGN_PARK_COASTER", Vector3(0, 0, 0.1), 0.34, Color(0.95, 0.9, 0.7))


func _spline(pts: Array[Vector3], t: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 0.9999) * n
	var i := int(f)
	var u := f - i
	var p0 := pts[maxi(i - 1, 0)]
	var p1 := pts[i]
	var p2 := pts[mini(i + 1, n)]
	var p3 := pts[mini(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u * u + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * u * u * u)


func _track(parent: Node, pts: Array[Vector3]) -> void:
	var tr := Node3D.new()
	U.add(parent, tr, "Track")
	var steps := 70
	var prev := _spline(pts, 0.0)
	for i in range(1, steps + 1):
		var cur := _spline(pts, float(i) / steps)
		var d := cur - prev
		var side := d.cross(Vector3.UP).normalized() * 0.55
		for sg in [-1.0, 1.0]:
			U.rod(tr, "Rail", prev + side * sg + Vector3(0, 0.3, 0), cur + side * sg + Vector3(0, 0.3, 0), 0.05, Color(0.55, 0.3, 0.2), 0.6, 0.4)
		U.rod(tr, "Sleeper", prev + side + Vector3(0, 0.22, 0), prev - side + Vector3(0, 0.22, 0), 0.04, Color(0.4, 0.28, 0.18))
		if i % 3 == 0 and cur.y > 1.6:
			U.rod(tr, "Support", Vector3(cur.x, 0.0, cur.z), cur + Vector3(0, 0.1, 0), 0.12, C_STEEL, 0.6, 0.4)
			U.rod(tr, "Cross", cur + side * 0.9 - Vector3(0, 0.1, 0), cur - side * 0.9 - Vector3(0, 0.1, 0), 0.06, C_STEEL, 0.6, 0.4)
		prev = cur


# ---------- колесо обозрения ----------

func _wheel() -> void:
	var w := _holder("Wheel")
	var hub := WHEEL_HUB
	# Опоры-«А»: две пары ног и ось
	for sx in [-1.2, 1.2]:
		U.rod(w, "LegA", Vector3(hub.x + sx, hub.y, hub.z), Vector3(hub.x + sx * 1.5, 0.0, hub.z - 9.0), 0.25, Color(0.85, 0.85, 0.82), 0.6, 0.3)
		U.rod(w, "LegB", Vector3(hub.x + sx, hub.y, hub.z), Vector3(hub.x + sx * 1.5, 0.0, hub.z + 9.0), 0.25, Color(0.85, 0.85, 0.82), 0.6, 0.3)
	U.rod(w, "Axle", Vector3(hub.x - 1.6, hub.y, hub.z), Vector3(hub.x + 1.6, hub.y, hub.z), 0.4, C_RED, 0.5, 0.4)
	# Обода и спицы
	var n := 24
	for sx in [-1.0, 1.0]:
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			U.rod(w, "Rim", hub + Vector3(sx, sin(a0) * WHEEL_R, cos(a0) * WHEEL_R), hub + Vector3(sx, sin(a1) * WHEEL_R, cos(a1) * WHEEL_R), 0.1, Color(0.9, 0.9, 0.88) if i % 2 == 0 else C_RED, 0.6, 0.3)
		for i in 12:
			var a := TAU * i / 12.0
			U.rod(w, "Spoke", hub + Vector3(sx * 0.8, 0, 0), hub + Vector3(sx, sin(a) * WHEEL_R, cos(a) * WHEEL_R), 0.05, C_STEEL, 0.6, 0.4)
	for i in 12:
		var a := TAU * i / 12.0
		U.rod(w, "RimTie", hub + Vector3(-1, sin(a) * WHEEL_R, cos(a) * WHEEL_R), hub + Vector3(1, sin(a) * WHEEL_R, cos(a) * WHEEL_R), 0.06, C_STEEL, 0.6, 0.4)
		_gondola(w, hub + Vector3(0, sin(a) * WHEEL_R, cos(a) * WHEEL_R), PASTEL[i % PASTEL.size()], i == 0, i)
	# Лампочки по ободу
	for i in 48:
		var a2 := TAU * i / 48.0
		_glow(w, "WheelBulb%d" % i, 0.08, Color(1.0, 0.85, 0.5), hub + Vector3(1.1, sin(a2) * (WHEEL_R + 0.1), cos(a2) * (WHEEL_R + 0.1)), 1.8)
	# Вывеска
	var sg := _vb(w, "WheelSign", Vector3(5.0, 1.1, 0.12), Color(0.2, 0.45, 0.65), Vector3(hub.x, 4.2, hub.z + 10.2), "paint")
	U.label(sg, "Text", "SIGN_PARK_WHEEL", Vector3(0, 0, 0.08), 0.26, Color(0.95, 0.9, 0.7))
	# Мостик от вершины горок до кабинки: проваливающиеся доски (FallingPlatform)
	var bridge := Node3D.new()
	U.add(w, bridge, "Bridge")
	for i in 4:
		var z := 29.0 - 0.6 - i * 1.7
		var fp := StaticBody3D.new()
		fp.set_script(load("res://scripts/falling_platform.gd"))
		fp.set("delay", 0.8)
		fp.set("respawn", 3.5)
		U.add(bridge, fp, "Plank%d" % i, Vector3(68.0, SUMMIT_Y - 0.1, z))
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _bshape(Vector3(2.0, 0.2, 1.2))
		fp.add_child(cs)
		_vb(fp, "Mesh", Vector3(2.0, 0.2, 1.2), Color(0.55, 0.4, 0.26).darkened(0.07 * i), Vector3.ZERO, "wood")
		var sensor := Area3D.new()
		sensor.name = "Sensor"
		sensor.collision_layer = 0
		sensor.collision_mask = 1
		var ss := CollisionShape3D.new()
		ss.shape = _bshape(Vector3(1.8, 0.4, 1.0))
		sensor.add_child(ss)
		U.add(fp, sensor, "Sensor", Vector3(0, 0.3, 0))
	for sg2 in [-1.0, 1.0]:
		U.rod(bridge, "Rope", Vector3(68.0 + sg2 * 1.1, SUMMIT_Y + 0.9, 29.2), Vector3(68.0 + sg2 * 1.1, SUMMIT_Y + 0.9, 22.8), 0.03, Color(0.65, 0.55, 0.38))
		U.rod(bridge, "RopePostA", Vector3(68.0 + sg2 * 1.1, SUMMIT_Y, 29.2), Vector3(68.0 + sg2 * 1.1, SUMMIT_Y + 1.0, 29.2), 0.05, C_STEEL)
		U.rod(bridge, "RopePostB", Vector3(68.0 + sg2 * 1.1, SUMMIT_Y, 22.8), Vector3(68.0 + sg2 * 1.1, SUMMIT_Y + 1.0, 22.8), 0.05, C_STEEL)
	# Табличка у моста
	var wb := _vb(bridge, "PlankSign", Vector3(1.4, 0.6, 0.05), Color(0.95, 0.4, 0.2), Vector3(66.2, SUMMIT_Y + 1.2, 29.3), "paint")
	U.label(wb, "Text", "MSG_PLANK", Vector3(0, 0, 0.04), 0.07, Color(0.1, 0.05, 0.05)).rotation_degrees.y = 0.0


func _gondola(parent: Node, rim: Vector3, col: Color, solid: bool, idx: int) -> void:
	var g := Node3D.new()
	U.add(parent, g, "Gondola%d" % idx, rim - Vector3(0, 1.0, 0))
	# Пол, борта, стойки, крыша, окна
	if solid:
		_sb(g, "Floor", Vector3(2.4, 0.12, 2.6), col.darkened(0.2), Vector3(0, -0.06, 0), "wood")
	else:
		_vb(g, "Floor", Vector3(2.4, 0.12, 2.6), col.darkened(0.2), Vector3(0, -0.06, 0), "wood")
	for sx in [-1.2, 1.2]:
		_vb(g, "Side", Vector3(0.08, 0.6, 2.6), col, Vector3(sx, 0.3, 0), "paint", 0.7)
	for sz in [-1.3, 1.3]:
		_vb(g, "End", Vector3(2.4, 0.6, 0.08), col, Vector3(0, 0.3, sz), "paint", 0.7)
	for sx in [-1.2, 1.2]:
		for sz in [-1.3, 1.3]:
			_vb(g, "Post", Vector3(0.06, 1.5, 0.06), C_STEEL, Vector3(sx, 0.75, sz), "metal", 0.5, 0.4)
	_vb(g, "Roof", Vector3(2.8, 0.1, 3.0), Color(0.9, 0.88, 0.8), Vector3(0, 1.55, 0), "paint")
	_vb(g, "Seat", Vector3(1.8, 0.12, 0.6), Color(0.45, 0.28, 0.18), Vector3(0, 0.3, -0.6), "wood")
	U.rod(g, "Hanger", Vector3(0, 1.6, 0), Vector3(0, 1.0, 0), 0.04, C_STEEL)


# ---------- вагонетки ----------

func _cart_body(parent: Node, col: Color) -> void:
	_vb(parent, "Tub", Vector3(1.4, 0.8, 2.0), col, Vector3(0, 0.75, 0), "metal", 0.5, 0.3)
	_vb(parent, "Rim", Vector3(1.5, 0.1, 2.1), col.darkened(0.3), Vector3(0, 1.2, 0), "metal")
	for sx in [-0.65, 0.65]:
		for sz in [-0.7, 0.7]:
			var w := CylinderMesh.new()
			w.top_radius = 0.25
			w.bottom_radius = 0.25
			w.height = 0.12
			w.radial_segments = 12
			var mi := MeshInstance3D.new()
			mi.mesh = w
			mi.material_override = U.mat(Color(0.1, 0.1, 0.11), 0.9)
			U.add(parent, mi, "Wheel", Vector3(sx, 0.3, sz))
			mi.rotation_degrees.z = 90
	# Глаза-фары и кружок «призрака»
	for sx in [-0.3, 0.3]:
		_glow(parent, "Eye", 0.14, Color(0.95, 1.0, 0.9), Vector3(sx, 0.95, 1.03), 1.4)
		_glow(parent, "Pupil", 0.06, Color(0.05, 0.1, 0.08), Vector3(sx, 0.95, 1.14), 0.2)


func _runaway(nm: String, path: PackedVector3Array, speed: float, col: Color) -> AnimatableBody3D:
	var cart := AnimatableBody3D.new()
	cart.set_script(load("res://scripts/location/warehouse/forklift_ghost.gd"))
	cart.set("path", path)
	cart.set("speed", speed)
	cart.set("turn_rate", 6.0)
	cart.set("push_message_key", "MSG_CART")
	U.add(root_node.get_node("Carts"), cart, nm, path[0])
	_cart_body(cart, col)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(1.4, 1.0, 2.0))
	cs.position = Vector3(0, 0.8, 0)
	cart.add_child(cs)
	return cart


func _carts() -> void:
	var c := _holder("Carts")
	# Рельсы по земле: две дорожки
	for track in [[-50.0, 10.0, 40.0], [-50.0, 34.0, 56.0]]:
		var x0: float = track[0]
		var x1: float = track[1]
		var z: float = track[2]
		for sg in [-0.6, 0.6]:
			_vb(c, "GroundRail", Vector3(x1 - x0, 0.08, 0.08), Color(0.5, 0.3, 0.2), Vector3((x0 + x1) * 0.5, 0.12, z + sg), "metal", 0.6, 0.4)
		for i in int((x1 - x0) / 1.0):
			_vb(c, "GroundSleeper", Vector3(0.18, 0.08, 1.7), Color(0.4, 0.28, 0.18), Vector3(x0 + 0.5 + i, 0.07, z), "wood")
		# Упоры
		for x in [x0, x1]:
			_sb(c, "Stopper", Vector3(0.4, 0.8, 1.6), C_RED, Vector3(x, 0.4, z), "paint")
	var c1 := _runaway("Cart1", PackedVector3Array([Vector3(-46.0, 0.0, 40.0), Vector3(6.0, 0.0, 40.0)]), 6.0, C_RED)
	_hazard(c1, 1)
	var c2 := _runaway("Cart2", PackedVector3Array([Vector3(-46.0, 0.0, 56.0), Vector3(30.0, 0.0, 56.0)]), 9.5, Color(0.3, 0.55, 0.8))
	_hazard(c2, 2)
	var sg := _vb(c, "CartSign", Vector3(1.4, 0.8, 0.06), Color(0.95, 0.5, 0.2), Vector3(-9.0, 1.4, 38.0), "paint")
	U.label(sg, "Text", "SIGN_PARK_CART", Vector3(0, 0, 0.05), 0.11, Color(0.1, 0.05, 0.05))
	_vb(c, "CartSignPost", Vector3(0.08, 1.4, 0.08), C_STEEL, Vector3(-9.0, 0.7, 38.0), "metal")


# ---------- киоски и аттракционы-декорации ----------

func _kiosk(parent: Node, nm: String, pos: Vector3, yaw: float, col: Color, sign_key: String, roof_col: Color) -> void:
	var k := Node3D.new()
	U.add(parent, k, nm, pos)
	k.rotation_degrees.y = yaw
	_sb(k, "Walls", Vector3(3.2, 2.5, 2.4), col, Vector3(0, 1.25, 0), "paint")
	_vb(k, "Counter", Vector3(2.4, 0.1, 0.6), Color(0.55, 0.38, 0.24), Vector3(0, 1.05, 1.45), "wood")
	_vb(k, "Awning", Vector3(3.6, 0.1, 1.8), roof_col, Vector3(0, 2.35, 1.2), "paint").rotation_degrees.x = -12.0
	for sx in [-1.7, 1.7]:
		_vb(k, "AwningPost", Vector3(0.06, 1.7, 0.06), C_STEEL, Vector3(sx, 1.2, 2.0), "metal")
	_vb(k, "Roof", Vector3(3.5, 0.2, 2.7), roof_col, Vector3(0, 2.6, 0), "paint")
	var b := _vb(k, "Board", Vector3(2.2, 0.7, 0.06), Color(0.95, 0.9, 0.7), Vector3(0, 2.95, 1.2), "paint")
	U.label(b, "Text", sign_key, Vector3(0, 0, 0.05), 0.15, Color(0.7, 0.15, 0.12))


func _kiosks() -> void:
	var k := _holder("Kiosks")
	_kiosk(k, "IceCream", Vector3(-13.0, 0, 38.0), 30.0, Color(0.55, 0.8, 0.9), "SIGN_PARK_ICE", C_RED)
	_kiosk(k, "Popcorn", Vector3(14.0, 0, 55.0), -30.0, Color(0.95, 0.85, 0.4), "SIGN_PARK_CORN", Color(0.3, 0.55, 0.65))
	_kiosk(k, "Shooting", Vector3(-26.0, 0, 52.0), 70.0, Color(0.85, 0.5, 0.35), "SIGN_PARK_SHOOT", C_CREAM)
	# Комната смеха: фасад с кривыми зеркалами
	var lh := Node3D.new()
	U.add(k, lh, "LaughHouse", Vector3(26.0, 0, 62.0))
	lh.rotation_degrees.y = -90.0
	_sb(lh, "Walls", Vector3(10.0, 4.0, 5.0), Color(0.55, 0.35, 0.7), Vector3(0, 2.0, 0), "paint")
	for i in 4:
		_vb(lh, "Mirror%d" % i, Vector3(1.6, 2.4, 0.06), Color(0.75, 0.82, 0.88), Vector3(-3.6 + i * 2.4, 1.6, 2.53), "metal", 0.1, 0.9)
	var lb := _vb(lh, "Board", Vector3(6.0, 1.0, 0.1), Color(0.95, 0.85, 0.3), Vector3(0, 4.6, 2.5), "paint")
	U.label(lb, "Text", "SIGN_PARK_LAUGH", Vector3(0, 0, 0.07), 0.24, Color(0.5, 0.1, 0.4))
	for i in 3:
		_vb(lh, "Tower", Vector3(1.2, 2.0 + i * 0.6, 1.2), Color(0.95, 0.6, 0.3), Vector3(-3.5 + i * 3.5, 4.0 + (2.0 + i * 0.6) * 0.5, 0), "paint")
	# Павильон автодрома: крыша на столбах и ограда
	var bc := Node3D.new()
	U.add(k, bc, "BumperPavilion", Vector3(-48.0, 0, 30.0))
	_vb(bc, "Floor", Vector3(16.0, 0.1, 12.0), Color(0.3, 0.32, 0.35), Vector3(0, 0.05, 0), "metal")
	_vb(bc, "Roof", Vector3(17.0, 0.3, 13.0), Color(0.85, 0.35, 0.3), Vector3(0, 5.2, 0), "paint")
	for sx in [-8.0, 8.0]:
		for sz in [-6.0, 6.0]:
			_vb(bc, "Pole", Vector3(0.3, 5.1, 0.3), C_STEEL, Vector3(sx, 2.55, sz), "metal", 0.5, 0.4)
	for i in 5:
		var car := Node3D.new()
		U.add(bc, car, "Bumper%d" % i, Vector3(rng.randf_range(-5, 5), 0.0, rng.randf_range(-3.5, 3.5)))
		car.rotation_degrees.y = rng.randf() * 360.0
		var cs := StaticBody3D.new()
		U.add(car, cs, "Body", Vector3(0, 0.4, 0))
		var csh := CollisionShape3D.new()
		csh.shape = _bshape(Vector3(1.4, 0.8, 1.8))
		cs.add_child(csh)
		_vb(car, "Tub", Vector3(1.4, 0.5, 1.8), PASTEL[i % PASTEL.size()], Vector3(0, 0.4, 0), "paint", 0.5)
		_vb(car, "Rubber", Vector3(1.5, 0.15, 1.9), Color(0.1, 0.1, 0.1), Vector3(0, 0.3, 0), "paint")
		_vb(car, "Pole", Vector3(0.04, 4.4, 0.04), C_STEEL, Vector3(0, 2.6, -0.6), "metal")
	# Мусорные баки-«урны» и пустые тележки с мороженым
	for i in 8:
		var bp := Vector3(rng.randf_range(-12, 12), 0.0, rng.randf_range(34, 74))
		_cyl(k, "Bin%d" % i, 0.28, 0.32, 0.8, Color(0.2, 0.4, 0.3), bp + Vector3(0, 0.4, 0), "metal", 10, true)


# ---------- деревья по периметру ----------

func _trees() -> void:
	var t := _holder("Trees")
	for i in 260:
		var a := rng.randf() * TAU
		var r := rng.randf_range(72.0, 170.0)
		var p := Vector3(cos(a) * r * 1.15, 0.0, sin(a) * r)
		if absf(p.x) < 90.0 and p.z > -86.0 and p.z < GATE_Z + 4.0 and absf(p.x) < 84.0:
			continue
		var sp := Node3D.new()
		sp.set_script(load("res://scripts/location/forest/forest_prop.gd"))
		if absf(p.x) < 16.0 and p.z > 0.0:
			continue
		var species: String = ["spruce", "birch", "oak", "spruce"][i % 4]
		sp.set("species", species)
		U.add(t, sp, "Tree%d" % i, p)
		sp.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
		sp.rotation_degrees.y = rng.randf() * 360.0
	# Деревья внутри парка вдоль аллей: берёзы и липы
	for i in 60:
		var x := rng.randf_range(-78.0, 78.0)
		var z := rng.randf_range(-78.0, 74.0)
		var p2 := Vector3(x, 0, z)
		# не на дорожках и аттракционах
		if p2.distance_to(CAROUSEL) < 14.0 or p2.distance_to(FOUNTAIN) < 17.0 or p2.distance_to(Vector3(68, 0, 10)) < 16.0:
			continue
		if absf(x) < 6.0 and z > 0.0:
			continue
		if x > 10.0 and x < 76.0 and z > 24.0 and z < 40.0:
			continue
		if x > 28.0 and x < 90.0 and z > -16.0 and z < 36.0:
			continue
		if x > -22.0 and x < -2.0 and z > 46.0 and z < 66.0:
			continue
		if absf(z - 40.0) < 3.0 or absf(z - 56.0) < 3.0:
			continue
		var sp2 := Node3D.new()
		sp2.set_script(load("res://scripts/location/forest/forest_prop.gd"))
		sp2.set("species", "birch" if i % 3 else "oak")
		U.add(t, sp2, "ParkTree%d" % i, p2)
		sp2.scale = Vector3.ONE * rng.randf_range(0.6, 1.0)
		sp2.rotation_degrees.y = rng.randf() * 360.0


# ---------- фонари с гирляндами ----------

func _lamps() -> void:
	var l := _holder("Lamps")
	var posts := []
	for z in [74.0, 64.0, 54.0, 38.0, 28.0]:
		posts.append(Vector3(-5.5, 0, z))
		posts.append(Vector3(5.5, 0, z))
	for p in [Vector3(-17, 0, 36), Vector3(17, 0, 36), Vector3(-30, 0, 4), Vector3(30, 0, 14), Vector3(0, 0, 8), Vector3(0, 0, -20), Vector3(60, 0, 40), Vector3(-45, 0, 44)]:
		posts.append(p)
	var i := 0
	for p in posts:
		_lamp_post(l, p, i % 3 == 0)
		i += 1
	# Гирлянды лампочек между столбами вдоль главной аллеи
	for z in [74.0, 64.0, 54.0]:
		for k in 12:
			var t := float(k) / 11.0
			var x := lerpf(-5.5, 5.5, t)
			var y := 5.2 - 0.9 * sin(t * PI)
			_glow(l, "Garland", 0.08, Color(1.0, [0.85, 0.5, 0.7, 0.9][k % 4], 0.5), Vector3(x, y, z), 1.8)


func _lamp_post(parent: Node, pos: Vector3, lit: bool) -> void:
	var p := Node3D.new()
	U.add(parent, p, "LampPost", pos)
	_vb(p, "Post", Vector3(0.14, 5.0, 0.14), Color(0.15, 0.2, 0.18), Vector3(0, 2.5, 0), "metal", 0.5, 0.5)
	_vb(p, "Base", Vector3(0.4, 0.6, 0.4), Color(0.15, 0.2, 0.18), Vector3(0, 0.3, 0), "metal", 0.5, 0.5)
	for i in 2:
		_vb(p, "Arm", Vector3(1.2, 0.08, 0.08), Color(0.15, 0.2, 0.18), Vector3((i * 2 - 1) * 0.55, 5.0, 0), "metal")
		_glow(p, "Globe", 0.28, Color(1.0, 0.85, 0.55) if lit else Color(0.5, 0.45, 0.4), Vector3((i * 2 - 1) * 1.1, 4.85, 0), 2.5 if lit else 0.3)
	if lit:
		var li := OmniLight3D.new()
		li.light_color = Color(1.0, 0.8, 0.5)
		li.light_energy = 1.1
		li.omni_range = 14.0
		U.add(p, li, "Light", Vector3(0, 4.4, 0))


# ---------- таблички ----------

func _signs() -> void:
	var s := _holder("Signs")
	var sg := _vb(s, "RouteSign", Vector3(1.6, 0.8, 0.06), Color(0.2, 0.45, 0.65), Vector3(-6.5, 1.8, 58.0), "paint")
	U.label(sg, "Text", "SIGN_PARK_NAME", Vector3(0, 0, 0.05), 0.065, Color(0.95, 0.9, 0.7))
	_vb(s, "RouteSignPost", Vector3(0.08, 1.8, 0.08), C_STEEL, Vector3(-6.5, 0.9, 58.0), "metal")


# ---------- кот ----------

func _cat() -> void:
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	var m0 := Marker3D.new()
	U.add(spots, m0, "Podium", CAROUSEL + Vector3(0, 1.05, 0))
	m0.rotation_degrees.y = 180.0
	var m1 := Marker3D.new()
	U.add(spots, m1, "SummitCart", Vector3(66.0, SUMMIT_Y + 1.0, 32.0))
	m1.rotation_degrees.y = 270.0
	var m2 := Marker3D.new()
	U.add(spots, m2, "Gondola", Vector3(WHEEL_HUB.x, WHEEL_HUB.y - 1.0, WHEEL_HUB.z + WHEEL_R))
	m2.rotation_degrees.y = 0.0
	CatBuilder.build(root_node, m0.position)


func _players_and_checkpoints() -> void:
	var holder := _holder("Players")
	U.player(holder, SPAWN + Vector3(0, 0.6, 0))
	var cps := _holder("Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, SPAWN + Vector3(2.0, 0.0, 0.0))
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(11.0, 0.0, 33.0))
	U.checkpoint(cps, "Checkpoint2", 2, Vector3(63.5, SUMMIT_Y, 31.0))
