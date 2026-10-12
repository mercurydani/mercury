class_name Tex
# Процедурные текстуры (внешние ассеты недоступны): асфальт, бетон, трава, обшивка самолёта.
# Каждая функция возвращает {"albedo": ImageTexture, "normal": ImageTexture}.

static var _cache := {}

static func _noise(seed_: int, freq: float, octaves: int = 4, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	return n

# Серое seamless-изображение шума -> PackedByteArray (L8).
static func _field(seed_: int, size: int, freq: float, octaves: int = 4, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> PackedByteArray:
	var img := _noise(seed_, freq, octaves, kind).get_seamless_image(size, size)
	img.convert(Image.FORMAT_L8)
	return img.get_data()

static func _finish(size: int, rgb: PackedByteArray, bump: PackedByteArray, bump_scale: float) -> Dictionary:
	var albedo := Image.create_from_data(size, size, false, Image.FORMAT_RGB8, rgb)
	albedo.generate_mipmaps()
	var b := Image.create_from_data(size, size, false, Image.FORMAT_L8, bump)
	b.bump_map_to_normal_map(bump_scale)
	b.generate_mipmaps()
	return {"albedo": ImageTexture.create_from_image(albedo), "normal": ImageTexture.create_from_image(b)}

static func _put(rgb: PackedByteArray, size: int, x: int, y: int, r: float, g: float, b: float) -> void:
	x = posmod(x, size)
	y = posmod(y, size)
	var i := (y * size + x) * 3
	rgb[i] = clampi(int(r * 255.0), 0, 255)
	rgb[i + 1] = clampi(int(g * 255.0), 0, 255)
	rgb[i + 2] = clampi(int(b * 255.0), 0, 255)

static func _dim(rgb: PackedByteArray, size: int, x: int, y: int, k: float) -> void:
	x = posmod(x, size)
	y = posmod(y, size)
	var i := (y * size + x) * 3
	rgb[i] = int(rgb[i] * k)
	rgb[i + 1] = int(rgb[i + 1] * k)
	rgb[i + 2] = int(rgb[i + 2] * k)

# Трещина: случайное блуждание.
static func _crack(rgb: PackedByteArray, size: int, rng: RandomNumberGenerator, k: float) -> void:
	var p := Vector2(rng.randf() * size, rng.randf() * size)
	var a := rng.randf() * TAU
	for i in rng.randi_range(40, 120):
		a += rng.randf_range(-0.5, 0.5)
		p += Vector2(cos(a), sin(a))
		_dim(rgb, size, int(p.x), int(p.y), k)
		if rng.randf() < 0.3:
			_dim(rgb, size, int(p.x) + 1, int(p.y), k + 0.15)

static func asphalt(size: int = 256, tone: float = 0.24) -> Dictionary:
	var key := "asphalt%d" % int(tone * 100)
	if _cache.has(key):
		return _cache[key]
	var fine := _field(11, size, 0.35, 2)
	var mid := _field(12, size, 0.05, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var rgb := PackedByteArray()
	rgb.resize(size * size * 3)
	var bump := PackedByteArray()
	bump.resize(size * size)
	for y in size:
		for x in size:
			var i := y * size + x
			var v := tone * (0.82 + fine[i] / 255.0 * 0.3 + mid[i] / 255.0 * 0.35)
			if rng.randf() < 0.025:
				v += rng.randf_range(0.08, 0.2)   # светлый щебень
			rgb[i * 3] = clampi(int(v * 255.0 * 1.0), 0, 255)
			rgb[i * 3 + 1] = clampi(int(v * 255.0 * 1.02), 0, 255)
			rgb[i * 3 + 2] = clampi(int(v * 255.0 * 1.08), 0, 255)
			bump[i] = clampi(int(fine[i] * 0.7 + rng.randf() * 80.0), 0, 255)
	for k in 7:
		_crack(rgb, size, rng, 0.45)
	for k in 5:   # масляные пятна
		var c := Vector2(rng.randf() * size, rng.randf() * size)
		var r := rng.randf_range(8.0, 22.0)
		for y in range(int(c.y - r), int(c.y + r)):
			for x in range(int(c.x - r), int(c.x + r)):
				var d := Vector2(x, y).distance_to(c) / r
				if d < 1.0:
					_dim(rgb, size, x, y, 1.0 - 0.35 * (1.0 - d))
	_cache[key] = _finish(size, rgb, bump, 2.0)
	return _cache[key]

static func concrete(size: int = 256, tone: float = 0.56, slabs: int = 1) -> Dictionary:
	var key := "concrete%d_%d" % [int(tone * 100), slabs]
	if _cache.has(key):
		return _cache[key]
	var fine := _field(21, size, 0.22, 3)
	var mid := _field(22, size, 0.03, 4)
	var stain := _field(23, size, 0.012, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var rgb := PackedByteArray()
	rgb.resize(size * size * 3)
	var bump := PackedByteArray()
	bump.resize(size * size)
	var cell := size / slabs
	for y in size:
		for x in size:
			var i := y * size + x
			var v := tone * (0.88 + fine[i] / 255.0 * 0.18 + mid[i] / 255.0 * 0.18)
			var s: float = stain[i] / 255.0
			var tint := Vector3(1.0, 0.99, 0.96) * (1.0 - maxf(0.0, s - 0.55) * 0.6)
			rgb[i * 3] = clampi(int(v * 255.0 * tint.x), 0, 255)
			rgb[i * 3 + 1] = clampi(int(v * 255.0 * tint.y), 0, 255)
			rgb[i * 3 + 2] = clampi(int(v * 255.0 * tint.z), 0, 255)
			bump[i] = clampi(int(fine[i] * 0.8 + rng.randf() * 50.0), 0, 255)
	# деформационные швы
	for k in slabs:
		for t in size:
			for w in 3:
				_dim(rgb, size, k * cell + w, t, 0.45)
				_dim(rgb, size, t, k * cell + w, 0.45)
				bump[(t * size + posmod(k * cell + w, size))] = 20
				bump[(posmod(k * cell + w, size) * size + t)] = 20
	for k in 4:
		_crack(rgb, size, rng, 0.7)
	_cache[key] = _finish(size, rgb, bump, 1.1)
	return _cache[key]

static func grass(size: int = 256) -> Dictionary:
	if _cache.has("grass"):
		return _cache["grass"]
	var fine := _field(31, size, 0.5, 2)
	var mid := _field(32, size, 0.04, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var rgb := PackedByteArray()
	rgb.resize(size * size * 3)
	var bump := PackedByteArray()
	bump.resize(size * size)
	for y in size:
		for x in size:
			var i := y * size + x
			var m: float = mid[i] / 255.0
			var f: float = fine[i] / 255.0
			var base := Color("3f7a32").lerp(Color("7da13d"), m * 0.8)
			var k := 0.75 + f * 0.5
			rgb[i * 3] = clampi(int(base.r * 255.0 * k), 0, 255)
			rgb[i * 3 + 1] = clampi(int(base.g * 255.0 * k), 0, 255)
			rgb[i * 3 + 2] = clampi(int(base.b * 255.0 * k), 0, 255)
			bump[i] = int(f * 255.0)
	_cache["grass"] = _finish(size, rgb, bump, 2.0)
	return _cache["grass"]

# Универсальная ячеистая текстура для обшивки самолёта: серый «белый» с панелями, заклёпками, грязью.
static func fuselage() -> Dictionary:
	if _cache.has("fuselage"):
		return _cache["fuselage"]
	var w := 1024
	var h := 256
	var dirt := _noise(41, 0.02, 4).get_image(w, h)
	dirt.convert(Image.FORMAT_L8)
	var dd := dirt.get_data()
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var rgb := PackedByteArray()
	rgb.resize(w * h * 3)
	var bump := PackedByteArray()
	bump.resize(w * h)
	for y in h:
		for x in w:
			var i := y * w + x
			var d: float = dd[i] / 255.0
			var v := 0.97 - maxf(0.0, d - 0.5) * 0.18
			# грязная полоса вдоль низа
			var vv := float(y) / h
			var belly := smoothstep(0.34, 0.5, vv) * (1.0 - smoothstep(0.5, 0.66, vv))
			v -= belly * 0.14
			rgb[i * 3] = int(v * 255.0)
			rgb[i * 3 + 1] = int(v * 255.0)
			rgb[i * 3 + 2] = int(v * 252.0)
			bump[i] = 200
	# панели: продольные и поперечные швы
	for px in range(0, w, 64):
		for y in h:
			rgb[(y * w + px) * 3] = int(rgb[(y * w + px) * 3] * 0.72)
			rgb[(y * w + px) * 3 + 1] = int(rgb[(y * w + px) * 3 + 1] * 0.72)
			rgb[(y * w + px) * 3 + 2] = int(rgb[(y * w + px) * 3 + 2] * 0.72)
			bump[y * w + px] = 90
	for py in [26, 58, 90, 166, 198, 230]:
		for x in w:
			var i: int = (py * w + x) * 3
			rgb[i] = int(rgb[i] * 0.78)
			rgb[i + 1] = int(rgb[i + 1] * 0.78)
			rgb[i + 2] = int(rgb[i + 2] * 0.78)
			bump[py * w + x] = 100
	# заклёпки по швам
	for px in range(0, w, 64):
		for y in range(0, h, 6):
			var i := (y * w + px + 2) * 3
			if i + 2 < rgb.size():
				rgb[i] = int(rgb[i] * 0.85)
	# двери (контуры): две пары на борту
	for door in [Vector2(110, 62), Vector2(780, 62), Vector2(110, 168), Vector2(780, 168)]:
		for t in 22:
			for k in [0, 1]:
				_box_line(rgb, w, h, int(door.x) + t * 2, int(door.y), 0.45)
				_box_line(rgb, w, h, int(door.x) + t * 2, int(door.y) + 40, 0.45)
		for t in 40:
			_box_line(rgb, w, h, int(door.x), int(door.y) + t, 0.45)
			_box_line(rgb, w, h, int(door.x) + 44, int(door.y) + t, 0.45)
	# следы выхлопа за двигателями
	for streak in [Vector2(540, 40), Vector2(540, 216)]:
		for t in 120:
			for off in range(-3, 4):
				_box_line(rgb, w, h, int(streak.x) + t, int(streak.y) + off, 0.88)
	var albedo := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, rgb)
	albedo.generate_mipmaps()
	var b := Image.create_from_data(w, h, false, Image.FORMAT_L8, bump)
	b.bump_map_to_normal_map(2.0)
	b.generate_mipmaps()
	_cache["fuselage"] = {"albedo": ImageTexture.create_from_image(albedo), "normal": ImageTexture.create_from_image(b)}
	return _cache["fuselage"]

static func _box_line(rgb: PackedByteArray, w: int, h: int, x: int, y: int, k: float) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var i := (y * w + x) * 3
	rgb[i] = int(rgb[i] * k)
	rgb[i + 1] = int(rgb[i + 1] * k)
	rgb[i + 2] = int(rgb[i + 2] * k)

static func material(t: Dictionary, tile: Vector2, rough: float = 0.9, normal_strength: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t.albedo
	m.normal_enabled = true
	m.normal_texture = t.normal
	m.normal_scale = normal_strength
	m.uv1_scale = Vector3(tile.x, tile.y, 1.0)
	m.roughness = rough
	return m


# Гофрированный металл (ангары): вертикальные рёбра, карта нормалей.
static func corrugated(size: int = 128, col: Color = Color("aeb7c4")) -> Dictionary:
	var key := "corr_" + col.to_html()
	if _cache.has(key):
		return _cache[key]
	var fine := _field(51, size, 0.06, 3)
	var rgb := PackedByteArray()
	rgb.resize(size * size * 3)
	var bump := PackedByteArray()
	bump.resize(size * size)
	for y in size:
		for x in size:
			var i := y * size + x
			var rib: float = 0.5 + 0.5 * sin(float(x) / size * TAU * 8.0)
			var k: float = 0.78 + rib * 0.3 + (fine[i] / 255.0 - 0.5) * 0.12
			rgb[i * 3] = clampi(int(col.r * 255.0 * k), 0, 255)
			rgb[i * 3 + 1] = clampi(int(col.g * 255.0 * k), 0, 255)
			rgb[i * 3 + 2] = clampi(int(col.b * 255.0 * k), 0, 255)
			bump[i] = int(rib * 255.0)
	_cache[key] = _finish(size, rgb, bump, 2.5)
	return _cache[key]

# Фасад здания с окнами (отель, склад): тёмное стекло, сетка светлых перекрытий.
static func windows(size: int = 128, lit: float = 0.25) -> Dictionary:
	var key := "win_%d" % int(lit * 100)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var rgb := PackedByteArray()
	rgb.resize(size * size * 3)
	var bump := PackedByteArray()
	bump.resize(size * size)
	var cell := size / 8
	for y in size:
		for x in size:
			var i := y * size + x
			var cx := x % cell
			var cy := y % cell
			var frame: bool = cx < 2 or cy < 3
			var col := Color("c9ced6") if frame else Color("2c4666")
			if not frame:
				var wi := (x / cell) + (y / cell) * 8
				var r := RandomNumberGenerator.new()
				r.seed = wi * 31 + 5
				if r.randf() < lit:
					col = Color("e8d79a")
			rgb[i * 3] = int(col.r * 255.0)
			rgb[i * 3 + 1] = int(col.g * 255.0)
			rgb[i * 3 + 2] = int(col.b * 255.0)
			bump[i] = 255 if frame else 120
	_cache[key] = _finish(size, rgb, bump, 1.5)
	return _cache[key]

# Мягкое пятно (альфа): масляные пятна, следы шин, контактные тени.
static func blob(size: int = 128, seed_: int = 3, ragged: float = 0.35) -> ImageTexture:
	var key := "blob_%d_%d" % [seed_, int(ragged * 100)]
	if _cache.has(key):
		return _cache[key]
	var n := _noise(seed_, 0.045, 3)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size / 2.0, y - size / 2.0).length() / (size / 2.0)
			var v := n.get_noise_2d(x, y) * ragged
			var a := clampf(1.0 - (d + v), 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(0.03, 0.03, 0.035, a * 0.85))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
