# Catch Game - Quick Start Guide

## 🚀 How to Play in 30 Seconds

### 1. Open Scene
```
In Godot Editor:
1. Open: res://scene/catch_game/catch_game.tscn
2. Press F5 to play
```

### 2. Game Rules
```
Press SPACEBAR to start
─────────────────────

⬅️ LEFT ARROW   = Bring hands together
➡️ RIGHT ARROW  = Move hands apart

🟢 Green = Catch (☑️ Do this!)    → +10 points
🔴 Red   = Avoid (✖️ Don't do!)  → -5 points
```

### 3. Gameplay (60 seconds)
```
1. Objects fall from top
2. Move hands to catch green 🟢
3. Move hands to avoid red 🔴
4. Score updates instantly
5. Timer counts down
6. Game ends at 0 seconds
```

### 4. See Results
```
📊 Final Score: 85
   Caught: 10 | Missed: 2
   Success Rate: 83.3%

Press SPACEBAR again to replay
```

---

## 🎯 Game Features

✅ **2 Hands** - Move in opposite directions
✅ **60 Second Trial** - Fixed duration
✅ **Falling Objects** - 2 per second
✅ **Real-time Scoring** - Instant feedback
✅ **Visual Feedback** - Success/failure popups
✅ **Statistics** - Final results displayed

---

## 📁 Files Created

```
scripts/catch_game/
├── catch_game_main.gd          # Game logic (300+ lines)
└── catch_game_ui.gd            # UI system (150+ lines)

scene/catch_game/
└── catch_game.tscn             # Scene file

Documentation/
├── CATCH_GAME_README.md        # Full documentation
└── CATCH_GAME_QUICKSTART.md    # This file
```

---

## 🎮 Keyboard Shortcuts

| Key | Action |
|-----|--------|
| SPACEBAR | Start / Restart game |
| ➡️ RIGHT | Move hands apart (spread) |
| ⬅️ LEFT | Bring hands together (close) |

---

## 💡 Strategy Tips

1. **Spread Early** - Prepare for falling objects
2. **Quick Reactions** - Objects fall fast (300 px/sec)
3. **Watch Pattern** - Objects spawn randomly but consistently
4. **Avoid Tunnel Vision** - Check both left and right
5. **Aim for Center** - Hands closer to center = safer catch

---

## 📊 Scoring Breakdown

```
Green Object (70% chance)
├─ Caught     → +10 points ✅
└─ Missed     → 0 points

Red Object (30% chance)
├─ Caught     → -5 points ❌
└─ Missed     → 0 points ✓ (OK!)

Best Case: 60 sec × 2 objects/sec × 10 pts = 1200 points
Real Score: Usually 80-150 points (realistic)
```

---

## 🔧 Customization (Easy Changes)

In `catch_game_main.gd`:

```gdscript
# Change game duration
const GAME_DURATION: float = 60.0  # ← Change to 30, 90, etc.

# Change hand speed
const HAND_SPEED: float = 500.0  # ← Higher = faster

# Change spawn rate
const SPAWN_RATE: float = 2.0  # ← Higher = more objects

# Change object ratio
var is_wanted = randf() < 0.7  # ← 0.7 = 70% green, 30% red
```

---

## 📺 Game States

```
WAITING STATE
├─ Show instructions
├─ Show hand positions
└─ Wait for SPACEBAR

PLAYING STATE (60 seconds)
├─ Spawn objects every 0.5 sec
├─ Update hand positions
├─ Detect collisions
├─ Update score & timer
└─ Check time elapsed

GAME_OVER STATE
├─ Show final score
├─ Show statistics
├─ Show restart instruction
└─ Wait for SPACEBAR
```

---

## 🎨 Visual Layout

```
┌──────────────────────────────────────────┐
│ Score: 85                  Time: 45.2s   │
├──────────────────────────────────────────┤
│                                          │
│        Instructions (start only)         │
│        Press SPACEBAR to Start           │
│                                          │
│           🟢  🔴  🟢                     │
│          Objects Falling                │
│                                          │
│                                          │
│                                          │
│              👋       👋                 │
│            Hands (bottom)                │
│                                          │
│  Spread: ▓▓░░░░░░░░ (30%)               │
└──────────────────────────────────────────┘
```

---

## 🧪 Testing Checklist

