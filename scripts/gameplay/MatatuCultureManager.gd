class_name MatatuCultureManager
extends Node

signal hype_changed(value: int, combo: int, message: String)
signal reputation_awarded(amount: int, total: int)

@export var passenger_manager_path: NodePath
@export var route_manager_path: NodePath
@export var radio_path: NodePath
@export var corridor_service_path: NodePath

var hype := 0
var combo := 0
var reputation := 0
var _last_event_msec := 0

func _ready() -> void:
	var passengers := get_node_or_null(passenger_manager_path)
	if passengers != null:
		passengers.fare_awarded.connect(_on_fare_awarded)
	var route := get_node_or_null(route_manager_path)
	if route != null:
		route.checkpoint_progress.connect(_on_checkpoint_progress)
		route.route_completed.connect(_on_route_completed)
	var corridor := get_node_or_null(corridor_service_path)
	if corridor != null:
		corridor.corridor_completed.connect(_on_corridor_completed)
	var radio := get_node_or_null(radio_path)
	if radio != null:
		radio.station_changed.connect(_on_station_changed)
	reputation = int(SaveManager.data.get("matatu_reputation", 0))
	hype_changed.emit(hype, combo, "CBD SHIFT STARTED")

func _on_fare_awarded(_amount: int, _balance: int) -> void:
	_add_hype(18, "STAGE SERVICE +18 HYPE")
	_add_reputation(25)

func _on_checkpoint_progress(current: int, total: int) -> void:
	if current <= 0 or current >= total:
		return
	_add_hype(6, "CLEAN CHECKPOINT +6 HYPE")

func _on_route_completed(_elapsed: float, _reward: int) -> void:
	_add_hype(25, "CBD ROUTE COMPLETE +25 HYPE")
	_add_reputation(60)

func _on_corridor_completed(_name: String, _reward: int, _balance: int) -> void:
	_add_hype(30, "CORRIDOR COMPLETE +30 HYPE")
	_add_reputation(75)

func _on_station_changed(_station: String, _track: String, _artist: String) -> void:
	if hype > 0:
		hype_changed.emit(hype, combo, "254 RADIO • KEEP THE VIBE")

func _add_hype(amount: int, message: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_event_msec < 12000:
		combo += 1
	else:
		combo = 1
	_last_event_msec = now
	var multiplier := clampi(combo, 1, 5)
	hype = clampi(hype + amount * multiplier, 0, 999)
	hype_changed.emit(hype, combo, message)

func _add_reputation(amount: int) -> void:
	reputation += amount
	SaveManager.data["matatu_reputation"] = reputation
	SaveManager.save_game()
	reputation_awarded.emit(amount, reputation)
