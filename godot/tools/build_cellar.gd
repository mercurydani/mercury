@tool
extends SceneTree
## Генерирует res://scenes/locations/cellar.tscn: локация 7 «Погреб» (подвал старого дома: потоп, шаткие полки, крысы, котёл).
## Запуск: godot --headless --path godot --script res://tools/build_cellar.gd
##
## Лестница с площадки (y=3), зал со стеллажами, винный погреб на запад, котельная на восток (помост y=2.6), угольная на север (кучa-пандус к помосту y=2.6).
## Коты: простая — за стеллажом в зале; средняя — в винном погребе; сложная — наверху угольной кучи.
## Опасности: вода прибывает с захлопнутой двери (таймер по сложности), котёл пускает пар (тир 0 один, 1 и 2 больше),
## шаткие полки и крысы со средней, скользкие ступени, на сложной вода быстрее и крыс больше.

const U := preload("res://scripts/location/loc_util.gd")

var root_node: Node3D
var rng := RandomNumberGenerator.new()
var _cache := {}

const SPAWN := Vector3(0.0, 3.0, 25.0)
const CEIL := 4.0
const C_RUST := Color(0.5, 0.3, 0.18)
const C_STEEL := Color(0.45, 0.5, 0.55)
const C_WOOD := Color(0.36, 0.24, 0.16)
const C_WOOD_D := Color(0.24, 0.16, 0.11)
const C_BRICK := Color(0.5, 0.3, 0.25)
const C_STONE := Color(0.42, 0.41, 0.4)
const C_SIDING := Color(0.55, 0.62, 0.55)


func _init() -> void:
	rng.seed = 1777
	root_node = Node3D.new()
	root_node.name = "Cellar"
	root_node.set_script(load("res://scripts/location/location.gd"))
	root_node.set("title_key", "LOC_CELLAR")
	root_node.set("kill_height", -4.0)
	U.rounded = false
	_environment()
	_shell()
	_landing()
	_hall()
	_wine()
	_boiler()
	_coal()
	_water_rise()
	_rats()
	_signs()
	_cat()
	_players_and_checkpoints()
	U.hud(root_node)
	var err := U.save_scene(root_node, "res://scenes/locations/cellar.tscn")
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


# ---------- освещение ----------

func _environment() -> void:
	U.environment(root_node, Color(0.02, 0.03, 0.05), Color(0.08, 0.09, 0.12), Color(0.7, 0.7, 0.8), Vector3(-60, 20, 0), 0.0, 0.45)
	var sun := root_node.get_node("Sun") as DirectionalLight3D
	sun.light_energy = 0.0
	sun.shadow_enabled = false
	var env := (root_node.get_node("WorldEnvironment") as WorldEnvironment).environment
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.12, 0.14)
	env.fog_density = 0.006
	env.ambient_light_energy = 0.9
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.65)
	env.glow_intensity = 0.8


func _lantern(parent: Node, pos: Vector3, energy := 1.2) -> void:
	var l := Node3D.new()
	U.add(parent, l, "Lantern", pos)
	_cyl(l, "Base", 0.1, 0.1, 0.04, Color(0.2, 0.2, 0.2), Vector3(0, 0.02, 0), "metal", 8)
	_glow(l, "Flame", 0.07, Color(1.0, 0.75, 0.35), Vector3(0, 0.15, 0), 3.0)
	_cyl(l, "Glass", 0.1, 0.1, 0.22, Color(1.0, 0.9, 0.6, 0.25), Vector3(0, 0.15, 0), "paint", 8)
	var fl := OmniLight3D.new()
	fl.set_script(load("res://scripts/location/forest/flicker.gd"))
	fl.set("base_energy", energy)
	fl.light_color = Color(1.0, 0.75, 0.45)
	fl.omni_range = 9.0
	fl.omni_attenuation = 1.3
	U.add(l, fl, "Light", Vector3(0, 0.3, 0))


func _bulb(parent: Node, pos: Vector3, energy := 1.5) -> void:
	var b := Node3D.new()
	U.add(parent, b, "Bulb", pos)
	U.rod(b, "Wire", Vector3(0, 0, 0), Vector3(0, 0.5, 0), 0.01, Color(0.05, 0.05, 0.05))
	_glow(b, "Glass", 0.1, Color(1.0, 0.85, 0.55), Vector3(0, -0.05, 0), 2.5)
	var li := OmniLight3D.new()
	li.light_color = Color(1.0, 0.8, 0.5)
	li.light_energy = energy * 1.6
	li.omni_range = 12.0
	li.omni_attenuation = 1.3
	U.add(b, li, "Light", Vector3(0, -0.15, 0))


# ---------- оболочка подвала ----------

