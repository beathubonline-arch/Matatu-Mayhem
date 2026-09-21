extends CanvasLayer

@export var culture_manager_path: NodePath
@export var radio_path: NodePath
@export var corridor_service_path: NodePath
@export var challenge_manager_path: NodePath
@export var career_manager_path: NodePath
@export var rival_manager_path: NodePath
@export var street_king_manager_path: NodePath

@onready var speed_label: Label = $Margin/VBox/TopBar/Speed
@onready var money_label: Label = $Margin/VBox/TopBar/Money
@onready var objective_label: Label = $Margin/VBox/ObjectiveCard/Objective
@onready var timer_label: Label = $Margin/VBox/Timer
@onready var passenger_label: Label = $Margin/VBox/PassengerObjective
@onready var passenger_load_label: Label = $Margin/VBox/PassengerLoad
@onready var navigation_label: Label = $Margin/VBox/Navigation
@onready var message_card: PanelContainer = $MessageCard
@onready var fare_notice: Label = $MessageCard/FareNotice
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
var street_king_manager: Node
var _fare_notice_time: float = 0.0
var _corridor_time: float = 0.0
var _last_completed_corridor := -1
var _event_text := ""
var _event_time := 0.0
var _rush_time := 0.0
var _rush_bonus := 0
var _shop_index := 0
var _service_objective := "FOLLOW ROUTE"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	finish_panel.visible = false
	replay_button.pressed.connect(_on_replay_pressed)
	$RouteSelectPanel/VBox/Ngong.pressed.connect(func(): _select_corridor(0))
	$RouteSelectPanel/VBox/Mombasa.pressed.connect(func(): _select_corridor(1))
	$RouteSelectPanel/VBox/Waiyaki.pressed.connect(func(): _select_corridor(2))
	$RouteSelectPanel/VBox/Thika.pressed.connect(func(): _select_corridor(3))
	$RouteSelectPanel/VBox/EngineUpgrade.pressed.connect(func(): _buy_upgrade("engine"))
	$RouteSelectPanel/VBox/BrakeUpgrade.pressed.connect(func(): _buy_upgrade("brakes"))
	$RouteSelectPanel/VBox/CapacityUpgrade.pressed.connect(func(): _buy_upgrade("capacity"))
	$RouteSelectPanel/VBox/NganyaSelect.pressed.connect(_cycle_owned_nganya)
	$RouteSelectPanel/VBox/NganyaBuy.pressed.connect(_buy_market_nganya)
	route_select_panel.visible = true
	GameManager.set_game_state(GameManager.GameState.ROUTE_SELECT)
	objective_label.text = "CHOOSE YOUR NAIROBI ROUTE • CLICK OR PRESS 1–4"
	passenger_label.text = "START: NGONG ROAD + MOMBASA ROAD • UNLOCK WAIYAKI + THIKA"
	passenger_load_label.text = "PASSENGERS 0/%d" % _current_capacity()
	navigation_label.text = "NAV • SELECT ROUTE"
	timer_label.text = "00:00.00"
	EconomyManager.money_changed.connect(_on_money_changed)
	_on_money_changed(EconomyManager.get_money())
	message_card.visible = false
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
		corridor_service.matatu_moment.connect(_on_matatu_moment)
	if not challenge_manager_path.is_empty():
		challenge_manager = get_node_or_null(challenge_manager_path)
	if challenge_manager != null:
		challenge_manager.challenge_changed.connect(_on_challenge_changed)
		challenge_manager.penalty_applied.connect(_on_penalty_applied)
		challenge_manager.rival_result.connect(_on_rival_result)
	if not street_king_manager_path.is_empty():
		street_king_manager = get_node_or_null(street_king_manager_path)
	if street_king_manager != null:
		street_king_manager.shift_changed.connect(_on_shift_changed)
		street_king_manager.shift_completed.connect(_on_shift_completed)
		street_king_manager.mastery_changed.connect(_on_mastery_changed)
		call_deferred("_refresh_shift_banner")
	if not rival_manager_path.is_empty():
		rival_manager = get_node_or_null(rival_manager_path)
	if rival_manager != null and rival_manager.has_signal("rival_pressure"):
		rival_manager.rival_pressure.connect(_on_rival_pressure)
	if not career_manager_path.is_empty():
		career_manager = get_node_or_null(career_manager_path)
	if career_manager != null:
		career_manager.career_changed.connect(_on_career_changed)
		career_manager.nganya_unlocked.connect(_on_nganya_unlocked)
		career_manager.nganya_available.connect(_on_nganya_available)
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
	if _event_time > 0.0:
		_event_time = maxf(_event_time - _delta, 0.0)
	if _rush_time > 0.0:
		_rush_time = maxf(_rush_time - _delta, 0.0)
	_render_live_objective()
	if _fare_notice_time > 0.0:
		_fare_notice_time -= _delta
		if _fare_notice_time <= 0.0:
			message_card.visible = false

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
	_message_style("reward")
	fare_notice.text = "+ KSh %s  PASSENGER FARE\\nBALANCE: KSh %s" % [_format_number(amount), _format_number(new_balance)]
	_show_message_card()
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
		objective_label.text = "RETURN TRIP STARTED • FOLLOW THE ROAD BACK TO CBD"
		return
	route_select_panel.visible = true
	GameManager.set_game_state(GameManager.GameState.ROUTE_SELECT)
	objective_label.text = "CHOOSE YOUR NEXT ROUTE FROM CBD"
	passenger_label.text = "CBD HUB • EVERY RUN LEAVES CBD AND RETURNS TO CBD"
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
	_show_message_card()
	_fare_notice_time = 5.0
	finish_panel.visible = true
	finish_title.text = "%s COMPLETE" % name
	var record_text := "NEW PERSONAL BEST!" if new_best else "Best: %s" % _format_time(best)
	finish_summary.text = "Time: %s\\n%s\\nPassengers: %d  •  Fares: KSh %s\\nRoute bonus: KSh %s\\nTotal: KSh %s\\nMASTERY %d/10 • %s\\n\\nSTOP AT TERMINUS • NO MANUAL U-TURN NEEDED" % [_format_time(elapsed), record_text, passengers, _format_number(fares), _format_number(reward), _format_number(balance), _route_mastery(int(corridor_service.get("corridor_index"))), street_king_manager.call("get_shift_summary") if street_king_manager != null else "STREET KING SHIFT"]
	_last_completed_corridor = int(corridor_service.get("corridor_index")) if corridor_service != null else -1
	replay_button.text = "START RETURN TRIP TO CBD" if corridor_service != null and not bool(corridor_service.get("inbound")) else "BACK AT CBD • CHOOSE NEXT ROUTE"
	_refresh_route_unlocks()

