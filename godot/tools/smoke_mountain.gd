extends SceneTree
## Дымовой тест локации «Мурашки»: игрок на снегу у лагеря, тропа проходима, коты по сложностям, опасности по тирам,
## холод и костёр, лёд, сосулька, лавинка, ледяной мост, провал в трещину, спасение.
## Запуск: godot --headless --path godot --script res://tools/smoke_mountain.gd

const MT := preload("res://scripts/location/mountain/mountain_terrain.gd")
var failures := 0


func check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FAIL ") + name)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func tp(player: Player, pos: Vector3) -> void:
	player.global_position = pos
	player.linear_velocity = Vector3.ZERO


func _init() -> void:
	var loc: Location = load("res://scenes/locations/mountain.tscn").instantiate()
	root.add_child(loc)
	await frames(80)
	var player: Player = loc.get_node("Players/Player1")
	var off := Node.PROCESS_MODE_DISABLED
	check("игрок стоит на снегу у лагеря", absf(player.global_position.y - MT.height(player.global_position.x, player.global_position.z)) < 1.5 and player.global_position.z > 60.0)
	# Тропа: на каждой точке стоим на земле
	var okp := true
	for w in MT.PATH:
		tp(player, Vector3(w.x, w.z + 2.0, w.y))
		await frames(40)
		if absf(player.global_position.y - (w.z)) > 3.0:
			okp = false
			print("  точка тропы ", w, " -> ", player.global_position)
	check("все точки тропы проходимы", okp)
	# Сложность и коты
	var cat: Node3D = loc.get_node("Cat")
	for d in 3:
		loc.apply_difficulty(d)
		await frames(2)
		check("кот на точке %d" % d, cat.global_position.distance_to(loc.get_node("CatSpots").get_child(d).global_position) < 0.1)
	loc.apply_difficulty(0)
	await frames(2)
	check("простая: лавин и сосулек арок нет, лёд есть", loc.get_node("Avalanches/Avalanche0").process_mode == off and loc.get_node("Arches/Arch0/Icicle0").process_mode == off and loc.get_node("Ice/IceZone0").process_mode != off and loc.get_node("Bridge/Falling").process_mode == off)
	loc.apply_difficulty(1)
	await frames(2)
	check("средняя: лавина 0, сосульки и плитки моста включены, лавина 1 выключена", loc.get_node("Avalanches/Avalanche0").process_mode != off and loc.get_node("Arches/Arch0/Icicle0").process_mode != off and loc.get_node("Bridge/Falling").process_mode != off and loc.get_node("Avalanches/Avalanche1").process_mode == off)
	loc.apply_difficulty(2)
	await frames(2)
	check("сложная: всё включено", loc.get_node("Avalanches/Avalanche1").process_mode != off and loc.get_node("Arches/Arch2/Icicle0").process_mode != off)
	# Холод и костёр
	var cold: Cold = loc.get_node("Cold")
	tp(player, Vector3(-14, MT.height(-14, 20) + 1.0, 20))
	cold.level = 0.0
	await frames(240)
	check("вне костра холод растёт", cold.level > 0.01)
	var lv: float = cold.level
	tp(player, Vector3(-4, MT.height(-4, 70) + 1.0, 70))
	await frames(240)
	check("у костра отогреваешься", cold.level < lv)
	# Лавинка
	var rb_before := 0
	for n in loc.get_children():
		if n is RigidBody3D:
			rb_before += 1
	(loc.get_node("Avalanches/Avalanche1") as Avalanche).spawn_now()
	await frames(5)
	var rb_after := 0
	for n in loc.get_children():
		if n is RigidBody3D:
			rb_after += 1
	check("лавина создаёт снежные шары", rb_after > rb_before)
	# Мост: провал в трещину возвращает на чекпоинт
	var bc: Vector3 = loc.get_node("Bridge/Solid/Plank2").global_position
	tp(player, bc + Vector3(0, 1.0, 0))
	await frames(30)
	check("на мосту стоим", player.global_position.y > bc.y)
	tp(player, bc + Vector3(0, -14.0, 0))
	await frames(40)
	check("провал в трещину -> возврат на чекпоинт", player.global_position.y > bc.y - 20.0 and player.global_position.distance_to(bc + Vector3(0, -14.0, 0)) > 5.0)
	# Спасение на уступе
	loc.apply_difficulty(2)
	await frames(2)
	var ledge: Vector3 = loc.get_node("CatSpots/Ledge").global_position
	tp(player, (loc.get_node("Cat") as Node3D).global_position + Vector3(0, 0.1, 0.5))
	await frames(30)
	var resc := [false]
	loc.cat_rescued.connect(func() -> void: resc[0] = true)
	Input.action_press("interact")
	await frames(240)
	Input.action_release("interact")
	check("кота можно спасти", resc[0])
	print("failures: %d" % failures)
	quit(failures)
