extends SceneTree
# Делает скриншоты меню и игры для визуальной проверки.

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_save("menu")
	main.start_game(2)
	main.workers[0].position = Vector2(500, 300)
	main.workers[1].position = Vector2(600, 420)
	main.workers[1].item = "bag"
	main.workers[0].item = "coffee"
	main.step(4.0)
	main.spawn_plane()
	main.spawn_plane()
	main.step(3.0)
	main.anger = 70.0
	main.spawn_npc("pilot")
	main.spawn_npc("hooligan")
	main.spawn_npc("dispatcher")
	main.spawn_npc("muscle")
	main.npcs[3].position = Vector2(900, 330)
	main.npcs[3].wind = 0.5
	main.npcs[0].position = Vector2(700, 480)
	main.npcs[1].position = Vector2(560, 560)
	main.shake = 0.0
	main.planes[0].pat = 5.0 if main.planes[0] else 0.0
	await process_frame
	await process_frame
	_save("game")
	quit()

func _save(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/tmp/%s.png" % n)
