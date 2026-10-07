# cracked

A 3D wave-survival FPS for Android. A neon-lit death run, twenty waves deep.
The design is in [plans.md](plans.md); read it before adding anything.

## Status

v1.0.0, the §11 finish line. One plaza, five moves, three guns (rifle,
shotgun, marksman), three enemy types plus the wave-20 boss, twenty waves,
the combo, regen, the HUD with hit / weak-point / kill markers, audio,
touch and gamepad controls, settings, a practice range, and a menu. Builds
to a debug-signed APK. Next comes tuning by play, on a real phone.

## Install on a phone

1. Get `build/cracked-1.0.0.apk` (build it as below).
2. On the phone, allow installs from unknown sources for your file manager,
   or use USB debugging and run `adb install -r build/cracked-1.0.0.apk`.

The APK is **debug-signed**. Before a store release it needs a release
keystore, and a release-signed build can't upgrade a debug install (you'd
uninstall first).

## Controls

| Action | Touch | Gamepad | Keyboard / mouse (desktop testing) |
|---|---|---|---|
| Move | Left stick (appears under your thumb) | Left stick | WASD |
| Sprint | Push the stick past its ring | Left stick click | Shift |
| Look | Drag the right half of the screen | Right stick | Mouse |
| Fire | FIRE (you can drag on it to aim) | Right trigger | Left mouse |
| Jump | JUMP | A | Space |
| Crouch / slide | SLIDE (slides while sprinting) | B | C or Ctrl |
| Dash | DASH | Right bumper | Q |
| Reload | R | X | R |
| Swap weapon | SWAP (skips dry guns) | Y | Tab, wheel, 1/2/3 |
| Scope (marksman) | SCOPE | Left trigger | Right mouse |
| Pause | II | Start | Esc |

## Requirements

- [Godot 4.7](https://godotengine.org/download) (standard build, not .NET)
- For Android export: Android SDK (platform-tools, build-tools) and JDK 17

## Run on desktop

Open `project.godot` in Godot and press F5, or run `godot --path .`.

## Build the APK

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. **Editor Settings → Export → Android**: set the Android SDK path
   (`%LOCALAPPDATA%\Android\Sdk`) and the Java SDK path (a JDK 17). Godot
   creates the debug keystore itself.
3. The `Android` preset is already in `export_presets.cfg` (package
   `com.proobker.cracked`, arm64-v8a + x86_64, landscape, immersive).

```sh
godot --headless --export-debug "Android" build/cracked-1.0.0.apk
```

## Layout

```
scenes/menu.tscn            title screen (main scene)
scenes/main.tscn            a run or the practice range; scripts/game/main.gd builds it
scripts/game/               main, tuning (every tunable + saved settings), audio,
                            wave director (all 20 waves), score, pickups
scripts/input/              the single input layer: touch, gamepad, keyboard → intents
scripts/player/             movement, health, aim assist, weapon slots
scripts/weapons/            weapon base, rifle, shotgun, marksman
scripts/enemies/            enemy base, rusher, shooter, heavy, boss, projectile
scripts/world/              the plaza blockout and skyline
scripts/ui/                 HUD, crosshair and markers, touch controls, menu, settings
audio/                      CC0 sound and music, see CREDITS.md
android_icons/              adaptive launcher icon layers
```

## Credits

All sound and music is CC0. See [CREDITS.md](CREDITS.md).
