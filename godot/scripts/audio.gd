extends Node
## UI sounds and (later) menu music.
##
## Sounds are played through a small pool of players so overlapping moves do
## not cut each other off. Everything respects the Settings values live.

const SOUND_DIR := "res://sounds/"
const POOL_SIZE := 6

## name -> file, pitch jitter
const SOUNDS := {
	"move": "move.wav",
	"select": "select.wav",
	"back": "back.wav",
	"folder": "folder.wav",
	"insert": "insert.wav",
}

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		var path: String = SOUND_DIR + SOUNDS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)
	Settings.changed.connect(_on_settings_changed)


func play(sound: String, pitch_jitter: float = 0.0) -> void:
	if not bool(Settings.get_value("sounds_enabled")):
		return
	if not _streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[sound]
	p.volume_db = float(Settings.get_value("sound_volume_db"))
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func play_music(path: String = "") -> void:
	if not bool(Settings.get_value("music_enabled")):
		return
	var stream: AudioStream = null
	if not path.is_empty() and FileAccess.file_exists(path):
		# User-supplied track from user://music/. Bundled tracks land in v0.6.
		stream = AudioStreamOggVorbis.load_from_file(path) if path.ends_with(".ogg") else null
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = float(Settings.get_value("music_volume_db"))
	_music.play()


## Fades the music out — used when a game launches.
func fade_out_music(duration: float = 0.6) -> void:
	if not _music.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music, "volume_db", -60.0, duration)
	tween.tween_callback(_music.stop)


func _on_settings_changed(key: String) -> void:
	if key == "music_volume_db" and _music.playing:
		_music.volume_db = float(Settings.get_value("music_volume_db"))
	elif key == "music_enabled" and not bool(Settings.get_value("music_enabled")):
		_music.stop()
