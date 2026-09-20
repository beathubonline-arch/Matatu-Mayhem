class_name CBDLifeManager
extends Node3D

@export var pedestrian_count := 28
@export var boda_count := 7

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 2542026
	_spawn_pedestrians()
	_spawn_bodas()

func _spawn_pedestrians() -> void:
	for i in pedestrian_count:
		var person := CharacterBody3D.new()
		person.name = "CBDPedestrian%02d" % i
		var side := -1.0 if i % 2 == 0 else 1.0
		person.position = Vector3(side * _rng.randf_range(10.1, 12.2), 0.3, _rng.randf_range(-88.0, 88.0))
		person.set_meta("walk_dir", -1.0 if i % 3 == 0 else 1.0)
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.28
		capsule.height = 1.7
		collision.shape = capsule
		collision.position.y = 0.85
		person.add_child(collision)
		var mesh := MeshInstance3D.new()
		var body := CapsuleMesh.new()
		body.radius = 0.28
		body.height = 1.55
		mesh.mesh = body
		var mat := StandardMaterial3D.new()
		var colors := [Color("1f4d7a"), Color("8b3d35"), Color("2f6b46"), Color("d19a32"), Color("5e477d")]
		mat.albedo_color = colors[i % colors.size()]
		mesh.material_override = mat
		mesh.position.y = 0.85
		person.add_child(mesh)
		add_child(person)

func _spawn_bodas() -> void:
	for i in boda_count:
		var boda := CharacterBody3D.new()
		boda.name = "Boda%02d" % i
		var direction := -1.0 if i % 2 == 0 else 1.0
		boda.position = Vector3(-6.4 if direction < 0.0 else 6.4, 0.42, -78.0 + float(i) * 25.0)
		boda.set_meta("direction", direction)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.8, 1.1, 2.1)
		collision.shape = shape
		collision.position.y = 0.5
		boda.add_child(collision)
		var bike := MeshInstance3D.new()
		var bike_mesh := BoxMesh.new()
		bike_mesh.size = Vector3(0.62, 0.55, 1.8)
		bike.mesh = bike_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = [Color("20252a"), Color("b9272f"), Color("25649b")][i % 3]
		mat.metallic = 0.3
		mat.roughness = 0.42
		bike.material_override = mat
		bike.position.y = 0.45
		boda.add_child(bike)
		add_child(boda)

func _physics_process(_delta: float) -> void:
	for child in get_children():
		if child.name.begins_with("CBDPedestrian"):
			var dir := float(child.get_meta("walk_dir", 1.0))
			child.velocity = Vector3(0.0, 0.0, dir * 1.25)
			child.move_and_slide()
			if child.global_position.z > 92.0:
				child.global_position.z = -92.0
			elif child.global_position.z < -92.0:
				child.global_position.z = 92.0
		elif child.name.begins_with("Boda"):
			var dir := float(child.get_meta("direction", 1.0))
			child.velocity = Vector3(0.0, 0.0, dir * 13.5)
			child.move_and_slide()
			if child.global_position.z > 94.0:
				child.global_position.z = -94.0
			elif child.global_position.z < -94.0:
				child.global_position.z = 94.0
