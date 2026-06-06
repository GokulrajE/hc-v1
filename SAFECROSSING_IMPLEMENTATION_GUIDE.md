# SafeCrossing Game Implementation Guide

## Quick Start: How States & Trial Management Work

### 1. Game States Overview

The game uses a **finite state machine (FSM)** with 8 states:

```gdscript
enum State {
    WAITING,     # Idle, waiting for user to start
    START,       # Initialization
    PLAYING,     # Active gameplay
    SUCCESS,     # Optional state for successful crossing
    FAILURE,     # Optional state for collision
    PAUSED,      # Game paused
    GAME_OVER,   # Trial time ended
    STOPPED      # Cleanup
}
```

### 2. Trial Duration: 60 Seconds

The trial runs for exactly 60 seconds from START until GAME_OVER:

```gdscript
const TRIAL_DURATION: float = 60.0

func _physics_process(delta: float) -> void:
    if not _game_state.is_state(SCGameState.State.PLAYING):
        return
    
    # Decrement timer each frame
    if _trial_is_running:
        _trial_time_left -= delta
        if _trial_time_left <= 0:
            _end_trial()  # Triggers GAME_OVER state
```

### 3. Starting a Trial

When user presses SPACEBAR in WAITING state:

```gdscript
func _start_trial() -> void:
    # Reset game statistics
    _reset_trial_stats()
    
    # Start timer
    _trial_time_left = TRIAL_DURATION
    _trial_is_running = true
    
    # Start data recording with AppDataTrial
    AppDataTrial.start_new_trial(
        Appdata.current_session_number,
        1,  # Trial number
        "SafeCrossing"
    )
    
    # Transition states
    _game_state.enter_state(SCGameState.State.START)
    _game_state.enter_state(SCGameState.State.PLAYING)
    print("🎮 PLAYING - 60 second trial started")
```

**What happens behind the scenes:**
- AppDataTrial creates a new raw data CSV file
- File path: `data/{hospital_id}/rawdata/raw-s1-t1-SafeCrossing.csv`
- Headers written: `Timestamp,PacketNumber,Force1,Force2,...`
- Ready to capture sensor data every frame

### 4. Tracking Crossings During Gameplay

```gdscript
# Called when a crossing line intersects the car
func _check_crossing_lines() -> void:
    # ... line intersection detection ...
    
    if crossing_detected:
        _trial_targets += 1  # Increment total attempts
        
        if _phase_collided:  # Hit a pedestrian/car
            _trial_failures += 1
            _on_crossing_complete(false)
        else:  # Successful crossing
            _trial_successes += 1
            _player_score += 1
            _on_crossing_complete(true)
        
        _has_scored_this_crossing = true

func _on_crossing_complete(is_success: bool) -> void:
    # Log this frame's sensor data
    AppDataTrial.write_frame_data()
    
    # Print status
    if is_success:
        print("✅ Success: %d/%d" % [_trial_successes, _trial_targets])
    else:
        print("❌ Failed: %d/%d" % [_trial_failures, _trial_targets])
```

### 5. Ending a Trial (60 seconds elapsed)

```gdscript
func _end_trial() -> void:
    print("⏹️ TRIAL ENDED - Time's Up!")
    _trial_is_running = false
    
    # Transition to GAME_OVER state
    _game_state.enter_state(SCGameState.State.GAME_OVER)
    
    # Stop data recording and save session row
    AppDataTrial.stop_trial(
        _trial_targets,      # Total crossings (e.g., 10)
        _trial_successes,    # Successful (e.g., 8)
        _trial_failures      # Failed (e.g., 2)
    )
    
    print("💾 Saved: %d targets, %d success, %d failures" % [
        _trial_targets, _trial_successes, _trial_failures
    ])
    
    # Show game over screen with results
    _show_game_over_screen()
```

**What happens behind the scenes:**
- AppDataTrial closes the raw data file
- Appends one row to `data/{hospital_id}/sessions/sessions.csv`:
  ```
  1,2026-05-20_10:30:45,1,1,...,80.0,...,raw-s1-t1-SafeCrossing.csv
  ```
- This row includes: session #, timestamp, targets, successes, failures, success rate
- Raw file now contains all 3600+ sensor frames from the 60-second trial

---

## Data Files Generated

### Raw Sensor Data File
**When created:** At `_start_trial()` via `AppDataTrial.start_new_trial()`
**When closed:** At `_end_trial()` via `AppDataTrial.stop_trial()`
**Path:** `data/{hospital_id}/rawdata/raw-s1-t1-SafeCrossing.csv`

