class_name ShopGoods
extends RefCounted
## Товар на полках ларька баб Нюры: украшения из каталога (design/items.md,
## «Где: Л»). Каждый предмет строится от точки на полке (низ по центру),
## под ним ценник.

const SHELF_X := [-1.2, -0.8, -0.4, 0.0, 0.4, 0.8, 1.2]

## Полки: y верхней грани полки, z — середина полки.
static func build(gm: GeoMesh, shelf_y: Array, z: float) -> void:
	var rows := [
		# Нижняя: тело и эффекты
		[_vest, _scarf, _apron, _cape, _confetti, _paws, _duck_ring],
		# Средняя: лицо и спина
		[_moustache, _nose_glasses, _hero_mask, _aviators, _chicken_tail, _cat_backpack, _wings],
		# Верхняя: голова
		[_cat_helmet, _bucket, _chef_hat, _pineapple, _pompom_hat, _knit_ears, _cat_helmet_alt],
	]
	for r in rows.size():
		var items: Array = rows[r]
		for i in items.size():
			var at := Vector3(SHELF_X[i], shelf_y[r], z)
			(items[i] as Callable).call(gm, at)
			_tag(gm, at + Vector3(0.0, -0.06, 0.16))


static func _e(gm: GeoMesh, key: String, c: Vector3, r: Vector3, col: Color, xf := Transform3D.IDENTITY) -> void:
	# xf задаёт только поворот вокруг центра c
	Babushka.ellip(gm.s(key), Vector3.ZERO, r, col, Transform3D(xf.basis, c + xf.origin), 8, 12)


static func _tag(gm: GeoMesh, at: Vector3) -> void:
	Geo.box(gm.s("plain"), at, Vector3(0.12, 0.05, 0.005), Color(0.97, 0.96, 0.9))
	Geo.box(gm.s("plain"), at + Vector3(-0.02, 0.0, 0.004), Vector3(0.06, 0.012, 0.003), Color(0.2, 0.2, 0.25))


## Тор вокруг оси Y (утиный круг, ободки).
static func _torus(st: SurfaceTool, c: Vector3, big: float, small: float, col: Color, xf := Transform3D.IDENTITY, n := 18, m := 10) -> void:
	st.set_smooth_group(0)
	st.set_color(col)
	for i in n:
		for j in m:
			var p := []
			for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var a: float = TAU * (i + d[0]) / n
				var b: float = TAU * (j + d[1]) / m
				var ring := Vector3(cos(a), 0, sin(a))
				p.append(c + ring * (big + small * cos(b)) + Vector3(0, small * sin(b), 0))
			var a0 := TAU * (i + 0.5) / n
			Geo.poly(st, p, c + Vector3(cos(a0), 0, sin(a0)) * big, xf)
	st.set_smooth_group(-1)


## Деревянная болванка-голова для шапок.
static func _stand(gm: GeoMesh, at: Vector3) -> Vector3:
	Geo.prism(gm.s("wood"), at, 0.06, 0.04, 0.06, Color(0.7, 0.5, 0.3), 12)
	_e(gm, "wood", at + Vector3(0, 0.15, 0), Vector3(0.09, 0.1, 0.09), Color(0.85, 0.7, 0.5))
	return at + Vector3(0, 0.15, 0)


# --- Голова -------------------------------------------------------------------

static func _cat_helmet(gm: GeoMesh, at: Vector3) -> void:
	var h := _stand(gm, at)
	var y := Color(0.98, 0.78, 0.15)
	_e(gm, "plain", h + Vector3(0, 0.03, 0), Vector3(0.105, 0.085, 0.11), y)
	Geo.prism(gm.s("plain"), h + Vector3(0, 0.0, 0), 0.12, 0.12, 0.015, y.darkened(0.15), 16)
	for sx in [-1.0, 1.0]:
		Geo.prism(gm.s("plain"), h + Vector3(sx * 0.055, 0.08, 0), 0.035, 0.0, 0.07, y, 8)
		Geo.prism(gm.s("plain"), h + Vector3(sx * 0.055, 0.085, 0.012), 0.02, 0.0, 0.05, Color(0.95, 0.55, 0.6), 8)


