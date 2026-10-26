class_name SkillTree
extends Control
## Entire graph on one canvas; drawing/picking share world coordinates.
## Inspection never spends coins. Touch users keep details in Armory's panel.
signal selected(id: String)
var branch := 0
var owned := {}
var active: Array = []
var level := 1
var _positions := {}
var _zoom := 0.22
var _pan := Vector2.ZERO
var _dragging := false
var _travel := 0.0
var _hover := ""
var _focus := "swap_speed"
var _touches := {}
var _last_size := Vector2.ZERO
var _card: PanelContainer
var _card_icon: TextureRect
var _card_title: Label
var _card_meaning: Label
var _card_stats: Label
const COLORS := [Color("45dfc4"), Color("78b4ff"), Color("f5a957")]

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(func() -> void:
		_pan += (size - _last_size) / 2
		_last_size = size
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = ""
		_card.hide()
		queue_redraw())
	_build_card()

## Hover card drawn by the tree itself: native tooltips cache their first
## text and go stale as the pointer moves from node to node.
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size.x = 380
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.09, 0.96)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	_card_icon = TextureRect.new()
	_card_icon.custom_minimum_size = Vector2(52, 52)
	_card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_card_icon)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 2)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	_card_title = _card_label(words, 20, 1.0)
	_card_meaning = _card_label(words, 16, 1.0)
	_card_stats = _card_label(words, 13, 0.6)

func _card_label(parent: Control, font_size: int, alpha: float) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate.a = alpha
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _show_card(id: String, at: Vector2) -> void:
	if id.is_empty() or _dragging:
		_card.hide()
		return
	var node: Dictionary = SkillCatalog.nodes()[id]
	var color: Color = COLORS[int(node.branch)].lightened(0.3)
	_card_icon.texture = SkillCatalog.icon(id)
	_card_icon.modulate = color
	_card_title.text = SkillCatalog.title(id)
	_card_title.add_theme_color_override("font_color", color)
	_card_meaning.text = SkillCatalog.meaning(id)
	# Rank shows as dots in the inspector; the card keeps only what it does.
	_card_stats.text = SkillCatalog.description(id)
	if level < int(node.tier):
		_card_icon.modulate.a = 0.4
	(_card.get_theme_stylebox("panel") as StyleBoxFlat).border_color = color
	_card.reset_size()
	_card.show()
	# Beside the pointer, flipped and clamped to stay inside the canvas.
	var card := _card.get_combined_minimum_size()
	var place := at + Vector2(18, 18)
	if place.x + card.x > size.x:
		place.x = at.x - card.x - 18
	if place.y + card.y > size.y:
		place.y = at.y - card.y - 18
	_card.position = place.clamp(Vector2.ZERO, (size - card).max(Vector2.ZERO))

func rebuild() -> void:
	_positions.clear()
	for id: String in SkillCatalog.nodes():
		if SkillCatalog.is_revealed(id, owned, level):
			_positions[id] = SkillCatalog.nodes()[id].position
	_hover = ""
	_card.hide()
	if not _positions.has(_focus):
		_focus = SkillCatalog.ROOTS[branch]
	queue_redraw()

func fit_all() -> void:
	if _positions.is_empty():
		return
	var bounds := Rect2(Vector2(_positions.values()[0]), Vector2.ZERO)
	for at: Vector2 in _positions.values():
		bounds = bounds.expand(at)
	bounds = bounds.grow(100)
	_zoom = clampf(minf(size.x / bounds.size.x, size.y / bounds.size.y), 0.05, 1.5)
	_pan = size / 2 - bounds.get_center() * _zoom
	queue_redraw()

func focus_node(id: String) -> void:
	if not _positions.has(id):
		return
	_focus = id
	_zoom = 0.7
	_pan = size / 2 - Vector2(_positions[id]) * _zoom
	selected.emit(id)
	queue_redraw()

