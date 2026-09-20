class_name VehicleStats
extends Resource

@export_group("Identity")
@export var vehicle_name := "Vehicle"

@export_group("Body")
@export var mass_kg := 2600.0
@export var center_of_mass_y := -0.7

@export_group("Engine")
@export var engine_force := 5200.0
@export var reverse_force := 2600.0
@export var soft_max_speed_kph := 125.0
@export var hard_max_speed_kph := 145.0
@export var acceleration_falloff := 1.15

@export_group("Brakes")
@export var brake_force := 42.0
@export var handbrake_force := 68.0

@export_group("Steering")
@export var max_steer_degrees := 29.0
@export var high_speed_steer_degrees := 10.0
@export var steering_reduction_speed_kph := 115.0
@export var steering_speed := 5.8
@export var steering_return_speed := 7.5

@export_group("Grip")
@export var front_grip := 4.4
@export var rear_grip := 4.0
@export var handbrake_rear_grip := 1.65
@export var drift_activation_speed_kph := 18.0

@export_group("Suspension")
@export var suspension_rest_length := 0.28
@export var suspension_travel := 0.22
@export var suspension_stiffness := 28.0
@export var damping_compression := 3.2
@export var damping_relaxation := 4.4
@export var suspension_max_force := 11000.0

@export_group("Wheels")
@export var wheel_radius := 0.44

@export_group("Arcade Stability")
@export var downforce_coefficient := 7.5
@export var upright_assist := 2.4
@export var drift_upright_multiplier := 0.45
