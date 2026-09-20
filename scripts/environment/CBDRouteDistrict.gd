class_name CBDRouteDistrict
extends Node3D

const ROAD_W := 15.0
const BLOCK := 42.0

func _ready() -> void:
	_build_grid()
	_build_stages()
	_build_landmarks()
	_build_clutter()

func _mat(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _box(name_text: String, size: Vector3, pos: Vector3, mat: Material, parent: Node = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var i := MeshInstance3D.new()
	i.name = name_text
	i.mesh = mesh
	i.material_override = mat
	i.position = pos
	(parent if parent != null else self).add_child(i)
	return i

func _solid(name_text: String, size: Vector3, pos: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_text
	body.position = pos
	add_child(body)
	_box("Mesh", size, Vector3.ZERO, mat, body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	return body

func _build_grid() -> void:
	var asphalt := _mat(Color("23262b"), 0.96)
	var pavement := _mat(Color("777b7d"), 0.94)
	var white := _mat(Color("e9e6dc"), 0.8)
	# Cross streets create a compact playable CBD grid around the original north-south spine.
	for z in [-63.0, -21.0, 21.0, 63.0]:
		_box("CrossStreet", Vector3(82.0, 0.07, ROAD_W), Vector3(0.0, 0.05, z), asphalt)
		for x in range(-35, 36, 8):
			_box("LaneDash", Vector3(4.0, 0.02, 0.15), Vector3(float(x), 0.1, z), white)
	# Parallel service streets make the world read as blocks rather than one corridor.
	for x in [-31.0, 31.0]:
		_box("ParallelStreet", Vector3(ROAD_W, 0.07, 180.0), Vector3(x, 0.05, 0.0), asphalt)
		for z in range(-82, 83, 9):
			_box("ParallelDash", Vector3(0.15, 0.02, 4.2), Vector3(x, 0.1, float(z)), white)
	# Pavement islands at block corners.
	for x in [-20.0, 20.0]:
		for z in [-42.0, 0.0, 42.0]:
			_solid("CBDPavementBlock", Vector3(13.0, 0.24, 24.0), Vector3(x, 0.12, z), pavement)

func _build_stages() -> void:
	_stage(Vector3(-22.0, 0.25, 63.0), "TOM MBOYA STAGE", "CBD • EASTLANDS")
	_stage(Vector3(22.0, 0.25, 21.0), "ACC/NGALA STAGE", "NGARA • THIKA RD")
	_stage(Vector3(-22.0, 0.25, -63.0), "LATEMA STAGE", "WESTLANDS • KANGEMI")

func _stage(pos: Vector3, title: String, route: String) -> void:
	var root := Node3D.new()
	root.name = "MatatuStage"
	root.position = pos
	add_child(root)
	var roof := _mat(Color("d9363e"), 0.62)
	var metal := _mat(Color("3c434a"), 0.45, 0.7)
	_box("Roof", Vector3(9.0, 0.18, 3.4), Vector3.ZERO + Vector3(0,3.2,0), roof, root)
	for x in [-4.2, 4.2]:
		for z in [-1.4, 1.4]:
			_box("Post", Vector3(0.12, 3.2, 0.12), Vector3(x,1.6,z), metal, root)
	var label := Label3D.new()
	label.text = title + "\n" + route
	label.position = pos + Vector3(0.0, 3.55, 0.0)
	label.modulate = Color("ffe15a")
	label.outline_size = 10
	label.font_size = 34
	label.pixel_size = 0.006
	add_child(label)

func _build_landmarks() -> void:
	_building(Vector3(-20.0, 0.0, 0.0), Vector3(12, 24, 20), Color("9b7a5c"), "ARCHIVES DISTRICT")
	_building(Vector3(20.0, 0.0, 42.0), Vector3(13, 31, 20), Color("607887"), "CBD TOWER")
	_building(Vector3(20.0, 0.0, -42.0), Vector3(13, 18, 20), Color("aa644c"), "CITY MARKET")
	_building(Vector3(-20.0, 0.0, 42.0), Vector3(12, 21, 20), Color("746b80"), "KENCOM BLOCK")
	_building(Vector3(-20.0, 0.0, -42.0), Vector3(12, 27, 20), Color("7f8a72"), "LATEMA BLOCK")

func _building(pos: Vector3, size: Vector3, color: Color, title: String) -> void:
	var mat := _mat(color, 0.82)
	_solid("CBDLandmark", size, pos + Vector3(0,size.y * 0.5,0), mat)
	var label := Label3D.new()
	label.text = title
	label.position = pos + Vector3(0,size.y + 1.0,-size.z * 0.51)
	label.modulate = Color("f5d85c")
	label.outline_size = 8
	label.font_size = 30
	label.pixel_size = 0.006
	add_child(label)

func _build_clutter() -> void:
	var kiosk_colors := [Color("d04b3f"), Color("2e7750"), Color("d3a230"), Color("346d9b")]
	for i in 18:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * (12.8 + float((i / 2) % 2) * 17.0)
		var z := -78.0 + float(i) * 9.0
		var body := _mat(kiosk_colors[i % kiosk_colors.size()], 0.92)
		_box("StreetKiosk", Vector3(2.8, 2.2, 2.2), Vector3(x, 1.1, z), body)
		var awning := _mat(Color("d9d3c5"), 0.8)
		_box("Awning", Vector3(3.3, 0.12, 2.8), Vector3(x, 2.35, z), awning)
