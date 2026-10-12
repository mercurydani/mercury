@tool
class_name Babushka
extends Node3D
## Баб Нюра — продавщица ларька. Пухленькая бабушка в платке в горошек,
## круглых очках, вязаной кофте и пуховой шали; вяжет шапочку для кота.
## Геометрия строится процедурно (гладкие эллипсоиды и «трубки»),
## анимация: вязание, дыхание, моргание, взгляд на ближайшего игрока.

const SKIN := Color(0.97, 0.78, 0.66)
const SCARF := Color(0.78, 0.12, 0.16)
const CARDIGAN := Color(0.62, 0.42, 0.22)
const SKIRT := Color(0.25, 0.2, 0.3)
const SHAWL := Color(0.72, 0.7, 0.68)
const HAIR := Color(0.85, 0.85, 0.85)
const NECK_Y := 1.41

var _head: Node3D
var _eyes: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _knit: Node3D
var _torso: Node3D
var _t := 0.0
var _blink := 3.0
var _yaw := 0.0
var _pitch := 0.25


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		if c.has_meta("generated"):
			remove_child(c)
			c.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_torso = _part(self, "Torso", Vector3.ZERO, _build_body(rng))
	_head = _part(self, "Head", Vector3(0, NECK_Y, 0.03), _build_head(rng))
	_head.scale = Vector3.ONE * 1.3
	_head.set_meta("base_scale", 1.3)
	_eyes = _part(_head, "Eyes", Vector3(0, 0.175, 0.17), _build_eyes())
	_arm_l = _part(self, "ArmL", Vector3(0.3, 1.24, 0.0), _build_arm(-1.0))
	_arm_r = _part(self, "ArmR", Vector3(-0.3, 1.24, 0.0), _build_arm(1.0))
	_knit = _part(self, "Knitting", Vector3(0, 1.0, 0.36), _build_knitting(rng))
	_part(self, "Yarn", Vector3.ZERO, _build_yarn())


func _part(parent: Node3D, nm: String, pos: Vector3, mesh: ArrayMesh) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = nm
	pivot.position = pos
	pivot.set_meta("generated", true)
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	pivot.add_child(mi)
	return pivot


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _head == null:
		return
	_t += delta
	# Дыхание
	_torso.scale = Vector3(1.0, 1.0 + sin(_t * 1.6) * 0.008, 1.0 + sin(_t * 1.6) * 0.012)
	# Вязание: руки ходят навстречу друг другу
	var k := sin(_t * 7.0)
	_arm_l.rotation = Vector3(k * 0.05, 0, k * 0.03)
	_arm_r.rotation = Vector3(-k * 0.05, 0, k * 0.03)
	_knit.position.y = 1.0 + k * 0.012
	_knit.rotation.z = k * 0.06
	# Взгляд: на ближайшего игрока поблизости, иначе — на вязание
	var target_yaw := sin(_t * 0.4) * 0.15
	var target_pitch := 0.3
	var best := 7.0
	for p in get_tree().get_nodes_in_group("players"):
		var lp := to_local((p as Node3D).global_position + Vector3(0, 1.2, 0))
		var d := lp.length()
		if d < best:
			best = d
			target_yaw = clampf(atan2(lp.x, lp.z), -0.7, 0.7)
			target_pitch = clampf(-atan2(lp.y - NECK_Y, Vector2(lp.x, lp.z).length()), -0.3, 0.35)
	_yaw = lerpf(_yaw, target_yaw, delta * 3.0)
	_pitch = lerpf(_pitch, target_pitch, delta * 3.0)
	_head.rotation = Vector3(_pitch, _yaw, sin(_t * 0.9) * 0.04)
	# Моргание
	_blink -= delta
	var open := 1.0
	if _blink < 0.12:
		open = 0.1
	if _blink < 0.0:
		_blink = randf_range(2.5, 5.0)
	_eyes.scale = Vector3(1, open, 1)


# --- Геометрия ---------------------------------------------------------------

