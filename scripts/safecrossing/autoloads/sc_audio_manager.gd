extends Node

var _sounds: Dictionary = {}
var _sfx_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _audio_enabled: bool = true

const _SOUND_PATHS: Dictionary = {
	"cg_success":  "res://assets/audio/success_cg.mp3",
	"cg_miss":     "res://assets/audio/failure_miss_cg.mp3",
	"cg_wrong":    "res://assets/audio/failure_wrong_cg.mp3",
	"sc_success":  "res://assets/audio/success_sc.mp3",
	"sc_failure":  "res://assets/audio/failure_sc.mp3",
	"gameover":    "res://assets/audio/gameover.mp3",
	"score":       "res://assets/audio/score.mp3",
	"tw_spray":    "res://assets/audio/spray.mp3",
	"rnr_success": "res://assets/audio/rnr_success.mp3",
}

func _ready() -> void:
	_sfx_player = AudioStreamPlayer.new()
	_music_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"Master"
	_music_player.bus = &"Master"
	add_child(_sfx_player)
	add_child(_music_player)

	for key in _SOUND_PATHS:
		var path: String = _SOUND_PATHS[key]
		if ResourceLoader.exists(path):
			_sounds[key] = load(path)
		else:
			push_warning("ScAudioManager: missing sound '%s' at %s" % [key, path])


func _play(key: String) -> void:
	if not _audio_enabled or not _sounds.has(key):
		return
	_sfx_player.stream = _sounds[key]
	_sfx_player.play()


## Catch Game
func play_cg_success() -> void:
	_play("cg_success")

func play_cg_miss() -> void:
	_play("cg_miss")

func play_cg_wrong() -> void:
	_play("cg_wrong")


## Safe Crossing
func play_sc_success() -> void:
	_play("sc_success")

func play_sc_failure() -> void:
	_play("sc_failure")


## Shared
func play_gameover() -> void:
	_play("gameover")

func play_score() -> void:
	_play("score")

func play_tw_spray() -> void:
	_play("tw_spray")

func play_rnr_success() -> void:
	_play("rnr_success")


## Background music
func play_background_music(path: String, loop: bool = true) -> void:
	if not _audio_enabled:
		return
	if not ResourceLoader.exists(path):
		push_warning("ScAudioManager: music not found at %s" % path)
		return
	var stream = load(path)
	if stream is AudioStreamMP3:
		stream.loop = loop
	elif stream is AudioStreamOggVorbis:
		stream.loop = loop
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func set_audio_enabled(enabled: bool) -> void:
	_audio_enabled = enabled
	if not enabled:
		_sfx_player.stop()
		_music_player.stop()
