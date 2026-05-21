# Mechanism & ROM Implementation for HC-V1

Implemented ROM (Range of Motion) and PlutoMechanism classes mirroring the Unity implementation structure.

## Files Created

### 1. `scripts/rom.gd` - ROM Class
Stores Active Range of Motion (AROM) data for HyperCube device.
HyperCube devices only track AROM measurements (patient's unassisted active range).

**Properties:**
```gdscript
var datetime: String
var arom_min: float
var arom_max: float
var mechanism: String
```

**Key Methods:**
```gdscript
func set_arom(min_val: float, max_val: float) -> void
func is_arom_set() -> bool
func is_set() -> bool  # True when arom is set
func write_to_assessment_file() -> bool
func get_current_arom() -> Array  # Returns [min, max]
```

**Usage Example:**
```gdscript
# Create new ROM for Hand Grip mechanism
var rom = ROM.new("Hand Grip", false)  # false = don't read from file
rom.set_arom(5.0, 80.0)  # Only AROM for HyperCube
if rom.is_set():
    rom.write_to_assessment_file()
```

### 2. `scripts/hypercuber_mechanism.gd` - HyperCuberMechanism Class
Represents a rehabilitation mechanism with AROM-only ROM tracking for HyperCube devices.

**Properties:**
```gdscript
var name: String                  # Mechanism name (Hand Grip, Knobs, Tripod Grip, etc.)
var side: String                  # "Left" or "Right"
var arom_completed: bool          # HyperCube only has AROM
var old_rom: ROM                  # Previously saved ROM data
var new_rom: ROM                  # Current assessment ROM data
var curr_speed: float             # Movement speed (Hz)
var trial_number_day: int
var trial_number_session: int
```

**Default Speeds:**
```gdscript
DEFAULT_SPEEDS = {
    "Hand Grip": 10.0,
    "Knobs": 10.0,
    "Tripod Grip": 10.0,
    "WFE": 10.0,
    "WURD": 10.0,
    "FPS": 10.0,
    "HOC": 10.0,
    "FME1": 10.0,
    "FME2": 10.0,
}
```

**Key Methods:**
```gdscript
# Accessors
func is_mechanism(mech_name: String) -> bool
func is_side(side_name: String) -> bool
func is_speed_updated() -> bool
func get_current_rom() -> ROM  # Returns newRom if set, else oldRom
func get_current_arom() -> Array  # HyperCube only
func get_speed() -> float

# Modifiers
func next_trial() -> void  # Increment day and session trial numbers
func set_speed(speed: float) -> void
func reset_arom_values() -> void  # HyperCube only

# Setters
func set_new_arom_values(amin: float, amax: float) -> void  # HyperCube only

# Persistence
func save_assessment_data() -> bool  # Saves when AROM assessment completed
```

**Usage Example:**
```gdscript
# Create mechanism for current session
var mechanism = HyperCuberMechanism.new("Hand Grip", "Left", AppData.session_number)

# Perform AROM assessment (HyperCube only)
mechanism.set_new_arom_values(5.0, 80.0)

# Save ROM when AROM assessment complete
if mechanism.save_assessment_data():
    print("ROM data saved successfully")

# Move to next trial
mechanism.next_trial()
```

### 3. Updates to `scripts/appdata.gd`
Added mechanism management to AppData:

**New Static Properties:**
```gdscript
static var current_side: String = ""
static var mechanisms: Dictionary = {}  # HyperCuberMechanism objects by name
```

**New Static Methods:**
```gdscript
# Get or create mechanism (lazy loading)
static func get_mechanism(mech_name: String, side_name: String = "")

# Create new mechanism for session
static func create_mechanism(mech_name: String, side_name: String = "")

# Get all active mechanisms
static func get_all_mechanisms() -> Array

# Clear mechanisms when switching users
static func clear_mechanisms() -> void
```

**Usage Example:**
```gdscript
# Create mechanism for current session
var mech = AppData.create_mechanism("Hand Grip", "Left")
mech.set_new_arom_values(5.0, 80.0)  # HyperCube only has AROM

# Later, retrieve the same mechanism
var mech = AppData.get_mechanism("Hand Grip")

# Check current ROM values (AROM only)
var arom = mech.get_current_arom()  # [min, max]
```

### 4. Updates to `scripts/data_manager.gd`
Added ROM file path method:

```gdscript
func get_rom_file_path(mechanism: String) -> String
    # Returns path like: data/{hospitalID}/rom/hand_grip_rom.csv
```

**ROM File Structure:**
- Location: `data/{hospitalID}/rom/{mechanism_name}_rom.csv`
- Format: CSV with pre-header metadata
- Rows contain: DateTime, PromMin, PromMax, AromMin, AromMax, APromMin, APromMax

## File Storage Structure

```
data/{hospitalID}/
├── rom/
│   ├── hand_grip_rom.csv
│   ├── knobs_rom.csv
│   └── tripod_grip_rom.csv
└── sessions/
    └── sessions.csv
```

## Example ROM CSV File (HyperCube - AROM Only)

**File:** `data/H001/rom/hand_grip_rom.csv`
```
:Location: Main Hospital
:Device: HC-V1
:User: H001
DateTime,AromMin,AromMax
2026-05-19 10:30:45,5.0,80.0
2026-05-20 11:15:30,10.0,85.0
```

## Integration with Assessment Flow

### Mechanism Selection → Assessment → AROM Assessment (HyperCube)

```gdscript
# In assessment.gd
func _on_mechanism_selected(mechanism_name: String, side: String):
    # Create mechanism object
    var mech = AppData.create_mechanism(mechanism_name, side)
    
    # Store for later use
    current_mechanism = mech

func _on_arom_assessed(amin: float, amax: float):
    # HyperCube only has AROM assessment
    current_mechanism.set_new_arom_values(amin, amax)
    
    # Once AROM assessment done, save
    if current_mechanism.save_assessment_data():
        print("AROM Assessment saved!")
```

## Compatibility Notes

- **HyperCube AROM-Only:** HyperCuberMechanism tracks only AROM (no PROM/APROM)
- **ROM File Format:** HyperCube CSV contains only DateTime, AromMin, AromMax
- **Path Naming:** Uses snake_case for file names (hand_grip_rom.csv)
- **Autoload Access:** Available globally as `AppData.get_mechanism()` or `AppData.create_mechanism()`
- **Device Specific:** ROM and HyperCuberMechanism classes are optimized for HyperCube devices

## Future Enhancements

- Load trial numbers from existing session history
- Batch ROM assessment (multiple mechanisms per session)
- ROM comparison and trending (old vs new)
- Graphical ROM visualization
- ROM validation (warn if ROM exceeds expected ranges)
