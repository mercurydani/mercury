@tool
extends SceneTree
## Генерирует res://scenes/lobby.tscn из примитивов.
## Запуск: godot --headless --path godot --script res://tools/build_lobby.gd
## Правки сцены делаем либо здесь, либо уже прямо в редакторе (после генерации).

var lobby_root: Node3D


func _init() -> void:
	lobby_root = Node3D.new()
	lobby_root.name = "Lobby"
	lobby_root.set_script(load("res://scripts/lobby.gd"))

	_environment()
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
	DirAccess.make_dir_recursive_absolute("res://scenes")
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
	var holder: Node3D
	if collide:
		holder = StaticBody3D.new()
	else:
		holder = Node3D.new()
	_add(parent, holder, nm, pos)
	var bm := BoxMesh.new()
	bm.size = size
	_mesh(holder, "Mesh", bm, color)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		_add(holder, cs, "Shape")
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


func _set_owner(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner(c, owner_node)


# ---------- сцена ----------

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.78, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.85, 0.7)
	env.ambient_light_energy = 0.7
	we.environment = env
	_add(lobby_root, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.85, 0.6)
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.shadow_enabled = true
	_add(lobby_root, sun, "Sun")


func _yard() -> void:
	var y := Node3D.new()
	_add(lobby_root, y, "Yard")
	_box(y, "Floor", Vector3(32, 0.5, 26), Color(0.45, 0.65, 0.4), Vector3(0, -0.25, 0))
	var fc := Color(0.55, 0.35, 0.2)
	_box(y, "FenceN", Vector3(32, 2.0, 0.4), fc, Vector3(0, 1.0, -13))
	_box(y, "FenceS", Vector3(32, 2.0, 0.4), fc, Vector3(0, 1.0, 13))
	_box(y, "FenceW", Vector3(0.4, 2.0, 26), fc, Vector3(-16, 1.0, 0))
	_box(y, "FenceE", Vector3(0.4, 2.0, 26), fc, Vector3(16, 1.0, 0))
	# Гирлянда: цветные лампочки вдоль северного забора
	var cols := [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.3, 0.8, 1), Color(0.5, 1, 0.5)]
	var g := Node3D.new()
	_add(y, g, "Garland")
	for i in 12:
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		_mesh(g, "Bulb%d" % i, sm, cols[i % 4], Vector3(-14.0 + i * 2.5, 2.4 + 0.15 * sin(i), -12.7))


