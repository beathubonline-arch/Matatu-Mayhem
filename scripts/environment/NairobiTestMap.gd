class_name NairobiTestMap
extends Node3D

const ROAD_LENGTH := 190.0
const ROAD_WIDTH := 18.0

func _ready() -> void:
	_build_ground_and_road()
	_build_markings()
	_build_sidewalks()
	_build_city_blocks()
	_build_street_furniture()
	_build_stage()
	_build_landmark()
	_build_intersection()
	_build_roadside_detail()
	_build_traffic_infrastructure()
	_build_cbd_identity()

func _mat(color: Color, emission: Color = Color.TRANSPARENT, roughness: float = 0.75, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.8
	return material

func _mesh_box(name_text: String, size: Vector3, position_value: Vector3, material: Material, parent_node: Node = null, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = box
	instance.material_override = material
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	var destination: Node = parent_node if parent_node != null else self
	destination.add_child(instance)
	return instance

func _solid_box(name_text: String, size: Vector3, position_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_text
	body.position = position_value
	body.rotation_degrees = rotation_value
	body.collision_layer = 1
	add_child(body)
	_mesh_box("Mesh", size, Vector3.ZERO, material, body)
	var shape_resource := BoxShape3D.new()
	shape_resource.size = size
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape_resource
	body.add_child(collision)
	return body

func _build_ground_and_road() -> void:
	var soil := _mat(Color("48513c"), Color.TRANSPARENT, 1.0)
	var asphalt := _mat(Color("25272b"), Color.TRANSPARENT, 0.92)
	_solid_box("Ground", Vector3(100.0, 0.5, 210.0), Vector3(0.0, -0.25, 0.0), soil)
	_mesh_box("Asphalt", Vector3(ROAD_WIDTH, 0.08, ROAD_LENGTH), Vector3(0.0, 0.04, 0.0), asphalt)
	var patch_mat := _mat(Color("17191c"), Color.TRANSPARENT, 1.0)
	var road_patches: Array[Vector3] = [Vector3(-4.0, 36.0, 2.8), Vector3(3.6, 5.0, 2.2), Vector3(-3.2, -47.0, 3.0), Vector3(4.2, -72.0, 2.0)]
	for patch_data: Vector3 in road_patches:
		var x_value: float = patch_data.x
		var z_value: float = patch_data.y
		var scale_value: float = patch_data.z
		_mesh_box("RoadPatch", Vector3(scale_value, 0.012, scale_value * 1.8), Vector3(x_value, 0.086, z_value), patch_mat, self, Vector3(0.0, z_value, 0.0))

func _build_markings() -> void:
	var white := _mat(Color("e7e5dc"), Color.TRANSPARENT, 0.75)
	var yellow := _mat(Color("f0b323"), Color.TRANSPARENT, 0.75)
	for z_value in range(-88, 89, 9):
		_mesh_box("CentreDash", Vector3(0.16, 0.025, 4.6), Vector3(0.0, 0.095, float(z_value)), white)
	for side in [-1.0, 1.0]:
		_mesh_box("EdgeLine", Vector3(0.18, 0.025, ROAD_LENGTH - 4.0), Vector3(float(side) * 8.2, 0.095, 0.0), yellow)
	for z_value in [48.0, -18.0, -68.0]:
		for stripe_index in 7:
			_mesh_box("Crosswalk", Vector3(0.7, 0.025, 3.6), Vector3(-5.1 + float(stripe_index) * 1.7, 0.098, z_value), white)

func _build_sidewalks() -> void:
	var concrete := _mat(Color("777b7d"), Color.TRANSPARENT, 0.95)
	var curb := _mat(Color("d9d8ce"), Color.TRANSPARENT, 0.8)
	for side in [-1.0, 1.0]:
		_solid_box("Sidewalk", Vector3(4.0, 0.3, ROAD_LENGTH), Vector3(float(side) * 11.0, 0.15, 0.0), concrete)
		_mesh_box("Curb", Vector3(0.28, 0.44, ROAD_LENGTH), Vector3(float(side) * 9.05, 0.22, 0.0), curb)

func _build_city_blocks() -> void:
	var palettes: Array[Color] = [Color("b65a3a"), Color("d09b63"), Color("4d6f82"), Color("8a8175"), Color("5d6573"), Color("c5b49a")]
	for side_index in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		for building_index in 9:
			var height: float = 6.0 + float((building_index * 7 + side_index * 3) % 13)
			var width: float = 7.0 + float(building_index % 3) * 1.8
			var depth: float = 8.0 + float((building_index + 1) % 3) * 2.0
			var z_value: float = -82.0 + float(building_index) * 20.5
			var x_value: float = side * (16.0 + depth * 0.5)
			var building_mat := _mat(palettes[(building_index + side_index) % palettes.size()], Color.TRANSPARENT, 0.88)
			var building := _solid_box("NairobiBlock", Vector3(depth, height, width), Vector3(x_value, height * 0.5, z_value), building_mat)
			_add_windows(building, depth, height, width, -side)

func _add_windows(building: Node3D, depth: float, height: float, width: float, road_facing: float) -> void:
	var window_mat := _mat(Color("143047"), Color("0b2538"), 0.25, 0.15)
	var floor_count: int = maxi(2, int(height / 2.4))
	var column_count: int = maxi(2, int(width / 2.2))
	for floor_index in floor_count:
		for column_index in column_count:
			var y_value: float = -height * 0.5 + 1.3 + float(floor_index) * 2.15
			var z_value: float = -width * 0.5 + 1.15 + float(column_index) * ((width - 2.0) / float(maxi(column_count - 1, 1)))
			_mesh_box("Window", Vector3(0.05, 0.75, 1.0), Vector3(road_facing * (depth * 0.5 + 0.03), y_value, z_value), window_mat, building)

func _build_street_furniture() -> void:
	var pole_mat := _mat(Color("30343a"), Color.TRANSPARENT, 0.4, 0.7)
	var lamp_mat := _mat(Color("fff4c4"), Color("ffe08a"), 0.25)
	for side in [-1.0, 1.0]:
		for z_value in range(-80, 81, 20):
			var pole := Node3D.new()
			pole.name = "StreetLight"
			pole.position = Vector3(float(side) * 9.8, 0.3, float(z_value))
			add_child(pole)
			_mesh_box("Pole", Vector3(0.12, 5.8, 0.12), Vector3(0.0, 2.9, 0.0), pole_mat, pole)
			_mesh_box("Arm", Vector3(1.35, 0.1, 0.1), Vector3(-float(side) * 0.62, 5.72, 0.0), pole_mat, pole)
			_mesh_box("Lamp", Vector3(0.52, 0.16, 0.3), Vector3(-float(side) * 1.25, 5.62, 0.0), lamp_mat, pole)
	for z_value in [-56.0, 12.0, 66.0]:
		_add_billboard(Vector3(-13.3, 4.0, z_value), "KEEP LEFT\nNAIROBI", Color("1fbf71"), 90.0)
	for z_value in [-35.0, 35.0]:
		_add_tree(Vector3(13.0, 0.3, z_value))

func _build_stage() -> void:
	var canopy := _mat(Color("e53e3e"), Color.TRANSPARENT, 0.65)
	var metal := _mat(Color("555d67"), Color.TRANSPARENT, 0.38, 0.7)
	var stage := Node3D.new()
	stage.name = "MatatuStage"
	stage.position = Vector3(-12.2, 0.3, 55.0)
	add_child(stage)
	_mesh_box("Canopy", Vector3(3.8, 0.18, 8.0), Vector3(0.0, 3.3, 0.0), canopy, stage)
	for x_value in [-1.7, 1.7]:
		for z_value in [-3.6, 3.6]:
			_mesh_box("Post", Vector3(0.12, 3.3, 0.12), Vector3(float(x_value), 1.65, float(z_value)), metal, stage)
	_add_label("StageSign", "MATATU STAGE\nCBD • WESTLANDS", Vector3(-10.15, 3.0, 55.0), Vector3(0.0, -90.0, 0.0), Color.WHITE, 0.006, 42)

func _build_landmark() -> void:
	var tower_mat := _mat(Color("6b7683"), Color.TRANSPARENT, 0.32, 0.62)
	var crown_mat := _mat(Color("cf2f3f"), Color("6d0d18"), 0.35, 0.4)
	var tower := Node3D.new()
	tower.name = "FictionalNairobiTower"
	tower.position = Vector3(-28.0, 0.0, -55.0)
	add_child(tower)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 2.2
	cylinder.bottom_radius = 3.0
	cylinder.height = 28.0
	cylinder.radial_segments = 12
	var tower_mesh := MeshInstance3D.new()
	tower_mesh.mesh = cylinder
	tower_mesh.material_override = tower_mat
	tower_mesh.position = Vector3(0.0, 14.0, 0.0)
	tower.add_child(tower_mesh)
	_mesh_box("Crown", Vector3(6.0, 1.4, 6.0), Vector3(0.0, 28.5, 0.0), crown_mat, tower)
	_add_label("CityTitle", "NAIROBI ARCADE RUN", Vector3(0.0, 7.0, -94.0), Vector3.ZERO, Color("f8d34f"), 0.012, 64)

func _build_intersection() -> void:
	var asphalt := _mat(Color("24262a"), Color.TRANSPARENT, 0.94)
	var white := _mat(Color("e6e4db"), Color.TRANSPARENT, 0.82)
	var island_mat := _mat(Color("c9c6bb"), Color.TRANSPARENT, 0.95)
	# A broad Nairobi junction breaks up the original corridor without changing the route.
	_mesh_box("CrossStreet", Vector3(76.0, 0.075, 16.0), Vector3(0.0, 0.045, 1.0), asphalt)
	for x_value in range(-34, 35, 8):
		_mesh_box("CrossStreetDash", Vector3(4.2, 0.025, 0.16), Vector3(float(x_value), 0.098, 1.0), white)
	for x_value in [-10.5, 10.5]:
		_solid_box("PedestrianIsland", Vector3(2.0, 0.22, 5.5), Vector3(float(x_value), 0.11, 1.0), island_mat)
	# Direction arrows on both carriageways.
	for arrow_data: Vector3 in [Vector3(-4.0, 27.0, 0.0), Vector3(4.0, -30.0, 180.0)]:
		_add_road_arrow(arrow_data.x, arrow_data.y, arrow_data.z, white)

func _add_road_arrow(x_value: float, z_value: float, yaw: float, material: Material) -> void:
	var arrow := Node3D.new()
	arrow.name = "LaneArrow"
	arrow.position = Vector3(x_value, 0.101, z_value)
	arrow.rotation_degrees = Vector3(0.0, yaw, 0.0)
	add_child(arrow)
	_mesh_box("Shaft", Vector3(0.28, 0.025, 3.0), Vector3.ZERO, material, arrow)
	_mesh_box("HeadLeft", Vector3(0.25, 0.025, 1.4), Vector3(-0.42, 0.0, -1.55), material, arrow, Vector3(0.0, -38.0, 0.0))
	_mesh_box("HeadRight", Vector3(0.25, 0.025, 1.4), Vector3(0.42, 0.0, -1.55), material, arrow, Vector3(0.0, 38.0, 0.0))

func _build_roadside_detail() -> void:
	var drain_mat := _mat(Color("34383a"), Color.TRANSPARENT, 1.0)
	var grate_mat := _mat(Color("1a1c1e"), Color.TRANSPARENT, 0.4, 0.78)
	var hump_mat := _mat(Color("d8b22c"), Color.TRANSPARENT, 0.82)
	# Open drainage and grates are characteristic roadside cues, kept shallow for playability.
	for side in [-1.0, 1.0]:
		_mesh_box("DrainChannel", Vector3(0.7, 0.12, ROAD_LENGTH), Vector3(float(side) * 9.45, 0.055, 0.0), drain_mat)
		for z_value in range(-80, 81, 20):
			_mesh_box("DrainGrate", Vector3(0.72, 0.035, 1.4), Vector3(float(side) * 9.45, 0.13, float(z_value)), grate_mat)
	# Painted humps are visual and gentle so the checkpoint route remains fun.
	for z_value in [58.0, -42.0]:
		_mesh_box("SpeedHump", Vector3(16.2, 0.11, 0.85), Vector3(0.0, 0.13, z_value), hump_mat)
		for stripe_index in range(-7, 8, 2):
			_mesh_box("HumpStripe", Vector3(0.6, 0.02, 0.88), Vector3(float(stripe_index), 0.195, z_value), grate_mat)
	# Small informal kiosks add human scale without expensive imported assets.
	for kiosk_data: Vector3 in [Vector3(-13.8, 72.0, 0.0), Vector3(14.1, -48.0, 1.0), Vector3(-14.2, -14.0, 2.0)]:
		_add_kiosk(kiosk_data)

func _add_kiosk(data: Vector3) -> void:
	var wall_colors: Array[Color] = [Color("d94a3a"), Color("297a55"), Color("d6a72d")]
	var wall := _mat(wall_colors[int(data.z) % wall_colors.size()], Color.TRANSPARENT, 0.9)
	var roof := _mat(Color("565b60"), Color.TRANSPARENT, 0.55, 0.65)
	var kiosk := Node3D.new()
	kiosk.name = "RoadsideKiosk"
	kiosk.position = Vector3(data.x, 0.3, data.y)
	add_child(kiosk)
	_mesh_box("KioskBody", Vector3(3.6, 2.6, 3.0), Vector3(0.0, 1.3, 0.0), wall, kiosk)
	_mesh_box("KioskRoof", Vector3(4.2, 0.14, 3.6), Vector3(0.0, 2.72, 0.0), roof, kiosk, Vector3(0.0, 0.0, 4.0))
	_mesh_box("ServingWindow", Vector3(1.6, 1.05, 0.06), Vector3(0.0, 1.45, -1.53), _mat(Color("14191d"), Color.TRANSPARENT, 0.5), kiosk)

func _build_traffic_infrastructure() -> void:
	var pole_mat := _mat(Color("262a2e"), Color.TRANSPARENT, 0.4, 0.75)
	var red_mat := _mat(Color("99152b"), Color("ff123f"), 0.2)
	var amber_mat := _mat(Color("a66b08"), Color("ff9d00"), 0.2)
	var green_mat := _mat(Color("0d7d42"), Color("16ef72"), 0.2)
	for side in [-1.0, 1.0]:
		var traffic_signal := Node3D.new()
		traffic_signal.name = "TrafficSignal"
		traffic_signal.position = Vector3(float(side) * 8.7, 0.3, 8.8)
		add_child(traffic_signal)
		_mesh_box("Pole", Vector3(0.16, 4.8, 0.16), Vector3(0.0, 2.4, 0.0), pole_mat, traffic_signal)
		_mesh_box("SignalHousing", Vector3(0.62, 1.75, 0.48), Vector3(0.0, 4.55, -0.18), pole_mat, traffic_signal)
		_add_signal_lens(traffic_signal, Vector3(0.0, 5.05, -0.44), red_mat)
		_add_signal_lens(traffic_signal, Vector3(0.0, 4.55, -0.44), amber_mat)
		_add_signal_lens(traffic_signal, Vector3(0.0, 4.05, -0.44), green_mat)
	_add_label("RoadSign", "CBD  2 km\nWESTLANDS  5 km", Vector3(7.6, 5.1, -22.0), Vector3(0.0, 180.0, 0.0), Color.WHITE, 0.007, 44)

func _add_signal_lens(parent_node: Node3D, position_value: Vector3, material: Material) -> void:
	var lens := SphereMesh.new()
	lens.radius = 0.18
	lens.height = 0.3
	lens.radial_segments = 10
	lens.rings = 5
	var instance := MeshInstance3D.new()
	instance.mesh = lens
	instance.material_override = material
	instance.position = position_value
	parent_node.add_child(instance)

func _add_billboard(position_value: Vector3, text_value: String, color: Color, yaw: float) -> void:
	var board_mat := _mat(Color("101318"), Color.TRANSPARENT, 0.5, 0.4)
	_solid_box("Billboard", Vector3(0.3, 4.0, 7.0), position_value, board_mat, Vector3(0.0, yaw, 0.0))
	var face_offset: float = -0.18 if position_value.x < 0.0 else 0.18
	var face_yaw: float = -90.0 if position_value.x < 0.0 else 90.0
	_add_label("BillboardText", text_value, position_value + Vector3(face_offset, 0.0, 0.0), Vector3(0.0, face_yaw, 0.0), color, 0.009, 46)

func _add_tree(position_value: Vector3) -> void:
	var trunk_mat := _mat(Color("5b3b22"), Color.TRANSPARENT, 1.0)
	var leaf_mat := _mat(Color("2e713d"), Color.TRANSPARENT, 0.95)
	var tree := Node3D.new()
	tree.name = "StreetTree"
	tree.position = position_value
	add_child(tree)
	_mesh_box("Trunk", Vector3(0.35, 3.0, 0.35), Vector3(0.0, 1.5, 0.0), trunk_mat, tree)
	var crown := SphereMesh.new()
	crown.radius = 1.8
	crown.height = 3.3
	crown.radial_segments = 12
	crown.rings = 6
	var crown_instance := MeshInstance3D.new()
	crown_instance.mesh = crown
	crown_instance.material_override = leaf_mat
	crown_instance.position = Vector3(0.0, 4.0, 0.0)
	tree.add_child(crown_instance)

func _add_label(name_text: String, text_value: String, position_value: Vector3, rotation_value: Vector3, color: Color, pixel_size_value: float, font_size_value: int) -> void:
	var label := Label3D.new()
	label.name = name_text
	label.text = text_value
	label.position = position_value
	label.rotation_degrees = rotation_value
	label.modulate = color
	label.outline_modulate = Color("080808")
	label.outline_size = 10
	label.pixel_size = pixel_size_value
	label.font_size = font_size_value
	add_child(label)

func _build_cbd_identity() -> void:
	# Street identity is inspired by real CBD names, while geometry remains a
	# gameplay interpretation until verified GIS/scan geometry is integrated.
	var sign_green := _mat(Color("176b48"), Color.TRANSPARENT, 0.55, 0.15)
	var pole := _mat(Color("31363b"), Color.TRANSPARENT, 0.45, 0.65)
	var signs: Array[Dictionary] = [
		{"z": 70.0, "text": "TOM MBOYA STREET"},
		{"z": 28.0, "text": "KENNETH MATIBA ROAD"},
		{"z": -18.0, "text": "RONALD NGALA STREET"},
		{"z": -62.0, "text": "LATEMA ROAD"}
	]
	for data in signs:
		var z_value := float(data["z"])
		var post := Node3D.new()
		post.name = "CBDStreetSign"
		post.position = Vector3(10.2, 0.3, z_value)
		add_child(post)
		_mesh_box("Post", Vector3(0.12, 3.3, 0.12), Vector3(0.0, 1.65, 0.0), pole, post)
		_mesh_box("Board", Vector3(0.18, 0.72, 4.9), Vector3(0.0, 3.1, 0.0), sign_green, post)
		_add_label("StreetName", str(data["text"]), Vector3(10.08, 3.4, z_value), Vector3(0.0, 90.0, 0.0), Color.WHITE, 0.005, 34)
	_add_label("CBDMarker", "NAIROBI CBD • MATATU MAYHEM", Vector3(-9.1, 5.4, 86.0), Vector3(0.0, -90.0, 0.0), Color("ffd34d"), 0.006, 42)
