class_name PassengerStop
extends Area3D

signal service_completed(stop: PassengerStop)

@export_enum("pickup", "dropoff") var stop_kind: String = "pickup"
@export var required_stop_seconds: float = 1.5

@onready var marker: MeshInstance3D = $Marker
@onready var title_label: Label3D = $Title
@onready var progress_label: Label3D = $Progress
@onready var passengers: Node3D = $Passengers

var active: bool = false
var service_progress: float = 0.0
var completed: bool = false

func _ready() -> void:
	monitoring = true
	_update_visuals()

func _physics_process(delta: float) -> void:
	if not active or completed:
		return
	var vehicle: Node3D = GameManager.get_player_vehicle() as Node3D
	if vehicle == null or not overlaps_body(vehicle):
		service_progress = 0.0
		_update_progress_text()
		return
	var speed: float = 999.0
	if vehicle.has_method("get_speed_kph"):
		speed = float(vehicle.call("get_speed_kph"))
	if speed > 4.0:
		service_progress = 0.0
		progress_label.text = "SLOW DOWN"
		return
	service_progress += delta
	_update_progress_text()
	if service_progress >= required_stop_seconds:
		completed = true
		progress_label.text = "PASSENGERS ON" if stop_kind == "pickup" else "FARE COMPLETE"
		service_completed.emit(self)

func set_active(value: bool) -> void:
	active = value
	completed = false
	service_progress = 0.0
	_update_visuals()

func _update_visuals() -> void:
	visible = active
	monitoring = active
	if not is_node_ready():
		return
	title_label.text = "PICK UP PASSENGERS" if stop_kind == "pickup" else "DROP OFF PASSENGERS"
	passengers.visible = stop_kind == "pickup"
	_update_progress_text()

func _update_progress_text() -> void:
	if not active:
		progress_label.text = ""
		return
	var percentage: int = int(clampf(service_progress / required_stop_seconds, 0.0, 1.0) * 100.0)
	progress_label.text = "STOP HERE  %d%%" % percentage
