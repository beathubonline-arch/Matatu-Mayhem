class_name ChaseCamera
extends Node3D

signal camera_mode_changed(mode_name: String)

@export var target_path: NodePath
@export var height := 2.6
@export var base_distance := 6.5
@export var max_distance := 9.0
@export var follow_smoothness := 6.0
@export var rotation_smoothness := 5.0
@export var look_ahead_distance := 3.5
@export var base_fov := 68.0
@export var max_fov := 82.0
@export var max_speed_reference := 145.0
@export var lateral_look_strength := 1.6
@export var lateral_smoothness := 4.0
@export var acceleration_kick := 0.22
@export var turn_roll_degrees := 2.4
@export var shoulder_offset := 0.72

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D
var _lateral_look := 0.0
var _last_speed_kph := 0.0
var _camera_roll := 0.0
var _camera_mode := 0
var _mode_height := 2.6
var _mode_distance_scale := 1.0
var _mode_shoulder := 0.72
var _mode_fov_offset := 0.0

const CAMERA_MODE_NAMES := ["CHASE", "WIDE", "CABIN"]

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if target == null:
		target = GameManager.get_player_vehicle() as Node3D
	if target != null:
		global_position = target.global_position + Vector3.UP * height
		global_rotation = Vector3.ZERO
	_apply_camera_mode()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("camera_cycle"):
		cycle_camera()
	if target == null or not is_instance_valid(target):
		target = GameManager.get_player_vehicle() as Node3D
		return

	var speed_kph := 0.0
	if target.has_method("get_speed_kph"):
		speed_kph = float(target.call("get_speed_kph"))
	var speed_ratio: float = clampf(speed_kph / max_speed_reference, 0.0, 1.0)

	var target_right := target.global_basis.x
	target_right.y = 0.0
	target_right = target_right.normalized()
	# A slight three-quarter view reveals the passenger door, driver and cabin.
	# It recentres progressively at speed so high-speed driving stays readable.
	var desired_pos := target.global_position + Vector3.UP * _mode_height + target_right * _mode_shoulder * (1.0 - speed_ratio * 0.45)
	global_position = global_position.lerp(desired_pos, 1.0 - exp(-follow_smoothness * delta))

	var forward := -target.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	# Keep a horizontal look offset even at rest so the look direction can never
	# become colinear with Vector3.UP and destabilize the camera basis.
	var camera_forward_distance: float = maxf(1.5, look_ahead_distance * speed_ratio)
	var steer_input := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	_lateral_look = lerpf(_lateral_look, steer_input * lateral_look_strength * speed_ratio, 1.0 - exp(-lateral_smoothness * delta))
	var right := target.global_basis.x
	right.y = 0.0
	right = right.normalized()
	var look_target: Vector3 = target.global_position + Vector3.UP + forward * camera_forward_distance + right * _lateral_look
	var desired_basis := global_transform.looking_at(look_target, Vector3.UP).basis
	global_basis = global_basis.slerp(desired_basis, 1.0 - exp(-rotation_smoothness * delta))

	var mode_distance := lerp(base_distance, max_distance, speed_ratio) * _mode_distance_scale
	spring_arm.spring_length = lerpf(spring_arm.spring_length, mode_distance, 1.0 - exp(-5.0 * delta))
	var acceleration := (speed_kph - _last_speed_kph) / maxf(delta, 0.001)
	_last_speed_kph = speed_kph
	var kick := clampf(acceleration / 90.0, -1.0, 1.0) * acceleration_kick
	spring_arm.position.z = lerpf(spring_arm.position.z, kick, 1.0 - exp(-5.0 * delta))
	_camera_roll = lerpf(_camera_roll, deg_to_rad(-steer_input * turn_roll_degrees * speed_ratio), 1.0 - exp(-5.0 * delta))
	camera.rotation.z = _camera_roll
	camera.fov = lerpf(camera.fov, lerp(base_fov, max_fov, speed_ratio) + _mode_fov_offset, 1.0 - exp(-5.0 * delta))

func cycle_camera() -> void:
	_camera_mode = (_camera_mode + 1) % CAMERA_MODE_NAMES.size()
	_apply_camera_mode()
	camera_mode_changed.emit(CAMERA_MODE_NAMES[_camera_mode])

func _apply_camera_mode() -> void:
	match _camera_mode:
		1:
			_mode_height = height + 1.25
			_mode_distance_scale = 1.42
			_mode_shoulder = 0.30
			_mode_fov_offset = 4.0
		2:
			_mode_height = height - 0.35
			_mode_distance_scale = 0.16
			_mode_shoulder = 0.42
			_mode_fov_offset = 6.0
		_:
			_mode_height = height
			_mode_distance_scale = 1.0
			_mode_shoulder = shoulder_offset
			_mode_fov_offset = 0.0
