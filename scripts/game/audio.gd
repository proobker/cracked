extends Node
## Sound and music (§10). Autoloaded as `Audio`. Every sound is looked up by
## role name from audio/sfx/<name>.ogg, so swapping a sound is a file swap.
## A miss, a hit, a weak point, and a kill each sound different.

const SFX_DIR := "res://audio/sfx/"
const MUSIC := {
	&"menu": "res://audio/music/menu.ogg",
	&"combat": "res://audio/music/combat.ogg",
	&"boss": "res://audio/music/boss.ogg",
}
## Per-sound volume trims in dB, so nothing drowns the markers.
const TRIM := {
	&"kill": 2.0, &"weak": 0.0, &"hit": -4.0,
	&"shot_rifle": -8.0, &"shot_shotgun": -4.0, &"shot_marksman": -3.0,
	&"telegraph": -12.0, &"spawn_rusher": -10.0, &"spawn_shooter": -10.0,
	&"pickup": -6.0, &"swap": -8.0, &"dash": -8.0, &"reload_rifle": -6.0,
	&"wave_start": -4.0, &"ui_click": -6.0,
}
const POOL_2D := 12
const POOL_3D := 16

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next_3d := 0
var _music: AudioStreamPlayer
var _music_name := &""
var _lowpass: AudioEffectLowPassFilter
var _music_bus := 0
var _sfx_bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus = _make_bus("Music")
	_sfx_bus = _make_bus("SFX")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)

	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 8.0
		p.max_distance = 80.0
		add_child(p)
		_pool_3d.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volumes()


## A non-positional sound: the player's own guns, markers, UI.
func play(sound: StringName, pitch_jitter := 0.04) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = TRIM.get(sound, 0.0)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## A sound in the world, so enemies can be located by ear.
func play_at(sound: StringName, pos: Vector3) -> void:
	var stream := _stream(sound)
	if stream == null or not is_inside_tree():
		return
	var p := _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % _pool_3d.size()
	p.stream = stream
	p.volume_db = TRIM.get(sound, 0.0)
	p.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
	p.global_position = pos
	p.play()


func play_music(track: StringName) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var stream: AudioStream = load(MUSIC[track]) if MUSIC.has(track) else null
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()
	_music_name = &""


## The track intensifies with the wave number and nothing else (§10):
## a closed filter early, fully open by the last waves.
func set_intensity(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	_lowpass.cutoff_hz = lerpf(900.0, 20000.0, t * t)
	_music.volume_db = lerpf(-6.0, 0.0, t)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Tuning.master_volume, 0.0001)))
	AudioServer.set_bus_volume_db(_music_bus, linear_to_db(maxf(Tuning.music_volume, 0.0001)))


func _stream(sound: StringName) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path := SFX_DIR + String(sound) + ".ogg"
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[sound] = stream
	return stream


func _make_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return idx
	idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	return idx
