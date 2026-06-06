# SafeCrossing Game States - Quick Reference

## TL;DR - The Essentials

### Game States (8 Total)
```
WAITING → START → PLAYING → GAME_OVER → STOPPED
           ↓ (60 sec)    ↑
           └─ SUCCESS/FAILURE/PAUSED
```

### Trial Duration
- **Exactly 60 seconds** from START to GAME_OVER
- Timer countdown: `_trial_time_left -= delta`
- Triggers `_end_trial()` when time expires

### Starting a Trial
```gdscript
# User presses SPACEBAR
_start_trial()
├─ Reset stats: targets=0, successes=0, failures=0
├─ Start timer: 60.0 seconds
├─ Start recording: AppDataTrial.start_new_trial()
└─ State: WAITING → START → PLAYING
```

### During Gameplay
```gdscript
# Each frame (60 times per second)
_physics_process(delta):
├─ Decrement timer: _trial_time_left -= delta
├─ Check for crossings
├─ Track: targets, successes, failures
├─ Write sensor frame: AppDataTrial.write_frame_data()
└─ When timer <= 0: _end_trial()
```

### Ending a Trial
```gdscript
# When 60 seconds elapsed
_end_trial()
├─ Stop recording: AppDataTrial.stop_trial()
├─ Save session row to CSV
├─ State: PLAYING → GAME_OVER
└─ Show results: Score, Success Rate, etc.
```

### Data Files Created
1. **Raw sensor data:** `data/{id}/rawdata/raw-s1-t1-SafeCrossing.csv` (3600+ rows)
2. **Session row:** Appended to `data/{id}/sessions/sessions.csv` (1 row)

---

## State Machine Quick Lookup

| State | When | Duration | What Happens |
|-------|------|----------|--------------|
| **WAITING** | Game startup | Until user input | Show "Press START" |
| **START** | User clicks START | Instant | Initialize trial |
| **PLAYING** | Active gameplay | 0-60 seconds | Track time, score, collisions |
| **SUCCESS** | Crossing OK | Instant | Play success animation |
| **FAILURE** | Collision | Instant | Play failure animation |
| **PAUSED** | User pauses | Until resume | Freeze game state |
| **GAME_OVER** | Time expired | Instant | Save data, show results |
| **STOPPED** | Back button | Instant | Return to menu |

---

## 60-Second Trial Timeline

```
0s:   PLAYING starts
      ├─ _trial_is_running = true
      ├─ _trial_time_left = 60.0
      └─ AppDataTrial recording started

30s:  Halfway through
      ├─ _trial_time_left = 30.0
      ├─ Crossings detected & recorded
      └─ UI shows: "Time Remaining: 30.0/60.0s"

59s:  Almost done
      ├─ _trial_time_left = 1.0
      └─ Last few crossings being tracked

60s:  Time expired!
      ├─ _trial_time_left <= 0
      ├─ _end_trial() called
      ├─ PLAYING → GAME_OVER
      ├─ AppDataTrial.stop_trial() saves data
      └─ Results displayed
```

---

## Critical Functions

### _start_trial()
**Triggered by:** User pressing SPACEBAR in WAITING state
**Purpose:** Initialize new 60-second trial
**Actions:**
- Reset trial statistics
- Start 60-second countdown
- Create raw data file via AppDataTrial
- Transition to PLAYING state

### _end_trial()
**Triggered by:** Timer reaching 0 seconds
**Purpose:** Finalize trial, save data
**Actions:**
- Stop countdown timer
- Save session row via AppDataTrial
- Calculate success rate
- Transition to GAME_OVER state
- Display results

### _on_crossing_complete(is_success)
**Triggered by:** Crossing line detected
**Purpose:** Track crossing result, record frame
**Actions:**
- Increment _trial_targets
- Increment _trial_successes or _trial_failures
- Write sensor frame to raw data file

### AppDataTrial Integration
```gdscript
# Start recording
AppDataTrial.start_new_trial(session, trial, "SafeCrossing")
# Creates: data/{id}/rawdata/raw-s{s}-t{t}-SafeCrossing.csv

# Record each frame
AppDataTrial.write_frame_data()
# Appends: Timestamp,PacketNumber,Force1,Force2,...

# Stop recording & save session
AppDataTrial.stop_trial(targets, successes, failures)
# Appends: row to data/{id}/sessions/sessions.csv
```

