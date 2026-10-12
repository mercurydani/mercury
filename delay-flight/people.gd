class_name People
# Карикатурные люди: большие головы, выразительные лица, форма одежды с деталями.
# Модель смотрит вдоль +Z, ноги на y=0. Узлы для анимации: LegL, LegR, Body/ArmL, Body/ArmR, Body/Head.

static var _outline: ShaderMaterial

static func outline_mat() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode cull_front, unshaded;\nuniform float grow = 0.011;\nvoid vertex() { VERTEX += NORMAL * grow; }\nvoid fragment() { ALBEDO = vec3(0.05, 0.04, 0.06); }\n"
		_outline = ShaderMaterial.new()
		_outline.shader = sh
	return _outline

static func _skin_mat(col: Color) -> StandardMaterial3D:
	var m := Rig.mat(col, 0.55)
	return m

static func _s(parent: Node3D, r: float, pos: Vector3, col: Color, sq: Vector3 = Vector3.ONE, emit: float = 0.0) -> MeshInstance3D:
	return Rig.sphere(parent, r, pos, col, sq, emit)

static func _c(parent: Node3D, r: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Rig.capsule(parent, r, h, pos, col, rot)

static func _b(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, emit: float = 0.0) -> MeshInstance3D:
	return Rig.box(parent, size, pos, col, rot, emit)

# ---------- готовые наряды ----------
static func crew_opts(i: int) -> Dictionary:
	match i % 4:
		0:   # Грузчик: каска, наушники, усы, щербатая улыбка
			return {"name": "Грузчик", "shirt": Color("3a4252"), "vest": Color("ff7a1a"), "hat": "helmet", "hat_col": Color("ffd24d"), "defenders": true,
				"skin": Color("e8b48a"), "mustache": Color("4a2f1a"), "buck_teeth": true, "grin": true, "belly": 0.35, "prop": "bag_tag", "hair": "comb", "hair_col": Color("4a2f1a")}
		1:   # Заправщик: кепка, огромный нос, жвачка
			return {"name": "Заправщик", "shirt": Color("e9edf2"), "vest": Color("c6e61a"), "hat": "cap", "hat_col": Color("f4f4f4"), "skin": Color("c98e65"),
				"nose": 1.9, "grin": true, "belly": 0.1, "prop": "nozzle", "stubble": true}
		2:   # Маршалер: ирокез, жезлы, ухмылка
			return {"name": "Маршалер", "shirt": Color("2b3345"), "vest": Color("ff4d2e"), "hat": "", "defenders": true, "skin": Color("f1c9a5"),
				"hair": "mohawk", "hair_col": Color("e63946"), "grin": true, "prop": "wands", "belly": 0.0}
		_:   # Механик: афро, очки на лбу, гаечный ключ
			return {"name": "Механик", "shirt": Color("3d7bd9"), "vest": Color(0, 0, 0, 0), "hat": "", "skin": Color("8d5a3c"),
				"hair": "afro", "hair_col": Color("1b1410"), "goggles": true, "grin": true, "prop": "wrench", "belly": 0.15, "mustache": Color("1b1410")}

static func npc_opts(type: String) -> Dictionary:
	match type:
		"pilot":   # Капитан: пузо, усы, фуражка, эполеты
			return {"s": 1.2, "shirt": Color("f4f6fa"), "pants": Color("1b2a52"), "hat": "pilot", "skin": Color("e0907a"), "tie": true, "belly": 0.7,
				"mustache": Color("2a2018"), "angry": true, "brow": true, "epaulettes": true, "buttons": true, "steam": true, "sweat": true, "prop": "coffee_empty"}
		"dispatcher":   # Диспетчер: выпученные глаза, гарнитура, вена на лбу
			return {"s": 1.15, "shirt": Color("9fc3ee"), "pants": Color("2b3345"), "headset": true, "skin": Color("e07a6a"), "tie": true, "belly": 0.2,
				"angry": true, "brow": true, "bulge_eyes": true, "vein": true, "steam": true, "sweat": true, "hair": "comb", "hair_col": Color("5a4a3a"), "prop": "megaphone", "buttons": true}
		"hooligan":   # Пилот-хулиган: набок кепка, очки, жвачка
			return {"s": 1.2, "shirt": Color("f4f6fa"), "pants": Color("1b2a52"), "vest": Color("ff8a3d"), "hat": "pilot_tilt", "shades": true, "skin": Color("e8a08a"),
				"angry": true, "grin_angry": true, "belly": 0.2, "steam": true, "epaulettes": true, "prop": "bottle"}
		_:   # КАЧОК: крошечная голова, огромный торс, шорты, усы
			return {"s": 2.6, "bulk": 1.75, "shirt": Color("d98c5f"), "tank": true, "pants": Color("e63946"), "shorts": true, "hat": "bandana", "skin": Color("d98c5f"),
				"arm": Color("d98c5f"), "head_scale": 0.62, "shades": true, "mustache": Color("1b1410"), "angry": true, "brow": true, "steam": true, "veins": true, "belly": 0.0, "grin_angry": true, "muscle": true}

# ---------- сборка ----------
static func person(o: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.scale = Vector3.ONE * float(o.get("s", 1.0))
	var bulk: float = o.get("bulk", 1.0)
	var belly: float = o.get("belly", 0.0)
	var skin: Color = o.get("skin", Color("e8b48a"))
	var shirt: Color = o.get("shirt", Color("3a4252"))
	var pants: Color = o.get("pants", Color("262d3d"))
	var arm_col: Color = o.get("arm", shirt)
	var shorts: bool = o.get("shorts", false)
	var boot_col := Color("2a1f18") if not o.has("pants") else Color("151a24")
	if o.get("muscle", false):
		boot_col = Color("f4f4f4")
	# --- ноги ---
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "LegL" if side < 0.0 else "LegR"
		leg.position = Vector3(0.115 * side * bulk, 0.55, 0)
		root.add_child(leg)
		if shorts:
			_c(leg, 0.1 * bulk, 0.34, Vector3(0, -0.12, 0), pants)
			_c(leg, 0.08 * bulk, 0.34, Vector3(0, -0.34, 0), skin)
		else:
			_c(leg, 0.095 * bulk, 0.6, Vector3(0, -0.27, 0), pants)
			_s(leg, 0.1 * bulk, Vector3(0, -0.46, 0.0), pants.darkened(0.15), Vector3(1.0, 0.45, 1.0))
		_s(leg, 0.115, Vector3(0, -0.53, 0.06), boot_col, Vector3(1.0, 0.62, 1.75))
		_b(leg, Vector3(0.2, 0.04, 0.4), Vector3(0, -0.57, 0.07), Color("0d0d10"))
	# --- корпус ---
	var body := Node3D.new()
	body.name = "Body"
	body.position = Vector3(0, 0.55, 0)
	root.add_child(body)
	var torso_col := shirt
	_c(body, 0.2 * bulk, 0.7, Vector3(0, 0.3, 0), torso_col, Vector3.ZERO).scale = Vector3(1.0, 1.0, 0.85)
	if belly > 0.0:
		_s(body, 0.22 + belly * 0.12, Vector3(0, 0.17, 0.08 + belly * 0.05), torso_col, Vector3(1.05, 0.95, 0.95))
	if o.get("tank", false):
		# майка + грудные мышцы
		for sx in [-1.0, 1.0]:
			_s(body, 0.17, Vector3(0.14 * sx * bulk, 0.42, 0.1), skin, Vector3(1.0, 0.85, 0.8))
		_c(body, 0.17 * bulk, 0.4, Vector3(0, 0.18, 0.0), Color("f4f4f4")).scale = Vector3(1.0, 1.0, 0.85)
	var vest: Color = o.get("vest", Color(0, 0, 0, 0))
	if vest.a > 0.0:
		_c(body, 0.215 * bulk, 0.58, Vector3(0, 0.27, 0.005), vest).scale = Vector3(1.0, 1.0, 0.9)
		for yy in [0.12, 0.34]:
			var ring := Rig.torus(body, 0.205 * bulk, 0.23 * bulk, Vector3(0, yy, 0), Color("e8eef5"), Vector3.ZERO, 0.45)
			ring.scale = Vector3(1.0, 1.0, 0.9)
		for sx in [-1.0, 1.0]:
			_b(body, Vector3(0.1, 0.1, 0.03), Vector3(0.1 * sx, 0.1, 0.2), vest.darkened(0.2))
	# ремень
	if not shorts:
		var belt := Rig.torus(body, 0.19 * bulk, 0.215 * bulk, Vector3(0, 0.0, 0.0), Color("1a1512"))
		belt.scale = Vector3(1.0, 1.0, 0.9 + belly * 0.2)
		_b(body, Vector3(0.07, 0.05, 0.03), Vector3(0, 0.0, 0.2 + belly * 0.1), Color("d8b24a"), Vector3.ZERO, 0.3)
	if o.get("buttons", false):
		for k in 5:
			_s(body, 0.016, Vector3(0, 0.08 + k * 0.1, 0.19 + belly * 0.07 - k * 0.012), Color("e0b84a"), Vector3.ONE, 0.5)
	if o.get("tie", false):
		_c(body, 0.032, 0.34, Vector3(0, 0.3, 0.2 + belly * 0.06), Color("c0392b")).scale = Vector3(1.0, 1.0, 0.4)
		_s(body, 0.035, Vector3(0, 0.5, 0.2), Color("c0392b"))
	if o.get("epaulettes", false):
		for sx in [-1.0, 1.0]:
			_b(body, Vector3(0.14, 0.03, 0.12), Vector3(0.2 * sx * bulk, 0.55, 0), Color("1b2a52"))
			_b(body, Vector3(0.14, 0.034, 0.025), Vector3(0.2 * sx * bulk, 0.55, 0.03), Color("e0b84a"), Vector3.ZERO, 0.4)
			_b(body, Vector3(0.14, 0.034, 0.025), Vector3(0.2 * sx * bulk, 0.55, -0.02), Color("e0b84a"), Vector3.ZERO, 0.4)
	# --- руки ---
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmL" if side < 0.0 else "ArmR"
		arm.position = Vector3(0.27 * side * bulk, 0.55, 0)
		body.add_child(arm)
		var sleeve := arm_col
		_s(arm, 0.095 * bulk, Vector3.ZERO, sleeve)
		_c(arm, 0.065 * bulk, 0.32, Vector3(0, -0.14, 0), sleeve)
		if o.get("muscle", false):
			_s(arm, 0.14 * bulk, Vector3(0.0, -0.1, 0.03), skin, Vector3(1.0, 1.1, 1.0))
		_c(arm, 0.056 * bulk, 0.3, Vector3(0, -0.38, 0.02), skin if (o.get("muscle", false) or o.get("shorts", false)) else sleeve)
		_s(arm, 0.075, Vector3(0, -0.56, 0.03), skin, Vector3(1.0, 1.05, 1.0))
		_s(arm, 0.035, Vector3(0.05 * side * -1.0, -0.54, 0.07), skin)
		_b(arm, Vector3(0.14 * bulk, 0.04, 0.12 * bulk), Vector3(0, -0.5, 0.01), sleeve.darkened(0.2))
		if side > 0.0:
			_prop(arm, o.get("prop", ""), Vector3(0, -0.56, 0.05))
	# --- шея и голова ---
	_c(body, 0.07, 0.15, Vector3(0, 0.67, 0), skin)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.74, 0)
	var hs: float = o.get("head_scale", 1.0)
	head.scale = Vector3.ONE * hs * 1.12
	body.add_child(head)
	_head(head, o, skin)
	# --- контур ---
	_outline_all(root)
	return root

static func _head(h: Node3D, o: Dictionary, skin: Color) -> void:
	var angry: bool = o.get("angry", false)
	_s(h, 0.23, Vector3(0, 0.2, 0), skin, Vector3(1.0, 1.05, 1.0))
	_s(h, 0.15, Vector3(0, 0.07, 0.07), skin, Vector3(1.1, 0.9, 1.0))
	for sx in [-1.0, 1.0]:
		_s(h, 0.075, Vector3(0.13 * sx, 0.12, 0.15), skin.lerp(Color("e07a7a"), 0.25), Vector3(1.0, 0.9, 0.8))
		_s(h, 0.065, Vector3(0.235 * sx, 0.2, 0.0), skin, Vector3(0.45, 1.0, 0.85))
		_s(h, 0.04, Vector3(0.24 * sx, 0.2, 0.01), skin.darkened(0.15), Vector3(0.3, 0.8, 0.7))
	var nose_k: float = o.get("nose", 1.0)
	_s(h, 0.055 * nose_k, Vector3(0, 0.15, 0.23 + 0.04 * nose_k), skin.lerp(Color("e07a7a"), 0.2), Vector3(1.0, 0.9, 1.3))
	# глаза
	var eye_r := 0.075 if o.get("bulge_eyes", false) else 0.062
	for sx in [-1.0, 1.0]:
		if o.get("shades", false):
			_s(h, 0.085, Vector3(0.085 * sx, 0.24, 0.185), Color("0b0b0b"), Vector3(1.15, 0.85, 0.5), 0.0)
			_s(h, 0.03, Vector3(0.1 * sx, 0.26, 0.225), Color("6fb4ff"), Vector3(1.0, 0.5, 0.3), 1.2)
		else:
			_s(h, eye_r, Vector3(0.088 * sx, 0.24, 0.185), Color("ffffff"), Vector3(1.0, 1.15, 0.6))
			_s(h, eye_r * 0.42, Vector3(0.088 * sx - 0.005 * sx, 0.24, 0.185 + eye_r * 0.5), Color("1b1b1b"), Vector3.ONE)
			_s(h, eye_r * 0.14, Vector3(0.088 * sx + 0.012, 0.255, 0.185 + eye_r * 0.7), Color("ffffff"), Vector3.ONE, 1.0)
			if angry:
				for k in 3:
					_b(h, Vector3(0.004, 0.012, 0.004), Vector3(0.088 * sx + (k - 1) * 0.03, 0.235, 0.214), Color("d03030"))
		if o.get("brow", false) or angry:
			_c(h, 0.017, 0.12, Vector3(0.09 * sx, 0.32, 0.19), Color("2a2018"), Vector3(0, 0, 62 * sx))
		else:
			_c(h, 0.012, 0.1, Vector3(0.09 * sx, 0.325, 0.19), Color("3a2a1a"), Vector3(0, 0, 8 * sx))
	if o.get("vein", false):
		_c(h, 0.01, 0.1, Vector3(0.0, 0.38, 0.17), Color("c04040"), Vector3(0, 0, 25))
		_c(h, 0.008, 0.07, Vector3(0.04, 0.35, 0.18), Color("c04040"), Vector3(0, 0, -30))
	# рот
	if angry:
		_s(h, 0.08, Vector3(0, 0.055, 0.205), Color("3a0f10"), Vector3(1.3, 0.95, 0.5))
		_b(h, Vector3(0.12, 0.028, 0.02), Vector3(0, 0.095, 0.232), Color("f6f6f0"))
		_b(h, Vector3(0.1, 0.022, 0.02), Vector3(0, 0.02, 0.228), Color("f6f6f0"))
		_s(h, 0.04, Vector3(0, 0.03, 0.222), Color("d85a6a"), Vector3(1.3, 0.5, 0.4))
	elif o.get("grin", false):
		_s(h, 0.085, Vector3(0, 0.07, 0.2), Color("3a0f10"), Vector3(1.4, 0.65, 0.45))
		_b(h, Vector3(0.14, 0.03, 0.02), Vector3(0, 0.095, 0.226), Color("f6f6f0"))
		if o.get("buck_teeth", false):
			for sx in [-1.0, 1.0]:
				_b(h, Vector3(0.04, 0.06, 0.02), Vector3(0.022 * sx, 0.055, 0.238), Color("f6f6f0"))
		for sx in [-1.0, 1.0]:
			_c(h, 0.012, 0.05, Vector3(0.1 * sx, 0.085, 0.2), skin.darkened(0.3), Vector3(0, 0, 30 * sx))
	else:
		_c(h, 0.011, 0.11, Vector3(0, 0.07, 0.225), Color("5a1f1f"), Vector3(0, 0, 90))
	if o.get("grin_angry", false) and not angry:
		pass
	var mus: Color = o.get("mustache", Color(0, 0, 0, 0))
	if mus.a > 0.0:
		for sx in [-1.0, 1.0]:
			_c(h, 0.028, 0.16, Vector3(0.07 * sx, 0.12, 0.235), mus, Vector3(0, 0, 90 + 22 * sx))
			_s(h, 0.03, Vector3(0.15 * sx, 0.105, 0.215), mus, Vector3(1.0, 1.4, 0.8))
	if o.get("stubble", false):
		_s(h, 0.152, Vector3(0, 0.065, 0.075), Color("5a4a3a", 0.35), Vector3(1.12, 0.9, 1.02))
	# волосы
	var hair: String = o.get("hair", "")
	var hc: Color = o.get("hair_col", Color("3a2a1a"))
	match hair:
		"comb":
			_s(h, 0.235, Vector3(0, 0.26, -0.03), hc, Vector3(1.0, 0.7, 1.0))
			_c(h, 0.016, 0.3, Vector3(0, 0.395, 0.02), hc, Vector3(0, 0, 90))
		"afro":
			_s(h, 0.34, Vector3(0, 0.34, -0.03), hc, Vector3(1.0, 0.95, 1.0))
		"mohawk":
			for k in 9:
				var a := -0.9 + k * 0.22
				_s(h, 0.07 + 0.012 * sin(k * 0.8), Vector3(0, 0.38 + cos(a * 1.4) * 0.07, a * 0.2), hc, Vector3(0.45, 1.4, 1.0))
	# головные уборы
	var hat: String = o.get("hat", "")
	var hat_col: Color = o.get("hat_col", Color.WHITE)
	var top := 0.35
	match hat:
		"helmet":
			Rig.hemi(h, 0.25, Vector3(0, top - 0.04, 0), hat_col)
			Rig.cyl(h, 0.27, 0.27, 0.03, Vector3(0, top - 0.04, 0), hat_col.darkened(0.18))
			_s(h, 0.14, Vector3(0, top, 0.14), hat_col, Vector3(1.0, 0.14, 0.95))
			_b(h, Vector3(0.03, 0.04, 0.3), Vector3(0, top + 0.12, 0), hat_col.darkened(0.12))
		"cap":
			Rig.hemi(h, 0.235, Vector3(0, top - 0.03, 0), hat_col)
			_s(h, 0.14, Vector3(0, top - 0.02, 0.2), hat_col.darkened(0.22), Vector3(1.05, 0.13, 0.95))
			_s(h, 0.025, Vector3(0, top + 0.18, 0), hat_col.darkened(0.3))
		"pilot", "pilot_tilt":
			var tilt := Node3D.new()
			h.add_child(tilt)
			tilt.position = Vector3(0, top - 0.02, 0)
			if hat == "pilot_tilt":
				tilt.rotation_degrees = Vector3(0, 0, -16)
			Rig.hemi(tilt, 0.255, Vector3(0, 0.0, 0), Color("1b2a52"))
			Rig.cyl(tilt, 0.26, 0.26, 0.05, Vector3(0, 0.0, 0), Color("162040"))
			_s(tilt, 0.15, Vector3(0, 0.0, 0.18), Color("0d1226"), Vector3(1.05, 0.13, 0.95))
			Rig.cyl(tilt, 0.262, 0.262, 0.035, Vector3(0, 0.05, 0), Color("e0b84a"), Vector3.ZERO, 0.4)
			_s(tilt, 0.04, Vector3(0, 0.06, 0.26), Color("f0d060"), Vector3(1.0, 1.0, 0.4), 0.6)
		"bandana":
			Rig.hemi(h, 0.235, Vector3(0, top - 0.06, 0), Color("c0392b"))
			for sx in [-1.0, 1.0]:
				_s(h, 0.05, Vector3(0.2 * sx, top - 0.08, -0.17), Color("c0392b"), Vector3(1.0, 0.5, 1.8))
	if o.get("defenders", false):
		for sx in [-1.0, 1.0]:
			_s(h, 0.1, Vector3(0.245 * sx, 0.2, 0.0), Color("e04b2f"), Vector3(0.7, 1.0, 1.0))
		Rig.torus(h, 0.225, 0.245, Vector3(0, 0.2, 0), Color("333333"), Vector3(0, 0, 90))
	if o.get("goggles", false):
		for sx in [-1.0, 1.0]:
			Rig.cyl(h, 0.07, 0.07, 0.05, Vector3(0.09 * sx, 0.42, 0.14), Color("2b3345"), Vector3(70, 0, 0))
			Rig.cyl(h, 0.055, 0.055, 0.052, Vector3(0.09 * sx, 0.42, 0.143), Color(0.6, 0.85, 1.0, 0.9), Vector3(70, 0, 0), 0.8)
		Rig.torus(h, 0.225, 0.24, Vector3(0, 0.38, 0), Color("2b3345"), Vector3(90, 0, 0)).scale = Vector3(1.0, 1.0, 0.3)
	if o.get("headset", false):
		_s(h, 0.075, Vector3(-0.26, 0.2, 0), Color("111111"), Vector3(0.6, 1.0, 1.0))
		_s(h, 0.075, Vector3(0.26, 0.2, 0), Color("111111"), Vector3(0.6, 1.0, 1.0))
		Rig.torus(h, 0.24, 0.255, Vector3(0, 0.2, 0), Color("111111"), Vector3(0, 0, 90))
		_c(h, 0.01, 0.2, Vector3(-0.22, 0.1, 0.13), Color("111111"), Vector3(75, 0, -20))
		_s(h, 0.03, Vector3(-0.16, 0.05, 0.22), Color("111111"))
	if o.get("sweat", false):
		for k in 2:
			var d := Node3D.new()
			d.position = Vector3(0.2 - k * 0.04, 0.3 + k * 0.05, 0.12)
			h.add_child(d)
			_s(d, 0.025, Vector3.ZERO, Color(0.6, 0.85, 1.0, 0.9), Vector3(0.8, 1.2, 0.8), 0.5)
			_c(d, 0.006, 0.05, Vector3(0, 0.035, 0), Color(0.6, 0.85, 1.0, 0.9))
	if o.get("steam", false):
		for sx in [-1.0, 1.0]:
			var p := CPUParticles3D.new()
			p.position = Vector3(0.27 * sx, 0.22, 0.0)
			p.amount = 10
			p.lifetime = 0.9
			p.direction = Vector3(0.3 * sx, 1.0, 0.0)
			p.spread = 20.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 0.9
			p.gravity = Vector3(0, 0.3, 0)
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.5
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			sm.radial_segments = 8
			sm.rings = 4
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1, 1, 1, 0.55)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.material = m
			p.mesh = sm
			h.add_child(p)

