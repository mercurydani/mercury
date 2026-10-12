extends SceneTree
## Дымовой тест локации «Ржавые гавани»: спавн на причале, рычаг запускает паром, паром довозит игрока на остров,
## лестницы на штабель, понтон держит игрока (кроме прилива), чайки и прилив включаются по сложности, спасение работает.
## Запуск: godot --headless --path godot --script res://tools/smoke_port.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func walk_until(action: String, cond: Callable, max_frames := 600) -> bool:
	Input.action_press(action)
	var ok := false
	for i in max_frames:
		await physics_frame
		if cond.call():
			ok = true
			break
	Input.action_release(action)
	return ok


func tp(player: Player, pos: Vector3) -> void:
	player.global_position = pos
	player.linear_velocity = Vector3.ZERO


func _init() -> void:
	var loc: Location = load("res://scenes/locations/port.tscn").instantiate()
	root.add_child(loc)
	await frames(60)
	var player: Player = loc.get_node("Players/Player1")
	var off := Node.PROCESS_MODE_DISABLED
	check("игрок стоит на причале", absf(player.global_position.y) < 0.4 and player.global_position.z > 40.0)
	# Сложность
	loc.apply_difficulty(0)
	await frames(2)
	check("простая: паром включён, чайки и прилив выключены", loc.get_node("Gantry/Ferry").process_mode != off and loc.get_node("Gulls/Gull0").process_mode == off and loc.get_node("Tide").process_mode == off)
	loc.apply_difficulty(1)
	await frames(2)
	check("средняя: чайки включены, прилив нет", loc.get_node("Gulls/Gull0").process_mode != off and loc.get_node("Tide").process_mode == off and loc.get_node("Gulls/GullB0").process_mode == off)
	loc.apply_difficulty(2)
	await frames(2)
	check("сложная: прилив и все чайки", loc.get_node("Tide").process_mode != off and loc.get_node("Gulls/GullB0").process_mode != off)
	# Коты
	var cat: Node3D = loc.get_node("Cat")
	for d in 3:
		loc.apply_difficulty(d)
		await frames(2)
		check("кот на точке %d" % d, cat.global_position.distance_to(loc.get_node("CatSpots").get_child(d).global_position) < 0.1)
	loc.apply_difficulty(0)
	await frames(2)
	# Открытый контейнер с котом: можно дойти
	tp(player, Vector3(-14.0, 0.8, 46.0))
	await frames(20)
	var spot0: Node3D = loc.get_node("CatSpots").get_child(0)
	var ok0: bool = await walk_until("move_back", func() -> bool: return player.global_position.distance_to(spot0.global_position) < 2.0, 400)
	check("контейнер на причале: дошли до кота", ok0)
	# Паром: стоит, пока рычаг выключен
	var ferry: FerryCrane = loc.get_node("Gantry/Ferry")
	var f0 := ferry.global_position
	await frames(60)
	check("паром стоит без рычага", ferry.global_position.distance_to(f0) < 0.01)
	var lever_a: Interactable = loc.get_node("Gantry/LeverA")
	lever_a.interact(player)
	check("рычаг включил паром", ferry.running)
	# Выходим на паром (он у причала), едем на остров
	tp(player, Vector3(0.0, 0.8, 27.0))
	await frames(20)
	var ok1: bool = await walk_until("move_forward", func() -> bool: return player.global_position.z < 20.0 and absf(player.global_position.y) < 0.6, 300)
	check("вышли на паром", ok1 or player.global_position.z < 24.0)
	await frames(30)
	var t_z := player.global_position.z
	var ok2 := false
	for i in 900:
		await physics_frame
		if ferry.position.z < 14.0 and ferry._wait > 0.0:
			ok2 = true
			break
	check("паром довёз игрока к острову", ok2 and player.global_position.y > -0.5 and player.global_position.z < t_z - 5.0)
	var ok3: bool = await walk_until("move_forward", func() -> bool: return player.global_position.z < 6.0, 300)
	check("сошли на остров", ok3 and player.global_position.y > -0.3)
	# Рычаг на острове выключает паром
	var lever_b: Interactable = loc.get_node("Island/LeverB")
	lever_b.interact(player)
	check("рычаг на острове выключил паром", not ferry.running)
	# Штабель: пандусы к коту наверху
	tp(player, Vector3(-6.0, 0.8, 4.0))
	await frames(20)
	var ok4: bool = await walk_until("move_forward", func() -> bool: return player.global_position.y > 2.3 and player.global_position.z < -4.5, 700)
	check("штабель: поднялись на первый ярус", ok4)
	var ok5: bool = await walk_until("move_right", func() -> bool: return player.global_position.y > 4.9 and player.global_position.x > 7.0, 900)
	check("штабель: поднялись на верхний контейнер", ok5)
	var spot1: Node3D = loc.get_node("CatSpots").get_child(1)
	var ok6: bool = await walk_until("move_right", func() -> bool: return player.global_position.distance_to(spot1.global_position) < 2.0, 300)
	check("штабель: дошли до кота", ok6)
	# Понтон к лодке
	tp(player, Vector3(16.5, 0.8, -2.0))
	await frames(20)
	var spot2: Node3D = loc.get_node("CatSpots").get_child(2)
	var ok7: bool = await walk_until("move_right", func() -> bool: return player.global_position.distance_to(spot2.global_position) < 2.2 and player.global_position.y > 0.2, 1500)
	check("понтон и трап: дошли до кота на лодке", ok7)
	# Прилив на сложной: понтон уходит под воду и возвращается
	loc.apply_difficulty(2)
	await frames(2)
	var seg: StaticBody3D = loc.get_node("Pontoon/Deck/Seg0")
	var sunk := false
	var back := false
	for i in 2400:
		await physics_frame
		var col := seg.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D
		if col.disabled:
			sunk = true
		elif sunk:
			back = true
			break
	check("прилив: понтон тонет и всплывает", sunk and back)
	# Чайка клюёт
	loc.apply_difficulty(1)
	await frames(2)
	tp(player, Vector3(0.0, 0.8, 38.0))
	var peck := false
	for i in 900:
		await physics_frame
		if player.linear_velocity.y > 3.5:
			peck = true
			break
		if player.global_position.y < 0.0:
			tp(player, Vector3(0.0, 0.8, 38.0))
	check("чайка подбросила игрока", peck)
	# Спасение
	var rescued := [false]
	loc.cat_rescued.connect(func() -> void: rescued[0] = true)
	loc.apply_difficulty(0)
	await frames(2)
	tp(player, cat.global_position + Vector3(0, 0.1, 0.5))
	await frames(10)
	Input.action_press("interact")
	await frames(60)
	Input.action_release("interact")
	check("спасение кота", rescued[0])
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
