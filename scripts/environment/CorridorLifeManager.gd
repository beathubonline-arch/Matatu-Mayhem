class_name CorridorLifeManager
extends Node3D

@export var network_path: NodePath
@export var pedestrians_per_waiyaki_stage := 5
@export var boda_count := 5
@export var minibus_count := 4
@export var people_per_other_stage := 3
@export var route_minibuses_per_other_corridor := 2

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
	_spawn_other_corridor_minibuses()
	_spawn_stage_conductors()

func _spawn_waiyaki_people() -> void:
	var data := network.get_corridor(0)
	var stops: Array = data["service_points"]
	for stop_index in range(stops.size()):
		var centre: Vector3 = network.get_stage_waiting_position(0, stop_index)
		var stage_dir: Vector3 = network.get_stage_direction(0, stop_index)
		var stage_right := Vector3(stage_dir.z, 0.0, -stage_dir.x)
		for i in range(pedestrians_per_waiyaki_stage):
			var person := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.22
			mesh.height = 1.5
			person.mesh = mesh
			person.position = centre + stage_right * (-3.0 + float(i) * 1.5) + stage_dir * (1.0 + float(i % 2) * 0.8) + Vector3.UP * 0.8
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
			var centre: Vector3 = network.get_stage_waiting_position(corridor_index, stop_index)
			var stage_dir: Vector3 = network.get_stage_direction(corridor_index, stop_index)
			var stage_right := Vector3(stage_dir.z, 0.0, -stage_dir.x)
			for i in range(people_per_other_stage):
				var person := MeshInstance3D.new()
				var mesh := CapsuleMesh.new()
				mesh.radius = 0.21
				mesh.height = 1.48
				person.mesh = mesh
				person.position = centre + stage_right * (-1.6 + float(i) * 1.6) + stage_dir * (1.0 + float(i % 2) * 0.7) + Vector3.UP * 0.78
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
		var start_index: int = i % max(points.size() - 1, 1)
		boda.position = points[start_index] + Vector3(0, 0.45, 0)
		boda.set_meta("points", points)
		boda.set_meta("point_index", mini(start_index + 1, points.size() - 1))
		boda.set_meta("forward", true)
		boda.set_meta("speed", 5.5 + float(i % 3))
		boda.set_meta("steer_dir", (points[mini(start_index + 1, points.size() - 1)] - points[start_index]).normalized())
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
		var index: int = clampi(int(mover.get_meta("point_index", 1)), 0, points.size() - 1)
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
		var steer_dir: Vector3 = mover.get_meta("steer_dir", direction)
		direction = steer_dir.lerp(direction, clampf(_delta * (2.4 if to_target.length() < 10.0 else 4.0), 0.0, 1.0)).normalized()
		mover.set_meta("steer_dir", direction)
		var speed: float = float(mover.get_meta("speed", 6.0))
		if to_target.length() < 9.0:
			speed *= 0.75
		mover.velocity = direction * speed
		if direction.length_squared() > 0.01:
			var target_yaw: float = atan2(-direction.x, -direction.z)
			mover.rotation.y = lerp_angle(mover.rotation.y, target_yaw, clampf(_delta * 4.5, 0.0, 1.0))
		mover.move_and_slide()

func _spawn_route_minibuses() -> void:
	var data := network.get_corridor(0)
	var points: Array = data["points"]
	for i in range(minibus_count):
		var bus := CharacterBody3D.new()
		var start_index: int = (i * 2) % max(points.size() - 1, 1)
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
		bus.set_meta("steer_dir", direction)
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

func _spawn_other_corridor_minibuses() -> void:
	for corridor_index in range(1, network.corridor_count()):
		var data := network.get_corridor(corridor_index)
		var points: Array = data["points"]
		for i in range(route_minibuses_per_other_corridor):
			if points.size() < 2:
				continue
			var segment_index: int = (i * 2) % (points.size() - 1)
			var a: Vector3 = points[segment_index]
			var b: Vector3 = points[segment_index + 1]
			var direction := (b - a).normalized()
			var forward := i % 2 == 0
			var lane_offset := 2.15 if forward else -2.15
			var bus := CharacterBody3D.new()
			bus.position = a.lerp(b, 0.35 + 0.2 * i) + Vector3(direction.z, 0.65, -direction.x) * lane_offset
			bus.set_meta("points", points)
			bus.set_meta("point_index", segment_index + 1 if forward else segment_index)
			bus.set_meta("forward", forward)
			bus.set_meta("speed", 6.6 + float(corridor_index) * 0.35)
			bus.set_meta("lane_offset", lane_offset)
			bus.set_meta("steer_dir", direction)
			var body := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(2.0, 2.1, 4.4)
			body.mesh = mesh
			body.position.y = 1.05
			var mat := StandardMaterial3D.new()
			var colors: Array[Color] = [Color("c8c6bd"), Color("d8d1be"), Color("b8bec2")]
			mat.albedo_color = colors[corridor_index % colors.size()]
			body.material_override = mat
			bus.add_child(body)
			var route := Label3D.new()
			route.text = String(data["name"])
			route.position = Vector3(0, 1.6, -2.22)
			route.rotation_degrees.y = 180
			route.font_size = 22
			route.pixel_size = 0.005
			route.outline_size = 6
			route.modulate = Color(String(data["color"]))
			bus.add_child(route)
			add_child(bus)
			_movers.append(bus)


func _spawn_stage_conductors() -> void:
	for corridor_index in range(network.corridor_count()):
		var data: Dictionary = network.get_corridor(corridor_index)
		var stops: Array = data["stops"]
		for stop_index in range(stops.size()):
			var root := Node3D.new()
			var direction: Vector3 = network.get_stage_direction(corridor_index, stop_index)
			var right := Vector3(direction.z, 0.0, -direction.x)
			root.position = network.get_stage_waiting_position(corridor_index, stop_index) + right * 2.4
			root.rotation.y = atan2(direction.x, direction.z)
			var body := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = 0.28
			mesh.height = 1.7
			body.mesh = mesh
			body.position.y = 0.85
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color("f59e0b") if (stop_index + corridor_index) % 2 == 0 else Color("22c55e")
			body.material_override = mat
			root.add_child(body)
			var call := Label3D.new()
			call.text = "%s! PANDA!" % String(stops[-1])
			call.position = Vector3(0, 2.25, 0)
			call.font_size = 22
			call.pixel_size = 0.005
			call.outline_size = 6
			call.modulate = Color("ffe15a")
			root.add_child(call)
			add_child(root)
