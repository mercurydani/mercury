extends Node3D
## Корень сцены лобби: связывает зоны с логикой, HUD и пока одиночный игрок.

var money: int = 0

@onready var player: Player = $Players/Player1
@onready var van: Van = $Van
@onready var mascot: Mascot = $Mascot
@onready var hint: Label = $HUD/Hint
@onready var toast: Label = $HUD/Toast
@onready var money_label: Label = $HUD/Money
var _toast_t: float = 0.0


func _ready() -> void:
	Texts.register()
	_setup_input()
	player.prompt_changed.connect(func(t: String) -> void: hint.text = t)
	van.message.connect(_show)
	mascot.message.connect(_show)
	van.mission_requested.connect(func() -> void: print("mission requested"))
	$Van/SeatTrigger.interacted.connect(func(p: Node3D) -> void: van.toggle_seat(p))
	$Van/Dashboard.interacted.connect(func(p: Node3D) -> void: van.request_search(p))
	$Van/ToolWall.interacted.connect(func(_p: Node3D) -> void: _show(tr("MSG_TOOLS_STUB")))
	$Stall/Trigger.interacted.connect(func(_p: Node3D) -> void: _show(tr("MSG_SHOP_STUB")))
	$SlotMachine/Trigger.interacted.connect(func(_p: Node3D) -> void: _show(tr("MSG_SLOT_STUB")))
	$Mascot/Trigger.interacted.connect(func(p: Node3D) -> void: mascot.pet(p))
	player.checkpoint_reached.connect(func(i: int) -> void: _show(tr("MSG_CHECKPOINT") % (i + 1)))
	$Parkour/Prize.collected.connect(func(_p: Node3D) -> void: _show(tr("MSG_PRIZE")))
	_update_money()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			toast.text = ""


func add_money(amount: int) -> void:
	money += amount
	_update_money()


func _update_money() -> void:
	money_label.text = tr("HUD_MONEY") % money


func _show(text: String) -> void:
	toast.text = text
	_toast_t = 3.0


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
