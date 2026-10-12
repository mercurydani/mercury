class_name VanMesh
extends RefCounted
## Фургон спасателей в духе «буханки»: обтекаемый кузов-лофт, белый с красной
## полосой, круглые фары, мигалки, багажник с лестницей, открытая боковая дверь
## со стеной инструментов. Перед смотрит в -Z, правый борт (+X) — дверь.

const W := 1.1         # половина ширины
const Y0 := 0.52       # низ кузова
const Y1 := 2.4        # крыша
const Z_FRONT := -2.45
const Z_REAR := 2.65
const WHITE := Color(0.95, 0.94, 0.9)
const RED := Color(0.8, 0.12, 0.12)
const DARK := Color(0.16, 0.16, 0.17)
const STRIPE := [1.05, 1.3]


static func build(gm: GeoMesh) -> void:
	_body(gm)
	_front(gm)
	_windows(gm)
	_side_door_and_tools(gm)
	_rear(gm)
	_roof(gm)
	for z in [-1.55, 1.8]:
		for sx in [-1.0, 1.0]:
			_wheel(gm, Vector3(sx * 0.98, 0.43, z), sx)


## Сечение кузова: скруглённый прямоугольник, точки против часовой (вид спереди).
static func _section() -> Array:
	var pts := []
	var rt := 0.5
	var rb := 0.14
	# правый борт снизу вверх (с точками на краях полосы — для чёткого цвета)
	for i in 5:
		var a := -PI * 0.5 + PI * 0.5 * i / 4.0
		pts.append(Vector2(W - rb + cos(a) * rb, Y0 + rb + sin(a) * rb))
	for y in [0.62, 0.64, STRIPE[0] - 0.01, STRIPE[0], STRIPE[1], STRIPE[1] + 0.01, 1.6]:
		pts.append(Vector2(W, y))
	for i in 7:
		var a := PI * 0.5 * i / 6.0
		pts.append(Vector2(W - rt + cos(a) * rt, Y1 - rt + sin(a) * rt))
	var n := pts.size()
	var res := pts.duplicate()
	for i in range(n - 1, -1, -1):
		res.append(Vector2(-pts[i].x, pts[i].y))
	return res


static func _color_at(y: float) -> Color:
	if y < 0.63:
		return DARK
	if y >= STRIPE[0] and y <= STRIPE[1]:
		return RED
	return WHITE


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, out: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.dot(out) > 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


static func _body(gm: GeoMesh) -> void:
	var st := gm.s("paint")
	var sec := _section()
	var stations := [[Z_FRONT, 0.86], [Z_FRONT + 0.05, 0.95], [Z_FRONT + 0.15, 0.99], [Z_FRONT + 0.3, 1.0], [Z_REAR - 0.15, 1.0], [Z_REAR - 0.05, 0.97], [Z_REAR, 0.92]]
	var ym := (Y0 + Y1) * 0.5
	var rings := []
	for s in stations:
		var ring := []
		for p in sec:
			ring.append(Vector3(p.x * s[1], ym + (p.y - ym) * s[1], s[0]))
		rings.append(ring)
	st.set_smooth_group(0)
	var n := sec.size()
	for i in rings.size() - 1:
		for j in n:
			var j2 := (j + 1) % n
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i + 1][j]
			var c: Vector3 = rings[i + 1][j2]
			var d: Vector3 = rings[i][j2]
			var out := ((a + c) * 0.5 - Vector3(0, ym, (a.z + c.z) * 0.5))
			_tri(st, a, b, c, _color_at(sec[j].y), _color_at(sec[j].y), _color_at(sec[j2].y), out)
			_tri(st, a, c, d, _color_at(sec[j].y), _color_at(sec[j2].y), _color_at(sec[j2].y), out)
	st.set_smooth_group(-1)
	# Торцы (плоские)
	for k in [0, rings.size() - 1]:
		var ring: Array = rings[k]
		var cz: float = ring[0].z
		var ctr := Vector3(0, ym, cz)
		var out := Vector3(0, 0, -1 if k == 0 else 1)
		for j in n:
			var j2 := (j + 1) % n
			var cj := DARK if sec[j].y < 0.63 else WHITE
			var cj2 := DARK if sec[j2].y < 0.63 else WHITE
			_tri(st, ctr, ring[j], ring[j2], WHITE, cj, cj2, out)
	# Полоса на задних дверях
	Geo.box(st, Vector3(0, 1.175, Z_REAR + 0.005), Vector3(1.9, 0.25, 0.01), RED)
	# Арки колёс и пороги
	for z in [-1.55, 1.8]:
		for sx in [-1.0, 1.0]:
			Babushka.ellip(gm.s("plain"), Vector3(sx * (W + 0.005), 0.52, z), Vector3(0.02, 0.5, 0.56), DARK)
	# Колпак-лапка на борту (логотип) — на левом борту и на двери справа
	for at in [Vector3(-W - 0.01, 0.84, 0.2)]:
		_paw_logo(gm, at, -1.0)


