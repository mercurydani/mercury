class_name Hud
extends Node2D
# Интерфейс: стеклянные панели, карточки рейсов, лента событий, подсказки-клавиши.

const BG := Color(0.04, 0.06, 0.09, 0.62)
const EDGE := Color(1, 1, 1, 0.10)
const TXT := Color(0.94, 0.96, 0.98)
const DIM := Color(0.66, 0.72, 0.8)
const TEAL := Color("5ee0c4")
const AMBER := Color("ffcf5c")
const RED := Color("ff6b5e")

var game: Node
var font: Font
var bold: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	var fv := FontVariation.new()
	fv.base_font = font
	fv.variation_embolden = 0.55
	bold = fv

func _process(_d: float) -> void:
	queue_redraw()

# ---------- примитивы ----------
func _panel(r: Rect2, col: Color = BG, radius: float = 10.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	draw_style_box(sb, r)

func _text(s: String, p: Vector2, size: int, col: Color = TXT, f: Font = null, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var ft := f if f != null else font
	draw_string(ft, p, s, align, w, size, col)

func _ctext(s: String, cx: float, y: float, size: int, col: Color = TXT, f: Font = null) -> void:
	_text(s, Vector2(cx - 640.0, y), size, col, f, 1280.0, HORIZONTAL_ALIGNMENT_CENTER)

func _bar(r: Rect2, v: float, col: Color) -> void:
	_rrect(r, Color(1, 1, 1, 0.09), 3.0)
	if v > 0.003:
		_rrect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col, 3.0)

func _rrect(r: Rect2, col: Color, radius: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)

func _key(label: String, p: Vector2) -> float:
	var w := maxf(34.0, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0)
	var r := Rect2(p, Vector2(w, 30))
	_rrect(Rect2(p + Vector2(0, 3), r.size), Color(0, 0, 0, 0.45), 6.0)
	_rrect(r, Color(0.93, 0.95, 0.98), 6.0)
	_text(label, p + Vector2(0, 20), 14, Color(0.1, 0.12, 0.16), bold, w, HORIZONTAL_ALIGNMENT_CENTER)
	return w

func _draw() -> void:
	match game.mode:
		"menu": _menu()
		"play":
			_play()
		"end":
			_play()
			_end()

# ---------- игровой интерфейс ----------
func _play() -> void:
	# смена и очки
	_panel(Rect2(16, 16, 214, 62))
	_text("СМЕНА", Vector2(30, 36), 11, DIM)
	var t: int = maxi(0, ceili(game.time_left))
	_text("%d:%02d" % [t / 60, t % 60], Vector2(30, 66), 28, TXT, bold)
	_text("ОЧКИ", Vector2(138, 36), 11, DIM)
	_text("%d" % game.score, Vector2(138, 66), 28, AMBER, bold)
	# напряжение
	var a: float = game.anger / 100.0
	_panel(Rect2(440, 16, 400, 40), BG, 20.0)
	_text("НАПРЯЖЕНИЕ", Vector2(462, 33), 10, DIM)
	_bar(Rect2(462, 40, 356, 7), a, TEAL if a < 0.4 else (AMBER if a < 0.7 else RED))
	# объявление
	if game.banner_t > 0.0:
		var w := minf(900.0, font.get_string_size(game.banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 64.0)
		var al := clampf(game.banner_t, 0.0, 1.0)
		_panel(Rect2(640 - w / 2.0, 66, w, 34), Color(0.1, 0.07, 0.04, 0.78 * al), 17.0)
		draw_circle(Vector2(640 - w / 2.0 + 18, 83), 4.0, Color(AMBER, al))
		_text(game.banner_text, Vector2(640 - w / 2.0 + 32, 88), 16, Color(1, 0.94, 0.8, al))
	_flights()
	_feed()
	_prompt()

func _flights() -> void:
	var y := 16.0
	var x := 1280.0 - 16.0 - 264.0
	for pl in game.planes:
		if pl == null or pl.state == "leaving":
			continue
		var r := Rect2(x, y, 264, 98)
		var late: bool = pl.delayed
		_panel(r, Color(0.16, 0.05, 0.05, 0.66) if late else BG)
		var gate := "A%d" % (pl.row + 1)
		_rrect(Rect2(x + 12, y + 12, 38, 22), RED if late else TEAL, 5.0)
		_text(gate, Vector2(x + 12, y + 28), 14, Color(0.05, 0.08, 0.1), bold, 38, HORIZONTAL_ALIGNMENT_CENTER)
		_text(pl.flight, Vector2(x + 60, y + 29), 17, TXT, bold)
		var status := "ПРИБЫВАЕТ" if pl.state == "arriving" else ("ЗАДЕРЖАН" if late else "ОБСЛУЖИВАНИЕ")
		_text(status, Vector2(x + 252 - 120, y + 28), 10, RED if late else DIM, null, 120, HORIZONTAL_ALIGNMENT_RIGHT)
		if pl.state == "ready":
			_row(x, y + 46, "БАГАЖ", "%d/%d" % [pl.bags, pl.need], float(pl.bags) / pl.need, AMBER)
			_row(x, y + 62, "ТОПЛИВО", "%d%%" % int(pl.fuel), pl.fuel / 100.0, Color("6aa8ff"))
			var r2: float = clampf(pl.pat / pl.max_pat, 0.0, 1.0)
			_row(x, y + 78, "ВРЕМЯ", "%d с" % maxi(0, ceili(pl.pat)), r2, TEAL if r2 > 0.4 else RED)
		y += 108.0

func _row(x: float, y: float, label: String, val: String, v: float, col: Color) -> void:
	_text(label, Vector2(x + 14, y + 8), 10, DIM)
	_bar(Rect2(x + 78, y + 1, 120, 7), v, col)
	_text(val, Vector2(x + 204, y + 9), 11, TXT, null, 48, HORIZONTAL_ALIGNMENT_RIGHT)

func _feed() -> void:
	var y := 94.0
	for f in game.feed:
		var al := clampf(f.t, 0.0, 1.0)
		var tag: String = f.tag
		var s: String = f.text
		var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var w := minf(420.0, tw + 30.0 + (font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0 if tag != "" else 0.0))
		_panel(Rect2(16, y, w, 28), Color(0.04, 0.06, 0.09, 0.55 * al), 7.0)
		var c: Color = f.color
		_rrect(Rect2(16, y + 5, 3, 18), Color(c, al), 2.0)
		var tx := 28.0
		if tag != "":
			_text(tag, Vector2(tx, y + 18), 10, Color(DIM, al))
			tx += font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
		_text(s, Vector2(tx, y + 19), 14, Color(TXT, al))
		y += 33.0

func _prompt() -> void:
	draw_circle(Vector2(640, 360), 2.5, Color(1, 1, 1, 0.9))
	draw_arc(Vector2(640, 360), 8.0, 0, TAU, 28, Color(1, 1, 1, 0.28), 1.5)
	if game.workers.is_empty():
		return
	var w: Worker = game.workers[0]
	var hint: String = game.hint_for(w)
	if hint != "":
		var key := "ПРОБЕЛ"
		var txt := hint
		if hint.begins_with("[Пробел] "):
			txt = hint.substr(9)
		elif hint.begins_with("Держи [Пробел] — "):
			txt = "держи: " + hint.substr(17)
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		var kw := maxf(34.0, font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0)
		var total := kw + 12.0 + tw
		var x0 := 640.0 - total / 2.0
		_panel(Rect2(x0 - 14, 628, total + 28, 46), Color(0.04, 0.06, 0.09, 0.66), 12.0)
		_key(key, Vector2(x0, 636))
		_text(txt, Vector2(x0 + kw + 12.0, 658), 17, TXT)
	if w.item != "":
		var names := {"bag": "чемодан", "coffee": "кофе", "burger": "бургер"}
		_panel(Rect2(16, 676, 168, 28), Color(0.04, 0.06, 0.09, 0.62), 8.0)
		_text("В РУКАХ", Vector2(28, 694), 10, DIM)
		_text(names.get(w.item, w.item), Vector2(88, 695), 14, TXT, bold)

# ---------- меню и финал ----------
func _menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 250), Color(0.02, 0.04, 0.07, 0.62))
	draw_rect(Rect2(0, 560, 1280, 160), Color(0.02, 0.04, 0.07, 0.72))
	_ctext("ЗАДЕРЖКА РЕЙСА", 640, 128, 76, TXT, bold)
	_rrect(Rect2(540, 148, 200, 3), AMBER, 2.0)
	_ctext("Наземная служба большого аэропорта. Самолёты не ждут. Пилоты — тем более.", 640, 196, 20, DIM)
	for i in 4:
		var sp: Vector2 = game.to_screen(game.menu_spot(i), 0.0)
		if sp.x < -1000.0:
			continue
		_ctext(Cfg.ROLES[i].name, sp.x, sp.y + 28, 14, Cfg.PLAYER_COLORS[i], bold)
	var cx := 640.0
	_ctext("Нажми  ПРОБЕЛ  чтобы начать смену", cx, 606, 24, TXT, bold)
	var kx := 330.0
	var y := 636.0
	for item in [["W A S D", "ходить"], ["МЫШЬ", "смотреть"], ["ПРОБЕЛ", "взять / отдать"], ["ESC", "курсор"]]:
		var w := _key(item[0], Vector2(kx, y))
		_text(item[1], Vector2(kx + w + 8, y + 20), 13, DIM)
		kx += w + 8 + font.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 30
	_ctext("Кофе успокаивает пилота и диспетчера, бургер — качка. У крыла держи ПРОБЕЛ — заправка.", cx, 686, 13, DIM)
	_ctext("Модели: BAe-146 — S. Kurniawan (CC BY) · терминал — soysascha (CC BY) · Poly by Google (CC BY) · Quaternius, Kenney (CC0)", cx, 708, 10, Color(DIM, 0.6))

func _end() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
	_panel(Rect2(380, 150, 520, 360), Color(0.04, 0.06, 0.09, 0.9), 16.0)
	var bad: bool = game.anger >= 100.0
	_ctext("СМЕНА ОКОНЧЕНА" if not bad else "АЭРОПОРТ ЗАКРЫТ", 640, 206, 30, RED if bad else TXT, bold)
	_ctext(game.reason, 640, 236, 14, DIM)
	_ctext("%d" % game.score, 640, 330, 72, AMBER, bold)
	_ctext("ОЧКОВ", 640, 352, 12, DIM)
	_ctext("Вылетов: %d      Успокоено: %d" % [game.departed, game.calmed], 640, 400, 18, TXT)
	var s: int = game.score
	var rank := "Король перрона" if s > 1200 else ("Опытный диспетчер перрона" if s > 700 else ("Стажёр" if s > 300 else "Лучше бы вы пошли на кассу"))
	_ctext(rank, 640, 450, 22, TEAL, bold)
	_ctext("R — в меню", 640, 490, 13, DIM)
