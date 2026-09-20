extends CanvasLayer

@export var culture_manager_path: NodePath
@export var radio_path: NodePath
@export var corridor_service_path: NodePath
@export var challenge_manager_path: NodePath
@export var career_manager_path: NodePath
@export var rival_manager_path: NodePath

@onready var speed_label: Label = $Margin/VBox/TopBar/Speed
@onready var money_label: Label = $Margin/VBox/TopBar/Money
@onready var objective_label: Label = $Margin/VBox/Objective
@onready var timer_label: Label = $Margin/VBox/Timer
@onready var passenger_label: Label = $Margin/VBox/PassengerObjective
@onready var passenger_load_label: Label = $Margin/VBox/PassengerLoad
@onready var navigation_label: Label = $Margin/VBox/Navigation
@onready var fare_notice: Label = $FareNotice
@onready var controls_label: Label = $Margin/VBox/Controls
@onready var hype_label: Label = $Margin/VBox/Hype
@onready var radio_label: Label = $RadioPanel/RadioText
@onready var finish_panel: PanelContainer = $FinishPanel
@onready var finish_title: Label = $FinishPanel/VBox/Title
@onready var finish_summary: Label = $FinishPanel/VBox/Summary
@onready var replay_button: Button = $FinishPanel/VBox/Replay
@onready var route_select_panel: PanelContainer = $RouteSelectPanel

var culture_manager: Node
var radio: Node
var corridor_service: Node
var challenge_manager: Node
var career_manager: Node
var rival_manager: Node
var _fare_notice_time: float = 0.0
var _corridor_time: float = 0.0
var _last_completed_corridor := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	finish_panel.visible = false
	replay_button.pressed.connect(_on_replay_pressed)
	$RouteSelectPanel/VBox/Waiyaki.pressed.connect(func(): _select_corridor(0))
	$RouteSelectPanel/VBox/Thika.pressed.connect(func(): _select_corridor(1))
	$RouteSelectPanel/VBox/Mombasa.pressed.connect(func(): _select_corridor(2))
	$RouteSelectPanel/VBox/Ngong.pressed.connect(func(): _select_corridor(3))
	$RouteSelectPanel/VBox/EngineUpgrade.pressed.connect(func(): _buy_upgrade("engine"))
	$RouteSelectPanel/VBox/BrakeUpgrade.pressed.connect(func(): _buy_upgrade("brakes"))
	$RouteSelectPanel/VBox/CapacityUpgrade.pressed.connect(func(): _buy_upgrade("capacity"))
	$RouteSelectPanel/VBox/NganyaSelect.pressed.connect(_cycle_nganya)
	route_select_panel.visible = true
	GameManager.set_game_state(GameManager.GameState.ROUTE_SELECT)
	objective_label.text = "CHOOSE YOUR NAIROBI ROUTE • CLICK OR PRESS 1–4"
	passenger_label.text = "WAIYAKI • THIKA • MOMBASA • NGONG"
	passenger_load_label.text = "PASSENGERS 0/%d" % _current_capacity()
	navigation_label.text = "NAV • SELECT ROUTE"
	timer_label.text = "00:00.00"
	EconomyManager.money_changed.connect(_on_money_changed)
	_on_money_changed(EconomyManager.get_money())
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
		corridor_service.navigation_changed.connect(_on_navigation_changed)
		corridor_service.maneuver_changed.connect(_on_maneuver_changed)
		corridor_service.route_progress_changed.connect(_on_route_progress_changed)
		corridor_service.conductor_call.connect(_on_conductor_call)
		corridor_service.stage_rush_changed.connect(_on_stage_rush_changed)
		corridor_service.stage_grade.connect(_on_stage_grade)
		corridor_service.event_changed.connect(_on_event_changed)
		corridor_service.route_unlocked.connect(_on_route_unlocked)
		corridor_service.direction_changed.connect(_on_direction_changed)
	if not challenge_manager_path.is_empty():
		challenge_manager = get_node_or_null(challenge_manager_path)
	if challenge_manager != null:
		challenge_manager.challenge_changed.connect(_on_challenge_changed)
		challenge_manager.penalty_applied.connect(_on_penalty_applied)
		challenge_manager.rival_result.connect(_on_rival_result)
	if not rival_manager_path.is_empty():
		rival_manager = get_node_or_null(rival_manager_path)
	if rival_manager != null and rival_manager.has_signal("rival_pressure"):
		rival_manager.rival_pressure.connect(_on_rival_pressure)
	if not career_manager_path.is_empty():
		career_manager = get_node_or_null(career_manager_path)
	if career_manager != null:
		career_manager.career_changed.connect(_on_career_changed)
		career_manager.nganya_unlocked.connect(_on_nganya_unlocked)
	_refresh_route_unlocks()
	_refresh_garage()
	_refresh_nganya_selector()
	_on_hype_changed(0, 0, "NAIROBI SHIFT READY")
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		controls_label.visible = false
	else:
		controls_label.text = "W/S Accelerate & Brake   A/D Steer   SPACE Handbrake   R Reset   ESC Pause"

