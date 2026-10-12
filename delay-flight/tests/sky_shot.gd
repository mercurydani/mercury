extends SceneTree
func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu_stage.visible = false
	main.start_game(1)
	main.workers.clear()
	main.world.visible = false
	var views := {"a": [Vector3(0, 18, 0), Vector3(0.2, 60, 100)], "b": [Vector3(0, 10, 0), Vector3(-80, 35, 60)], "c": [Vector3(0, 2, 0), Vector3(40, 5, 100)]}
	for k in views:
		main.camera.position = Vector3(30, 1.6, 20)
		main.camera.fov = 70
		main.camera.look_at(Vector3(30, 1.6, 20) + (views[k][1] as Vector3), Vector3.UP)
		main.camera.current = true
		for f in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/sky_%s.png" % k)
	quit()