static func _paw_logo(gm: GeoMesh, at: Vector3, side: float) -> void:
	var pink := Color(0.95, 0.45, 0.55)
	var b := Basis(Vector3.UP, side * PI * 0.5)
	Babushka.ellip(gm.s("plain"), Vector3.ZERO, Vector3(0.1, 0.085, 0.012), pink, Transform3D(b, at))
	for i in 4:
		var a := -0.6 + i * 0.4
		var off := Vector3(sin(a) * 0.13, cos(a) * 0.11 + 0.02, 0)
		Babushka.ellip(gm.s("plain"), Vector3.ZERO, Vector3(0.035, 0.042, 0.01), pink, Transform3D(b, at + b * off))


static func _front(gm: GeoMesh) -> void:
	var z := Z_FRONT - 0.01
	var ch := gm.s("chrome")
	# Бампер
	Geo.cbox(ch, Vector3(0, 0.55, Z_FRONT - 0.1), Vector3(2.05, 0.16, 0.14), Color(0.8, 0.8, 0.82), 0.05)
	for sx in [-1.0, 1.0]:
		Geo.cbox(ch, Vector3(sx * 0.55, 0.5, Z_FRONT - 0.03), Vector3(0.1, 0.12, 0.12), Color(0.6, 0.6, 0.62), 0.02)
	# Круглые фары с хромом, поворотники
	for sx in [-1.0, 1.0]:
		var c := Vector3(sx * 0.66, 0.95, z)
		Geo.prism(ch, Vector3.ZERO, 0.17, 0.15, 0.05, Color(0.85, 0.85, 0.87), 20, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), c))
		Babushka.ellip(gm.s("lit_white"), c + Vector3(0, 0, -0.05), Vector3(0.135, 0.135, 0.04), Color(1, 1, 0.95))
		Babushka.ellip(gm.s("lit"), c + Vector3(sx * 0.26, -0.1, -0.01), Vector3(0.06, 0.04, 0.03), Color(1, 0.6, 0.1))
	# Решётка радиатора
	for i in 5:
		Geo.cbox(ch, Vector3(0, 0.78 + i * 0.07, z - 0.02), Vector3(0.7, 0.035, 0.04), Color(0.75, 0.75, 0.78), 0.01)
	# Номер
	Geo.cbox(gm.s("plain"), Vector3(0, 0.55, Z_FRONT - 0.18), Vector3(0.52, 0.12, 0.02), Color(0.95, 0.95, 0.95), 0.01)
	# Зеркала
	for sx in [-1.0, 1.0]:
		Geo.rod(ch, Vector3(sx * 1.0, 1.55, Z_FRONT + 0.4), Vector3(sx * 1.32, 1.7, Z_FRONT + 0.3), 0.015, Color(0.2, 0.2, 0.2), 5)
		Geo.cbox(gm.s("plain"), Vector3(sx * 1.35, 1.8, Z_FRONT + 0.3), Vector3(0.06, 0.24, 0.16), DARK, 0.03)


