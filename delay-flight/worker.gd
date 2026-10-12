class_name Worker
extends Node3D
# Игрок: сотрудник аэропорта. В режиме fp камера у него «в глазах».

const KEYS := [
	{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "act": KEY_SPACE},
	{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "act": KEY_ENTER},
]
const EYE := 0.5

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
var fp := false
var yaw := 0.0
var pitch := 0.0
var pos := Vector2.ZERO:
	set(v):
		pos = v
		position = Cfg.to3(v)

var rig: Node3D
var hold: Node3D
var held := ""
var stars: Node3D
var cam: Camera3D

func setup(i: int) -> void:
	idx = i
	role = Cfg.ROLES[i % Cfg.ROLES.size()]

func joy_device() -> int:
	return idx - 2 if idx >= 2 else -1

# Вектор движения в мировых координатах логики (пиксели).
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
	d = d.limit_length(1.0)
	if fp:
		var fwd := Vector2(-cos(yaw), -sin(yaw))
		var right := Vector2(-sin(yaw), cos(yaw))
		return right * d.x + fwd * -d.y
	return d

func act_held() -> bool:
	if idx < 2:
		return Input.is_physical_key_pressed(KEYS[idx].act)
	return Input.is_joy_button_pressed(joy_device(), JOY_BUTTON_A)

func _ready() -> void:
	var o := People.crew_opts(idx)
	o["s"] = 1.2 * Cfg.PERSON
	rig = People.person(o)
	add_child(rig)
	var col: Color = Cfg.PLAYER_COLORS[idx]
	var ring := Rig.cyl(self, 0.25, 0.25, 0.01, Vector3(0, 0.012, 0), Color(col, 0.75), Vector3.ZERO, 1.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tag := Node3D.new()
	stars = Node3D.new()
	stars.position = Vector3(0, 0.9, 0)
	add_child(stars)
	for i in 3:
		var a := TAU * i / 3.0
		Rig.sphere(stars, 0.02, Vector3(cos(a) * 0.15, 0, sin(a) * 0.15), Color("ffd24d"), Vector3.ONE, 1.5)
	hold = Node3D.new()
	if fp:
		cam = Camera3D.new()
		cam.fov = 78.0
		cam.near = 0.12
		cam.position = Vector3(0, EYE, 0)
		add_child(cam)
		hold.position = Vector3(0.12, -0.14, -0.3)
		hold.scale = Vector3.ONE * 0.45
		cam.add_child(hold)
		rig.visible = false
		ring.visible = false
		tag.visible = false
		stars.visible = false
	else:
		hold.position = Vector3(0, 0.9, 0)
		add_child(hold)

func _process(delta: float) -> void:
	if moving:
		walk += delta * 14.0
	var want := item if item != "" else ("fuel" if fueling else "")
	if want != held:
		held = want
		for c in hold.get_children():
			c.queue_free()
		if want != "":
			hold.add_child(Rig.item(want))
	var lying := stun > 0.35
	if fp:
		rotation.y = yaw
		cam.rotation.x = pitch
		cam.rotation.z = lerpf(cam.rotation.z, 1.1 if lying else 0.0, minf(1.0, delta * 10.0))
		var bob := sin(walk) * 0.012 if moving and not lying else 0.0
		cam.position.y = lerpf(cam.position.y, 0.12 if lying else EYE + bob, minf(1.0, delta * 10.0))
		hold.rotation.y = sin(walk * 0.5) * 0.1
		return
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.y, dir.x), minf(1.0, delta * 14.0))
	rig.rotation.x = lerpf(rig.rotation.x, -1.45 if lying else 0.0, minf(1.0, delta * 12.0))
	rig.position.y = lerpf(rig.position.y, 0.16 if lying else 0.0, minf(1.0, delta * 12.0))
	People.animate(rig, walk, moving and not lying)
	hold.rotation.y += delta * 2.0
	stars.visible = stun > 0.0
	stars.rotation.y += delta * 6.0
