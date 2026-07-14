# HC-V1 — HyperCube Rehabilitation Game Platform

Godot 4 project. Windows only. Device communicates over serial (COM15, 115200 baud). All scripts are GDScript 4.

---

## Autoloaders (project.godot)

| Name | File | Purpose |
|---|---|---|
| `Appdata` | `scripts/appdata.gd` | Global user/game/mechanism state |
| `HCcomm` | `scripts/hccomm.gd` | Serial device I/O and sensor parsing |
| `Datamanager` | `scripts/data_manager.gd` | CSV file persistence |
| `AppDataTrial` | `scripts/app_data_trial.gd` | Trial lifecycle + raw data logging |
| `ScAudioManager` | `scripts/sc_audio_manager.gd` | Global audio playback |

---

## Key Classes

### `AppData` (autoload `Appdata`)

```gdscript
const COM_PORT    = "COM15"
const BAUD_RATE   = 115200
const device_name = "HyperCube"

var user_data          : HyperCubeUserData    # set by initilize_user()
var selected_mechanism : HyperCubeMechanism   # set by set_mechanism()
var selected_game      : HyperCubeGame        # set by set_game()
var target_game_scene  : String = ""          # set by game_selection.gd before mode select
var current_session_number : int
var reassessing        : bool = false         # true when Ctrl+R reassessment from game_selection

func initilize_user(hospital_id)  # loads user data, computes session number
func set_mechanism(mech_name)     # creates HyperCubeMechanism
func set_game(game_name)          # creates HyperCubeGame
func show_achievement(score, successes, expected)  # spawns achievement_card.tscn on root
func initialize_connection(port)  # opens HCcomm serial port
```

`show_achievement()` instantiates `res://scene/achievement_card.tscn` and calls `card.setup(score, successes, expected, gname)`. All 6 game scripts call this after `ui.show_game_over()`.

---

### `HCComm` (autoload `HCcomm`)

Binary serial packet parser. Packet format: `[0xFF 0xFF] [size: 1b] [payload: Nb] [checksum: 1b]`

Sensor properties (populated after each valid packet):
```
force_1, force_2          — grip force values
angle_1..angle_4          — rotation angles
distance_1, distance_2    — IR distance sensors
button_1..button_7        — digital buttons
```

Key methods:
```gdscript
get_total_force() -> float          # force_1 + force_2
get_btw_distance() -> float         # 11.2 - (distance_1 + distance_2)
get_avg_btw_distance() -> float     # moving average of btw_distance (used for TRIPOD)
connect_device(port, baud)
disconnect_device()
```

Signals: `new_device_data`, `device_connected`, `device_disconnected`

**Disconnect detection**: physical Bluetooth disconnect can't be detected via `manager.is_open()`. A 2.5-second data-silence timeout (`DATA_TIMEOUT_SEC = 2.5`) calls `_do_disconnect()` automatically.

---

### `HyperCubeGame` (class, created by `Appdata.set_game()`)

Holds per-game configuration and adaptive difficulty timing.

```gdscript
var name: String               # "TABLE WIPPING", "HAT TRICK", etc.
var movement: String           # mechanism name (uppercase)
var selected_difficulty: String = "normal"   # set by mode_select.gd

# Adaptive timing (computed by compute_speed_mode_parameter() in _init)
var EASY_SPEED, NORMAL_SPEED, HARD_SPEED : float   # seconds per event
var expected_targets: int                           # mutated by set_expected_targets()

# Assessment-derived (populated from ROM in compute_speed_mode_parameter)
var angle_min, angle_max : float
var grip_threshold        : float
var avg_reach_time        : float
var grip_reach_time       : float

func get_speed_for(difficulty) -> float           # pure read, no side effects
func get_expected_targets_for(difficulty) -> int  # pure read, no side effects
func get_speed_mode_parameter(difficulty) -> float  # mutates expected_targets — use for game init only
```

`compute_speed_mode_parameter()` runs in `_init()` and reads ROM files to derive `angle_min/max`, `grip_threshold`, `avg_reach_time`, `grip_reach_time`, and the three speed tiers.

