class_name NairobiRouteNetwork
extends Node3D

# Phase 2 Nairobi Twin Experience foundation.
# The network uses recognizable public-route ordering and a denser gameplay polyline.
# Geometry remains deliberately compressed/optimized for gameplay; it is not survey-grade GIS.

const ROAD_Y := 0.04
const ROAD_W := 15.0
const WAIYAKI_POINTS := [
	Vector3(-31,0,-63), Vector3(-31,0,-92), Vector3(-52,0,-92), Vector3(-52,0,-122),
	Vector3(-86,0,-122), Vector3(-86,0,-151), Vector3(-122,0,-151), Vector3(-122,0,-184),
	Vector3(-161,0,-184), Vector3(-161,0,-216), Vector3(-205,0,-216), Vector3(-225,0,-238)
]
const WAIYAKI_DISTRICTS := ["WESTLANDS","WESTLANDS","ABC PLACE","ABC PLACE","KANGEMI","KANGEMI","UTHIRU","UTHIRU","UTHIRU","UTHIRU","UTHIRU"]
const CORRIDOR_DISTRICTS := [
	["WESTLANDS","ABC PLACE","KANGEMI","UTHIRU"],
	["NGARA","PANGANI","MUTHAIGA","KASARANI"],
	["NYAYO","SOUTH B / C","GENERAL MOTORS","IMARA DAIMA"],
	["COMMUNITY","PRESTIGE","ADAMS ARCADE","JUNCTION"]
]
const CORRIDORS := [
	{"name":"WAIYAKI WAY","color":"4aa3df","points":WAIYAKI_POINTS,
	 "service_points":[Vector3(-31,0,-92),Vector3(-86,0,-122),Vector3(-161,0,-184),Vector3(-225,0,-238)],
	 "stops":["WESTLANDS","ABC PLACE","KANGEMI","UTHIRU"],"reward":9000},
	{"name":"THIKA ROAD","color":"e8c547","points":[Vector3(31,0,21),Vector3(31,0,-12),Vector3(58,0,-12),Vector3(58,0,-52),Vector3(92,0,-52),Vector3(92,0,-96),Vector3(124,0,-96),Vector3(142,0,-142)],
	 "service_points":[Vector3(31,0,-12),Vector3(58,0,-52),Vector3(92,0,-96),Vector3(142,0,-142)],
	 "stops":["NGARA","PANGANI","MUTHAIGA","ROYSAMBU / KASARANI"],"reward":11000},
	{"name":"MOMBASA ROAD","color":"e36a54","points":[Vector3(0,0,63),Vector3(0,0,96),Vector3(32,0,96),Vector3(32,0,132),Vector3(62,0,132),Vector3(62,0,172),Vector3(92,0,172),Vector3(92,0,214),Vector3(76,0,258)],
	 "service_points":[Vector3(0,0,96),Vector3(32,0,132),Vector3(62,0,172),Vector3(76,0,258)],
	 "stops":["NYAYO","SOUTH B / C","GENERAL MOTORS","IMARA DAIMA"],"reward":12000},
	{"name":"NGONG ROAD","color":"69c779","points":[Vector3(-31,0,21),Vector3(-58,0,21),Vector3(-58,0,54),Vector3(-91,0,54),Vector3(-91,0,91),Vector3(-124,0,91),Vector3(-124,0,132),Vector3(-146,0,178)],
	 "service_points":[Vector3(-58,0,21),Vector3(-91,0,54),Vector3(-124,0,91),Vector3(-146,0,178)],
	 "stops":["COMMUNITY","PRESTIGE","ADAMS ARCADE","JUNCTION"],"reward":10000}
]

func corridor_count() -> int:
	return CORRIDORS.size()

func get_corridor(index: int) -> Dictionary:
	return CORRIDORS[index % CORRIDORS.size()]

func get_service_stop(corridor: int, stop: int) -> Vector3:
	return get_stage_bay_position(corridor, stop)

func get_stage_bay_position(corridor: int, stop: int) -> Vector3:
	var data: Dictionary = get_corridor(corridor)
	var points: Array = data["points"]
	var service_points: Array = data["service_points"]
	var service_point: Vector3 = service_points[clampi(stop, 0, service_points.size() - 1)]
	var direction := _route_direction_at(points, service_point)
	var right := Vector3(direction.z, 0.0, -direction.x)
	return service_point + right * 5.2

