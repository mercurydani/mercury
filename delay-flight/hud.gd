class_name Hud
extends Node2D
# Интерфейс: верхняя панель, баннер, меню, финал.

var game: Node

func _t(text: String, cx: float, y: float, size: int, col: Color = Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(cx - 640, y), text, HORIZONTAL_ALIGNMENT_CENTER, 1280, size, 6, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(cx - 640, y), text, HORIZONTAL_ALIGNMENT_CENTER, 1280, size, col)

func _left(text: String, x: float, y: float, size: int, col: Color = Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	match game.mode:
		"menu": _menu()
		"play":
			_bar()
			_crosshair()
		"end":
			_bar()
			_end()

func _crosshair() -> void:
	draw_circle(Vector2(640, 360), 3.0, Color(1, 1, 1, 0.85))
	draw_arc(Vector2(640, 360), 9.0, 0, TAU, 24, Color(1, 1, 1, 0.35), 2.0)
	var hint: String = game.hint_for(game.workers[0]) if not game.workers.is_empty() else ""
	if hint != "":
		_t(hint, 640, 420, 26, Color("ffd24d"))

func _bar() -> void:
	Paint.round_rect(self, Rect2(8, 8, 1264, 38), Color(0, 0, 0, 0.55), 10)
	_left("Время  %d" % maxi(0, ceili(game.time_left)), 24, 34, 22)
	_left("Очки  %d" % game.score, 220, 34, 22, Color("ffd24d"))
	_left("Вылетов  %d" % game.departed, 400, 34, 22)
	_left("ЗЛОСТЬ", 640, 34, 18, Color("ff8a80"))
	Paint.round_rect(self, Rect2(730, 16, 520, 22), Color(0, 0, 0, 0.6), 8)
	var a: float = game.anger / 100.0
	var col := Color("7dff8a") if a < 0.33 else (Color("ff9f43") if a < 0.66 else Color("ff3b30"))
	if a > 0.01:
		Paint.round_rect(self, Rect2(730, 16, 520 * a, 22), col, 8)
	if game.banner_t > 0.0:
		draw_rect(Rect2(0, 330, 1280, 64), Color(0, 0, 0, 0.7))
		_t(game.banner_text, 640, 372, 32, Color("ffd24d"))

func _menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 300), Color(0.05, 0.08, 0.14, 0.8))
	draw_rect(Rect2(0, 540, 1280, 180), Color(0.05, 0.08, 0.14, 0.8))
	_t("ЗАДЕРЖКА РЕЙСА", 640, 140, 84, Color("ffd24d"))
	_t("Ты сотрудник наземной службы. Самолёты не ждут. Пилоты — тем более.", 640, 202, 24)
	_t("Опоздаешь — придёт КАЧОК.", 640, 245, 26, Color("ff8a80"))
	for i in 4:
		var role: Dictionary = Cfg.ROLES[i]
		var sp: Vector2 = game.to_screen(game.menu_spot(i), 0.0)
		_t(role.name, sp.x, 500, 22, Cfg.PLAYER_COLORS[i])
	_t("Нажми Пробел — начать смену", 640, 590, 30, Color("7dff8a"))
	_t("Мышь — смотреть, WASD — ходить, Пробел — взять / отдать. У крыла держи Пробел — заправка.", 640, 646, 20)
	_t("Кофе успокаивает пилота и диспетчера. Бургер — качка.", 640, 672, 20)
	_t("Модели: BAe-146 — S. Kurniawan (CC BY), терминал — soysascha (CC BY), Poly by Google (CC BY), Quaternius, Kenney (CC0)", 640, 704, 13, Color("9aa4b3"))

func _end() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.8))
	_t(game.reason, 640, 220, 40, Color("ff5a4d") if game.anger >= 100.0 else Color("ffd24d"))
	_t("Очки: %d" % game.score, 640, 310, 56)
	_t("Вылетов: %d      Успокоено: %d" % [game.departed, game.calmed], 640, 370, 28)
	var s: int = game.score
	var rank := "Король перрона" if s > 1200 else ("Опытный грузчик" if s > 700 else ("Стажёр" if s > 300 else "Лучше бы вы пошли на кассу"))
	_t(rank, 640, 440, 34, Color("7dff8a"))
	_t("R — в меню", 640, 520, 24)
