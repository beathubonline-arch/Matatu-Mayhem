class_name TrafficManager
extends Node3D

const TRAFFIC_SCENE := preload("res://scenes/traffic/TrafficVehicle.tscn")

@export_range(2, 12, 2) var traffic_count: int = 8

func _ready() -> void:
	var colors: Array[Color] = [Color("d8d4c5"), Color("306b9b"), Color("a53b32"), Color("3e7d50"), Color("d39a2f"), Color("777c86")]
	for index in traffic_count:
		var vehicle := TRAFFIC_SCENE.instantiate() as TrafficVehicle
		if vehicle == null:
			continue
		add_child(vehicle)
		var direction_value: float = -1.0 if index % 2 == 0 else 1.0
		var lane_x: float = -4.0 if direction_value < 0.0 else 4.0
		var lane_index: int = int(index / 2)
		var start_z: float = -78.0 + float(lane_index) * 43.0 + (0.0 if direction_value < 0.0 else 20.0)
		var speed_value: float = 8.5 + float(index % 4) * 1.25
		vehicle.configure(lane_x, start_z, direction_value, speed_value, colors[index % colors.size()])
