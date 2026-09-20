class_name ChaseCamera
extends Node3D

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

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var target: Node3D
var _lateral_look := 0.0

func _ready() -> void:
	if not target_path.is_empty():
		target = get_node_or_null(target_path) as Node3D
	if target == null:
		target = GameManager.get_player_vehicle() as Node3D
	if target != null:
		global_position = target.global_position + Vector3.UP * height
		global_rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = GameManager.get_player_vehicle() as Node3D
		return

	var speed_kph := 0.0
	if target.has_method("get_speed_kph"):
		speed_kph = float(target.call("get_speed_kph"))
	var speed_ratio: float = clampf(speed_kph / max_speed_reference, 0.0, 1.0)

	var desired_pos := target.global_position + Vector3.UP * height
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

	spring_arm.spring_length = lerp(base_distance, max_distance, speed_ratio)
	camera.fov = lerp(base_fov, max_fov, speed_ratio)