func _shell() -> void:
	var s := _holder("Shell")
	var wc := C_STONE
	# Пол и потолок единым массивом, стены по комнатам
	_sb(s, "Floor", Vector3(64.0, 0.5, 38.0), Color(0.3, 0.3, 0.3), Vector3(-2.0, -0.25, -3.0), "concrete", 0.95)
	_vb(s, "FloorStain", Vector3(8.0, 0.02, 6.0), Color(0.12, 0.14, 0.14), Vector3(0, 0.01, 4.0), "bitumen")
	_slab_area(s, "HallCeil", [-14.4, 14.4, -4.4, 12.4], [], CEIL + 0.3, 0.3, Color(0.25, 0.22, 0.2), "wood")
	# Зал: стены x -14..14, z -4..12
	_wall_x(s, "HallN", -4.0, -14.15, 14.15, 0.0, CEIL, C_BRICK, [[11.0, 2.4, 0.0, 2.6]], false, 1.0, "brick")
	_wall_x(s, "HallS", 12.0, -14.15, 14.15, 0.0, CEIL, C_BRICK, [[0.0, 3.2, 0.0, CEIL]], false, 1.0, "brick")
	_wall_z(s, "HallW", -14.0, -4.15, 12.15, 0.0, CEIL, C_BRICK, [[4.0, 3.0, 0.0, 2.6]], false, 1.0, "brick")
	_wall_z(s, "HallE", 14.0, -4.15, 12.15, 0.0, CEIL, C_BRICK, [[6.0, 3.0, 0.0, 2.6]], false, 1.0, "brick")
	# Лестничный коридор к площадке: ceiling выше
	_wall_z(s, "StairW", -1.7, 12.0, 20.0, 0.0, 6.2, wc, [], false, 1.0, "concrete")
	_wall_z(s, "StairE", 1.7, 12.0, 20.0, 0.0, 6.2, wc, [], false, 1.0, "concrete")
	_slab_area(s, "StairCeil", [-1.85, 1.85, 11.9, 20.15], [], 6.5, 0.3, Color(0.22, 0.2, 0.18), "wood")
	_vb(s, "HallLintel", Vector3(3.2, 2.2, 0.3), C_BRICK, Vector3(0, CEIL + 1.1, 12.0), "brick")
	# Винный погреб: x -28..-14, z -6..10, потолок ниже
	_wall_x(s, "WineN", -6.0, -28.15, -13.85, 0.0, 3.4, wc, [], false, 1.0, "concrete")
	_wall_x(s, "WineS", 10.0, -28.15, -13.85, 0.0, 3.4, wc, [], false, 1.0, "concrete")
	_wall_z(s, "WineW", -28.0, -6.15, 10.15, 0.0, 3.4, wc, [], false, 1.0, "concrete")
	_slab_area(s, "WineCeil", [-28.4, -13.6, -6.4, 10.4], [], 3.7, 0.3, Color(0.25, 0.22, 0.2), "wood")
	# Котельная: x 14..26, z 0..14, потолок 5
	_wall_x(s, "BoilN", 0.0, 13.85, 26.15, 0.0, 5.0, wc, [], false, 1.0, "concrete")
	_wall_x(s, "BoilS", 14.0, 13.85, 26.15, 0.0, 5.0, wc, [], false, 1.0, "concrete")
	_wall_z(s, "BoilE", 26.0, -0.15, 14.15, 0.0, 5.0, wc, [], false, 1.0, "concrete")
	_slab_area(s, "BoilCeil", [13.6, 26.4, -0.4, 14.4], [], 5.3, 0.3, Color(0.22, 0.2, 0.18), "wood")
	# Угольная: x 6..18, z -16..-4, потолок 5.2
	_wall_x(s, "CoalN", -16.0, 5.85, 18.15, 0.0, 5.2, wc, [], false, 1.0, "concrete")
	_wall_z(s, "CoalW", 6.0, -16.15, -4.0, 0.0, 5.2, wc, [], false, 1.0, "concrete")
	_wall_z(s, "CoalE", 18.0, -16.15, -4.0, 0.0, 5.2, wc, [], false, 1.0, "concrete")
	_slab_area(s, "CoalCeil", [5.6, 18.4, -16.4, -3.8], [], 5.5, 0.3, Color(0.22, 0.2, 0.18), "wood")
	# Подтёки, водомерные риски на стенах зала
	for k in 6:
		var y := 0.0 + k * 0.5
		_vb(s, "Mark%d" % k, Vector3(0.05, 0.03, 0.6), Color(0.9, 0.9, 0.9), Vector3(13.82, y, 10.0), "paint")
	for k in 40:
		_vb(s, "Stain%d" % k, Vector3(rng.randf_range(0.2, 0.6), rng.randf_range(0.6, 2.0), 0.02), Color(0.12, 0.14, 0.14, 0.8), Vector3(rng.randf_range(-13.5, 13.5), rng.randf_range(0.6, 3.0), -3.83), "paint")
	# Трубы под потолком
	for k in 4:
		U.rod(s, "Pipe%d" % k, Vector3(-13.5, CEIL - 0.3 - k * 0.0, -3.2 + k * 0.5), Vector3(13.5, CEIL - 0.3, -3.2 + k * 0.5), 0.12, Color(0.5, 0.3, 0.2), 0.7, 0.4)
	for k in 7:
		U.rod(s, "Bracket%d" % k, Vector3(-12.0 + k * 4.0, CEIL - 0.3, -3.2), Vector3(-12.0 + k * 4.0, CEIL, -3.2), 0.05, C_STEEL)
	# Паутина по углам
	for p in [Vector3(-13.6, CEIL - 0.5, -3.6), Vector3(13.6, CEIL - 0.5, -3.6), Vector3(-13.6, CEIL - 0.5, 11.6), Vector3(13.6, CEIL - 0.5, 11.6)]:
		_web(s, p, 1.3, 45.0, 30.0)


