class_name MatatuRadio
extends Node

signal station_changed(station_name: String, track_title: String, artist_name: String)
signal playback_state_changed(is_playing: bool)

@export var station_name := "254 STREET RADIO"
@export var auto_play := true
@export_range(-40.0, 6.0, 0.5) var volume_db := -7.0

var _tracks: Array[Dictionary] = []
var _current_index := 0
var _player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "RadioPlayer"
	_player.volume_db = volume_db
	add_child(_player)
	_player.finished.connect(_play_next)
	_discover_tracks()
	if auto_play and not _tracks.is_empty():
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
	# Only files deliberately added to this folder are played. This keeps the
	# game safe for licensed/original BeatHub submissions rather than bundled
	# commercial music without permission.
	var dir := DirAccess.open("res://audio/radio")
	if dir == null:
		return
	dir.list_dir_begin()
	var filename := dir.get_next()
	while filename != "":
		if not dir.current_is_dir():
			var lower := filename.to_lower()
			if lower.ends_with(".ogg") or lower.ends_with(".mp3") or lower.ends_with(".wav"):
				var stream := load("res://audio/radio/" + filename) as AudioStream
				if stream != null:
					var display := filename.get_basename().replace("_", " ")
					var artist := "BeatHub / 254"
					var title := display
					var split_at := display.find(" - ")
					if split_at > 0:
						artist = display.substr(0, split_at).strip_edges()
						title = display.substr(split_at + 3).strip_edges()
					_tracks.append({"stream": stream, "title": title, "artist": artist})
		filename = dir.get_next()
	dir.list_dir_end()

func _play_current() -> void:
	if _tracks.is_empty():
		_emit_metadata()
		return
	_current_index = wrapi(_current_index, 0, _tracks.size())
	_player.stream = _tracks[_current_index]["stream"]
	_player.play()
	_emit_metadata()
	playback_state_changed.emit(true)

func _play_next() -> void:
	if _tracks.is_empty():
		_emit_metadata()
		return
	_current_index = (_current_index + 1) % _tracks.size()
	_play_current()

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

func _emit_metadata() -> void:
	if _tracks.is_empty():
		station_changed.emit(station_name, "DROP LICENSED 254 TRACKS INTO audio/radio", "MATATU MAYHEM × BEATHUB")
		return
	var track: Dictionary = _tracks[_current_index]
	station_changed.emit(station_name, str(track["title"]), str(track["artist"]))
