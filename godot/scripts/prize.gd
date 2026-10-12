extends Area3D
## Приз на финише паркура (подушка с логотипом студии). Касание = достижение.

signal collected(player: Node3D)

var _taken := {}


func _ready() -> void:
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player and not _taken.has(b):
			_taken[b] = true
			collected.emit(b))


func _process(delta: float) -> void:
	$Visual.rotate_y(delta * 1.5)