# ---------- верхняя площадка и лестница ----------

func _landing() -> void:
	var l := _holder("Landing")
	_slab_area(l, "LandingFloor", [-3.2, 3.2, 19.8, 28.4], [], 3.0, 0.3, Color(0.3, 0.26, 0.22), "wood")
	_wall_x(l, "LandN", 28.0, -3.15, 3.15, 3.0, 4.0, C_STONE, [[0.0, 1.6, 3.0, 5.4]], false, 1.0, "concrete")
	_wall_z(l, "LandW", -3.0, 19.85, 28.15, 3.0, 4.0, C_STONE, [], false, 1.0, "concrete")
	_wall_z(l, "LandE", 3.0, 19.85, 28.15, 3.0, 4.0, C_STONE, [], false, 1.0, "concrete")
	_wall_x(l, "LandS1", 19.85, -3.15, -1.7, 3.0, 4.0, C_STONE, [], false, 1.0, "concrete")
	_wall_x(l, "LandS2", 19.85, 1.7, 3.15, 3.0, 4.0, C_STONE, [], false, 1.0, "concrete")
	_slab_area(l, "LandCeil", [-3.3, 3.3, 19.7, 28.5], [], 7.3, 0.3, Color(0.22, 0.2, 0.18), "wood")
	# Дверь (открыта в начале; DoorSlam захлопнет её)
	var ds := Node3D.new()
	ds.set_script(load("res://scripts/location/cellar/door_slam.gd"))
	U.add(l, ds, "Door", Vector3(-0.8, 3.0, 27.85))
	var leaf := Node3D.new()
	U.add(ds, leaf, "Leaf")
	_sb(leaf, "Plank", Vector3(1.6, 2.4, 0.1), Color(0.35, 0.22, 0.14), Vector3(0.8, 1.2, 0), "wood")
	for k in 4:
		_vb(leaf, "Strap%d" % k, Vector3(1.6, 0.08, 0.04), Color(0.1, 0.1, 0.1), Vector3(0.8, 0.4 + k * 0.55, 0.07), "metal")
	_vb(leaf, "Knob", Vector3(0.1, 0.1, 0.1), Color(0.7, 0.55, 0.2), Vector3(1.4, 1.1, 0.1), "metal", 0.4, 0.6)
	# Свет сверху и лестница вниз
	_lantern(l, Vector3(1.8, 3.0, 22.0), 1.0)
	_bulb(l, Vector3(0, 6.0, 24.0), 1.0)
	_bulb(l, Vector3(0, 5.6, 16.0), 0.9)
	var st := _slab(l, "Stairs", Vector3(0.0, 0.0, 12.3), Vector3(0.0, 3.0, 19.9), 2.8, Color(0.35, 0.28, 0.22), true)
	var slip := Area3D.new()
	slip.set_script(load("res://scripts/location/cellar/slip_zone.gd"))
	U.add(l, slip, "SlipStairs", Vector3(0, 1.8, 16.0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(3.0, 4.0, 7.8))
	slip.add_child(cs)
	_hazard(slip, 0)
	for k in 5:
		_vb(l, "Puddle%d" % k, Vector3(rng.randf_range(0.5, 1.2), 0.01, rng.randf_range(0.5, 1.2)), Color(0.15, 0.2, 0.22, 0.6), Vector3(rng.randf_range(-0.8, 0.8), 3.01 - 0.0, rng.randf_range(21, 27)), "paint", 0.05, 0.4)
	# Банки и ящики на площадке
	_crate(l, Vector3(-2.2, 3.0, 26.5), 0.8, 20.0)
	_barrel(l, Vector3(2.4, 3.0, 26.8))


# ---------- зал со стеллажами ----------

func _shelf(parent: Node, nm: String, pos: Vector3, yaw: float, w: float, tier: int, shaky := true) -> void:
	var h := Node3D.new()
	U.add(parent, h, nm, pos)
	h.rotation_degrees.y = yaw
	var hold := Node3D.new()
	hold.name = "Shelf"
	h.add_child(hold)
	_sb(hold, "Frame", Vector3(w, 2.3, 0.5), C_WOOD_D, Vector3(0, 1.15, 0), "wood")
	for k in 5:
		var y := 0.28 + k * 0.45
		_vb(hold, "Plank%d" % k, Vector3(w - 0.05, 0.05, 0.54), C_WOOD, Vector3(0, y, 0.0), "wood")
		var x := -w * 0.5 + 0.15
		while x < w * 0.5 - 0.15:
			var kind := rng.randi() % 3
			var col := Color.from_hsv(rng.randf(), 0.5, 0.55, 0.9)
			if kind == 0:
				_cyl(hold, "Jar", 0.075, 0.075, 0.22, col, Vector3(x, y + 0.14, 0.12), "paint", 8)
				_cyl(hold, "Lid", 0.08, 0.08, 0.03, Color(0.6, 0.55, 0.3), Vector3(x, y + 0.27, 0.12), "metal", 8)
			elif kind == 1:
				_cyl(hold, "Bottle", 0.05, 0.05, 0.3, col, Vector3(x, y + 0.18, 0.1), "paint", 8)
			else:
				_vb(hold, "Box", Vector3(0.18, 0.16, 0.22), Color(0.55, 0.45, 0.3), Vector3(x, y + 0.1, 0.1), "wood")
			x += 0.22
	if shaky and tier >= 0:
		var a := Area3D.new()
		a.set_script(load("res://scripts/location/cellar/shaky_shelf.gd"))
		U.add(h, a, "Shaker", Vector3(0, 1.0, 0))
		var cs := CollisionShape3D.new()
		cs.shape = _bshape(Vector3(w + 3.0, 2.4, 3.5))
		a.add_child(cs)
		for k in 4:
			var m := Marker3D.new()
			U.add(a, m, "Drop%d" % k, Vector3(-w * 0.35 + k * w * 0.23, 1.1, 0.2))
		_hazard(a, tier)


func _hall() -> void:
	var h := _holder("Hall")
	# Три ряда стеллажей, проходы между ними; кот за первым рядом у северо-западного угла
	_shelf(h, "ShelfNook", Vector3(-11.2, 0, -2.0), 0.0, 5.6, 1)
	_shelf(h, "ShelfA", Vector3(-4.0, 0, 2.0), 0.0, 5.0, 1)
	_shelf(h, "ShelfB", Vector3(5.0, 0, 3.5), 0.0, 5.0, 1)
	_shelf(h, "ShelfC", Vector3(-6.0, 0, 8.0), 0.0, 6.0, 1)
	_shelf(h, "ShelfD", Vector3(7.0, 0, 9.5), 0.0, 5.0, 1)
	# Гнездо кота (простая): в нише между стеной и стеллажом
	var nest := _holder("NestHall", Vector3(-12.0, 0, -3.1))
	_vb(nest, "Blanket", Vector3(0.9, 0.06, 0.6), Color(0.45, 0.5, 0.65), Vector3(0, 0.04, 0), "paint", 1.0)
	_crate(nest, Vector3(0.9, 0, 0.1), 0.6, 10.0)
	_lantern(nest, Vector3(0.9, 0.6, 0.1), 0.8)
	# Бочки, ящики, мешки, доски по залу
	for k in 8:
		var p := Vector3(rng.randf_range(-13.0, 13.0), 0, rng.randf_range(-3.0, 11.0))
		if absf(p.x) < 2.0 and p.z > 8.0:
			continue
		_barrel(h, p)
	for k in 8:
		var p2 := Vector3(rng.randf_range(-13.0, 13.0), 0, rng.randf_range(-3.0, 11.0))
		if absf(p2.x) < 2.0 and p2.z > 8.0:
			continue
		_crate(h, p2, rng.randf_range(0.5, 0.9), rng.randf() * 90.0)
	# Верстак и инструменты
	var wb := _sb(h, "Workbench", Vector3(2.4, 0.9, 0.8), C_WOOD, Vector3(0, 0.45, -3.5), "wood")
	_vb(h, "Vise", Vector3(0.2, 0.25, 0.25), C_STEEL, Vector3(0.9, 1.0, -3.5), "metal", 0.5, 0.5)
	_vb(h, "Saw", Vector3(0.7, 0.2, 0.02), Color(0.6, 0.6, 0.65), Vector3(-0.5, 1.2, -3.84), "metal", 0.4, 0.6)
	# Утечка: сорванная труба на северной стене
	_vb(h, "BrokenPipe", Vector3(0.3, 0.3, 1.0), Color(0.5, 0.3, 0.2), Vector3(0.0, 2.2, -3.6), "metal", 0.7, 0.4)
	var jet := CylinderMesh.new()
	jet.top_radius = 0.18
	jet.bottom_radius = 0.06
	jet.height = 2.6
	var jm := StandardMaterial3D.new()
	jm.albedo_color = Color(0.7, 0.85, 0.95, 0.5)
	jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var jmi := MeshInstance3D.new()
	jmi.mesh = jet
	jmi.material_override = jm
	jmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(h, jmi, "PipeJet", Vector3(0.0, 1.1, -3.0))
	jmi.rotation_degrees.x = 25.0
	# Освещение: лампы, фонари, холодное заполнение
	for p in [Vector3(-8, 3.4, 0), Vector3(0, 3.4, 5), Vector3(8, 3.4, 0), Vector3(0, 3.4, -1), Vector3(-9, 3.4, 8), Vector3(9, 3.4, 8)]:
		_bulb(h, p, 0.9)
	_lantern(h, Vector3(0.0, 0.9, -3.5), 0.9)
	_lantern(h, Vector3(-4.0, 0.9 + 0.0, -2.0), 0.0)
	for p in [Vector3(-7.0, 2.4, 4.0), Vector3(7.0, 2.4, 4.0), Vector3(0.0, 2.4, 9.0)]:
		var rl := OmniLight3D.new()
		rl.light_color = Color(0.55, 0.65, 0.95)
		rl.light_energy = 0.85
		rl.omni_range = 11.0
		U.add(h, rl, "RoomGlow", p)


# ---------- винный погреб ----------

func _wine() -> void:
	var w := _holder("Wine")
	# Своды и стеллажи с бутылками
	for k in 5:
		var x := -26.0 + k * 3.2
		_vb(w, "ArchTop%d" % k, Vector3(0.5, 0.4, 16.0), C_STONE.darkened(0.1), Vector3(x, 3.5, 2.0), "concrete")
	_sb(w, "RackN", Vector3(13.0, 2.4, 0.5), C_WOOD_D, Vector3(-21.0, 1.2, -5.6), "wood")
	_sb(w, "RackS", Vector3(13.0, 2.4, 0.5), C_WOOD_D, Vector3(-21.0, 1.2, 9.6), "wood")
	_sb(w, "RackW", Vector3(0.5, 2.4, 9.0), C_WOOD_D, Vector3(-27.6, 1.2, 2.0), "wood")
	for sx in [-27.2]:
		for r in 5:
			for j in 16:
				var cc := Color(0.1, 0.25, 0.15, 0.9) if (r + j) % 3 else Color(0.35, 0.12, 0.12, 0.9)
				_cyl(w, "Bottle", 0.06, 0.06, 0.32, cc, Vector3(sx + 0.05, 0.4 + r * 0.42, -2.0 + j * 0.45), "paint", 8).rotation_degrees.z = 90.0
	for k in 5:
		for j in 18:
			var cc2 := Color(0.1, 0.25, 0.15, 0.9) if (k + j) % 3 else Color(0.35, 0.12, 0.12, 0.9)
			_cyl(w, "BottleN", 0.06, 0.06, 0.32, cc2, Vector3(-26.0 + j * 0.7, 0.4 + k * 0.42, -5.3), "paint", 8).rotation_degrees.x = 90.0
	# Большие бочки вдоль южной стены
	for k in 5:
		var b := _cyl(w, "Cask%d" % k, 0.8, 0.8, 1.6, Color(0.45, 0.3, 0.18), Vector3(-26.0 + k * 2.4, 0.8, 8.5), "wood", 14, true)
		b.rotation_degrees.x = 90.0
	# Стол дегустации со свечами и креслом, ковёр
	_table(w, Vector3(-20.0, 0, 2.0), 2.4, 1.0, 0.8)
	_chair(w, Vector3(-20.0, 0, 3.0), 180.0)
	_chair(w, Vector3(-20.0, 0, 1.0), 0.0)
	_candle(w, Vector3(-20.4, 0.9, 2.0), 0.8)
	_candle(w, Vector3(-19.6, 0.9, 2.0), 0.8)
	_rug(w, Vector3(-20.0, 0, 2.0), 3.6, 2.6, Color(0.45, 0.15, 0.2))
	# Гнездо кота в глубине (средняя)
	var nest := _holder("NestWine", Vector3(-26.0, 0, 3.0))
	_vb(nest, "Blanket", Vector3(0.9, 0.06, 0.7), Color(0.55, 0.3, 0.4), Vector3(0, 0.04, 0), "paint", 1.0)
	_barrel(nest, Vector3(0.0, 0, 1.0))
	_candle(nest, Vector3(0.4, 0.0, -0.3), 0.7)
	for p in [Vector3(-18.0, 3.0, 2.0), Vector3(-24.0, 3.0, 2.0)]:
		_bulb(w, p, 0.8)
	for p in [Vector3(-20.0, 2.0, 2.0)]:
		var rl := OmniLight3D.new()
		rl.light_color = Color(0.55, 0.65, 0.95)
		rl.light_energy = 0.8
		rl.omni_range = 11.0
		U.add(w, rl, "RoomGlow", p)
	for k in 3:
		_web(w, Vector3(-27.6, 3.1, -4.0 + k * 5.0), 1.4, 90.0, 20.0)
	_slip_patch(w, Vector3(-16.0, 0.1, 4.0), 2)


func _slip_patch(parent: Node, pos: Vector3, tier: int) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/location/cellar/slip_zone.gd"))
	U.add(parent, a, "SlipPatch", pos + Vector3(0, 0.5, 0))
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(3.0, 1.2, 3.0))
	a.add_child(cs)
	_vb(a, "Slick", Vector3(3.0, 0.015, 3.0), Color(0.1, 0.15, 0.17, 0.7), Vector3(0, -0.49, 0), "paint", 0.02, 0.5)
	_hazard(a, tier)


