class_name CityAtmosphere
extends Node

@export var sun_path: NodePath
@export var environment_path: NodePath
@export var cycle_seconds := 180.0

var _phase := 0.22
var _manual_night := false
var _sun: DirectionalLight3D
var _world: WorldEnvironment

func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_world = get_node_or_null(environment_path) as WorldEnvironment

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_manual_night = not _manual_night
		_phase = 0.78 if _manual_night else 0.22

func _process(delta: float) -> void:
	if not _manual_night:
		_phase = fmod(_phase + delta / cycle_seconds, 1.0)
	if _sun == null or _world == null or _world.environment == null:
		return
	var daylight := clampf(sin(_phase * TAU) * 0.5 + 0.5, 0.08, 1.0)
	_sun.rotation_degrees.x = lerpf(-12.0, -62.0, daylight)
	_sun.light_energy = lerpf(0.12, 1.18, daylight)
	_sun.light_color = Color("ffb36b").lerp(Color("fff0d0"), daylight)
	var env := _world.environment
	env.ambient_light_energy = lerpf(0.22, 0.72, daylight)
	env.background_color = Color("07101f").lerp(Color("548bc2"), daylight)
	env.fog_light_energy = lerpf(0.08, 0.38, daylight)