# ---------- предметы в руке ----------
static func _prop(arm: Node3D, kind: String, at: Vector3) -> void:
	var p := Node3D.new()
	p.position = at
	arm.add_child(p)
	match kind:
		"wands":
			for sx in [-1.0, 1.0]:
				_c(p, 0.022, 0.5, Vector3(0.0, 0.0, 0.25), Color("ff7a1a"), Vector3(90, 0, 0)).material_override.emission_enabled = true
			Rig.cyl(p, 0.035, 0.035, 0.18, Vector3(0, 0, 0), Color("333b4a"), Vector3(90, 0, 0))
		"wrench":
			_b(p, Vector3(0.05, 0.5, 0.025), Vector3(0, 0.12, 0.05), Color("aab4c3"))
			Rig.torus(p, 0.035, 0.07, Vector3(0, 0.4, 0.05), Color("aab4c3"), Vector3(90, 0, 0)).scale = Vector3(1.0, 1.0, 0.4)
		"nozzle":
			_c(p, 0.03, 0.34, Vector3(0, 0.0, 0.18), Color("e63946"), Vector3(80, 0, 0))
			_c(p, 0.012, 0.9, Vector3(0, -0.4, 0.2), Color("333b4a"))
		"megaphone":
			Rig.cyl(p, 0.14, 0.05, 0.3, Vector3(0, 0.02, 0.18), Color("f0f0f0"), Vector3(90, 0, 0))
			Rig.cyl(p, 0.06, 0.06, 0.16, Vector3(0, -0.04, 0.0), Color("333b4a"))
		"coffee_empty":
			Rig.cyl(p, 0.06, 0.045, 0.14, Vector3(0, 0.0, 0.06), Color("f4f4f4"))
		"bottle":
			_c(p, 0.04, 0.22, Vector3(0, 0.05, 0.05), Color("2a9d5c"))
			_c(p, 0.015, 0.1, Vector3(0, 0.2, 0.05), Color("2a9d5c"))
		"bag_tag":
			_b(p, Vector3(0.1, 0.14, 0.01), Vector3(0, -0.1, 0.08), Color("f4f4f4"))