---

### `HyperCubeMechanism`

```gdscript
var name: String          # uppercase: "HANDLE", "GRIP", "KNOB", "FINE KNOB", "KEY KNOB", "TRIPOD", "PINCH", "BUTTONS"
var trial_number_day, trial_number_session : int
var new_rom, old_rom : ROM

func get_current_arom() -> Array    # [min, max]
func get_current_rom()  -> ROM
func set_new_arom_values(min, max, reaching_time)
func save_assessment_data() -> bool
func next_trial()
```

---

### `ROM`

Persists AROM values per mechanism to `data/{id}/rom/{MECHANISM}.csv`.

Format: `DateTime,AromMin,AromMax,ReachingTime`

```gdscript
func is_arom_set() -> bool
func write_to_assessment_file() -> bool
```

---

### `GameDefs` (`scripts/game_defs.gd`)

Inner classes holding all game constants — no `class_name`, accessed as `GameDefs.TableWipping.PLAY_LEFT` etc.

| Inner class | Key constants |
|---|---|
| `TableWipping` | `PLAY_LEFT/RIGHT/TOP/BOTTOM`, `CLOTH_WIDTH`, `STAIN_W/H`, `BRUSH_RX/RY`, `ALPHA_DECREMENT`, `ERASE_THRESHOLD`, `STAIN_TIMEOUT`, `GAME_DURATION`, `GLITTER_COUNT/DURATION`, `RESULT_DELAY`, `STAIN_PATHS[]` |
| `HatTrick` | `PLAY_LEFT/RIGHT`, `HAT_Y`, `HAT_HALF_W`, `BALL_SPEED`, `BALL_RADIUS`, `GAME_DURATION`, `RESULT_DELAY`, `SPAWN_DELAY` |
| `RainAndRise` | `PLAY_LEFT/RIGHT`, `CLOUD_Y`, `SEED_COUNT`, `HIGHLIGHT_DURATION`, `RAIN_TO_GROW`, `GAME_DURATION`, `RESULT_DELAY`, `SEED_XS[]` |
| `Juicer` | `FRUIT_COUNT`, `FRUIT_SPACING`, `TARGET_RADIUS`, `HIGHLIGHT_DURATION`, `JUICE_FILL_TIME`, `FORCE_THRESHOLD`, `TRIPOD_BAND`, `GAME_DURATION`, `RESULT_DELAY` |
| `Catch` | `GAME_DURATION`, `FALL_SPEED`, `SPAWN_DELAY`, `RESULT_DELAY`, `HAND_SPEED` |
| `SafeCrossing` | `TRIAL_DURATION`, `RESULT_DELAY`, `BASE_SPEED`, `PHASE_HEIGHT` |

---

### `DataStructure` (autoload `Datamanager`)

CSV file I/O. Data root: `res://data/` in debug, `{exe_path}_data/` in release.

```
data/{hospitalID}/
  configdata.csv         — user profile
  sessions/sessions.csv  — trial results
  rawdata/               — per-trial sensor CSVs + AROM assessment CSVs
  rom/                   — one CSV per mechanism with AROM history
  applog/, errorlog/
```

CSV headers:
- **CONFIG**: `DateTime, HospitalID, Name, Age, Location, AffectedLimb, PinchGrasp1, PinchGrasp2, Buttons`
- **SESSION**: `SessionNumber, DateTime, TrialNumberDay, TrialNumberSession, TrialStartTime, TrialStopTime, Mechanism, GameName, GameParameter, GameDuration, SuccessRate, CurrentTargets, CurrentHits, CurrentMisses, CumulativeTargets, CumulativeHits, CumulativeMisses, RawDataFileName`
- **RAW**: `Force1, Force2, Angle1-4, Distance1-2, Button1-7, GameState, PlayerX, PlayerY, TargetX, TargetY`

---

### `AppdataTrial` (autoload `AppDataTrial`)

Trial lifecycle: `start_new_trial()` → connects `HCcomm.new_device_data` → `write_frame_data()` buffers rows → `stop_trial()` flushes + writes session row + disconnects signal.

