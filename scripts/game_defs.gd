class TableWipping:
	const STAIN_PATHS: Array = [
		"res://assets/tablewipping/stainsblue.png",
		"res://assets/tablewipping/stainsbrown.png",
		"res://assets/tablewipping/stainssandel.png",
		"res://assets/tablewipping/redstain.png",
		"res://assets/tablewipping/whitestain.png",
	]
	const PLAY_LEFT         = 180.0
	const PLAY_RIGHT        = 1740.0
	const PLAY_TOP          = 180.0
	const PLAY_BOTTOM       = 820.0
	const CLOTH_SPEED       = 420.0
	const CLOTH_WIDTH       = 80.0
	const CLOTH_HEIGHT      = 50.0
	const STAIN_W           = 300
	const STAIN_H           = 220
	const BRUSH_RX          = 20
	const BRUSH_RY          = 110
	const ALPHA_DECREMENT   = 0.30
	const ERASE_THRESHOLD   = 0.98
	const CENTER_TOUCH_ZONE = 40.0
	const CENTER_DEAD_ZONE  = 5.0
	const MIN_STAIN_DIST    = 500.0
	const GAME_DURATION     = 60.0
	const GLITTER_COUNT     = 20
	const GLITTER_DURATION  = 1.6
	const STAIN_TIMEOUT     = 20.0
	const RESULT_DELAY      = 0.8

class Juicer:
	const FRUIT_COUNT        = 5
	const FRUIT_SPACING      = 280.0
	const TARGET_RADIUS      = 110.0
	const GAME_DURATION      = 60.0
	const HIGHLIGHT_DURATION = 7.0
	const JUICE_FILL_TIME    = 3.0
	const FORCE_THRESHOLD    = 5.0
	const TRIPOD_BAND        = 0.25
	const RESULT_DELAY       = 1.0
	const ARROW_SPEED_KB     = 600.0
	const ARROW_BASE_Y       = 50.0
	const ARROW_TIP_OFF      = 52.0

class Catch:
	const GAME_DURATION  = 60.0
	const FALL_SPEED     = 300.0   # default fallback; overridden by adaptive speed
	const SPAWN_DELAY    = 0.05
	const RESULT_DELAY   = 0.6
	const HAND_SPEED     = 500.0   # keyboard fallback px/s

class HatTrick:
	const PLAY_LEFT:  float = 150.0
	const PLAY_RIGHT: float = 1770.0
	const HAT_START_X: float = 960.0
	const HAT_Y:      float = 860.0
	const HAT_SPEED:  float = 700.0
	const HAT_HALF_W: float = 120.0

	const BALL_SPEED:  float = 380.0
	const BALL_RADIUS: float = 45.0

	const SPAWN_DELAY:   float = 0.05   # small gap after spawning before MOVE starts
	const RESULT_DELAY:  float = 0.6    # pause after catch/miss before next ball

	const GAME_DURATION: float = 60.0

	const BALL_SCALE: float = 0.7
	
	
class RainAndRise:
	const PLAY_LEFT         = 100.0
	const PLAY_RIGHT        = 1800.0
	const CLOUD_Y           = 150.0
	const CLOUD_SPEED       = 600.0
	const CLOUD_HALF_W      = 140.0
	const SEED_COUNT        = 5
	const SEED_Y            = 1000.0
	const SEED_HALF_W       = 60.0
	const CLOUD_SCALE       = 0.4
	const SEED_SCALE        = 0.25
	const RAIN_DROP_COUNT   = 100
	const RAIN_DROP_SPEED   = 500.0
	const GAME_DURATION     = 60.0
	const HIGHLIGHT_DURATION = 4.0
	const RAIN_TO_GROW      = 1.0
	const SPAWN_DELAY       = 0.05
	const RESULT_DELAY      = 0.6
	const EMOTION_INTERVAL  = 12.0
	const SEED_XS: PackedFloat64Array = [235.0, 558.0, 881.0, 1204.0, 1527.0]

class SafeCrossing:
	const TRIAL_DURATION = 60.0
	const RESULT_DELAY   = 0.8
	const BASE_SPEED     = 300.0   # default fallback scroll speed (px/s)
	const PHASE_HEIGHT   = 1080.0  # px per scroll phase — used to convert time → speed
