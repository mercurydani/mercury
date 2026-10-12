extends Control

const SAVE_PATH := "user://save.json"
const OFFLINE_CAP_SEC := 8.0 * 3600.0
const PRESTIGE_DIV := 1.0e6

# name, base cost, cost growth, power, kind ("click" or "auto")
const UPGRADES := [
	{"name": "Гравитационный захват", "cost": 10.0, "growth": 1.15, "power": 1.0, "kind": "click"},
	{"name": "Пыль-пылесос", "cost": 15.0, "growth": 1.15, "power": 0.5, "kind": "auto"},
	{"name": "Аккреционный диск", "cost": 120.0, "growth": 1.16, "power": 4.0, "kind": "auto"},
	{"name": "Горизонт событий", "cost": 800.0, "growth": 1.17, "power": 12.0, "kind": "click"},
	{"name": "Приливный разрыв", "cost": 2500.0, "growth": 1.17, "power": 40.0, "kind": "auto"},
	{"name": "Квазар", "cost": 30000.0, "growth": 1.18, "power": 300.0, "kind": "auto"},
	{"name": "Поглощение галактики", "cost": 400000.0, "growth": 1.19, "power": 4000.0, "kind": "auto"},
	{"name": "Сингулярность", "cost": 8.0e6, "growth": 1.20, "power": 80000.0, "kind": "auto"},
]

var mass := 0.0
var run_mass := 0.0
var dark_matter := 0.0
var levels: Array = []

var stars: Array = []
var floaters: Array = []
var pulse := 0.0
var save_timer := 0.0

var mass_label: Label
var rate_label: Label
var info_label: Label
var buttons: Array = []
var prestige_button: Button
var center := Vector2.ZERO


func _ready() -> void:
	for i in UPGRADES.size():
		levels.append(0)
	load_game()
	build_ui()
	layout()
	get_viewport().size_changed.connect(layout)
	for i in 40:
		spawn_star(true)


func build_ui() -> void:
	mass_label = Label.new()
	mass_label.add_theme_font_size_override("font_size", 36)
	mass_label.position = Vector2(24, 16)
	add_child(mass_label)

	rate_label = Label.new()
	rate_label.add_theme_font_size_override("font_size", 18)
	rate_label.position = Vector2(24, 64)
	add_child(rate_label)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 16)
	info_label.modulate = Color(1, 1, 1, 0.6)
	info_label.position = Vector2(24, 680)
	add_child(info_label)

	var panel := VBoxContainer.new()
	panel.name = "Panel"
	panel.position = Vector2(820, 16)
	panel.size = Vector2(440, 690)
	panel.add_theme_constant_override("separation", 6)
	add_child(panel)

	for i in UPGRADES.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(440, 62)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(buy.bind(i))
		panel.add_child(b)
		buttons.append(b)

	prestige_button = Button.new()
	prestige_button.custom_minimum_size = Vector2(440, 70)
	prestige_button.pressed.connect(prestige)
	panel.add_child(prestige_button)


func layout() -> void:
	var s := get_viewport_rect().size
	center = Vector2(s.x * 0.33, s.y * 0.52)


func cost_of(i: int) -> float:
	var u: Dictionary = UPGRADES[i]
	return floor(u.cost * pow(u.growth, levels[i]))


func prestige_mult() -> float:
	return 1.0 + dark_matter * 0.10


func click_power() -> float:
	var p := 1.0
	for i in UPGRADES.size():
		if UPGRADES[i].kind == "click":
			p += UPGRADES[i].power * levels[i]
	return p * prestige_mult()


func auto_rate() -> float:
	var p := 0.0
	for i in UPGRADES.size():
		if UPGRADES[i].kind == "auto":
			p += UPGRADES[i].power * levels[i]
	return p * prestige_mult()


func pending_dark_matter() -> float:
	return floor(sqrt(run_mass / PRESTIGE_DIV))


func add_mass(v: float) -> void:
	mass += v
	run_mass += v


func buy(i: int) -> void:
	var c := cost_of(i)
	if mass >= c:
		mass -= c
		levels[i] += 1
		pulse = 1.0


func prestige() -> void:
	var gain := pending_dark_matter()
	if gain < 1.0:
		return
	dark_matter += gain
	mass = 0.0
	run_mass = 0.0
	for i in levels.size():
		levels[i] = 0
	stars.clear()
	floaters.clear()
	pulse = 2.0
	save_game()


func _gui_input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if pressed and pos.distance_to(center) <= hole_radius() + 60.0:
		var v := click_power()
		add_mass(v)
		pulse = 1.0
		floaters.append({"pos": pos, "text": "+" + fmt(v), "t": 0.0})