`set_game_context(state, px, py, tx, ty)` — called every `_physics_process` by game scripts to tag raw data rows with game state and positions.

AROM logging (separate from trial logging):
- `start_arom_raw_data_logging()` / `stop_arom_raw_data_logging()`
- Creates `rawdata/arom-{mechanism}-{datetime}.csv`

---

## Scene Flow

```
main.tscn
  ├─ signup.tscn          → creates user folder + configdata.csv
  └─ login.tscn           → Appdata.initilize_user() → mechanism.tscn

mechanism.tscn             → Appdata.set_mechanism() per button
  ├─ handle_assessment.tscn   (HANDLE)
  ├─ grip_assessment.tscn     (GRIP)
  ├─ knob_assessment.tscn     (KNOB / FINE KNOB / KEY KNOB)
  ├─ tripod_assessment.tscn   (TRIPOD)
  ├─ pinch_assessment.tscn    (PINCH)
  ├─ buttons_assessment.tscn  (BUTTONS)
  └─ game_selection.tscn  (after assessment saved)

game_selection.tscn        → Appdata.set_game() + target_game_scene → mode_select.tscn
  [Ctrl+R shortcut → reassessment for current mechanism]

mode_select.tscn           → sets selected_difficulty → target_game_scene

Games (all → game_selection.tscn after game over):
  scene/tablewipping/tw_game.tscn
  scene/hattrick/ht_game.tscn
  scene/rainandrise/rnr_game.tscn
  scene/juicer/game.tscn
  scene/catch_game/catch_game.tscn
  scenes/safecrossing/sc_game.tscn
  scene/safecrossing3D/sc3d_game.tscn   (no mode select — goes direct)

scene/achievement_card.tscn  (CanvasLayer layer=10, spawned on tree root after each game)
```

---

## Mechanism → Game Mapping

`game_selection.gd` filters visible game cards by mechanism:

| Mechanism | Games shown |
|---|---|
| KNOB / FINE KNOB / KEY KNOB | Hat Trick, Table Wiping, Rain and Rise |
| HANDLE / GRIP | Rain and Rise, Table Wiping, Juicer |
| TRIPOD | Catch, Hat Trick, Juicer |
| PINCH / BUTTONS | Rain and Rise, Safe Crossing, Catch |

Reassessment shortcut `Ctrl+R` from `game_selection.tscn` navigates to the correct assessment scene for the current mechanism and sets `Appdata.reassessing = true`. After save, returns to `game_selection.tscn`.

---

## Mode Select (`scene/mode_select.tscn` + `scripts/mode_select.gd`)

Shows Easy / Normal / Hard difficulty cards before launching any game. Cards display:
- Expected targets (`get_expected_targets_for(diff)`)
- Move window (`get_speed_for(diff)` in seconds)
- Assessment reaching time (`avg_reach_time + grip_reach_time`)

On SELECT: sets `Appdata.selected_game.selected_difficulty` then loads `Appdata.target_game_scene`.

Card styling: `StyleBoxFlat` with colored borders — green (Easy), orange (Normal), red (Hard).

---

## Achievement Card (`scene/achievement_card.tscn` + `scripts/achievement_card.gd`)

Spawned by `Appdata.show_achievement(score, successes, expected)` after every game ends.

- Animated progress bar fills from 0 → final percentage over 2.5 s (EASE_OUT, TRANS_CUBIC)
- Score counter animates 0 → final score in sync
- Stars activate at 30% / 60% / 90% thresholds (☆ → ⭐)
- "Continue" button → `game_selection.tscn`

Node paths for script:
`$card/game_lbl`, `$card/pct_lbl`, `$card/score_lbl`, `$card/bar_bg/bar_fill`, `$card/star1..3`, `$card/continue_btn`

---

## Game State Machine Pattern

All 6 games use the same enum pattern:

```
WAITING → START → [SPAWN/SPAWNBALL/SPAWNSEED] → MOVE → SUCCESS/FAILURE → [loop] → STOP → DONE
```