func _van() -> void:
	var v := Node3D.new()
	v.set_script(load("res://scripts/van.gd"))
	_add(lobby_root, v, "Van", Vector3(0, 0, -3))
	var body_c := Color(0.95, 0.35, 0.2)
	# Кузов: пол, потолок, три стенки (задняя сторона +Z открыта)
	_box(v, "Floor", Vector3(5.0, 0.2, 2.6), Color(0.35, 0.3, 0.28), Vector3(0, 0.45, 0))
	_box(v, "Roof", Vector3(5.0, 0.2, 2.6), body_c, Vector3(0, 2.55, 0))
	_box(v, "WallL", Vector3(5.0, 2.0, 0.2), body_c, Vector3(0, 1.5, -1.3))
	_box(v, "WallR", Vector3(5.0, 2.0, 0.2), body_c, Vector3(0, 1.5, 1.3))
	_box(v, "WallFront", Vector3(0.2, 2.0, 2.6), body_c, Vector3(-2.5, 1.5, 0))
	# Мордочка кота на капоте-стенке (заглушка)
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	_mesh(v, "CatFace", sm, Color(1.0, 0.85, 0.3), Vector3(-2.7, 1.6, 0))
	# Колёса
	for i in 4:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 0.35
		var w := _mesh(v, "Wheel%d" % i, cm, Color(0.1, 0.1, 0.1), Vector3(-1.6 + (i % 2) * 3.2, 0.45, -1.4 + (i / 2) * 2.8))
		w.rotation_degrees = Vector3(90, 0, 0)
	# Места: 4 штуки, по два вдоль стен, лицом к центру
	var seats := Node3D.new()
	_add(v, seats, "Seats")
	var spos := [Vector3(-1.2, 0.7, -0.8), Vector3(0.6, 0.7, -0.8), Vector3(-1.2, 0.7, 0.8), Vector3(0.6, 0.7, 0.8)]
	var scol := [Color(1.0, 0.55, 0.1), Color(0.3, 0.5, 1.0), Color(0.3, 0.8, 0.4), Color(1.0, 0.5, 0.75)]
	for i in 4:
		var s := Marker3D.new()
		_add(seats, s, "Seat%d" % (i + 1), spos[i])
		_box(s, "Cushion", Vector3(0.9, 0.3, 0.9), scol[i], Vector3(0, -0.25, 0), false)
	var ep := Marker3D.new()
	_add(v, ep, "ExitPoint", Vector3(0, 1.0, 3.6))
	# Приборная панель «Радар котиков»
	_box(v, "DashboardPanel", Vector3(0.3, 1.0, 1.6), Color(0.15, 0.2, 0.3), Vector3(-2.2, 1.2, 0), false)
	var rm := SphereMesh.new()
	rm.radius = 0.25
	rm.height = 0.5
	_mesh(v, "RadarLight", rm, Color(0.2, 1.0, 0.4), Vector3(-2.0, 1.55, 0))
	_trigger(v, "Dashboard", "PROMPT_SEARCH", Vector3(-1.6, 1.2, 0), 1.6)
	# Сесть: триггер у заднего борта
	_trigger(v, "SeatTrigger", "PROMPT_SIT", Vector3(0, 1.0, 2.3), 1.8)
	# Стена инструментов (на задней стенке внутри)
	_box(v, "ToolWallBoard", Vector3(3.2, 1.2, 0.1), Color(0.5, 0.35, 0.2), Vector3(0.2, 1.7, -1.15), false)
	for i in 5:
		var hm := CylinderMesh.new()
		hm.top_radius = 0.05
		hm.bottom_radius = 0.05
		hm.height = 0.25
		_mesh(v, "Hook%d" % i, hm, Color(0.8, 0.8, 0.85), Vector3(-1.2 + i * 0.7, 1.9, -1.05), 0.8)
	_trigger(v, "ToolWall", "PROMPT_TOOLS", Vector3(0.2, 1.4, -0.7), 1.6)
	# Ящик «на миссию»
	_box(v, "MissionCrate", Vector3(0.8, 0.5, 0.6), Color(0.7, 0.55, 0.25), Vector3(1.9, 0.8, 0.9), false)


func _stall() -> void:
	var s := Node3D.new()
	_add(lobby_root, s, "Stall", Vector3(-10, 0, 4))
	_box(s, "Counter", Vector3(3.0, 1.0, 1.0), Color(0.75, 0.45, 0.25), Vector3(0, 0.5, 0))
	_box(s, "BackWall", Vector3(3.0, 2.6, 0.2), Color(0.6, 0.4, 0.3), Vector3(0, 1.3, -1.3))
	_box(s, "PostL", Vector3(0.2, 2.8, 0.2), Color(0.5, 0.3, 0.2), Vector3(-1.5, 1.4, 0.4))
	_box(s, "PostR", Vector3(0.2, 2.8, 0.2), Color(0.5, 0.3, 0.2), Vector3(1.5, 1.4, 0.4))
	_box(s, "Awning", Vector3(3.6, 0.15, 2.2), Color(0.9, 0.2, 0.3), Vector3(0, 2.9, -0.3), false)
	_box(s, "Sign", Vector3(2.2, 0.5, 0.1), Color(1.0, 0.85, 0.3), Vector3(0, 3.3, 0.7), false)
	# Баб Нюра за прилавком
	var n := Node3D.new()
	_add(s, n, "BabNyura", Vector3(0, 0, -0.6))
	var cap := CapsuleMesh.new()
	cap.radius = 0.4
	cap.height = 1.5
	_mesh(n, "Body", cap, Color(0.45, 0.3, 0.6), Vector3(0, 0.75, 0))
	var head := SphereMesh.new()
	head.radius = 0.35
	head.height = 0.7
	_mesh(n, "Head", head, Color(0.95, 0.8, 0.7), Vector3(0, 1.75, 0))
	var shawl := SphereMesh.new()
	shawl.radius = 0.42
	shawl.height = 0.5
	_mesh(n, "Shawl", shawl, Color(0.85, 0.5, 0.5), Vector3(0, 1.35, 0))
	# Зеркало-примерочная справа от ларька
	_box(s, "MirrorFrame", Vector3(1.4, 2.2, 0.15), Color(0.9, 0.75, 0.3), Vector3(2.6, 1.2, -0.8), false)
	_box(s, "Mirror", Vector3(1.2, 2.0, 0.05), Color(0.7, 0.9, 1.0), Vector3(2.6, 1.2, -0.7), false)
	_trigger(s, "Trigger", "PROMPT_SHOP", Vector3(0, 1.0, 1.6), 2.0)