static func _windows(gm: GeoMesh) -> void:
	var gl := gm.s("glass")
	var dark := Color(0.15, 0.2, 0.25)
	# Лобовое стекло из двух половин
	for sx in [-1.0, 1.0]:
		Geo.cbox(gl, Vector3(sx * 0.43, 1.85, Z_FRONT - 0.005), Vector3(0.78, 0.6, 0.02), dark, 0.05)
	Geo.box(gm.s("plain"), Vector3(0, 1.85, Z_FRONT - 0.01), Vector3(0.06, 0.62, 0.02), DARK)
	# Дворники
	for sx in [-1.0, 1.0]:
		Geo.rod(gm.s("plain"), Vector3(sx * 0.1, 1.57, Z_FRONT - 0.02), Vector3(sx * 0.65, 1.75, Z_FRONT - 0.02), 0.01, DARK, 4)
	# Боковые окна
	for sx in [-1.0, 1.0]:
		var spans := [[-1.95, -1.25], [-0.95, 0.3], [0.55, 1.6], [1.85, 2.4]]
		for sp in spans:
			if sx > 0.0 and (sp[0] > -0.7 and sp[0] < 1.0 or sp[0] > 1.7):
				continue  # справа открытая дверь и сдвинутая створка
			var zc: float = (sp[0] + sp[1]) * 0.5
			var zl: float = sp[1] - sp[0]
			Geo.cbox(gl, Vector3(sx * (W + 0.005), 1.72, zc), Vector3(0.02, 0.5, zl), dark, 0.05)
			Geo.cbox(gm.s("plain"), Vector3(sx * (W + 0.002), 1.72, zc), Vector3(0.015, 0.56, zl + 0.06), DARK, 0.02)
	# Ручки дверей кабины
	for sx in [-1.0, 1.0]:
		Geo.cbox(gm.s("chrome"), Vector3(sx * (W + 0.02), 1.38, -1.35), Vector3(0.03, 0.04, 0.16), Color(0.8, 0.8, 0.82), 0.01)


