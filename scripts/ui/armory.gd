class_name Armory
extends Control
## Persistent purchases and free activation share one validated service API.
signal closed
signal practice_requested
var practice := false
var practice_context := false
const PRACTICE_OFF := "PRACTICE BUILD IS TURNED OFF"
var _practice_warning: PanelContainer
var _warning_tween: Tween
var _icon: TextureRect
var _title: Label
var _stats: Label
var _enter_range: Button
var _fit: Button
var _branch := 0
var _selected := "swap_speed"
var _level: Label
var _xp: ProgressBar
var _coins: Label
var _slot_pips: Pips
var _rank: Pips
var _info: Button
var _detail: Label
var _notice: Label
var _buy: Button
var _equip: Button
var _tree: SkillTree
var _slots: Array[OptionButton] = []
var _grenade: OptionButton
var _preview: Button
var _updating := false
const GOLD := Color(1.0, 0.8, 0.3)
const CYAN := Color(0.3, 0.95, 1.0)

## A row of dots: filled up to `value` of `total`. Ranks and skill slots.
class Pips extends Control:
	var value := 0
	var total := 1
	var color := Color.WHITE
	func set_to(v: int, t: int, c: Color) -> void:
		value = v
		total = maxi(t, 1)
		color = c
		custom_minimum_size = Vector2(total * _pitch() + 2, 18)
		queue_redraw()
	## Many dots pack tighter so a full slot bar still fits the header.
	func _pitch() -> float:
		return 16.0 if total <= 8 else 10.0
	func _draw() -> void:
		var r := _pitch() * 0.34
		for i in total:
			var at := Vector2(_pitch() / 2.0 + 1.0 + i * _pitch(), size.y / 2.0)
			if i < value:
				draw_circle(at, r, color)
			else:
				draw_arc(at, r - 0.5, 0.0, TAU, 16, Color(color, 0.45), 1.5, true)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.015, 0.02, 0.05, 0.98)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = 12
	box.offset_bottom = -12
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	# Header: what you have, as pictures. Words live in tooltips.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	_icon_button(header, "back", "Back", close)
	header.add_child(UiIcons.glyph("xp", 30.0, CYAN))
	_level = _readout(header, 26, CYAN)
	_level.tooltip_text = "Player level"
	_xp = ProgressBar.new()
	_xp.show_percentage = false
	_xp.custom_minimum_size = Vector2(150, 12)
	_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp.tooltip_text = "XP to next level"
	var fill := StyleBoxFlat.new()
	fill.bg_color = CYAN
	fill.set_corner_radius_all(6)
	_xp.add_theme_stylebox_override("fill", fill)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.1)
	track.set_corner_radius_all(6)
	_xp.add_theme_stylebox_override("background", track)
	header.add_child(_xp)
	header.add_child(UiIcons.glyph("coin", 30.0, GOLD))
	_coins = _readout(header, 26, GOLD)
	_coins.tooltip_text = "Coins"
	header.add_child(UiIcons.glyph("power", 26.0, Color(1, 1, 1, 0.8)))
	_slot_pips = Pips.new()
	_slot_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slot_pips.tooltip_text = "Active skill slots"
	header.add_child(_slot_pips)
	var grow := Control.new()
	grow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(grow)
	_preview = UiIcons.button("practice", "Practice build: try any gear and skill. Only used in Practice Range.", 64.0, Color(1, 0.4, 0.7))
	_preview.toggle_mode = true
	_preview.toggled.connect(_on_practice_toggled)
	header.add_child(_preview)
	# Loadout and tree controls on one row.
	var loadout := HBoxContainer.new()
	loadout.add_theme_constant_override("separation", 8)
	box.add_child(loadout)
	for i in 3:
		var option := _option(loadout)
		option.item_selected.connect(func(_index: int) -> void: _save_loadout())
		_slots.append(option)
	_grenade = _option(loadout)
	_grenade.item_selected.connect(func(_index: int) -> void: _save_loadout())
	for i in 3:
		var tab := _icon_button(loadout, ["runner", "gunner", "demolition"][i], ["Runner", "Gunner", "Demolition"][i], func() -> void:
			_branch = i
			_selected = SkillCatalog.ROOTS[i]
			_tree.focus_node(_selected), SkillTree.COLORS[i])
		tab.custom_minimum_size = Vector2(52, 52)
	_fit = _icon_button(loadout, "fit", "Fit", func() -> void: _tree.fit_all())
	var zoom_in := _icon_button(loadout, "zoom_in", "Zoom in", func() -> void: _tree.zoom_by(1.4))
	var zoom_out := _icon_button(loadout, "zoom_out", "Zoom out", func() -> void: _tree.zoom_by(1.0 / 1.4))
	for b: Button in [_fit, zoom_in, zoom_out]:
		b.custom_minimum_size = Vector2(52, 52)
	_tree = SkillTree.new()
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.custom_minimum_size.y = 180
	_tree.selected.connect(func(id: String) -> void:
		_selected = id
		_refresh_detail())
	box.add_child(_tree)
	# Inspector, one row: picture, name, one line of meaning, rank as dots,
	# then the actions as icons. Exact tuning hides behind the info button.
	var inspector := HBoxContainer.new()
	inspector.add_theme_constant_override("separation", 14)
	box.add_child(inspector)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspector.add_child(_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	inspector.add_child(words)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	words.add_child(name_row)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	name_row.add_child(_title)
	_rank = Pips.new()
	_rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rank.tooltip_text = "Rank"
	name_row.add_child(_rank)
	_detail = Label.new()
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail.clip_text = true
	_detail.add_theme_font_size_override("font_size", 17)
	_detail.modulate.a = 0.85
	words.add_child(_detail)
	_info = _icon_button(inspector, "info", "Details", func() -> void: _stats.visible = _info.button_pressed)
	_info.toggle_mode = true
	_buy = _icon_button(inspector, "coin", "Upgrade", _purchase, GOLD)
	_buy.custom_minimum_size = Vector2(130, 64)
	_buy.add_theme_font_size_override("font_size", 24)
	_buy.add_theme_color_override("font_color", GOLD)
	_buy.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_equip = _icon_button(inspector, "power", "Activate", _toggle)
	_enter_range = _icon_button(inspector, "play", "Enter range", func() -> void: practice_requested.emit(), CYAN)
	_enter_range.visible = false
	_stats = Label.new()
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.add_theme_font_size_override("font_size", 14)
	_stats.modulate.a = 0.6
	_stats.visible = false
	box.add_child(_stats)
	_notice = Label.new()
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	box.add_child(_notice)
	_practice_warning = _make_practice_warning()
	add_child(_practice_warning)
	Progress.changed.connect(_refresh)
	Progress.problem.connect(func(message: String) -> void: _notice.text = message)
	_refresh()

func _icon_button(parent: Node, icon: String, tooltip: String, callback: Callable, tint := Color.WHITE) -> Button:
	var button := UiIcons.button(icon, tooltip, 64.0, tint)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _readout(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(label)
	return label

func _option(parent: Node) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(112, 52)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.clip_text = true
	option.add_theme_font_size_override("font_size", 16)
	option.add_theme_constant_override("icon_max_width", 20)
	option.fit_to_longest_item = false
	parent.add_child(option)
	return option

## Non-blocking notice: the player keeps working with the normal build.
func _make_practice_warning() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = 120
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.03, 0.06, 0.94)
	style.border_color = Color(1, 0.3, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	style.shadow_color = Color(1, 0.2, 0.55, 0.3)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = PRACTICE_OFF + "\nContinuing with your normal build. Practice builds run only in Practice Range."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	panel.add_child(label)
	return panel

func warn_practice_off() -> void:
	if _warning_tween:
		_warning_tween.kill()
	_practice_warning.visible = true
	_practice_warning.modulate.a = 1.0
	_warning_tween = create_tween()
	_warning_tween.tween_interval(2.8)
	_warning_tween.tween_property(_practice_warning, "modulate:a", 0.0, 0.6)
	_warning_tween.tween_callback(_practice_warning.hide)

func open(for_practice := false) -> void:
	var was_practice := practice
	practice_context = for_practice
	practice = for_practice
	_preview.set_pressed_no_signal(practice)
	_enter_range.visible = for_practice
	visible = true
	_refresh()
	_tree.fit_all.call_deferred()
	if was_practice and not for_practice:
		warn_practice_off()

func _on_practice_toggled(value: bool) -> void:
	if value and not practice_context:
		practice = false
		_preview.set_pressed_no_signal(false)
		_refresh()
		warn_practice_off()
		return
	practice = value
	_refresh()

## Campaign always runs the saved build. If a practice build was on, the
## run's HUD says why it is gone, without stopping the player.
func prepare_campaign() -> void:
	if practice:
		disable_practice()
		Game.notice = PRACTICE_OFF

func disable_practice() -> void:
	practice = false
	practice_context = false
	_preview.set_pressed_no_signal(false)
	_enter_range.visible = false
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()

func _owned() -> Dictionary:
	if not practice:
		return Progress.ledger.owned
	var ranks := {}
	for id: String in SkillCatalog.nodes():
		ranks[id] = SkillCatalog.nodes()[id].max
	return ranks

func _active() -> Array:
	return Progress.practice_active if practice else Progress.active

func _refresh() -> void:
	if not is_instance_valid(_tree):
		return
	_updating = true
	var level := 30 if practice else Progress.player_level()
	_level.text = str(level)
	_coins.text = str(Progress.ledger.coins)
	if level < 30:
		_xp.min_value = SkillCatalog.xp_for_level(level)
		_xp.max_value = SkillCatalog.xp_for_level(level + 1)
		_xp.value = Progress.ledger.xp
	else:
		_xp.min_value = 0
		_xp.max_value = 1
		_xp.value = 1
	_slot_pips.set_to(_active().size(), SkillCatalog.slots(level), Color.WHITE)
	var guns := Progress.practice_guns if practice else Progress.guns
	for i in 3:
		var option := _slots[i]
		option.clear()
		for id: String in Arsenal.GUNS:
			var index := option.item_count
			var unlocked := practice or Arsenal.available(id, Progress.clears)
			if unlocked:
				option.add_item(id.to_upper())
			else:
				option.add_icon_item(UiIcons.texture("lock"), "%s  ·  %s" % [id.to_upper(), Levels.name_for(Arsenal.GUNS[id])])
			option.set_item_metadata(index, id)
			option.set_item_disabled(index, not unlocked)
			if guns[i] == id:
				option.select(index)
	_grenade.clear()
	_grenade.add_item("—")
	_grenade.set_item_metadata(0, "")
	for id: String in Arsenal.GRENADES:
		var index := _grenade.item_count
		var unlocked := practice or Arsenal.available(id, Progress.clears)
		if unlocked:
			_grenade.add_item(id.to_upper())
		else:
			_grenade.add_icon_item(UiIcons.texture("lock"), "%s  ·  %s" % [id.to_upper(), Levels.name_for(Arsenal.GRENADES[id])])
		_grenade.set_item_metadata(index, id)
		_grenade.set_item_disabled(index, not unlocked)
		if id == (Progress.practice_grenade if practice else Progress.grenade):
			_grenade.select(index)
	_tree.branch = _branch
	_tree.owned = _owned()
	_tree.active = _active()
	_tree.level = level
	_tree.rebuild()
	if not _tree._positions.has(_selected):
		_selected = SkillCatalog.ROOTS[_branch]
	_refresh_detail()
	_updating = false

func _refresh_detail() -> void:
	var node: Dictionary = SkillCatalog.nodes()[_selected]
	var rank := int(_owned().get(_selected, 0))
	var color: Color = SkillTree.COLORS[int(node.branch)]
	_icon.texture = SkillCatalog.icon(_selected)
	_icon.modulate = color.lightened(0.35)
	_title.text = SkillCatalog.title(_selected)
	_title.add_theme_color_override("font_color", color.lightened(0.2))
	_detail.text = SkillCatalog.meaning(_selected)
	_detail.tooltip_text = _detail.text
	_rank.set_to(rank, int(node.max), color.lightened(0.35))
	_stats.text = "%s | %s | Player level %d\n%s" % [SkillCatalog.discipline(_selected), SkillCatalog.requirements(_selected), node.tier, SkillCatalog.description(_selected)]
	var maxed := rank >= int(node.max)
	_buy.icon = UiIcons.texture("check" if maxed else "coin")
	_buy.text = "" if maxed else str(SkillCatalog.cost(_selected, rank + 1))
	_buy.tooltip_text = "Max rank" if maxed else "Upgrade"
	_buy.disabled = practice or maxed or Progress.ledger.purchase_record(_selected).is_empty()
	var on := _active().has(_selected)
	_equip.tooltip_text = "Deactivate" if on else "Activate"
	_equip.add_theme_color_override("icon_normal_color", CYAN if on else Color(1, 1, 1, 0.55))
	_equip.add_theme_color_override("icon_hover_color", CYAN.lightened(0.3) if on else Color.WHITE)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(0.05, 0.3, 0.35) if on else Color(0.1, 0.1, 0.14)
	lit.border_color = CYAN if on else Color(1, 1, 1, 0.2)
	lit.set_border_width_all(2)
	lit.set_corner_radius_all(8)
	_equip.add_theme_stylebox_override("normal", lit)
	_equip.disabled = rank == 0

func _purchase() -> void:
	_notice.text = ""
	Progress.purchase(_selected)

func _toggle() -> void:
	var ids := _active().duplicate()
	if ids.has(_selected):
		ids.erase(_selected)
	else:
		ids.append(_selected)
	var valid := SkillCatalog.valid_active(ids, _owned(), 30 if practice else Progress.player_level())
	if ids.has(_selected) and not valid.has(_selected):
		_notice.text = "Needs a route to an active skill, a free slot, and only one capstone."
		return
	_notice.text = ""
	Progress.select_build(valid, Progress.practice_guns if practice else Progress.guns, Progress.practice_grenade if practice else Progress.grenade, practice)

func _save_loadout() -> void:
	if _updating:
		return
	var ids: Array = []
	for option in _slots:
		var id: String = option.get_item_metadata(option.selected)
		if ids.has(id):
			_notice.text = "Choose three different guns."
			_refresh()
			return
		ids.append(id)
	Progress.select_build(_active(), ids, _grenade.get_item_metadata(_grenade.selected), practice)
