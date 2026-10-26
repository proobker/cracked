extends Node
## Google Play Games: sign-in, the player's gamer name, and level progress
## kept in a cloud save, through the godot-play-game-services plugin
## (addons/GodotPlayGameServices). Autoloaded as `PlayGames`.
##
## Off until configured (README, "Google Play Games"). It turns itself on
## only on Android, with the plugin enabled and its singleton present. Until
## then every call here does nothing and the game runs offline as before.
## The plugin is reached by node path and loaded scripts, never by name, so
## this file compiles while the plugin is disabled.

signal signed_in_changed

const PLUGIN_DIR := "res://addons/GodotPlayGameServices/scripts/"
## The cloud save holding Progress.
const SAVE_NAME := "progress"
## Configure a new board before publishing expansion scores.
const LEADERBOARD_ID := ""
var _upload_delay := -1.0
## From Play Console → Play Games Services → Leaderboards. Empty = off.
## Scores submitted: the sum of the best score on every level.
const LEGACY_LEADERBOARD_ID := "CgkIt_aIjdgTEAIQBw"
## Level number → achievement ID, unlocked on that level's first clear.
## Empty IDs are skipped. 100 is "Galaxy Conquered" (icon:
## store/play-games/ach_100.png).
const ACHIEVEMENTS := {10: "CgkIt_aIjdgTEAIQAw", 25: "CgkIt_aIjdgTEAIQBA", 50: "CgkIt_aIjdgTEAIQBQ", 99: "CgkIt_aIjdgTEAIQBg", 100: "CgkIt_aIjdgTEAIQCA"}
## Furthest wave reached in the endless level. Empty = off.
const ENDLESS_LEADERBOARD_ID := ""

## True once the plugin is up; the menu offers SIGN IN while not signed in.
var available := false
var signed_in := false
var player_name := ""

var _sign_in: Node
var _players: Node
var _snapshots: Node
var _leaderboards: Node
var _achievements: Node
var _loaded := false # never upload before the cloud copy has been merged in


func _ready() -> void:
	if Progress.isolated:
		return
	if OS.get_name() == "Android":
		# The plugin's autoload is registered after this one.
		_start.call_deferred()


func sign_in() -> void:
	if _sign_in:
		_sign_in.sign_in()


## A level was cleared with this score; Progress has already recorded it.
func level_cleared(level: int, _score: int) -> void:
	if not signed_in:
		return
	if LEADERBOARD_ID != "":
		var total := 0
		for n: int in Progress.best:
			total += Progress.best[n]
		_leaderboards.submit_score(LEADERBOARD_ID, total)
	var id: String = ACHIEVEMENTS.get(level, "")
	if id != "":
		_achievements.unlock_achievement(id)


## An endless run ended on this wave.
func endless_ended(wave: int) -> void:
	if signed_in and ENDLESS_LEADERBOARD_ID != "":
		_leaderboards.submit_score(ENDLESS_LEADERBOARD_ID, wave)


func _start() -> void:
	var core := get_node_or_null("/root/GodotPlayGameServices")
	if core == null or core.initialize() != 0:
		return
	_sign_in = _client("sign_in/sign_in_client.gd")
	_players = _client("players/players_client.gd")
	_snapshots = _client("snapshots/snapshots_client.gd")
	_leaderboards = _client("leaderboards/leaderboards_client.gd")
	_achievements = _client("achievements/achievements_client.gd")
	_sign_in.user_authenticated.connect(_on_authenticated)
	_players.current_player_loaded.connect(func(player: RefCounted) -> void:
		player_name = player.display_name
		signed_in_changed.emit())
	_snapshots.game_loaded.connect(_on_cloud_loaded)
	_snapshots.conflict_emitted.connect(_on_conflict)
	Progress.changed.connect(_schedule_upload)
	available = true
	_sign_in.is_authenticated()


func _client(script: String) -> Node:
	var node: Node = load(PLUGIN_DIR + script).new()
	add_child(node)
	return node


func _on_authenticated(is_authenticated: bool) -> void:
	signed_in = is_authenticated
	signed_in_changed.emit()
	if signed_in:
		_players.load_current_player(true)
		_snapshots.load_game(SAVE_NAME, true)


## Cloud and phone are merged by keeping the further of each (Progress.merge),
## so neither side can lose a clear; the result goes back up.
func _on_cloud_loaded(snapshot: RefCounted) -> void:
	if snapshot and not _merge_bytes(snapshot.content):
		_loaded = false
		return
	_loaded = true
	_upload()


func _on_conflict(conflict: RefCounted) -> void:
	if conflict.server_snapshot and not _merge_bytes(conflict.server_snapshot.content):
		_loaded = false
		return
	if conflict.conflicting_snapshot and not _merge_bytes(conflict.conflicting_snapshot.content):
		_loaded = false
		return
	_loaded = true
	_upload()


func _merge_bytes(bytes: PackedByteArray) -> bool:
	var parser := JSON.new()
	var error := parser.parse(bytes.get_string_from_utf8())
	var data: Variant = parser.data
	if error != OK or not data is Dictionary or not Progress._valid_data(data):
		Progress._fail("Cloud save could not be read. Upload is paused to preserve it.")
		return false
	Progress.merge(data)
	return Progress.writable and Progress.last_error.is_empty()


func _upload() -> void:
	if not signed_in or not _loaded or not Progress.writable or Progress.isolated:
		return
	var text := JSON.stringify(Progress.to_dict())
	_snapshots.save_game(SAVE_NAME, "Charted to " + Levels.name_for(Progress.unlocked), text.to_utf8_buffer(), 0, Progress.unlocked)

func _schedule_upload() -> void:
	_upload_delay = 2.0

func _process(delta: float) -> void:
	if _upload_delay < 0.0:
		return
	_upload_delay -= delta
	if _upload_delay <= 0.0:
		_upload_delay = -1.0
		_upload()
