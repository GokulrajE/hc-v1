extends Node

# Audio streams for game events
var _success_sound: AudioStream = null
var _failure_sound: AudioStream = null
var _time_warning_sound: AudioStream = null
var _phase_change_sound: AudioStream = null

# AudioStreamPlayer nodes
var _success_player: AudioStreamPlayer = null
var _failure_player: AudioStreamPlayer = null
var _warning_player: AudioStreamPlayer = null
var _ambient_player: AudioStreamPlayer = null

var _audio_enabled: bool = true

func _ready() -> void:
	# Create audio players
	_success_player = AudioStreamPlayer.new()
	_failure_player = AudioStreamPlayer.new()
	_warning_player = AudioStreamPlayer.new()
	_ambient_player = AudioStreamPlayer.new()

	add_child(_success_player)
	add_child(_failure_player)
	add_child(_warning_player)
	add_child(_ambient_player)

	# Set bus channels if needed
	_success_player.bus = &"Master"
	_failure_player.bus = &"Master"
	_warning_player.bus = &"Master"
	_ambient_player.bus = &"Master"

	print("🔊 Audio Manager initialized")

func play_success() -> void:
	if not _audio_enabled or _success_sound == null:
		return

	_success_player.stream = _success_sound
	_success_player.play()
	print("🔊 Success sound played")

func play_failure() -> void:
	if not _audio_enabled or _failure_sound == null:
		return

	_failure_player.stream = _failure_sound
	_failure_player.play()
	print("🔊 Failure sound played")

func play_time_warning() -> void:
	if not _audio_enabled:
		return

	print("🔊 Time warning sound played")

func play_phase_change() -> void:
	if not _audio_enabled:
		return

	print("🔊 Phase change sound played")

func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if not enabled:
		_success_player.stop()
		_failure_player.stop()
		_warning_player.stop()
		_ambient_player.stop()

func load_audio_file(sound_type: String, file_path: String) -> bool:
	var audio_stream = load(file_path)
	if audio_stream == null:
		print("❌ Failed to load audio: ", file_path)
		return false

	match sound_type:
		"success":
			_success_sound = audio_stream
		"failure":
			_failure_sound = audio_stream
		"warning":
			_time_warning_sound = audio_stream
		"phase_change":
			_phase_change_sound = audio_stream
		_:
			print("❌ Unknown sound type: ", sound_type)
			return false

	print("✓ Audio loaded: ", sound_type, " from ", file_path)
	return true