static func _side_door_and_tools(gm: GeoMesh) -> void:
	var x := W + 0.008
	# Проём (тёмная рамка) и задняя стенка с инструментами
	var z0 := -0.6
	var z1 := 1.0
	var y0 := 0.64
	var y1 := 2.05
	Geo.box(gm.s("plain"), Vector3(x, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(0.01, y1 - y0 + 0.08, z1 - z0 + 0.08), Color(0.08, 0.08, 0.08))
	Geo.box(gm.s("wood"), Vector3(x + 0.006, (y0 + y1) * 0.5 + 0.02, (z0 + z1) * 0.5), Vector3(0.01, y1 - y0 - 0.08, z1 - z0 - 0.08), Color(0.72, 0.52, 0.32))
	Geo.box(gm.s("metal"), Vector3(x + 0.04, y0 + 0.02, (z0 + z1) * 0.5), Vector3(0.12, 0.05, z1 - z0), Color(0.5, 0.5, 0.52))
	var tx := x + 0.02
	var ch := gm.s("chrome")
	# Крючки
	for i in 5:
		Geo.rod(ch, Vector3(tx, 1.82, -0.45 + i * 0.33), Vector3(tx + 0.1, 1.86, -0.45 + i * 0.33), 0.012, Color(0.8, 0.8, 0.82), 5)
	# Сачок: шест, обод и сетка
	var f := gm.s("fabric")
	Geo.rod(gm.s("wood"), Vector3(tx + 0.05, 0.75, -0.45), Vector3(tx + 0.05, 1.6, -0.45), 0.02, Color(0.6, 0.42, 0.25), 6)
	ShopGoods._torus(ch, Vector3.ZERO, 0.17, 0.012, Color(0.8, 0.8, 0.82), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(tx + 0.05, 1.77, -0.45)), 16, 6)
	Babushka.ellip(f, Vector3(tx + 0.06, 1.7, -0.45), Vector3(0.04, 0.17, 0.15), Color(0.85, 0.85, 0.75))
	# Верёвка бухтой
	ShopGoods._torus(f, Vector3.ZERO, 0.13, 0.035, Color(0.85, 0.65, 0.3), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(tx + 0.05, 1.6, -0.12)), 16, 8)
	# Аптечка кота
	Geo.cbox(gm.s("plain"), Vector3(tx + 0.08, 1.3, 0.22), Vector3(0.16, 0.26, 0.34), Color(0.95, 0.95, 0.95), 0.03)
	Geo.box(gm.s("plain"), Vector3(tx + 0.165, 1.3, 0.22), Vector3(0.01, 0.16, 0.05), RED)
	Geo.box(gm.s("plain"), Vector3(tx + 0.165, 1.3, 0.22), Vector3(0.01, 0.05, 0.16), RED)
	# Фонарь
	Geo.prism(gm.s("plain"), Vector3.ZERO, 0.05, 0.05, 0.28, Color(0.95, 0.75, 0.1), 12, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(tx + 0.06, 1.62, 0.1)))
	Babushka.ellip(gm.s("lit_white"), Vector3(tx + 0.06, 1.62, 0.38), Vector3(0.05, 0.05, 0.02), Color(1, 1, 0.9))
	# Удочка с рыбкой
	Geo.rod(gm.s("wood"), Vector3(tx + 0.04, 0.8, 0.6), Vector3(tx + 0.04, 1.95, 0.75), 0.012, Color(0.3, 0.25, 0.2), 5)
	Geo.rod(gm.s("plain"), Vector3(tx + 0.05, 1.95, 0.75), Vector3(tx + 0.07, 1.5, 0.85), 0.003, Color(0.9, 0.9, 0.9), 3)
	Babushka.ellip(gm.s("plain"), Vector3(tx + 0.07, 1.45, 0.85), Vector3(0.025, 0.05, 0.08), Color(0.3, 0.6, 0.9))
	# Переноска на полу
	Geo.cbox(gm.s("plain"), Vector3(tx + 0.2, 0.86, 0.45), Vector3(0.36, 0.34, 0.45), Color(0.4, 0.7, 0.8), 0.05)
	for i in 5:
		Geo.box(ch, Vector3(tx + 0.385, 0.86, 0.29 + i * 0.08), Vector3(0.01, 0.24, 0.015), Color(0.8, 0.8, 0.82))
	Geo.rod(ch, Vector3(tx + 0.2, 1.05, 0.33), Vector3(tx + 0.2, 1.05, 0.57), 0.015, DARK, 5)
	# Сдвинутая назад створка двери (снаружи борта)
	var dz0 := 1.05
	var dz1 := 2.55
	var dx := W + 0.05
	var st := gm.s("paint")
	Geo.cbox(st, Vector3(dx, 0.85, (dz0 + dz1) * 0.5), Vector3(0.05, 0.4, dz1 - dz0), WHITE, 0.02)
	Geo.cbox(st, Vector3(dx, 1.175, (dz0 + dz1) * 0.5), Vector3(0.05, 0.25, dz1 - dz0), RED, 0.01)
	Geo.cbox(st, Vector3(dx, 1.4, (dz0 + dz1) * 0.5), Vector3(0.05, 0.2, dz1 - dz0), WHITE, 0.01)
	Geo.cbox(st, Vector3(dx, 1.98, (dz0 + dz1) * 0.5), Vector3(0.05, 0.1, dz1 - dz0), WHITE, 0.02)
	for zz in [dz0 + 0.05, dz1 - 0.05]:
		Geo.cbox(st, Vector3(dx, 1.72, zz), Vector3(0.05, 0.5, 0.1), WHITE, 0.01)
	Geo.cbox(gm.s("glass"), Vector3(dx, 1.72, (dz0 + dz1) * 0.5), Vector3(0.02, 0.5, dz1 - dz0 - 0.15), Color(0.15, 0.2, 0.25), 0.03)
	Geo.rod(gm.s("metal"), Vector3(W + 0.03, 2.08, -0.65), Vector3(W + 0.03, 2.08, 2.6), 0.02, Color(0.4, 0.4, 0.42), 6)
	Geo.cbox(gm.s("chrome"), Vector3(dx + 0.04, 1.35, dz0 + 0.12), Vector3(0.03, 0.04, 0.14), Color(0.8, 0.8, 0.82), 0.01)
	_paw_logo(gm, Vector3(dx + 0.03, 0.84, 1.8), 1.0)


