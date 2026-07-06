extends Node2D

var back_button: Button
var message_label: Label

const CARD_W   : float = 550.0
const CARD_GAP : float = 70.0
const SCREEN_W : float = 1920.0
const SCREEN_H : float = 1080.0
const TITLE_H  : float = 90.0
const CARD_H   : float = 580.0

const CARD_KEYS := ["catch", "safe", "tw", "ht", "rnr", "juicer"]

const CARD_NODES_MAP := {
	"catch":  ["card_catch",  "category_catch",  "icon_catch",    "catch_desc",       "catch_game_button"],
	"safe":   ["card_safe",   "category_safe",   "icon_safe_car", "icon_safe_player", "safe_desc",   "safe_crossing_button"],
	"tw":     ["card_tw",     "category_tw",     "icon_tw",       "tw_desc",          "tw_game_button"],
	"ht":     ["card_ht",     "category_ht",     "icon_ht_hat",   "icon_ht_ball",     "ht_desc",     "ht_game_button"],
	"rnr":    ["card_rnr",    "category_rnr",    "icon_rnr",      "rnr_desc",         "rnr_game_button"],
	"juicer": ["card_juicer", "category_juicer", "icon_juicer",   "juicer_desc",      "juicer_game_button"],
}

var _orig_pos:  Dictionary = {}
var _orig_size: Dictionary = {}


func _ready() -> void:
	back_button   = get_node_or_null("back_button")
	message_label = get_node_or_null("message_label")

	_cache_positions()

	_connect_button("catch_game_button",    _on_catch_game_pressed)
	_connect_button("safe_crossing_button", _on_safe_crossing_pressed)
	_connect_button("tw_game_button",       _on_tw_game_pressed)
	_connect_button("ht_game_button",       _on_ht_game_pressed)
	_connect_button("rnr_game_button",      _on_rnr_game_pressed)
	_connect_button("juicer_game_button",   _on_juicer_game_pressed)
	_connect_button("sc3d_button",          _on_sc3d_pressed)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	_update_info()
	_update_game_visibility()


func _cache_positions() -> void:
	for nodes in CARD_NODES_MAP.values():
		for node_name: String in nodes:
			var nd = get_node_or_null(node_name)
			if nd:
				_orig_pos[node_name]  = nd.position
				_orig_size[node_name] = nd.size


func _connect_button(node_name: String, callable: Callable) -> void:
	var btn = get_node_or_null(node_name)
	if btn:
		btn.pressed.connect(callable)


func _update_game_visibility() -> void:
	var show_map := {
		"catch": false, "safe": false, "tw": false,
		"ht":    false, "rnr":  false, "juicer": false,
	}

	if Appdata.selected_mechanism != null:
		match Appdata.selected_mechanism.name:
			"KNOB", "FINE KNOB", "KEY KNOB":
				show_map["ht"] = true; show_map["tw"] = true; show_map["rnr"] = true
			"HANDLE", "GRIP":
				show_map["rnr"] = true; show_map["tw"] = true; show_map["juicer"] = true
			"TRIPOD":
				show_map["catch"] = true; show_map["ht"] = true; show_map["juicer"] = true
			"PINCH", "BUTTONS":
				show_map["rnr"] = true; show_map["safe"] = true; show_map["catch"] = true
			_:
				for key in show_map:
					show_map[key] = true

	# Hide all cards first
	for key in CARD_KEYS:
		for node_name: String in CARD_NODES_MAP[key]:
			var nd = get_node_or_null(node_name)
			if nd:
				nd.visible = false

	# Build ordered list of visible cards then show them in one centered row
	var visible: Array = []
	for key in CARD_KEYS:
		if show_map[key]:
			visible.append(key)

	_reposition_and_show(visible)

	var sc3d = get_node_or_null("sc3d_button")
	if sc3d:
		sc3d.visible = false


func _reposition_and_show(keys: Array) -> void:
	var n := keys.size()
	if n == 0:
		return

	var row_y   : float = TITLE_H + (SCREEN_H - TITLE_H - CARD_H) * 0.5
	var total_w : float = n * CARD_W + (n - 1) * CARD_GAP
	var start_x : float = (SCREEN_W - total_w) * 0.5

	for i in range(n):
		var key       : String  = keys[i]
		var card_name : String  = "card_" + key
		var orig_card : Vector2 = _orig_pos.get(card_name, Vector2.ZERO)
		var orig_csz  : Vector2 = _orig_size.get(card_name, Vector2(600.0, 462.0))
		var x_scale   : float   = CARD_W / maxf(orig_csz.x, 1.0)
		var y_scale   : float   = CARD_H / maxf(orig_csz.y, 1.0)
		var card_x    : float   = start_x + i * (CARD_W + CARD_GAP)

		for node_name: String in CARD_NODES_MAP[key]:
			var nd = get_node_or_null(node_name)
			if nd == null or not _orig_pos.has(node_name):
				continue
			var rel : Vector2 = _orig_pos[node_name] - orig_card
			var sz  : Vector2 = _orig_size.get(node_name, Vector2.ZERO)
			nd.position = Vector2(card_x + rel.x * x_scale, row_y + rel.y * y_scale)
			if sz != Vector2.ZERO:
				if nd is Button:
					(nd as Button).custom_minimum_size = Vector2.ZERO
				nd.size = Vector2(sz.x * x_scale, sz.y * y_scale)
			nd.visible = true
			# icon_ht_hat2 is a child of icon_ht_hat with fixed offsets — keep it
			# filling the parent exactly so it doesn't misalign when parent is scaled.
			if node_name == "icon_ht_hat":
				var hat2 := nd.get_node_or_null("icon_ht_hat2") as Control
				if hat2:
					hat2.position = Vector2.ZERO
					hat2.size     = nd.size


func _update_info() -> void:
	if message_label == null:
		return
	if Appdata.selected_mechanism == null:
		message_label.text = "No mechanism selected"
		return
	var mech = Appdata.selected_mechanism
	if mech.is_mechanism("Pinch") or mech.is_mechanism("Buttons"):
		message_label.text = "Mechanism: %s  |  No AROM required — Ready to play!" % mech.name
		return
	var arom = mech.get_current_arom()
	message_label.text = "Mechanism: %s  |  AROM Range: %.2f → %.2f" % [mech.name, arom[0], arom[1]]


func _on_catch_game_pressed() -> void:
	Appdata.set_game("Catch")
	get_tree().change_scene_to_file("res://scene/catch_game/catch_game.tscn")


func _on_safe_crossing_pressed() -> void:
	Appdata.set_game("Safe Crossing")
	get_tree().change_scene_to_file("res://scenes/safecrossing/sc_game.tscn")


func _on_tw_game_pressed() -> void:
	Appdata.set_game("Table Wipping")
	get_tree().change_scene_to_file("res://scene/tablewipping/tw_game.tscn")


func _on_ht_game_pressed() -> void:
	Appdata.set_game("Hat Trick")
	get_tree().change_scene_to_file("res://scene/hattrick/ht_game.tscn")


func _on_rnr_game_pressed() -> void:
	Appdata.set_game("Rain and Rise")
	get_tree().change_scene_to_file("res://scene/rainandrise/rnr_game.tscn")


func _on_sc3d_pressed() -> void:
	Appdata.set_game("Safe Crossing 3D")
	get_tree().change_scene_to_file("res://scene/safecrossing3D/sc3d_game.tscn")


func _on_juicer_game_pressed() -> void:
	Appdata.set_game("Juicer")
	get_tree().change_scene_to_file("res://scene/juicer/game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/mechanism.tscn")