func get_stage_waiting_position(corridor: int, stop: int) -> Vector3:
	var data: Dictionary = get_corridor(corridor)
	var points: Array = data["points"]
	var service_points: Array = data["service_points"]
	var service_point: Vector3 = service_points[clampi(stop, 0, service_points.size() - 1)]
	var direction := _route_direction_at(points, service_point)
	var right := Vector3(direction.z, 0.0, -direction.x)
	return service_point + right * 9.4

func get_stage_direction(corridor: int, stop: int) -> Vector3:
	var data: Dictionary = get_corridor(corridor)
	return _route_direction_at(data["points"], data["service_points"][clampi(stop, 0, data["service_points"].size() - 1)])

func _route_direction_at(route_points: Array, service_point: Vector3) -> Vector3:
	var best_index := 0
	var best_distance := INF
	for i in range(route_points.size()):
		var d := service_point.distance_squared_to(route_points[i])
		if d < best_distance:
			best_distance = d
			best_index = i
	var prev_index := maxi(best_index - 1, 0)
	var next_index := mini(best_index + 1, route_points.size() - 1)
	var direction: Vector3 = route_points[next_index] - route_points[prev_index]
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() < 0.01 else direction.normalized()

func _ready() -> void:
	for corridor_index in range(CORRIDORS.size()):
		_build_corridor(CORRIDORS[corridor_index], corridor_index)

func _build_corridor(data: Dictionary, corridor_index: int) -> void:
	var points: Array = data["points"]
	var color: Color = Color(String(data["color"]))
	for i in range(points.size() - 1):
		_road_segment(points[i], points[i + 1], color)
		if corridor_index == 0:
			_waiyaki_streetscape(points[i], points[i + 1], i)
		else:
			_corridor_streetscape(points[i], points[i + 1], i, corridor_index)
		if i > 0:
			_junction_detail(points[i], color)
			_branch_road(points[i - 1], points[i], points[i + 1], color, i)
			_turn_arrow(points[i - 1], points[i], points[i + 1], color)
	var service_points: Array = data["service_points"]
	for i in range(service_points.size()):
		_stage(get_stage_waiting_position(corridor_index, i), get_stage_direction(corridor_index, i), String(data["stops"][i]), String(data["name"]), int(data["reward"]))
	if corridor_index == 0:
		_waiyaki_landmarks()
	else:
		_other_corridor_landmarks(data, corridor_index)
	_corridor_gateway(data, corridor_index)

func _stage_visual_position(route_points: Array, service_point: Vector3) -> Vector3:
	var best_index := 0
	var best_distance := INF
	for i in range(route_points.size()):
		var d := service_point.distance_squared_to(route_points[i])
		if d < best_distance:
			best_distance = d
			best_index = i
	var next_index := mini(best_index + 1, route_points.size() - 1)
	var prev_index := maxi(best_index - 1, 0)
	var direction: Vector3 = route_points[next_index] - route_points[prev_index]
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	return service_point + right * 10.2

func _road_segment(a: Vector3, b: Vector3, accent: Color) -> void:
	var delta: Vector3 = b - a
	var length: float = Vector2(delta.x, delta.z).length()
	var mid: Vector3 = (a + b) * 0.5
	var yaw := atan2(delta.x, delta.z)
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ROAD_W, 0.08, length)
	road.mesh = mesh
	road.position = Vector3(mid.x, ROAD_Y, mid.z)
	road.rotation.y = yaw
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("25282d")
	mat.roughness = 0.96
	road.material_override = mat
	add_child(road)

	var body := StaticBody3D.new()
	body.position = Vector3(mid.x, ROAD_Y - 0.10, mid.z)
	body.rotation.y = yaw
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(ROAD_W, 0.20, length)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

	# Kenyan urban arterial treatment: centre divider plus lane/edge markings.
	_marking(mid, yaw, length, 0.0, 0.18, accent)
	_marking(mid, yaw, length, -3.7, 0.10, Color("d9d9d9"))
	_marking(mid, yaw, length, 3.7, 0.10, Color("d9d9d9"))
	_marking(mid, yaw, length, -7.15, 0.14, Color("f2f2f2"))
	_marking(mid, yaw, length, 7.15, 0.14, Color("f2f2f2"))

