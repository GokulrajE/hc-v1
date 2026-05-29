class_name SCGameState

extends Node

enum State {
	MENU,
	PLAYING,
	PAUSED,
	GAME_OVER
}

var _current_state: State = State.MENU
var _state_callbacks: Dictionary = {}

func _init() -> void:
	_state_callbacks = {
		State.MENU: func(): pass,
		State.PLAYING: func(): pass,
		State.PAUSED: func(): pass,
		State.GAME_OVER: func(): pass
	}

func enter_state(new_state: State) -> void:
	if _current_state != new_state:
		exit_state(_current_state)
		_current_state = new_state
		_on_state_entered(new_state)

func exit_state(state: State) -> void:
	_on_state_exited(state)

func get_current_state() -> State:
	return _current_state

func is_state(state: State) -> bool:
	return _current_state == state

func set_state_callback(state: State, callback: Callable) -> void:
	if state in _state_callbacks:
		_state_callbacks[state] = callback

func _on_state_entered(state: State) -> void:
	match state:
		State.MENU:
			SCGameManager.change_state("menu")
		State.PLAYING:
			SCGameManager.change_state("playing")
		State.PAUSED:
			SCGameManager.change_state("paused")
		State.GAME_OVER:
			SCGameManager.change_state("game_over")

	if state in _state_callbacks:
		_state_callbacks[state].call()

func _on_state_exited(state: State) -> void:
	pass

func state_to_string() -> String:
	match _current_state:
		State.MENU:
			return "menu"
		State.PLAYING:
			return "playing"
		State.PAUSED:
			return "paused"
		State.GAME_OVER:
			return "game_over"
		_:
			return "unknown"
