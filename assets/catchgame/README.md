# Catch Game Assets

## Asset File Required

Place your sprite sheet at: `assets/catchgame/catch_game.png`

### Sprite Sheet Requirements

The `catch_game.png` file should contain the following sprites:

**Wanted Objects (Green Tint):**
- 🍎 Apple - Objects to CATCH (+10 points)
- 💎 Diamond - Objects to CATCH (+10 points)

**Unwanted Objects (Red Tint):**
- 🪙 Gold Coin - Objects to AVOID (-5 if caught)

### Sprite Arrangement Options

#### Option 1: Single Sprite Sheet (Recommended)
- Create a 256×256 px image with all three sprites
- Game will load the entire image and use it as the falling object
- Sprites will be colored with tint overlay (white for wanted, reddish for unwanted)

#### Option 2: Separate Sprites
If you prefer separate files, update the code:
```gdscript
const WANTED_SPRITES: Dictionary = {
    "apple": "res://assets/catchgame/apple.png",
    "diamond": "res://assets/catchgame/diamond.png"
}

const UNWANTED_SPRITES: Dictionary = {
    "gold_coin": "res://assets/catchgame/gold_coin.png"
}
```

### Current Setup

The game currently:
1. Loads `res://assets/catchgame/catch_game.png`
2. Applies color tints:
   - **Wanted (Green):** White color (normal)
   - **Unwanted (Red):** Reddish tint (0.5, 0.5, 1.0)
3. Falls with your hand reaching to catch

### Adding Your Sprite

1. Save your sprite as `catch_game.png`
2. Place in `d:\hc-v1\assets\catchgame\` folder
3. Restart the game
4. Objects will now display your custom sprites!

### Sprite Size Recommendations

- Individual sprite: 64×64 to 128×128 pixels
- Sprite sheet: 256×256 to 512×512 pixels
- The game scales sprites 3× (sprite.scale = Vector2(3, 3))

### Fallback Behavior

If the sprite file is not found:
- Game will display generated circles instead
- Green circles for wanted objects
- Red circles for unwanted objects
- Game is fully playable with fallback graphics

---

**Current Asset Status:** ⏳ Waiting for sprite file
**Path:** `res://assets/catchgame/catch_game.png`

To use your assets:
1. Create the `assets/catchgame/` directory
2. Add your `catch_game.png` file
3. Restart Godot
4. Play! 🎮