static func _cat_helmet_alt(gm: GeoMesh, at: Vector3) -> void:
	# Вторая каска — красная, у края полки
	var h := _stand(gm, at)
	var r := Color(0.85, 0.2, 0.18)
	_e(gm, "plain", h + Vector3(0, 0.03, 0), Vector3(0.105, 0.085, 0.11), r)
	Geo.prism(gm.s("plain"), h, 0.12, 0.12, 0.015, r.darkened(0.15), 16)
	for sx in [-1.0, 1.0]:
		Geo.prism(gm.s("plain"), h + Vector3(sx * 0.055, 0.08, 0), 0.035, 0.0, 0.07, r, 8)


static func _bucket(gm: GeoMesh, at: Vector3) -> void:
	var m := Color(0.62, 0.64, 0.66)
	Geo.prism(gm.s("metal"), at, 0.075, 0.1, 0.17, m, 16)
	Geo.prism(gm.s("metal"), at + Vector3(0, 0.165, 0), 0.105, 0.105, 0.015, m.lightened(0.1), 16)
	for i in 8:
		var a0 := PI * i / 8.0
		var a1 := PI * (i + 1) / 8.0
		Geo.rod(gm.s("metal"), at + Vector3(cos(a0) * 0.1, 0.17 + sin(a0) * 0.09, 0), at + Vector3(cos(a1) * 0.1, 0.17 + sin(a1) * 0.09, 0), 0.004, m.darkened(0.3), 4)


static func _chef_hat(gm: GeoMesh, at: Vector3) -> void:
	var w := Color(0.97, 0.97, 0.95)
	Geo.prism(gm.s("fabric"), at, 0.08, 0.085, 0.12, w, 16)
	for i in 6:
		var a := TAU * i / 6.0
		_e(gm, "fabric", at + Vector3(cos(a) * 0.05, 0.17, sin(a) * 0.05), Vector3(0.06, 0.055, 0.06), w)
	_e(gm, "fabric", at + Vector3(0, 0.19, 0), Vector3(0.07, 0.06, 0.07), w)


static func _pineapple(gm: GeoMesh, at: Vector3) -> void:
	_e(gm, "plain", at + Vector3(0, 0.1, 0), Vector3(0.075, 0.1, 0.075), Color(0.9, 0.65, 0.15))
	for i in 12:
		var a := TAU * i / 12.0
		for k in 3:
			_e(gm, "plain", at + Vector3(cos(a + k * 0.26) * 0.072 * (1.0 - absf(k - 1) * 0.15), 0.05 + k * 0.05, sin(a + k * 0.26) * 0.072 * (1.0 - absf(k - 1) * 0.15)), Vector3(0.012, 0.012, 0.012), Color(0.6, 0.38, 0.08))
	for i in 7:
		var a := TAU * i / 7.0
		var d := Vector3(cos(a) * 0.045, 0.1, sin(a) * 0.045)
		Geo.rod(gm.s("plain"), at + Vector3(0, 0.19, 0), at + Vector3(0, 0.19, 0) + d, 0.012, Color(0.2, 0.55, 0.2), 5)
	Geo.prism(gm.s("plain"), at + Vector3(0, 0.19, 0), 0.025, 0.0, 0.14, Color(0.25, 0.6, 0.22), 6)


static func _pompom_hat(gm: GeoMesh, at: Vector3) -> void:
	var h := _stand(gm, at)
	var c := Color(0.35, 0.6, 0.85)
	_e(gm, "fabric", h + Vector3(0, 0.03, 0), Vector3(0.1, 0.09, 0.105), c)
	Geo.prism(gm.s("fabric"), h - Vector3(0, 0.01, 0), 0.105, 0.105, 0.04, Color(0.95, 0.95, 0.92), 16)
	for i in 6:
		var a := TAU * i / 6.0
		Geo.rod(gm.s("fabric"), h + Vector3(cos(a) * 0.1, 0.035, sin(a) * 0.1), h + Vector3(cos(a) * 0.04, 0.115, sin(a) * 0.04), 0.008, c.lightened(0.2), 4)
	_e(gm, "fabric", h + Vector3(0, 0.135, 0), Vector3(0.04, 0.04, 0.04), Color(0.95, 0.95, 0.92))


