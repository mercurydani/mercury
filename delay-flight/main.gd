extends Node3D
# ЗАДЕРЖКА РЕЙСА — игровая логика смены.

const LINES := {
	"pilot": ["Где мой кофе?!", "Я опаздываю в Сочи!", "Вы вообще работаете?!"],
	"dispatcher": ["ЧТО ЗА БАРДАК?!", "РЕЙС ЗАДЕРЖАН!!!", "Я ВСЁ ВИЖУ!"],
	"hooligan": ["Я САМ ПОЕДУ!", "Дай руль!", "Прочь с дороги!"],
	"muscle": ["ВЫ ЗАДЕРЖАЛИ МОЙ РЕЙС!"],
}
const LIVERIES := [Color("e63946"), Color("2a9d8f"), Color("f4a261"), Color("6c5ce7"), Color("00a8e8")]
const FLIGHTS := ["SU 214", "S7 905", "U6 331", "DP 404", "FV 77", "N4 612"]

var mode := "menu"   # menu | play | end
var world: Node3D
var camera: Camera3D
var airport: Airport
var plane_layer: Node3D
var npc_layer: Node3D
var worker_layer: Node3D
var bag_layer: Node3D
var menu_stage: Node3D
var menu_rigs: Array[Node3D] = []
var overlay: Overlay
var hud: Hud

var workers: Array[Worker] = []
var planes: Array = [null, null, null]
var npcs: Array[Angry] = []
var bags: Array[Vector2] = []
var texts: Array = []
var feed: Array = []          # лента событий: {text, color, tag, t}

var anger := 0.0
var time_left := Cfg.SHIFT
var elapsed := 0.0
var score := 0
var departed := 0
var calmed := 0
var bag_t := 0.0
var plane_t := 1.0
var npc_t := 8.0
var shake := 0.0
var banner_text := ""
var banner_t := 0.0
var reason := ""

func _ready() -> void:
	randomize()
	world = Node3D.new()
	add_child(world)
	_setup_environment()
	airport = Airport.new()
	airport.game = self
	world.add_child(airport)
	plane_layer = Node3D.new()
	world.add_child(plane_layer)
	npc_layer = Node3D.new()
	world.add_child(npc_layer)
	worker_layer = Node3D.new()
	world.add_child(worker_layer)
	bag_layer = Node3D.new()
	world.add_child(bag_layer)
	_build_menu_stage()
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Overlay.new()
	overlay.game = self
	layer.add_child(overlay)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)

func _setup_environment() -> void:
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 3500.0
	camera.near = 0.12
	camera.position = Vector3(34.0, 0.75, 5.8)
	add_child(camera)
	camera.look_at(Vector3(31.4, 0.5, 11.5), Vector3.UP)
	# низкое солнце: длинные мягкие тени, тёплый свет
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, 38, 0)
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = true
	sun.light_angular_distance = 0.6
	add_child(sun)
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky_clouds.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_sky_contribution = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.82
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.95
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.9)
	env.fog_density = 0.0007
	env.fog_sun_scatter = 0.12
	env.fog_aerial_perspective = 0.55
	# дополнительные эффекты работают в Forward+/Mobile (запуск: godot --rendering-method forward_plus)
	if RenderingServer.get_rendering_device() != null:
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 2.0
		env.ssil_enabled = true
		env.ssr_enabled = true
		env.ssr_max_steps = 64
		get_viewport().use_taa = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_menu_stage() -> void:
	menu_stage = Node3D.new()
	world.add_child(menu_stage)
	var vests := [Color("ff7a1a"), Color("d7ef2a"), Color("ff4d2e"), Color("4da3ff")]
	var hats := [Color("ffd24d"), Color("f4f4f4"), Color("f4f4f4"), Color("2b6fd6")]
	var skins := [Color("e8b48a"), Color("c98e65"), Color("f1c9a5"), Color("8d5a3c")]
	var anims := ["Walk", "Wave", "Interact", "Idle"]
	for i in 4:
		var rig: Node3D = Assets.worker(vests[i], hats[i], skins[i])
		if rig != null:
			var holder := Node3D.new()
			holder.add_child(rig)
			holder.scale = Vector3.ONE * 1.1
			Assets.play(rig, anims[i])
			rig = holder
		else:
			var o := People.crew_opts(i)
			o["s"] = 1.15 * Cfg.PERSON
			rig = People.person(o)
		rig.position = Cfg.to3(menu_spot(i))
		menu_stage.add_child(rig)
		menu_rigs.append(rig)