func _input(event: InputEvent) -> void:
	if not route_select_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_select_corridor(0)
				get_viewport().set_input_as_handled()
			KEY_2:
				_select_corridor(1)
				get_viewport().set_input_as_handled()
			KEY_3:
				_select_corridor(2)
				get_viewport().set_input_as_handled()
			KEY_4:
				_select_corridor(3)
				get_viewport().set_input_as_handled()

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
	if corridor_service == null:
		return
	if not bool(corridor_service.get("inbound")) and _last_completed_corridor >= 0:
		corridor_service.call("select_corridor", _last_completed_corridor, true)
		GameManager.set_game_state(GameManager.GameState.PLAYING)
		_corridor_time = 0.0
		route_select_panel.visible = false
		objective_label.text = "RETURN RUN • BACK TO NAIROBI CBD"
		return
	route_select_panel.visible = true
	GameManager.set_game_state(GameManager.GameState.ROUTE_SELECT)
	objective_label.text = "CHOOSE YOUR NEXT ROUTE FROM CBD"
	passenger_label.text = "CBD → WAIYAKI • THIKA • MOMBASA • NGONG"
	passenger_load_label.text = "PASSENGERS 0/%d" % _current_capacity()
	navigation_label.text = "NAV • SELECT ROUTE"
	_refresh_garage()
	_refresh_nganya_selector()

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
	_last_completed_corridor = int(corridor_service.get("corridor_index")) if corridor_service != null else -1
	replay_button.text = "RETURN TO CBD" if corridor_service != null and not bool(corridor_service.get("inbound")) else "CHOOSE NEXT ROUTE"
	_refresh_route_unlocks()

func _select_corridor(index: int) -> void:
	if corridor_service == null:
		fare_notice.text = "ROUTE SYSTEM NOT READY"
		fare_notice.visible = true
		_fare_notice_time = 3.0
		return
	corridor_service.call("select_corridor", index)
	if not bool(corridor_service.get("active")):
		return
	GameManager.set_game_state(GameManager.GameState.PLAYING)
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
	passenger_load_label.text = "PASSENGERS %d/%d%s" % [onboard, capacity, movement]

func _refresh_route_unlocks() -> void:
	var unlocked := int(SaveManager.data.get("unlocked_corridors", 1))
	var buttons: Array[Button] = [
		$RouteSelectPanel/VBox/Waiyaki,
		$RouteSelectPanel/VBox/Thika,
		$RouteSelectPanel/VBox/Mombasa,
		$RouteSelectPanel/VBox/Ngong
	]
	var base_texts := [
		"WAIYAKI WAY  •  CBD → UTHIRU  •  KSh 9,000 BONUS",
		"THIKA ROAD  •  CBD → KASARANI  •  KSh 11,000 BONUS",
		"MOMBASA ROAD  •  CBD → IMARA DAIMA  •  KSh 12,000 BONUS",
		"NGONG ROAD  •  CBD → JUNCTION  •  KSh 10,000 BONUS"
	]
	var best_times: Dictionary = SaveManager.data.get("corridor_best_times", {})
	for i in range(buttons.size()):
		var locked := i >= unlocked
		buttons[i].disabled = locked
		if locked:
			buttons[i].text = "LOCKED • %s" % base_texts[i]
		else:
			var best := float(best_times.get(str(i), 0.0))
			var pb := "" if best <= 0.0 else "  •  PB %s" % _format_time(best)
			buttons[i].text = "%s%s" % [base_texts[i], pb]