func _turn_arrow(prev: Vector3, junction: Vector3, next: Vector3, accent: Color) -> void:
	var incoming := junction - prev
	var outgoing := next - junction
	incoming.y = 0.0
	outgoing.y = 0.0
	if incoming.length_squared() < 0.01 or outgoing.length_squared() < 0.01:
		return
	incoming = incoming.normalized()
	outgoing = outgoing.normalized()
	var signed_turn := incoming.signed_angle_to(outgoing, Vector3.UP)
	if absf(rad_to_deg(signed_turn)) < 18.0:
		return
	var root := Node3D.new()
	root.position = junction - incoming * 9.0 + Vector3(0, ROAD_Y + 0.09, 0)
	root.rotation.y = atan2(incoming.x, incoming.z)
	add_child(root)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.45, 0.025, 4.0)
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0, 0, -1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = accent
	shaft.material_override = mat
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(2.6, 0.025, 0.45)
	head.mesh = head_mesh
	head.position = Vector3(-1.05 if signed_turn > 0.0 else 1.05, 0, -3.0)
	head.material_override = mat
	root.add_child(head)

func _branch_road(prev: Vector3, junction: Vector3, next: Vector3, accent: Color, seed: int) -> void:
	var incoming := junction - prev
	var outgoing := next - junction
	incoming.y = 0.0
	outgoing.y = 0.0
	if incoming.length_squared() < 0.01 or outgoing.length_squared() < 0.01:
		return
	incoming = incoming.normalized()
	outgoing = outgoing.normalized()
	if absf(incoming.dot(outgoing)) > 0.96:
		return
	var branch_dir := -incoming if seed % 2 == 0 else -outgoing
	var branch_end := junction + branch_dir * (20.0 + float(seed % 3) * 4.0)
	_side_road_segment(junction, branch_end)
	var sign := Label3D.new()
	sign.text = "LOCAL ROAD"
	sign.position = junction + branch_dir * 8.0 + Vector3(0, 3.2, 0)
	sign.font_size = 22
	sign.pixel_size = 0.005
	sign.outline_size = 6
	sign.modulate = accent
	add_child(sign)

func _side_road_segment(a: Vector3, b: Vector3) -> void:
	var delta := b - a
	var length := Vector2(delta.x, delta.z).length()
	if length < 2.0:
		return
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(9.0, 0.07, length)
	road.mesh = mesh
	road.position = (a + b) * 0.5 + Vector3(0, ROAD_Y - 0.005, 0)
	road.rotation.y = atan2(delta.x, delta.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("303338")
	mat.roughness = 0.98
	road.material_override = mat
	add_child(road)
	var body := StaticBody3D.new()
	body.position = road.position + Vector3(0, -0.10, 0)
	body.rotation.y = road.rotation.y
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.0, 0.20, length)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _junction_detail(pos: Vector3, accent: Color) -> void:
	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(17.5, 0.09, 17.5)
	pad.mesh = mesh
	pad.position = pos + Vector3(0, ROAD_Y + 0.01, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("292c31")
	mat.roughness = 0.96
	pad.material_override = mat
	add_child(pad)
	for offset in [-5.2, 5.2]:
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.16, 0.025, 11.0)
		stripe.mesh = stripe_mesh
		stripe.position = pos + Vector3(offset, ROAD_Y + 0.07, 0)
		var stripe_mat := StandardMaterial3D.new()
		stripe_mat.albedo_color = accent
		stripe.material_override = stripe_mat
		add_child(stripe)

func _marking(mid: Vector3, yaw: float, length: float, lateral: float, width: float, color: Color) -> void:
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(width, 0.02, length * 0.94)
	stripe.mesh = stripe_mesh
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	stripe.position = Vector3(mid.x, ROAD_Y + 0.06, mid.z) + right * lateral
	stripe.rotation.y = yaw
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = color
	stripe.material_override = stripe_mat
	add_child(stripe)