func zoom_by(factor: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if anchor.x < 0:
		anchor = size / 2
	var world := (anchor - _pan) / _zoom
	_zoom = clampf(_zoom * factor, 0.055, 1.5)
	_pan = anchor - world * _zoom
	queue_redraw()

func _pick(at: Vector2) -> String:
	var nearest := ""
	var distance := 24.0
	for id: String in _positions:
		var d := at.distance_to(Vector2(_positions[id]) * _zoom + _pan)
		if d < distance:
			distance = d
			nearest = id
	return nearest

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_by(1.2, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_by(1.0 / 1.2, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_travel = 0
				grab_focus()
			elif _travel < 10:
				inspect_at(event.position)
	elif event is InputEventMouseMotion:
		if _dragging:
			_pan += event.relative
			_travel += event.relative.length()
		_hover = _pick(event.position)
		_show_card(_hover, event.position)
		queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			_travel = 0 if _touches.size() == 1 else 100
		else:
			if _touches.size() == 1 and _travel < 10:
				inspect_at(event.position)
			_touches.erase(event.index)
	elif event is InputEventScreenDrag:
		if _touches.size() == 2:
			var points: Array = _touches.values()
			var before: float = points[0].distance_to(points[1])
			_touches[event.index] = event.position
			points = _touches.values()
			if before > 1:
				zoom_by(points[0].distance_to(points[1]) / before, (points[0] + points[1]) / 2)
		else:
			_pan += event.relative
			_touches[event.index] = event.position
		_travel += event.relative.length()
		queue_redraw()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor, event.position)
	elif event is InputEventKey and event.pressed:
		var direction := Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction = Vector2.LEFT
			KEY_RIGHT: direction = Vector2.RIGHT
			KEY_UP: direction = Vector2.UP
			KEY_DOWN: direction = Vector2.DOWN
			KEY_ENTER, KEY_SPACE: selected.emit(_focus)
			KEY_F: fit_all()
			KEY_EQUAL, KEY_PLUS: zoom_by(1.2)
			KEY_MINUS: zoom_by(1.0 / 1.2)
		if direction != Vector2.ZERO:
			var best := ""
			var score := INF
			for id: String in _positions:
				var delta: Vector2 = _positions[id] - _positions[_focus]
				if delta.dot(direction) > 0 and delta.normalized().dot(direction) > 0.5 and delta.length() < score:
					best = id
					score = delta.length()
			if not best.is_empty():
				focus_node(best)
	accept_event()

func inspect_at(at: Vector2) -> void:
	var id := _pick(at)
	if not id.is_empty():
		_focus = id
		selected.emit(id)
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080d16"))
	var graph := SkillCatalog.nodes()
	var viewport := Rect2(Vector2(-30, -30), size + Vector2(60, 60))
	for id: String in _positions:
		var end: Vector2 = _positions[id] * _zoom + _pan
		for parent: String in graph[id].parents:
			if not _positions.has(parent):
				continue
			var start: Vector2 = _positions[parent] * _zoom + _pan
			var color: Color = COLORS[int(graph[id].branch)]
			color.a = 0.85 if active.has(parent) and active.has(id) else (0.45 if owned.has(id) and owned.has(parent) else 0.17)
			draw_line(start, end, color, 1.5, true)
	if _zoom < 0.3:
		_draw_disciplines()
	for id: String in _positions:
		var at: Vector2 = _positions[id] * _zoom + _pan
		if not viewport.has_point(at):
			continue
		var node: Dictionary = graph[id]
		var color: Color = COLORS[int(node.branch)]
		var minor := node.has("weight")
		var radius := maxf(3.0, (24.0 if minor else 36.0) * _zoom)
		if node.cap:
			radius *= 1.3
		color.a = 1.0 if active.has(id) else (0.85 if owned.has(id) else (0.48 if level >= int(node.tier) else 0.22))
		var fill := Color("10232b") if active.has(id) else Color("0b101c")
		var width := 2.0 if owned.has(id) else 1.0
		# Shape carries importance, never colour alone: plates for core
		# skills, small circles for echoes, an outer ring for capstones.
		if minor:
			draw_circle(at, radius, fill)
			draw_arc(at, radius, 0, TAU, 24, color, width, true)
		else:
			var rect := Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2)
			draw_rect(rect, fill)
			draw_rect(rect, color, false, width)
		if node.cap:
			draw_arc(at, radius * 1.5, 0, TAU, 32, color, 1, true)
		if active.has(id):
			draw_circle(at + Vector2(radius, -radius) * 0.8, maxf(2, radius * 0.15), Color.WHITE)
		if id == _hover or id == _focus:
			draw_arc(at, radius * 1.45 + 3, 0, TAU, 32, Color.WHITE, 1.5, true)
		if radius >= 6:
			# Echoes reuse their skill's art so repeated investments read as
			# the same mechanic, not 405 different ones.
			var icon := Vector2.ONE * radius * 1.45
			var tint := color.lightened(0.35)
			# Locked art stays legible; the border carries the locked state.
			tint.a = maxf(color.a, 0.5)
			draw_texture_rect(SkillCatalog.icon(id), Rect2(at - icon / 2, icon), false, tint)

func _draw_disciplines() -> void:
	# Zoomed-out wayfinding: each spoke is named beyond its outer edge.
	var font := ThemeDB.fallback_font
	var font_size := int(clampf(260 * _zoom, 11, 34))
	var paths: Array = SkillCatalog.PATHS.keys()
	for i in paths.size():
		var at := Vector2.from_angle(TAU * i / 6.0 - PI / 2.0) * 2500 * _zoom + _pan
		var color: Color = COLORS[i / 2]
		color.a = 0.75
		draw_string(font, at + Vector2(-200, font_size * 0.35), String(paths[i]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 400, font_size, color)
