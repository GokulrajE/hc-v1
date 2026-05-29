class_name SCTrafficSignal
extends Node2D

signal signal_changed(is_green: bool)

var is_green: bool = true
var cycle_time: float = 4.0
var green_duration: float = 2.0
var red_duration: float = 2.0
var timer: float = 0.0

func _ready() -> void:
	timer = green_duration
	signal_changed.emit(is_green)

func _process(delta: float) -> void:
	timer -= delta

	if timer <= 0:
		toggle_signal()

func toggle_signal() -> void:
	is_green = !is_green
	timer = green_duration if is_green else red_duration
	signal_changed.emit(is_green)

func get_signal_color() -> Color:
	return Color.GREEN if is_green else Color.RED

func get_signal_text() -> String:
	return "🟢 GO" if is_green else "🔴 STOP"
