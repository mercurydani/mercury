extends SceneTree
# Проверяет, что маршруты рабочих не проходят сквозь технику, здания и самолёты.

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game(1)
	for i in 3:
		main.spawn_plane()
	for i in 300:
		main.step(0.1)
		if main.planes.all(func(p): return p == null or p.state == "ready"):
			break
	var ap: Airport = main.airport
	var bad := 0
	var idx := 0
	for c in ap.crew:
		var pts: Array = c.pts
		var hit := false
		for s in pts.size():
			var a: Vector2 = pts[s]
			var b: Vector2 = pts[(s + 1) % pts.size()]
			var steps := int(a.distance_to(b) / 0.2) + 1
			for k in steps + 1:
				var p := a.lerp(b, float(k) / steps)
				var px := Vector2(p.y / Cfg.K, p.x / Cfg.K)
				var q: Vector2 = main.resolve_px(px, 12.0)
				if q.distance_to(px) > 4.0:
					hit = true
		if hit:
			bad += 1
			print("route ", idx, " crosses solids: ", pts)
		idx += 1
	print("routes=", ap.crew.size(), " bad=", bad, " solids=", ap.solids_px.size())
	quit()
