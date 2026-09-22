class_name GameSfx
extends Node

@export var corridor_service_path: NodePath
@export var player_path: NodePath

var _player: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _phase := 0.0
var _web_audio_started := false

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "GameSfxPlayer"
	_player.volume_db = -5.0
	add_child(_player)
	_engine = AudioStreamPlayer.new()
	_engine.name = "EngineAudio"
	_engine.volume_db = -18.0
	add_child(_engine)
	var service := get_node_or_null(corridor_service_path)
	if service != null:
		if service.has_signal("fare_awarded"):
			service.fare_awarded.connect(_on_fare_awarded)
		if service.has_signal("passenger_load_changed"):
			service.passenger_load_changed.connect(_on_passenger_load_changed)
		if service.has_signal("corridor_completed"):
			service.corridor_completed.connect(_on_corridor_completed)
	if OS.has_feature("web"):
		print("SFX: waiting for WebAudio user interaction")
	else:
		_play_engine_loop()

func _input(_event: InputEvent) -> void:
	# The generated 82 Hz loop sounds like a fault on Web and can mask music.
	# Web music is supplied by the native browser radio; keep this loop desktop-only.
	if OS.has_feature("web"):
		return

func _process(_delta: float) -> void:
	var vehicle := get_node_or_null(player_path)
	if vehicle != null and vehicle.has_method("get_speed_kph"):
		var speed := float(vehicle.call("get_speed_kph"))
		_engine.pitch_scale = clampf(0.75 + speed / 95.0, 0.75, 1.75)

func _tone(frequency: float, duration: float, volume: float = 0.35) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := maxi(1, int(duration * mix_rate))
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var fade := 1.0 - float(i) / float(frames)
		var sample := sin(TAU * frequency * float(i) / float(mix_rate)) * volume * fade
		var value := clampi(int(sample * 32767.0), -32768, 32767)
		bytes[i * 2] = value & 0xff
		bytes[i * 2 + 1] = (value >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _play_tone(frequency: float, duration: float, volume: float = 0.35) -> void:
	_player.stream = _tone(frequency, duration, volume)
	_player.play()

func _play_engine_loop() -> void:
	var wav := _tone(82.0, 0.8, 0.18)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(0.8 * wav.mix_rate)
	_engine.stream = wav
	_engine.play()
	if OS.has_feature("web"):
		_web_audio_started = _engine.playing

func _on_passenger_load_changed(_onboard: int, _capacity: int, boarded: int, alighted: int) -> void:
	if boarded > 0:
		_play_tone(620.0, 0.18, 0.42)
	elif alighted > 0:
		_play_tone(420.0, 0.16, 0.35)

func _on_fare_awarded(_amount: int, _balance: int) -> void:
	_play_tone(880.0, 0.22, 0.42)

func _on_corridor_completed(_name: String, _reward: int, _balance: int, _elapsed: float, _best: float, _new_best: bool, _fares: int, _passengers: int) -> void:
	_play_tone(1040.0, 0.35, 0.45)
