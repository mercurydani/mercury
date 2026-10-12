class_name Aircraft
extends Node3D
# Самолёт: плавный фюзеляж, стреловидные крылья, двигатели. Нос смотрит в -X модели.
# Корневой узел только двигается, поворот (курс) делает дочерний body.

const SCALE := 1.4
const LENGTH := 6.4
const RADIUS := 0.58

var row := 0
var state := "arriving"   # arriving | ready | leaving
var phase := 0
var reverse := false
var ambient := false      # декоративный самолёт на полосе
var bags := 0
var need := 3
var fuel := 0.0
var pat := 40.0
var max_pat := 40.0
var delayed := false
var livery := Color("e63946")
var flight := "SU 100"
var blink := 0.0
var pos := Vector2.ZERO:
	set(v):
		pos = v
		position = Cfg.to3(v)

var body: Node3D
var body_mat: StandardMaterial3D
var beacon: MeshInstance3D
var info: Node3D
var bag_label: Label3D
var fuel_label: Label3D
var bar_fill: MeshInstance3D
var last_pos := Vector2.ZERO

func door_pt() -> Vector2:
	return pos + Cfg.DOOR_OFF

func fuel_pt() -> Vector2:
	return pos + Cfg.FUEL_OFF

# ---------- геометрия ----------
static func _profile(u: float) -> float:
	if u < 0.11:
		return sqrt(maxf(0.0, 1.0 - pow(1.0 - u / 0.11, 2.0)))
	if u < 0.66:
		return 1.0
	var t := (u - 0.66) / 0.34
	return lerpf(1.0, 0.1, pow(t, 1.25))

static func _lift(u: float) -> float:
	if u < 0.66:
		return 0.0
	var t := (u - 0.66) / 0.34
	return RADIUS * 0.65 * t * t

static func fuselage_mesh(livery: Color) -> ArrayMesh:
	var n := 44
	var m := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var white := Color("f4f6f9")
	var belly := Color("c9d0da")
	var grid: Array = []
	for i in n + 1:
		var u := float(i) / n
		var x := -LENGTH / 2.0 + u * LENGTH
		var r := _profile(u) * RADIUS
		var yc := _lift(u)
		var ring: Array = []
		for j in m:
			var a := TAU * j / m
			var v := cos(a)
			var col := white
			if v < -0.45:
				col = belly
			elif v < -0.05 and v > -0.4 and u > 0.1 and u < 0.9:
				col = livery
			if u > 0.8 and v > -0.2:
				col = livery
			ring.append([Vector3(x, yc + v * r, sin(a) * r), col])
		grid.append(ring)
	for i in n:
		for j in m:
			var j2 := (j + 1) % m
			var p00: Array = grid[i][j]
			var p01: Array = grid[i][j2]
			var p10: Array = grid[i + 1][j]
			var p11: Array = grid[i + 1][j2]
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var v0 := float(j) / m
			var v1 := float(j + 1) / m
			var uvs := {p00: Vector2(u0, v0), p10: Vector2(u1, v0), p11: Vector2(u1, v1), p01: Vector2(u0, v1)}
			for q in [p00, p10, p11, p00, p11, p01]:
				st.set_color(q[1])
				st.set_uv(uvs[q])
				st.add_vertex(q[0])
	st.generate_normals()
	return st.commit()

