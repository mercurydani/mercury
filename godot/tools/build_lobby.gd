@tool
extends SceneTree
## Генерирует res://scenes/lobby.tscn: двор внутри городского квартала.
## Запуск: godot --headless --path godot --script res://tools/build_lobby.gd
## Модели: CC0-наборы Kenney из res://assets/kenney (см. LICENSE.md там же).

const CITY := "res://assets/kenney/city/"
const PLAT := "res://assets/kenney/platformer/"
const RACE := "res://assets/kenney/racing/"

# Двор: x от -18 до 18, z от -14 до 12. Вокруг дома, на юге улица.
const YARD_MIN := Vector2(-18, -14)
const YARD_MAX := Vector2(18, 12)

var lobby_root: Node3D
var _mesh_i := 0


func _init() -> void:
	lobby_root = Node3D.new()
	lobby_root.name = "Lobby"
	lobby_root.set_script(load("res://scripts/lobby.gd"))
	DirAccess.make_dir_recursive_absolute("res://scenes/generated")
	for f in DirAccess.get_files_at("res://scenes/generated"):
		DirAccess.remove_absolute("res://scenes/generated/" + f)

	_environment()
	_city()
	_yard()
	_van()
	_stall()
	_slot_machine()
	_mascot()
	_parkour()
	_players()
	_hud()

	_set_owner(lobby_root, lobby_root)
	var packed := PackedScene.new()
	var err := packed.pack(lobby_root)
	if err != OK:
		push_error("pack failed: %d" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://scenes/lobby.tscn")
	print("saved lobby.tscn: ", err)
	lobby_root.free()
	quit(0 if err == OK else 1)


# ---------- helpers ----------

func _mat(c: Color, metallic := 0.0, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


func _add(parent: Node, n: Node, nm: String, pos := Vector3.ZERO) -> Node:
	n.name = nm
	if n is Node3D:
		(n as Node3D).position = pos
	parent.add_child(n)
	return n


func _mesh(parent: Node, nm: String, mesh: Mesh, color: Color, pos := Vector3.ZERO, metallic := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, metallic)
	return _add(parent, mi, nm, pos) as MeshInstance3D


func _box(parent: Node, nm: String, size: Vector3, color: Color, pos: Vector3, collide := true) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	_add(parent, holder, nm, pos)
	var bm := BoxMesh.new()
	bm.size = size
	_mesh(holder, "Mesh", bm, color)
	if collide:
		_box_shape(holder, size, Vector3.ZERO)
	return holder


func _box_shape(parent: Node, size: Vector3, center: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	return _add(parent, cs, "Shape", center) as CollisionShape3D


func _aabb_of(n: Node, xf: Transform3D, acc: Array) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var a: AABB = t * (n as MeshInstance3D).get_aabb()
		acc[0] = a if acc[0] == null else (acc[0] as AABB).merge(a)
	for c in n.get_children():
		_aabb_of(c, t, acc)


func _model_aabb(path: String) -> AABB:
	var inst: Node = load(path).instantiate()
	var acc := [null]
	_aabb_of(inst, Transform3D.IDENTITY, acc)
	inst.free()
	return acc[0]


## Модель из glb. collide=true оборачивает её в StaticBody3D с коробкой по габаритам.
func _model(parent: Node, nm: String, path: String, pos: Vector3, scale := 1.0, rot_y := 0.0, collide := false) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	_add(parent, holder, nm, pos)
	holder.rotation_degrees.y = rot_y
	var inst: Node3D = load(path).instantiate()
	inst.scale = Vector3.ONE * scale
	_add(holder, inst, "Model")
	if collide:
		var a := _model_aabb(path)
		_box_shape(holder, a.size * scale, (a.position + a.size * 0.5) * scale)
	return holder


func _trigger(parent: Node, nm: String, key: String, pos: Vector3, radius := 2.2) -> Interactable:
	var a := Interactable.new()
	a.prompt_key = key
	a.collision_layer = 2
	a.collision_mask = 0
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = radius
	cs.shape = ss
	_add(a, cs, "Shape")
	_add(parent, a, nm, pos)
	return a


## Владелец нужен всем узлам, кроме внутренностей вложенных .glb-сцен.
func _set_owner(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		if c.scene_file_path == "":
			_set_owner(c, owner_node)


func _khrushchevka(parent: Node, nm: String, pos: Vector3, rot_y: float, sections: int, seed_value: int, color: Color) -> void:
	var k := StaticBody3D.new()
	k.set_script(load("res://scripts/khrushchevka.gd"))
	k.set("sections", sections)
	k.set("seed_value", seed_value)
	k.set("panel_color", color)
	_add(parent, k, nm, pos)
	k.rotation_degrees.y = rot_y


func _tree(parent: Node, pos: Vector3, kind: int, seed_value: int, h: float) -> void:
	var t := StaticBody3D.new()
	t.set_script(load("res://scripts/tree.gd"))
	t.set("kind", kind)
	t.set("seed_value", seed_value)
	t.set("height", h)
	_add(parent, t, "Tree%d" % seed_value, pos)


# ---------- окружение и город ----------

func _environment() -> void:
	# Тёплый вечер: низкое мягкое солнце, золотистое небо, лёгкая дымка
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.42, 0.62)
	sm.sky_horizon_color = Color(0.98, 0.72, 0.45)
	sm.sky_curve = 0.12
	sm.ground_horizon_color = Color(0.85, 0.62, 0.42)
	sm.ground_bottom_color = Color(0.3, 0.27, 0.26)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.ambient_light_sky_contribution = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.5
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.7, 0.48)
	env.fog_density = 0.0025
	env.fog_sun_scatter = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.05
	we.environment = env
	_add(lobby_root, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.74, 0.46)
	sun.light_energy = 0.75
	sun.rotation_degrees = Vector3(-22, -55, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 80.0
	_add(lobby_root, sun, "Sun")


## Процедурный меш: fn(st) рисует в SurfaceTool через Geo.
func _proc(parent: Node, nm: String, pos: Vector3, fn: Callable, rot_y := 0.0) -> MeshInstance3D:
	var g := GeoMesh.new()
	fn.call(g)
	var mi := MeshInstance3D.new()
	var mesh := g.build()
	# Меши сохраняем отдельными бинарными файлами, чтобы .tscn оставался лёгким
	_mesh_i += 1
	var path := "res://scenes/generated/%s_%d.mesh" % [nm.to_snake_case(), _mesh_i]
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	mesh.take_over_path(path)
	mi.mesh = mesh
	_add(parent, mi, nm, pos)
	mi.rotation_degrees.y = rot_y
	return mi


func _lamp_post(parent: Node, nm: String, pos: Vector3, rot_y := 0.0) -> void:
	var holder := StaticBody3D.new()
	_add(parent, holder, nm, pos)
	holder.rotation_degrees.y = rot_y
	_proc(holder, "Mesh", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var st := gm.s("metal")
		Geo.prism(st, Vector3.ZERO, 0.16, 0.12, 0.5, Color(0.3, 0.32, 0.3), 8)
		Geo.rod(st, Vector3(0, 0.4, 0), Vector3(0, 5.2, 0), 0.07, Color(0.3, 0.32, 0.3), 8)
		Geo.rod(st, Vector3(0, 5.1, 0), Vector3(0, 5.35, 0.9), 0.05, Color(0.3, 0.32, 0.3), 6)
		Geo.cbox(st, Vector3(0, 5.3, 1.05), Vector3(0.35, 0.18, 0.55), Color(0.25, 0.27, 0.25), 0.05))
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.13
	bm.height = 0.2
	bulb.mesh = bm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1, 0.85, 0.6)
	lm.emission_enabled = true
	lm.emission = Color(1.0, 0.75, 0.4)
	lm.emission_energy_multiplier = 3.0
	bulb.material_override = lm
	_add(holder, bulb, "Bulb", Vector3(0, 5.18, 1.05))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.38)
	l.light_energy = 2.0
	l.omni_range = 11.0
	l.omni_attenuation = 1.3
	_add(holder, l, "Light", Vector3(0, 5.0, 1.05))
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.15
	cyl.height = 5.2
	cs.shape = cyl
	_add(holder, cs, "Shape", Vector3(0, 2.6, 0))


func _bench(parent: Node, nm: String, pos: Vector3, rot_y := 0.0) -> void:
	var b := StaticBody3D.new()
	_add(parent, b, nm, pos)
	b.rotation_degrees.y = rot_y
	_proc(b, "Mesh", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var st := gm.s("wood")
		var wood := Color(0.55, 0.36, 0.22)
		for i in 4:
			Geo.cbox(st, Vector3(0, 0.45, -0.22 + i * 0.15), Vector3(2.0, 0.05, 0.12), wood.darkened(0.05 * (i % 2)), 0.02)
		for i in 3:
			Geo.cbox(st, Vector3(0, 0.62 + i * 0.16, -0.36 - i * 0.03), Vector3(2.0, 0.11, 0.04), wood, 0.015)
		for sx in [-0.85, 0.85]:
			Geo.cbox(gm.s("metal"), Vector3(sx, 0.22, 0), Vector3(0.08, 0.44, 0.5), Color(0.2, 0.2, 0.22), 0.02)
			Geo.cbox(gm.s("metal"), Vector3(sx, 0.7, -0.38), Vector3(0.06, 0.6, 0.06), Color(0.2, 0.2, 0.22), 0.02))
	_box_shape(b, Vector3(2.0, 0.5, 0.6), Vector3(0, 0.25, 0))


func _city() -> void:
	var c := Node3D.new()
	_add(lobby_root, c, "City")
	# Земля квартала (асфальт), на ней всё стоит
	var ground := StaticBody3D.new()
	_add(c, ground, "Ground")
	_proc(ground, "Mesh", Vector3.ZERO, func(gm: GeoMesh) -> void:
		Geo.box(gm.s("asphalt"), Vector3(0, -0.5, 0), Vector3(140, 1.0, 140), Color(0.85, 0.85, 0.85)))
	_box_shape(ground, Vector3(140, 1.0, 140), Vector3(0, -0.5, 0))
	var b := Node3D.new()
	_add(c, b, "Buildings")
	# Хрущёвки вокруг двора, фасадом с подъездами во двор
	_khrushchevka(b, "North", Vector3(0, 0, -19.5), 0.0, 4, 11, Color(0.8, 0.78, 0.72))
	_khrushchevka(b, "West", Vector3(-24.5, 0, 0), 90.0, 3, 12, Color(0.82, 0.74, 0.66))
	_khrushchevka(b, "East", Vector3(24.5, 0, 0), -90.0, 3, 13, Color(0.74, 0.76, 0.78))
	_khrushchevka(b, "South", Vector3(0, 0, 31), 180.0, 5, 14, Color(0.8, 0.75, 0.62))
	# Улица на юге: дорога с фонарями, тротуар и дома напротив
	var road := Node3D.new()
	_add(c, road, "Street")
	_proc(road, "Road", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		# Проезжая часть чуть темнее, разметка, бордюры и тротуары
		Geo.box(gm.s("asphalt"), Vector3(0, 0.005, 19), Vector3(110, 0.01, 7.6), Color(0.7, 0.7, 0.72))
		for x in range(-54, 55, 4):
			Geo.box(gm.s("plain"), Vector3(x, 0.012, 19), Vector3(2.0, 0.005, 0.14), Color(0.85, 0.83, 0.75))
		for sz in [-1.0, 1.0]:
			Geo.cbox(gm.s("concrete"), Vector3(0, 0.09, 19 + sz * 3.9), Vector3(110, 0.18, 0.25), Color(0.75, 0.74, 0.72), 0.04)
			Geo.box(gm.s("concrete"), Vector3(0, 0.08, 19 + sz * 5.4), Vector3(110, 0.16, 2.8), Color(0.62, 0.6, 0.58))
		# Плитка тротуара швами
		for x in range(-54, 55, 1):
			for sz in [-1.0, 1.0]:
				Geo.box(gm.s("plain"), Vector3(x, 0.165, 19 + sz * 5.4), Vector3(0.02, 0.005, 2.8), Color(0.35, 0.34, 0.33))
		# Ливнёвки
		for x in range(-50, 51, 12):
			Geo.box(gm.s("metal"), Vector3(x, 0.015, 15.55), Vector3(0.8, 0.01, 0.4), Color(0.2, 0.2, 0.2)))
	# Припаркованные машины
	_model(road, "CarGreen", RACE + "vehicle-truck-green.glb", Vector3(-14, 0, 16.5), 1.8, 90.0, true)
	_model(road, "CarPurple", RACE + "vehicle-truck-purple.glb", Vector3(12, 0, 21.5), 1.8, -90.0, true)


func _yard() -> void:
	var y := Node3D.new()
	_add(lobby_root, y, "Yard")
	# Асфальт двора пятнами разного оттенка, газоны с бордюрами, площадка
	var lawns := [
		Rect2(-18, -13.4, 4.2, 12.0), Rect2(14.2, -13.4, 3.8, 11.5),
		Rect2(-18, 9.0, 13.5, 2.6), Rect2(4.0, 9.0, 14.0, 2.6),
		Rect2(-14.5, -13.4, 9.0, 0.9), Rect2(-1.5, -13.4, 12.0, 0.9),
	]
	_proc(y, "Ground", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var st := gm.s("asphalt")
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for x in range(-18, 18, 3):
			for z in range(-14, 12, 3):
				var tone := Color(1.0, 1.0, 1.0).darkened(rng.randf_range(-0.05, 0.15))
				Geo.box(st, Vector3(x + 1.5, -0.04, z + 1.5), Vector3(3.0, 0.08, 3.0), tone)
		# Трещины и заплатки
		for i in 30:
			# Трещина: ломаная из тонких полосок
			var p := Vector3(rng.randf_range(-17, 17), 0.004, rng.randf_range(-13, 11))
			var ang := rng.randf() * TAU
			for k in 4:
				var seg := rng.randf_range(0.3, 0.8)
				var d := Vector3(cos(ang), 0, sin(ang))
				Geo.box(st, Vector3.ZERO, Vector3(seg, 0.008, 0.035), Color(0.2, 0.2, 0.21), Transform3D(Basis(Vector3.UP, -ang), p + d * seg * 0.5))
				p += d * seg
				ang += rng.randf_range(-0.6, 0.6)
		for r in lawns:
			var rr := r as Rect2
			var c := Vector3(rr.position.x + rr.size.x * 0.5, 0.0, rr.position.y + rr.size.y * 0.5)
			Geo.cbox(gm.s("concrete"), c + Vector3(0, 0.07, 0), Vector3(rr.size.x, 0.14, rr.size.y), Color(0.72, 0.71, 0.68), 0.03)
			Geo.box(gm.s("grass"), c + Vector3(0, 0.15, 0), Vector3(rr.size.x - 0.3, 0.04, rr.size.y - 0.3), Color(1, 1, 1))
			# Пучки травы карточками
			var gb := gm.s("grass_blades")
			for k in int(rr.get_area() * 7.0):
				var gp := c + Vector3(rng.randf_range(-0.5, 0.5) * (rr.size.x - 0.5), 0.17, rng.randf_range(-0.5, 0.5) * (rr.size.y - 0.5))
				var hgt := rng.randf_range(0.25, 0.5)
				var ang := rng.randf() * PI
				var tint := Color(1, 1, 1).darkened(rng.randf_range(0.0, 0.25))
				for q in 2:
					var bx := Basis(Vector3.UP, ang + q * PI * 0.5)
					Geo.card(gb, gp + Vector3(0, hgt * 0.5, 0), Basis(bx.x * hgt * 1.2, Vector3.UP * hgt, bx.z), tint)
		# Площадка с песком и резиновой крошкой
		Geo.cbox(gm.s("asphalt"), Vector3(-8.5, 0.04, -6), Vector3(9, 0.08, 6), Color(1.6, 0.85, 0.7), 0.02))
	for r in lawns:
		var rr := r as Rect2
		var body := StaticBody3D.new()
		_add(y, body, "Lawn%d" % lawns.find(r), Vector3(rr.position.x + rr.size.x * 0.5, 0.0, rr.position.y + rr.size.y * 0.5))
		_box_shape(body, Vector3(rr.size.x, 0.17, rr.size.y), Vector3(0, 0.085, 0))
	# Металлический забор с калиткой на юге
	for side in [-1.0, 1.0]:
		var fence := StaticBody3D.new()
		_add(y, fence, "Fence%s" % ("W" if side < 0 else "E"), Vector3(side * 10.25, 0, 12))
		_proc(fence, "Mesh", Vector3.ZERO, func(gm: GeoMesh) -> void:
			var st := gm.s("metal")
			var green := Color(0.2, 0.36, 0.25)
			Geo.cbox(gm.s("concrete"), Vector3(0, 0.15, 0), Vector3(15.5, 0.3, 0.3), Color(0.7, 0.68, 0.65), 0.03)
			for i in 78:
				var x := -7.7 + i * 0.2
				Geo.rod(st, Vector3(x, 0.3, 0), Vector3(x, 1.5, 0), 0.015, green, 4)
				Geo.prism(st, Vector3(x, 1.5, 0), 0.03, 0.0, 0.1, green, 4)
			for yy in [0.45, 1.35]:
				Geo.rod(st, Vector3(-7.75, yy, 0), Vector3(7.75, yy, 0), 0.025, green, 4)
			for i in 6:
				Geo.cbox(st, Vector3(-7.7 + i * 3.08, 0.8, 0), Vector3(0.12, 1.6, 0.12), green.darkened(0.2), 0.02))
		_box_shape(fence, Vector3(15.5, 1.6, 0.3), Vector3(0, 0.8, 0))
	for sx in [-1.0, 1.0]:
		var post := StaticBody3D.new()
		_add(y, post, "GatePost%s" % ("L" if sx < 0 else "R"), Vector3(sx * 2.5, 0, 12))
		_proc(post, "Mesh", Vector3.ZERO, func(gm: GeoMesh) -> void:
			var st := gm.s("brick")
			# Кирпичный столб
			Geo.cbox(st, Vector3(0, 1.2, 0), Vector3(0.55, 2.4, 0.55), Color(1, 1, 1), 0.03)
			Geo.prism(gm.s("concrete"), Vector3(0, 2.4, 0), 0.42, 0.0, 0.35, Color(0.6, 0.58, 0.56), 4))
		_box_shape(post, Vector3(0.55, 2.4, 0.55), Vector3(0, 1.2, 0))
	_proc(y, "GateSign", Vector3(0, 2.75, 12), func(gm: GeoMesh) -> void:
		var st := gm.s("metal")
		Geo.cbox(st, Vector3.ZERO, Vector3(5.3, 0.6, 0.1), Color(0.85, 0.42, 0.18), 0.05)
		Geo.cbox(st, Vector3(0, 0, 0.04), Vector3(4.9, 0.4, 0.04), Color(0.95, 0.85, 0.6), 0.02))
	# Фонари во дворе и на улице
	var lamps := Node3D.new()
	_add(y, lamps, "Lamps")
	_lamp_post(lamps, "LampYard1", Vector3(-6, 0, 7.5), 180.0)
	_lamp_post(lamps, "LampYard2", Vector3(9, 0, 2), -90.0)
	_lamp_post(lamps, "LampYard3", Vector3(-3, 0, -10), 0.0)
	for x in [-24, -8, 8, 24]:
		_lamp_post(lamps, "LampStreet%d" % (x + 24), Vector3(x, 0.16, 14.4), 0.0)
	# Деревья: берёзы, тополя, липы по краям двора и вдоль улицы
	var trees := Node3D.new()
	_add(y, trees, "Trees")
	var spots := [
		[-16, -12, 0, 8.0], [-16, -8, 2, 7.0], [-16.5, -3, 1, 11.0], [-15.5, -5.5, 0, 6.5],
		[-6, -12.9, 2, 7.5], [-12, -13, 0, 8.5], [16.5, -12.5, 1, 12.0], [15.5, -8, 0, 7.0],
		[16.0, -3.6, 2, 8.0], [12, 10.3, 2, 7.0],
		[-16.5, 10.3, 1, 11.0], [-10, 10.4, 2, 7.5], [15.5, 10.3, 0, 8.0],
	]
	var n := 1
	for sp in spots:
		_tree(trees, Vector3(sp[0], 0.15, sp[1]), sp[2], n, sp[3])
		n += 1
	for x in range(-34, 35, 7):
		_tree(trees, Vector3(x + 1.5, 0.16, 13.9), (n % 3), n, 7.0 + (n % 4))
		n += 1
		_tree(trees, Vector3(x - 1.0, 0.16, 24.6), (n % 3), n, 7.0 + (n % 3))
		n += 1
	# Детская площадка: песочница с грибком, качели, горка
	var pg := StaticBody3D.new()
	_add(y, pg, "Playground", Vector3(-9, 0, -6))
	_proc(pg, "Mesh", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var st := gm.s("metal")
		var red := Color(0.78, 0.25, 0.2)
		for k in 4:
			var xf := Transform3D(Basis(Vector3.UP, k * PI * 0.5), Vector3.ZERO)
			Geo.cbox(st, Vector3(0, 0.2, 1.5), Vector3(3.2, 0.32, 0.22), red, 0.05, xf)
		Geo.box(gm.s("concrete"), Vector3(0, 0.15, 0), Vector3(2.8, 0.14, 2.8), Color(1.15, 0.95, 0.62))
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		Geo.blob(gm.s("concrete"), Vector3(0.6, 0.22, 0.4), Vector3(0.5, 0.15, 0.4), Color(1.15, 0.95, 0.62), rng, 5, 10, 0.2)
		Geo.rod(st, Vector3(0, 0, 0), Vector3(0, 2.1, 0), 0.06, Color(0.35, 0.35, 0.38))
		Geo.prism(st, Vector3(0, 2.0, 0), 1.4, 0.15, 0.55, Color(0.85, 0.22, 0.2), 10)
		var blue := Color(0.25, 0.45, 0.75)
		for sz in [-0.9, 0.9]:
			Geo.rod(st, Vector3(3.5, 0, sz - 0.5), Vector3(3.5, 2.6, sz * 0.2), 0.05, blue)
			Geo.rod(st, Vector3(3.5, 0, sz + 0.5), Vector3(3.5, 2.6, sz * 0.2), 0.05, blue)
		Geo.rod(st, Vector3(3.5, 2.6, -0.9), Vector3(3.5, 2.6, 0.9), 0.06, blue)
		for sz in [-0.25, 0.25]:
			Geo.rod(st, Vector3(3.5, 2.55, sz), Vector3(3.5, 0.62, sz), 0.012, Color(0.3, 0.3, 0.3), 4)
		Geo.cbox(st, Vector3(3.5, 0.6, 0), Vector3(0.45, 0.06, 0.65), Color(0.9, 0.7, 0.2), 0.02)
		# Горка
		Geo.cbox(st, Vector3(-3.4, 0.9, 1.8), Vector3(0.9, 0.08, 2.8), Color(0.75, 0.75, 0.78), 0.03, Transform3D(Basis(Vector3.RIGHT, -0.55), Vector3(0, 0, 0)))
		for i in 6:
			Geo.rod(st, Vector3(-3.8, 0.3 * i, 0.0), Vector3(-3.0, 0.3 * i, 0.0), 0.03, Color(0.85, 0.6, 0.15), 5)
		Geo.cbox(st, Vector3(-3.4, 1.8, -0.1), Vector3(1.0, 0.08, 0.8), Color(0.85, 0.6, 0.15), 0.02))
	_box_shape(pg, Vector3(3.2, 0.35, 3.2), Vector3(0, 0.17, 0))
	# Выбивалка для ковров, мусорные баки, лавочки
	_proc(y, "CarpetRack", Vector3(10.25, 0, -3.5), func(gm: GeoMesh) -> void:
		var st := gm.s("metal")
		var g := Color(0.3, 0.45, 0.32)
		for sx in [-1.25, 1.25]:
			Geo.rod(st, Vector3(sx, 0, 0), Vector3(sx, 2.0, 0), 0.05, g)
		Geo.rod(st, Vector3(-1.3, 1.95, 0), Vector3(1.3, 1.95, 0), 0.04, g)
		Geo.rod(st, Vector3(-1.3, 1.0, 0), Vector3(1.3, 1.0, 0), 0.03, g)
		Geo.cbox(gm.s("fabric"), Vector3(0, 1.35, 0.03), Vector3(1.7, 1.15, 0.04), Color(0.6, 0.12, 0.16), 0.02)
		for i in 5:
			Geo.box(gm.s("fabric"), Vector3(0, 1.0 + i * 0.2, 0.06), Vector3(1.5, 0.04, 0.01), Color(0.85, 0.7, 0.3)))
	for i in 3:
		var bin := StaticBody3D.new()
		_add(y, bin, "Bin%d" % i, Vector3(-17.2, 0, 6.0 + i * 1.35))
		bin.rotation_degrees.y = 90.0
		_proc(bin, "Mesh", Vector3.ZERO, func(gm: GeoMesh) -> void:
			var st := gm.s("metal")
			var c := [Color(0.25, 0.42, 0.3), Color(0.3, 0.35, 0.45), Color(0.25, 0.42, 0.3)][i] as Color
			Geo.cbox(st, Vector3(0, 0.6, 0), Vector3(1.2, 1.0, 0.95), c, 0.06)
			Geo.cbox(st, Vector3(0, 1.13, -0.02), Vector3(1.26, 0.08, 1.0), c.darkened(0.25), 0.03)
			for sx in [-0.45, 0.45]:
				Geo.prism(st, Vector3(sx, 0, 0.3), 0.07, 0.07, 0.1, Color(0.1, 0.1, 0.1), 6)
				Geo.prism(st, Vector3(sx, 0, -0.3), 0.07, 0.07, 0.1, Color(0.1, 0.1, 0.1), 6))
		_box_shape(bin, Vector3(1.2, 1.15, 0.95), Vector3(0, 0.58, 0))
	_bench(y, "Bench1", Vector3(-10.6, 0, -12.0))
	_bench(y, "Bench2", Vector3(1.4, 0, -12.0))
	_bench(y, "Bench3", Vector3(6.5, 0, 8.3), 180.0)
	# Гирлянда между домами над двором
	var cols := [Color(1, 0.35, 0.25), Color(1, 0.8, 0.3), Color(0.4, 0.75, 1), Color(0.5, 1, 0.5)]
	var g := Node3D.new()
	_add(y, g, "Garland")
	_proc(g, "Wire", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var st := gm.s("plain")
		for i in 17:
			var t0 := float(i) / 17.0
			var t1 := float(i + 1) / 17.0
			Geo.rod(st, Vector3(lerpf(-17, 17, t0), 6.2 - 1.2 * sin(t0 * PI), -2), Vector3(lerpf(-17, 17, t1), 6.2 - 1.2 * sin(t1 * PI), -2), 0.012, Color(0.15, 0.15, 0.15), 3))
	for i in 18:
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		var t := float(i) / 17.0
		var mi := _mesh(g, "Bulb%d" % i, sm, cols[i % 4], Vector3(lerpf(-17, 17, t), 6.05 - 1.2 * sin(t * PI), -2))
		var lm := StandardMaterial3D.new()
		lm.albedo_color = cols[i % 4]
		lm.emission_enabled = true
		lm.emission = cols[i % 4]
		lm.emission_energy_multiplier = 2.5
		mi.material_override = lm


# ---------- зоны лобби ----------

func _van() -> void:
	var v := Node3D.new()
	v.set_script(load("res://scripts/van.gd"))
	_add(lobby_root, v, "Van", Vector3(-3, 0, 1))
	_model(v, "Body", RACE + "vehicle-truck-red.glb", Vector3.ZERO, 2.2, 180.0, true)
	# Мигалка и табличка с котом на крыше
	_box(v, "LightRed", Vector3(0.6, 0.25, 0.35), Color(1, 0.15, 0.15), Vector3(-0.4, 2.95, -0.6), false)
	_box(v, "LightBlue", Vector3(0.6, 0.25, 0.35), Color(0.2, 0.4, 1), Vector3(0.4, 2.95, -0.6), false)
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	_mesh(v, "CatSign", sm, Color(1.0, 0.85, 0.3), Vector3(0, 3.3, -0.6))
	# Места (игрок «внутри», модель скрыта)
	var seats := Node3D.new()
	_add(v, seats, "Seats")
	for i in 4:
		var s := Marker3D.new()
		_add(seats, s, "Seat%d" % (i + 1), Vector3(-0.5 + (i % 2), 1.0, 0.5 + (i / 2) * 1.0))
	var ep := Marker3D.new()
	_add(v, ep, "ExitPoint", Vector3(0, 0.6, 4.2))
	# Дверь кабины: панель «Радар котиков»
	_trigger(v, "Dashboard", "PROMPT_SEARCH", Vector3(-2.2, 1.0, -1.6), 1.4)
	# Задние двери: сесть
	_trigger(v, "SeatTrigger", "PROMPT_SIT", Vector3(0, 1.0, 3.6), 1.6)
	# Стена инструментов: открытый шкаф на боку фургона
	_box(v, "ToolWallBoard", Vector3(0.12, 1.4, 2.4), Color(0.5, 0.35, 0.2), Vector3(1.75, 1.3, 0.8), false)
	for i in 5:
		var hm := CylinderMesh.new()
		hm.top_radius = 0.05
		hm.bottom_radius = 0.05
		hm.height = 0.25
		var h := _mesh(v, "Hook%d" % i, hm, Color(0.8, 0.8, 0.85), Vector3(1.85, 1.6, -0.2 + i * 0.5), 0.8)
		h.rotation_degrees = Vector3(0, 0, 90)
	_box(v, "MissionCrate", Vector3(0.8, 0.5, 0.6), Color(0.7, 0.55, 0.25), Vector3(2.4, 0.25, 2.2))
	_trigger(v, "ToolWall", "PROMPT_TOOLS", Vector3(2.6, 1.0, 0.8), 1.4)


func _stall() -> void:
	var s := StaticBody3D.new()
	_add(lobby_root, s, "Stall", Vector3(-13, 0, 4.5))
	s.rotation_degrees.y = 90.0
	# Ларёк: стены с фаской, витрина, прилавок, полосатый козырёк, вывеска
	_proc(s, "Kiosk", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var st := gm.s("metal")
		var wall := Color(0.38, 0.55, 0.62)
		var trim := Color(0.9, 0.88, 0.82)
		Geo.cbox(gm.s("concrete"), Vector3(0, 0.1, -0.7), Vector3(3.4, 0.2, 2.2), Color(0.7, 0.68, 0.65), 0.04)
		Geo.cbox(st, Vector3(0, 1.4, -1.65), Vector3(3.2, 2.6, 0.15), wall, 0.05)
		for sx in [-1.0, 1.0]:
			Geo.cbox(st, Vector3(sx * 1.55, 1.4, -0.75), Vector3(0.15, 2.6, 1.85), wall, 0.05)
			Geo.cbox(st, Vector3(sx * 1.55, 1.3, 0.15), Vector3(0.2, 2.5, 0.2), trim, 0.05)
		# Прилавок с деревянной столешницей
		Geo.cbox(st, Vector3(0, 0.55, 0.05), Vector3(2.9, 0.9, 0.45), wall.darkened(0.15), 0.05)
		Geo.cbox(gm.s("wood"), Vector3(0, 1.03, 0.12), Vector3(3.0, 0.07, 0.65), Color(0.75, 0.52, 0.32), 0.02)
		# Крыша и полосатый козырёк
		Geo.cbox(gm.s("asphalt"), Vector3(0, 2.75, -0.75), Vector3(3.5, 0.18, 2.3), Color(0.9, 0.9, 0.9), 0.05)
		for i in 7:
			var col := Color(0.82, 0.2, 0.22) if i % 2 == 0 else Color(0.96, 0.93, 0.86)
			var x := -1.5 + 0.215 + i * 0.43
			Geo.cbox(gm.s("fabric"), Vector3.ZERO, Vector3(0.43, 0.04, 1.1), col, 0.01, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(x, 2.55, 0.65)))
			Geo.prism(gm.s("fabric"), Vector3(x, 2.25, 1.15), 0.215, 0.215, 0.1, col, 12)
		# Вывеска «Украшения»
		Geo.cbox(st, Vector3(0, 3.15, 0.25), Vector3(2.8, 0.5, 0.1), Color(0.95, 0.75, 0.25), 0.04)
		Geo.cbox(st, Vector3(0, 3.15, 0.3), Vector3(2.5, 0.3, 0.04), Color(0.55, 0.18, 0.18), 0.02)
		# Полки с товаром за продавцом
		for k in 3:
			Geo.cbox(gm.s("wood"), Vector3(0, 1.1 + k * 0.5, -1.45), Vector3(2.8, 0.05, 0.3), Color(0.75, 0.52, 0.32), 0.01)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for k in 3:
			for i in 7:
				var c := Color.from_hsv(rng.randf(), 0.55, 0.9)
				var pos := Vector3(-1.2 + i * 0.4, 1.22 + k * 0.5, -1.45)
				if rng.randf() < 0.5:
					Geo.blob(gm.s("fabric"), pos, Vector3(0.13, 0.11, 0.13), c, rng, 6, 10, 0.08)
				else:
					Geo.cbox(gm.s("fabric"), pos, Vector3(0.22, 0.18, 0.16), c, 0.04)
		# Шапки на верёвке под козырьком
		Geo.rod(st, Vector3(-1.45, 2.25, 0.35), Vector3(1.45, 2.25, 0.35), 0.01, Color(0.85, 0.85, 0.85), 3)
		for i in 5:
			var hc := Color.from_hsv(i * 0.19, 0.6, 0.85)
			Geo.blob(gm.s("fabric"), Vector3(-1.0 + i * 0.5, 2.05, 0.35), Vector3(0.14, 0.14, 0.14), hc, rng, 7, 12, 0.03)
			Geo.blob(gm.s("fabric"), Vector3(-1.0 + i * 0.5, 2.22, 0.35), Vector3(0.05, 0.05, 0.05), Color(0.97, 0.95, 0.9), rng, 5, 8, 0.0))
	_box_shape(s, Vector3(3.4, 2.8, 2.2), Vector3(0, 1.4, -0.7))
	# Баб Нюра: процедурная бабушка с анимацией (scripts/babushka.gd)
	var n := Node3D.new()
	n.set_script(load("res://scripts/babushka.gd"))
	_add(s, n, "BabNyura", Vector3(0, 0.2, -0.8))
	# Лампочка под крышей ларька, чтобы бабушку было видно
	var bulb := OmniLight3D.new()
	_add(s, bulb, "StallLight", Vector3(0, 2.35, -0.2))
	bulb.light_color = Color(1.0, 0.8, 0.55)
	bulb.light_energy = 1.3
	bulb.omni_range = 3.5
	_proc(s, "Bulb", Vector3.ZERO, func(gm: GeoMesh) -> void:
		Geo.rod(gm.s("metal"), Vector3(0, 2.66, -0.2), Vector3(0, 2.45, -0.2), 0.008, Color(0.1, 0.1, 0.1), 4)
		Geo.blob(gm.s("lit"), Vector3(0, 2.4, -0.2), Vector3(0.05, 0.06, 0.05), Color(1, 1, 1), RandomNumberGenerator.new(), 6, 10, 0.0))
	# Примерочная: зеркало в раме на ножках
	_proc(s, "Mirror", Vector3(2.5, 0, -0.6), func(gm: GeoMesh) -> void:
		var st := gm.s("wood")
		Geo.cbox(st, Vector3(0, 1.25, 0), Vector3(1.3, 2.1, 0.12), Color(0.85, 0.65, 0.3), 0.05)
		Geo.cbox(gm.s("glass"), Vector3(0, 1.25, 0.05), Vector3(1.1, 1.9, 0.04), Color(0.85, 0.9, 0.95), 0.02)
		for sx in [-0.5, 0.5]:
			Geo.cbox(st, Vector3(sx, 0.1, 0), Vector3(0.15, 0.2, 0.6), Color(0.6, 0.45, 0.22), 0.04))
	_trigger(s, "Trigger", "PROMPT_SHOP", Vector3(0, 1.0, 1.6), 2.0)


