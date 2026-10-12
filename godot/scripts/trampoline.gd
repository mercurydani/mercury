extends Area3D
## Батут для паркура: подбрасывает тела, зашедшие в зону.

@export var bounce_impulse: float = 14.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		(body as RigidBody3D).linear_velocity.y = bounce_impulse
