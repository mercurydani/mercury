class_name Angry
extends Node2D
# Злой сотрудник: пилот, диспетчер, пилот-хулиган или КАЧОК.

var type := "pilot"
var cd := 1.5
var wind := 0.0
var shout := 3.0
var walk := 0.0
var face := -1.0
var moving := false

const NAMES := {"pilot": "пилот", "dispatcher": "диспетчер", "hooligan": "пилот-хулиган", "muscle": "КАЧОК"}

func _process(delta: float) -> void:
	if moving:
		walk += delta * 12.0
	queue_redraw()

func _draw() -> void:
	var o := {"face": face, "walk": walk if moving else 0.0, "brow": true, "skin": Color("e8a08a")}
	var r := 24.0
	match type:
		"pilot":
			o.merge({"shirt": Color("f4f6fa"), "hat": "pilot", "tie": true, "arm": Color("f4f6fa")})
		"dispatcher":
			o.merge({"shirt": Color("9fc3ee"), "headset": true, "tie": true, "arm": Color("9fc3ee"), "skin": Color("e07a6a")})
		"hooligan":
			o.merge({"shirt": Color("f4f6fa"), "hat": "pilot", "shades": true, "vest": Color("ff8a3d"), "arm": Color("f4f6fa")})
		"muscle":
			o.merge({"s": 2.1, "shirt": Color("d8d8d8"), "hat": "bandana", "shades": true, "skin": Color("d98c5f"), "arm": Color("d98c5f"), "arm_r": 8.0, "pants": Color("22304d")})
			r = 62.0
			if wind > 0.0 and int(wind * 12.0) % 2 == 0:
				draw_circle(Vector2(0, -20), 70, Color(1, 0.2, 0.1, 0.25))
	Paint.person(self, Vector2.ZERO, o)
	if type == "muscle":
		for sx in [-1.0, 1.0]:
			draw_arc(Vector2(sx * 30, -4), 12, 0.3, 2.4, 8, Color("a8532f"), 2.5)
		if wind > 0.0:
			_label("!!!", Vector2(0, -r - 34), 40, Color("ff2d2d"))
	_label(NAMES[type], Vector2(0, -r - 16 if type != "muscle" else -r - 6), 13 if type != "muscle" else 20, Color("ffb3a8"))

func _label(t: String, p: Vector2, size: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, p + Vector2(-100, 0), t, HORIZONTAL_ALIGNMENT_CENTER, 200, size, 5, Color.BLACK)
	draw_string(font, p + Vector2(-100, 0), t, HORIZONTAL_ALIGNMENT_CENTER, 200, size, col)
