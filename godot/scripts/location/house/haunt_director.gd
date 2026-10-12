class_name HauntDirector
extends Node
## Дом №13: считает шум (скрипящие половицы), вызывает призрака-простыню и ведёт «тихий бонус».
## Шум затухает со временем; когда он выше порога, призрак появляется рядом с ближайшим игроком.

@export var threshold: float = 3.0
@export var decay: float = 0.12
@export var ghost_cooldown: float = 14.0
@export var quiet_creaks: int = 6

var noise := 0.0
var creaks := 0
var scares := 0
var _cd := 0.0
var _ghost: Node3D
var _loc: Node


func _ready() -> void:
	add_to_group("haunt")
	_loc = get_tree().get_first_node_in_group("location")
	if _loc and _loc.has_signal("cat_rescued"):
		_loc.cat_rescued.connect(_on_rescued)


func add_noise(amount: float) -> void:
	noise += amount
	creaks += 1


func scare_done() -> void:
	scares += 1


func _physics_process(delta: float) -> void:
	noise = maxf(noise - decay * delta, 0.0)
	_cd = maxf(_cd - delta, 0.0)
	if _ghost == null:
		_ghost = get_tree().get_first_node_in_group("ghost") as Node3D
	if _ghost and noise >= threshold and _cd <= 0.0 and _ghost.has_method("appear"):
		var p := _nearest_player()
		if p:
			_cd = ghost_cooldown
			noise = 0.0
			_ghost.appear(p)


func _nearest_player() -> Player:
	var best: Player = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("players"):
		var p := n as Player
		if p == null or p.seated:
			continue
		var d := p.global_position.length()
		if d < bd:
			bd = d
			best = p
	return best


func _on_rescued() -> void:
	if _loc == null or not _loc.has_method("say"):
		return
	await get_tree().create_timer(1.8).timeout
	if scares == 0 and creaks <= quiet_creaks:
		_loc.say(tr("MSG_QUIET_BONUS"), 3.5)
	else:
		_loc.say(tr("MSG_NOISY_END") % [creaks, scares], 3.5)
