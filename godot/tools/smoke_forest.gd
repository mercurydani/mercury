extends SceneTree
## Дымовой тест локации «Нора у ручья»: игрок стоит на берегу, ручей замедляет и тянет, омут топит и возвращает на чекпоинт,
## опасности включаются по сложности, белка кидает шишки, кот на месте, спасение работает.
## Запуск: godot --headless --path godot --script res://tools/smoke_forest.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _init() -> void:
	var loc: Location = load("res://scenes/locations/forest.tscn").instantiate()
	root.add_child(loc)
	await frames(60)
	var player: Player = loc.get_node("Players/Player1")
	var R := load("res://scripts/location/forest/ravine_terrain.gd")
	var start := player.global_position
	check("игрок стоит на берегу (не провалился)", absf(start.y - R.height(start.x, start.z)) < 1.0)
	# Ручей: течение несёт к +X, замедляет
	var mx: float = -50.0
	player.global_position = Vector3(mx, R.WATER_Y + 0.2, R.meander(mx))
	player.linear_velocity = Vector3.ZERO
	var x0 := player.global_position.x
	await frames(90)
	check("течение несёт игрока вниз по ручью", player.global_position.x > x0 + 1.5)
	check("в воде скорость снижена", player.move_speed < 6.4)
	# Омут: тонешь и возвращаешься на чекпоинт
	var drowned := [0]
	loc.player_fell.connect(func(_p: Node3D) -> void: drowned[0] += 1)
	var px: float = R.POND_X
	player.global_position = Vector3(px, R.WATER_Y + 0.1, R.meander(px))
	player.linear_velocity = Vector3.ZERO
	await frames(240)
	check("омут: утонул и вернулся на чекпоинт", drowned[0] >= 1 and player.global_position.distance_to(Vector3(px, 0, R.meander(px))) > 5.0)
	check("скорость восстановлена после утопления", player.move_speed > 6.4)
	# Сложность
	loc.apply_difficulty(0)
	await frames(2)
	check("простая: капкан выключен", loc.get_node("Hazards/Trap").process_mode == Node.PROCESS_MODE_DISABLED)
	check("простая: ящики выключены", loc.get_node("Hazards/Crates").process_mode == Node.PROCESS_MODE_DISABLED)
	check("простая: белка 0 работает", loc.get_node("Hazards/Squirrel0").process_mode != Node.PROCESS_MODE_DISABLED)
	loc.apply_difficulty(2)
	await frames(2)
	check("сложная: капкан и ящики включены", loc.get_node("Hazards/Trap").process_mode != Node.PROCESS_MODE_DISABLED and loc.get_node("Hazards/Crates").process_mode != Node.PROCESS_MODE_DISABLED)
	await frames(240)
	check("сложная: ящики плывут", get_nodes_in_group("floaters").size() > 0)
	# Кот на месте по сложности
	var cat: Node3D = loc.get_node("Cat")
	for d in 3:
		loc.apply_difficulty(d)
		await frames(2)
		var spot: Node3D = loc.get_node("CatSpots").get_child(d)
		check("кот на точке %d" % d, cat.global_position.distance_to(spot.global_position) < 0.1)
	# Подъём к ветке дуба B по брёвнам (простая сложность)
	loc.apply_difficulty(0)
	var spotB: Node3D = loc.get_node("CatSpots").get_child(1)
	player.global_position = Vector3(spotB.global_position.x + 10.0, R.height(spotB.global_position.x + 10.0, spotB.global_position.z) + 0.8, spotB.global_position.z)
	player.linear_velocity = Vector3.ZERO
	await frames(30)
	var reachedB := false
	Input.action_press("move_left")
	for i in 240:
		await physics_frame
		if player.global_position.y > spotB.global_position.y - 0.8 and player.global_position.distance_to(spotB.global_position) < 3.0:
			reachedB = true
			break
	Input.action_release("move_left")
	check("дуб B: игрок поднялся на ветку", reachedB)
	# Дуб C: два пролёта и помост
	var spotC: Node3D = loc.get_node("CatSpots").get_child(2)
	var cp := Vector3(spotC.global_position.x - 7.4 - 7.0, 0, spotC.global_position.z - 6.0)
	cp.y = R.height(cp.x, cp.z) + 0.8
	player.global_position = cp
	player.linear_velocity = Vector3.ZERO
	await frames(30)
	var reachedC := false
	Input.action_press("move_right")
	for i in 400:
		await physics_frame
		if player.global_position.x > spotC.global_position.x - 1.0:
			break
	Input.action_release("move_right")
	Input.action_press("move_back")
	for i in 240:
		await physics_frame
		if player.global_position.y > spotC.global_position.y - 1.0 and player.global_position.distance_to(spotC.global_position) < 3.0:
			reachedC = true
			break
	Input.action_release("move_back")
	check("дуб C: игрок дошёл по пролётам до ветки над ручьём", reachedC)
	# Белка кидает шишки в игрока рядом
	loc.apply_difficulty(0)
	var sq: Node3D = loc.get_node("Hazards/Squirrel0")
	player.global_position = sq.global_position + Vector3(0, -3.0, 6.0)
	var n0 := root.get_child_count()
	await frames(400)
	var cones := 0
	for c in loc.get_node("Hazards").get_children():
		if c is RigidBody3D:
			cones += 1
	check("белка кинула шишку", cones > 0 or player.linear_velocity.length() > 0.0)
	# Падение с водопада возвращает на чекпоинт
	var fell := [0]
	loc.player_fell.connect(func(_p: Node3D) -> void: fell[0] += 1)
	player.global_position = Vector3(R.FALL_X + 3.0, R.WATER_Y + 0.5, R.meander(R.FALL_X + 3.0))
	await frames(240)
	check("водопад: вернулись на чекпоинт", fell[0] >= 1)
	# Спасение кота
	var rescued := [false]
	loc.cat_rescued.connect(func() -> void: rescued[0] = true)
	player.global_position = cat.global_position + Vector3(0, 0.1, 0.5)
	await frames(10)
	Input.action_press("interact")
	await frames(5)
	Input.action_release("interact")
	await frames(10)
	check("кот спасён", rescued[0])
	print("FOREST SMOKE OK" if failures == 0 else "FOREST SMOKE FAILED: %d" % failures)
	quit(failures)
