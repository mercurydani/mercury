@tool
extends SceneTree
## Генерирует res://scenes/locations/forest.tscn: локация 2 «Нора у ручья» (лес и овраг, русская глубинка).
## Запуск: godot --headless --path godot --script res://tools/build_forest.gd
## Рельеф, вода, лес и трава строятся при загрузке сцены скриптами (RavineTerrain, Scatter), в .tscn лежат только параметры
## и рукотворные объекты: стоянка с «буханкой», мостки, дубы с котом, вышка, ЛЭП, опасности.
##
## Карта (X на восток, ручей течёт к +X и падает с водопада на x≈72; «юг» — это +Z):
##   спавн на южном берегу у стоянки, x=-58; ручей мелкий (по колено), омут на x=22;
##   дуб A (простая): низкая ветка у южного берега; дуб B (средняя): ветка 3.4 м, мшистый скользкий лаз;
##   дуб C (сложная): ветка на 5 м над ручьём, два пролёта брёвен.
## Опасности (группа "hazard", мета "tier"): 0 течение и белка, 1 скользкий лаз + капкан, 2 плывущие ящики + вторая белка.

const U := preload("res://scripts/location/loc_util.gd")
const R := preload("res://scripts/location/forest/ravine_terrain.gd")

var root_node: Node3D
var rng := RandomNumberGenerator.new()

const C_BARK := Color(0.42, 0.33, 0.26)
const C_WOOD := Color(0.62, 0.45, 0.28)
const C_RUST := Color(0.55, 0.3, 0.17)
const C_PAINT := Color(0.85, 0.82, 0.7)


func _init() -> void:
	rng.seed = 1993
	root_node = Node3D.new()
	root_node.name = "Forest"
	root_node.set_script(load("res://scripts/location/location.gd"))
	root_node.set("title_key", "LOC_FOREST")
	root_node.set("kill_height", -6.5)
	U.environment(root_node, Color(0.42, 0.62, 0.86), Color(1.0, 0.84, 0.58), Color(1.0, 0.82, 0.55), Vector3(-17, -62, 0), 0.0045, 0.5)
	_terrain()
	_forest()
	_far_hills()
	U.clouds(root_node, rng, 36, Vector3(0.75, 0.3, 0.6))
	_camp()
	_crossings()
	_oaks()
	_landmarks()
	_hazards()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/forest.tscn")
	root_node.free()
	quit(0 if err == OK else 1)


# ---------- общие помощники ----------

func _g(x: float, z: float) -> float:
	return R.height(x, z)


func _m(x: float) -> float:
	return R.meander(x)


func _hazard(n: Node, tier: int) -> void:
	n.add_to_group("hazard", true)
	n.set_meta("tier", tier)


func _holder(nm: String, pos := Vector3.ZERO) -> Node3D:
	var h := Node3D.new()
	U.add(root_node, h, nm, pos)
	return h


## Твёрдый «брус» от a до b (бревно, ветка): цилиндр-меш и коробчатая коллизия по оси.
func _beam(parent: Node, nm: String, a: Vector3, b: Vector3, width: float, thick: float, kind: String, col: Color) -> StaticBody3D:
	var old := U.kind
	U.kind = kind
	var body := StaticBody3D.new()
	var mid := (a + b) * 0.5
	U.add(parent, body, nm, mid)
	var y := (b - a).normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var z := x.cross(y)
	body.basis = Basis(x, y, z)
	var len := a.distance_to(b)
	var cm := CylinderMesh.new()
	cm.top_radius = thick * 0.5
	cm.bottom_radius = thick * 0.5
	cm.height = len
	cm.radial_segments = 14
	cm.rings = 1
	var mi := U.mesh(body, "Mesh", cm, col)
	mi.scale = Vector3(width / thick, 1.0, 1.0)
	U.box_shape(body, Vector3(width * 0.95, len, thick * 0.9))
	U.kind = old
	return body


## Настил-пандус: плоская верхняя грань идёт от a (низ) к b (верх), ширина w.
func _ramp(parent: Node, nm: String, a: Vector3, b: Vector3, w: float, kind: String, col: Color) -> StaticBody3D:
	var old := U.kind
	U.kind = kind
	var d := b - a
	var flat := Vector3(d.x, 0, d.z)
	var holder := StaticBody3D.new()
	var th := 0.3
	var mid := (a + b) * 0.5 - Vector3(0, th * 0.5, 0)
	U.add(parent, holder, nm, mid)
	var yaw := atan2(flat.x, flat.z)
	var pitch := atan2(d.y, flat.length())
	holder.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch)
	var size := Vector3(w, th, d.length())
	U.rounded = true
	var bm := U.rounded_box(size, 0.07)
	U.mesh(holder, "Mesh", bm, col)
	U.box_shape(holder, size)
	U.kind = old
	return holder


func _terrain() -> void:
	var t := Node3D.new()
	t.set_script(load("res://scripts/location/forest/ravine_terrain.gd"))
	U.add(root_node, t, "Terrain")
	var w := Node3D.new()
	w.set_script(load("res://scripts/location/forest/water_body.gd"))
	U.add(root_node, w, "Stream")


# ---------- лес: MultiMesh по рельефу ----------

func _scatter(nm: String, species: String, count: int, seed_value: int, opts := {}) -> void:
	var s := Node3D.new()
	s.set_script(load("res://scripts/location/forest/scatter.gd"))
	s.set("species", species)
	s.set("count", count)
	s.set("seed_value", seed_value)
	for k in opts:
		s.set(k, opts[k])
	U.add(root_node, s, nm)


