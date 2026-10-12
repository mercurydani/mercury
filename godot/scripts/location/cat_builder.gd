class_name CatBuilder
extends RefCounted
## Кот-«Мурзик» для всех локаций: рыжий полосатый, с ошейником, хвостом и репликой «Мяу!?».
## Возвращает узел Cat (скрипт RescueCat) с триггером спасения.


static func build(parent: Node, pos: Vector3, nm := "Cat") -> Node3D:
	var U := LocUtil
	var old := U.kind
	U.kind = "paint"
	var cat := Node3D.new()
	cat.set_script(load("res://scripts/location/rescue_cat.gd"))
	U.add(parent, cat, nm, pos)
	var v := Node3D.new()
	U.add(cat, v, "Visual")
	var fur := Color(0.95, 0.6, 0.2)
	var dark := Color(0.7, 0.35, 0.1)
	U.sphere(v, "Body", 0.28, fur, Vector3(0, 0.3, 0), 1.15)
	U.sphere(v, "Belly", 0.2, Color(1.0, 0.92, 0.8), Vector3(0, 0.28, 0.17), 1.0)
	U.sphere(v, "Haunch", 0.2, fur, Vector3(0.17, 0.2, -0.06), 0.9)
	U.sphere(v, "HaunchL", 0.2, fur, Vector3(-0.17, 0.2, -0.06), 0.9)
	for i in 3:
		U.box(v, "Stripe%d" % i, Vector3(0.36, 0.05, 0.05), dark, Vector3(0, 0.45 - i * 0.08, -0.15 + i * 0.1)).rotation_degrees.x = 15 * (i - 1)
	var head := Node3D.new()
	U.add(v, head, "Head", Vector3(0, 0.72, 0.1))
	U.sphere(head, "HeadMesh", 0.24, fur, Vector3.ZERO, 0.9)
	U.sphere(head, "Muzzle", 0.1, Color(1.0, 0.92, 0.8), Vector3(0, -0.06, 0.18), 0.8)
	U.sphere(head, "Nose", 0.03, Color(0.95, 0.5, 0.55), Vector3(0, -0.02, 0.26))
	for s in [-1.0, 1.0]:
		var ear := U.cyl(head, "Ear", 0.09, 0.0, 0.2, fur, Vector3(s * 0.14, 0.2, 0.0), 4)
		ear.rotation_degrees.z = -s * 18
		U.cyl(head, "EarIn", 0.05, 0.0, 0.14, Color(0.95, 0.6, 0.65), Vector3(s * 0.14, 0.19, 0.04), 4).rotation_degrees.z = -s * 18
		for k in 3:
			U.rod(head, "Whisker", Vector3(s * 0.08, -0.05 - k * 0.015, 0.22), Vector3(s * 0.36, -0.03 - k * 0.05, 0.2), 0.008, Color(0.95, 0.95, 0.95))
	var eyes := Node3D.new()
	U.add(v, eyes, "Eyes", Vector3(0, 0.76, 0.3))
	for s in [-1.0, 1.0]:
		U.sphere(eyes, "EyeWhite", 0.07, Color.WHITE, Vector3(s * 0.1, 0, 0), 1.2)
		U.sphere(eyes, "Pupil", 0.045, Color(0.08, 0.1, 0.12), Vector3(s * 0.1, -0.01, 0.045), 1.2)
		U.sphere(eyes, "Glint", 0.015, Color.WHITE, Vector3(s * 0.1 + 0.015, 0.02, 0.085))
	U.cyl(v, "Collar", 0.2, 0.2, 0.05, Color(0.85, 0.15, 0.2), Vector3(0, 0.58, 0.1), 14).rotation_degrees.x = 20
	U.sphere(v, "Tag", 0.035, Color(0.95, 0.8, 0.2), Vector3(0, 0.52, 0.28), 1.0)
	for s in [-1.0, 1.0]:
		U.sphere(v, "Paw", 0.08, Color(1.0, 0.92, 0.8), Vector3(s * 0.12, 0.06, 0.2), 0.7)
	var tail := Node3D.new()
	U.add(v, tail, "Tail", Vector3(0, 0.12, -0.28))
	for i in 5:
		U.sphere(tail, "Seg%d" % i, 0.07 - i * 0.004, fur if i != 4 else dark, Vector3(0.0, 0.06 + i * 0.08, -0.05 - i * 0.04), 1.0)
	var bubble := Label3D.new()
	bubble.text = "CAT_MEOW"
	bubble.font_size = 64
	bubble.pixel_size = 0.012
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.modulate = Color(1, 1, 1)
	bubble.outline_size = 14
	bubble.outline_modulate = Color(0.1, 0.1, 0.1)
	bubble.no_depth_test = true
	U.add(cat, bubble, "Bubble", Vector3(0, 1.4, 0))
	U.trigger(cat, "Trigger", "PROMPT_RESCUE", Vector3(0, 0.6, 0), 1.9)
	U.kind = old
	return cat
