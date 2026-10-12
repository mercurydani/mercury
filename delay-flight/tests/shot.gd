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
	w.pos = Vector2(130, 560)
	w.yaw = PI
	await _frames(3)
	_save("fp_a")
	w.pos = Vector2(820, 765)
	w.yaw = 0.0
	w.pitch = 0.42
	await _frames(3)
	_save("fp_sign")
	w.pitch = 0.0
	w.pos = Vector2(1000, 765)
	w.yaw = PI
	w.pitch = 0.05
	await _frames(3)
	_save("fp_far")
	w.pos = Vector2(330, 1000)
	w.yaw = PI * 0.62
	await _frames(3)
	_save("fp_b")
	w.pos = Vector2(250, 1120)
	w.yaw = PI
	w.item = "bag"
	main.spawn_npc("pilot")
	main.spawn_npc("hooligan")
	main.spawn_npc("muscle")
	main.npcs[0].pos = Vector2(380, 1060)
	main.npcs[1].pos = Vector2(340, 1200)
	main.npcs[2].pos = Vector2(430, 1180)
	main.npcs[2].wind = 0.5
	await _frames(3)
	_save("fp_c")
	main.workers.clear()
	main.camera.position = Vector3(22.0, 40.0, -6.0)
	main.camera.look_at(Vector3(22.0, 0.0, 28.0), Vector3.UP)
	await _frames(3)
	_save("overview")
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _save(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/%s.png" % n)
