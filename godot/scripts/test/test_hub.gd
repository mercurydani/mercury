class_name TestHub
extends Node
## Тестовое меню: выбор локации и сложности, свободная прогулка. Esc — назад в меню, F1/F2/F3 — сложность внутри локации.

const LOCS := [
	["Крыша", "res://scenes/locations/roof.tscn"],
	["Лес «Нора у ручья»", "res://scenes/locations/forest.tscn"],
	["Склад «Темнота»", "res://scenes/locations/warehouse.tscn"],
	["Парк «Карусель-гора»", "res://scenes/locations/amusement.tscn"],
	["Порт «Ржавые гавани»", "res://scenes/locations/port.tscn"],
	["Дом №13", "res://scenes/locations/house.tscn"],
	["Подвал «Погреб»", "res://scenes/locations/cellar.tscn"],
	["Горы «Мурашки»", "res://scenes/locations/mountain.tscn"],
	["Лобби (двор)", "res://scenes/lobby.tscn"],
]

var _menu: Control
var _current: Node
var _overlay: Label
var _diff := 0


func _ready() -> void:
	Texts.register()
	LocationTexts.register()
	TranslationServer.set_locale("ru")
	_build_menu()
	_overlay = Label.new()
	_overlay.position = Vector2(16, 690)
	_overlay.add_theme_font_size_override("font_size", 16)
	var cl := CanvasLayer.new()
	cl.layer = 50
	cl.add_child(_overlay)
	add_child(cl)
	_overlay.visible = false


func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(440, 40)
	box.custom_minimum_size = Vector2(400, 0)
	box.add_theme_constant_override("separation", 8)
	_menu.add_child(box)
	var t := Label.new()
	t.text = "Meow Rescue Crew — тест локаций"
	t.add_theme_font_size_override("font_size", 28)
	box.add_child(t)
	var h := Label.new()
	h.text = "WASD ходить, пробел прыжок, E взаимодействие, R респаун, Esc меню, F1/F2/F3 сложность"
	h.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(h)
	var opt := OptionButton.new()
	for n in ["Сложность: простая", "Сложность: средняя", "Сложность: сложная"]:
		opt.add_item(n)
	opt.item_selected.connect(func(i: int) -> void: _diff = i)
	box.add_child(opt)
	for e in LOCS:
		var b := Button.new()
		b.text = e[0]
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_open.bind(e[1]))
		box.add_child(b)
	add_child(_menu)


func _open(path: String) -> void:
	_menu.visible = false
	_current = (load(path) as PackedScene).instantiate()
	add_child(_current)
	if _current.has_method("apply_difficulty"):
		_current.apply_difficulty(_diff)
	_overlay.visible = true
	_overlay.text = "Esc — меню · F1/F2/F3 — сложность"


func _back() -> void:
	if _current:
		_current.queue_free()
		_current = null
	_overlay.visible = false
	_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode == KEY_ESCAPE and _current:
		_back()
	elif _current and _current.has_method("apply_difficulty") and e.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		_diff = e.keycode - KEY_F1
		_current.apply_difficulty(_diff)
