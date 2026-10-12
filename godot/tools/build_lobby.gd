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


func _init() -> void:
	lobby_root = Node3D.new()
	lobby_root.name = "Lobby"
	lobby_root.set_script(load("res://scripts/lobby.gd"))

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
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.55, 0.9)
	sm.sky_horizon_color = Color(1.0, 0.8, 0.6)
	sm.ground_horizon_color = Color(1.0, 0.8, 0.6)
	sm.ground_bottom_color = Color(0.45, 0.42, 0.45)
	sm.ground_horizon_color = Color(1.0, 0.8, 0.6)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.85, 0.7)
	env.fog_density = 0.004
	we.environment = env
	_add(lobby_root, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.88, 0.7)
	sun.light_energy = 0.8
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.shadow_enabled = true
	_add(lobby_root, sun, "Sun")


func _city() -> void:
	var c := Node3D.new()
	_add(lobby_root, c, "City")
	# Земля квартала (асфальт), на ней всё стоит
	_box(c, "Ground", Vector3(140, 1.0, 140), Color(0.36, 0.37, 0.4), Vector3(0, -0.5, 0))
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
	for x in range(-48, 49, 8):
		var kind := "road-straight-lightposts" if (x / 8) % 2 == 0 else "road-straight"
		_model(road, "Road%d" % (x + 48), CITY + kind + ".glb", Vector3(x, 0.0, 19), 8.0, 90.0)
	for x in range(-36, 37, 4):
		_model(road, "Walk%d" % (x + 36), CITY + "pavement.glb", Vector3(x, 0.0, 14), 4.0)
	# Припаркованные машины
	_model(road, "CarGreen", RACE + "vehicle-truck-green.glb", Vector3(-14, 0, 16.5), 1.8, 90.0, true)
	_model(road, "CarPurple", RACE + "vehicle-truck-purple.glb", Vector3(12, 0, 21.5), 1.8, -90.0, true)


