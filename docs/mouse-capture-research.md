# FPS mouse capture research

Researched 23 October 2026 for the desktop pointer escaping Cracked's window.

## Findings from primary sources

Godot's `Input.MOUSE_MODE_CAPTURED` hides the operating-system pointer and locks
its position to the window center. `MOUSE_MODE_HIDDEN` only hides it; confined
modes restrict its position to the window but do not provide the same centered
capture behavior. Captured camera controls should use motion deltas, with the
crosshair drawn separately by the HUD. The HUD separation is our implementation
recommendation, not a claim about Minecraft's internals.
[Source: Godot Input mouse modes](https://docs.godotengine.org/en/stable/classes/class_input.html#enum-input-mousemode).

For aiming, Godot explicitly recommends `InputEventMouseMotion.screen_relative`.
Unlike `relative`, this delta is unaffected by viewport content scaling, so
changing the window size or stretch factor does not change the input sensitivity.
[Source: Godot mouse motion](https://docs.godotengine.org/en/stable/classes/class_inputeventmousemotion.html#class-inputeventmousemotion-property-screen-relative).

The same FPS control pattern appears in GLFW's official guide: its
`GLFW_CURSOR_DISABLED` mode supports unlimited camera movement by hiding and
locking the cursor while handling recentering and motion offsets. Its hidden
mode alone still lets the pointer move normally. GLFW advises using its built-in
mode rather than implementing cursor recentering manually. This corroborates the
general approach; it does not verify a particular Minecraft version's code.
[Source: GLFW cursor modes](https://www.glfw.org/docs/latest/input_guide.html#cursor_mode).

Godot windows expose `focus_entered`, `focus_exited`, and `has_focus()` so capture
can follow actual window focus rather than an assumption made at scene startup.
[Source: Godot Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-signal-focus-exited).

## Recommended Cracked behavior

These are project decisions based on those capabilities:

- Capture only during focused desktop gameplay; let Godot handle pointer locking.
- Keep the HUD crosshair centered and rotate the camera using screen motion deltas.
- Release capture for menus, pause, completion, death, and focus loss.
- Pause on focus loss. Returning to the game should require an explicit resume,
  so Alt+Tab cannot resume combat accidentally.
- Ignore gameplay mouse look while uncaptured. Clear held combat inputs when
  pausing, and consume the resume/capture click so it cannot also fire a shot.
- Preserve touch input on Android; a touchscreen does not need desktop capture.

Verify in a real window that repeated horizontal motion rotates indefinitely
without reaching a desktop edge, Escape frees the pointer, Alt+Tab pauses,
resume recaptures, and menu/Armory interaction remains normal. Headless checks
can verify state transitions but cannot prove operating-system cursor locking.