func _exclusions() -> PackedVector3Array:
	var e := PackedVector3Array()
	e.append(Vector3(-58, _m(-58) + 11, 11))   # стоянка
	e.append(Vector3(-8, _m(-8) + 13, 6))      # дуб A
	e.append(Vector3(2, _m(2), 8))             # мостки
	e.append(Vector3(14, _m(14) - 12, 8))      # дуб B
	e.append(Vector3(31, _m(31) - 9, 14))      # дуб C с пролётами
	e.append(Vector3(-30, _m(-30), 6))         # камни-переходы
	e.append(Vector3(52, _m(52) - 12, 7))      # вышка
	e.append(Vector3(-40, _m(-40) + 12, 6))    # «жигули»
	return e


func _forest() -> void:
	var ex := _exclusions()
	_scatter("Spruce", "spruce", 520, 11, {"min_stream": 13.0, "max_slope": 1.1, "scale_range": Vector2(0.75, 1.35), "exclude": ex, "collide_within": 42.0, "collide_radius": 0.4})
	_scatter("SpruceFar", "spruce", 700, 12, {"min_stream": 40.0, "max_slope": 1.6, "scale_range": Vector2(1.0, 1.7)})
	_scatter("Birch", "birch", 170, 13, {"min_stream": 10.0, "max_slope": 1.0, "exclude": ex, "collide_within": 32.0, "collide_radius": 0.25})
	_scatter("Oak", "oak", 55, 14, {"min_stream": 16.0, "max_slope": 0.9, "scale_range": Vector2(0.8, 1.15), "exclude": ex, "collide_within": 36.0, "collide_radius": 0.6})
	_scatter("Dead", "deadspruce", 26, 15, {"min_stream": 12.0, "exclude": ex, "collide_within": 30.0, "collide_radius": 0.3})
	_scatter("Bush", "bush", 330, 16, {"min_stream": 4.5, "max_slope": 1.2, "exclude": ex})
	_scatter("Fern", "fern", 520, 17, {"min_stream": 3.0, "max_slope": 1.3, "exclude": ex})
	_scatter("Grass", "grass", 3200, 18, {"min_stream": 2.4, "max_slope": 1.3, "x_range": Vector2(-120, 110), "z_range": Vector2(-70, 70), "scale_range": Vector2(0.8, 1.4)})
	_scatter("Flowers", "flowers", 700, 19, {"min_stream": 2.4, "x_range": Vector2(-100, 90), "z_range": Vector2(-50, 50)})
	_scatter("Mushrooms", "mushroom", 120, 20, {"min_stream": 6.0, "max_slope": 0.8, "exclude": ex})
	_scatter("Rocks", "rock", 150, 21, {"min_stream": 1.0, "max_slope": 2.0, "allow_in_water": true})
	_scatter("Boulders", "boulder", 34, 22, {"min_stream": 3.0, "max_slope": 2.0, "exclude": ex, "collide_within": 40.0, "collide_radius": 1.0, "collide_height": 1.2})
	_scatter("Stumps", "stump", 30, 23, {"min_stream": 6.0, "max_slope": 0.8, "exclude": ex})
	_scatter("Logs", "log", 28, 24, {"min_stream": 6.0, "max_slope": 0.8, "exclude": ex, "tilt_deg": 4.0})
	_scatter("Reeds", "reeds", 260, 25, {"near_water_only": true, "allow_in_water": true, "min_stream": 0.0, "max_stream": 9.0})


func _far_hills() -> void:
	# Дальние сопки в дымке: усечённые конусы кольцом за краем рельефа
	var old := U.kind
	U.kind = "paint"
	var hills := _holder("FarHills")
	for i in 22:
		var a := TAU * i / 22.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(520.0, 640.0)
		var h := rng.randf_range(70.0, 150.0)
		var c := Color(0.45, 0.58, 0.62).lerp(Color(0.72, 0.74, 0.72), rng.randf_range(0.2, 0.6))
		U.cyl(hills, "Hill%d" % i, rng.randf_range(160.0, 260.0), rng.randf_range(10.0, 50.0), h, c, Vector3(cos(a) * r, h * 0.5 - 20.0, sin(a) * r), 10, 1.0)
	U.kind = old


# ---------- стоянка у спавна ----------

