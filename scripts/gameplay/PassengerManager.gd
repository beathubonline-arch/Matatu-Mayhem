class_name PassengerManager
extends Node

signal passenger_status_changed(message: String)
signal fare_awarded(amount: int, new_balance: int)

enum ServiceState { WAITING_FOR_PICKUP, PASSENGERS_ONBOARD }

@export var pickup_stop_path: NodePath
@export var dropoff_stop_path: NodePath
@export var fare_amount: int = 5000
@export var enabled: bool = true

var state: ServiceState = ServiceState.WAITING_FOR_PICKUP
var pickup_stop: PassengerStop
var dropoff_stop: PassengerStop

func _ready() -> void:
	pickup_stop = get_node_or_null(pickup_stop_path) as PassengerStop
	dropoff_stop = get_node_or_null(dropoff_stop_path) as PassengerStop
	if not enabled:
		if pickup_stop != null:
			pickup_stop.set_active(false)
		if dropoff_stop != null:
			dropoff_stop.set_active(false)
		return
	if pickup_stop == null or dropoff_stop == null:
		push_error("PassengerManager requires pickup and drop-off stops.")
		return
	pickup_stop.service_completed.connect(_on_stop_completed)
	dropoff_stop.service_completed.connect(_on_stop_completed)
	_start_next_trip()

func _on_stop_completed(stop: PassengerStop) -> void:
	if state == ServiceState.WAITING_FOR_PICKUP and stop == pickup_stop:
		state = ServiceState.PASSENGERS_ONBOARD
		pickup_stop.set_active(false)
		dropoff_stop.set_active(true)
		passenger_status_changed.emit("PASSENGERS ONBOARD — DRIVE TO DROP-OFF")
	elif state == ServiceState.PASSENGERS_ONBOARD and stop == dropoff_stop:
		dropoff_stop.set_active(false)
		EconomyManager.add_passenger_fare(fare_amount)
		SaveManager.data["passenger_trips_completed"] = int(SaveManager.data.get("passenger_trips_completed", 0)) + 1
		SaveManager.save_game()
		fare_awarded.emit(fare_amount, EconomyManager.get_money())
		call_deferred("_start_next_trip")

func _start_next_trip() -> void:
	state = ServiceState.WAITING_FOR_PICKUP
	pickup_stop.set_active(true)
	dropoff_stop.set_active(false)
	passenger_status_changed.emit("PICK UP PASSENGERS AT THE GREEN MATATU STAGE")
