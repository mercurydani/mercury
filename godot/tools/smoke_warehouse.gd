extends SceneTree
## Дымовой тест локации «Темнота»: игрок стоит на полу, погрузчик едет, щит бьёт током, ловушки роняют ящики и бочки,
## опасности включаются по сложности, до всех трёх котов можно добраться, спасение работает.
## Запуск: godot --headless --path godot --script res://tools/smoke_warehouse.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


## Идёт в сторону action, пока условие не выполнится (до max_frames).
func walk_until(player: Player, action: String, cond: Callable, max_frames := 600) -> bool:
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
	var loc: Location = load("res://scenes/locations/warehouse.tscn").instantiate()
	root.add_child(loc)
	await frames(60)
	var player: Player = loc.get_node("Players/Player1")
	check("игрок стоит на полу склада", absf(player.global_position.y) < 0.4 and player.global_position.x > 20.0)
	# Сложность
	loc.apply_difficulty(0)
	await frames(2)
	check("простая: щит и погрузчик F1 включены", loc.get_node("Hazards/ShockPanel").process_mode != Node.PROCESS_MODE_DISABLED and loc.get_node("Hazards/Forklift1").process_mode != Node.PROCESS_MODE_DISABLED)
	check("простая: падение ящиков и F2 выключены", loc.get_node("Hazards/CrateDrop").process_mode == Node.PROCESS_MODE_DISABLED and loc.get_node("Hazards/Forklift2").process_mode == Node.PROCESS_MODE_DISABLED)
	check("простая: запасные лампы включены", loc.get_node("AuxLamps").visible)
	loc.apply_difficulty(2)
	await frames(2)
	check("сложная: F2 включён, запасные лампы погашены", loc.get_node("Hazards/Forklift2").process_mode != Node.PROCESS_MODE_DISABLED and not loc.get_node("AuxLamps").visible)
	# Коты
	var cat: Node3D = loc.get_node("Cat")
	for d in 3:
		loc.apply_difficulty(d)
		await frames(2)
		check("кот на точке %d" % d, cat.global_position.distance_to(loc.get_node("CatSpots").get_child(d).global_position) < 0.1)
	# Погрузчик едет
	loc.apply_difficulty(0)
	var f1: Node3D = loc.get_node("Hazards/Forklift1")
	var p0 := f1.global_position
	await frames(120)
	check("погрузчик F1 едет по маршруту", f1.global_position.distance_to(p0) > 1.5)
	# Щит бьёт током рядом
	var panel: Area3D = loc.get_node("Hazards/ShockPanel")
	tp(player, panel.global_position + Vector3(0, -0.5, -1.5))
	var v_max := 0.0
	for i in 400:
		await physics_frame
		v_max = maxf(v_max, player.linear_velocity.length())
		tp_guard(player, panel)
	check("щит отбросил игрока током", v_max > 5.0)
	# Падающие ящики и бочки (средняя)
	loc.apply_difficulty(1)
	await frames(2)
	var dz: Area3D = loc.get_node("Hazards/CrateDrop")
	var n0 := loc.get_node("Hazards").get_child_count()
	tp(player, dz.global_position)
	await frames(60)
	check("ловушка уронила ящики", loc.get_node("Hazards").get_child_count() > n0)
	var bz: Area3D = loc.get_node("Hazards/BarrelSpill")
	var n1 := loc.get_node("Hazards").get_child_count()
	tp(player, bz.global_position)
	await frames(80)
	check("бочки выкатились", loc.get_node("Hazards").get_child_count() > n1)
	# Путь на среднюю полку по пандусу
	loc.apply_difficulty(0)
	var spot1: Node3D = loc.get_node("CatSpots").get_child(1)
	tp(player, Vector3(22.0, 0.8, 7.0))
	await frames(20)
	var ok1: bool = await walk_until(player, "move_left", func() -> bool: return player.global_position.distance_to(spot1.global_position) < 2.0 and player.global_position.y > 3.8, 900)
	check("полка R3: игрок поднялся по пандусу и дошёл до кота", ok1)
	# Дальше на запад по полке, мостик и галерея на север
	tp(player, Vector3(-26.0, 4.6, 7.0))
	await frames(20)
	var ok2: bool = await walk_until(player, "move_left", func() -> bool: return player.global_position.x < -31.0, 300)
	check("полка R3: дошли до западного торца", ok2)
	var ok3: bool = await walk_until(player, "move_forward", func() -> bool: return player.global_position.z < -14.1 and player.global_position.y > 4.0, 600)
	check("галерея: прошли вдоль западной стены", ok3)
	Input.action_press("move_right")
	var ok4 := false
	for i in 300:
		await physics_frame
		if player.global_position.y > 6.0:
			ok4 = true
			break
	Input.action_release("move_right")
	check("подъём на верх R1", ok4)
	var spot2: Node3D = loc.get_node("CatSpots").get_child(2)
	var ok5: bool = await walk_until(player, "move_right", func() -> bool: return player.global_position.distance_to(spot2.global_position) < 2.0 and player.global_position.y > 5.8, 700)
	check("верх R1: игрок дошёл до кота", ok5)
	# Падение с полки возвращает на пол без вылета за карту
	tp(player, Vector3(-12.0, 7.0, -10.0))
	await frames(120)
	check("после падения игрок остаётся на полу", player.global_position.y > -1.0)
	# Спасение
	var rescued := [false]
	loc.cat_rescued.connect(func() -> void: rescued[0] = true)
	tp(player, cat.global_position + Vector3(0, 0.1, 0.5))
	await frames(10)
	Input.action_press("interact")
	await frames(5)
	Input.action_release("interact")
	await frames(10)
	check("кот спасён", rescued[0])
	print("WAREHOUSE SMOKE OK" if failures == 0 else "WAREHOUSE SMOKE FAILED: %d" % failures)
	quit(failures)


func tp_guard(player: Player, panel: Node3D) -> void:
	# держим игрока у щита в течение теста дуги, пока его не отбросило
	if player.global_position.distance_to(panel.global_position) > 6.0:
		return
