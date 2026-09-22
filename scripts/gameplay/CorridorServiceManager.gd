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
signal conductor_call(message: String)
signal stage_rush_changed(seconds_left: float, bonus: int)
signal stage_grade(message: String, reward: int)
signal event_changed(message: String, seconds_left: float)
signal route_unlocked(name: String)
signal direction_changed(label: String)
signal matatu_moment(message: String, reward: int)

@export var player_path: NodePath
@export var network_path: NodePath
@export var corridor_life_path: NodePath

var player: Node3D
var network: NairobiRouteNetwork
var corridor_life: Node
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
var _stage_rush_time := 0.0
var _stage_rush_bonus := 0
var _stage_entry_speed := 0.0
var _event_time := 0.0
var _event_message := ""
var _event_triggered_stage := -1
var inbound := false
var _moment_triggered: Dictionary = {}

func _ready() -> void:
	player = get_node_or_null(player_path) as Node3D
	network = get_node_or_null(network_path) as NairobiRouteNetwork
	corridor_life = get_node_or_null(corridor_life_path)
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
	select_corridor(corridor_index, inbound)

func select_corridor(index: int, return_to_cbd: bool = false) -> void:
	if network == null or player == null:
		return
	var requested: int = clampi(index, 0, network.corridor_count() - 1)
	var unlocked: int = clampi(int(SaveManager.data.get("unlocked_corridors", 2)), 2, network.corridor_count())
	if requested >= unlocked:
		service_progress.emit("ROUTE LOCKED • COMPLETE MORE NAIROBI CORRIDORS")
		return
	corridor_index = requested
	inbound = return_to_cbd
	if not inbound:
		# One Nairobi job is CBD -> terminus -> CBD. Aggregate both legs.
		SaveManager.data["current_round_trip_earnings"] = 0
		SaveManager.data["current_round_trip_passengers"] = 0
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
	_stage_rush_time = 0.0
	_stage_rush_bonus = 0
	_event_time = 0.0
	_event_message = ""
	_event_triggered_stage = -1
	_moment_triggered.clear()
	var data: Dictionary = _active_corridor_data()
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
	_board_origin_passengers()
	_emit_status()
	_update_active_stage_visual()
	direction_changed.emit("TO CBD" if inbound else "CBD → %s • %s" % [String(data["stops"][data["stops"].size() - 1]).to_upper(), String(data.get("feel", "NAIROBI RUN"))])
	conductor_call.emit("WATU WA %s! PANDA PANDA!" % String(data["stops"][data["stops"].size() - 1]).to_upper())

func _board_origin_passengers() -> void:
	# A selected route begins at an active CBD stage. Board that waiting queue
	# immediately so a new run never leaves the terminus showing 0 passengers.
	var data: Dictionary = _active_corridor_data()
	var stops: Array = data["stops"]
	if stops.size() < 2:
		return
	var visual_stop_index := stops.size() - 1 if inbound else 0
	var waiting: int = mini(7 + corridor_index, passenger_capacity)
	passengers_onboard = waiting
	total_passengers_this_run = waiting
	var fare := EconomyManager.PASSENGER_FARE * waiting
	EconomyManager.add_passenger_fare(fare)
	total_fares_this_run = fare
	SaveManager.data["passenger_trips_completed"] = int(SaveManager.data.get("passenger_trips_completed", 0)) + waiting
	if corridor_life != null:
		if corridor_life.has_method("board_passengers"):
			corridor_life.call("board_passengers", corridor_index, visual_stop_index, waiting, player)
		if corridor_life.has_method("set_vehicle_passenger_load"):
			corridor_life.call("set_vehicle_passenger_load", player, passengers_onboard)
	passenger_load_changed.emit(passengers_onboard, passenger_capacity, waiting, 0)
	fare_awarded.emit(fare, EconomyManager.get_money())
	service_progress.emit("CBD BOARDING COMPLETE • %d/%d SEATS • TWENDE!" % [passengers_onboard, passenger_capacity])
	conductor_call.emit("%d WAMEPANDA CBD • TWENDE!" % waiting)
	SaveManager.save_game()
	stop_index = 1
	next_stage_route_index = _find_route_index_for_service(stop_index)

