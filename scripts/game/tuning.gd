extends Node
## Every number plans.md says is found by playing, not by deciding (§14).
## One place to change them. Autoloaded as `Tuning`. The player-facing
## subset (§11 settings) is saved to user://settings.cfg.

const SETTINGS_PATH := "user://settings.cfg"
## Settings a player can change, with their allowed ranges.
const SETTINGS := {
	"sensitivity": [0.3, 3.0],
	"fov": [70.0, 100.0],
	"aim_assist_strength": [0.0, 0.7],
	"touch_scale": [0.7, 1.4],
	"touch_opacity": [0.15, 0.9],
	"master_volume": [0.0, 1.0],
	"music_volume": [0.0, 1.0],
}

# Settings (§11)
var sensitivity := 1.0 # multiplies every look source
var master_volume := 0.9
var music_volume := 0.6

# Camera and aim (§4)
var mouse_sens_deg_per_px := 0.12 # editor testing only
var touch_look_deg_per_screen := 160.0 # dragging the full screen height turns this far
var pad_look_deg_per_sec := 200.0
var aim_assist_strength := 0.4 # fraction of look speed removed on target; 0 = off
var aim_assist_angle_deg := 3.5
var fov := 85.0
var scoped_look_scale := 0.35

# Movement (§4)
var walk_speed := 7.0
var sprint_speed := 11.0
var crouch_speed := 3.5
var ground_accel := 60.0
var air_accel := 15.0
var gravity := 20.0
var jump_velocity := 6.5
var sprint_meter_seconds := 4.0
var sprint_refill_seconds := 3.0
var slide_speed := 14.0
var slide_friction := 9.0
var slide_min_speed := 4.0
var dash_speed := 24.0
var dash_duration := 0.16
var dash_iframes := 0.14
var dash_cooldown := 2.0

# Health (§8)
var max_health := 100.0
var regen_delay := 5.0
var regen_per_sec := 50.0

# Combo (§8)
var combo_grace := 1.5
var combo_step_factor := 0.8 # x8 -> x6, x40 -> x32

# Waves and spawning (§2, §7)
var first_wave_delay := 3.0
var interval_seconds := 10.0
var spawn_telegraph := 0.9
var min_spawn_distance := 14.0
var walk_in_delay := 0.6

# Touch controls (§9)
var touch_opacity := 0.45
var touch_scale := 1.0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for key: String in SETTINGS:
		var range_: Array = SETTINGS[key]
		var value: float = cfg.get_value("settings", key, get(key))
		set(key, clampf(value, range_[0], range_[1]))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in SETTINGS:
		cfg.set_value("settings", key, get(key))
	cfg.save(SETTINGS_PATH)
