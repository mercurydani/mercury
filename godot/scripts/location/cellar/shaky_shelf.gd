class_name ShakyShelf
extends Area3D
## Шаткая полка: от прыжков рядом трясётся и роняет банки (мягко толкают, не вредят).
## Зона Area вокруг стеллажа; банки падают из узлов Marker3D «Drop*».

@export var shake_needed: int = 2
@export var cooldown: float = 6.0

var _cd := 0.0
var _hits := 0
var _last_vy := {}
var _shake := 0.0
var _home := Vector3.ZERO
@onready var shelf: Node3D = get_node_or_null("Shelf")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	if shelf:
		_home = shelf.position


func _physics_process(delta: float) -> void:
	_cd = maxf(_cd - delta, 0.0)
	if _shake > 0.0:
		_shake -= delta
		if shelf:
			shelf.position = _home + Vector3(sin(_shake * 60.0) * 0.03, 0, 0)
			if _shake <= 0.0:
				shelf.position = _home
	for b in get_overlapping_bodies():
		if b is Player:
			var vy := (b as Player).linear_velocity.y
			if vy > 4.0 and _last_vy.get(b, 0.0) <= 4.0 and _cd <= 0.0:
				_hits += 1
				_shake = 0.5
				if _hits >= shake_needed:
					_hits = 0
					_cd = cooldown
					_drop(b)
			_last_vy[b] = vy


func _drop(p: Player) -> void:
	var loc := get_tree().get_first_node_in_group("location")
	if loc and loc.has_method("say"):
		loc.say(tr("MSG_JARS"), 2.2)
	for c in get_children():
		if c is Marker3D and String(c.name).begins_with("Drop"):
			var jar := RigidBody3D.new()
			jar.mass = 0.4
			jar.collision_layer = 1
			jar.collision_mask = 1
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = 0.1
			sh.height = 0.26
			cs.shape = sh
			jar.add_child(cs)
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.1
			cm.bottom_radius = 0.1
			cm.height = 0.26
			cm.radial_segments = 8
			mi.mesh = cm
			mi.material_override = LocUtil.mat(Color.from_hsv(randf(), 0.5, 0.6, 0.9), 0.3)
			jar.add_child(mi)
			var host := get_tree().get_first_node_in_group("location")
			host.add_child(jar)
			jar.global_position = (c as Node3D).global_position
			jar.linear_velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			jar.contact_monitor = true
			jar.max_contacts_reported = 2
			jar.body_entered.connect(func(bd: Node) -> void:
				if bd is Player:
					(bd as Player).linear_velocity += (bd.global_position - jar.global_position).normalized() * 4.0 + Vector3(0, 1.5, 0))
			get_tree().create_timer(5.0).timeout.connect(jar.queue_free)
