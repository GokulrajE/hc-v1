# SafeCrossing Game States & Trial Management

## Overview

The SafeCrossing game implements a **state machine architecture** with a 60-second trial duration. Game states control the flow from startup → gameplay → completion, while trial management handles data recording and session statistics.

---

## Game States Architecture

### State Enum (SCGameState)

```
WAITING    → Game ready, waiting for user to click START
↓
START      → Initializing trial, loading resources
↓
PLAYING    → Game actively running (countdown from 60 seconds)
├ → SUCCESS (optional) - Phase completed successfully
├ → FAILURE (optional) - Phase failed (collision)
└ → PAUSED  - User paused game (can resume to PLAYING)
↓
GAME_OVER  → 60 seconds elapsed, trial ended
↓
STOPPED    → Cleanup, returning to menu
```

### State Definitions

| State | Purpose | Duration | Actions |
|-------|---------|----------|---------|
| **WAITING** | Idle state, game ready | Until user input | Show "Press START" UI |
| **START** | Trial initialization | Instant | Reset stats, start AppDataTrial |
| **PLAYING** | Active gameplay | Up to 60 seconds | Track timer, process collisions, score |
| **SUCCESS** | Crossing completed | Instant | Play success animation, increment score |
| **FAILURE** | Collision occurred | Instant | Play failure animation, increment failures |
| **PAUSED** | Game paused by user | Until resume | Show pause menu, freeze time |
| **GAME_OVER** | Trial duration ended | Instant | Save trial data, show results |
| **STOPPED** | Cleanup | Instant | Return to menu scene |

---

## Trial Lifecycle (60 Seconds)

### Phase 1: Trial Start

```
User presses SPACEBAR in WAITING state
    ↓
_start_trial() called
    ├─ State: WAITING → START → PLAYING
    ├─ Reset statistics (_trial_targets, _trial_successes, _trial_failures)
    ├─ Reset timer: _trial_time_left = 60.0 seconds
    ├─ Start data recording: AppDataTrial.start_new_trial()
    │   └─ Creates raw data file: rawdata/{session}-{trial}.csv
    └─ _trial_is_running = true
```

**Code:**
```gdscript
func _start_trial() -> void:
    print("▶️ TRIAL STARTED")
    _game_state.enter_state(SCGameState.State.START)
    _reset_trial_stats()
    _trial_time_left = TRIAL_DURATION
    _trial_is_running = true

    # Start data logging
    AppDataTrial.start_new_trial(
        Appdata.current_session_number,
        1,  # Trial number
        "SafeCrossing"
    )

    _game_state.enter_state(SCGameState.State.PLAYING)
```

### Phase 2: Gameplay (0-60 seconds)

During PLAYING state, every physics frame:

```
_physics_process(delta):
    ├─ Check game state (only run if PLAYING)
    ├─ Decrement timer: _trial_time_left -= delta
    ├─ Track distance: _distance_traveled += speed * delta
    ├─ Update scroll position
    ├─ Check for crossing line intersections:
    │  ├─ Phase 2 (Pedestrians): Check collision_line Y position
    │  └─ Phase 3 (Traffic): Check collision_line Y position
    ├─ Detect collisions with pedestrians/traffic
    ├─ Update phase display with remaining time
    └─ Check if time expired: if _trial_time_left <= 0 → _end_trial()
```

**Timer Display:**
```
Time Remaining: 59.8s / 60.0s
```

### Phase 3: Crossing Detection

When a crossing line passes through the car:

```
_check_crossing_lines():
    ├─ Get car Y position
    ├─ Get collision line Y position
    ├─ Detect: _last_line_y < car_y AND line_y >= car_y
    │  ├─ YES (line moved from below car to above car):
    │  │  ├─ _trial_targets += 1
    │  │  ├─ If no collision: _trial_successes += 1, _add_score(1)
    │  │  └─ If collision: _trial_failures += 1
    │  └─ NO (crossing not complete):
    │     └─ Wait for next frame
    └─ Write frame data: AppDataTrial.write_frame_data()
```

