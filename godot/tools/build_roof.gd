@tool
extends SceneTree
## Генерирует res://scenes/locations/roof.tscn: локация 1 «Верхотура» (крыша хрущёвки, Россия ~2010).
## Запуск: godot --headless --path godot --script res://tools/build_roof.gd
## Геометрия: примитивы + процедурные хрущёвки и деревья из лобби; модели Kenney (CC0) только для персонажа и флажка чекпоинта.
##
## Карта (X на восток, Y вверх, фасады хрущёвок смотрят на +Z):
##   A — крыша-старт (пятиэтажка), люк на лестницу слева, деревянный трап вниз на
##   B — крыша четырёхэтажки (ниже на 2.8 м): вентилятор, бельё, рекламный щит с котом, обрыв парапета с карнизом,
##   C — старый дом с мокрым шиферным скатом (скользит), труба на коньке.
## Опасности помечены группой "hazard" и метой "tier": 0 всегда, 1 со средней, 2 только на сложной.

const U := preload("res://scripts/location/loc_util.gd")
const DECK_A := 0.1     # верх настила крыши A
const DECK_B := -2.7    # верх настила крыши B
const GROUND := -14.7
const SLATE_W_EAVE := -2.9   # y западного карниза шиферной крыши C
const SLATE_RIDGE := -0.7
const C_X0 := 43.0
const C_X1 := 55.0
const C_RIDGE_X := 49.0
const C_HALF_Z := 4.5

var root_node: Node3D
var rng := RandomNumberGenerator.new()

# палитра: панельная пятиэтажка, рубероид, ржавчина, кирпич
const C_BIT := Color(0.24, 0.25, 0.28)
const C_BIT2 := Color(0.28, 0.29, 0.31)
const C_CONC := Color(0.72, 0.7, 0.66)
const C_BRICK := Color(0.66, 0.34, 0.26)
const C_RUST := Color(0.55, 0.3, 0.17)
const C_STEEL := Color(0.52, 0.56, 0.6)
const C_GREEN := Color(0.25, 0.5, 0.35)
const C_WOOD := Color(0.62, 0.45, 0.28)


func _init() -> void:
	rng.seed = 2010
	root_node = Node3D.new()
	root_node.name = "Roof"
	root_node.set_script(load("res://scripts/location/location.gd"))
	U.environment(root_node, Color(0.42, 0.55, 0.78), Color(0.98, 0.72, 0.45), Color(1.0, 0.78, 0.48), Vector3(-22, -58, 0), 0.004, 0.36)
	_surroundings()
	_far_city()
	_clouds()
	_roof_a()
	_roof_b()
	_roof_c()
	_ramp_and_planks()
	_extras()
	_hazards()
	_cat()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/roof.tscn")
	root_node.free()
	quit(0 if err == OK else 1)


# ---------- общие мелочи ----------

func _hazard(n: Node, tier: int) -> void:
	n.add_to_group("hazard", true)
	n.set_meta("tier", tier)


func _kh(parent: Node, nm: String, pos: Vector3, rot_y: float, sections: int, floors: int, seed_value: int, color: Color, props := true, parapet := true) -> StaticBody3D:
	var k := StaticBody3D.new()
	k.set_script(load("res://scripts/khrushchevka.gd"))
	k.set("sections", sections)
	k.set("floors", floors)
	k.set("seed_value", seed_value)
	k.set("panel_color", color)
	k.set("roof_props", props)
	k.set("parapet", parapet)
	U.add(parent, k, nm, pos)
	k.rotation_degrees.y = rot_y
	return k


func _tree(parent: Node, pos: Vector3, kind: int, seed_value: int, h: float) -> void:
	var t := StaticBody3D.new()
	t.set_script(load("res://scripts/tree.gd"))
	t.set("kind", kind)
	t.set("seed_value", seed_value)
	t.set("height", h)
	U.add(parent, t, "Tree%d" % seed_value, pos)


# ---------- окружение: двор внизу, соседние дома, облака ----------

func _surroundings() -> void:
	U.rounded = false
	var _k := U.kind
	U.kind = "paint"
	var s := Node3D.new()
	U.add(root_node, s, "Surroundings")
	U.box(s, "Ground", Vector3(1400, 1.0, 1400), Color(0.42, 0.45, 0.4), Vector3(0, GROUND - 0.5, 0))
	# Асфальтовые дорожки и газон двора
	U.box(s, "LawnSouth", Vector3(60, 0.06, 14), Color(0.4, 0.58, 0.32), Vector3(10, GROUND + 0.03, 15))
	U.box(s, "LawnNorth", Vector3(60, 0.06, 14), Color(0.4, 0.58, 0.32), Vector3(10, GROUND + 0.03, -15))
	U.box(s, "PathSouth", Vector3(70, 0.08, 3.0), Color(0.3, 0.3, 0.33), Vector3(10, GROUND + 0.04, 8.5))
	U.box(s, "PathNorth", Vector3(70, 0.08, 3.0), Color(0.3, 0.3, 0.33), Vector3(10, GROUND + 0.04, -8.5))
	U.box(s, "Road", Vector3(160, 0.08, 7.0), Color(0.26, 0.26, 0.29), Vector3(10, GROUND + 0.04, 22.5))
	for i in 14:
		U.box(s, "RoadMark%d" % i, Vector3(2.2, 0.02, 0.18), Color(0.95, 0.95, 0.9), Vector3(-45 + i * 7.5, GROUND + 0.09, 22.5))
	# Соседние дома: свои антенны и вентшахты, фасады во двор
	_kh(s, "NorthRow", Vector3(0, GROUND, -30), 0.0, 5, 5, 31, Color(0.82, 0.8, 0.72))
	_kh(s, "NorthTower", Vector3(46, GROUND, -33), 0.0, 3, 9, 32, Color(0.74, 0.76, 0.8))
	_kh(s, "SouthRow", Vector3(10, GROUND, 38), 180.0, 5, 5, 33, Color(0.84, 0.78, 0.64))
	_kh(s, "SouthRow2", Vector3(-48, GROUND, 38), 180.0, 3, 5, 34, Color(0.78, 0.7, 0.66))
	_kh(s, "WestEnd", Vector3(-46, GROUND, -2), 90.0, 3, 5, 35, Color(0.74, 0.78, 0.7))
	_kh(s, "EastFar", Vector3(88, GROUND, -4), -90.0, 4, 9, 36, Color(0.8, 0.76, 0.7))
	_kh(s, "SouthTower", Vector3(60, GROUND, 40), 180.0, 3, 9, 37, Color(0.78, 0.8, 0.84))
	# Деревья двора (берёзы, тополя, липы), у стен вырастают до уровня окон
	var tid := 100
	for z in [-14.0, 14.0]:
		for i in 9:
			var x := -22.0 + i * 8.0 + rng.randf_range(-2.0, 2.0)
			var zz: float = z + rng.randf_range(-3.0, 3.0)
			_tree(s, Vector3(x, GROUND, zz), rng.randi() % 3, tid, rng.randf_range(7.0, 12.0))
			tid += 1
	# Машины: «жигули», «газель», иномарка у подъезда
	var cars := [[Vector3(-14, 0, 11.0), 0.0, Color(0.7, 0.15, 0.12)], [Vector3(-9, 0, 11.2), 0.1, Color(0.85, 0.85, 0.82)],
		[Vector3(4, 0, 10.8), 180.0, Color(0.25, 0.4, 0.62)], [Vector3(16, 0, 11.0), 0.0, Color(0.15, 0.15, 0.18)],
		[Vector3(30, 0, -10.8), 90.0, Color(0.85, 0.7, 0.2)], [Vector3(-6, 0, -10.8), 0.0, Color(0.5, 0.52, 0.5)]]
	var ci := 0
	for c in cars:
		_car(s, "Car%d" % ci, c[0] + Vector3(0, GROUND, 0), c[1], c[2])
		ci += 1
	# Детская площадка: песочница с грибком, качели, турник
	_playground(s, Vector3(-26, GROUND, 14))
	# Гаражи-«ракушки» и лавочки
	for i in 5:
		U.box(s, "Garage%d" % i, Vector3(3.0, 2.3, 5.5), Color.from_hsv(0.08 + i * 0.07, 0.25, 0.55), Vector3(-36 + i * 3.3, GROUND + 1.15, -20), false)
		U.box(s, "GarageDoor%d" % i, Vector3(2.4, 2.0, 0.08), Color(0.45, 0.3, 0.2), Vector3(-36 + i * 3.3, GROUND + 1.05, -17.2), false)
	for bx in [-6.0, 12.0, 26.0]:
		_bench(s, Vector3(bx, GROUND, 6.8))
	U.kind = _k


func _car(parent: Node, nm: String, pos: Vector3, rot_y: float, col: Color) -> void:
	var _k := U.kind
	U.kind = "metal"
	var c := Node3D.new()
	U.add(parent, c, nm, pos)
	c.rotation_degrees.y = rot_y
	U.box(c, "Body", Vector3(4.0, 0.75, 1.7), col, Vector3(0, 0.65, 0), false, 0.5, 0.3)
	U.box(c, "Cabin", Vector3(2.0, 0.65, 1.55), col.lightened(0.05), Vector3(-0.1, 1.3, 0), false, 0.5, 0.3)
	U.box(c, "Glass", Vector3(2.02, 0.45, 1.58), Color(0.25, 0.35, 0.45), Vector3(-0.1, 1.33, 0), false, 0.2)
	for x in [-1.3, 1.3]:
		for z in [-0.85, 0.85]:
			var w := U.cyl(c, "Wheel", 0.33, 0.33, 0.25, Color(0.1, 0.1, 0.1), Vector3(x, 0.33, z), 10)
			w.rotation_degrees.x = 90
	U.kind = _k