- `WAITING`: listens for `ui_select` to start
- `START`: calls `_initialize_game()` — resets counters, calls `AppDataTrial.start_new_trial()`
- `SPAWN`: spawns a target object
- `MOVE`: player interacts; transitions to SUCCESS/FAILURE
- `SUCCESS/FAILURE`: event delay timer, then back to SPAWN or STOP if time up
- `STOP`: calls `_end_game()` — `AppDataTrial.stop_trial()`, `ui.show_game_over()`, `Appdata.show_achievement()`
- `DONE`: navigation handled by UI buttons

Every `_physics_process` calls `AppdataTrial.set_game_context(state, player_x, player_y, target_x, target_y)`.

---

## Assessment Flow (3-step pattern)

Used by Handle, Knob, Tripod, Pinch assessments:

**Step 1** — Comfortable position / baseline capture. User presses START to lock start point.

**Step 2** — AROM measurement. User moves through full range. STOP or REDO button.

**Step 3** — Reaching validation. Timer 60 s. User must alternately reach min and max 5 times. When complete (or timer expires), SAVE button appears.

On SAVE: `AppDataTrial.stop_arom_raw_data_logging()` → `selected_mechanism.set_new_arom_values(min, max, time)` → `selected_mechanism.save_assessment_data()`.

Grip assessment differs: Step 1 = max force capture, Step 2 = 5× threshold (40% of max) repetitions.

---

## Device Sensor → Mechanism Mapping

| Mechanism | Primary sensor |
|---|---|
| HANDLE | `angle_1` |
| KNOB | `angle_2` |
| KEY KNOB | `angle_3` |
| FINE KNOB | `angle_4` |
| GRIP | `get_total_force()` |
| TRIPOD | `get_avg_btw_distance()` |
| PINCH | `button_1..4` (grasp buttons) |
| BUTTONS | `button_5..7` |

---

## Audio

`ScAudioManager` (autoload). Key methods used by games and assessments:
```gdscript
play_background_music(path)   # loops
stop_music()
play_gameover()
play_sc_success()             # table wipe stain cleared
play_tw_spray()               # spray sound
play_cg_success()             # catch/hattrick success
play_cg_miss()
play_asmnt_reach()            # assessment step reach feedback
play_asmnt_complete()
play_asmnt_btn()
```

---

## Visual Assets

- **UI theme**: `assets/fonts/TiltNeon-Regular-VariableFont_XROT,YROT.ttf`
- **Window background**: `assets/ui/Window04.png`
- **Buttons**: `Button13.png` (normal), `Button08.png` (hover/pressed)
- **Glitter stars**: `assets/tablewipping/glitter_star.png` — spawned as Sprite2D + tween (not GPUParticles2D)

---

## Data File Paths

```
data/{id}/configdata.csv
data/{id}/sessions/sessions.csv
data/{id}/rawdata/raw-s{session}-t{trial}-{mechanism}.csv
data/{id}/rawdata/arom-{mechanism}-{datetime}.csv
data/{id}/rom/{MECHANISM}.csv          e.g. HANDLE.csv, KNOB.csv
```

Raw file naming: `Datamanager.get_raw_filename(session, trial, mechanism_name)`

---

## Known Behaviors / Gotchas

- `selected_difficulty` defaults to `"normal"` on `HyperCubeGame`. Mode select always sets it before launching a game.
- `get_speed_mode_parameter()` on `HyperCubeGame` **mutates** `expected_targets` as a side effect. Use `get_speed_for()` / `get_expected_targets_for()` when you need read-only access (e.g. mode select cards).
- `HCcomm.manager.is_open()` stays `true` after physical Bluetooth disconnect — only data timeout detects real disconnect.
- Safe Crossing 3D (`sc3d_game.tscn`) skips mode select — `_on_sc3d_pressed()` calls `change_scene_to_file` directly.
- `Appdata.reassessing = true` is set when navigating to reassessment from game_selection via Ctrl+R. Assessment scenes check this flag on back/save to decide whether to return to `game_selection.tscn` or `mechanism.tscn`.
- `.tscn` Color literals require all 4 args: `Color(r, g, b, a)` — 3-arg form causes parse errors.