## Гладкий эллипсоид без пятен (для кожи и ткани).
static func ellip(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, xf := Transform3D.IDENTITY, rings := 12, segs := 18) -> void:
	st.set_smooth_group(0)
	st.set_color(col)
	var v := []
	for i in rings + 1:
		var phi := PI * i / rings
		var row := []
		for j in segs:
			var th := TAU * j / segs
			row.append(c + Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * r)
		v.append(row)
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			Geo.poly(st, [v[i][j], v[i + 1][j], v[i + 1][j2], v[i][j2]] if i > 0 and i < rings - 1 else ([v[0][j], v[1][j], v[1][j2]] if i == 0 else [v[i][j], v[i + 1][j], v[i][j2]]), c, xf)
	st.set_smooth_group(-1)


## Сужающаяся «трубка» от a к b со скруглёнными концами (руки, пальцы).
static func limb(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, col: Color, n := 14) -> void:
	var dir := b - a
	var length := dir.length()
	var y := dir / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	st.set_smooth_group(0)
	Geo.prism(st, Vector3.ZERO, ra, rb, length, col, n, Transform3D(Basis(x, y, z), a), false)
	st.set_smooth_group(-1)
	ellip(st, a, Vector3.ONE * ra, col, Transform3D.IDENTITY, 8, n)
	ellip(st, b, Vector3.ONE * rb, col, Transform3D.IDENTITY, 8, n)


func _build_body(rng: RandomNumberGenerator) -> ArrayMesh:
	var g := GeoMesh.new()
	var f := g.s("fabric")
	# Валенки
	for sx in [-1.0, 1.0]:
		ellip(f, Vector3(sx * 0.13, 0.08, 0.06), Vector3(0.1, 0.09, 0.15), Color(0.35, 0.3, 0.28))
	# Длинная юбка-колокол с подолом
	f.set_smooth_group(0)
	Geo.prism(f, Vector3(0, 0.1, 0), 0.43, 0.36, 0.72, SKIRT, 28, Transform3D.IDENTITY, false)
	f.set_smooth_group(-1)
	Geo.prism(f, Vector3(0, 0.08, 0), 0.44, 0.44, 0.06, SKIRT.darkened(0.25), 28)
	# Туловище: пухлое, с животиком
	ellip(f, Vector3(0, 1.0, 0), Vector3(0.35, 0.4, 0.29), CARDIGAN)
	ellip(f, Vector3(0, 0.88, 0.07), Vector3(0.32, 0.26, 0.25), CARDIGAN)
	# Вязаная фактура кофты: вертикальные «косы»
	for i in 7:
		var ang := -0.9 + i * 0.3
		for k in 6:
			var y := 0.72 + k * 0.08
			var rr := 0.33 * sqrt(maxf(0.0, 1.0 - pow((y - 0.95) / 0.42, 2.0)))
			ellip(f, Vector3(sin(ang) * rr, y, cos(ang) * rr * 0.92), Vector3(0.022, 0.035, 0.012), CARDIGAN.lightened(0.1), Transform3D.IDENTITY, 4, 6)
	# Фартук в цветочек на животе
	var ap := g.s("plain")
	ellip(ap, Vector3(0, 0.82, 0.25), Vector3(0.24, 0.2, 0.05), Color(0.95, 0.93, 0.88))
	for i in 9:
		var p := Vector3(rng.randf_range(-0.17, 0.17), rng.randf_range(0.7, 0.94), 0.0)
		p.z = 0.25 + 0.05 * sqrt(maxf(0.0, 1.0 - pow(p.x / 0.24, 2.0) - pow((p.y - 0.82) / 0.2, 2.0))) + 0.004
		ellip(ap, p, Vector3(0.022, 0.022, 0.008), [Color(0.3, 0.45, 0.8), Color(0.85, 0.3, 0.35), Color(0.95, 0.75, 0.2)][i % 3], Transform3D.IDENTITY, 4, 8)
	ellip(ap, Vector3(0, 1.0, 0.26), Vector3(0.2, 0.025, 0.03), Color(0.95, 0.93, 0.88))
	# Пуговицы кофты
	for k in 3:
		ellip(g.s("plain"), Vector3(0, 1.1 + k * 0.07, 0.285 - k * 0.012), Vector3(0.018, 0.018, 0.01), Color(0.35, 0.2, 0.1), Transform3D.IDENTITY, 5, 8)
	# Пуховая шаль на плечах с бахромой
	ellip(f, Vector3(0, 1.28, -0.02), Vector3(0.39, 0.08, 0.31), SHAWL)
	ellip(f, Vector3(0, 1.1, -0.16), Vector3(0.36, 0.26, 0.15), SHAWL)
	# Концы шали, перекрещенные на груди
	for sx in [-1.0, 1.0]:
		ellip(f, Vector3.ZERO, Vector3(0.075, 0.17, 0.04), SHAWL.darkened(0.06), Transform3D(Basis(Vector3.BACK, sx * 0.5).rotated(Vector3.RIGHT, -0.2), Vector3(sx * 0.17, 1.16, 0.24)))
	for i in 22:
		var ang := PI * 0.15 + i * PI * 0.7 / 21.0
		var p := Vector3(cos(ang) * 0.36, 0.86, -sin(ang) * 0.14 - 0.1)
		Geo.rod(f, p, p + Vector3(0, -0.09, 0), 0.008, SHAWL.darkened(0.1), 4)
	# Шея
	ellip(g.s("skin"), Vector3(0, 1.4, 0.02), Vector3(0.09, 0.1, 0.09), SKIN)
	return g.build()