---

## State Checking in Code

```gdscript
# Check specific state
if _game_state.is_state(SCGameState.State.PLAYING):
    # Game is actively running
    print("Running!")

# Check if game is in playable state (any active play state)
if _game_state.is_playing():
    # Game is PLAYING, SUCCESS, or FAILURE
    # Use this for general gameplay logic
    
# Get current state as string
var state_name = _game_state.state_to_string()
print("Current state: %s" % state_name)  # "PLAYING", "PAUSED", etc.

# Transition to new state
_game_state.enter_state(SCGameState.State.PAUSED)
```

---

## Trial Statistics at a Glance

```gdscript
# During 60-second trial
_trial_targets:    # How many crossings were attempted (increments on each detection)
_trial_successes:  # How many succeeded without collision
_trial_failures:   # How many failed with collision
_player_score:     # Points earned (same as successes)

# Example after 60 seconds:
# _trial_targets = 10    (10 crossing lines passed)
# _trial_successes = 8   (8 crossed safely)
# _trial_failures = 2    (2 had collisions)
# Success Rate = 8/10 * 100 = 80.0%
```

---

## Console Output Indicators

```
🎮  PLAYING      → Game started
⏱️  Trial: X/60s  → Elapsed time / total time
💥  Collision    → Collision detected
✅  Success      → Crossing completed safely
❌  Failed       → Crossing with collision
⏹️  TRIAL ENDED   → 60 seconds expired
💾  Saved        → Data written to CSV
📊  GAME OVER    → Results displayed
```

---

## File Paths Reference

### Raw Sensor Data File
```
data/{hospital_id}/rawdata/raw-s1-t1-SafeCrossing.csv
├─ Created at: _start_trial() via start_new_trial()
├─ Closed at: _end_trial() via stop_trial()
├─ Size: ~100-150 KB
└─ Rows: 3600+ (one per device packet)
```

### Session Data File
```
data/{hospital_id}/sessions/sessions.csv
├─ Updated at: _end_trial() via stop_trial()
├─ Operation: APPEND one row
├─ Contents: Session #, Targets, Success, Failure, Success Rate, etc.
└─ New rows: One per trial
```

---

## Common Issues & Solutions

### Issue: Data not saving
**Check:**
- [ ] AppDataTrial.start_new_trial() called in _start_trial()
- [ ] AppDataTrial.stop_trial() called in _end_trial()
- [ ] Hospital ID is set in Appdata
- [ ] data/ directory exists

**Fix:** Verify AppDataTrial.start_new_trial() is called before gameplay starts.

### Issue: Timer not counting down
**Check:**
- [ ] _trial_is_running = true in _start_trial()
- [ ] _physics_process() checks `if not _game_state.is_state(...) return`
- [ ] _trial_time_left -= delta is executing

**Fix:** Add debug print to verify _physics_process() is running:
```gdscript
func _physics_process(delta: float) -> void:
    if not _game_state.is_state(SCGameState.State.PLAYING):
        return
    if _trial_is_running:
        print("Timer: %.1f" % _trial_time_left)
        _trial_time_left -= delta
```

### Issue: Statistics not tracking correctly
**Check:**
- [ ] _trial_targets incremented when crossing detected
- [ ] _trial_successes incremented on safe crossing
- [ ] _trial_failures incremented on collision
- [ ] _on_crossing_complete() called with correct is_success value

**Fix:** Add debug output:
```gdscript
func _on_crossing_complete(is_success: bool) -> void:
    print("Crossing: %s | Targets: %d | Success: %d | Fail: %d" % [
        "OK" if is_success else "COLLISION",
        _trial_targets,
        _trial_successes,
        _trial_failures
    ])
```

---

## Extending to Other Games

To use this state machine in another game:

```gdscript
# 1. Copy state machine setup
var _game_state: SCGameState
func _ready():
    _game_state = SCGameState.new()
    _game_state.enter_state(SCGameState.State.WAITING)

# 2. Implement start
func _your_game_start() -> void:
    AppDataTrial.start_new_trial(Appdata.current_session_number, 1, "YourGame")
    _game_state.enter_state(SCGameState.State.PLAYING)

# 3. Track statistics during gameplay
func _your_event_occurs() -> void:
    _trial_targets += 1
    _trial_successes += 1
    AppDataTrial.write_frame_data()

# 4. Implement end
func _your_game_end() -> void:
    AppDataTrial.stop_trial(_trial_targets, _trial_successes, _trial_failures)
    _game_state.enter_state(SCGameState.State.GAME_OVER)
```