func menu_spot(i: int) -> Vector2:
	return Vector2(550.0, 1660.0 - i * 65.0)

func to_screen(p: Vector2, h: float = 0.0) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var p3 := Cfg.to3(p, h)
	if cam == null or cam.is_position_behind(p3):
		return Vector2(-9999, -9999)
	return cam.unproject_position(p3)

# Выталкивает круг (радиус r px) из непроходимых прямоугольников: терминал, техника, киоски, припаркованные самолёты.
func resolve_px(p: Vector2, r: float) -> Vector2:
	for pass_i in 2:
		for rc: Rect2 in airport.solids_px:
			p = _push(p, r, rc)
		for pl in planes:
			if pl != null and pl.state == "ready":
				for rc: Rect2 in plane_rects(pl):
					p = _push(p, r, rc)
	return p

func plane_rects(pl: Aircraft) -> Array:
	var len_px: float = (Assets.LENGTHS[pl.model_idx] if pl.model_idx >= 0 else 12.0) / Cfg.K
	var span_px := len_px * 0.95
	return [
		Rect2(pl.pos.x - len_px * 0.5, pl.pos.y - 0.34 / Cfg.K, len_px, 0.68 / Cfg.K),
		Rect2(pl.pos.x - len_px * 0.12, pl.pos.y - span_px * 0.48, len_px * 0.34, span_px * 0.96),
	]

func _push(p: Vector2, r: float, rc: Rect2) -> Vector2:
	var q := Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y))
	var d := p - q
	if d == Vector2.ZERO:
		var l := p.x - rc.position.x
		var rr := rc.end.x - p.x
		var t := p.y - rc.position.y
		var b := rc.end.y - p.y
		var mn := minf(minf(l, rr), minf(t, b))
		if mn == l:
			return Vector2(rc.position.x - r, p.y)
		if mn == rr:
			return Vector2(rc.end.x + r, p.y)
		if mn == t:
			return Vector2(p.x, rc.position.y - r)
		return Vector2(p.x, rc.end.y + r)
	if d.length() < r:
		return q + d.normalized() * r
	return p

# Подсказка у прицела: что можно сделать прямо сейчас.
func hint_for(w: Worker) -> String:
	if w.stun > 0.0:
		return ""
	if w.item == "bag":
		for pl in planes:
			if pl != null and pl.state == "ready" and pl.bags < pl.need and w.pos.distance_to(pl.door_pt()) < 90.0:
				return "[Пробел] сдать чемодан"
		return "[Пробел] бросить чемодан"
	if w.item != "":
		for n in npcs:
			if n.pos.distance_to(w.pos) < 110.0:
				return "[Пробел] успокоить: %s" % ("бургер" if w.item == "burger" else "кофе")
		return "[Пробел] бросить"
	for pl in planes:
		if pl != null and pl.state == "ready" and pl.fuel < 100.0 and w.pos.distance_to(pl.fuel_pt()) < 85.0:
			return "Держи [Пробел] — заправка"
	for b in bags:
		if b.distance_to(w.pos) < 60.0:
			return "[Пробел] взять чемодан"
	if w.pos.distance_to(Cfg.COFFEE) < 90.0:
		return "[Пробел] взять кофе"
	if w.pos.distance_to(Cfg.BURGER) < 90.0:
		return "[Пробел] взять бургер"
	return ""

# ---------- ввод ----------
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mode == "play" and not workers.is_empty():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var w: Worker = workers[0]
			w.yaw -= event.relative.x * 0.0025
			w.pitch = clampf(w.pitch - event.relative.y * 0.0025, -1.35, 1.35)
	elif event is InputEventMouseButton and event.pressed and mode == "play":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		match mode:
			"menu":
				if event.physical_keycode in [KEY_1, KEY_ENTER, KEY_SPACE]:
					start_game(1)
			"end":
				if event.physical_keycode == KEY_R:
					mode = "menu"
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			"play":
				for w in workers:
					if w.idx < 2 and Worker.KEYS[w.idx].act == event.physical_keycode:
						w.pressed = true
	elif event is InputEventJoypadButton and event.pressed and mode == "play" and event.button_index == JOY_BUTTON_A:
		for w in workers:
			if w.joy_device() == event.device:
				w.pressed = true