func _slot_machine() -> void:
	var m := StaticBody3D.new()
	_add(lobby_root, m, "SlotMachine", Vector3(-12.5, 0, 7.8))
	m.rotation_degrees.y = 90.0
	_proc(m, "Body", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var st := gm.s("metal")
		var red := Color(0.62, 0.14, 0.17)
		var chrome := Color(0.8, 0.8, 0.82)
		Geo.cbox(st, Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 1.0), red.darkened(0.2), 0.08)
		Geo.cbox(st, Vector3(0, 1.45, -0.1), Vector3(1.35, 1.1, 0.8), red, 0.12)
		Geo.cbox(st, Vector3(0, 2.15, -0.05), Vector3(1.45, 0.4, 0.9), Color(0.95, 0.75, 0.2), 0.15)
		Geo.cbox(st, Vector3(0, 1.5, 0.3), Vector3(1.05, 0.6, 0.06), chrome, 0.04)
		Geo.box(gm.s("glass"), Vector3(0, 1.5, 0.34), Vector3(0.95, 0.5, 0.02), Color(0.2, 0.2, 0.25))
		for i in 3:
			Geo.prism(st, Vector3(-0.3 + i * 0.3, 1.3, 0.36), 0.12, 0.12, 0.4, Color(0.97, 0.94, 0.86), 10, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO) * Transform3D.IDENTITY, true)
		Geo.cbox(st, Vector3(0, 1.0, 0.5), Vector3(1.2, 0.08, 0.15), chrome, 0.02)
		Geo.cbox(st, Vector3(0, 0.55, 0.51), Vector3(0.5, 0.25, 0.04), Color(0.1, 0.1, 0.1), 0.02)
		# Рычаг-лапка
		Geo.rod(st, Vector3(0.72, 1.3, 0), Vector3(0.85, 2.05, 0), 0.05, chrome)
		var rng := RandomNumberGenerator.new()
		rng.seed = 2
		Geo.blob(gm.s("plain"), Vector3(0.86, 2.13, 0), Vector3(0.13, 0.13, 0.13), Color(1, 0.3, 0.3), rng, 8, 14, 0.0)
		# Лампочки по верху
		for i in 7:
			Geo.blob(gm.s("lit"), Vector3(-0.6 + i * 0.2, 2.38, 0.3), Vector3(0.05, 0.05, 0.05), Color(1, 0.9, 0.5), rng, 5, 8, 0.0))
	_box_shape(m, Vector3(1.4, 2.4, 1.0), Vector3(0, 1.2, 0))
	_trigger(m, "Trigger", "PROMPT_SLOT", Vector3(0, 1.0, 1.4), 1.6)