**Example Output:**
```
⏱️ Trial: 15.3/60.0s | SCORE: 3 | SUCCESS: 3 | FAIL: 0
⏱️ Trial: 30.2/60.0s | SCORE: 6 | SUCCESS: 6 | FAIL: 1
⏱️ Trial: 45.1/60.0s | SCORE: 8 | SUCCESS: 8 | FAIL: 2
```

### Phase 4: Trial End (60 seconds elapsed)

```
When _trial_time_left <= 0:
    ↓
_end_trial() called
    ├─ _trial_is_running = false
    ├─ State: PLAYING → GAME_OVER
    ├─ Stop data recording: AppDataTrial.stop_trial()
    │  ├─ Parameters: targets, successes, failures
    │  ├─ Writes row to: sessions.csv
    │  │   SessionNumber,DateTime,...,SuccessRate,...
    │  │   1,20-05-2026 10:30:45,...,75.0,...
    │  └─ Flushes remaining raw data to file
    ├─ Calculate statistics:
    │  ├─ Success Rate = successes / targets * 100%
    │  ├─ Failure Rate = failures / targets * 100%
    │  └─ Score = successes
    └─ Show game over UI with results
```

**Code:**
```gdscript
func _end_trial() -> void:
    print("⏹️ TRIAL ENDED - Time's Up!")
    _trial_is_running = false
    _game_state.enter_state(SCGameState.State.GAME_OVER)

    # Save session data
    AppDataTrial.stop_trial(
        _trial_targets,
        _trial_successes,
        _trial_failures
    )
```

---

## Trial Statistics Tracking

### Variables Updated During Gameplay

```
_trial_targets:    Total crossing attempts (incremented on each crossing detection)
_trial_successes:  Successful crossings without collision
_trial_failures:   Failed crossings with collision
_player_score:     Points earned (same as successes)
_distance_traveled: Total scroll distance traveled
```

### Tracking Flow

```
Crossing Detected:
    ├─ _trial_targets += 1
    ├─ If collision:
    │  └─ _trial_failures += 1
    └─ If no collision:
       ├─ _trial_successes += 1
       ├─ _player_score += 1
       └─ AppDataTrial.write_frame_data()
```

### Example Session Statistics

```
===== GAME OVER RESULTS =====
Score: 8
Crossings: 8/10 successful
Success Rate: 80.0%
Time Played: 60.0s
Distance: 1234.5 pixels

Raw Data File:
  data/{hospital_id}/rawdata/raw-s1-t1-SafeCrossing.csv
  (3600+ sensor frames @ 60fps)

Session Data File:
  data/{hospital_id}/sessions/sessions.csv
  (One row added with all metrics)
```

---

## Data Recording & Persistence

### Trial Data Files Created

#### 1. Raw Sensor Data File
**Path:** `data/{hospital_id}/rawdata/raw-s{session}-t{trial}-{movement}.csv`

**Creation:** When `AppDataTrial.start_new_trial()` called

**Content:** All sensor data during 60-second trial
- Headers: `Timestamp,PacketNumber,Force1,Force2,Angle1-4,Distance1-2,Button1-7`
- Rows: One per device packet (~60 packets/second)
- Total rows: ~3600 packets for 60-second trial
- Size: ~100-150 KB per trial

**Example:**
```csv
Timestamp,PacketNumber,Force1,Force2,Angle1,Angle2,Angle3,Angle4,Distance1,Distance2,Button1,Button2,Button3,Button4,Button5,Button6,Button7
0.000,1,45.23,32.15,12.45,-8.90,-5.32,15.67,5.45,4.98,0,0,0,1,0,0,0
0.017,2,45.89,32.45,12.67,-8.75,-5.20,15.80,5.50,5.00,0,0,0,1,0,0,0
0.033,3,46.12,32.78,12.89,-8.60,-5.08,15.95,5.55,5.02,0,0,0,1,0,0,0
```

#### 2. Session Data Row (Appended to sessions.csv)
**Path:** `data/{hospital_id}/sessions/sessions.csv`

**Creation:** When `AppDataTrial.stop_trial()` called

**Content:** Single row with trial metadata and statistics
- Headers: `SessionNumber,DateTime,TrialNumberDay,TrialNumberSession,...,SuccessRate,RawDataFileName`
- Appended at end of existing sessions

