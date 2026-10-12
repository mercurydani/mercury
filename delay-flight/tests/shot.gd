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
	w.pos = Vector2(130, 450)
	w.yaw = PI
	await _frames(3)
	_save("fp_a")
	w.pos = Vector2(300, 880)
	w.yaw = PI * 0.62
	await _frames(3)
	_save("fp_b")
	w.pos = Vector2(250, 700)
	w.yaw = PI
	w.item = "bag"
	main.spawn_npc("pilot")
	main.spawn_npc("hooligan")
	main.spawn_npc("muscle")
	main.npcs[0].pos = Vector2(380, 640)
	main.npcs[1].pos = Vector2(340, 760)
	main.npcs[2].pos = Vector2(430, 560)
	main.npcs[2].wind = 0.5
	await _frames(3)
	_save("fp_c")
	main.workers.clear()
	main.camera.position = Vector3(4.0, 6.0, 4.2)
	main.camera.look_at(Vector3(15.0, 0.5, 14.0), Vector3.UP)
	await _frames(3)
	_save("overview")
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _save(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/%s.png" % n)
