class_name Van
extends Node3D
## Спасательный фургон: места, готовность, запуск поиска.
## Правило: миссия стартует только когда ВСЕ игроки лобби сидят в фургоне.

signal message(text: String)
signal mission_requested

@onready var seats: Array[Node] = $Seats.get_children()
@onready var exit_point: Marker3D = $ExitPoint


func take_seat(player: Player) -> void:
	for s in seats:
		if not s.has_meta("occupant") or not is_instance_valid(s.get_meta("occupant")):
			s.set_meta("occupant", player)
			player.sit(s)
			return


func leave_seat(player: Player) -> void:
	for s in seats:
		if s.has_meta("occupant") and s.get_meta("occupant") == player:
			s.remove_meta("occupant")
	player.stand(exit_point.global_position)


func toggle_seat(player: Player) -> void:
	if player.seated:
		leave_seat(player)
	else:
		take_seat(player)


func request_search(player: Player) -> void:
	if not player.seated:
		message.emit(tr("MSG_NEED_SEAT"))
		return
	var waiting: Array[String] = []
	for p in get_tree().get_nodes_in_group("players"):
		if not (p as Player).seated:
			waiting.append(p.name)
	if waiting.size() > 0:
		message.emit(tr("MSG_WAITING") % ", ".join(waiting))
		return
	message.emit(tr("MSG_SEARCH_START"))
	mission_requested.emit()
