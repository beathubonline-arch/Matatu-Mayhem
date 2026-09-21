class_name StreetKingManager
extends Node

signal shift_changed(summary: String)
signal shift_completed(reward: int, rep_reward: int)
signal mastery_changed(corridor: int, level: int, summary: String)

@export var corridor_service_path: NodePath
@export var challenge_manager_path: NodePath

const SHIFT_RUN_TARGET := 2
const SHIFT_PASSENGER_TARGET := 28
const SHIFT_RIVAL_TARGET := 1
const SHIFT_REWARD := 15000
const SHIFT_REP_REWARD := 250
const ROUTE_NAMES := ["NGONG ROAD", "MOMBASA ROAD", "WAIYAKI WAY", "THIKA ROAD"]

var corridor_service: CorridorServiceManager
var challenge_manager: DrivingChallengeManager

func _ready() -> void:
	corridor_service = get_node_or_null(corridor_service_path) as CorridorServiceManager
	challenge_manager = get_node_or_null(challenge_manager_path) as DrivingChallengeManager
	if corridor_service != null:
		corridor_service.corridor_completed.connect(_on_corridor_completed)
	if challenge_manager != null:
		challenge_manager.rival_result.connect(_on_rival_result)
	call_deferred("_emit_shift")

func _on_corridor_completed(_name: String, reward: int, _balance: int, _elapsed: float, _best: float, new_best: bool, fares: int, passengers: int) -> void:
	var idx := corridor_service.corridor_index if corridor_service != null else 0
	SaveManager.data["shift_runs"] = int(SaveManager.data.get("shift_runs", 0)) + 1
	SaveManager.data["total_routes_completed"] = int(SaveManager.data.get("total_routes_completed", 0)) + 1
	SaveManager.data["total_passengers_carried"] = int(SaveManager.data.get("total_passengers_carried", 0)) + passengers
	SaveManager.data["shift_passengers"] = int(SaveManager.data.get("shift_passengers", 0)) + passengers
	SaveManager.data["shift_earnings"] = int(SaveManager.data.get("shift_earnings", 0)) + reward + fares
	var passenger_totals: Dictionary = SaveManager.data.get("route_total_passengers", {})
	var earning_totals: Dictionary = SaveManager.data.get("route_total_earnings", {})
	passenger_totals[str(idx)] = int(passenger_totals.get(str(idx), 0)) + passengers
	earning_totals[str(idx)] = int(earning_totals.get(str(idx), 0)) + reward + fares
	SaveManager.data["route_total_passengers"] = passenger_totals
	SaveManager.data["route_total_earnings"] = earning_totals
	_update_mastery(idx, new_best)
	_check_shift()
	SaveManager.save_game()
	_emit_shift()

func _on_rival_result(won: bool, _player_time: float, _rival_time: float, _reward: int) -> void:
	if not won:
		return
	SaveManager.data["shift_rival_wins"] = int(SaveManager.data.get("shift_rival_wins", 0)) + 1
	SaveManager.data["total_rival_wins"] = int(SaveManager.data.get("total_rival_wins", 0)) + 1
	var idx := corridor_service.corridor_index if corridor_service != null else 0
	var wins: Dictionary = SaveManager.data.get("route_rival_wins", {})
	wins[str(idx)] = int(wins.get(str(idx), 0)) + 1
	SaveManager.data["route_rival_wins"] = wins
	_check_shift()
	SaveManager.save_game()
	_emit_shift()

func _update_mastery(idx: int, new_best: bool) -> void:
	var mastery: Dictionary = SaveManager.data.get("route_mastery", {})
	var passengers: Dictionary = SaveManager.data.get("route_total_passengers", {})
	var earnings: Dictionary = SaveManager.data.get("route_total_earnings", {})
	var wins: Dictionary = SaveManager.data.get("route_rival_wins", {})
	var p := int(passengers.get(str(idx), 0))
	var e := int(earnings.get(str(idx), 0))
	var w := int(wins.get(str(idx), 0))
	var score := p + int(e / 1500) + w * 12 + (8 if new_best else 0)
	var level := clampi(1 + int(score / 45), 1, 10)
	var old_level := int(mastery.get(str(idx), 1))
	mastery[str(idx)] = level
	SaveManager.data["route_mastery"] = mastery
	if level > old_level:
		mastery_changed.emit(idx, level, "%s MASTERY %d/10 • NAIROBI KNOWS YOUR NAME" % [ROUTE_NAMES[idx], level])

func _check_shift() -> void:
	if bool(SaveManager.data.get("shift_claimed", false)):
		return
	var complete := int(SaveManager.data.get("shift_runs", 0)) >= SHIFT_RUN_TARGET
	complete = complete and int(SaveManager.data.get("shift_passengers", 0)) >= SHIFT_PASSENGER_TARGET
	complete = complete and int(SaveManager.data.get("shift_rival_wins", 0)) >= SHIFT_RIVAL_TARGET
	if not complete:
		return
	SaveManager.data["shift_claimed"] = true
	EconomyManager.add_money(SHIFT_REWARD)
	SaveManager.data["matatu_reputation"] = int(SaveManager.data.get("matatu_reputation", 0)) + SHIFT_REP_REWARD
	shift_completed.emit(SHIFT_REWARD, SHIFT_REP_REWARD)

func get_shift_summary() -> String:
	var runs := mini(int(SaveManager.data.get("shift_runs", 0)), SHIFT_RUN_TARGET)
	var passengers := mini(int(SaveManager.data.get("shift_passengers", 0)), SHIFT_PASSENGER_TARGET)
	var rivals := mini(int(SaveManager.data.get("shift_rival_wins", 0)), SHIFT_RIVAL_TARGET)
	var status := "SHIFT COMPLETE" if bool(SaveManager.data.get("shift_claimed", false)) else "STREET KING SHIFT"
	return "%s • RUNS %d/%d • PASSENGERS %d/%d • RIVALS %d/%d • BONUS KSh %d" % [status, runs, SHIFT_RUN_TARGET, passengers, SHIFT_PASSENGER_TARGET, rivals, SHIFT_RIVAL_TARGET, SHIFT_REWARD]

func get_route_mastery(idx: int) -> int:
	var mastery: Dictionary = SaveManager.data.get("route_mastery", {})
	return int(mastery.get(str(idx), 1))

func _emit_shift() -> void:
	shift_changed.emit(get_shift_summary())


func get_driver_card() -> String:
	var mastery: Dictionary = SaveManager.data.get("route_mastery", {})
	var best_route := 0
	var best_mastery := 1
	for i in range(ROUTE_NAMES.size()):
		var level := int(mastery.get(str(i), 1))
		if level > best_mastery:
			best_mastery = level
			best_route = i
	var nganya := String(SaveManager.data.get("selected_nganya", "Maverick")).to_upper()
	return "MATATU MAYHEM • STREET KING\n%s • MASTERY %d/10\n%d ROUTES • %d PASSENGERS • %d RIVAL WINS\nNGANYA: %s\nCAN YOU BEAT MY NAIROBI RUN?" % [ROUTE_NAMES[best_route], best_mastery, int(SaveManager.data.get("total_routes_completed", 0)), int(SaveManager.data.get("total_passengers_carried", 0)), int(SaveManager.data.get("total_rival_wins", 0)), nganya]
