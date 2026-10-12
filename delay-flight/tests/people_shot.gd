extends SceneTree
# Портреты всех персонажей крупным планом -> /tmp/people_*.png

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.menu_stage.visible = false
	var rigs: Array = []
	for i in 4:
		rigs.append(People.person(People.crew_opts(i)))
	for t in ["pilot", "dispatcher", "hooligan", "muscle"]:
		rigs.append(People.person(People.npc_opts(t)))
	for k in rigs.size():
		var r: Node3D = rigs[k]
		var row := k / 4
		var xs := [1.7, 0.55, -0.6, -1.75] if row == 0 else [2.2, 0.6, -0.9, -3.0]
		r.position = Vector3(12.8 + xs[k % 4], 0, 7.0)
		r.rotation.y = PI
		main.world.add_child(r)
		People.animate(r, 0.0, false, "angry" if row == 1 else "")
	main.camera.current = true
	main.start_game(1)
	main.workers[0].pos = Vector2(130, 100)
	main.workers[0].visible = false
	main.workers.clear()
	var cams := [[Vector3(12.8, 1.1, 3.9), Vector3(12.8, 0.85, 7.0)], [Vector3(12.8, 1.7, 2.6), Vector3(12.0, 1.3, 7.0)]]
	for c in 2:
		main.camera.position = cams[c][0]
		main.camera.look_at(cams[c][1], Vector3.UP)
		main.camera.fov = 52
		for k in rigs.size():
			rigs[k].visible = (k / 4) == c
		for f in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/people_%d.png" % c)
	quit()