**Example:**
```csv
1,20-05-2026 10:30:45,1,1,...,80.0,...,raw-s1-t1-SafeCrossing.csv
```

### Data Flow Diagram

```
User Presses START
    ↓
_start_trial()
    ├─ AppDataTrial.start_new_trial(session, trial, "SafeCrossing")
    │  └─ Creates: rawdata/raw-s1-t1-SafeCrossing.csv
    │     Headers: Timestamp,PacketNumber,Force1,...
    │     File is OPEN for writing
    ↓
60-second gameplay loop
    ├─ Each frame: _physics_process(delta)
    ├─ Crossing detected: _on_crossing_complete(is_success)
    │  ├─ _trial_targets += 1
    │  ├─ _trial_successes/failures += 1
    │  └─ AppDataTrial.write_frame_data()
    │     └─ Buffers current sensor frame to raw file
    ↓
Time expires: _trial_time_left <= 0
    ↓
_end_trial()
    ├─ AppDataTrial.stop_trial(_trial_targets, _trial_successes, _trial_failures)
    │  ├─ Closes raw data file
    │  ├─ Appends row to sessions.csv:
    │  │  SessionNumber=1
    │  │  DateTime=2026-05-20 10:30:45
    │  │  Targets=10
    │  │  Successes=8
    │  │  Failures=2
    │  │  SuccessRate=80.0
    │  └─ RawDataFileName=raw-s1-t1-SafeCrossing.csv
    ↓
AppData.trial_number_session incremented
User clicks "Retry" or "Return to Menu"
```

---

## State Transitions

### Complete State Machine Diagram

```
                    ┌─────────────┐
                    │   WAITING   │ ← Initial state
                    └──────┬──────┘
                           │ User presses SPACEBAR
                           ↓
                    ┌─────────────┐
                    │   START     │ Initialize trial
                    └──────┬──────┘
                           │ Immediately transition
                           ↓
        ┌──────────────────────────────────────┐
        │        PLAYING (0-60 seconds)        │
        │  ┌──────────────┐  ┌──────────────┐  │
        │  │   SUCCESS    │  │   FAILURE    │  │
        │  │ (instant)    │  │  (instant)   │  │
        │  └──────┬───────┘  └──────┬───────┘  │
        │         │                 │          │
        │         └────────┬────────┘          │
        │                  │                   │
        │              Loop back               │
        │          or PAUSED ↔ PLAYING        │
        └──────────────┬─────────────────────┘
                       │ 60 seconds elapsed
                       ↓
                ┌──────────────┐
                │  GAME_OVER   │ Save data
                └──────┬───────┘
                       │ User clicks "Back"
                       ↓
                ┌──────────────┐
                │   STOPPED    │ Return to menu
                └──────────────┘
```

### State Functions

| Transition | Method | Trigger |
|-----------|--------|---------|
| WAITING → START → PLAYING | `_start_trial()` | Spacebar press |
| PLAYING → PAUSED | `_toggle_pause()` | ESC press |
| PAUSED → PLAYING | `_toggle_pause()` | ESC press |
| PLAYING → GAME_OVER | `_end_trial()` | Timer reaches 0 |
| GAME_OVER → Main | `return_to_menu()` | Back button click |

---

## Integration with AppData & AppDataTrial

### AppData (User Context)
```gdscript
Appdata.current_session_number  # Current session (e.g., 1, 2, 3)
Appdata.user_data.hospital_id   # Patient ID (e.g., "H001")
```

### AppDataTrial (Trial Recording)
```gdscript
# Start recording
AppDataTrial.start_new_trial(
    session: int,          # Appdata.current_session_number
    trial: int,            # Trial number in session (1, 2, 3...)
    movement: String       # "SafeCrossing"
)

# Record each frame
AppDataTrial.write_frame_data()

# End recording & save session row
AppDataTrial.stop_trial(
    targets: int,          # _trial_targets
    successes: int,        # _trial_successes  
    failures: int          # _trial_failures
)

# Flush pending data (call before scene change)
AppDataTrial.flush_raw_data()
```

---

## Usage Example: Complete Trial Flow

