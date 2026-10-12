extends SceneTree
## Дымовой тест локации «Погреб»: игрок на площадке, дверь захлопывается и запускает потоп, лестница вниз скользкая,
## путь к трём котам (зал, винный погреб, угольная куча), помост котельной, пар, крысы, полки, утопление при полном потопе, спасение.
## Запуск: godot --headless --path godot --script res://tools/smoke_cellar.gd

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
	var loc: Location = load("res://scenes/locations/cellar.tscn").instantiate()
	root.add_child(loc)
	await frames(60)
	var player: Player = loc.get_node("Players/Player1")
	var off := Node.PROCESS_MODE_DISABLED
	var flood: RisingWater = loc.get_node("Flood")
	check("игрок стоит на верхней площадке", absf(player.global_position.y - 3.0) < 0.5 and player.global_position.z > 22.0)
	check("потоп ещё не начался", not flood.started and flood.level == 0.0)
	# Сложность
	loc.apply_difficulty(0)
	await frames(2)
	check("простая: пар 1 и скользкие ступени включены, полки и крысы выключены", loc.get_node("Boiler/Vent1").process_mode != off and loc.get_node("Boiler/Vent2").process_mode == off and loc.get_node("Landing/SlipStairs").process_mode != off and loc.get_node("Hall/ShelfA/Shaker").process_mode == off and loc.get_node("Rats/R1").process_mode == off)
	loc.apply_difficulty(1)
	await frames(2)
	check("средняя: полки, крысы и пар 2 включены", loc.get_node("Hall/ShelfA/Shaker").process_mode != off and loc.get_node("Rats/R1").process_mode != off and loc.get_node("Boiler/Vent2").process_mode != off and loc.get_node("Rats/R5").process_mode == off)
	loc.apply_difficulty(2)
	await frames(2)
	check("сложная: больше крыс, пар 3 и скользкий пол", loc.get_node("Rats/R5").process_mode != off and loc.get_node("Boiler/Vent3").process_mode != off and loc.get_node("Wine/SlipPatch").process_mode != off)
	var cat: Node3D = loc.get_node("Cat")
	for d in 3:
		loc.apply_difficulty(d)
		await frames(2)
		check("кот на точке %d" % d, cat.global_position.distance_to(loc.get_node("CatSpots").get_child(d).global_position) < 0.1)
	loc.apply_difficulty(0)
	await frames(2)
	# Лестница вниз скользкая, дверь захлопывается
	var acc0 := player.accel
	tp(player, Vector3(0.0, 3.8, 21.0))
	await frames(20)
	var slow_seen := false
	Input.action_press("move_forward")
	var down := false
	for i in 700:
		await physics_frame
		if player.accel < acc0 * 0.5:
			slow_seen = true
		if player.global_position.y < 0.5 and player.global_position.z < 12.5:
			down = true
			break
	Input.action_release("move_forward")
	check("лестница: спустились в зал", down)
	check("ступени скользкие", slow_seen)
	var door: DoorSlam = loc.get_node("Landing/Door")
	check("дверь захлопнулась", door.closed)
	await frames(10)
	check("потоп запущен дверью", flood.started)
	# Кот за стеллажом
	var spot0: Node3D = loc.get_node("CatSpots").get_child(0)
	tp(player, Vector3(-6.0, 0.8, -3.0))
	await frames(20)
	var ok0: bool = await walk_until("move_left", func() -> bool: return player.global_position.distance_to(spot0.global_position) < 2.0, 500)
	check("зал: дошли до кота за стеллажом", ok0)
	# Винный погреб
	var spot1: Node3D = loc.get_node("CatSpots").get_child(1)
	tp(player, Vector3(-11.0, 0.8, 4.5))
	await frames(20)
	var ok1: bool = await walk_until("move_left", func() -> bool: return player.global_position.distance_to(spot1.global_position) < 3.0, 800)
	check("винный погреб: дошли до кота", ok1)
	# Котельная: помост
	tp(player, Vector3(14.8, 0.8, 12.8))
	await frames(20)
	var ok2: bool = await walk_until("move_right", func() -> bool: return player.global_position.y > 2.3 and player.global_position.x > 20.0, 700)
	check("котельная: поднялись на помост", ok2)
	# Угольная: куча-пандус
	var spot2: Node3D = loc.get_node("CatSpots").get_child(2)
	tp(player, Vector3(13.0, 0.8, -4.5))
	await frames(20)
	var ok3: bool = await walk_until("move_forward", func() -> bool: return player.global_position.y > 2.3 and player.global_position.z < -11.8, 800)
	check("угольная: поднялись по куче на помост", ok3)
	var ok4: bool = await walk_until("move_forward", func() -> bool: return player.global_position.distance_to(spot2.global_position) < 2.5, 200)
	check("угольная: дошли до кота", ok4)
	# Пар бьёт
	loc.apply_difficulty(0)
	await frames(2)
	var vent: Area3D = loc.get_node("Boiler/Vent1")
	var vmax := 0.0
	for k in 600:
		if k % 10 == 0:
			tp(player, vent.global_position - Vector3(0, 0.9, 0))
		await physics_frame
		vmax = maxf(vmax, absf(player.linear_velocity.x))
	check("котёл пшикнул паром и толкнул игрока", vmax > 2.0)
	# Крысы бегают
	loc.apply_difficulty(1)
	await frames(2)
	var rat: Node3D = loc.get_node("Rats/R2")
	var r0 := rat.position
	await frames(60)
	check("крыса бегает", rat.position.distance_to(r0) > 1.0)
	# Шаткая полка роняет банки (средняя)
	var shaker: Area3D = loc.get_node("Hall/ShelfA/Shaker")
	tp(player, shaker.global_position)
	await frames(10)
	var jars := 0
	for k in 3:
		player.linear_velocity.y = 6.0
		await frames(3)
		player.linear_velocity.y = 0.0
		await frames(20)
	for ch in loc.get_children():
		if ch is RigidBody3D and ch != player:
			jars += 1
	check("полка уронила банки", jars > 0)
	# Потоп: утопление при полной воде
	loc.apply_difficulty(0)
	await frames(2)
	var fell := [0]
	loc.player_fell.connect(func(_p: Node3D) -> void: fell[0] += 1)
	flood.level = 1.0
	flood.delay = 0.0
	tp(player, Vector3(-3.0, 0.8, 5.0))
	for i in 400:
		await physics_frame
		if fell[0] > 0:
			break
	check("полная вода топит игрока в зале", fell[0] > 0)
	await frames(20)
	check("после утопления игрок на безопасном чекпоинте", player.global_position.y > 2.4)
	# Спасение
	var rescued := [false]
	loc.cat_rescued.connect(func() -> void: rescued[0] = true)
	flood.level = 0.0
	await frames(2)
	tp(player, cat.global_position + Vector3(0, 0.1, 0.5))
	await frames(10)
	Input.action_press("interact")
	await frames(60)
	Input.action_release("interact")
	check("спасение кота", rescued[0])
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
