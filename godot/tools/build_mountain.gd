@tool
extends SceneTree
## Генерирует res://scenes/locations/mountain.tscn: локация 8 «Мурашки» (снежные горы и домик у обрыва, закат, метель).
## Запуск: godot --headless --path godot --script res://tools/build_mountain.gd
##
## Серпантин от лагеря (0,72) через иглу (43,15) и домик у обрыва (8,-8) к уступу (-14,-72) за трещиной. Рельеф строится при загрузке
## (MountainTerrain), все объекты ставятся по высоте рельефа.
## Коты: простая — в снежной пещере-иглу; средняя — в домике; сложная — на дальнем уступе за ледяным мостом над трещиной.
## Опасности: лёд скользит, холод замедляет вне костра/домика, сосульки (тир 1, больше на 2), лавинки (тир 1, больше на 2),
## метель (туман по сложности), на средней и сложной ледяные плитки моста проваливаются; провал в трещину возвращает на чекпоинт.

const U := preload("res://scripts/location/loc_util.gd")
const MT := preload("res://scripts/location/mountain/mountain_terrain.gd")

var root_node: Node3D
var rng := RandomNumberGenerator.new()
var _cache := {}

const SPAWN := Vector3(0.0, 0.0, 74.0)
const C_RUST := Color(0.5, 0.3, 0.18)
const C_STEEL := Color(0.45, 0.5, 0.55)
const C_WOOD := Color(0.4, 0.27, 0.18)
const C_WOOD_D := Color(0.27, 0.18, 0.12)
const C_SIDING := Color(0.5, 0.36, 0.24)
const C_SNOW := Color(0.95, 0.97, 1.0)
const C_ICE := Color(0.6, 0.8, 0.95)
const C_ROCK := Color(0.42, 0.42, 0.46)
const TENT_COLS := [Color(0.85, 0.3, 0.25), Color(0.9, 0.65, 0.25), Color(0.25, 0.5, 0.7)]


func _init() -> void:
	rng.seed = 2024
	root_node = Node3D.new()
	root_node.name = "Mountain"
	root_node.set_script(load("res://scripts/location/location.gd"))
	root_node.set("title_key", "LOC_MOUNTAIN")
	root_node.set("kill_height", -6.0)
	U.rounded = false
	_environment()
	_terrain()
	_camp()
	_cabin()
	_igloo()
	_ledge()
	_bridge()
	_ice()
	_arches()
	_avalanches()
	_trees()
	_rocks()
	_signs()
	_cat()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/mountain.tscn")
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
	li.omni_range = 5.5
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


# ---------- вспомогательное ----------

func _th(x: float, z: float) -> float:
	return MT.height(x, z)


func _path_xz(t: float) -> Vector2:
	var i := clampi(int(t), 0, MT.PATH.size() - 2)
	var f := t - i
	var a: Vector3 = MT.PATH[i]
	var b: Vector3 = MT.PATH[i + 1]
	return Vector2(lerpf(a.x, b.x, f), lerpf(a.y, b.y, f))


func _path_dir(t: float) -> Vector2:
	var i := clampi(int(t), 0, MT.PATH.size() - 2)
	var a: Vector3 = MT.PATH[i]
	var b: Vector3 = MT.PATH[i + 1]
	return Vector2(b.x - a.x, b.y - a.y).normalized()


func _at(t: float, side := 0.0) -> Vector3:
	var p := _path_xz(t)
	var d := _path_dir(t)
	var n := Vector2(-d.y, d.x)
	p += n * side
	return Vector3(p.x, _th(p.x, p.y), p.y)


func _kill_zone(parent: Node, nm: String, pos: Vector3, size: Vector3, yaw: float) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/location/mountain/crack_kill.gd"))
	U.add(parent, a, nm, pos)
	a.rotation_degrees.y = yaw
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(size)
	a.add_child(cs)


# ---------- закат и метель ----------

