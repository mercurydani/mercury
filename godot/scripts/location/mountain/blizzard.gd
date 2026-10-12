class_name Blizzard
extends Node3D
## Метель: вокруг игрока летят снежинки, туман сгущается по сложности (простая — лёгкий, сложная — почти ничего не видно).

@export var fog_by_tier: PackedFloat32Array = PackedFloat32Array([0.006, 0.014, 0.028])
@export var snow_amount: int = 700

var _parts: GPUParticles3D
var _env: Environment


func _ready() -> void:
	_parts = GPUParticles3D.new()
	_parts.amount = snow_amount
	_parts.lifetime = 3.0
	_parts.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 20, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 6, 16)
	pm.direction = Vector3(1, -0.8, 0.3)
	pm.spread = 15.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(3, -1, 1)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	_parts.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mat
	_parts.draw_pass_1 = qm
	_parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_parts)
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		_env = we.environment


func _physics_process(delta: float) -> void:
	var best: Node3D = null
	for n in get_tree().get_nodes_in_group("players"):
		best = n as Node3D
		break
	if best:
		global_position = best.global_position + Vector3(0, 3, 0)
	if _env:
		var loc := get_tree().get_first_node_in_group("location")
		var tier: int = loc.difficulty if loc else 0
		var want := fog_by_tier[mini(tier, fog_by_tier.size() - 1)]
		_env.fog_density = lerpf(_env.fog_density, want, minf(delta * 1.5, 1.0))
