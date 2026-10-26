class_name DeviceTest
extends RefCounted
## Runs a test scene on a phone/emulator, where adb cannot pass command-line
## arguments (the Godot activity is not exported; the launcher alias drops
## extras). tools/check_android.py writes REQUEST with `adb run-as`, which
## only works on debuggable builds, then launches the app normally.
##
## Release builds never read the file. A request is consumed on read, so the
## next normal launch is the real game. The menu (boot scene) switches to
## the requested scene. Requests always isolate progress: no save
## loading/writing and no cloud, exactly like tools/check_game.py.

const REQUEST := "user://device_test.txt"
static var _read := false
static var _scene := ""
static var _args: PackedStringArray = []

## Requested test scene, or "" for a normal launch.
static func scene() -> String:
	_load()
	return _scene

## Command-line user args, plus any the request supplies on device.
static func user_args() -> PackedStringArray:
	_load()
	var args := OS.get_cmdline_user_args()
	args.append_array(_args)
	return args

## Where test captures go: the ignored build/ folder on desktop, app data on
## device (res:// is read-only in an APK); the harness pulls them back.
static func capture_path(name: String) -> String:
	if OS.has_feature("android"):
		DirAccess.make_dir_recursive_absolute("user://captures")
		return "user://captures/%s.png" % name
	return "res://build/%s.png" % name

static func _load() -> void:
	if _read:
		return
	_read = true
	if not OS.is_debug_build() or not OS.has_feature("android") or not FileAccess.file_exists(REQUEST):
		return
	var words := FileAccess.get_file_as_string(REQUEST).strip_edges().split(" ", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(REQUEST))
	if words.is_empty() or not words[0].begins_with("res://tests/"):
		return
	if not ResourceLoader.exists(words[0]):
		print("DEVICE TEST MISSING ", words[0])
		return
	_scene = words[0]
	_args = words.slice(1)
	print("DEVICE TEST ", _scene, " ", " ".join(_args))