static func _outline_all(n: Node) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c.material_override != null and c.mesh is not TorusMesh:
			var m: Material = c.material_override
			if m is StandardMaterial3D and m.albedo_color.a >= 0.99 and not m.emission_enabled:
				m.next_pass = outline_mat()
		_outline_all(c)

# ---------- анимация ----------
static func animate(rig: Node3D, t: float, moving: bool, mood: String = "") -> void:
	var swing := sin(t) * 0.85 if moving else 0.0
	rig.get_node("LegL").rotation.x = swing
	rig.get_node("LegR").rotation.x = -swing
	var body: Node3D = rig.get_node("Body")
	var head: Node3D = body.get_node("Head")
	var al: Node3D = body.get_node("ArmL")
	var ar: Node3D = body.get_node("ArmR")
	var now := Time.get_ticks_msec() / 1000.0
	if mood == "angry":
		# топает и трясёт кулаками
		var fury := sin(now * 18.0) * 0.22
		al.rotation = Vector3(-2.2 + fury, 0, 0.35)
		ar.rotation = Vector3(-2.2 - fury, 0, -0.35)
		body.rotation.z = sin(t * 0.5) * 0.12 if moving else sin(now * 14.0) * 0.03
		body.position.y = 0.55 + absf(sin(t)) * 0.05 if moving else 0.55
		head.rotation = Vector3(0.1 + sin(now * 20.0) * 0.05, sin(now * 9.0) * 0.12, sin(now * 16.0) * 0.06)
		return
	al.rotation = Vector3(-swing, 0, 0.05)
	ar.rotation = Vector3(swing, 0, -0.05)
	body.rotation.z = sin(t * 0.5) * 0.1 if moving else 0.0
	body.position.y = 0.55 + absf(sin(t)) * 0.035 if moving else 0.55 + sin(now * 2.0) * 0.006
	head.rotation = Vector3(0.0, 0.0, -sin(t * 0.5) * 0.07 if moving else sin(now * 1.3) * 0.03)
