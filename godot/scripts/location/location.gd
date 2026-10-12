class_name Location
extends Node3D
## База сцены миссии: ввод, HUD, зона падения, сложность и выбор места кота.
## Опасности помечены группой "hazard" и метой "tier" (0 — есть всегда, 1 — со средней, 2 — только на сложной).
## Всё на хосте: клиенты получат результаты синхронизацией (сеть позже).

signal player_fell(player: Node3D)
signal cat_rescued

@export var title_key: String = "LOC_ROOF"
## 0 простая, 1 средняя, 2 сложная (lobby.md 6б, locations.md 6)
@export_range(0, 2) var difficulty: int = 0
@export var kill_height: float = -9.0
@export var random_cat_spot: bool = false

var _toast_t: float = 0.0
@onready var player: Player = $Players/Player1
@onready var hint: Label = $HUD/Hint
@onready var toast: Label = $HUD/Toast
@onready var title: Label = $HUD/Title


func _ready() -> void:
	add_to_group("location")
	Texts.register()
	LocationTexts.register()
	_setup_input()
	player.prompt_changed.connect(func(t: String) -> void: hint.text = t)
	player.checkpoint_reached.connect(func(_i: int) -> void: say(tr("MSG_CHECKPOINT_ROOF")))
	apply_difficulty(difficulty)
	if has_node("Cat"):
		$Cat.rescued.connect(_on_rescued)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast.text = ""
	for p in get_tree().get_nodes_in_group("players"):
		if p is Player and not p.seated and p.global_position.y < kill_height:
			_on_fell(p)


func say(text: String, seconds := 3.0) -> void:
	toast.text = text
	_toast_t = seconds


func _on_fell(p: Player) -> void:
	player_fell.emit(p)
	say(tr("MSG_FELL"))
	p.respawn()


func _on_rescued(_p: Node3D) -> void:
	say(tr("MSG_RESCUED"), 5.0)
	cat_rescued.emit()


## Включает опасности по tier и ставит кота на место для данной сложности.
func apply_difficulty(d: int) -> void:
	difficulty = d
	if title:
		title.text = "%s · %s" % [tr(title_key), tr("LOC_DIFFICULTY") % tr("DIFF_%d" % d)]
	for h in get_tree().get_nodes_in_group("hazard"):
		var on: bool = int(h.get_meta("tier", 0)) <= d and d <= int(h.get_meta("tier_max", 2))
		_set_active(h, on)
	for w in get_tree().get_nodes_in_group("water"):
		(w as WaterBody).set_tier(d)
	for w in get_tree().get_nodes_in_group("wind"):
		var g := w as WindGust
		if g.strength_by_tier.size() > d:
			g.strength = g.strength_by_tier[d]
	_place_cat(d)


func _set_active(n: Node, on: bool) -> void:
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if n is Node3D:
		(n as Node3D).visible = on
	for c in n.find_children("*", "CollisionObject3D", true, false):
		for s in c.get_children():
			if s is CollisionShape3D:
				(s as CollisionShape3D).set_deferred("disabled", not on)
	if n is CollisionObject3D:
		for s in n.get_children():
			if s is CollisionShape3D:
				(s as CollisionShape3D).set_deferred("disabled", not on)


func _place_cat(d: int) -> void:
	var spots := get_node_or_null("CatSpots")
	var cat := get_node_or_null("Cat") as Node3D
	if spots == null or cat == null or spots.get_child_count() == 0:
		return
	var idx := mini(d, spots.get_child_count() - 1)
	if random_cat_spot:
		idx = randi() % (mini(d, spots.get_child_count() - 1) + 1)
	var spot := spots.get_child(idx) as Node3D
	cat.global_transform = spot.global_transform


func _setup_input() -> void:
	var map := {
		"move_forward": KEY_W, "move_back": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "interact": KEY_E, "respawn": KEY_R,
		"cam_left": KEY_LEFT, "cam_right": KEY_RIGHT,
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = map[action]
			InputMap.action_add_event(action, ev)
