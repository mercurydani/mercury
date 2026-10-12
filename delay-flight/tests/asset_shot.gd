extends SceneTree
# Превью моделей с авто-подбором камеры -> /tmp/asset_<name>_<view>.png

func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := n.global_transform.affine_inverse() * mi.global_transform
		var a: AABB = xf * mi.mesh.get_aabb()
		box = a if first else box.merge(a)
		first = false
	return box

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.menu_stage.visible = false
	main.start_game(1)
	main.workers.clear()
	var items := {
		"worker": "res://assets/models/worker/Worker.fbx", "terminal": "res://assets/models/terminal/scene.gltf",
		"bae": "res://assets/models/bae146/scene.gltf", "polya": "res://assets/models/poly/airplane_a.glb",
		"polyb": "res://assets/models/poly/airplane_b.glb", "bus": "res://assets/models/traffic/Bus.fbx",
		"firetruck": "res://assets/models/kenney/firetruck.glb", "tractor": "res://assets/models/kenney/tractor.glb",
	}
	for key in items:
		var holder := Node3D.new()
		main.world.add_child(holder)
		holder.position = Vector3(12.8, 0.0, 30.0)
		var m: Node3D = (load(items[key]) as PackedScene).instantiate()
		holder.add_child(m)
		for ap in m.find_children("*", "AnimationPlayer", true, false):
			var al: PackedStringArray = (ap as AnimationPlayer).get_animation_list()
			for a in al:
				if a.ends_with("Walk"):
					(ap as AnimationPlayer).play(a)
		await process_frame
		var b := _aabb(m)
		var big := maxf(b.size.x, maxf(b.size.y, b.size.z))
		var k := 6.0 / big
		m.scale = Vector3.ONE * k
		m.position = -b.get_center() * k + Vector3(0, b.size.y * k / 2.0, 0)
		print(key, " size=", b.size, " k=", k)
		main.camera.fov = 45
		main.camera.position = holder.position + Vector3(7, 4, 10)
		main.camera.look_at(holder.position + Vector3(0, 2.5, 0), Vector3.UP)
		main.camera.current = true
		for f in 4:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("/tmp/asset_%s.png" % key)
		holder.queue_free()
		await process_frame
	quit()
