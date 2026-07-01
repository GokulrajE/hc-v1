class_name RNRUI
extends CanvasLayer

@onready var score_label:     Label       = $Control/ScoreLabel
@onready var timer_label:     Label       = $Control/TimerLabel
@onready var exit_button:     Button      = $Control/ExitButton
@onready var start_board:     TextureRect = $Control/StartBoard
@onready var game_over_board: TextureRect = $Control/GameOverBoard
@onready var results_label:   Label       = $Control/GameOverBoard/ContentVBox/ResultsLabel
@onready var restart_button:  Button      = $Control/GameOverBoard/ContentVBox/RestartButton
@onready var menu_button:     Button      = $Control/GameOverBoard/ContentVBox/MenuButton
@onready var success_popup:   Control     = $SuccessPopup
@onready var failure_popup:   Control     = $FailurePopup

func _ready() -> void:
	game_over_board.visible = false
	exit_button.visible     = true
	success_popup.visible   = false
	failure_popup.visible   = false

	restart_button.pressed.connect(func(): get_parent().restart_game())
	menu_button.pressed.connect(func():    get_parent().go_to_menu())
	exit_button.pressed.connect(func():    get_parent().exit_game())


# ============================================================
# SCREEN STATES
# ============================================================
func show_start() -> void:
	start_board.visible     = true
	game_over_board.visible = false
	exit_button.visible     = true


func show_playing() -> void:
	start_board.visible     = false
	game_over_board.visible = false
	exit_button.visible     = true


func show_game_over(score: int, targets: int, success: int, _failure: int) -> void:
	exit_button.visible     = false
	game_over_board.visible = true
	var rate := (float(success) / float(targets) * 100.0) if targets > 0 else 0.0
	results_label.text = (
		"Score: %d\n" +
		"Seeds Watered: %d / %d\n" +
		"Success Rate: %.1f%%"
	) % [score, success, targets, rate]
	restart_button.grab_focus()


# ============================================================
# VALUE UPDATES
# ============================================================
func update_score(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score


func update_timer(time_left: float) -> void:
	timer_label.text = "⏱️ Time: %.0fs" % maxf(time_left, 0.0)
	if time_left <= 10.0:
		timer_label.self_modulate = Color.RED
	elif time_left < 30.0:
		timer_label.self_modulate = Color.YELLOW
	else:
		timer_label.self_modulate = Color.WHITE


func show_success_popup() -> void:
	_show_popup(success_popup)


func show_failure_popup() -> void:
	_show_popup(failure_popup)


func _show_popup(popup: Control) -> void:
	popup.visible    = true
	popup.modulate.a = 0.0
	popup.scale      = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(popup, "scale", Vector2(1.12, 1.12), 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(popup, "modulate:a", 1.0, 0.15)
	tw.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.08) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.6)
	tw.tween_property(popup, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): popup.visible = false)
