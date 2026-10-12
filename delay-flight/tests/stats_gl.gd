extends SceneTree
func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var h := {}
	var total := 0
	for n in main.world.get_child(0).find_children("*", "MeshInstance3D", true, false):
		total += 1
		var mi := n as MeshInstance3D
		var why := mi.mesh.get_class()
		if mi.material_override is StandardMaterial3D and (mi.material_override as StandardMaterial3D).shading_mode != 1: why += " unshaded"
		h[why] = h.get(why, 0) + 1
	print("TOTAL airport meshes=", total, " ", h)
	quit()