func _playground(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "paint"
	var p := Node3D.new()
	U.add(parent, p, "Playground", pos)
	U.box(p, "Sandbox", Vector3(4, 0.3, 4), Color(0.85, 0.75, 0.5), Vector3(0, 0.15, 0))
	U.box(p, "SandboxEdge1", Vector3(4.4, 0.35, 0.2), C_WOOD, Vector3(0, 0.2, 2.1))
	U.box(p, "SandboxEdge2", Vector3(4.4, 0.35, 0.2), C_WOOD, Vector3(0, 0.2, -2.1))
	U.cyl(p, "MushroomStem", 0.12, 0.12, 1.2, Color(0.9, 0.9, 0.85), Vector3(0, 0.9, 0), 8)
	U.sphere(p, "MushroomCap", 0.9, Color(0.85, 0.15, 0.12), Vector3(0, 1.5, 0), 0.5, true)
	for x in [-2.0, 2.0]:
		U.rod(p, "SwingLegA", Vector3(7 + x * 0.0 + (x * 0.0), 0, -1), Vector3(7 + x * 0.0, 2.6, 0), 0.12, Color(0.3, 0.45, 0.7), 0.6, 0.2)
	U.rod(p, "SwingBeam", Vector3(7, 2.6, -1.8), Vector3(7, 2.6, 1.8), 0.14, Color(0.3, 0.45, 0.7), 0.6, 0.2)
	U.rod(p, "SwingLegB", Vector3(7, 0, 1.6), Vector3(7, 2.6, 0.6), 0.12, Color(0.3, 0.45, 0.7), 0.6, 0.2)
	U.rod(p, "SwingLegC", Vector3(7, 0, -1.6), Vector3(7, 2.6, -0.6), 0.12, Color(0.3, 0.45, 0.7), 0.6, 0.2)
	U.box(p, "Seat", Vector3(0.5, 0.06, 0.25), Color(0.9, 0.55, 0.15), Vector3(7, 0.8, 0.0))
	U.rod(p, "Chain", Vector3(7, 2.6, 0), Vector3(7, 0.8, 0), 0.03, Color(0.3, 0.3, 0.3))
	# Турник для выбивания ковров
	U.rod(p, "CarpetBarL", Vector3(-6, 0, 3), Vector3(-6, 2.4, 3), 0.1, C_STEEL, 0.5, 0.4)
	U.rod(p, "CarpetBarR", Vector3(-9, 0, 3), Vector3(-9, 2.4, 3), 0.1, C_STEEL, 0.5, 0.4)
	U.rod(p, "CarpetBar", Vector3(-9, 2.4, 3), Vector3(-6, 2.4, 3), 0.1, C_STEEL, 0.5, 0.4)
	U.kind = _k


func _bench(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "wood"
	var b := Node3D.new()
	U.add(parent, b, "Bench", pos)
	U.box(b, "Seat", Vector3(1.8, 0.08, 0.45), C_WOOD, Vector3(0, 0.5, 0))
	U.box(b, "Back", Vector3(1.8, 0.4, 0.07), C_WOOD, Vector3(0, 0.85, -0.2))
	for x in [-0.8, 0.8]:
		U.box(b, "Leg", Vector3(0.1, 0.5, 0.4), Color(0.2, 0.2, 0.22), Vector3(x, 0.25, 0))


# ---------- крыша A: старт ----------

## Настил с рубероидом: швы полос, заплатки, лужи, птичий «привет».
	U.kind = _k


func _deck(parent: Node, nm: String, cx: float, top: float, length: float, depth: float) -> Node3D:
	var _k := U.kind
	U.kind = "bitumen"
	var d := Node3D.new()
	U.add(parent, d, nm, Vector3(cx, top, 0))
	# Коллизия настила (верх ровно на top)
	var body := StaticBody3D.new()
	U.add(d, body, "Floor", Vector3(0, -0.1, 0))
	U.box_shape(body, Vector3(length + 0.3, 0.2, depth + 0.3))
	# Полосы рубероида вдоль X, шириной ~1 м, со швами и перепадом цвета
	var strips := int(ceil(depth / 1.0))
	var sw := depth / strips
	for i in strips:
		var col := C_BIT if i % 2 == 0 else C_BIT2
		col = col.lightened(rng.randf_range(-0.03, 0.04))
		U.box(d, "Strip%d" % i, Vector3(length, 0.012, sw - 0.04), col, Vector3(0, 0.006, -depth * 0.5 + sw * (i + 0.5)))
		U.box(d, "Seam%d" % i, Vector3(length, 0.014, 0.05), Color(0.12, 0.12, 0.14), Vector3(0, 0.007, -depth * 0.5 + sw * i))
	# Заплатки смолой, вздутия, трещины
	for i in int(length * 0.5):
		var pw := rng.randf_range(0.8, 2.0)
		var pd := rng.randf_range(0.6, 1.4)
		U.box(d, "Patch%d" % i, Vector3(pw, 0.02, pd), Color(0.14, 0.14, 0.16), Vector3(rng.randf_range(-length * 0.45, length * 0.45), 0.012, rng.randf_range(-depth * 0.4, depth * 0.4)))
	for i in int(length * 0.35):
		var b := U.box(d, "Bubble%d" % i, Vector3(0.5, 0.05, 0.4), Color(0.3, 0.3, 0.33), Vector3(rng.randf_range(-length * 0.45, length * 0.45), 0.02, rng.randf_range(-depth * 0.4, depth * 0.4)))
		b.rotation_degrees.y = rng.randf_range(0, 90)
	# Лужи после дождя
	for i in int(length * 0.25):
		var pud := U.cyl(d, "Puddle%d" % i, 1.0, 1.0, 0.012, Color(0.55, 0.72, 0.88, 0.85), Vector3(rng.randf_range(-length * 0.4, length * 0.4), 0.018, rng.randf_range(-depth * 0.35, depth * 0.35)), 16, 0.04, 0.2)
		pud.scale = Vector3(rng.randf_range(0.5, 1.3), 1.0, rng.randf_range(0.4, 0.9))
	# Следы голубей
	for i in int(length * 0.6):
		U.sphere(d, "Splat%d" % i, 0.09, Color(0.95, 0.95, 0.92), Vector3(rng.randf_range(-length * 0.5, length * 0.5), 0.02, rng.randf_range(-depth * 0.5, depth * 0.5)), 0.2)
	return d


## Парапет: цельный по кромке, с проёмами gaps = [[ось, from, to], ...] (ось "x"/"z" — вдоль чего проём)
	U.kind = _k


func _parapet(parent: Node, cx: float, top: float, length: float, depth: float, gaps: Dictionary) -> void:
	var _k := U.kind
	U.kind = "concrete"
	var holder := Node3D.new()
	U.add(parent, holder, "Parapet", Vector3(cx, top, 0))
	var hh := 0.6
	var edges := [
		["N", Vector3(0, hh * 0.5, -depth * 0.5 - 0.1), true, length + 0.3],
		["S", Vector3(0, hh * 0.5, depth * 0.5 + 0.1), true, length + 0.3],
		["W", Vector3(-length * 0.5 - 0.1, hh * 0.5, 0), false, depth],
		["E", Vector3(length * 0.5 + 0.1, hh * 0.5, 0), false, depth],
	]
	for e in edges:
		var segs: Array = [[-e[3] * 0.5, e[3] * 0.5]]
		if gaps.has(e[0]):
			var g: Array = gaps[e[0]]
			segs = [[-e[3] * 0.5, g[0]], [g[1], e[3] * 0.5]]
		var si := 0
		for sg in segs:
			var len: float = sg[1] - sg[0]
			if len < 0.05:
				continue
			var mid: float = (sg[0] + sg[1]) * 0.5
			var pos: Vector3 = e[1] + (Vector3(mid, 0, 0) if e[2] else Vector3(0, 0, mid))
			var size := Vector3(len, hh, 0.22) if e[2] else Vector3(0.22, hh, len)
			U.box(holder, "Wall%s%d" % [e[0], si], size, C_CONC.darkened(0.1), pos, true)
			# Бетонный «козырёк» и трещины
			var cap := Vector3(len + 0.06, 0.07, 0.36) if e[2] else Vector3(0.36, 0.07, len + 0.06)
			U.box(holder, "Coping%s%d" % [e[0], si], cap, C_CONC.lightened(0.12), pos + Vector3(0, hh * 0.5 + 0.035, 0))
			for k in int(len / 2.5):
				var cz := rng.randf_range(-len * 0.4, len * 0.4)
				var crack := Vector3(0.04, 0.35, 0.02) if e[2] else Vector3(0.02, 0.35, 0.04)
				var cpos: Vector3 = pos + (Vector3(cz, 0.05, (0.11 if e[0] == "S" else -0.11) if e[2] else 0) if e[2] else Vector3((0.11 if e[0] == "E" else -0.11), 0.05, cz))
				var cr := U.box(holder, "Crack", crack, Color(0.15, 0.15, 0.15), cpos)
				cr.rotation_degrees.z = rng.randf_range(-30, 30) if e[2] else 0.0
			si += 1
	U.kind = _k


func _roof_a() -> void:
	var _k := U.kind
	U.kind = "paint"
	var a := Node3D.new()
	U.add(root_node, a, "RoofA")
	_kh(a, "Building", Vector3(0, GROUND, 0), 0.0, 2, 5, 7, Color(0.8, 0.77, 0.7), false, false)
	_deck(a, "Deck", 0.0, DECK_A, 24.0, 11.0)
	_parapet(a, 0.0, DECK_A, 24.0, 11.0, {"E": [-1.4, 1.4]})
	var props := Node3D.new()
	U.add(a, props, "Props", Vector3(0, DECK_A, 0))
	_stair_hut(props, Vector3(-10.4, 0, 0))
	# Вентшахты: бетон с козырьком и решёткой
	for v in [Vector3(-5.5, 0, -4.0), Vector3(-2.2, 0, 4.2), Vector3(3.0, 0, -3.9), Vector3(6.2, 0, 4.0), Vector3(9.5, 0, -4.2)]:
		_vent(props, v, rng.randf_range(0.9, 1.4))
	# Антенны: «рога» и «ёлки» с растяжками
	_antenna(props, Vector3(-3.6, 0, 0.8), 4.2, 5)
	_antenna(props, Vector3(7.8, 0, -1.2), 3.6, 4)
	_antenna(props, Vector3(1.0, 0, 2.2), 3.0, 3)
	_dish(props, Vector3(0.5, 0, -4.5), 0.0)
	_dish(props, Vector3(9.8, 0, 4.4), 200.0)
	_dish(props, Vector3(-7.0, 0, -4.6), -30.0)
	# Кондиционеры на стене у южного парапета
	_ac_unit(props, Vector3(-7.0, 0, 5.15))
	_ac_unit(props, Vector3(-5.6, 0, 5.15))
	_ac_unit(props, Vector3(4.5, 0, 5.15))
	# Воронки водостока
	for dp in [Vector3(-6.2, 0, -2.0), Vector3(4.2, 0, 2.2), Vector3(10.0, 0, 1.0)]:
		_drain(props, dp)
	# Труба теплотрассы вдоль северного парапета на подставках
	_pipe_run(props, Vector3(-9.5, 0, -5.0), Vector3(9.5, 0, -5.0))
	# Труба поперёк прохода: перешагни
	_pipe_run(props, Vector3(2.0, 0, -3.0), Vector3(2.0, 0, 3.4), true)
	# Уголок отдыха жильцов: кресло, телевизор, ящики, бутылки
	_armchair(props, Vector3(-8.0, 0, 3.6), 200.0)
	_old_tv(props, Vector3(-9.0, 0, 4.4))
	_crate(props, Vector3(-10.0, 0, 4.4))
	_bottle(props, Vector3(-8.6, 0, 2.8), Color(0.2, 0.5, 0.25))
	_bottle(props, Vector3(-7.4, 0, 2.5), Color(0.5, 0.3, 0.12))
	_bottle(props, Vector3(-3.0, 0, -2.5), Color(0.2, 0.5, 0.25))
	_carpet_rack(props, Vector3(-1.0, 0, -4.4))
	_cables(props)
	_gravel(props, 24.0, 11.0)
	# Перила-трап: два столбика у спуска
	for z in [-1.5, 1.5]:
		U.box(props, "RampPost", Vector3(0.12, 1.0, 0.12), C_STEEL, Vector3(11.8, 0.5, z), false, 0.5, 0.4)
	# Хлам: старый стул, жестяной таз
	U.cyl(props, "Basin", 0.5, 0.35, 0.22, Color(0.7, 0.72, 0.74), Vector3(5.0, 0.11, 2.9), 14, 0.5, 0.5)
	U.kind = _k


func _stair_hut(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "concrete"
	var h := Node3D.new()
	U.add(parent, h, "StairHut", pos)
	var body := U.box(h, "Walls", Vector3(3.2, 2.5, 3.4), C_CONC.darkened(0.05), Vector3(0, 1.25, 0), true)
	U.box(h, "Roof", Vector3(3.6, 0.15, 3.8), Color(0.3, 0.3, 0.33), Vector3(0, 2.57, 0))
	U.box(h, "RoofEdge", Vector3(3.7, 0.08, 3.9), C_CONC.darkened(0.25), Vector3(0, 2.46, 0))
	# Железная дверь, окрашенная суриком, с замком и табличкой
	U.box(h, "DoorFrame", Vector3(0.12, 2.0, 1.3), Color(0.3, 0.3, 0.3), Vector3(1.64, 1.0, 0), false, 0.6, 0.3)
	U.box(h, "Door", Vector3(0.1, 1.9, 1.15), C_GREEN, Vector3(1.69, 0.96, 0), false, 0.6, 0.3)
	U.box(h, "DoorPanel", Vector3(0.04, 1.3, 0.8), C_GREEN.darkened(0.15), Vector3(1.75, 1.0, 0))
	U.box(h, "Lock", Vector3(0.1, 0.18, 0.22), Color(0.2, 0.2, 0.2), Vector3(1.77, 1.0, 0.45), false, 0.4, 0.6)
	U.box(h, "Handle", Vector3(0.06, 0.06, 0.3), Color(0.85, 0.85, 0.85), Vector3(1.79, 1.05, -0.35), false, 0.3, 0.8)
	U.box(h, "Rust", Vector3(0.03, 0.5, 0.3), C_RUST, Vector3(1.75, 0.35, -0.3))
	var sign_board := U.box(h, "Sign", Vector3(0.04, 0.5, 0.8), Color(0.9, 0.85, 0.2), Vector3(1.7, 2.25, 0))
	U.label(sign_board, "Text", "SIGN_EXIT", Vector3(0.03, 0, 0), 0.14, Color(0.1, 0.1, 0.1)).rotation_degrees.y = 90
	# Козырёк над дверью и лампа
	U.box(h, "Canopy", Vector3(0.9, 0.08, 1.8), Color(0.35, 0.35, 0.38), Vector3(2.0, 2.15, 0))
	U.sphere(h, "Lamp", 0.14, Color(1.0, 0.95, 0.6), Vector3(2.0, 2.0, 0.0), 1.0)
	# Вентрешётки и труба на крыше будки
	U.box(h, "Slot1", Vector3(0.04, 0.5, 0.9), Color(0.15, 0.15, 0.16), Vector3(0, 1.5, 1.72))
	U.box(h, "Slot2", Vector3(0.04, 0.5, 0.9), Color(0.15, 0.15, 0.16), Vector3(0, 1.5, -1.72))
	U.cyl(h, "Chimney", 0.18, 0.2, 0.9, Color(0.4, 0.4, 0.42), Vector3(-0.8, 3.1, 0.6), 10, 0.6, 0.4)
	U.cyl(h, "ChimneyCap", 0.3, 0.05, 0.12, Color(0.4, 0.4, 0.42), Vector3(-0.8, 3.62, 0.6), 10, 0.6, 0.4)
	U.kind = _k


func _vent(parent: Node, pos: Vector3, h: float) -> void:
	var _k := U.kind
	U.kind = "concrete"
	var v := Node3D.new()
	U.add(parent, v, "Vent", pos)
	U.box(v, "Base", Vector3(0.9, h, 0.9), C_CONC.darkened(0.08), Vector3(0, h * 0.5, 0), true)
	U.box(v, "Cap", Vector3(1.15, 0.1, 1.15), C_CONC.darkened(0.3), Vector3(0, h + 0.05, 0))
	U.box(v, "Grille", Vector3(0.6, 0.35, 0.04), Color(0.12, 0.12, 0.13), Vector3(0, h * 0.6, 0.46))
	for i in 3:
		U.box(v, "Slat", Vector3(0.6, 0.03, 0.05), Color(0.5, 0.5, 0.5), Vector3(0, h * 0.6 - 0.1 + i * 0.1, 0.47))
	U.box(v, "Stain", Vector3(0.06, h * 0.7, 0.02), Color(0.45, 0.4, 0.34), Vector3(0.3, h * 0.45, 0.455))
	U.kind = _k


func _antenna(parent: Node, pos: Vector3, h: float, arms: int) -> void:
	var _k := U.kind
	U.kind = "metal"
	var a := Node3D.new()
	U.add(parent, a, "Antenna", pos)
	U.box(a, "Foot", Vector3(0.5, 0.15, 0.5), C_CONC.darkened(0.2), Vector3(0, 0.07, 0), true)
	U.cyl(a, "Mast", 0.035, 0.03, h, C_STEEL, Vector3(0, h * 0.5, 0), 6, 0.4, 0.6)
	# «Волновой канал»: траверса + директоры
	for i in arms:
		var y := h * (0.45 + 0.55 * float(i) / arms)
		var len := 1.5 - i * 0.18
		U.rod(a, "Boom%d" % i, Vector3(0, y, -len * 0.5), Vector3(0, y, len * 0.5), 0.025, C_STEEL, 0.4, 0.6)
		for j in 3:
			var z := -len * 0.5 + len * (j + 0.5) / 3.0
			U.rod(a, "Dir%d_%d" % [i, j], Vector3(-0.55 + j * 0.07, y, z), Vector3(0.55 - j * 0.07, y, z), 0.018, C_STEEL, 0.4, 0.6)
	# Растяжки к настилу
	for ang in [30.0, 150.0, 270.0]:
		var ap := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang))) * h * 0.55
		U.rod(a, "Guy", Vector3(0, h * 0.8, 0), ap + Vector3(0, 0.05, 0), 0.012, Color(0.15, 0.15, 0.15))
		U.box(a, "Anchor", Vector3(0.14, 0.1, 0.14), C_RUST, ap)
	# Флажок-ленточка на мачте, качается
	var flag := Sway.new()
	flag.amplitude_deg = 18.0
	flag.speed = 5.0
	flag.axis = Vector3.UP
	flag.phase = rng.randf_range(0, 6)
	U.add(a, flag, "Ribbon", Vector3(0, h + 0.05, 0))
	U.box(flag, "Cloth", Vector3(0.5, 0.18, 0.015), Color(0.95, 0.3, 0.25), Vector3(0.25, 0, 0))
	U.kind = _k


