extends Node
## Offscreen rendered UI QA, outputs ignored build/armory-*.png.
func _ready() -> void:
	if not Progress.isolated:
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	var armory := Armory.new()
	add_child(armory)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DeviceTest.capture_path("armory-starter"))
	armory.practice = true
	Progress.practice_active = ["swap_speed", "moving_accuracy", "slide_distance", "moving_reload", "slide_guard", "slide_stagger"]
	armory._preview.set_pressed_no_signal(true)
	armory._refresh()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DeviceTest.capture_path("armory-build"))
	armory._tree.fit_all()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DeviceTest.capture_path("armory-map"))
	armory._tree.focus_node("momentum_circuit_1_1")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DeviceTest.capture_path("armory-icons"))
	armory.queue_free()
	Progress.practice_guns = ["plasma", "railgun", "arc"]
	Progress.practice_grenade = "emp"
	Game.mode = Game.Mode.PRACTICE
	var game := load("res://scenes/main.tscn").instantiate() as Game
	add_child(game)
	for i in 30:
		await RenderingServer.frame_post_draw
	game._set_paused(false)
	game._touch.visible = true # Inspect the phone layout on the desktop renderer.
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_press("grenade")
	for i in 5:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DeviceTest.capture_path("expansion-practice"))
	game._player.cancel_grenade()
	Input.action_release("grenade")
	Audio.stop_all()
	print("Captured Armory starter and practice build.")
	get_tree().quit()