func _mascot() -> void:
	var m := Node3D.new()
	m.set_script(load("res://scripts/mascot.gd"))
	_add(lobby_root, m, "Mascot", Vector3(0, 0, 9.5))
	m.rotation_degrees.y = 180.0
	var gold := Color(1.0, 0.8, 0.2)
	var pm := CylinderMesh.new()
	pm.top_radius = 0.9
	pm.bottom_radius = 1.0
	pm.height = 0.8
	_mesh(m, "Pedestal", pm, Color(0.55, 0.55, 0.6), Vector3(0, 0.4, 0))
	var body := SphereMesh.new()
	body.radius = 0.75
	body.height = 1.5
	_mesh(m, "Body", body, gold, Vector3(0, 1.5, 0), 0.9)
	var head := SphereMesh.new()
	head.radius = 0.55
	head.height = 1.1
	_mesh(m, "Head", head, gold, Vector3(0, 2.5, 0.1), 0.9)
	for sx in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.2
		ear.height = 0.4
		_mesh(m, "Ear%s" % ("L" if sx < 0 else "R"), ear, gold, Vector3(sx * 0.35, 3.1, 0.1), 0.9)
	var bell := SphereMesh.new()
	bell.radius = 0.15
	bell.height = 0.3
	_mesh(m, "Bell", bell, Color(0.9, 0.2, 0.2), Vector3(0, 2.05, 0.6))
	var paw := Node3D.new()
	_add(m, paw, "Paw", Vector3(0.6, 1.9, 0.3))
	var arm := CapsuleMesh.new()
	arm.radius = 0.16
	arm.height = 0.9
	var am := _mesh(paw, "Arm", arm, gold, Vector3(0.05, 0.4, 0), 0.9)
	am.rotation_degrees = Vector3(0, 0, -10)
	_trigger(m, "Trigger", "PROMPT_PET", Vector3(0, 1.0, 1.4), 2.2)


