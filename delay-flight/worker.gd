class_name Worker
extends Node2D
# Игрок: сотрудник аэропорта.

const KEYS := [
	{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "act": KEY_SPACE},
	{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "act": KEY_ENTER},
]

var idx := 0
var role: Dictionary
var item := ""
var stun := 0.0
var knock := Vector2.ZERO
var pressed := false
var fueling := false
var face := 1.0
var walk := 0.0
var moving := false

func setup(i: int) -> void:
	idx = i
	role = Cfg.ROLES[i % Cfg.ROLES.size()]

func joy_device() -> int:
	return idx - 2 if idx >= 2 else -1

func read_dir() -> Vector2:
	var d := Vector2.ZERO
	if idx < 2:
		var k: Dictionary = KEYS[idx]
		d.x = float(Input.is_physical_key_pressed(k.right)) - float(Input.is_physical_key_pressed(k.left))
		d.y = float(Input.is_physical_key_pressed(k.down)) - float(Input.is_physical_key_pressed(k.up))
	else:
		var dev := joy_device()
		d = Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
		if d.length() < 0.25:
			d = Vector2.ZERO
	return d.limit_length(1.0)

func act_held() -> bool:
	if idx < 2:
		return Input.is_physical_key_pressed(KEYS[idx].act)
	return Input.is_joy_button_pressed(joy_device(), JOY_BUTTON_A)

func act_label() -> String:
	return ["Пробел", "Enter", "A (геймпад)", "A (геймпад)"][idx]

func _process(delta: float) -> void:
	if moving:
		walk += delta * 14.0
	queue_redraw()

func _draw() -> void:
	Paint.ellipse(self, Vector2(0, 19), 21, 8, Color(Cfg.PLAYER_COLORS[idx], 0.55))
	var o := {
		"shirt": role.shirt, "vest": role.vest, "hat": role.hat, "hat_col": role.hat_col,
		"ears": role.ears, "skin": role.skin, "face": face, "walk": walk if moving else 0.0,
		"stun": stun > 0.0, "brow": false,
	}
	if stun > 0.0:
		o.skin = Color(role.skin).lerp(Color("9aa0a6"), 0.5)
	Paint.person(self, Vector2.ZERO, o)
	if item != "":
		Paint.item(self, item, Vector2(0, -46), 1.1)
	elif fueling:
		_fuel_icon()
	var font := ThemeDB.fallback_font
	var tag := "P%d · %s" % [idx + 1, role.name]
	draw_string_outline(font, Vector2(-60, 38), tag, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 4, Color.BLACK)
	draw_string(font, Vector2(-60, 38), tag, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Cfg.PLAYER_COLORS[idx])

func _fuel_icon() -> void:
	Paint.round_rect(self, Rect2(-8, -58, 16, 20), Color("ff9f43"), 3)
	draw_rect(Rect2(-5, -55, 10, 6), Color("2b3345"))
