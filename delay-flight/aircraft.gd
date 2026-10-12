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
			for q in [p00, p10, p11, p00, p11, p01]:
				st.set_color(q[1])
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
			st.add_vertex(f[k])
	st.generate_normals()
	return st.commit()

static func _vc_mat(rough: float = 0.4, metal: float = 0.1) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
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
		Rig.cyl(parent, 0.04, 0.04, 0.6, g, Color("333b4a"))
		Rig.cyl(parent, 0.15, 0.15, 0.13, g + Vector3(0, -0.25, 0.0), Color("15181f"), Vector3(90, 0, 0))
	# номер рейса на борту
	for sz in [-1.0, 1.0]:
		var l := Rig.label(parent, flight, Vector3(-0.2, 1.1, 0.585 * sz), 40, Color("2b3345"), false)
		l.outline_size = 0
		l.pixel_size = 0.006
		if sz < 0.0:
			l.rotation_degrees.y = 180
	out.beacon = Rig.sphere(parent, 0.1, Vector3(0.5, 1.68, 0), Color("ff2d2d"), Vector3.ONE, 3.0)
	return out

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
