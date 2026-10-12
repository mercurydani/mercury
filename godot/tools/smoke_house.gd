extends SceneTree
## Дымовой тест локации «Дом №13»: игрок у калитки, дом проходим (лестницы на этаж, чердак, подвал), гнилой пол проваливается,
## скрипы будят призрака, тайный шкаф открывается, сквозняк гасит свечи, коты на трёх точках, спасение и бонус тишины.
## Запуск: godot --headless --path godot --script res://tools/smoke_house.gd

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
	var loc: Location = load("res://scenes/locations/house.tscn").instantiate()
	root.add_child(loc)
	await frames(60)
	var player: Player = loc.get_node("Players/Player1")
	var off := Node.PROCESS_MODE_DISABLED
	check("игрок стоит во дворе", absf(player.global_position.y) < 0.4 and player.global_position.z > 15.0)
	# Сложность
	loc.apply_difficulty(0)
	await frames(2)
	check("простая: сквозняки и дальние половицы выключены, паутина W1 включена", loc.get_node("Draughts/D1").process_mode == off and loc.get_node("Creaks/T1a").process_mode == off and loc.get_node("Cobwebs/W1").process_mode != off and loc.get_node("Cobwebs/W4").process_mode == off)
	loc.apply_difficulty(1)
	await frames(2)
	check("средняя: сквозняки и доп. половицы включены", loc.get_node("Draughts/D1").process_mode != off and loc.get_node("Creaks/T1a").process_mode != off and loc.get_node("Creaks/T2a").process_mode == off)
	loc.apply_difficulty(2)
	await frames(2)
	check("сложная: больше паутины и половиц", loc.get_node("Cobwebs/W4").process_mode != off and loc.get_node("Creaks/T2a").process_mode != off)
	# Коты
	var cat: Node3D = loc.get_node("Cat")
	for d in 3:
		loc.apply_difficulty(d)
		await frames(2)
		check("кот на точке %d" % d, cat.global_position.distance_to(loc.get_node("CatSpots").get_child(d).global_position) < 0.1)
	loc.apply_difficulty(0)
	await frames(2)
	# Вход в дом по дорожке
	var ok0: bool = await walk_until("move_forward", func() -> bool: return player.global_position.z < 6.5, 700)
	check("вошли в дом через дверь", ok0 and absf(player.global_position.y) < 0.4)
	# Лестница на второй этаж
	tp(player, Vector3(2.4, 0.8, 6.8))
	await frames(20)
	var ok1: bool = await walk_until("move_forward", func() -> bool: return player.global_position.y > 2.9 and player.global_position.z < 1.0, 700)
	check("лестница: поднялись на второй этаж", ok1)
	# Лестница на чердак
	tp(player, Vector3(-2.4, F2 + 0.8, 6.8))
	await frames(20)
	var ok2: bool = await walk_until("move_forward", func() -> bool: return player.global_position.y > 6.1 and player.global_position.z < 1.0, 700)
	check("чердак: поднялись по второй лестнице", ok2)
	var spot0: Node3D = loc.get_node("CatSpots").get_child(0)
	tp(player, Vector3(2.0, 7.0, -4.0))
	await frames(20)
	var ok3: bool = await walk_until("move_right", func() -> bool: return player.global_position.distance_to(spot0.global_position) < 2.2, 500)
	check("чердак: дошли до кота", ok3)
	# Подвал по лестнице
	tp(player, Vector3(-10.9, 0.8, 0.8))
	await frames(20)
	var ok4: bool = await walk_until("move_back", func() -> bool: return false, 1)
	var okc: bool = await walk_until("move_forward", func() -> bool: return player.global_position.y < -2.6, 700)
	check("подвал: спустились по лестнице", okc)
	var spot1: Node3D = loc.get_node("CatSpots").get_child(1)
	tp(player, Vector3(-8.0, -2.4, -5.0))
	await frames(20)
	var ok5: bool = await walk_until("move_right", func() -> bool: return player.global_position.distance_to(spot1.global_position) < 2.3, 400)
	check("подвал: дошли до кота", ok5)
	# Гнилой пол провалился
	tp(player, Vector3(-6.5, 0.8, 2.5))
	var fell := false
	for i in 200:
		await physics_frame
		if player.global_position.y < -2.0:
			fell = true
			break
	check("гнилой пол: провалились в подвал", fell)
	# Скрип будит призрака
	tp(player, Vector3(0.0, 0.8, 5.5))
	await frames(10)
	var hd: Node = loc.get_node("Haunt")
	var c0: int = hd.creaks
	var ghost: Node3D = loc.get_node("Ghost")
	for k in 4:
		var board: Area3D = loc.get_node("Creaks/C1")
		board.cooldown = 0.0
		tp(player, Vector3(0.0, 1.5, 5.5))
		await frames(30)
	check("скрипы засчитаны", hd.creaks > c0)
	check("призрак появился", ghost.visible)
	# Призрак пугает
	var scared := false
	for i in 600:
		await physics_frame
		if hd.scares > 0:
			scared = true
			break
	check("призрак напугал игрока", scared)
	# Тайный шкаф
	var door: SecretDoor = loc.get_node("Secret/BookcaseDoor")
	var sw: Interactable = loc.get_node("Secret/Sconce")
	var x0 := door.position.x
	sw.interact(player)
	await frames(90)
	check("шкаф отъехал", door.position.x > x0 + 1.5)
	var spot2: Node3D = loc.get_node("CatSpots").get_child(2)
	tp(player, Vector3(0.0, F2 + 0.8, -5.5))
	await frames(20)
	var ok6: bool = await walk_until("move_forward", func() -> bool: return player.global_position.distance_to(spot2.global_position) < 2.2, 500)
	check("тайная комната: дошли до кота", ok6)
	# Сквозняк гасит свечи (средняя)
	loc.apply_difficulty(1)
	await frames(2)
	tp(player, Vector3(-9.0, 1.0, 3.0))
	var out := false
	for i in 1200:
		await physics_frame
		for c in get_nodes_in_group_safe(loc, "candle"):
			if c.get_node("Light").visible == false:
				out = true
		if out:
			break
	check("сквозняк погасил свечу", out)
	# Паутина липнет
	loc.apply_difficulty(0)
	await frames(2)
	var web: Area3D = loc.get_node("Cobwebs/W3")
	var sp0 := player.move_speed
	tp(player, web.global_position)
	await frames(10)
	check("паутина замедляет", player.move_speed < sp0 * 0.8)
	tp(player, Vector3(0.0, 0.8, 18.0))
	await frames(10)
	check("после паутины скорость вернулась", absf(player.move_speed - sp0) < 0.01)
	# Спасение и бонус
	var rescued := [false]
	loc.cat_rescued.connect(func() -> void: rescued[0] = true)
	hd.creaks = 0
	hd.scares = 0
	tp(player, cat.global_position + Vector3(0, 0.1, 0.5))
	await frames(10)
	Input.action_press("interact")
	await frames(60)
	Input.action_release("interact")
	check("спасение кота", rescued[0])
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)


const F2 := 3.2


func get_nodes_in_group_safe(loc: Node, g: String) -> Array:
	return loc.get_tree().get_nodes_in_group(g)
