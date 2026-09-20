class_name RouteManager
extends Node3D

signal route_started(total_checkpoints: int)
signal checkpoint_progress(current: int, total: int)
signal route_completed(elapsed_seconds: float, reward: int)

@export var auto_start := true

var checkpoints: Array[RouteCheckpoint] = []
var current_index := 0
var elapsed_seconds := 0.0
var running := false

func _ready() -> void:
	for child in get_children():
		if child is RouteCheckpoint:
			checkpoints.append(child)
	checkpoints.sort_custom(_sort_checkpoints)
	for checkpoint in checkpoints:
		checkpoint.passed.connect(_on_checkpoint_passed)
	GameManager.register_route(self)
	if auto_start:
		start_route()

func _process(delta: float) -> void:
	if running:
		elapsed_seconds += delta

func start_route() -> void:
	elapsed_seconds = 0.0
	current_index = 0
	running = true
	for checkpoint in checkpoints:
		checkpoint.reset_checkpoint()
	if not checkpoints.is_empty():
		checkpoints[0].set_active(true)
	route_started.emit(checkpoints.size())
	checkpoint_progress.emit(0, checkpoints.size())

func restart_route() -> void:
	var vehicle = GameManager.get_player_vehicle()
	if vehicle != null and vehicle.has_method("reset_to_spawn"):
		vehicle.call("reset_to_spawn")
	start_route()
	GameManager.set_game_state(GameManager.GameState.PLAYING)

func _on_checkpoint_passed(checkpoint: RouteCheckpoint) -> void:
	if not running:
		return
	if checkpoints[current_index] != checkpoint:
		return
	checkpoint.mark_completed()
	current_index += 1
	checkpoint_progress.emit(current_index, checkpoints.size())
	if current_index >= checkpoints.size():
		_finish_route()
	else:
		checkpoints[current_index].set_active(true)

func _finish_route() -> void:
	running = false
	var reward := EconomyManager.calculate_route_reward(elapsed_seconds)
	EconomyManager.add_money(reward)
	SaveManager.data["routes_completed"] = int(SaveManager.data.get("routes_completed", 0)) + 1
	var best := float(SaveManager.data.get("best_time", 0.0))
	if best <= 0.0 or elapsed_seconds < best:
		SaveManager.data["best_time"] = elapsed_seconds
	SaveManager.save_game()
	GameManager.set_game_state(GameManager.GameState.ROUTE_COMPLETE)
	route_completed.emit(elapsed_seconds, reward)

func _sort_checkpoints(a: RouteCheckpoint, b: RouteCheckpoint) -> bool:
	return a.checkpoint_index < b.checkpoint_index