func _dish(parent: Node, pos: Vector3, yaw: float) -> void:
	var _k := U.kind
	U.kind = "metal"
	var d := Node3D.new()
	U.add(parent, d, "Dish", pos)
	d.rotation_degrees.y = yaw
	U.box(d, "Foot", Vector3(0.6, 0.12, 0.6), C_CONC.darkened(0.2), Vector3(0, 0.06, 0), true)
	U.cyl(d, "Pole", 0.05, 0.05, 1.0, C_STEEL, Vector3(0, 0.6, 0), 8, 0.4, 0.6)
	var dish := U.sphere(d, "Bowl", 0.7, Color(0.92, 0.92, 0.9), Vector3(0, 1.4, 0.1), 1.0, true, 0.4)
	dish.rotation_degrees.x = 60
	dish.scale = Vector3(1, 1, 0.7)
	var arm := U.rod(d, "Arm", Vector3(0, 1.3, 0.2), Vector3(0, 1.75, 0.8), 0.025, Color(0.2, 0.2, 0.2))
	U.sphere(d, "LNB", 0.07, Color(0.2, 0.2, 0.22), Vector3(0, 1.78, 0.82))
	U.rod(d, "Cable", Vector3(0, 1.0, 0.0), Vector3(0.8, 0.02, 1.2), 0.02, Color(0.1, 0.1, 0.1))
	U.kind = _k


