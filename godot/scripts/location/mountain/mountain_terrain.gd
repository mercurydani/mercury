class_name MountainTerrain
extends Node3D
## Рельеф «Мурашек»: заснеженная гора с серпантином. Тропа — ломаная PATH (x, z, y): вдоль неё рельеф выравнивается,
## площадки (лагерь, домик, иглу, уступ) плоские, у домика обрыв, перед уступом трещина. Мешь и коллизия строятся при загрузке.

const PATH := [Vector3(0, 72, 0), Vector3(0, 52, 1.5), Vector3(24, 36, 5), Vector3(34, 14, 9), Vector3(14, -2, 12), Vector3(8, -26, 16), Vector3(-16, -38, 20), Vector3(-34, -52, 24), Vector3(-14, -66, 27)]
## Площадки: x, z, радиус, y
const PLATFORMS := [Vector4(0, 74, 12, 0), Vector4(6, -8, 8, 12), Vector4(43, 15, 6, 9), Vector4(-14, -72, 8, 27)]
const CHASM_T := 7.5          # параметр пути (индекс сегмента + доля): центр трещины между P7 и P8
const SEG_LEN := 24.4         # длина сегмента P7-P8, м
const CHASM_W := 3.4
const CHASM_DEPTH := 16.0

static var _noise: FastNoiseLite
static var _noise2: FastNoiseLite

@export var extent: float = 160.0
@export var step: float = 2.5


static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 11
		_noise.frequency = 0.03
		_noise.fractal_octaves = 3
		_noise2 = FastNoiseLite.new()
		_noise2.seed = 23
		_noise2.frequency = 0.4
	return _noise


## Ближайшая точка тропы: x = расстояние, y = высота тропы, z = параметр вдоль (индекс сегмента + доля).
static func path_info(x: float, z: float) -> Vector3:
	var best_d := 1e9
	var best_y := 0.0
	var best_t := 0.0
	for i in PATH.size() - 1:
		var a: Vector3 = PATH[i]
		var b: Vector3 = PATH[i + 1]
		var ab := Vector2(b.x - a.x, b.y - a.y)
		var ap := Vector2(x - a.x, z - a.y)
		var t := clampf(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := (ap - ab * t).length()
		if d < best_d:
			best_d = d
			best_y = lerpf(a.z, b.z, t)
			best_t = i + t
	return Vector3(best_d, best_y, best_t)


static func mountain(x: float, z: float) -> float:
	_n()
	var dx := x / 95.0
	var dz := (z + 50.0) / 85.0
	var h := 30.0 * exp(-(dx * dx + dz * dz))
	h += _noise.get_noise_2d(x, z) * 5.0
	h += _noise2.get_noise_2d(x, z) * 0.18
	var rim := smoothstep(110.0, 160.0, maxf(absf(x), absf(z + 20.0)))
	h += rim * 60.0
	return h


static func height(x: float, z: float) -> float:
	var h := mountain(x, z)
	# Обрыв у домика (запад от площадки)
	var cliff := smoothstep(1.5, -3.0, x) * (1.0 - smoothstep(6.0, 13.0, absf(z + 8.0)))
	h -= 16.0 * cliff
	var pi := path_info(x, z)
	var w := 1.0 - smoothstep(4.0, 15.0, pi.x)
	h = lerpf(h, pi.y, w)
	for p in PLATFORMS:
		var dd := Vector2(x - p.x, z - p.y).length()
		h = lerpf(h, p.w, 1.0 - smoothstep(p.z, p.z + 6.0, dd))
	# Трещина перед уступом: поперёк тропы между P7 и P8
	if pi.z > 7.0 and pi.z < 8.0:
		var c := exp(-pow((pi.z - CHASM_T) * SEG_LEN / CHASM_W, 2.0)) * (1.0 - smoothstep(10.0, 13.0, pi.x))
		h -= CHASM_DEPTH * c
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
	rng.seed = 5
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
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mat.normal_enabled = true
	var ntex := NoiseTexture2D.new()
	var nz := FastNoiseLite.new()
	nz.frequency = 0.06
	ntex.noise = nz
	ntex.as_normal_map = true
	ntex.seamless = true
	ntex.width = 256
	ntex.height = 256
	mat.normal_texture = ntex
	mat.normal_scale = 0.5
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.12
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


func _color(x: float, z: float, h: float, rng: RandomNumberGenerator) -> Color:
	var s := slope(x, z)
	var snow := Color(0.82, 0.85, 0.93).lerp(Color(0.68, 0.76, 0.9), clampf(_noise2.get_noise_2d(x * 0.3, z * 0.3) * 0.5 + 0.5, 0.0, 1.0) * 0.6)
	var rock := Color(0.45, 0.45, 0.48)
	var c := snow
	var pi := path_info(x, z)
	if pi.x < 3.2:
		c = c.lerp(Color(0.78, 0.84, 0.94), 0.7)
	c = c.lerp(rock, clampf((s - 0.75) * 2.2, 0.0, 1.0))
	return c
