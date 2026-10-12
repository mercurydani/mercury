class_name Assets
# Загрузка внешних моделей (CC0 / CC-BY, см. CREDITS.md) с подгонкой размера и ориентации.

const BAE := "res://assets/models/bae146/scene.gltf"
const POLY_A := "res://assets/models/poly/airplane_a.glb"
const POLY_B := "res://assets/models/poly/airplane_b.glb"
const WORKER := "res://assets/models/worker/Worker.fbx"
const TERMINAL := "res://assets/models/terminal/scene.gltf"
const KENNEY := "res://assets/models/kenney/%s.glb"

const FLEET := [BAE, POLY_A, POLY_B]
const LENGTHS := [8.7, 12.5, 14.8]       # реальные длины: 26 м, 37.6 м, 44.5 м (единица = 3 м)

static func load_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null

# Границы по локальным трансформам вершин (не зависят от того, в дереве ли узел).
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var xf: Transform3D = it[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var a: AABB = xf * (n as MeshInstance3D).mesh.get_aabb()
			box = a if first else box.merge(a)
			first = false
		for c in n.get_children():
			var cxf := xf
			if c is Node3D:
				cxf = xf * (c as Node3D).transform
			stack.append([c, cxf])
	return box

# Обернуть модель: центр по XZ в нуле, низ на y=0, масштаб k. Возвращает обёртку.
static func fit(model: Node3D, target_len: float, target_span: float = 0.0) -> Node3D:
	var b := bounds(model)
	var k := target_len / maxf(b.size.z, 0.0001)
	if target_span > 0.0:
		k = minf(k, target_span / maxf(b.size.x, 0.0001))
	var wrap := Node3D.new()
	wrap.add_child(model)
	model.scale = model.scale * k
	var c := b.get_center()
	model.position = Vector3(-c.x * k, -b.position.y * k, -c.z * k)
	return wrap

static func kenney(name: String, length: float = 1.5) -> Node3D:
	var m := load_scene(KENNEY % name)
	if m == null:
		return null
	return fit(m, length)

# Рабочий Quaternius с анимациями; vest/hat/skin — цвета.
static func worker(vest: Color, hat: Color, skin: Color, shirt: Color = Color(0, 0, 0, 0)) -> Node3D:
	var w := load_scene(WORKER)
	if w == null:
		return null
	w.scale = Vector3.ONE * (Cfg.PERSON * 0.95)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat is StandardMaterial3D:
				var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				match d.resource_name:
					"Worker_Vest": d.albedo_color = vest
					"Worker_Yellow": d.albedo_color = hat
					"Skin": d.albedo_color = skin
					"LightBrown":
						if shirt.a > 0.0:
							d.albedo_color = shirt
				m.set_surface_override_material(s, d)
	return w

# Делает материалы импортированных моделей менее «пластиковыми»: слегка металлик, умеренная шероховатость.
static func polish(root: Node, metallic: float, rough: float) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat is StandardMaterial3D:
				var d := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.metallic = metallic
				d.roughness = rough
				d.metallic_specular = 0.6
				m.set_surface_override_material(s, d)

static func play(model: Node, anim: String, speed: float = 1.0) -> AnimationPlayer:
	for ap in model.find_children("*", "AnimationPlayer", true, false):
		var p := ap as AnimationPlayer
		var full := "CharacterArmature|" + anim
		if p.has_animation(full):
			p.get_animation(full).loop_mode = Animation.LOOP_LINEAR
			p.play(full, 0.15, speed)
			return p
	return null
