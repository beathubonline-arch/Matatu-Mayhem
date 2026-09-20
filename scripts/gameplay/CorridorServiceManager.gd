class_name CorridorServiceManager
extends Node

signal corridor_changed(name: String, stop_name: String, current: int, total: int)
signal corridor_completed(name: String, reward: int, balance: int, elapsed: float, best: float, new_best: bool, fares: int, passengers: int)
signal fare_awarded(amount: int, balance: int)
signal service_progress(message: String)
signal run_time_changed(seconds: float)
signal passenger_load_changed(onboard: int, capacity: int, boarded: int, alighted: int)
signal navigation_changed(distance: float, turn_angle: float)
signal maneuver_changed(message: String)
signal route_progress_changed(percent: int, off_route: bool)

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
var route_point_index := 1
var next_stage_route_index := 1
var _off_route_time := 0.0

func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D
	network = get_node_or_null(network_path) as NairobiRouteNetwork
	if player == null or network == null:
		push_error("CorridorServiceManager requires player and NairobiRouteNetwork.")
		return
	var levels: Dictionary = SaveManager.data.get("upgrade_levels", {})
	passenger_capacity = 14 + clampi(int(levels.get("capacity", 0)), 0, 5) * 2
	# Wait for the player to choose a Nairobi route from the HUD.
	active = false

func restart_corridor() -> void:
	if network == null or player == null:
		return
	select_corridor(corridor_index)

func select_corridor(index: int) -> void:
	if network == null or player == null:
		return
	var requested: int = clampi(index, 0, network.corridor_count() - 1)
	var unlocked: int = clampi(int(SaveManager.data.get("unlocked_corridors", 1)), 1, network.corridor_count())
	if requested >= unlocked:
		service_progress.emit("ROUTE LOCKED • COMPLETE MORE NAIROBI CORRIDORS")
		return
	corridor_index = requested
	stop_index = 0
	dwell = 0.0
	elapsed_seconds = 0.0
	passengers_onboard = 0
	total_fares_this_run = 0
	total_passengers_this_run = 0
	route_point_index = 1
	next_stage_route_index = _find_route_index_for_service(0)
	active = true
	_off_route_time = 0.0
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
	var data: Dictionary = network.get_corridor(corridor_index)
	var route_points: Array = data["points"]
	var stage_target: Vector3 = network.get_service_stop(corridor_index, stop_index)
	var distance: float = player.global_position.distance_to(stage_target)
	while route_point_index < next_stage_route_index:
		var waypoint: Vector3 = route_points[route_point_index]
		var waypoint_distance := player.global_position.distance_to(waypoint)
		var passed_waypoint := false
		if route_point_index > 0:
			var segment_dir: Vector3 = route_points[route_point_index] - route_points[route_point_index - 1]
			segment_dir.y = 0.0
			var beyond: Vector3 = player.global_position - waypoint
			beyond.y = 0.0
			passed_waypoint = segment_dir.length_squared() > 0.01 and beyond.dot(segment_dir.normalized()) > 2.0
		if waypoint_distance < 11.0 or passed_waypoint:
			route_point_index += 1
		else:
			break
	var nav_target: Vector3 = route_points[clampi(route_point_index, 0, route_points.size() - 1)]
	var nav_distance: float = distance if route_point_index >= next_stage_route_index else player.global_position.distance_to(nav_target)
	# Turn cues come from the route geometry, not the player's current heading.
	# This keeps LEFT/RIGHT stable even if the matatu is recovering from a skid.
	var turn_angle := _route_turn_angle(route_points, route_point_index)
	navigation_changed.emit(nav_distance, turn_angle)
	var nearest_distance := _nearest_route_distance(player.global_position, route_points)
	var off_route := nearest_distance > 18.0
	if off_route:
		_off_route_time += delta
	else:
		_off_route_time = 0.0
	var progress := int(clampf(float(route_point_index) / float(maxi(route_points.size() - 1, 1)), 0.0, 1.0) * 100.0)
	route_progress_changed.emit(progress, off_route)
	if _off_route_time > 1.0:
		maneuver_changed.emit("OFF ROUTE • RETURN TO THE MARKED ROAD")
	elif route_point_index < next_stage_route_index and absf(rad_to_deg(turn_angle)) > 22.0 and nav_distance < 32.0:
		maneuver_changed.emit(("TURN LEFT" if turn_angle > 0.0 else "TURN RIGHT") + " • %dm" % int(player.global_position.distance_to(nav_target)))
	else:
		maneuver_changed.emit("FOLLOW ROUTE • STAGE %dm" % int(distance))
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
	var is_terminal := stop_index >= stops.size() - 1
	var alighted := passengers_onboard if is_terminal else (0 if stop_index == 0 else mini(passengers_onboard, 2 + stop_index))
	passengers_onboard -= alighted
	var boarded := 0
	if not is_terminal:
		var waiting: int = 4 + ((corridor_index * 3 + stop_index * 2) % 7)
		boarded = mini(waiting, passenger_capacity - passengers_onboard)
		passengers_onboard += boarded
	var fare := EconomyManager.PASSENGER_FARE if boarded > 0 else 0
	if fare > 0:
		EconomyManager.add_passenger_fare(fare)
		total_fares_this_run += fare
		total_passengers_this_run += boarded
		fare_awarded.emit(fare, EconomyManager.get_money())
	passenger_load_changed.emit(passengers_onboard, passenger_capacity, boarded, alighted)
	SaveManager.data["passenger_trips_completed"] = int(SaveManager.data.get("passenger_trips_completed", 0)) + boarded
	SaveManager.save_game()
	stop_index += 1
	if not is_terminal:
		next_stage_route_index = _find_route_index_for_service(stop_index)
		route_point_index = mini(route_point_index + 1, next_stage_route_index)
	if is_terminal:
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

