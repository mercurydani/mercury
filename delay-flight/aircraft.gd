class_name Aircraft
extends Node2D
# Самолёт на стоянке: ждёт багаж и топливо.

var row := 0
var state := "arriving"   # arriving | ready | leaving
var bags := 0
var need := 3
var fuel := 0.0
var pat := 40.0
var max_pat := 40.0
var delayed := false
var livery := Color("e63946")
var flight := "SU 100"
var blink := 0.0

func door_pt() -> Vector2:
	return position + Vector2(-130, 0)

func fuel_pt() -> Vector2:
	return position + Vector2(80, 0)

func _process(delta: float) -> void:
	blink += delta
	queue_redraw()

func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)

func _draw() -> void:
	var tint := Color(1, 0.72, 0.72) if delayed else Color.WHITE
	Paint.ellipse(self, Vector2(16, 18), 185, 36, Color(0, 0, 0, 0.28))
	var wing := Color("d5dce6") * tint
	var edge := Color("aab4c3")
	for sy in [-1.0, 1.0]:
		_poly([Vector2(-14, 22 * sy), Vector2(38, 22 * sy), Vector2(112, 92 * sy), Vector2(82, 92 * sy)], wing)
		_poly([Vector2(130, 14 * sy), Vector2(168, 14 * sy), Vector2(188, 46 * sy), Vector2(166, 46 * sy)], wing)
		draw_circle(Vector2(18, 54 * sy), 14, Color("5d6778"))
		draw_circle(Vector2(18, 54 * sy), 8, Color("c2c9d4"))
		draw_line(Vector2(82, 88 * sy), Vector2(112, 88 * sy), edge, 2)
	# фюзеляж
	var body := Color("f6f8fb") * tint
	draw_rect(Rect2(-150, -26, 285, 52), body)
	draw_circle(Vector2(-150, 0), 26, body)
	_poly([Vector2(130, -26), Vector2(188, -8), Vector2(188, 8), Vector2(130, 26)], body)
	draw_rect(Rect2(-150, 9, 285, 7), livery)
	_poly([Vector2(150, -26), Vector2(188, -8), Vector2(188, 8), Vector2(150, 26)], livery)
	# окна и кабина
	draw_rect(Rect2(-172, -9, 14, 18), Color("1f3a5f"))
	for i in 15:
		draw_rect(Rect2(-118 + i * 15, -12, 7, 8), Color("5aa9ff"))
	draw_rect(Rect2(-137, -8, 14, 16), Color("5d6778"))
	draw_string(ThemeDB.fallback_font, Vector2(-60, 8), flight, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color("2b3345"))
	if delayed and int(blink * 3.0) % 2 == 0:
		draw_circle(Vector2(0, 0), 9, Color("ff2d2d"))
	if state != "ready":
		return
	_zone(Vector2(-130, 0), Color("ffd24d"), "чемоданы %d/%d" % [bags, need])
	_zone(Vector2(80, 0), Color("ff9f43"), "топливо %d%%" % int(fuel))
	var w := 240.0
	var r := clampf(pat / max_pat, 0.0, 1.0)
	Paint.round_rect(self, Rect2(-w / 2, -128, w, 12), Color(0, 0, 0, 0.55), 5)
	var col := Color("7dff8a") if r > 0.5 else (Color("ffd24d") if r > 0.25 else Color("ff5a4d"))
	if r > 0.0:
		Paint.round_rect(self, Rect2(-w / 2, -128, w * r, 12), col, 5)

func _zone(p: Vector2, col: Color, label: String) -> void:
	draw_arc(p, 36, 0, TAU, 28, col, 3.0)
	var font := ThemeDB.fallback_font
	draw_string_outline(font, p + Vector2(-70, 62), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, 5, Color.BLACK)
	draw_string(font, p + Vector2(-70, 62), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, Color.WHITE)
