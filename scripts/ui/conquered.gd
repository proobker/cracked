class_name Conquered
extends Control
## The ending, after the last boss of level 100 falls: the badge flies in,
## the title splits into neon, and the abyss opens. Plain tweens, no shaders.

signal action(id: StringName)

const BADGE := preload("res://assets/ui/galaxy_conquered.svg")
const CYAN := Color(0.1, 0.9, 1.0)
const MAGENTA := Color(1.0, 0.2, 0.65)

## One line under the title, set before this enters the tree.
var stats := ""

var _badge: TextureRect
var _title: Label
var _ghost: Label
var _body: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.0, 0.06, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	_badge = TextureRect.new()
	_badge.texture = BADGE
	_badge.custom_minimum_size = Vector2(260, 260)
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_badge)

	# Two copies of the title, magenta behind cyan and slightly offset: the
	# same split-neon look as the menu, without a shader.
	var title_holder := Control.new()
	title_holder.custom_minimum_size = Vector2(0, 96)
	box.add_child(title_holder)
	_ghost = _title_label(MAGENTA)
	title_holder.add_child(_ghost)
	_title = _title_label(CYAN)
	title_holder.add_child(_title)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	box.add_child(_body)
	var line := Label.new()
	line.text = "every star bows. the abyss stirs."
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 26)
	line.modulate = Color(1, 1, 1, 0.8)
	_body.add_child(line)
	var numbers := Label.new()
	numbers.text = stats
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numbers.add_theme_font_size_override("font_size", 20)
	numbers.modulate = Color(1, 1, 1, 0.55)
	_body.add_child(numbers)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_body.add_child(row)
	var abyss := _button(row, "ENTER THE ABYSS", &"abyss", MAGENTA)
	_button(row, "MENU", &"menu", CYAN)

	# Entrance: badge scales up from nothing, title slams in, the rest fades.
	_badge.pivot_offset = _badge.custom_minimum_size / 2.0
	_badge.scale = Vector2.ZERO
	_badge.modulate.a = 0.0
	title_holder.modulate.a = 0.0
	_body.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_badge, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_badge, "modulate:a", 1.0, 0.5)
	t.tween_property(title_holder, "modulate:a", 1.0, 0.25)
	t.parallel().tween_method(_split, 18.0, 3.0, 0.5).set_ease(Tween.EASE_OUT)
	t.tween_property(_body, "modulate:a", 1.0, 0.6)
	t.tween_callback(abyss.grab_focus)
	Audio.play(&"win")


func _title_label(color: Color) -> Label:
	var label := Label.new()
	label.text = "GALAXY CONQUERED"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 76)
	label.add_theme_color_override("font_color", color)
	return label


## Offsets the two title copies apart by `amount` pixels.
func _split(amount: float) -> void:
	_ghost.position = Vector2(amount, amount * 0.5)
	_title.position = Vector2(-amount * 0.3, 0.0)


func _button(parent: Node, text: String, id: StringName, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 72)
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", color)
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		action.emit(id))
	parent.add_child(b)
	return b