static func _rear(gm: GeoMesh) -> void:
	var z := Z_REAR + 0.01
	Geo.box(gm.s("plain"), Vector3(0, 1.45, z), Vector3(0.02, 1.6, 0.01), DARK)
	for sx in [-1.0, 1.0]:
		Geo.cbox(gm.s("glass"), Vector3(sx * 0.42, 1.85, z), Vector3(0.6, 0.42, 0.02), Color(0.15, 0.2, 0.25), 0.04)
		Geo.cbox(gm.s("chrome"), Vector3(sx * 0.12, 1.35, z + 0.02), Vector3(0.04, 0.16, 0.03), Color(0.8, 0.8, 0.82), 0.01)
		Babushka.ellip(gm.s("lit_red"), Vector3(sx * 0.82, 0.95, z), Vector3(0.08, 0.13, 0.03), Color(1, 0.2, 0.15))
	Geo.cbox(gm.s("chrome"), Vector3(0, 0.55, Z_REAR + 0.1), Vector3(2.0, 0.15, 0.14), Color(0.8, 0.8, 0.82), 0.05)
	Geo.cbox(gm.s("metal"), Vector3(0, 0.38, Z_REAR + 0.25), Vector3(0.8, 0.05, 0.3), Color(0.35, 0.35, 0.37), 0.02)
	Geo.rod(gm.s("metal"), Vector3(-0.7, 0.35, Z_REAR - 0.2), Vector3(-0.7, 0.3, Z_REAR + 0.2), 0.04, DARK, 8)
	Geo.cbox(gm.s("plain"), Vector3(0, 0.75, z + 0.01), Vector3(0.52, 0.12, 0.02), Color(0.95, 0.95, 0.95), 0.01)


static func _roof(gm: GeoMesh) -> void:
	var m := gm.s("metal")
	# Багажник с лестницей
	for sx in [-1.0, 1.0]:
		Geo.rod(m, Vector3(sx * 0.85, Y1 + 0.12, -0.5), Vector3(sx * 0.85, Y1 + 0.12, 2.4), 0.025, DARK, 6)
		for z in [-0.4, 0.9, 2.3]:
			Geo.rod(m, Vector3(sx * 0.85, Y1 - 0.03, z), Vector3(sx * 0.85, Y1 + 0.12, z), 0.02, DARK, 5)
	for z in [-0.4, 0.9, 2.3]:
		Geo.rod(m, Vector3(-0.85, Y1 + 0.12, z), Vector3(0.85, Y1 + 0.12, z), 0.02, DARK, 5)
	var al := Color(0.78, 0.78, 0.8)
	for sx in [-1.0, 1.0]:
		Geo.rod(gm.s("chrome"), Vector3(sx * 0.3, Y1 + 0.17, -0.3), Vector3(sx * 0.3, Y1 + 0.17, 2.3), 0.025, al, 6)
	for i in 9:
		Geo.rod(gm.s("chrome"), Vector3(-0.3, Y1 + 0.17, -0.2 + i * 0.3), Vector3(0.3, Y1 + 0.17, -0.2 + i * 0.3), 0.015, al, 5)
	# Проблесковые маячки на перекладине
	Geo.cbox(gm.s("plain"), Vector3(0, Y1 + 0.05, -1.75), Vector3(1.5, 0.1, 0.32), DARK, 0.03)
	for sx in [-1.0, 1.0]:
		Babushka.ellip(gm.s("lit_red" if sx < 0 else "lit_blue"), Vector3(sx * 0.45, Y1 + 0.16, -1.75), Vector3(0.24, 0.12, 0.14), Color(1, 1, 1))
	Babushka.ellip(gm.s("lit_white"), Vector3(0, Y1 + 0.13, -1.75), Vector3(0.12, 0.07, 0.1), Color(1, 1, 1))
	# Вывеска-кот на крыше: голова с ушками и мордочкой
	var c := Vector3(0, Y1 + 0.75, -1.15)
	var o := Color(1.0, 0.62, 0.2)
	var st := gm.s("plain")
	Geo.rod(m, Vector3(-0.25, Y1, -1.15), c + Vector3(-0.25, -0.2, 0), 0.025, DARK, 5)
	Geo.rod(m, Vector3(0.25, Y1, -1.15), c + Vector3(0.25, -0.2, 0), 0.025, DARK, 5)
	Babushka.ellip(st, c, Vector3(0.48, 0.38, 0.12), o)
	for sx in [-1.0, 1.0]:
		Geo.prism(st, Vector3.ZERO, 0.17, 0.0, 0.26, o, 10, Transform3D(Basis(Vector3.BACK, -sx * 0.35).scaled(Vector3(1, 1, 0.5)), c + Vector3(sx * 0.27, 0.25, 0)))
		Geo.prism(st, Vector3.ZERO, 0.09, 0.0, 0.16, Color(1, 0.7, 0.75), 10, Transform3D(Basis(Vector3.BACK, -sx * 0.35).scaled(Vector3(1, 1, 0.3)), c + Vector3(sx * 0.27, 0.27, -0.05)))
		for zs in [-1.0, 1.0]:
			Babushka.ellip(st, c + Vector3(sx * 0.16, 0.06, zs * 0.11), Vector3(0.06, 0.08, 0.02), Color(0.1, 0.1, 0.1))
			Babushka.ellip(st, c + Vector3(sx * 0.16 + 0.02, 0.09, zs * 0.125), Vector3(0.02, 0.02, 0.008), Color(1, 1, 1))
			for k in 3:
				Geo.rod(st, c + Vector3(sx * 0.22, -0.08 + k * 0.04, zs * 0.12), c + Vector3(sx * 0.5, -0.1 + k * 0.06, zs * 0.12), 0.006, Color(0.15, 0.1, 0.05), 3)
	for zs in [-1.0, 1.0]:
		Babushka.ellip(st, c + Vector3(0, -0.05, zs * 0.12), Vector3(0.05, 0.035, 0.015), Color(1, 0.5, 0.6))
		for sx in [-1.0, 1.0]:
			Geo.rod(st, c + Vector3(0, -0.09, zs * 0.122), c + Vector3(sx * 0.07, -0.13, zs * 0.122), 0.008, Color(0.2, 0.1, 0.05), 4)