# ---------- котельная ----------

func _vent(parent: Node, nm: String, pos: Vector3, yaw: float, push: Vector3, tier: int) -> void:
	var a := Area3D.new()
	a.set_script(load("res://scripts/location/cellar/steam_vent.gd"))
	a.set("push", push)
	U.add(parent, a, nm, pos + Vector3(0, 1.0, 0))
	a.rotation_degrees.y = yaw
	var cs := CollisionShape3D.new()
	cs.shape = _bshape(Vector3(2.4, 2.0, 2.4))
	a.add_child(cs)
	var jets := Node3D.new()
	U.add(a, jets, "Jets")
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.9, 0.92, 0.95, 0.35)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.emission_enabled = true
	sm.emission = Color(0.8, 0.85, 0.9)
	sm.emission_energy_multiplier = 0.3
	for k in 3:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.7 + k * 0.2
		cm.bottom_radius = 0.1
		cm.height = 2.6
		cm.radial_segments = 8
		var mi := MeshInstance3D.new()
		mi.mesh = cm
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		U.add(jets, mi, "Puff%d" % k, Vector3(0.0, 0.2 + k * 0.1, 0.0))
		mi.rotation_degrees.z = 70.0
		mi.position = Vector3(0.0, -0.1 + k * 0.25, 0.0) + Vector3(0, 0, 0)
	_hazard(a, tier)
	_vb(parent, nm + "Nozzle", Vector3(0.3, 0.3, 0.3), Color(0.35, 0.35, 0.38), pos + Vector3(0, 0.55, 0), "metal", 0.5, 0.5)


