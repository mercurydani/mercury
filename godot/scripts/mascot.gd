class_name Mascot
extends Node3D
## Золотой кот-талисман: машет лапкой, быстрее при приближении игрока.
## Погладка даёт «удачу»: +1.25% к награде за каждого, максимум +5%.

signal message(text: String)

const LUCK_PER_PET := 1.25
const LUCK_MAX := 5.0

@onready var paw: Node3D = $Paw
var luck: float = 0.0
var _petted: Dictionary = {}
var _t: float = 0.0


func _ready() -> void:
	# Машущая лапа модели переезжает в шарнир Paw (глобальная поза сохраняется)
	var arm := find_child("4-RightArm", true, false)
	if arm:
		arm.reparent(paw, true)
	# Кот золотой (по дизайну): тонируем фарфор модели в золото, красные узоры остаются
	for part in ["2-Body", "1-Head", "5-LeftArm", "4-RightArm"]:
		var n := find_child(part, true, false)
		if n == null:
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for i in mesh.get_surface_count():
				var m := mesh.surface_get_material(i)
				if m is StandardMaterial3D:
					var g := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					g.albedo_color = Color(1.0, 0.8, 0.38)
					g.metallic = 0.7
					g.roughness = 0.3
					(mi as MeshInstance3D).set_surface_override_material(i, g)


func _process(delta: float) -> void:
	var near := false
	for p in get_tree().get_nodes_in_group("players"):
		if (p as Node3D).global_position.distance_to(global_position) < 5.0:
			near = true
	_t += delta * (9.0 if near else 3.0)
	paw.rotation.z = sin(_t) * 0.22


func pet(player: Node3D) -> void:
	if _petted.has(player):
		return
	_petted[player] = true
	luck = minf(luck + LUCK_PER_PET, LUCK_MAX)
	message.emit(tr("MSG_PET") % str(luck))


func reset_luck() -> void:
	luck = 0.0
	_petted.clear()
