@tool
extends SceneTree
## Генерирует res://scenes/locations/house.tscn: локация 6 «Дом №13» (старый дом с привидениями, ночь, свечи).
## Запуск: godot --headless --path godot --script res://tools/build_house.gd
##
## Дом 24×16 м: подвал под гостиной, этажи y=0 / 3.2 / 6.4 (чердак), лестницы-пандусы, тайная комната за шкафом.
## Коты: простая — на чердаке; средняя — в подвале (путь через гнилой пол гостиной или лестницу); сложная — в тайной комнате.
## Опасности: скрипучие половицы будят призрака-простыню (тихое прохождение — бонус), гнилой пол, сквозняки гасят свечи (тир 1),
## паутина липнет (тир 0, на сложной больше), призрак быстрее по тирам.

const U := preload("res://scripts/location/loc_util.gd")

var root_node: Node3D
var rng := RandomNumberGenerator.new()
var _cache := {}

const SPAWN := Vector3(0.0, 0.0, 22.0)
const F1 := 0.0
const F2 := 3.2
const F3 := 6.4
const C_RUST := Color(0.5, 0.3, 0.18)
const C_STEEL := Color(0.45, 0.5, 0.55)
const C_WOOD := Color(0.36, 0.24, 0.16)
const C_WOOD_D := Color(0.24, 0.16, 0.11)
const C_PAPER_G := Color(0.3, 0.42, 0.35)
const C_PAPER_Y := Color(0.72, 0.64, 0.42)
const C_PAPER_R := Color(0.5, 0.22, 0.24)
const C_PAPER_B := Color(0.32, 0.4, 0.52)
const C_PAPER_P := Color(0.58, 0.42, 0.47)
const C_SIDING := Color(0.55, 0.62, 0.55)


func _init() -> void:
	rng.seed = 1313
	root_node = Node3D.new()
	root_node.name = "House"
	root_node.set_script(load("res://scripts/location/location.gd"))
	root_node.set("title_key", "LOC_HOUSE")
	root_node.set("kill_height", -6.0)
	U.rounded = false
	_environment()
	_director()
	_yard()
	_shell()
	_stairs()
	_ground_floor()
	_upper_floor()
	_attic()
	_cellar()
	_secret()
	_roof()
	_creaks()
	_draughts()
	_cobwebs()
	_signs()
	_cat()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/house.tscn")
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


# ---------- геометрия: плиты, стены, проёмы ----------

## Вычитает прямоугольники-дыры из прямоугольника: [x0, x1, z0, z1] → список оставшихся кусков.
func _rect_minus(rect: Array, holes: Array) -> Array:
	var res := [rect]
	for h in holes:
		var nxt := []
		for r in res:
			var ix0: float = maxf(r[0], h[0])
			var ix1: float = minf(r[1], h[1])
			var iz0: float = maxf(r[2], h[2])
			var iz1: float = minf(r[3], h[3])
			if ix0 >= ix1 or iz0 >= iz1:
				nxt.append(r)
				continue
			if r[0] < ix0:
				nxt.append([r[0], ix0, r[2], r[3]])
			if ix1 < r[1]:
				nxt.append([ix1, r[1], r[2], r[3]])
			if r[2] < iz0:
				nxt.append([ix0, ix1, r[2], iz0])
			if iz1 < r[3]:
				nxt.append([ix0, ix1, iz1, r[3]])
		res = nxt
	return res


## Плита: верх на y, толщина th. Дыры вырезаются.
func _slab_area(parent: Node, nm: String, rect: Array, holes: Array, y: float, th: float, col: Color, kind := "wood") -> void:
	var i := 0
	for r in _rect_minus(rect, holes):
		var sx: float = r[1] - r[0]
		var sz: float = r[3] - r[2]
		if sx < 0.05 or sz < 0.05:
			continue
		_sb(parent, "%s%d" % [nm, i], Vector3(sx, th, sz), col, Vector3((r[0] + r[1]) * 0.5, y - th * 0.5, (r[2] + r[3]) * 0.5), kind, 0.9)
		i += 1


## Разбивает отрезок [a, b] проёмами [центр, ширина, низ, верх] на куски стены (низ/верх проёмов и полные).
func _wall_pieces(a: float, b: float, y0: float, h: float, openings: Array) -> Array:
	var ops := openings.duplicate()
	ops.sort_custom(func(p, q): return p[0] < q[0])
	var pieces := []
	var cur := a
	for o in ops:
		var l: float = o[0] - o[1] * 0.5
		var r: float = o[0] + o[1] * 0.5
		if l > cur + 0.01:
			pieces.append([cur, l, y0, y0 + h])
		if o[2] > y0 + 0.01:
			pieces.append([l, r, y0, o[2]])
		if o[3] < y0 + h - 0.01:
			pieces.append([l, r, o[3], y0 + h])
		cur = r
	if cur < b - 0.01:
		pieces.append([cur, b, y0, y0 + h])
	return pieces


## Стена вдоль X на z: проёмы [cx, w, y_low, y_high] (абсолютные y). skin — наружная обшивка; out = +1/-1 (в какую сторону наружу).
func _wall_x(parent: Node, nm: String, z: float, x0: float, x1: float, y0: float, h: float, col: Color, openings := [], skin := false, out := 1.0, kind := "plaster") -> void:
	var i := 0
	for p in _wall_pieces(x0, x1, y0, h, openings):
		var sx: float = p[1] - p[0]
		var sy: float = p[3] - p[2]
		var cx: float = (p[0] + p[1]) * 0.5
		var cy: float = (p[2] + p[3]) * 0.5
		_sb(parent, "%s%d" % [nm, i], Vector3(sx, sy, 0.3), col, Vector3(cx, cy, z), kind, 0.95)
		if skin:
			_vb(parent, "%sSkin%d" % [nm, i], Vector3(sx, sy, 0.07), C_SIDING, Vector3(cx, cy, z + out * 0.185), "wood", 0.95)
		i += 1


func _wall_z(parent: Node, nm: String, x: float, z0: float, z1: float, y0: float, h: float, col: Color, openings := [], skin := false, out := 1.0, kind := "plaster") -> void:
	var i := 0
	for p in _wall_pieces(z0, z1, y0, h, openings):
		var sz: float = p[1] - p[0]
		var sy: float = p[3] - p[2]
		var cz: float = (p[0] + p[1]) * 0.5
		var cy: float = (p[2] + p[3]) * 0.5
		_sb(parent, "%s%d" % [nm, i], Vector3(0.3, sy, sz), col, Vector3(x, cy, cz), kind, 0.95)
		if skin:
			_vb(parent, "%sSkin%d" % [nm, i], Vector3(0.07, sy, sz), C_SIDING, Vector3(x + out * 0.185, cy, cz), "wood", 0.95)
		i += 1


## Оконная рама со стеклом и рваной шторой. axis "x": окно в стене вдоль X на z; "z": в стене вдоль Z на x.
func _window(parent: Node, axis: String, fixed: float, c: float, y_low: float, w: float, h: float, inward: float) -> void:
	var wn := Node3D.new()
	U.add(parent, wn, "Window")
	var frame := Color(0.8, 0.78, 0.7)
	var dx: Vector3 = Vector3(1, 0, 0) if axis == "x" else Vector3(0, 0, 1)
	var dn: Vector3 = Vector3(0, 0, 1) if axis == "x" else Vector3(1, 0, 0)
	var base: Vector3 = Vector3(c, y_low + h * 0.5, fixed) if axis == "x" else Vector3(fixed, y_low + h * 0.5, c)
	wn.position = base
	var glass_size := Vector3(w, h, 0.02) if axis == "x" else Vector3(0.02, h, w)
	var gm := _vb(wn, "Glass", glass_size, Color(0.55, 0.65, 0.75, 0.22), Vector3.ZERO, "paint", 0.05)
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sgn in [-1.0, 1.0]:
		var fs := Vector3(w + 0.1, 0.07, 0.1) if axis == "x" else Vector3(0.1, 0.07, w + 0.1)
		_vb(wn, "FrameH", fs, frame, Vector3(0, sgn * (h * 0.5 + 0.02), 0), "wood")
		var vs := Vector3(0.07, h, 0.1) if axis == "x" else Vector3(0.1, h, 0.07)
		_vb(wn, "FrameV", vs, frame, dx * sgn * (w * 0.5 + 0.02), "wood")
	var cs := Vector3(w, 0.05, 0.1) if axis == "x" else Vector3(0.1, 0.05, w)
	_vb(wn, "Mullion", cs, frame, Vector3.ZERO, "wood")
	var cv := Vector3(0.05, h, 0.1) if axis == "x" else Vector3(0.1, h, 0.05)
	_vb(wn, "MullionV", cv, frame, Vector3.ZERO, "wood")
	# подоконник и рваная штора внутри
	var sill := Vector3(w + 0.3, 0.06, 0.3) if axis == "x" else Vector3(0.3, 0.06, w + 0.3)
	var inv := dn * inward
	_vb(wn, "Sill", sill, frame, Vector3(0, -h * 0.5 - 0.05, 0) + inv * 0.45, "wood")
	var cur := Vector3(w * 0.3, h * 1.05, 0.04) if axis == "x" else Vector3(0.04, h * 1.05, w * 0.3)
	for sg in [-1.0, 1.0]:
		var side: Vector3 = dx * sg * w * 0.36
		_vb(wn, "Curtain", cur, Color(0.45, 0.2, 0.25).darkened(0.2), side + inv * 0.22 + Vector3(0, 0.05, 0), "paint", 1.0)


