extends SceneTree
## Дымовой тест локации «Верхотура»: игрок идёт по крыше, сходит трапом на B, падение возвращает на чекпоинт,
## сложность включает опасности, кот спасается.
## Запуск: godot --headless --path godot --script res://tools/smoke_roof.gd

var failures := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		failures += 1


func hold(action: String, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func walk(player: Player, action: String, seconds: float) -> void:
	hold(action, true)
	for i in int(seconds * 60.0):
		# труба поперёк крыши A — перепрыгиваем
		hold("jump", i % 40 == 0)
		await physics_frame
	hold(action, false)
	hold("jump", false)


func _init() -> void:
	var loc: Location = load("res://scenes/locations/roof.tscn").instantiate()
	root.add_child(loc)
	for i in 30:
		await physics_frame
	var player: Player = loc.get_node("Players/Player1")
	check("игрок стоит на крыше A", absf(player.global_position.y - 0.1) < 0.3)
	# Идём на восток: мимо чекпоинта, к трапу, вниз на B
	await walk(player, "move_right", 4.5)
	check("игрок дошёл до трапа (x > 8)", player.global_position.x > 8.0)
	await walk(player, "move_right", 3.0)
	for i in 60:
		await physics_frame
	check("игрок спустился на B и идёт дальше (x > 17, y около -2.7)", player.global_position.x > 17.0 and player.global_position.y < -2.0 and player.global_position.y > -3.2)
	check("чекпоинт 0 взят", player.checkpoint_index >= 0)
	# Падение с обрыва возвращает на чекпоинт
	var fell := [0]
	loc.player_fell.connect(func(_p: Node3D) -> void: fell[0] += 1)
	player.global_position = Vector3(30.5, -9.5, -6.3)
	for i in 5:
		await physics_frame
	check("падение вернуло на чекпоинт", fell[0] == 1 and player.global_position.y > -4.0)
	# Сложность: простая — вентиляторов нет; сложная — есть оба
	loc.apply_difficulty(0)
	await physics_frame
	check("простая: Fan1 выключен", loc.get_node("Hazards/Fan1").process_mode == Node.PROCESS_MODE_DISABLED)
	loc.apply_difficulty(2)
	await physics_frame
	check("сложная: Fan2 включён", loc.get_node("Hazards/Fan2").process_mode != Node.PROCESS_MODE_DISABLED)
	var wind: WindGust = loc.get_node("Hazards/WindGust")
	check("сила ветра растёт со сложностью", wind.strength > 6.0)
	var cat: Node3D = loc.get_node("Cat")
	check("сложная: кот на трубе", cat.global_position.distance_to(loc.get_node("CatSpots/Chimney").global_position) < 0.01)
	# Кот спасается
	var rescued := [false]
	loc.cat_rescued.connect(func() -> void: rescued[0] = true)
	loc.get_node("Cat/Trigger").interact(player)
	check("кот спасён", rescued[0])
	print("ROOF SMOKE ", "OK" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
