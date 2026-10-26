class_name LevelSelect
extends Control
## The galaxy map (LevelMap) with a slim icon bar and a card for the chosen
## star. Picking another star flies out to the whole galaxy and back in.
## No level numbers are ever shown: stars have names, and how many there
## are is for the player to find out.

signal chosen(level: int)
signal closed
signal armory_requested

const CLEARED := Color(0.2, 0.9, 1.0)
const BOSS := Color(1.0, 0.2, 0.65)

## Set by a cleared run's NEXT: the map opens on this star, flies to
## Game.level and starts it.
static var travel_from := 0

var _map: LevelMap
var _continue: Button
var _card: PanelContainer
var _name: Label
var _rooms: HBoxContainer
var _boss: TextureRect
var _clear: TextureRect
var _star: TextureRect
var _best: Label
var _play: Button
var _autostart := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.0, 0.035)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_map = LevelMap.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.picked.connect(_pick)
	_map.activated.connect(_choose)
	_map.arrived.connect(_on_arrived)
	add_child(_map)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	add_child(top)
	var back := UiIcons.button("back", "Back")
	back.pressed.connect(close)
	top.add_child(back)
	var armory := UiIcons.button("armory", "Armory", 64.0, CLEARED)
	armory.pressed.connect(func() -> void: armory_requested.emit())
	top.add_child(armory)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var whole := UiIcons.button("fit", "Whole galaxy")
	whole.pressed.connect(_map.look_at_all)
	top.add_child(whole)
	_continue = UiIcons.button("play", "Continue", 64.0, CLEARED)
	_continue.pressed.connect(func() -> void: _pick(Progress.unlocked))
	top.add_child(_continue)

	_card = _build_card()
	add_child(_card)
	Progress.changed.connect(_refresh)


func _build_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.02, 0.08, 0.85)
	style.border_color = Color(CLEARED, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.content_margin_left = 22
	card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 4)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(words)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 30)
	words.add_child(_name)
	var facts := HBoxContainer.new()
	facts.add_theme_constant_override("separation", 10)
	words.add_child(facts)
	_rooms = HBoxContainer.new()
	_rooms.add_theme_constant_override("separation", 4)
	_rooms.tooltip_text = "Rooms"
	facts.add_child(_rooms)
	_boss = UiIcons.glyph("boss", 24.0, BOSS)
	_boss.tooltip_text = "Boss"
	facts.add_child(_boss)
	_clear = UiIcons.glyph("check", 24.0, CLEARED)
	_clear.tooltip_text = "Conquered"
	facts.add_child(_clear)
	_star = UiIcons.glyph("xp", 22.0, Color(1.0, 0.8, 0.3))
	_star.tooltip_text = "Best"
	facts.add_child(_star)
	_best = Label.new()
	_best.add_theme_font_size_override("font_size", 18)
	_best.modulate = Color(1, 1, 1, 0.6)
	facts.add_child(_best)
	_play = UiIcons.button("play", "Play", 76.0, CLEARED)
	_play.pressed.connect(func() -> void: _choose(_map.selected))
	row.add_child(_play)
	return card


func open() -> void:
	visible = true
	_refresh()
	var target := clampi(Progress.unlocked, 1, Levels.COUNT)
	if travel_from > 0:
		# Coming from a cleared star: fly on to the next one and launch it.
		target = clampi(Game.level, 1, Levels.COUNT)
		_map.look_at_star(travel_from)
		travel_from = 0
		_autostart = true
	else:
		_map.look_at_all()
	_map.selected = target
	_show_card(target)
	_map.travel_to.call_deferred(target)
	_map.grab_focus.call_deferred()


func close() -> void:
	Audio.play(&"ui_click")
	_autostart = false
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _refresh() -> void:
	_map.unlocked = clampi(Progress.unlocked, 1, Levels.COUNT)
	_map.cleared = Progress.clears
	_map.queue_redraw()


## Another star: fly there, and say what it is when we arrive.
func _pick(n: int) -> void:
	if not Progress.is_unlocked(n):
		return
	Audio.play(&"ui_click")
	_autostart = false
	_card.modulate.a = 0.0
	_map.travel_to(n)


func _on_arrived(n: int) -> void:
	_show_card(n)
	if _autostart:
		_autostart = false
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if visible:
				_choose(n))


func _show_card(n: int) -> void:
	_name.text = Levels.name_for(n)
	_name.add_theme_color_override("font_color", (Levels.theme_for(n)["trim"] as Color).lightened(0.3))
	for child in _rooms.get_children():
		child.queue_free()
	# Rooms as dots.
	var rooms := Levels.room_count_for(n)
	for i in rooms:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = Color(CLEARED, 0.85)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_rooms.add_child(dot)
	_boss.visible = Levels.is_boss_level(n)
	_best.text = ""
	if Levels.is_endless(n):
		_best.text = "WAVE %d" % Progress.endless_wave if Progress.endless_wave > 0 else ""
	elif Progress.best_for(n) > 0:
		_best.text = str(Progress.best_for(n))
	elif Progress.legacy_best.has(n):
		_best.text = str(Progress.legacy_best[n])
	_star.visible = not _best.text.is_empty()
	_clear.visible = Progress.clears.has(str(n))
	_card.reset_size()
	_card.offset_left = -_card.get_combined_minimum_size().x / 2.0
	_card.offset_right = _card.get_combined_minimum_size().x / 2.0
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.2)


func _choose(n: int) -> void:
	if not Progress.is_unlocked(n):
		return
	if _map.is_travelling():
		_map.skip()
	Audio.play(&"ui_click")
	chosen.emit(n)
