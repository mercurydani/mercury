extends SceneTree
# Скриншоты меню и игры от первого лица (нужен xvfb и opengl3).

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	_save("menu")
	main.start_game(1)
	for i in 3:
		main.spawn_plane()
	for i in 400:
		main.step(0.1)
		if main.planes.all(func(p): return p == null or p.state == "ready"):
			break
	var w: Worker = main.workers[0]
	w.pos = Vector2(140, 1225)
	w.yaw = PI
	await _frames(3)
	_save("fp_a")
	w.pos = Vector2(1180, 1500)
	w.yaw = 0.0
	w.pitch = 0.22
	await _frames(3)
	_save("fp_sign")
	w.pitch = 0.0
	w.pos = Vector2(1500, 1025)
	w.yaw = PI
	w.pitch = 0.04
	await _frames(3)
	_save("fp_far")
	w.pos = Vector2(760, 1030)
	w.yaw = PI * 0.5
	w.pitch = 0.08
	await _frames(3)
	_save("fp_side")
	w.pos = Vector2(700, 1260)
	w.yaw = PI * 0.62
	await _frames(3)
	_save("fp_b")
	w.pos = Vector2(1000, 1030)
	w.yaw = PI
	w.item = "bag"
	main.spawn_npc("pilot")
	main.spawn_npc("hooligan")
	main.spawn_npc("muscle")
	main.npcs[0].pos = Vector2(1050, 1000)
	main.npcs[1].pos = Vector2(1100, 1090)
	main.npcs[2].pos = Vector2(1180, 1020)
	main.npcs[2].wind = 0.5
	await _frames(3)
	_save("fp_c")
	main.workers.clear()
	main.camera.position = Vector3(30.0, 120.0, -30.0)
	main.camera.look_at(Vector3(30.0, 0.0, 60.0), Vector3.UP)
	await _frames(3)
	_save("overview")
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _save(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/%s.png" % n)
