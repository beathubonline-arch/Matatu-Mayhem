class_name NairobiTestMap
extends Node3D

# Milestone 4: the legacy straight test road has been retired.
# This node now supplies only a lightweight ground plane beneath the data-driven
# NairobiRouteNetwork. Roads, junctions, stages and route identity live there.

func _ready() -> void:
	var ground := StaticBody3D.new()
	ground.name = "NairobiGround"
	ground.position = Vector3(0.0, -0.32, 20.0)
	ground.collision_layer = 1
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(620.0, 0.5, 650.0)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("46503c")
	material.roughness = 1.0
	mesh_instance.material_override = material
	ground.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	ground.add_child(collision)
	add_child(ground)
