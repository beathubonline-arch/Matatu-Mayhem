class_name NairobiRouteNetwork
extends Node3D

# Gameplay-scale reconstruction of Nairobi's major matatu corridors.
# Corridor ordering and stop names are grounded in public Nairobi route maps.
# Distances are compressed for playability; this is not survey-grade GIS geometry.

const ROAD_Y := 0.04
const ROAD_W := 15.0
const CORRIDORS := [
	{"name":"WAIYAKI WAY","color":"4aa3df","points":[Vector3(-31,0,-63),Vector3(-70,0,-82),Vector3(-118,0,-98),Vector3(-170,0,-108),Vector3(-225,0,-112)],"stops":["WESTLANDS","ABC PLACE","KANGEMI","UTHIRU"],"reward":9000},
	{"name":"THIKA ROAD","color":"e8c547","points":[Vector3(31,0,21),Vector3(62,0,2),Vector3(95,0,-38),Vector3(122,0,-86),Vector3(142,0,-142)],"stops":["NGARA","PANGANI","MUTHAIGA","ROYSAMBU / KASARANI"],"reward":11000},
	{"name":"MOMBASA ROAD","color":"e36a54","points":[Vector3(0,0,63),Vector3(34,0,102),Vector3(58,0,148),Vector3(72,0,202),Vector3(76,0,258)],"stops":["NYAYO","SOUTH B / C","GENERAL MOTORS","IMARA DAIMA"],"reward":12000},
	{"name":"NGONG ROAD","color":"69c779","points":[Vector3(-31,0,21),Vector3(-66,0,50),Vector3(-96,0,86),Vector3(-122,0,130),Vector3(-146,0,178)],"stops":["COMMUNITY","PRESTIGE","ADAMS ARCADE","JUNCTION"],"reward":10000}
]

func corridor_count() -> int:
	return CORRIDORS.size()

func get_corridor(index: int) -> Dictionary:
	return CORRIDORS[index % CORRIDORS.size()]

func get_service_stop(corridor: int, stop: int) -> Vector3:
	var data: Dictionary = get_corridor(corridor)
	var points: Array = data["points"]
	return points[clampi(stop + 1, 1, points.size() - 1)]

func _ready() -> void:
	for corridor in CORRIDORS:
		_build_corridor(corridor)

func _build_corridor(data: Dictionary) -> void:
	var points: Array = data["points"]
	var color: Color = Color(String(data["color"]))
	for i in range(points.size() - 1):
		_road_segment(points[i], points[i + 1], color)
	for i in range(1, points.size()):
		_stage(points[i], String(data["stops"][i - 1]), String(data["name"]), int(data["reward"]))

func _road_segment(a: Vector3, b: Vector3, accent: Color) -> void:
	var delta: Vector3 = b - a
	var length: float = Vector2(delta.x, delta.z).length()
	var mid: Vector3 = (a + b) * 0.5
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ROAD_W, 0.08, length)
	road.mesh = mesh
	road.position = Vector3(mid.x, ROAD_Y, mid.z)
	road.rotation.y = atan2(delta.x, delta.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("25282d")
	mat.roughness = 0.96
	road.material_override = mat
	add_child(road)
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.18, 0.02, length * 0.92)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(mid.x, ROAD_Y + 0.06, mid.z)
	stripe.rotation.y = road.rotation.y
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = accent
	stripe.material_override = stripe_mat
	add_child(stripe)

func _stage(pos: Vector3, stop_name: String, corridor: String, reward: int) -> void:
	var root := Node3D.new()
	root.position = pos
	root.name = stop_name.replace(" ", "_") + "_Stage"
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
	sign.text = "%s\\n%s\\nROUTE BONUS KSh %d" % [stop_name, corridor, reward]
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
