# Verification

Tests are Godot scenes so autoloads exist. Run from the repository root:

```sh
rtk proxy python tools/check_game.py res://tests/check_levels.tscn
rtk proxy python tools/check_game.py res://tests/check_expansion.tscn
rtk proxy python tools/check_game.py res://tests/check_combat.tscn
rtk proxy python tools/check_game.py res://tests/autoplay.tscn -- 1 10 99
rtk proxy python tools/check_game.py --rendered res://tests/capture_armory.tscn
rtk proxy python tools/check_game.py --rendered res://tests/check_mouse_capture.tscn
rtk proxy python tools/check_game.py res://tests/check_visuals.tscn
rtk proxy python tools/check_game.py --rendered res://tests/capture_visuals.tscn
```

Set GODOT to the installed executable if it is not on PATH. The wrapper redirects
user data to ignored build/test-profile and adds --isolated to disable cloud
and normal save loading/writing. Disk tests explicitly exercise the redirected profile.

- check_levels.gd: deterministic levels, wave/room rules, cover and gates.
- check_expansion.gd: 405-node reachability/effect caps, purchases, concurrent
  spends, migration, save rollback, banking, Armory picking and hover descriptions.
- check_combat.gd: real physics rays for rail/arc/blast/shield/support, burst,
  charge cancellation, burn stacking, grenade input and paused fuse behavior.
- capture_armory.gd: rendered desktop graph and touch-layout screenshots.
- check_mouse_capture.gd: actual rendered mouse modes during gameplay, pause,
  menu/Armory and focus transitions; unscaled look deltas and paused-motion rejection.
- check_visuals.gd: galaxy layout (one spaced star per level, finale at the
  core, abyss past the rim), reveal/pick/flight, no digits on the map, 39 unique names and icon artwork, no save IDs in
  hover card/inspector, hover card following the pointer, Armory fitting a 4:3
  window, pinned 405-node graph shape, practice refusal outside the
  range, campaign fallback to the saved build and the persistent HUD notice.
- capture_visuals.gd: rendered build/visual-*.png for early/whole/late galaxy, the ending,
  the icon contact sheet at real sizes, tree close/overview and both notices.
- autoplay.gd: instant kills, player kept alive, door traversal and progression;
  restores its progress snapshot on normal completion.
- smoke_level.gd: selected-level runtime smoke exercise.
- capture_store.gd: screenshot utility, not a correctness test.
- bench_level.gd: frame time and draw calls per level while firing into live
  waves; needs a real renderer, e.g. `godot --rendering-method mobile
  --disable-vsync --path . res://tests/bench_level.tscn -- --isolated 3 27 63`.

Autoplay does not validate combat balance, ammo economy or device performance.
Restoration is not guaranteed after interruption. Isolate user data and disable
real cloud submission.

## Android (emulator or phone)

```sh
emulator -avd Medium_Phone_API_36.1        # or plug in a phone with USB debugging
rtk proxy python tools/check_android.py    # build debug APK, install, run all
rtk proxy python tools/check_android.py --no-build android_touch
```

Builds a debug APK (tests/ is exported with it), then runs check_visuals,
check_expansion, check_combat, check_levels, capture_visuals, capture_armory and
android_touch on the device, then a normal launch. adb cannot pass arguments to
the Godot activity, so scripts/game/device_test.gd reads a one-shot request
file written with `run-as` (debug builds only; release builds ignore it). All
requests run isolated. Output, logs and screenshots go to build/android/.

- android_touch.gd: real `adb input` taps and swipes. Menu → galaxy map
  (locked star ignored, first star started, tap target size, fixed stick) → Armory (tap
  inspects a node, drag pans without selecting, practice toggle refused with
  the notice) → back navigation, Practice Range, Settings. In a run: touch
  controls shown, right-side swipe turns, FIRE shoots, left stick moves, II
  pauses and hides the controls. Device screenshots at every step.

Emulators do not measure real-phone thermals, frame pacing or thumb comfort.

## Expansion coverage

Use [the acceptance matrix](../docs/expansion-implementation.md#acceptance-matrix):
room/final-room rewards, migration, conflicting spends, graph/slots, every skill
and delayed damage. Extend wave counts for new enemies and isolate/restore every
new persistent field. Test fixtures must not earn real rewards/achievements.
Real-device play verifies touch and thermal performance.
