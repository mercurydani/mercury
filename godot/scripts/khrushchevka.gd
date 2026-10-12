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
@export var porch_lights: bool = true:
	set(v):
		porch_lights = v
		_rebuild()

const COL_W := 3.0
const COLS_PER_SECTION := 4
const FLOOR_H := 2.8
const DEPTH := 11.0
const PLINTH := 0.8

var _rng := RandomNumberGenerator.new()
var _g: GeoMesh
var _lit: SurfaceTool
var _metal: SurfaceTool
var _glass: SurfaceTool
var _plain: SurfaceTool
var _wood: SurfaceTool
var _fabric: SurfaceTool


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
	_g = GeoMesh.new()
	var st := _g.s("concrete")
	_lit = _g.s("lit")
	_metal = _g.s("metal")
	_glass = _g.s("glass")
	_plain = _g.s("plain")
	_wood = _g.s("wood")
	_fabric = _g.s("fabric")
	var L := length()
	var top := PLINTH + floors * FLOOR_H
	var seam := panel_color.darkened(0.35)
	var cols := sections * COLS_PER_SECTION

	# Несущая коробка (видна в швах между панелями) и цоколь
	Geo.box(st, Vector3(0, top * 0.5, 0), Vector3(L - 0.02, top, DEPTH - 0.02), seam)
	Geo.cbox(st, Vector3(0, PLINTH * 0.5, 0), Vector3(L + 0.25, PLINTH, DEPTH + 0.25), Color(0.42, 0.4, 0.38), 0.04)

	for side in [-1.0, 1.0]:
		var zf: float = side * DEPTH * 0.5
		var front: bool = side > 0.0
		# Панели фасада: свой оттенок у каждой, грязнее у земли
		for c in cols:
			var x := -L * 0.5 + (c + 0.5) * COL_W
			var entrance := front and c % COLS_PER_SECTION == 1
			for f in floors:
				var y := PLINTH + f * FLOOR_H + FLOOR_H * 0.5
				var tint := panel_color.darkened(_rng.randf_range(-0.04, 0.08))
				tint = tint.lerp(Color(0.42, 0.38, 0.32), clampf(0.35 - f * 0.12, 0.0, 0.35) + _rng.randf_range(0.0, 0.06))
				Geo.cbox(st, Vector3(x, y, zf + side * 0.06), Vector3(COL_W - 0.07, FLOOR_H - 0.07, 0.12), tint, 0.025)
				if entrance and f == 0:
					continue
				if entrance:
					_window(Vector3(x, y - 0.75, zf + side * 0.12), side, Vector2(1.0, 0.8), st, false)
				else:
					_window(Vector3(x, y + 0.1, zf + side * 0.12), side, Vector2(1.45, 1.35), st, true)
					if front and f > 0 and c % 2 == 0 and _rng.randf() < 0.75:
						_balcony(st, Vector3(x, PLINTH + f * FLOOR_H, zf + 0.12))
					elif _rng.randf() < 0.08:
						# Кондиционер под окном
						Geo.cbox(_metal, Vector3(x + 0.5, y - 0.75, zf + side * 0.38), Vector3(0.8, 0.5, 0.3), Color(0.9, 0.9, 0.88), 0.06)
						for k in 6:
							Geo.box(_metal, Vector3(x + 0.25 + k * 0.08, y - 0.75, zf + side * 0.54), Vector3(0.03, 0.4, 0.02), Color(0.6, 0.6, 0.6))
			if entrance:
				_entrance(st, x, zf)
			# Продухи в цоколе
			if not entrance:
				Geo.box(_plain, Vector3(x, PLINTH * 0.45, zf + side * 0.13), Vector3(0.6, 0.3, 0.02), Color(0.08, 0.08, 0.08))
	# Торцы: глухие панели
	for sx in [-1.0, 1.0]:
		for f in floors:
			for k in 4:
				var z := -DEPTH * 0.5 + (k + 0.5) * DEPTH / 4.0
				var tint := panel_color.darkened(_rng.randf_range(0.0, 0.1))
				Geo.cbox(st, Vector3(sx * (L * 0.5 + 0.05), PLINTH + (f + 0.5) * FLOOR_H, z), Vector3(0.12, FLOOR_H - 0.07, DEPTH / 4.0 - 0.07), tint, 0.025)
	# Водосточные трубы
	for i in sections + 1:
		var x := -L * 0.5 + i * COLS_PER_SECTION * COL_W + (0.4 if i == 0 else -0.4)
		for side in [-1.0, 1.0]:
			var z: float = side * (DEPTH * 0.5 + 0.25)
			Geo.rod(_metal, Vector3(x, 0.1, z), Vector3(x, top + 0.2, z), 0.07, Color(0.5, 0.5, 0.52), 12)
			for k in floors:
				Geo.prism(_metal, Vector3(x, PLINTH + k * FLOOR_H + 0.4, z), 0.085, 0.085, 0.08, Color(0.42, 0.42, 0.44), 12)
			Geo.prism(_metal, Vector3(x, top - 0.1, z), 0.1, 0.2, 0.3, Color(0.5, 0.5, 0.52), 12)
	# Крыша: карниз, парапет, выходы, вентшахты, антенны
	Geo.cbox(_g.s("asphalt"), Vector3(0, top + 0.08, 0), Vector3(L + 0.4, 0.16, DEPTH + 0.4), Color(0.75, 0.72, 0.72), 0.04)
	for side in [-1.0, 1.0]:
		Geo.cbox(st, Vector3(0, top + 0.4, side * (DEPTH * 0.5 + 0.1)), Vector3(L + 0.4, 0.5, 0.22), seam, 0.04)
		Geo.cbox(st, Vector3(side * (L * 0.5 + 0.1), top + 0.4, 0), Vector3(0.22, 0.5, DEPTH + 0.4), seam, 0.04)
	for s in sections:
		var x := -L * 0.5 + (s * COLS_PER_SECTION + 1.5) * COL_W
		Geo.cbox(st, Vector3(x, top + 1.1, -1.5), Vector3(2.2, 2.0, 2.2), seam, 0.05)
		Geo.cbox(_metal, Vector3(x, top + 2.15, -1.5), Vector3(2.5, 0.12, 2.5), Color(0.45, 0.45, 0.45), 0.03)
		Geo.cbox(st, Vector3(x + 3.5, top + 0.6, 2.0), Vector3(0.9, 0.9, 0.9), seam, 0.05)
		if _rng.randf() < 0.8:
			var ax := x + _rng.randf_range(-2, 4)
			var az := _rng.randf_range(-3, 3)
			Geo.rod(_metal, Vector3(ax, top, az), Vector3(ax, top + 3.0, az), 0.035, Color(0.3, 0.3, 0.32))
			for k in 3:
				var yy := top + 1.8 + k * 0.45
				Geo.rod(_metal, Vector3(ax - 0.6 + k * 0.1, yy, az), Vector3(ax + 0.6 - k * 0.1, yy, az), 0.02, Color(0.3, 0.3, 0.32), 6)
	# Сборка: все поверхности в одном меше, у каждой свой материал
	var mi := MeshInstance3D.new()
	mi.mesh = _g.build()
	mi.set_meta("generated", true)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(L, top, DEPTH)
	cs.shape = bs
	cs.position = Vector3(0, top * 0.5, 0)
	cs.set_meta("generated", true)
	add_child(cs)