static func _wheel(gm: GeoMesh, c: Vector3, side: float) -> void:
	var rot := Basis(Vector3.BACK, PI * 0.5)  # ось цилиндра вдоль -X
	var tire := Color(0.12, 0.12, 0.12)
	var t := gm.s("plain")
	t.set_smooth_group(0)
	Geo.prism(t, Vector3.ZERO, 0.43, 0.43, 0.28, tire, 24, Transform3D(rot, c + Vector3(0.14, 0, 0)), false)
	t.set_smooth_group(-1)
	Geo.prism(t, Vector3.ZERO, 0.4, 0.4, 0.3, tire.lightened(0.05), 24, Transform3D(rot, c + Vector3(0.15, 0, 0)))
	# Протектор
	for i in 24:
		var a := TAU * i / 24.0
		var p := c + Vector3(0, cos(a) * 0.43, sin(a) * 0.43)
		Geo.box(t, Vector3.ZERO, Vector3(0.24, 0.03, 0.05), tire.darkened(0.3), Transform3D(Basis(Vector3.RIGHT, -a), p))
	# Колпак и гайки
	var o := c + Vector3(side * 0.15, 0, 0)
	Geo.prism(gm.s("chrome"), Vector3.ZERO, 0.25, 0.2, 0.04, Color(0.88, 0.88, 0.9), 20, Transform3D(Basis(Vector3.BACK, -side * PI * 0.5), o))
	Babushka.ellip(gm.s("chrome"), o + Vector3(side * 0.045, 0, 0), Vector3(0.03, 0.08, 0.08), Color(0.7, 0.7, 0.72))
	for i in 5:
		var a := TAU * i / 5.0
		Babushka.ellip(gm.s("plain"), o + Vector3(side * 0.04, cos(a) * 0.14, sin(a) * 0.14), Vector3(0.015, 0.02, 0.02), Color(0.3, 0.3, 0.3), Transform3D.IDENTITY, 4, 6)