# ---------- паркур ----------
# Маршрут: старт у восточного края двора, вверх по площадкам, узкая балка,
# проваливающиеся платформы, ездящая платформа, балка над двором, лифт и финиш
# на высоте ~11.5 м. Рывок прыжка ~2.5 м по высоте, ~6-7 м по длине на бегу.
# Позиции — это центр ВЕРХНЕЙ поверхности площадки.

var _parkour_root: Node3D
var _pad_i := 0


func _pad_node(body: Node3D, kind: String, top: Vector3) -> void:
	# Площадки паркура в духе двора: ящики-поддоны, бетонные плиты, металлические листы
	var size := Vector3(1.2, 0.3, 1.2)
	if kind == "big":
		size = Vector3(1.8, 0.35, 1.8)
	elif kind == "fall":
		size = Vector3(1.3, 0.22, 1.3)
	body.position = top - Vector3(0, size.y, 0)
	_proc(body, "Model", Vector3.ZERO, func(gm: GeoMesh) -> void:
		var c := Vector3(0, size.y * 0.5, 0)
		if kind == "big":
			Geo.cbox(gm.s("concrete"), c, size, Color(0.85, 0.83, 0.8), 0.05)
			Geo.box(gm.s("plain"), c + Vector3(0, size.y * 0.5 + 0.004, 0), Vector3(size.x - 0.2, 0.004, 0.05), Color(1.0, 0.8, 0.2))
		elif kind == "fall":
			# Трухлявые доски с щелями
			for i in 5:
				var w := size.x / 5.0
				Geo.cbox(gm.s("wood"), Vector3(-size.x * 0.5 + (i + 0.5) * w, size.y * 0.75, 0), Vector3(w - 0.04, size.y * 0.5, size.z), Color(0.7, 0.5, 0.35).darkened(0.1 * (i % 2)), 0.015)
			for z in [-0.45, 0.45]:
				Geo.cbox(gm.s("wood"), Vector3(0, size.y * 0.25, z * size.z), Vector3(size.x, size.y * 0.5, 0.12), Color(0.55, 0.38, 0.26), 0.015)
		else:
			# Деревянный поддон
			for i in 6:
				var w := size.x / 6.0
				Geo.cbox(gm.s("wood"), Vector3(-size.x * 0.5 + (i + 0.5) * w, size.y - 0.04, 0), Vector3(w - 0.03, 0.08, size.z), Color(0.95, 0.78, 0.55), 0.012)
			for z in [-0.42, 0.0, 0.42]:
				Geo.cbox(gm.s("wood"), Vector3(0, (size.y - 0.08) * 0.5, z * size.z), Vector3(size.x, size.y - 0.08, 0.14), Color(0.85, 0.68, 0.48), 0.015))
	_box_shape(body, size, Vector3(0, size.y * 0.5, 0))


