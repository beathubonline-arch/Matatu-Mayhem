class_name CityAtmosphere
extends Node

signal conditions_changed(label: String, is_night: bool, raining: bool)

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var player_path: NodePath
@export var cycle_seconds := 180.0

var _phase := 0.22
var _manual_night := false
var _sun: DirectionalLight3D
var _world: WorldEnvironment
var _player: Node3D
var _rain: CPUParticles3D
var _weather_clock := 0.0
var _last_condition := ""

func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_world = get_node_or_null(environment_path) as WorldEnvironment
	_player = get_node_or_null(player_path) as Node3D
	_create_rain()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_manual_night = not _manual_night
		_phase = 0.78 if _manual_night else 0.22

func _process(delta: float) -> void:
	_weather_clock = fmod(_weather_clock + delta, 120.0)
	if not _manual_night:
		_phase = fmod(_phase + delta / cycle_seconds, 1.0)
	if _sun == null or _world == null or _world.environment == null:
		return
	var daylight := clampf(sin(_phase * TAU) * 0.5 + 0.5, 0.08, 1.0)
	var raining := _weather_clock >= 48.0 and _weather_clock <= 76.0
	var is_night := daylight < 0.34
	_sun.rotation_degrees.x = lerpf(-12.0, -62.0, daylight)
	_sun.light_energy = lerpf(0.12, 1.18, daylight)
	_sun.light_color = Color("ffb36b").lerp(Color("fff0d0"), daylight)
	var env := _world.environment
	env.ambient_light_energy = lerpf(0.22, 0.72, daylight)
	env.background_color = Color("07101f").lerp(Color("548bc2"), daylight)
	env.fog_light_energy = lerpf(0.08, 0.38, daylight)
	env.fog_density = 0.0065 if raining else lerpf(0.0042, 0.0023, daylight)
	if _rain != null:
		_rain.emitting = raining
		if _player != null and is_instance_valid(_player):
			_rain.global_position = _player.global_position + Vector3.UP * 10.0
	var condition := "SHORT RAINS" if raining else ("NIGHT SHIFT" if is_night else ("GOLDEN HOUR" if daylight < 0.55 else "NAIROBI DAY"))
	if condition != _last_condition:
		_last_condition = condition
		conditions_changed.emit(condition, is_night, raining)
		_set_vehicle_lights(is_night or raining)

func _create_rain() -> void:
	_rain = CPUParticles3D.new()
	_rain.name = "NairobiRain"
	_rain.amount = 110
	_rain.lifetime = 0.75
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(13.0, 0.25, 13.0)
	_rain.direction = Vector3.DOWN
	_rain.spread = 3.0
	_rain.initial_velocity_min = 24.0
	_rain.initial_velocity_max = 29.0
	_rain.gravity = Vector3.ZERO
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.75)
	var rain_mat := StandardMaterial3D.new()
	rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain_mat.albedo_color = Color(0.65, 0.82, 1.0, 0.58)
	rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	streak.material = rain_mat
	_rain.mesh = streak
	_rain.emitting = false
	add_child(_rain)

func _set_vehicle_lights(active: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_node_or_null(player_path) as Node3D
	if _player == null:
		return
	var visuals := _player.get_node_or_null("NganyaVisuals")
	if visuals != null and visuals.has_method("set_environment_lights"):
		visuals.call("set_environment_lights", active)

func set_quality_level(level: String) -> void:
	if _rain != null:
		_rain.amount = 45 if level == "PERFORMANCE" else 110
	if _sun != null:
		_sun.shadow_enabled = level != "PERFORMANCE"
