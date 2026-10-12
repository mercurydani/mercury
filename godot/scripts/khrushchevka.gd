@tool
class_name Khrushchevka
extends StaticBody3D
## Процедурная панельная пятиэтажка («хрущёвка»).
## Длина по X, фасад с подъездами и балконами смотрит в +Z.
## Геометрия строится при загрузке, в сцене хранятся только параметры.

@export var sections: int = 3:
	set(v):
		sections = maxi(v, 1)
		_rebuild()
@export var floors: int = 5:
	set(v):
		floors = maxi(v, 1)
		_rebuild()
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		_rebuild()
@export var panel_color: Color = Color(0.78, 0.76, 0.7):
	set(v):
		panel_color = v
		_rebuild()

const COL_W := 3.0       # ширина «окна» (шаг панелей)
const COLS_PER_SECTION := 4
const FLOOR_H := 2.8
const DEPTH := 11.0
const PLINTH := 0.7

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rebuild()


func length() -> float:
	return sections * COLS_PER_SECTION * COL_W


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("generated"):
			remove_child(c)
			c.queue_free()
	_rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var L := length()
	var H := PLINTH + floors * FLOOR_H
	var dark := panel_color.darkened(0.25)
	# Цоколь, коробка, крыша с парапетом
	_box(st, Vector3(0, PLINTH * 0.5, 0), Vector3(L + 0.2, PLINTH, DEPTH + 0.2), Color(0.45, 0.42, 0.4))
	_box(st, Vector3(0, PLINTH + floors * FLOOR_H * 0.5, 0), Vector3(L, floors * FLOOR_H, DEPTH), panel_color)
	_box(st, Vector3(0, H + 0.05, 0), Vector3(L + 0.3, 0.1, DEPTH + 0.3), Color(0.35, 0.33, 0.33))
	for side in [-1.0, 1.0]:
		_box(st, Vector3(0, H + 0.35, side * (DEPTH * 0.5 + 0.1)), Vector3(L + 0.3, 0.6, 0.2), dark)
		_box(st, Vector3(side * (L * 0.5 + 0.1), H + 0.35, 0), Vector3(0.2, 0.6, DEPTH + 0.3), dark)
	# Швы панелей: горизонтальные по этажам, вертикальные по шагу окон
	for f in floors + 1:
		var y := PLINTH + f * FLOOR_H
		for side in [-1.0, 1.0]:
			_box(st, Vector3(0, y, side * (DEPTH * 0.5 + 0.02)), Vector3(L, 0.08, 0.05), dark)
	var cols := sections * COLS_PER_SECTION
	for c in cols + 1:
		var x := -L * 0.5 + c * COL_W
		for side in [-1.0, 1.0]:
			_box(st, Vector3(x, PLINTH + floors * FLOOR_H * 0.5, side * (DEPTH * 0.5 + 0.02)), Vector3(0.06, floors * FLOOR_H, 0.05), dark)
	# Окна, балконы, подъезды
	for c in cols:
		var x := -L * 0.5 + (c + 0.5) * COL_W
		var entrance := c % COLS_PER_SECTION == 1
		for f in floors:
			var y := PLINTH + f * FLOOR_H + FLOOR_H * 0.55
			for side in [-1.0, 1.0]:
				var front: bool = side > 0.0
				if front and entrance:
					if f == 0:
						continue
					# Окно лестничной клетки между этажами
					_window(st, Vector3(x, y - 0.6, side), Vector2(1.0, 0.8), false)
					continue
				_window(st, Vector3(x, y, side), Vector2(1.4, 1.3), true)
				if front and f > 0 and c % 2 == 0 and _rng.randf() < 0.7:
					_balcony(st, Vector3(x, PLINTH + f * FLOOR_H, DEPTH * 0.5))
		if entrance:
			_entrance(st, Vector3(x, 0, DEPTH * 0.5))
	# Мелочи на крыше: вентшахты и антенны
	for i in sections * 2:
		var x := -L * 0.5 + (i + 0.5) * L / (sections * 2)
		_box(st, Vector3(x, H + 0.5, _rng.randf_range(-2, 2)), Vector3(1.0, 1.0, 1.0), dark)
		if _rng.randf() < 0.6:
			_box(st, Vector3(x + 1.5, H + 1.3, _rng.randf_range(-3, 3)), Vector3(0.06, 2.6, 0.06), Color(0.3, 0.3, 0.3))
			_box(st, Vector3(x + 1.5, H + 2.3, 0), Vector3(1.2, 0.05, 0.05), Color(0.3, 0.3, 0.3))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mi.material_override = mat
	mi.set_meta("generated", true)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(L, H, DEPTH)
	cs.shape = bs
	cs.position = Vector3(0, H * 0.5, 0)
	cs.set_meta("generated", true)
	add_child(cs)