# Плита: четырёхугольник (a,b,c,d по кругу) с толщиной вдоль normal.
static func slab(corners: Array, normal: Vector3, th: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_color(col)
	var up: Array = []
	var dn: Array = []
	for c in corners:
		up.append(c + normal * th * 0.5)
		dn.append(c - normal * th * 0.5)
	var faces := [
		[up[0], up[1], up[2], up[3]],
		[dn[3], dn[2], dn[1], dn[0]],
		[up[0], dn[0], dn[1], up[1]],
		[up[1], dn[1], dn[2], up[2]],
		[up[2], dn[2], dn[3], up[3]],
		[up[3], dn[3], dn[0], up[0]],
	]
	for f in faces:
		for k in [0, 1, 2, 0, 2, 3]:
			var p: Vector3 = f[k]
			st.set_uv(Vector2(p.x + p.z * 0.3, p.z + p.y * 0.5) * 0.35)
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()

static func _vc_mat(rough: float = 0.4, metal: float = 0.1) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	var t := Tex.fuselage()
	mat.albedo_texture = t.albedo
	mat.normal_enabled = true
	mat.normal_texture = t.normal
	mat.normal_scale = 0.6
	mat.roughness = rough
	mat.metallic = metal
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func _mesh_node(parent: Node3D, mesh: ArrayMesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# Собирает модель в parent; возвращает материал фюзеляжа.
static func build_model(parent: Node3D, livery: Color, flight: String) -> Dictionary:
	var out := {}
	var fus := _mesh_node(parent, fuselage_mesh(livery), _vc_mat(0.35, 0.15))
	fus.position.y = 1.05
	out.mat = fus.material_override
	var wing_col := Color("dfe4ec")
	var wing_mat := _vc_mat(0.45, 0.2)
	for sz in [-1.0, 1.0]:
		var y0 := 0.85
		var wing := [
			Vector3(-0.3, y0, 0.45 * sz), Vector3(0.95, y0, 0.45 * sz),
			Vector3(1.75, y0 + 0.28, 2.15 * sz), Vector3(1.2, y0 + 0.28, 2.15 * sz),
		]
		if sz < 0.0:
			wing.reverse()
		_mesh_node(parent, slab(wing, Vector3.UP, 0.1, wing_col), wing_mat)
		var wl := [
			Vector3(1.55, y0 + 0.26, 2.15 * sz), Vector3(1.75, y0 + 0.26, 2.15 * sz),
			Vector3(1.8, y0 + 0.78, 2.2 * sz), Vector3(1.68, y0 + 0.78, 2.2 * sz),
		]
		_mesh_node(parent, slab(wl, Vector3(0, 0, 1), 0.05, livery), wing_mat)
		# горизонтальный стабилизатор
		var hs := [
			Vector3(2.55, 1.35, 0.2 * sz), Vector3(3.2, 1.38, 0.2 * sz),
			Vector3(3.3, 1.5, 1.15 * sz), Vector3(2.95, 1.5, 1.15 * sz),
		]
		if sz < 0.0:
			hs.reverse()
		_mesh_node(parent, slab(hs, Vector3.UP, 0.06, wing_col), wing_mat)
		# двигатель
		var ex := 0.3
		var ez: float = 1.0 * sz
		var nac := Rig.capsule(parent, 0.27, 1.15, Vector3(ex, 0.58, ez), Color("8d97a6"), Vector3(0, 0, 90))
		nac.material_override.metallic = 0.5
		nac.material_override.roughness = 0.3
		Rig.cyl(parent, 0.21, 0.21, 0.06, Vector3(ex - 0.56, 0.58, ez), Color("1c2230"), Vector3(0, 0, 90))
		Rig.cyl(parent, 0.1, 0.1, 0.07, Vector3(ex - 0.55, 0.58, ez), Color("aab4c3"), Vector3(0, 0, 90))
		Rig.box(parent, Vector3(0.5, 0.35, 0.07), Vector3(ex + 0.1, 0.8, ez), Color("8d97a6"))
		# навигационные огни
		var lc := Color("ff2d2d") if sz < 0.0 else Color("2dff6a")
		Rig.sphere(parent, 0.05, Vector3(1.62, 1.1, 2.2 * sz), lc, Vector3.ONE, 3.0)
	_details(parent, livery, wing_mat)
	# киль
	var fin := [
		Vector3(2.3, 1.55, 0), Vector3(3.2, 1.8, 0),
		Vector3(3.45, 3.0, 0), Vector3(3.0, 3.0, 0),
	]
	_mesh_node(parent, slab(fin, Vector3(0, 0, 1), 0.1, livery), wing_mat)
	Rig.sphere(parent, 0.17, Vector3(3.13, 2.3, 0.06), Color("ffffff"), Vector3(1.0, 1.0, 0.2))
	# кабина и окна
	Rig.sphere(parent, 0.3, Vector3(-2.62, 1.38, 0), Color("1f3a5f"), Vector3(1.3, 0.55, 1.5), 0.2)
	for i in 17:
		for sz in [-1.0, 1.0]:
			Rig.sphere(parent, 0.065, Vector3(-2.0 + i * 0.26, 1.35, 0.565 * sz), Color("5aa9ff"), Vector3(0.8, 1.0, 0.25), 0.4)
	# шасси
	for g in [Vector3(-2.1, 0.5, 0), Vector3(0.7, 0.5, 0.45), Vector3(0.7, 0.5, -0.45)]:
		Rig.cyl(parent, 0.045, 0.045, 0.6, g, Color("9aa4b3"))
		Rig.cyl(parent, 0.02, 0.02, 0.45, g + Vector3(0.12, 0.05, 0.0), Color("333b4a"), Vector3(0, 0, 40))
		for wz in ([-0.1, 0.1] if g.x > 0.0 else [-0.07, 0.07]):
			Rig.cyl(parent, 0.17, 0.17, 0.1, g + Vector3(0, -0.28, wz), Color("15181f"), Vector3(90, 0, 0))
			Rig.cyl(parent, 0.085, 0.085, 0.105, g + Vector3(0, -0.28, wz), Color("c8ced8"), Vector3(90, 0, 0))
	# номер рейса на борту
	for sz in [-1.0, 1.0]:
		var l := Rig.label(parent, flight, Vector3(-0.2, 1.1, 0.585 * sz), 40, Color("2b3345"), false)
		l.outline_size = 0
		l.pixel_size = 0.006
		if sz < 0.0:
			l.rotation_degrees.y = 180
	out.beacon = Rig.sphere(parent, 0.1, Vector3(0.5, 1.68, 0), Color("ff2d2d"), Vector3.ONE, 3.0)
	return out

static func _details(parent: Node3D, livery: Color, wing_mat: StandardMaterial3D) -> void:
	var metal := Color("9aa4b3")
	var seam := Color("aeb6c3")
	for sz in [-1.0, 1.0]:
		var y0 := 0.85
		# закрылки и элероны (накладки на крыле)
		for seg: Array in [[0.5, 1.2, 0.0], [1.3, 2.0, 0.0]]:
			var t0: float = (float(seg[0]) - 0.45) / 1.7
			var t1: float = (float(seg[1]) - 0.45) / 1.7
			var xa := lerpf(0.95, 1.2, t0) - 0.02
			var xb := lerpf(0.95, 1.2, t1) - 0.02
			var fl := [
				Vector3(lerpf(0.55, 1.2, t0), y0 + 0.28 * t0 + 0.06, seg[0] * sz),
				Vector3(xa + 0.0, y0 + 0.28 * t0 + 0.06, seg[0] * sz),
				Vector3(xb, y0 + 0.28 * t1 + 0.06, seg[1] * sz),
				Vector3(lerpf(0.55, 1.2, t1), y0 + 0.28 * t1 + 0.06, seg[1] * sz),
			]
			if sz < 0.0:
				fl.reverse()
			_mesh_node(parent, slab(fl, Vector3.UP, 0.012, seam), wing_mat)
		# воздушные тормоза-линии на передней кромке
		Rig.box(parent, Vector3(0.04, 0.02, 1.7), Vector3(0.33, y0 + 0.17, 1.25 * sz), Color("c0c8d4"), Vector3(0, 21 * sz, 0))
		# стойки-пилоны двигателей уже есть; обтекатель шасси на крыле
		Rig.sphere(parent, 0.28, Vector3(0.75, 0.7, 0.55 * sz), Color("e4e8ee"), Vector3(2.2, 0.55, 0.9))
		# лопатки вентилятора и обтекатель
		var ex := 0.3
		var ez: float = 1.0 * sz
		for k in 12:
			var fb := Rig.box(parent, Vector3(0.012, 0.19, 0.045), Vector3(ex - 0.52, 0.58, ez), Color("c8ced8"), Vector3(k * 30.0, 0, 0))
			fb.rotation_degrees.x = k * 30.0
		Rig.cyl(parent, 0.0, 0.07, 0.14, Vector3(ex - 0.6, 0.58, ez), Color("e8ecf2"), Vector3(0, 0, 90))
		Rig.torus(parent, 0.22, 0.29, Vector3(ex - 0.575, 0.58, ez), Color("d0d6df"), Vector3(0, 0, 90)).scale = Vector3(1.0, 0.5, 1.0)
		Rig.cyl(parent, 0.16, 0.09, 0.22, Vector3(ex + 0.62, 0.58, ez), Color("3a404c"), Vector3(0, 0, 90))
		Rig.cyl(parent, 0.28, 0.28, 0.02, Vector3(ex + 0.2, 0.58 + 0.275, ez), Color("e63946"), Vector3(0, 0, 90)).scale = Vector3(1.0, 1.0, 0.1)
		# створки шасси
		Rig.box(parent, Vector3(0.9, 0.02, 0.28), Vector3(0.7, 0.48, 0.58 * sz), Color("aab3c0"), Vector3(0, 0, 0))
	# ветровые стёкла кабины
	for k in 4:
		var sx := -1.0 + k * 0.5 - 0.25
		Rig.box(parent, Vector3(0.2, 0.2, 0.012), Vector3(-2.55 - 0.02 * abs(sx), 1.43, sx * 0.42), Color("0e1e33"), Vector3(0, sx * 38.0, -24), 0.15)
	# нос: радом и приёмник
	Rig.sphere(parent, 0.2, Vector3(-3.15, 1.05, 0), Color("565d6a"), Vector3(0.9, 0.9, 0.9))
	Rig.cyl(parent, 0.012, 0.012, 0.3, Vector3(-3.0, 1.18, 0.38), Color("c8ced8"), Vector3(0, 0, 90))
	Rig.cyl(parent, 0.012, 0.012, 0.3, Vector3(-3.0, 1.18, -0.38), Color("c8ced8"), Vector3(0, 0, 90))
	# антенны, приёмники, маяк, спутниковый обтекатель
	Rig.cyl(parent, 0.015, 0.015, 0.4, Vector3(-1.4, 1.8, 0), Color("333b4a"))
	Rig.cyl(parent, 0.015, 0.015, 0.3, Vector3(1.6, 0.4, 0), Color("333b4a"))
	Rig.sphere(parent, 0.25, Vector3(-0.6, 1.62, 0), Color("f4f6f9"), Vector3(2.2, 0.35, 0.8))
	Rig.sphere(parent, 0.06, Vector3(3.3, 1.55, 0), Color("ffffff"), Vector3.ONE, 3.0)
	# АПУ и рули
	Rig.cyl(parent, 0.14, 0.04, 0.5, Vector3(3.5, 1.38, 0), Color("3a404c"), Vector3(0, 0, 90))
	Rig.box(parent, Vector3(0.02, 1.0, 0.12), Vector3(3.3, 2.4, 0), seam, Vector3(0, 0, 14))
	Rig.cyl(parent, 0.1, 0.1, 0.02, Vector3(3.0, 2.35, 0.075), livery, Vector3(90, 0, 0))
	# багажные люки на брюхе
	Rig.box(parent, Vector3(0.5, 0.012, 0.38), Vector3(1.2, 0.46, 0.0), Color("aab3c0"))
	Rig.box(parent, Vector3(0.5, 0.012, 0.38), Vector3(-1.5, 0.46, 0.0), Color("aab3c0"))

func _ready() -> void:
	body = Node3D.new()
	body.scale = Vector3.ONE * SCALE
	body.rotation.y = 0.0
	add_child(body)
	var m := build_model(body, livery, flight)
	body_mat = m.mat
	beacon = m.beacon
	beacon.visible = false
	last_pos = pos
	if ambient:
		return
	info = Node3D.new()
	info.position = Vector3(0, 4.6, 0)
	add_child(info)
	Rig.box(info, Vector3(2.8, 0.2, 0.1), Vector3.ZERO, Color(0, 0, 0, 0.6))
	bar_fill = Rig.box(info, Vector3(2.7, 0.13, 0.12), Vector3.ZERO, Color("7dff8a"), Vector3.ZERO, 1.0)
	var door := Cfg.to3(Cfg.DOOR_OFF, 2.1)
	var fuel_p := Cfg.to3(Cfg.FUEL_OFF, 2.1)
	bag_label = Rig.label(self, "", door, 40, Color("ffd24d"))
	fuel_label = Rig.label(self, "", fuel_p, 40, Color("ff9f43"))
	info.visible = false

func _process(delta: float) -> void:
	blink += delta
	if ambient:
		return
	# курс по направлению движения
	var v := (pos - last_pos) / maxf(delta, 0.0001)
	last_pos = pos
	if v.length() > 8.0:
		var wd := Vector2(v.y, v.x)   # мировые X, Z
		if reverse:
			wd = -wd
		body.rotation.y = lerp_angle(body.rotation.y, atan2(wd.y, -wd.x), minf(1.0, delta * 2.4))
	var ready := state == "ready"
	info.visible = ready
	bag_label.visible = ready
	fuel_label.visible = ready
	if ready:
		var r := clampf(pat / max_pat, 0.0, 1.0)
		bar_fill.scale.x = maxf(r, 0.001)
		bar_fill.position.x = -1.35 * (1.0 - r)
		var col := Color("7dff8a") if r > 0.5 else (Color("ffd24d") if r > 0.25 else Color("ff5a4d"))
		bar_fill.material_override.albedo_color = col
		bar_fill.material_override.emission = col
		bag_label.text = "багаж %d/%d" % [bags, need]
		fuel_label.text = "топливо %d%%" % int(fuel)
	body_mat.albedo_color = Color(1.0, 0.72, 0.72) if delayed else Color.WHITE
	beacon.visible = delayed and int(blink * 3.0) % 2 == 0