func _camp() -> void:
	var old := U.kind
	var camp := _holder("Camp")
	var cx := -58.0
	var cz := _m(cx) + 11.0
	var gy := _g(cx, cz)
	# Кострище: камни по кругу, поленья, живой свет
	U.kind = "paint"
	for i in 9:
		var a := TAU * i / 9.0
		U.sphere(camp, "FireStone%d" % i, 0.22, Color(0.5, 0.5, 0.48), Vector3(cx + 4.0 + cos(a) * 0.8, gy + 0.1, cz + 1.0 + sin(a) * 0.8), 0.7)
	U.kind = "wood"
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		U.rod(camp, "FireLog%d" % i, Vector3(cx + 4.0 + cos(a) * 0.55, gy + 0.2, cz + 1.0 + sin(a) * 0.55), Vector3(cx + 4.0, gy + 0.55, cz + 1.0), 0.09, Color(0.35, 0.22, 0.12))
	U.kind = "paint"
	U.sphere(camp, "Embers", 0.3, Color(1.0, 0.45, 0.1), Vector3(cx + 4.0, gy + 0.25, cz + 1.0), 0.6)
	var fl := OmniLight3D.new()
	fl.set_script(load("res://scripts/location/forest/flicker.gd"))
	fl.light_color = Color(1.0, 0.6, 0.25)
	fl.omni_range = 11.0
	fl.shadow_enabled = true
	U.add(camp, fl, "Fire", Vector3(cx + 4.0, gy + 0.9, cz + 1.0))
	# Лавки-брёвна вокруг костра
	for k in [[0.0, 3.0], [PI, 3.0], [PI * 0.5, 3.1]]:
		var a: float = k[0]
		var p := Vector3(cx + 4.0 + cos(a) * 2.2, gy + 0.28, cz + 1.0 + sin(a) * 2.2)
		var pb := _beam(camp, "Bench", p + Vector3(-sin(a), 0, cos(a)) * 1.2, p - Vector3(-sin(a), 0, cos(a)) * 1.2, 0.5, 0.5, "bark", C_BARK)
	# Палатка: ткань на двух стойках, вход к костру
	U.kind = "paint"
	var tent := Node3D.new()
	U.add(camp, tent, "Tent", Vector3(cx - 7.0, _g(cx - 7.0, _m(cx - 7.0) + 9.5), _m(cx - 7.0) + 9.5))
	tent.rotation_degrees.y = 25
	var tm := PrismMesh.new()
	tm.size = Vector3(3.0, 1.7, 2.6)
	tm.left_to_right = 0.5
	var tmi := U.mesh(tent, "Cloth", tm, Color(0.9, 0.55, 0.15), Vector3(0, 0.85, 0), 0.9)
	tmi.rotation_degrees.y = 90
	var sb := StaticBody3D.new()
	U.add(tent, sb, "Body", Vector3(0, 0.6, 0))
	U.box_shape(sb, Vector3(2.4, 1.1, 2.4))
	U.box(tent, "Door", Vector3(0.05, 1.1, 0.9), Color(0.25, 0.2, 0.15), Vector3(1.28, 0.55, 0.0))
	# УАЗ-«буханка»: хаки с белой крышей, рядом с лагерем
	_uaz(camp, Vector3(cx - 6.0, _g(cx - 6.0, cz - 1.0), cz - 1.0), 18.0)
	# Мангал, ящик с вещами, бревно для рубки, поленница
	U.kind = "metal"
	U.box(camp, "Grill", Vector3(0.9, 0.12, 0.45), Color(0.15, 0.15, 0.16), Vector3(cx + 7.4, gy + 0.78, cz + 3.0))
	for sx in [-0.4, 0.4]:
		U.rod(camp, "GrillLeg", Vector3(cx + 7.4 + sx, gy, cz + 3.0), Vector3(cx + 7.4 + sx, gy + 0.75, cz + 3.0), 0.025, Color(0.15, 0.15, 0.16))
	U.kind = "wood"
	_woodpile(camp, Vector3(cx - 2.0, _g(cx - 2.0, _m(cx - 2.0) + 11.5), _m(cx - 2.0) + 11.5))
	U.kind = "wood"
	U.box(camp, "Cooler", Vector3(0.9, 0.55, 0.55), Color(0.2, 0.45, 0.75), Vector3(cx + 1.0, gy + 0.28, cz + 3.2), true)
	# Рюкзак, котелок
	U.kind = "paint"
	U.sphere(camp, "Pot", 0.2, Color(0.35, 0.35, 0.38), Vector3(cx + 4.0, gy + 1.1, cz + 1.0), 0.8)
	# Указатель
	_sign(camp, Vector3(cx + 8.0, _g(cx + 8.0, cz - 5.0), cz - 5.0), "SIGN_CAMP", 20.0)
	_sign(camp, Vector3(cx + 14.0, _g(cx + 14.0, _m(cx + 14.0) + 8.0), _m(cx + 14.0) + 8.0), "SIGN_RAVINE", 160.0)
	U.kind = old


func _uaz(parent: Node, pos: Vector3, yaw: float) -> void:
	var old := U.kind
	var v := Node3D.new()
	U.add(parent, v, "UAZ", pos)
	v.rotation_degrees.y = yaw
	var body := StaticBody3D.new()
	U.add(v, body, "Body", Vector3(0, 1.1, 0))
	U.box_shape(body, Vector3(1.9, 1.7, 4.6))
	U.kind = "metal"
	var khaki := Color(0.4, 0.48, 0.3)
	U.rounded = true
	U.box(v, "Hull", Vector3(1.9, 1.15, 4.6), khaki, Vector3(0, 0.95, 0), false, 0.5, 0.35)
	U.box(v, "Cab", Vector3(1.85, 0.75, 4.2), Color(0.92, 0.9, 0.84), Vector3(0, 1.88, -0.1), false, 0.5, 0.2)
	U.box(v, "Hood", Vector3(1.8, 0.1, 0.9), khaki.darkened(0.1), Vector3(0, 1.55, 1.95), false, 0.5, 0.3)
	U.kind = "paint"
	for s in [-1.0, 1.0]:
		U.box(v, "Window", Vector3(0.02, 0.5, 3.3), Color(0.18, 0.25, 0.3, 1.0), Vector3(s * 0.935, 1.98, -0.1), false, 0.1, 0.5)
		for z in [-1.5, 1.7]:
			U.cyl(v, "Wheel", 0.46, 0.46, 0.34, Color(0.08, 0.08, 0.09), Vector3(s * 0.93, 0.46, z), 20, 0.95).rotation_degrees.z = 90
			U.cyl(v, "Hub", 0.2, 0.2, 0.36, Color(0.6, 0.6, 0.62), Vector3(s * 0.93, 0.46, z), 12, 0.4, 0.6).rotation_degrees.z = 90
		U.sphere(v, "Headlight", 0.14, Color(1.0, 0.95, 0.75), Vector3(s * 0.65, 1.05, 2.32), 0.5)
	U.box(v, "Windshield", Vector3(1.7, 0.55, 0.04), Color(0.18, 0.25, 0.3), Vector3(0, 1.98, 2.0), false, 0.1, 0.5).rotation_degrees.x = -12
	U.box(v, "Bumper", Vector3(1.9, 0.18, 0.2), Color(0.35, 0.35, 0.37), Vector3(0, 0.55, 2.38))
	U.box(v, "Grille", Vector3(0.9, 0.35, 0.05), Color(0.12, 0.12, 0.12), Vector3(0, 0.95, 2.31))
	U.box(v, "Plate", Vector3(0.52, 0.12, 0.02), Color(0.95, 0.95, 0.9), Vector3(0, 0.62, 2.4))
	U.label(v, "PlateText", "А 777 АА", Vector3(0, 0.62, 2.415), 0.05, Color(0.1, 0.1, 0.1))
	U.box(v, "Roof", Vector3(1.8, 0.08, 4.1), Color(0.92, 0.9, 0.84), Vector3(0, 2.3, -0.1))
	U.box(v, "Rack", Vector3(1.6, 0.05, 2.4), Color(0.2, 0.2, 0.22), Vector3(0, 2.42, -0.3))
	U.rounded = false
	U.kind = old