func _on_navigation_changed(distance: float, turn_angle: float) -> void:
	var degrees := rad_to_deg(turn_angle)
	var cue := "STRAIGHT"
	if degrees > 18.0:
		cue = "LEFT"
	elif degrees < -18.0:
		cue = "RIGHT"
	navigation_label.text = "NAV • %s • %dm AHEAD" % [cue, int(distance)]

func _current_capacity() -> int:
	var levels: Dictionary = SaveManager.data.get("upgrade_levels", {})
	return 14 + clampi(int(levels.get("capacity", 0)), 0, 5) * 2

func _upgrade_cost(kind: String) -> int:
	var bases := {"engine": 8000, "brakes": 6000, "capacity": 7000}
	var levels: Dictionary = SaveManager.data.get("upgrade_levels", {})
	return int(bases[kind]) * (clampi(int(levels.get(kind, 0)), 0, 5) + 1)

func _buy_upgrade(kind: String) -> void:
	var levels: Dictionary = SaveManager.data.get("upgrade_levels", {})
	var level: int = clampi(int(levels.get(kind, 0)), 0, 5)
	if level >= 5:
		fare_notice.text = "%s MAX LEVEL" % kind.to_upper()
		fare_notice.visible = true
		_fare_notice_time = 2.5
		return
	var cost := _upgrade_cost(kind)
	if not EconomyManager.spend_money(cost):
		fare_notice.text = "NEED KSh %s FOR %s" % [_format_number(cost), kind.to_upper()]
		fare_notice.visible = true
		_fare_notice_time = 2.5
		return
	levels[kind] = level + 1
	SaveManager.data["upgrade_levels"] = levels
	SaveManager.save_game()
	var vehicle = GameManager.get_player_vehicle()
	if vehicle != null and vehicle.has_method("refresh_saved_upgrades"):
		vehicle.call("refresh_saved_upgrades")
	if corridor_service != null and corridor_service.has_method("refresh_capacity_upgrade"):
		corridor_service.call("refresh_capacity_upgrade")
	fare_notice.text = "%s UPGRADED • LEVEL %d" % [kind.to_upper(), level + 1]
	fare_notice.visible = true
	_fare_notice_time = 2.5
	_refresh_garage()

func _refresh_garage() -> void:
	var levels: Dictionary = SaveManager.data.get("upgrade_levels", {})
	var specs := [
		["engine", $RouteSelectPanel/VBox/EngineUpgrade],
		["brakes", $RouteSelectPanel/VBox/BrakeUpgrade],
		["capacity", $RouteSelectPanel/VBox/CapacityUpgrade]
	]
	for spec in specs:
		var kind: String = spec[0]
		var button: Button = spec[1]
		var level: int = clampi(int(levels.get(kind, 0)), 0, 5)
		if level >= 5:
			button.text = "%s • LEVEL 5 • MAX" % kind.to_upper()
		else:
			button.text = "%s • LEVEL %d → %d • KSh %s" % [kind.to_upper(), level, level + 1, _format_number(_upgrade_cost(kind))]
	_refresh_nganya_selector()

func _cycle_nganya() -> void:
	var owned: Array = SaveManager.data.get("owned_nganyas", ["Maverick"])
	if owned.is_empty():
		return
	var selected := String(SaveManager.data.get("selected_nganya", "Maverick"))
	var index := owned.find(selected)
	index = 0 if index < 0 else (index + 1) % owned.size()
	SaveManager.data["selected_nganya"] = String(owned[index])
	SaveManager.save_game()
	var vehicle = GameManager.get_player_vehicle()
	if vehicle != null and vehicle.has_method("refresh_selected_nganya"):
		vehicle.call("refresh_selected_nganya")
	_refresh_nganya_selector()
	fare_notice.text = "NGANYA SELECTED • %s" % String(owned[index]).to_upper()
	fare_notice.visible = true
	_fare_notice_time = 3.0

