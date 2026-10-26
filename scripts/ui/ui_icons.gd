class_name UiIcons
## White-stroke interface icons (assets/ui), tinted where they are used, and
## the square icon buttons built from them. Words go in the tooltip.

static var _cache := {}


static func texture(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load("res://assets/ui/%s.svg" % name)
	return _cache[name]


static func button(name: String, tooltip: String, side := 64.0, tint := Color.WHITE) -> Button:
	var b := Button.new()
	b.icon = texture(name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(side, side)
	b.add_theme_constant_override("icon_max_width", int(side * 0.62))
	b.add_theme_color_override("icon_normal_color", tint)
	b.add_theme_color_override("icon_hover_color", tint.lightened(0.3))
	b.add_theme_color_override("icon_focus_color", tint.lightened(0.3))
	b.add_theme_color_override("icon_pressed_color", Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(tint, 0.3))
	return b


## A small icon for a row of HUD-like readouts.
static func glyph(name: String, side := 28.0, tint := Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture(name)
	t.custom_minimum_size = Vector2(side, side)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t