func _boiler() -> void:
	var b := _holder("Boiler")
	# Сам котёл: цилиндр с заклёпками, топка, дымоход, манометры
	var bo := _cyl(b, "Tank", 1.6, 1.6, 3.2, Color(0.35, 0.3, 0.28), Vector3(20.0, 1.6, 4.0), "metal", 20, true)
	for k in 3:
		_cyl(bo, "Ring%d" % k, 1.66, 1.66, 0.12, Color(0.2, 0.18, 0.17), Vector3(0, -1.0 + k * 1.0, 0), "metal", 20)
	_vb(b, "Firebox", Vector3(1.6, 1.2, 1.2), Color(0.2, 0.18, 0.17), Vector3(20.0, 0.6, 5.8), "metal", 0.6, 0.4)
	_vb(b, "FireDoor", Vector3(0.9, 0.8, 0.05), Color(0.06, 0.05, 0.05), Vector3(20.0, 0.6, 6.42), "metal")
	_glow(b, "Ember", 0.12, Color(1.0, 0.4, 0.1), Vector3(20.0, 0.4, 6.35), 2.5)
	_cyl(b, "Flue", 0.3, 0.3, 2.2, Color(0.25, 0.22, 0.2), Vector3(20.0, 4.1, 4.0), "metal", 10)
	for k in 3:
		U.sphere(b, "Gauge%d" % k, 0.18, Color(0.85, 0.85, 0.8), Vector3(18.8, 2.2 + k * 0.3, 3.3 + k * 0.3), 0.5)
	var fl := OmniLight3D.new()
	fl.set_script(load("res://scripts/location/forest/flicker.gd"))
	fl.set("base_energy", 1.6)
	fl.light_color = Color(1.0, 0.5, 0.2)
	fl.omni_range = 9.0
	U.add(b, fl, "FireLight", Vector3(20.0, 0.7, 7.0))
	# Трубы по потолку и стене
	for k in 3:
		U.rod(b, "Pipe%d" % k, Vector3(14.0, 4.6, 1.0 + k * 0.7), Vector3(25.6, 4.6, 1.0 + k * 0.7), 0.14, Color(0.5, 0.3, 0.2), 0.7, 0.4)
	U.rod(b, "Down", Vector3(20.0, 3.0, 4.0), Vector3(20.0, 4.6, 1.4), 0.2, Color(0.5, 0.3, 0.2), 0.7, 0.4)
	# Помост-галерея y=2.6 и пандус
	_slab_area(b, "Catwalk", [20.0, 25.8, 8.0, 13.8], [], 2.6, 0.3, Color(0.3, 0.3, 0.32), "metal")
	for p in [Vector3(20.2, 0, 8.2), Vector3(25.6, 0, 8.2), Vector3(20.2, 0, 13.6), Vector3(25.6, 0, 13.6)]:
		_vb(b, "CatwalkLeg", Vector3(0.2, 2.5, 0.2), C_STEEL, p + Vector3(0, 1.25, 0), "metal", 0.5, 0.4)
	for sz in [8.0, 13.8]:
		_vb(b, "CatwalkRail", Vector3(5.8, 0.06, 0.06), C_STEEL, Vector3(22.9, 3.6, sz), "metal")
	_vb(b, "CatwalkRailE", Vector3(0.06, 0.06, 5.8), C_STEEL, Vector3(25.8, 3.6, 10.9), "metal")
	_vb(b, "CatwalkRailW", Vector3(0.06, 0.06, 4.0), C_STEEL, Vector3(20.0, 3.6, 11.8), "metal")
	_slab(b, "CatwalkRamp", Vector3(15.0, 0.0, 12.8), Vector3(20.0, 2.6, 12.8), 1.8, Color(0.3, 0.3, 0.32))
	# Пар: тир 0 один, средняя и сложная больше
	_vent(b, "Vent1", Vector3(17.0, 0, 6.0), 0.0, Vector3(4.0, 3.0, 0.0), 0)
	_vent(b, "Vent2", Vector3(23.0, 0, 3.0), 180.0, Vector3(4.0, 3.0, 0.0), 1)
	_vent(b, "Vent3", Vector3(17.0, 0, 10.0), 0.0, Vector3(4.0, 3.0, 0.0), 2)
	# Бочки, ящик с углём, лопата, ведро
	_crate(b, Vector3(24.8, 0, 1.2), 1.0, 5.0)
	_barrel(b, Vector3(15.0, 0, 1.0))
	_barrel(b, Vector3(15.8, 0, 1.4))
	_vb(b, "Shovel", Vector3(0.1, 1.2, 0.02), C_WOOD, Vector3(25.6, 0.9, 6.0), "wood").rotation_degrees.z = 12.0
	_cyl(b, "Bucket", 0.18, 0.14, 0.3, Color(0.4, 0.4, 0.42), Vector3(24.6, 0.15, 6.2), "metal", 10)
	for p in [Vector3(16.0, 4.5, 6.0), Vector3(23.0, 4.7, 10.0), Vector3(23.0, 4.7, 2.0)]:
		_bulb(b, p, 0.7)


