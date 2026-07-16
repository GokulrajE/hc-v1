extends Control


func _ready() -> void:
	var g := Appdata.selected_game

	# Header labels
	($game_name_label as Label).text = g.name if g != null else ""
	var reach := (g.avg_reach_time + g.grip_reach_time) if g != null else 0.0
	($reach_note_label as Label).text = "Assessment reaching time: %.1f s" % reach

	($back_button as Button).pressed.connect(_on_back)

	if g == null or Appdata.target_game_scene == "":
		return

	_fill_card(g, "card_easy",   "easy")
	_fill_card(g, "card_normal", "normal")
	_fill_card(g, "card_hard",   "hard")

	for pair: Array in [["card_easy", "easy"], ["card_normal", "normal"], ["card_hard", "hard"]]:
		var btn := get_node_or_null(pair[0] + "/btn_select") as Button
		if btn:
			btn.pressed.connect(_on_select.bind(pair[1] as String))


func _fill_card(g: HyperCubeGame, card: String, diff: String) -> void:
	var speed  := g.get_speed_for(diff)
	var expect := g.get_expected_targets_for(diff)
	var reach  := g.avg_reach_time + g.grip_reach_time
	_set_label(card + "/row_targets/val_targets", str(expect))
	_set_label(card + "/row_window/val_window",   "%.1f s" % speed)
	_set_label(card + "/row_reach/val_reach",     "%.1f s" % reach)


func _set_label(path: String, value: String) -> void:
	var nd := get_node_or_null(path)
	if nd is Label:
		(nd as Label).text = value


func _on_select(difficulty: String) -> void:
	Appdata.selected_game.selected_difficulty = difficulty
	get_tree().change_scene_to_file(Appdata.target_game_scene)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scene/game_selection.tscn")