static func _knit_ears(gm: GeoMesh, at: Vector3) -> void:
	var h := _stand(gm, at)
	var c := Color(0.95, 0.55, 0.65)
	for i in 10:
		var a0 := PI * i / 10.0
		var a1 := PI * (i + 1) / 10.0
		Geo.rod(gm.s("fabric"), h + Vector3(cos(a0) * 0.095, sin(a0) * 0.095, 0), h + Vector3(cos(a1) * 0.095, sin(a1) * 0.095, 0), 0.016, c, 6)
	for sx in [-1.0, 1.0]:
		Geo.prism(gm.s("fabric"), h + Vector3(sx * 0.06, 0.07, 0), 0.04, 0.0, 0.08, c, 8)


# --- Лицо и спина ------------------------------------------------------------

static func _moustache(gm: GeoMesh, at: Vector3) -> void:
	Geo.prism(gm.s("wood"), at, 0.04, 0.04, 0.01, Color(0.6, 0.45, 0.3), 10)
	Geo.rod(gm.s("wood"), at, at + Vector3(0, 0.12, 0), 0.006, Color(0.6, 0.45, 0.3), 5)
	var b := Color(0.3, 0.18, 0.1)
	for sx in [-1.0, 1.0]:
		_e(gm, "fabric", at + Vector3(sx * 0.045, 0.13, 0.01), Vector3(0.05, 0.02, 0.018), b, Transform3D(Basis(Vector3.BACK, sx * 0.25), Vector3.ZERO))
		_e(gm, "fabric", at + Vector3(sx * 0.095, 0.145, 0.01), Vector3(0.02, 0.015, 0.012), b)


static func _nose_glasses(gm: GeoMesh, at: Vector3) -> void:
	var f := Color(0.1, 0.1, 0.1)
	for sx in [-1.0, 1.0]:
		var c := at + Vector3(sx * 0.045, 0.1, 0)
		for i in 10:
			var a0 := TAU * i / 10.0
			var a1 := TAU * (i + 1) / 10.0
			Geo.rod(gm.s("plain"), c + Vector3(cos(a0), sin(a0), 0) * 0.035, c + Vector3(cos(a1), sin(a1), 0) * 0.035, 0.005, f, 4)
		Geo.rod(gm.s("plain"), c + Vector3(sx * 0.035, 0, 0), c + Vector3(sx * 0.04, -0.09, -0.06), 0.004, f, 4)
		_e(gm, "fabric", c + Vector3(0, 0.045, 0.005), Vector3(0.035, 0.01, 0.01), f)
	_e(gm, "plain", at + Vector3(0, 0.06, 0.03), Vector3(0.025, 0.035, 0.03), Color(0.95, 0.6, 0.55))


static func _hero_mask(gm: GeoMesh, at: Vector3) -> void:
	Geo.prism(gm.s("wood"), at, 0.04, 0.04, 0.01, Color(0.6, 0.45, 0.3), 10)
	Geo.rod(gm.s("wood"), at, at + Vector3(0, 0.1, 0), 0.006, Color(0.6, 0.45, 0.3), 5)
	var r := Color(0.15, 0.25, 0.75)
	for sx in [-1.0, 1.0]:
		_e(gm, "fabric", at + Vector3(sx * 0.045, 0.12, 0), Vector3(0.055, 0.035, 0.012), r)
		_e(gm, "plain", at + Vector3(sx * 0.045, 0.12, 0.009), Vector3(0.022, 0.014, 0.006), Color(0.05, 0.05, 0.08))
		Geo.rod(gm.s("fabric"), at + Vector3(sx * 0.1, 0.12, 0), at + Vector3(sx * 0.13, 0.07, -0.01), 0.008, r, 4)


static func _aviators(gm: GeoMesh, at: Vector3) -> void:
	var leather := Color(0.45, 0.28, 0.15)
	Geo.rod(gm.s("fabric"), at + Vector3(-0.13, 0.03, -0.02), at + Vector3(0.13, 0.03, -0.02), 0.012, leather, 6)
	for sx in [-1.0, 1.0]:
		var c := at + Vector3(sx * 0.055, 0.05, 0)
		Geo.prism(gm.s("metal"), Vector3.ZERO, 0.045, 0.045, 0.03, Color(0.7, 0.6, 0.3), 14, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c))
		Geo.prism(gm.s("glass"), Vector3.ZERO, 0.035, 0.035, 0.01, Color(0.3, 0.6, 0.55), 14, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c + Vector3(0, 0, 0.025)))


