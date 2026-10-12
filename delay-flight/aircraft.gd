class_name Aircraft
extends Node3D
# Самолёт на стоянке: ждёт багаж и топливо. Нос смотрит в -X.

var row := 0
var state := "arriving"   # arriving | ready | leaving
var bags := 0
var need := 3
var fuel := 0.0
var pat := 40.0
var max_pat := 40.0
var delayed := false
var livery := Color("e63946")
var flight := "SU 100"
var blink := 0.0
var pos := Vector2.ZERO:
	set(v):
		pos = v
		position = Cfg.to3(v)

var body_mat: StandardMaterial3D
var beacon: MeshInstance3D
var info: Node3D
var bag_label: Label3D
var fuel_label: Label3D
var bar_fill: MeshInstance3D

func door_pt() -> Vector2:
	return pos + Vector2(-130, 0)

func fuel_pt() -> Vector2:
	return pos + Vector2(80, 0)

func _ready() -> void:
	var white := Color("f6f8fb")
	var fus := Rig.capsule(self, 0.6, 6.4, Vector3(0, 0.95, 0), white, Vector3(0, 0, 90))
	body_mat = fus.material_override
	# хвост и оперение
	Rig.cyl(self, 0.12, 0.55, 1.5, Vector3(3.15, 1.05, 0), white, Vector3(0, 0, 90))
	Rig.box(self, Vector3(1.1, 1.5, 0.12), Vector3(3.0, 2.0, 0), livery, Vector3(0, 0, -18))
	for sz in [-1.0, 1.0]:
		Rig.box(self, Vector3(0.8, 0.08, 0.9), Vector3(3.2, 1.2, 0.55 * sz), Color("d5dce6"), Vector3(0, 20 * sz, 0))
		# крыло и двигатель
		Rig.box(self, Vector3(1.6, 0.12, 1.35), Vector3(0.5, 0.85, 0.85 * sz), Color("d5dce6"), Vector3(0, 22 * sz, 0))
		Rig.cyl(self, 0.3, 0.3, 1.0, Vector3(-0.1, 0.55, 0.9 * sz), Color("5d6778"), Vector3(0, 0, 90))
		Rig.cyl(self, 0.2, 0.2, 0.05, Vector3(-0.62, 0.55, 0.9 * sz), Color("c2c9d4"), Vector3(0, 0, 90))
		# окна и полоса ливреи
		Rig.box(self, Vector3(5.6, 0.16, 1.22), Vector3(-0.2, 0.7, 0), livery)
		for i in 15:
			Rig.box(self, Vector3(0.15, 0.17, 0.06), Vector3(-2.3 + i * 0.32, 1.12, 0.57 * sz), Color("5aa9ff"), Vector3.ZERO, 0.4)
	Rig.box(self, Vector3(0.5, 0.28, 0.7), Vector3(-2.85, 1.3, 0), Color("1f3a5f"), Vector3(0, 0, -18))
	# шасси
	for g in [Vector3(-2.2, 0.3, 0), Vector3(0.6, 0.3, 0.55), Vector3(0.6, 0.3, -0.55)]:
		Rig.cyl(self, 0.05, 0.05, 0.6, g + Vector3(0, 0.1, 0), Color("333b4a"))
		Rig.cyl(self, 0.14, 0.14, 0.12, g + Vector3(0, -0.12, 0), Color("15181f"), Vector3(90, 0, 0))
	beacon = Rig.sphere(self, 0.14, Vector3(0, 1.58, 0), Color("ff2d2d"), Vector3.ONE, 3.0)
	beacon.visible = false
	Rig.label(self, flight, Vector3(-0.6, 1.9, 0), 26, Color("ffffff"))
	# информационная панель над самолётом
	info = Node3D.new()
	info.position = Vector3(0, 3.3, 0)
	add_child(info)
	Rig.box(info, Vector3(2.5, 0.16, 0.1), Vector3.ZERO, Color(0, 0, 0, 0.6))
	bar_fill = Rig.box(info, Vector3(2.4, 0.1, 0.12), Vector3.ZERO, Color("7dff8a"), Vector3.ZERO, 1.0)
	bag_label = Rig.label(self, "", Vector3(-2.6, 1.7, 1.0), 36, Color("ffd24d"))
	fuel_label = Rig.label(self, "", Vector3(1.6, 1.7, 1.0), 36, Color("ff9f43"))
	info.visible = false

func _process(delta: float) -> void:
	blink += delta
	var ready := state == "ready"
	info.visible = ready
	bag_label.visible = ready
	fuel_label.visible = ready
	if ready:
		var r := clampf(pat / max_pat, 0.0, 1.0)
		bar_fill.scale.x = maxf(r, 0.001)
		bar_fill.position.x = -1.2 * (1.0 - r)
		bar_fill.material_override.albedo_color = Color("7dff8a") if r > 0.5 else (Color("ffd24d") if r > 0.25 else Color("ff5a4d"))
		bar_fill.material_override.emission = bar_fill.material_override.albedo_color
		bag_label.text = "чемоданы %d/%d" % [bags, need]
		fuel_label.text = "топливо %d%%" % int(fuel)
	body_mat.albedo_color = Color(1.0, 0.72, 0.72) if delayed else Color("f6f8fb")
	beacon.visible = delayed and int(blink * 3.0) % 2 == 0
