class_name GeoMesh
extends RefCounted
## Сборщик меша из нескольких поверхностей: каждая со своим материалом из Mats.
## g.s("concrete") — SurfaceTool для бетона и т. д.

var _tools := {}


func s(key: String) -> SurfaceTool:
	if not _tools.has(key):
		_tools[key] = Geo.begin()
	return _tools[key]


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _tools:
		var st: SurfaceTool = _tools[key]
		st.generate_normals()
		if key in ["leaves", "grass_blades", "interior"]:
			st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Mats.get_mat(key))
	return mesh
