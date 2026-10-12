class_name Airport
extends Node2D
# Декорации: терминал, перрон, багажный зал, киоски, рулёжка.

const ASPHALT := Color("4b5363")
const PANEL := Color("434b5a")
const PAINT_Y := Color("f2c744")
const PAINT_W := Color("e6ebf2")

func _ready() -> void:
	queue_redraw()

func _txt(t: String, c: Vector2, size: int, col: Color, w: float = 240.0) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-w / 2, size * 0.35), t, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, Cfg.W, Cfg.H), ASPHALT)
	# плиты перрона
	for x in range(0, Cfg.W, 90):
		draw_line(Vector2(x, 90), Vector2(x, Cfg.H), PANEL, 2)
	for y in range(90, Cfg.H, 90):
		draw_line(Vector2(0, y), Vector2(Cfg.W, y), PANEL, 2)
	_taxiway()
	for i in 3:
		_stand(i, float(Cfg.ROWS[i]))
	_terminal()
	_baggage_hall()
	_kiosk(Cfg.COFFEE, "КОФЕ", Color("7a5230"), Color("e8d2a8"), true)
	_kiosk(Cfg.BURGER, "БУРГЕРЫ", Color("a13a2a"), Color("f1d9c4"), false)
	_props()

func _terminal() -> void:
	# корпус
	draw_rect(Rect2(0, 0, Cfg.W, 78), Color("c8d0db"))
	draw_rect(Rect2(0, 70, Cfg.W, 12), Color("8d98a8"))
	draw_rect(Rect2(0, 0, Cfg.W, 8), Color("5d6a7e"))
	# окна терминала
	for i in 20:
		var x := 22.0 + i * 62.0
		draw_rect(Rect2(x, 20, 48, 34), Color("2f5d8a"))
		draw_rect(Rect2(x, 20, 48, 12), Color("5aa9ff", 0.7))
		draw_line(Vector2(x + 24, 20), Vector2(x + 24, 54), Color("c8d0db"), 2)
	# вывеска
	Paint.round_rect(self, Rect2(Cfg.W / 2.0 - 150, 8, 300, 22), Color("1b2a52"), 6)
	_txt("ВЫЛЕТ · DEPARTURES", Vector2(Cfg.W / 2.0, 19), 14, Color("ffd24d"), 300)
	# диспетчерская вышка
	var tx := 1010.0
	draw_rect(Rect2(tx - 16, 40, 32, 60), Color("aab4c3"))
	Paint.round_rect(self, Rect2(tx - 44, 14, 88, 34), Color("5d6a7e"), 8)
	draw_rect(Rect2(tx - 38, 20, 76, 20), Color("7fd0ff", 0.85))
	draw_line(Vector2(tx, 14), Vector2(tx, -6), Color("333b4a"), 3)
	draw_circle(Vector2(tx, -6), 4, Color("ff4d4d"))
	_txt("ДИСПЕТЧЕРСКАЯ", Vector2(tx, 62), 11, Color("2b3345"), 120)

func _taxiway() -> void:
	draw_rect(Rect2(1130, 82, 150, Cfg.H - 82), Color("3c4350"))
	draw_line(Vector2(1205, 82), Vector2(1205, Cfg.H), PAINT_Y, 5)
	for y in range(100, Cfg.H, 36):
		draw_circle(Vector2(1138, y), 3, Color("5aa9ff"))
		draw_circle(Vector2(1272, y), 3, Color("5aa9ff"))
	for y in range(100, Cfg.H, 60):
		draw_rect(Rect2(1172, y, 66, 6), Color(PAINT_W, 0.35))