func _select_corridor(index: int) -> void:
	if corridor_service == null:
		fare_notice.text = "ROUTE SYSTEM NOT READY"
		_show_message_card()
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
	_service_objective = message
	_render_live_objective()

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
	var unlocked := maxi(int(SaveManager.data.get("unlocked_corridors", 2)), 2)
	var buttons: Array[Button] = [
		$RouteSelectPanel/VBox/Ngong,
		$RouteSelectPanel/VBox/Mombasa,
		$RouteSelectPanel/VBox/Waiyaki,
		$RouteSelectPanel/VBox/Thika
	]
	var base_texts := [
		"NGONG ROAD • TIER 1 • CITY HUSTLE • TIGHT STAGES • KSh 10,000",
		"MOMBASA ROAD • TIER 1 • INDUSTRIAL RUN • LONG STRAIGHTS • KSh 12,000",
		"WAIYAKI WAY • TIER 2 • WESTLANDS EXPRESS • RIVAL PRESSURE • KSh 15,000",
		"THIKA ROAD • TIER 3 • SUPERHIGHWAY • HIGH SPEED • KSh 18,000"
	]
	var best_times: Dictionary = SaveManager.data.get("corridor_best_times", {})
	for i in range(buttons.size()):
		var locked := i >= unlocked
		buttons[i].disabled = locked
		if locked:
			buttons[i].text = "🔒 COMPLETE CBD RUNS TO UNLOCK • %s" % base_texts[i]
		else:
			var best := float(best_times.get(str(i), 0.0))
			var pb := "" if best <= 0.0 else " • PB %s" % _format_time(best)
			buttons[i].text = "%s • MASTERY %d/10%s" % [base_texts[i], _route_mastery(i), pb]

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
		_show_message_card()
		_fare_notice_time = 2.5
		return
	var cost := _upgrade_cost(kind)
	if not EconomyManager.spend_money(cost):
		fare_notice.text = "NEED KSh %s FOR %s" % [_format_number(cost), kind.to_upper()]
		_show_message_card()
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
	_show_message_card()
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