func _environment() -> void:
	U.environment(root_node, Color(0.45, 0.58, 0.8), Color(0.98, 0.78, 0.7), Color(1.0, 0.72, 0.5), Vector3(-13, -25, 0), 0.006, 0.7)
	var sun := root_node.get_node("Sun") as DirectionalLight3D
	sun.light_energy = 0.6
	sun.directional_shadow_max_distance = 170.0
	var env := (root_node.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_light_color = Color(0.82, 0.86, 0.95)
	env.glow_intensity = 0.25
	env.ambient_light_energy = 0.5
	U.clouds(root_node, rng, 28, Vector3(0.9, 0.12, 0.35))
	var b := Node3D.new()
	b.set_script(load("res://scripts/location/mountain/blizzard.gd"))
	U.add(root_node, b, "Blizzard")
	var c := Node.new()
	c.set_script(load("res://scripts/location/mountain/cold.gd"))
	U.add(root_node, c, "Cold")


func _terrain() -> void:
	var t := Node3D.new()
	t.set_script(load("res://scripts/location/mountain/mountain_terrain.gd"))
	U.add(root_node, t, "Terrain")


# ---------- тёплые зоны ----------

func _warm(parent: Node, nm: String, pos: Vector3, radius: float) -> void:
	var m := Marker3D.new()
	U.add(parent, m, nm, pos)
	m.add_to_group("warm", true)
	m.set_meta("radius", radius)


func _fire(parent: Node, pos: Vector3, scale := 1.0) -> void:
	var f := Node3D.new()
	U.add(parent, f, "Campfire", pos)
	for k in 8:
		var a := TAU * k / 8.0
		U.sphere(f, "Stone%d" % k, 0.22 * scale, Color(0.4, 0.4, 0.42), Vector3(cos(a) * 0.8 * scale, 0.1, sin(a) * 0.8 * scale), 0.7)
	for k in 4:
		var a2 := TAU * k / 4.0 + 0.4
		U.rod(f, "Log%d" % k, Vector3(cos(a2) * 0.5 * scale, 0.1, sin(a2) * 0.5 * scale), Vector3(0, 0.55 * scale, 0), 0.09 * scale, Color(0.3, 0.2, 0.12), 0.95)
	_glow(f, "Flame", 0.28 * scale, Color(1.0, 0.55, 0.15), Vector3(0, 0.5 * scale, 0), 3.0).scale = Vector3(1, 1.6, 1)
	_glow(f, "FlameCore", 0.16 * scale, Color(1.0, 0.85, 0.4), Vector3(0, 0.4 * scale, 0), 3.5)
	var fl := OmniLight3D.new()
	fl.set_script(load("res://scripts/location/forest/flicker.gd"))
	fl.set("base_energy", 2.0)
	fl.light_color = Color(1.0, 0.65, 0.35)
	fl.omni_range = 12.0
	fl.omni_attenuation = 1.2
	U.add(f, fl, "Light", Vector3(0, 1.0, 0))


# ---------- лагерь у старта ----------

func _tent(parent: Node, pos: Vector3, yaw: float, col: Color) -> void:
	var t := Node3D.new()
	U.add(parent, t, "Tent", pos)
	t.rotation_degrees.y = yaw
	var pr := PrismMesh.new()
	pr.size = Vector3(2.8, 2.0, 3.2)
	var mi := MeshInstance3D.new()
	mi.mesh = pr
	mi.material_override = U.mat(col, 0.9)
	U.add(t, mi, "Cloth", Vector3(0, 1.0, 0))
	var body := StaticBody3D.new()
	U.add(t, body, "Body", Vector3(0, 0.75, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(2.0, 1.5, 3.0))
	body.add_child(cs)
	_vb(t, "Flap", Vector3(1.0, 1.6, 0.04), col.darkened(0.4), Vector3(0, 0.8, 1.62), "paint", 0.9)
	for sg in [-1.0, 1.0]:
		U.rod(t, "Rope", Vector3(sg * 1.4, 0.0, 1.6), Vector3(sg * 1.9, 0.0, 2.6), 0.02, Color(0.8, 0.75, 0.6))
	_vb(t, "Snow", Vector3(2.7, 0.08, 3.2), C_SNOW, Vector3(0, 1.9, 0), "paint", 0.95).rotation_degrees.z = 0.0


func _camp() -> void:
	var c := _holder("Camp")
	var y0 := _th(0, 74)
	_tent(c, Vector3(-8, y0, 78), 20.0, TENT_COLS[0])
	_tent(c, Vector3(8, y0, 79), -15.0, TENT_COLS[1])
	_tent(c, Vector3(-11, y0, 68), 60.0, TENT_COLS[2])
	_fire(c, Vector3(-4, y0, 70))
	_warm(c, "Warm", Vector3(-4, y0, 70), 9.0)
	for k in 4:
		var p := Vector3(-6.0 + (k % 2) * 3.4, y0, 66.5 + (k / 2) * 0.0)
	_crate(c, Vector3(5.0, y0, 70.0), 0.9, 15.0)
	_crate(c, Vector3(6.0, y0, 70.4), 0.7, 30.0)
	_crate(c, Vector3(5.5, y0 + 0.9, 70.1), 0.6, 8.0)
	_barrel(c, Vector3(7.4, y0, 69.4), Color(0.5, 0.3, 0.2))
	# Сани и вещмешки
	_sb(c, "Sled", Vector3(1.0, 0.1, 2.2), C_WOOD, Vector3(3.0, y0 + 0.25, 65.5), "wood")
	for sg in [-0.4, 0.4]:
		_vb(c, "Runner", Vector3(0.06, 0.12, 2.6), Color(0.15, 0.15, 0.17), Vector3(3.0 + sg, y0 + 0.12, 65.5), "metal")
	U.sphere(c, "Pack1", 0.4, Color(0.55, 0.2, 0.15), Vector3(3.0, y0 + 0.5, 65.4), 0.8)
	U.sphere(c, "Pack2", 0.35, Color(0.2, 0.4, 0.3), Vector3(-1.0, y0 + 0.35, 72.5), 0.8)
	# Бревно у костра, чайник на камне
	_sb(c, "Bench", Vector3(2.2, 0.35, 0.4), C_WOOD, Vector3(-4.0, y0 + 0.18, 72.4), "wood")
	_cyl(c, "Kettle", 0.18, 0.14, 0.3, Color(0.25, 0.25, 0.28), Vector3(-4.3, y0 + 0.62, 70.0), "metal", 10)
	# Флаг с котом
	U.rod(c, "FlagPole", Vector3(1.5, y0, 76.0), Vector3(1.5, y0 + 4.5, 76.0), 0.05, C_STEEL)
	var fl := _vb(c, "Flag", Vector3(1.4, 0.9, 0.03), Color(0.95, 0.6, 0.2), Vector3(2.2, y0 + 4.0, 76.0), "paint", 0.9)
	U.sphere(fl, "Face", 0.2, Color(0.2, 0.15, 0.1), Vector3(0, 0, 0.03), 0.5)
	# Фонари
	for p in [Vector3(-2, y0, 76), Vector3(4, y0, 74)]:
		_lamp(c, p, 3.2)


func _lamp(parent: Node, pos: Vector3, h := 3.0) -> void:
	var l := Node3D.new()
	U.add(parent, l, "Lamp", pos)
	_vb(l, "Post", Vector3(0.12, h, 0.12), Color(0.2, 0.18, 0.15), Vector3(0, h * 0.5, 0), "wood")
	_vb(l, "Arm", Vector3(0.8, 0.07, 0.07), Color(0.2, 0.18, 0.15), Vector3(0.35, h, 0), "wood")
	_glow(l, "Globe", 0.18, Color(1.0, 0.8, 0.5), Vector3(0.7, h - 0.12, 0), 3.0)
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.78, 0.5)
	li.light_energy = 1.2
	li.omni_range = 11.0
	li.omni_attenuation = 1.3
	U.add(l, li, "Light", Vector3(0.7, h - 0.4, 0))


# ---------- домик у обрыва ----------

func _cabin() -> void:
	var c := _holder("Cabin")
	var y := 12.0
	# Пол и фундамент
	_sb(c, "Floor", Vector3(8.4, 0.4, 6.4), C_WOOD_D, Vector3(8.0, y - 0.2, -8.0), "wood")
	_sb(c, "Porch", Vector3(4.6, 0.3, 6.4), C_WOOD, Vector3(1.9, y - 0.15, -8.0), "wood")
	for k in 5:
		_vb(c, "PorchBoard%d" % k, Vector3(4.6, 0.02, 0.05), Color(0.2, 0.13, 0.08), Vector3(1.9, y + 0.01, -10.5 + k * 1.25), "wood")
	for p in [Vector3(-0.2, 0, -10.8), Vector3(-0.2, 0, -5.2), Vector3(4.0, 0, -10.8), Vector3(4.0, 0, -5.2)]:
		var gy := _th(p.x, p.z)
		_vb(c, "PorchPost", Vector3(0.3, y - gy, 0.3), C_WOOD_D, Vector3(p.x, (y + gy) * 0.5, p.z), "wood")
	# Стены из брёвен (коробки с полосами), проёмы: дверь на юг, окна
	var col := Color(0.45, 0.3, 0.2)
	_wall_x(c, "WallS", -5.0, 4.0, 12.0, y, 2.8, col, [[10.0, 1.2, y, y + 2.1], [6.0, 1.2, y + 0.9, y + 2.0]], false, 1.0, "wood")
	_wall_x(c, "WallN", -11.0, 4.0, 12.0, y, 2.8, col, [[8.0, 1.4, y + 0.9, y + 2.0]], false, -1.0, "wood")
	_wall_z(c, "WallW", 4.0, -11.0, -5.0, y, 2.8, col, [[-8.0, 1.2, y, y + 2.1]], false, -1.0, "wood")
	_wall_z(c, "WallE", 12.0, -11.0, -5.0, y, 2.8, col, [[-8.0, 1.2, y + 0.9, y + 2.0]], false, 1.0, "wood")
	for k in 7:
		for pos in [[8.0, -4.82, 8.2, 0.12], [8.0, -11.18, 8.2, 0.12]]:
			_vb(c, "Log%d" % k, Vector3(pos[2], 0.1, 0.12), C_WOOD_D, Vector3(pos[0], y + 0.3 + k * 0.4, pos[1]), "wood")
	_window(c, "x", -5.0, 6.0, y + 0.9, 1.2, 1.1, -1.0)
	_window(c, "x", -11.0, 8.0, y + 0.9, 1.4, 1.1, 1.0)
	_window(c, "z", 12.0, -8.0, y + 0.9, 1.2, 1.1, -1.0)
	# Крыша: два ската со снежной шапкой и дымоходом
	var ang := rad_to_deg(atan2(1.7, 3.6))
	for sg in [-1.0, 1.0]:
		var rb := _sb(c, "RoofSlope", Vector3(9.4, 0.25, 4.1), Color(0.3, 0.2, 0.14), Vector3(8.0, y + 2.8 + 0.85, -8.0 + sg * 1.8), "wood")
		rb.rotation_degrees.x = sg * ang
		_vb(rb, "SnowCap", Vector3(9.6, 0.35, 4.1), C_SNOW, Vector3(0, 0.3, 0), "paint", 0.95)
	_sb(c, "Chimney", Vector3(1.0, 3.6, 1.0), Color(0.5, 0.33, 0.28), Vector3(5.0, y + 3.6, -9.6), "brick")
	_vb(c, "ChimneyCap", Vector3(1.2, 0.3, 1.2), C_SNOW, Vector3(5.0, y + 5.55, -9.6), "paint")
	# Фронтоны
	for sx in [4.0, 12.0]:
		var gm := MeshInstance3D.new()
		gm.mesh = U.gable(6.4, 1.7, 0.3, C_SIDING)
		gm.material_override = U.mat(C_SIDING, 0.95)
		U.add(c, gm, "Gable", Vector3(sx, y + 2.8, -8.0))
		gm.rotation_degrees.y = 90.0
	# Внутри: камин с огнём (тепло), койки, стол, лампа, полки
	var fp := Node3D.new()
	U.add(c, fp, "Fireplace", Vector3(4.6, y, -8.0))
	_sb(fp, "Breast", Vector3(0.8, 2.6, 2.4), Color(0.5, 0.33, 0.28), Vector3(0, 1.3, 0), "brick")
	_vb(fp, "Opening", Vector3(0.1, 0.9, 1.2), Color(0.05, 0.03, 0.02), Vector3(0.42, 0.6, 0), "paint")
	_glow(fp, "Fire", 0.2, Color(1.0, 0.5, 0.15), Vector3(0.45, 0.4, 0), 3.0).scale = Vector3(0.6, 1.4, 1.0)
	var fl := OmniLight3D.new()
	fl.set_script(load("res://scripts/location/forest/flicker.gd"))
	fl.set("base_energy", 1.8)
	fl.light_color = Color(1.0, 0.6, 0.3)
	fl.omni_range = 8.0
	U.add(fp, fl, "Light", Vector3(1.0, 0.8, 0))
	_warm(c, "Warm", Vector3(7.0, y + 1.0, -8.0), 8.0)
	_warm(c, "WarmPorch", Vector3(2.0, y + 1.0, -8.0), 4.5)
	_bed(c, Vector3(11.0, y, -10.0), 90.0, Color(0.5, 0.2, 0.2))
	_bed(c, Vector3(11.0, y, -7.2), 90.0, Color(0.2, 0.35, 0.5))
	_table(c, Vector3(8.0, y, -9.2), 1.5, 0.8, 0.75)
	_chair(c, Vector3(8.0, y, -8.3), 180.0)
	_chair(c, Vector3(7.2, y, -9.2), 90.0)
	_candle(c, Vector3(8.0, y + 0.84, -9.2), 0.8)
	_bookshelf(c, Vector3(9.0, y, -10.78), 0.0, 1.4)
	_rug(c, Vector3(7.0, y, -7.2), 2.4, 1.6, Color(0.45, 0.2, 0.2))
	var wb := _sb(c, "Woodpile", Vector3(1.4, 0.8, 0.6), C_WOOD_D, Vector3(6.2, y + 0.4, -5.6), "wood")
	_lamp(c, Vector3(0.0, y, -5.4), 3.0)
	# Перила крыльца у обрыва и вывеска
	for z in [-10.7, -5.3]:
		_vb(c, "RailSide", Vector3(4.4, 0.08, 0.08), C_WOOD_D, Vector3(1.9, y + 1.0, z), "wood")
	_vb(c, "RailEdge", Vector3(0.08, 0.08, 5.4), C_WOOD_D, Vector3(-0.35, y + 1.0, -8.0), "wood")
	for z in [-10.7, -9.0, -7.3, -5.6]:
		_vb(c, "RailPost", Vector3(0.08, 1.0, 0.08), C_WOOD_D, Vector3(-0.35, y + 0.5, z), "wood")
	var gn := _vb(c, "CabinSign", Vector3(1.3, 0.6, 0.05), Color(0.8, 0.7, 0.4), Vector3(10.0, y + 2.6, -4.78), "wood")
	U.label(gn, "Text", "SIGN_MOUNT_CABIN", Vector3(0, 0, 0.04), 0.1, Color(0.2, 0.1, 0.05))
	# Гнездо кота на койке (средняя)
	var nest := _holder("NestCabin", Vector3(11.0, y + 0.55, -10.0))
	_vb(nest, "Blanket", Vector3(0.8, 0.06, 0.6), Color(0.55, 0.35, 0.45), Vector3.ZERO, "paint", 1.0)


# ---------- иглу-пещера ----------

func _igloo() -> void:
	var g := _holder("Igloo")
	var cx := 43.0
	var cz := 15.0
	var y := _th(cx, cz)
	var snowc := Color(0.88, 0.93, 1.0)
	var n := 14
	for k in n:
		var a := TAU * k / n
		# проём на запад (к тропе): угол pi
		if absf(wrapf(a - PI, -PI, PI)) < 0.45:
			continue
		var p := Vector3(cx + cos(a) * 3.3, y + 1.4, cz + sin(a) * 3.3)
		var blk := _sb(g, "Block%d" % k, Vector3(1.6, 2.8, 1.0), snowc.darkened(rng.randf_range(0.0, 0.08)), p, "paint", 0.9)
		blk.rotation.y = -a + PI * 0.5
	_sb(g, "Roof", Vector3(7.6, 0.6, 7.6), snowc, Vector3(cx, y + 3.1, cz), "paint", 0.9)
	for k in 5:
		var sm := SphereMesh.new()
		sm.radius = 4.4 - k * 0.55
		sm.height = (4.4 - k * 0.55) * 1.1
		sm.radial_segments = 14
		sm.rings = 6
		sm.is_hemisphere = true
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = U.mat(snowc.lightened(0.04 * k), 0.95)
		U.add(g, mi, "Dome%d" % k, Vector3(cx, y + 3.3 + k * 0.28, cz))
	# Вход: наклонный туннельный козырёк
	_sb(g, "EntranceRoof", Vector3(2.4, 0.5, 3.0), snowc, Vector3(cx - 4.2, y + 2.7, cz), "paint", 0.9)
	_sb(g, "EntranceL", Vector3(0.9, 2.5, 3.0), snowc, Vector3(cx - 4.2, y + 1.25, cz - 1.7), "paint", 0.9)
	_sb(g, "EntranceR", Vector3(0.9, 2.5, 3.0), snowc, Vector3(cx - 4.2, y + 1.25, cz + 1.7), "paint", 0.9)
	var cv := _vb(g, "CaveSign", Vector3(1.2, 0.5, 0.05), Color(0.2, 0.5, 0.7), Vector3(cx - 5.6, y + 2.2, cz), "paint")
	cv.rotation_degrees.y = -90.0
	U.label(cv, "Text", "SIGN_MOUNT_CAVE", Vector3(0, 0, 0.04), 0.14, Color(0.95, 0.95, 0.95))
	# Внутри: спальный мешок, фонарь (тепло слабое), гнездо
	var nest := _holder("NestIgloo", Vector3(cx, y, cz))
	_vb(nest, "Bag", Vector3(1.0, 0.15, 1.8), Color(0.8, 0.35, 0.25), Vector3(0, 0.08, 0), "paint", 1.0)
	_vb(nest, "Pillow", Vector3(0.6, 0.12, 0.4), Color(0.9, 0.85, 0.75), Vector3(0, 0.2, -0.7), "paint", 1.0)
	var li := OmniLight3D.new()
	li.light_color = Color(0.7, 0.85, 1.0)
	li.light_energy = 0.9
	li.omni_range = 7.0
	U.add(g, li, "IceGlow", Vector3(cx, y + 2.0, cz))
	_candle(g, Vector3(cx + 1.2, y, cz + 1.0), 0.9)
	_warm(g, "Warm", Vector3(cx, y + 1.0, cz), 3.5)
	# Сосульки на козырьке и в куполе (тир 1/2)
	for k in 4:
		_icicle(g, "IcicleCave%d" % k, Vector3(cx - 4.6, y + 2.45, cz - 0.9 + k * 0.6), 1 if k < 2 else 2)


# ---------- уступ с котом ----------

func _ledge() -> void:
	var l := _holder("Ledge")
	var p := Vector3(-14.0, _th(-14, -72), -72.0)
	var y := p.y
	_vb(l, "Rug", Vector3(2.2, 0.04, 1.6), Color(0.65, 0.25, 0.3), p + Vector3(0, 0.03, 0), "paint", 1.0)
	_sb(l, "Rock1", Vector3(3.0, 3.0, 3.0), C_ROCK, p + Vector3(-5.0, 1.2, -3.0), "concrete", 0.95)
	_vb(l, "Rock1Snow", Vector3(3.2, 0.35, 3.2), C_SNOW, p + Vector3(-5.0, 2.8, -3.0), "paint", 0.95)
	var nest := _holder("NestLedge", p + Vector3(0, 0.0, 0))
	_vb(nest, "Blanket", Vector3(0.9, 0.06, 0.6), Color(0.6, 0.3, 0.35), Vector3(0, 0.07, 0), "paint", 1.0)
	_candle(l, p + Vector3(1.2, 0.0, 0.4), 0.9)
	_lamp(l, p + Vector3(3.0, 0.0, 1.5), 3.0)
	# Табличка у трещины и верёвочное ограждение
	var near := _at(7.1)
	var sg := _vb(l, "CrevasseSign", Vector3(1.6, 0.8, 0.06), Color(0.9, 0.45, 0.2), near + Vector3(3.2, 1.4, 0.0), "wood")
	U.label(sg, "Text", "SIGN_MOUNT_CREVASSE", Vector3(0, 0, 0.05), 0.1, Color(0.15, 0.05, 0.02))
	_vb(l, "CrevasseSignPost", Vector3(0.08, 1.4, 0.08), C_WOOD_D, near + Vector3(3.2, 0.7, 0.0), "wood")


# ---------- ледяной мост над трещиной ----------

func _bridge() -> void:
	var b := _holder("Bridge")
	var t := MT.CHASM_T
	var pc := _path_xz(t)
	var d := _path_dir(t)
	var yaw := atan2(d.x, d.y)
	var pyc := MT.path_info(pc.x, pc.y).y
	var solid := Node3D.new()
	U.add(b, solid, "Solid")
	var fallb := Node3D.new()
	U.add(b, fallb, "Falling")
	for k in range(-2, 3):
		var o := Vector2(d.x, d.y) * (k * 1.9)
		var pos := Vector3(pc.x + o.x, pyc - 0.12, pc.y + o.y)
		var plank := _sb(solid, "Plank%d" % (k + 2), Vector3(2.6, 0.24, 1.8), C_ICE.lightened(0.1), pos, "paint", 0.2, 0.1)
		plank.rotation.y = yaw
		var fp := StaticBody3D.new()
		fp.set_script(load("res://scripts/falling_platform.gd"))
		fp.set("delay", 0.9)
		fp.set("respawn", 4.0)
		U.add(fallb, fp, "Tile%d" % (k + 2), pos)
		fp.rotation.y = yaw
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _bshape(Vector3(2.6, 0.24, 1.8))
		fp.add_child(cs)
		_vb(fp, "Mesh", Vector3(2.6, 0.24, 1.8), C_ICE.lightened(0.15), Vector3.ZERO, "paint", 0.15, 0.1)
		var sensor := Area3D.new()
		sensor.name = "Sensor"
		sensor.collision_layer = 0
		sensor.collision_mask = 1
		var ss := CollisionShape3D.new()
		ss.shape = _bshape(Vector3(2.3, 0.5, 1.5))
		sensor.add_child(ss)
		U.add(fp, sensor, "Sensor", Vector3(0, 0.3, 0))
	_hazard(solid, 0, 0)
	_hazard(fallb, 1)
	# Верёвочные перила
	for sg in [-1.4, 1.4]:
		var n: Vector2 = Vector2(-d.y, d.x) * float(sg)
		var a := Vector3(pc.x + n.x - d.x * 5.0, pyc + 0.9, pc.y + n.y - d.y * 5.0)
		var e := Vector3(pc.x + n.x + d.x * 5.0, pyc + 0.9, pc.y + n.y + d.y * 5.0)
		U.rod(b, "Rope", a, e, 0.03, Color(0.75, 0.65, 0.4))
		for k in 3:
			var q := a.lerp(e, k * 0.5)
			U.rod(b, "Post", q - Vector3(0, 0.9, 0), q + Vector3(0, 0.2, 0), 0.05, C_STEEL)
	# Зона провала: падение в трещину
	_kill_zone(b, "CrackKill", Vector3(pc.x, pyc - 9.0, pc.y), Vector3(34.0, 10.0, 14.0), rad_to_deg(yaw))
	# Снег и лёд по стенам трещины (визуал)
	for k in 8:
		var o2: Vector2 = Vector2(-d.y, d.x) * rng.randf_range(-7.0, 7.0)
		var mi := U.sphere(b, "Icicle%d" % k, 0.5, C_ICE, Vector3(pc.x + o2.x + d.x * 3.0, pyc - 4.5 - rng.randf() * 3.0, pc.y + o2.y + d.y * 3.0), 1.8)


# ---------- лёд, сосульки, арки, лавины ----------

func _ice() -> void:
	var s := _holder("Ice")
	var ts := [[0.8, 0], [1.9, 0], [3.3, 0], [4.4, 0], [5.4, 1], [2.6, 1], [6.3, 1], [7.0, 1], [0.4, 2], [3.9, 2], [5.9, 2], [6.8, 2]]
	var k := 0
	for e in ts:
		var p := _at(e[0])
		var a := Area3D.new()
		a.set_script(load("res://scripts/location/cellar/slip_zone.gd"))
		a.set("accel_scale", 0.14)
		a.set("message_key", "MSG_ICE")
		U.add(s, a, "IceZone%d" % k, p + Vector3(0, 0.6, 0))
		var cs := CollisionShape3D.new()
		cs.shape = _bshape(Vector3(5.0, 1.6, 5.0))
		a.add_child(cs)
		var dm := CylinderMesh.new()
		dm.top_radius = 2.6
		dm.bottom_radius = 2.6
		dm.height = 0.04
		dm.radial_segments = 16
		var mi := MeshInstance3D.new()
		mi.mesh = dm
		var im := StandardMaterial3D.new()
		im.albedo_color = Color(0.55, 0.78, 0.95, 0.72)
		im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		im.metallic = 0.4
		im.roughness = 0.05
		mi.material_override = im
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.add(a, mi, "Sheet", Vector3(0, -0.52, 0))
		_hazard(a, e[1])
		k += 1
	var ib := _vb(s, "IceSign", Vector3(1.2, 0.6, 0.05), Color(0.2, 0.5, 0.75), _at(0.6, 3.4) + Vector3(0, 1.4, 0), "paint")
	U.label(ib, "Text", "SIGN_MOUNT_ICE", Vector3(0, 0, 0.04), 0.1, Color(0.95, 0.95, 0.95))
	_vb(s, "IceSignPost", Vector3(0.08, 1.4, 0.08), C_WOOD_D, _at(0.6, 3.4) + Vector3(0, 0.7, 0), "wood")


func _icicle(parent: Node, nm: String, pos: Vector3, tier: int) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/location/mountain/icicle.gd"))
	U.add(parent, a, nm, pos)
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(0.3, 1.0, 0.3))
	cs.position = Vector3(0, -0.5, 0)
	a.add_child(cs)
	var cm := CylinderMesh.new()
	cm.top_radius = 0.14
	cm.bottom_radius = 0.0
	cm.height = 1.0
	cm.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	var im := StandardMaterial3D.new()
	im.albedo_color = Color(0.7, 0.88, 1.0, 0.8)
	im.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	im.roughness = 0.1
	im.metallic = 0.3
	mi.material_override = im
	U.add(a, mi, "Mesh", Vector3(0, -0.5, 0))
	_hazard(a, tier)