func _build_head(rng: RandomNumberGenerator) -> ArrayMesh:
	var g := GeoMesh.new()
	var sk := g.s("skin")
	var c := Vector3(0, 0.15, 0)
	# Голова, щёчки, двойной подбородок
	ellip(sk, c, Vector3(0.19, 0.21, 0.19), SKIN, Transform3D.IDENTITY, 16, 24)
	ellip(sk, c + Vector3(0, -0.13, 0.06), Vector3(0.12, 0.07, 0.1), SKIN)
	for sx in [-1.0, 1.0]:
		ellip(sk, c + Vector3(sx * 0.1, -0.04, 0.12), Vector3(0.065, 0.055, 0.05), Color(0.98, 0.62, 0.58))
	# Нос картошкой
	ellip(sk, c + Vector3(0, -0.005, 0.19), Vector3(0.045, 0.04, 0.045), Color(0.98, 0.7, 0.62))
	# Улыбка и морщинки
	var d := g.s("plain")
	for i in 7:
		var u := (i - 3) / 3.0
		ellip(d, c + Vector3(u * 0.055, -0.085 + u * u * 0.02, 0.17 - u * u * 0.015), Vector3(0.014, 0.009, 0.007), Color(0.6, 0.2, 0.2), Transform3D.IDENTITY, 4, 6)
	for sx in [-1.0, 1.0]:
		for k in 3:
			var a := Vector3(sx * (0.12 + k * 0.004), 0.03 + k * 0.022 - 0.02, 0.13 - k * 0.006)
			Geo.rod(d, c + a, c + a + Vector3(sx * 0.03, 0.005 - k * 0.006, -0.012), 0.003, SKIN.darkened(0.2), 4)
		# Брови — седые, домиком
		Geo.rod(d, c + Vector3(sx * 0.03, 0.065, 0.178), c + Vector3(sx * 0.1, 0.075, 0.16), 0.009, HAIR, 5)
	# Седая чёлка из-под платка
	for i in 9:
		var x := -0.11 + i * 0.0275
		ellip(g.s("fabric"), c + Vector3(x, 0.12 - absf(x) * 0.25, 0.155 - absf(x) * 0.35), Vector3(0.025, 0.02, 0.02), HAIR, Transform3D.IDENTITY, 5, 8)
	# Круглые очки
	var m := g.s("metal")
	for sx in [-1.0, 1.0]:
		var oc := c + Vector3(sx * 0.068, 0.025, 0.2)
		for i in 16:
			var a0 := TAU * i / 16.0
			var a1 := TAU * (i + 1) / 16.0
			Geo.rod(m, oc + Vector3(cos(a0), sin(a0), 0) * 0.052, oc + Vector3(cos(a1), sin(a1), 0) * 0.052, 0.006, Color(0.25, 0.18, 0.1), 5)
		Geo.prism(g.s("lens"), Vector3.ZERO, 0.05, 0.05, 0.004, Color(0.9, 0.95, 1.0), 16, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), oc + Vector3(0, 0, -0.004)))
		Geo.rod(m, oc + Vector3(sx * 0.052, 0, 0), c + Vector3(sx * 0.19, 0.03, 0.02), 0.005, Color(0.25, 0.18, 0.1), 4)
	Geo.rod(m, c + Vector3(-0.018, 0.03, 0.205), c + Vector3(0.018, 0.03, 0.205), 0.005, Color(0.25, 0.18, 0.1), 4)
	# Платок: оболочка вокруг головы с овальным вырезом под лицо
	var sc := g.s("fabric")
	_hood(sc, c + Vector3(0, 0.02, -0.01), Vector3(0.225, 0.235, 0.225))
	# Горошек
	for i in 46:
		var al := rng.randf_range(1.3, PI)
		var be := rng.randf() * TAU
		var dir := _hood_dir(al, be)
		var pos := c + Vector3(0, 0.02, -0.01) + dir * Vector3(0.226, 0.236, 0.226)
		var bs := Basis.looking_at(-dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
		ellip(sc, Vector3.ZERO, Vector3(0.018, 0.018, 0.006), Color(0.98, 0.96, 0.9), Transform3D(bs, pos), 4, 8)
	# Узел под подбородком и концы платка
	ellip(sc, c + Vector3(0, -0.22, 0.09), Vector3(0.05, 0.04, 0.04), SCARF.darkened(0.1))
	for sx in [-1.0, 1.0]:
		ellip(sc, c + Vector3(sx * 0.05, -0.29, 0.1), Vector3(0.035, 0.07, 0.02), SCARF, Transform3D(Basis(Vector3.BACK, sx * 0.4), Vector3.ZERO))
	return g.build()


## Направление на оболочке платка: полюс смотрит вперёд (+Z).
static func _hood_dir(al: float, be: float) -> Vector3:
	return Vector3(sin(al) * cos(be), sin(al) * sin(be), cos(al))


## Платок: эллипсоид с вырезом под лицо (вырез выше узкий, к подбородку шире),
## с толстым подвёрнутым краем.
static func _hood(st: SurfaceTool, c: Vector3, r: Vector3) -> void:
	var segs := 32
	var rings := 14
	var rows := []
	for i in rings + 2:
		var row := []
		for j in segs:
			var be := TAU * j / segs
			var sb := sin(be)
			var a0 := 0.95 + (sb * sb * (-0.25) if sb > 0.0 else sb * sb * 0.35)
			var al: float
			var k := 1.0
			if i == 0:
				al = a0
				k = 0.9
			elif i == 1:
				al = a0 + 0.04
				k = 1.04
			else:
				al = a0 + 0.04 + (PI - a0 - 0.04) * (i - 1) / float(rings)
			row.append(c + _hood_dir(al, be) * r * k)
		rows.append(row)
	st.set_smooth_group(0)
	st.set_color(SCARF)
	for i in rings + 1:
		for j in segs:
			var j2 := (j + 1) % segs
			Geo.poly(st, [rows[i][j], rows[i + 1][j], rows[i + 1][j2], rows[i][j2]], c)
	st.set_smooth_group(-1)


func _build_eyes() -> ArrayMesh:
	var g := GeoMesh.new()
	var e := g.s("plain")
	for sx in [-1.0, 1.0]:
		ellip(e, Vector3(sx * 0.068, 0.0, 0.0), Vector3(0.02, 0.024, 0.012), Color(0.08, 0.06, 0.05), Transform3D.IDENTITY, 6, 10)
		ellip(e, Vector3(sx * 0.068 + 0.007, 0.009, 0.01), Vector3(0.006, 0.006, 0.004), Color(1, 1, 1), Transform3D.IDENTITY, 4, 6)
	# сдвиг: глаза на лице (центр головы + 0.025 по Y, у поверхности)
	var mesh := g.build()
	return mesh


func _build_arm(side: float) -> ArrayMesh:
	var g := GeoMesh.new()
	var f := g.s("fabric")
	var x := -side
	# Плечо → локоть → кисть (кисти у вязания перед животом)
	var sh := Vector3(0, 0, 0)
	var el := Vector3(x * 0.07, -0.3, 0.12)
	var wr := Vector3(side * 0.12, -0.22, 0.33)
	limb(f, sh, el, 0.1, 0.085, CARDIGAN)
	limb(f, el, wr, 0.085, 0.07, CARDIGAN)
	# Манжета
	limb(f, wr.lerp(el, 0.12), wr, 0.078, 0.078, CARDIGAN.darkened(0.15))
	# Кисть с пальчиками
	var sk := g.s("skin")
	var hc := wr + Vector3(side * 0.04, 0.0, 0.05)
	ellip(sk, hc, Vector3(0.05, 0.035, 0.06), SKIN)
	for i in 4:
		var base := hc + Vector3(side * 0.035, -0.005 + i * 0.0, 0.03 - i * 0.022)
		limb(sk, base, base + Vector3(side * 0.04, -0.015, 0.0), 0.014, 0.012, SKIN, 8)
	limb(sk, hc + Vector3(0, 0.02, 0.04), hc + Vector3(side * 0.02, 0.045, 0.07), 0.016, 0.013, SKIN, 8)
	return g.build()


func _build_knitting(rng: RandomNumberGenerator) -> ArrayMesh:
	var g := GeoMesh.new()
	var m := g.s("metal")
	# Спицы крест-накрест
	Geo.rod(m, Vector3(-0.2, 0.03, -0.02), Vector3(0.12, 0.12, 0.08), 0.006, Color(0.75, 0.75, 0.78), 6)
	Geo.rod(m, Vector3(0.2, 0.03, -0.02), Vector3(-0.12, 0.12, 0.08), 0.006, Color(0.75, 0.75, 0.78), 6)
	# Недовязанная шапочка для кота с ушками
	var f := g.s("fabric")
	var pink := Color(0.95, 0.55, 0.65)
	ellip(f, Vector3(0, -0.05, 0.02), Vector3(0.11, 0.08, 0.06), pink)
	for sx in [-1.0, 1.0]:
		Geo.prism(f, Vector3(sx * 0.06, 0.0, 0.02), 0.035, 0.0, 0.06, pink.darkened(0.1), 8)
	for i in 5:
		Geo.rod(f, Vector3(-0.1 + i * 0.05, 0.02, 0.07), Vector3(-0.1 + i * 0.05, -0.11, 0.07), 0.008, pink.lightened(0.15), 5)
	return g.build()


## Клубок на прилавке и нитка к вязанию (не анимируются).
func _build_yarn() -> ArrayMesh:
	var g := GeoMesh.new()
	var f := g.s("fabric")
	var pink := Color(0.95, 0.55, 0.65)
	var ball := Vector3(0.28, 1.14, 1.16)
	var pts := [Vector3(0, 1.0, 0.41), Vector3(0.05, 0.97, 0.6), Vector3(0.14, 1.0, 0.85), Vector3(0.24, 1.08, 1.1)]
	for i in pts.size() - 1:
		Geo.rod(f, pts[i], pts[i + 1], 0.004, pink, 4)
	ellip(f, ball, Vector3(0.08, 0.075, 0.08), pink)
	for i in 6:
		var a := i * PI / 6.0
		Geo.rod(f, ball + Vector3(cos(a), sin(a), 0.3) * 0.075, ball + Vector3(-cos(a), -sin(a), 0.3) * 0.075, 0.006, pink.darkened(0.15), 4)
	return g.build()
