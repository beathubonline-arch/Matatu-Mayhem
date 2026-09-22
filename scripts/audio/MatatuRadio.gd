class_name MatatuRadio
extends Node

signal station_changed(station_name: String, track_title: String, artist_name: String)
signal playback_state_changed(is_playing: bool)
signal radio_catalog_changed(message: String)

@export var station_name := "254 STREET RADIO"
@export var auto_play := true
@export_range(-40.0, 6.0, 0.5) var volume_db := -7.0

const RADIO_DIR := "res://audio/radio"
const MANIFEST_PATH := "res://audio/radio/catalog.json"
const RADIO_FILES := [
	"Buruklyn Boyz - 24.ogg",
	"Buruklyn Boyz - East Kwetu.ogg",
	"Mtu Mboka & Moti The NRG - Morio Wa Me.ogg",
	"NI GENJE - Stickman.ogg",
]

var _tracks: Array[Dictionary] = []
var _current_index := 0
var _last_index := -1
var _rng := RandomNumberGenerator.new()
var _player: AudioStreamPlayer
var _web_audio_started := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.name = "RadioPlayer"
	_player.volume_db = volume_db
	# Godot Web defaults to SAMPLE playback. Long-form 254 Street Radio music
	# must use Godot STREAM playback to avoid WebAudio sample-path failures.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_player.finished.connect(_play_next)
	_discover_tracks()
	print("RADIO: %d tracks loaded" % _tracks.size())
	print("RADIO: playback type STREAM (%d)" % _player.playback_type)
	if auto_play and not _tracks.is_empty():
		_current_index = _random_track_index()
		if OS.has_feature("web"):
			# WebAudio cannot start until a genuine browser user gesture.
			# Defer the first play() instead of making a blocked startup call.
			print("RADIO: waiting for WebAudio user interaction")
			_emit_metadata()
		else:
			_play_current()
	else:
		_emit_metadata()

func _input(event: InputEvent) -> void:
	if not OS.has_feature("web") or _tracks.is_empty():
		return
	var user_gesture := false
	if event is InputEventKey:
		user_gesture = event.pressed and not event.echo
	elif event is InputEventMouseButton:
		user_gesture = event.pressed
	elif event is InputEventScreenTouch:
		user_gesture = event.pressed
	if user_gesture:
		print("RADIO: WebAudio user interaction received")
		# N/M are handled by _unhandled_input(). Avoid starting one track here
		# and immediately replacing or stopping it in the same input event.
		if event.is_action_pressed("radio_next") or event.is_action_pressed("radio_toggle"):
			return
		# Browsers require WebAudio playback to begin inside a user gesture.
		# Retry on later gestures if the browser did not start playback.
		if not _web_audio_started or not _player.playing:
			_play_current()
			_web_audio_started = _player.playing
			print("RADIO: WebAudio started=%s" % str(_web_audio_started))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radio_next"):
		_play_next()
	elif event.is_action_pressed("radio_toggle"):
		toggle_radio()

func _discover_tracks() -> void:
	_tracks.clear()
	var manifest := _load_manifest()
	for filename in RADIO_FILES:
		var path := RADIO_DIR + "/" + filename
		if not ResourceLoader.exists(path):
			push_warning("254 Street Radio missing exported resource: " + path)
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("254 Street Radio could not load: " + path)
			continue
		var metadata: Dictionary = manifest.get(filename, {})
		if not metadata.is_empty() and not bool(metadata.get("licensed_for_game", false)):
			continue
		var display := filename.get_basename().replace("_", " ")
		var artist := str(metadata.get("artist", "BeatHub / 254"))
		var title := str(metadata.get("title", display))
		var split_at := display.find(" - ")
		if metadata.is_empty() and split_at > 0:
			artist = display.substr(0, split_at).strip_edges()
			title = display.substr(split_at + 3).strip_edges()
		_tracks.append({
			"stream": stream,
			"title": title,
			"artist": artist,
			"source": str(metadata.get("source", "BEATHUB / LICENSED 254")),
			"credit": str(metadata.get("credit", "")),
			"licensed": bool(metadata.get("licensed_for_game", false))
		})
	radio_catalog_changed.emit("254 STREET RADIO • %d LICENSED/LOCAL TRACKS READY" % _tracks.size())

func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("254 Street Radio catalog.json must be a dictionary keyed by audio filename.")
		return {}
	return parsed

func _play_current() -> void:
	if _tracks.is_empty():
		_emit_metadata()
		return
	_current_index = wrapi(_current_index, 0, _tracks.size())
	var track: Dictionary = _tracks[_current_index]
	print("RADIO: attempting %s - %s" % [str(track["artist"]), str(track["title"])])
	_player.stream = track["stream"]
	_player.play()
	if OS.has_feature("web"):
		_web_audio_started = _player.playing
	print("RADIO: play() called; playing=%s" % str(_player.playing))
	_emit_metadata()
	playback_state_changed.emit(true)

func _play_next() -> void:
	if _tracks.is_empty():
		_emit_metadata()
		return
	_current_index = _random_track_index()
	_play_current()

func _random_track_index() -> int:
	if _tracks.size() <= 1:
		_last_index = 0
		return 0
	var next_index := _rng.randi_range(0, _tracks.size() - 1)
	while next_index == _current_index or next_index == _last_index:
		next_index = _rng.randi_range(0, _tracks.size() - 1)
	_last_index = _current_index
	return next_index

func toggle_radio() -> void:
	if _tracks.is_empty():
		_emit_metadata()
		return
	if _player.playing:
		_player.stop()
		playback_state_changed.emit(false)
	else:
		_play_current()

func get_current_track() -> Dictionary:
	if _tracks.is_empty():
		return {}
	return _tracks[_current_index].duplicate()

func _emit_metadata() -> void:
	if _tracks.is_empty():
		station_changed.emit(station_name, "RADIO FILES NOT AVAILABLE", "CHECK WEB EXPORT")
		return
	var track: Dictionary = _tracks[_current_index]
	var artist := str(track["artist"])
	if str(track["credit"]) != "":
		artist += " • " + str(track["credit"])
	station_changed.emit(station_name, str(track["title"]), artist)
