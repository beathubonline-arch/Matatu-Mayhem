class_name NganyaVisuals
extends Node3D

const BODY := Color("11131c")
const CYAN := Color("00d9ff")
const MAGENTA := Color("ff2e88")
const ORANGE := Color("ff8a00")
const GLASS := Color("071525")
const CHROME := Color("8c98a8")

func _ready() -> void:
	_build_body()
	_build_windows()
	_build_lighting()
	_build_trim()
	_build_identity()
	_build_realism_details()
	_build_wheels_and_door()
	_apply_selected_nganya()

func _mat(color: Color, emission: Color = Color.TRANSPARENT, metallic: float = 0.0, roughness: float = 0.55) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 2.3
	return material

func _box(name_text: String, size: Vector3, position_value: Vector3, material: Material, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	add_child(instance)
	return instance

func _cylinder(name_text: String, radius: float, depth: float, position_value: Vector3, rotation_value: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 16
	var instance := MeshInstance3D.new()
	instance.name = name_text
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	add_child(instance)
	return instance

func _build_body() -> void:
	var body_mat := _mat(BODY, Color.TRANSPARENT, 0.55, 0.28)
	var cyan_mat := _mat(Color("06354a"), CYAN, 0.3, 0.25)
	var roof_mat := _mat(Color("e5e7eb"), Color.TRANSPARENT, 0.3, 0.32)
	_box("LowerBody", Vector3(2.18, 1.25, 4.85), Vector3(0.0, 0.82, 0.0), body_mat)
	_box("UpperBody", Vector3(2.02, 1.15, 3.95), Vector3(0.0, 1.95, 0.25), body_mat)
	_box("FrontNose", Vector3(2.12, 0.78, 0.55), Vector3(0.0, 1.0, -2.55), body_mat, Vector3(-8.0, 0.0, 0.0))
	_box("Roof", Vector3(2.12, 0.16, 4.25), Vector3(0.0, 2.58, 0.22), roof_mat)
	_box("ElectricBelt", Vector3(2.21, 0.17, 4.72), Vector3(0.0, 1.32, 0.02), cyan_mat)

func _build_windows() -> void:
	var glass_mat := _mat(GLASS, Color("03101d"), 0.15, 0.08)
	_box("Windshield", Vector3(1.78, 0.82, 0.07), Vector3(0.0, 2.0, -2.12), glass_mat, Vector3(-11.0, 0.0, 0.0))
	_box("RearWindow", Vector3(1.72, 0.72, 0.06), Vector3(0.0, 2.0, 2.25), glass_mat)
	for side_index in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		for window_index in 4:
			var z_value: float = -1.25 + float(window_index) * 0.85
			_box("SideWindow_%d_%d" % [side_index, window_index], Vector3(0.055, 0.7, 0.68), Vector3(side * 1.025, 2.02, z_value), glass_mat)

func _build_lighting() -> void:
	var white_light := _mat(Color.WHITE, Color("e8f7ff"), 0.1, 0.12)
	var red_light := _mat(Color("ff1f3d"), Color("ff002b"), 0.1, 0.15)
	var cyan_light := _mat(CYAN, CYAN, 0.1, 0.15)
	var magenta_light := _mat(MAGENTA, MAGENTA, 0.1, 0.15)
	for x_value in [-0.72, 0.72]:
		_box("Headlight", Vector3(0.48, 0.22, 0.08), Vector3(float(x_value), 1.12, -2.84), white_light)
		_box("TailLight", Vector3(0.4, 0.24, 0.07), Vector3(float(x_value), 1.05, 2.47), red_light)
	for x_value in [-0.74, -0.25, 0.25, 0.74]:
		_cylinder("RoofLamp", 0.12, 0.13, Vector3(float(x_value), 2.78, -1.45), Vector3(90.0, 0.0, 0.0), cyan_light if float(x_value) < 0.0 else magenta_light)
	_box("LeftUnderGlow", Vector3(0.06, 0.06, 3.7), Vector3(-1.08, 0.42, 0.15), cyan_light)
	_box("RightUnderGlow", Vector3(0.06, 0.06, 3.7), Vector3(1.08, 0.42, 0.15), magenta_light)

func _build_trim() -> void:
	var chrome_mat := _mat(CHROME, Color.TRANSPARENT, 0.85, 0.18)
	var dark_mat := _mat(Color("050608"), Color.TRANSPARENT, 0.25, 0.38)
	var orange_mat := _mat(ORANGE, ORANGE, 0.25, 0.3)
	_box("FrontBumper", Vector3(2.28, 0.22, 0.24), Vector3(0.0, 0.48, -2.72), chrome_mat)
	_box("RearBumper", Vector3(2.28, 0.22, 0.24), Vector3(0.0, 0.48, 2.56), chrome_mat)
	_box("FrontGrille", Vector3(1.2, 0.42, 0.08), Vector3(0.0, 0.78, -2.84), dark_mat)
	for x_value in [-0.4, -0.2, 0.0, 0.2, 0.4]:
		_box("GrilleBar", Vector3(0.055, 0.36, 0.03), Vector3(float(x_value), 0.78, -2.895), chrome_mat)
	for side_index in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		_box("RoofRail", Vector3(0.06, 0.12, 4.2), Vector3(side * 0.88, 2.76, 0.2), chrome_mat)
		_box("MirrorArm", Vector3(0.34, 0.06, 0.06), Vector3(side * 1.18, 1.9, -1.72), chrome_mat)
		_box("Mirror", Vector3(0.12, 0.3, 0.28), Vector3(side * 1.34, 1.9, -1.72), dark_mat)
		_box("GraffitiSlashA", Vector3(0.04, 0.24, 2.25), Vector3(side * 1.095, 1.05, 0.25), _mat(MAGENTA, MAGENTA), Vector3(0.0, 0.0, 13.0 * side))
		_box("GraffitiSlashB", Vector3(0.045, 0.18, 1.8), Vector3(side * 1.1, 0.82, 0.45), orange_mat, Vector3(0.0, 0.0, -10.0 * side))

func _build_identity() -> void:
	_add_label("FrontRoute", "NAIROBI EXPRESS", Vector3(0.0, 2.35, -2.18), Vector3(0.0, 180.0, 0.0), Color("f7ff00"), 0.0045, 54)
	_add_label("RearName", "MAVERICK", Vector3(0.0, 1.58, 2.29), Vector3.ZERO, CYAN, 0.005, 58)
	_add_label("LeftTag", "MATATU MAYHEM", Vector3(-1.13, 1.55, 0.25), Vector3(0.0, -90.0, 0.0), Color.WHITE, 0.0045, 44)
	_add_label("RightTag", "MATATU MAYHEM", Vector3(1.13, 1.55, 0.25), Vector3(0.0, 90.0, 0.0), Color.WHITE, 0.0045, 44)
	var speaker_mat := _mat(Color("070709"), Color.TRANSPARENT, 0.2, 0.42)
	for x_value in [-0.52, 0.0, 0.52]:
		_cylinder("RearSpeaker", 0.2, 0.08, Vector3(float(x_value), 0.82, 2.49), Vector3(90.0, 0.0, 0.0), speaker_mat)

func _build_realism_details() -> void:
	var black := _mat(Color("050608"), Color.TRANSPARENT, 0.15, 0.58)
	var chrome := _mat(CHROME, Color.TRANSPARENT, 0.92, 0.14)
	var amber := _mat(Color("ff9d18"), Color("ff6a00"), 0.05, 0.18)
	var plate := _mat(Color("f4f4ec"), Color.TRANSPARENT, 0.05, 0.62)
	var red := _mat(Color("d91432"), Color("8a061c"), 0.2, 0.36)
	var green := _mat(Color("12874d"), Color.TRANSPARENT, 0.1, 0.55)
	var white := _mat(Color("f0f0e8"), Color.TRANSPARENT, 0.1, 0.55)
	# Bull bar and front protection frame.
	_box("BullBarTop", Vector3(1.75, 0.08, 0.08), Vector3(0.0, 0.72, -2.98), chrome)
	_box("BullBarBottom", Vector3(1.75, 0.08, 0.08), Vector3(0.0, 0.42, -2.98), chrome)
	for x_value in [-0.78, 0.78]:
		_box("BullBarPost", Vector3(0.08, 0.42, 0.08), Vector3(float(x_value), 0.57, -2.98), chrome)
	# Windshield divider, wipers and sun visor.
	_box("WindshieldDivider", Vector3(0.045, 0.78, 0.045), Vector3(0.0, 2.0, -2.175), black, Vector3(-11.0, 0.0, 0.0))
	_box("LeftWiper", Vector3(0.035, 0.48, 0.035), Vector3(-0.38, 1.78, -2.205), black, Vector3(-8.0, 0.0, -28.0))
	_box("RightWiper", Vector3(0.035, 0.48, 0.035), Vector3(0.38, 1.78, -2.205), black, Vector3(-8.0, 0.0, 28.0))
	_box("SunVisor", Vector3(2.12, 0.16, 0.42), Vector3(0.0, 2.62, -1.96), black, Vector3(-8.0, 0.0, 0.0))
	# Indicators, number plates and tow hooks.
	for x_value in [-0.98, 0.98]:
		_box("FrontIndicator", Vector3(0.17, 0.18, 0.06), Vector3(float(x_value), 1.02, -2.86), amber)
		_cylinder("TowHook", 0.08, 0.08, Vector3(float(x_value) * 0.55, 0.34, -2.9), Vector3(90.0, 0.0, 0.0), red)
	_box("FrontPlate", Vector3(0.7, 0.22, 0.045), Vector3(0.0, 0.44, -3.035), plate)
	_box("RearPlate", Vector3(0.7, 0.22, 0.045), Vector3(0.0, 0.48, 2.69), plate)
	_add_label("FrontPlateText", "KMM 047N", Vector3(0.0, 0.44, -3.061), Vector3(0.0, 180.0, 0.0), Color("101010"), 0.0028, 38)
	_add_label("RearPlateText", "KMM 047N", Vector3(0.0, 0.48, 2.716), Vector3.ZERO, Color("101010"), 0.0028, 38)
	# Passenger door seams, handle, fuel cap and mud flaps.
	for side_index in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		_box("DoorSeamFront", Vector3(0.035, 1.68, 0.035), Vector3(side * 1.112, 1.23, -1.48), chrome)
		_box("DoorSeamRear", Vector3(0.035, 1.68, 0.035), Vector3(side * 1.112, 1.23, -0.18), chrome)
		_box("DoorHandle", Vector3(0.045, 0.07, 0.28), Vector3(side * 1.14, 1.36, -0.38), chrome)
		_box("MudFlapFront", Vector3(0.08, 0.5, 0.42), Vector3(side * 0.98, 0.28, -0.98), black)
		_box("MudFlapRear", Vector3(0.08, 0.5, 0.42), Vector3(side * 0.98, 0.28, 2.05), black)
	_cylinder("FuelCap", 0.12, 0.035, Vector3(-1.125, 0.95, 1.82), Vector3(0.0, 0.0, 90.0), chrome)
	# Kenyan flag accent and roof equipment make the vehicle read as a real nganya.
	_box("FlagBlack", Vector3(0.04, 0.09, 2.7), Vector3(-1.13, 1.22, 0.28), black)
	_box("FlagRed", Vector3(0.041, 0.09, 2.7), Vector3(-1.132, 1.12, 0.28), red)
	_box("FlagGreen", Vector3(0.042, 0.09, 2.7), Vector3(-1.134, 1.02, 0.28), green)
	_box("FlagWhiteA", Vector3(0.043, 0.025, 2.7), Vector3(-1.136, 1.17, 0.28), white)
	_box("FlagWhiteB", Vector3(0.043, 0.025, 2.7), Vector3(-1.136, 1.07, 0.28), white)
	_box("RoofAC", Vector3(0.82, 0.25, 1.0), Vector3(0.0, 2.82, 0.72), white)
	_box("RoofRackFront", Vector3(1.8, 0.07, 0.07), Vector3(0.0, 2.84, -0.5), chrome)
	_box("RoofRackRear", Vector3(1.8, 0.07, 0.07), Vector3(0.0, 2.84, 1.55), chrome)
	_box("Antenna", Vector3(0.035, 0.9, 0.035), Vector3(0.72, 3.18, 1.45), black, Vector3(0.0, 0.0, -10.0))
	# Exhaust and rear ladder.
	_cylinder("Exhaust", 0.07, 0.7, Vector3(0.82, 0.48, 2.75), Vector3(90.0, 0.0, 0.0), chrome)
	for x_value in [0.62, 0.96]:
		_box("RearLadderRail", Vector3(0.055, 1.55, 0.055), Vector3(float(x_value), 1.65, 2.66), chrome)
	for y_value in [0.98, 1.3, 1.62, 1.94, 2.26]:
		_box("RearLadderStep", Vector3(0.4, 0.045, 0.055), Vector3(0.79, float(y_value), 2.66), chrome)

func _add_label(name_text: String, label_text: String, position_value: Vector3, rotation_value: Vector3, color: Color, pixel_size_value: float, font_size_value: int) -> void:
	var label := Label3D.new()
	label.name = name_text
	label.text = label_text
	label.position = position_value
	label.rotation_degrees = rotation_value
	label.modulate = color
	label.outline_modulate = Color("050505")
	label.outline_size = 8
	label.pixel_size = pixel_size_value
	label.font_size = font_size_value
	add_child(label)

func _apply_selected_nganya() -> void:
	var selected := String(SaveManager.data.get("selected_nganya", "Maverick")).to_upper()
	var palettes := {
		"MAVERICK": [Color("00d9ff"), Color("ff2e88")],
		"ONYX": [Color("a855f7"), Color("22d3ee")],
		"MOXIE": [Color("ff8a00"), Color("f7ff00")],
		"MONEYFEST": [Color("22c55e"), Color("facc15")],
		"STREET LEGEND": [Color("f7ff00"), Color("ff2e88")]
	}
	var palette: Array = palettes.get(selected, palettes["MAVERICK"])
	for child in get_children():
		if child is MeshInstance3D and (child.name.contains("UnderGlow") or child.name.contains("ElectricBelt")):
			var material := _mat(palette[0], palette[0], 0.25, 0.22)
			child.material_override = material
	var rear := get_node_or_null("RearName") as Label3D
	if rear != null:
		rear.text = selected
		rear.modulate = palette[0]
	var front := get_node_or_null("FrontRoute") as Label3D
	if front != null:
		front.modulate = palette[1]


func _build_wheels_and_door() -> void:
	var tyre := _mat(Color("070707"), Color.TRANSPARENT, 0.05, 0.82)
	var rim := _mat(CHROME, Color.TRANSPARENT, 0.92, 0.16)
	for side in [-1.0, 1.0]:
		for z in [-1.55, 1.55]:
			_cylinder("Tyre", 0.43, 0.22, Vector3(side * 1.08, 0.48, z), Vector3(0, 0, 90), tyre)
			_cylinder("Rim", 0.24, 0.235, Vector3(side * 1.085, 0.48, z), Vector3(0, 0, 90), rim)
	# Passenger door is deliberately obvious from the chase camera/stage side.
	var door_mat := _mat(Color("151923"), Color.TRANSPARENT, 0.42, 0.34)
	_box("PassengerDoor", Vector3(0.055, 1.65, 1.18), Vector3(1.13, 1.25, -0.82), door_mat)
	_add_label("DoorCall", "PANDA / SHUKA", Vector3(1.17, 1.45, -0.82), Vector3(0, 90, 0), Color("ffe15a"), 0.0034, 32)
