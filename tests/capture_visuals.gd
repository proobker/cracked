extends Node
## Offscreen rendered QA for docs/visual-progression-plan.md; writes ignored
## build/visual-*.png: early, whole and finished galaxy maps, the ending, the 39-icon contact
## sheet, the tree up close and zoomed out, and both practice notices.
func _ready() -> void:
	if not Progress.isolated:
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	Progress.restore({})
	Progress.merge({"unlocked": 31, "best": {}}, false)
	var select := LevelSelect.new()
	add_child(select)
	select.open()
	await get_tree().process_frame
	select._map.skip()
	await _shot("visual-levels-early")
	select._map.look_at_all()
	await _shot("visual-levels-galaxy")
	Progress.merge({"unlocked": Levels.COUNT, "best": {}}, false)
	for n in range(1, Levels.COUNT):
		Progress.clears[str(n)] = true
	select._refresh()
	select._map.look_at_all()
	await _shot("visual-levels-late")
	select.queue_free()
	Progress.restore({})
	var ending := Conquered.new()
	ending.stats = "48210 score   ·   x22 best combo"
	add_child(ending)
	await get_tree().create_timer(2.5).timeout
	await _shot("visual-conquered")
	ending.queue_free()

	var sheet := _contact_sheet()
	add_child(sheet)
	await _shot("visual-skill-icons")
	sheet.queue_free()

	var armory := Armory.new()
	add_child(armory)
	armory.open()
	await _shot("visual-tree-discovery")
	armory.open(true)
	await get_tree().process_frame
	armory._tree.focus_node("evasion_circuit_1_3")
	armory._tree.zoom_by(0.5)
	await _shot("visual-tree-close")
	var motion := InputEventMouseMotion.new()
	# The capture window is offscreen, so the OS reports the real pointer as
	# outside and the tree's mouse_exited would hide the card mid-capture.
	for connection: Dictionary in armory._tree.mouse_exited.get_connections():
		armory._tree.mouse_exited.disconnect(connection.callable)
	var tree := armory._tree
	motion.position = Vector2(tree._positions["evasion_circuit_1_3"]) * tree._zoom + tree._pan
	tree._gui_input(motion)
	await _shot("visual-tree-hover")
	armory._tree.fit_all()
	await _shot("visual-tree-overview")
	armory.open(false)
	armory._preview.button_pressed = true
	await _shot("visual-practice-warning")
	armory.open(true)
	armory.prepare_campaign()
	armory.queue_free()

	Game.mode = Game.Mode.RUN
	Game.level = 1
	var game := load("res://scenes/main.tscn").instantiate() as Game
	add_child(game)
	for i in 10:
		await RenderingServer.frame_post_draw
	await _shot("visual-practice-notice-hud")
	Audio.stop_all()
	print("Captured visual progression screens.")
	get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DeviceTest.capture_path(name))

func _contact_sheet() -> Control:
	var root := ColorRect.new()
	root.color = Color("080d16")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.position = Vector2(16, 12)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	root.add_child(grid)
	var ids: Array = SkillCatalog.ROOTS.duplicate()
	for path: String in SkillCatalog.PATHS:
		ids.append_array(SkillCatalog.PATHS[path])
	for id: String in ids:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(150, 0)
		cell.add_theme_constant_override("separation", 0)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(row)
		# Actual sizes: inspector, close tree plate, zoomed-out echo.
		for side in [76, 36, 18]:
			var icon := TextureRect.new()
			icon.texture = SkillCatalog.icon(id)
			icon.custom_minimum_size = Vector2(side, side)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.modulate = SkillTree.COLORS[int(SkillCatalog.nodes()[id].branch)].lightened(0.35)
			row.add_child(icon)
		var label := Label.new()
		label.text = SkillCatalog.title(id)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 13)
		cell.add_child(label)
		grid.add_child(cell)
	return root
