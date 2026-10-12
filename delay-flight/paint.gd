class_name Paint
# 2D-помощники для интерфейса.

static func round_rect(c: CanvasItem, rect: Rect2, col: Color, r: float = 6.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	c.draw_style_box(sb, rect)
