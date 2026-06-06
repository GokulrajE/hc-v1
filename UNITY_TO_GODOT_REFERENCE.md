# Unity to Godot: DCGameController → SafeCrossing Game States

## Overview

This guide maps the Unity `DCGameController.cs` state machine to the Godot SafeCrossing implementation, showing how concepts translate between frameworks.

---

## State Machine Comparison

### Unity States (DCGameController)

```csharp
enum GameStates {
    WAITING = 0,      // No user input yet
    START,            // Initialize game
    STOP,             // Game duration ended
    PAUSED,           // User paused
    SPAWNDIAMOND,     // Create next target (diamond catcher specific)
    WAITFORCATCH,     // Waiting for player to reach target
    PLAYERIN,         // Player entered target area
    PLAYEREXIT,       // Player left target area
    SUCCESS,          // Target successfully caught
    FAILURE,          // Target timeout, failed catch
    DONE              // Cleanup complete
}
```

### Godot SafeCrossing States

```gdscript
enum State {
    WAITING,          // Idle, waiting for user to start
    START,            // Initialization
    PLAYING,          // Active gameplay (combines multiple Unity states)
    SUCCESS,          // Crossing succeeded (optional state)
    FAILURE,          // Collision occurred (optional state)
    PAUSED,           // Game paused
    GAME_OVER,        // Trial duration ended
    STOPPED           // Return to menu
}
```

### State Mapping

| Unity State | Purpose | Godot Equivalent |
|------------|---------|------------------|
| WAITING | Idle, ready for input | WAITING |
| START | Initialize game | START |
| SPAWNDIAMOND | Create next objective | (Implicit in PLAYING) |
| WAITFORCATCH | Wait for player action | PLAYING |
| PLAYERIN/PLAYEREXIT | Player position tracking | (Implicit in PLAYING) |
| SUCCESS | Achievement | SUCCESS (optional state) |
| FAILURE | Failure condition met | FAILURE (optional state) |
| PAUSED | Game paused | PAUSED |
| STOP | Time ended | GAME_OVER |
| DONE | Cleanup | STOPPED |

---

## Lifecycle Comparison

### Unity Diamond Catcher

```csharp
// Initialization
void Start() {
    gameState = GameStates.WAITING;
    gameTimeLeft = gameDuration;  // gameDuration = 60f
}

// Main state machine loop in FixedUpdate()
void RunStateMachine() {
    switch (gameState) {
        case GameStates.WAITING:
            if (isGameStarted) gameState = GameStates.START;
            break;
        
        case GameStates.START:
            startGame();
            gameState = GameStates.SPAWNDIAMOND;
            break;
        
        case GameStates.SPAWNDIAMOND:
            // Spawn diamond at random position
            // Set reachDuration based on game speed
            nTargets++;
            break;
        
        case GameStates.WAITFORCATCH:
            reachTimeLeft -= Time.deltaTime;
            if (reachTimeLeft <= 0f) {
                nFailure++;
                gameState = GameStates.FAILURE;
            }
            break;
        
        case GameStates.SUCCESS:
        case GameStates.FAILURE:
            eventDelayTimer -= Time.deltaTime;
            if (eventDelayTimer <= 0f) {
                gameState = isTimeUp ? GameStates.STOP : GameStates.SPAWNDIAMOND;
            }
            break;
        
        case GameStates.STOP:
            gameOver();
            break;
    }
    
    // Timer countdown
    if (isGamePlaying && !isTimeUp) {
        gameTimeLeft -= Time.deltaTime;
    }
}

// Game start
void startGame() {
    gameTimeLeft = gameDuration;  // 60 seconds
    nTargets = 0;
    nSuccess = 0;
    nFailure = 0;
    AppData.Instance.StartNewTrial();
}

// Game end
void gameOver() {
    AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);
}
```

### Godot SafeCrossing

