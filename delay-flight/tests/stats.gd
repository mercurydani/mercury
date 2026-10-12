extends SceneTree
func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_game(1)
	for i in 3:
		main.spawn_plane()
	for i in 200:
		main.step(0.1)
	var meshes := 0
	var multi := 0
	var labels := 0
	var verts := 0
	for n in main.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for s in 1:
				verts += (mi.mesh.get_faces().size())
	for n in main.find_children("*", "MultiMeshInstance3D", true, false):
		multi += 1
		var mm := (n as MultiMeshInstance3D).multimesh
		verts += mm.instance_count * (mm.mesh.get_faces().size() if mm.mesh != null else 0)
	labels = main.find_children("*", "Label3D", true, false).size()
	print("MeshInstance3D=", meshes, " MultiMesh=", multi, " Label3D=", labels, " approx_verts=", verts, " nodes=", main.find_children("*", "Node", true, false).size())
	# сколько мешей на каждый корневой слой
	for c in main.world.get_children():
		print("  ", c.name, " children=", c.get_child_count(), " meshes=", c.find_children("*", "MeshInstance3D", true, false).size())
	quit()
