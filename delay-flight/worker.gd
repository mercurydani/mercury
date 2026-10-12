class_name Worker
extends Node3D
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
var dir := Vector2(0, 1)
var walk := 0.0
var moving := false
var pos := Vector2.ZERO:
	set(v):
		pos = v
		position = Cfg.to3(v)

var rig: Node3D
var hold: Node3D
var held := ""
var stars: Node3D

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

func _ready() -> void:
	rig = Rig.person({
		"s": 2.0, "shirt": role.shirt, "vest": role.vest, "hat": role.hat, "hat_col": role.hat_col,
		"ears": role.ears, "skin": role.skin,
	})
	add_child(rig)
	var col: Color = Cfg.PLAYER_COLORS[idx]
	var ring := Rig.cyl(self, 0.7, 0.7, 0.02, Vector3(0, 0.012, 0), Color(col, 0.75), Vector3.ZERO, 1.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hold = Node3D.new()
	hold.position = Vector3(0, 3.0, 0)
	add_child(hold)
	stars = Node3D.new()
	stars.position = Vector3(0, 2.8, 0)
	add_child(stars)
	for i in 3:
		var a := TAU * i / 3.0
		Rig.sphere(stars, 0.05, Vector3(cos(a) * 0.45, 0, sin(a) * 0.45), Color("ffd24d"), Vector3.ONE, 1.5)
	Rig.label(self, "P%d · %s" % [idx + 1, role.name], Vector3(0, -0.3, 0.0), 30, col)

func _process(delta: float) -> void:
	if moving:
		walk += delta * 14.0
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.x, dir.y), minf(1.0, delta * 14.0))
	var lying := stun > 0.35
	rig.rotation.x = lerpf(rig.rotation.x, -1.45 if lying else 0.0, minf(1.0, delta * 12.0))
	rig.position.y = lerpf(rig.position.y, 0.16 if lying else 0.0, minf(1.0, delta * 12.0))
	Rig.animate(rig, walk, moving and not lying)
	var want := item if item != "" else ("fuel" if fueling else "")
	if want != held:
		held = want
		for c in hold.get_children():
			c.queue_free()
		if want != "":
			hold.add_child(Rig.item(want))
	hold.rotation.y += delta * 2.0
	stars.visible = stun > 0.0
	stars.rotation.y += delta * 6.0
