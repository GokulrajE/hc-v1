# HyperCubeGame Data Management

## Overview

The `HyperCubeGame` class manages all game data for rehabilitation games in the HyperCube system. It mirrors the Unity `MarsGame` class and tracks:
- Game metadata (name, movement type)
- Rehabilitation parameters (reach speed, game speed)
- Current trial statistics
- Cumulative statistics across multiple trials
- ROM (Range of Motion) data
- Star/achievement tracking

---

## Class Structure

### Creation

```gdscript
# Create a new game instance
var game = HyperCubeGame.new("SafeCrossing", "Left Arm", 1.0)

# Parameters:
# - game_name: String - Name of the game (e.g., "SafeCrossing", "DiamondCatcher")
# - movement_name: String - Movement type (e.g., "Flexion", "Extension")
# - reach_spd: float - Reach speed parameter (0.5 - 2.0)
```

### Key Properties

```gdscript
# Game Info
game.name              # "SAFECROSSING"
game.movement          # "LEFT ARM"
game.reach_speed       # 1.0 (0.5 - 2.0 range)
game.game_speed        # 100.0 (calculated from reach_speed)
game.game_parameter    # Game-specific parameter (e.g., reach duration)
game.game_duration     # 60.0 (seconds)

# Current Trial Stats
game.current_targets   # Total targets in current trial
game.current_hits      # Successful hits in current trial
game.current_misses    # Failed attempts in current trial

# Cumulative Stats (across all trials)
game.cumulative_targets  # Total across all trials
game.cumulative_hits     # Total successes across all trials
game.cumulative_misses   # Total failures across all trials
game.cumulative_stars    # Total stars earned

# Session Info
game.session_number      # Current session number
game.trial_number_day    # Trial count for the day
game.trial_number_session # Trial count for current session
```

---

## Usage Examples

### 1. Initialize Game

```gdscript
# Create a new SafeCrossing game instance
var safecrossing_game = HyperCubeGame.new("SafeCrossing", "Left Arm", 1.0)

# Or with default reach speed
var game = HyperCubeGame.new("SafeCrossing", "Left Arm")
# → reach_speed defaults to 1.0
```

### 2. Adjust Reach Speed

```gdscript
# Change rehabilitation difficulty
game.set_reach_speed(1.5)  # Faster movement required
# Output: ✓ Reach speed for 'SAFECROSSING' set to 1.50 | Game speed: 150.0

# Reach speed clamps to 0.5 - 2.0
game.set_reach_speed(0.3)  # Clamps to 0.5
game.set_reach_speed(3.0)  # Clamps to 2.0
```

### 3. Set Game-Specific Parameters

```gdscript
# Set reach duration for target
game.set_game_parameter(2.5)  # Must hold target for 2.5 seconds
# Output: ✓ Game parameter set to 2.50

# Or set ROM data
game.set_arom("Knob", 5.0, 80.0)  # Min: 5°, Max: 80°
# Output: ✓ AROM set for KNOB: 5.0 - 80.0
```

### 4. Record Trial Results

```gdscript
# After 60-second trial ends with:
# - 10 targets presented
# - 8 successfully hit
# - 2 missed

game.update_targets_hits_misses(10, 8, 2)

# Output:
# 📊 Trial Stats: Targets=10, Hits=8, Misses=2
# 📈 Cumulative: Targets=10, Hits=8, Misses=2
```

### 5. Query Success Rates

```gdscript
# Current trial success rate
var current_rate = game.get_current_success_rate()
# → Returns: 80.0 (80%)

# Cumulative success rate across all trials
var cumulative_rate = game.get_cumulative_success_rate()
# → Returns: 80.0 (80%)
```

### 6. Handle Achievements

```gdscript
# Award star if player exceeded yesterday's score
if new_score > yesterday_score:
    game.award_star()
    # Output: ⭐ Star awarded! Total: 1 | Today: 1

# Check if achievement unlocked today
if game.is_achieved_today():
    print("Achievement unlocked today!")
```

### 7. Trial Management

```gdscript
# Move to next trial (resets current, increments counters)
game.next_trial()
# Output: ➡️ Next trial: Session 1 | Day Trial 2 | Session Trial 2

# Or manually update trial numbers
game.update_trial_numbers(1, 5, 3)  # Session 1, Trial 5 today, Trial 3 this session

# Reset current trial only (keep cumulative)
game.reset_current_trial()
```

### 8. Get Summary

```gdscript
# Get data as dictionary
var summary = game.get_summary()
# Returns:
# {
#   "name": "SAFECROSSING",
#   "movement": "LEFT ARM",
#   "reach_speed": 1.0,
#   "game_speed": 100.0,
#   "current_targets": 10,
#   "current_hits": 8,
#   "current_misses": 2,
#   "current_success_rate": 80.0,
#   "cumulative_targets": 50,
#   "cumulative_hits": 40,
#   "cumulative_misses": 10,
#   "cumulative_success_rate": 80.0,
#   ...
# }

# Print formatted summary
game.print_summary()
# Output:
# ╔═══════════════════════════════════════════════╗
# ║         HYPERCUBE GAME DATA SUMMARY          ║
# ╠═══════════════════════════════════════════════╣
# ║ Game: SAFECROSSING
# ║ Movement: LEFT ARM
# ║ Reach Speed: 1.00 | Game Speed: 100.0
# ║ Session: 1 | Trial (Day): 5 | Trial (Session): 3
# ║
# ║ CURRENT TRIAL:
# ║   Targets: 10 | Hits: 8 | Misses: 2
# ║   Success Rate: 80.0%
# ║   Trial Star: ⭐
# ║
# ║ CUMULATIVE:
# ║   Targets: 50 | Hits: 40 | Misses: 10
# ║   Success Rate: 80.0%
# ║   Total Stars: 2 | Today Stars: 1
# ║   ⭐ ⭐
# ╚═══════════════════════════════════════════════╝
```

