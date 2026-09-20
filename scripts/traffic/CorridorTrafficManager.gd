class_name CorridorTrafficManager
extends Node3D

@export var network_path: NodePath
@export var vehicles_per_corridor: int = 4

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
	vehicle.set_meta("a", a)
	vehicle.set_meta("b", b)
	vehicle.set_meta("direction", direction if index % 2 == 0 else -direction)
	vehicle.set_meta("speed", 7.0 + float(index % 3))
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
	for child in get_children():
		var vehicle := child as CharacterBody3D
		if vehicle == null:
			continue
		var direction: Vector3 = vehicle.get_meta("direction", Vector3.ZERO)
		var speed: float = float(vehicle.get_meta("speed", 8.0))
		vehicle.velocity = direction * speed
		vehicle.move_and_slide()
		var a: Vector3 = vehicle.get_meta("a", Vector3.ZERO)
		var b: Vector3 = vehicle.get_meta("b", Vector3.ZERO)
		if vehicle.global_position.distance_to(a) > a.distance_to(b) + 12.0 and vehicle.global_position.distance_to(b) > 12.0:
			vehicle.global_position = a + Vector3(0, 0.55, 0)
