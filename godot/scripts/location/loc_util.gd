class_name LocUtil
extends RefCounted
## Помощники для генераторов локаций (tools/build_*.gd): материалы, примитивы, игрок, HUD, окружение.
## Общие для всех 8 локаций, чтобы не копировать код.

static var _mats := {}
static var _grain: NoiseTexture2D


## Общая мелкая «зернистость» (бетон, рубероид, дерево не выглядят пластиком)
static func grain() -> NoiseTexture2D:
	if _grain == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.frequency = 0.04
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		_grain = NoiseTexture2D.new()
		_grain.noise = n
		_grain.width = 256
		_grain.height = 256
		_grain.seamless = true
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0.82, 0.82, 0.82), Color(1, 1, 1)])
		_grain.color_ramp = g
	return _grain


static func mat(c: Color, rough := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(true), rough, metallic]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metallic
	if c.a >= 1.0:
		m.albedo_texture = grain()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.5
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func add(parent: Node, n: Node, nm: String, pos := Vector3.ZERO) -> Node:
	n.name = nm
	if n is Node3D:
		(n as Node3D).position = pos
	parent.add_child(n)
	return n


static func mesh(parent: Node, nm: String, m: Mesh, c: Color, pos := Vector3.ZERO, rough := 0.85, metallic := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(c, rough, metallic)
	return add(parent, mi, nm, pos) as MeshInstance3D


## Коробка. collide=true оборачивает в StaticBody3D с коллизией.
static func box(parent: Node, nm: String, size: Vector3, c: Color, pos: Vector3, collide := false, rough := 0.85, metallic := 0.0) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	add(parent, holder, nm, pos)
	var bm := BoxMesh.new()
	bm.size = size
	mesh(holder, "Mesh", bm, c, Vector3.ZERO, rough, metallic)
	if collide:
		box_shape(holder, size)
	return holder


static func box_shape(parent: Node, size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	return add(parent, cs, "Shape", pos) as CollisionShape3D


## Цилиндр (ось Y). top/bottom — радиусы.
static func cyl(parent: Node, nm: String, bottom: float, top: float, h: float, c: Color, pos: Vector3, seg := 12, rough := 0.85, metallic := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom
	cm.top_radius = top
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return mesh(parent, nm, cm, c, pos, rough, metallic)


static func sphere(parent: Node, nm: String, r: float, c: Color, pos: Vector3, squash := 1.0, hemi := false, rough := 0.85) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0 * squash if not hemi else r
	sm.is_hemisphere = hemi
	sm.radial_segments = 14
	sm.rings = 8
	return mesh(parent, nm, sm, c, pos, rough)


## Тонкий стержень между двумя точками (провод, растяжка, перила).
static func rod(parent: Node, nm: String, a: Vector3, b: Vector3, thick: float, c: Color, rough := 0.7, metallic := 0.0) -> MeshInstance3D:
	var d := b - a
	var holder := Node3D.new()
	add(parent, holder, nm, (a + b) * 0.5)
	var bm := BoxMesh.new()
	bm.size = Vector3(thick, thick, d.length())
	var mi := mesh(holder, "Mesh", bm, c, Vector3.ZERO, rough, metallic)
	if d.length() > 0.001:
		var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
		holder.look_at_from_position(holder.position, holder.position + d, up)
	return mi


static func label(parent: Node, nm: String, text: String, pos: Vector3, size := 0.5, c := Color.WHITE, outline := Color(0, 0, 0, 0.0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = size / 64.0
	l.modulate = c
	l.outline_size = 0 if outline.a == 0.0 else 8
	l.outline_modulate = outline
	l.shaded = true
	l.double_sided = false
	add(parent, l, nm, pos)
	return l


static func set_owner_rec(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		if c.scene_file_path == "":
			set_owner_rec(c, owner_node)


static func save_scene(root: Node, path: String) -> int:
	set_owner_rec(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("pack failed: %d" % err)
		return err
	err = ResourceSaver.save(packed, path)
	print("saved ", path, ": ", err)
	return err


# ---------- общие части сцены ----------

static func environment(parent: Node, sky_top: Color, sky_horizon: Color, sun_color: Color, sun_rot: Vector3, fog_density := 0.003, ambient := 0.6) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = sky_top
	sm.sky_horizon_color = sky_horizon
	sm.ground_horizon_color = sky_horizon
	sm.ground_bottom_color = sky_horizon.darkened(0.3)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.8
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = sky_horizon
	env.fog_density = fog_density
	we.environment = env
	add(parent, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = sun_color
	sun.light_energy = 0.55
	sun.rotation_degrees = sun_rot
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add(parent, sun, "Sun")


## Игрок в той же сборке, что и в лобби (RigidBody3D + модель Kenney + каска + камера).
static func player(parent: Node, pos: Vector3, nm := "Player1") -> RigidBody3D:
	var p := RigidBody3D.new()
	p.set_script(load("res://scripts/player.gd"))
	p.collision_layer = 1
	p.collision_mask = 1
	p.mass = 1.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	p.physics_material_override = pm
	add(parent, p, nm, pos)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.4
	cs.shape = cap
	add(p, cs, "Shape", Vector3(0, 0.7, 0))
	var model := Node3D.new()
	add(p, model, "Model")
	var ch: Node3D = load("res://assets/kenney/platformer/character.glb").instantiate()
	ch.scale = Vector3.ONE * 1.3
	add(model, ch, "Character")
	var helmet := SphereMesh.new()
	helmet.radius = 0.38
	helmet.height = 0.45
	helmet.is_hemisphere = true
	mesh(model, "Helmet", helmet, Color(1.0, 0.55, 0.1), Vector3(0, 1.25, 0))
	var ia := Area3D.new()
	ia.collision_layer = 0
	ia.collision_mask = 2
	var ics := CollisionShape3D.new()
	var iss := SphereShape3D.new()
	iss.radius = 0.8
	ics.shape = iss
	add(ia, ics, "Shape")
	add(p, ia, "InteractArea", Vector3(0, 0.7, 0))
	var fr := RayCast3D.new()
	fr.target_position = Vector3(0, -0.3, 0)
	fr.collision_mask = 1
	add(p, fr, "FloorRay", Vector3(0, 0.1, 0))
	var cam := Camera3D.new()
	cam.top_level = true
	cam.fov = 65
	cam.far = 400.0
	add(p, cam, "Camera", pos + Vector3(0, 6.5, 9))
	return p


static func trigger(parent: Node, nm: String, key: String, pos: Vector3, radius := 1.6) -> Interactable:
	var a := Interactable.new()
	a.prompt_key = key
	a.collision_layer = 2
	a.collision_mask = 0
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = radius
	cs.shape = ss
	add(a, cs, "Shape")
	add(parent, a, nm, pos)
	return a


## Невидимая зона, реагирующая на игроков (слой 1). Скрипт вешается снаружи.
static func zone(parent: Node, nm: String, size: Vector3, pos: Vector3, script_path := "") -> Area3D:
	var a := Area3D.new()
	if script_path != "":
		a.set_script(load(script_path))
	a.collision_layer = 0
	a.collision_mask = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add(a, cs, "Shape")
	add(parent, a, nm, pos)
	return a


static func checkpoint(parent: Node, nm: String, index: int, pos: Vector3) -> Area3D:
	var cp := Area3D.new()
	cp.set_script(load("res://scripts/checkpoint.gd"))
	cp.set("index", index)
	cp.collision_layer = 0
	cp.collision_mask = 1
	add(parent, cp, nm, pos)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.0, 1.6, 2.0)
	cs.shape = bs
	add(cp, cs, "Shape", Vector3(0, 0.8, 0))
	var flag: Node3D = load("res://assets/kenney/platformer/flag.glb").instantiate()
	add(cp, flag, "Flag", Vector3(0.6, 0, 0.6))
	return cp


static func hud(parent: Node) -> void:
	var cl := CanvasLayer.new()
	add(parent, cl, "HUD")
	var hint := Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-150, -90)
	hint.add_theme_font_size_override("font_size", 26)
	add(cl, hint, "Hint")
	var toast := Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-200, 40)
	toast.add_theme_font_size_override("font_size", 28)
	add(cl, toast, "Toast")
	var title := Label.new()
	title.position = Vector2(20, 16)
	title.add_theme_font_size_override("font_size", 24)
	add(cl, title, "Title")


## Волнистый лист (шифер). Ось X — вдоль ската, Z — поперёк. Верх на y=0, волна вдоль X.
static func corrugated(length: float, width: float, amp: float, wave: float, base: Color, stain: Color, seed_value := 1) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nz := int(width / wave * 4.0)
	var nx := maxi(int(length / 1.5), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.25
	var grid := []
	for i in nx + 1:
		var row := []
		for j in nz + 1:
			var x := length * i / nx
			var z := -width * 0.5 + width * j / nz
			var y := amp * sin(z / wave * TAU)
			var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
			var col := base.lerp(stain, clampf(n * 1.4 - 0.35, 0.0, 1.0))
			if int(floor((z + width) / wave)) % 7 == 3:
				col = col.darkened(0.08)  # заменённый лист
			row.append([Vector3(x, y, z), col])
		grid.append(row)
	for i in nx:
		for j in nz:
			var a: Array = grid[i][j]
			var b: Array = grid[i + 1][j]
			var c: Array = grid[i + 1][j + 1]
			var d: Array = grid[i][j + 1]
			for tri in [[a, b, c], [a, c, d]]:
				for v in tri:
					st.set_color(v[1])
					st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()


## Призма фронтона (треугольник) толщиной t, основание на y=0 шириной w, высота h; плоскость XY, толщина по Z.
static func gable(w: float, h: float, t: float, c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(c)
	var p := [Vector3(-w * 0.5, 0, -t * 0.5), Vector3(w * 0.5, 0, -t * 0.5), Vector3(0, h, -t * 0.5),
		Vector3(-w * 0.5, 0, t * 0.5), Vector3(w * 0.5, 0, t * 0.5), Vector3(0, h, t * 0.5)]
	var tris := [[3, 4, 5], [1, 0, 2], [0, 3, 5], [0, 5, 2], [4, 1, 2], [4, 2, 5], [0, 1, 4], [0, 4, 3]]
	for t3 in tris:
		for i in t3:
			st.add_vertex(p[i])
	st.generate_normals()
	return st.commit()