# ---------- угольная ----------

func _coal() -> void:
	var c := _holder("Coal")
	# Помост y=2.6 вдоль северной стены и куча-пандус к нему
	_slab_area(c, "CoalDeck", [8.5, 17.8, -15.8, -11.6], [], 2.6, 0.3, Color(0.12, 0.12, 0.13), "metal")
	for p in [Vector3(8.7, 0, -15.6), Vector3(17.6, 0, -15.6), Vector3(8.7, 0, -11.8), Vector3(17.6, 0, -11.8)]:
		_vb(c, "DeckLeg", Vector3(0.3, 2.5, 0.3), C_WOOD_D, p + Vector3(0, 1.25, 0), "wood")
	_slab(c, "CoalRamp", Vector3(13.0, 0.0, -5.8), Vector3(13.0, 2.6, -11.6), 2.4, Color(0.1, 0.1, 0.11), false)
	# Кучи угля вокруг пандуса, камни-куски
	for k in 70:
		var t := rng.randf()
		var p := Vector3(rng.randf_range(7.0, 17.0), 0.0, rng.randf_range(-15.0, -6.0))
		var near_ramp := absf(p.x - 13.0) < 1.8 and p.z > -11.6
		if near_ramp:
			continue
		var hgt := clampf((-6.0 - p.z) * 0.22, 0.0, 2.4)
		var sphere := U.sphere(c, "Coal%d" % k, rng.randf_range(0.3, 0.7), Color(0.05, 0.05, 0.06).lightened(rng.randf_range(0.0, 0.1)), p + Vector3(0, hgt * 0.5, 0), 0.7)
	for k in 40:
		var cp := Vector3(13.0 + rng.randf_range(-1.1, 1.1), 0, rng.randf_range(-11.4, -6.0))
		var h := (cp.z + 5.8) * -0.43
		U.sphere(c, "RampCoal%d" % k, rng.randf_range(0.08, 0.18), Color(0.05, 0.05, 0.06), cp + Vector3(0, clampf(h, 0, 2.6) + 0.05, 0), 0.7)
	# Жёлоб в стене и окошко
	_vb(c, "Chute", Vector3(1.6, 0.1, 5.0), Color(0.4, 0.4, 0.42), Vector3(13.0, 4.4, -13.5), "metal", 0.5, 0.4).rotation_degrees.x = -22.0
	_vb(c, "ChuteWall", Vector3(0.1, 0.9, 1.6), Color(0.4, 0.4, 0.42), Vector3(12.2, 4.8, -14.5), "metal")
	_vb(c, "Window", Vector3(1.2, 0.5, 0.05), Color(0.7, 0.8, 0.9, 0.5), Vector3(13.0, 4.7, -15.8), "paint", 0.1, 0.4)
	var wl := OmniLight3D.new()
	wl.light_color = Color(0.6, 0.7, 1.0)
	wl.light_energy = 0.9
	wl.omni_range = 9.0
	U.add(c, wl, "WindowLight", Vector3(13.0, 4.5, -14.5))
	# Гнездо кота на помосте (сложная)
	var nest := _holder("NestCoal", Vector3(14.0, 2.6, -14.5))
	_vb(nest, "Blanket", Vector3(0.9, 0.06, 0.7), Color(0.5, 0.35, 0.3), Vector3(0, 0.04, 0), "paint", 1.0)
	_crate(nest, Vector3(0.9, 0, 0.0), 0.6, 20.0)
	_lantern(nest, Vector3(0.9, 0.62, 0.0), 0.7)
	for p in [Vector3(10.0, 5.0, -9.0), Vector3(15.0, 5.0, -9.0)]:
		_bulb(c, p, 0.7)


