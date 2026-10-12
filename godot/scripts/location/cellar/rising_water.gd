class_name RisingWater
extends Node3D
## Потоп: уровень воды поднимается от low_y до high_y за rise_time (по сложности). Замедляет игрока по глубине,
## глубже head_depth топит через drown_time. Старт — когда захлопнется дверь (DoorSlam) или через fallback.
## Дочерний узел Surface — плоскость воды.

@export var low_y: float = -0.25
@export var high_y: float = 2.3
@export var rise_time_by_tier: PackedFloat32Array = PackedFloat32Array([360.0, 260.0, 190.0])
@export var wade_slow: float = 0.22
@export var head_depth: float = 1.6
@export var drown_time: float = 2.0
@export var delay: float = 6.0
@export var fallback_start: float = 30.0

var level := 0.0           # 0..1
var started := false
var _t := 0.0
var _orig_speed := {}
var _orig_accel := {}
var _drown := {}
var _next_msg := 0
var _label: Label
var _linked := false
@onready var surface: Node3D = get_node_or_null("Surface")


func _ready() -> void:
	add_to_group("flood")
	var hud := get_parent().get_node_or_null("HUD")
	if hud:
		_label = Label.new()
		_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_label.position = Vector2(-260, 16)
		_label.add_theme_font_size_override("font_size", 24)
		hud.add_child(_label)
	_apply()


func current_y() -> float:
	return lerpf(low_y, high_y, level)


func _apply() -> void:
	if surface:
		surface.position.y = low_y + (high_y - low_y) * level
	if _label:
		var f := tr("FLOOD_LABEL")
		_label.text = (f % int(level * 100.0)) if f.contains("%") else "%s %d%%" % [f, int(level * 100.0)]


func reset() -> void:
	level = 0.0
	_t = 0.0
	_next_msg = 0
	started = false
	_apply()


func _physics_process(delta: float) -> void:
	_t += delta
	if not _linked:
		_linked = true
		for d in get_tree().get_nodes_in_group("door_slam"):
			d.slammed.connect(func() -> void: started = true)
	if not started and _t > fallback_start:
		started = true
	var loc := get_tree().get_first_node_in_group("location")
	var tier: int = loc.difficulty if loc else 0
	if started:
		var total := rise_time_by_tier[mini(tier, rise_time_by_tier.size() - 1)]
		if delay > 0.0:
			delay -= delta
		else:
			level = minf(level + delta / total, 1.0)
		_apply()
		var marks := [0.25, 0.5, 0.8]
		var keys := ["MSG_FLOOD_25", "MSG_FLOOD_50", "MSG_FLOOD_80"]
		if _next_msg < marks.size() and level >= marks[_next_msg]:
			if loc and loc.has_method("say"):
				loc.say(tr(keys[_next_msg]), 3.0)
			_next_msg += 1
	var wy := current_y()
	for n in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p == null or p.seated:
			continue
		var d := wy - p.global_position.y
		if d > 0.15:
			if not _orig_speed.has(p):
				_orig_speed[p] = p.move_speed
				_orig_accel[p] = p.accel
			p.move_speed = _orig_speed[p] * clampf(1.0 - d * wade_slow, 0.3, 1.0)
			p.accel = _orig_accel[p] * 0.4
			if d > head_depth:
				_drown[p] = _drown.get(p, 0.0) + delta
				if _drown[p] > drown_time:
					_do_drown(p)
			else:
				_drown[p] = maxf(_drown.get(p, 0.0) - delta, 0.0)
		elif _orig_speed.has(p):
			_leave(p)


func _leave(p: Player) -> void:
	if _orig_speed.has(p):
		p.move_speed = _orig_speed[p]
		_orig_speed.erase(p)
	if _orig_accel.has(p):
		p.accel = _orig_accel[p]
		_orig_accel.erase(p)
	_drown.erase(p)


func _do_drown(p: Player) -> void:
	_drown[p] = 0.0
	_ring(p.global_position)
	_leave(p)
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_DROWNED"))
	if loc and loc.has_signal("player_fell"):
		loc.player_fell.emit(p)
	p.respawn()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		for p in _orig_speed.keys():
			_leave(p)


func _ring(pos: Vector3) -> void:
	var ring := Node3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.35
	tm.outer_radius = 0.7
	tm.rings = 24
	tm.ring_segments = 12
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = LocUtil.mat(Color(1.0, 0.85, 0.15), 0.4)
	ring.add_child(mi)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.3
	hs.height = 0.6
	head.mesh = hs
	head.material_override = LocUtil.mat(Color(1.0, 0.85, 0.15), 0.4)
	head.position = Vector3(0, 0.4, 0.55)
	ring.add_child(head)
	get_parent().add_child(ring)
	ring.global_position = Vector3(pos.x, current_y() + 0.05, pos.z)
	get_tree().create_timer(8.0).timeout.connect(ring.queue_free)
