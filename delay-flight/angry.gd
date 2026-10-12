class_name Angry
extends Node3D
# Злой сотрудник: пилот, диспетчер, пилот-хулиган или КАЧОК.

var type := "pilot"
var cd := 1.5
var wind := 0.0
var shout := 3.0
var walk := 0.0
var dir := Vector2(-1, 0)
var moving := false
var pos := Vector2.ZERO:
	set(v):
		pos = v
		position = Cfg.to3(v)

var rig: Node3D
var glow: MeshInstance3D
var alarm: Label3D

const NAMES := {"pilot": "пилот", "dispatcher": "диспетчер", "hooligan": "пилот-хулиган", "muscle": "КАЧОК"}

func _ready() -> void:
	var o := People.npc_opts(type)
	o["s"] = float(o.get("s", 1.0)) * Cfg.PERSON
	rig = People.person(o)
	add_child(rig)
	if type == "muscle":
		glow = Rig.sphere(self, 0.8, Vector3(0, 0.8, 0), Color(1, 0.15, 0.1, 0.22), Vector3.ONE, 1.0)
		glow.visible = false
		alarm = Rig.label(self, "!!!", Vector3(0, 2.0, 0), 80, Color("ff2d2d"))
		alarm.pixel_size = 0.004
		alarm.visible = false

func _process(delta: float) -> void:
	if moving:
		walk += delta * 12.0
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.y, dir.x), minf(1.0, delta * 10.0))
	People.animate(rig, walk, moving, "angry")
	if type == "muscle":
		var on := wind > 0.0 and int(wind * 12.0) % 2 == 0
		glow.visible = on
		alarm.visible = wind > 0.0
		if wind > 0.0:
			rig.rotation.z = sin(Time.get_ticks_msec() / 25.0) * 0.06
		else:
			rig.rotation.z = 0.0