func _window(at: Vector3, side: float, size: Vector2, st: SurfaceTool, can_light: bool) -> void:
	var plastic := _rng.randf() < 0.35
	var fst := _plain if plastic else _wood
	var frame := Color(0.95, 0.95, 0.93) if plastic else Color(0.72, 0.6, 0.45).lerp(Color(0.9, 0.88, 0.82), _rng.randf())
	var z := at.z
	var fw := 0.09
	# Откосы (глубина проёма) и рама с переплётом и форточкой
	Geo.box(st, Vector3(at.x, at.y, z - side * 0.07), Vector3(size.x + 0.16, size.y + 0.16, 0.02), panel_color.darkened(0.45))
	Geo.cbox(fst, Vector3(at.x, at.y + size.y * 0.5, z), Vector3(size.x + fw, fw, 0.1), frame, 0.015)
	Geo.cbox(fst, Vector3(at.x, at.y - size.y * 0.5, z), Vector3(size.x + fw, fw, 0.1), frame, 0.015)
	Geo.cbox(fst, Vector3(at.x - size.x * 0.5, at.y, z), Vector3(fw, size.y, 0.1), frame, 0.015)
	Geo.cbox(fst, Vector3(at.x + size.x * 0.5, at.y, z), Vector3(fw, size.y, 0.1), frame, 0.015)
	Geo.cbox(fst, Vector3(at.x - size.x * 0.1, at.y, z), Vector3(0.06, size.y, 0.08), frame, 0.01)
	Geo.cbox(fst, Vector3(at.x + size.x * 0.2, at.y + size.y * 0.22, z), Vector3(size.x * 0.6, 0.05, 0.08), frame, 0.01)
	# Отлив под окном
	Geo.cbox(_metal, Vector3(at.x, at.y - size.y * 0.5 - 0.06, z + side * 0.08), Vector3(size.x + 0.2, 0.04, 0.24), Color(0.6, 0.61, 0.63), 0.01)
	var gz := z - side * 0.03
	var r := _rng.randf()
	if can_light and r < 0.22:
		Geo.box(_lit, Vector3(at.x, at.y, gz - side * 0.02), Vector3(size.x, size.y, 0.02), Color(1.0, 0.78, 0.45))
	elif can_light and r < 0.5:
		var curtain := Color.from_hsv(_rng.randf(), _rng.randf_range(0.25, 0.5), _rng.randf_range(0.5, 0.8))
		# Шторы складками за стеклом
		for k in 6:
			Geo.box(_fabric, Vector3(at.x - size.x * 0.5 + (k + 0.5) * size.x / 6.0, at.y, gz - side * (0.05 + 0.02 * (k % 2))), Vector3(size.x / 6.0, size.y, 0.02), curtain.darkened(0.12 * (k % 2)))
		Geo.box(_glass, Vector3(at.x, at.y, gz), Vector3(size.x, size.y, 0.015), Color(0.55, 0.62, 0.7))
	else:
		Geo.box(_plain, Vector3(at.x, at.y, gz - side * 0.06), Vector3(size.x, size.y, 0.02), Color(0.08, 0.09, 0.11))
		Geo.box(_glass, Vector3(at.x, at.y, gz), Vector3(size.x, size.y, 0.015), Color(0.45, 0.55, 0.65))