func _refresh_nganya_selector() -> void:
	var owned: Array = SaveManager.data.get("owned_nganyas", ["Maverick"])
	var selected := String(SaveManager.data.get("selected_nganya", "Maverick")).to_upper()
	$RouteSelectPanel/VBox/GarageTitle.text = "%s GARAGE • %d OWNED" % [selected, owned.size()]
	$RouteSelectPanel/VBox/NganyaSelect.text = "NGANYA • %s • CLICK TO SWITCH" % selected

func _on_challenge_changed(message: String, clean_streak: int) -> void:
	var suffix := "" if clean_streak <= 0 else " • CLEAN x%d" % clean_streak
	fare_notice.text = "%s%s" % [message, suffix]
	fare_notice.visible = true
	_fare_notice_time = 3.0

func _on_penalty_applied(amount: int, balance: int, reason: String) -> void:
	fare_notice.text = "%s • -KSh %s\nBALANCE: KSh %s" % [reason, _format_number(amount), _format_number(balance)]
	fare_notice.visible = true
	_fare_notice_time = 3.0

func _on_rival_result(won: bool, player_time: float, rival_time: float, reward: int) -> void:
	if won:
		fare_notice.text = "RIVAL BEATEN • +KSh %s\nYOU %s • RIVAL %s" % [_format_number(reward), _format_time(player_time), _format_time(rival_time)]
	else:
		fare_notice.text = "RIVAL WINS THIS RUN\nYOU %s • RIVAL %s • RUN IT AGAIN" % [_format_time(player_time), _format_time(rival_time)]
	fare_notice.visible = true
	_fare_notice_time = 5.0

func _on_maneuver_changed(message: String) -> void:
	navigation_label.text = "NAV • %s" % message

func _on_route_progress_changed(percent: int, off_route: bool) -> void:
	if off_route:
		navigation_label.text = "NAV • OFF ROUTE • REJOIN ROAD"
	elif not navigation_label.text.contains("TURN") and not navigation_label.text.contains("OFF ROUTE"):
		navigation_label.text = "NAV • ROUTE %d%% • FOLLOW ROAD" % percent

func _on_career_changed(rank: int, rank_name: String, xp: int, next_xp: int, owned: Array) -> void:
	var progress := "MAX"
	if next_xp > xp:
		progress = "%d/%d XP" % [xp, next_xp]
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		controls_label.visible = false
	else:
		controls_label.visible = true
		controls_label.text = "W/S DRIVE • A/D STEER • SPACE HANDBRAKE • R RESET  |  CAREER R%d %s • %s • %d NGANYAS" % [rank, rank_name, progress, owned.size()]

func _on_nganya_unlocked(name: String) -> void:
	fare_notice.text = "NEW NGANYA UNLOCKED • %s" % name
	fare_notice.visible = true
	_fare_notice_time = 5.0


func _on_conductor_call(message: String) -> void:
	fare_notice.text = "CONDUCTOR • %s" % message
	fare_notice.visible = true
	_fare_notice_time = 2.8


func _on_stage_rush_changed(seconds_left: float, bonus: int) -> void:
	if seconds_left <= 0.0 or bonus <= 0:
		return
	objective_label.text = "STAGE RUSH • %.1fs • +KSh %s" % [seconds_left, _format_number(bonus)]


func _on_stage_grade(message: String, reward: int) -> void:
	fare_notice.text = "%s • +KSh %s" % [message, _format_number(reward)]
	fare_notice.visible = true
	_fare_notice_time = 2.6


func _on_event_changed(message: String, seconds_left: float) -> void:
	if seconds_left <= 0.0:
		return
	objective_label.text = "⚡ %s • %.0fs" % [message, seconds_left]


func _on_route_unlocked(name: String) -> void:
	fare_notice.text = "NEW ROUTE UNLOCKED • %s\nNAIROBI JUST GOT BIGGER" % name.to_upper()
	fare_notice.visible = true
	_fare_notice_time = 5.0


func _on_rival_pressure(message: String) -> void:
	fare_notice.text = "RIVAL • %s" % message
	fare_notice.visible = true
	_fare_notice_time = 2.5


func _on_direction_changed(label: String) -> void:
	fare_notice.text = "ROUTE DIRECTION • %s" % label
	fare_notice.visible = true
	_fare_notice_time = 2.5
