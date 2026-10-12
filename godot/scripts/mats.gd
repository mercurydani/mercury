class_name Mats
extends RefCounted
## Библиотека материалов двора. Текстуры сгенерированы tools/gen_textures.py.
## Процедурные меши без UV используют мировую трипланарную проекцию;
## цвет вершин подкрашивает нейтральные текстуры.

const TEX := "res://assets/textures/"

## key: [текстура, метров на тайл, шероховатость по умолчанию, сила нормали]
const TEXTURED := {
	"concrete": ["concrete", 3.0, 0.9, 0.6],
	"asphalt": ["asphalt", 2.5, 0.95, 1.0],
	"brick": ["brick", 1.2, 0.9, 1.0],
	"bark": ["bark", 1.0, 0.95, 1.2],
	"wood": ["wood", 1.0, 0.75, 0.6],
	"metal": ["metal_paint", 1.5, 0.6, 0.6],
	"grass": ["grass", 2.0, 0.95, 0.8],
}

static var _cache := {}


static func get_mat(key: String) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	if TEXTURED.has(key):
		var d: Array = TEXTURED[key]
		m.albedo_texture = load(TEX + d[0] + "_albedo.png")
		m.normal_enabled = true
		m.normal_texture = load(TEX + d[0] + "_normal.png")
		m.normal_scale = d[3]
		m.roughness_texture = load(TEX + d[0] + "_rough.png")
		m.roughness = 1.0
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / float(d[1])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match key:
		"glass":
			m.roughness = 0.05
			m.metallic = 0.6
			m.metallic_specular = 0.9
		"plain":
			m.roughness = 0.85
		"fabric":
			m.roughness = 1.0
		"lit":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.72, 0.38)
			m.emission_energy_multiplier = 1.4
		"leaves", "grass_blades":
			m.albedo_texture = load(TEX + key + "_albedo.png")
			m.normal_enabled = true
			m.normal_texture = load(TEX + key + "_normal.png")
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.45
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.85
			m.backlight_enabled = true
			m.backlight = Color(0.25, 0.35, 0.1)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		"foliage":
			m.roughness = 0.95
	_cache[key] = m
	return m
