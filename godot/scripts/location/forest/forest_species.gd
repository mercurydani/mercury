class_name ForestSpecies
extends RefCounted
## Меши лесных видов: ель, берёза, дуб, куст, папоротник, трава, цветы, грибы, камни, пни, брёвна, камыш.
## Всё через GeoMesh/Geo лобби (материалы из Mats), в масштабе «1 = типичный экземпляр».

static var _cache := {}


static func get_mesh(species: String) -> ArrayMesh:
	if _cache.has(species):
		return _cache[species]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(species)
	var g := GeoMesh.new()
	match species:
		"spruce": spruce(g, rng, 14.0)
		"birch": birch(g, rng, 11.0)
		"oak": oak(g, rng, 14.0)
		"bush": bush(g, rng)
		"fern": fern(g, rng)
		"grass": grass(g, rng, false)
		"flowers": grass(g, rng, true)
		"mushroom": mushroom(g, rng)
		"rock": rock(g, rng, 1.0)
		"boulder": rock(g, rng, 2.2)
		"stump": stump(g, rng)
		"log": log_mesh(g, rng)
		"reeds": reeds(g, rng)
		"deadspruce": dead_tree(g, rng)
	var m := g.build()
	_cache[species] = m
	return m


static func _tint(rng: RandomNumberGenerator, base := Color.WHITE, v := 0.1) -> Color:
	return base.darkened(rng.randf_range(0.0, v)).lightened(rng.randf_range(0.0, v * 0.5))


static func spruce(g: GeoMesh, rng: RandomNumberGenerator, h: float) -> void:
	var bark := g.s("bark")
	var fol := g.s("foliage")
	var lv := g.s("leaves")
	bark.set_smooth_group(0)
	Geo.prism(bark, Vector3.ZERO, 0.42, 0.14, h * 0.96, Color(0.42, 0.32, 0.26), 9)
	bark.set_smooth_group(-1)
	Geo.prism(bark, Vector3.ZERO, 0.65, 0.4, 0.5, Color(0.36, 0.28, 0.22), 9)
	var tiers := 11
	for t in tiers:
		var k := float(t) / (tiers - 1)
		var y := h * (0.2 + 0.78 * k)
		var r := lerpf(3.6, 0.7, pow(k, 0.85))
		var col := Color(0.1, 0.24, 0.13).lerp(Color(0.2, 0.36, 0.17), k * 0.5 + rng.randf() * 0.2)
		var cone_h := lerpf(3.0, 1.6, k)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.ZERO)
		Geo.prism(fol, Vector3(0, y - cone_h * 0.55, 0), r, 0.0, cone_h, col, 9, xf)
		# Лапы: карточки хвои свисают по краю яруса
		for i in 7:
			var ang := TAU * i / 7.0 + rng.randf() * 0.5
			var p := Vector3(cos(ang), 0, sin(ang)) * r * 0.8 + Vector3(0, y - cone_h * 0.55 + 0.1, 0)
			var b := Basis(Vector3.UP, -ang + PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(35, 65)))
			var sz := r * rng.randf_range(0.7, 1.0)
			Geo.card(lv, p, b.scaled(Vector3(sz, sz, sz)), Color(0.75, 0.95, 0.7).lerp(Color(0.55, 0.8, 0.5), rng.randf()))
	Geo.prism(fol, Vector3(0, h * 0.97, 0), 0.25, 0.0, 1.4, Color(0.14, 0.3, 0.15), 7)


