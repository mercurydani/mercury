class_name Cfg

const W := 1280
const H := 720
const SHIFT := 180.0
const PX := 800.0
const ROWS := [215.0, 405.0, 595.0]
const BELT := Rect2(36, 250, 118, 250)
const COFFEE := Vector2(300, 176)
const BURGER := Vector2(300, 668)
const SPEED := 215.0

# Рабочие аэропорта: у каждого своя роль и экипировка.
const ROLES := [
	{"name": "Грузчик", "shirt": Color("3a4252"), "vest": Color("ff7a1a"), "hat": "helmet", "hat_col": Color("ffd24d"), "ears": true, "skin": Color("e8b48a")},
	{"name": "Заправщик", "shirt": Color("e9edf2"), "vest": Color("c6e61a"), "hat": "cap", "hat_col": Color("ffffff"), "ears": false, "skin": Color("c98e65")},
	{"name": "Маршалер", "shirt": Color("2b3345"), "vest": Color("ff4d2e"), "hat": "helmet", "hat_col": Color("f4f4f4"), "ears": true, "skin": Color("f1c9a5")},
	{"name": "Механик", "shirt": Color("3d7bd9"), "vest": Color("00000000"), "hat": "cap", "hat_col": Color("2b5fb3"), "ears": false, "skin": Color("8d5a3c")},
]
const PLAYER_COLORS := [Color("4da3ff"), Color("ffb347"), Color("7dff8a"), Color("ff7ad9")]
