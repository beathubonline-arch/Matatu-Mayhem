class_name DrivingChallengeManager
extends Node

signal challenge_changed(message: String, clean_streak: int)
signal penalty_applied(amount: int, balance: int, reason: String)
signal rival_result(won: bool, player_time: float, rival_time: float, reward: int)
signal driving_skill(message: String, points: int)

@export var player_path: NodePath
@export var corridor_service_path: NodePath

const COLLISION_PENALTY := 350
const CLEAN_STAGE_REWARD := 250
const RIVAL_WIN_REWARD := 1800
const PERFECT_RUN_REWARD := 1200
const IMPACT_COOLDOWN := 1.2
# Calibrated against the current compressed route lengths and mandatory stage dwell.
const RIVAL_BASE_TIMES := [58.0, 54.0, 58.0, 53.0]

var player: VehicleBody3D
var corridor_service: CorridorServiceManager
var clean_streak := 0
var _last_velocity := Vector3.ZERO
var _impact_cooldown := 0.0
var _last_stop_index := 0
var _run_collisions := 0
var _skill_cooldown := 0.0
var _near_miss_cooldown := 0.0
var _drift_time := 0.0
var _speed_hold := 0.0
var _last_speed_reward := 0.0

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
	_skill_cooldown = maxf(_skill_cooldown - delta, 0.0)
	_near_miss_cooldown = maxf(_near_miss_cooldown - delta, 0.0)
	if GameManager.current_state != GameManager.GameState.PLAYING:
		_last_velocity = player.linear_velocity
		return
	var velocity_change := (player.linear_velocity - _last_velocity).length()
	_last_velocity = player.linear_velocity
	if _impact_cooldown <= 0.0 and velocity_change > 7.5 and player.linear_velocity.length() > 1.5:
		_register_collision()
	_update_driving_skills(delta)
	_update_speed_pressure(delta)

func _register_collision() -> void:
	_impact_cooldown = IMPACT_COOLDOWN
	_run_collisions += 1
	clean_streak = 0
	SaveManager.data["clean_streak"] = 0
	var penalty: int = mini(COLLISION_PENALTY, EconomyManager.get_money())
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
	if _run_collisions == 0:
		EconomyManager.add_money(PERFECT_RUN_REWARD)
		SaveManager.data["perfect_runs"] = int(SaveManager.data.get("perfect_runs", 0)) + 1
		challenge_changed.emit("CLEAN RUN! +KSh %d • STREET CRED UP" % PERFECT_RUN_REWARD, clean_streak + 1)
	var corridor_idx := corridor_service.corridor_index if corridor_service != null else 0
	var rival_time: float = RIVAL_BASE_TIMES[clampi(corridor_idx, 0, RIVAL_BASE_TIMES.size() - 1)]
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


func _update_driving_skills(delta: float) -> void:
	var speed_kph := float(player.call("get_speed_kph")) if player.has_method("get_speed_kph") else player.linear_velocity.length() * 3.6
	var local_velocity := player.global_basis.inverse() * player.linear_velocity
	var sideways_speed := absf(local_velocity.x)
	var drifting := speed_kph > 28.0 and sideways_speed > 3.2 and Input.is_action_pressed("handbrake")
	if drifting:
		_drift_time += delta
		if _drift_time >= 0.75 and _skill_cooldown <= 0.0:
			_skill_cooldown = 2.0
			_drift_time = 0.0
			driving_skill.emit("MATATU SLIDE +12 HYPE", 12)
	else:
		_drift_time = 0.0
	if speed_kph < 32.0 or _near_miss_cooldown > 0.0:
		return
	for body in player.get_colliding_bodies():
		if body == player:
			continue
		var distance := player.global_position.distance_to(body.global_position)
		if distance > 2.8:
			continue
		var relative := body.global_position - player.global_position
		var local_relative := player.global_basis.inverse() * relative
		if absf(local_relative.x) > 1.1:
			_near_miss_cooldown = 2.5
			driving_skill.emit("SQUEEZE THROUGH! +10 HYPE", 10)
			break


func _update_speed_pressure(delta: float) -> void:
	var speed_kph := float(player.call("get_speed_kph")) if player.has_method("get_speed_kph") else player.linear_velocity.length() * 3.6
	if speed_kph >= 75.0:
		_speed_hold += delta
		if _speed_hold >= 5.0 and _last_speed_reward <= 0.0:
			_last_speed_reward = 4.0
			_speed_hold = 0.0
			driving_skill.emit("FULL SEND! +8 HYPE", 8)
	else:
		_speed_hold = 0.0
	_last_speed_reward = maxf(_last_speed_reward - delta, 0.0)