static func birch(g: GeoMesh, rng: RandomNumberGenerator, h: float) -> void:
	var bark := g.s("bark")
	var plain := g.s("plain")
	var core := g.s("foliage")
	var lv := g.s("leaves")
	var pts := [Vector3.ZERO]
	var segs := 7
	var trunk_h := h * 0.78
	for i in segs:
		pts.append(pts[-1] + Vector3(rng.randf_range(-0.12, 0.12), trunk_h / segs, rng.randf_range(-0.12, 0.12)))
	bark.set_smooth_group(0)
	for i in segs:
		Geo.rod(bark, pts[i], pts[i + 1], 0.2 * (1.0 - i * 0.09), Color(0.95, 0.94, 0.9), 10)
	bark.set_smooth_group(-1)
	Geo.prism(bark, Vector3.ZERO, 0.34, 0.2, 0.5, Color(0.55, 0.5, 0.45), 10)
	for i in 50:
		var t := rng.randf_range(0.04, 0.99)
		var si := mini(int(t * segs), segs - 1)
		var p: Vector3 = (pts[si] as Vector3).lerp(pts[si + 1], t * segs - si)
		var ang := rng.randf() * TAU
		var rad := 0.2 * (1.0 - si * 0.09) + 0.006
		Geo.box(plain, Vector3.ZERO, Vector3(rng.randf_range(0.08, 0.2), rng.randf_range(0.02, 0.06), 0.02), Color(0.1, 0.1, 0.1), Transform3D(Basis(Vector3.UP, PI * 0.5 - ang), p + Vector3(cos(ang), 0, sin(ang)) * rad))
	var top: Vector3 = pts[-1]
	var tips := []
	for i in 9:
		var from: Vector3 = (pts[0] as Vector3).lerp(top, rng.randf_range(0.45, 0.95))
		var ang := TAU * i / 9.0 + rng.randf() * 0.4
		var to := from + Vector3(cos(ang) * 1.5, rng.randf_range(1.0, 2.0), sin(ang) * 1.5)
		Geo.rod(bark, from, to, 0.07, Color(0.9, 0.88, 0.84), 6)
		tips.append(to)
	tips.append(top + Vector3(0, 1.0, 0))
	var cr := Vector3(h * 0.2, h * 0.2, h * 0.2)
	Geo.blob(core, top + Vector3(0, h * 0.08, 0), cr * 0.7, Color(0.22, 0.34, 0.12), rng, 7, 12, 0.18)
	for tip in tips:
		for k in 6:
			var p: Vector3 = tip + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.7, 1.0), rng.randf_range(-1, 1)) * 1.1
			var b := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
			var sz := rng.randf_range(1.3, 2.0)
			var col := _tint(rng, Color(1.05, 1.05, 0.8).lerp(Color(0.9, 1.0, 0.8), rng.randf()), 0.08)
			Geo.card(lv, p, b.scaled(Vector3(sz, sz, sz)), col)
			Geo.card(lv, p, (b * Basis(Vector3.UP, PI * 0.5)).scaled(Vector3(sz, sz, sz)), col)


static func oak(g: GeoMesh, rng: RandomNumberGenerator, h: float) -> void:
	var bark := g.s("bark")
	var core := g.s("foliage")
	var lv := g.s("leaves")
	var trunk_h := h * 0.42
	bark.set_smooth_group(0)
	var prev := Vector3.ZERO
	for i in 5:
		var nxt := prev + Vector3(rng.randf_range(-0.15, 0.15), trunk_h / 5.0, rng.randf_range(-0.15, 0.15))
		Geo.rod(bark, prev, nxt, 0.62 * (1.0 - i * 0.1), Color(0.38, 0.3, 0.24), 12)
		prev = nxt
	bark.set_smooth_group(-1)
	for i in 6:
		var ang := TAU * i / 6.0 + rng.randf() * 0.3
		Geo.rod(bark, Vector3(cos(ang) * 1.1, 0.0, sin(ang) * 1.1), Vector3(cos(ang) * 0.3, 1.2, sin(ang) * 0.3), 0.2, Color(0.36, 0.28, 0.22), 6)
	var top := prev
	var tips := []
	for i in 7:
		var ang := TAU * i / 7.0 + rng.randf() * 0.4
		var from := top - Vector3(0, rng.randf_range(0.0, 1.4), 0)
		var mid := from + Vector3(cos(ang) * 1.6, rng.randf_range(0.8, 1.6), sin(ang) * 1.6)
		var to := mid + Vector3(cos(ang) * 1.8, rng.randf_range(0.6, 1.4), sin(ang) * 1.8)
		Geo.rod(bark, from, mid, 0.26, Color(0.4, 0.31, 0.25), 8)
		Geo.rod(bark, mid, to, 0.16, Color(0.4, 0.31, 0.25), 7)
		tips.append(to)
	var cc := top + Vector3(0, h * 0.2, 0)
	for i in 5:
		var off := Vector3(rng.randf_range(-3, 3), rng.randf_range(-0.5, 1.8), rng.randf_range(-3, 3))
		Geo.blob(core, cc + off, Vector3(h * 0.2, h * 0.14, h * 0.2), Color(0.15, 0.26, 0.09), rng, 7, 12, 0.18)
	for tip in tips:
		for k in 9:
			var p: Vector3 = tip + Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.8, 1.6), rng.randf_range(-1.4, 1.4))
			var b := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
			var sz := rng.randf_range(1.5, 2.4)
			var col := _tint(rng, Color(0.85, 1.0, 0.7).lerp(Color(1.0, 0.95, 0.65), rng.randf() * 0.5), 0.1)
			Geo.card(lv, p, b.scaled(Vector3(sz, sz, sz)), col)
			Geo.card(lv, p, (b * Basis(Vector3.UP, PI * 0.5)).scaled(Vector3(sz, sz, sz)), col)


