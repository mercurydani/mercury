class_name Overlay
extends Node2D
# Мелкие всплывашки («+10», «Не то!») у источника; видны только вблизи.

var game: Node

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var font := ThemeDB.fallback_font
	for t in game.texts:
		var a := clampf(t.t, 0.0, 1.0)
		var p3 := Cfg.to3(t.pos, 0.6)
		var d := cam.global_position.distance_to(p3)
		if d > 14.0 or cam.is_position_behind(p3):
			continue
		var fade := a * clampf(1.0 - d / 14.0, 0.0, 1.0)
		var sp := cam.unproject_position(p3)
		var col: Color = t.color
		col.a = fade
		draw_string_outline(font, sp + Vector2(-100, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 200, 14, 4, Color(0, 0, 0, fade * 0.8))
		draw_string(font, sp + Vector2(-100, 0), t.text, HORIZONTAL_ALIGNMENT_CENTER, 200, 14, col)

func _process(_d: float) -> void:
	queue_redraw()