func hole_radius() -> float:
	return 60.0 + clampf(log(1.0 + run_mass) * 6.0, 0.0, 110.0)


func spawn_star(anywhere: bool = false) -> void:
	var s := get_viewport_rect().size
	var angle := randf() * TAU
	var far: float = maxf(s.x, s.y) * 0.6
	var dist: float = randf_range(hole_radius() + 40.0, far) if anywhere else far
	stars.append({
		"pos": center + Vector2(cos(angle), sin(angle)) * dist,
		"size": randf_range(1.0, 3.5),
		"color": Color.from_hsv(randf_range(0.05, 0.65), randf_range(0.0, 0.5), 1.0),
	})


func _process(delta: float) -> void:
	add_mass(auto_rate() * delta)
	pulse = maxf(0.0, pulse - delta * 3.0)

	var rate := auto_rate()
	var want: int = 40 + int(minf(80.0, log(1.0 + rate) * 8.0))
	while stars.size() < want:
		spawn_star()
	var swallow := hole_radius()
	for i in range(stars.size() - 1, -1, -1):
		var st: Dictionary = stars[i]
		var to_c: Vector2 = center - st.pos
		var d := to_c.length()
		var speed: float = 30.0 + 40000.0 / maxf(d, 40.0)
		var tangent := Vector2(-to_c.y, to_c.x).normalized()
		st.pos += (to_c.normalized() * speed + tangent * speed * 0.6) * delta
		if d < swallow * 0.8:
			stars.remove_at(i)

	for i in range(floaters.size() - 1, -1, -1):
		floaters[i].t += delta
		floaters[i].pos.y -= 50.0 * delta
		if floaters[i].t > 1.0:
			floaters.remove_at(i)

	update_ui()
	save_timer += delta
	if save_timer > 10.0:
		save_timer = 0.0
		save_game()
	queue_redraw()


func update_ui() -> void:
	mass_label.text = "Масса: " + fmt(mass)
	rate_label.text = "+%s за клик   |   +%s/сек   |   Тёмная материя: %s (×%.1f)" % [
		fmt(click_power()), fmt(auto_rate()), fmt(dark_matter), prestige_mult()]
	for i in UPGRADES.size():
		var u: Dictionary = UPGRADES[i]
		var b: Button = buttons[i]
		var what := "клик" if u.kind == "click" else "/сек"
		b.text = "%s  [ур. %d]\n+%s %s  —  цена: %s" % [u.name, levels[i], fmt(u.power * prestige_mult()), what, fmt(cost_of(i))]
		b.disabled = mass < cost_of(i)
	var gain := pending_dark_matter()
	prestige_button.text = "СВЕРХНОВАЯ: сброс ради +%s тёмной материи\n(+10%% ко всему за каждую)" % fmt(gain)
	prestige_button.disabled = gain < 1.0
	info_label.text = "Кликай по чёрной дыре. Прогресс сохраняется автоматически."


func _draw() -> void:
	for st in stars:
		draw_circle(st.pos, st.size, st.color)

	var r := hole_radius() + pulse * 6.0
	# свечение диска
	for k in 6:
		var rr := r + 30.0 - k * 5.0
		draw_arc(center, rr + 12.0, 0, TAU, 96, Color(1.0, 0.55 - k * 0.05, 0.1, 0.10 + k * 0.05), 4.0)
	draw_arc(center, r + 6.0, 0, TAU, 96, Color(1.0, 0.8, 0.4, 0.9), 3.0)
	draw_circle(center, r, Color(0, 0, 0, 1))

	for f in floaters:
		var a: float = 1.0 - float(f.t)
		draw_string(ThemeDB.fallback_font, f.pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, a))


func fmt(v: float) -> String:
	var suffixes := ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc"]
	var idx := 0
	var x := v
	while x >= 1000.0 and idx < suffixes.size() - 1:
		x /= 1000.0
		idx += 1
	if idx == 0:
		return str(int(x)) if x >= 100.0 or x == floor(x) else "%.1f" % x
	return "%.2f%s" % [x, suffixes[idx]]


func save_game() -> void:
	var data := {
		"mass": mass, "run_mass": run_mass, "dark_matter": dark_matter,
		"levels": levels, "time": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	mass = data.get("mass", 0.0)
	run_mass = data.get("run_mass", 0.0)
	dark_matter = data.get("dark_matter", 0.0)
	var saved: Array = data.get("levels", [])
	for i in min(saved.size(), levels.size()):
		levels[i] = int(saved[i])
	var away: float = clampf(Time.get_unix_time_from_system() - float(data.get("time", 0.0)), 0.0, OFFLINE_CAP_SEC)
	if away > 5.0:
		add_mass(auto_rate() * away * 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
