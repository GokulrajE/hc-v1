class_name SCUI

extends CanvasLayer

@onready var score_label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var distance_label = $MarginContainer/VBoxContainer/DistanceLabel
@onready var speed_label = $MarginContainer/VBoxContainer/SpeedLabel
@onready var game_over_panel = $GameOverPanel
@onready var game_over_label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var final_score_label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var final_distance_label = $GameOverPanel/VBoxContainer/FinalDistanceLabel
@onready var restart_button = $GameOverPanel/VBoxContainer/RestartButton
@onready var menu_button = $GameOverPanel/VBoxContainer/MenuButton

var phase_label: Label
var signal_label: Label

func _ready() -> void:
	game_over_panel.visible = false

	SCGameManager.score_changed.connect(_on_score_changed)
	SCGameManager.distance_changed.connect(_on_distance_changed)
	SCGameManager.difficulty_increased.connect(_on_difficulty_increased)

	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	score_label.text = "Score: 0"
	distance_label.text = "Distance: 0m"
	speed_label.text = "Speed: 0"

func _process(delta: float) -> void:
	if not SCGameManager.is_paused:
		speed_label.text = "Speed: %d" % int(SCGameManager.game_speed)

func _on_score_changed(new_score: int) -> void:
	score_label.text = "Score: %d" % new_score

func _on_distance_changed(new_distance: int) -> void:
	distance_label.text = "Distance: %dm" % new_distance

func _on_difficulty_increased() -> void:
	print("Difficulty increased! Speed: %.0f, Spawn Rate: %.2f" % [SCGameManager.game_speed, SCGameManager.spawn_rate])

func show_game_over() -> void:
	game_over_panel.visible = true
	game_over_label.text = "GAME OVER!"
	final_score_label.text = "Score: %d" % SCGameManager.score
	final_distance_label.text = "Distance: %dm" % int(SCGameManager.distance)
	restart_button.grab_focus()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/main.tscn")

func update_phase_display(phase_name: String, time_remaining: float) -> void:
	if not phase_label:
		_create_phase_label()
	phase_label.text = "Phase: %s (%.1f s)" % [phase_name, time_remaining]

func update_signal_display(is_green: bool) -> void:
	if not signal_label:
		_create_signal_label()
	var signal_text = "🟢 GO" if is_green else "🔴 STOP"
	signal_label.text = signal_text

func _create_phase_label() -> void:
	phase_label = Label.new()
	phase_label.text = "Phase: Empty Road"
	$MarginContainer/VBoxContainer.add_child(phase_label)

func _create_signal_label() -> void:
	signal_label = Label.new()
	signal_label.text = "🟢 GO"
	$MarginContainer/VBoxContainer.add_child(signal_label)