func _window(st: SurfaceTool, at: Vector3, size: Vector2, curtains: bool) -> void:
	var z := at.z * (DEPTH * 0.5 + 0.03)
	_box(st, Vector3(at.x, at.y, z), Vector3(size.x + 0.2, size.y + 0.2, 0.06), Color(0.93, 0.93, 0.9))
	var glass := Color(0.25, 0.32, 0.42)
	var r := _rng.randf()
	if curtains and r < 0.15:
		glass = Color(1.0, 0.85, 0.5)  # горит свет
	elif curtains and r < 0.4:
		glass = Color.from_hsv(_rng.randf(), 0.4, 0.75)  # шторы
	_box(st, Vector3(at.x, at.y, z + at.z * 0.03), Vector3(size.x, size.y, 0.06), glass)
	# Переплёт
	_box(st, Vector3(at.x, at.y, z + at.z * 0.06), Vector3(0.06, size.y, 0.03), Color(0.93, 0.93, 0.9))


func _balcony(st: SurfaceTool, base: Vector3) -> void:
	var w := 2.6
	var d := 1.1
	var zc := base.z + d * 0.5
	_box(st, Vector3(base.x, base.y, zc), Vector3(w, 0.15, d), Color(0.6, 0.58, 0.55))
	var rail: Color = [Color(0.55, 0.62, 0.7), Color(0.7, 0.45, 0.35), Color(0.62, 0.7, 0.55), Color(0.85, 0.85, 0.8)][_rng.randi() % 4]
	_box(st, Vector3(base.x, base.y + 0.55, base.z + d), Vector3(w, 1.0, 0.06), rail)
	_box(st, Vector3(base.x - w * 0.5, base.y + 0.55, zc), Vector3(0.06, 1.0, d), rail)
	_box(st, Vector3(base.x + w * 0.5, base.y + 0.55, zc), Vector3(0.06, 1.0, d), rail)
	if _rng.randf() < 0.35:
		# Застеклённый балкон
		_box(st, Vector3(base.x, base.y + 1.6, base.z + d), Vector3(w, 1.1, 0.05), Color(0.6, 0.7, 0.75))
		_box(st, Vector3(base.x, base.y + 2.2, zc), Vector3(w + 0.1, 0.08, d + 0.1), Color(0.5, 0.5, 0.5))


func _entrance(st: SurfaceTool, base: Vector3) -> void:
	_box(st, Vector3(base.x, PLINTH + 1.1, base.z + 0.04), Vector3(1.4, 2.2, 0.08), Color(0.45, 0.28, 0.18))
	_box(st, Vector3(base.x, PLINTH + 2.6, base.z + 0.8), Vector3(2.4, 0.15, 1.6), Color(0.55, 0.53, 0.5))
	_box(st, Vector3(base.x, PLINTH * 0.5, base.z + 0.9), Vector3(2.2, PLINTH, 1.8), Color(0.5, 0.48, 0.46))
	_box(st, Vector3(base.x, PLINTH * 0.25, base.z + 2.0), Vector3(2.2, PLINTH * 0.5, 0.5), Color(0.5, 0.48, 0.46))


func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s * 0.5
	var p := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z),
		c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z),
		c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z),
	]
	var faces := [[4, 5, 6, 7], [1, 0, 3, 2], [0, 4, 7, 3], [5, 1, 2, 6], [7, 6, 2, 3], [0, 1, 5, 4]]
	st.set_color(col)
	for f in faces:
		st.add_vertex(p[f[0]])
		st.add_vertex(p[f[2]])
		st.add_vertex(p[f[1]])
		st.add_vertex(p[f[0]])
		st.add_vertex(p[f[3]])
		st.add_vertex(p[f[2]])
