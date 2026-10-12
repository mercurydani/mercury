class_name Cfg
# Логические координаты — «пиксели»: x = вглубь от терминала, y = вдоль терминала.
# В сцене: X = y * K, Z = x * K (терминал в z≈2, перрон, рулёжка, полоса).

const W := 1280
const H := 720
const K := 0.02
const SHIFT := 180.0
const PX := 480.0                           # центр стоянки (x)
const ROWS := [260.0, 640.0, 1020.0]        # центры стоянок (y)
const TAXI_X := 800.0                       # линия рулёжки (x)
const SPAWN_Y := 1450.0                     # откуда выруливают самолёты (y)
const BELT := Rect2(250, 15, 240, 90)       # багажная лента (x, y, глубина, ширина)
const COFFEE := Vector2(150, 1225)
const BURGER := Vector2(150, 60)
const DOOR_OFF := Vector2(150, 70)          # багажный люк относительно центра самолёта
const FUEL_OFF := Vector2(30, 110)          # заправка под крылом
const BOUNDS := Rect2(110, 25, 700, 1230)
const SPEED := 215.0

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