---

## Key Takeaways

1. **States control flow** - Game progresses through defined states (WAITING → PLAYING → GAME_OVER)

2. **60-second timer** - Every trial runs for exactly 60 seconds, automatically tracked

3. **Automatic data recording** - Sensor frames captured 60 times per second (~3600 frames per trial)

4. **Statistics tracked** - Targets, successes, failures collected during gameplay

5. **One-button lifecycle:**
   - START: `AppDataTrial.start_new_trial()`
   - END: `AppDataTrial.stop_trial()`

6. **Files created automatically** - Raw data + session row saved without manual intervention

---

## Reference: Complete Trial Flow

```
┌─────────────────────────────────────────────┐
│ 1. WAITING STATE                            │
│    Player sees "Press SPACEBAR to Start"   │
└─────────────────────┬───────────────────────┘
                      │
                      │ User presses SPACEBAR
                      ↓
┌─────────────────────────────────────────────┐
│ 2. _start_trial() EXECUTES                  │
│    ├─ _reset_trial_stats()                 │
│    ├─ _trial_time_left = 60.0              │
│    ├─ _trial_is_running = true             │
│    ├─ AppDataTrial.start_new_trial()       │
│    │   └─ Creates raw data file            │
│    └─ State: WAITING → START → PLAYING     │
└─────────────────────┬───────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────┐
│ 3. PLAYING STATE (60 seconds)               │
│    Each frame (_physics_process):          │
│    ├─ _trial_time_left -= delta            │
│    ├─ _check_crossing_lines()              │
│    ├─ _on_crossing_complete()              │
│    │   └─ AppDataTrial.write_frame_data()  │
│    └─ Update UI with time & score          │
│                                             │
│    Crossings detected:                     │
│    ├─ _trial_targets += 1                  │
│    ├─ If success: _trial_successes += 1    │
│    └─ If failure: _trial_failures += 1     │
└─────────────────────┬───────────────────────┘
                      │
                      │ After 60.0 seconds
                      │ _trial_time_left <= 0
                      ↓
┌─────────────────────────────────────────────┐
│ 4. _end_trial() EXECUTES                    │
│    ├─ _trial_is_running = false            │
│    ├─ AppDataTrial.stop_trial()            │
│    │   ├─ Closes raw data file             │
│    │   ├─ Appends row to sessions.csv      │
│    │   └─ Includes success rate: 80.0%     │
│    ├─ Calculate results                    │
│    ├─ State: PLAYING → GAME_OVER           │
│    └─ _show_game_over_screen()             │
└─────────────────────┬───────────────────────┘
                      │
                      ↓
┌─────────────────────────────────────────────┐
│ 5. GAME_OVER STATE                          │
│    Show Results:                            │
│    ├─ Score: 8                              │
│    ├─ Targets: 10                           │
│    ├─ Success Rate: 80.0%                   │
│    │                                         │
│    └─ [Retry] [Return to Menu]              │
└─────────────────────┬───────────────────────┘
                      │
                      │ User clicks button
                      ↓
        ┌──────────────────────────┐
        │ Return to Menu / Retry   │
        │ State: → STOPPED         │
        └──────────────────────────┘
```

---

## See Also

- 📄 [SAFECROSSING_GAME_STATES.md](SAFECROSSING_GAME_STATES.md) - Detailed architecture & data flow
- 📄 [SAFECROSSING_IMPLEMENTATION_GUIDE.md](SAFECROSSING_IMPLEMENTATION_GUIDE.md) - Code examples & patterns
- 📄 [UNITY_TO_GODOT_REFERENCE.md](UNITY_TO_GODOT_REFERENCE.md) - Unity vs Godot comparison

---

**Last Updated:** 2026-05-20
**Game:** SafeCrossing
**Trial Duration:** 60 seconds
**States:** 8 (WAITING, START, PLAYING, SUCCESS, FAILURE, PAUSED, GAME_OVER, STOPPED)
