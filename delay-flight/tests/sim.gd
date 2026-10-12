extends SceneTree
# Прогон смены без игроков: проверяет, что логика не падает, злость растёт и качок приходит.

func _initialize() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start_game(2)
	for i in 600:
		if main.mode != "play" or main.anger >= 50.0:
			break
		main.step(0.1)
	print("anger=", main.anger, " npcs=", main.npcs.size(), " planes=", main.planes.filter(func(p): return p != null).size())
	main.spawn_npc("muscle")
	for i in 4000:
		if main.mode != "play":
			break
		main.step(0.1)
	print("mode=", main.mode, " score=", main.score, " reason=", main.reason)
	# ручной сценарий: игрок несёт чемодан в самолёт и заправляет
	main.start_game(1)
	main.spawn_plane()
	main.step(3.0)
	var w: Worker = main.workers[0]
	var pl: Aircraft = main.planes.filter(func(p): return p != null)[0]
	w.pos = Cfg.BELT.position + Vector2(40, 40)
	main.bags.append(w.pos)
	w.pressed = true
	main.step(0.016)
	print("holding=", w.item)
	w.pos = pl.door_pt()
	w.pressed = true
	main.step(0.016)
	print("plane bags=", pl.bags, " item='", w.item, "'")
	quit()