func _physics_process(delta: float) -> void:
	if not active or player == null or network == null:
		return
	elapsed_seconds += delta
	run_time_changed.emit(elapsed_seconds)
	if _stage_rush_time > 0.0:
		_stage_rush_time = maxf(_stage_rush_time - delta, 0.0)
		stage_rush_changed.emit(_stage_rush_time, _stage_rush_bonus)
	if _event_time > 0.0:
		_event_time = maxf(_event_time - delta, 0.0)
		event_changed.emit(_event_message, _event_time)
	var data: Dictionary = _active_corridor_data()
	var route_points: Array = data["points"]
	var stage_target: Vector3 = _active_stage_bay(stop_index)
	_maybe_trigger_route_event()
	_update_matatu_moments(stage_target)
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
	if distance > 11.0:
		dwell = 0.0
		if distance < 18.0 and _stage_entry_speed <= 0.0 and player.has_method("get_speed_kph"):
			_stage_entry_speed = float(player.call("get_speed_kph"))
		if distance < 28.0:
			service_progress.emit("STAGE AHEAD • %dm" % int(distance))
		return
	var speed: float = 999.0
	if player.has_method("get_speed_kph"):
		speed = float(player.call("get_speed_kph"))
	if speed > 10.0:
		dwell = 0.0
		service_progress.emit("PULL IN • SLOW BELOW 10 km/h • %d km/h" % int(speed))
		return
	dwell += delta
	service_progress.emit("PANDA! BOARDING • %d%%" % int(clampf(dwell / 0.45, 0.0, 1.0) * 100.0))
	if dwell >= 0.45:
		_complete_stop()

