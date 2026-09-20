class_name RivalMatatuManager
extends Node3D

@export var rival_count := 4
@export var network_path: NodePath
@export var corridor_service_path: NodePath

var network: NairobiRouteNetwork
var corridor_service: CorridorServiceManager
var active_corridor := 0

func _ready() -> void:
	network = get_node_or_null(network_path) as NairobiRouteNetwork
	corridor_service = get_node_or_null(corridor_service_path) as CorridorServiceManager
	if corridor_service != null:
		corridor_service.corridor_changed.connect(_on_corridor_changed)
	_spawn_pack()

func _spawn_pack() -> void:
	for child in get_children():
		child.queue_free()
	for i in range(rival_count):
		_spawn_rival(i)

func _on_corridor_changed(_name: String, _stop_name: String, current: int, _total: int) -> void:
	if current != 1 or corridor_service == null:
		return
	var selected := corridor_service.corridor_index
	if selected == active_corridor and get_child_count() > 0:
		return
	active_corridor = selected
	_spawn_pack()

func _spawn_rival(index: int) -> void:
	var rival := CharacterBody3D.new()
	rival.name = "RivalNganya%02d" % index
	var points: Array = []
	if network != null:
		points = network.get_corridor(active_corridor)["points"]
	if points.size() < 2:
		points = [Vector3(0,0,80), Vector3(0,0,-80)]
	var segment_index: int = index % max(points.size() - 1, 1)
	var a: Vector3 = points[segment_index]
	var b: Vector3 = points[segment_index + 1]
	var forward := index % 2 == 0
	var direction := (b - a).normalized()
	var lane_offset := 2.8 if forward else -2.8
	rival.position = a.lerp(b, 0.2 + 0.16 * float(index % 4)) + Vector3(direction.z, 0.55, -direction.x) * lane_offset
	rival.set_meta("points", points)
	rival.set_meta("point_index", segment_index + 1 if forward else segment_index)
	rival.set_meta("forward", forward)
	rival.set_meta("lane_offset", lane_offset)
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
	var neon: Color = [Color("00d9ff"), Color("ff2e88"), Color("ff9a18"), Color("54ff77")][index % 4]
	glow_mat.albedo_color = neon
	glow_mat.emission_enabled = true
	glow_mat.emission = neon
	glow_mat.emission_energy_multiplier = 2.4
	glow.material_override = glow_mat
	rival.add_child(glow)
	var label := Label3D.new()
	label.text = ["ONYX", "MONEYFEST", "OPPOSITE", "MOXIE"][index % 4]
	label.position = Vector3(0.0, 2.0, -2.28)
	label.rotation_degrees.y = 180.0
	label.modulate = neon
	label.outline_size = 8
	label.font_size = 34
	label.pixel_size = 0.005
	rival.add_child(label)
	add_child(rival)

func _physics_process(_delta: float) -> void:
	for child in get_children():
		var rival := child as CharacterBody3D
		if rival == null:
			continue
		var points: Array = rival.get_meta("points", [])
		if points.size() < 2:
			continue
		var point_index := clampi(int(rival.get_meta("point_index", 1)), 0, points.size() - 1)
		var target: Vector3 = points[point_index]
		var to_target := target - rival.global_position
		to_target.y = 0.0
		if to_target.length() < 4.5:
			var forward := bool(rival.get_meta("forward", true))
			if forward and point_index >= points.size() - 1:
				forward = false
				point_index = maxi(points.size() - 2, 0)
			elif not forward and point_index <= 0:
				forward = true
				point_index = mini(1, points.size() - 1)
			else:
				point_index += 1 if forward else -1
			rival.set_meta("forward", forward)
			rival.set_meta("point_index", point_index)
			target = points[point_index]
			to_target = target - rival.global_position
			to_target.y = 0.0
		var direction := to_target.normalized()
		var lateral := Vector3(direction.z, 0.0, -direction.x) * float(rival.get_meta("lane_offset", 2.8))
		var desired := target + lateral
		direction = (desired - rival.global_position).normalized()
		direction.y = 0.0
		rival.velocity = direction * float(rival.get_meta("speed", 10.0))
		if direction.length_squared() > 0.01:
			rival.rotation.y = atan2(-direction.x, -direction.z)
		rival.move_and_slide()
