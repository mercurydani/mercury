class_name Overlay
extends Node2D
# Всплывающие надписи над 3D-миром (проецируются камерой).

var game: Node

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for t in game.texts:
		var a := clampf(t.t, 0.0, 1.0)
		var col: Color = t.color
		col.a = a
		var sp: Vector2 = game.to_screen(t.pos, 1.8)
		sp.x = clampf(sp.x, 400.0, 880.0)
		draw_string_outline(font, sp + Vector2(-500, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 1000, t.size, 6, Color(0, 0, 0, a))
		draw_string(font, sp + Vector2(-500, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 1000, t.size, col)

func _process(_d: float) -> void:
	queue_redraw()