```gdscript
# Initialization
func _ready() -> void:
    _game_state = SCGameState.new()
    _game_state.enter_state(SCGameState.State.WAITING)

# Main gameplay loop
func _physics_process(delta: float) -> void:
    if not _game_state.is_state(SCGameState.State.PLAYING):
        return
    
    # Timer countdown
    if _trial_is_running:
        _trial_time_left -= delta
        if _trial_time_left <= 0:
            _end_trial()
    
    # Process crossings
    _check_crossing_lines()

func _process(delta: float) -> void:
    # Start game on input
    if _game_state.is_state(SCGameState.State.WAITING):
        if Input.is_action_just_pressed("ui_select"):
            _start_trial()

# Game start
func _start_trial() -> void:
    _reset_trial_stats()
    _trial_time_left = TRIAL_DURATION
    _trial_is_running = true
    
    AppDataTrial.start_new_trial(
        Appdata.current_session_number,
        1,
        "SafeCrossing"
    )
    
    _game_state.enter_state(SCGameState.State.PLAYING)

# Game end
func _end_trial() -> void:
    _trial_is_running = false
    AppDataTrial.stop_trial(_trial_targets, _trial_successes, _trial_failures)
    _game_state.enter_state(SCGameState.State.GAME_OVER)
```

---

## Timer & Duration

### Unity Implementation

```csharp
public float gameDuration = MarsGameDefs.GAMEDURATION["DC"];  // 60 seconds
private float gameTimeLeft;

void Start() {
    gameTimeLeft = gameDuration;
}

void RunStateMachine() {
    bool isTimeUp = gameTimeLeft < 0;
    
    if (isGamePlaying && !isTimeUp) {
        gameTimeLeft -= Time.deltaTime;
    }
    
    if (isTimeUp) {
        gameState = GameStates.STOP;  // Trigger game over
    }
    
    if (isGamePlaying) {
        TimerText.text = "Timer:" + Mathf.CeilToInt(gameTimeLeft) + "s";
    }
}
```

### Godot Implementation

```gdscript
const TRIAL_DURATION: float = 60.0
var _trial_time_left: float = TRIAL_DURATION
var _trial_is_running: bool = false

func _start_trial() -> void:
    _trial_time_left = TRIAL_DURATION
    _trial_is_running = true

func _physics_process(delta: float) -> void:
    if not _game_state.is_state(SCGameState.State.PLAYING):
        return
    
    if _trial_is_running:
        _trial_time_left -= delta
        if _trial_time_left <= 0:
            _end_trial()
    
    # Display timer
    ui.update_phase_display("Phase Name [%.1f/60.0s]" % [
        TRIAL_DURATION - _trial_time_left
    ])
```

---

## Statistics Tracking

### Unity

```csharp
public int nTargets = 0;   // Total objectives/diamonds
public int nSuccess = 0;   // Successfully caught
public int nFailure = 0;   // Failed to catch

void RunStateMachine() {
    case GameStates.SPAWNDIAMOND:
        nTargets++;
        break;
    
    case GameStates.PLAYERIN:
        if (insideTargetTimer >= TARGET_IN_TIME) {
            nSuccess++;
            gameState = GameStates.SUCCESS;
        }
        break;
    
    case GameStates.WAITFORCATCH:
        if (reachTimeLeft <= 0f) {
            nFailure++;
            gameState = GameStates.FAILURE;
        }
        break;
}

void gameOver() {
    AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);
}
```

### Godot SafeCrossing

```gdscript
var _trial_targets: int = 0      # Total crossing attempts
var _trial_successes: int = 0    # Successful crossings
var _trial_failures: int = 0     # Failed crossings

func _check_crossing_lines() -> void:
    if crossing_detected:
        _trial_targets += 1
        
        if _phase_collided:
            _trial_failures += 1
        else:
            _trial_successes += 1
        
        _on_crossing_complete(is_success)

func _end_trial() -> void:
    AppDataTrial.stop_trial(
        _trial_targets,
        _trial_successes,
        _trial_failures
    )
```

---

## Data Logging

### Unity Flow

```csharp
// Start recording
void startGame() {
    AppData.Instance.StartNewTrial();
}

// End recording with statistics
void gameOver() {
    int gametime = (int)gameDuration - (int)gameTimeLeft;
    AppData.Instance.gameTime = gametime;
    AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);
    
    // AppData internally:
    // 1. Closes raw data file
    // 2. Appends row to sessions.csv with:
    //    - SessionNumber, DateTime
    //    - Targets, Success, Failure
    //    - SuccessRate = (nSuccess / nTargets) * 100
    //    - RawDataFileName
}
```