func _waiyaki_streetscape(a: Vector3, b: Vector3, segment_index: int) -> void:
	var delta := b - a
	var length := Vector2(delta.x, delta.z).length()
	if length < 2.0:
		return
	var direction := delta.normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	var mid := (a + b) * 0.5
	# Pavements and drainage shoulders keep the corridor visually grounded.
	for side in [-1.0, 1.0]:
		var walk := MeshInstance3D.new()
		var walk_mesh := BoxMesh.new()
		walk_mesh.size = Vector3(2.2, 0.16, length)
		walk.mesh = walk_mesh
		walk.position = mid + right * (side * 8.6) + Vector3(0, 0.05, 0)
		walk.rotation.y = atan2(delta.x, delta.z)
		var walk_mat := StandardMaterial3D.new()
		walk_mat.albedo_color = Color("7a756d")
		walk.material_override = walk_mat
		add_child(walk)
	# Lightweight streetlights; alternate sides to control node count on mobile.
	var light_pos := mid + right * (9.6 if segment_index % 2 == 0 else -9.6)
	_streetlight(light_pos)
	# Low-cost roadside massing creates the Westlands -> Kangemi -> Uthiru transition.
	for side in [-1.0, 1.0]:
		var height := 8.0 + float((segment_index * 7 + int(side > 0.0) * 5) % 14)
		var footprint := Vector3(9.0 + float(segment_index % 3) * 2.0, height, 8.0)
		_building(mid + right * (side * 16.0) + direction * (3.0 if side > 0.0 else -4.0), footprint, segment_index, side)
	if segment_index % 2 == 0:
		_roadside_shop(mid + right * (12.2 if segment_index % 4 == 0 else -12.2), WAIYAKI_DISTRICTS[mini(segment_index, WAIYAKI_DISTRICTS.size() - 1)], segment_index)


func _corridor_streetscape(a: Vector3, b: Vector3, segment_index: int, corridor_index: int) -> void:
	var delta := b - a
	var length := Vector2(delta.x, delta.z).length()
	if length < 2.0:
		return
	var direction := delta.normalized()
	var right := Vector3(direction.z, 0.0, -direction.x)
	var mid := (a + b) * 0.5
	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := BoxMesh.new()
		shoulder_mesh.size = Vector3(1.8, 0.12, length)
		shoulder.mesh = shoulder_mesh
		shoulder.position = mid + right * (side * 8.4) + Vector3(0, 0.04, 0)
		shoulder.rotation.y = atan2(delta.x, delta.z)
		var shoulder_mat := StandardMaterial3D.new()
		shoulder_mat.albedo_color = Color("77736b")
		shoulder.material_override = shoulder_mat
		add_child(shoulder)
	if segment_index % 2 == 0:
		var districts: Array = CORRIDOR_DISTRICTS[corridor_index]
		var district := String(districts[mini(segment_index, districts.size() - 1)])
		_roadside_shop(mid + right * 12.0, district, segment_index + corridor_index)

func _corridor_gateway(data: Dictionary, corridor_index: int) -> void:
	var points: Array = data["points"]
	if points.is_empty():
		return
	var start: Vector3 = points[0]
	var label := Label3D.new()
	label.text = "%s\nNAIROBI CORRIDOR %d" % [String(data["name"]), corridor_index + 1]
	label.position = start + Vector3(0, 6.5, 0)
	label.font_size = 38
	label.pixel_size = 0.007
	label.outline_size = 9
	label.modulate = Color(String(data["color"]))
	add_child(label)

func _roadside_shop(pos: Vector3, district: String, seed: int) -> void:
	var shop := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(5.5, 3.0, 3.5)
	shop.mesh = mesh
	shop.position = pos + Vector3(0, 1.5, 0)
	var mat := StandardMaterial3D.new()
	var palette: Array[Color] = [Color("b24c36"), Color("28666e"), Color("c18c3d"), Color("525b76")]
	mat.albedo_color = palette[seed % palette.size()]
	shop.material_override = mat
	add_child(shop)
	var label := Label3D.new()
	label.text = ["M-PESA", "KINYOZI", "HOTEL", "DUKA"][seed % 4] + "\n" + district
	label.position = pos + Vector3(0, 2.1, -1.8)
	label.font_size = 28
	label.pixel_size = 0.006
	label.outline_size = 7
	label.modulate = Color("f7f4df")
	add_child(label)