func _stand(i: int, y: float) -> void:
	# осевая линия заруливания и стоп-линия
	draw_line(Vector2(330, y), Vector2(1130, y), PAINT_Y, 4)
	draw_rect(Rect2(Cfg.PX - 188, y - 46, 5, 92), PAINT_W)
	# безопасная зона
	for k in range(0, 46):
		var a := Vector2(Cfg.PX - 200 + k * 10.0, y - 106)
		if k % 2 == 0:
			draw_line(a, a + Vector2(6, 0), Color("c0392b", 0.7), 3)
			draw_line(a + Vector2(0, 212), a + Vector2(6, 212), Color("c0392b", 0.7), 3)
	# номер стоянки
	_txt("A%d" % (i + 1), Vector2(480, y - 40), 44, Color(PAINT_W, 0.8), 120)
	# метки точек работ на асфальте
	draw_arc(Vector2(Cfg.PX - 130, y), 36, 0, TAU, 28, Color(PAINT_Y, 0.25), 3)
	draw_arc(Vector2(Cfg.PX + 80, y), 36, 0, TAU, 28, Color("ff9f43", 0.25), 3)
	# люк с топливом
	draw_circle(Vector2(Cfg.PX + 80, y + 4), 11, Color("2b3345"))
	draw_circle(Vector2(Cfg.PX + 80, y + 4), 7, Color("ffb347"))

func _baggage_hall() -> void:
	var r := Cfg.BELT
	# здание багажного зала
	draw_rect(Rect2(0, 90, 176, Cfg.H - 90), Color("9aa6b6"))
	draw_rect(Rect2(170, 90, 8, Cfg.H - 90), Color("6b7789"))
	for y in range(110, 690, 70):
		draw_rect(Rect2(8, y, 18, 40), Color("2f5d8a"))
	# карусель
	Paint.round_rect(self, Rect2(r.position - Vector2(12, 12), r.size + Vector2(24, 24)), Color("1d222d"), 20)
	Paint.round_rect(self, r, Color("2f3645"), 14)
	for k in range(0, int(r.size.y), 20):
		draw_line(r.position + Vector2(6, k), r.position + Vector2(r.size.x - 6, k), Color("3d4658"), 3)
	draw_line(r.position + Vector2(r.size.x / 2.0, 8), r.position + Vector2(r.size.x / 2.0, r.size.y - 8), Color(PAINT_Y, 0.4), 3)
	Paint.round_rect(self, Rect2(r.position.x - 12, r.position.y - 46, r.size.x + 24, 26), Color("1b2a52"), 6)
	_txt("БАГАЖ", Vector2(r.position.x + r.size.x / 2.0, r.position.y - 33), 16, Color("ffd24d"), 120)

func _kiosk(p: Vector2, title: String, roof: Color, wall: Color, top: bool) -> void:
	var base := Rect2(p.x - 62, p.y - 30, 124, 60)
	draw_rect(Rect2(base.position + Vector2(5, 8), base.size), Color(0, 0, 0, 0.25))
	draw_rect(base, wall)
	# полосатый козырёк
	for k in 8:
		draw_rect(Rect2(base.position.x + k * 15.5, base.position.y - 14, 15.5, 22), roof if k % 2 == 0 else Color("f4f4f4"))
	draw_rect(Rect2(base.position.x + 10, base.position.y + 18, base.size.x - 20, 32), Color("5d4a3a"))
	_txt(title, Vector2(p.x, base.position.y + 34), 15, Color("ffffff"), 120)
	if top:
		Paint.cup(self, Vector2(p.x - 38, p.y - 40), 0.9)
	else:
		Paint.burger(self, Vector2(p.x + 38, p.y - 40), 0.9)

func _props() -> void:
	# конусы и колодки у стоянок
	for i in 3:
		var y: float = Cfg.ROWS[i]
		for off in [Vector2(-196, -100), Vector2(-196, 100), Vector2(190, -100), Vector2(190, 100)]:
			var p: Vector2 = Vector2(Cfg.PX, y) + off
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(7, 7), p + Vector2(-7, 7)]), Color("ff6a2a"))
			draw_rect(Rect2(p + Vector2(-8, 7), Vector2(16, 3)), Color("2b3345"))
			draw_rect(Rect2(p + Vector2(-3, -1), Vector2(6, 3)), Color.WHITE)
