class_name SpinningBlade
extends AnimatableBody3D
## Крутящиеся лопасти крышного вентилятора. Толкают игрока физикой (AnimatableBody3D).

@export var speed: float = 2.4  # рад/с
@export var axis: Vector3 = Vector3.UP


func _physics_process(delta: float) -> void:
	rotate(axis.normalized(), speed * delta)
