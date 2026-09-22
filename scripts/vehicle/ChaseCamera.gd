class_name ChaseCamera
extends Node3D

signal camera_mode_changed(mode_name: String)

@export var target_path: NodePath
@export var follow_smoothness := 8.0
@export var rotation_smoothness := 9.0
@export var base_fov := 68.0
@export var max_fov := 80.0
@export var max_speed_reference := 145.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

const CAMERA_MODE_NAMES := ["CHASE", "WIDE", "DRIVER"]

var target: Node3D
# Start every run in the elevated wide view preferred for driving.
var _camera_mode := 1
var _camera_key_was_down := false
var _initialized := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	target = get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null
	if target == null:
		target = GameManager.get_player_vehicle() as Node3D

	# The old SpringArm3D could collapse against the matatu or road and trap the
	# view at ground level. Keep it only as a scene container; the Camera3D now
	# follows explicit world-space positions that cannot be collision-compressed.
	spring_arm.spring_length = 0.0
	spring_arm.collision_mask = 0
	camera.top_level = true
	camera.current = true
	_snap_to_mode()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_5:
			set_camera_mode(0)
		KEY_6:
			set_camera_mode(1)
		KEY_7:
			set_camera_mode(2)

func _process(delta: float) -> void:
	# Direct polling survives browser canvas focus and focused HUD controls.
	var camera_key_down := Input.is_physical_key_pressed(KEY_C)
	if camera_key_down and not _camera_key_was_down:
		cycle_camera()
	_camera_key_was_down = camera_key_down

	if target == null or not is_instance_valid(target):
		target = GameManager.get_player_vehicle() as Node3D
		_initialized = false
		return
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	var forward := -target.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()

	var desired_position: Vector3
	var look_target: Vector3
	var mode_fov := base_fov
	match _camera_mode:
		1: # Wide cinematic view.
			desired_position = target.global_position + Vector3.UP * 6.2 - forward * 12.5 + right * 0.4
			look_target = target.global_position + Vector3.UP * 1.3 + forward * 4.0
			mode_fov = 74.0
		2: # Stable driver/bonnet view; never intersects the vehicle collider.
			desired_position = target.global_position + Vector3.UP * 2.55 + forward * 1.15 - right * 0.28
			look_target = desired_position + forward * 14.0 - Vector3.UP * 0.25
			mode_fov = 76.0
		_: # Classic chase view.
			desired_position = target.global_position + Vector3.UP * 3.4 - forward * 7.4 + right * 0.8
			look_target = target.global_position + Vector3.UP * 1.35 + forward * 2.6

	var speed_kph := 0.0
	if target.has_method("get_speed_kph"):
		speed_kph = float(target.call("get_speed_kph"))
	var speed_ratio := clampf(speed_kph / max_speed_reference, 0.0, 1.0)
	var desired_fov := mode_fov + (max_fov - base_fov) * speed_ratio * 0.55

	if not _initialized:
		camera.global_position = desired_position
		camera.look_at(look_target, Vector3.UP)
		camera.fov = desired_fov
		_initialized = true
		return

	var position_weight := 1.0 - exp(-follow_smoothness * delta)
	var rotation_weight := 1.0 - exp(-rotation_smoothness * delta)
	camera.global_position = camera.global_position.lerp(desired_position, position_weight)
	var desired_basis := Transform3D.IDENTITY.looking_at(look_target - camera.global_position, Vector3.UP).basis
	camera.global_basis = camera.global_basis.slerp(desired_basis, rotation_weight).orthonormalized()
	camera.fov = lerpf(camera.fov, desired_fov, position_weight)

func cycle_camera() -> void:
	set_camera_mode((_camera_mode + 1) % CAMERA_MODE_NAMES.size())

func set_camera_mode(mode: int) -> void:
	_camera_mode = clampi(mode, 0, CAMERA_MODE_NAMES.size() - 1)
	_initialized = false
	_snap_to_mode()
	camera_mode_changed.emit(CAMERA_MODE_NAMES[_camera_mode])

func get_camera_mode_name() -> String:
	return CAMERA_MODE_NAMES[_camera_mode]

func _snap_to_mode() -> void:
	if camera == null or target == null or not is_instance_valid(target):
		return
	_update_camera(1.0)
