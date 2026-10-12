extends SceneTree
## Дымовой тест: грузит лобби, сажает игрока в фургон, проверяет запуск поиска.
## Запуск: godot --headless --path godot --script res://tools/smoke_test.gd

func _init() -> void:
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	root.add_child(lobby)
	await process_frame
	await physics_frame
	var player: Player = lobby.get_node("Players/Player1")
	var van: Van = lobby.get_node("Van")
	var msgs: Array[String] = []
	van.message.connect(func(t: String) -> void: msgs.append(t))
	van.request_search(player)
	van.take_seat(player)
	van.request_search(player)
	var ok := msgs.size() == 2 and player.seated
	print("messages: ", msgs, " seated: ", player.seated)
	print("SMOKE ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
