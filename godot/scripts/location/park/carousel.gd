class_name Carousel
extends Node3D
## Вращающийся диск карусели. Сектора (AnimatableBody3D) вращаются вокруг оси узла и каждый отдаёт игроку
## свою линейную скорость (platform_velocity), чтобы его «везло». Узлы с именем Spin* (лошадки, кровля) вращаются синхронно.
## Центр вращения — позиция узла, ось Y.

@export var speed: float = 0.5   # рад/с, знак задаёт направление
@export var message_key: String = "MSG_CAROUSEL"

var _angle := 0.0
var _sectors: Array = []
var _spins: Array[Node3D] = []
var _rest := {}
var _warned := false


func _ready() -> void:
	for c in get_children():
		if c is CarouselSector:
			_sectors.append(c)
			_rest[c] = c.transform
		elif c is Node3D and String(c.name).begins_with("Spin"):
			_spins.append(c)
	for s in _sectors:
		(s as AnimatableBody3D).sync_to_physics = true


func _physics_process(delta: float) -> void:
	_angle += speed * delta
	var basis_rot := Basis(Vector3.UP, _angle)
	for s in _sectors:
		var rest: Transform3D = _rest[s]
		var sec := s as CarouselSector
		sec.transform = Transform3D(basis_rot, Vector3.ZERO) * rest
		var rel := basis_rot * sec.centroid
		sec.platform_velocity = Vector3(rel.z, 0.0, -rel.x) * speed
	for sp in _spins:
		sp.rotation.y = _angle
	if not _warned and absf(speed) > 0.01:
		for p in get_tree().get_nodes_in_group("players"):
			if (p as Node3D).global_position.distance_to(global_position) < 10.0:
				_warned = true
				var loc := get_tree().get_first_node_in_group("location")
				if loc and loc.has_method("say"):
					loc.say(tr(message_key), 2.5)
				get_tree().create_timer(12.0).timeout.connect(func() -> void: _warned = false)
				break