func _pad(top: Vector3, kind := "pad") -> Node3D:
	_pad_i += 1
	var body: Node3D
	if kind == "fall":
		body = StaticBody3D.new()
		body.set_script(load("res://scripts/falling_platform.gd"))
		_add(_parkour_root, body, "Falling%d" % _pad_i)
		_pad_node(body, kind, top)
		var sensor := Area3D.new()
		sensor.collision_layer = 0
		sensor.collision_mask = 1
		_add(body, sensor, "Sensor")
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.2, 0.4, 1.2)
		cs.shape = bs
		_add(sensor, cs, "Shape", Vector3(0, 0.45, 0))
	else:
		body = StaticBody3D.new()
		_add(_parkour_root, body, "Pad%d" % _pad_i)
		_pad_node(body, kind, top)
	return body


func _mover(top: Vector3, offset: Vector3, period: float) -> Node3D:
	_pad_i += 1
	var body := AnimatableBody3D.new()
	body.set_script(load("res://scripts/mover.gd"))
	body.set("offset", offset)
	body.set("period", period)
	_add(_parkour_root, body, "Mover%d" % _pad_i)
	_pad_node(body, "pad", top)
	return body


func _beam(from: Vector3, to: Vector3, width := 0.35) -> void:
	_pad_i += 1
	var mid := (from + to) * 0.5
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var b := _box(_parkour_root, "Beam%d" % _pad_i, Vector3(width, 0.25, length), Color(0.55, 0.55, 0.6), mid - Vector3(0, 0.125, 0))
	b.rotation.y = atan2(to.x - from.x, to.z - from.z)


