class_name Paint
# Общие примитивы рисования: люди, предметы.

static func ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)

static func half_disc(c: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 15:
		var a := PI + PI * i / 14.0
		pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	c.draw_colored_polygon(pts, col)

static func round_rect(c: CanvasItem, rect: Rect2, col: Color, r: float = 6.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	c.draw_style_box(sb, rect)

# o: s, shirt, vest, hat, hat_col, ears, skin, face(-1..1), walk, stun, shades, tie, headset, pants, brow
static func person(c: CanvasItem, p: Vector2, o: Dictionary) -> void:
	var s: float = o.get("s", 1.0)
	var walk: float = o.get("walk", 0.0)
	var face: float = o.get("face", 1.0)
	var bob := sin(walk) * 3.0 * s
	var skin: Color = o.get("skin", Color("e8b48a"))
	var shirt: Color = o.get("shirt", Color("3a4252"))
	var pants: Color = o.get("pants", Color("262d3d"))
	ellipse(c, p + Vector2(0, 18 * s), 16 * s, 6 * s, Color(0, 0, 0, 0.3))
	# ноги
	c.draw_rect(Rect2(p + Vector2(-8 * s, 7 * s + bob), Vector2(6 * s, 11 * s)), pants)
	c.draw_rect(Rect2(p + Vector2(2 * s, 7 * s - bob), Vector2(6 * s, 11 * s)), pants)
	c.draw_rect(Rect2(p + Vector2(-9 * s, 16 * s + bob), Vector2(8 * s, 3 * s)), Color("151a24"))
	c.draw_rect(Rect2(p + Vector2(1 * s, 16 * s - bob), Vector2(8 * s, 3 * s)), Color("151a24"))
	# руки
	var arm: Color = o.get("arm", shirt)
	var ar: float = o.get("arm_r", 4.5)
	c.draw_circle(p + Vector2(-14 * s, 0 + bob * 0.5), ar * s, arm)
	c.draw_circle(p + Vector2(14 * s, 0 - bob * 0.5), ar * s, arm)
	# торс
	round_rect(c, Rect2(p + Vector2(-11 * s, -9 * s), Vector2(22 * s, 19 * s)), shirt, 5 * s)
	var vest: Color = o.get("vest", Color(0, 0, 0, 0))
	if vest.a > 0.0:
		c.draw_rect(Rect2(p + Vector2(-11 * s, -9 * s), Vector2(7 * s, 19 * s)), vest)
		c.draw_rect(Rect2(p + Vector2(4 * s, -9 * s), Vector2(7 * s, 19 * s)), vest)
		c.draw_rect(Rect2(p + Vector2(-11 * s, 1 * s), Vector2(22 * s, 3 * s)), Color("e8eef5"))
	if o.get("tie", false):
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8 * s), p + Vector2(-3 * s, 2 * s), p + Vector2(0, 8 * s), p + Vector2(3 * s, 2 * s)]), Color("c0392b"))
	# голова
	var hc := p + Vector2(0, -19 * s)
	c.draw_circle(hc, 10 * s, skin)
	if o.get("ears", false):
		c.draw_circle(hc + Vector2(-10 * s, 0), 4.5 * s, Color("e04b2f"))
		c.draw_circle(hc + Vector2(10 * s, 0), 4.5 * s, Color("e04b2f"))
	# глаза
	var ex := face * 2.0 * s
	if o.get("shades", false):
		c.draw_rect(Rect2(hc + Vector2(-8 * s + ex, -2 * s), Vector2(16 * s, 4 * s)), Color("0b0b0b"))
	else:
		c.draw_circle(hc + Vector2(-3.5 * s + ex, -1 * s), 1.6 * s, Color("111111"))
		c.draw_circle(hc + Vector2(3.5 * s + ex, -1 * s), 1.6 * s, Color("111111"))
		if o.get("brow", false):
			c.draw_line(hc + Vector2(-6 * s + ex, -5 * s), hc + Vector2(-1 * s + ex, -3 * s), Color("111111"), 1.8 * s)
			c.draw_line(hc + Vector2(6 * s + ex, -5 * s), hc + Vector2(1 * s + ex, -3 * s), Color("111111"), 1.8 * s)
	c.draw_line(hc + Vector2(-3 * s + ex, 5 * s), hc + Vector2(3 * s + ex, 5 * s), Color("5a1f1f"), 1.5 * s)
	# головной убор
	var hat: String = o.get("hat", "")
	var hat_col: Color = o.get("hat_col", Color.WHITE)
	if hat == "helmet":
		half_disc(c, hc + Vector2(0, -1 * s), 11.5 * s, hat_col)
		c.draw_rect(Rect2(hc + Vector2(-12 * s, -2 * s), Vector2(24 * s, 2.5 * s)), hat_col.darkened(0.2))
	elif hat == "cap":
		half_disc(c, hc + Vector2(0, -2 * s), 10.5 * s, hat_col)
		c.draw_rect(Rect2(hc + Vector2(-2 * s + face * 5 * s, -3 * s), Vector2(11 * s, 3 * s)), hat_col.darkened(0.25))
	elif hat == "pilot":
		half_disc(c, hc + Vector2(0, -2 * s), 11 * s, Color("1b2a52"))
		c.draw_rect(Rect2(hc + Vector2(-11 * s, -4 * s), Vector2(22 * s, 3 * s)), Color("ffd24d"))
		c.draw_rect(Rect2(hc + Vector2(-2 * s + face * 5 * s, -2 * s), Vector2(11 * s, 2.5 * s)), Color("111a33"))
	elif hat == "bandana":
		half_disc(c, hc + Vector2(0, -1 * s), 10.5 * s, Color("c0392b"))
	if o.get("headset", false):
		c.draw_arc(hc, 11 * s, PI, TAU, 14, Color("111111"), 2 * s)
		c.draw_circle(hc + Vector2(-11 * s, 0), 3.5 * s, Color("111111"))
		c.draw_line(hc + Vector2(-11 * s, 2 * s), hc + Vector2(-5 * s, 8 * s), Color("111111"), 1.5 * s)
	if o.get("stun", false):
		for i in 3:
			var a := Time.get_ticks_msec() / 200.0 + i * TAU / 3.0
			c.draw_circle(hc + Vector2(cos(a) * 12, -14 + sin(a) * 4), 2.5, Color("ffd24d"))