func _slot_machine() -> void:
	var m := Node3D.new()
	_add(lobby_root, m, "SlotMachine", Vector3(-6, 0, 8))
	_box(m, "Body", Vector3(1.4, 2.2, 1.0), Color(0.55, 0.15, 0.2), Vector3(0, 1.1, 0))
	_box(m, "Screen", Vector3(1.0, 0.7, 0.05), Color(0.2, 0.25, 0.3), Vector3(0, 1.5, 0.52), false)
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
	_add(lobby_root, m, "Mascot", Vector3(0, 0, 10.5))
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
	# Лапка: узел для вращения
	var paw := Node3D.new()
	_add(m, paw, "Paw", Vector3(0.6, 1.9, 0.3))
	var arm := CapsuleMesh.new()
	arm.radius = 0.16
	arm.height = 0.9
	var am := _mesh(paw, "Arm", arm, gold, Vector3(0.05, 0.4, 0), 0.9)
	am.rotation_degrees = Vector3(0, 0, -10)
	_trigger(m, "Trigger", "PROMPT_PET", Vector3(0, 1.0, 1.4), 2.2)


func _parkour() -> void:
	var p := Node3D.new()
	_add(lobby_root, p, "Parkour", Vector3(10, 0, -2))
	var wood := Color(0.7, 0.5, 0.25)
	# Ящики-ступени
	_box(p, "Crate1", Vector3(1.6, 0.8, 1.6), wood, Vector3(-2, 0.4, 3))
	_box(p, "Crate2", Vector3(1.6, 1.6, 1.6), wood, Vector3(0, 0.8, 3))
	_box(p, "Crate3", Vector3(1.6, 2.4, 1.6), wood, Vector3(2, 1.2, 3))
	# Бочки (физика)
	for i in 3:
		var rb := RigidBody3D.new()
		_add(p, rb, "Barrel%d" % (i + 1), Vector3(-3 + i * 1.4, 0.7, -1.0))
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 1.2
		_mesh(rb, "Mesh", cm, Color(0.3, 0.45, 0.8))
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.5
		sh.height = 1.2
		cs.shape = sh
		_add(rb, cs, "Shape")
	# Труба-балка
	_box(p, "Beam", Vector3(5.0, 0.3, 0.5), Color(0.5, 0.5, 0.55), Vector3(1.0, 1.4, -4.0))
	_box(p, "BeamPostL", Vector3(0.3, 1.4, 0.3), Color(0.5, 0.5, 0.55), Vector3(-1.3, 0.7, -4.0))
	_box(p, "BeamPostR", Vector3(0.3, 1.4, 0.3), Color(0.5, 0.5, 0.55), Vector3(3.3, 0.7, -4.0))
	# Батут
	var t := Area3D.new()
	t.set_script(load("res://scripts/trampoline.gd"))
	_add(p, t, "Trampoline", Vector3(3.5, 0.2, 0.0))
	var tm := CylinderMesh.new()
	tm.top_radius = 1.3
	tm.bottom_radius = 1.3
	tm.height = 0.4
	_mesh(t, "Mesh", tm, Color(0.95, 0.3, 0.6))
	var tcs := CollisionShape3D.new()
	var tsh := CylinderShape3D.new()
	tsh.radius = 1.3
	tsh.height = 0.6
	tcs.shape = tsh
	_add(t, tcs, "Shape")
	# Сарай с крышей, на крыше приз
	var shed := Node3D.new()
	_add(p, shed, "Shed", Vector3(2.5, 0, -8.0))
	_box(shed, "Walls", Vector3(5.0, 4.5, 3.0), Color(0.6, 0.35, 0.3), Vector3(0, 2.25, 0))
	_box(shed, "RoofSlab", Vector3(5.4, 0.3, 3.4), Color(0.35, 0.2, 0.2), Vector3(0, 4.65, 0))
	var prize := Node3D.new()
	_add(shed, prize, "PrizeCushion", Vector3(0, 5.1, 0))
	_box(prize, "Cushion", Vector3(0.9, 0.35, 0.9), Color(0.95, 0.75, 0.85), Vector3.ZERO, false)
	var lm := SphereMesh.new()
	lm.radius = 0.15
	lm.height = 0.3
	_mesh(prize, "LogoStub", lm, Color(0.3, 0.2, 0.9), Vector3(0, 0.25, 0))
	# Лесенка из ящиков к сараю (подъём на крышу)
	_box(shed, "Step1", Vector3(1.5, 1.2, 1.5), wood, Vector3(-3.4, 0.6, 2.2))
	_box(shed, "Step2", Vector3(1.5, 2.4, 1.5), wood, Vector3(-3.4, 1.2, 0.2))
	_box(shed, "Step3", Vector3(1.5, 3.6, 1.5), wood, Vector3(-3.4, 1.8, -1.8))
	_box(shed, "Step4", Vector3(1.5, 4.5, 1.5), wood, Vector3(-3.4, 2.25, -3.8))


