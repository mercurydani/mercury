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
	var o := {"s": 1.3, "brow": true, "skin": Color("e8a08a")}
	var height := 2.2
	match type:
		"pilot":
			o.merge({"shirt": Color("f4f6fa"), "hat": "pilot", "tie": true})
		"dispatcher":
			o.merge({"shirt": Color("9fc3ee"), "headset": true, "tie": true, "skin": Color("e07a6a")})
		"hooligan":
			o.merge({"shirt": Color("f4f6fa"), "hat": "pilot", "shades": true, "vest": Color("ff8a3d")})
		"muscle":
			o.merge({"s": 3.0, "bulk": 1.9, "shirt": Color("d8d8d8"), "hat": "bandana", "shades": true, "skin": Color("d98c5f"), "arm": Color("d98c5f"), "pants": Color("22304d")})
			height = 4.6
	rig = Rig.person(o)
	add_child(rig)
	Rig.label(self, NAMES[type], Vector3(0, height + 0.15, 0), 30 if type == "muscle" else 20, Color("ffb3a8"))
	if type == "muscle":
		glow = Rig.sphere(self, 2.2, Vector3(0, 2.0, 0), Color(1, 0.15, 0.1, 0.22), Vector3.ONE, 1.0)
		glow.visible = false
		alarm = Rig.label(self, "!!!", Vector3(0, 5.6, 0), 80, Color("ff2d2d"))
		alarm.visible = false

func _process(delta: float) -> void:
	if moving:
		walk += delta * 12.0
	rig.rotation.y = lerp_angle(rig.rotation.y, atan2(dir.y, dir.x), minf(1.0, delta * 10.0))
	Rig.animate(rig, walk, moving)
	if type == "muscle":
		var on := wind > 0.0 and int(wind * 12.0) % 2 == 0
		glow.visible = on
		alarm.visible = wind > 0.0
		if wind > 0.0:
			rig.rotation.z = sin(Time.get_ticks_msec() / 25.0) * 0.06
		else:
			rig.rotation.z = 0.0
