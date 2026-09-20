extends Node

enum GameState { BOOT, PLAYING, PAUSED, ROUTE_COMPLETE }

var current_state: GameState = GameState.BOOT
var player_vehicle: Node = null
var current_route: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_game_state(GameState.PLAYING)

func set_game_state(new_state: GameState) -> void:
	current_state = new_state
	get_tree().paused = current_state == GameState.PAUSED

func toggle_pause() -> void:
	if current_state == GameState.PAUSED:
		set_game_state(GameState.PLAYING)
	elif current_state == GameState.PLAYING:
		set_game_state(GameState.PAUSED)

func register_player_vehicle(vehicle: Node) -> void:
	player_vehicle = vehicle

func unregister_player_vehicle(vehicle: Node) -> void:
	if player_vehicle == vehicle:
		player_vehicle = null

func register_route(route: Node) -> void:
	current_route = route

func get_player_vehicle() -> Node:
	return player_vehicle if is_instance_valid(player_vehicle) else null