# ---------- мебель ----------

func _table(parent: Node, pos: Vector3, w: float, d: float, h: float, col := C_WOOD) -> void:
	var t := Node3D.new()
	U.add(parent, t, "Table", pos)
	var top := _sb(t, "Top", Vector3(w, 0.08, d), col, Vector3(0, h, 0), "wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_vb(t, "Leg", Vector3(0.08, h, 0.08), col.darkened(0.2), Vector3(sx * (w * 0.5 - 0.08), h * 0.5, sz * (d * 0.5 - 0.08)), "wood")


func _chair(parent: Node, pos: Vector3, yaw: float, col := C_WOOD) -> void:
	var c := Node3D.new()
	U.add(parent, c, "Chair", pos)
	c.rotation_degrees.y = yaw
	_sb(c, "Seat", Vector3(0.45, 0.06, 0.45), col, Vector3(0, 0.45, 0), "wood")
	_vb(c, "Back", Vector3(0.45, 0.5, 0.05), col, Vector3(0, 0.72, -0.2), "wood")
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_vb(c, "Leg", Vector3(0.05, 0.45, 0.05), col.darkened(0.2), Vector3(sx * 0.19, 0.225, sz * 0.19), "wood")


func _bed(parent: Node, pos: Vector3, yaw: float, col: Color) -> void:
	var b := Node3D.new()
	U.add(parent, b, "Bed", pos)
	b.rotation_degrees.y = yaw
	_sb(b, "Frame", Vector3(1.6, 0.4, 2.1), C_WOOD_D, Vector3(0, 0.2, 0), "wood")
	_vb(b, "Mattress", Vector3(1.5, 0.2, 2.0), Color(0.75, 0.72, 0.65), Vector3(0, 0.5, 0), "paint", 1.0)
	_vb(b, "Blanket", Vector3(1.5, 0.12, 1.3), col, Vector3(0, 0.62, 0.35), "paint", 1.0)
	_vb(b, "Pillow", Vector3(0.7, 0.14, 0.4), Color(0.85, 0.83, 0.78), Vector3(0, 0.65, -0.8), "paint", 1.0)
	_sb(b, "Headboard", Vector3(1.7, 1.1, 0.1), C_WOOD_D, Vector3(0, 0.75, -1.1), "wood")


func _wardrobe(parent: Node, pos: Vector3, yaw: float) -> void:
	var w := Node3D.new()
	U.add(parent, w, "Wardrobe", pos)
	w.rotation_degrees.y = yaw
	_sb(w, "Body", Vector3(1.4, 2.2, 0.6), C_WOOD, Vector3(0, 1.1, 0), "wood")
	for sg in [-1.0, 1.0]:
		_vb(w, "Door", Vector3(0.66, 2.0, 0.04), C_WOOD.lightened(0.08), Vector3(sg * 0.34, 1.1, 0.32), "wood")
		_vb(w, "Handle", Vector3(0.04, 0.2, 0.04), Color(0.7, 0.55, 0.2), Vector3(sg * 0.1, 1.1, 0.36), "metal", 0.4, 0.6)


func _bookshelf(parent: Node, pos: Vector3, yaw: float, w := 1.6) -> void:
	var s := Node3D.new()
	U.add(parent, s, "Bookshelf", pos)
	s.rotation_degrees.y = yaw
	_sb(s, "Frame", Vector3(w, 2.2, 0.35), C_WOOD_D, Vector3(0, 1.1, 0), "wood")
	for k in 5:
		var y := 0.35 + k * 0.4
		_vb(s, "Shelf", Vector3(w - 0.1, 0.04, 0.38), C_WOOD, Vector3(0, y, 0.01), "wood")
		var x := -w * 0.5 + 0.2
		while x < w * 0.5 - 0.2:
			var bw := rng.randf_range(0.05, 0.12)
			var bh := rng.randf_range(0.22, 0.34)
			_vb(s, "Book", Vector3(bw, bh, 0.24), Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.6), rng.randf_range(0.3, 0.55)), Vector3(x, y + 0.02 + bh * 0.5, 0.08), "paint", 0.9)
			x += bw + 0.01


func _sofa(parent: Node, pos: Vector3, yaw: float, col: Color) -> void:
	var s := Node3D.new()
	U.add(parent, s, "Sofa", pos)
	s.rotation_degrees.y = yaw
	_sb(s, "Seat", Vector3(2.2, 0.45, 0.9), col, Vector3(0, 0.22, 0), "paint", 1.0)
	_sb(s, "Back", Vector3(2.2, 0.6, 0.25), col.darkened(0.15), Vector3(0, 0.75, -0.35), "paint", 1.0)
	for sg in [-1.0, 1.0]:
		_sb(s, "Arm", Vector3(0.22, 0.6, 0.9), col.darkened(0.1), Vector3(sg * 1.1, 0.4, 0), "paint", 1.0)
	_vb(s, "Cushion", Vector3(0.9, 0.12, 0.7), col.lightened(0.08), Vector3(-0.5, 0.52, 0.05), "paint", 1.0)
	_vb(s, "Cushion2", Vector3(0.9, 0.12, 0.7), col.lightened(0.08), Vector3(0.5, 0.52, 0.05), "paint", 1.0)


func _painting(parent: Node, pos: Vector3, yaw: float, w := 0.9, h := 0.7) -> void:
	var p := Node3D.new()
	U.add(parent, p, "Painting", pos)
	p.rotation_degrees.y = yaw
	_vb(p, "Frame", Vector3(w + 0.1, h + 0.1, 0.05), Color(0.6, 0.45, 0.2), Vector3.ZERO, "wood")
	_vb(p, "Canvas", Vector3(w, h, 0.03), Color.from_hsv(rng.randf(), 0.35, 0.35), Vector3(0, 0, 0.02), "paint", 0.9)


func _rug(parent: Node, pos: Vector3, w: float, d: float, col: Color) -> void:
	_vb(parent, "Rug", Vector3(w, 0.02, d), col, pos + Vector3(0, 0.012, 0), "paint", 1.0)
	_vb(parent, "RugEdge", Vector3(w - 0.3, 0.025, d - 0.3), col.lightened(0.15), pos + Vector3(0, 0.014, 0), "paint", 1.0)


func _candle(parent: Node, pos: Vector3, energy := 0.9) -> Node3D:
	var c := Node3D.new()
	c.set_script(load("res://scripts/location/house/candle.gd"))
	c.set("base_energy", energy)
	U.add(parent, c, "Candle", pos)
	_cyl(c, "Dish", 0.1, 0.1, 0.02, Color(0.7, 0.6, 0.3), Vector3(0, 0.01, 0), "metal", 8)
	_cyl(c, "Wax", 0.035, 0.035, 0.2, Color(0.95, 0.9, 0.75), Vector3(0, 0.12, 0), "paint", 8)
	_glow(c, "Flame", 0.03, Color(1.0, 0.75, 0.3), Vector3(0, 0.26, 0), 3.0)
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.75, 0.45)
	li.light_energy = energy
	li.omni_range = 7.0
	li.omni_attenuation = 1.4
	U.add(c, li, "Light", Vector3(0, 0.35, 0))
	return c


func _barrel(parent: Node, pos: Vector3, col := Color(0.4, 0.28, 0.17)) -> void:
	var b := _cyl(parent, "Barrel", 0.34, 0.34, 0.9, col, pos + Vector3(0, 0.45, 0), "wood", 12, true)
	for k in 3:
		_cyl(b, "Band", 0.355, 0.355, 0.04, Color(0.2, 0.2, 0.2), Vector3(0, -0.3 + k * 0.3, 0), "metal", 12)


func _crate(parent: Node, pos: Vector3, s := 0.7, yaw := 0.0) -> void:
	var c := _sb(parent, "Crate", Vector3(s, s, s), Color(0.5, 0.36, 0.22), pos + Vector3(0, s * 0.5, 0), "wood")
	c.rotation_degrees.y = yaw


func _web(parent: Node, pos: Vector3, size: float, yaw: float, tilt := 0.0) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.9, 0.9, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(parent, mi, "Web", pos)
	mi.rotation_degrees = Vector3(tilt, yaw, 0)
	# нити по диагоналям
	for k in 3:
		var a := Vector3(-size * 0.5, 0, -size * 0.5 + k * size * 0.5)
		var b := Vector3(size * 0.5, 0, size * 0.5 - k * size * 0.5)
		U.rod(mi, "Thread", a, b, 0.006, Color(0.9, 0.9, 0.9), 1.0)


# ---------- ночь ----------