static func bag(c: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	c.draw_arc(p + Vector2(0, -7 * s), 5 * s, PI, TAU, 8, Color("3b2a1a"), 2.0 * s)
	round_rect(c, Rect2(p + Vector2(-10 * s, -7 * s), Vector2(20 * s, 15 * s)), Color("b5651d"), 3 * s)
	c.draw_rect(Rect2(p + Vector2(-10 * s, -1 * s), Vector2(20 * s, 2 * s)), Color("7a4310"))
	c.draw_rect(Rect2(p + Vector2(-2 * s, -2 * s), Vector2(4 * s, 4 * s)), Color("ffd24d"))

static func cup(c: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-6 * s, -7 * s), p + Vector2(6 * s, -7 * s), p + Vector2(4 * s, 7 * s), p + Vector2(-4 * s, 7 * s)]), Color("f4f4f4"))
	c.draw_rect(Rect2(p + Vector2(-5 * s, -2 * s), Vector2(10 * s, 4 * s)), Color("8b5a2b"))
	c.draw_rect(Rect2(p + Vector2(-7 * s, -9 * s), Vector2(14 * s, 3 * s)), Color("6b4423"))
	c.draw_arc(p + Vector2(6 * s, 0), 3.5 * s, -PI / 2, PI / 2, 8, Color("f4f4f4"), 2.0 * s)

static func burger(c: CanvasItem, p: Vector2, s: float = 1.0) -> void:
	half_disc(c, p + Vector2(0, -1 * s), 9 * s, Color("d9893b"))
	c.draw_rect(Rect2(p + Vector2(-9 * s, -1 * s), Vector2(18 * s, 3 * s)), Color("5a2d0c"))
	c.draw_rect(Rect2(p + Vector2(-9 * s, 2 * s), Vector2(18 * s, 2 * s)), Color("6bbf3a"))
	c.draw_rect(Rect2(p + Vector2(-9 * s, 4 * s), Vector2(18 * s, 3 * s)), Color("d9893b"))

static func item(c: CanvasItem, name: String, p: Vector2, s: float = 1.0) -> void:
	match name:
		"bag": bag(c, p, s)
		"coffee": cup(c, p, s)
		"burger": burger(c, p, s)