func _ac_unit(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "metal"
	var u := Node3D.new()
	U.add(parent, u, "AC", pos)
	U.box(u, "Bracket", Vector3(0.9, 0.06, 0.4), C_STEEL, Vector3(0, 0.55, -0.1), false, 0.4, 0.6)
	U.box(u, "Body", Vector3(0.85, 0.65, 0.34), Color(0.92, 0.92, 0.9), Vector3(0, 0.9, -0.25), true)
	U.cyl(u, "Fan", 0.25, 0.25, 0.02, Color(0.15, 0.15, 0.16), Vector3(0, 0.9, -0.42), 12).rotation_degrees.x = 90
	for i in 5:
		U.box(u, "Grille%d" % i, Vector3(0.5, 0.012, 0.01), Color(0.55, 0.55, 0.55), Vector3(0, 0.78 + i * 0.06, -0.435))
	U.rod(u, "Drip", Vector3(-0.3, 0.55, -0.25), Vector3(-0.3, 0.1, -0.5), 0.025, Color(0.9, 0.9, 0.9))
	U.kind = _k


func _drain(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "metal"
	U.cyl(parent, "DrainRing", 0.38, 0.38, 0.03, Color(0.3, 0.3, 0.33), pos + Vector3(0, 0.025, 0), 16, 0.4, 0.6)
	U.cyl(parent, "DrainHole", 0.26, 0.26, 0.035, Color(0.04, 0.04, 0.05), pos + Vector3(0, 0.03, 0), 12)
	for i in 4:
		var b := U.box(parent, "DrainBar", Vector3(0.5, 0.02, 0.03), Color(0.35, 0.35, 0.37), pos + Vector3(0, 0.05, 0), false, 0.4, 0.6)
		b.rotation_degrees.y = i * 45.0
	for i in 5:
		U.box(parent, "Leaf", Vector3(0.12, 0.01, 0.08), Color(0.55, 0.45, 0.12), pos + Vector3(rng.randf_range(-0.5, 0.5), 0.03, rng.randf_range(-0.5, 0.5)))
	U.kind = _k


func _pipe_run(parent: Node, a: Vector3, b: Vector3, collide := false) -> void:
	var _k := U.kind
	U.kind = "metal"
	var holder := StaticBody3D.new() if collide else Node3D.new()
	U.add(parent, holder, "Pipe", Vector3.ZERO)
	var h := 0.42
	var mid := (a + b) * 0.5 + Vector3(0, h, 0)
	var d := b - a
	var len := d.length()
	var pm := U.cyl(holder, "Tube", 0.2, 0.2, len, Color(0.55, 0.56, 0.58), mid, 14, 0.45, 0.5)
	pm.look_at_from_position(mid, mid + d.normalized().cross(Vector3.UP).cross(d.normalized()) * 0.0 + d, Vector3.UP)
	pm.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	if collide:
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.2
		sh.height = len
		cs.shape = sh
		U.add(holder, cs, "Shape", mid)
		cs.look_at_from_position(mid, mid + d, Vector3.UP)
		cs.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	# Подставки, муфты и утеплитель-«бинты»
	var n := maxi(int(len / 2.0), 2)
	for i in n + 1:
		var p := a + d * (float(i) / n)
		U.box(holder, "Stand%d" % i, Vector3(0.18, h - 0.1, 0.18), C_RUST, p + Vector3(0, (h - 0.1) * 0.5, 0), false, 0.8, 0.2)
		var ring := U.cyl(holder, "Coupling%d" % i, 0.23, 0.23, 0.14, Color(0.75, 0.75, 0.72), p + Vector3(0, h, 0), 14, 0.5, 0.4)
		ring.look_at_from_position(ring.position, ring.position + d, Vector3.UP)
		ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	U.kind = _k


func _armchair(parent: Node, pos: Vector3, yaw: float) -> void:
	var _k := U.kind
	U.kind = "paint"
	var c := Node3D.new()
	U.add(parent, c, "Armchair", pos)
	c.rotation_degrees.y = yaw
	var fab := Color(0.55, 0.22, 0.18)
	U.box(c, "Seat", Vector3(0.9, 0.3, 0.8), fab, Vector3(0, 0.4, 0), true)
	U.box(c, "Back", Vector3(0.9, 0.7, 0.2), fab.darkened(0.1), Vector3(0, 0.85, -0.35))
	U.box(c, "ArmL", Vector3(0.18, 0.45, 0.8), fab.darkened(0.15), Vector3(-0.5, 0.55, 0))
	U.box(c, "ArmR", Vector3(0.18, 0.45, 0.8), fab.darkened(0.15), Vector3(0.5, 0.55, 0))
	for x in [-0.4, 0.4]:
		for z in [-0.3, 0.3]:
			U.box(c, "Leg", Vector3(0.08, 0.22, 0.08), C_WOOD.darkened(0.3), Vector3(x, 0.11, z))
	U.box(c, "Doily", Vector3(0.5, 0.02, 0.4), Color(0.95, 0.93, 0.85), Vector3(0, 0.56, -0.2))
	U.kind = _k


func _old_tv(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "wood"
	var t := Node3D.new()
	U.add(parent, t, "OldTV", pos)
	t.rotation_degrees.y = 160
	U.box(t, "Stool", Vector3(0.6, 0.45, 0.5), C_WOOD, Vector3(0, 0.225, 0), true)
	U.box(t, "Body", Vector3(0.7, 0.55, 0.55), Color(0.35, 0.28, 0.2), Vector3(0, 0.72, 0))
	U.box(t, "Screen", Vector3(0.5, 0.4, 0.04), Color(0.2, 0.3, 0.3), Vector3(-0.05, 0.74, 0.29), false, 0.1)
	for i in 3:
		U.cyl(t, "Knob%d" % i, 0.04, 0.04, 0.03, Color(0.8, 0.8, 0.75), Vector3(0.27, 0.9 - i * 0.12, 0.29), 8).rotation_degrees.x = 90
	# «Рога» комнатной антенны
	U.rod(t, "RabbitL", Vector3(0, 1.0, 0), Vector3(-0.4, 1.5, -0.1), 0.02, C_STEEL)
	U.rod(t, "RabbitR", Vector3(0, 1.0, 0), Vector3(0.4, 1.45, -0.1), 0.02, C_STEEL)
	U.sphere(t, "RabbitBase", 0.1, Color(0.2, 0.2, 0.2), Vector3(0, 1.02, 0), 0.5)
	U.kind = _k


func _crate(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "wood"
	var c := U.box(parent, "Crate", Vector3(0.7, 0.55, 0.5), C_WOOD.darkened(0.1), pos + Vector3(0, 0.275, 0), true)
	for i in 3:
		U.box(c, "Slat", Vector3(0.72, 0.06, 0.52), C_WOOD.lightened(0.1), Vector3(0, -0.2 + i * 0.2, 0))
	U.kind = _k


func _bottle(parent: Node, pos: Vector3, col: Color) -> void:
	var _k := U.kind
	U.kind = "paint"
	var b := Node3D.new()
	U.add(parent, b, "Bottle", pos)
	U.cyl(b, "Body", 0.06, 0.06, 0.22, col, Vector3(0, 0.11, 0), 8, 0.2)
	U.cyl(b, "Neck", 0.025, 0.04, 0.12, col, Vector3(0, 0.28, 0), 8, 0.2)
	U.cyl(b, "Cap", 0.03, 0.03, 0.02, Color(0.8, 0.7, 0.2), Vector3(0, 0.35, 0), 8, 0.3, 0.6)
	b.rotation_degrees.z = rng.randf_range(-6, 90) if rng.randf() < 0.4 else 0.0
	U.kind = _k


func _carpet_rack(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "metal"
	var r := Node3D.new()
	U.add(parent, r, "CarpetRack", pos)
	for x in [-1.1, 1.1]:
		U.rod(r, "Post", Vector3(x, 0, 0), Vector3(x, 1.7, 0), 0.07, C_RUST, 0.8, 0.2)
	U.rod(r, "Bar", Vector3(-1.1, 1.7, 0), Vector3(1.1, 1.7, 0), 0.07, C_RUST, 0.8, 0.2)
	var carpet := Sway.new()
	carpet.amplitude_deg = 4.0
	carpet.speed = 1.5
	carpet.axis = Vector3.RIGHT
	U.add(r, carpet, "Carpet", Vector3(0, 1.7, 0))
	# Ковёр с узором, висит на перекладине
	U.box(carpet, "Rug", Vector3(1.8, 1.4, 0.05), Color(0.62, 0.15, 0.18), Vector3(0, -0.7, 0))
	U.box(carpet, "RugBorder1", Vector3(1.8, 0.1, 0.06), Color(0.9, 0.75, 0.3), Vector3(0, -1.3, 0))
	U.box(carpet, "RugBorder2", Vector3(1.8, 0.1, 0.06), Color(0.9, 0.75, 0.3), Vector3(0, -0.1, 0))
	U.box(carpet, "RugDiamond", Vector3(0.8, 0.8, 0.07), Color(0.12, 0.28, 0.5), Vector3(0, -0.7, 0)).rotation_degrees.z = 45
	for i in 9:
		U.box(carpet, "Fringe%d" % i, Vector3(0.04, 0.12, 0.04), Color(0.9, 0.75, 0.3), Vector3(-0.8 + i * 0.2, -1.46, 0))
	U.kind = _k


func _cables(parent: Node) -> void:
	var _k := U.kind
	U.kind = "paint"
	# Кабели к антеннам по настилу, чёрные «змейки» на скобах
	var pts := [Vector3(-3.6, 0.02, 0.8), Vector3(-2.2, 0.02, 1.7), Vector3(0.0, 0.02, 2.6), Vector3(1.0, 0.02, 2.2)]
	for i in pts.size() - 1:
		U.rod(parent, "Cable%d" % i, pts[i], pts[i + 1], 0.03, Color(0.08, 0.08, 0.09))
	var pts2 := [Vector3(7.8, 0.02, -1.2), Vector3(6.0, 0.02, -2.4), Vector3(3.0, 0.02, -3.8), Vector3(0.5, 0.02, -4.5)]
	for i in pts2.size() - 1:
		U.rod(parent, "CableB%d" % i, pts2[i], pts2[i + 1], 0.03, Color(0.08, 0.08, 0.09))
	U.kind = _k


func _gravel(parent: Node, length: float, depth: float) -> void:
	var _k := U.kind
	U.kind = "concrete"
	for i in int(length * 3):
		var s := rng.randf_range(0.05, 0.14)
		U.box(parent, "Stone%d" % i, Vector3(s, s * 0.6, s), Color(0.45, 0.45, 0.47).lightened(rng.randf_range(-0.1, 0.15)), Vector3(rng.randf_range(-length * 0.5, length * 0.5), s * 0.3, rng.randf_range(-depth * 0.5, depth * 0.5)))


# ---------- крыша B: четырёхэтажка с вентилятором, бельём и щитом ----------
	U.kind = _k


func _roof_b() -> void:
	var _k := U.kind
	U.kind = "paint"
	var b := Node3D.new()
	U.add(root_node, b, "RoofB")
	_kh(b, "Building", Vector3(29, GROUND, 0), 0.0, 2, 4, 9, Color(0.84, 0.76, 0.66), false, false)
	_deck(b, "Deck", 29.0, DECK_B, 24.0, 11.0)
	# Проёмы: трап слева, мостик справа, обвалившийся кусок парапета на север (локальные x от 0 до 3)
	_parapet(b, 29.0, DECK_B, 24.0, 11.0, {"W": [-1.4, 1.4], "E": [-1.4, 1.4], "N": [0.0, 3.0]})
	var props := Node3D.new()
	U.add(b, props, "Props", Vector3(29, DECK_B, 0))
	for v in [Vector3(-6.0, 0, -4.2), Vector3(5.0, 0, 4.4), Vector3(10.0, 0, -3.8)]:
		_vent(props, v, rng.randf_range(0.9, 1.3))
	_antenna(props, Vector3(-9.5, 0, 3.8), 4.0, 5)
	_antenna(props, Vector3(8.0, 0, -4.0), 3.4, 4)
	_dish(props, Vector3(-10.5, 0, -3.8), 20.0)
	_ac_unit(props, Vector3(-3.0, 0, 5.15))
	_ac_unit(props, Vector3(-1.6, 0, 5.15))
	_drain(props, Vector3(-3.5, 0, -2.0))
	_drain(props, Vector3(6.5, 0, 0.5))
	_water_tank(props, Vector3(-9.0, 0, -3.2))
	_pipe_run(props, Vector3(4.0, 0, -5.0), Vector3(11.0, 0, -5.0))
	_laundry(props)
	_hatch(props, Vector3(3.5, 0, -2.2))
	_billboard(props)
	_crate(props, Vector3(11.0, 0, 1.0))
	_crate(props, Vector3(11.0, 0, 1.7))
	_bottle(props, Vector3(8.3, 0, 2.0), Color(0.2, 0.5, 0.25))
	_gravel(props, 24.0, 11.0)
	# Скол парапета: обломки на настиле и торчащая арматура
	for i in 6:
		var s := rng.randf_range(0.12, 0.3)
		U.box(props, "Debris%d" % i, Vector3(s, s * 0.7, s), C_CONC, Vector3(rng.randf_range(0.0, 3.0), s * 0.35, rng.randf_range(-5.0, -3.8)))
	for x in [0.3, 1.2, 2.1, 2.8]:
		U.rod(props, "Rebar", Vector3(x, 0.0, -5.5), Vector3(x + rng.randf_range(-0.1, 0.1), 0.45, -5.45), 0.03, C_RUST, 0.8, 0.3)
	# Карниз (кирпичный выступ) для кота за проёмом
	var ledge := U.box(props, "Cornice", Vector3(3.6, 0.3, 1.8), C_CONC.darkened(0.1), Vector3(1.5, -1.05, -6.3), true)
	U.box(ledge, "Stain", Vector3(3.4, 0.02, 1.6), Color(0.45, 0.42, 0.4), Vector3(0, 0.16, 0))
	U.box(props, "CornicePipe", Vector3(0.14, 3.0, 0.14), C_RUST, Vector3(3.1, -2.4, -5.65), false, 0.8, 0.3)
	# Голуби на парапете и на щите
	var perches := [Vector3(-8.0, 0.66, 5.7), Vector3(-6.4, 0.66, 5.7), Vector3(-5.9, 0.66, 5.7), Vector3(4.0, 0.66, 5.7), Vector3(9.0, 0.66, 5.7), Vector3(-4.0, 0.66, -5.7)]
	var i := 0
	for pp in perches:
		_pigeon(props, pp, i == 0 or i == 3, i + 1, 0)
		i += 1
	_pigeon(props, Vector3(9.5, 2.2 + 0.0, 4.15), true, 20, 2)
	_pigeon(props, Vector3(6.0, 2.2, 3.9), true, 21, 2)
	U.kind = _k


func _pigeon(parent: Node, pos: Vector3, hooligan: bool, seed_value: int, tier: int) -> void:
	var _k := U.kind
	U.kind = "paint"
	var p := Node3D.new()
	p.set_script(load("res://scripts/location/pigeon.gd"))
	p.set("hooligan", hooligan)
	U.add(parent, p, "Pigeon%d" % seed_value, pos)
	p.rotation_degrees.y = seed_value * 47.0
	var grey := Color(0.55, 0.57, 0.62)
	U.sphere(p, "Body", 0.17, grey, Vector3(0, 0.17, 0), 0.75)
	U.sphere(p, "Chest", 0.12, Color(0.45, 0.55, 0.62), Vector3(0, 0.2, 0.1), 0.9)
	var head := Node3D.new()
	U.add(p, head, "Head", Vector3(0, 0.3, 0.16))
	U.sphere(head, "HeadMesh", 0.075, Color(0.5, 0.52, 0.58), Vector3.ZERO)
	var beak := U.box(head, "Beak", Vector3(0.025, 0.025, 0.06), Color(0.95, 0.8, 0.5), Vector3(0, -0.01, 0.08))
	U.sphere(head, "Eye", 0.015, Color(0.9, 0.4, 0.1), Vector3(0.05, 0.015, 0.04))
	U.sphere(head, "Eye2", 0.015, Color(0.9, 0.4, 0.1), Vector3(-0.05, 0.015, 0.04))
	var tail := U.box(p, "Tail", Vector3(0.1, 0.02, 0.18), Color(0.3, 0.3, 0.34), Vector3(0, 0.17, -0.22))
	tail.rotation_degrees.x = 15
	for s in [-1.0, 1.0]:
		var w := Node3D.new()
		U.add(p, w, "WingL" if s < 0 else "WingR", Vector3(s * 0.13, 0.22, 0))
		U.box(w, "Feather", Vector3(0.2, 0.02, 0.22), Color(0.42, 0.44, 0.5), Vector3(s * 0.1, 0, -0.02))
	for s in [-1.0, 1.0]:
		U.box(p, "Leg", Vector3(0.015, 0.1, 0.015), Color(0.8, 0.4, 0.4), Vector3(s * 0.04, 0.05, 0.02))
	if hooligan:
		_hazard(p, tier)
	else:
		# Мирные голуби сидят всегда
		pass
	U.kind = _k


func _water_tank(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "metal"
	var t := Node3D.new()
	U.add(parent, t, "Tank", pos)
	for x in [-0.55, 0.55]:
		for z in [-0.55, 0.55]:
			U.box(t, "Leg", Vector3(0.1, 1.0, 0.1), C_RUST, Vector3(x, 0.5, z), false, 0.8, 0.2)
	U.box(t, "Platform", Vector3(1.4, 0.08, 1.4), C_RUST.darkened(0.2), Vector3(0, 1.02, 0), true, 0.8, 0.2)
	U.cyl(t, "Barrel", 0.62, 0.62, 1.3, Color(0.3, 0.45, 0.62), Vector3(0, 1.72, 0), 18, 0.5, 0.3)
	for y in [1.35, 1.75, 2.1]:
		U.cyl(t, "Hoop", 0.64, 0.64, 0.05, Color(0.2, 0.2, 0.22), Vector3(0, y, 0), 18, 0.5, 0.5)
	U.cyl(t, "Lid", 0.6, 0.55, 0.1, Color(0.25, 0.38, 0.55), Vector3(0, 2.4, 0), 18, 0.5, 0.3)
	U.rod(t, "Hose", Vector3(0.62, 1.2, 0), Vector3(1.4, 0.05, 0.4), 0.05, Color(0.1, 0.1, 0.12))
	U.kind = _k


func _hatch(parent: Node, pos: Vector3) -> void:
	var _k := U.kind
	U.kind = "metal"
	var h := Node3D.new()
	U.add(parent, h, "Hatch", pos)
	U.box(h, "Frame", Vector3(1.1, 0.14, 1.1), Color(0.3, 0.3, 0.32), Vector3(0, 0.07, 0), true, 0.6, 0.3)
	U.box(h, "Lid", Vector3(0.9, 0.05, 0.9), Color(0.35, 0.4, 0.45), Vector3(0, 0.16, 0), false, 0.6, 0.4)
	U.box(h, "Handle", Vector3(0.3, 0.05, 0.05), Color(0.8, 0.8, 0.8), Vector3(0, 0.2, 0.25), false, 0.3, 0.8)
	U.box(h, "Padlock", Vector3(0.1, 0.1, 0.06), Color(0.8, 0.65, 0.2), Vector3(0.4, 0.15, 0.0), false, 0.3, 0.8)
	U.kind = _k


func _laundry(parent: Node) -> void:
	var _k := U.kind
	U.kind = "paint"
	# Две бельевые верёвки между столбами: простыни, полотенца, майки, носки
	var cols := [Color(0.95, 0.95, 0.92), Color(0.9, 0.3, 0.3), Color(0.3, 0.55, 0.85), Color(0.95, 0.8, 0.25), Color(0.4, 0.75, 0.45), Color(0.85, 0.55, 0.75)]
	var line_z := [2.4, 4.0]
	for li in 2:
		var z: float = line_z[li]
		var x0 := -8.0
		var x1 := -1.0
		for x in [x0, x1]:
			U.rod(parent, "Pole", Vector3(x, 0, z), Vector3(x, 2.3, z), 0.08, C_RUST.darkened(0.2), 0.8, 0.2)
			U.rod(parent, "PoleBrace", Vector3(x, 1.0, z), Vector3(x + (0.5 if x == x0 else -0.5), 0.0, z), 0.05, C_RUST.darkened(0.2), 0.8, 0.2)
			U.box(parent, "PoleFoot", Vector3(0.4, 0.12, 0.4), C_CONC.darkened(0.2), Vector3(x, 0.06, z), true)
		U.rod(parent, "Line", Vector3(x0, 2.15, z), Vector3(x1, 2.0, z), 0.015, Color(0.9, 0.9, 0.85))
		var x := x0 + 0.5
		var k := 0
		while x < x1 - 0.5:
			var w := rng.randf_range(0.5, 1.5)
			var hgt := rng.randf_range(0.6, 1.4)
			var sw := Sway.new()
			sw.amplitude_deg = 7.0
			sw.speed = 2.0
			sw.phase = rng.randf_range(0, 6)
			sw.axis = Vector3.RIGHT
			U.add(parent, sw, "Cloth%d_%d" % [li, k], Vector3(x + w * 0.5, 2.1 - (x - x0) * 0.02, z))
			U.box(sw, "Item", Vector3(w, hgt, 0.02), cols[rng.randi() % cols.size()], Vector3(0, -hgt * 0.5, 0))
			for pn in [-0.3, 0.3]:
				U.box(sw, "Peg", Vector3(0.04, 0.1, 0.05), Color(0.9, 0.7, 0.2), Vector3(w * pn, -0.02, 0))
			x += w + 0.1
			k += 1
	U.kind = _k


func _billboard(parent: Node) -> void:
	var _k := U.kind
	U.kind = "metal"
	var b := Node3D.new()
	U.add(parent, b, "Billboard", Vector3.ZERO)
	var x0 := 3.0
	var x1 := 11.2
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var pz := 4.15
	# Основание, столбы и раскосы (труба-профиль, ржавая краска)
	for px in [x0 + 0.5, cx, x1 - 0.5]:
		U.box(b, "PostFoot", Vector3(0.7, 0.2, 0.7), C_CONC.darkened(0.2), Vector3(px, 0.1, pz + 0.3), true)
		U.rod(b, "Post", Vector3(px, 0.2, pz + 0.3), Vector3(px, 6.0, pz + 0.3), 0.14, C_STEEL.darkened(0.2), 0.5, 0.4)
	for i in 4:
		var ax := x0 + 0.5 + i * (w - 1.0) / 4.0
		U.rod(b, "Brace%d" % i, Vector3(ax, 0.3, pz + 0.3), Vector3(ax + (w - 1.0) / 8.0, 2.2, pz + 0.3), 0.07, C_RUST, 0.8, 0.3)
	# Каркас щита и два полотна (спереди и сзади разные)
	U.box(b, "Frame", Vector3(w, 3.6, 0.2), Color(0.2, 0.22, 0.28), Vector3(cx, 4.2, pz), false, 0.5, 0.4)
	var poster := U.box(b, "Poster", Vector3(w - 0.3, 3.3, 0.06), Color(0.98, 0.93, 0.62), Vector3(cx, 4.2, pz - 0.12))
	U.box(poster, "Band", Vector3(w - 0.3, 0.9, 0.02), Color(0.2, 0.45, 0.85), Vector3(0, -1.1, -0.02))
	U.label(poster, "Title", "SIGN_WINDOWS", Vector3(0, 0.3, -0.05), 0.9, Color(0.1, 0.25, 0.55)).rotation_degrees.y = 180
	U.label(poster, "Phone", "SIGN_PHONE", Vector3(0, -1.1, -0.05), 0.7, Color.WHITE).rotation_degrees.y = 180
	var back := U.box(b, "PosterBack", Vector3(w - 0.3, 3.3, 0.06), Color(0.95, 0.5, 0.45), Vector3(cx, 4.2, pz + 0.12))
	U.label(back, "Title", "SIGN_PELMENI", Vector3(0, 0.0, 0.05), 0.42, Color(0.98, 0.95, 0.9))
	# Прожекторы на штангах (выгоревшие, один не горит)
	for i in 3:
		var lx := x0 + 1.4 + i * 2.8
		U.rod(b, "LampArm%d" % i, Vector3(lx, 6.0, pz - 0.1), Vector3(lx, 6.5, pz - 0.7), 0.05, C_STEEL)
		U.box(b, "Lamp%d" % i, Vector3(0.5, 0.16, 0.25), Color(0.2, 0.2, 0.22) if i != 1 else Color(0.5, 0.45, 0.3), Vector3(lx, 6.5, pz - 0.8), false, 0.4, 0.5)
	# Мостик обслуживания на высоте 2.2, перила, ступеньки из поддонов с кирпичом
	var cw := U.box(b, "Catwalk", Vector3(8.8, 0.14, 1.1), Color(0.45, 0.47, 0.5), Vector3(6.8, 2.13, 3.5), true, 0.5, 0.5)
	for i in 14:
		U.box(cw, "Grating%d" % i, Vector3(0.05, 0.02, 1.0), Color(0.25, 0.26, 0.28), Vector3(-4.1 + i * 0.6, 0.08, 0))
	for j in 5:
		var lx := 2.7 + j * 2.2
		U.rod(b, "RailPost%d" % j, Vector3(lx, 2.2, 2.95), Vector3(lx, 3.2, 2.95), 0.05, C_STEEL)
	U.rod(b, "RailTop", Vector3(2.7, 3.2, 2.95), Vector3(11.1, 3.2, 2.95), 0.05, C_STEEL)
	U.rod(b, "RailMid", Vector3(2.7, 2.7, 2.95), Vector3(11.1, 2.7, 2.95), 0.04, C_STEEL)
	U.kind = "brick"
	var step1 := U.box(b, "PalletStack1", Vector3(1.6, 1.1, 1.2), C_BRICK, Vector3(1.5, 0.55, 3.5), true)
	for i in 4:
		U.box(step1, "BrickRow%d" % i, Vector3(1.62, 0.02, 1.22), C_BRICK.darkened(0.25), Vector3(0, -0.4 + i * 0.28, 0))
	U.box(step1, "Pallet", Vector3(1.7, 0.14, 1.3), C_WOOD, Vector3(0, -0.52, 0))
	U.box(step1, "Film", Vector3(1.62, 0.5, 1.22), Color(0.8, 0.85, 0.9, 0.35), Vector3(0, 0.2, 0))
	U.kind = "wood"
	var step2 := U.box(b, "PalletStack2", Vector3(1.2, 0.55, 1.2), C_WOOD.lightened(0.05), Vector3(2.5, 0.28, 2.0), false)
	_crate(b, Vector3(0.0, 0, 3.4))


# ---------- крыша C: мокрый шифер ----------
	U.kind = _k


func _roof_c() -> void:
	var _k := U.kind
	U.kind = "plaster"
	var c := Node3D.new()
	U.add(root_node, c, "RoofC")
	var wall := U.box(c, "Walls", Vector3(12.0, SLATE_W_EAVE - GROUND, 9.0), Color(0.88, 0.76, 0.48), Vector3(49.0, (SLATE_W_EAVE + GROUND) * 0.5, 0.0), true, 0.95)
	var theta := atan2(SLATE_RIDGE - SLATE_W_EAVE, C_RIDGE_X - C_X0)
	var slope_len := sqrt(pow(C_RIDGE_X - C_X0, 2) + pow(SLATE_RIDGE - SLATE_W_EAVE, 2))
	var slate_mat := StandardMaterial3D.new()
	slate_mat.vertex_color_use_as_albedo = true
	slate_mat.roughness = 0.22
	slate_mat.metallic = 0.15
	for side in [-1, 1]:
		var holder := Node3D.new()
		var nm := "SlateW" if side < 0 else "SlateE"
		var origin := Vector3(C_X0, SLATE_W_EAVE, 0) if side < 0 else Vector3(C_RIDGE_X, SLATE_RIDGE, 0)
		U.add(c, holder, nm, origin)
		holder.rotation.z = theta if side < 0 else -theta
		var mi := MeshInstance3D.new()
		mi.mesh = U.corrugated(slope_len, 10.2, 0.05, 0.3, Color(0.42, 0.47, 0.52), Color(0.25, 0.38, 0.3), 5 + side)
		mi.material_override = slate_mat
		U.add(holder, mi, "Sheets")
		var body := StaticBody3D.new()
		U.add(holder, body, "Collider", Vector3(slope_len * 0.5, -0.1, 0))
		U.box_shape(body, Vector3(slope_len, 0.2, 10.2))
		# Гвозди-шляпки и мох в стыках, ржавые подтёки
		for i in 26:
			var nx := rng.randf_range(0.3, slope_len - 0.3)
			var nzz := rng.randf_range(-4.8, 4.8)
			U.cyl(holder, "Nail%d" % i, 0.025, 0.02, 0.03, Color(0.15, 0.15, 0.15), Vector3(nx, 0.07, nzz), 6, 0.4, 0.6)
		for i in 10:
			var moss := U.box(holder, "Moss%d" % i, Vector3(rng.randf_range(0.4, 1.0), 0.02, rng.randf_range(0.3, 0.8)), Color(0.28, 0.5, 0.22), Vector3(rng.randf_range(0.3, slope_len - 0.4), 0.08, rng.randf_range(-4.5, 4.5)))
		# Лужицы в ложбинках у карниза
		var pud := U.cyl(holder, "Wet", 0.8, 0.8, 0.01, Color(0.55, 0.72, 0.88, 0.7), Vector3(0.9 if side < 0 else slope_len - 0.9, 0.09, rng.randf_range(-3, 3)), 14, 0.03, 0.2)
		pud.scale = Vector3(1.5, 1.0, 1.0)
		var zone_pos := (Vector3(C_X0 + 3.0, SLATE_W_EAVE + 1.4, 0) if side < 0 else Vector3(C_RIDGE_X + 3.0, SLATE_W_EAVE + 1.4, 0))
		var z := U.zone(c, "Slide" + nm, Vector3(6.2, 2.4, 9.6), zone_pos, "res://scripts/location/slide_zone.gd")
		z.set("downhill", Vector3(-1, 0, 0) if side < 0 else Vector3(1, 0, 0))
		z.set("pull", 4.5)
		z.set("grip", 5.0)
		_hazard(z, 1)
	# Конёк, желоба, фронтоны
	U.rod(c, "RidgeCap", Vector3(C_RIDGE_X, SLATE_RIDGE + 0.12, -5.0), Vector3(C_RIDGE_X, SLATE_RIDGE + 0.12, 5.0), 0.38, Color(0.3, 0.3, 0.34), 0.4, 0.5)
	for x in [C_X0 - 0.15, C_X1 + 0.15]:
		U.rod(c, "Gutter", Vector3(x, SLATE_W_EAVE - 0.1, -5.0), Vector3(x, SLATE_W_EAVE - 0.1, 5.0), 0.18, C_RUST, 0.7, 0.3)
		U.rod(c, "Downspout", Vector3(x + (0.05 if x < 49 else -0.05), SLATE_W_EAVE - 0.2, 4.2), Vector3(x + (0.05 if x < 49 else -0.05), GROUND + 0.4, 4.2), 0.12, C_RUST, 0.7, 0.3)
	for sz in [-1.0, 1.0]:
		var gm := MeshInstance3D.new()
		gm.mesh = U.gable(12.0, SLATE_RIDGE - SLATE_W_EAVE, 0.3, Color(0.82, 0.7, 0.42))
		gm.material_override = U.mat(Color(0.85, 0.72, 0.43), 0.95)
		U.add(c, gm, "Gable%s" % ("N" if sz < 0 else "S"), Vector3(C_RIDGE_X, SLATE_W_EAVE, sz * 4.5))
		# Слуховое окно на фронтоне
		U.box(c, "AtticFrame%s" % ("N" if sz < 0 else "S"), Vector3(0.9, 1.0, 0.1), Color(0.95, 0.95, 0.92), Vector3(C_RIDGE_X, SLATE_W_EAVE + 0.8, sz * 4.68))
		U.box(c, "AtticGlass%s" % ("N" if sz < 0 else "S"), Vector3(0.7, 0.8, 0.1), Color(0.2, 0.28, 0.36), Vector3(C_RIDGE_X, SLATE_W_EAVE + 0.8, sz * 4.72))
		U.box(c, "AtticBar%s" % ("N" if sz < 0 else "S"), Vector3(0.05, 0.8, 0.12), Color(0.95, 0.95, 0.92), Vector3(C_RIDGE_X, SLATE_W_EAVE + 0.8, sz * 4.74))
	# Окна старого дома (на западной и южной сторонах)
	for f in 4:
		for i in 3:
			_old_window(c, Vector3(C_X0 - 0.03, GROUND + 2.2 + f * 2.8, -2.8 + i * 2.8), true)
		for i in 4:
			_old_window(c, Vector3(C_X0 + 1.8 + i * 2.8, GROUND + 2.2 + f * 2.8, 4.53), false)
	# Труба-дымоход на коньке: наверху ждёт кот
	U.kind = "brick"
	var ch := U.box(c, "Chimney", Vector3(0.95, 2.4, 0.95), C_BRICK, Vector3(C_RIDGE_X, SLATE_RIDGE - 0.3 + 1.2 - 0.0, 2.8), true)
	for i in 8:
		U.box(ch, "BrickLine%d" % i, Vector3(0.97, 0.02, 0.97), C_BRICK.darkened(0.3), Vector3(0, -1.0 + i * 0.3, 0))
	U.box(ch, "Cap", Vector3(1.3, 0.18, 1.3), C_CONC, Vector3(0, 1.29, 0), false)
	U.box(ch, "Hole", Vector3(0.55, 0.02, 0.55), Color(0.05, 0.05, 0.05), Vector3(0, 1.39, 0), false)
	U.box(ch, "Soot", Vector3(0.7, 0.35, 0.02), Color(0.15, 0.15, 0.15), Vector3(0, 1.1, 0.48))
	U.kind = "plaster"
	_antenna(c, Vector3(C_RIDGE_X, SLATE_RIDGE + 0.1, -2.4), 3.4, 5)
	# Табличка у мостика: не ходить, крыша течёт
	var post := U.rod(c, "SignPost", Vector3(40.6, DECK_B, -3.0), Vector3(40.6, DECK_B + 1.5, -3.0), 0.07, C_RUST, 0.8, 0.3)
	var board := U.box(c, "SignBoard", Vector3(0.05, 0.7, 1.1), Color(0.95, 0.85, 0.25), Vector3(40.6, DECK_B + 1.35, -3.0))
	U.label(board, "Text", "SIGN_NO_ENTRY", Vector3(-0.03, 0, 0), 0.17, Color(0.15, 0.1, 0.1)).rotation_degrees.y = -90
	U.kind = _k


func _old_window(parent: Node, pos: Vector3, on_x: bool) -> void:
	var _k := U.kind
	U.kind = "paint"
	var w := Node3D.new()
	U.add(parent, w, "OldWindow", pos)
	if on_x:
		w.rotation_degrees.y = -90
	var glass := Color(0.22, 0.3, 0.4)
	var r := rng.randf()
	if r < 0.2:
		glass = Color(1.0, 0.85, 0.5)
	elif r < 0.45:
		glass = Color.from_hsv(rng.randf(), 0.35, 0.75)
	U.box(w, "Frame", Vector3(1.3, 1.5, 0.08), Color(0.95, 0.95, 0.92), Vector3.ZERO)
	U.box(w, "Glass", Vector3(1.1, 1.3, 0.1), glass, Vector3.ZERO)
	U.box(w, "Mullion", Vector3(0.06, 1.3, 0.12), Color(0.95, 0.95, 0.92), Vector3.ZERO)
	U.box(w, "Sill", Vector3(1.5, 0.08, 0.3), Color(0.7, 0.68, 0.64), Vector3(0, -0.8, 0.12))
	if rng.randf() < 0.4:
		U.box(w, "Flowerpot", Vector3(0.3, 0.2, 0.2), Color(0.7, 0.35, 0.25), Vector3(0.3, -0.65, 0.13))
		U.sphere(w, "Flower", 0.14, Color(0.9, 0.3, 0.4), Vector3(0.3, -0.45, 0.13))


# ---------- трап и мостик ----------
	U.kind = _k


func _ramp_and_planks() -> void:
	var _k := U.kind
	U.kind = "wood"
	var r := Node3D.new()
	U.add(root_node, r, "Bridges")
	# Трап с A на B: два широких прогона с поперечными рейками и верёвочными перилами
	var a := Vector3(12.0, DECK_A, 0)
	var b := Vector3(17.0, DECK_B, 0)
	var d := b - a
	var ang := atan2(d.y, d.x)
	var len := d.length()
	var n := Vector3(-sin(ang), cos(ang), 0)
	var ramp := StaticBody3D.new()
	U.add(r, ramp, "WoodRamp", (a + b) * 0.5 - n * 0.06)
	ramp.rotation.z = ang
	U.box_shape(ramp, Vector3(len + 0.2, 0.12, 1.9))
	var boards := 3
	for i in boards:
		U.box(ramp, "Board%d" % i, Vector3(len, 0.12, 0.6), C_WOOD.lightened(rng.randf_range(-0.08, 0.08)), Vector3(0, 0, -0.64 + i * 0.64), false, 0.95)
	for i in int(len / 0.6):
		U.box(ramp, "Cleat%d" % i, Vector3(0.08, 0.05, 1.9), C_WOOD.darkened(0.2), Vector3(-len * 0.5 + 0.3 + i * 0.6, 0.085, 0), false, 0.95)
	for z in [-0.98, 0.98]:
		for i in 4:
			var t := 0.1 + i * 0.27
			var p0 := a + d * t + Vector3(0, 0.0, z)
			U.rod(r, "RopePost", p0 + Vector3(0, 0.0, 0), p0 + Vector3(0, 0.95, 0), 0.06, C_WOOD.darkened(0.3), 0.9)
		U.rod(r, "Rope", a + d * 0.1 + Vector3(0, 0.9, z), a + d * 0.91 + Vector3(0, 0.9, z), 0.03, Color(0.85, 0.75, 0.5), 0.95)
	# Доска-мостик с B на C: узкая, прогнувшаяся
	var p1 := Vector3(41.0, DECK_B, 0)
	var p2 := Vector3(43.4, -2.74, 0)
	var dd := p2 - p1
	var pang := atan2(dd.y, dd.x)
	var plank := StaticBody3D.new()
	U.add(r, plank, "Plank", (p1 + p2) * 0.5 - Vector3(-sin(pang), cos(pang), 0) * 0.06)
	plank.rotation.z = pang
	U.box_shape(plank, Vector3(dd.length() + 0.2, 0.12, 1.4))
	U.box(plank, "Mesh", Vector3(dd.length() + 0.2, 0.12, 1.4), C_WOOD.darkened(0.05), Vector3.ZERO, false, 0.95)
	U.box(plank, "Split", Vector3(0.5, 0.125, 0.04), Color(0.15, 0.1, 0.06), Vector3(0.3, 0, 0.2))
	for s in [-1.0, 1.0]:
		U.box(plank, "Edge", Vector3(dd.length() + 0.2, 0.05, 0.05), C_WOOD.darkened(0.25), Vector3(0, 0.08, s * 0.68))


# ---------- опасности ----------
	U.kind = _k


func _hazards() -> void:
	var h := Node3D.new()
	U.add(root_node, h, "Hazards")
	# Ветер: толкает на север, к обрыву парапета. Сила растёт со сложностью
	var wind := U.zone(h, "WindGust", Vector3(66, 10, 16), Vector3(26, 3, 0), "res://scripts/location/wind_gust.gd")
	wind.set("direction", Vector3(0.15, 0, -1))
	wind.set("strength_by_tier", PackedFloat32Array([3.5, 5.5, 8.0]))
	_hazard(wind, 0)
	# Вентиляторы с лопастями
	_fan(h, "Fan1", Vector3(25.0, DECK_B, -1.0), 1)
	_fan(h, "Fan2", Vector3(28.0, DECK_B, 2.0), 2)


func _fan(parent: Node, nm: String, pos: Vector3, tier: int) -> void:
	var _k := U.kind
	U.kind = "metal"
	var f := Node3D.new()
	U.add(parent, f, nm, pos)
	U.cyl(f, "Housing", 0.7, 0.55, 0.9, Color(0.55, 0.58, 0.62), Vector3(0, 0.45, 0), 16, 0.4, 0.5).get_parent()
	var base := StaticBody3D.new()
	U.add(f, base, "Collider", Vector3(0, 0.45, 0))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.6
	sh.height = 0.9
	cs.shape = sh
	U.add(base, cs, "Shape")
	U.cyl(f, "Collar", 0.62, 0.62, 0.1, Color(0.3, 0.3, 0.33), Vector3(0, 0.95, 0), 16, 0.4, 0.5)
	U.box(f, "Warning", Vector3(0.6, 0.5, 0.04), Color(0.95, 0.85, 0.15), Vector3(0, 1.2, 0.8)).rotation_degrees.x = -10
	U.label(f.get_node("Warning"), "Text", "SIGN_BLADES", Vector3(0, 0, 0.03), 0.14, Color(0.1, 0.1, 0.1))
	U.rod(f, "WarnPost", Vector3(0, 0.0, 0.8), Vector3(0, 1.0, 0.8), 0.05, C_STEEL)
	var blades := SpinningBlade.new()
	blades.speed = 2.6 if tier == 1 else -3.4
	U.add(f, blades, "Blades", Vector3(0, 1.25, 0))
	for i in 2:
		var bl := U.box(blades, "Blade%d" % i, Vector3(2.8, 0.12, 0.45), Color(0.82, 0.25, 0.2), Vector3.ZERO, false, 0.5)
		bl.rotation_degrees.y = i * 90.0
		var cs2 := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.8, 0.5, 0.45)
		cs2.shape = bs
		U.add(blades, cs2, "Shape%d" % i)
		cs2.rotation_degrees.y = i * 90.0
	U.sphere(blades, "Hub", 0.18, Color(0.2, 0.2, 0.22), Vector3(0, 0.1, 0), 1.0)
	_hazard(f, tier)


# ---------- кот, игрок, чекпоинты ----------
	U.kind = _k


func _cat() -> void:
	var _k := U.kind
	U.kind = "paint"
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	# 0 щит (простая), 1 карниз над двором (средняя), 2 труба на шиферной крыше (сложная)
	var m0 := Marker3D.new()
	U.add(spots, m0, "Billboard", Vector3(39.4, DECK_B + 2.2, 3.5))
	m0.rotation_degrees.y = 270
	var m1 := Marker3D.new()
	U.add(spots, m1, "Cornice", Vector3(30.5, DECK_B - 0.9, -6.3))
	m1.rotation_degrees.y = 180
	var m2 := Marker3D.new()
	U.add(spots, m2, "Chimney", Vector3(C_RIDGE_X, 0.99, 2.8))
	m2.rotation_degrees.y = 200
	var cat := Node3D.new()
	cat.set_script(load("res://scripts/location/rescue_cat.gd"))
	U.add(root_node, cat, "Cat", m0.position)
	var v := Node3D.new()
	U.add(cat, v, "Visual")
	var fur := Color(0.95, 0.6, 0.2)
	var dark := Color(0.7, 0.35, 0.1)
	U.sphere(v, "Body", 0.28, fur, Vector3(0, 0.3, 0), 1.15)
	U.sphere(v, "Belly", 0.2, Color(1.0, 0.92, 0.8), Vector3(0, 0.28, 0.17), 1.0)
	U.sphere(v, "Haunch", 0.2, fur, Vector3(0.17, 0.2, -0.06), 0.9)
	U.sphere(v, "HaunchL", 0.2, fur, Vector3(-0.17, 0.2, -0.06), 0.9)
	for i in 3:
		U.box(v, "Stripe%d" % i, Vector3(0.36, 0.05, 0.05), dark, Vector3(0, 0.45 - i * 0.08, -0.15 + i * 0.1)).rotation_degrees.x = 15 * (i - 1)
	var head := Node3D.new()
	U.add(v, head, "Head", Vector3(0, 0.72, 0.1))
	U.sphere(head, "HeadMesh", 0.24, fur, Vector3.ZERO, 0.9)
	U.sphere(head, "Muzzle", 0.1, Color(1.0, 0.92, 0.8), Vector3(0, -0.06, 0.18), 0.8)
	U.sphere(head, "Nose", 0.03, Color(0.95, 0.5, 0.55), Vector3(0, -0.02, 0.26))
	for s in [-1.0, 1.0]:
		var ear := U.cyl(head, "Ear", 0.09, 0.0, 0.2, fur, Vector3(s * 0.14, 0.2, 0.0), 4)
		ear.rotation_degrees.z = -s * 18
		U.cyl(head, "EarIn", 0.05, 0.0, 0.14, Color(0.95, 0.6, 0.65), Vector3(s * 0.14, 0.19, 0.04), 4).rotation_degrees.z = -s * 18
		# Усы
		for k in 3:
			U.rod(head, "Whisker", Vector3(s * 0.08, -0.05 - k * 0.015, 0.22), Vector3(s * 0.36, -0.03 - k * 0.05, 0.2), 0.008, Color(0.95, 0.95, 0.95))
	var eyes := Node3D.new()
	U.add(v, eyes, "Eyes", Vector3(0, 0.76, 0.3))
	for s in [-1.0, 1.0]:
		U.sphere(eyes, "EyeWhite", 0.07, Color.WHITE, Vector3(s * 0.1, 0, 0), 1.2)
		U.sphere(eyes, "Pupil", 0.045, Color(0.08, 0.1, 0.12), Vector3(s * 0.1, -0.01, 0.045), 1.2)
		U.sphere(eyes, "Glint", 0.015, Color.WHITE, Vector3(s * 0.1 + 0.015, 0.02, 0.085))
	# Ошейник с биркой «Мурзик»
	U.cyl(v, "Collar", 0.2, 0.2, 0.05, Color(0.85, 0.15, 0.2), Vector3(0, 0.58, 0.1), 14).rotation_degrees.x = 20
	U.sphere(v, "Tag", 0.035, Color(0.95, 0.8, 0.2), Vector3(0, 0.52, 0.28), 1.0)
	# Лапы и хвост
	for s in [-1.0, 1.0]:
		U.sphere(v, "Paw", 0.08, Color(1.0, 0.92, 0.8), Vector3(s * 0.12, 0.06, 0.2), 0.7)
	var tail := Node3D.new()
	U.add(v, tail, "Tail", Vector3(0, 0.12, -0.28))
	for i in 5:
		var seg := U.sphere(tail, "Seg%d" % i, 0.07 - i * 0.004, fur if i != 4 else dark, Vector3(0.0, 0.06 + i * 0.08, -0.05 - i * 0.04), 1.0)
	var bubble := Label3D.new()
	bubble.text = "CAT_MEOW"
	bubble.font_size = 64
	bubble.pixel_size = 0.012
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.modulate = Color(1, 1, 1)
	bubble.outline_size = 14
	bubble.outline_modulate = Color(0.1, 0.1, 0.1)
	bubble.no_depth_test = true
	U.add(cat, bubble, "Bubble", Vector3(0, 1.4, 0))
	U.trigger(cat, "Trigger", "PROMPT_RESCUE", Vector3(0, 0.6, 0), 1.9)
	U.kind = _k


func _players_and_checkpoints() -> void:
	var holder := Node3D.new()
	U.add(root_node, holder, "Players")
	U.player(holder, Vector3(-7.4, DECK_A + 0.5, 0.0))
	var cps := Node3D.new()
	U.add(root_node, cps, "Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, Vector3(-6.2, DECK_A, 0.0))
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(19.5, DECK_B, -2.2))
	U.checkpoint(cps, "Checkpoint2", 2, Vector3(C_RIDGE_X - 0.3, SLATE_RIDGE + 0.1, -3.6))


# ---------- мелочи для реализма: сорняки, подтёки, вёдра, шины, гнездо ----------

func _extras() -> void:
	var old := U.kind
	var e := Node3D.new()
	U.add(root_node, e, "Extras")
	# Сорняки и мох в трещинах у парапета и вокруг воронок (пучки из стеблей-конусов)
	U.kind = "paint"
	var tufts: Array[Vector3] = []
	for deck in [[0.0, DECK_A], [29.0, DECK_B]]:
		for i in 26:
			var along := rng.randf_range(-11.5, 11.5)
			var edge := rng.randf_range(0.0, 1.0)
			var z := (-5.35 if edge < 0.5 else 5.35) + rng.randf_range(-0.1, 0.1)
			tufts.append(Vector3(deck[0] + along, deck[1], z))
		for i in 8:
			tufts.append(Vector3(deck[0] + rng.randf_range(-11, 11), deck[1], rng.randf_range(-4.5, 4.5)))
	var ti := 0
	for t in tufts:
		_weed(e, t, ti)
		ti += 1
	# Ржавые подтёки под креплениями и дымоходом
	for i in 14:
		var x := rng.randf_range(-11.0, 11.0)
		var drip := U.box(e, "RustDrip%d" % i, Vector3(0.06, 0.012, rng.randf_range(0.5, 1.4)), Color(0.5, 0.28, 0.14, 0.7), Vector3(x, DECK_A + 0.017, rng.randf_range(-4.5, 4.5)))
	for i in 10:
		var x := 29.0 + rng.randf_range(-11.0, 11.0)
		U.box(e, "RustDripB%d" % i, Vector3(0.06, 0.012, rng.randf_range(0.5, 1.4)), Color(0.5, 0.28, 0.14, 0.7), Vector3(x, DECK_B + 0.017, rng.randf_range(-4.5, 4.5)))
	# Вёдра с застывшей смолой, банки краски, старая шина, мотки кабеля
	U.kind = "metal"
	_bucket(e, Vector3(-4.8, DECK_A, -1.6), Color(0.2, 0.4, 0.7))
	_bucket(e, Vector3(7.0, DECK_A, 3.0), Color(0.75, 0.2, 0.18))
	_bucket(e, Vector3(35.0, DECK_B, -2.5), Color(0.9, 0.7, 0.15))
	for p in [Vector3(-9.0, DECK_A, -3.0), Vector3(32.5, DECK_B, 3.6)]:
		var tire := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.18
		tm.outer_radius = 0.42
		tm.rings = 24
		tm.ring_segments = 14
		tire.mesh = tm
		tire.material_override = U.mat(Color(0.1, 0.1, 0.11), 0.95)
		U.add(e, tire, "Tire", p + Vector3(0, 0.2, 0))
	# Гнездо голубя на выступе щита и птичьи перья
	U.kind = "wood"
	var nest := Node3D.new()
	U.add(e, nest, "Nest", Vector3(29.0 + 3.6, DECK_B + 2.3, 3.55))
	for i in 22:
		var ang := rng.randf() * TAU
		var tw := U.rod(nest, "Twig", Vector3(cos(ang) * 0.05, 0, sin(ang) * 0.05), Vector3(cos(ang) * 0.24, rng.randf_range(0.0, 0.1), sin(ang) * 0.24), 0.012, Color(0.45, 0.35, 0.22), 0.95)
	U.sphere(nest, "Egg", 0.05, Color(0.95, 0.95, 0.9), Vector3(0, 0.03, 0), 1.3)
	U.kind = old


func _weed(parent: Node, pos: Vector3, seed_value: int) -> void:
	var w := Node3D.new()
	U.add(parent, w, "Weed%d" % seed_value, pos)
	var col := Color(0.35, 0.55, 0.2).lerp(Color(0.55, 0.62, 0.25), rng.randf())
	for i in rng.randi_range(4, 8):
		var blade := U.cyl(w, "Blade", 0.0, 0.012, rng.randf_range(0.18, 0.4), col, Vector3(rng.randf_range(-0.06, 0.06), 0.1, rng.randf_range(-0.06, 0.06)), 4, 0.9)
		blade.rotation_degrees = Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))
	if rng.randf() < 0.3:
		U.sphere(w, "Flower", 0.025, Color(0.95, 0.85, 0.2), Vector3(0, 0.38, 0), 1.0)


func _bucket(parent: Node, pos: Vector3, col: Color) -> void:
	var b := Node3D.new()
	U.add(parent, b, "Bucket", pos)
	U.cyl(b, "Body", 0.2, 0.24, 0.32, col, Vector3(0, 0.16, 0), 24, 0.5, 0.3)
	U.cyl(b, "Rim", 0.25, 0.25, 0.03, col.darkened(0.2), Vector3(0, 0.33, 0), 24, 0.5, 0.3)
	U.cyl(b, "Tar", 0.2, 0.2, 0.01, Color(0.06, 0.06, 0.07), Vector3(0, 0.3, 0), 24, 0.3)
	var handle := U.rod(b, "Handle", Vector3(-0.22, 0.33, 0), Vector3(0.0, 0.5, 0), 0.015, Color(0.7, 0.7, 0.72), 0.4, 0.6)
	U.rod(b, "Handle2", Vector3(0.0, 0.5, 0), Vector3(0.22, 0.33, 0), 0.015, Color(0.7, 0.7, 0.72), 0.4, 0.6)


# ---------- дальний город: кварталы до горизонта ----------

const FAR_COLORS := [Color(0.9, 0.86, 0.76), Color(0.85, 0.8, 0.7), Color(0.82, 0.84, 0.86), Color(0.9, 0.82, 0.68), Color(0.78, 0.8, 0.74), Color(0.88, 0.78, 0.72), Color(0.8, 0.75, 0.8)]

var _win_tex: ImageTexture
var _far_mats := {}


## Текстура фасада: 4 окна × 4 этажа (12 × 11.2 м), швы панелей, балконы, где-то горит свет.
func _facade_texture() -> ImageTexture:
	if _win_tex:
		return _win_tex
	var img := Image.create(256, 256, true, Image.FORMAT_RGBA8)
	img.fill(Color(0.95, 0.94, 0.92))
	var cell := 64
	for fy in 4:
		for fx in 4:
			var x0 := fx * cell
			var y0 := fy * cell
			var lit := rng.randf() < 0.14
			var glass := Color(1.0, 0.85, 0.5) if lit else Color(0.28, 0.34, 0.44).lerp(Color(0.5, 0.52, 0.58), rng.randf() * 0.6)
			if not lit and rng.randf() < 0.3:
				glass = Color.from_hsv(rng.randf(), 0.3, 0.75)  # шторы
			img.fill_rect(Rect2i(x0 + 15, y0 + 14, 34, 36), Color(0.97, 0.97, 0.95))
			img.fill_rect(Rect2i(x0 + 18, y0 + 17, 28, 30), glass)
			img.fill_rect(Rect2i(x0 + 31, y0 + 17, 2, 30), Color(0.97, 0.97, 0.95))
			if fx % 2 == 0:
				img.fill_rect(Rect2i(x0 + 8, y0 + 50, 48, 10), Color(0.55, 0.62, 0.7).lerp(Color(0.8, 0.5, 0.35), rng.randf() * 0.7))
	for i in 5:
		img.fill_rect(Rect2i(0, i * cell - 1 if i > 0 else 0, 256, 2), Color(0.6, 0.58, 0.55))
		img.fill_rect(Rect2i(i * cell - 1 if i > 0 else 0, 0, 2, 256), Color(0.7, 0.68, 0.65))
	img.generate_mipmaps()
	_win_tex = ImageTexture.create_from_image(img)
	return _win_tex


func _far_mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if _far_mats.has(key):
		return _far_mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.albedo_texture = _facade_texture()
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.0 / 12.0, -1.0 / 11.2, 1.0 / 12.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 0.9
	_far_mats[key] = m
	return m


func _lod_building(parent: Node, nm: String, cx: float, cz: float, rot_y: float, length: float, floors: int, col: Color) -> void:
	var depth := 11.0
	var h := 0.7 + floors * 2.8
	var b := Node3D.new()
	U.add(parent, b, nm, Vector3(cx, GROUND, cz))
	b.rotation_degrees.y = rot_y
	var bm := BoxMesh.new()
	bm.size = Vector3(length, h, depth)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = _far_mat(col)
	U.add(b, mi, "Body", Vector3(0, h * 0.5, 0))
	U.box(b, "Plinth", Vector3(length + 0.2, 0.7, depth + 0.2), Color(0.45, 0.42, 0.4), Vector3(0, 0.35, 0))
	U.box(b, "Roof", Vector3(length + 0.4, 0.3, depth + 0.4), Color(0.3, 0.3, 0.33), Vector3(0, h + 0.1, 0))
	U.box(b, "ParapetF", Vector3(length + 0.4, 0.5, 0.2), col.darkened(0.25), Vector3(0, h + 0.4, depth * 0.5 + 0.1))
	U.box(b, "ParapetB", Vector3(length + 0.4, 0.5, 0.2), col.darkened(0.25), Vector3(0, h + 0.4, -depth * 0.5 - 0.1))
	for i in int(length / 12.0):
		var x := -length * 0.5 + 6.0 + i * 12.0
		U.box(b, "Vent%d" % i, Vector3(1.0, 1.0, 1.0), col.darkened(0.3), Vector3(x, h + 0.8, rng.randf_range(-2, 2)))
		if rng.randf() < 0.6:
			U.rod(b, "Ant%d" % i, Vector3(x + 2.0, h + 0.3, 1.0), Vector3(x + 2.0, h + 3.2, 1.0), 0.05, Color(0.3, 0.3, 0.3))
			U.rod(b, "AntBar%d" % i, Vector3(x + 1.4, h + 2.6, 1.0), Vector3(x + 2.6, h + 2.6, 1.0), 0.04, Color(0.3, 0.3, 0.3))


func _far_tree(parent: Node, pos: Vector3, h: float, col: Color) -> void:
	var t := Node3D.new()
	U.add(parent, t, "FTree", pos)
	U.cyl(t, "Trunk", 0.2, 0.28, h * 0.5, Color(0.4, 0.3, 0.22), Vector3(0, h * 0.25, 0), 6)
	for i in 3:
		U.sphere(t, "Crown%d" % i, h * (0.3 - i * 0.04), col.lerp(Color(0.5, 0.65, 0.3), rng.randf() * 0.4), Vector3(rng.randf_range(-0.5, 0.5), h * (0.55 + i * 0.16), rng.randf_range(-0.5, 0.5)), 1.1)


func _far_city() -> void:
	var old := U.kind
	U.rounded = false
	U.kind = "paint"
	var f := Node3D.new()
	U.add(root_node, f, "FarCity")
	var asphalt := Color(0.27, 0.27, 0.3)
	var ci := 0
	for ix in range(-7, 8):
		for iz in range(-7, 8):
			var cx := ix * 56.0 + rng.randf_range(-5, 5)
			var cz := iz * 56.0 + rng.randf_range(-5, 5)
			# Рядом уже стоят дома со двором: оставляем центр
			if cx > -80 and cx < 120 and cz > -55 and cz < 60:
				continue
			var tall := rng.randf() < 0.28
			var floors: int = [9, 12, 16][rng.randi() % 3] if tall else 5
			var col: Color = FAR_COLORS[rng.randi() % FAR_COLORS.size()]
			var length: float = rng.randf_range(24, 48)
			_lod_building(f, "B%d" % ci, cx, cz - 13, 0.0, length, floors, col)
			if rng.randf() < 0.75:
				_lod_building(f, "B%d" % (ci + 1), cx + rng.randf_range(-10, 10), cz + 13, 180.0, rng.randf_range(24, 48), 5 if rng.randf() < 0.7 else 9, FAR_COLORS[rng.randi() % FAR_COLORS.size()])
			ci += 2
			# Дорога вдоль квартала, разметка и машины
			U.box(f, "Road%d_%d" % [ix, iz], Vector3(56.0, 0.08, 7.0), asphalt, Vector3(cx, GROUND + 0.04, cz + 28.0))
			U.box(f, "RoadX%d_%d" % [ix, iz], Vector3(7.0, 0.08, 56.0), asphalt, Vector3(cx + 28.0, GROUND + 0.045, cz))
			for k in 3:
				U.box(f, "Mark", Vector3(2.2, 0.02, 0.16), Color(0.95, 0.95, 0.9), Vector3(cx - 18 + k * 18, GROUND + 0.09, cz + 28.0))
			if rng.randf() < 0.55 and absf(cx) < 260 and absf(cz) < 260:
				_car(f, "FCar%d" % ci, Vector3(cx + rng.randf_range(-22, 22), GROUND, cz + 28.0 + (-1.7 if rng.randf() < 0.5 else 1.7)), 0.0 if rng.randf() < 0.5 else 180.0, Color.from_hsv(rng.randf(), 0.5, 0.7))
			# Дворы: газон, деревья, гаражи, площадка
			U.box(f, "Lawn%d_%d" % [ix, iz], Vector3(46.0, 0.05, 11.0), Color(0.42, 0.56, 0.34), Vector3(cx, GROUND + 0.03, cz))
			for t in 5:
				_far_tree(f, Vector3(cx + rng.randf_range(-26, 26), GROUND, cz + rng.randf_range(-6, 6)), rng.randf_range(6.0, 11.0), Color(0.35, 0.55, 0.28))
			if rng.randf() < 0.35:
				for g in 4:
					U.box(f, "G%d" % g, Vector3(3.0, 2.3, 5.5), Color.from_hsv(0.08 + g * 0.07, 0.25, 0.55), Vector3(cx + 20 + g * 3.3, GROUND + 1.15, cz - 3))
	# Рощи и лесополоса по краю города
	var edge := Node3D.new()
	U.add(root_node, edge, "Forest")
	for i in 240:
		var a := rng.randf() * TAU
		var r := rng.randf_range(430.0, 520.0)
		_far_tree(edge, Vector3(cos(a) * r, GROUND, sin(a) * r), rng.randf_range(10.0, 18.0), Color(0.25, 0.42, 0.22))
	# ТЭЦ: трубы в красно-белую полоску, градирни, пар
	var pw := Node3D.new()
	U.add(root_node, pw, "PowerPlant", Vector3(-230, GROUND, -250))
	for i in 2:
		var x := i * 28.0
		for seg in 8:
			U.cyl(pw, "Stack%d_%d" % [i, seg], 5.5 - seg * 0.28, 5.5 - (seg + 1) * 0.28, 14.0, Color(0.9, 0.2, 0.15) if seg % 2 == 0 else Color(0.95, 0.95, 0.95), Vector3(x, 7.0 + seg * 14.0, 0), 20)
		for k in 6:
			U.sphere(pw, "Steam%d_%d" % [i, k], 9.0 + k * 3.0, Color(0.95, 0.95, 0.97, 0.75), Vector3(x + 8 + k * 11, 125.0 + k * 9.0, 4), 0.7)
	for i in 3:
		U.cyl(pw, "Cooling%d" % i, 22.0, 15.0, 55.0, Color(0.78, 0.76, 0.72), Vector3(-60 + i * 50, 27.5, 60), 32)
		U.sphere(pw, "CoolSteam%d" % i, 18.0, Color(0.95, 0.95, 0.97, 0.7), Vector3(-60 + i * 50, 70.0, 60), 0.6)
	U.box(pw, "Hall", Vector3(110, 28, 36), Color(0.6, 0.6, 0.62), Vector3(10, 14, -50))
	# Телебашня и стрела башенного крана на стройке
	var tv := Node3D.new()
	U.add(root_node, tv, "TVTower", Vector3(260, GROUND, -230))
	for leg in 4:
		var ang := leg * PI * 0.5 + PI * 0.25
		U.rod(tv, "Leg%d" % leg, Vector3(cos(ang) * 14, 0, sin(ang) * 14), Vector3(0, 150, 0), 1.2, Color(0.9, 0.9, 0.92), 0.6, 0.2)
	U.cyl(tv, "Mast", 1.0, 0.3, 80.0, Color(0.9, 0.2, 0.15), Vector3(0, 190, 0), 12)
	U.cyl(tv, "Deck", 8.0, 8.0, 5.0, Color(0.85, 0.85, 0.88), Vector3(0, 120, 0), 20)
	var cr := Node3D.new()
	U.add(root_node, cr, "Crane", Vector3(-150, GROUND, 120))
	U.rod(cr, "Mast", Vector3(0, 0, 0), Vector3(0, 55, 0), 1.6, Color(0.95, 0.75, 0.1), 0.6, 0.2)
	U.rod(cr, "Jib", Vector3(-30, 55, 0), Vector3(38, 55, 0), 1.2, Color(0.95, 0.75, 0.1), 0.6, 0.2)
	U.rod(cr, "Cable", Vector3(26, 55, 0), Vector3(26, 20, 0), 0.1, Color(0.2, 0.2, 0.2))
	U.box(cr, "Weight", Vector3(4, 3, 3), Color(0.5, 0.5, 0.5), Vector3(-26, 52, 0))
	# ЛЭП: решётчатые опоры с проводами через город
	var prev := Vector3.ZERO
	for i in 8:
		var pylon := Node3D.new()
		var pos := Vector3(-300 + i * 90, GROUND, 150)
		U.add(root_node, pylon, "Pylon%d" % i, pos)
		for leg in [-1.0, 1.0]:
			U.rod(pylon, "Leg", Vector3(leg * 4, 0, 0), Vector3(leg * 1.0, 38, 0), 0.5, Color(0.55, 0.57, 0.6), 0.6, 0.4)
		for y in [14.0, 24.0, 33.0]:
			U.rod(pylon, "Arm", Vector3(-9, y, 0), Vector3(9, y, 0), 0.35, Color(0.55, 0.57, 0.6), 0.6, 0.4)
			U.rod(pylon, "Brace", Vector3(-1.5, y - 8, 0), Vector3(1.5, y, 0), 0.2, Color(0.55, 0.57, 0.6), 0.6, 0.4)
		if i > 0:
			for dx in [-9.0, 0.0, 9.0]:
				var mid := (pos + prev) * 0.5 + Vector3(dx, 29.0, 0)
				U.rod(root_node, "Wire", prev + Vector3(dx, 33.0, 0), mid, 0.06, Color(0.1, 0.1, 0.1))
				U.rod(root_node, "Wire2", mid, pos + Vector3(dx, 33.0, 0), 0.06, Color(0.1, 0.1, 0.1))
		prev = pos
	U.kind = old
	U.rounded = true


# ---------- облака ----------

func _clouds() -> void:
	var old_r := U.rounded
	var c := Node3D.new()
	U.add(root_node, c, "Clouds")
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(1.0, 0.96, 0.9)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.78, 0.55)
	lit.emission_energy_multiplier = 0.28
	lit.roughness = 1.0
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(0.82, 0.74, 0.74)
	shade.emission_enabled = true
	shade.emission = Color(0.95, 0.65, 0.5)
	shade.emission_energy_multiplier = 0.2
	shade.roughness = 1.0
	for i in 34:
		var a := rng.randf() * TAU
		var r := rng.randf_range(120.0, 650.0)
		var cl := Node3D.new()
		U.add(c, cl, "Cloud%d" % i, Vector3(cos(a) * r, rng.randf_range(70.0, 190.0), sin(a) * r))
		cl.rotation_degrees.y = rng.randf() * 360.0
		var k := rng.randf_range(0.8, 1.7)
		var puffs := rng.randi_range(6, 10)
		for j in puffs:
			var rad := rng.randf_range(14.0, 26.0) * k
			var sm := SphereMesh.new()
			sm.radius = rad
			sm.height = rad * 1.5
			sm.radial_segments = 20
			sm.rings = 10
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			var up := rng.randf_range(0.0, 1.0)
			mi.material_override = lit if up > 0.25 else shade
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			U.add(cl, mi, "Puff%d" % j, Vector3((j - puffs * 0.5) * 22.0 * k * 0.7 + rng.randf_range(-8, 8), rad * 0.5 * (up if up > 0.25 else 0.0) , rng.randf_range(-12, 12) * k))
			mi.scale = Vector3(1.0, 0.8, 1.0)
	# Высокие перистые полосы
	for i in 10:
		var a := rng.randf() * TAU
		var st := U.box(c, "Cirrus%d" % i, Vector3(rng.randf_range(160, 300), 0.6, rng.randf_range(6, 14)), Color(1.0, 0.92, 0.85, 0.5), Vector3(cos(a) * 500, rng.randf_range(260, 340), sin(a) * 500))
		st.rotation_degrees.y = rng.randf() * 180.0
		st.get_child(0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.rounded = old_r
