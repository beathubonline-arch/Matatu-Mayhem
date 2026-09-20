class_name CorridorTrafficManager
extends Node3D

@export var network_path: NodePath
@export var vehicles_per_corridor: int = 4
@export var junction_slowdown_distance := 11.0

var network: NairobiRouteNetwork

func _ready() -> void:
	network = get_node_or_null(network_path) as NairobiRouteNetwork
	if network == null:
		push_error("CorridorTrafficManager requires NairobiRouteNetwork.")
		return
	for corridor_index in range(network.corridor_count()):
		var data: Dictionary = network.get_corridor(corridor_index)
		for vehicle_index in range(vehicles_per_corridor):
			_spawn_vehicle(data, vehicle_index)

func _spawn_vehicle(data: Dictionary, index: int) -> void:
	var points: Array = data["points"]
	var segment_index: int = index % max(points.size() - 1, 1)
	var a: Vector3 = points[segment_index]
	var b: Vector3 = points[segment_index + 1]
	var direction: Vector3 = (b - a).normalized()
	var vehicle := CharacterBody3D.new()
	vehicle.position = a.lerp(b, 0.25 + 0.15 * float(index % 4)) + Vector3(direction.z, 0.55, -direction.x) * (2.6 if index % 2 == 0 else -2.6)
	vehicle.set_meta("points", points)
	var forward := index % 2 == 0
	vehicle.set_meta("point_index", segment_index + 1 if forward else segment_index)
	vehicle.set_meta("forward", forward)
	vehicle.set_meta("lane_offset", 2.6 if index % 2 == 0 else -2.6)
	vehicle.set_meta("speed", 7.0 + float(index % 3))
	vehicle.set_collision_layer_value(1, true)
	vehicle.set_collision_mask_value(1, false)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, 1.55, 3.8)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.75
	var material := StandardMaterial3D.new()
	var colors: Array[Color] = [Color("d8d4c5"), Color("306b9b"), Color("a53b32"), Color("3e7d50")]
	material.albedo_color = colors[index % colors.size()]
	mesh_instance.material_override = material
	vehicle.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.55, 3.8)
	collision.shape = shape
	collision.position.y = 0.75
	vehicle.add_child(collision)
	add_child(vehicle)

func _physics_process(_delta: float) -> void:
	var player := GameManager.get_player_vehicle() as Node3D
	for child in get_children():
		var vehicle := child as CharacterBody3D
		if vehicle == null:
			continue
		var points: Array = vehicle.get_meta("points", [])
		if points.size() < 2:
			continue
		var point_index: int = int(vehicle.get_meta("point_index", 1))
		point_index = clampi(point_index, 0, points.size() - 1)
		var target: Vector3 = points[point_index]
		var to_target: Vector3 = target - vehicle.global_position
		to_target.y = 0.0
		if to_target.length() < 5.0:
			var forward: bool = bool(vehicle.get_meta("forward", true))
			if forward:
				if point_index >= points.size() - 1:
					forward = false
					point_index = maxi(points.size() - 2, 0)
				else:
					point_index += 1
			else:
				if point_index <= 0:
					forward = true
					point_index = mini(1, points.size() - 1)
				else:
					point_index -= 1
			vehicle.set_meta("forward", forward)
			vehicle.set_meta("point_index", point_index)
			target = points[point_index]
			to_target = target - vehicle.global_position
			to_target.y = 0.0
		var direction: Vector3 = to_target.normalized()
		var lane_offset: float = float(vehicle.get_meta("lane_offset", 2.6))
		var lateral := Vector3(direction.z, 0.0, -direction.x) * lane_offset
		var desired_target: Vector3 = target + lateral
		direction = (desired_target - vehicle.global_position).normalized()
		direction.y = 0.0
		var speed: float = float(vehicle.get_meta("speed", 8.0))
		if to_target.length() < junction_slowdown_distance:
			speed *= 0.58
		if player != null:
			var distance_to_player: float = vehicle.global_position.distance_to(player.global_position)
			if distance_to_player < 9.0:
				speed = 0.0
			elif distance_to_player < 16.0:
				speed *= 0.35
		vehicle.velocity = direction * speed
		if direction.length_squared() > 0.01:
			vehicle.rotation.y = atan2(-direction.x, -direction.z)
		vehicle.move_and_slide()
