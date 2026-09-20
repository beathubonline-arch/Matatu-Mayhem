class_name CorridorServiceManager
extends Node

signal corridor_changed(name: String, stop_name: String, current: int, total: int)
signal corridor_completed(name: String, reward: int, balance: int)
signal fare_awarded(amount: int, balance: int)
signal service_progress(message: String)
signal run_time_changed(seconds: float)

@export var player_path: NodePath
@export var network_path: NodePath

var player: Node3D
var network: NairobiRouteNetwork
var corridor_index := 0
var stop_index := 0
var dwell := 0.0
var active := false
var elapsed_seconds := 0.0

func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D
	network = get_node_or_null(network_path) as NairobiRouteNetwork
	if player == null or network == null:
		push_error("CorridorServiceManager requires player and NairobiRouteNetwork.")
		return
	# Wait for the player to choose a Nairobi route from the HUD.
	active = false

func restart_corridor() -> void:
	if network == null or player == null:
		return
	select_corridor(corridor_index)

func select_corridor(index: int) -> void:
	if network == null or player == null:
		return
	corridor_index = clampi(index, 0, network.corridor_count() - 1)
	stop_index = 0
	dwell = 0.0
	elapsed_seconds = 0.0
	active = true
	var data: Dictionary = network.get_corridor(corridor_index)
	var points: Array = data["points"]
	var start: Vector3 = points[0]
	var next_point: Vector3 = points[1]
	var direction: Vector3 = (next_point - start).normalized()
	var yaw: float = atan2(-direction.x, -direction.z)
	var spawn_transform := Transform3D(Basis(Vector3.UP, yaw), start + Vector3(0.0, 1.4, 0.0))
	player.global_transform = spawn_transform
	if player.has_method("set_route_spawn"):
		player.call("set_route_spawn", spawn_transform)
	if player.has_method("reset_to_spawn"):
		player.call("reset_to_spawn")
	_emit_status()

func _physics_process(delta: float) -> void:
	if not active or player == null or network == null:
		return
	elapsed_seconds += delta
	run_time_changed.emit(elapsed_seconds)
	var target: Vector3 = network.get_service_stop(corridor_index, stop_index)
	var distance: float = player.global_position.distance_to(target)
	if distance > 7.0:
		dwell = 0.0
		if distance < 28.0:
			service_progress.emit("STAGE AHEAD • %dm" % int(distance))
		return
	var speed: float = 999.0
	if player.has_method("get_speed_kph"):
		speed = float(player.call("get_speed_kph"))
	if speed > 4.0:
		dwell = 0.0
		service_progress.emit("SLOW DOWN FOR STAGE • %d km/h" % int(speed))
		return
	dwell += delta
	service_progress.emit("BOARDING PASSENGERS • %d%%" % int(clampf(dwell / 1.5, 0.0, 1.0) * 100.0))
	if dwell >= 1.5:
		_complete_stop()

func _complete_stop() -> void:
	dwell = 0.0
	var data: Dictionary = network.get_corridor(corridor_index)
	var stops: Array = data["stops"]
	var fare: int = 2500 + stop_index * 500
	EconomyManager.add_passenger_fare(fare)
	fare_awarded.emit(fare, EconomyManager.get_money())
	SaveManager.data["passenger_trips_completed"] = int(SaveManager.data.get("passenger_trips_completed", 0)) + 1
	SaveManager.save_game()
	stop_index += 1
	if stop_index >= stops.size():
		var reward: int = int(data["reward"])
		EconomyManager.add_money(reward)
		SaveManager.data["routes_completed"] = int(SaveManager.data.get("routes_completed", 0)) + 1
		SaveManager.data["last_corridor"] = corridor_index
		SaveManager.save_game()
		corridor_completed.emit(String(data["name"]), reward, EconomyManager.get_money())
		active = false
		return
	_emit_status()

func _emit_status() -> void:
	var data: Dictionary = network.get_corridor(corridor_index)
	var stops: Array = data["stops"]
	corridor_changed.emit(String(data["name"]), String(stops[stop_index]), stop_index + 1, stops.size())
