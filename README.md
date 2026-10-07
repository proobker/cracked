# cracked

A 3D wave-survival FPS for Android. A neon-lit death run, twenty waves deep.
The design is in [plans.md](plans.md); read it before adding anything.

## Status

First playable slice: the plaza blockout, all five moves, the rifle, rushers,
waves 1–4, the combo, health regen, the HUD, touch and gamepad controls, and
the death screen. Everything else in plans.md §11 is still to build.

## Requirements

- [Godot 4.4+](https://godotengine.org/download) (standard build, not .NET)
- For Android export: Android SDK (platform-tools, build-tools, an NDK) and
  JDK 17

## Run

Open `project.godot` in Godot and press F5. On desktop, keyboard and mouse
stand in for touch so you can test in the editor:

| Action | Keys |
|---|---|
| Move / look | WASD / mouse |
| Sprint | Shift (forward only) |
| Jump | Space |
| Crouch, or slide while sprinting | C or Ctrl |
| Dash | Q |
| Fire / reload | Left mouse / R |
| Pause | Esc |

A gamepad works on both desktop and Android.

## Export to Android

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. **Editor Settings → Export → Android**: set the Android SDK path
   (`%LOCALAPPDATA%\Android\Sdk`) and the Java SDK path (a JDK 17).
3. **Project → Export → Add… → Android**. Name the preset `Android`. Godot
   creates a debug keystore for you.
4. Plug in a phone with USB debugging on and click the one-click deploy
   button in the editor's top-right. Or build an APK from the command line:

   ```sh
   godot --headless --export-debug "Android" build/cracked.apk
   adb install -r build/cracked.apk
   ```

## Layout

```
scenes/main.tscn            entry scene; scripts/game/main.gd builds the rest
scripts/game/               main, tuning (every tunable), wave director, score, pickups
scripts/input/              the single input layer: touch, gamepad, keyboard → intents
scripts/player/             movement, health, aim assist
scripts/weapons/            weapon base + rifle
scripts/enemies/            rusher
scripts/world/              the plaza blockout and skyline
scripts/ui/                 HUD, crosshair and markers, touch controls
```
