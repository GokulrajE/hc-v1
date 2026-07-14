class_name AchievementCard
extends CanvasLayer

const ANIM_DURATION := 2.5
const HOLD_DURATION := 1.5
const BAR_W         := 640.0
const THRESHOLDS    := [0.30, 0.60, 0.90]

@onready var _game_lbl     := $card/game_lbl     as Label
@onready var _pct_lbl      := $card/pct_lbl      as Label
@onready var _score_lbl    := $card/score_lbl    as Label
@onready var _bar_fill     := $card/bar_bg/bar_fill as ColorRect
@onready var _stars        := [
	$card/star1 as Label,
	$card/star2 as Label,
	$card/star3 as Label,
]

signal finished

var _final_score : int   = 0
var _expected    : int   = 1
var _final_pct   : float = 0.0
var _star_count  : int   = 0


func setup(score: int, successes: int, expected: int, gname: String) -> void:
	_final_score = score
	_expected    = maxi(expected, 1)
	_final_pct   = minf(float(successes) / float(_expected), 1.0) * 100.0
	_game_lbl.text = gname
	_reset()
	_animate()


func _reset() -> void:
	_bar_fill.size = Vector2(0.0, _bar_fill.size.y)
	_pct_lbl.text   = "0%"
	_score_lbl.text = "Score: 0"
	for s: Label in _stars:
		s.text = "☆"
	_star_count = 0


func _animate() -> void:
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(_on_tick, 0.0, 100.0, ANIM_DURATION)
	tw.tween_interval(HOLD_DURATION)
	tw.tween_callback(_close)


func _on_tick(t: float) -> void:
	var pct: float = minf(t / 100.0, 1.0) * _final_pct
	_bar_fill.size = Vector2(BAR_W * pct / 100.0, _bar_fill.size.y)
	_pct_lbl.text   = "%d%%" % int(pct)
	var cur: int = int(float(_final_score) * pct / _final_pct) if _final_pct > 0.0 else _final_score
	_score_lbl.text = "Score: %d" % cur

	var earned := 0
	for thr: float in THRESHOLDS:
		if pct / 100.0 >= thr:
			earned += 1
	if earned != _star_count:
		_star_count = earned
		for i in 3:
			(_stars[i] as Label).text = "⭐" if i < earned else "☆"


func _close() -> void:
	finished.emit()
	queue_free()
