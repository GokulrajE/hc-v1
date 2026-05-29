class_name SCPauseMenu

extends CanvasLayer

@onready var pause_label = $PausePanel/VBoxContainer/PauseLabel
@onready var resume_button = $PausePanel/VBoxContainer/ResumeButton
@onready var menu_button = $PausePanel/VBoxContainer/MenuButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_resume_pressed() -> void:
	get_parent().resume_game()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scene/main.tscn")