func start_game(n: int) -> void:
	for c in [plane_layer, npc_layer, worker_layer, bag_layer]:
		for ch in c.get_children():
			ch.queue_free()
	workers.clear()
	npcs.clear()
	bags.clear()
	texts.clear()
	feed.clear()
	planes = [null, null, null]
	anger = 0.0
	time_left = Cfg.SHIFT
	elapsed = 0.0
	score = 0
	departed = 0
	calmed = 0
	bag_t = 0.0
	plane_t = 1.0
	npc_t = 8.0
	shake = 0.0
	banner_t = 0.0
	var w := Worker.new()
	w.setup(0)
	w.fp = true
	w.yaw = PI
	w.pos = Vector2(140, 780)
	worker_layer.add_child(w)
	workers.append(w)
	mode = "play"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# Важные события — в ленту; мелочи («+10», «Не то!») — маленькие всплывашки рядом с источником.
func ft(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 22) -> void:
	if size >= 26:
		push_feed(text, color)
	else:
		texts.append({"pos": pos, "text": text, "color": color, "size": size, "t": 1.4})

func push_feed(text: String, color: Color = Color.WHITE, tag: String = "") -> void:
	feed.push_front({"text": text, "color": color, "tag": tag, "t": 7.0})
	if feed.size() > 6:
		feed.pop_back()

const SPEAKERS := {"pilot": "Капитан", "dispatcher": "Диспетчер", "hooligan": "Пилот-хулиган", "muscle": "КАЧОК"}

func show_banner(text: String) -> void:
	banner_text = text
	banner_t = 2.4

# ---------- самолёты ----------
func spawn_plane() -> void:
	var free: Array[int] = []
	for i in planes.size():
		if planes[i] == null:
			free.append(i)
	if free.is_empty():
		return
	var row: int = free.pick_random()
	var pl := Aircraft.new()
	pl.row = row
	pl.pos = Vector2(Cfg.TAXI_X, Cfg.SPAWN_Y)
	pl.max_pat = maxf(28.0, 46.0 - elapsed / 8.0)
	pl.pat = pl.max_pat
	pl.need = 4 if elapsed > 80.0 else 3
	pl.livery = LIVERIES.pick_random()
	pl.model_idx = randi() % Assets.FLEET.size()
	pl.flight = _free_flight()
	plane_layer.add_child(pl)
	planes[row] = pl

func _free_flight() -> String:
	var used: Array = []
	for p in planes:
		if p != null:
			used.append(p.flight)
	var pool: Array = FLIGHTS.filter(func(f): return not used.has(f))
	return pool.pick_random() if not pool.is_empty() else FLIGHTS.pick_random()

