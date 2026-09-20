extends Node

const SAVE_PATH := "user://matatu_mayhem_save.json"

var data := {
	"money": 0,
	"best_time": 0.0,
	"routes_completed": 0,
	"passenger_trips_completed": 0,
	"matatu_reputation": 0,
	"last_corridor": 0,
	"owned_nganyas": ["Maverick"],
	"upgrade_levels": {}
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
