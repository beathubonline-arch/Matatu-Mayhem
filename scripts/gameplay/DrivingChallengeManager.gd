class_name DrivingChallengeManager
extends Node

signal challenge_changed(message: String, clean_streak: int)
signal penalty_applied(amount: int, balance: int, reason: String)
signal rival_result(won: bool, player_time: float, rival_time: float, reward: int)

@export var player_path: NodePath
@export var corridor_service_path: NodePath

const COLLISION_PENALTY := 350
const CLEAN_STAGE_REWARD := 250
const RIVAL_WIN_REWARD := 1800
const IMPACT_COOLDOWN := 1.2

var player: VehicleBody3D
var corridor_service: CorridorServiceManager
var clean_streak := 0
var _last_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _last_stop_index := 0
var _run_collisions := 0

func _ready() -> void:
	player = get_node_or_null(player_path) as VehicleBody3D
	corridor_service = get_node_or_null(corridor_service_path) as CorridorServiceManager
	clean_streak = int(SaveManager.data.get("clean_streak", 0))
	if corridor_service != null:
		corridor_service.corridor_changed.connect(_on_corridor_changed)
		corridor_service.corridor_completed.connect(_on_corridor_completed)
	if player != null:
		_last_velocity = player.linear_velocity

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	if GameManager.current_state != GameManager.GameState.PLAYING:
		_last_velocity = player.linear_velocity
		return
	var velocity_change := (player.linear_velocity - _last_velocity).length()
	_last_velocity = player.linear_velocity
	if _impact_cooldown <= 0.0 and velocity_change > 7.5 and player.linear_velocity.length() > 1.5:
		_register_collision()

func _register_collision() -> void:
	_impact_cooldown = IMPACT_COOLDOWN
	_run_collisions += 1
	clean_streak = 0
	SaveManager.data["clean_streak"] = 0
	var penalty := mini(COLLISION_PENALTY, EconomyManager.get_money())
	if penalty > 0:
		EconomyManager.spend_money(penalty)
	SaveManager.save_game()
	penalty_applied.emit(penalty, EconomyManager.get_money(), "CRASH")
	challenge_changed.emit("CRASH! CLEAN STREAK RESET", clean_streak)

func _on_corridor_changed(_name: String, _stop_name: String, current: int, _total: int) -> void:
	if current == 1:
		_last_stop_index = 0
		_run_collisions = 0
		return
	if current > _last_stop_index + 1:
		clean_streak += 1
		SaveManager.data["clean_streak"] = clean_streak
		SaveManager.data["best_clean_streak"] = maxi(int(SaveManager.data.get("best_clean_streak", 0)), clean_streak)
		EconomyManager.add_money(CLEAN_STAGE_REWARD)
		SaveManager.save_game()
		challenge_changed.emit("CLEAN STAGE +KSh %d • STREAK x%d" % [CLEAN_STAGE_REWARD, clean_streak], clean_streak)
	_last_stop_index = current - 1

func _on_corridor_completed(_name: String, _reward: int, _balance: int, elapsed: float, _best: float, _new_best: bool, _fares: int, _passengers: int) -> void:
	var corridor_idx := corridor_service.corridor_index if corridor_service != null else 0
	var rival_time := 82.0 + float(corridor_idx) * 9.0
	var won := elapsed <= rival_time
	var reward := 0
	if won:
		reward = RIVAL_WIN_REWARD + corridor_idx * 350
		EconomyManager.add_money(reward)
		SaveManager.data["rival_wins"] = int(SaveManager.data.get("rival_wins", 0)) + 1
	else:
		SaveManager.data["rival_losses"] = int(SaveManager.data.get("rival_losses", 0)) + 1
	SaveManager.save_game()
	rival_result.emit(won, elapsed, rival_time, reward)
