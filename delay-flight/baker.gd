class_name Baker
# Склеивает статичные меши (примитивы и импортированные модели) в крупные куски по материалу и району.
# Было ~3300 объектов на сцену (лаги) — стало около двухсот; отсечение по кадру сохраняется (куски по 90 м).

const CHUNK := 90.0

static func bake(root: Node3D) -> int:
	var groups := {}
	var doomed: Array = []
	_collect(root, Transform3D.IDENTITY, groups, doomed)
	for key in groups:
		var g: Dictionary = groups[key]
		if g.v.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g.v
		arrays[Mesh.ARRAY_NORMAL] = g.n
		if not g.uv.is_empty():
			arrays[Mesh.ARRAY_TEX_UV] = g.uv
		if not g.c.is_empty():
			arrays[Mesh.ARRAY_COLOR] = g.c
		arrays[Mesh.ARRAY_INDEX] = g.i
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = g.mat if g.mat != null else _make_mat(g)
		if not g.shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var n_done := doomed.size()
	doomed.reverse()   # сначала потомки
	for n in doomed:
		if not is_instance_valid(n):
			continue
		if n.get_child_count() > 0:
			(n as MeshInstance3D).mesh = null
		else:
			n.get_parent().remove_child(n)
			n.free()
	return n_done

static func _make_mat(g: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = g.rough
	mat.metallic = g.metal
	if g.unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if g.emit > 0.0:
		mat.emission_enabled = true
		mat.emission = g.emit_col
		mat.emission_energy_multiplier = g.emit
	if g.alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

static func _collect(n: Node, xf: Transform3D, groups: Dictionary, doomed: Array) -> void:
	for c in n.get_children():
		if c is Aircraft or c.has_meta("nobake"):
			continue
		var cxf := xf
		if c is Node3D:
			cxf = xf * (c as Node3D).transform
		if c is MeshInstance3D:
			if _try_add(c as MeshInstance3D, cxf, groups):
				doomed.append(c)
		_collect(c, cxf, groups, doomed)

static func _group(groups: Dictionary, key: String, init: Dictionary) -> Dictionary:
	if not groups.has(key):
		init["v"] = PackedVector3Array()
		init["n"] = PackedVector3Array()
		init["c"] = PackedColorArray()
		init["uv"] = PackedVector2Array()
		init["i"] = PackedInt32Array()
		groups[key] = init
	return groups[key]

static func _append(g: Dictionary, xf: Transform3D, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, col: Color, use_color: bool) -> void:
	var base: int = g.v.size()
	var nb := xf.basis.inverse().transposed()
	var has_uv := uvs.size() == verts.size()
	for k in verts.size():
		g.v.append(xf * verts[k])
		g.n.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
		if use_color:
			g.c.append(col)
		if has_uv:
			g.uv.append(uvs[k])
	for k in idx.size():
		g.i.append(idx[k] + base)

static func _try_add(mi: MeshInstance3D, xf: Transform3D, groups: Dictionary) -> bool:
	var mesh := mi.mesh
	if mesh == null or mesh is PlaneMesh or not mi.visible or mi.skin != null or mi.get_parent() is Skeleton3D:
		return false
	var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cx := int(floor(xf.origin.x / CHUNK))
	var cz := int(floor(xf.origin.z / CHUNK))
	if mesh is PrimitiveMesh:
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or mat.albedo_texture != null or mat.normal_texture != null or mat.next_pass != null or mat.vertex_color_use_as_albedo:
			return false
		var unshaded := mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		if not unshaded and mat.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			return false
		var alpha := mat.albedo_color.a < 0.999
		var emit := mat.emission_energy_multiplier if mat.emission_enabled else 0.0
		var ecol := mat.emission if mat.emission_enabled else Color.BLACK
		var key := "p_%d_%d_%s_%s_%s_%.2f_%.2f_%.2f_%s" % [cx, cz, shadow, alpha, unshaded, mat.roughness, mat.metallic, emit, ecol.to_html()]
		var g := _group(groups, key, {"mat": null, "rough": mat.roughness, "metal": mat.metallic, "emit": emit, "emit_col": ecol,
			"alpha": alpha, "shadow": shadow, "unshaded": unshaded})
		var arrays: Array = mesh.get_mesh_arrays()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty() or idx.is_empty():
			return false
		_append(g, xf, arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], PackedVector2Array(), idx, mat.albedo_color, true)
		return true
	if mesh is ArrayMesh:
		if DisplayServer.get_name() == "headless":
			return false   # у dummy-рендерера нет данных поверхностей
		# импортированная модель: объединяем поверхности с одним и тем же материалом
		var any := false
		for s in mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null or not (mat is StandardMaterial3D) or (mat as StandardMaterial3D).next_pass != null:
				return false
		for s in mesh.get_surface_count():
			var mat := mi.get_active_material(s) as StandardMaterial3D
			var arrays: Array = mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			if idx.is_empty() or verts.is_empty():
				return false
			var key := "m_%d_%d_%s_%d" % [cx, cz, shadow, mat.get_instance_id()]
			var g := _group(groups, key, {"mat": mat, "shadow": shadow})
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			_append(g, xf, verts, norms, uvs, idx, Color.WHITE, false)
			any = true
		return any
	return false
