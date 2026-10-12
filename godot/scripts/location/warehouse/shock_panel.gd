class_name ShockPanel
extends Area3D
## Искрящий электрощит. Цикл: тихо, потом дуга 1.2 с: искры, вспышка, бьёт током (отбрасывает) тех, кто рядом.
## Дуга предупреждает потрескиванием света заранее (windup).

@export var period: float = 4.0
@export var windup: float = 1.0
@export var arc_time: float = 1.2
@export var push_force: float = 9.0

var _t := 0.0
var _hit := {}
@onready var light: OmniLight3D = get_node_or_null("Light")
@onready var sparks: CPUParticles3D = get_node_or_null("Sparks")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_t = randf() * period


func _arcing() -> bool:
	var ph := fposmod(_t, period)
	return ph > period - arc_time


func _physics_process(delta: float) -> void:
	_t += delta
	var ph := fposmod(_t, period)
	var arc := ph > period - arc_time
	var warn := ph > period - arc_time - windup and not arc
	if sparks:
		sparks.emitting = arc or warn
		sparks.amount = 40 if arc else 6
	if light:
		light.light_energy = (3.5 + randf() * 3.0) if arc else ((0.8 + randf() * 1.2) if warn else 0.15)
	if not arc:
		_hit.clear()
		return
	for b in get_overlapping_bodies():
		if b is Player and not _hit.has(b):
			_hit[b] = true
			(b as Player).linear_velocity += (b.global_position - global_position).normalized() * push_force + Vector3(0, 4.5, 0)
			var loc := get_tree().get_first_node_in_group("location")
			if loc and loc.has_method("say"):
				loc.say(tr("MSG_SHOCK"), 2.5)
