extends SceneTree
func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var h := {}
	for n in main.world.get_child(0).find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var why := mi.mesh.get_class()
		var m := mi.material_override
		if m is StandardMaterial3D:
			if m.albedo_texture != null: why += " tex"
			if m.shading_mode != 1: why += " unshaded"
			if m.vertex_color_use_as_albedo: why += " vc"
		elif m == null:
			why += " nomat"
		# родитель
		var p := mi.get_parent()
		why += " <" + p.get_class() + (":" + p.get_script().get_global_name() if p.get_script() != null else "") + ">"
		h[why] = h.get(why, 0) + 1
	var keys := h.keys()
	keys.sort_custom(func(a, b): return h[a] > h[b])
	for k in keys.slice(0, 14):
		print(h[k], "  ", k)
	quit()