**Contents (3600+ rows for 60-second trial):**
```csv
Timestamp,PacketNumber,Force1,Force2,Angle1,Angle2,Angle3,Angle4,Distance1,Distance2,Button1-7...
0.000,1,45.23,32.15,12.45,-8.90,-5.32,15.67,5.45,4.98,0,0,0,1,0,0,0
0.017,2,45.89,32.45,12.67,-8.75,-5.20,15.80,5.50,5.00,0,0,0,1,0,0,0
...
60.000,3600,47.56,34.12,14.23,-7.34,-4.67,16.89,5.78,5.12,0,0,0,1,0,0,0
```

**Size:** ~100-150 KB per trial

### Session Data Row
**When created:** At `_end_trial()` via `AppDataTrial.stop_trial()`
**Where appended:** `data/{hospital_id}/sessions/sessions.csv`

**Format:**
```csv
SessionNumber,DateTime,TrialNumberDay,TrialNumberSession,TrialStartTime,TrialStopTime,Movement,GameName,ReachSpeed,GameParameter,GameDuration,SuccessRate,MoveTime,CurrentTargets,CurrentHits,CurrentMisses,CumulativeTargets,CumulativeHits,CumulativeMisses,RawDataFileName

1,2026-05-20_10:30:45,1,1,0.00,60.00,SafeCrossing,SafeCrossing,1.0,0.0,60.00,80.0,58.5,10,8,2,10,8,2,raw-s1-t1-SafeCrossing.csv
```

---

## State Diagram

```
                     START GAME
                         ↓
    ┌────────────────────────────────────────┐
    │      Initial State: WAITING            │
    │   (Show "Press SPACEBAR to Start")     │
    └────────────────┬───────────────────────┘
                     │
                     │ SPACEBAR pressed
                     ↓
    ┌────────────────────────────────────────┐
    │      _start_trial() executes:          │
    │  • Reset statistics                    │
    │  • Start data recording                │
    │  • State: START → PLAYING              │
    └────────────────┬───────────────────────┘
                     │
                     ↓
    ┌────────────────────────────────────────┐
    │      PLAYING STATE (60 seconds)        │
    │  • Timer: 60.0 → 59.9 → ... → 0.0     │
    │  • Track crossings & collisions        │
    │  • Record sensor data each frame       │
    │  • Update UI with score & time         │
    │                                        │
    │  ┌──────────────────────────────────┐  │
    │  │ Optional States (instant):       │  │
    │  │  • SUCCESS (crossing OK)         │  │
    │  │  • FAILURE (collision)           │  │
    │  │  • PAUSED (user pauses)          │  │
    │  └──────────────────────────────────┘  │
    │                                        │
    │  Crossings detected → increment stats │
    │                                        │
    └────────────────┬───────────────────────┘
                     │
                     │ 60 seconds elapsed
                     │ _trial_time_left <= 0
                     ↓
    ┌────────────────────────────────────────┐
    │      _end_trial() executes:            │
    │  • Stop timer                          │
    │  • Save data: AppDataTrial.stop_trial()│
    │  • Close raw file                      │
    │  • Append session row to sessions.csv  │
    │  • Calculate success rate: 80.0%       │
    │  • State: PLAYING → GAME_OVER          │
    └────────────────┬───────────────────────┘
                     │
                     ↓
    ┌────────────────────────────────────────┐
    │      GAME_OVER STATE                   │
    │   (Show Results Screen)                │
    │   Score: 8                             │
    │   Targets: 10                          │
    │   Success: 80.0%                       │
    │                                        │
    │   [Retry] [Return to Menu]             │
    └────────────────┬───────────────────────┘
                     │
                     │ User clicks button
                     ↓
            ┌────────────────┐
            │ Return to Main │
            │   Scene (MENU) │
            └────────────────┘
```

---

## Key Variables & Their Purpose

```gdscript
# Timing
const TRIAL_DURATION: float = 60.0      # Total time per trial
var _trial_time_left: float             # Remaining time (decrements each frame)
var _trial_is_running: bool             # Whether timer is active

# Statistics
var _trial_targets: int = 0             # Total crossing attempts
var _trial_successes: int = 0           # Crossings without collision
var _trial_failures: int = 0            # Crossings with collision
var _player_score: int = 0              # Points earned (same as successes)

# Game State
var _game_state: SCGameState            # Current state machine
var _phase_collided: bool               # Whether current phase had collision
```