static func _chicken_tail(gm: GeoMesh, at: Vector3) -> void:
	Geo.cbox(gm.s("fabric"), at + Vector3(0, 0.03, 0), Vector3(0.1, 0.06, 0.06), Color(0.95, 0.92, 0.85), 0.02)
	var cols := [Color(0.95, 0.92, 0.85), Color(0.85, 0.3, 0.15), Color(0.95, 0.75, 0.3)]
	for i in 7:
		var a := -0.9 + i * 0.3
		var d := Vector3(sin(a), cos(a), -0.3).normalized()
		var c := at + Vector3(0, 0.05, 0) + d * 0.1
		_e(gm, "fabric", c, Vector3(0.025, 0.1, 0.008), cols[i % 3], Transform3D(Basis(Vector3.BACK, -a), Vector3.ZERO))


static func _cat_backpack(gm: GeoMesh, at: Vector3) -> void:
	var o := Color(0.95, 0.6, 0.25)
	Geo.cbox(gm.s("fabric"), at + Vector3(0, 0.12, 0), Vector3(0.2, 0.24, 0.12), o, 0.05)
	for sx in [-1.0, 1.0]:
		Geo.prism(gm.s("fabric"), at + Vector3(sx * 0.065, 0.23, 0), 0.04, 0.0, 0.07, o, 8)
		_e(gm, "plain", at + Vector3(sx * 0.045, 0.16, 0.062), Vector3(0.016, 0.02, 0.006), Color(0.1, 0.1, 0.1))
		Geo.rod(gm.s("plain"), at + Vector3(sx * 0.03, 0.12, 0.062), at + Vector3(sx * 0.1, 0.13, 0.062), 0.003, Color(0.2, 0.15, 0.1), 3)
	_e(gm, "plain", at + Vector3(0, 0.13, 0.064), Vector3(0.014, 0.01, 0.006), Color(0.95, 0.5, 0.55))
	Geo.cbox(gm.s("fabric"), at + Vector3(0, 0.07, 0.07), Vector3(0.14, 0.08, 0.03), o.darkened(0.15), 0.015)


static func _wings(gm: GeoMesh, at: Vector3) -> void:
	var w := Color(0.98, 0.97, 0.95)
	Geo.cbox(gm.s("fabric"), at + Vector3(0, 0.03, 0), Vector3(0.06, 0.06, 0.04), w.darkened(0.1), 0.015)
	for sx in [-1.0, 1.0]:
		for k in 3:
			_e(gm, "fabric", at + Vector3(sx * (0.07 + k * 0.025), 0.1 + k * 0.02, -0.01), Vector3(0.05, 0.08 - k * 0.012, 0.015), w.darkened(k * 0.04), Transform3D(Basis(Vector3.BACK, -sx * 0.5), Vector3.ZERO))


# --- Тело и эффекты -----------------------------------------------------------

## Стопка сложенной одежды в полоску или однотонной.
static func _folded(gm: GeoMesh, at: Vector3, a: Color, b: Color, stripes: int) -> void:
	for k in 2:
		var base := at + Vector3(0, 0.03 + k * 0.055, 0)
		Geo.cbox(gm.s("fabric"), base, Vector3(0.28, 0.05, 0.2), a, 0.02)
		for i in stripes:
			Geo.box(gm.s("fabric"), base + Vector3(-0.12 + i * 0.24 / maxf(1, stripes - 1), 0, 0.101), Vector3(0.02, 0.045, 0.004), b)


static func _vest(gm: GeoMesh, at: Vector3) -> void:
	# Тельняшка: белая с синими полосками
	for k in 2:
		var base := at + Vector3(0, 0.03 + k * 0.055, 0)
		Geo.cbox(gm.s("fabric"), base, Vector3(0.28, 0.05, 0.2), Color(0.96, 0.96, 0.95), 0.02)
		for i in 3:
			Geo.box(gm.s("fabric"), base + Vector3(0, -0.015 + i * 0.015, 0.101), Vector3(0.26, 0.006, 0.004), Color(0.1, 0.2, 0.55))