func _yard() -> void:
	var y := Node3D.new()
	_add(lobby_root, y, "Yard")
	# Плитка двора
	for x in range(int(YARD_MIN.x) + 2, int(YARD_MAX.x), 4):
		for z in range(int(YARD_MIN.y) + 2, int(YARD_MAX.y), 4):
			_model(y, "Tile_%d_%d" % [x, z], CITY + "pavement.glb", Vector3(x, -0.2, z), 4.0)
	# Забор с калиткой на юге (остальные стороны закрывают дома)
	var fc := Color(0.55, 0.35, 0.2)
	_box(y, "FenceSW", Vector3(15.5, 1.6, 0.3), fc, Vector3(-10.25, 0.8, 12))
	_box(y, "FenceSE", Vector3(15.5, 1.6, 0.3), fc, Vector3(10.25, 0.8, 12))
	_box(y, "GatePostL", Vector3(0.5, 2.4, 0.5), Color(0.4, 0.25, 0.15), Vector3(-2.5, 1.2, 12))
	_box(y, "GatePostR", Vector3(0.5, 2.4, 0.5), Color(0.4, 0.25, 0.15), Vector3(2.5, 1.2, 12))
	_box(y, "GateSign", Vector3(5.5, 0.6, 0.15), Color(0.95, 0.5, 0.2), Vector3(0, 2.6, 12), false)
	# Деревья: берёзы, тополя, липы по краям двора и вдоль улицы
	var trees := Node3D.new()
	_add(y, trees, "Trees")
	var spots := [
		[-16, -12, 0, 8.0], [-16, -8, 2, 7.0], [-16.5, -3, 1, 11.0], [-16, 2, 0, 7.5],
		[-6, -12.5, 2, 7.5], [-8.5, -12, 0, 8.5], [16.5, -12.5, 1, 12.0],
		[16.0, -3.6, 2, 8.0], [17, 4, 0, 7.0], [11, 10.5, 2, 7.0], [-5, 10.5, 0, 6.5],
		[7, 10.8, 0, 7.5], [-16.5, 10.5, 1, 11.0],
	]
	var n := 1
	for sp in spots:
		_tree(trees, Vector3(sp[0], 0, sp[1]), sp[2], n, sp[3])
		n += 1
	for x in range(-34, 35, 7):
		_tree(trees, Vector3(x + 1.5, 0, 14.6), (n % 3), n, 7.0 + (n % 4))
		n += 1
		_tree(trees, Vector3(x - 1.0, 0, 24.2), (n % 3), n, 7.0 + (n % 3))
		n += 1
	# Детская площадка: песочница, качели, горка
	var pg := Node3D.new()
	_add(y, pg, "Playground", Vector3(-9, 0, -6))
	_box(pg, "SandboxRim", Vector3(3.2, 0.35, 0.2), Color(0.85, 0.3, 0.25), Vector3(0, 0.17, -1.5))
	_box(pg, "SandboxRim2", Vector3(3.2, 0.35, 0.2), Color(0.85, 0.3, 0.25), Vector3(0, 0.17, 1.5))
	_box(pg, "SandboxRim3", Vector3(0.2, 0.35, 3.2), Color(0.85, 0.3, 0.25), Vector3(-1.5, 0.17, 0))
	_box(pg, "SandboxRim4", Vector3(0.2, 0.35, 3.2), Color(0.85, 0.3, 0.25), Vector3(1.5, 0.17, 0))
	_box(pg, "Sand", Vector3(2.8, 0.2, 2.8), Color(0.93, 0.82, 0.55), Vector3(0, 0.1, 0), false)
	_box(pg, "Fungus", Vector3(0.12, 2.0, 0.12), Color(0.4, 0.4, 0.45), Vector3(0, 1.0, 0), false)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.1
	cap.bottom_radius = 1.4
	cap.height = 0.5
	cap.radial_segments = 8
	_mesh(pg, "FungusCap", cap, Color(0.9, 0.25, 0.25), Vector3(0, 2.2, 0))
	var sw_col := Color(0.3, 0.55, 0.85)
	_box(pg, "SwingPostL", Vector3(0.12, 2.6, 0.12), sw_col, Vector3(3.5, 1.3, -0.8))
	_box(pg, "SwingPostR", Vector3(0.12, 2.6, 0.12), sw_col, Vector3(3.5, 1.3, 0.8))
	_box(pg, "SwingBar", Vector3(0.12, 0.12, 1.8), sw_col, Vector3(3.5, 2.6, 0), false)
	_box(pg, "SwingSeat", Vector3(0.45, 0.06, 0.6), Color(0.9, 0.75, 0.2), Vector3(3.5, 0.6, 0), false)
	_box(pg, "SwingRopes", Vector3(0.03, 2.0, 0.5), Color(0.3, 0.3, 0.3), Vector3(3.5, 1.6, 0), false)
	# Выбивалка для ковров и мусорные баки
	_box(y, "CarpetRackL", Vector3(0.1, 2.0, 0.1), Color(0.35, 0.5, 0.35), Vector3(9, 1.0, -3.5))
	_box(y, "CarpetRackR", Vector3(0.1, 2.0, 0.1), Color(0.35, 0.5, 0.35), Vector3(11.5, 1.0, -3.5))
	_box(y, "CarpetRackBar", Vector3(2.6, 0.08, 0.08), Color(0.35, 0.5, 0.35), Vector3(10.25, 1.9, -3.5), false)
	_box(y, "Carpet", Vector3(1.6, 1.2, 0.05), Color(0.65, 0.15, 0.2), Vector3(10.25, 1.3, -3.5), false)
	for i in 3:
		_box(y, "Bin%d" % i, Vector3(1.1, 1.1, 0.9), Color(0.25, 0.45, 0.3), Vector3(-17.0, 0.55, 6.0 + i * 1.3))
	# Лавочки у подъездов
	for x in [-10.6, 1.4]:
		_box(y, "Bench_%d" % int(x), Vector3(2.0, 0.45, 0.6), Color(0.55, 0.35, 0.22), Vector3(x, 0.3, -12.2))
	# Гирлянда между домами над двором
	var cols := [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.3, 0.8, 1), Color(0.5, 1, 0.5)]
	var g := Node3D.new()
	_add(y, g, "Garland")
	for i in 18:
		var sm := SphereMesh.new()
		sm.radius = 0.15
		sm.height = 0.3
		var t := float(i) / 17.0
		var mi := _mesh(g, "Bulb%d" % i, sm, cols[i % 4], Vector3(lerpf(-17, 17, t), 6.0 - 1.2 * sin(t * PI), -2))
		var lm := StandardMaterial3D.new()
		lm.albedo_color = cols[i % 4]
		lm.emission_enabled = true
		lm.emission = cols[i % 4]
		lm.emission_energy_multiplier = 1.5
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
	var s := Node3D.new()
	_add(lobby_root, s, "Stall", Vector3(-13, 0, 5))
	s.rotation_degrees.y = 90.0
	_box(s, "Counter", Vector3(3.0, 1.0, 1.0), Color(0.75, 0.45, 0.25), Vector3(0, 0.5, 0))
	_box(s, "BackWall", Vector3(3.0, 2.6, 0.2), Color(0.6, 0.4, 0.3), Vector3(0, 1.3, -1.6))
	_box(s, "SideL", Vector3(0.2, 2.6, 1.8), Color(0.6, 0.4, 0.3), Vector3(-1.5, 1.3, -0.7))
	_box(s, "SideR", Vector3(0.2, 2.6, 1.8), Color(0.6, 0.4, 0.3), Vector3(1.5, 1.3, -0.7))
	# Полосатый навес
	for i in 6:
		var col := Color(0.9, 0.2, 0.3) if i % 2 == 0 else Color(1, 0.95, 0.9)
		_box(s, "Awning%d" % i, Vector3(0.6, 0.12, 2.4), col, Vector3(-1.5 + 0.3 + i * 0.6, 2.75, -0.3), false)
	_box(s, "Sign", Vector3(2.4, 0.5, 0.1), Color(1.0, 0.85, 0.3), Vector3(0, 3.15, 0.6), false)
	# Украшения на прищепках
	for i in 5:
		var hm := SphereMesh.new()
		hm.radius = 0.15
		hm.height = 0.3
		_mesh(s, "Goods%d" % i, hm, Color.from_hsv(i * 0.2, 0.7, 1.0), Vector3(-1.0 + i * 0.5, 2.3, 0.4))
	# Баб Нюра: персонаж Kenney + платок и шаль
	var n := _model(s, "BabNyura", PLAT + "character.glb", Vector3(0, 0, -0.8), 1.2)
	var scarf := SphereMesh.new()
	scarf.radius = 0.36
	scarf.height = 0.5
	_mesh(n, "Headscarf", scarf, Color(0.85, 0.2, 0.25), Vector3(0, 1.15, -0.02))
	var shawl := CylinderMesh.new()
	shawl.top_radius = 0.3
	shawl.bottom_radius = 0.45
	shawl.height = 0.35
	_mesh(n, "Shawl", shawl, Color(0.55, 0.4, 0.7), Vector3(0, 0.7, 0))
	# Примерочная: зеркало сбоку
	_box(s, "MirrorFrame", Vector3(1.4, 2.2, 0.15), Color(0.9, 0.75, 0.3), Vector3(2.6, 1.1, -0.8), false)
	_box(s, "Mirror", Vector3(1.2, 2.0, 0.05), Color(0.7, 0.9, 1.0), Vector3(2.6, 1.1, -0.7), false)
	_trigger(s, "Trigger", "PROMPT_SHOP", Vector3(0, 1.0, 1.6), 2.0)


