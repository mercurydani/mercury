class_name Pigeon
extends Node3D
## Голубь. Сидит и кивает; «хулиган» время от времени пикирует на ближайшего игрока и сбивает его.

@export var hooligan: bool = false
@export var notice_range: float = 9.0
@export var cooldown: Vector2 = Vector2(6.0, 10.0)

enum S { SIT, FLY, RETURN }
var _s := S.SIT
var _home: Vector3
var _t := 0.0
var _wait := 3.0
var _from: Vector3
var _to: Vector3
var _fly_t := 0.0
var _hit_done := false
@onready var head: Node3D = get_node_or_null("Head")
@onready var wing_l: Node3D = get_node_or_null("WingL")
@onready var wing_r: Node3D = get_node_or_null("WingR")


func _ready() -> void:
	_home = global_position
	_wait = randf_range(cooldown.x * 0.4, cooldown.y)


func _process(delta: float) -> void:
	_t += delta
	if head and _s == S.SIT:
		head.rotation.x = 0.0 + maxf(0.0, sin(_t * 5.0 + get_index())) * 0.35
	var flap := 0.0
	if _s != S.SIT:
		flap = sin(_t * 30.0) * 0.9
	if wing_l:
		wing_l.rotation.z = flap
	if wing_r:
		wing_r.rotation.z = -flap


func _physics_process(delta: float) -> void:
	match _s:
		S.SIT:
			if not hooligan:
				return
			_wait -= delta
			if _wait <= 0.0:
				var p := _nearest_player()
				if p and p.global_position.distance_to(_home) < notice_range:
					_start_fly(p)
				else:
					_wait = 1.0
		S.FLY, S.RETURN:
			_fly_t += delta / 1.2
			var k := clampf(_fly_t, 0.0, 1.0)
			var pos := _from.lerp(_to, k)
			pos.y += sin(k * PI) * 1.6 * (1.0 if _s == S.FLY else 0.5)
			look_at_from_position(pos, pos + (_to - _from).normalized() * Vector3(1, 0, 1), Vector3.UP)
			if _s == S.FLY and not _hit_done:
				for p in get_tree().get_nodes_in_group("players"):
					var pp := p as Player
					if pp.global_position.distance_to(global_position) < 1.1:
						_hit_done = true
						var dir := (_to - _from) * Vector3(1, 0, 1)
						pp.linear_velocity += dir.normalized() * 6.5 + Vector3(0, 3.0, 0)
						var loc := get_tree().get_first_node_in_group("location")
						if loc and loc.has_method("say"):
							loc.say(tr("MSG_PIGEON"), 2.0)
			if k >= 1.0:
				if _s == S.FLY:
					_s = S.RETURN
					_from = global_position
					_to = _home
					_fly_t = 0.0
				else:
					_s = S.SIT
					rotation = Vector3.ZERO
					_wait = randf_range(cooldown.x, cooldown.y)


func _start_fly(p: Node3D) -> void:
	_s = S.FLY
	_from = global_position
	var dir := ((p.global_position + Vector3(0, 0.9, 0)) - _from)
	_to = _from + dir * 1.5
	_fly_t = 0.0
	_hit_done = false


func _nearest_player() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for p in get_tree().get_nodes_in_group("players"):
		var d := (p as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = p
	return best
