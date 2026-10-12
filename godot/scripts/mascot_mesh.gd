class_name MascotMesh
extends RefCounted
## Золотой кот-талисман (манэки-нэко) на постаменте с подушкой.
## Смотрит в +Z. Машущая лапа строится отдельно (paw) — вращается в mascot.gd.

const GOLD := Color(1.0, 0.78, 0.25)
const GOLD_DARK := Color(0.85, 0.6, 0.15)
const RED := Color(0.82, 0.1, 0.12)
const PINK := Color(1.0, 0.6, 0.65)
const INK := Color(0.08, 0.06, 0.05)
const SEAT_Y := 1.0


static func _e(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, xf := Transform3D.IDENTITY) -> void:
	Babushka.ellip(st, Vector3.ZERO, r, col, Transform3D(xf.basis, c + xf.origin))


static func build_body(gm: GeoMesh) -> void:
	var g := gm.s("gold")
	# Постамент: ступенчатый камень и табличка
	Geo.cbox(gm.s("concrete"), Vector3(0, 0.15, 0), Vector3(1.9, 0.3, 1.9), Color(0.75, 0.72, 0.68), 0.06)
	Geo.cbox(gm.s("concrete"), Vector3(0, 0.55, 0), Vector3(1.6, 0.5, 1.6), Color(0.82, 0.8, 0.76), 0.05)
	Geo.cbox(gm.s("gold"), Vector3(0, 0.55, 0.81), Vector3(0.9, 0.25, 0.02), GOLD_DARK, 0.01)
	# Красная подушка-дзабутон с кисточками
	Geo.cbox(gm.s("fabric"), Vector3(0, 0.88, 0), Vector3(1.45, 0.16, 1.45), RED, 0.07)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var p := Vector3(sx * 0.72, 0.9, sz * 0.72)
			_e(gm.s("gold"), p, Vector3(0.04, 0.04, 0.04), GOLD)
			Geo.prism(gm.s("fabric"), p + Vector3(0, -0.18, 0), 0.03, 0.01, 0.16, GOLD, 8)
	var y := SEAT_Y
	# Туловище: сидячая «груша»
	_e(g, Vector3(0, y + 0.42, 0), Vector3(0.62, 0.55, 0.52), GOLD)
	_e(g, Vector3(0, y + 0.85, 0.02), Vector3(0.5, 0.42, 0.44), GOLD)
	# Задние лапы по бокам и передние лапки
	for sx in [-1.0, 1.0]:
		_e(g, Vector3(sx * 0.42, y + 0.2, 0.1), Vector3(0.24, 0.2, 0.36), GOLD)
		_e(g, Vector3(sx * 0.2, y + 0.08, 0.48), Vector3(0.15, 0.1, 0.17), GOLD)
		for t in 3:
			Geo.rod(gm.s("plain"), Vector3(sx * 0.2 - 0.05 + t * 0.05, y + 0.1, 0.62), Vector3(sx * 0.2 - 0.05 + t * 0.05, y + 0.05, 0.645), 0.006, GOLD_DARK.darkened(0.3), 3)
	# Хвост колечком сзади
	for i in 10:
		var a := PI * 0.1 + i * 0.16
		var p := Vector3(0.25 + cos(a) * 0.25, y + 0.15 + sin(a) * 0.18, -0.5 - sin(a * 0.5) * 0.08)
		_e(g, p, Vector3.ONE * (0.09 - i * 0.003), GOLD)
	# Левая лапа держит монету-кобан
	Babushka.limb(g, Vector3(-0.42, y + 1.0, 0.15), Vector3(-0.22, y + 0.65, 0.48), 0.13, 0.12, GOLD)
	_e(g, Vector3(-0.2, y + 0.66, 0.52), Vector3(0.13, 0.11, 0.11), GOLD)
	_e(gm.s("gold"), Vector3(0.0, y + 0.62, 0.5), Vector3(0.2, 0.3, 0.05), Color(1.0, 0.88, 0.4), Transform3D(Basis(Vector3.BACK, 0.2), Vector3.ZERO))
	for k in 3:
		Geo.box(gm.s("plain"), Vector3.ZERO, Vector3(0.02, 0.24, 0.004), GOLD_DARK.darkened(0.25), Transform3D(Basis(Vector3.BACK, 0.2), Vector3((k - 1) * 0.06, y + 0.62, 0.552)))
	# Нагрудник: красный ошейник, бантик и колокольчик
	ShopGoods._torus(gm.s("fabric"), Vector3.ZERO, 0.36, 0.05, RED, Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0, y + 1.17, 0.04)), 24, 8)
	var bell := Vector3(0, y + 1.0, 0.43)
	_e(gm.s("gold"), bell, Vector3(0.11, 0.11, 0.11), Color(1.0, 0.85, 0.3))
	Geo.box(gm.s("plain"), bell + Vector3(0, -0.04, 0.1), Vector3(0.12, 0.012, 0.02), INK)
	_e(gm.s("plain"), bell + Vector3(0, -0.06, 0.09), Vector3(0.02, 0.02, 0.02), INK)
	for sx in [-1.0, 1.0]:
		_e(gm.s("fabric"), bell + Vector3(sx * 0.12, 0.12, -0.03), Vector3(0.1, 0.06, 0.04), RED, Transform3D(Basis(Vector3.BACK, sx * 0.3), Vector3.ZERO))
	# Голова
	var h := Vector3(0, y + 1.6, 0.05)
	_e(g, h, Vector3(0.58, 0.48, 0.48), GOLD)
	for sx in [-1.0, 1.0]:
		# Щёки
		_e(g, h + Vector3(sx * 0.26, -0.16, 0.3), Vector3(0.22, 0.17, 0.16), GOLD)
		# Уши с розовой серединкой
		var ear := Transform3D(Basis(Vector3.BACK, -sx * 0.3).scaled(Vector3(1.0, 1.0, 0.55)), h + Vector3(sx * 0.32, 0.3, -0.02))
		Geo.prism(g, Vector3.ZERO, 0.19, 0.0, 0.3, GOLD, 12, ear)
		Geo.prism(gm.s("plain"), Vector3.ZERO, 0.11, 0.0, 0.2, PINK, 12, ear * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.07)))
		# Глаза: большие, блестящие
		var eye := h + Vector3(sx * 0.2, 0.05, 0.42)
		_e(gm.s("plain"), eye, Vector3(0.075, 0.095, 0.04), INK)
		_e(gm.s("plain"), eye + Vector3(0.025, 0.035, 0.035), Vector3(0.025, 0.025, 0.012), Color(1, 1, 1))
		_e(gm.s("plain"), eye + Vector3(-0.02, -0.03, 0.035), Vector3(0.012, 0.012, 0.008), Color(1, 1, 1))
		# Брови-точки (как на классических манэки-нэко)
		_e(gm.s("plain"), h + Vector3(sx * 0.2, 0.22, 0.4), Vector3(0.04, 0.02, 0.015), RED)
		# Румянец
		_e(gm.s("plain"), h + Vector3(sx * 0.33, -0.1, 0.42), Vector3(0.07, 0.04, 0.012), PINK)
		# Усы
		for k in 3:
			Geo.rod(gm.s("plain"), h + Vector3(sx * 0.32, -0.12 + k * 0.045, 0.43), h + Vector3(sx * 0.7, -0.17 + k * 0.08, 0.38), 0.008, INK, 4)
	# Нос и ротик «w»
	_e(gm.s("plain"), h + Vector3(0, -0.07, 0.48), Vector3(0.05, 0.035, 0.03), PINK)
	for sx in [-1.0, 1.0]:
		Geo.rod(gm.s("plain"), h + Vector3(0, -0.1, 0.48), h + Vector3(sx * 0.05, -0.15, 0.47), 0.01, INK, 4)
		Geo.rod(gm.s("plain"), h + Vector3(sx * 0.05, -0.15, 0.47), h + Vector3(sx * 0.1, -0.12, 0.455), 0.01, INK, 4)


## Машущая лапа: от плеча вверх, подушечки смотрят вперёд. Начало — в точке вращения.
static func build_paw(gm: GeoMesh) -> void:
	var g := gm.s("gold")
	Babushka.limb(g, Vector3.ZERO, Vector3(0.08, 0.5, 0.08), 0.15, 0.14, GOLD)
	var p := Vector3(0.08, 0.6, 0.1)
	Babushka.ellip(g, p, Vector3(0.17, 0.16, 0.14), GOLD)
	Babushka.ellip(gm.s("plain"), p + Vector3(0, -0.03, 0.13), Vector3(0.07, 0.06, 0.02), PINK)
	for i in 3:
		var a := -0.6 + i * 0.6
		Babushka.ellip(gm.s("plain"), p + Vector3(sin(a) * 0.09, 0.06 + cos(a) * 0.02, 0.125), Vector3(0.03, 0.035, 0.015), PINK)
