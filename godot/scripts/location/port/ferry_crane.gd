class_name FerryCrane
extends MovingPlatform
## Контейнер на тросах портального крана: ходит между двумя берегами, пока рычаг включён.
## Рычаги — Interactable из группы "ferry_lever" (по одному на каждом берегу). На концах стоит пару секунд,
## чтобы можно было сойти. Кинематическое тело, игрока «везёт» platform_velocity.

@export var from_pos: Vector3 = Vector3.ZERO     # локальные координаты родителя
@export var to_pos: Vector3 = Vector3(0, 0, -10)
@export var speed: float = 1.8
@export var dwell: float = 3.0
@export var speed_by_tier: PackedFloat32Array = PackedFloat32Array([1.6, 2.0, 2.6])
@export var running := false

var _dir := 1.0
var _wait := 0.0
var _speed_mul := 1.0
var _levers: Array = []


func _ready() -> void:
	sync_to_physics = true
	position = from_pos
	for n in get_tree().get_nodes_in_group("ferry_lever"):
		_levers.append(n)
		(n as Interactable).interacted.connect(func(_p: Node3D) -> void: toggle())
	_refresh()


func apply_tier(t: int) -> void:
	if speed_by_tier.size() > t:
		speed = speed_by_tier[t]


func toggle() -> void:
	running = not running
	_refresh()
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_FERRY_ON" if running else "MSG_FERRY_OFF"), 2.0)


func _refresh() -> void:
	for l in _levers:
		var h := (l as Node).get_node_or_null("Handle") as Node3D
		if h:
			h.rotation.x = deg_to_rad(-35.0 if running else 35.0)
		var lamp := (l as Node).get_node_or_null("Lamp") as MeshInstance3D
		if lamp:
			var m := StandardMaterial3D.new()
			var c := Color(0.2, 1.0, 0.3) if running else Color(1.0, 0.2, 0.15)
			m.albedo_color = c
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 2.0
			lamp.material_override = m


func _physics_process(delta: float) -> void:
	var target := to_pos if _dir > 0.0 else from_pos
	var new_pos := position
	if running:
		if _wait > 0.0:
			_wait -= delta
		else:
			var d := target - position
			var step := speed * delta
			if d.length() <= step:
				new_pos = target
				_dir = -_dir
				_wait = dwell
			else:
				new_pos = position + d.normalized() * step
	platform_velocity = (new_pos - position) / delta
	position = new_pos