func _arches() -> void:
	var a := _holder("Arches")
	var ts := [1.5, 3.4, 5.5]
	var tiers := [1, 1, 2]
	for i in 3:
		var t: float = ts[i]
		var p := _at(t)
		var d := _path_dir(t)
		var yaw := atan2(d.x, d.y)
		var holder := Node3D.new()
		U.add(a, holder, "Arch%d" % i, p)
		holder.rotation.y = yaw
		for sx in [-3.4, 3.4]:
			var py := _th(p.x + (-d.y) * sx, p.z + d.x * sx) - p.y
			_sb(holder, "Pillar", Vector3(1.8, 5.0 - py * 0.0 + 1.0, 1.8), C_ROCK, Vector3(sx, 2.0 + 0.5, 0.0), "concrete", 0.95)
			_vb(holder, "PillarSnow", Vector3(1.9, 0.3, 1.9), C_SNOW, Vector3(sx, 5.1, 0.0), "paint", 0.95)
		_sb(holder, "Beam", Vector3(9.0, 1.2, 2.2), C_ROCK, Vector3(0, 4.8, 0), "concrete", 0.95)
		_vb(holder, "BeamSnow", Vector3(9.2, 0.45, 2.3), C_SNOW, Vector3(0, 5.6, 0), "paint", 0.95)
		for k in 5:
			_icicle(holder, "Icicle%d" % k, Vector3(-2.4 + k * 1.2, 4.2, 0.0), tiers[i])
	# Подвешенные сосульки под скальным навесом у лагеря и у домика
	for k in 3:
		var cp := Vector3(5.0 + k * 2.0, 12.0 + 2.9, -4.7)
		_icicle(a, "EaveIcicle%d" % k, cp, 2)