static func bush(g: GeoMesh, rng: RandomNumberGenerator) -> void:
	var core := g.s("foliage")
	var lv := g.s("leaves")
	for i in 4:
		Geo.blob(core, Vector3(rng.randf_range(-0.5, 0.5), 0.45, rng.randf_range(-0.5, 0.5)), Vector3(0.7, 0.55, 0.7), Color(0.18, 0.3, 0.11), rng, 6, 9, 0.2)
	for i in 22:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 1.0), rng.randf_range(-1, 1)).normalized()
		var b := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
		var sz := rng.randf_range(0.6, 1.0)
		Geo.card(lv, Vector3(0, 0.45, 0) + dir * 0.85, b.scaled(Vector3(sz, sz, sz)), _tint(rng, Color(0.95, 1.05, 0.8), 0.1))


static func fern(g: GeoMesh, rng: RandomNumberGenerator) -> void:
	var lv := g.s("leaves")
	for i in 11:
		var ang := TAU * i / 11.0 + rng.randf() * 0.3
		var b := Basis(Vector3.UP, -ang + PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(15, 55)))
		var sz := rng.randf_range(0.7, 1.0)
		Geo.card(lv, Vector3(cos(ang), 0.0, sin(ang)) * 0.28 + Vector3(0, 0.3, 0), b.scaled(Vector3(sz * 0.55, sz, sz)), _tint(rng, Color(0.75, 1.05, 0.7), 0.1))


static func grass(g: GeoMesh, rng: RandomNumberGenerator, flowers: bool) -> void:
	var gb := g.s("grass_blades")
	for i in 6:
		var ang := TAU * i / 6.0 + rng.randf() * 0.5
		var b := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-12, 12)))
		var sz := rng.randf_range(0.65, 0.95)
		Geo.card(gb, Vector3(0, sz * 0.5, 0), b.scaled(Vector3(sz * 1.2, sz, sz)), _tint(rng, Color(0.9, 1.0, 0.8), 0.12))
	if flowers:
		var plain := g.s("plain")
		var cols := [Color(0.98, 0.95, 0.9), Color(0.98, 0.85, 0.2), Color(0.8, 0.4, 0.9), Color(0.95, 0.3, 0.35), Color(0.5, 0.6, 1.0)]
		for i in 5:
			var base := Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
			var hgt := rng.randf_range(0.4, 0.7)
			Geo.rod(plain, base, base + Vector3(0, hgt, 0), 0.01, Color(0.3, 0.5, 0.2), 4)
			var c: Color = cols[rng.randi() % cols.size()]
			for p in 6:
				var a := TAU * p / 6.0
				Geo.blob(plain, base + Vector3(0, hgt, 0) + Vector3(cos(a), 0, sin(a)) * 0.04, Vector3(0.035, 0.012, 0.035), c, rng, 3, 5, 0.0)
			Geo.blob(plain, base + Vector3(0, hgt + 0.01, 0), Vector3(0.025, 0.02, 0.025), Color(0.95, 0.75, 0.1), rng, 3, 5, 0.0)


static func mushroom(g: GeoMesh, rng: RandomNumberGenerator) -> void:
	var plain := g.s("plain")
	for i in 4:
		var p := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
		var hgt := rng.randf_range(0.1, 0.22)
		var r := rng.randf_range(0.06, 0.14)
		Geo.prism(plain, p, 0.025, 0.03, hgt, Color(0.92, 0.9, 0.82), 7)
		var red := rng.randf() < 0.5
		var cap := Color(0.8, 0.12, 0.1) if red else Color(0.55, 0.35, 0.2)
		Geo.blob(plain, p + Vector3(0, hgt, 0), Vector3(r, r * 0.5, r), cap, rng, 4, 8, 0.03)
		if red:
			for k in 5:
				var a := rng.randf() * TAU
				Geo.blob(plain, p + Vector3(cos(a) * r * 0.5, hgt + r * 0.38, sin(a) * r * 0.5), Vector3(0.015, 0.008, 0.015), Color(1, 1, 0.95), rng, 3, 5, 0.0)


static func rock(g: GeoMesh, rng: RandomNumberGenerator, scale: float) -> void:
	var st := g.s("concrete")
	var moss := g.s("foliage")
	Geo.blob(st, Vector3(0, 0.3 * scale, 0), Vector3(0.7, 0.45, 0.6) * scale, Color(0.6, 0.6, 0.58), rng, 6, 9, 0.22, false)
	Geo.blob(st, Vector3(0.35 * scale, 0.2 * scale, 0.1 * scale), Vector3(0.4, 0.3, 0.38) * scale, Color(0.55, 0.55, 0.53), rng, 5, 8, 0.2, false)
	for i in 3:
		var a := rng.randf() * TAU
		Geo.blob(moss, Vector3(cos(a) * 0.35, 0.55, sin(a) * 0.3) * scale, Vector3(0.22, 0.07, 0.2) * scale, Color(0.22, 0.38, 0.14), rng, 4, 8, 0.15)