func _streetlight(pos: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 6.0
	pole.mesh = pole_mesh
	pole.position = pos + Vector3(0, 3.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("42474d")
	pole.material_override = mat
	add_child(pole)

func _building(pos: Vector3, size: Vector3, seed: int, side: float) -> void:
	var building := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	building.mesh = mesh
	building.position = pos + Vector3(0, size.y * 0.5, 0)
	var mat := StandardMaterial3D.new()
	var palette: Array[Color] = [Color("b9b3a6"), Color("8f969b"), Color("c6b99d"), Color("777d82")]
	mat.albedo_color = palette[(seed + (1 if side > 0.0 else 0)) % palette.size()]
	mat.roughness = 0.9
	building.material_override = mat
	add_child(building)

func _waiyaki_landmarks() -> void:
	var data: Dictionary = get_corridor(0)
	var stops: Array = data["stops"]
	for i in range(stops.size()):
		var pos := get_stage_waiting_position(0, i)
		_landmark_sign(pos + Vector3(0, 5.4, 0), "%s\nWAIYAKI WAY" % String(stops[i]))
	_billboard(get_stage_waiting_position(0, 1) + Vector3(0, 4.5, 6.0), "MATATU MAYHEM\n254 STREET RADIO")
	_billboard(get_stage_waiting_position(0, 2) + Vector3(0, 4.5, 6.0), "BEATHUB\nNAIROBI SOUNDS")

func _other_corridor_landmarks(data: Dictionary, corridor_index: int) -> void:
	var points: Array = data["service_points"]
	var stops: Array = data["stops"]
	var accent := Color(String(data["color"]))
	for i in range(points.size()):
		var pos: Vector3 = points[i]
		var sign := Label3D.new()
		sign.text = String(stops[i])
		sign.position = pos + Vector3(0, 5.2, -5.0)
		sign.font_size = 34
		sign.pixel_size = 0.007
		sign.outline_size = 9
		sign.modulate = accent
		add_child(sign)
	if points.size() >= 2:
		_billboard(points[1] + Vector3(8.0, 4.5, 5.0), "MATATU MAYHEM\n%s" % String(data["name"]))

func _landmark_sign(pos: Vector3, text: String) -> void:
	var sign := Label3D.new()
	sign.text = text
	sign.position = pos
	sign.font_size = 42
	sign.pixel_size = 0.008
	sign.outline_size = 10
	sign.modulate = Color("f7f4df")
	add_child(sign)

func _billboard(pos: Vector3, text: String) -> void:
	var board := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(7.0, 3.2, 0.25)
	board.mesh = mesh
	board.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("181b22")
	board.material_override = mat
	add_child(board)
	var label := Label3D.new()
	label.text = text
	label.position = pos + Vector3(0, 0, -0.16)
	label.font_size = 34
	label.pixel_size = 0.006
	label.outline_size = 8
	label.modulate = Color("ffe15a")
	add_child(label)

func _stage(pos: Vector3, direction: Vector3, stop_name: String, corridor: String, reward: int) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = atan2(direction.x, direction.z)
	root.name = stop_name.replace(" ", "_").replace("/", "_") + "_Stage"
	add_child(root)
	var shelter := MeshInstance3D.new()
	var shelter_mesh := BoxMesh.new()
	shelter_mesh.size = Vector3(7.5, 0.18, 2.8)
	shelter.mesh = shelter_mesh
	shelter.position = Vector3(0, 3.0, 0)
	var shelter_mat := StandardMaterial3D.new()
	shelter_mat.albedo_color = Color("d23d45")
	shelter.material_override = shelter_mat
	root.add_child(shelter)
	for x in [-3.4, 3.4]:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.12, 3.0, 0.12)
		post.mesh = post_mesh
		post.position = Vector3(x, 1.5, 0)
		root.add_child(post)
	var sign := Label3D.new()
	sign.text = "%s\n%s\nROUTE BONUS KSh %d" % [stop_name, corridor, reward]
	sign.position = Vector3(0, 3.45, 0)
	sign.font_size = 30
	sign.pixel_size = 0.006
	sign.outline_size = 9
	sign.modulate = Color("ffe15a")
	root.add_child(sign)
	_spawn_passengers(root)

func _spawn_passengers(parent: Node3D) -> void:
	for i in range(6):
		var person := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.24
		mesh.height = 1.55
		person.mesh = mesh
		person.position = Vector3(-2.5 + float(i), 0.8, 1.7)
		var mat := StandardMaterial3D.new()
		var passenger_colors: Array[Color] = [Color("4f86c6"), Color("d25f4b"), Color("59a96a"), Color("d5a33f")]
		mat.albedo_color = passenger_colors[i % passenger_colors.size()]
		person.material_override = mat
		parent.add_child(person)
