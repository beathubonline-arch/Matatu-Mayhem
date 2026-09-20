class_name MatatuController
extends VehicleBody3D

@export var stats: VehicleStats
@export var reset_height := 1.5

@onready var wheel_front_left: VehicleWheel3D = $WheelFrontLeft
@onready var wheel_front_right: VehicleWheel3D = $WheelFrontRight
@onready var wheel_rear_left: VehicleWheel3D = $WheelRearLeft
@onready var wheel_rear_right: VehicleWheel3D = $WheelRearRight

var speed_kph := 0.0
var forward_speed_kph := 0.0
var handbrake_active := false
var _current_steering := 0.0
var _spawn_transform: Transform3D

func _ready() -> void:
	if stats == null:
		push_error("MatatuController requires VehicleStats.")
		set_physics_process(false)
		return
	_spawn_transform = global_transform
	_apply_vehicle_configuration()
	GameManager.register_player_vehicle(self)

func _exit_tree() -> void:
	GameManager.unregister_player_vehicle(self)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_vehicle"):
		reset_vehicle()

func _physics_process(delta: float) -> void:
	_update_speed_values()
	_update_steering(delta)
	_update_engine_and_brakes()
	_update_handbrake_grip()
	_apply_arcade_stability()

func _update_speed_values() -> void:
	speed_kph = linear_velocity.length() * 3.6
	var local_velocity := global_basis.inverse() * linear_velocity
	forward_speed_kph = -local_velocity.z * 3.6

func _update_steering(delta: float) -> void:
	# VehicleBody3D steering sign is opposite to the matatu's visual/local
	# forward convention (-Z). Keep the input actions semantically correct:
	# steer_left must physically turn left and steer_right must turn right.
	var input_value := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	var ratio: float = clampf(speed_kph / float(stats.steering_reduction_speed_kph), 0.0, 1.0)
	var steer_degrees: float = lerpf(float(stats.max_steer_degrees), float(stats.high_speed_steer_degrees), ratio)
	var target := deg_to_rad(steer_degrees * input_value)
	var response := stats.steering_speed if abs(input_value) > 0.01 else stats.steering_return_speed
	_current_steering = move_toward(_current_steering, target, response * delta)
	steering = _current_steering

func _update_engine_and_brakes() -> void:
	var throttle := Input.get_action_strength("accelerate")
	var brake_input := Input.get_action_strength("brake")
	handbrake_active = Input.is_action_pressed("handbrake")
	engine_force = 0.0
	brake = 0.0
	if throttle > 0.0 and forward_speed_kph < stats.hard_max_speed_kph:
		# The Maverick's visual nose and route face local -Z. VehicleBody3D's
		# positive wheel force travels +Z, so forward drive requires negative force.
		engine_force = -stats.engine_force * throttle * _get_engine_force_multiplier()
	if brake_input > 0.0:
		if forward_speed_kph > 3.0:
			brake = stats.brake_force * brake_input
		else:
			engine_force = stats.reverse_force * brake_input
	if handbrake_active:
		brake = max(brake, stats.handbrake_force)

func _get_engine_force_multiplier() -> float:
	if forward_speed_kph <= 0.0:
		return 1.0
	if forward_speed_kph <= stats.soft_max_speed_kph:
		var normalized: float = clampf(forward_speed_kph / float(stats.soft_max_speed_kph), 0.0, 1.0)
		return clamp(1.0 - pow(normalized, stats.acceleration_falloff) * 0.55, 0.35, 1.0)
	var limiter_range: float = maxf(float(stats.hard_max_speed_kph) - float(stats.soft_max_speed_kph), 1.0)
	var limiter_ratio: float = clampf((forward_speed_kph - float(stats.soft_max_speed_kph)) / limiter_range, 0.0, 1.0)
	return lerp(0.35, 0.0, limiter_ratio)

func _update_handbrake_grip() -> void:
	wheel_front_left.wheel_friction_slip = stats.front_grip
	wheel_front_right.wheel_friction_slip = stats.front_grip
	var rear := stats.rear_grip
	if handbrake_active and speed_kph >= stats.drift_activation_speed_kph:
		rear = stats.handbrake_rear_grip
	wheel_rear_left.wheel_friction_slip = rear
	wheel_rear_right.wheel_friction_slip = rear

func _apply_arcade_stability() -> void:
	if speed_kph < 1.0:
		return
	var speed_mps := speed_kph / 3.6
	apply_central_force(-global_basis.y * speed_mps * stats.downforce_coefficient * mass / 100.0)
	var correction_axis := global_basis.y.normalized().cross(Vector3.UP)
	var assist := stats.upright_assist * (stats.drift_upright_multiplier if handbrake_active else 1.0)
	apply_torque(correction_axis * assist * mass)

func _apply_vehicle_configuration() -> void:
	mass = stats.mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, stats.center_of_mass_y, 0.0)
	_configure_wheel(wheel_front_left, true, false, stats.front_grip)
	_configure_wheel(wheel_front_right, true, false, stats.front_grip)
	_configure_wheel(wheel_rear_left, false, true, stats.rear_grip)
	_configure_wheel(wheel_rear_right, false, true, stats.rear_grip)

func _configure_wheel(wheel: VehicleWheel3D, steering_wheel: bool, traction_wheel: bool, grip: float) -> void:
	wheel.use_as_steering = steering_wheel
	wheel.use_as_traction = traction_wheel
	wheel.wheel_radius = stats.wheel_radius
	wheel.wheel_rest_length = stats.suspension_rest_length
	wheel.suspension_travel = stats.suspension_travel
	wheel.suspension_stiffness = stats.suspension_stiffness
	wheel.suspension_max_force = stats.suspension_max_force
	wheel.damping_compression = stats.damping_compression
	wheel.damping_relaxation = stats.damping_relaxation
	wheel.wheel_friction_slip = grip

func reset_vehicle() -> void:
	var pos := global_position
	var forward := -global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = -_spawn_transform.basis.z
	forward = forward.normalized()
	var yaw := atan2(-forward.x, -forward.z)
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * reset_height)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force = 0.0
	brake = 0.0
	steering = 0.0
	_current_steering = 0.0
	sleeping = false

func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	global_position += Vector3.UP * reset_height
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO

func get_speed_kph() -> float:
	return speed_kph
