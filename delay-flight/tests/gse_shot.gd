extends SceneTree
# Портреты техники крупным планом -> /tmp/gse_*.png

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu_stage.visible = false
	main.start_game(1)
	main.workers.clear()
	var stage := Node3D.new()
	main.world.add_child(stage)
	var specs := [
		["fuel", GSE.fuel_truck, 3.2, Vector3(0.5, 0.6, -0.8)],
		["loader", GSE.belt_loader, 3.4, Vector3(0.9, 0.7, -0.6)],
		["train", func(): return GSE.baggage_train(2), 4.4, Vector3(0.9, 0.5, 0.7)],
		["stairs", GSE.stairs_truck, 3.0, Vector3(0.9, 0.6, -0.7)],
		["catering", GSE.catering_truck, 3.2, Vector3(0.9, 0.6, -0.7)],
		["bus", GSE.bus, 4.2, Vector3(0.9, 0.5, -0.7)],
		["pushback", GSE.pushback_tug, 3.6, Vector3(0.9, 0.6, 0.6)],
		["gpu_uld", func(): var n := Node3D.new(); var a := GSE.gpu_cart(); n.add_child(a); var b := GSE.uld(); b.position = Vector3(1.0, 0, 0); n.add_child(b); var c := GSE.cone(); c.position = Vector3(-0.6, 0, 0.2); n.add_child(c); return n, 2.0, Vector3(0.7, 0.5, -0.7)],
	]
	for s in specs:
		var v: Node3D = s[1].call()
		v.position = Vector3(30, 0, 70)
		stage.add_child(v)
		var d: float = s[2]
		var dir: Vector3 = (s[3] as Vector3).normalized()
		main.camera.fov = 45
		main.camera.position = Vector3(30, 0.7, 70) + dir * d
		main.camera.position.y = 0.9
		main.camera.look_at(Vector3(30, 0.55, 70), Vector3.UP)
		main.camera.current = true
		for f in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/gse_%s.png" % s[0])
		v.queue_free()
		await process_frame
	quit()
