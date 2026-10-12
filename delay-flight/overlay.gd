class_name Overlay
extends Node2D
# Багаж на земле и всплывающие надписи.

var game: Node

func _draw() -> void:
	for p in game.bags:
		Paint.bag(self, p, 1.2)
	var font := ThemeDB.fallback_font
	for t in game.texts:
		var a := clampf(t.t, 0.0, 1.0)
		var col: Color = t.color
		col.a = a
		draw_string_outline(font, t.pos + Vector2(-500, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 1000, t.size, 6, Color(0, 0, 0, a))
		draw_string(font, t.pos + Vector2(-500, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 1000, t.size, col)

func _process(_d: float) -> void:
	queue_redraw()