func update_plane(pl: Aircraft, dt: float, idx: int) -> void:
	match pl.state:
		"arriving":
			var lane := Vector2(Cfg.TAXI_X, Cfg.ROWS[pl.row])
			if pl.phase == 0:
				pl.pos = pl.pos.move_toward(lane, 1500.0 * dt)
				if pl.pos.distance_to(lane) < 2.0:
					pl.phase = 1
			else:
				var stand := Vector2(Cfg.PX, Cfg.ROWS[pl.row])
				var d := pl.pos.distance_to(stand)
				pl.pos = pl.pos.move_toward(stand, clampf(d * 0.9 + 60.0, 60.0, 700.0) * dt)
				if d < 2.0:
					pl.pos = stand
					pl.state = "ready"
		"ready":
			pl.pat -= dt
			if pl.pat <= 0.0 and not pl.delayed:
				pl.delayed = true
				anger += 12.0
				push_feed("Рейс %s задержан!" % pl.flight, Color("ff6b5e"), "ДИСПЕТЧЕРСКАЯ")
				show_banner("Рейс %s задержан. Пассажиры недовольны." % pl.flight)
			if pl.bags >= pl.need and pl.fuel >= 100.0:
				pl.state = "leaving"
				var pts := 30 if pl.delayed else 100 + roundi(pl.pat)
				score += pts
				departed += 1
				push_feed("Рейс %s вылетел  +%d" % [pl.flight, pts], Color("5ee0c4"), "ВЫЛЕТ")
		"leaving":
			var back := Vector2(Cfg.TAXI_X - 30.0, Cfg.ROWS[pl.row])
			if pl.phase == 0:
				pl.reverse = true
				pl.pos = pl.pos.move_toward(back, 450.0 * dt)
				if pl.pos.distance_to(back) < 2.0:
					pl.phase = 1
			else:
				pl.reverse = false
				pl.pos = pl.pos.move_toward(Vector2(back.x, Cfg.SPAWN_Y), 1500.0 * dt)
				if pl.pos.y >= Cfg.SPAWN_Y - 2.0:
					planes[idx] = null
					pl.queue_free()

# ---------- злые сотрудники ----------
func spawn_npc(type: String) -> void:
	var n := Angry.new()
	n.type = type
	n.cd = 1.5
	n.shout = randf_range(2.0, 4.0)
	n.pos = Vector2(randf_range(250, 1500), randf_range(2400.0, 2850.0))
	if type == "dispatcher":
		n.pos = Vector2(115, randf_range(300, 2800))
	npc_layer.add_child(n)
	npcs.append(n)
	push_feed(LINES[type].pick_random(), Color("ff8a80"), SPEAKERS[type])
	if type == "muscle":
		show_banner("Внимание! Сотрудник службы безопасности в ярости. Спрячьте багаж.")
		shake = 14.0

func nearest_worker(p: Vector2) -> Worker:
	var best: Worker = null
	var bd := 1e9
	for w in workers:
		var d := p.distance_to(w.pos)
		if d < bd:
			bd = d
			best = w
	return best

func hit_worker(w: Worker, from: Vector2, force: float, stun: float) -> void:
	var dir := (w.pos - from).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	w.knock += dir * force
	w.stun = maxf(w.stun, stun)
	if w.item == "bag":
		bags.append(w.pos)
	w.item = ""

func update_npc(n: Angry, dt: float) -> void:
	n.cd -= dt
	n.moving = false
	if n.type == "dispatcher":
		n.shout -= dt
		if n.shout <= 0.0:
			n.shout = 6.0
			shake = maxf(shake, 9.0)
			push_feed(LINES.dispatcher.pick_random(), Color("ff8a80"), SPEAKERS["dispatcher"])
			var live: Array = planes.filter(func(p): return p != null and p.state == "ready")
			if not live.is_empty():
				var pl: Aircraft = live.pick_random()
				pl.bags = maxi(0, pl.bags - 1)
				pl.fuel = maxf(0.0, pl.fuel - 20.0)
				ft(pl.pos, "Чемодан потерян!", Color("ffd24d"))
		return
	var t := nearest_worker(n.pos)
	if t == null:
		return
	var d := n.pos.distance_to(t.pos)
	var speed: float = {"pilot": 80.0, "hooligan": 150.0, "muscle": 95.0}[n.type]
	if n.type == "muscle":
		if n.wind > 0.0:
			n.wind -= dt
			if n.wind <= 0.0:
				shake = 26.0
				for w in workers:
					if n.pos.distance_to(w.pos) < 190.0:
						hit_worker(w, n.pos, 1700.0, 1.6)
						push_feed("БАБАХ! Тебя отправили в полёт", Color("ff6b5e"), "КАЧОК")
				var near: Array = planes.filter(func(p): return p != null)
				near.sort_custom(func(a, b): return n.pos.distance_to(a.pos) < n.pos.distance_to(b.pos))
				if not near.is_empty() and near[0].state == "ready":
					near[0].bags = maxi(0, near[0].bags - 1)
				n.cd = 2.6
			return
		if d < 150.0 and n.cd <= 0.0:
			n.wind = 0.9
			return
	elif d < 36.0 and n.cd <= 0.0:
		hit_worker(t, n.pos, 640.0 if n.type == "hooligan" else 300.0, 1.0)
		n.cd = 2.0
		ft(t.pos + Vector2(0, -50), "ОЙ!" if n.type == "hooligan" else "эй!", Color("ffd24d"))
	if d > 4.0:
		var dir := (t.pos - n.pos) / d
		n.pos += dir * speed * dt
		n.pos = resolve_px(n.pos, 30.0 if n.type == "muscle" else 16.0)
		n.moving = true
		n.dir = dir