func _checkpoint(top: Vector3, index: int) -> void:
	var cp := Area3D.new()
	cp.set_script(load("res://scripts/checkpoint.gd"))
	cp.set("index", index)
	cp.collision_layer = 0
	cp.collision_mask = 1
	_add(_parkour_root, cp, "Checkpoint%d" % index, top)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 1.5, 1.6)
	cs.shape = bs
	_add(cp, cs, "Shape", Vector3(0, 0.75, 0))
	var flag: Node3D = load(PLAT + "flag.glb").instantiate()
	_add(cp, flag, "Flag", Vector3(0.6, 0, 0.6))


func _parkour() -> void:
	_parkour_root = Node3D.new()
	_add(lobby_root, _parkour_root, "Parkour")
	# Этап 1: подъём по площадкам вдоль восточной стены
	_checkpoint(Vector3(15, 0, 10), 0)
	_pad(Vector3(15, 1.2, 6.8))
	_pad(Vector3(15.5, 2.5, 3.6))
	_pad(Vector3(13.5, 3.5, 0.8))
	# Этап 2: узкая балка 5.5 м
	_beam(Vector3(13.5, 3.5, 0.2), Vector3(13.5, 3.5, -5.6), 0.35)
	_pad(Vector3(13.5, 3.5, -7), "big")
	_checkpoint(Vector3(13.5, 3.5, -7), 1)
	# Этап 3: три проваливающиеся платформы с подъёмом
	_pad(Vector3(10.2, 3.9, -7.3), "fall")
	_pad(Vector3(7.0, 4.3, -6.7), "fall")
	_pad(Vector3(3.8, 4.7, -7.3), "fall")
	_pad(Vector3(0.5, 4.7, -7), "big")
	_checkpoint(Vector3(0.5, 4.7, -7), 2)
	# Этап 4: ездящая платформа через провал 6 м
	_mover(Vector3(-2.6, 4.9, -7), Vector3(-5.5, 0, 0), 4.0)
	_pad(Vector3(-10.8, 5.5, -7))
	_pad(Vector3(-10.8, 6.9, -10.8))
	# Этап 5: длинная тонкая балка над двором
	_beam(Vector3(-10.2, 6.9, -10.8), Vector3(-0.1, 6.9, -10.8), 0.3)
	_pad(Vector3(1.0, 6.9, -10.8), "big")
	_checkpoint(Vector3(1.0, 6.9, -10.8), 3)
	# Этап 6: лифт вверх, прыжки к финишу
	_mover(Vector3(4.2, 6.9, -10.8), Vector3(0, 3.6, 0), 3.0)
	_pad(Vector3(7.4, 10.6, -11.5))
	_pad(Vector3(10.4, 11.5, -10.5), "big")
	# Приз: подушка с логотипом студии
	var prize := Area3D.new()
	prize.set_script(load("res://scripts/prize.gd"))
	prize.collision_layer = 0
	prize.collision_mask = 1
	_add(_parkour_root, prize, "Prize", Vector3(10.4, 11.5, -10.5))
	var pcs := CollisionShape3D.new()
	var pbs := BoxShape3D.new()
	pbs.size = Vector3(1.2, 1.2, 1.2)
	pcs.shape = pbs
	_add(prize, pcs, "Shape", Vector3(0, 0.6, 0))
	var vis := Node3D.new()
	_add(prize, vis, "Visual", Vector3(0, 0.5, 0))
	_box(vis, "Cushion", Vector3(0.9, 0.3, 0.9), Color(0.95, 0.75, 0.85), Vector3.ZERO, false)
	var lm := SphereMesh.new()
	lm.radius = 0.15
	lm.height = 0.3
	_mesh(vis, "LogoStub", lm, Color(0.3, 0.2, 0.9), Vector3(0, 0.2, 0))


