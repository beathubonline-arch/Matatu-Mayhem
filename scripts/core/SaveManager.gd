extends Node

const SAVE_PATH := "user://matatu_mayhem_save.json"

var data := {
	"money": 0,
	"best_time": 0.0,
	"routes_completed": 0,
	"passenger_trips_completed": 0,
	"matatu_reputation": 0,
	"last_corridor": 0,
	"unlocked_corridors": 2,
	"corridor_best_times": {},
	"upgrade_levels": {},
	"rival_wins": 0,
	"rival_losses": 0,
	"clean_streak": 0,
	"best_clean_streak": 0,
	"street_cred": 0,
	"best_hype": 0,
	"perfect_runs": 0,
	"owned_nganyas": ["Maverick"],
	"selected_nganya": "Maverick",
	"career_rank": 1,
	"career_xp": 0,
	"career_earnings": 0,
	"shift_runs": 0,
	"shift_passengers": 0,
	"shift_earnings": 0,
	"shift_rival_wins": 0,
	"shift_clean_runs": 0,
	"shift_claimed": false,
	"shift_id": 0,
	"shifts_completed": 0,
	"route_mastery": {},
	"route_total_passengers": {},
	"route_total_earnings": {},
	"route_rival_wins": {},
	"first_run_seen": false,
	"total_routes_completed": 0,
	"total_passengers_carried": 0,
	"total_rival_wins": 0,
	"round_trips_completed": 0,
	"current_round_trip_earnings": 0,
	"current_round_trip_passengers": 0,
	"last_round_trip_earnings": 0,
	"last_round_trip_passengers": 0,
	"rival_win_streak": 0,
	"best_rival_win_streak": 0
}

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for key in data.keys():
		if parsed.has(key):
			data[key] = parsed[key]

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(data, "\t"))
