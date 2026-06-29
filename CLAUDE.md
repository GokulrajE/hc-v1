# HC-V1 Godot Device Communication - Implementation Summary

**Status: ✅ WORKING** - Device successfully connected, data structure implemented, user management system complete

## Overview
Implemented a complete device data reading system AND user data management structure in Godot that mirrors the Unity implementation. The system:
- Reads binary sensor data from HyperCube device via serial (COM15 at 115200 baud)
- Manages user sessions with persistent CSV storage
- Supports multi-user workflow with signup/login/assessment flow

**Key Achievements:**
1. ✅ Device communication working with real-time sensor data
2. ✅ Data structure mirroring Unity's DataManager and AppData.Trial
3. ✅ User account management with file persistence
4. ✅ Complete scene flow: Main → Signup/Login → Assessment → Diagnostics

## Project Structure

```
d:\hc-v-1\
├── scripts/
│   ├── appdata.gd                  # Autoloader - Connection & user state management
│   ├── hccomm.gd                   # Autoloader - Serial device communication & data parsing
│   ├── data_manager.gd             # Autoloader - User data persistence (CSV files)
│   ├── app_data_trial.gd           # Autoloader - Trial lifecycle & AROM raw data logging
│   ├── rom.gd                      # ROM class - Range of Motion (AROM only for HyperCube)
│   ├── hypercube_mechanism.gd     # HyperCubeMechanism class - Mechanism with AROM tracking
│   ├── main.gd                     # Main scene - Device & user management
│   ├── signup.gd                   # User registration with file structure creation
│   ├── login.gd                    # User login with data validation
│   ├── assessment.gd               # Mechanism selection & knob selection display
│   ├── mechanism.gd                # Mechanism selection scene controller
│   ├── hand_grip_assessment.gd     # Hand Grip AROM assessment & real-time monitoring
│   ├── knob_assessment.gd          # Knob AROM assessment & real-time monitoring
│   └── diagnostics.gd              # Device sensor data display & monitoring
├── scene/
│   ├── main.tscn                   # Main entry point (Signup/Login/Diagnostics buttons)
│   ├── signup.tscn                 # User registration form
│   ├── login.tscn                  # User login form
│   ├── mechanism.tscn              # Mechanism selection (Hand Grip/Knobs/Tripod Grip)
│   ├── assessment.tscn             # Assessment & knob selection display
│   ├── hand_grip_assessment.tscn   # Hand Grip AROM assessment with real-time monitoring
│   ├── knob_assessment.tscn        # Knob AROM assessment with real-time monitoring
│   ├── knob_progress.tscn          # Reusable knob progress display (CW/CCW fills)
│   └── diagnostics.tscn            # Device sensor data display
├── data/                           # User data directory (created at runtime)
│   └── {hospitalID}/
│       ├── configdata.csv          # User profile info
│       ├── sessions/
│       │   └── sessions.csv        # Trial results
│       ├── rawdata/
│       │   ├── raw-s{s}-t{t}-{move}.csv   # Game trial sensor data
│       │   └── arom-{mech}-{time}.csv     # AROM assessment sensor data
│       ├── rom/
│       │   ├── KNOB.csv            # Knob ROM assessments
│       │   ├── FINE KNOB.csv       # Fine knob ROM assessments
│       │   ├── KEY KNOB.csv        # Key knob ROM assessments
│       │   ├── HAND GRIP.csv       # Hand grip ROM assessments
│       │   └── TRIPOD GRIP.csv     # Tripod grip ROM assessments
│       ├── applog/                 # (future) Application logs
│       └── errorlog/               # (future) Error logs
├── addons/
│   └── gdserial/                   # GdSerial addon for serial communication
├── project.godot                   # Autoload configuration
└── CLAUDE.md                       # This file
```

## Autoloader Architecture

### **AppData Autoloader** (`scripts/appdata.gd`)
Global connection & user state management layer. Registered in `project.godot` as `Appdata`. Extends Node.

**Static Constants:**
```gdscript
const COM_PORT: String = "COM15"
const BAUD_RATE: int = 115200
```

**Static User Variables:**
```gdscript
static var hospital_id: String = ""
static var user_name: String = ""
static var affected_limb: String = ""
static var session_number: int = 0
static var trial_number_day: int = 0
static var trial_number_session: int = 0
static var game_name: String = ""
static var game_time: float = 30.0
static var reach_speed: float = 1.0
static var game_parameter: float = 0.0
static var cumulative_targets: int = 0
static var cumulative_hits: int = 0
static var cumulative_misses: int = 0
static var current_mechanism: String = ""
static var current_side: String = ""
static var mechanisms: Dictionary = {}  # HyperCubeMechanism objects indexed by name
```

**Instance Variables:**
```gdscript
var selected_mechanism = null  # Current HyperCubeMechanism object
```

**Static Methods:**
- `open_connection(port: String = "")` - Opens device connection (non-blocking, only if not connected)
- `close_connection()` - Closes device connection
- `load_user(id: String) -> bool` - Loads user data from config file
- `increment_session()` - Increments session number and resets trial counters
- `get_all_mechanisms() -> Array` - Returns all mechanism objects in the session
- `clear_mechanisms()` - Clears all mechanisms and resets state (for user switch)

**Instance Methods:**
- `set_mechanism(mech_name: String)` - Creates a new HyperCubeMechanism object with given name

**Usage from any script:**
```gdscript
AppData.open_connection()          # Connect to COM15
AppData.close_connection()         # Disconnect from device
AppData.load_user("HOSPITAL123")   # Load user data
var total_force = HCcomm.get_total_force()
```

### **HCComm Autoloader** (`scripts/hccomm.gd`)
Device communication and data parsing. Registered in `project.godot` as `HCcomm`. Extends Node.

**Signals:**
- `device_connected` - Emitted when device successfully connects
- `device_disconnected` - Emitted when device disconnects
- `new_device_data` - Emitted when new sensor data is parsed

**Sensor Properties (all public):**
- Forces: `force_1`, `force_2` 
- Angles: `angle_1`, `angle_2`, `angle_3`, `angle_4`
- Distances: `distance_1`, `distance_2`
- Buttons: `button_1` through `button_7`
- Status: `device_is_connected`

**Key Methods:**
- `connect_device(port: String, baud: int)` - Connect to serial device
- `disconnect_device()` - Disconnect from device
- `get_total_force() -> float` - Returns force_1 + force_2
- `get_btw_distance() -> float` - Calculates distance between sensors
- `get_avg_btw_distance() -> float` - Returns moving average of btw_distance
- `get_formatted_data() -> String` - Returns data as CSV format
- `load_data_format(filename: String) -> bool` - Load data format configuration

**Usage from any script:**
```gdscript
# Connect to signals
HCcomm.device_connected.connect(_on_device_connected)
HCcomm.new_device_data.connect(_on_new_device_data)

# Access sensor data
var force_total = HCcomm.get_total_force()
var is_connected = HCcomm.device_is_connected
```

### **DataManager Autoloader** (`scripts/data_manager.gd`)
User data persistence and file I/O. Registered in `project.godot` as `DataManager`. Extends Node.

**CSV Headers:**
- `CONFIG_HEADER` - User info: HospitalID, Name, Age, Location, AffectedLimb, CreatedDate
- `SESSION_HEADER` - Trial data: SessionNumber, DateTime, TrialNumberDay, TrialNumberSession, TrialStartTime, TrialStopTime, Movement, GameName, ReachSpeed, GameParameter, GameDuration, SuccessRate, MoveTime, CurrentTargets, CurrentHits, CurrentMisses, CumulativeTargets, CumulativeHits, CumulativeMisses, RawDataFileName
- `RAW_HEADER` - Sensor frames: Timestamp, PacketNumber, Force1, Force2, Angle1-4, Distance1-2, Button1-7