---

## State Checking in Code

```gdscript
# Check current state
if _game_state.is_state(SCGameState.State.PLAYING):
    # Game is actively running
    
if _game_state.is_state(SCGameState.State.PAUSED):
    # Game is paused
    
if _game_state.is_state(SCGameState.State.WAITING):
    # Waiting for user to start

# Check if game is actively playing (any game state)
if _game_state.is_playing():
    # Game is in one of: PLAYING, SUCCESS, FAILURE
    # Use this for logic that should run during active play
```

---

## Comparison with Unity Reference (DCGameController)

### Similarities

| Aspect | Unity | Godot SafeCrossing |
|--------|-------|-------------------|
| State Machine | `enum GameStates` | `enum State` |
| Total States | 10 states | 8 states |
| Timer Duration | 60 seconds | 60 seconds |
| Track Statistics | targets, success, failure | targets, successes, failures |
| Data Logging | `StartNewTrial()` → `StopTrial()` | `start_new_trial()` → `stop_trial()` |
| Session Row | Appended to CSV | Appended to sessions.csv |
| Raw Data File | Per-trial sensor log | Per-trial sensor log |

### Differences

| Aspect | Unity | Godot SafeCrossing |
|--------|-------|-------------------|
| Game Type | Catch diamonds | Navigate traffic |
| Target Detection | Physics collision | Line intersection |
| Success Condition | Hold diamond 0.5s | Cross line safely |
| Failure Condition | Diamond timeout | Collision detected |
| Additional States | SPAWNDIAMOND, WAITFORCATCH | (Implicit in crossing detection) |
| Speed Control | Game parameter | Base speed constant |
| Pause System | Button release | ESC key / explicit state |

---

## How to Extend: Custom Games

To create another game with the same state/trial system:

```gdscript
# 1. Copy the state machine concept
var _game_state: SCGameState
_game_state.enter_state(SCGameState.State.WAITING)

# 2. Implement START state behavior
func _start_trial() -> void:
    AppDataTrial.start_new_trial(
        Appdata.current_session_number,
        1,
        "YourGameName"
    )
    _game_state.enter_state(SCGameState.State.PLAYING)

# 3. Track your custom statistics during PLAYING
func your_event_detected():
    _trial_targets += 1
    _trial_successes += 1
    AppDataTrial.write_frame_data()

# 4. End trial when time expires
func _end_trial() -> void:
    AppDataTrial.stop_trial(
        _trial_targets,
        _trial_successes,
        _trial_failures
    )
    _game_state.enter_state(SCGameState.State.GAME_OVER)
```

---

## Debugging Checklist

- [ ] Raw data file created in `data/{id}/rawdata/`
- [ ] Raw file contains 3600+ sensor frames
- [ ] Session row appended to `data/{id}/sessions/sessions.csv`
- [ ] Success rate calculated correctly: `successes / targets * 100`
- [ ] Timer displays countdown from 60 to 0
- [ ] Statistics printed: Targets, Success, Failures
- [ ] Game over screen shows results
- [ ] Return to menu cleans up properly

---

## Summary

```
Game Lifecycle:
┌─────────────────────────────────────────────────────┐
│ WAITING                                             │
│ User presses START                                  │
│ ↓                                                   │
│ _start_trial() executes                            │
│   • Reset stats (targets=0, success=0, fail=0)    │
│   • Start timer (60.0 seconds)                     │
│   • Start recording: AppDataTrial.start_new_trial()│
│   • Enter PLAYING state                            │
│ ↓                                                   │
│ PLAYING (60 seconds)                               │
│   Each frame (_physics_process):                   │
│   • Decrement timer                                │
│   • Check for crossings                            │
│   • Update stats                                   │
│   • Write frame data                               │
│ ↓                                                   │
│ Timer reaches 0                                     │
│ _end_trial() executes                              │
│   • Stop recording: AppDataTrial.stop_trial()      │
│   • Save session row to CSV                        │
│   • Calculate success rate                         │
│   • Enter GAME_OVER state                          │
│ ↓                                                   │
│ GAME_OVER                                          │
│ Show results                                        │
│ User clicks "Return to Menu"                       │
│ ↓                                                   │
│ Back to WAITING for next trial                     │
└─────────────────────────────────────────────────────┘
```

Use this pattern for any game that needs:
- Timed gameplay
- Automatic data recording
- Session statistics
- Persistence to CSV