---

## Integration with Game Scripts

### In SafeCrossing Game

```gdscript
# scripts/safecrossing/game/sc_game.gd

var game_data: HyperCubeGame

func _ready() -> void:
    # Create game data instance
    game_data = HyperCubeGame.new("SafeCrossing", "Left Arm", 1.0)

func _end_trial() -> void:
    # Record trial results
    game_data.update_targets_hits_misses(
        _trial_targets,
        _trial_successes,
        _trial_failures
    )
    
    # Check for achievement
    if _trial_successes > last_trial_score:
        game_data.award_star()
    
    # Move to next trial
    game_data.next_trial()
    
    # Display summary
    game_data.print_summary()
```

### In Appdata (Global Manager)

```gdscript
# scripts/appdata.gd

var current_game: HyperCubeGame

func select_game(game_name: String, movement: String, reach_speed: float = 1.0) -> void:
    current_game = HyperCubeGame.new(game_name, movement, reach_speed)
    print("Game selected: %s | %s | Speed: %.2f" % [game_name, movement, reach_speed])

func get_current_game() -> HyperCubeGame:
    return current_game
```

---

## Data Export for CSV

```gdscript
# Export game data to CSV format
var csv_data = game.export_for_csv()
# Returns dictionary with string-formatted values:
# {
#   "game_name": "SAFECROSSING",
#   "reach_speed": "1.00",
#   "game_speed": "100.0",
#   "current_success_rate": "80.0",
#   ...
# }

# Can be directly written to CSV file
for key in csv_data.keys():
    csv_row = "%s,%s" % [key, csv_data[key]]
```

---

## Complete Trial Workflow

```
1. Create Game Instance
   ↓
   game = HyperCubeGame.new("SafeCrossing", "Left Arm", 1.0)

2. Configure Game (optional)
   ↓
   game.set_reach_speed(1.5)
   game.set_game_parameter(2.5)
   game.set_arom("Knob", 5.0, 80.0)

3. Run Trial (60 seconds)
   ↓
   Track targets/hits/misses during gameplay

4. End Trial
   ↓
   game.update_targets_hits_misses(10, 8, 2)
   game.award_star()  # if deserved
   game.print_summary()

5. Next Trial
   ↓
   game.next_trial()  # Increments counters, resets current stats

6. Export Data (when saving)
   ↓
   var csv = game.export_for_csv()
   Datamanager.save_to_csv(csv)
```

---

## Reach Speed Reference

| Speed | Name | Difficulty | Notes |
|-------|------|-----------|-------|
| 0.5 | Very Slow | Easy | Good for rehabilitation, slow movements |
| 0.75 | Slow | Easy-Medium | Standard slow rehabilitation pace |
| 1.0 | Normal | Medium | Default, standard pace |
| 1.25 | Fast | Medium-Hard | Faster rehabilitation pace |
| 1.5 | Very Fast | Hard | Challenging, requires precise control |
| 2.0 | Max Speed | Very Hard | Maximum speed, expert level |

---

## Star Achievement System

```gdscript
# Star award logic (typically in game controller)

var yesterday_score = 15  # Previous high score
var today_score = 18      # New trial score

if today_score > yesterday_score:
    game.award_star()     # Player beat their previous score
    # Output: ⭐ Star awarded! Total: 3 | Today: 1

# Check achievement status
if game.is_achieved_today():
    print("✓ Unlocked today's achievement!")
    ui.show_star_animation()
```

---

## Performance Metrics

### Current Trial
- Used to track performance in single 60-second trial
- Reset after each trial
- Updated in real-time during gameplay

### Cumulative Metrics
- Persistent across all trials in session
- Used for long-term progress tracking
- Used for achievement/star calculation
- Saved to disk at session end

### Example Session

```
Trial 1:  10 targets, 7 hits, 3 misses (70%)
Trial 2:  10 targets, 8 hits, 2 misses (80%)
Trial 3:  10 targets, 9 hits, 1 miss   (90%)

Cumulative: 30 targets, 24 hits, 6 misses (80% overall)
Stars: 2 (if beat yesterday's score on trials 2 & 3)
```

---

## Comparison with Unity MarsGame

| Feature | Unity MarsGame | Godot HyperCubeGame |
|---------|---|---|
| Initialization | Constructor params | `.new(name, movement, speed)` |
| Reach Speed | `reachSpeed` property | `set_reach_speed()` method |
| Game Speed Calc | Auto in reachSpeed setter | `_calculate_game_speed()` |
| Update Stats | `UpdateTargetsHitsMisses()` | `update_targets_hits_misses()` |
| Success Rate | Method | Method: `get_current_success_rate()` |
| Stars | `updateCummulativeStars()` | `award_star()` |
| Achievement Check | `isAchievedToday()` | `is_achieved_today()` |
| Summary | Debug output | `print_summary()` / `get_summary()` |

---

## See Also

- 📄 [SAFECROSSING_GAME_STATES.md](SAFECROSSING_GAME_STATES.md) - Game state management
- 📄 [sc_game.gd](scripts/safecrossing/game/sc_game.gd) - SafeCrossing implementation
- 📄 [appdata.gd](scripts/appdata.gd) - User/session management
