class_name SCGameState

extends Node

enum State {
	WAITING,      # Game not started, waiting for user to click START
	START,        # User clicked START, initialize trial
	PLAYING,      # Game is running, processing phases
	SUCCESS,      # Current phase completed successfully
	FAILURE,      # Current phase failed (collision)
	PAUSED,       # Game paused by user
	GAME_OVER,    # Trial duration ended (60 seconds)
	STOPPED       # Clean up and return to menu
}

var _current_state: State = State.WAITING
var _previous_state: State = State.WAITING
var _state_callbacks: Dictionary = {}

func _init() -> void:
	_state_callbacks = {
		State.WAITING: func(): pass,
		State.START: func(): pass,
		State.PLAYING: func(): pass,
		State.SUCCESS: func(): pass,
		State.FAILURE: func(): pass,
		State.PAUSED: func(): pass,
		State.GAME_OVER: func(): pass,
		State.STOPPED: func(): pass
	}

func enter_state(new_state: State) -> void:
	if _current_state != new_state:
		_previous_state = _current_state
		_on_state_exiting(_current_state)
		_current_state = new_state
		_on_state_entered(new_state)

func exit_state(state: State) -> void:
	_on_state_exited(state)

func get_current_state() -> State:
	return _current_state

func get_previous_state() -> State:
	return _previous_state

func is_state(state: State) -> bool:
	return _current_state == state

func is_playing() -> bool:
	return _current_state in [State.PLAYING, State.SUCCESS, State.FAILURE]

func set_state_callback(state: State, callback: Callable) -> void:
	if state in _state_callbacks:
		_state_callbacks[state] = callback

func _on_state_entered(state: State) -> void:
	print("🎮 Game State Changed: %s → %s" % [state_to_string(_previous_state), state_to_string(state)])
	match state:
		State.WAITING:
			SCGameManager.change_state("waiting")
		State.START:
			SCGameManager.change_state("start")
		State.PLAYING:
			SCGameManager.change_state("playing")
		State.SUCCESS:
			SCGameManager.change_state("success")
		State.FAILURE:
			SCGameManager.change_state("failure")
		State.PAUSED:
			SCGameManager.change_state("paused")
		State.GAME_OVER:
			SCGameManager.change_state("game_over")
		State.STOPPED:
			SCGameManager.change_state("stopped")

	if state in _state_callbacks:
		_state_callbacks[state].call()

func _on_state_exiting(_state: State) -> void:
	pass

func _on_state_exited(state: State) -> void:
	pass

func state_to_string(state: State = _current_state) -> String:
	match state:
		State.WAITING:
			return "WAITING"
		State.START:
			return "START"
		State.PLAYING:
			return "PLAYING"
		State.SUCCESS:
			return "SUCCESS"
		State.FAILURE:
			return "FAILURE"
		State.PAUSED:
			return "PAUSED"
		State.GAME_OVER:
			return "GAME_OVER"
		State.STOPPED:
			return "STOPPED"
		_:
			return "UNKNOWN"