func _complete_stop() -> void:
	dwell = 0.0
	var stage_reward := 0
	var stage_message := ""
	if _stage_entry_speed >= 18.0 and _stage_entry_speed <= 34.0:
		stage_reward = 350
		stage_message = "PERFECT STAGE ENTRY"
	elif _stage_entry_speed > 34.0 and _stage_entry_speed <= 48.0:
		stage_reward = 180
		stage_message = "HOT STAGE ENTRY"
	if stage_reward > 0:
		EconomyManager.add_money(stage_reward)
		stage_grade.emit(stage_message, stage_reward)
	_stage_entry_speed = 0.0
	var data: Dictionary = _active_corridor_data()
	var stops: Array = data["stops"]
	var is_terminal := stop_index >= stops.size() - 1
	var event_won := _event_time > 0.0 and stop_index > 0
	if event_won:
		var event_bonus := 500 + corridor_index * 150
		EconomyManager.add_money(event_bonus)
		stage_grade.emit("NAIROBI PRESSURE WON", event_bonus)
	_event_time = 0.0
	_event_message = ""
	event_changed.emit("", 0.0)
	var rush_won := _stage_rush_time > 0.0 and stop_index > 0
	if rush_won and _stage_rush_bonus > 0:
		EconomyManager.add_money(_stage_rush_bonus)
		service_progress.emit("STAGE RUSH WON • +KSh %d" % _stage_rush_bonus)
	_stage_rush_time = 0.0
	_stage_rush_bonus = 0
	stage_rush_changed.emit(0.0, 0)
	var alighted := passengers_onboard if is_terminal else (0 if stop_index == 0 else mini(passengers_onboard, 2 + stop_index))
	passengers_onboard -= alighted
	var boarded := 0
	if not is_terminal:
		var waiting: int = 5 + corridor_index + ((corridor_index * 3 + stop_index * 2) % 7)
		boarded = mini(waiting, passenger_capacity - passengers_onboard)
		passengers_onboard += boarded
	var fare := EconomyManager.PASSENGER_FARE * boarded if boarded > 0 else 0
	if fare > 0:
		EconomyManager.add_passenger_fare(fare)
		total_fares_this_run += fare
		total_passengers_this_run += boarded
		fare_awarded.emit(fare, EconomyManager.get_money())
		conductor_call.emit("TWENDE! %d WAMEPANDA • STAGE INAYOFUATA!" % boarded)
		_stage_rush_time = 24.0 + float(corridor_index * 2)
		_stage_rush_bonus = 900 + corridor_index * 250
		stage_rush_changed.emit(_stage_rush_time, _stage_rush_bonus)
		service_progress.emit("%d ABOARD • %d/%d SEATS FILLED • TWENDE!" % [boarded, passengers_onboard, passenger_capacity])
	if corridor_life != null:
		var visual_stop_index: int = stops.size() - 1 - stop_index if inbound else stop_index
		if alighted > 0 and corridor_life.has_method("alight_passengers"):
			corridor_life.call("alight_passengers", corridor_index, visual_stop_index, alighted, player)
		if boarded > 0 and corridor_life.has_method("board_passengers"):
			corridor_life.call("board_passengers", corridor_index, visual_stop_index, boarded, player)
		if corridor_life.has_method("set_vehicle_passenger_load"):
			corridor_life.call("set_vehicle_passenger_load", player, passengers_onboard)
	passenger_load_changed.emit(passengers_onboard, passenger_capacity, boarded, alighted)
	SaveManager.data["passenger_trips_completed"] = int(SaveManager.data.get("passenger_trips_completed", 0)) + boarded
	SaveManager.save_game()
	stop_index += 1
	if not is_terminal:
		next_stage_route_index = _find_route_index_for_service(stop_index)
		route_point_index = mini(route_point_index + 1, next_stage_route_index)
		_update_active_stage_visual()
	if is_terminal:
		if corridor_life != null and corridor_life.has_method("clear_active_stage"):
			corridor_life.call("clear_active_stage")
		conductor_call.emit("MWISHO! WOTE SHUKA • SIMAMA HAPA • RETURN TO CBD NEXT!")
		if corridor_life != null and corridor_life.has_method("refresh_stage_passengers"):
			for physical_stop in range(stops.size()):
				corridor_life.call("refresh_stage_passengers", corridor_index, physical_stop)
		var reward: int = int(data["reward"])
		EconomyManager.add_money(reward)
		SaveManager.data["current_round_trip_earnings"] = int(SaveManager.data.get("current_round_trip_earnings", 0)) + reward + total_fares_this_run
		SaveManager.data["current_round_trip_passengers"] = int(SaveManager.data.get("current_round_trip_passengers", 0)) + total_passengers_this_run
		SaveManager.data["routes_completed"] = int(SaveManager.data.get("routes_completed", 0)) + 1
		SaveManager.data["last_corridor"] = corridor_index
		var unlocked := maxi(int(SaveManager.data.get("unlocked_corridors", 2)), 2)
		# Progression is earned after returning to CBD, not at the far terminus.
		if inbound and corridor_index + 1 >= unlocked and unlocked < network.corridor_count():
			SaveManager.data["unlocked_corridors"] = unlocked + 1
			var unlocked_data: Dictionary = network.get_corridor(unlocked)
			route_unlocked.emit(String(unlocked_data["name"]))
		if inbound:
			SaveManager.data["round_trips_completed"] = int(SaveManager.data.get("round_trips_completed", 0)) + 1
			SaveManager.data["last_round_trip_earnings"] = int(SaveManager.data.get("current_round_trip_earnings", 0))
			SaveManager.data["last_round_trip_passengers"] = int(SaveManager.data.get("current_round_trip_passengers", 0))
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
	var data: Dictionary = _active_corridor_data()
	var stops: Array = data["stops"]
	corridor_changed.emit(String(data["name"]), String(stops[stop_index]), stop_index + 1, stops.size())

func _update_active_stage_visual() -> void:
	if corridor_life == null or not corridor_life.has_method("set_active_stage"):
		return
	var data: Dictionary = _active_corridor_data()
	var stops: Array = data["stops"]
	var visual_stop_index := stops.size() - 1 - stop_index if inbound else stop_index
	corridor_life.call("set_active_stage", corridor_index, visual_stop_index, _active_stage_bay(stop_index), String(stops[stop_index]), inbound)