func _slot_machine() -> void:
	var m := Node3D.new()
	_add(lobby_root, m, "SlotMachine", Vector3(-12.5, 0, 9.5))
	m.rotation_degrees.y = 90.0
	_box(m, "Body", Vector3(1.4, 2.2, 1.0), Color(0.55, 0.15, 0.2), Vector3(0, 1.1, 0))
	_box(m, "Screen", Vector3(1.0, 0.7, 0.05), Color(0.2, 0.25, 0.3), Vector3(0, 1.5, 0.52), false)
	for i in 3:
		var reel := SphereMesh.new()
		reel.radius = 0.13
		reel.height = 0.26
		_mesh(m, "Reel%d" % i, reel, Color(1, 0.8, 0.3), Vector3(-0.3 + i * 0.3, 1.5, 0.58))
	_box(m, "Marquee", Vector3(1.4, 0.35, 0.1), Color(1.0, 0.9, 0.2), Vector3(0, 2.35, 0.2), false)
	var lever := CylinderMesh.new()
	lever.top_radius = 0.05
	lever.bottom_radius = 0.05
	lever.height = 0.9
	_mesh(m, "Lever", lever, Color(0.8, 0.8, 0.85), Vector3(0.85, 1.4, 0), 0.8)
	var knob := SphereMesh.new()
	knob.radius = 0.12
	knob.height = 0.24
	_mesh(m, "LeverKnob", knob, Color(1.0, 0.2, 0.2), Vector3(0.85, 1.9, 0))
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
	var path := PLAT + ("platform-medium.glb" if kind == "big" else ("platform-falling.glb" if kind == "fall" else "platform.glb"))
	var a := _model_aabb(path)
	var k := 0.6
	body.position = top - Vector3(0, a.end.y * k, 0)
	var inst: Node3D = load(path).instantiate()
	inst.scale = Vector3.ONE * k
	_add(body, inst, "Model")
	_box_shape(body, a.size * k, (a.position + a.size * 0.5) * k)


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
