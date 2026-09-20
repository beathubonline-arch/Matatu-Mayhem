class_name MatatuCareerManager
extends Node

signal career_changed(rank: int, rank_name: String, xp: int, next_xp: int, owned: Array)
signal nganya_unlocked(name: String)

@export var corridor_service_path: NodePath
@export var culture_manager_path: NodePath

const RANKS := [
	{"name":"ROOKIE CONDUCTOR","xp":0},
	{"name":"STAGE REGULAR","xp":350},
	{"name":"ROUTE KING","xp":900},
	{"name":"NAIROBI HEAT","xp":1800},
	{"name":"NGANYA BOSS","xp":3200}
]
const NGANYA_UNLOCKS := [
	{"name":"Maverick","rank":1},
	{"name":"ONYX","rank":2},
	{"name":"MOXIE","rank":3},
	{"name":"MONEYFEST","rank":4},
	{"name":"STREET LEGEND","rank":5}
]

var career_xp := 0
var career_rank := 1
var career_earnings := 0

func _ready() -> void:
	career_xp = int(SaveManager.data.get("career_xp", 0))
	career_rank = int(SaveManager.data.get("career_rank", 1))
	career_earnings = int(SaveManager.data.get("career_earnings", 0))
	var corridor := get_node_or_null(corridor_service_path)
	if corridor != null:
		corridor.fare_awarded.connect(_on_fare)
		corridor.corridor_completed.connect(_on_corridor_completed)
	var culture := get_node_or_null(culture_manager_path)
	if culture != null:
		culture.reputation_awarded.connect(_on_reputation)
	_refresh_rank()
	_unlock_rank_nganyas()
	SaveManager.save_game()
	_emit()

func _on_fare(amount: int, _balance: int) -> void:
	career_earnings += amount
	_add_xp(maxi(5, int(amount / 250)))

func _on_reputation(amount: int, _total: int) -> void:
	_add_xp(maxi(1, int(amount / 3)))

func _on_corridor_completed(_name: String, reward: int, _balance: int, _elapsed: float, _best: float, new_best: bool, _fares: int, passengers: int) -> void:
	career_earnings += reward
	_add_xp(80 + passengers * 4 + (40 if new_best else 0))

func _add_xp(amount: int) -> void:
	career_xp += amount
	SaveManager.data["career_xp"] = career_xp
	SaveManager.data["career_earnings"] = career_earnings
	_refresh_rank()
	SaveManager.save_game()
	_emit()

func _refresh_rank() -> void:
	var new_rank := 1
	for i in range(RANKS.size()):
		if career_xp >= int(RANKS[i]["xp"]):
			new_rank = i + 1
	if new_rank > career_rank:
		career_rank = new_rank
		SaveManager.data["career_rank"] = career_rank
		_unlock_rank_nganyas()
	else:
		career_rank = new_rank
	SaveManager.data["career_rank"] = career_rank

func _unlock_rank_nganyas() -> void:
	var owned: Array = SaveManager.data.get("owned_nganyas", ["Maverick"])
	for entry in NGANYA_UNLOCKS:
		if career_rank >= int(entry["rank"]) and not owned.has(String(entry["name"])):
			owned.append(String(entry["name"]))
			nganya_unlocked.emit(String(entry["name"]))
	SaveManager.data["owned_nganyas"] = owned

func get_rank_name() -> String:
	return String(RANKS[clampi(career_rank - 1, 0, RANKS.size() - 1)]["name"])

func _emit() -> void:
	var next_xp := career_xp
	if career_rank < RANKS.size():
		next_xp = int(RANKS[career_rank]["xp"])
	career_changed.emit(career_rank, get_rank_name(), career_xp, next_xp, SaveManager.data.get("owned_nganyas", ["Maverick"]))