func _cycle_owned_nganya() -> void:
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
	_message_style("default")
	fare_notice.text = "NOW DRIVING • %s" % String(owned[index]).to_upper()
	_show_message_card()
	_fare_notice_time = 2.5

func _buy_market_nganya() -> void:
	var available: Array = career_manager.call("get_available_nganyas") if career_manager != null else []
	if available.is_empty():
		_message_style("default")
		fare_notice.text = "GARAGE MARKET • BUILD REP TO UNLOCK NEW NGANYAS"
		_show_message_card()
		_fare_notice_time = 3.0
		return
	_shop_index = _shop_index % available.size()
	var entry: Dictionary = available[_shop_index]
	var name := String(entry["name"])
	var price := int(entry["price"])
	if career_manager.call("buy_nganya", name):
		var vehicle = GameManager.get_player_vehicle()
		if vehicle != null and vehicle.has_method("refresh_selected_nganya"):
			vehicle.call("refresh_selected_nganya")
		_message_style("unlock")
		fare_notice.text = "NEW NGANYA • %s\nPAID KSh %s • READY TO ROLL" % [name.to_upper(), _format_number(price)]
		_show_message_card()
		_fare_notice_time = 4.0
		_shop_index = 0
		_refresh_nganya_selector()
		return
	_message_style("danger")
	fare_notice.text = "NEED KSh %s • %s\nKEEP WORKING THE ROUTES" % [_format_number(price), name.to_upper()]
	_show_message_card()
	_fare_notice_time = 3.0
	_shop_index = (_shop_index + 1) % available.size()
	_refresh_nganya_selector()

func _refresh_nganya_selector() -> void:
	var owned: Array = SaveManager.data.get("owned_nganyas", ["Maverick"])
	var selected := String(SaveManager.data.get("selected_nganya", "Maverick")).to_upper()
	$RouteSelectPanel/VBox/GarageTitle.text = "%s GARAGE • %d OWNED" % [selected, owned.size()]
	$RouteSelectPanel/VBox/NganyaSelect.text = "DRIVE • %s • CLICK TO SWITCH OWNED" % selected
	var available: Array = career_manager.call("get_available_nganyas") if career_manager != null else []
	if available.is_empty():
		$RouteSelectPanel/VBox/NganyaBuy.text = "GARAGE MARKET • BUILD REP FOR NEW STOCK"
		$RouteSelectPanel/VBox/NganyaBuy.disabled = true
	else:
		$RouteSelectPanel/VBox/NganyaBuy.disabled = false
		_shop_index = _shop_index % available.size()
		var entry: Dictionary = available[_shop_index]
		$RouteSelectPanel/VBox/NganyaBuy.text = "BUY • %s • KSh %s" % [String(entry["name"]).to_upper(), _format_number(int(entry["price"]))]

func _on_challenge_changed(message: String, clean_streak: int) -> void:
	var suffix := "" if clean_streak <= 0 else " • CLEAN x%d" % clean_streak
	fare_notice.text = "%s%s" % [message, suffix]
	_show_message_card()
	_fare_notice_time = 3.0

func _on_penalty_applied(amount: int, balance: int, reason: String) -> void:
	_message_style("danger")
	fare_notice.text = "%s • -KSh %s\nBALANCE: KSh %s" % [reason, _format_number(amount), _format_number(balance)]
	_show_message_card()
	_fare_notice_time = 3.0

func _on_rival_result(won: bool, player_time: float, rival_time: float, reward: int) -> void:
	if won:
		fare_notice.text = "RIVAL BEATEN • +KSh %s\nYOU %s • RIVAL %s" % [_format_number(reward), _format_time(player_time), _format_time(rival_time)]
	else:
		fare_notice.text = "RIVAL WINS THIS RUN\nYOU %s • RIVAL %s • RUN IT AGAIN" % [_format_time(player_time), _format_time(rival_time)]
	_show_message_card()
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
	_show_message_card()
	_fare_notice_time = 5.0