### Godot Implementation

```gdscript
# Start recording
func _start_trial() -> void:
    AppDataTrial.start_new_trial(
        Appdata.current_session_number,
        1,
        "SafeCrossing"
    )
    # Creates: data/{id}/rawdata/raw-s1-t1-SafeCrossing.csv

# Record each frame
func _on_crossing_complete(is_success: bool) -> void:
    AppDataTrial.write_frame_data()
    # Writes sensor frame to raw data file

# End recording
func _end_trial() -> void:
    AppDataTrial.stop_trial(
        _trial_targets,
        _trial_successes,
        _trial_failures
    )
    # 1. Closes raw data file
    # 2. Appends row to sessions.csv with all metrics
    # 3. Success rate calculated automatically
```

---

## Event Handling

### Unity

```csharp
// Button press triggers game state change
public void onMarsButtonReleased() {
    if (gameState == GameStates.WAITING) {
        isGameStarted = true;  // Triggers: WAITING → START
    }
    else if (gameState != GameStates.STOP) {
        isGamePaused = !isGamePaused;  // Toggle pause
    }
}

void Update() {
    if (isGamePaused && gameState != GameStates.PAUSED) {
        PauseGame();
    }
    else if (!isGamePaused && gameState == GameStates.PAUSED) {
        ResumeGame();
    }
}
```

### Godot Implementation

```gdscript
# Input handling
func _process(delta: float) -> void:
    # Start game
    if _game_state.is_state(SCGameState.State.WAITING):
        if Input.is_action_just_pressed("ui_select"):
            _start_trial()
    
    # Pause/Resume
    if Input.is_action_just_pressed("ui_cancel"):
        if _game_state.is_state(SCGameState.State.PLAYING):
            _toggle_pause()

func _toggle_pause() -> void:
    if _game_state.is_state(SCGameState.State.PLAYING):
        _game_state.enter_state(SCGameState.State.PAUSED)
        get_tree().paused = true
    elif _game_state.is_state(SCGameState.State.PAUSED):
        _game_state.enter_state(SCGameState.State.PLAYING)
        get_tree().paused = false
```

---

## Key Differences

### 1. Target Type

| Unity | Godot |
|-------|-------|
| Spawn random diamond objects | Detect line intersections |
| Player must reach & hold diamond | Player must cross line safely |
| 2-stage success (reach + hold) | 1-stage success (line cross) |

### 2. State Complexity

| Unity | Godot |
|-------|-------|
| 10 states, very granular | 8 states, consolidated |
| SPAWNDIAMOND → WAITFORCATCH → PLAYERIN → SUCCESS flow | Single PLAYING state, crossing detection implicit |
| Multiple phases within one state | Phase transitions managed separately |

### 3. Time Tracking

| Unity | Godot |
|-------|-------|
| `gameTimeLeft` (counts down) | `_trial_time_left` (counts down) |
| `reachTimeLeft` (per-target timer) | No per-crossing timer |
| `insideTargetTimer` (hold duration) | No hold requirement |

### 4. Success Condition

| Unity | Godot |
|-------|-------|
| Hold diamond for 0.5 seconds | Simply cross line without collision |
| Check: `insideTargetTimer >= TARGET_IN_TIME` | Check: collision status at crossing |

### 5. Statistics Display

| Unity | Godot |
|-------|-------|
| Shows cumulative score (previous day vs today) | Shows current trial score only |
| Updates TimerText each frame | Updates phase display with timer |
| Shows star count & achievements | Shows success rate percentage |

---

## Console Output Comparison

### Unity Log

```
Timer:60s Score:0
Timer:59s Score:0
Timer:45s Score:3
Timer:30s Score:6
Timer:15s Score:8
Timer:0s Score:8
Game Over: nTargets=10, nSuccess=8, nFailure=2
Success Rate: 80%
```

### Godot Log

