class_name SCUI

extends CanvasLayer

@onready var score_label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var distance_label = $MarginContainer/VBoxContainer/DistanceLabel
@onready var speed_label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var phase_label = $MarginContainer/VBoxContainer/PhaseLabel
@onready var signal_label = $MarginContainer/VBoxContainer/SignalLabel
@onready var timer_label = $MarginContainer/VBoxContainer/TimerLabel
@onready var start_board = $StartBoard
@onready var exit_button = $ExitButton
@onready var game_over_board = $GameOverBoard
@onready var game_over_label = $GameOverBoard/ContentVBox/GameOverLabel
@onready var final_score_label = $GameOverBoard/ContentVBox/FinalScoreLabel
@onready var final_distance_label = $GameOverBoard/ContentVBox/FinalDistanceLabel
@onready var restart_button = $GameOverBoard/ContentVBox/RestartButton
@onready var menu_button = $GameOverBoard/ContentVBox/MenuButton
@onready var success_popup = $SuccessPopup
@onready var failure_popup = $FailurePopup
@onready var time_up_popup = $TimeUpPopup

var _score_feedback_timer: float = 0.0
var _score_feedback_duration: float = 0.4
var _popup_timer: float = 0.0
var _popup_duration: float = 0.8
var _original_score_color: Color
var _current_score: int = 0

func _ready() -> void:
	game_over_board.visible = false
	exit_button.visible = true
	start_board.visible = true

	# Hide labels not needed in this UI
	distance_label.visible = false
	speed_label.visible = false
	phase_label.visible = false
	signal_label.visible = false

	SCGameManager.score_changed.connect(_on_score_changed)
	SCGameManager.game_state_changed.connect(_on_game_state_changed_ui)

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	score_label.text = "Score: 0"
	timer_label.text = "⏱️ Time: 60.0s"

	_original_score_color = score_label.self_modulate

func _process(delta: float) -> void:
	if _score_feedback_timer > 0:
		_score_feedback_timer -= delta
		var progress = 1.0 - (_score_feedback_timer / _score_feedback_duration)
		var scale_amount = 1.0 + sin(progress * PI) * 0.3
		score_label.scale = Vector2(scale_amount, scale_amount)
		score_label.self_modulate = Color.YELLOW.lerp(_original_score_color, progress)
	else:
		score_label.scale = Vector2(1.0, 1.0)
		score_label.self_modulate = _original_score_color

	if _popup_timer > 0:
		_popup_timer -= delta
		var progress = 1.0 - (_popup_timer / _popup_duration)
		var scale_amount = 1.0 + (1.0 - progress) * 0.3
		var alpha = 1.0 - progress
		if success_popup.visible:
			success_popup.scale = Vector2(scale_amount, scale_amount)
			success_popup.modulate.a = alpha
		elif failure_popup.visible:
			failure_popup.scale = Vector2(scale_amount, scale_amount)
			failure_popup.modulate.a = alpha
		elif time_up_popup.visible:
			time_up_popup.scale = Vector2(scale_amount, scale_amount)
			time_up_popup.modulate.a = alpha
	else:
		success_popup.visible = false
		failure_popup.visible = false
		time_up_popup.visible = false

func _on_game_state_changed_ui(new_state: String) -> void:
	match new_state:
		"start", "playing", "success", "failure":
			start_board.visible = false
			exit_button.visible = true
			game_over_board.visible = false
		"game_over", "stopped":
			exit_button.visible = false
		"waiting":
			start_board.visible = true
			exit_button.visible = true

func _on_score_changed(new_score: int) -> void:
	_current_score = new_score
	score_label.text = "Score: %d" % new_score

func update_score_display(new_score: int) -> void:
	_current_score = new_score
	score_label.text = "Score: %d" % new_score
	show_score_popup()

func show_score_popup() -> void:
	_score_feedback_timer = _score_feedback_duration
	score_label.scale = Vector2(1.0, 1.0)
	score_label.self_modulate = Color.YELLOW
	show_success_popup()

func show_success_popup() -> void:
	success_popup.visible = true
	success_popup.modulate.a = 1.0
	success_popup.scale = Vector2(1.0, 1.0)
	_popup_timer = _popup_duration

func show_failure_popup() -> void:
	failure_popup.visible = true
	failure_popup.modulate.a = 1.0
	failure_popup.scale = Vector2(1.0, 1.0)
	_popup_timer = _popup_duration

func show_time_up_popup() -> void:
	time_up_popup.visible = true
	time_up_popup.modulate.a = 1.0
	time_up_popup.scale = Vector2(1.0, 1.0)
	_popup_timer = _popup_duration

func show_game_over(score: int = 0, targets: int = 0, successes: int = 0, failures: int = 0) -> void:
	exit_button.visible = false
	start_board.visible = false
	game_over_board.visible = true
	game_over_label.text = "GAME OVER!"

	var success_rate = (successes / float(targets) * 100.0) if targets > 0 else 0.0
	final_score_label.text = "Score: %d | Success: %d/%d (%.1f%%)" % [score, successes, targets, success_rate]
	final_distance_label.text = "Failures: %d" % failures
	restart_button.grab_focus()

func _on_exit_pressed() -> void:
	get_tree().paused = true
	show_game_over(_current_score, 0, 0, 0)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")

func update_timer_display(time_remaining: float) -> void:
	timer_label.text = "⏱️ Time: %.1fs" % time_remaining
	if time_remaining <= 0.0:
		timer_label.self_modulate = Color.RED
	elif time_remaining < 10.0:
		timer_label.self_modulate = Color.YELLOW
	elif time_remaining < 30.0:
		timer_label.self_modulate = Color.ORANGE
	else:
		timer_label.self_modulate = Color.WHITE

## Stub methods kept so sc_game.gd calls don't error
func update_phase_display(_phase_name: String, _time_remaining: float) -> void:
	pass

func update_signal_display(_is_green: bool) -> void:
	pass