func _balcony(st: SurfaceTool, base: Vector3) -> void:
	var w := 2.7
	var d := 1.05
	var zc := base.z + d * 0.5
	Geo.cbox(st, Vector3(base.x, base.y, zc), Vector3(w, 0.16, d), Color(0.58, 0.56, 0.53), 0.03)
	var glazed := _rng.randf() < 0.35
	var kind := _rng.randi() % 3
	var paint := [Color(0.42, 0.55, 0.62), Color(0.62, 0.36, 0.28), Color(0.5, 0.6, 0.42), Color(0.78, 0.76, 0.7)][_rng.randi() % 4] as Color
	var front_z := base.z + d - 0.03
	if kind == 0:
		# Решётка из прутьев
		var n := 16
		for i in n + 1:
			var x := base.x - w * 0.5 + i * w / n
			Geo.rod(_metal, Vector3(x, base.y + 0.08, front_z), Vector3(x, base.y + 1.05, front_z), 0.015, Color(0.25, 0.25, 0.27), 6)
		for i in 6:
			var z := base.z + i * d / 6.0
			for sx in [-1.0, 1.0]:
				var x: float = base.x + sx * (w * 0.5 - 0.02)
				Geo.rod(_metal, Vector3(x, base.y + 0.08, z), Vector3(x, base.y + 1.05, z), 0.015, Color(0.25, 0.25, 0.27), 6)
	else:
		# Крашеный лист в полоску
		var stripes := 9
		for i in stripes:
			var c := paint.darkened(0.12 if i % 2 == 0 else 0.0)
			Geo.cbox(_metal, Vector3(base.x - w * 0.5 + (i + 0.5) * w / stripes, base.y + 0.58, front_z), Vector3(w / stripes, 0.9, 0.03), c, 0.012)
		for sx in [-1.0, 1.0]:
			Geo.box(_metal, Vector3(base.x + sx * (w * 0.5 - 0.02), base.y + 0.58, zc), Vector3(0.03, 0.9, d), paint.darkened(0.06))
	# Поручень
	Geo.rod(_metal, Vector3(base.x - w * 0.5, base.y + 1.08, front_z), Vector3(base.x + w * 0.5, base.y + 1.08, front_z), 0.035, Color(0.3, 0.3, 0.32), 10)
	if glazed:
		var fc := Color(0.85, 0.85, 0.82)
		for i in 5:
			var x := base.x - w * 0.5 + i * w / 4.0
			Geo.cbox(_plain, Vector3(x, base.y + 1.75, front_z), Vector3(0.06, 1.3, 0.06), fc, 0.01)
		Geo.box(_glass, Vector3(base.x, base.y + 1.75, front_z - 0.01), Vector3(w, 1.3, 0.02), Color(0.45, 0.55, 0.6))
		Geo.cbox(_metal, Vector3(base.x, base.y + 2.45, zc), Vector3(w + 0.1, 0.08, d + 0.1), Color(0.5, 0.5, 0.5), 0.02)
	elif _rng.randf() < 0.35:
		# Бельё на верёвке
		var y := base.y + 1.9
		Geo.rod(_plain, Vector3(base.x - w * 0.5, y, zc), Vector3(base.x + w * 0.5, y, zc), 0.008, Color(0.9, 0.9, 0.9), 4)
		for i in 4:
			var cloth := Color.from_hsv(_rng.randf(), 0.5, 0.9)
			Geo.cbox(_fabric, Vector3(base.x - 0.9 + i * 0.6, y - 0.3, zc), Vector3(0.4, 0.55, 0.02), cloth, 0.008)