func _players() -> void:
	var holder := Node3D.new()
	_add(lobby_root, holder, "Players")
	var cols := [Color(1.0, 0.55, 0.1), Color(0.3, 0.5, 1.0), Color(0.3, 0.8, 0.4), Color(1.0, 0.5, 0.75)]
	var p := RigidBody3D.new()
	p.set_script(load("res://scripts/player.gd"))
	p.collision_layer = 1
	p.collision_mask = 1
	p.mass = 1.2
	p.linear_damp = 0.2
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.0
	p.physics_material_override = pm
	_add(holder, p, "Player1", Vector3(4, 1.2, 4))
	# Тело: пухлая капсула + большая голова + рюкзак
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.2
	cs.shape = cap
	_add(p, cs, "Shape", Vector3(0, 0.6, 0))
	var bm := CapsuleMesh.new()
	bm.radius = 0.5
	bm.height = 1.1
	_mesh(p, "Body", bm, cols[0], Vector3(0, 0.55, 0))
	var hm := SphereMesh.new()
	hm.radius = 0.45
	hm.height = 0.9
	_mesh(p, "Head", hm, Color(1.0, 0.85, 0.7), Vector3(0, 1.4, 0))
	var helmet := SphereMesh.new()
	helmet.radius = 0.5
	helmet.height = 0.6
	_mesh(p, "Helmet", helmet, cols[0], Vector3(0, 1.65, 0))
	var bag := BoxMesh.new()
	bag.size = Vector3(0.6, 0.7, 0.3)
	_mesh(p, "Backpack", bag, Color(0.2, 0.2, 0.25), Vector3(0, 0.7, 0.5))
	var ia := Area3D.new()
	ia.name = "InteractArea"
	ia.collision_layer = 0
	ia.collision_mask = 2
	var ics := CollisionShape3D.new()
	var iss := SphereShape3D.new()
	iss.radius = 0.8
	ics.shape = iss
	_add(ia, ics, "Shape")
	_add(p, ia, "InteractArea", Vector3(0, 0.6, 0))
	var fr := RayCast3D.new()
	fr.target_position = Vector3(0, -0.3, 0)
	fr.collision_mask = 1
	fr.add_exception(p)
	_add(p, fr, "FloorRay", Vector3(0, 0.1, 0))
	var cam := Camera3D.new()
	cam.top_level = true
	cam.fov = 60
	_add(p, cam, "Camera", Vector3(0, 9, 11))
	# Точки спавна (для 2-4 игроков)
	var sp := Node3D.new()
	_add(lobby_root, sp, "SpawnPoints")
	for i in 4:
		var m := Marker3D.new()
		_add(sp, m, "Spawn%d" % (i + 1), Vector3(3 + i * 1.2, 0.5, 6))


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