func try_calm(w: Worker) -> bool:
	var best: Angry = null
	var bd := 110.0
	for n in npcs:
		var d := n.pos.distance_to(w.pos)
		if d < bd:
			bd = d
			best = n
	if best == null:
		return false
	var ok := true
	match best.type:
		"muscle": ok = w.item == "burger"
		"hooligan": ok = true
		_: ok = w.item == "coffee"
	if not ok:
		ft(w.pos + Vector2(0, -60), "Не то!", Color("ff8a80"))
		return true
	npcs.erase(best)
	best.queue_free()
	w.item = ""
	calmed += 1
	var muscle := best.type == "muscle"
	score += 150 if muscle else 25
	anger = maxf(0.0, anger - (15.0 if muscle else 5.0))
	push_feed("Он ушёл сам!  +150" if muscle else "Успокоен: %s  +25" % SPEAKERS[best.type], Color("5ee0c4"), "ПЕРРОН")
	return true

# ---------- игроки ----------
func update_worker(w: Worker, dt: float) -> void:
	w.pos += w.knock * dt
	w.knock *= exp(-4.5 * dt)
	w.stun = maxf(0.0, w.stun - dt)
	w.fueling = false
	w.moving = false
	if w.stun <= 0.0:
		var d := w.read_dir()
		if d != Vector2.ZERO:
			w.pos += d * Cfg.SPEED * dt
			w.moving = true
			w.dir = d.normalized()
	w.pos = Vector2(clampf(w.pos.x, Cfg.BOUNDS.position.x, Cfg.BOUNDS.end.x), clampf(w.pos.y, Cfg.BOUNDS.position.y, Cfg.BOUNDS.end.y))
	w.pos = resolve_px(w.pos, 14.0)

	if w.pressed and w.stun <= 0.0:
		if w.item == "bag":
			var target: Aircraft = null
			for pl in planes:
				if pl != null and pl.state == "ready" and pl.bags < pl.need and w.pos.distance_to(pl.door_pt()) < 90.0:
					target = pl
			if target != null:
				target.bags += 1
				w.item = ""
				score += 10
				ft(w.pos + Vector2(0, -60), "+10", Color("7dff8a"))
			else:
				bags.append(w.pos)
				w.item = ""
		elif w.item != "":
			if not try_calm(w):
				w.item = ""
		else:
			var bi := -1
			for i in bags.size():
				if bags[i].distance_to(w.pos) < 60.0:
					bi = i
					break
			if bi >= 0:
				bags.remove_at(bi)
				w.item = "bag"
			elif w.pos.distance_to(Cfg.COFFEE) < 90.0:
				w.item = "coffee"
			elif w.pos.distance_to(Cfg.BURGER) < 90.0:
				w.item = "burger"
	w.pressed = false

	if w.item == "" and w.stun <= 0.0 and w.act_held():
		for pl in planes:
			if pl != null and pl.state == "ready" and pl.fuel < 100.0 and w.pos.distance_to(pl.fuel_pt()) < 85.0:
				pl.fuel = minf(100.0, pl.fuel + dt * 33.0)
				w.fueling = true
				break

# ---------- главный цикл ----------
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	step(dt)
	menu_stage.visible = mode == "menu"
	if mode == "menu":
		for i in menu_rigs.size():
			var r := menu_rigs[i]
			r.rotation.y = PI + sin(Time.get_ticks_msec() / 900.0 + i) * 0.35
			if r.get_node_or_null("Body") != null:
				People.animate(r, Time.get_ticks_msec() / 90.0 + i, true)
	var fp_cam: Camera3D = null
	if mode == "play" and not workers.is_empty():
		fp_cam = workers[0].cam
	if fp_cam != null:
		fp_cam.current = true
		fp_cam.h_offset = randf_range(-shake, shake) * 0.008
		fp_cam.v_offset = randf_range(-shake, shake) * 0.008
	else:
		camera.current = true
	_sync_bags()

