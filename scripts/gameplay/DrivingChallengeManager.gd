class_name DrivingChallengeManager
extends Node

signal challenge_changed(message: String, clean_streak: int)
signal penalty_applied(amount: int, balance: int, reason: String)
signal rival_result(won: bool, player_time: float, rival_time: float, reward: int)
signal rival_pace_changed(rival_name: String, target_time: float, time_remaining: float)
signal driving_skill(message: String, points: int)

@export var player_path: NodePath
@export var corridor_service_path: NodePath

const COLLISION_PENALTY := 350
const CLEAN_STAGE_REWARD := 250
const RIVAL_WIN_REWARD := 1800
const PERFECT_RUN_REWARD := 1200
const IMPACT_COOLDOWN := 1.2
# Calibrated against the current compressed route lengths and mandatory stage dwell.
const RIVAL_BASE_TIMES := [58.0, 58.0, 54.0, 53.0]
const RIVAL_NAMES := ["ONYX", "MONEYFEST", "MOXIE", "BABA YAGA"]

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
var _proximity_cooldown := 0.0
var _rival_pace_emit_cooldown := 0.0

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
	_proximity_cooldown = maxf(_proximity_cooldown - delta, 0.0)
	if GameManager.current_state != GameManager.GameState.PLAYING:
		_last_velocity = player.linear_velocity
		return
	_update_rival_pace(delta)
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
		_rival_pace_emit_cooldown = 0.0
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
		var streak := int(SaveManager.data.get("rival_win_streak", 0)) + 1
		SaveManager.data["rival_win_streak"] = streak
		SaveManager.data["best_rival_win_streak"] = maxi(int(SaveManager.data.get("best_rival_win_streak", 0)), streak)
	else:
		SaveManager.data["rival_losses"] = int(SaveManager.data.get("rival_losses", 0)) + 1
		SaveManager.data["rival_win_streak"] = 0
	SaveManager.save_game()
	var rival_name := RIVAL_NAMES[clampi(corridor_idx, 0, RIVAL_NAMES.size() - 1)]
	challenge_changed.emit(("%s DEFEATED • OWN THE STAGE" if won else "%s GOT THERE FIRST • RUN IT BACK") % rival_name, clean_streak)
	rival_result.emit(won, elapsed, rival_time, reward)

func _update_rival_pace(delta: float) -> void:
	if corridor_service == null or not corridor_service.active:
		return
	_rival_pace_emit_cooldown = maxf(_rival_pace_emit_cooldown - delta, 0.0)
	if _rival_pace_emit_cooldown > 0.0:
		return
	_rival_pace_emit_cooldown = 0.1
	var corridor_idx := clampi(corridor_service.corridor_index, 0, RIVAL_BASE_TIMES.size() - 1)
	var target_time := RIVAL_BASE_TIMES[corridor_idx]
	var rival_name := RIVAL_NAMES[corridor_idx]
	rival_pace_changed.emit(rival_name, target_time, target_time - corridor_service.elapsed_seconds)


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
	# Near misses must be detected before contact. VehicleBody3D collision lists only
	# contain bodies after impact, which made the old reward practically impossible.
	if speed_kph < 32.0 or _near_miss_cooldown > 0.0 or _proximity_cooldown > 0.0:
		return
	var space := player.get_world_3d().direct_space_state
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.2, 2.8, 7.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(player.global_basis, player.global_position)
	query.exclude = [player.get_rid()]
	query.collision_mask = 3
	var hits := space.intersect_shape(query, 8)
	for hit in hits:
		var body := hit.get("collider") as Node3D
		if body == null:
			continue
		var relative := body.global_position - player.global_position
		var local_relative := player.global_basis.inverse() * relative
		if absf(local_relative.x) >= 1.3 and absf(local_relative.x) <= 3.1 and absf(local_relative.z) <= 3.8:
			_near_miss_cooldown = 2.5
			_proximity_cooldown = 0.35
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
