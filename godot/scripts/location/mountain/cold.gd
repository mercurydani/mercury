class_name Cold
extends Node
## Холод: вне тёплых зон (группа "warm", метаданные radius) руки замерзают и игрок постепенно замедляется (до 50% скорости).
## У костра и в домике отогревается. Скорость замерзания по сложности.

@export var rate_by_tier: PackedFloat32Array = PackedFloat32Array([0.007, 0.011, 0.018])   # доля в секунду
@export var warm_rate: float = 0.12
@export var max_slow: float = 0.5

var level := 0.0
var _orig := {}
var _label: Label
var _warned := false


func _ready() -> void:
	var hud := get_parent().get_node_or_null("HUD")
	if hud:
		_label = Label.new()
		_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_label.position = Vector2(-260, 16)
		_label.add_theme_font_size_override("font_size", 24)
		hud.add_child(_label)


func in_warm(pos: Vector3) -> bool:
	for w in get_tree().get_nodes_in_group("warm"):
		if (w as Node3D).global_position.distance_to(pos) < float((w as Node3D).get_meta("radius", 6.0)):
			return true
	return false


func _physics_process(delta: float) -> void:
	var loc := get_tree().get_first_node_in_group("location")
	var tier: int = loc.difficulty if loc else 0
	var rate := rate_by_tier[mini(tier, rate_by_tier.size() - 1)]
	for n in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p == null or p.seated:
			continue
		if not _orig.has(p):
			_orig[p] = p.move_speed
		if in_warm(p.global_position):
			level = maxf(level - warm_rate * delta, 0.0)
			_warned = false
		else:
			level = minf(level + rate * delta, 1.0)
		p.move_speed = _orig[p] * (1.0 - max_slow * level)
		if level > 0.6 and not _warned:
			_warned = true
			if loc and loc.has_method("say"):
				loc.say(tr("MSG_COLD"), 3.0)
	if _label:
		var f := tr("COLD_LABEL")
		_label.text = (f % int(level * 100.0)) if f.contains("%") else "%s %d%%" % [f, int(level * 100.0)]