func _on_belt(p: Vector2) -> bool:
	for b: Rect2 in Cfg.BELTS:
		if b.has_point(p):
			return true
	return false

func _sync_bags() -> void:
	while bag_layer.get_child_count() < bags.size():
		var n := Rig.item("bag")
		n.scale = Vector3.ONE * 0.55
		bag_layer.add_child(n)
	var kids := bag_layer.get_children()
	for i in kids.size():
		kids[i].visible = i < bags.size()
		if i < bags.size():
			kids[i].position = Cfg.to3(bags[i], 0.68 if _on_belt(bags[i]) else 0.12)

func step(dt: float) -> void:
	if mode != "play":
		return
	time_left -= dt
	elapsed += dt
	shake = maxf(0.0, shake - dt * 30.0)

	for w in workers:
		update_worker(w, dt)

	bag_t -= dt
	if bag_t <= 0.0:
		bag_t = 1.5
		var belt: Rect2 = Cfg.BELTS.pick_random()
		var on_belt := 0
		var start_free := true
		for bg in bags:
			if belt.has_point(bg):
				on_belt += 1
				if bg.x < belt.position.x + 70.0:
					start_free = false
		if on_belt < 6 and start_free:
			bags.append(Vector2(belt.position.x + 16.0, belt.position.y + belt.size.y / 2.0 + randf_range(-12.0, 12.0)))
	# багаж едет по ленте к столу и накапливается у упора
	for i in bags.size():
		var bg := bags[i]
		for belt: Rect2 in Cfg.BELTS:
			if belt.has_point(bg):
				var end_x := belt.end.x - 24.0
				if bg.x < end_x:
					var blocked := false
					for j in bags.size():
						if j != i and bags[j].x > bg.x and bags[j].x - bg.x < 34.0 and absf(bags[j].y - bg.y) < 36.0 and belt.has_point(bags[j]):
							blocked = true
							break
					if not blocked:
						bags[i] = Vector2(minf(bg.x + Cfg.BELT_SPEED * dt, end_x), bg.y)
				break

	plane_t -= dt
	if plane_t <= 0.0:
		spawn_plane()
		plane_t = maxf(7.0, 15.0 - elapsed / 18.0)
	for i in planes.size():
		if planes[i] != null:
			update_plane(planes[i], dt, i)

	var delayed := 0
	for pl in planes:
		if pl != null and pl.delayed and pl.state == "ready":
			delayed += 1
	if delayed > 0:
		anger += delayed * 1.2 * dt
	else:
		anger = maxf(0.0, anger - 0.8 * dt)
	anger = clampf(anger, 0.0, 100.0)

	npc_t -= dt
	if npc_t <= 0.0:
		npc_t = 5.0
		if npcs.size() < int(anger / 20.0):
			var pool: Array[String] = []
			if anger >= 20.0:
				pool.append("pilot")
			if anger >= 40.0 and not npcs.any(func(n): return n.type == "dispatcher"):
				pool.append("dispatcher")
			if anger >= 55.0:
				pool.append("hooligan")
			if not pool.is_empty():
				spawn_npc(pool.pick_random())
		if anger >= 45.0 and not npcs.any(func(n): return n.type == "muscle") and randf() < 0.06:
			spawn_npc("muscle")
	for n in npcs:
		update_npc(n, dt)

	for t in texts:
		t.t -= dt
		t.pos.y -= 22.0 * dt
	texts = texts.filter(func(t): return t.t > 0.0)
	for f in feed:
		f.t -= dt
	feed = feed.filter(func(f): return f.t > 0.0)
	banner_t = maxf(0.0, banner_t - dt)

	if anger >= 100.0:
		reason = "Аэропорт закрыт: пассажиры взяли терминал штурмом!"
		mode = "end"
	elif time_left <= 0.0:
		reason = "Смена окончена!"
		mode = "end"
