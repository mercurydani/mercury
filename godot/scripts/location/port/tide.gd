class_name Tide
extends Node
## Прилив: уровень воды (узел по water_path) плавно поднимается и опускается. Узлы группы "tide_deck"
## (низкие понтоны) уходят под воду: коллизия выключается, пока вода выше их настила.

@export var low_y: float = -1.1
@export var high_y: float = -0.1
@export var cycle: Vector4 = Vector4(14.0, 4.0, 6.0, 4.0)   # низкая вода, подъём, высокая, спад (с)
@export var deck_top: float = -0.3

var _t := 0.0
var _decks_on := true
var _warned := false
@export var water_path: NodePath
@onready var water: Node3D = get_node_or_null(water_path) as Node3D


func _ready() -> void:
	_t = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		_reset()


func _reset() -> void:
	_t = 0.0
	_warned = false
	_decks_on = true
	if water:
		water.position.y = low_y
	for d in get_tree().get_nodes_in_group("tide_deck"):
		for c in (d as Node).find_children("*", "CollisionShape3D", true, false):
			(c as CollisionShape3D).set_deferred("disabled", false)
		(d as Node3D).visible = true


func _process(delta: float) -> void:
	_t += delta
	var total := cycle.x + cycle.y + cycle.z + cycle.w
	var ph := fposmod(_t, total)
	var k := 0.0
	if ph < cycle.x:
		k = 0.0
	elif ph < cycle.x + cycle.y:
		k = smoothstep(0.0, 1.0, (ph - cycle.x) / cycle.y)
	elif ph < cycle.x + cycle.y + cycle.z:
		k = 1.0
	else:
		k = 1.0 - smoothstep(0.0, 1.0, (ph - cycle.x - cycle.y - cycle.z) / cycle.w)
	var y := lerpf(low_y, high_y, k)
	if water:
		water.position.y = y + sin(_t * 1.3) * 0.03
	var under := y > deck_top - 0.05
	if under != not _decks_on:
		_decks_on = not under
		for d in get_tree().get_nodes_in_group("tide_deck"):
			for c in (d as Node).find_children("*", "CollisionShape3D", true, false):
				(c as CollisionShape3D).set_deferred("disabled", under)
			(d as Node3D).visible = not under
	if k > 0.5 and not _warned:
		_warned = true
		var loc := get_tree().get_first_node_in_group("location")
		if loc and loc.has_method("say"):
			loc.say(tr("MSG_TIDE"), 2.5)
	elif k < 0.1:
		_warned = false