```gdscript
# 1. Player launches game - state is WAITING
# UI shows: "Press SPACEBAR to Start"

# 2. Player presses SPACEBAR
# → _process() detects input → _start_trial() called
# → State: WAITING → START → PLAYING
# → AppDataTrial.start_new_trial() creates raw file

# 3. Game runs for 60 seconds
# → _physics_process(delta) runs every frame
# → Countdown: 59.9s, 59.8s, 59.7s...
# → Crossings detected, successes/failures tracked

# Frame 0: ⏱️ Trial: 0.0/60.0s | SCORE: 0 | SUCCESS: 0 | FAIL: 0
# Frame 900: ⏱️ Trial: 15.0/60.0s | SCORE: 3 | SUCCESS: 3 | FAIL: 1
# Frame 1800: ⏱️ Trial: 30.0/60.0s | SCORE: 6 | SUCCESS: 6 | FAIL: 2
# Frame 2700: ⏱️ Trial: 45.0/60.0s | SCORE: 8 | SUCCESS: 8 | FAIL: 2
# Frame 3600: ⏱️ Trial: 60.0/60.0s | SCORE: 8 | SUCCESS: 8 | FAIL: 2

# 4. Timer reaches 0 seconds
# → _trial_time_left <= 0
# → _end_trial() called
# → State: PLAYING → GAME_OVER

# 5. _end_trial() execution
# → AppDataTrial.stop_trial(10, 8, 2)
# → Raw file closed
# → Session row appended:
#    1,2026-05-20_10:30:45,1,1,...,80.0,...,raw-s1-t1-SafeCrossing.csv

# 6. Game over UI shows results
# 📊 GAME OVER RESULTS
# Score: 8
# Crossings: 8/10 successful
# Success Rate: 80.0%

# 7. Player clicks "Return to Menu"
# → return_to_menu() called
# → AppDataTrial.flush_raw_data() (safety)
# → Scene changes to main.tscn
# → State: GAME_OVER → STOPPED
```

---

## Debugging & Console Output

### Expected Console Output During Trial

```
▶️ TRIAL STARTED
🏁 Game starting...
🎮 Game playing...
📍 Phase 1: Empty Road
📍 Phase 2: Pedestrians Crossing
✅ PHASE 2 CROSSING DETECTED!
⭐ Pedestrians crossing completed safely! Score: 1
⏱️ Trial: 0.5/60.0s | SCROLL: 12 | PHASE: 2 | COLLIDED: false | SCORE: 1 | SUCCESS: 1 | FAIL: 0
...
⏱️ Trial: 59.9/60.0s | SCROLL: 1234 | PHASE: 3 | COLLIDED: false | SCORE: 8 | SUCCESS: 8 | FAIL: 2
⏹️ TRIAL ENDED - Time's Up!
💾 Trial data saved: Targets=10, Success=8, Failures=2
📊 GAME OVER SCREEN:
  Score: 8
  Crossings: 8/10 successful
  Success Rate: 80.0%
```

### Debugging Tips

1. **Check raw data file:**
   ```
   data/H001/rawdata/raw-s1-t1-SafeCrossing.csv
   Should have ~3600 rows (60 sec * 60 fps)
   ```

2. **Check session row:**
   ```
   data/H001/sessions/sessions.csv
   Last row should contain new trial metrics
   ```

3. **Check trial statistics:**
   ```
   print("Targets: %d" % _trial_targets)
   print("Success: %d" % _trial_successes)
   print("Failure: %d" % _trial_failures)
   print("Success Rate: %.1f%%" % ((_trial_successes / float(_trial_targets)) * 100.0))
   ```

---

## Summary

The SafeCrossing game implements:

✅ **Game States** - 8 states (WAITING, START, PLAYING, SUCCESS, FAILURE, PAUSED, GAME_OVER, STOPPED)
✅ **Trial Duration** - Fixed 60-second gameplay window
✅ **Automatic Data Recording** - AppDataTrial captures all sensor frames
✅ **Session Statistics** - Targets, successes, failures tracked automatically
✅ **Data Persistence** - Raw files + session rows saved to CSV
✅ **Timer Display** - Real-time countdown shown to player

Use this architecture as a template for other games!
