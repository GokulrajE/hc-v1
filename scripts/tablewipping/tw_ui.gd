class_name TWUI
extends CanvasLayer

@onready var score_label:       Label       = $Control/ScoreLabel
@onready var timer_label:       Label       = $Control/TimerLabel
@onready var wipe_bar:          ProgressBar = $Control/WipeBar
@onready var wipe_label:        Label       = $Control/WipeLabel
@onready var stain_timer_bar:   ProgressBar = $Control/StainTimerBar
@onready var stain_timer_label: Label       = $Control/StainTimerLabel
@onready var exit_button:       Button      = $Control/ExitButton
@onready var start_board:       TextureRect = $Control/StartBoard
@onready var game_over_board:   TextureRect = $Control/GameOverBoard
@onready var results_label:     Label       = $Control/GameOverBoard/ContentVBox/ResultsLabel
@onready var restart_button:    Button      = $Control/GameOverBoard/ContentVBox/RestartButton
@onready var menu_button:       Button      = $Control/GameOverBoard/ContentVBox/MenuButton
@onready var success_popup:     Control     = $SuccessPopup

func _ready() -> void:
	game_over_board.visible   = false
	exit_button.visible       = true
	success_popup.visible     = false
	stain_timer_bar.visible   = false
	stain_timer_label.visible = false

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


func show_game_over(score: int, targets: int, successes: int) -> void:
	exit_button.visible     = false
	game_over_board.visible = true

	var rate := (float(successes) / float(targets) * 100.0) if targets > 0 else 0.0
	results_label.text = (
		"Score: %d\n" +
		"Stains Cleaned: %d / %d\n" +
		"Success Rate: %.1f%%"
	) % [score, successes, targets, rate]

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


func update_progress(pct: float) -> void:
	wipe_bar.value    = pct * 100.0
	wipe_label.text   = "Wiped: %.0f%%" % (pct * 100.0)
	if pct >= 0.95:
		wipe_bar.self_modulate = Color.GREEN
	elif pct >= 0.5:
		wipe_bar.self_modulate = Color.YELLOW
	else:
		wipe_bar.self_modulate = Color.WHITE


func show_stain_timer(enabled: bool) -> void:
	stain_timer_bar.visible   = enabled
	stain_timer_label.visible = enabled


func update_stain_timer(time_remaining: float, time_total: float) -> void:
	var pct := clampf(time_remaining / time_total, 0.0, 1.0)
	stain_timer_bar.value    = pct * 100.0
	stain_timer_label.text   = "Stain Time: %.0fs" % maxf(time_remaining, 0.0)
	if pct > 0.5:
		stain_timer_bar.self_modulate = Color.WHITE
	elif pct > 0.25:
		stain_timer_bar.self_modulate = Color(1.0, 0.75, 0.1)
	else:
		stain_timer_bar.self_modulate = Color(1.0, 0.2, 0.2)


func show_success_popup(stain_top_center: Vector2 = Vector2(960.0, 540.0)) -> void:
	const PW := 260.0
	const PH := 60.0
	success_popup.position = Vector2(stain_top_center.x - PW * 0.5,
									 stain_top_center.y - PH - 12.0)
	# Vivid color + black outline
	var lbl := success_popup.get_child(0) as Label
	if lbl:
		lbl.add_theme_color_override("font_color", Color(0.0, 1.0, 0.35))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 6)

	# Burst in from tiny
	success_popup.visible    = true
	success_popup.modulate.a = 0.0
	success_popup.scale      = Vector2(0.05, 0.05)
	var tw := create_tween()
	tw.tween_property(success_popup, "scale", Vector2(1.7, 1.7), 0.22) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(success_popup, "modulate:a", 1.0, 0.15)
	tw.tween_property(success_popup, "scale", Vector2(1.0, 1.0), 0.14) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.9)
	tw.tween_property(success_popup, "modulate:a", 0.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): success_popup.visible = false)
