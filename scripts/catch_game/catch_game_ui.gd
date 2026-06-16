class_name CatchGameUI

extends CanvasLayer

@onready var score_label = $Control/ScoreLabel
@onready var timer_label = $Control/TimerLabel
@onready var instructions_label = $Control/InstructionsLabel
@onready var hands_spread_bar = $Control/HandsSpreadBar
@onready var game_over_panel = $Control/GameOverPanel
@onready var game_over_label = $Control/GameOverPanel/GameOverVBox/GameOverLabel
@onready var results_label = $Control/GameOverPanel/GameOverVBox/ResultsLabel
@onready var restart_button = $Control/GameOverPanel/GameOverVBox/RestartButton
@onready var success_popup = $SuccessPopup
@onready var failure_popup = $FailurePopup

var _popup_timer: float = 0.0
const POPUP_DURATION: float = 0.3


func _ready() -> void:
	game_over_panel.visible = false
	success_popup.visible = false
	failure_popup.visible = false

	# Initial display
	score_label.text = "Score: 0"
	timer_label.text = "Time: 60.0s"
	instructions_label.text = "Press SPACEBAR to Start\n➡️ RIGHT - Move Apart | ⬅️ LEFT - Join"


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
	game_over_panel.visible = false
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
	print("✅ Success popup shown")


func show_failure() -> void:
	failure_popup.visible = true
	failure_popup.modulate.a = 1.0
	failure_popup.scale = Vector2(1.0, 1.0)
	_popup_timer = POPUP_DURATION
	print("❌ Failure popup shown")


func show_playing() -> void:
	instructions_label.visible = false


func show_game_over(score: int, caught: int, missed: int, success_rate: float) -> void:
	game_over_panel.visible = true
	game_over_label.text = "GAME OVER!"

	var results_text = "Score: %d\nCaught: %d | Missed: %d\nSuccess Rate: %.1f%%" % [score, caught, missed, success_rate]

	results_label.text = results_text
	restart_button.grab_focus()

	print("✅ Game Over Panel Shown")
	print("   Score: %d" % score)
	print("   Caught: %d | Missed: %d" % [caught, missed])
	print("   Success Rate: %.1f%%" % success_rate)
