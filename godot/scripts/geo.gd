class_name Geo
extends RefCounted
## Помощники процедурной геометрии: всё пишется в один SurfaceTool с цветами вершин.
## Материал: Geo.material() (цвет берётся из вершин).


static func material(rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	return m


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	return st


static func finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


## Выпуклый многоугольник; ориентация наружу определяется по точке inside.
static func poly(st: SurfaceTool, pts: Array, inside: Vector3, xf := Transform3D.IDENTITY) -> void:
	var a: Vector3 = pts[0]
	var n: Vector3 = (pts[1] - a).cross(pts[2] - a)
	var centroid := Vector3.ZERO
	for p in pts:
		centroid += p
	centroid /= pts.size()
	if n.dot(centroid - inside) < 0.0:
		pts = pts.duplicate()
		pts.reverse()
	for i in range(1, pts.size() - 1):
		st.add_vertex(xf * pts[0])
		st.add_vertex(xf * pts[i + 1])
		st.add_vertex(xf * pts[i])


static func box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, xf := Transform3D.IDENTITY) -> void:
	cbox(st, c, s, col, 0.0, xf)


## Коробка со скошенными рёбрами (фаска r) — выглядит мягче кубика.
static func cbox(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, r := 0.05, xf := Transform3D.IDENTITY) -> void:
	st.set_color(col)
	var h := s * 0.5
	r = clampf(r, 0.0, minf(h.x, minf(h.y, h.z)) * 0.9)
	if r <= 0.0001:
		for ax in 3:
			for sg in [-1.0, 1.0]:
				var pts := []
				for uv in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
					var p := Vector3.ZERO
					p[ax] = sg * h[ax]
					p[(ax + 1) % 3] = uv[0] * h[(ax + 1) % 3]
					p[(ax + 2) % 3] = uv[1] * h[(ax + 2) % 3]
					pts.append(c + p)
				poly(st, pts, c, xf)
		return
	# F(ax, sgn): точка на грани ax возле угла sgn (две другие оси ужаты на r)
	var F := func(ax: int, sg: Vector3) -> Vector3:
		var p := Vector3(sg.x * h.x, sg.y * h.y, sg.z * h.z)
		for k in 3:
			if k != ax:
				p[k] -= sg[k] * r
		return c + p
	# 6 граней
	for ax in 3:
		for sg in [-1.0, 1.0]:
			var pts := []
			for uv in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				var v := Vector3.ZERO
				v[ax] = sg
				v[(ax + 1) % 3] = uv[0]
				v[(ax + 2) % 3] = uv[1]
				pts.append(F.call(ax, v))
			poly(st, pts, c, xf)
	# 12 фасок по рёбрам: ребро вдоль оси e, между гранями a и b
	for e in 3:
		var a := (e + 1) % 3
		var b := (e + 2) % 3
		for sa in [-1.0, 1.0]:
			for sb in [-1.0, 1.0]:
				var lo := Vector3.ZERO
				lo[a] = sa
				lo[b] = sb
				lo[e] = -1.0
				var hi := lo
				hi[e] = 1.0
				poly(st, [F.call(a, lo), F.call(a, hi), F.call(b, hi), F.call(b, lo)], c, xf)
	# 8 угловых треугольников
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var sg := Vector3(sx, sy, sz)
				poly(st, [F.call(0, sg), F.call(1, sg), F.call(2, sg)], c, xf)


## Призма/цилиндр по оси Y: низ в c, высота hgt.
static func prism(st: SurfaceTool, c: Vector3, r_bottom: float, r_top: float, hgt: float, col: Color, n := 12, xf := Transform3D.IDENTITY, caps := true) -> void:
	st.set_color(col)
	var inside := c + Vector3(0, hgt * 0.5, 0)
	var bot := []
	var top := []
	for i in n:
		var ang := TAU * i / n
		var d := Vector3(cos(ang), 0, sin(ang))
		bot.append(c + d * r_bottom)
		top.append(c + d * r_top + Vector3(0, hgt, 0))
	for i in n:
		var j := (i + 1) % n
		var side := [bot[i], bot[j], top[j], top[i]]
		if r_top <= 0.0001:
			side = [bot[i], bot[j], top[i]]
		poly(st, side, inside, xf)
	if caps:
		poly(st, bot, inside, xf)
		if r_top > 0.0001:
			poly(st, top, inside, xf)


## Цилиндр между двумя точками (трубы, перила).
static func rod(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, col: Color, n := 10, xf := Transform3D.IDENTITY) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		return
	var y := dir / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var local := Transform3D(Basis(x, y, z), a)
	prism(st, Vector3.ZERO, radius, radius, length, col, n, xf * local)


## Неровный low-poly «комок» (крона дерева, куст).
static func blob(st: SurfaceTool, c: Vector3, radius: Vector3, col: Color, rng: RandomNumberGenerator, rings := 7, segs := 12, jitter := 0.12, smooth := true, xf := Transform3D.IDENTITY) -> void:
	if smooth:
		st.set_smooth_group(0)
	var verts := []
	for i in rings + 1:
		var row := []
		var phi := PI * i / rings
		for j in segs:
			var th := TAU * j / segs
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k := 1.0 + (rng.randf_range(-jitter, jitter) if i > 0 and i < rings else 0.0)
			row.append(c + d * radius * k)
		verts.append(row)
	for i in rings:
		for j in segs:
			var j2 := (j + 1) % segs
			var shade: Color = col.lightened(rng.randf_range(0.0, 0.12)) if i < rings / 2 else col.darkened(rng.randf_range(0.0, 0.15))
			st.set_color(shade)
			if i == 0:
				poly(st, [verts[0][j], verts[1][j], verts[1][j2]], c, xf)
			elif i == rings - 1:
				poly(st, [verts[i][j], verts[i + 1][j], verts[i][j2]], c, xf)
			else:
				poly(st, [verts[i][j], verts[i + 1][j], verts[i + 1][j2], verts[i][j2]], c, xf)
	st.set_smooth_group(-1)


## Двусторонняя карточка с UV (листва, трава). basis задаёт ориентацию и размер.
static func card(st: SurfaceTool, c: Vector3, b: Basis, col: Color, uv_rect := Rect2(0, 0, 1, 1)) -> void:
	var x := b.x * 0.5
	var y := b.y * 0.5
	var pts := [c - x - y, c + x - y, c + x + y, c - x + y]
	var uvs := [
		uv_rect.position + Vector2(0, uv_rect.size.y), uv_rect.position + uv_rect.size,
		uv_rect.position + Vector2(uv_rect.size.x, 0), uv_rect.position,
	]
	st.set_color(col)
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_uv(uvs[idx])
		st.add_vertex(pts[idx])


## Скруглённый «пузырь» вдоль отрезка (подушки, кот-талисман и пр.)
static func capsule(st: SurfaceTool, a: Vector3, b: Vector3, r: float, col: Color, rng: RandomNumberGenerator) -> void:
	var steps := 4
	for i in steps + 1:
		blob(st, a.lerp(b, float(i) / steps), Vector3.ONE * r, col, rng, 7, 12, 0.0)