func _find_route_index_for_service(service_index: int) -> int:
	var data: Dictionary = _active_corridor_data()
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


func _maybe_trigger_route_event() -> void:
	if stop_index <= 0 or stop_index == _event_triggered_stage or _event_time > 0.0:
		return
	var seed: int = int(corridor_index * 11 + stop_index * 7 + int(elapsed_seconds) / 8) % 4
	if seed == 0:
		_event_message = "PASSENGER LATE • PUSH FOR THE STAGE!"
		_event_time = 14.0
	elif seed == 1:
		_event_message = "RIVAL CREW AHEAD • DON'T LET THEM TAKE THE STAGE!"
		_event_time = 16.0
	elif seed == 2:
		_event_message = "TRAFFIC BUILDING • FIND THE CLEAN LINE!"
		_event_time = 12.0
	else:
		return
	_event_triggered_stage = stop_index
	event_changed.emit(_event_message, _event_time)
	conductor_call.emit(_event_message)


func _active_corridor_data() -> Dictionary:
	var base: Dictionary = network.get_corridor(corridor_index)
	if not inbound:
		return base
	var reversed := base.duplicate(true)
	var points: Array = base["points"].duplicate()
	var service_points: Array = base["service_points"].duplicate()
	var stops: Array = base["stops"].duplicate()
	points.reverse()
	service_points.reverse()
	stops.reverse()
	reversed["points"] = points
	reversed["service_points"] = service_points
	reversed["stops"] = stops
	return reversed

func start_return_to_cbd() -> void:
	select_corridor(corridor_index, true)


func _active_stage_bay(service_index: int) -> Vector3:
	var data: Dictionary = _active_corridor_data()
	var points: Array = data["points"]
	var service_points: Array = data["service_points"]
	var idx: int = clampi(service_index, 0, service_points.size() - 1)
	var service_point: Vector3 = service_points[idx]
	var direction := _direction_at_active_point(points, service_point)
	var right := Vector3(direction.z, 0.0, -direction.x)
	return service_point + right * 5.2

func _direction_at_active_point(points: Array, service_point: Vector3) -> Vector3:
	var best_index := 0
	var best_distance: float = INF
	for i in range(points.size()):
		var d: float = service_point.distance_squared_to(points[i])
		if d < best_distance:
			best_distance = d
			best_index = i
	var next_index: int = mini(best_index + 1, points.size() - 1)
	var prev_index: int = maxi(best_index - 1, 0)
	var direction: Vector3
	if next_index != best_index:
		direction = points[next_index] - points[best_index]
	else:
		direction = points[best_index] - points[prev_index]
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() < 0.01 else direction.normalized()


func _update_matatu_moments(stage_target: Vector3) -> void:
	if not active or player == null or stop_index <= 0:
		return
	var speed: float = float(player.call("get_speed_kph")) if player.has_method("get_speed_kph") else 0.0
	var distance := player.global_position.distance_to(stage_target)
	var key := "%d:%d:%s" % [corridor_index, stop_index, "IN" if inbound else "OUT"]
	if _moment_triggered.has(key):
		return
	var trigger := false
	var message := ""
	var reward := 0
	match corridor_index:
		0:
			trigger = speed >= 42.0 and distance > 20.0 and distance < 55.0
			message = "NGONG HUSTLE • BEAT THE STAGE RUSH!"
			reward = 220
		1:
			trigger = speed >= 58.0 and distance > 28.0 and distance < 70.0
			message = "MOMBASA ROAD PULL • INDUSTRIAL EXPRESS!"
			reward = 300
		2:
			trigger = speed >= 68.0 and distance > 32.0 and distance < 80.0
			message = "WESTLANDS HEAT • RIVAL TERRITORY!"
			reward = 450
		3:
			trigger = speed >= 78.0 and distance > 35.0 and distance < 90.0
			message = "THIKA SUPERHIGHWAY • FULL SEND!"
			reward = 600
	if trigger:
		_moment_triggered[key] = true
		EconomyManager.add_money(reward)
		matatu_moment.emit(message, reward)
