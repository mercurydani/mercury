class_name Scatter
extends Node3D
## Раскидывает вид из ForestSpecies по рельефу через MultiMesh (сотни деревьев, тысячи травинок — один вызов отрисовки).
## Положение и размер детерминированы seed_value. Стволы вблизи ручья получают коллизию (collide).

@export var species: String = "spruce"
@export var count: int = 100
@export var seed_value: int = 1
@export var x_range: Vector2 = Vector2(-240, 240)
@export var z_range: Vector2 = Vector2(-240, 240)
@export var min_stream: float = 0.0
@export var max_stream: float = 1000.0
@export var max_slope: float = 1.2
@export var scale_range: Vector2 = Vector2(0.8, 1.2)
## Круги (x, z, радиус), где ничего не растёт
@export var exclude: PackedVector3Array = PackedVector3Array()
@export var collide_within: float = 0.0   # >0: коллизия у экземпляров ближе к ручью, радиус ствола в collide_radius
@export var collide_radius: float = 0.35
@export var collide_height: float = 4.0
## Для камыша и осоки: расти только у воды
@export var near_water_only: bool = false
@export var allow_in_water: bool = false
@export var tilt_deg: float = 0.0
## Плавающие листья: только на воде, высота = уровень воды
@export var on_water: bool = false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var xforms: Array[Transform3D] = []
	var body: StaticBody3D = null
	var tries := 0
	while xforms.size() < count and tries < count * 12:
		tries += 1
		var x := rng.randf_range(x_range.x, x_range.y)
		var z := rng.randf_range(z_range.x, z_range.y)
		var d := RavineTerrain.stream_dist(x, z)
		if d < min_stream or d > max_stream:
			continue
		var h := RavineTerrain.height(x, z)
		var wet := h < RavineTerrain.WATER_Y + 0.15
		if on_water:
			if not wet or h > RavineTerrain.WATER_Y - 0.3:
				continue
		elif wet and not allow_in_water:
			continue
		if near_water_only and (h > RavineTerrain.WATER_Y + 0.5 or h < RavineTerrain.WATER_Y - 0.9):
			continue
		if x > RavineTerrain.FALL_X - 4.0 and d < 16.0:
			continue
		if RavineTerrain.slope(x, z) > max_slope:
			continue
		var skip := false
		for e in exclude:
			if Vector2(x - e.x, z - e.y).length() < e.z:
				skip = true
				break
		if skip:
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		if tilt_deg > 0.0:
			b = b * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-tilt_deg, tilt_deg)))
		b = b.scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
		xforms.append(Transform3D(b, Vector3(x, (RavineTerrain.WATER_Y + 0.02) if on_water else h - 0.05, z)))
		if collide_within > 0.0 and d < collide_within:
			if body == null:
				body = StaticBody3D.new()
				body.name = "Trunks"
				add_child(body)
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = collide_radius * s
			cyl.height = collide_height * s
			cs.shape = cyl
			cs.position = Vector3(x, h + collide_height * s * 0.5, z)
			body.add_child(cs)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ForestSpecies.get_mesh(species)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.name = "Instances"
	if species in ["grass", "flowers", "fern", "reeds", "mushroom"]:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
