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

# Человек. Модель смотрит вдоль +Z. o: s, bulk, shirt, vest, hat, hat_col, ears, skin, shades, tie, headset, pants, brow, arm
static func person(o: Dictionary) -> Node3D:
	var root := Node3D.new()
	var s: float = o.get("s", 1.0)
	var bulk: float = o.get("bulk", 1.0)
	root.scale = Vector3.ONE * s
	var skin: Color = o.get("skin", Color("e8b48a"))
	var shirt: Color = o.get("shirt", Color("3a4252"))
	var pants: Color = o.get("pants", Color("262d3d"))
	var arm: Color = o.get("arm", shirt)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0.0 else "LegR"
		leg.position = Vector3(0.12 * side, 0.42, 0)
		root.add_child(leg)
		box(leg, Vector3(0.17, 0.42, 0.19), Vector3(0, -0.21, 0), pants)
		box(leg, Vector3(0.19, 0.08, 0.28), Vector3(0, -0.4, 0.04), Color("151a24"))
		var a := Node3D.new()
		a.name = "ArmL" if side < 0.0 else "ArmR"
		a.position = Vector3(0.3 * side * bulk, 0.88, 0)
		root.add_child(a)
		box(a, Vector3(0.13 * bulk, 0.38, 0.14 * bulk), Vector3(0, -0.19, 0), arm)
		sphere(a, 0.08 * bulk, Vector3(0, -0.4, 0), skin)
		if bulk > 1.0:
			sphere(a, 0.13 * bulk, Vector3(0, -0.1, 0), skin)
	box(root, Vector3(0.46 * bulk, 0.5, 0.28), Vector3(0, 0.67, 0), shirt)
	var vest: Color = o.get("vest", Color(0, 0, 0, 0))
	if vest.a > 0.0:
		box(root, Vector3(0.48 * bulk, 0.44, 0.31), Vector3(0, 0.69, 0), vest)
		box(root, Vector3(0.5 * bulk, 0.06, 0.33), Vector3(0, 0.62, 0), Color("e8eef5"))
		box(root, Vector3(0.5 * bulk, 0.06, 0.33), Vector3(0, 0.8, 0), Color("e8eef5"))
	if o.get("tie", false):
		box(root, Vector3(0.07, 0.3, 0.02), Vector3(0, 0.7, 0.15), Color("c0392b"))
	# голова
	var hy := 1.12
	sphere(root, 0.19, Vector3(0, hy, 0), skin)
	box(root, Vector3(0.08, 0.1, 0.08), Vector3(0, 0.95, 0), skin)
	if o.get("ears", false):
		sphere(root, 0.085, Vector3(-0.2, hy, 0), Color("e04b2f"))
		sphere(root, 0.085, Vector3(0.2, hy, 0), Color("e04b2f"))
		box(root, Vector3(0.42, 0.04, 0.05), Vector3(0, hy + 0.17, 0), Color("333333"))
	if o.get("shades", false):
		box(root, Vector3(0.32, 0.07, 0.05), Vector3(0, hy + 0.01, 0.17), Color("0b0b0b"))
	else:
		sphere(root, 0.025, Vector3(-0.07, hy + 0.01, 0.18), Color("111111"))
		sphere(root, 0.025, Vector3(0.07, hy + 0.01, 0.18), Color("111111"))
		if o.get("brow", false):
			box(root, Vector3(0.1, 0.025, 0.03), Vector3(-0.07, hy + 0.07, 0.18), Color("111111"), Vector3(0, 0, -22))
			box(root, Vector3(0.1, 0.025, 0.03), Vector3(0.07, hy + 0.07, 0.18), Color("111111"), Vector3(0, 0, 22))
	box(root, Vector3(0.1, 0.02, 0.03), Vector3(0, hy - 0.1, 0.18), Color("5a1f1f"))
	var hat: String = o.get("hat", "")
	var hc: Color = o.get("hat_col", Color.WHITE)
	if hat == "helmet":
		hemi(root, 0.225, Vector3(0, hy + 0.04, 0), hc)
		cyl(root, 0.25, 0.25, 0.03, Vector3(0, hy + 0.045, 0), hc.darkened(0.2))
	elif hat == "cap":
		hemi(root, 0.205, Vector3(0, hy + 0.05, 0), hc)
		box(root, Vector3(0.2, 0.025, 0.14), Vector3(0, hy + 0.06, 0.2), hc.darkened(0.25))
	elif hat == "pilot":
		hemi(root, 0.21, Vector3(0, hy + 0.06, 0), Color("1b2a52"))
		cyl(root, 0.215, 0.215, 0.04, Vector3(0, hy + 0.08, 0), Color("ffd24d"))
		box(root, Vector3(0.22, 0.025, 0.14), Vector3(0, hy + 0.07, 0.2), Color("111a33"))
	elif hat == "bandana":
		hemi(root, 0.2, Vector3(0, hy + 0.07, 0), Color("c0392b"))
	if o.get("headset", false):
		sphere(root, 0.07, Vector3(-0.2, hy, 0), Color("111111"))
		box(root, Vector3(0.02, 0.02, 0.15), Vector3(-0.19, hy - 0.08, 0.1), Color("111111"))
		box(root, Vector3(0.4, 0.03, 0.03), Vector3(0, hy + 0.19, 0), Color("111111"))
	return root

static func animate(rig: Node3D, walk: float, moving: bool) -> void:
	var a := sin(walk) * 0.8 if moving else 0.0
	rig.get_node("LegL").rotation.x = a
	rig.get_node("LegR").rotation.x = -a
	rig.get_node("ArmL").rotation.x = -a
	rig.get_node("ArmR").rotation.x = a

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
