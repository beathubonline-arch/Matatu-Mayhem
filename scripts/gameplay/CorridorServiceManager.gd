class_name CorridorServiceManager
extends Node

signal corridor_changed(name: String, stop_name: String, current: int, total: int)
signal corridor_completed(name: String, reward: int, balance: int, elapsed: float, best: float, new_best: bool, fares: int, passengers: int)
signal fare_awarded(amount: int, balance: int)
signal service_progress(message: String)
signal run_time_changed(seconds: float)
signal passenger_load_changed(onboard: int, capacity: int, boarded: int, alighted: int)

@export var player_path: NodePath
@export var network_path: NodePath

var player: Node3D
var network: NairobiRouteNetwork
var corridor_index := 0
var stop_index := 0
var dwell := 0.0
var active := false
var elapsed_seconds := 0.0
var passenger_capacity := 14
var passengers_onboard := 0
var total_fares_this_run := 0
var total_passengers_this_run := 0

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
	var unlocked := int(SaveManager.data.get("unlocked_corridors", 1))
	if index >= unlocked:
		service_progress.emit("ROUTE LOCKED • BUILD REPUTATION FIRST")
		return
	corridor_index = clampi(index, 0, network.corridor_count() - 1)
	stop_index = 0
	dwell = 0.0
	elapsed_seconds = 0.0
	passengers_onboard = 0
	total_fares_this_run = 0
	total_passengers_this_run = 0
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
	var alighted: int = 0 if stop_index == 0 else mini(passengers_onboard, 2 + stop_index)
	passengers_onboard -= alighted
	var waiting: int = 4 + ((corridor_index * 3 + stop_index * 2) % 7)
	var boarded: int = mini(waiting, passenger_capacity - passengers_onboard)
	passengers_onboard += boarded
	var fare: int = boarded * 500
	if fare > 0:
		EconomyManager.add_passenger_fare(fare)
		total_fares_this_run += fare
		total_passengers_this_run += boarded
	if fare > 0:
		fare_awarded.emit(fare, EconomyManager.get_money())
	passenger_load_changed.emit(passengers_onboard, passenger_capacity, boarded, alighted)
	SaveManager.data["passenger_trips_completed"] = int(SaveManager.data.get("passenger_trips_completed", 0)) + 1
	SaveManager.save_game()
	stop_index += 1
	if stop_index >= stops.size():
		var final_alighted := passengers_onboard
		passengers_onboard = 0
		passenger_load_changed.emit(0, passenger_capacity, 0, final_alighted)
		var reward: int = int(data["reward"])
		EconomyManager.add_money(reward)
		SaveManager.data["routes_completed"] = int(SaveManager.data.get("routes_completed", 0)) + 1
		SaveManager.data["last_corridor"] = corridor_index
		var unlocked := int(SaveManager.data.get("unlocked_corridors", 1))
		if corridor_index + 1 >= unlocked and unlocked < network.corridor_count():
			SaveManager.data["unlocked_corridors"] = unlocked + 1
		var best_times: Dictionary = SaveManager.data.get("corridor_best_times", {})
		var key := str(corridor_index)
		var previous_best := float(best_times.get(key, 0.0))
		var new_best := previous_best <= 0.0 or elapsed_seconds < previous_best
		if new_best:
			best_times[key] = elapsed_seconds
			SaveManager.data["corridor_best_times"] = best_times
		var best := elapsed_seconds if new_best else previous_best
		SaveManager.save_game()
		active = false
		corridor_completed.emit(String(data["name"]), reward, EconomyManager.get_money(), elapsed_seconds, best, new_best, total_fares_this_run, total_passengers_this_run)
		return
	_emit_status()

func _emit_status() -> void:
	var data: Dictionary = network.get_corridor(corridor_index)
	var stops: Array = data["stops"]
	corridor_changed.emit(String(data["name"]), String(stops[stop_index]), stop_index + 1, stops.size())