func refresh_capacity_upgrade() -> void:
	var levels: Dictionary = SaveManager.data.get("upgrade_levels", {})
	passenger_capacity = 14 + clampi(int(levels.get("capacity", 0)), 0, 5) * 2
	passengers_onboard = mini(passengers_onboard, passenger_capacity)
	passenger_load_changed.emit(passengers_onboard, passenger_capacity, 0, 0)

func _emit_status() -> void:
	var data: Dictionary = network.get_corridor(corridor_index)
	var stops: Array = data["stops"]
	corridor_changed.emit(String(data["name"]), String(stops[stop_index]), stop_index + 1, stops.size())

func _find_route_index_for_service(service_index: int) -> int:
	var data: Dictionary = network.get_corridor(corridor_index)
	var route_points: Array = data["points"]
	var service_points: Array = data["service_points"]
	var target: Vector3 = service_points[clampi(service_index, 0, service_points.size() - 1)]
	var best_index := 0
	var best_distance: float = INF
	for i in range(route_points.size()):
		var d := target.distance_squared_to(route_points[i])
		if d < best_distance:
			best_distance = d
			best_index = i
	return best_index

func _nearest_route_distance(position: Vector3, route_points: Array) -> float:
	var best: float = INF
	for i in range(route_points.size() - 1):
		var a: Vector3 = route_points[i]
		var b: Vector3 = route_points[i + 1]
		var ab := b - a
		ab.y = 0.0
		var ap := position - a
		ap.y = 0.0
		var denom := ab.length_squared()
		var t := 0.0 if denom < 0.001 else clampf(ap.dot(ab) / denom, 0.0, 1.0)
		var closest := a + ab * t
		best = minf(best, position.distance_to(closest))
	return best


func _route_turn_angle(route_points: Array, index: int) -> float:
	if index <= 0 or index >= route_points.size() - 1:
		return 0.0
	var incoming: Vector3 = route_points[index] - route_points[index - 1]
	var outgoing: Vector3 = route_points[index + 1] - route_points[index]
	incoming.y = 0.0
	outgoing.y = 0.0
	if incoming.length_squared() < 0.01 or outgoing.length_squared() < 0.01:
		return 0.0
	return incoming.normalized().signed_angle_to(outgoing.normalized(), Vector3.UP)
