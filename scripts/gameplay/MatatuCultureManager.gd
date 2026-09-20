class_name MatatuCultureManager
extends Node

signal hype_changed(value: int, combo: int, message: String)
signal reputation_awarded(amount: int, total: int)

@export var passenger_manager_path: NodePath
@export var radio_path: NodePath
@export var corridor_service_path: NodePath
@export var challenge_manager_path: NodePath

var hype := 0
var combo := 0
var reputation := 0
var street_cred := 0
var _last_event_msec := 0
var _last_decay_msec := 0

func _ready() -> void:
	var passengers := get_node_or_null(passenger_manager_path)
	if passengers != null:
		passengers.fare_awarded.connect(_on_fare_awarded)
	var corridor := get_node_or_null(corridor_service_path)
	if corridor != null:
		corridor.corridor_completed.connect(_on_corridor_completed)
	var radio := get_node_or_null(radio_path)
	if radio != null:
		radio.station_changed.connect(_on_station_changed)
	var challenges := get_node_or_null(challenge_manager_path)
	if challenges != null:
		challenges.challenge_changed.connect(_on_challenge_changed)
		challenges.rival_result.connect(_on_rival_result)
		challenges.driving_skill.connect(_on_driving_skill)
	reputation = int(SaveManager.data.get("matatu_reputation", 0))
	street_cred = int(SaveManager.data.get("street_cred", 0))
	_last_decay_msec = Time.get_ticks_msec()
	hype_changed.emit(hype, combo, "NAIROBI SHIFT READY")

func _process(_delta: float) -> void:
	if combo <= 0:
		return
	var now := Time.get_ticks_msec()
	if now - _last_event_msec > 12000 and now - _last_decay_msec > 2500:
		_last_decay_msec = now
		combo = maxi(combo - 1, 0)
		hype = maxi(hype - 4, 0)
		hype_changed.emit(hype, combo, "KEEP MOVING • BUILD THE HYPE")

func _on_fare_awarded(_amount: int, _balance: int) -> void:
	_add_hype(18, "STAGE SERVICE +18 HYPE")
	_add_reputation(25)

func _on_corridor_completed(_name: String, _reward: int, _balance: int, _elapsed: float, _best: float, _new_best: bool, _fares: int, _passengers: int) -> void:
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
	var multiplier: int = clampi(combo, 1, 5)
	hype = clampi(hype + amount * multiplier, 0, 999)
	var previous_best := int(SaveManager.data.get("best_hype", 0))
	if hype > previous_best:
		SaveManager.data["best_hype"] = hype
		SaveManager.save_game()
	hype_changed.emit(hype, combo, "%s • CRED %d" % [message, street_cred])

func _add_reputation(amount: int) -> void:
	reputation += amount
	SaveManager.data["matatu_reputation"] = reputation
	street_cred += maxi(1, int(amount / 5))
	SaveManager.data["street_cred"] = street_cred
	SaveManager.save_game()
	reputation_awarded.emit(amount, reputation)

func _on_challenge_changed(message: String, clean_streak: int) -> void:
	if clean_streak > 0:
		_add_hype(mini(4 + clean_streak * 2, 16), message)

func _on_rival_result(won: bool, _player_time: float, _rival_time: float, _reward: int) -> void:
	if won:
		_add_hype(35, "RIVAL BEATEN +35 HYPE")
		_add_reputation(90)
	else:
		combo = 0
		hype = maxi(hype - 20, 0)
		hype_changed.emit(hype, combo, "RIVAL GOT THERE FIRST • RUN IT BACK")


func _on_driving_skill(message: String, points: int) -> void:
	_add_hype(points, message)
