extends SceneTree
## Дымовой тест локации «Карусель-гора»: спавн на земле, карусель везёт игрока, фонтан и вагонетки включаются по сложности,
## на вершину горок можно подняться по лестнице и подъёмнику, коты на трёх точках, спасение работает.
## Запуск: godot --headless --path godot --script res://tools/smoke_amusement.gd

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
	var loc: Location = load("res://scenes/locations/amusement.tscn").instantiate()
	root.add_child(loc)
	await frames(60)
	var player: Player = loc.get_node("Players/Player1")
	check("игрок стоит у ворот", absf(player.global_position.y) < 0.4 and player.global_position.z > 60.0)
	# Сложность
	loc.apply_difficulty(0)
	await frames(2)
	var off := Node.PROCESS_MODE_DISABLED
	check("простая: карусель и фонтан включены", loc.get_node("Carousel/Outer").process_mode != off and loc.get_node("Carousel/InnerStatic").process_mode != off)
	check("простая: вагонетки и сломанные батуты выключены", loc.get_node("Carts/Cart1").process_mode == off and loc.get_node("Carts/Cart2").process_mode == off)
	check("простая: встречное кольцо выключено", loc.get_node("Carousel/InnerSpin").process_mode == off)
	loc.apply_difficulty(2)
	await frames(2)
	check("сложная: встречное кольцо и обе вагонетки включены", loc.get_node("Carousel/InnerSpin").process_mode != off and loc.get_node("Carts/Cart2").process_mode != off and loc.get_node("Carts/Cart1").process_mode != off)
	check("сложная: неподвижное кольцо выключено", loc.get_node("Carousel/InnerStatic").process_mode == off)
	# Коты
	var cat: Node3D = loc.get_node("Cat")
	for d in 3:
		loc.apply_difficulty(d)
		await frames(2)
		check("кот на точке %d" % d, cat.global_position.distance_to(loc.get_node("CatSpots").get_child(d).global_position) < 0.1)
	# Карусель везёт игрока
	loc.apply_difficulty(0)
	await frames(2)
	var cpos: Vector3 = loc.get_node("Carousel").global_position
	tp(player, cpos + Vector3(7.2, 0.9, 0))
	await frames(30)
	var a0 := atan2(player.global_position.x - cpos.x, player.global_position.z - cpos.z)
	await frames(180)
	var a1 := atan2(player.global_position.x - cpos.x, player.global_position.z - cpos.z)
	check("карусель сместила стоящего игрока по кругу", absf(wrapf(a1 - a0, -PI, PI)) > 0.3 and player.global_position.y > 0.3)
	# Внутреннее кольцо стоит на простой
	tp(player, cpos + Vector3(4.0, 0.9, 0))
	await frames(30)
	var p0 := player.global_position
	await frames(90)
	check("внутреннее кольцо неподвижно на простой", player.global_position.distance_to(p0) < 0.6)
	# Подъём на постамент к коту
	tp(player, cpos + Vector3(4.6, 0.9, 0))
	await frames(10)
	var spot0: Node3D = loc.get_node("CatSpots").get_child(0)
	var okp: bool = await walk_until("move_left", func() -> bool: return player.global_position.distance_to(spot0.global_position) < 1.8, 120)
	check("постамент: игрок вышел к коту", okp)
	# Вагонетка едет
	loc.apply_difficulty(1)
	await frames(2)
	var c1: Node3D = loc.get_node("Carts/Cart1")
	var q0 := c1.global_position
	await frames(120)
	check("вагонетка едет", c1.global_position.distance_to(q0) > 2.0)
	# Лестница и подъёмник на вершину
	loc.apply_difficulty(0)
	tp(player, Vector3(11.0, 0.8, 32.0))
	await frames(20)
	var ok1: bool = await walk_until("move_right", func() -> bool: return player.global_position.y > 3.6 and player.global_position.x > 28.0, 900)
	check("станция: поднялись по лестнице", ok1)
	var ok2: bool = await walk_until("move_right", func() -> bool: return player.global_position.y > 13.5 and player.global_position.x > 62.0, 1500)
	check("вершина: поднялись по подъёмнику", ok2)
	var spot1: Node3D = loc.get_node("CatSpots").get_child(1)
	var ok3: bool = await walk_until("move_right", func() -> bool: return player.global_position.distance_to(spot1.global_position) < 2.5, 200)
	check("вершина: дошли до вагонетки с котом", ok3)
	# Доски моста к кабинке
	tp(player, Vector3(68.0, 14.6, 30.5))
	await frames(20)
	var ok4: bool = await walk_until("move_forward", func() -> bool: return player.global_position.z < 22.6 and player.global_position.y > 13.5, 900)
	check("мост: дошли до кабинки колеса", ok4)
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