# ---------- вода, крысы, таблички ----------

func _water_rise() -> void:
	var w := Node3D.new()
	w.set_script(load("res://scripts/location/cellar/rising_water.gd"))
	U.add(root_node, w, "Flood", Vector3(0, 0, 0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 40)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.2, 0.22, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.6
	m.roughness = 0.1
	m.normal_enabled = true
	var ntex := NoiseTexture2D.new()
	var nz := FastNoiseLite.new()
	nz.frequency = 0.03
	ntex.noise = nz
	ntex.as_normal_map = true
	ntex.seamless = true
	ntex.width = 256
	ntex.height = 256
	m.normal_texture = ntex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * 0.08
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	U.add(w, mi, "Surface", Vector3(-2.0, -0.25, -3.0))


func _rat(parent: Node, nm: String, path: Array, tier: int) -> void:
	var r := Node3D.new()
	r.set_script(load("res://scripts/location/cellar/rat.gd"))
	var pp := PackedVector3Array()
	for p in path:
		pp.append(p)
	r.set("path", pp)
	U.add(parent, r, nm, path[0])
	var fur := Color(0.28, 0.24, 0.22)
	U.sphere(r, "Body", 0.14, fur, Vector3(0, 0.12, 0), 0.8).scale = Vector3(0.7, 0.6, 1.5)
	U.sphere(r, "Head", 0.08, fur, Vector3(0, 0.14, 0.26))
	U.cyl(r, "Snout", 0.0, 0.05, 0.12, Color(0.8, 0.6, 0.6), Vector3(0, 0.12, 0.36), 6).rotation_degrees.x = 90.0
	for sg in [-1.0, 1.0]:
		U.sphere(r, "Ear", 0.04, Color(0.8, 0.6, 0.6), Vector3(sg * 0.06, 0.22, 0.2), 0.4)
		U.sphere(r, "Eye", 0.015, Color(0.9, 0.1, 0.1), Vector3(sg * 0.04, 0.17, 0.32))
	U.rod(r, "Tail", Vector3(0, 0.1, -0.24), Vector3(0.1, 0.04, -0.6), 0.02, Color(0.75, 0.55, 0.55))
	_hazard(r, tier)


func _rats() -> void:
	var r := _holder("Rats")
	_rat(r, "R1", [Vector3(-3.0, 0, -2.5), Vector3(3.0, 0, -2.5), Vector3(3.0, 0, 1.5), Vector3(-3.0, 0, 1.5)], 1)
	_rat(r, "R2", [Vector3(8.0, 0, 6.5), Vector3(-1.0, 0, 6.5)], 1)
	_rat(r, "R3", [Vector3(-20.0, 0, -4.0), Vector3(-16.0, 0, 8.0)], 1)
	_rat(r, "R4", [Vector3(16.0, 0, 6.0), Vector3(24.0, 0, 5.0), Vector3(22.0, 0, 1.5)], 1)
	_rat(r, "R5", [Vector3(10.0, 0, -6.0), Vector3(16.0, 0, -9.0), Vector3(8.0, 0, -9.0)], 2)
	_rat(r, "R6", [Vector3(-9.0, 0, 4.0), Vector3(-1.5, 0, 10.5)], 2)
	_rat(r, "R7", [Vector3(-26.0, 0, 0.0), Vector3(-18.0, 0, 0.0)], 2)
	_rat(r, "R8", [Vector3(5.0, 0, 10.5), Vector3(12.0, 0, 7.0)], 2)


func _signs() -> void:
	var s := _holder("Signs")
	var sg := _vb(s, "CellarSign", Vector3(2.2, 0.9, 0.06), Color(0.8, 0.75, 0.55), Vector3(-1.4, 4.6, 19.8), "wood")
	U.label(sg, "Text", "SIGN_CELLAR_NAME", Vector3(0, 0, 0.05), 0.09, Color(0.2, 0.1, 0.05))
	var w := _vb(s, "WineSign", Vector3(1.4, 0.7, 0.06), Color(0.55, 0.15, 0.2), Vector3(-13.6, 2.9, 4.0), "paint")
	w.rotation_degrees.y = 90.0
	U.label(w, "Text", "SIGN_CELLAR_WINE", Vector3(0, 0, 0.05), 0.12, Color(0.95, 0.85, 0.6))
	var b := _vb(s, "BoilerSign", Vector3(1.6, 0.8, 0.06), Color(0.85, 0.5, 0.2), Vector3(13.6, 2.9, 6.0), "paint")
	b.rotation_degrees.y = -90.0
	U.label(b, "Text", "SIGN_CELLAR_BOILER", Vector3(0, 0, 0.05), 0.1, Color(0.15, 0.05, 0.02))
	var c := _vb(s, "CoalSign", Vector3(1.0, 0.5, 0.06), Color(0.15, 0.15, 0.16), Vector3(11.0, 2.9, -3.8), "paint")
	U.label(c, "Text", "SIGN_CELLAR_COAL", Vector3(0, 0, 0.05), 0.12, Color(0.9, 0.9, 0.85))


func _cat() -> void:
	var spots := Node3D.new()
	U.add(root_node, spots, "CatSpots")
	var m0 := Marker3D.new()
	U.add(spots, m0, "Behind", Vector3(-12.0, 0.1, -3.1))
	m0.rotation_degrees.y = 0.0
	var m1 := Marker3D.new()
	U.add(spots, m1, "Wine", Vector3(-26.0, 0.1, 3.0))
	m1.rotation_degrees.y = 90.0
	var m2 := Marker3D.new()
	U.add(spots, m2, "CoalTop", Vector3(14.0, 2.7, -14.5))
	m2.rotation_degrees.y = 0.0
	CatBuilder.build(root_node, m0.position)


func _players_and_checkpoints() -> void:
	var holder := _holder("Players")
	var p := U.player(holder, SPAWN + Vector3(0, 0.6, 0))
	var hl := OmniLight3D.new()
	hl.name = "Flashlight"
	hl.light_color = Color(1.0, 0.92, 0.75)
	hl.light_energy = 0.9
	hl.omni_range = 7.0
	hl.omni_attenuation = 1.5
	hl.position = Vector3(0, 1.7, 0.2)
	p.add_child(hl)
	var cps := _holder("Checkpoints")
	U.checkpoint(cps, "Checkpoint0", 0, SPAWN + Vector3(1.5, 0, 0))
	U.checkpoint(cps, "Checkpoint1", 1, Vector3(22.8, 2.6, 11.0))
	U.checkpoint(cps, "Checkpoint2", 2, Vector3(11.0, 2.6, -13.0))
