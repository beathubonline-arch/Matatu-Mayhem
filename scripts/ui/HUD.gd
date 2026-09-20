extends CanvasLayer

@export var route_manager_path: NodePath
@export var passenger_manager_path: NodePath
@export var culture_manager_path: NodePath
@export var radio_path: NodePath
@export var corridor_service_path: NodePath

@onready var speed_label: Label = $Margin/VBox/TopBar/Speed
@onready var money_label: Label = $Margin/VBox/TopBar/Money
@onready var objective_label: Label = $Margin/VBox/Objective
@onready var timer_label: Label = $Margin/VBox/Timer
@onready var passenger_label: Label = $Margin/VBox/PassengerObjective
@onready var fare_notice: Label = $FareNotice
@onready var controls_label: Label = $Margin/VBox/Controls
@onready var hype_label: Label = $Margin/VBox/Hype
@onready var radio_label: Label = $RadioPanel/RadioText
@onready var finish_panel: PanelContainer = $FinishPanel
@onready var finish_title: Label = $FinishPanel/VBox/Title
@onready var finish_summary: Label = $FinishPanel/VBox/Summary
@onready var replay_button: Button = $FinishPanel/VBox/Replay
@onready var route_select_panel: PanelContainer = $RouteSelectPanel

var route_manager: RouteManager
var passenger_manager: PassengerManager
var culture_manager: Node
var radio: Node
var corridor_service: Node
var _fare_notice_time: float = 0.0
var _corridor_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	finish_panel.visible = false
	replay_button.pressed.connect(_on_replay_pressed)
	$RouteSelectPanel/VBox/Waiyaki.pressed.connect(func(): _select_corridor(0))
	$RouteSelectPanel/VBox/Thika.pressed.connect(func(): _select_corridor(1))
	$RouteSelectPanel/VBox/Mombasa.pressed.connect(func(): _select_corridor(2))
	$RouteSelectPanel/VBox/Ngong.pressed.connect(func(): _select_corridor(3))
	route_select_panel.visible = true
	GameManager.set_game_state(GameManager.GameState.ROUTE_SELECT)
	objective_label.text = "CHOOSE YOUR NAIROBI ROUTE"
	passenger_label.text = "WAIYAKI • THIKA • MOMBASA • NGONG"
	timer_label.text = "00:00.00"
	EconomyManager.money_changed.connect(_on_money_changed)
	_on_money_changed(EconomyManager.get_money())
	if not route_manager_path.is_empty():
		route_manager = get_node_or_null(route_manager_path) as RouteManager
	if not passenger_manager_path.is_empty():
		passenger_manager = get_node_or_null(passenger_manager_path) as PassengerManager
	fare_notice.visible = false
	if not culture_manager_path.is_empty():
		culture_manager = get_node_or_null(culture_manager_path)
	if culture_manager != null:
		culture_manager.hype_changed.connect(_on_hype_changed)
		culture_manager.reputation_awarded.connect(_on_reputation_awarded)
	if not radio_path.is_empty():
		radio = get_node_or_null(radio_path)
	if radio != null:
		radio.station_changed.connect(_on_radio_changed)
	if not corridor_service_path.is_empty():
		corridor_service = get_node_or_null(corridor_service_path)
	if corridor_service != null:
		corridor_service.corridor_changed.connect(_on_corridor_changed)
		corridor_service.corridor_completed.connect(_on_corridor_completed)
		corridor_service.fare_awarded.connect(_on_fare_awarded)
		corridor_service.service_progress.connect(_on_service_progress)
		corridor_service.run_time_changed.connect(_on_corridor_time_changed)
		corridor_service.passenger_load_changed.connect(_on_passenger_load_changed)
	_on_hype_changed(0, 0, "NAIROBI SHIFT READY")
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		controls_label.visible = false
	else:
		controls_label.text = "W/S Accelerate & Brake   A/D Steer   SPACE Handbrake   R Reset   ESC Pause"

func _process(_delta: float) -> void:
	var vehicle = GameManager.get_player_vehicle()
	if vehicle != null and vehicle.has_method("get_speed_kph"):
		speed_label.text = "%03d km/h" % int(vehicle.call("get_speed_kph"))
	else:
		speed_label.text = "000 km/h"
	if corridor_service != null and bool(corridor_service.get("active")):
		timer_label.text = _format_time(_corridor_time)
	elif GameManager.current_state == GameManager.GameState.ROUTE_SELECT:
		timer_label.text = "00:00.00"
	if _fare_notice_time > 0.0:
		_fare_notice_time -= _delta
		if _fare_notice_time <= 0.0:
			fare_notice.visible = false

