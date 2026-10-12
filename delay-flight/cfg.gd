class_name Cfg
# Логические координаты — «пиксели»: x = вглубь от терминала, y = вдоль терминала.
# В сцене: X = y * K, Z = x * K. ЕДИНИЦА МИРА = 3 м (человек ≈ 0.6, самолёт-«Airbus» ≈ 12.5, терминал 360 м).

const W := 1280
const H := 720
const K := 0.02
const LREF := 14.8                          # эталонная длина самолёта: носы всегда у одной линии
const PERSON := 0.34                        # масштаб людей относительно «метра=единица»
const SHIFT := 180.0
const PX := 720.0                           # центр стоянки (x): z0 = 14.4, нос самолёта на z = 7
const ROWS := [550.0, 1500.0, 2450.0]       # центры стоянок (y): X = 11, 30, 49 (шаг 57 м)
const TAXI_X := 1700.0                      # рулёжка (x): z = 34
const SPAWN_Y := 5400.0                     # откуда выруливают самолёты (y)
const BELT := Rect2(20, 985, 440, 80)       # левая лента: из терминала (z=0.4) к стоянкам (z=9.2)
const BELTS := [Rect2(20, 985, 440, 80), Rect2(20, 1935, 440, 80)]
const BELT_SPEED := 75.0                    # скорость ленты, px/с
const COFFEE := Vector2(170, 1190)
const BURGER := Vector2(170, 2150)
const DOOR_OFF := Vector2(225, 80)           # багажный люк относительно центра самолёта
const FUEL_OFF := Vector2(30, 230)           # заправка под крылом
const BOUNDS := Rect2(100, 20, 1600, 2900)
const SPEED := 190.0

const ROLES := [
	{"name": "Грузчик", "shirt": Color("3a4252"), "vest": Color("ff7a1a"), "hat": "helmet", "hat_col": Color("ffd24d"), "ears": true, "skin": Color("e8b48a")},
	{"name": "Заправщик", "shirt": Color("e9edf2"), "vest": Color("c6e61a"), "hat": "cap", "hat_col": Color("ffffff"), "ears": false, "skin": Color("c98e65")},
	{"name": "Маршалер", "shirt": Color("2b3345"), "vest": Color("ff4d2e"), "hat": "helmet", "hat_col": Color("f4f4f4"), "ears": true, "skin": Color("f1c9a5")},
	{"name": "Механик", "shirt": Color("3d7bd9"), "vest": Color("00000000"), "hat": "cap", "hat_col": Color("2b5fb3"), "ears": false, "skin": Color("8d5a3c")},
]
const PLAYER_COLORS := [Color("4da3ff"), Color("ffb347"), Color("7dff8a"), Color("ff7ad9")]

static func to3(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.y * K, h, p.x * K)

static func from3(v: Vector3) -> Vector2:
	return Vector2(v.z / K, v.x / K)