# ---------- игроки и HUD ----------

func _players() -> void:
	var holder := Node3D.new()
	_add(lobby_root, holder, "Players")
	var p := RigidBody3D.new()
	p.set_script(load("res://scripts/player.gd"))
	p.collision_layer = 1
	p.collision_mask = 1
	p.mass = 1.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	p.physics_material_override = pm
	_add(holder, p, "Player1", Vector3(3, 0.5, 3))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.4
	cs.shape = cap
	_add(p, cs, "Shape", Vector3(0, 0.7, 0))
	# Модель: персонаж Kenney (idle/walk/jump) + цветная каска спасателя
	var model := Node3D.new()
	_add(p, model, "Model")
	var ch: Node3D = load(PLAT + "character.glb").instantiate()
	ch.scale = Vector3.ONE * 1.3
	_add(model, ch, "Character")
	var helmet := SphereMesh.new()
	helmet.radius = 0.38
	helmet.height = 0.45
	helmet.is_hemisphere = true
	_mesh(model, "Helmet", helmet, Color(1.0, 0.55, 0.1), Vector3(0, 1.25, 0))
	var ia := Area3D.new()
	ia.collision_layer = 0
	ia.collision_mask = 2
	var ics := CollisionShape3D.new()
	var iss := SphereShape3D.new()
	iss.radius = 0.8
	ics.shape = iss
	_add(ia, ics, "Shape")
	_add(p, ia, "InteractArea", Vector3(0, 0.7, 0))
	var fr := RayCast3D.new()
	fr.target_position = Vector3(0, -0.3, 0)
	fr.collision_mask = 1
	_add(p, fr, "FloorRay", Vector3(0, 0.1, 0))
	var cam := Camera3D.new()
	cam.top_level = true
	cam.fov = 65
	_add(p, cam, "Camera", Vector3(3, 6.5, 12))
	var sp := Node3D.new()
	_add(lobby_root, sp, "SpawnPoints")
	for i in 4:
		var m := Marker3D.new()
		_add(sp, m, "Spawn%d" % (i + 1), Vector3(2 + i * 1.2, 0.5, 3))


func _hud() -> void:
	var cl := CanvasLayer.new()
	_add(lobby_root, cl, "HUD")
	var hint := Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-150, -90)
	hint.add_theme_font_size_override("font_size", 26)
	_add(cl, hint, "Hint")
	var toast := Label.new()
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-200, 40)
	toast.add_theme_font_size_override("font_size", 28)
	_add(cl, toast, "Toast")
	var money := Label.new()
	money.position = Vector2(20, 16)
	money.add_theme_font_size_override("font_size", 24)
	_add(cl, money, "Money")