static func stump(g: GeoMesh, rng: RandomNumberGenerator) -> void:
	var bark := g.s("bark")
	var wood := g.s("wood")
	var moss := g.s("foliage")
	Geo.prism(bark, Vector3.ZERO, 0.4, 0.3, 0.5, Color(0.42, 0.33, 0.26), 11, Transform3D.IDENTITY, false)
	Geo.prism(wood, Vector3(0, 0.5, 0), 0.3, 0.3, 0.02, Color(0.85, 0.7, 0.5), 11)
	for i in 5:
		var a := TAU * i / 5.0
		Geo.rod(bark, Vector3(cos(a) * 0.55, 0, sin(a) * 0.55), Vector3(cos(a) * 0.3, 0.3, sin(a) * 0.3), 0.07, Color(0.4, 0.3, 0.24), 5)
	Geo.blob(moss, Vector3(0.2, 0.1, 0.1), Vector3(0.18, 0.08, 0.16), Color(0.2, 0.36, 0.13), rng, 4, 7, 0.12)


static func log_mesh(g: GeoMesh, rng: RandomNumberGenerator) -> void:
	# Бревно длиной 4 вдоль X, радиус 0.35
	var bark := g.s("bark")
	var wood := g.s("wood")
	var moss := g.s("foliage")
	var xf := Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(-2.0, 0.35, 0))
	bark.set_smooth_group(0)
	Geo.prism(bark, Vector3.ZERO, 0.35, 0.33, 4.0, Color(0.4, 0.31, 0.25), 12, xf, false)
	bark.set_smooth_group(-1)
	Geo.prism(wood, Vector3.ZERO, 0.33, 0.33, 0.02, Color(0.82, 0.66, 0.46), 12, xf)
	Geo.prism(wood, Vector3(0, 4.0, 0), 0.33, 0.33, 0.02, Color(0.82, 0.66, 0.46), 12, xf)
	for i in 6:
		Geo.blob(moss, Vector3(rng.randf_range(-1.8, 1.8), 0.66, rng.randf_range(-0.12, 0.12)), Vector3(rng.randf_range(0.2, 0.5), 0.07, 0.17), Color(0.22, 0.4, 0.14), rng, 4, 8, 0.15)
	for i in 3:
		var x := rng.randf_range(-1.4, 1.4)
		Geo.rod(bark, Vector3(x, 0.4, 0), Vector3(x + 0.4, 0.8, rng.randf_range(-0.5, 0.5)), 0.05, Color(0.38, 0.3, 0.24), 5)


static func reeds(g: GeoMesh, rng: RandomNumberGenerator) -> void:
	var gb := g.s("grass_blades")
	var plain := g.s("plain")
	for i in 7:
		var ang := TAU * i / 7.0 + rng.randf() * 0.4
		var b := Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-10, 10)))
		var sz := rng.randf_range(1.0, 1.5)
		Geo.card(gb, Vector3(0, sz * 0.5, 0), b.scaled(Vector3(sz * 0.8, sz, sz)), _tint(rng, Color(0.85, 1.0, 0.7), 0.1))
	for i in 3:
		var base := Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var hgt := rng.randf_range(1.1, 1.6)
		Geo.rod(plain, base, base + Vector3(0, hgt, 0), 0.012, Color(0.45, 0.5, 0.25), 4)
		Geo.prism(plain, base + Vector3(0, hgt - 0.25, 0), 0.04, 0.035, 0.25, Color(0.4, 0.25, 0.13), 6)


static func dead_tree(g: GeoMesh, rng: RandomNumberGenerator) -> void:
	var bark := g.s("bark")
	bark.set_smooth_group(0)
	Geo.prism(bark, Vector3.ZERO, 0.35, 0.1, 8.0, Color(0.5, 0.45, 0.4), 9)
	bark.set_smooth_group(-1)
	for i in 8:
		var y := rng.randf_range(2.0, 7.0)
		var ang := rng.randf() * TAU
		Geo.rod(bark, Vector3(0, y, 0), Vector3(cos(ang) * 1.3, y + rng.randf_range(0.2, 0.9), sin(ang) * 1.3), 0.04, Color(0.48, 0.43, 0.38), 5)