static func _scarf(gm: GeoMesh, at: Vector3) -> void:
	# Вязаный шарф, свёрнутый рулоном
	var c := Color(0.85, 0.25, 0.3)
	for i in 5:
		var x := -0.1 + i * 0.05
		Geo.prism(gm.s("fabric"), Vector3.ZERO, 0.07, 0.07, 0.045, c if i % 2 == 0 else Color(0.95, 0.9, 0.8), 14, Transform3D(Basis(Vector3.BACK, PI * 0.5), at + Vector3(x + 0.0225, 0.07, 0)))
	for i in 4:
		Geo.rod(gm.s("fabric"), at + Vector3(0.12, 0.01, 0.05 - i * 0.03), at + Vector3(0.16, 0.0, 0.06 - i * 0.03), 0.006, c, 4)


static func _apron(gm: GeoMesh, at: Vector3) -> void:
	_folded(gm, at, Color(0.95, 0.85, 0.6), Color(0.95, 0.85, 0.6), 0)
	for i in 3:
		var p := at + Vector3(-0.08 + i * 0.08, 0.14, 0.04)
		_e(gm, "plain", p, Vector3(0.02, 0.015, 0.02), Color(0.4, 0.4, 0.4))
		for sx in [-1.0, 1.0]:
			Geo.prism(gm.s("plain"), p + Vector3(sx * 0.01, 0.01, 0), 0.007, 0.0, 0.015, Color(0.4, 0.4, 0.4), 5)


static func _cape(gm: GeoMesh, at: Vector3) -> void:
	_folded(gm, at, Color(0.8, 0.12, 0.15), Color(0.95, 0.8, 0.2), 0)
	_e(gm, "plain", at + Vector3(0, 0.115, 0.06), Vector3(0.04, 0.008, 0.04), Color(0.95, 0.8, 0.2))


static func _confetti(gm: GeoMesh, at: Vector3) -> void:
	# Банка с конфетти
	Geo.prism(gm.s("lens"), at, 0.07, 0.07, 0.16, Color(0.9, 0.95, 1.0), 14)
	Geo.prism(gm.s("metal"), at + Vector3(0, 0.16, 0), 0.072, 0.072, 0.03, Color(0.85, 0.3, 0.3), 14)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 40:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.06
		Geo.box(gm.s("plain"), Vector3.ZERO, Vector3(0.015, 0.004, 0.012), Color.from_hsv(rng.randf(), 0.7, 1.0), Transform3D(Basis(Vector3(rng.randf(), rng.randf(), rng.randf()).normalized(), rng.randf() * TAU), at + Vector3(cos(a) * r, rng.randf_range(0.01, 0.12), sin(a) * r)))


static func _paws(gm: GeoMesh, at: Vector3) -> void:
	# Табличка со следами лапок
	Geo.cbox(gm.s("wood"), at + Vector3(0, 0.1, -0.02), Vector3(0.22, 0.18, 0.02), Color(0.9, 0.85, 0.75), 0.01, Transform3D(Basis(Vector3.RIGHT, -0.2), Vector3.ZERO))
	Geo.box(gm.s("wood"), at + Vector3(0, 0.05, -0.07), Vector3(0.02, 0.1, 0.02), Color(0.5, 0.35, 0.2))
	for k in 2:
		var p := at + Vector3(-0.05 + k * 0.1, 0.07 + k * 0.06, -0.005)
		_e(gm, "plain", p, Vector3(0.022, 0.02, 0.006), Color(0.9, 0.4, 0.5))
		for t in 3:
			_e(gm, "plain", p + Vector3(-0.02 + t * 0.02, 0.028 - absf(t - 1) * 0.006, 0), Vector3(0.008, 0.009, 0.005), Color(0.9, 0.4, 0.5))


static func _duck_ring(gm: GeoMesh, at: Vector3) -> void:
	var y := Color(1.0, 0.82, 0.15)
	_torus(gm.s("plain"), at + Vector3(0, 0.05, 0), 0.1, 0.045, y)
	_e(gm, "plain", at + Vector3(0, 0.13, 0.1), Vector3(0.045, 0.045, 0.045), y)
	_e(gm, "plain", at + Vector3(0, 0.12, 0.15), Vector3(0.025, 0.012, 0.03), Color(0.98, 0.5, 0.1))
	for sx in [-1.0, 1.0]:
		_e(gm, "plain", at + Vector3(sx * 0.02, 0.145, 0.138), Vector3(0.007, 0.009, 0.004), Color(0.05, 0.05, 0.05))
