class_name CorridorLifeManager
extends Node3D

@export var network_path: NodePath
@export var pedestrians_per_waiyaki_stage := 5
@export var boda_count := 5
@export var minibus_count := 4
@export var people_per_other_stage := 3

var network: NairobiRouteNetwork
var _movers: Array[CharacterBody3D] = []

func _ready() -> void:
	network = get_node_or_null(network_path) as NairobiRouteNetwork
	if network == null:
		push_error("CorridorLifeManager requires NairobiRouteNetwork.")
		return
	_spawn_waiyaki_people()
	_spawn_other_corridor_people()
	_spawn_bodas()
	_spawn_route_minibuses()

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

func _spawn_other_corridor_people() -> void:
	for corridor_index in range(1, network.corridor_count()):
		var data := network.get_corridor(corridor_index)
		var stops: Array = data["service_points"]
		for stop_index in range(stops.size()):
			var centre: Vector3 = stops[stop_index]
			for i in range(people_per_other_stage):
				var person := MeshInstance3D.new()
				var mesh := CapsuleMesh.new()
				mesh.radius = 0.21
				mesh.height = 1.48
				person.mesh = mesh
				person.position = centre + Vector3(-2.2 + float(i) * 1.6, 0.78, 2.8)
				var mat := StandardMaterial3D.new()
				var colors: Array[Color] = [Color("466a8a"), Color("a54f45"), Color("557a55"), Color("9a7137")]
				mat.albedo_color = colors[(i + stop_index + corridor_index) % colors.size()]
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
	for mover in _movers:
		var points: Array = mover.get_meta("points", [])
		if points.size() < 2:
			continue
		var index := clampi(int(mover.get_meta("point_index", 1)), 0, points.size() - 1)
		var target: Vector3 = points[index]
		var to_target := target - mover.global_position
		to_target.y = 0.0
		if to_target.length() < 3.0:
			var forward := bool(mover.get_meta("forward", true))
			if forward and index >= points.size() - 1:
				forward = false
				index = maxi(points.size() - 2, 0)
			elif not forward and index <= 0:
				forward = true
				index = mini(1, points.size() - 1)
			else:
				index += 1 if forward else -1
			mover.set_meta("forward", forward)
			mover.set_meta("point_index", index)
			target = points[index]
			to_target = target - mover.global_position
			to_target.y = 0.0
		var direction := to_target.normalized()
		var lane_offset := float(mover.get_meta("lane_offset", 0.0))
		if absf(lane_offset) > 0.01:
			var lateral := Vector3(direction.z, 0.0, -direction.x) * lane_offset
			direction = (target + lateral - mover.global_position).normalized()
			direction.y = 0.0
		mover.velocity = direction * float(mover.get_meta("speed", 6.0))
		if direction.length_squared() > 0.01:
			mover.rotation.y = atan2(-direction.x, -direction.z)
		mover.move_and_slide()

func _spawn_route_minibuses() -> void:
	var data := network.get_corridor(0)
	var points: Array = data["points"]
	for i in range(minibus_count):
		var bus := CharacterBody3D.new()
		var start_index := (i * 2) % max(points.size() - 1, 1)
		var a: Vector3 = points[start_index]
		var b: Vector3 = points[start_index + 1]
		var direction := (b - a).normalized()
		var forward := i % 2 == 0
		var lane_offset := 2.2 if forward else -2.2
		bus.position = a.lerp(b, 0.45) + Vector3(direction.z, 0.65, -direction.x) * lane_offset
		bus.set_meta("points", points)
		bus.set_meta("point_index", start_index + 1 if forward else start_index)
		bus.set_meta("forward", forward)
		bus.set_meta("speed", 6.8 + float(i % 2))
		bus.set_meta("lane_offset", lane_offset)
		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.0, 2.1, 4.4)
		body.mesh = mesh
		body.position.y = 1.05
		var mat := StandardMaterial3D.new()
		mat.albedo_color = [Color("d6d6d2"), Color("efe9d5"), Color("bfc4c8"), Color("ded5c4")][i % 4]
		body.material_override = mat
		bus.add_child(body)
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(2.04, 0.22, 4.2)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(0, 1.0, 0)
		var stripe_mat := StandardMaterial3D.new()
		stripe_mat.albedo_color = Color("e0b51b")
		stripe.material_override = stripe_mat
		bus.add_child(stripe)
		var route := Label3D.new()
		route.text = ["23 UTHIRU", "22 KANGEMI", "105 LIMURU", "115 WANGIGE"][i % 4]
		route.position = Vector3(0, 1.6, -2.22)
		route.rotation_degrees.y = 180
		route.font_size = 26
		route.pixel_size = 0.005
		route.outline_size = 7
		route.modulate = Color("fff2a8")
		bus.add_child(route)
		add_child(bus)
		_movers.append(bus)