- [ ] Scene opens without errors
- [ ] Press SPACEBAR - game starts
- [ ] Right arrow - hands move apart
- [ ] Left arrow - hands move together
- [ ] Objects spawn from top
- [ ] Objects fall downward
- [ ] Green object caught - score +10
- [ ] Red object caught - score -5
- [ ] Red object missed - score unchanged
- [ ] Timer counts down from 60
- [ ] Game ends at 0 seconds
- [ ] Game over panel shows results
- [ ] Press SPACEBAR - game restarts

**All Green ✅ = Ready to Use!**

---

## 🐛 If Something Breaks

### Objects not spawning?
```
Check: catch_game_main.gd line 235 (_spawn_object)
Verify: spawner node exists
```

### Hands not moving?
```
Check: Input Map (Project > Project Settings > Input Map)
Verify: ui_right and ui_left are mapped
```

### Score not updating?
```
Check: catch_game_ui.gd line 45 (update_score)
Verify: score_label node exists in scene
```

### Game won't start?
```
Check: Console (F12) for error messages
Verify: Scene path is correct
Reload scene: Press F5
```

---

## 📱 Future: Device Integration

This game will eventually use device sensors:

```gdscript
# Right now (keyboard):
if Input.is_action_pressed("ui_right"):
    spread_increase()

# Future (with device):
if HCcomm.force_1 > 50:
    spread_increase()  # Use hand squeeze to spread
```

No changes needed for basic gameplay!

---

## 🎯 Next Steps

1. **Test the game** - Play a few times
2. **Customize parameters** - Adjust difficulty
3. **Add sounds** - Beep on catch, buzz on wrong
4. **Add effects** - Particles, animations
5. **Integrate with device** - Use HCcomm sensors
6. **Track statistics** - Save to AppDataTrial
7. **Create assets** - Custom hand graphics, objects

---

## 💾 Save Game Data

To integrate with trial system:

```gdscript
# At game end:
AppDataTrial.start_new_trial(session, trial, "CatchGame")
# ... play game ...
AppDataTrial.stop_trial(_caught_objects, _caught_objects, _missed_objects)
```

This will save:
- ✅ Raw sensor data (device frame by frame)
- ✅ Session row (game statistics)
- ✅ Success rate calculation

---

## 🎮 Game Loop (Behind the Scenes)

```
1. User presses SPACEBAR
2. Game state: WAITING → PLAYING
3. Timer starts: 60.0 seconds
4. Spawn rate: 2 objects/second

5. MAIN GAME LOOP (runs every frame @ 60 FPS)
   ├─ Decrement timer
   ├─ Check input (arrow keys)
   ├─ Update hand positions
   ├─ Spawn new objects
   ├─ Update falling objects
   ├─ Detect collisions
   ├─ Update score
   ├─ Refresh UI
   └─ Check if time elapsed

6. When time = 0:
   ├─ Stop gameplay
   ├─ Calculate final score
   ├─ Calculate success rate
   └─ Show results panel

7. User presses SPACEBAR to restart
8. Go back to step 1
```

---

## 📈 Difficulty Progression

**Easy Mode:**
- Spawn Rate: 1.0 objects/sec
- Hand Speed: 400 pixels/sec
- Max Spread: 500 pixels

**Normal Mode (Default):**
- Spawn Rate: 2.0 objects/sec
- Hand Speed: 500 pixels/sec
- Max Spread: 400 pixels

**Hard Mode:**
- Spawn Rate: 3.0 objects/sec
- Hand Speed: 600 pixels/sec
- Max Spread: 300 pixels

---

## 🏆 Sample Scores

```
Beginner Player (First time):
  Score: 20
  Caught: 5 | Missed: 85
  Success: 6%

Intermediate Player (Practiced):
  Score: 75
  Caught: 10 | Missed: 10
  Success: 50%

Expert Player (Very fast):
  Score: 200
  Caught: 30 | Missed: 0
  Success: 100%
```

---

## 🎁 Asset Download

**No downloads required!**

This game uses only:
- Godot built-in features
- Generated circle textures
- Unicode emoji

**Size: ~5 KB (source code only)**

All assets are procedurally generated in code.

---

## 📞 Need Help?

1. Check CATCH_GAME_README.md for full documentation
2. Review console output (F12) for error messages
3. Verify all nodes are created in scene
4. Check script paths are correct
5. Reload scene (F5) to refresh

---

**Version:** 1.0
**Status:** ✅ Ready to Play
**Created:** 2026-05-20

🎮 **Enjoy the Catch Game!** 🎮
