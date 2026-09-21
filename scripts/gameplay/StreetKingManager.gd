class_name StreetKingManager
extends Node

signal shift_changed(summary: String)
signal shift_completed(reward: int, rep_reward: int)
signal mastery_changed(corridor: int, level: int, summary: String)

@export var corridor_service_path: NodePath
@export var challenge_manager_path: NodePath
@export var culture_manager_path: NodePath

const SHIFT_PRESETS := [
	{"name":"CBD HUSTLE","runs":2,"passengers":28,"rivals":1,"reward":15000,"rep":250},
	{"name":"STAGE PRESSURE","runs":3,"passengers":42,"rivals":1,"reward":22000,"rep":325},
	{"name":"RIVAL NIGHT","runs":2,"passengers":24,"rivals":2,"reward":26000,"rep":400},
	{"name":"NAIROBI MARATHON","runs":4,"passengers":55,"rivals":2,"reward":35000,"rep":550}
]
const ROUTE_NAMES := ["NGONG ROAD", "MOMBASA ROAD", "WAIYAKI WAY", "THIKA ROAD"]

var corridor_service: CorridorServiceManager
var challenge_manager: DrivingChallengeManager
var culture_manager: MatatuCultureManager

func _ready() -> void:
	corridor_service = get_node_or_null(corridor_service_path) as CorridorServiceManager
	challenge_manager = get_node_or_null(challenge_manager_path) as DrivingChallengeManager
	culture_manager = get_node_or_null(culture_manager_path) as MatatuCultureManager
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
	var shift := _current_shift()
	var complete := int(SaveManager.data.get("shift_runs", 0)) >= int(shift["runs"])
	complete = complete and int(SaveManager.data.get("shift_passengers", 0)) >= int(shift["passengers"])
	complete = complete and int(SaveManager.data.get("shift_rival_wins", 0)) >= int(shift["rivals"])
	if not complete:
		return
	SaveManager.data["shift_claimed"] = true
	var reward := int(shift["reward"])
	var rep := int(shift["rep"])
	EconomyManager.add_money(reward)
	if culture_manager != null:
		culture_manager.award_reputation(rep)
	else:
		SaveManager.data["matatu_reputation"] = int(SaveManager.data.get("matatu_reputation", 0)) + rep
	SaveManager.data["shifts_completed"] = int(SaveManager.data.get("shifts_completed", 0)) + 1
	shift_completed.emit(reward, rep)

func get_shift_summary() -> String:
	var shift := _current_shift()
	var runs := mini(int(SaveManager.data.get("shift_runs", 0)), int(shift["runs"]))
	var passengers := mini(int(SaveManager.data.get("shift_passengers", 0)), int(shift["passengers"]))
	var rivals := mini(int(SaveManager.data.get("shift_rival_wins", 0)), int(shift["rivals"]))
	var status := "SHIFT COMPLETE" if bool(SaveManager.data.get("shift_claimed", false)) else String(shift["name"])
	return "%s • RUNS %d/%d • PASSENGERS %d/%d • RIVALS %d/%d • BONUS KSh %d" % [status, runs, int(shift["runs"]), passengers, int(shift["passengers"]), rivals, int(shift["rivals"]), int(shift["reward"])]

func begin_next_shift_if_needed() -> void:
	if not bool(SaveManager.data.get("shift_claimed", false)):
		return
	SaveManager.data["shift_id"] = int(SaveManager.data.get("shift_id", 0)) + 1
	SaveManager.data["shift_runs"] = 0
	SaveManager.data["shift_passengers"] = 0
	SaveManager.data["shift_earnings"] = 0
	SaveManager.data["shift_rival_wins"] = 0
	SaveManager.data["shift_clean_runs"] = 0
	SaveManager.data["shift_claimed"] = false
	SaveManager.save_game()
	_emit_shift()

func _current_shift() -> Dictionary:
	var id := int(SaveManager.data.get("shift_id", 0))
	return SHIFT_PRESETS[id % SHIFT_PRESETS.size()]

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