func _on_conductor_call(message: String) -> void:
	fare_notice.text = "CONDUCTOR • %s" % message
	_show_message_card()
	_fare_notice_time = 2.8


func _on_stage_rush_changed(seconds_left: float, bonus: int) -> void:
	_rush_time = seconds_left
	_rush_bonus = bonus


func _on_stage_grade(message: String, reward: int) -> void:
	_message_style("hype")
	fare_notice.text = "%s • +KSh %s" % [message, _format_number(reward)]
	_show_message_card()
	_fare_notice_time = 2.6


func _on_event_changed(message: String, seconds_left: float) -> void:
	_event_text = message
	_event_time = seconds_left


func _on_route_unlocked(name: String) -> void:
	_message_style("unlock")
	fare_notice.text = "NEW ROUTE UNLOCKED • %s\nNAIROBI JUST GOT BIGGER" % name.to_upper()
	_show_message_card()
	_fare_notice_time = 5.0


func _on_rival_pressure(message: String) -> void:
	fare_notice.text = "RIVAL • %s" % message
	_show_message_card()
	_fare_notice_time = 2.5


func _on_direction_changed(label: String) -> void:
	fare_notice.text = "ROUTE DIRECTION • %s" % label
	_show_message_card()
	_fare_notice_time = 2.5


func _render_live_objective() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if _event_time > 0.0 and not _event_text.is_empty():
		objective_label.text = "⚡ %s • %.0fs" % [_event_text, _event_time]
		return
	if _rush_time > 0.0 and _rush_bonus > 0:
		objective_label.text = "STAGE RUSH • %.1fs • +KSh %s" % [_rush_time, _format_number(_rush_bonus)]
		return
	objective_label.text = _service_objective


func _on_nganya_available(name: String, price: int) -> void:
	fare_notice.text = "GARAGE STOCK UNLOCKED • %s • KSh %s" % [name.to_upper(), _format_number(price)]
	_show_message_card()
	_fare_notice_time = 4.0
	_refresh_nganya_selector()


func _show_message_card() -> void:
	message_card.visible = true
	message_card.modulate = Color(1, 1, 1, 0)
	message_card.scale = Vector2(0.78, 0.78)
	message_card.pivot_offset = message_card.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(message_card, "modulate", Color.WHITE, 0.14)
	tween.tween_property(message_card, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(message_card, "scale", Vector2.ONE, 0.10)

func _message_style(kind: String) -> void:
	match kind:
		"reward":
			fare_notice.modulate = Color("62ff82")
		"danger":
			fare_notice.modulate = Color("ff4d64")
		"hype":
			fare_notice.modulate = Color("ff5ca8")
		"unlock":
			fare_notice.modulate = Color("ffe15a")
		_:
			fare_notice.modulate = Color("5cecff")


func _on_matatu_moment(message: String, reward: int) -> void:
	_message_style("hype")
	fare_notice.text = "⚡ %s\n+KSh %s • KEEP IT MOVING!" % [message, _format_number(reward)]
	_show_message_card()
	_fare_notice_time = 3.0


func _refresh_shift_banner() -> void:
	if street_king_manager != null:
		passenger_label.text = street_king_manager.call("get_shift_summary")

func _on_shift_changed(summary: String) -> void:
	if GameManager.current_state == GameManager.GameState.ROUTE_SELECT:
		passenger_label.text = summary

func _on_shift_completed(reward: int, rep_reward: int) -> void:
	_message_style("unlock")
	fare_notice.text = "STREET KING SHIFT COMPLETE!\n+KSh %s • +%d REP • NAIROBI NOTICED" % [_format_number(reward), rep_reward]
	_show_message_card()
	_fare_notice_time = 6.0

func _on_mastery_changed(_corridor: int, level: int, summary: String) -> void:
	_message_style("hype")
	fare_notice.text = "%s\nMASTERY LEVEL %d • KEEP PUSHING" % [summary, level]
	_show_message_card()
	_fare_notice_time = 5.0

func _route_mastery(index: int) -> int:
	if street_king_manager == null:
		return 1
	return int(street_king_manager.call("get_route_mastery", index))