func _on_money_changed(total: int) -> void:
	money_label.text = "KSh %s" % _format_number(total)

func _on_checkpoint_progress(current: int, total: int) -> void:
	if total <= 0:
		objective_label.text = "FREE DRIVE"
	elif current >= total:
		objective_label.text = "ROUTE COMPLETE"
	else:
		objective_label.text = "CHECKPOINT %d / %d" % [current + 1, total]

func _on_passenger_status_changed(message: String) -> void:
	passenger_label.text = message

func _on_fare_awarded(amount: int, new_balance: int) -> void:
	fare_notice.text = "+ KSh %s  PASSENGER FARE\\nBALANCE: KSh %s" % [_format_number(amount), _format_number(new_balance)]
	fare_notice.visible = true
	_fare_notice_time = 4.0

func _on_route_completed(elapsed: float, reward: int) -> void:
	finish_panel.visible = true
	finish_title.text = "ROUTE COMPLETE"
	finish_summary.text = "Time: %s\\nReward: KSh %s\\nTotal: KSh %s" % [_format_time(elapsed), _format_number(reward), _format_number(EconomyManager.get_money())]

func _on_replay_pressed() -> void:
	finish_panel.visible = false
	if corridor_service != null:
		route_select_panel.visible = true
		GameManager.set_game_state(GameManager.GameState.ROUTE_SELECT)
		objective_label.text = "CHOOSE YOUR NEXT ROUTE"
		passenger_label.text = "WAIYAKI • THIKA • MOMBASA • NGONG"
		return
	if route_manager != null:
		route_manager.restart_route()

func _format_time(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	var secs := int(seconds) % 60
	var centis := int(fmod(seconds, 1.0) * 100.0)
	return "%02d:%02d.%02d" % [minutes, secs, centis]

func _format_number(value: int) -> String:
	var s := str(value)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

func _on_hype_changed(value: int, combo: int, message: String) -> void:
	var combo_text := "" if combo <= 1 else "  x%d COMBO" % combo
	hype_label.text = "HYPE %03d%s  •  %s" % [value, combo_text, message]

func _on_reputation_awarded(_amount: int, total: int) -> void:
	hype_label.text += "  •  REP %d" % total

func _on_radio_changed(station: String, track: String, artist: String) -> void:
	radio_label.text = "♫ %s\\n%s — %s\\n[M] RADIO  [N] NEXT" % [station, artist, track]

func _on_corridor_changed(name: String, stop_name: String, current: int, total: int) -> void:
	passenger_label.text = "%s  •  STAGE %d/%d  •  %s" % [name, current, total, stop_name]

func _on_corridor_completed(name: String, reward: int, balance: int, elapsed: float, best: float, new_best: bool, fares: int, passengers: int) -> void:
	GameManager.set_game_state(GameManager.GameState.ROUTE_COMPLETE)
	objective_label.text = "ROUTE COMPLETE"
	fare_notice.text = "%s COMPLETE  +KSh %s\\nBALANCE: KSh %s" % [name, _format_number(reward), _format_number(balance)]
	fare_notice.visible = true
	_fare_notice_time = 5.0
	finish_panel.visible = true
	finish_title.text = "%s COMPLETE" % name
	var record_text := "NEW PERSONAL BEST!" if new_best else "Best: %s" % _format_time(best)
	finish_summary.text = "Time: %s\\n%s\\nPassengers: %d  •  Fares: KSh %s\\nRoute bonus: KSh %s\\nTotal: KSh %s" % [_format_time(elapsed), record_text, passengers, _format_number(fares), _format_number(reward), _format_number(balance)]
	replay_button.text = "CHOOSE NEXT ROUTE"

func _select_corridor(index: int) -> void:
	if corridor_service == null:
		return
	GameManager.set_game_state(GameManager.GameState.PLAYING)
	corridor_service.call("select_corridor", index)
	_corridor_time = 0.0
	route_select_panel.visible = false
	finish_panel.visible = false

func _on_service_progress(message: String) -> void:
	objective_label.text = message

func _on_corridor_time_changed(seconds: float) -> void:
	_corridor_time = seconds

func _on_passenger_load_changed(onboard: int, capacity: int, boarded: int, alighted: int) -> void:
	var movement := ""
	if boarded > 0:
		movement += "  +%d IN" % boarded
	if alighted > 0:
		movement += "  -%d OUT" % alighted
	passenger_label.text = "PASSENGERS %d/%d%s" % [onboard, capacity, movement]
