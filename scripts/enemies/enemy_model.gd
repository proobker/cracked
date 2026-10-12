class_name EnemyModel
extends Node3D
## An enemy's animated robot (CC0, Quaternius Sci-Fi Essentials Kit), tinted
## in its type's neon so it still reads against the city (§13 risk 6). It
## is only what you see: the hitboxes are the enemy's own shapes.

## Clips that repeat; anything else plays once and falls back to moving.
const LOOPING := [&"Idle", &"Walk", &"Run", &"Look", &"Hanging"]

var _anim: AnimationPlayer
var _overlay: StandardMaterial3D
var _tint: Color
var _moving := false
var _action_left := 0.0


## Returns null when the model cannot be loaded, so the caller can fall
## back to the placeholder.
static func create(path: String, model_scale: float, tint: Color) -> EnemyModel:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := EnemyModel.new()
	var inst := scene.instantiate() as Node3D
	inst.scale = Vector3.ONE * model_scale
	inst.rotation.y = PI # the models face +z; enemies face -z
	model.add_child(inst)
	model._tint = tint
	model._overlay = StandardMaterial3D.new()
	model._overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	model._overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	model._overlay.albedo_color = tint * 0.3
	for m in inst.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = model._overlay
	var players := inst.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		model._anim = players[0]
		for clip in LOOPING:
			if model._anim.has_animation(clip):
				model._anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	return model


func _ready() -> void:
	_play(&"Idle")


func _process(delta: float) -> void:
	if _action_left > 0.0:
		_action_left -= delta
		if _action_left <= 0.0:
			_play(&"Run" if _moving else &"Idle")


## Brightness of the neon tint; the hit flash and windups drive it.
func set_glow(energy: float) -> void:
	_overlay.albedo_color = _tint * (0.25 * energy)


## Walk cycle or idle, unless a one-shot action is still playing.
func locomote(moving: bool, speed_scale := 1.0) -> void:
	if _anim == null:
		return
	_moving = moving
	if _action_left <= 0.0:
		_play(&"Run" if moving else &"Idle")
		_anim.speed_scale = clampf(speed_scale, 0.6, 1.8) if moving else 1.0


## A one-shot clip: Attack, Hit, Charging… Missing clips are ignored.
func action(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.05)
	_anim.seek(0.0, true)
	_action_left = _anim.get_animation(clip).length


func _play(clip: StringName) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	if _anim.current_animation != clip:
		_anim.play(clip, 0.15)