func _avalanches() -> void:
	var a := _holder("Avalanches")
	var sets := [[[3.5, 1], [5.2, 1]], [[2.4, 2], [4.3, 2], [6.4, 2]]]
	for si in sets.size():
		var av := Node3D.new()
		av.set_script(load("res://scripts/location/mountain/avalanche.gd"))
		av.set("period", 22.0 if si == 0 else 16.0)
		U.add(a, av, "Avalanche%d" % si, Vector3.ZERO)
		var tier := 1 if si == 0 else 2
		for e in sets[si]:
			var p := _at(e[0])
			var toward := (Vector2(0, -50) - Vector2(p.x, p.z)).normalized()
			var sp := Vector2(p.x, p.z) + toward * 15.0
			var m := Marker3D.new()
			U.add(av, m, "Spawn%d" % av.get_child_count(), Vector3(sp.x, _th(sp.x, sp.y) + 2.0, sp.y))
		_hazard(av, tier)


# ---------- деревья, камни ----------

func _snow_tree_mesh(kind: int) -> Mesh:
	var key := "tree%d" % kind
	if _cache.has(key):
		return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var layers := 4 + kind
	var trunk := Color(0.28, 0.2, 0.14)
	var green := Color(0.14, 0.28, 0.2)
	for L in layers:
		var f := float(L) / layers
		var r := lerpf(1.7, 0.45, f) * (0.9 + kind * 0.1)
		var y0 := 0.6 + f * (3.6 + kind)
		var h := 1.7 - f * 0.5
		var snow := Color(0.96, 0.97, 1.0)
		var n := 10
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var tip := Vector3(0, y0 + h, 0)
			var b0 := Vector3(cos(a0) * r, y0, sin(a0) * r)
			var b1 := Vector3(cos(a1) * r, y0, sin(a1) * r)
			st.set_color(green.lerp(snow, 0.35 + (i % 2) * 0.15))
			st.add_vertex(tip)
			st.add_vertex(b1)
			st.add_vertex(b0)
			st.set_color(green.darkened(0.3))
			st.add_vertex(Vector3(0, y0, 0))
			st.add_vertex(b0)
			st.add_vertex(b1)
	for i in 6:
		var a0 := TAU * i / 6
		var a1 := TAU * (i + 1) / 6
		st.set_color(trunk)
		st.add_vertex(Vector3(cos(a0) * 0.18, 0, sin(a0) * 0.18))
		st.add_vertex(Vector3(cos(a0) * 0.14, 1.0, sin(a0) * 0.14))
		st.add_vertex(Vector3(cos(a1) * 0.18, 0, sin(a1) * 0.18))
		st.add_vertex(Vector3(cos(a1) * 0.18, 0, sin(a1) * 0.18))
		st.add_vertex(Vector3(cos(a0) * 0.14, 1.0, sin(a0) * 0.14))
		st.add_vertex(Vector3(cos(a1) * 0.14, 1.0, sin(a1) * 0.14))
	st.generate_normals()
	var m := st.commit()
	_cache[key] = m
	return m