```
⏱️ Trial: 0.0/60.0s | SCORE: 0 | SUCCESS: 0 | FAIL: 0
⏱️ Trial: 15.0/60.0s | SCORE: 3 | SUCCESS: 3 | FAIL: 0
⏱️ Trial: 30.0/60.0s | SCORE: 6 | SUCCESS: 6 | FAIL: 1
⏱️ Trial: 45.0/60.0s | SCORE: 8 | SUCCESS: 8 | FAIL: 2
⏱️ Trial: 60.0/60.0s | SCORE: 8 | SUCCESS: 8 | FAIL: 2
⏹️ TRIAL ENDED - Time's Up!
💾 Trial data saved: Targets=10, Success=8, Failures=2
📊 GAME OVER SCREEN:
  Score: 8
  Crossings: 8/10 successful
  Success Rate: 80.0%
```

---

## Method Mapping

### StartNewTrial()

**Unity:**
```csharp
public void StartNewTrial() {
    // In AppData
    // - Creates raw data file
    // - Initializes packet number
    // - Sets trial start time
}

// Called from:
void startGame() {
    AppData.Instance.StartNewTrial();
}
```

**Godot:**
```gdscript
# In AppDataTrial
func start_new_trial(session: int, trial: int, movement: String) -> void:
    # Creates raw data file
    # Initializes packet number
    # Sets trial start time

# Called from:
func _start_trial() -> void:
    AppDataTrial.start_new_trial(
        Appdata.current_session_number,
        1,
        "SafeCrossing"
    )
```

### StopTrial(targets, success, failure)

**Unity:**
```csharp
public void StopTrial(int nTargets, int nSuccess, int nFailure) {
    // - Closes raw data file
    // - Appends row to sessions.csv
    // - Calculates success rate
}

// Called from:
void gameOver() {
    AppData.Instance.StopTrial(nTargets, nSuccess, nFailure);
}
```

**Godot:**
```gdscript
# In AppDataTrial
func stop_trial(targets: int, successes: int, failures: int) -> void:
    # - Closes raw data file
    # - Appends row to sessions.csv
    # - Calculates success rate

# Called from:
func _end_trial() -> void:
    AppDataTrial.stop_trial(
        _trial_targets,
        _trial_successes,
        _trial_failures
    )
```

---

## CSV Format Comparison

### Both Use Same Session Data Format

```csv
SessionNumber,DateTime,TrialNumberDay,TrialNumberSession,TrialStartTime,TrialStopTime,Movement,GameName,ReachSpeed,GameParameter,GameDuration,SuccessRate,MoveTime,CurrentTargets,CurrentHits,CurrentMisses,CumulativeTargets,CumulativeHits,CumulativeMisses,RawDataFileName

1,2026-05-20_10:30:45,1,1,0.00,60.00,SafeCrossing,SafeCrossing,1.0,0.0,60.00,80.0,58.5,10,8,2,10,8,2,raw-s1-t1-SafeCrossing.csv
```

### Both Use Same Raw Data Format

```csv
Timestamp,PacketNumber,Force1,Force2,Angle1,Angle2,Angle3,Angle4,Distance1,Distance2,Button1-7...

0.000,1,45.23,32.15,12.45,-8.90,-5.32,15.67,5.45,4.98,0,0,0,1,0,0,0
0.017,2,45.89,32.45,12.67,-8.75,-5.20,15.80,5.50,5.00,0,0,0,1,0,0,0
```

---

## Summary: What's the Same?

✅ **60-second trial duration**
✅ **State machine architecture**
✅ **Three statistics: targets, successes, failures**
✅ **Data logging: raw files + session rows**
✅ **CSV persistence format**
✅ **Success rate calculation**
✅ **Game over detection**
✅ **Pause/resume capability**

## Summary: What's Different?

🔄 **Game mechanics** - Catch diamonds vs navigate traffic
🔄 **State granularity** - 10 states vs 8 states  
🔄 **Success condition** - Hold duration vs collision-free crossing
🔄 **Target tracking** - Per-diamond timers vs line intersection
🔄 **UI display** - Score/stars vs success rate percentage

## Conclusion

The SafeCrossing Godot implementation follows the **same state machine philosophy** and **data logging patterns** as the Unity DCGameController, adapted for a different game mechanic. Both use the **AppData/AppDataTrial pattern** for trial management and persistence.

For other games, follow the same template:
1. Implement state machine (WAITING → START → PLAYING → GAME_OVER)
2. Track trial duration (60 seconds)
3. Call `start_new_trial()` at game start
4. Call `stop_trial()` at game end
5. Record statistics (targets, successes, failures)