**Methods:**
- `get_formatted_datetime() -> String` - Returns formatted datetime string in dd-MM-yyyy HH:mm:ss format
- `get_data_root() -> String` - Returns base data directory (res://data/ in debug, exe_path_data/ in build)
- `get_user_path(hospital_id: String) -> String` - Returns user folder path
- `user_exists(hospital_id: String) -> bool` - Checks if user config exists
- `create_file_structure(hospital_id: String) -> bool` - Creates directory tree
- `create_session_file(hospital_id: String) -> bool` - Creates sessions.csv with header
- `save_config(data: Dictionary) -> bool` - Writes configdata.csv
- `load_config(hospital_id: String) -> Dictionary` - Reads configdata.csv
- `append_session_row(hospital_id: String, row: Array) -> bool` - Adds trial result to sessions.csv
- `create_raw_file(filepath: String) -> bool` - Creates raw data CSV
- `append_raw_row(filepath: String, row: Array) -> bool` - Appends sensor frame
- `load_csv(filepath: String) -> Array` - Generic CSV loader

### **AppDataTrial Autoloader** (`scripts/app_data_trial.gd`)
Trial lifecycle management and raw data logging. Registered in `project.godot` as `AppDataTrial`. Extends Node.

**Static Variables:**
- `trial_start_time: float` - Timestamp when trial started
- `raw_data_buffer: String` - Buffered sensor data for writing
- `current_raw_filepath: String` - Path to current raw data file
- `packet_number: int` - Packet counter for current trial

**Instance Variables (AROM Logging):**
- `arom_logging_active: bool` - AROM logging session state
- `arom_start_time: float` - Timestamp when AROM logging started
- `arom_raw_data_buffer: String` - Buffered AROM sensor data
- `arom_raw_filepath: String` - Path to AROM raw data file
- `arom_packet_number: int` - Packet counter for AROM session
- `arom_mechanism: String` - Current mechanism being assessed
- `arom_knob_type: String` - Knob type being assessed (for knob mechanisms)

**Methods (Trial Logging):**
- `start_new_trial(session: int, trial: int, movement: String)` - Initialize new trial
- `write_frame_data()` - Buffer one sensor frame
- `flush_raw_data()` - Write buffer to disk
- `stop_trial(n_targets: int, n_success: int, n_failure: int)` - Complete trial, write session row

**Methods (AROM Logging):**
- `start_arom_raw_data_logging()` - Start AROM assessment data logging (creates arom-{mechanism}-{datetime}.csv)
- `stop_arom_raw_data_logging()` - Stop AROM logging and write buffered data to file
- `_on_arom_device_data_received()` - Internal handler for device data during AROM logging

**AROM File Format:**
- **Filename:** `arom-{mechanism}-{timestamp}.csv` (e.g., `arom-knob-2026-05-20_10-30-45.csv`)
- **Headers:** Same as raw data (Timestamp, PacketNumber, Force1-2, Angle1-4, Distance1-2, Button1-7)
- **Storage Location:** `data/{hospitalID}/rawdata/`

### **ROM Class** (`scripts/rom.gd`)
Range of Motion assessment data storage for HyperCube device (AROM only). Extends Resource.

**Key Properties:**
- `arom_min`, `arom_max` - Active Range of Motion (patient's unassisted movement)
- `mechanism` - Mechanism name this ROM data belongs to
- `datetime` - Timestamp of assessment

**Key Methods:**
- `set_arom(min: float, max: float)` - Set active ROM values
- `is_arom_set() -> bool` - True when AROM is set
- `is_set() -> bool` - True when AROM is set (HyperCube only has AROM)
- `write_to_assessment_file() -> bool` - Persist ROM data to CSV
- `get_current_arom() -> Array` - Get values as [min, max]

**ROM CSV Format (HyperCube):**
```
DateTime,AromMin,AromMax
19-05-2026 10:30:45,5.0,80.0
```

**Usage:**
```gdscript
var rom = ROM.new("Hand Grip", false)  # Create empty ROM
rom.set_arom(5.0, 80.0)  # Only AROM for HyperCube
if rom.is_set():
	rom.write_to_assessment_file()
```

### **HyperCubeMechanism Class** (`scripts/hypercube_mechanism.gd`)
Rehabilitation mechanism with AROM-only ROM tracking for HyperCube device. Extends Resource.

**Constructor:**
```gdscript
func _init(mechanism_name: String = "", sess_no: int = 1) -> void
```
- `mechanism_name` - Mechanism name (converted to uppercase: "KNOB", "FINE KNOB", "KEY KNOB", etc.)
- `sess_no` - Session number for trial tracking

**Key Properties:**
- `name` - Mechanism name (auto-converted to UPPERCASE)
- `side` - "Left" or "Right" (for future side-specific tracking)
- `old_rom`, `new_rom` - ROM objects for previous and current assessments
- `arom_completed` - AROM assessment flag (HyperCube only)
- `curr_speed` - Current mechanism speed (-1.0 if using default)
- `trial_number_day`, `trial_number_session` - Trial counters
- `DEFAULT_SPEEDS` - Default speed constants for each mechanism (currently 10.0 Hz)

**Key Methods:**
- `_init(mechanism_name: String, sess_no: int)` - Constructor with name and session number
- `is_mechanism(mech_name) -> bool` - Case-insensitive mechanism name check
- `is_side(side_name) -> bool` - Check if mechanism is on given side
- `is_speed_updated() -> bool` - Check if custom speed is set
- `next_trial()` - Increment trial numbers
- `get_current_rom() -> ROM` - Get newRom if set, else oldRom
- `get_current_arom() -> Array` - Get AROM values as [min, max]
- `reset_arom_values()` - Reset AROM to 0.0/0.0 and mark incomplete
- `set_new_arom_values(amin, amax)` - Set AROM and mark completed
- `save_assessment_data() -> bool` - Save ROM when AROM assessment done
- `update_trial_numbers(session_no)` - Update trial counters from session
- `get_speed() -> float` - Get current or default speed
- `set_speed(speed)` - Set custom mechanism speed

**Usage:**
```gdscript
# Via AppData.set_mechanism()
Appdata.set_mechanism("Knob")  # Creates new HyperCubeMechanism("KNOB", session_number)

# Access the mechanism
var mech = Appdata.selected_mechanism
mech.set_new_arom_values(5.0, 80.0)  # Set AROM range
if mech.save_assessment_data():
	print("ROM saved!")
```

### **Diagnostics Script** (`scripts/diagnostics.gd`)
Displays device status and sensor data in real-time.

**Key Features:**
- Accesses HCcomm and AppData autoloaders globally
- Device connection managed by Main scene (preserves connection across scenes)
- Connects to HCcomm signals for real-time updates
- Displays connection status and all 15 sensor values
- Updates at configurable interval (every 5 frames by default)
- Back button returns to Main scene

**Scene Structure:**
```
diagnostices (Node2D) - diagnostics.gd
├── bg (ColorRect) - Background
│   └── Label - Status and sensor data display
└── back_button (Button) - Navigation back to main
```

### **Main Scene** (`scripts/main.gd`)
Central hub for app navigation and device management. Registered in `project.godot` as main scene.

**Key Features:**
- Hospital ID input field for login
- Three main buttons: Signup, Login, Diagnostics
- Device status display (persistent across scenes)
- Device connection on first load only (non-blocking background connection)
- Device signals connected to update status label
- Validates user existence before allowing login

**Behavior:**
- Only connects to device if not already connected (preserves connection across scene changes)
- Displays "Device: CONNECTED" or "Device: NOT CONNECTED"
- All buttons work regardless of device status
- Device connection attempt happens in background

**Navigation:**
- Signup → signup.tscn (create new user)
- Login → mechanism.tscn (load existing user, select mechanism)
- Diagnostics → diagnostics.tscn (view device data)

### **Assessment Scene** (`scripts/assessment.gd`)
Mechanism-specific assessment display. For non-knob mechanisms, shows user information. For Knobs mechanism, shows knob selection buttons.

**Key Features:**
- **For Knobs:** Shows three knob selection buttons (Knob, Fine Knob, Key Knob)
- **For Other Mechanisms:** Displays user information and session details
- **Dynamic Title:** Shows "ASSESS {MechanismName}"
- **Knob Button Integration:** Each knob button calls Appdata.set_mechanism() and loads knob_assessment.tscn
- Back button returns to mechanism scene

**Scene Structure:**
```
Assessment (Node2D) - assessment.gd
├── bg (ColorRect) - Background
├── title (Label) - "ASSESS {Mechanism}"
├── [For Knobs mechanism only]
│   └── knob_buttons_container (HBoxContainer):
│       ├── knob_button (Button) - Select Knob
│       ├── fine_knob_button (Button) - Select Fine Knob
│       └── key_knob_button (Button) - Select Key Knob
├── [For other mechanisms]
│   ├── user_info (Label) - User and session information
│   └── start_button (Button) - Start assessment (future)
└── back_button (Button) - Navigation back to mechanism scene
```

**Knob Selection Flow:**
```
Assessment scene (with current_mechanism = "Knobs")
	↓
Shows three buttons:
	├─ Knob Button → _on_knob_selected()
	│       Appdata.set_mechanism("Knob")
	│       → knob_assessment.tscn
	│
	├─ Fine Knob Button → _on_fine_knob_selected()
	│       Appdata.set_mechanism("Fine Knob")
	│       → knob_assessment.tscn
	│
	└─ Key Knob Button → _on_key_knob_selected()
			Appdata.set_mechanism("Key Knob")
			→ knob_assessment.tscn
```

**Usage Flow (Knob Assessment):**
1. User selects "Knobs" from mechanism scene
2. Assessment scene displays with three knob buttons
3. User clicks knob button (e.g., "Knob")
4. Appdata.set_mechanism("Knob") creates HyperCubeMechanism object
5. Scene changes to knob_assessment.tscn
6. Real-time AROM assessment begins

## Complete Data Flow

### **Device Communication Flow:**
1. **Device sends binary data** → Serial port (COM15)
2. **HCcomm receives & parses** → Extracts 15 sensor values from packet
3. **HCcomm emits signal** → `new_device_data`
4. **Diagnostics/KnobAssessment receive signal** → Updates real-time displays
5. **User sees real-time data** → Forces, angles, distances, buttons

### **User Management & Assessment Flow:**
1. **Signup:**
   - User fills form (Hospital ID, Name, Age, Location, Affected Limb)
   - signup.gd validates all fields non-empty
   - DataManager.create_file_structure() creates d:\hc-v-1\data\{hospitalID}\
   - DataManager.save_config() writes configdata.csv with pre-header metadata
   - DataManager.create_session_file() creates sessions.csv with header
   - Scene returns to Main

2. **Login:**
   - User enters Hospital ID on Main
   - DataManager.user_exists() validates Hospital ID
   - AppData.load_user() reads config and populates static variables
   - AppData.clear_mechanisms() resets mechanism list
   - Scene changes to mechanism.tscn

3. **Mechanism Selection:**
   - User selects rehabilitation mechanism: Hand Grip, Knobs, or Tripod Grip
   - AppData.current_mechanism = selected mechanism (string)
   - Scene changes to assessment.tscn with mechanism context

4. **Assessment (Mechanism-Specific):**
   
   **For Hand Grip / Tripod Grip:**
   - Assessment scene title shows "ASSESS {Mechanism}"
   - Displays user information from AppData
   - Shows session and trial information
   - Shows cumulative statistics
   - Back button returns to mechanism scene
   
   **For Knobs:**
   - Assessment scene shows three knob selection buttons
   - Each button calls Appdata.set_mechanism(knob_name):
	 ```gdscript
	 Appdata.set_mechanism("Knob")
	 # Creates: Appdata.selected_mechanism = HyperCubeMechanism("KNOB", session_number)
	 ```
   - Scene changes to knob_assessment.tscn

5. **Knob AROM Assessment (for Knobs mechanism):**
   - knob_assessment._ready():
	 - Gets reference to Appdata.selected_mechanism
	 - Calls AppDataTrial.start_arom_raw_data_logging()
   - Real-time monitoring loop (100+ Hz):
	 - HCcomm emits new_device_data signal
	 - knob_assessment._on_device_data_received():
	   * Reads angle from HCcomm (angle_2/3/4)
	   * Updates min/max angle tracking
	   * Updates radial progress displays
   - User completes assessment and clicks Save:
	 - AppDataTrial.stop_arom_raw_data_logging() writes arom-{mech}-{time}.csv
	 - Appdata.selected_mechanism.set_new_arom_values(min_angle, max_angle)
	 - Appdata.selected_mechanism.save_assessment_data() writes ROM CSV file
	 - ROM file created at: data/{hospitalID}/rom/{KNOB}.csv
   - Back button returns to mechanism scene

6. **Trial Execution (Future):**
   - AppDataTrial.start_new_trial() creates raw data file
   - AppDataTrial.write_frame_data() buffers each sensor frame
   - AppDataTrial.stop_trial() writes session row to sessions.csv
   - Raw data file created in data/{hospitalID}/rawdata/

### **Mechanism Object System:**
```
User creates mechanism via assessment button click
	↓
Appdata.set_mechanism(name)
	↓
Creates: Appdata.selected_mechanism = HyperCubeMechanism(name.to_upper(), session_number)
	↓
Mechanism stored in: Appdata.mechanisms[name.to_upper()]
	↓
Scene can access: Appdata.selected_mechanism.name, .set_new_arom_values(), .save_assessment_data()
	↓
Each knob type gets its own mechanism object with separate ROM file
```

## Protocol Details

**Binary Packet Structure:**
```
[Header: 0xFF 0xFF] [Size: 1 byte] [Payload: N bytes] [Checksum: 1 byte]
```

**Supported Data Types:**
- `'b'` = byte (1 byte)
- `'i'` = uint16 (2 bytes)
- `'f'` = float (4 bytes)

**Device Connection Parameters:**
- Port: **COM15** (configurable via AppData.COM_PORT)
- Baud Rate: **115200** (configurable via AppData.BAUD_RATE)
- Connection Timeout: **2000ms**

## Scene Flow

```
Main (main.tscn)
  ├── Signup Button → signup.tscn → creates user folder & config → back to Main
  ├── Login Button → Validates Hospital ID → Appdata.load_user() → mechanism.tscn
  └── Diagnostics Button → diagnostics.tscn (device data, no login required)

Mechanism (mechanism.tscn) - MECHANISM SELECTION
  ├── Hand Grip Button → Appdata.set_mechanism("Hand Grip")
  │   ├── If AROM done: Show message + stay
  │   └── If new: Show message → hand_grip_assessment.tscn
  ├── Knobs Button → Sets Appdata.current_mechanism = "Knobs" → assessment.tscn
  ├── Tripod Grip Button → Sets Appdata.current_mechanism = "Tripod Grip" → assessment.tscn
  └── Back Button → Main

Assessment (assessment.tscn) - MECHANISM-SPECIFIC DISPLAY
  If mechanism is "Knobs":
	├── Shows three knob selection buttons:
	│   ├── Knob Button → Appdata.set_mechanism("Knob") → knob_assessment.tscn
	│   ├── Fine Knob Button → Appdata.set_mechanism("Fine Knob") → knob_assessment.tscn
	│   └── Key Knob Button → Appdata.set_mechanism("Key Knob") → knob_assessment.tscn
	└── Back Button → mechanism.tscn
  
  If mechanism is other (Hand Grip, Tripod Grip):
	├── Title shows: "ASSESS {Mechanism}"
	├── Shows user info from Appdata
	├── Displays session & trial information
	├── Shows cumulative statistics
	├── Start Trial button (future)
	└── Back Button → mechanism.tscn

HandGripAssessment (hand_grip_assessment.tscn) - HAND GRIP AROM ASSESSMENT
  ├── Title: "HAND GRIP"
  ├── Real-time grip angle monitoring (angle_1)
  ├── Radial progress bars with needle indicator
  ├── Min/max/current angle values
  ├── Device connection status
  ├── Save Button → Saves AROM values & ROM to CSV
  └── Back Button → mechanism.tscn

KnobAssessment (knob_assessment.tscn) - KNOB AROM ASSESSMENT
  ├── Title: Selected knob name (e.g., "KNOB", "FINE KNOB")
  ├── Real-time angle monitoring with radial progress
  ├── Min/max/current angle values
  ├── Device connection status
  ├── Save Button → Saves AROM values & ROM to CSV
  └── Back Button → mechanism.tscn

Diagnostics (diagnostics.tscn)
  ├── Real-time device sensor display
  ├── Shows all 15 sensor values (forces, angles, distances, buttons)
  └── Back Button → main.tscn
```

## Assessment Implementation Details

### **Purpose:**
Bridge between login and actual therapeutic sessions. Displays verified user information and current session state.

### **Implementation** (`scripts/assessment.gd`):
```gdscript
extends Node2D

var back_button: Button

func _ready() -> void:
	back_button = get_node_or_null("back_button")
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _display_user_info() -> void:
	# Reads from AppData static variables populated by load_user()
	text = "Hospital ID: %s\n" % AppData.hospital_id
	text += "Name: %s\n" % AppData.user_name
	text += "Affected Limb: %s\n" % AppData.affected_limb
	text += "Session: %d\n" % AppData.session_number
	# ... more fields

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/main.tscn")
```

### **Data Source:**
- All displayed data comes from **AppData** static variables
- These are populated by `AppData.load_user(hospital_id)` called from main.gd login
- Data is read from `data/{hospitalID}/configdata.csv` by DataManager.load_config()

### **User Information Displayed:**
1. **Patient Identity:**
   - Hospital ID
   - Full Name
   - Age (from config file)
   - Location/Facility (from config file)
   - Affected Limb (Left/Right)

2. **Session State:**
   - Current Session Number
   - Trial Number (Day)
   - Trial Number (Session)
   - Device Port (COM15)

3. **Cumulative Statistics:**
   - Total Targets presented
   - Total Hits achieved
   - Total Misses
   - Success rate (calculated as: hits/targets * 100%)

### **Design Rationale:**
- **Non-modifiable display:** Assessment is read-only, user cannot edit loaded data
- **State verification:** Confirms user data was correctly loaded from storage
- **Session continuity:** Shows ongoing session context before starting exercises
- **Simple navigation:** Single back button for non-modal flow
- **Minimal UI:** Focuses on information clarity without distractions

### **Implementation Status: ✅ COMPLETE**

**Implemented Features:**
- ✅ User information display (Hospital ID, Name, Affected Limb)
- ✅ Session details display (Session #, Trial #, Device Port)
- ✅ Cumulative statistics with success rate calculation
- ✅ Automatic population from AppData variables
- ✅ Read-only display format
- ✅ Navigation back to Main scene
- ✅ Error handling for missing user_info label

**Code Structure:**
- Uses `user_info_label` node to display formatted text
- Calls `_display_user_info()` in `_ready()` to populate on scene load
- Calculates success rate: `(hits / targets) * 100%`
- Displays formatted text with section headers and proper spacing
- Non-blocking, read-only interface

### **Future Enhancements:**
- Start Trial button to begin data logging
- Select Movement dropdown for exercise type
- Start Game button to launch therapeutic application
- Session notes or comments field
- Edit profile link (return to signup to modify)
- Download session report button
- Reset session data option
- Session history navigation

## Assessment & Knob Assessment - Complete Flow

### **Step-by-Step Execution (Knob Assessment Flow):**

1. **Main Scene (Login):**
   ```
   User enters Hospital ID → Clicks Login
   ↓
   main.gd._on_login_pressed():
	 - Validates Hospital ID not empty
	 - Checks DataManager.user_exists(hospital_id)
	 - Calls AppData.load_user(hospital_id)
   ↓
   AppData.load_user(id):
	 - Calls DataManager.load_config(id)
	 - Reads d:\hc-v-1\data\{id}\configdata.csv
	 - Populates all static variables:
	   * hospital_id, user_name, affected_limb
	   * session_number = 1, trial_number_day = 1
	   * cumulative_targets/hits/misses = 0
	 - AppData.clear_mechanisms() resets mechanism list
   ↓
   Scene changes to mechanism.tscn
   ```

2. **Mechanism Selection Scene:**
   ```
   User selects "Knobs" from mechanism.tscn
   ↓
   mechanism.gd._on_knobs_pressed():
	 - AppData.current_mechanism = "Knobs"
   ↓
   Scene changes to assessment.tscn
   ```

3. **Assessment Scene (Knob Selection):**
   ```
   assessment.gd._ready():
	 - Gets references to knob buttons and other nodes
	 - Connects button signals
	 - Calls _update_title() and _update_ui()
   ↓
   _update_title():
	 - Sets title to "ASSESS Knobs"
   ↓
   _update_ui():
	 - Checks if "Knobs" in AppData.current_mechanism
	 - Shows knob_buttons_container (three buttons)
	 - Hides start_button and user_info label
   ↓
   User sees: Three buttons - Knob, Fine Knob, Key Knob
   ```

4. **Knob Selection & Mechanism Creation:**
   ```
   User clicks "Knob" button
   ↓
   assessment.gd._on_knob_selected():
	 - Appdata.set_mechanism("Knob")
   ↓
   AppData.set_mechanism(name):
	 - selected_mechanism = HyperCubeMechanism.new("Knob", session_number)
	   Creates: HyperCubeMechanism("KNOB", 1)
	 - Mechanism stored in mechanisms dictionary
   ↓
   Scene changes to knob_assessment.tscn
   ```

5. **Knob Assessment Scene (Real-time Monitoring):**
   ```
   knob_assessment.gd._ready():
	 - Gets node references (labels, progress bars)
	 - Stores selected_knob = Appdata.selected_mechanism.name ("KNOB")
	 - Connects to HCcomm signals: new_device_data, device_connected, device_disconnected
	 - Calls _start_arom_raw_logging()
	   AppDataTrial.start_arom_raw_data_logging()
	   Creates: arom-knob-2026-05-20_10-30-45.csv
	 - Calls _update_title() → Sets title to "KNOB"
	 - Calls _update_status()
   ↓
   Device connection established, AROM logging active
   ```

6. **Real-time Angle Monitoring (100+ Hz loop):**
   ```
   HCcomm detects new sensor packet
   ↓
   HCcomm emits new_device_data signal
   ↓
   knob_assessment._on_device_data_received():
	 - current_angle = _get_current_angle()
	   match selected_knob "KNOB":
		 return HCcomm.angle_2  (≈12.45°)
   ↓
	 - Update knob_1_angle_label.text = "12.45°"
	 - Update current_label.text = "Current: 12.45°"
   ↓
	 - _update_min_max():
	   if current_angle < min_angle: min_angle = current_angle
	   if current_angle > max_angle: max_angle = current_angle
	   Update min_label and max_label
   ↓
	 - _update_knob_progress():
	   knob_progress_cw.radial_fill_degrees = max_angle
	   knob_progress_ccw.radial_fill_degrees = abs(min_angle)
   ↓
   User sees real-time angle display + min/max tracking + visual progress bars
   ```

7. **Assessment Completion (User clicks Save):**
   ```
   User rotates knob through full range (e.g., -25° to +45°)
   User clicks Save button
   ↓
   knob_assessment._on_save_pressed():
	 - Validates measurements exist
	 - AppDataTrial.stop_arom_raw_data_logging()
	   Disconnects from HCcomm signal
	   Writes buffered data to arom-knob-2026-05-20_10-30-45.csv (4523 packets)
   ↓
	 - Appdata.selected_mechanism.set_new_arom_values(-25.0, 45.0)
	   Sets new_rom.arom_min = -25.0
	   Sets new_rom.arom_max = 45.0
	   Sets arom_completed = true
   ↓
	 - Appdata.selected_mechanism.save_assessment_data()
	   Calls new_rom.write_to_assessment_file()
	   Creates/Updates: data/H001/rom/KNOB.csv
	   Appends: 20-05-2026 10:30:45,-25.0,45.0
   ↓
	 - status_label.text = "Success: Assessment saved! AROM: -25.00° to 45.00°"
   ```

8. **Return to Mechanism Selection:**
   ```
   User clicks Back button
   ↓
   knob_assessment._on_back_pressed():
	 - Scene changes to mechanism.tscn
	 - Appdata.selected_mechanism preserved (stays in memory)
	 - AppDataTrial internal state reset (files closed)
   ↓
   User can select different knob or different mechanism
   ```

### **Data Flow Summary:**
```
CSV User File → DataManager → AppData static vars → Mechanism Selection
data/{id}/configdata.csv    load_config()        hospital_id, session_number
							
												 ↓
												 
Mechanism Selection → Assessment → Knob Selection → HyperCubeMechanism Object
"Knobs"               Button          "Knob"      selected_mechanism
												 
												 ↓
												 
Real-time Sensor Loop → Min/Max Tracking → Save Assessment → ROM CSV File
HCcomm signals        min_angle=-25°      save_assessment()  data/{id}/rom/KNOB.csv
					  max_angle=45°                         -25.0,45.0
					  
												 ↓
												 
Raw Sensor Data File → AROM CSV
arom-knob-{time}.csv  4523 packets logged during assessment
```

## How to Run

1. **Start the application:**
   - Open Godot project
   - Main scene is `res://scene/main.tscn`
   - Press Play (F5)

2. **Create a new user (Signup):**
   - Click "Signup" button on Main
   - Fill form: Hospital ID, Name, Age, Location, Affected Limb
   - Click "Save"
   - Data folder created at: `d:\hc-v-1\data\{hospitalID}\`
   - Returns to Main

3. **Login existing user:**
   - Enter Hospital ID on Main
   - Click "Login" button
   - Assessment scene shows loaded user info
   - Click "Back" to return to Main

4. **View device diagnostics:**
   - Click "Diagnostics" button (requires device connected)
   - Shows real-time sensor data
   - Click "Back" to return to Main

5. **Device connection:**
   - Device connection happens automatically in background
   - Status shown on Main scene: "Device: CONNECTED" or "Device: NOT CONNECTED"
   - Connection persists across scene changes

## Console Output Examples

**Successful Connection:**
```
=== Available COM Ports ===
Found 1 port(s):
  Port: COM15
	Type: USB Device
	Device: HyperCube Device
===========================

HCComm _ready() starting...
Attempting to load data format from: res://jeditextformat.txt
Data format loaded: fffffffffffffff (size: 60)
DEBUG: Checksum validation DISABLED - accepting all packets
HCComm: opening COM15 at 115200 baud...
✓ HCComm: COM15 opened!
Device connected!
```

**Failed Connection:**
```
HCComm: opening COM15 at 115200 baud...
✗ HCComm: failed to open COM15
Device disconnected!
```

## Troubleshooting

### Device Not Connecting

**Check 1: Is the device on COM15?**
- Verify device is connected to correct COM port
- Open Device Manager (Windows) to confirm COM port
- Change default port in `appdata.gd` if different:
  ```gdscript
  const COM_PORT: String = "COMX"
  ```

**Check 2: Is GdSerial addon enabled?**
- Go to Project > Project Settings > Plugins
- Ensure "GdSerial" is enabled
- Restart Godot if you enabled it

**Check 3: Is baud rate correct?**
- Default: 115200
- Verify device baud rate matches
- Change in `appdata.gd` if different:
  ```gdscript
  const BAUD_RATE: int = 115200
  ```

**Check 4: Data format file**
- Optional file: `res://jeditextformat.txt`
- If not found, script defaults to 15 floats (60 bytes)
- Device will work without it

### Display Shows "Device: NOT CONNECTED"

This means:
1. Device is not connected to configured COM port, OR
2. GdSerial addon is not available, OR
3. Device is not powered on

Check the console output for specific error message.

## Implemented Features (from Unity)

**Device Communication:**
✅ Autoloader architecture for global access
✅ Binary packet parsing with checksum validation
✅ Data format configuration system  
✅ 15 sensor values extraction (2 forces, 4 angles, 2 distances, 7 buttons)
✅ Moving average calculation for inter-sensor distance
✅ Signal-based event system
✅ Real-time display updates
✅ Connection status indicators
✅ Error handling and logging
✅ Non-blocking device connection (preserves across scene changes)

**Data Management:**
✅ User account creation (signup with form validation)
✅ User authentication (login by Hospital ID)
✅ File structure creation matching Unity pattern
✅ CSV data persistence (config + sessions + raw data)
✅ Pre-header format for CSV files (metadata preservation)
✅ Session management with trial tracking
✅ Raw sensor data logging per trial
✅ Cumulative statistics (targets, hits, misses)
✅ Project path vs built game path handling

## Using the System in Custom Scripts

### **Device Communication:**
```gdscript
# In any script
func _ready():
	# Connect to device
	AppData.open_connection()
	
	# Listen for device events
	HCcomm.device_connected.connect(_on_connected)
	HCcomm.new_device_data.connect(_on_data_received)

func _on_data_received():
	# Access sensor data directly
	print("Force total: ", HCcomm.get_total_force())
	print("Angle 1: ", HCcomm.angle_1)
	print("Button 1: ", HCcomm.button_1)

func _on_connected():
	print("Device is ready!")
	AppData.close_connection()
```

### **Mechanism & AROM Assessment:**
```gdscript
# Create a mechanism (typically called from assessment button)
func _on_knob_selected():
	Appdata.set_mechanism("Knob")  # Creates HyperCubeMechanism("KNOB", session_number)

# Access the current mechanism
func _ready():
	var mech = Appdata.selected_mechanism
	print("Current mechanism: ", mech.name)  # Output: "KNOB", "FINE KNOB", etc.

# Start AROM assessment
func start_assessment():
	AppDataTrial.start_arom_raw_data_logging()  # Begin recording sensor data

# Set AROM values (min/max angles)
func set_arom_values(min_val: float, max_val: float):
	var mech = Appdata.selected_mechanism
	mech.set_new_arom_values(min_val, max_val)  # Set AROM range
	if mech.save_assessment_data():
		print("ROM saved successfully!")

# Stop AROM assessment and write files
func stop_assessment():
	AppDataTrial.stop_arom_raw_data_logging()  # Write arom-{mech}-{time}.csv
```

### **User Management:**
```gdscript
# Load user (called at login)
func login_user(hospital_id: String):
	if AppData.load_user(hospital_id):
		print("User loaded: ", AppData.user_name)
	else:
		print("User not found")

# Switch to new user
func switch_user(new_hospital_id: String):
	AppData.clear_mechanisms()  # Clear all mechanisms from previous user
	AppData.load_user(new_hospital_id)
```

## Architecture Benefits

1. **Global Access** - No need to pass references, use `AppData` and `HCcomm` anywhere
2. **Clean Separation** - AppData handles connection logic, HCComm handles communication
3. **Event-Driven** - Signals allow loosely-coupled updates across your game
4. **Configurable** - Change port/baud rate in AppData without touching device code

## Working Data Display

The diagnostics screen now successfully displays:

```
=== HyperCube Device Diagnostics ===
Status: CONNECTED

FORCES:
  Force 1: 45.23
  Force 2: 32.15
  Total: 77.38

ANGLES:
  Angle 1: 12.45°
  Angle 2: -8.90°
  Angle 3: -5.32°
  Angle 4: 15.67°

DISTANCES:
  Distance 1: 5.45
  Distance 2: 4.98
  Between: 0.77
  Avg Between: 0.75

BUTTONS: 0 0 0 1 0 0 0
```

Updates are received as packets arrive from the device (~100+ packets per second).

## Data Storage Details

**User Config File** (`data/{hospitalID}/configdata.csv`):
```
:Location: Hospital Name
:Device: HC-V1
:User: hospitalID
HospitalID,Name,Age,Location,AffectedLimb,CreatedDate
H001,John Doe,45,Main Hospital,Left,20-05-2026 10:30:45
```

**Sessions File** (`data/{hospitalID}/sessions/sessions.csv`):
```
SessionNumber,DateTime,TrialNumberDay,TrialNumberSession,TrialStartTime,TrialStopTime,Movement,GameName,ReachSpeed,GameParameter,GameDuration,SuccessRate,MoveTime,CurrentTargets,CurrentHits,CurrentMisses,CumulativeTargets,CumulativeHits,CumulativeMisses,RawDataFileName
1,19-05-2026 10:35:20,1,1,0.00,30.45,Flexion,ReachGame,1.0,5.0,30.45,85.5,28.50,10,9,1,10,9,1,raw-s01-t001-flexion.csv
```

**Raw Data File** (`data/{hospitalID}/rawdata/raw-s{session}-t{trial}-{movement}.csv`):
```
Timestamp,PacketNumber,Force1,Force2,Angle1,Angle2,Angle3,Angle4,Distance1,Distance2,Button1,Button2,Button3,Button4,Button5,Button6,Button7
0.000,1,45.23,32.15,12.45,-8.90,-5.32,15.67,5.45,4.98,0,0,0,1,0,0,0
0.010,2,45.89,32.45,12.67,-8.75,-5.20,15.80,5.50,5.00,0,0,0,1,0,0,0
```

## Future Enhancements

**Device Features:**
- Fix checksum validation to match device protocol exactly
- Advanced error recovery and automatic reconnection
- Device firmware info and diagnostics display
- Real-time signal strength indicator
- Data filtering and smoothing options
- Multi-device support (multiple HyperCube devices)

**Data & Analytics:**
- Historical data graphing and visualization
- Session reports and statistics dashboard
- Data export to multiple formats (Excel, JSON)
- Batch data processing and analysis
- Data backup and archival system

**UI/UX:**
- Calibration UI for ROM values
- Session replay/review functionality
- Performance metrics dashboard
- Custom user preferences
- Role-based access control (admin/therapist/patient)

## Production Readiness

### **Core Features - READY:**
✅ Device connection working with persistence across scenes
✅ Device data parsing functional (15 sensor values)
✅ Real-time sensor display updating
✅ User data management system complete (CRUD operations)
✅ File I/O error handling in place
✅ Console logging for debugging
✅ Autoloader architecture implemented (AppData, HCcomm, DataManager, AppDataTrial)
✅ Signup workflow with form validation and folder creation
✅ Login workflow with user validation and mechanism selection
✅ Mechanism selection scene (Hand Grip, Knobs, Tripod Grip)
✅ Assessment scene with mechanism-specific displays
✅ Knob selection and individual knob assessment
✅ AROM assessment with real-time angle monitoring (min/max tracking)
✅ Radial progress display for knob rotation (CW/CCW directions)
✅ AROM data logging to separate CSV files (arom-{mech}-{time}.csv)
✅ ROM persistence system (separate assessment files per mechanism)
✅ HyperCubeMechanism object-based system
✅ Mechanism object creation and storage
✅ Data structure matches Unity implementation
✅ CSV persistence with pre-header metadata format
✅ Success rate calculation for sessions
✅ Non-blocking device connection (preserves state)
✅ Navigation between all scenes working

### **Testing Features - READY:**
✅ Diagnostics scene for device testing
✅ Device status indicator on Main scene
✅ Real-time sensor value display
✅ Device signal connectivity (connected/disconnected events)

### **Known Limitations:**
⚠️ Checksum validation disabled in HCcomm (device works without it)
⚠️ No data encryption (suitable for local/internal use only)
⚠️ No backup/restore system yet
⚠️ No concurrent user support (single user session at a time)
⚠️ No multi-user session tracking (single session per user ID)

## Known Limitations

- Device must be on COM15 (configurable in AppData.COM_PORT)
- Data stored in plain text CSV (no encryption)
- No concurrent user support (single user at a time)
- No cloud sync or remote backup
- Raw data files can grow large for long sessions

## Notes

- The application successfully communicates with HyperCube device on COM15
- User accounts and session data persist in d:\hc-v-1\data\{hospitalID}\
- All 15 sensor values are being extracted and displayed correctly
- Autoloader structure enables clean, global access to device and user data
- Packet reception rate: 100+ packets per second
- Device connection persists across scene changes (non-blocking)
- CSV files use pre-header lines (:Location:, :Device:, :User:) for metadata

## Mechanism Scene Implementation

### **Purpose:**
Allow users to select the rehabilitation mechanism (Hand Grip, Knobs, Tripod Grip) before starting assessment. Single Assessment scene handles all mechanism types.

### **Implementation:**

#### **1. AppData Update:**
Added mechanism variable to track current selection:
```gdscript
static var current_mechanism: String = ""
```

#### **2. Mechanism Scene** (`scene/mechanism.tscn`):
- Title: "Select Mechanism"
- Three buttons: Hand Grip, Knobs, Tripod Grip
- Message label for feedback
- Back button for navigation

#### **3. Mechanism Script** (`scripts/mechanism.gd`):
```gdscript
extends Node2D

func _on_hand_grip_pressed() -> void:
	AppData.current_mechanism = "Hand Grip"
	get_tree().change_scene_to_file("res://scene/assessment.tscn")

func _on_knobs_pressed() -> void:
	AppData.current_mechanism = "Knobs"
	get_tree().change_scene_to_file("res://scene/assessment.tscn")

func _on_tripod_grip_pressed() -> void:
	AppData.current_mechanism = "Tripod Grip"
	get_tree().change_scene_to_file("res://scene/assessment.tscn")
```

#### **4. Assessment Scene Updates:**
- Title dynamically shows: "ASSESS {Mechanism}" when mechanism selected
- Shows current mechanism in user information
- Back button returns to Mechanism scene if mechanism is selected

### **Scene Flow:**
```
Main (Login) → Mechanism Selection → Assessment → Diagnostics
			  [Hand Grip/Knobs/Tripod] [Shows ASSESS {Mechanism}]
```

### **Data Flow:**
```
User selects mechanism
  ↓
AppData.current_mechanism = "Hand Grip" (or other)
  ↓
Navigate to Assessment scene
  ↓
Assessment title updates to "ASSESS Hand Grip"
  ↓
User information shows "Current Mechanism: Hand Grip"
```

### **Features:**
- ✅ Three mechanism buttons with clear labels
- ✅ Global mechanism access via AppData.current_mechanism
- ✅ Dynamic Assessment title based on selected mechanism
- ✅ Single Assessment scene handles all mechanisms
- ✅ Back navigation between scenes
- ✅ Mechanism persists during session
## Knob Assessment Implementation

### **Purpose:**
Real-time monitoring of individual knob rotation angles (KNOB, FINE KNOB, KEY KNOB) with dual-direction radial progress indicators, min/max angle tracking, and AROM assessment data persistence.

### **Implementation Structure (v3.0):**

#### **1. Assessment Scene - Knob Selection:**
When "Knobs" mechanism is selected from mechanism scene, assessment displays three buttons:
- **Knob Button** - Selects angle_2 monitoring, creates HyperCubeMechanism("Knob", session)
- **Fine Knob Button** - Selects angle_4 monitoring, creates HyperCubeMechanism("Fine Knob", session)
- **Key Knob Button** - Selects angle_3 monitoring, creates HyperCubeMechanism("Key Knob", session)

Button handlers call `Appdata.set_mechanism()`:
```gdscript
func _on_knob_selected() -> void:
	Appdata.set_mechanism("Knob")
	get_tree().change_scene_to_file("res://scene/knob_assessment.tscn")
```

This creates: `Appdata.selected_mechanism = HyperCubeMechanism("KNOB", session_number)`

#### **2. Knob Assessment Scene** (`scene/knob_assessment.tscn`):
Flexible scene that displays the selected knob type with real-time angle monitoring:
- **Dynamic Title** - Shows selected knob name from `Appdata.selected_mechanism.name`
- **Knob Angle Display** - Large real-time angle value in degrees
- **Radial Progress Bars** - CW/CCW TextureProgressBar for dual-direction rotation
- **Min/Max/Current Values** - Tracked and displayed during session
- **Device Status Label** - Shows connection state and AROM logging status
- **Save Button** - Saves assessed AROM values to mechanism ROM file

#### **3. Radial Progress Implementation:**
Uses TextureProgressBar with radial_fill_degrees based on angle sign:
```gdscript
func _update_knob_progress() -> void:
	knob_progress_cw.radial_fill_degrees = max_angle      # Clockwise max fill
	knob_progress_ccw.radial_fill_degrees = abs(min_angle) # CCW min fill (absolute)
```

#### **4. Angle Tracking & AROM Measurement:**
Tracks min/max angles during assessment session:
```gdscript
var min_angle = 0.0  # Lowest angle reached
var max_angle = 0.0  # Highest angle reached
var current_angle = 0.0  # Real-time value

func _update_min_max() -> void:
	if current_angle < min_angle:
		min_angle = current_angle
	if current_angle > max_angle:
		max_angle = current_angle
```

These min/max values become the AROM assessment result when saved.

#### **5. Scene Layout** (`scene/knob_assessment.tscn`):
```
KnobAssessment (Node2D) - knob_assessment.gd
├── knob_1_title (Label) - Shows selected knob name (e.g., "KNOB")
├── knob_1_angle (Label) - Large angle display (e.g., "12.45°")
├── knob_progress (Node2D instance):
│   ├── knob_2_progress_cw (TextureProgressBar) - Clockwise fill
│   └── knob_2_progress_ccw (TextureProgressBar) - Counter-clockwise fill
├── min_max_container (VBoxContainer):
│   ├── min_label (Label) - "Min: -25.32°"
│   ├── max_label (Label) - "Max: 45.67°"
│   └── current_label (Label) - "Current: 12.45°"
├── status_label (Label) - Device/AROM logging status
├── save_button (Button) - Saves AROM assessment data
└── back_button (Button) - Returns to mechanism.tscn
```

#### **6. Script Implementation** (`scripts/knob_assessment.gd`):
**Variables:**
```gdscript
var selected_knob: String  # e.g., "KNOB", "FINE KNOB", "KEY KNOB"
var min_angle, max_angle, current_angle: float
var current_mechanism  # Reference to Appdata.selected_mechanism
```

**Key Functions:**
- `_ready()` - Initialize nodes, connect to HCcomm signals, start AROM logging
- `_get_current_angle() -> float` - Returns correct angle based on selected_knob
- `_on_device_data_received()` - Updates angle displays and tracking on each packet
- `_update_min_max()` - Tracks min/max angle values
- `_update_knob_progress()` - Updates radial progress bars based on min/max angles
- `_update_title()` - Sets title to selected knob name
- `_update_status()` - Displays device connection and AROM logging status
- `_start_arom_raw_logging()` - Calls AppDataTrial.start_arom_raw_data_logging()
- `_on_save_pressed()` - Validates measurements, saves AROM, writes ROM file
- `_on_back_pressed()` - Returns to mechanism scene

**Real-time Data Flow:**
```
HCcomm.new_device_data signal (100+ packets/sec)
	↓
_on_device_data_received():
	├─ current_angle = _get_current_angle() [reads angle_2/3/4]
	├─ Update knob_1_angle_label ("12.45°")
	├─ Update current_label ("Current: 12.45°")
	├─ _update_min_max() [tracks min/max]
	└─ _update_knob_progress() [updates CW/CCW fills]
	
User sees real-time angle display + min/max tracking
```

#### **7. AROM Data Persistence:**
When user clicks Save:
```gdscript
func _on_save_pressed() -> void:
	# Stop AROM raw data logging
	AppDataTrial.stop_arom_raw_data_logging()
	
	# Set AROM values (min/max from tracking)
	Appdata.selected_mechanism.set_new_arom_values(min_angle, max_angle)
	
	# Save to ROM assessment file
	if Appdata.selected_mechanism.save_assessment_data():
		status_label.text = "Success: Assessment data saved! AROM: %.2f° to %.2f°" % [min_angle, max_angle]
```

**Output Files Created:**
1. **AROM Raw Data:** `data/{hospitalID}/rawdata/arom-{knob}-{timestamp}.csv`
   - Contains all sensor packets during assessment
   - Headers: Timestamp, PacketNumber, Force1, Force2, Angle1-4, Distance1-2, Button1-7

2. **ROM Assessment:** `data/{hospitalID}/rom/{KNOB}.csv`
   - One row per assessment session
   - Format: DateTime,AromMin,AromMax
   - Example: `2026-05-20 10:30:45,5.0,80.0`

#### **8. Assessment Scene Integration** (`scripts/assessment.gd`):
**When "Knobs" mechanism selected:**
- Shows three knob selection buttons
- Hides start_button, shows knob_buttons_container
- Button callbacks use `Appdata.set_mechanism()` instead of string assignment

#### **9. Navigation Flow:**
```
Mechanism Scene (Click "Knobs")
	↓
Assessment Scene (Shows three knob buttons)
	├─ Click "Knob"
	├─ Click "Fine Knob"  ─→ Appdata.set_mechanism(name)
	└─ Click "Key Knob"       ↓
						 knob_assessment.tscn
						 ↓
					Real-time AROM Assessment
					(min/max angle tracking)
						 ↓ (Click Save)
					ROM data persisted to CSV
						 ↓ (Click Back)
					Returns to mechanism.tscn
```

#### **Implementation Status: ✅ COMPLETE**

**Features Implemented:**
- ✅ Three knob selection buttons with mechanism object creation
- ✅ Dynamic knob_assessment scene for all three knob types
- ✅ Real-time angle monitoring with min/max tracking
- ✅ Radial progress bars (CW for max, CCW for min)
- ✅ Device signal integration (100+ updates/sec)
- ✅ AROM raw data logging (via AppDataTrial)
- ✅ Save button with validation and ROM persistence
- ✅ Status indicator for device connection and logging state
- ✅ Mechanism object integration (HyperCubeMechanism)
- ✅ Connection status monitoring

**Data Flow Summary:**
```
Assessment Scene
	↓
Appdata.set_mechanism("Knob")
	↓ Creates HyperCubeMechanism object
knob_assessment.tscn loaded
	↓
Appdata.selected_mechanism.name = "KNOB"
AppDataTrial.start_arom_raw_data_logging()
	↓ Starts sensor packet recording
Real-time monitoring: min/max angle tracking
	↓ User rotates knob, sees angle updates
Click Save button
	↓
Appdata.selected_mechanism.set_new_arom_values(min_angle, max_angle)
Appdata.selected_mechanism.save_assessment_data()
	↓ Writes ROM file
AppDataTrial.stop_arom_raw_data_logging()
	↓ Writes AROM raw data file
Assessment saved and files persisted
```

**Example Session Output:**
```
=== ASSESS KNOBS ===
Real-time Knob Angle Monitoring

Knob Type: KNOB
Current Angle: 12.45°

Min: -25.32°
Max: 45.67°
Current: 12.45°

Device Status: CONNECTED - Real-time Monitoring Active

[Circular Progress Visualization with CW/CCW fills]

[Save Button] [Back Button]

--- After Save ---
Success: Assessment data saved! AROM: -25.32° to 45.67°

--- Files Created ---
1. arom-knob-2026-05-20_10-30-45.csv (4523 packets)
2. rom/KNOB.csv (1 row with assessment date and AROM range)
```

## Hand Grip Assessment Implementation

### **Purpose:**
Real-time monitoring of hand grip strength/range using angle_1 sensor with visual needle indicator, min/max tracking, and AROM assessment data persistence.

### **Key Features:**

#### **1. Mechanism Selection Integration:**
When "Hand Grip" button selected in mechanism.tscn:
- Creates HyperCubeMechanism("Hand Grip", session_number)
- Checks if AROM already completed: `old_rom.is_arom_set()`
- **If completed:** Shows message with saved AROM values (Min/Max) - stays on mechanism screen
- **If new:** Shows message and navigates to hand_grip_assessment.tscn

#### **2. Real-time Assessment Monitoring:**
- **Sensor:** angle_1 (hand grip angle)
- **Display:** Large real-time angle value in degrees
- **Visual Indicator:** Needle sprite rotating with current angle
- **Progress Bars:** Radial fill showing min/max range (CW for max, CCW for min)
- **Min/Max Tracking:** Auto-tracks during grip squeeze session

#### **3. Hand Grip Assessment Script** (`scripts/hand_grip_assessment.gd`):

**Key Methods:**
- `_get_current_angle() -> float` - Returns angle_1 from HCcomm
- `_on_device_data_received()` - Updates all displays at 100+ Hz
- `_update_min_max()` - Tracks squeeze range
- `_update_grip_progress()` - Updates progress bars
- `_update_needle_rotation()` - Rotates visual needle
- `_start_arom_raw_logging()` - Begins sensor recording
- `_on_save_pressed()` - Saves AROM assessment to ROM file

#### **4. Real-time Data Flow:**
```
HCcomm.new_device_data signal (100+ packets/sec)
	↓
_on_device_data_received():
	├─ current_angle = HCcomm.angle_1
	├─ Update angle display (e.g., "45.67°")
	├─ Track min/max values
	├─ Update progress bars (CW/CCW fills)
	└─ Update needle rotation

User sees real-time grip angle + visual feedback
```

#### **5. Scene Structure** (`hand_grip_assessment.tscn`):
```
HandGripAssessment (Node2D)
├── grip_title (Label) - "HAND GRIP"
├── grip_angle (Label) - Large angle display
├── grip_progress (Node2D):
│   ├── grip_progress_cw (TextureProgressBar)
│   ├── grip_progress_ccw (TextureProgressBar)
│   └── needle (Sprite2D) - Visual needle
├── min_max_container (VBoxContainer):
│   ├── min_label (Label) - "Min: X.XX°"
│   ├── max_label (Label) - "Max: X.XX°"
│   └── current_label (Label) - "Current: X.XX°"
├── status_label (Label) - Device connection status
├── save_button (Button) - Saves assessment
└── back_button (Button) - Returns to mechanism.tscn
```

#### **6. Assessment Workflow:**

**First Assessment (No Prior Data):**
1. User clicks "Hand Grip" button on mechanism.tscn
2. Message: "Starting AROM assessment for Hand Grip..."
3. Waits 0.5 seconds
4. Opens hand_grip_assessment.tscn
5. Real-time monitoring begins (angle_1 updates at 100+ Hz)
6. User squeezes handle through full range
7. Min/max values auto-tracked
8. User clicks Save
9. AROM values saved to ROM file: `data/{id}/rom/HAND_GRIP.csv`
10. Returns to mechanism.tscn

**Subsequent Selection (AROM Complete):**
1. User clicks "Hand Grip" button again
2. Message shows: "✓ AROM already completed for HAND GRIP (Min: X.XX° | Max: X.XX°)"
3. **Does NOT navigate** - stays on mechanism selection
4. User can select different mechanism

#### **7. Files Created:**

**AROM Raw Sensor Data:**
- Path: `data/{hospitalID}/rawdata/arom-hand-grip-{timestamp}.csv`
- Contains: All sensor packets during assessment (~5000+ packets)
- Format: Timestamp, PacketNumber, Force1, Force2, Angle1-4, Distance1-2, Button1-7

**ROM Assessment:**
- Path: `data/{hospitalID}/rom/HAND_GRIP.csv`
- Format: DateTime,AromMin,AromMax
- Example: `20-05-2026 14:30:45,10.23,78.90`

#### **Implementation Status: ✅ COMPLETE**

**Features Implemented:**
- ✅ Hand grip AROM assessment (angle_1)
- ✅ Real-time angle monitoring with needle
- ✅ Min/max squeeze range tracking
- ✅ Radial progress display (CW/CCW)
- ✅ AROM raw data logging
- ✅ ROM persistence
- ✅ Assessment completion detection
- ✅ Prevents re-assessment notification

**Example Output:**
```
=== ASSESS HAND GRIP ===
Real-time Grip Assessment

Current Angle: 45.67°

Min: 10.23°
Max: 78.90°
Current: 45.67°

Device Status: CONNECTED - Real-time Monitoring Active

[Circular Progress with Needle Visual]

--- After Save ---
Success: Assessment data saved! AROM: 10.23° to 78.90°

Files Created:
1. arom-hand-grip-2026-05-20_14-30-45.csv (5234 packets)
2. rom/HAND_GRIP.csv
```
### new knob assessment flow
 step 1-  show the knob_progress ui set min value is 10 and max is 10 monitor the current angle if crossed both the limits - step 1 passed if failed move to mechanism scene
 step 2- if step 1 passed now assess the real Active range of motion of the participant store the min and max values 
  step 3 - after arom show ui the stored min and max of AROM, now star the timer and monitor the current angle value ,alternative reach 5 times min and max point , if they reached in 1 min show the save assessment button to store the Arom data 
## new hand_grip_assessment flow
  the max rang 0 - 110 degree
   step1- move the handle to comfortable positon, now needle is at 20 - 40 this start point show the start button to move to step2
   step2 - start point is step 1 from this needle point we need to show +10 and - 10 degree in the knob progress,monitor the current angle if crossed both the limits - step 1 passed if failed move to mechanism scene
  step 3- if step 2 passed now assess the real Active range of motion of the participant form the step1 starting point store the min and max values 
  step 4 - after arom show ui the stored min and max of AROM, now star the timer and monitor the current angle value ,alternative reach 5 times min and max point , if they reached in 1 min show the save assessment button to store the Arom data 
