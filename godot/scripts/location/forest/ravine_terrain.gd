class_name RavineTerrain
extends Node3D
## Рельеф локации «Нора у ручья»: овраг с извилистым ручьём, омут, водопад и холмы по краям.
## Мешь, коллизия и вода строятся при загрузке из параметров (в сцене лежат только они).
## Ручей течёт к +X. Высоты считает статический height(), им пользуются генератор сцены, посадка леса и вода.

const WATER_Y := -0.55
const FALL_X := 72.0
const POND_X := 22.0
## Вытоптанные пятна: x, смещение от ручья по z, радиус
const DIRT_SPOTS := [Vector3(-56, 11, 8), Vector3(-40, -14, 6), Vector3(-37, -4, 4), Vector3(18, 5, 5), Vector3(2, -10, 4), Vector3(2, 10, 4), Vector3(-28, -10, 4)]

static var _noise: FastNoiseLite
static var _noise2: FastNoiseLite

@export var extent: float = 260.0
@export var step: float = 2.5


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 7
		_noise.frequency = 0.02
		_noise.fractal_octaves = 3
		_noise2 = FastNoiseLite.new()
		_noise2.seed = 19
		_noise2.frequency = 0.35
	return _noise


static func meander(x: float) -> float:
	return 6.0 * sin(x * 0.035) + 2.5 * sin(x * 0.09 + 1.0)


static func stream_dist(x: float, z: float) -> float:
	return absf(z - meander(x))


static func height(x: float, z: float) -> float:
	_n()
	var d := stream_dist(x, z)
	var bank := smoothstep(9.0, 26.0, d)
	var h := bank * 9.0 + bank * bank * 6.0
	h += _noise.get_noise_2d(x, z) * 5.0 * smoothstep(6.0, 30.0, d)
	h += _noise2.get_noise_2d(x, z) * 0.22
	# Берега не уходят под воду вне русла (иначе в низинах разливаются озёра)
	h = maxf(h, WATER_Y + 0.45 * smoothstep(4.5, 8.0, d))
	var rim := smoothstep(150.0, 250.0, maxf(absf(x), absf(z)))
	h += rim * 30.0
	h -= 1.7 * exp(-pow(d / 3.4, 2.0))
	h -= 3.4 * exp(-(pow(x - POND_X, 2.0) / 40.0 + pow(z - meander(x), 2.0) / 14.0))
	h -= 17.0 * smoothstep(FALL_X - 2.0, FALL_X + 6.0, x) * (1.0 - smoothstep(8.0, 14.0, d))
	return h


static func slope(x: float, z: float) -> float:
	var e := 0.8
	var dx := height(x + e, z) - height(x - e, z)
	var dz := height(x, z + e) - height(x, z - e)
	return sqrt(dx * dx + dz * dz) / (2.0 * e)


func _ready() -> void:
	_build()


func _build() -> void:
	var n := int(extent * 2.0 / step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	for i in n + 1:
		for j in n + 1:
			var x := -extent + i * step
			var z := -extent + j * step
			var h := height(x, z)
			verts.append(Vector3(x, h, z))
			cols.append(_color(x, z, h, rng))
	for i in n:
		for j in n:
			var a := i * (n + 1) + j
			var b := (i + 1) * (n + 1) + j
			var c := (i + 1) * (n + 1) + j + 1
			var d := i * (n + 1) + j + 1
			for idx in [a, b, c, a, c, d]:
				st.set_color(cols[idx])
				st.add_vertex(verts[idx])
	st.generate_normals()
	var mesh := st.commit()
	var mat: Material = Mats.get_mat("grass")
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.name = "TerrainMesh"
	add_child(mi)
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)
	_water()


