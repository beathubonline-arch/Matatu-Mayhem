class_name CorridorLifeManager
extends Node3D

@export var network_path: NodePath
@export var pedestrians_per_waiyaki_stage := 5
@export var boda_count := 5

var network: NairobiRouteNetwork
var _movers: Array[CharacterBody3D] = []

func _ready() -> void:
	network = get_node_or_null(network_path) as NairobiRouteNetwork
	if network == null:
		push_error("CorridorLifeManager requires NairobiRouteNetwork.")
		return
	_spawn_waiyaki_people()
	_spawn_bodas()

func _spawn_waiyaki_people() -> void:
	var data := network.get_corridor(0)
	var stops: Array = data["service_points"]
	for stop_index in range(stops.size()):
		var centre: Vector3 = stops[stop_index]
		for i in range(pedestrians_per_waiyaki_stage):
			var person := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.22
			mesh.height = 1.5
			person.mesh = mesh
			person.position = centre + Vector3(-5.0 + float(i) * 1.5, 0.8, 3.0 + float(stop_index % 2))
			var mat := StandardMaterial3D.new()
			var colors: Array[Color] = [Color("294c60"), Color("e07a5f"), Color("3d9970"), Color("d4a373"), Color("6d597a")]
			mat.albedo_color = colors[(i + stop_index) % colors.size()]
			person.material_override = mat
			add_child(person)

func _spawn_bodas() -> void:
	var data := network.get_corridor(0)
	var points: Array = data["points"]
	for i in range(boda_count):
		var boda := CharacterBody3D.new()
		var start_index := i % max(points.size() - 1, 1)
		boda.position = points[start_index] + Vector3(0, 0.45, 0)
		boda.set_meta("points", points)
		boda.set_meta("point_index", mini(start_index + 1, points.size() - 1))
		boda.set_meta("forward", true)
		boda.set_meta("speed", 5.5 + float(i % 3))
		var body := MeshInstance3D.new()
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(0.7, 0.65, 1.8)
		body.mesh = body_mesh
		body.position.y = 0.35
		var body_mat := StandardMaterial3D.new()
		var colors: Array[Color] = [Color("e8b923"), Color("d8483e"), Color("2f6fa3")]
		body_mat.albedo_color = colors[i % colors.size()]
		body.material_override = body_mat
		boda.add_child(body)
		var rider := MeshInstance3D.new()
		var rider_mesh := CapsuleMesh.new()
		rider_mesh.radius = 0.2
		rider_mesh.height = 1.0
		rider.mesh = rider_mesh
		rider.position = Vector3(0, 1.0, 0.15)
		boda.add_child(rider)
		add_child(boda)
		_movers.append(boda)

func _physics_process(_delta: float) -> void:
	for boda in _movers:
		var points: Array = boda.get_meta("points", [])
		if points.size() < 2:
			continue
		var index := clampi(int(boda.get_meta("point_index", 1)), 0, points.size() - 1)
		var target: Vector3 = points[index]
		var to_target := target - boda.global_position
		to_target.y = 0.0
		if to_target.length() < 3.0:
			var forward := bool(boda.get_meta("forward", true))
			if forward and index >= points.size() - 1:
				forward = false
				index = maxi(points.size() - 2, 0)
			elif not forward and index <= 0:
				forward = true
				index = mini(1, points.size() - 1)
			else:
				index += 1 if forward else -1
			boda.set_meta("forward", forward)
			boda.set_meta("point_index", index)
			target = points[index]
			to_target = target - boda.global_position
			to_target.y = 0.0
		var direction := to_target.normalized()
		boda.velocity = direction * float(boda.get_meta("speed", 6.0))
		if direction.length_squared() > 0.01:
			boda.rotation.y = atan2(-direction.x, -direction.z)
		boda.move_and_slide()
