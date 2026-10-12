class_name LevelSelect
extends Control
## The 99 levels as a grid. Locked levels are disabled, cleared ones are lit
## cyan, and boss levels are magenta. CONTINUE plays the highest open level.

signal chosen(level: int)
signal closed

const COLUMNS := 11
const CLEARED := Color(0.2, 0.9, 1.0)
const BOSS := Color(1.0, 0.2, 0.65)

var _grid: GridContainer
var _continue: Button
var _info: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.0, 0.08, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 20
	box.offset_bottom = -20
	add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var back := _button("BACK", Vector2(180, 64))
	back.pressed.connect(close)
	top.add_child(back)
	var title := Label.new()
	title.text = "LEVELS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", CLEARED)
	top.add_child(title)
	_continue = _button("CONTINUE", Vector2(240, 64))
	_continue.pressed.connect(func() -> void: _choose(Progress.unlocked))
	top.add_child(_continue)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.modulate = Color(1, 1, 1, 0.7)
	box.add_child(_info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12 # a drag scrolls, a tap still presses
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	for n in range(1, Levels.COUNT + 1):
		var b := _button(str(n), Vector2(0, 76))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose.bind(n))
		b.focus_entered.connect(_show_info.bind(n))
		b.mouse_entered.connect(_show_info.bind(n))
		_grid.add_child(b)
	Progress.changed.connect(_refresh)


func open() -> void:
	visible = true
	_refresh()
	var focus: Button = _grid.get_child(clampi(Progress.unlocked, 1, Levels.COUNT) - 1)
	focus.grab_focus.call_deferred()
	_show_info(Progress.unlocked)


func close() -> void:
	Audio.play(&"ui_click")
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _refresh() -> void:
	_continue.text = "CONTINUE  %d" % Progress.unlocked
	for i in _grid.get_child_count():
		var n := i + 1
		var b: Button = _grid.get_child(i)
		b.disabled = not Progress.is_unlocked(n)
		var c := Color.WHITE
		if Levels.is_boss_level(n):
			c = BOSS
		elif Progress.best_for(n) > 0:
			c = CLEARED
		b.add_theme_color_override("font_color", c)
		b.add_theme_color_override("font_focus_color", c)
		b.add_theme_color_override("font_hover_color", c)


func _show_info(n: int) -> void:
	var rooms := Levels.room_count_for(n)
	var text := "LEVEL %d   ·   %d room%s" % [n, rooms, "" if rooms == 1 else "s"]
	if Levels.is_boss_level(n):
		text += "   ·   BOSS"
	if not Progress.is_unlocked(n):
		text += "   ·   locked"
	elif Progress.best_for(n) > 0:
		text += "   ·   best %d" % Progress.best_for(n)
	_info.text = text


func _choose(n: int) -> void:
	if not Progress.is_unlocked(n):
		return
	Audio.play(&"ui_click")
	chosen.emit(n)


func _button(text: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 28)
	return b