func _woodpile(parent: Node, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	U.add(parent, sb, "Woodpile", pos)
	U.box_shape(sb, Vector3(2.4, 1.1, 0.9), Vector3(0, 0.55, 0))
	for row in 4:
		for i in 10:
			var c := Color(0.55, 0.4, 0.25).darkened(rng.randf_range(0.0, 0.2))
			var cy := U.cyl(sb, "Log", 0.1, 0.1, 0.9, c, Vector3(-1.08 + i * 0.24, 0.12 + row * 0.26, 0), 8, 0.9)
			cy.rotation_degrees.x = 90
	U.box(sb, "PostL", Vector3(0.08, 1.15, 0.08), Color(0.35, 0.25, 0.15), Vector3(-1.25, 0.57, 0.5))
	U.box(sb, "PostR", Vector3(0.08, 1.15, 0.08), Color(0.35, 0.25, 0.15), Vector3(1.25, 0.57, 0.5))


func _sign(parent: Node, pos: Vector3, key: String, yaw: float) -> void:
	var old := U.kind
	var s := Node3D.new()
	U.add(parent, s, "Sign", pos)
	s.rotation_degrees.y = yaw
	U.kind = "wood"
	U.rod(s, "Post", Vector3(0, -0.1, 0), Vector3(0, 1.9, 0), 0.07, Color(0.45, 0.32, 0.2))
	U.kind = "paint"
	var board := U.box(s, "Board", Vector3(1.5, 0.75, 0.06), Color(0.93, 0.9, 0.78), Vector3(0, 1.55, 0.05))
	U.box(s, "Frame", Vector3(1.58, 0.83, 0.04), Color(0.4, 0.28, 0.15), Vector3(0, 1.55, 0.02))
	U.label(board, "Text", key, Vector3(0, 0, 0.04), 0.1, Color(0.15, 0.12, 0.1))
	U.kind = old


# ---------- переправы ----------

func _crossings() -> void:
	var old := U.kind
	var c := _holder("Crossings")
	# Мостки на x=2: настил из досок на лежнях, перила, подпорки
	var bx := 2.0
	var bm := _m(bx)
	U.kind = "wood"
	var deck_y := 0.05
	var z0 := bm - 8.5
	var z1 := bm + 8.5
	var span := z1 - z0
	var deck := StaticBody3D.new()
	U.add(c, deck, "Footbridge", Vector3(bx, deck_y, bm))
	U.box_shape(deck, Vector3(2.2, 0.2, span), Vector3(0, -0.1, 0))
	for i in int(span / 0.42):
		var zz := -span * 0.5 + 0.21 + i * 0.42
		var board := U.box(deck, "Plank%d" % i, Vector3(2.2, 0.08, 0.38), Color(0.6, 0.45, 0.28).darkened(rng.randf_range(0.0, 0.25)), Vector3(0, 0.0, zz))
		board.rotation_degrees.y = rng.randf_range(-1.5, 1.5)
	for sx in [-0.8, 0.8]:
		U.box(deck, "Stringer", Vector3(0.18, 0.22, span + 0.4), Color(0.42, 0.3, 0.18), Vector3(sx, -0.22, 0))
	for sx in [-1.12, 1.12]:
		U.rod(deck, "Rail", Vector3(sx, 0.95, -span * 0.5 + 0.2), Vector3(sx, 0.95, span * 0.5 - 0.2), 0.05, Color(0.5, 0.36, 0.22))
		U.rod(deck, "Rail2", Vector3(sx, 0.5, -span * 0.5 + 0.2), Vector3(sx, 0.5, span * 0.5 - 0.2), 0.04, Color(0.5, 0.36, 0.22))
		for i in 9:
			var zz2 := -span * 0.5 + 0.2 + i * (span - 0.4) / 8.0
			U.rod(deck, "Baluster", Vector3(sx, -0.1, zz2), Vector3(sx, 1.0, zz2), 0.045, Color(0.48, 0.34, 0.2))
	# опоры в воде
	for k in [-2.0, 2.0]:
		for sx in [-0.8, 0.8]:
			U.rod(c, "Pile", Vector3(bx + sx, _g(bx + sx, bm + k) - 0.3, bm + k), Vector3(bx + sx, deck_y - 0.2, bm + k), 0.13, Color(0.35, 0.26, 0.17))
	# Камни-переходы на x=-30 (простая альтернатива течению)
	var sx0 := -30.0
	var sm := _m(sx0)
	U.kind = "concrete"
	var zs := [-4.2, -2.1, 0.0, 2.1, 4.2]
	for i in zs.size():
		var zz3: float = sm + zs[i] + rng.randf_range(-0.3, 0.3)
		var top := R.WATER_Y + 0.28 + rng.randf_range(0.0, 0.1)
		var st := StaticBody3D.new()
		U.add(c, st, "StepStone%d" % i, Vector3(sx0 + rng.randf_range(-0.4, 0.4), 0, zz3))
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.95
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(0, top - 1.5, 0)
		st.add_child(cs)
		var sp := U.sphere(st, "Stone", 1.05, Color(0.55, 0.56, 0.54), Vector3(0, top - 0.75, 0), 0.5)
	U.kind = old


# ---------- дубы с котом ----------

func _hero_oak(nm: String, pos: Vector3, scale: float, yaw: float) -> Node3D:
	var o := Node3D.new()
	o.set_script(load("res://scripts/location/forest/forest_prop.gd"))
	o.set("species", "oak")
	U.add(root_node, o, nm, pos)
	o.scale = Vector3.ONE * scale
	o.rotation_degrees.y = yaw
	var sb := StaticBody3D.new()
	U.add(root_node, sb, nm + "Trunk", pos + Vector3(0, 3.0 * scale, 0))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.7 * scale
	cyl.height = 6.0 * scale
	cs.shape = cyl
	sb.add_child(cs)
	return o


func _oaks() -> void:
	var old := U.kind
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	# A — простая: старый дуб на южном берегу, кот на низкой ветке-сучке; ступени из пней
	var ax := -8.0
	var az := _m(ax) + 13.0
	var ay := _g(ax, az)
	_hero_oak("OakA", Vector3(ax, ay, az), 0.85, 20.0)
	U.kind = "bark"
	var limb_y := ay + 1.55
	_beam(root_node, "LimbA", Vector3(ax - 0.4, limb_y, az), Vector3(ax - 3.6, limb_y + 0.25, az - 0.6), 1.0, 0.7, "bark", C_BARK)
	for i in 2:
		var px := ax - 3.0 - i * 1.7
		var pz := az + 2.3 + i * 0.8
		var pg := _g(px, pz)
		var step := StaticBody3D.new()
		U.add(root_node, step, "StumpStep%d" % i, Vector3(px, pg, pz))
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.7
		sh.height = 0.8 + i * 0.3
		cs.shape = sh
		cs.position = Vector3(0, sh.height * 0.5, 0)
		step.add_child(cs)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.62
		cm.bottom_radius = 0.75
		cm.height = sh.height + 1.2
		var mi := U.mesh(step, "Mesh", cm, Color(0.5, 0.38, 0.26), Vector3(0, sh.height * 0.5 - 0.6, 0))
		U.cyl(step, "Rings", 0.55, 0.55, 0.02, Color(0.82, 0.66, 0.46), Vector3(0, sh.height + 0.005, 0), 18)
	var ma := Marker3D.new()
	U.add(spots, ma, "OakA", Vector3(ax - 2.4, limb_y + 0.48, az - 0.4))
	ma.rotation_degrees.y = 90
	# B — средняя: северный берег, ветка 3.4 м, лаз-брёвна (мшистый и скользкий на средней и выше)
	var bx := 14.0
	var bz := _m(bx) - 12.0
	var by := _g(bx, bz)
	_hero_oak("OakB", Vector3(bx, by, bz), 1.0, 70.0)
	var ly := by + 3.4
	_beam(root_node, "LimbB", Vector3(bx + 0.3, ly, bz), Vector3(bx + 4.4, ly + 0.2, bz), 1.1, 0.7, "bark", C_BARK)
	var ramp_from := Vector3(bx + 11.0, _g(bx + 11.0, bz), bz)
	var ramp_top := Vector3(bx + 4.2, ly + 0.32, bz)
	var rb := _ramp(root_node, "LogRampB", ramp_from, ramp_top, 1.5, "bark", Color(0.46, 0.4, 0.26))
	var slide := U.zone(root_node, "SlideLogB", Vector3(2.0, 2.2, 5.4), Vector3(bx + 7.7, (ramp_from.y + ramp_top.y) * 0.5 + 0.8, bz), "res://scripts/location/slide_zone.gd")
	slide.set("downhill", Vector3(1, 0, 0))
	slide.set("pull", 3.0)
	slide.set("grip", 5.0)
	slide.rotation_degrees.y = 0
	_hazard(slide, 1)
	# мох на бревне (виден всегда, предупреждает о скользком)
	U.kind = "paint"
	for i in 6:
		var t := rng.randf()
		var p: Vector3 = ramp_from.lerp(ramp_top, t) + Vector3(rng.randf_range(-0.3, 0.3), 0.04, rng.randf_range(-0.5, 0.5))
		U.sphere(root_node, "Moss%d" % i, 0.28, Color(0.2, 0.42, 0.14), p, 0.15)
	var mb := Marker3D.new()
	U.add(spots, mb, "OakB", Vector3(bx + 2.2, ly + 0.55, bz))
	mb.rotation_degrees.y = 270
	# C — сложная: два пролёта, помост у ствола и ветка-мостик на 5 м над омутом
	var cx := 27.0
	var cz := _m(cx) - 9.0
	var cy := _g(cx, cz)
	_hero_oak("OakC", Vector3(cx, cy, cz), 1.2, 140.0)
	U.kind = "wood"
	var plat_y := cy + 2.6
	var plat := U.box(root_node, "PlatformC", Vector3(3.2, 0.3, 3.2), Color(0.55, 0.4, 0.25), Vector3(cx, plat_y - 0.15, cz), true)
	var low := Vector3(cx - 7.0, _g(cx - 7.0, cz - 1.0), cz - 1.0)
	_ramp(root_node, "RampC1", low, Vector3(cx - 1.6, plat_y, cz - 1.0), 1.5, "wood", Color(0.55, 0.42, 0.28))
	var deck_end := Vector3(cx + 7.2, cy + 5.2, cz - 1.0)
	_ramp(root_node, "RampC2", Vector3(cx + 1.6, plat_y, cz - 1.0), deck_end, 1.5, "wood", Color(0.55, 0.42, 0.28))
	_beam(root_node, "LimbC", Vector3(cx + 7.0, cy + 4.95, cz - 1.0), Vector3(cx + 7.4, cy + 4.95, cz + 6.2), 1.2, 0.9, "bark", C_BARK)
	for p in [Vector3(cx + 4.0, cy, cz - 1.0), Vector3(cx + 6.8, cy, cz - 1.0)]:
		var pg: float = _g(p.x, p.z)
		U.rod(root_node, "StrutC", Vector3(p.x, pg - 0.2, p.z), Vector3(p.x, plat_y + (p.x - cx - 1.6) * 0.45 - 0.45, p.z), 0.12, Color(0.4, 0.3, 0.2))
	var mc := Marker3D.new()
	U.add(spots, mc, "OakC", Vector3(cx + 7.4, cy + 5.65, cz + 5.0))
	mc.rotation_degrees.y = 180
	# Кот
	CatBuilder.build(root_node, ma.position)
	U.kind = old


# ---------- ориентиры ----------

func _landmarks() -> void:
	var old := U.kind
	var lm := _holder("Landmarks")
	# Охотничья вышка у водопада: ноги, площадка, лестница, крыша
	var tx := 52.0
	var tz := _m(tx) - 12.0
	var ty := _g(tx, tz)
	U.kind = "wood"
	var tw := StaticBody3D.new()
	U.add(lm, tw, "HunterTower", Vector3(tx, ty, tz))
	for sx in [-1.2, 1.2]:
		for sz in [-1.2, 1.2]:
			U.rod(tw, "Leg", Vector3(sx, -0.3, sz), Vector3(sx * 0.8, 5.0, sz * 0.8), 0.14, Color(0.45, 0.33, 0.2))
	for i in 3:
		var y := 1.2 + i * 1.3
		var w := 2.4 - i * 0.28
		U.rod(tw, "BraceA%d" % i, Vector3(-w * 0.5, y, -w * 0.5), Vector3(w * 0.5, y + 1.0, -w * 0.5), 0.05, Color(0.5, 0.36, 0.22))
		U.rod(tw, "BraceB%d" % i, Vector3(w * 0.5, y, -w * 0.5), Vector3(-w * 0.5, y + 1.0, -w * 0.5), 0.05, Color(0.5, 0.36, 0.22))
	U.box(tw, "Floor", Vector3(2.2, 0.15, 2.2), Color(0.55, 0.4, 0.25), Vector3(0, 5.0, 0), true)
	for sx in [-1.0, 1.0]:
		U.box(tw, "Wall", Vector3(0.08, 1.0, 2.0), Color(0.5, 0.36, 0.22), Vector3(sx, 5.6, 0))
	U.box(tw, "WallB", Vector3(2.0, 1.0, 0.08), Color(0.5, 0.36, 0.22), Vector3(0, 5.6, -1.0))
	U.box(tw, "Roof", Vector3(2.8, 0.1, 2.8), Color(0.3, 0.35, 0.3), Vector3(0, 6.9, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			U.rod(tw, "RoofPost", Vector3(sx, 5.1, sz), Vector3(sx, 6.9, sz), 0.07, Color(0.45, 0.33, 0.2))
	U.rod(tw, "LadderL", Vector3(-0.35, 0, 1.4), Vector3(-0.35, 5.0, 1.15), 0.05, Color(0.5, 0.36, 0.22))
	U.rod(tw, "LadderR", Vector3(0.35, 0, 1.4), Vector3(0.35, 5.0, 1.15), 0.05, Color(0.5, 0.36, 0.22))
	for i in 10:
		var f := float(i) / 9.0
		U.rod(tw, "Rung%d" % i, Vector3(-0.35, 0.3 + f * 4.5, 1.37 - f * 0.22), Vector3(0.35, 0.3 + f * 4.5, 1.37 - f * 0.22), 0.04, Color(0.55, 0.4, 0.25))
	_sign(lm, Vector3(tx - 4.0, _g(tx - 4.0, tz + 3.0), tz + 3.0), "SIGN_HUNT", 200.0)
	# Столбы ЛЭП вдоль южного склона с провисшими проводами
	U.kind = "wood"
	var poles: Array[Vector3] = []
	for i in 7:
		var px := -90.0 + i * 38.0
		var pz := _m(px) + 38.0
		poles.append(Vector3(px, _g(px, pz), pz))
	for i in poles.size():
		var p := poles[i]
		U.rod(lm, "Pole%d" % i, p - Vector3(0, 0.3, 0), p + Vector3(0, 9.0, 0), 0.17, Color(0.38, 0.3, 0.22))
		U.rod(lm, "Arm%d" % i, p + Vector3(-1.4, 8.5, 0), p + Vector3(1.4, 8.5, 0), 0.07, Color(0.38, 0.3, 0.22))
		for k in 3:
			var kx := -1.2 + k * 1.2
			U.sphere(lm, "Insulator", 0.09, Color(0.55, 0.75, 0.7), p + Vector3(kx, 8.7, 0), 1.3)
		if i + 1 < poles.size():
			var q := poles[i + 1]
			for k in 3:
				var kx := -1.2 + k * 1.2
				var a := p + Vector3(kx, 8.7, 0)
				var b := q + Vector3(kx, 8.7, 0)
				var prev := a
				for s in range(1, 9):
					var t := float(s) / 8.0
					var nxt := a.lerp(b, t) - Vector3(0, 1.6 * sin(t * PI), 0)
					U.rod(lm, "Wire", prev, nxt, 0.012, Color(0.1, 0.1, 0.1), 0.6)
					prev = nxt
	# Ржавая «копейка» у просёлка
	_lada(lm, Vector3(-40.0, _g(-40.0, _m(-40.0) + 12.0), _m(-40.0) + 12.0), 70.0)
	# Скворечники на берёзах у ручья и грибной указатель
	U.kind = "wood"
	for i in 4:
		var bx := -72.0 + i * 28.0
		var bz := _m(bx) + 18.0
		var gy := _g(bx, bz)
		U.rod(lm, "BirdPost%d" % i, Vector3(bx, gy - 0.1, bz), Vector3(bx, gy + 2.6, bz), 0.06, Color(0.4, 0.3, 0.2))
		U.box(lm, "Birdhouse%d" % i, Vector3(0.28, 0.32, 0.28), Color(0.7, 0.5, 0.25), Vector3(bx, gy + 2.8, bz))
		U.box(lm, "BirdRoof%d" % i, Vector3(0.38, 0.05, 0.36), Color(0.45, 0.2, 0.15), Vector3(bx, gy + 3.0, bz)).rotation_degrees.z = 0
		U.sphere(lm, "Hole%d" % i, 0.05, Color(0.05, 0.04, 0.03), Vector3(bx, gy + 2.82, bz + 0.15), 0.4)
	_sign(lm, Vector3(-18.0, _g(-18.0, _m(-18.0) - 10.0), _m(-18.0) - 10.0), "SIGN_MUSHROOM", 20.0)
	# Тропинка вытоптана по обоим берегам (светлые пятна у воды), плоские камни на отмелях
	U.kind = "concrete"
	for i in 22:
		var rx := rng.randf_range(-80.0, 62.0)
		var rz := _m(rx) + rng.randf_range(-4.0, 4.0)
		var rg := _g(rx, rz)
		if rg > R.WATER_Y + 0.4 or rg < R.WATER_Y - 1.6:
			continue
		U.sphere(lm, "Pebble%d" % i, rng.randf_range(0.3, 0.6), Color(0.6, 0.6, 0.57), Vector3(rx, rg + 0.05, rz), 0.45)
	U.kind = old


func _lada(parent: Node, pos: Vector3, yaw: float) -> void:
	var old := U.kind
	var v := Node3D.new()
	U.add(parent, v, "RustyLada", pos)
	v.rotation_degrees.y = yaw
	var body := StaticBody3D.new()
	U.add(v, body, "Body", Vector3(0, 0.85, 0))
	U.box_shape(body, Vector3(1.65, 1.3, 4.1))
	U.kind = "metal"
	var rust := Color(0.6, 0.38, 0.22)
	U.rounded = true
	U.box(v, "Hull", Vector3(1.65, 0.7, 4.1), Color(0.78, 0.74, 0.62), Vector3(0, 0.75, 0), false, 0.7, 0.2)
	U.box(v, "Cabin", Vector3(1.5, 0.55, 2.2), Color(0.78, 0.74, 0.62), Vector3(0, 1.35, -0.2), false, 0.7, 0.2)
	U.box(v, "RustSill", Vector3(1.68, 0.18, 4.0), rust, Vector3(0, 0.48, 0), false, 0.9, 0.1)
	U.box(v, "RustDoor", Vector3(0.02, 0.4, 0.8), rust, Vector3(0.84, 0.8, -0.3), false, 0.9, 0.1)
	U.rounded = false
	U.kind = "paint"
	for s in [-1.0, 1.0]:
		U.box(v, "Window", Vector3(0.02, 0.38, 1.7), Color(0.2, 0.25, 0.28), Vector3(s * 0.755, 1.38, -0.2), false, 0.1, 0.5)
		for z in [-1.3, 1.3]:
			U.cyl(v, "Wheel", 0.36, 0.36, 0.22, Color(0.1, 0.1, 0.1), Vector3(s * 0.8, 0.36, z), 16, 0.95).rotation_degrees.z = 90
	# Крапива и берёзка вырастают сквозь капот
	var wr := Node3D.new()
	U.add(v, wr, "Weeds", Vector3(0, 1.1, 1.1))
	for i in 8:
		U.rod(wr, "Weed", Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.4, 0.4)), Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.5, 1.2), rng.randf_range(-0.6, 0.6)), 0.02, Color(0.3, 0.5, 0.2))
	U.kind = old


