class_name RivalMatatuManager
extends Node3D

@export var rival_count := 4

func _ready() -> void:
	for i in rival_count:
		_spawn_rival(i)

func _spawn_rival(index: int) -> void:
	var rival := CharacterBody3D.new()
	rival.name = "RivalNganya%02d" % index
	var direction := -1.0 if index % 2 == 0 else 1.0
	var lane := -2.6 if direction < 0.0 else 2.6
	rival.position = Vector3(lane, 0.5, -72.0 + float(index) * 39.0)
	rival.rotation_degrees.y = 0.0 if direction < 0.0 else 180.0
	rival.set_meta("direction", direction)
	rival.set_meta("speed", 9.0 + float(index) * 0.8)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.05, 2.3, 4.5)
	collision.shape = shape
	collision.position.y = 1.1
	rival.add_child(collision)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.05, 2.15, 4.5)
	body.mesh = body_mesh
	body.position.y = 1.1
	var palettes := [Color("171822"), Color("28202f"), Color("132c32"), Color("2f181c")]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = palettes[index % palettes.size()]
	mat.metallic = 0.45
	mat.roughness = 0.3
	body.material_override = mat
	rival.add_child(body)
	var glow := MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(2.12, 0.12, 3.6)
	glow.mesh = glow_mesh
	glow.position = Vector3(0.0, 0.45, 0.0)
	var glow_mat := StandardMaterial3D.new()
	var neon := [Color("00d9ff"), Color("ff2e88"), Color("ff9a18"), Color("54ff77")][index % 4]
	glow_mat.albedo_color = neon
	glow_mat.emission_enabled = true
	glow_mat.emission = neon
	glow_mat.emission_energy_multiplier = 2.4
	glow.material_override = glow_mat
	rival.add_child(glow)
	var label := Label3D.new()
	label.text = ["RONG RENDE", "CBD BEAST", "NAIROBI NIGHTS", "STREET KING"][index % 4]
	label.position = Vector3(0.0, 2.0, -2.28)
	label.rotation_degrees.y = 180.0
	label.modulate = neon
	label.outline_size = 8
	label.font_size = 34
	label.pixel_size = 0.005
	rival.add_child(label)
	add_child(rival)

func _physics_process(_delta: float) -> void:
	for rival in get_children():
		if not rival is CharacterBody3D:
			continue
		var direction := float(rival.get_meta("direction", -1.0))
		var speed := float(rival.get_meta("speed", 10.0))
		rival.velocity = Vector3(0.0, 0.0, direction * speed)
		rival.move_and_slide()
		if rival.global_position.z < -94.0:
			rival.global_position.z = 94.0
		elif rival.global_position.z > 94.0:
			rival.global_position.z = -94.0
