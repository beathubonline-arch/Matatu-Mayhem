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

var _tracks: Array[Dictionary] = []
var _current_index := 0
var _last_index := -1
var _rng := RandomNumberGenerator.new()
var _player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_player = AudioStreamPlayer.new()
	_player.name = "RadioPlayer"
	_player.volume_db = volume_db
	add_child(_player)
	_player.finished.connect(_play_next)
	_discover_tracks()
	if auto_play and not _tracks.is_empty():
		_current_index = _random_track_index()
		_play_current()
	else:
		_emit_metadata()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("radio_next"):
		_play_next()
	elif event.is_action_pressed("radio_toggle"):
		toggle_radio()

func _discover_tracks() -> void:
	_tracks.clear()
	var manifest := _load_manifest()
	var dir := DirAccess.open(RADIO_DIR)
	if dir == null:
		radio_catalog_changed.emit("254 STREET RADIO • NO AUDIO FOLDER")
		return
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir():
			var lower := filename.to_lower()
			if lower.ends_with(".ogg") or lower.ends_with(".mp3") or lower.ends_with(".wav"):
				var stream := load(RADIO_DIR + "/" + filename) as AudioStream
				if stream != null:
					var metadata: Dictionary = manifest.get(filename, {})
					if not metadata.is_empty() and not bool(metadata.get("licensed_for_game", false)):
						filename = dir.get_next()
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
		filename = dir.get_next()
	dir.list_dir_end()
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
	_player.stream = track["stream"]
	_player.play()
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
		_player.play()
		playback_state_changed.emit(true)

func get_current_track() -> Dictionary:
	if _tracks.is_empty():
		return {}
	return _tracks[_current_index].duplicate()

func _emit_metadata() -> void:
	if _tracks.is_empty():
		station_changed.emit(station_name, "BEATHUB 254 SUBMISSIONS OPEN", "ADD LICENSED KENYAN MUSIC")
		return
	var track: Dictionary = _tracks[_current_index]
	var artist := str(track["artist"])
	if str(track["credit"]) != "":
		artist += " • " + str(track["credit"])
	station_changed.emit(station_name, str(track["title"]), artist)