func _entrance(st: SurfaceTool, x: float, zf: float) -> void:
	var z := zf + 0.12
	# Крыльцо со ступенями
	Geo.cbox(st, Vector3(x, PLINTH * 0.5, z + 0.9), Vector3(2.4, PLINTH, 1.8), Color(0.55, 0.53, 0.5), 0.04)
	for i in 2:
		var sh := PLINTH * (2 - i) / 3.0
		Geo.cbox(st, Vector3(x, sh * 0.5, z + 1.95 + i * 0.3), Vector3(2.4, sh, 0.3), Color(0.52, 0.5, 0.47), 0.03)
	# Дверь в раме, домофон
	Geo.cbox(_metal, Vector3(x, PLINTH + 1.1, z + 0.02), Vector3(1.5, 2.3, 0.06), Color(0.3, 0.3, 0.3), 0.02)
	Geo.cbox(_metal, Vector3(x, PLINTH + 1.05, z + 0.06), Vector3(1.3, 2.1, 0.06), Color(0.3, 0.45, 0.36), 0.02)
	Geo.rod(_metal, Vector3(x + 0.45, PLINTH + 0.85, z + 0.12), Vector3(x + 0.45, PLINTH + 1.15, z + 0.12), 0.02, Color(0.75, 0.75, 0.75), 8)
	Geo.cbox(_metal, Vector3(x + 0.85, PLINTH + 1.3, z + 0.03), Vector3(0.18, 0.28, 0.04), Color(0.25, 0.25, 0.27), 0.015)
	# Козырёк на столбиках
	Geo.cbox(st, Vector3(x, PLINTH + 2.65, z + 0.95), Vector3(2.7, 0.14, 1.9), Color(0.5, 0.48, 0.46), 0.04)
	for sx in [-1.0, 1.0]:
		Geo.rod(_metal, Vector3(x + sx * 1.15, PLINTH, z + 1.75), Vector3(x + sx * 1.15, PLINTH + 2.6, z + 1.75), 0.05, Color(0.35, 0.35, 0.36), 12)
	# Фонарь над дверью
	Geo.cbox(_lit, Vector3(x, PLINTH + 2.45, z + 0.15), Vector3(0.3, 0.18, 0.18), Color(1.0, 0.85, 0.55), 0.04)
	if porch_lights:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.4)
		l.light_energy = 1.4
		l.omni_range = 6.0
		l.position = Vector3(x, PLINTH + 2.3, z + 0.6)
		l.set_meta("generated", true)
		add_child(l)