# ---------- опасности ----------

func _squirrel(parent: Node, nm: String, pos: Vector3) -> Node3D:
	var old := U.kind
	U.kind = "paint"
	var s := Node3D.new()
	s.set_script(load("res://scripts/location/forest/squirrel.gd"))
	U.add(parent, s, nm, pos)
	var fur := Color(0.72, 0.38, 0.14)
	U.sphere(s, "Body", 0.22, fur, Vector3(0, 0.3, 0), 1.3)
	U.sphere(s, "Belly", 0.14, Color(0.95, 0.88, 0.75), Vector3(0, 0.26, 0.13), 1.0)
	var head := Node3D.new()
	U.add(s, head, "Head", Vector3(0, 0.62, 0.1))
	U.sphere(head, "Skull", 0.17, fur, Vector3.ZERO)
	U.sphere(head, "Muzzle", 0.08, Color(0.95, 0.88, 0.75), Vector3(0, -0.04, 0.13), 0.8)
	U.sphere(head, "Nose", 0.025, Color(0.1, 0.07, 0.06), Vector3(0, -0.02, 0.2))
	for sx in [-1.0, 1.0]:
		U.cyl(head, "Ear", 0.06, 0.0, 0.14, fur, Vector3(sx * 0.1, 0.17, 0.0), 4)
		U.sphere(head, "EyeW", 0.045, Color.WHITE, Vector3(sx * 0.07, 0.04, 0.12), 1.0)
		U.sphere(head, "Pupil", 0.025, Color(0.05, 0.05, 0.05), Vector3(sx * 0.07, 0.03, 0.155), 1.0)
		# сердитые брови
		U.rod(head, "Brow", Vector3(sx * 0.13, 0.11, 0.14), Vector3(sx * 0.03, 0.07, 0.15), 0.014, Color(0.25, 0.12, 0.05))
	var tail := Node3D.new()
	U.add(s, tail, "Tail", Vector3(0, 0.25, -0.2))
	for i in 5:
		U.sphere(tail, "Seg%d" % i, 0.14 + i * 0.02, fur.lightened(0.05 * i), Vector3(0, 0.1 + i * 0.13, -0.08 - i * 0.04), 1.0)
	var arm := Node3D.new()
	U.add(s, arm, "Arm", Vector3(0.14, 0.4, 0.1))
	U.rod(arm, "Limb", Vector3.ZERO, Vector3(0, 0.0, 0.2), 0.05, fur)
	U.sphere(arm, "Cone", 0.07, Color(0.45, 0.3, 0.16), Vector3(0, 0, 0.24), 1.2)
	U.kind = old
	return s


