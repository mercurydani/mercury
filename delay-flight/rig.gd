class_name Rig
# Сборка 3D-моделей из примитивов: люди, предметы, мелкие детали.

static func mat(col: Color, rough: float = 0.85, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	if col.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, rot: Vector3, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(col, 0.85, emit)
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(parent, m, pos, col, rot, emit)

static func sphere(parent: Node3D, r: float, pos: Vector3, col: Color, squash: Vector3 = Vector3.ONE, emit: float = 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	var mi := _add(parent, m, pos, col, Vector3.ZERO, emit)
	mi.scale = squash
	return mi

static func hemi(parent: Node3D, r: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r
	m.is_hemisphere = true
	m.radial_segments = 16
	m.rings = 6
	return _add(parent, m, pos, col, Vector3.ZERO)

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = 20
	return _add(parent, m, pos, col, rot, emit)

static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	return _add(parent, m, pos, col, rot, emit)

static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 20
	m.rings = 8
	return _add(parent, m, pos, col, rot)

static func label(parent: Node3D, text: String, pos: Vector3, size: int, col: Color, billboard: bool = true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.009
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
	parent.add_child(l)
	return l

# Предмет в руках / на земле.
static func item(kind: String) -> Node3D:
	var r := Node3D.new()
	match kind:
		"bag":
			box(r, Vector3(0.36, 0.27, 0.15), Vector3(0, 0.14, 0), Color("b5651d"))
			box(r, Vector3(0.38, 0.04, 0.16), Vector3(0, 0.12, 0), Color("7a4310"))
			box(r, Vector3(0.14, 0.03, 0.03), Vector3(0, 0.3, 0), Color("3b2a1a"))
			box(r, Vector3(0.05, 0.05, 0.17), Vector3(0, 0.14, 0), Color("ffd24d"))
		"coffee":
			cyl(r, 0.1, 0.075, 0.24, Vector3(0, 0.12, 0), Color("f4f4f4"))
			cyl(r, 0.103, 0.095, 0.08, Vector3(0, 0.14, 0), Color("8b5a2b"))
			cyl(r, 0.11, 0.11, 0.03, Vector3(0, 0.25, 0), Color("6b4423"))
		"burger":
			hemi(r, 0.15, Vector3(0, 0.12, 0), Color("d9893b"))
			cyl(r, 0.15, 0.15, 0.05, Vector3(0, 0.1, 0), Color("5a2d0c"))
			cyl(r, 0.16, 0.16, 0.025, Vector3(0, 0.07, 0), Color("6bbf3a"))
			cyl(r, 0.15, 0.15, 0.06, Vector3(0, 0.04, 0), Color("d9893b"))
		"fuel":
			box(r, Vector3(0.26, 0.32, 0.14), Vector3(0, 0.16, 0), Color("ff9f43"))
			box(r, Vector3(0.08, 0.06, 0.08), Vector3(0.06, 0.35, 0), Color("2b3345"))
	return r