func _tree_mat() -> StandardMaterial3D:
	if _cache.has("treemat"):
		return _cache["treemat"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["treemat"] = m
	return m


func _trees() -> void:
	var t := _holder("Trees")
	var count := 0
	var tries := 0
	while count < 220 and tries < 2400:
		tries += 1
		var x := rng.randf_range(-150.0, 150.0)
		var z := rng.randf_range(-130.0, 110.0)
		var pi := MT.path_info(x, z)
		if pi.x < 8.0:
			continue
		var skip := false
		for pf in MT.PLATFORMS:
			if Vector2(x - pf.x, z - pf.y).length() < pf.z + 5.0:
				skip = true
		if skip:
			continue
		if MT.slope(x, z) > 0.7:
			continue
		var h := _th(x, z)
		if h > 38.0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = _snow_tree_mesh(rng.randi() % 3)
		mi.material_override = _tree_mat()
		U.add(t, mi, "Tree%d" % count, Vector3(x, h - 0.1, z))
		mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
		mi.rotation_degrees.y = rng.randf() * 360.0
		count += 1


func _rocks() -> void:
	var r := _holder("Rocks")
	var count := 0
	var tries := 0
	while count < 110 and tries < 1500:
		tries += 1
		var x := rng.randf_range(-130.0, 130.0)
		var z := rng.randf_range(-120.0, 100.0)
		var pi := MT.path_info(x, z)
		if pi.x < 5.0:
			continue
		var skip := false
		for pf in MT.PLATFORMS:
			if Vector2(x - pf.x, z - pf.y).length() < pf.z + 3.0:
				skip = true
		if skip:
			continue
		var h := _th(x, z)
		var s := rng.randf_range(0.8, 2.6)
		var sm := U.sphere(r, "Rock%d" % count, s, C_ROCK.lerp(Color(0.55, 0.52, 0.5), rng.randf()), Vector3(x, h + s * 0.3, z), 0.7)
		sm.rotation_degrees = Vector3(0, rng.randf() * 360.0, 0)
		var cap := U.sphere(sm, "Snow", s * 0.8, C_SNOW, Vector3(0, s * 0.18, 0), 0.5)
		count += 1
	# Сугробы вдоль тропы
	for k in 60:
		var t := rng.randf_range(0.0, 8.0)
		var side := rng.randf_range(3.5, 6.5) * (1.0 if rng.randf() < 0.5 else -1.0)
		var p := _at(t, side)
		var s2 := rng.randf_range(0.7, 1.6)
		U.sphere(r, "Drift%d" % k, s2, C_SNOW, p + Vector3(0, s2 * 0.15, 0), 0.4)


# ---------- таблички ----------

func _signs() -> void:
	var s := _holder("Signs")
	var y0 := _th(0, 74)
	var sg := _vb(s, "MountSign", Vector3(3.2, 1.4, 0.1), Color(0.2, 0.45, 0.7), Vector3(0, y0 + 3.2, 80.0), "wood")
	U.label(sg, "Text", "SIGN_MOUNT_NAME", Vector3(0, 0, -0.07), 0.22, Color(0.95, 0.95, 0.95)).rotation_degrees.y = 180.0
	for sx in [-1.4, 1.4]:
		_vb(s, "MountSignPost", Vector3(0.14, 3.2, 0.14), C_WOOD_D, Vector3(sx, y0 + 1.6, 80.0), "wood")
	var cs := _vb(s, "CampSign", Vector3(1.2, 0.6, 0.05), Color(0.9, 0.6, 0.25), Vector3(-6.4, y0 + 1.6, 70.0), "wood")
	cs.rotation_degrees.y = 90.0
	U.label(cs, "Text", "SIGN_MOUNT_CAMP", Vector3(0, 0, 0.04), 0.1, Color(0.2, 0.08, 0.02))
	_vb(s, "CampSignPost", Vector3(0.08, 1.6, 0.08), C_WOOD_D, Vector3(-6.4, y0 + 0.8, 70.0), "wood")


# ---------- кот ----------

func _cat() -> void:
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	var igy := _th(43, 15)
	var m0 := Marker3D.new()
	U.add(spots, m0, "Igloo", Vector3(43.0, igy + 0.15, 15.0))
	m0.rotation_degrees.y = 90.0
	var m1 := Marker3D.new()
	U.add(spots, m1, "Cabin", Vector3(11.0, 12.0 + 0.7, -10.0))
	m1.rotation_degrees.y = 200.0
	var m2 := Marker3D.new()
	U.add(spots, m2, "Ledge", Vector3(-14.0, _th(-14, -72) + 0.15, -72.0))
	m2.rotation_degrees.y = 160.0
	CatBuilder.build(root_node, m0.position)


func _players_and_checkpoints() -> void:
	var holder := _holder("Players")
	U.player(holder, SPAWN + Vector3(0, 0.6, 0))
	var cps := _holder("Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, SPAWN + Vector3(3.0, 0, 1.0))
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(13.0, _th(13, -2) + 0.0, -2.5))
	var c2 := _at(6.9)
	U.checkpoint(cps, "Checkpoint2", 2, c2)