func _hazards() -> void:
	var old := U.kind
	var hz := _holder("Hazards")
	# Тир 0: белка на сучке у мостков (кидается шишками)
	var sx := 8.0
	var sz := _m(sx) - 9.5
	var sy := _g(sx, sz) + 3.6
	U.kind = "wood"
	U.rod(hz, "Perch0", Vector3(sx - 1.0, sy - 0.1, sz), Vector3(sx + 0.8, sy - 0.05, sz), 0.1, C_BARK)
	var s0 := _squirrel(hz, "Squirrel0", Vector3(sx, sy, sz))
	_hazard(s0, 0)
	# Тир 1: капкан охотников на тропе у мостков (ложная тревога)
	var tx := 3.0
	var tz := _m(tx) - 10.5
	var trap := U.zone(hz, "Trap", Vector3(1.6, 1.0, 1.6), Vector3(tx, _g(tx, tz) + 0.3, tz), "res://scripts/location/forest/snap_trap.gd")
	U.kind = "metal"
	var ja := Node3D.new()
	U.add(trap, ja, "JawA", Vector3(0, -0.25, -0.2))
	ja.rotation_degrees.x = -70
	var jb := Node3D.new()
	U.add(trap, jb, "JawB", Vector3(0, -0.25, 0.2))
	jb.rotation_degrees.x = 70
	for j in [ja, jb]:
		var sgn := -1.0 if j == ja else 1.0
		U.box(j, "Plate", Vector3(0.9, 0.04, 0.35), Color(0.4, 0.38, 0.36), Vector3(0, 0, sgn * 0.17), false, 0.5, 0.6)
		for i in 7:
			U.cyl(j, "Tooth", 0.04, 0.0, 0.14, Color(0.55, 0.53, 0.5), Vector3(-0.36 + i * 0.12, 0.08, sgn * 0.34), 4)
	U.box(trap, "Chain", Vector3(0.04, 0.04, 0.9), Color(0.3, 0.3, 0.3), Vector3(0, -0.28, 0.0))
	_hazard(trap, 1)
	# Тир 2: ящики плывут по течению выше мостков и вторая белка у дуба B
	var cs := Node3D.new()
	cs.set_script(load("res://scripts/location/forest/crate_spawner.gd"))
	U.add(hz, cs, "Crates", Vector3(-24.0, R.WATER_Y, _m(-24.0)))
	_hazard(cs, 2)
	var s2x := 42.0
	var s2z := _m(s2x) - 7.5
	var s2y := _g(s2x, s2z) + 4.0
	U.kind = "wood"
	U.rod(hz, "Perch2", Vector3(s2x - 1.0, s2y - 0.1, s2z), Vector3(s2x + 0.8, s2y - 0.05, s2z), 0.1, C_BARK)
	var s2 := _squirrel(hz, "Squirrel2", Vector3(s2x, s2y, s2z))
	_hazard(s2, 2)
	U.kind = old


# ---------- игрок и чекпоинты ----------

func _players_and_checkpoints() -> void:
	var sx := -58.0
	var sz := _m(sx) + 8.0
	var holder := Node3D.new()
	U.add(root_node, holder, "Players")
	U.player(holder, Vector3(sx, _g(sx, sz) + 0.6, sz))
	var cps := Node3D.new()
	U.add(root_node, cps, "Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, Vector3(sx + 1.5, _g(sx + 1.5, sz), sz))
	var c1x := 2.0
	var c1z := _m(c1x) - 10.0
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(c1x, _g(c1x, c1z), c1z))
	var c2x := 11.0
	var c2z := _m(c2x) - 9.5
	U.checkpoint(cps, "Checkpoint2", 2, Vector3(c2x, _g(c2x, c2z), c2z))
