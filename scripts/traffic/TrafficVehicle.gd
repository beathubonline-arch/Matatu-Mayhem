class_name TrafficVehicle
extends CharacterBody3D

@export var cruise_speed: float = 11.0
@export var travel_direction: float = -1.0
@export var wrap_min_z: float = -92.0
@export var wrap_max_z: float = 92.0

func configure(lane_x: float, start_z: float, direction_value: float, speed_value: float, body_color: Color) -> void:
	position = Vector3(lane_x, 0.72, start_z)
	travel_direction = direction_value
	cruise_speed = speed_value
	rotation_degrees.y = 0.0 if travel_direction < 0.0 else 180.0
	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	material.metallic = 0.18
	material.roughness = 0.48
	$Visuals/Body.material_override = material

func _physics_process(_delta: float) -> void:
	velocity = Vector3(0.0, 0.0, travel_direction * cruise_speed)
	move_and_slide()
	if travel_direction < 0.0 and global_position.z < wrap_min_z:
		global_position.z = wrap_max_z
	elif travel_direction > 0.0 and global_position.z > wrap_max_z:
		global_position.z = wrap_min_z
