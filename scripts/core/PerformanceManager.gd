class_name PerformanceManager
extends Node

signal performance_changed(mode: String, effective: String, fps: int)

@export var traffic_path: NodePath
@export var life_path: NodePath
@export var atmosphere_path: NodePath

const MODES := ["AUTO", "PERFORMANCE", "QUALITY"]

var mode := "AUTO"
var effective := "BALANCED"
var _sample_time := 0.0
var _low_fps_time := 0.0
var _startup_grace := 8.0

func _ready() -> void:
	mode = String(SaveManager.data.get("quality_mode", "AUTO"))
	if not mode in MODES:
		mode = "AUTO"
	effective = "BALANCED" if mode == "AUTO" else mode
	_apply_quality()

func _process(delta: float) -> void:
	_startup_grace = maxf(_startup_grace - delta, 0.0)
	_sample_time += delta
	if _sample_time < 1.0:
		return
	_sample_time = 0.0
	var fps := Engine.get_frames_per_second()
	if mode == "AUTO" and _startup_grace <= 0.0:
		_low_fps_time = _low_fps_time + 1.0 if fps < 28 else maxf(_low_fps_time - 1.0, 0.0)
		if _low_fps_time >= 4.0 and effective != "PERFORMANCE":
			effective = "PERFORMANCE"
			_apply_quality()
	performance_changed.emit(mode, effective, fps)

func cycle_mode() -> void:
	var index := MODES.find(mode)
	mode = String(MODES[(index + 1) % MODES.size()])
	effective = "BALANCED" if mode == "AUTO" else mode
	_low_fps_time = 0.0
	_startup_grace = 5.0
	SaveManager.data["quality_mode"] = mode
	SaveManager.save_game()
	_apply_quality()
	performance_changed.emit(mode, effective, Engine.get_frames_per_second())

func _apply_quality() -> void:
	var traffic := get_node_or_null(traffic_path)
	if traffic != null and traffic.has_method("set_vehicle_limit"):
		traffic.call("set_vehicle_limit", 10 if effective == "PERFORMANCE" else 20)
	var life := get_node_or_null(life_path)
	if life != null and life.has_method("set_mover_limit"):
		life.call("set_mover_limit", 7 if effective == "PERFORMANCE" else 18)
	var atmosphere := get_node_or_null(atmosphere_path)
	if atmosphere != null and atmosphere.has_method("set_quality_level"):
		atmosphere.call("set_quality_level", effective)
