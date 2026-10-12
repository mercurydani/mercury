class_name GhostSheet
extends Node3D
## Милый призрак-простыня: появляется рядом с игроком, плывёт к нему и пугает (толчок, не вред). Исчезает сам.

@export var speed_by_tier: PackedFloat32Array = PackedFloat32Array([1.8, 2.8, 4.0])
@export var lifetime: float = 7.0

var _target: Player
var _life := 0.0
var _t := 0.0
var _hit := false


func _ready() -> void:
	add_to_group("ghost")
	visible = false


func appear(p: Player) -> void:
	_target = p
	_life = lifetime
	_hit = false
	var back := Vector3(0, 0, 1).rotated(Vector3.UP, p.rotation.y)
	var pos := p.global_position + Vector3(rng(), 0, rng()).normalized() * 6.0
	global_position = Vector3(pos.x, p.global_position.y + 0.9, pos.z)
	visible = true
	scale = Vector3.ZERO
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_GHOST_APPEAR"), 2.2)


func rng() -> float:
	return randf_range(-1.0, 1.0)


func _physics_process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_life -= delta
	scale = scale.lerp(Vector3.ONE, minf(delta * 4.0, 1.0))
	if _life <= 0.0 or not is_instance_valid(_target):
		_vanish()
		return
	var loc := get_tree().get_first_node_in_group("location")
	var tier: int = loc.difficulty if loc else 0
	var spd := speed_by_tier[mini(tier, speed_by_tier.size() - 1)]
	var tgt := _target.global_position + Vector3(0, 0.9 + sin(_t * 2.0) * 0.2, 0)
	var d := tgt - global_position
	rotation.y = atan2(d.x, d.z)
	global_position += d.normalized() * minf(spd * delta, d.length())
	if not _hit and d.length() < 1.1:
		_hit = true
		var push := Vector3(d.x, 0, d.z).normalized() * 5.0 + Vector3(0, 2.0, 0)
		_target.linear_velocity += push
		var dr := get_tree().get_first_node_in_group("haunt")
		if dr and dr.has_method("scare_done"):
			dr.scare_done()
		if loc and loc.has_method("say"):
			loc.say(tr("MSG_GHOST_SCARE"), 2.2)
		_life = minf(_life, 1.0)


func _vanish() -> void:
	visible = false
	global_position = Vector3(0, -50, 0)
