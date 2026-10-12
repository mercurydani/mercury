extends SceneTree
## Снимки сцены для проверки вида (нужен рендер, не headless; в контейнере: xvfb-run + opengl3).
## xvfb-run -a godot --path godot --rendering-method gl_compatibility --rendering-driver opengl3 \
##   --resolution 1280x720 --script res://tools/screenshot.gd -- <scene> <prefix> [lang] [x y z tx ty tz]...
## Для игроков камера берётся из сцены; здесь ставим свою камеру и сохраняем <prefix>_<n>.png.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: Node = load(args[0]).instantiate()
	root.add_child(scene)
	var cam := Camera3D.new()
	cam.far = 600.0
	cam.fov = 60
	root.add_child(cam)
	await process_frame
	TranslationServer.set_locale(args[2])
	if OS.has_environment("DIFF") and scene.has_method("apply_difficulty"):
		scene.apply_difficulty(int(OS.get_environment("DIFF")))
	cam.make_current()
	var views := []
	var i := 3
	while i + 5 < args.size():
		views.append([Vector3(float(args[i]), float(args[i + 1]), float(args[i + 2])), Vector3(float(args[i + 3]), float(args[i + 4]), float(args[i + 5]))])
		i += 6
	var n := 0
	for v in views:
		cam.global_position = v[0]
		cam.look_at(v[1])
		for k in 12:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [args[1], n])
		n += 1
	quit()
