class_name CatchGameUI

extends CanvasLayer

@onready var score_label = $Control/ScoreLabel
@onready var timer_label = $Control/TimerLabel
@onready var start_board = $Control/StartBoard
@onready var hands_spread_bar = $Control/HandsSpreadBar
@onready var game_over_board = $Control/GameOverBoard
@onready var game_over_label = $Control/GameOverBoard/ContentVBox/GameOverLabel
@onready var results_label = $Control/GameOverBoard/ContentVBox/ResultsLabel
@onready var restart_button = $Control/GameOverBoard/ContentVBox/RestartButton
@onready var menu_button = $Control/GameOverBoard/ContentVBox/MenuButton
@onready var exit_button = $Control/ExitButton
@onready var success_popup = $SuccessPopup
@onready var failure_popup = $FailurePopup

var _popup_timer: float = 0.0
const POPUP_DURATION: float = 0.3

signal exit_pressed
signal restart_pressed


func _ready() -> void:
	game_over_board.visible = false
	exit_button.visible = false
	success_popup.visible = false
	failure_popup.visible = false

	score_label.text = "Score: 0"
	timer_label.text = "Time: 60.0s"

	restart_button.pressed.connect(func(): restart_pressed.emit())
	exit_button.pressed.connect(_on_exit_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


func _process(delta: float) -> void:
	# Update popup animations
	if _popup_timer > 0:
		_popup_timer -= delta
		var progress = 1.0 - (_popup_timer / POPUP_DURATION)

		# Scale and fade out
		var scale_amount = 1.0 + (1.0 - progress) * 0.3
		var alpha = 1.0 - progress

		if success_popup.visible:
			success_popup.scale = Vector2(scale_amount, scale_amount)
			success_popup.modulate.a = alpha
		elif failure_popup.visible:
			failure_popup.scale = Vector2(scale_amount, scale_amount)
			failure_popup.modulate.a = alpha
	else:
		success_popup.visible = false
		failure_popup.visible = false


func setup(duration: float) -> void:
	game_over_board.visible = false
	timer_label.text = "Time: %.1fs" % duration


func update_score(score: int) -> void:
	score_label.text = "Score: %d" % score
	score_label.self_modulate = Color.GREEN if score > 0 else Color.RED


func update_timer(time_left: float) -> void:
	timer_label.text = "⏱️ Time: %.1fs" % time_left

	# Color warnings
	if time_left <= 0:
		timer_label.self_modulate = Color.RED
	elif time_left < 10:
		timer_label.self_modulate = Color.YELLOW
	elif time_left < 30:
		timer_label.self_modulate = Color.ORANGE
	else:
		timer_label.self_modulate = Color.WHITE


func update_hands_spread(spread_ratio: float) -> void:
	# Update visual progress bar (0.0 to 1.0)
	if hands_spread_bar:
		hands_spread_bar.value = spread_ratio * 100.0


func show_success() -> void:
	success_popup.visible = true
	success_popup.modulate.a = 1.0
	success_popup.scale = Vector2(1.0, 1.0)
	_popup_timer = POPUP_DURATION


func show_failure() -> void:
	failure_popup.visible = true
	failure_popup.modulate.a = 1.0
	failure_popup.scale = Vector2(1.0, 1.0)
	_popup_timer = POPUP_DURATION


func show_playing() -> void:
	start_board.visible = false
	game_over_board.visible = false
	exit_button.visible = true


func show_game_over(score: int, caught: int, missed: int, avoided: int, caught_unwanted: int, success_rate: float) -> void:
	exit_button.visible = false
	game_over_board.visible = true
	game_over_label.text = "GAME OVER!"

	var results_text = (
		"Score: %d\n" +
		"✅ Caught: %d  |  ❌ Missed: %d\n" +
		"🟢 Dodged: %d  |  💥 Wrong: %d\n" +
		"Success Rate: %.1f%%"
	) % [score, caught, missed, avoided, caught_unwanted, success_rate]

	results_label.text = results_text
	restart_button.grab_focus()

	print("✅ Game Over Panel Shown")
	print("   Score: %d" % score)
	print("   Caught wanted: %d | Missed wanted: %d" % [caught, missed])
	print("   Dodged unwanted: %d | Caught unwanted: %d" % [avoided, caught_unwanted])
	print("   Success Rate: %.1f%%" % success_rate)


func _on_exit_pressed() -> void:
	exit_pressed.emit()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")
