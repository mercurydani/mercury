class_name FountainJet
extends Area3D
## Струи фонтана: по таймеру бьют вверх и подбрасывают игрока, который стоит рядом.

@export var period: float = 5.0
@export var burst: float = 1.4
@export var lift: float = 9.5
@export var message_key: String = "MSG_JET"

var _t := 0.0
var _hit := {}
@onready var jets: Node3D = get_node_or_null("Jets")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	_t = randf() * period


func _physics_process(delta: float) -> void:
	_t += delta
	var ph := fposmod(_t, period)
	var on := ph > period - burst
	if jets:
		jets.visible = on or ph > period - burst - 0.5
		jets.scale.y = 1.0 if on else 0.35
	if not on:
		_hit.clear()
		return
	for b in get_overlapping_bodies():
		if b is Player and not _hit.has(b):
			_hit[b] = true
			(b as Player).linear_velocity.y = lift
			var loc := get_tree().get_first_node_in_group("location")
			if loc and loc.has_method("say"):
				loc.say(tr(message_key), 2.0)
