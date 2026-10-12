extends SceneTree
# «Прогулка»: сценарный проход игрока по аэропорту (для записи видео --write-movie).

const FPS := 20.0
# [время, x_глубина, y_вдоль, yaw, pitch]
const KEYS := [
	[0.0, 700.0, 765.0, 0.0, 0.40],
	[3.5, 700.0, 765.0, 0.0, 0.38],
	[5.5, 700.0, 765.0, PI, 0.02],
	[9.5, 900.0, 765.0, PI, 0.03],
	[11.5, 900.0, 765.0, PI * 0.5, 0.06],
	[14.0, 900.0, 765.0, PI * 0.5, 0.06],
	[16.0, 900.0, 765.0, PI, 0.03],
	[18.0, 900.0, 765.0, PI * 1.5, 0.06],
	[20.0, 900.0, 765.0, PI * 1.5, 0.06],
	[22.0, 900.0, 765.0, 0.0, 0.05],
	[27.0, 220.0, 765.0, 0.0, 0.12],
	[29.0, 170.0, 765.0, PI * 1.5, 0.1],
	[35.0, 170.0, 1270.0, PI * 1.5, 0.1],
	[37.0, 170.0, 1270.0, PI * 1.2, 0.12],
	[40.0, 170.0, 1270.0, PI * 1.0, 0.1],
]

var main: Node
var frame := 0
var w: Worker
var max_frames := 0

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	max_frames = int(KEYS[KEYS.size() - 1][0] * FPS)
	if OS.get_cmdline_user_args().size() > 0:
		max_frames = int(OS.get_cmdline_user_args()[0])

func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)

func _process(_delta: float) -> bool:
	if frame == 2:
		main.start_game(1)
		w = main.workers[0]
		main.anger = 0.0
		for i in 3:
			main.spawn_plane()
	if w != null:
		var t := frame / FPS
		var a: Array = KEYS[0]
		var b: Array = KEYS[0]
		for i in KEYS.size() - 1:
			if t >= KEYS[i][0] and t <= KEYS[i + 1][0]:
				a = KEYS[i]
				b = KEYS[i + 1]
		if t > KEYS[KEYS.size() - 1][0]:
			a = KEYS[KEYS.size() - 1]
			b = a
		var u := 0.0 if b[0] == a[0] else _smooth(clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0))
		w.pos = Vector2(lerpf(a[1], b[1], u), lerpf(a[2], b[2], u))
		w.yaw = lerp_angle(a[3], b[3], u)
		w.pitch = lerpf(a[4], b[4], u)
		main.anger = 0.0
		main.time_left = 170.0
	frame += 1
	return frame > max_frames
