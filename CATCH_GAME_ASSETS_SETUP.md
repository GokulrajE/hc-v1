# Catch Game - Asset Setup Guide

## 🎨 Current Status

The game has been updated to load sprites from an asset file instead of generating circles.

**Asset File Location:** `res://assets/catchgame/catch_game.png`

---

## 📁 Folder Structure

```
d:\hc-v1\
├── assets/
│   └── catchgame/
│       ├── catch_game.png          ← Your sprite file goes here
│       └── README.md               ← Asset instructions
│
├── scripts/catch_game/
│   ├── catch_game_main.gd          ← Updated to load sprites
│   └── catch_game_ui.gd
│
└── scene/catch_game/
    └── catch_game.tscn
```

---

## 🎯 Object Types

The game now distinguishes between different object types:

### Wanted Objects (70% spawn rate) ✅
Displayed with **WHITE color** (normal)
- 🍎 **Apple** - Catch for +10 points
- 💎 **Diamond** - Catch for +10 points

### Unwanted Objects (30% spawn rate) ❌
Displayed with **REDDISH tint** (warning color)
- 🪙 **Gold Coin** - Avoid! (-5 if caught)

---

## 📥 How to Add Your Sprites

### Step 1: Create Asset Folder
```
If not already created:
1. Create folder: d:\hc-v1\assets\catchgame\
2. Place your sprite file there
```

### Step 2: Prepare Sprite File
Your `catch_game.png` should contain:
- Apple sprite
- Diamond sprite
- Gold Coin sprite

**Recommended Sprite Sheet Layout:**
```
┌──────────────────┐
│ 🍎  💎  🪙      │
│                 │
│  64×64 each     │
└──────────────────┘
Overall: 256×64 pixels (or larger)
```

### Step 3: Load in Game
1. Save your sprite as: `catch_game.png`
2. Place in: `d:\hc-v1\assets\catchgame\`
3. Restart Godot or reload scene (F5)
4. Run game - objects will now show your sprites!

---

## 🎮 What Happens With Your Sprites

When the game runs:

```
1. Game loads res://assets/catchgame/catch_game.png
   ↓
2. Spawns object (either wanted or unwanted)
   ↓
3. Displays loaded sprite with color tint:
   - Wanted: WHITE (normal appearance)
   - Unwanted: REDDISH (warning color)
   ↓
4. Falls at 300 pixels/second
   ↓
5. Player catches with hands (spreading left/right)
   ↓
6. Score updates based on type
```

---

## 🔧 Fallback Behavior

If the sprite file is NOT found:
- ✅ Game still works
- ✅ Uses generated colored circles instead
- 🟢 Green circles = wanted objects
- 🔴 Red circles = unwanted objects
- ✅ Gameplay is 100% functional

**Console Message If Missing:**
```
⚠️ Warning: Asset file not found. Using generated circles.
```

---

## 💾 Asset File Information

### File Format
- **Format:** PNG image
- **Transparency:** Recommended (PNG with alpha channel)
- **Color Space:** RGB or RGBA
- **Size:** 256×512 pixels recommended (flexible)

### Naming Convention
```
catch_game.png              ← Main sprite sheet (REQUIRED)
```

### Sprite Organization (Example)

**Option A: Single Row**
```
[Apple | Diamond | Gold Coin]
64px   | 64px    | 64px
Total: 256×64 pixels
```

**Option B: 2D Grid**
```
[Apple    | Diamond]
[GoldCoin | spare  ]
```

**Option C: Large Sheet**
```
Multiple items can be repeated/varied
Size: 512×512 recommended
```

---

## 🎬 Game Behavior With Assets

### What Gets Displayed

```
WANTED OBJECTS (shown normally):
🍎 Apple (white color)  → Catch for +10 points
💎 Diamond (white color) → Catch for +10 points

UNWANTED OBJECTS (shown with warning):
🪙 Gold Coin (reddish tint) → Avoid! (-5 if caught)
```

### Sprite Scaling

Objects are scaled 3× in the game:
```gdscript
sprite.scale = Vector2(3, 3)
```

So if your sprite is 64×64, it displays as ~192×192 on screen.

---

## 🔍 Troubleshooting

### Sprites Not Showing?

1. **Check file location:**
   ```
   d:\hc-v1\assets\catchgame\catch_game.png
   ```

2. **Check file name:** Must be exactly `catch_game.png`

3. **Check file format:** Should be PNG with transparency

4. **Check Godot sees the file:**
   - In Godot FileSystem panel
   - Should appear in `res://assets/catchgame/`

5. **Restart Godot:**
   - Close and reopen project
   - Or press F5 to reload scene

### Still Using Circles?

If you see colored circles instead of your sprites:
1. Sprite file not found at correct path
2. File format issue
3. Check console output for warning message

### Performance Issues?

If game lags with custom sprites:
1. Reduce sprite size (64×64 pixels ideal)
2. Compress PNG file
3. Use single sprite sheet instead of multiple files

---

## 📋 Quick Checklist

- [ ] Created `assets/catchgame/` folder
- [ ] Prepared sprite images (apple, diamond, gold coin)
- [ ] Combined into single PNG file
- [ ] Named file: `catch_game.png`
- [ ] Placed in: `d:\hc-v1\assets\catchgame\`
- [ ] Restarted Godot
- [ ] Launched game (F5)
- [ ] Objects now show custom sprites ✅

---

## 🎨 Sprite Design Tips

### Colors That Work Well
- **Wanted objects:** Bright colors (green, yellow, blue)
- **Unwanted objects:** Darker colors (brown, grey, dark red)

### Size Recommendations
- **Small:** 32×32 pixels (needs 4× scaling, less detail)
- **Medium:** 64×64 pixels (good balance, recommended)
- **Large:** 128×128 pixels (lots of detail, 2.3× scaling)

### Transparency
- Use PNG with transparency (alpha channel)
- Allows sprites to have rounded edges
- Makes them blend better on dark background

---

## 🚀 Testing Your Assets

Once you've added your sprites:

```
1. Open Godot
2. Open scene: res://scene/catch_game/catch_game.tscn
3. Press F5 to play
4. Press SPACEBAR to start
5. Watch objects fall with your custom sprites
6. Catch wanted objects (white/normal)
7. Avoid unwanted objects (reddish tint)
```

---

## 📞 Asset Support

### If Assets Don't Load

Check console (F12) for messages:
```
✅ Asset file loaded successfully
⚠️ Warning: Asset file not found. Using generated circles.
🎯 Spawned wanted object: apple
🎯 Spawned unwanted object: gold_coin
```

### File Validation

Your sprite file should:
1. ✅ Be in PNG format
2. ✅ Be named exactly `catch_game.png`
3. ✅ Be in `assets/catchgame/` folder
4. ✅ Contain recognizable sprite images
5. ✅ Use transparency for clean edges

---

## 🎮 Play with Your Sprites!

Once everything is set up:
1. Run the game
2. Press SPACEBAR to start
3. Watch your custom sprites fall
4. Catch the wanted ones (apple, diamond)
5. Avoid the unwanted one (gold coin)
6. Enjoy! 🎉

---

**Current Status:** ⏳ Waiting for sprite file at `res://assets/catchgame/catch_game.png`

**Fallback Status:** ✅ Game works with generated circles if sprites not found

**Next Step:** Add your sprite file to enable custom graphics! 🎨