func _environment() -> void:
	U.environment(root_node, Color(0.04, 0.06, 0.14), Color(0.18, 0.2, 0.3), Color(0.55, 0.65, 0.9), Vector3(-38, 150, 0), 0.012, 0.32)
	var sun := root_node.get_node("Sun") as DirectionalLight3D
	sun.light_energy = 0.42
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	var env := (root_node.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_light_color = Color(0.16, 0.2, 0.28)
	env.glow_intensity = 0.8
	env.ambient_light_energy = 0.55
	# Луна: светящийся диск на небе
	var moon := SphereMesh.new()
	moon.radius = 14.0
	moon.height = 28.0
	var mi := MeshInstance3D.new()
	mi.mesh = moon
	mi.material_override = _emissive(Color(0.92, 0.94, 1.0), 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(root_node, mi, "Moon", Vector3(-110, 150, -280))
	U.clouds(root_node, rng, 22, Vector3(0.2, 0.4, -0.9))


func _director() -> void:
	var d := Node.new()
	d.set_script(load("res://scripts/location/house/haunt_director.gd"))
	U.add(root_node, d, "Haunt")
	var g := Node3D.new()
	g.set_script(load("res://scripts/location/house/ghost_sheet.gd"))
	U.add(root_node, g, "Ghost", Vector3(0, -50, 0))
	var white := Color(0.92, 0.94, 0.98, 0.78)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = white
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.emission_enabled = true
	gm.emission = Color(0.7, 0.8, 1.0)
	gm.emission_energy_multiplier = 0.5
	gm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var body := CylinderMesh.new()
	body.top_radius = 0.34
	body.bottom_radius = 0.62
	body.height = 1.1
	body.radial_segments = 14
	var bm := MeshInstance3D.new()
	bm.mesh = body
	bm.material_override = gm
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(g, bm, "Body", Vector3(0, -0.2, 0))
	var head := SphereMesh.new()
	head.radius = 0.36
	head.height = 0.72
	var hm := MeshInstance3D.new()
	hm.mesh = head
	hm.material_override = gm
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(g, hm, "Head", Vector3(0, 0.5, 0))
	# подол: волны
	for i in 8:
		var a := TAU * i / 8.0
		var s := SphereMesh.new()
		s.radius = 0.16
		s.height = 0.32
		var sm := MeshInstance3D.new()
		sm.mesh = s
		sm.material_override = gm
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.add(g, sm, "Hem%d" % i, Vector3(cos(a) * 0.58, -0.74, sin(a) * 0.58))
	for sg in [-1.0, 1.0]:
		var eye := U.sphere(g, "Eye", 0.07, Color(0.03, 0.03, 0.05), Vector3(sg * 0.13, 0.54, 0.31), 1.4)
		U.rod(g, "Arm", Vector3(sg * 0.3, 0.1, 0.0), Vector3(sg * 0.65, 0.35, 0.3), 0.09, white)
	U.sphere(g, "Mouth", 0.07, Color(0.03, 0.03, 0.05), Vector3(0, 0.38, 0.33), 1.2)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.7, 0.85, 1.0)
	gl.light_energy = 0.6
	gl.omni_range = 5.0
	U.add(g, gl, "Glow", Vector3(0, 0.3, 0))


# ---------- двор ----------

func _yard() -> void:
	var y := _holder("Yard")
	for r in _rect_minus([-300.0, 300.0, -300.0, 300.0], [[-12.3, 12.3, -8.3, 8.3]]):
		var sx: float = r[1] - r[0]
		var sz: float = r[3] - r[2]
		_sb(y, "Ground", Vector3(sx, 1.0, sz), Color(0.3, 0.38, 0.24), Vector3((r[0] + r[1]) * 0.5, -0.5, (r[2] + r[3]) * 0.5), "grass", 0.95)
	# Дорожка к двери и крыльцо
	_vb(y, "Path", Vector3(1.8, 0.04, 18.0), Color(0.45, 0.43, 0.4), Vector3(0, 0.02, 17.0), "concrete")
	for i in 14:
		_vb(y, "Stone%d" % i, Vector3(1.4, 0.05, 0.9), Color(0.5, 0.48, 0.44).darkened(rng.randf_range(0, 0.2)), Vector3(rng.randf_range(-0.2, 0.2), 0.03, 9.4 + i * 1.2), "concrete").rotation_degrees.y = rng.randf_range(-6, 6)
	_sb(y, "Porch", Vector3(5.0, 0.2, 2.6), Color(0.4, 0.3, 0.22), Vector3(0, 0.1, 9.35), "wood")
	for sx in [-2.3, 2.3]:
		_sb(y, "PorchPost", Vector3(0.2, 3.0, 0.2), Color(0.8, 0.78, 0.7), Vector3(sx, 1.6, 10.4), "wood")
	_vb(y, "PorchRoof", Vector3(5.6, 0.2, 3.0), Color(0.25, 0.22, 0.22), Vector3(0, 3.2, 9.5), "bitumen")
	_vb(y, "PorchRoofB", Vector3(5.6, 0.18, 3.2), Color(0.25, 0.22, 0.22), Vector3(0, 3.5, 9.5), "bitumen").rotation_degrees.x = 6.0
	for k in 3:
		_vb(y, "Step%d" % k, Vector3(2.0, 0.07, 0.35), Color(0.4, 0.3, 0.22), Vector3(0, 0.035 + k * 0.0, 10.9 + k * 0.35), "wood")
	# Забор вокруг двора с воротами
	for i in 28:
		var x := -24.0 + i * 1.8
		if absf(x) < 2.0:
			continue
		_fence_boards(y, Vector3(x, 0, 30.0), 0.0)
	for i in 30:
		var z := -22.0 + i * 1.8
		_fence_boards(y, Vector3(-24.0, 0, z), 90.0)
		_fence_boards(y, Vector3(24.0, 0, z), 90.0)
	for i in 28:
		_fence_boards(y, Vector3(-24.0 + i * 1.8, 0, -22.0), 0.0)
	# Ворота: столбы и покосившиеся створки
	for sx in [-2.0, 2.0]:
		_sb(y, "GatePost", Vector3(0.4, 2.4, 0.4), Color(0.5, 0.36, 0.28), Vector3(sx, 1.2, 30.0), "brick")
		_vb(y, "GateCap", Vector3(0.5, 0.15, 0.5), Color(0.6, 0.58, 0.54), Vector3(sx, 2.45, 30.0), "concrete")
	var lf := _vb(y, "GateLeaf", Vector3(1.4, 1.6, 0.06), Color(0.15, 0.15, 0.17), Vector3(-1.2, 1.0, 30.0), "metal", 0.5, 0.5)
	lf.rotation_degrees.y = 22.0
	for k in 7:
		_vb(lf, "Bar", Vector3(0.04, 1.6, 0.08), Color(0.15, 0.15, 0.17), Vector3(-0.6 + k * 0.2, 0, 0), "metal")
	# Кладбище-огородик, колодец, мёртвые деревья, фонарь, почтовый ящик
	for i in 6:
		var gp := Vector3(-18.0 + (i % 3) * 2.0, 0, -12.0 + (i / 3) * 3.0)
		_sb(y, "Grave%d" % i, Vector3(0.7, 1.0 + (i % 2) * 0.3, 0.14), Color(0.5, 0.5, 0.5), gp + Vector3(0, 0.5, 0), "concrete").rotation_degrees.y = rng.randf_range(-12, 12)
		_cyl(y, "GraveTop%d" % i, 0.35, 0.35, 0.14, Color(0.5, 0.5, 0.5), gp + Vector3(0, 1.0 + (i % 2) * 0.3, 0), "concrete", 10).rotation_degrees.x = 90.0
		_vb(y, "Mound%d" % i, Vector3(0.9, 0.2, 1.8), Color(0.28, 0.24, 0.18), gp + Vector3(0, 0.1, 1.1), "grass", 0.95)
	var well := _cyl(y, "Well", 0.9, 0.9, 0.9, Color(0.45, 0.42, 0.38), Vector3(14.0, 0.45, 18.0), "brick", 14, true)
	_cyl(y, "WellWater", 0.7, 0.7, 0.02, Color(0.05, 0.1, 0.12), Vector3(14.0, 0.82, 18.0), "paint", 14)
	for sx in [-0.8, 0.8]:
		_vb(y, "WellPost", Vector3(0.1, 1.8, 0.1), C_WOOD, Vector3(14.0 + sx, 1.8, 18.0), "wood")
	_vb(y, "WellRoof", Vector3(2.0, 0.1, 1.3), Color(0.25, 0.22, 0.22), Vector3(14.0, 2.7, 18.0), "bitumen")
	_dead_tree(y, Vector3(-15.0, 0, 16.0), 1.2)
	_dead_tree(y, Vector3(17.0, 0, 8.0), 1.0)
	_dead_tree(y, Vector3(-17.0, 0, -4.0), 1.4)
	var mb := _vb(y, "Mailbox", Vector3(0.4, 0.3, 0.6), Color(0.3, 0.3, 0.35), Vector3(3.2, 1.1, 27.0), "metal", 0.6, 0.3)
	_vb(y, "MailboxPost", Vector3(0.1, 1.0, 0.1), C_WOOD, Vector3(3.2, 0.5, 27.0), "wood")
	U.label(mb, "Num", "SIGN_HOUSE_13", Vector3(0, 0, 0.31), 0.25, Color(0.9, 0.85, 0.5))
	# Фонарь у дорожки (мерцает)
	var lp := Node3D.new()
	U.add(y, lp, "Lantern", Vector3(-2.6, 0, 20.0))
	_vb(lp, "Post", Vector3(0.1, 2.6, 0.1), Color(0.12, 0.14, 0.12), Vector3(0, 1.3, 0), "metal", 0.5, 0.5)
	_glow(lp, "Globe", 0.2, Color(1.0, 0.8, 0.45), Vector3(0, 2.7, 0), 3.0)
	var fl := OmniLight3D.new()
	fl.set_script(load("res://scripts/location/forest/flicker.gd"))
	fl.set("base_energy", 1.3)
	fl.light_color = Color(1.0, 0.78, 0.45)
	fl.omni_range = 14.0
	U.add(lp, fl, "Light", Vector3(0, 2.6, 0))
	# Лес за забором
	for i in 90:
		var a := rng.randf() * TAU
		var r := rng.randf_range(34.0, 110.0)
		var p := Vector3(cos(a) * r * 1.2, 0, sin(a) * r)
		if p.z > 26.0 and absf(p.x) < 6.0:
			continue
		var sp := Node3D.new()
		sp.set_script(load("res://scripts/location/forest/forest_prop.gd"))
		sp.set("species", ["spruce", "oak", "birch"][i % 3])
		U.add(y, sp, "Tree%d" % i, p)
		sp.scale = Vector3.ONE * rng.randf_range(0.9, 1.7)
		sp.rotation_degrees.y = rng.randf() * 360.0


func _fence_boards(parent: Node, pos: Vector3, yaw: float) -> void:
	var f := Node3D.new()
	U.add(parent, f, "Fence", pos)
	f.rotation_degrees.y = yaw
	var body := StaticBody3D.new()
	U.add(f, body, "Block", Vector3(0.9, 0.8, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(1.8, 1.6, 0.15))
	body.add_child(cs)
	_vb(f, "RailTop", Vector3(1.8, 0.07, 0.05), C_WOOD_D, Vector3(0.9, 1.15, -0.05), "wood")
	_vb(f, "RailLow", Vector3(1.8, 0.07, 0.05), C_WOOD_D, Vector3(0.9, 0.4, -0.05), "wood")
	for k in 5:
		if rng.randf() < 0.12:
			continue
		var h := rng.randf_range(1.3, 1.6)
		var b := _vb(f, "Board", Vector3(0.16, h, 0.04), Color(0.78, 0.76, 0.7).darkened(rng.randf_range(0, 0.35)), Vector3(0.18 + k * 0.36, h * 0.5, 0), "wood")
		b.rotation_degrees.z = rng.randf_range(-6, 6)


func _dead_tree(parent: Node, pos: Vector3, s: float) -> void:
	var t := Node3D.new()
	U.add(parent, t, "DeadTree", pos)
	var bark := Color(0.22, 0.17, 0.14)
	U.rod(t, "Trunk", Vector3(0, 0, 0), Vector3(0.2, 4.2 * s, -0.1), 0.38 * s, bark, 0.95)
	var tr := _sb(t, "TrunkBody", Vector3(0.5, 2.0, 0.5), bark, Vector3(0, 1.0, 0), "bark", 0.95)
	tr.visible = true
	var tips := [Vector3(-2.2, 6.0, 0.6), Vector3(2.0, 5.6, -0.8), Vector3(-0.8, 6.8, -1.6), Vector3(1.4, 7.0, 1.2), Vector3(-2.6, 4.6, -1.2)]
	for tp in tips:
		var tpv: Vector3 = tp * s
		U.rod(t, "Branch", Vector3(0.1, 3.4 * s, 0), tpv, 0.16 * s, bark, 0.95)
		U.rod(t, "Twig", tpv, tpv + Vector3(tpv.x * 0.2, 0.9, tpv.z * 0.3), 0.07 * s, bark, 0.95)
		U.rod(t, "Twig2", tpv * 0.8, tpv * 0.8 + Vector3(-tpv.z * 0.3, 0.7, tpv.x * 0.3), 0.06 * s, bark, 0.95)


# ---------- каркас дома ----------

func _shell() -> void:
	var s := _holder("Shell")
	# Подвальные стены (вне двора: камень)
	var cw := Color(0.28, 0.27, 0.26)
	_wall_x(s, "CellarN", -8.0, -12.15, -3.85, -3.5, 3.5, cw, [], false, 1.0, "concrete")
	_wall_x(s, "CellarS", 8.0, -12.15, -3.85, -3.5, 3.5, cw, [], false, 1.0, "concrete")
	_wall_z(s, "CellarW", -12.0, -8.15, 8.15, -3.5, 3.5, cw, [], false, 1.0, "concrete")
	_wall_z(s, "CellarE", -4.0, -8.15, 8.15, -3.5, 3.5, cw, [], false, 1.0, "concrete")
	_sb(s, "CellarFloor", Vector3(8.4, 0.4, 16.4), Color(0.25, 0.24, 0.23), Vector3(-8.0, -3.4, 0), "concrete")
	# Плита первого этажа: дыры под лестницу в подвал и гнилой участок
	var holes := [[-11.8, -10.0, -7.0, -0.3], [-8.0, -5.0, 0.5, 4.5]]
	_slab_area(s, "Floor1_", [-12.0, 12.0, -8.0, 8.0], holes, F1, 0.3, C_WOOD, "wood")
	# Плиты этажей: дыры под лестницы
	_slab_area(s, "Floor2_", [-12.0, 12.0, -8.0, 8.0], [[1.4, 3.4, 0.3, 6.8]], F2, 0.3, C_WOOD, "wood")
	_slab_area(s, "Floor3_", [-12.0, 12.0, -8.0, 8.0], [[-3.4, -1.4, 0.3, 6.8]], F3, 0.3, C_WOOD, "wood")
	# Наружные стены: первый этаж и второй, обшивка снаружи
	var win_g := [[-8.0, 1.4, 0.9, 2.3], [8.0, 1.4, 0.9, 2.3]]
	_wall_x(s, "S1", 8.0, -12.0, 12.0, F1, 2.9, C_PAPER_Y, win_g + [[0.0, 1.7, 0.0, 2.4]], true, 1.0)
	_wall_x(s, "N1", -8.0, -12.0, 12.0, F1, 2.9, C_PAPER_Y, [[-8.0, 1.4, 0.9, 2.3], [8.0, 1.4, 0.9, 2.3], [0.0, 1.4, 0.9, 2.3]], true, -1.0)
	_wall_z(s, "W1", -12.0, -8.0, 8.0, F1, 2.9, C_PAPER_G, [[-4.0, 1.4, 0.9, 2.3], [4.0, 1.4, 0.9, 2.3]], true, -1.0)
	_wall_z(s, "E1", 12.0, -8.0, 8.0, F1, 2.9, C_PAPER_Y, [[-4.0, 1.4, 0.9, 2.3], [4.0, 1.4, 0.9, 2.3]], true, 1.0)
	var win_u := [[-8.0, 1.4, F2 + 0.9, F2 + 2.3], [0.0, 1.4, F2 + 0.9, F2 + 2.3], [8.0, 1.4, F2 + 0.9, F2 + 2.3]]
	_wall_x(s, "S2", 8.0, -12.0, 12.0, F2, 2.9, C_PAPER_B, win_u, true, 1.0)
	_wall_x(s, "N2", -8.0, -12.0, 12.0, F2, 2.9, C_PAPER_B, [[-8.0, 1.4, F2 + 0.9, F2 + 2.3], [8.0, 1.4, F2 + 0.9, F2 + 2.3], [0.0, 1.8, F2, F2 + 2.4]], true, -1.0)
	_wall_z(s, "W2", -12.0, -8.0, 8.0, F2, 2.9, C_PAPER_B, [[-4.0, 1.4, F2 + 0.9, F2 + 2.3], [4.0, 1.4, F2 + 0.9, F2 + 2.3]], true, -1.0)
	_wall_z(s, "E2", 12.0, -8.0, 8.0, F2, 2.9, C_PAPER_P, [[-4.0, 1.4, F2 + 0.9, F2 + 2.3], [4.0, 1.4, F2 + 0.9, F2 + 2.3]], true, 1.0)
	# Окна: рамы со стёклами и шторами
	for o in [[8.0, -8.0], [-8.0, -8.0]]:
		_window(s, "x", 8.0, o[0], 0.9, 1.4, 1.4, -1.0)
	_window(s, "x", -8.0, -8.0, 0.9, 1.4, 1.4, 1.0)
	_window(s, "x", -8.0, 0.0, 0.9, 1.4, 1.4, 1.0)
	_window(s, "x", -8.0, 8.0, 0.9, 1.4, 1.4, 1.0)
	for z in [-4.0, 4.0]:
		_window(s, "z", -12.0, z, 0.9, 1.4, 1.4, 1.0)
		_window(s, "z", 12.0, z, 0.9, 1.4, 1.4, -1.0)
	for c in [-8.0, 0.0, 8.0]:
		_window(s, "x", 8.0, c, F2 + 0.9, 1.4, 1.4, -1.0)
	for c in [-8.0, 8.0]:
		_window(s, "x", -8.0, c, F2 + 0.9, 1.4, 1.4, 1.0)
	for z in [-4.0, 4.0]:
		_window(s, "z", -12.0, z, F2 + 0.9, 1.4, 1.4, 1.0)
		_window(s, "z", 12.0, z, F2 + 0.9, 1.4, 1.4, -1.0)
	# Внутренние стены этажей с дверными проёмами
	var doors1 := [[-3.0, 1.4, F1, 2.3], [3.0, 1.4, F1, 2.3]]
	_wall_z(s, "I1W", -4.0, -8.0, 8.0, F1, 2.9, C_PAPER_R, doors1)
	_wall_z(s, "I1E", 4.0, -8.0, 8.0, F1, 2.9, C_PAPER_R, doors1)
	var doors2 := [[-3.0, 1.4, F2, F2 + 2.3], [3.0, 1.4, F2, F2 + 2.3]]
	_wall_z(s, "I2W", -4.0, -8.0, 8.0, F2, 2.9, C_PAPER_P, doors2)
	_wall_z(s, "I2E", 4.0, -8.0, 8.0, F2, 2.9, C_PAPER_P, doors2)
	# Дверная плита входа (приоткрыта) и табличка «13»
	var door := _vb(s, "FrontDoor", Vector3(0.9, 2.3, 0.08), Color(0.35, 0.18, 0.12), Vector3(-1.1, 1.15, 8.7), "wood")
	door.rotation_degrees.y = 70.0
	var plate := _vb(s, "Plate", Vector3(0.25, 0.25, 0.03), Color(0.7, 0.55, 0.2), Vector3(0.0, 2.7, 8.2), "metal", 0.4, 0.6)
	U.label(plate, "Num", "SIGN_HOUSE_13", Vector3(0, 0, 0.02), 0.2, Color(0.1, 0.07, 0.03))
	# Плинтусы и карнизы внутри: по периметру этажей
	for lvl in [F1, F2]:
		for side in [-1.0, 1.0]:
			_vb(s, "BaseboardZ", Vector3(24.0, 0.15, 0.04), C_WOOD_D, Vector3(0, lvl + 0.08, side * 7.82), "wood")
			_vb(s, "CrownZ", Vector3(24.0, 0.12, 0.05), C_WOOD_D, Vector3(0, lvl + 2.82, side * 7.82), "wood")
			_vb(s, "BaseboardX", Vector3(0.04, 0.15, 16.0), C_WOOD_D, Vector3(side * 11.82, lvl + 0.08, 0), "wood")


# ---------- лестницы ----------

func _stairs() -> void:
	var s := _holder("Stairs")
	_slab(s, "StairsUp", Vector3(2.4, F1, 6.5), Vector3(2.4, F2, 0.1), 1.8, Color(0.42, 0.3, 0.2))
	_slab(s, "StairsAttic", Vector3(-2.4, F2, 6.5), Vector3(-2.4, F3, 0.1), 1.8, Color(0.42, 0.3, 0.2))
	_slab(s, "StairsCellar", Vector3(-10.9, -3.2, -7.0), Vector3(-10.9, 0.0, -0.5), 1.6, Color(0.36, 0.28, 0.2))
	# Перила вдоль проёмов (визуал)
	for sx in [1.4, 3.4]:
		_vb(s, "HoleRail1", Vector3(0.05, 0.9, 6.3), C_WOOD_D, Vector3(sx, F2 + 0.45, 3.55), "wood")
	for sx in [-3.4, -1.4]:
		_vb(s, "HoleRail2", Vector3(0.05, 0.9, 6.3), C_WOOD_D, Vector3(sx, F3 + 0.45, 3.55), "wood")


# ---------- первый этаж ----------

func _ground_floor() -> void:
	var g := _holder("Ground1")
	# Гнилой участок гостиной: проваливающиеся доски 1×1, 3×4
	for ix in 3:
		for iz in 4:
			var fp := StaticBody3D.new()
			fp.set_script(load("res://scripts/falling_platform.gd"))
			fp.set("delay", 0.5)
			fp.set("respawn", 4.0)
			U.add(g, fp, "Rotten%d_%d" % [ix, iz], Vector3(-7.5 + ix, -0.15, 1.0 + iz))
			var cs := CollisionShape3D.new()
			cs.name = "Shape"
			cs.shape = _bshape(Vector3(0.98, 0.3, 0.98))
			fp.add_child(cs)
			_vb(fp, "Mesh", Vector3(0.98, 0.3, 0.98), Color(0.3, 0.2, 0.12).darkened(rng.randf_range(0.0, 0.3)), Vector3.ZERO, "wood")
			var sensor := Area3D.new()
			sensor.name = "Sensor"
			sensor.collision_layer = 0
			sensor.collision_mask = 1
			var ss := CollisionShape3D.new()
			ss.shape = _bshape(Vector3(0.9, 0.4, 0.9))
			sensor.add_child(ss)
			U.add(fp, sensor, "Sensor", Vector3(0, 0.3, 0))
	# Ковёр, гостиная (x -12..-4)
	_rug(g, Vector3(-8.5, 0, -2.5), 4.0, 3.0, Color(0.5, 0.2, 0.2))
	_sofa(g, Vector3(-8.5, 0, 6.8), 180.0, Color(0.35, 0.18, 0.22))
	_table(g, Vector3(-8.5, 0, 5.6), 1.2, 0.6, 0.4)
	_candle(g, Vector3(-8.5, 0.46, 5.6))
	# Камин на западной стене
	var fp2 := Node3D.new()
	U.add(g, fp2, "Fireplace", Vector3(-11.5, 0, 4.0))
	_sb(fp2, "Breast", Vector3(0.7, 3.0, 2.6), Color(0.5, 0.35, 0.3), Vector3(0, 1.5, 0), "brick")
	_vb(fp2, "Opening", Vector3(0.1, 1.0, 1.4), Color(0.05, 0.03, 0.02), Vector3(0.38, 0.6, 0), "paint")
	_vb(fp2, "Mantel", Vector3(0.9, 0.12, 2.8), C_WOOD, Vector3(0.1, 1.5, 0), "wood")
	_candle(g, Vector3(-11.1, 1.62, 3.5))
	_candle(g, Vector3(-11.1, 1.62, 4.6))
	_painting(g, Vector3(-11.8, 2.1, -4.0), 90.0)
	_bookshelf(g, Vector3(-6.5, 0, -7.65), 0.0)
	_bookshelf(g, Vector3(-9.0, 0, -7.65), 0.0)
	_painting(g, Vector3(-8.0, 1.9, 7.8), 180.0, 1.2, 0.8)
	# Пианино
	var pn := Node3D.new()
	U.add(g, pn, "Piano", Vector3(-4.7, 0, -4.0))
	pn.rotation_degrees.y = 90.0
	_sb(pn, "Body", Vector3(1.6, 1.2, 0.6), Color(0.1, 0.07, 0.06), Vector3(0, 0.6, 0), "wood")
	_vb(pn, "Keys", Vector3(1.4, 0.05, 0.2), Color(0.9, 0.88, 0.8), Vector3(0, 0.82, 0.32), "paint")
	_chair(g, Vector3(-3.8, 0, -4.0), 90.0)
	# Зал: часы, консоль, ковровая дорожка
	_rug(g, Vector3(0, 0, 1.0), 2.0, 12.0, Color(0.45, 0.22, 0.2))
	var gc := Node3D.new()
	U.add(g, gc, "Clock", Vector3(-3.4, 0, -7.4))
	_sb(gc, "Case", Vector3(0.6, 2.2, 0.4), C_WOOD_D, Vector3(0, 1.1, 0), "wood")
	_vb(gc, "Face", Vector3(0.4, 0.4, 0.03), Color(0.9, 0.88, 0.75), Vector3(0, 1.8, 0.22), "paint")
	_vb(gc, "Pendulum", Vector3(0.04, 0.5, 0.03), Color(0.7, 0.55, 0.2), Vector3(0, 1.0, 0.2), "metal", 0.4, 0.6)
	_table(g, Vector3(-3.5, 0, 6.0), 0.4, 1.2, 0.8)
	_candle(g, Vector3(-3.5, 0.9, 6.0))
	_painting(g, Vector3(0, 2.0, -7.8), 0.0, 1.0, 1.2)
	# Кухня (x 4..12)
	_table(g, Vector3(8.0, 0, 1.0), 1.8, 1.0, 0.75)
	for sx in [-0.7, 0.7]:
		_chair(g, Vector3(8.0 + sx, 0, 0.1), 0.0)
		_chair(g, Vector3(8.0 + sx, 0, 1.9), 180.0)
	_candle(g, Vector3(8.0, 0.84, 1.0))
	_sb(g, "Counter", Vector3(6.0, 0.9, 0.7), Color(0.55, 0.5, 0.4), Vector3(8.0, 0.45, -7.5), "wood")
	_vb(g, "CounterTop", Vector3(6.1, 0.06, 0.8), Color(0.3, 0.3, 0.3), Vector3(8.0, 0.93, -7.5), "concrete")
	_sb(g, "Stove", Vector3(0.8, 0.9, 0.7), Color(0.85, 0.83, 0.8), Vector3(5.4, 0.45, -7.5), "metal", 0.5, 0.2)
	for k in 4:
		_cyl(g, "Burner%d" % k, 0.12, 0.12, 0.02, Color(0.1, 0.1, 0.1), Vector3(5.2 + (k % 2) * 0.35, 0.93, -7.6 + (k / 2) * 0.3), "metal", 10)
	_sb(g, "Fridge", Vector3(0.9, 1.9, 0.8), Color(0.8, 0.82, 0.78), Vector3(11.2, 0.95, -7.4), "metal", 0.5, 0.2)
	_vb(g, "FridgeHandle", Vector3(0.04, 0.5, 0.04), Color(0.4, 0.4, 0.4), Vector3(10.78, 1.2, -6.98), "metal")
	_vb(g, "Sink", Vector3(0.8, 0.06, 0.5), Color(0.6, 0.62, 0.6), Vector3(9.5, 0.96, -7.5), "metal", 0.4, 0.5)
	for k in 5:
		_vb(g, "Shelf%d" % k, Vector3(2.6, 0.04, 0.3), C_WOOD, Vector3(6.0 + (k % 2) * 4.0, 1.6 + (k / 2) * 0.5, -7.82), "wood")
	for k in 12:
		_cyl(g, "Jar%d" % k, 0.07, 0.07, 0.2, Color.from_hsv(rng.randf(), 0.4, 0.6, 0.8), Vector3(rng.randf_range(4.8, 7.2) + (k % 2) * 3.0, 1.72 + (k / 6) * 0.5, -7.8), "paint", 8)
	for k in 5:
		_cyl(g, "Pan%d" % k, 0.14, 0.14, 0.03, Color(0.15, 0.15, 0.15), Vector3(6.5 + k * 0.4, 2.2, -7.78), "metal", 10).rotation_degrees.x = 90.0
	_candle(g, Vector3(10.2, 0.99, -7.5))
	_painting(g, Vector3(11.8, 2.0, 1.0), -90.0)
	_barrel(g, Vector3(11.4, 0, 6.8))
	_crate(g, Vector3(10.4, 0, 6.9), 0.7, 12.0)
	_sofa(g, Vector3(8.0, 0, 6.8), 180.0, Color(0.3, 0.38, 0.28))
	for p in [Vector3(-8.0, 1.2, 0.0), Vector3(0.0, 1.2, 0.0), Vector3(8.0, 1.2, -1.0)]:
		var rl := OmniLight3D.new()
		rl.light_color = Color(0.6, 0.7, 1.0)
		rl.light_energy = 0.55
		rl.omni_range = 9.0
		U.add(g, rl, "RoomGlow", p + Vector3(0, 1.0, 0))


# ---------- второй этаж ----------

func _upper_floor() -> void:
	var u := _holder("Upper")
	var y := F2
	_rug(u, Vector3(0, y, -3.0), 2.4, 8.0, Color(0.3, 0.3, 0.5))
	# Западная спальня
	_bed(u, Vector3(-9.5, y, -5.5), 0.0, Color(0.35, 0.45, 0.65))
	_wardrobe(u, Vector3(-6.0, y, -7.5), 0.0)
	_table(u, Vector3(-11.4, y, 3.0), 0.7, 1.4, 0.75)
	_chair(u, Vector3(-10.6, y, 3.0), 90.0)
	_candle(u, Vector3(-11.4, y + 0.84, 3.0))
	_rug(u, Vector3(-8.0, y, 0.0), 3.5, 2.5, Color(0.5, 0.35, 0.3))
	_painting(u, Vector3(-11.8, y + 2.0, -2.0), 90.0)
	_bookshelf(u, Vector3(-4.35, y, -5.5), 90.0, 1.2)
	# Восточная спальня: детская
	_bed(u, Vector3(9.0, y, -5.5), 0.0, Color(0.7, 0.45, 0.55))
	_wardrobe(u, Vector3(6.0, y, -7.5), 0.0)
	_sb(u, "ToyBox", Vector3(0.9, 0.5, 0.5), Color(0.8, 0.45, 0.2), Vector3(11.2, y + 0.25, 1.5), "wood")
	for k in 4:
		_cyl(u, "Block%d" % k, 0.1, 0.1, 0.18, Color.from_hsv(rng.randf(), 0.6, 0.7), Vector3(9.0 + rng.randf_range(-1, 1), y + 0.09, 1.5 + rng.randf_range(-1, 1)), "paint", 6)
	_sb(u, "RockingHorseBody", Vector3(0.9, 0.5, 0.3), Color(0.6, 0.4, 0.25), Vector3(8.0, y + 0.55, 3.5), "wood")
	_vb(u, "RockerA", Vector3(1.2, 0.05, 0.05), C_WOOD_D, Vector3(8.0, y + 0.1, 3.4), "wood")
	_vb(u, "RockerB", Vector3(1.2, 0.05, 0.05), C_WOOD_D, Vector3(8.0, y + 0.1, 3.6), "wood")
	_rug(u, Vector3(8.0, y, 0.5), 3.0, 3.0, Color(0.4, 0.5, 0.4))
	_candle(u, Vector3(11.2, y + 0.56, 1.5))
	_candle(u, Vector3(9.0, y + 0.8, -6.7))
	_painting(u, Vector3(11.8, y + 2.0, -2.0), -90.0)
	# Зал второго этажа: портреты, подсвечники, часы
	for k in 3:
		_painting(u, Vector3(-3.8, y + 1.9, -5.0 + k * 3.0), 90.0, 0.6, 0.8)
	_candle(u, Vector3(-3.5, y + 1.0, 5.0))
	_table(u, Vector3(3.6, y, -2.5), 0.4, 1.0, 0.8)
	_candle(u, Vector3(3.6, y + 0.9, -2.5))
	for p in [Vector3(-8.0, 1.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(8.0, 1.0, 0.0)]:
		var rl := OmniLight3D.new()
		rl.light_color = Color(0.6, 0.7, 1.0)
		rl.light_energy = 0.5
		rl.omni_range = 9.0
		U.add(u, rl, "RoomGlow", p + Vector3(0, y + 1.0, 0))


# ---------- чердак ----------

func _attic() -> void:
	var a := _holder("Attic")
	var y := F3
	# Низкие стенки под скатом и торцы
	_wall_x(a, "AtticS", 8.0, -12.0, 12.0, y, 1.3, C_WOOD, [], true, 1.0, "wood")
	_wall_x(a, "AtticN", -8.0, -12.0, 12.0, y, 1.3, C_WOOD, [], true, -1.0, "wood")
	_wall_z(a, "AtticW", -12.0, -8.0, 8.0, y, 3.6, C_WOOD, [[0.0, 1.4, y + 1.6, y + 2.8]], true, -1.0, "wood")
	_wall_z(a, "AtticE", 12.0, -8.0, 8.0, y, 3.6, C_WOOD, [[0.0, 1.4, y + 1.6, y + 2.8]], true, 1.0, "wood")
	_window(a, "z", -12.0, 0.0, y + 1.6, 1.4, 1.2, 1.0)
	_window(a, "z", 12.0, 0.0, y + 1.6, 1.4, 1.2, -1.0)
	# Балки
	for k in 9:
		var x := -10.0 + k * 2.5
		_vb(a, "Rafter%d" % k, Vector3(0.18, 0.18, 17.0), C_WOOD_D, Vector3(x, y + 3.0, 0), "wood")
	_vb(a, "Ridge", Vector3(25.0, 0.3, 0.3), C_WOOD_D, Vector3(0, y + 4.1, 0), "wood")
	# Барахло: сундуки, ящики, манекен, коляска, ёлочные игрушки
	for k in 6:
		var p := Vector3(rng.randf_range(-10.5, 10.5), y, rng.randf_range(-7.0, 7.0))
		if absf(p.x + 2.4) < 2.2 and p.z > -0.5:
			continue
		if p.x > 6.0 and p.z < -3.0:
			continue
		_crate(a, p, rng.randf_range(0.5, 1.0), rng.randf() * 90.0)
	for k in 3:
		var tp := Vector3(-9.0 + k * 3.0, y, -6.6)
		_sb(a, "Trunk%d" % k, Vector3(1.1, 0.6, 0.6), C_WOOD, tp + Vector3(0, 0.3, 0), "wood")
		_vb(a, "TrunkLid%d" % k, Vector3(1.15, 0.12, 0.65), C_WOOD_D, tp + Vector3(0, 0.66, 0), "wood")
		_vb(a, "Lock%d" % k, Vector3(0.1, 0.1, 0.03), Color(0.7, 0.55, 0.2), tp + Vector3(0, 0.5, 0.32), "metal", 0.4, 0.6)
	var mq := Node3D.new()
	U.add(a, mq, "Mannequin", Vector3(5.0, y, 4.5))
	U.cyl(mq, "Stand", 0.03, 0.03, 1.5, C_WOOD_D, Vector3(0, 0.75, 0), 8)
	U.sphere(mq, "Torso", 0.3, Color(0.6, 0.55, 0.45), Vector3(0, 1.4, 0), 1.4)
	U.sphere(mq, "Head", 0.14, Color(0.7, 0.65, 0.55), Vector3(0, 1.9, 0))
	# Колыбель и качалка
	_sb(a, "Crib", Vector3(1.0, 0.4, 0.6), C_WOOD, Vector3(-6.0, y + 0.2, 5.5), "wood")
	for sg in [-1.0, 1.0]:
		_vb(a, "CribRail", Vector3(1.0, 0.3, 0.04), C_WOOD_D, Vector3(-6.0, y + 0.55, 5.5 + sg * 0.28), "wood")
	# Гнездо кота (простая)
	var nest := _holder("NestAttic", Vector3(8.5, y, -5.5))
	_sb(nest, "Trunk", Vector3(1.2, 0.5, 0.7), C_WOOD, Vector3(0, 0.25, 0), "wood")
	_vb(nest, "Blanket", Vector3(0.9, 0.08, 0.5), Color(0.6, 0.35, 0.4), Vector3(0, 0.54, 0), "paint", 1.0)
	_candle(nest, Vector3(0.8, 0.0, 0.8))
	# Свечи и паутина
	_candle(a, Vector3(-9.0, y + 0.66, -6.6))
	_candle(a, Vector3(0.0, y + 0.0, -6.6))
	_candle(a, Vector3(6.0, y, 6.0))
	var rl := OmniLight3D.new()
	rl.light_color = Color(0.6, 0.7, 1.0)
	rl.light_energy = 0.55
	rl.omni_range = 12.0
	U.add(a, rl, "RoomGlow", Vector3(0, y + 2.5, 0))
	for k in 6:
		_web(a, Vector3(rng.randf_range(-11, 11), y + 3.0, rng.randf_range(-7, 7)), 1.6, rng.randf() * 360.0, rng.randf_range(-25, 25))


# ---------- подвал ----------

func _cellar() -> void:
	var c := _holder("Cellar")
	var y := -3.2
	# Каменные полки с банками на северной и западной стенах, бочки и ящики; кот спрятан за стеллажом
	for k in 3:
		var sx := -11.2 + k * 2.4
		_sb(c, "RackFrame%d" % k, Vector3(2.0, 2.2, 0.4), C_WOOD_D, Vector3(sx + 1.0, y + 1.1, -7.6), "wood")
		for r in 4:
			_vb(c, "RackShelf", Vector3(1.9, 0.04, 0.42), C_WOOD, Vector3(sx + 1.0, y + 0.3 + r * 0.5, -7.58), "wood")
			for j in 6:
				_cyl(c, "Jar", 0.07, 0.07, 0.2, Color.from_hsv(rng.randf(), 0.5, 0.55, 0.9), Vector3(sx + 0.2 + j * 0.3, y + 0.43 + r * 0.5, -7.5), "paint", 8)
	_sb(c, "WineRack", Vector3(0.5, 1.8, 3.0), C_WOOD_D, Vector3(-11.6, y + 0.9, 3.0), "wood")
	for r in 3:
		for j in 5:
			_cyl(c, "Bottle", 0.06, 0.06, 0.3, Color(0.1, 0.25, 0.15, 0.9), Vector3(-11.3, y + 0.3 + r * 0.5, 1.8 + j * 0.6), "paint", 8).rotation_degrees.z = 90.0
	for k in 7:
		_barrel(c, Vector3(rng.randf_range(-10.0, -5.0), y, rng.randf_range(-1.0, 7.0)))
	for k in 6:
		_crate(c, Vector3(rng.randf_range(-10.5, -4.8), y, rng.randf_range(-6.5, -3.0)), rng.randf_range(0.5, 0.9), rng.randf() * 90.0)
	# Угольная куча
	for k in 12:
		U.sphere(c, "Coal%d" % k, rng.randf_range(0.25, 0.5), Color(0.06, 0.06, 0.07), Vector3(-5.0 + rng.randf_range(-0.8, 0.8), y + 0.1, 6.5 + rng.randf_range(-0.8, 0.8)), 0.6)
	# Опорные столбы
	for sx in [-8.0, -5.0]:
		_sb(c, "Pillar", Vector3(0.4, 3.2, 0.4), C_WOOD_D, Vector3(sx, y + 1.6, -4.0), "wood")
	# Гнездо кота за стеллажом (простая средняя): в углу у северо-восточной стены
	var nest := _holder("NestCellar", Vector3(-5.0, y, -6.6))
	_vb(nest, "Blanket", Vector3(0.9, 0.08, 0.6), Color(0.4, 0.5, 0.35), Vector3(0, 0.05, 0), "paint", 1.0)
	_sb(nest, "Crate", Vector3(0.7, 0.7, 0.7), Color(0.5, 0.36, 0.22), Vector3(0.9, 0.35, 0.0), "wood")
	_candle(nest, Vector3(0.9, 0.7, 0.0), 0.7)
	_candle(c, Vector3(-10.0, y + 0.0, 1.0), 0.7)
	_candle(c, Vector3(-7.0, y + 0.0, -2.0), 0.7)
	for p in [Vector3(-8.0, y + 1.8, 0.0)]:
		var rl := OmniLight3D.new()
		rl.light_color = Color(0.6, 0.7, 1.0)
		rl.light_energy = 0.5
		rl.omni_range = 11.0
		U.add(c, rl, "RoomGlow", p)
	for k in 4:
		_web(c, Vector3(-4.3, y + 2.6 - k * 0.5, -7.5 + k * 3.5), 1.4, 90.0, 0.0)
	_web(c, Vector3(-11.7, y + 2.8, -7.7), 1.4, 0.0, 0.0)


# ---------- тайная комната ----------

func _secret() -> void:
	var s := _holder("Secret")
	var y := F2
	# Шкаф-дверь: AnimatableBody в проёме северной стены
	var door := AnimatableBody3D.new()
	door.set_script(load("res://scripts/location/house/secret_door.gd"))
	door.set("offset", Vector3(2.2, 0, 0))
	U.add(s, door, "BookcaseDoor", Vector3(0, y + 1.25, -7.85))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(2.0, 2.5, 0.4))
	door.add_child(cs)
	_vb(door, "Body", Vector3(2.0, 2.5, 0.4), C_WOOD_D, Vector3.ZERO, "wood")
	for r in 5:
		_vb(door, "Shelf", Vector3(1.9, 0.04, 0.42), C_WOOD, Vector3(0, -1.1 + r * 0.5, 0.02), "wood")
		for j in 6:
			var bh := rng.randf_range(0.2, 0.34)
			_vb(door, "Book", Vector3(rng.randf_range(0.06, 0.1), bh, 0.24), Color.from_hsv(rng.randf(), 0.4, 0.45), Vector3(-0.8 + j * 0.3, -1.08 + r * 0.5 + bh * 0.5, 0.1), "paint", 0.9)
	# Подсвечник-переключатель на стене зала
	var sw := U.trigger(s, "Sconce", "SECRET_SCONCE", Vector3(-2.6, y + 1.5, -7.5), 1.7)
	sw.add_to_group("secret_switch", true)
	_vb(sw, "Arm", Vector3(0.05, 0.05, 0.3), Color(0.7, 0.55, 0.2), Vector3(0, -0.15, 0.1), "metal", 0.4, 0.6)
	var cdl := _candle(sw, Vector3(0, -0.12, 0.25), 0.6)
	# Сама комната-пристройка: z -11.4..-8, x -2.2..2.2
	_slab_area(s, "AnnexFloor", [-2.4, 2.4, -11.6, -7.9], [], y, 0.3, C_WOOD, "wood")
	_wall_x(s, "AnnexN", -11.5, -2.4, 2.4, y, 2.9, C_PAPER_P, [], true, -1.0)
	_wall_z(s, "AnnexW", -2.3, -11.6, -8.0, y, 2.9, C_PAPER_P, [], true, -1.0)
	_wall_z(s, "AnnexE", 2.3, -11.6, -8.0, y, 2.9, C_PAPER_P, [], true, 1.0)
	_slab_area(s, "AnnexCeil", [-2.5, 2.5, -11.7, -7.9], [], y + 3.2, 0.3, C_WOOD, "wood")
	for sx in [-2.2, 2.2]:
		_sb(s, "AnnexColumn", Vector3(0.3, y, 0.3), C_WOOD_D, Vector3(sx, y * 0.5, -11.4), "wood")
	_window(s, "x", -11.5, 0.0, y + 1.0, 1.0, 1.0, 1.0)
	# Внутри: детская кроватка, игрушки, лампа, письмо
	_sb(s, "AnnexBed", Vector3(1.0, 0.4, 1.8), C_WOOD, Vector3(-1.2, y + 0.2, -10.2), "wood")
	_vb(s, "AnnexBlanket", Vector3(0.9, 0.12, 1.5), Color(0.55, 0.35, 0.5), Vector3(-1.2, y + 0.45, -10.0), "paint", 1.0)
	_rug(s, Vector3(0.6, y, -9.8), 1.8, 1.6, Color(0.35, 0.45, 0.4))
	_candle(s, Vector3(0.0, y + 0.0, -10.6), 0.7)
	for k in 5:
		U.sphere(s, "Toy%d" % k, 0.1, Color.from_hsv(rng.randf(), 0.6, 0.8), Vector3(rng.randf_range(0, 1.6), y + 0.1, rng.randf_range(-10.8, -9.0)))
	var nest := _holder("NestSecret", Vector3(0.6, y + 0.02, -10.2))
	_vb(nest, "Pillow", Vector3(0.7, 0.1, 0.5), Color(0.8, 0.5, 0.45), Vector3.ZERO, "paint", 1.0)
	_web(s, Vector3(2.0, y + 2.8, -11.2), 1.2, 0.0, 45.0)


# ---------- крыша и дымоход ----------

func _roof() -> void:
	var r := _holder("Roof")
	var th := 0.3
	var run := 8.9
	var rise := 3.3
	var ang := rad_to_deg(atan2(rise, run))
	var length := sqrt(run * run + rise * rise) + 0.4
	var col := Color(0.22, 0.2, 0.22)
	for sg in [-1.0, 1.0]:
		var rb := _sb(r, "RoofSlope", Vector3(25.5, th, length), col, Vector3(0, F3 + 1.3 + rise * 0.5 + 0.9, sg * run * 0.5), "bitumen", 0.95)
		rb.rotation_degrees.x = sg * ang
		for k in 14:
			_vb(rb, "Shingle%d" % k, Vector3(25.5, 0.03, 0.08), Color(0.15, 0.13, 0.15), Vector3(0, th * 0.5 + 0.02, -length * 0.5 + 0.4 + k * (length / 14.0)), "bitumen")
	# Фронтоны
	for sx in [-12.0, 12.0]:
		var gm := MeshInstance3D.new()
		gm.mesh = U.gable(17.4, 3.1, 0.3, C_SIDING)
		gm.material_override = U.mat(C_SIDING, 0.95)
		U.add(r, gm, "Gable", Vector3(sx, F3 + 1.3 + 1.55 - 0.3, 0))
		gm.rotation_degrees.y = 90.0
	# Дымоход
	_sb(r, "Chimney", Vector3(1.6, 7.0, 1.6), Color(0.5, 0.33, 0.28), Vector3(-7.0, F3 + 3.8, -4.0), "brick")
	_vb(r, "ChimneyCap", Vector3(1.9, 0.2, 1.9), Color(0.4, 0.38, 0.35), Vector3(-7.0, F3 + 7.4, -4.0), "concrete")
	# Флюгер
	U.rod(r, "VaneRod", Vector3(10.0, F3 + 4.9, 0), Vector3(10.0, F3 + 6.5, 0), 0.04, C_STEEL, 0.5, 0.5)
	_vb(r, "VaneArrow", Vector3(1.0, 0.1, 0.05), Color(0.2, 0.2, 0.22), Vector3(10.0, F3 + 6.4, 0), "metal").rotation_degrees.y = 40.0
	# Карниз-водосток
	for sg in [-1.0, 1.0]:
		_vb(r, "Gutter", Vector3(25.5, 0.1, 0.15), Color(0.3, 0.32, 0.3), Vector3(0, F3 + 1.4, sg * 8.95), "metal", 0.6, 0.3)


# ---------- скрипучие половицы ----------

func _creak(parent: Node, nm: String, pos: Vector3, tier: int) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/location/house/creak_board.gd"))
	U.add(parent, a, nm, pos + Vector3(0, 0.4, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(1.6, 0.8, 0.6))
	a.add_child(cs)
	_vb(a, "Mesh", Vector3(1.5, 0.02, 0.5), Color(0.55, 0.4, 0.28), Vector3(0, -0.39, 0), "wood")
	_vb(a, "Nail1", Vector3(0.05, 0.03, 0.05), Color(0.8, 0.7, 0.3), Vector3(-0.6, -0.38, 0), "metal", 0.4, 0.6)
	_vb(a, "Nail2", Vector3(0.05, 0.03, 0.05), Color(0.8, 0.7, 0.3), Vector3(0.6, -0.38, 0), "metal", 0.4, 0.6)
	if tier > 0:
		_hazard(a, tier)


func _creaks() -> void:
	var c := _holder("Creaks")
	_creak(c, "C1", Vector3(0.0, F1, 5.5), 0)
	_creak(c, "C2", Vector3(-1.5, F1, -1.0), 0)
	_creak(c, "C3", Vector3(8.0, F1, 4.5), 0)
	_creak(c, "C4", Vector3(-8.0, F1, -4.5), 0)
	_creak(c, "C5", Vector3(0.0, F2, -4.0), 0)
	_creak(c, "C6", Vector3(-1.0, F2, 3.0), 0)
	_creak(c, "C7", Vector3(-8.0, F2, 1.0), 0)
	_creak(c, "C8", Vector3(8.0, F2, -2.5), 0)
	_creak(c, "C9", Vector3(0.0, F3, -2.0), 0)
	_creak(c, "C10", Vector3(5.0, F3, 2.0), 0)
	_creak(c, "C11", Vector3(-6.0, F3, -3.0), 0)
	_creak(c, "C12", Vector3(7.0, F3, -5.0), 0)
	# На средней и сложной: больше половиц на проходах
	_creak(c, "T1a", Vector3(0.0, F1, 2.5), 1)
	_creak(c, "T1b", Vector3(-6.0, F1, 6.0), 1)
	_creak(c, "T1c", Vector3(7.0, F1, -3.5), 1)
	_creak(c, "T1d", Vector3(0.0, F2, 0.0), 1)
	_creak(c, "T1e", Vector3(8.0, F2, 1.0), 1)
	_creak(c, "T2a", Vector3(-1.0, F3, 4.0), 2)
	_creak(c, "T2b", Vector3(-9.0, F2, -4.0), 2)
	_creak(c, "T2c", Vector3(0.0, F2, -6.5), 2)
	# Камни у калитки: «квакающие» доски у порога
	_creak(c, "Porch", Vector3(0.0, 0.2, 9.4), 0)


func _draught(parent: Node, nm: String, pos: Vector3, radius: float) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/location/house/draught.gd"))
	a.set("radius", radius)
	U.add(parent, a, nm, pos)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(1.0, 1.0, 1.0))
	a.add_child(cs)
	_hazard(a, 1)


func _draughts() -> void:
	var d := _holder("Draughts")
	_draught(d, "D1", Vector3(-11.0, 1.4, 4.0), 9.0)
	_draught(d, "D2", Vector3(11.0, F2 + 1.4, -4.0), 9.0)
	_draught(d, "D3", Vector3(0.0, F3 + 2.2, 0.0), 14.0)
	_draught(d, "D4", Vector3(8.0, 1.4, -7.0), 7.0)


func _cobweb(parent: Node, nm: String, pos: Vector3, tier: int) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/location/house/cobweb.gd"))
	U.add(parent, a, nm, pos)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(1.6, 2.0, 1.2))
	a.add_child(cs)
	_web(a, Vector3(0, 0.3, 0), 1.5, rng.randf() * 90.0, 90.0)
	if tier > 0:
		_hazard(a, tier, 2)
	else:
		_hazard(a, 0)


func _cobwebs() -> void:
	var c := _holder("Cobwebs")
	_cobweb(c, "W1", Vector3(-7.0, -3.2 + 1.0, 5.0), 0)
	_cobweb(c, "W2", Vector3(5.0, F3 + 1.0, -2.0), 0)
	_cobweb(c, "W3", Vector3(-11.0, F2 + 1.0, 2.0), 0)
	_cobweb(c, "W4", Vector3(0.0, F1 + 1.0, -6.0), 2)
	_cobweb(c, "W5", Vector3(10.5, F1 + 1.0, 2.5), 2)
	_cobweb(c, "W6", Vector3(0.0, F2 + 1.0, 4.0), 2)
	_cobweb(c, "W7", Vector3(-8.0, F3 + 1.0, 1.0), 2)


# ---------- таблички ----------

func _signs() -> void:
	var s := _holder("Signs")
	var sg := _vb(s, "NoteBoard", Vector3(1.2, 0.8, 0.05), Color(0.8, 0.75, 0.6), Vector3(-2.6, 1.4, 11.2), "wood")
	U.label(sg, "Text", "SIGN_HOUSE_NOTE", Vector3(0, 0, 0.04), 0.1, Color(0.2, 0.1, 0.05))
	_vb(s, "NotePost", Vector3(0.08, 1.4, 0.08), C_WOOD_D, Vector3(-2.6, 0.7, 11.2), "wood")
	var rs := _vb(s, "RottenSign", Vector3(1.2, 0.6, 0.05), Color(0.8, 0.45, 0.2), Vector3(-6.5, 1.1, 0.0), "wood")
	U.label(rs, "Text", "SIGN_HOUSE_ROTTEN", Vector3(0, 0, 0.04), 0.1, Color(0.2, 0.05, 0.05))
	_vb(s, "RottenPost", Vector3(0.06, 1.1, 0.06), C_WOOD_D, Vector3(-6.5, 0.55, 0.0), "wood")


# ---------- кот ----------

func _cat() -> void:
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	var m0 := Marker3D.new()
	U.add(spots, m0, "Attic", Vector3(8.5, F3 + 0.6, -5.5))
	m0.rotation_degrees.y = 200.0
	var m1 := Marker3D.new()
	U.add(spots, m1, "Cellar", Vector3(-5.0, -3.2 + 0.1, -6.6))
	m1.rotation_degrees.y = 160.0
	var m2 := Marker3D.new()
	U.add(spots, m2, "Secret", Vector3(0.6, F2 + 0.15, -10.2))
	m2.rotation_degrees.y = 180.0
	CatBuilder.build(root_node, m0.position)


func _players_and_checkpoints() -> void:
	var holder := _holder("Players")
	var p := U.player(holder, SPAWN + Vector3(0, 0.6, 0))
	var hl := OmniLight3D.new()
	hl.name = "Flashlight"
	hl.light_color = Color(1.0, 0.9, 0.7)
	hl.light_energy = 0.8
	hl.omni_range = 7.0
	hl.omni_attenuation = 1.5
	hl.position = Vector3(0, 1.7, 0.2)
	p.add_child(hl)
	var cps := _holder("Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, SPAWN + Vector3(1.5, 0, 0))
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(0.0, F1, 4.0))
	U.checkpoint(cps, "Checkpoint2", 2, Vector3(-1.0, F2, -2.0))
