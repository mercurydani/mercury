extends SceneTree
# Ориентация самолётов (где хвост), материалы рабочего.

func _verts(n: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var xf := n.global_transform.affine_inverse() * mi.global_transform
		var arr := mi.mesh.surface_get_arrays(0)
		for v in arr[Mesh.ARRAY_VERTEX]:
			out.append(xf * v)
		for s in range(1, mi.mesh.get_surface_count()):
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	return out

func _initialize() -> void:
	for p in ["res://assets/models/bae146/scene.gltf", "res://assets/models/poly/airplane_a.glb", "res://assets/models/poly/airplane_b.glb"]:
		var n: Node3D = (load(p) as PackedScene).instantiate()
		root.add_child(n)
		var vs := _verts(n)
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := Vector3(-1e9, -1e9, -1e9)
		for v in vs:
			mn = mn.min(v)
			mx = mx.max(v)
		# хвост: самые высокие вершины
		var top_y := mx.y - (mx.y - mn.y) * 0.1
		var sx := 0.0
		var sz := 0.0
		var c := 0
		for v in vs:
			if v.y > top_y:
				sx += v.x
				sz += v.z
				c += 1
		var cen := (mn + mx) / 2.0
		print(p.get_file(), " min=", mn, " max=", mx, " tail_top_offset x=", snappedf(sx / c - cen.x, 0.01), " z=", snappedf(sz / c - cen.z, 0.01), " verts=", vs.size())
		n.queue_free()
	var w: Node3D = (load("res://assets/models/worker/Worker.fbx") as PackedScene).instantiate()
	root.add_child(w)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var mats := []
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			mats.append("%s:%s" % [mat.resource_name, (mat as StandardMaterial3D).albedo_color.to_html(false) if mat is StandardMaterial3D else "?"])
		print("worker mesh ", m.name, " surfaces=", mats)
	print("worker scale ", w.scale, " children ", w.get_children().map(func(c): return c.name))
	quit()