func _color(x: float, z: float, h: float, rng: RandomNumberGenerator) -> Color:
	var s := slope(x, z)
	var d := stream_dist(x, z)
	var grass := Color(0.34, 0.52, 0.2).lerp(Color(0.48, 0.6, 0.24), rng.randf())
	grass = grass.lerp(Color(0.28, 0.42, 0.18), clampf(_noise2.get_noise_2d(x * 0.2, z * 0.2) * 0.5 + 0.5, 0.0, 1.0) * 0.5)
	var dirt := Color(0.45, 0.34, 0.22)
	var rock := Color(0.5, 0.5, 0.48)
	var sand := Color(0.72, 0.66, 0.48)
	var c := grass
	if h < WATER_Y + 0.5 and d < 7.0:
		c = sand.lerp(Color(0.5, 0.45, 0.35), clampf((WATER_Y - h) * 0.4, 0.0, 1.0))
	c = c.lerp(dirt, clampf((s - 0.45) * 2.5, 0.0, 1.0))
	c = c.lerp(rock, clampf((s - 0.9) * 2.5, 0.0, 1.0))
	# Вытоптанные места: стоянка, избушка, пирс, колодец, огород
	for sp in DIRT_SPOTS:
		var dd := Vector2(x - sp.x, z - (meander(sp.x) + sp.y)).length()
		if dd < sp.z:
			c = c.lerp(dirt.lightened(0.1), 0.85 * (1.0 - smoothstep(sp.z * 0.55, sp.z, dd)))
	# Тропа вдоль ручья: вытоптанная земля
	if d > 5.0 and d < 7.5:
		c = c.lerp(dirt.lightened(0.15), 0.4 * (1.0 - absf(d - 6.2) / 1.4))
	return c


func _water() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform vec4 shallow_color : source_color = vec4(0.28, 0.55, 0.55, 0.78);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform sampler2D normal_tex : hint_normal, repeat_enable;
uniform sampler2D noise_tex : repeat_enable;
uniform vec2 flow = vec2(1.0, 0.0);
uniform float flow_speed = 0.35;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 0.09 - flow * TIME * flow_speed;
	vec2 q = wpos.xz * 0.21 - flow * TIME * flow_speed * 1.7 + vec2(0.37, 0.11);
	vec3 n1 = texture(normal_tex, p).rgb;
	vec3 n2 = texture(normal_tex, q).rgb;
	NORMAL_MAP = mix(n1, n2, 0.5);
	NORMAL_MAP_DEPTH = 1.6;
	float nz = texture(noise_tex, p * 1.3).r;
	float foam = smoothstep(0.78, 0.9, nz);
	vec3 col = mix(shallow_color.rgb, vec3(0.12, 0.3, 0.38), smoothstep(0.2, 0.8, texture(noise_tex, wpos.xz * 0.02).r));
	ALBEDO = mix(col, foam_color.rgb, foam * 0.55);
	ALPHA = mix(shallow_color.a, 0.95, foam * 0.5);
	ROUGHNESS = 0.06;
	SPECULAR = 0.7;
	METALLIC = 0.1;
}
"""
	var nz := FastNoiseLite.new()
	nz.frequency = 0.03
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX
	var nt := NoiseTexture2D.new()
	nt.noise = nz
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var nn := FastNoiseLite.new()
	nn.frequency = 0.05
	var nm := NoiseTexture2D.new()
	nm.noise = nn
	nm.seamless = true
	nm.as_normal_map = true
	nm.bump_strength = 6.0
	nm.width = 256
	nm.height = 256
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("normal_tex", nm)
	m.set_shader_parameter("noise_tex", nt)
	# Поверхность ручья до водопада
	var pm := PlaneMesh.new()
	pm.size = Vector2(extent + FALL_X + 4.0, extent * 2.0)
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = m
	mi.name = "Water"
	mi.position = Vector3((FALL_X + 4.0 - extent) * 0.5, WATER_Y, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Водопад: вертикальная лента с быстрым потоком
	var fall := QuadMesh.new()
	fall.size = Vector2(16.0, 17.5)
	var fm := ShaderMaterial.new()
	fm.shader = shader
	fm.set_shader_parameter("normal_tex", nm)
	fm.set_shader_parameter("noise_tex", nt)
	fm.set_shader_parameter("flow", Vector2(0, 1))
	fm.set_shader_parameter("flow_speed", 1.8)
	var fmi := MeshInstance3D.new()
	fmi.mesh = fall
	fmi.material_override = fm
	fmi.name = "Waterfall"
	fmi.rotation_degrees.y = 90
	fmi.position = Vector3(FALL_X + 3.0, WATER_Y - 8.5, meander(FALL_X + 3.0))
	fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fmi)
	# Заводь внизу водопада
	var pool := PlaneMesh.new()
	pool.size = Vector2(extent, extent * 2.0)
	var pmi := MeshInstance3D.new()
	pmi.mesh = pool
	pmi.material_override = m
	pmi.name = "LowerWater"
	pmi.position = Vector3(FALL_X + 6.0 + extent * 0.5, WATER_Y - 17.2, 0)
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmi)
