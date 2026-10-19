# cracked

A 3D room-clearing FPS for Android. A neon-lit death run, ninety-nine levels deep.
The design is in [plans.md](plans.md); read it before adding anything.

## Status

v2 in progress (see plans.md §11). 99 levels, each a chain of one to four
rectangular rooms, each level in its own colour theme, each room in one of
seven cover layouts, and some levels carrying a modifier (swarm,
crossfire, juggernaut, blackout, overdrive). Enemies weave, strafe and
juke. The guns have bloom, recoil with recovery, flash, tracers, impacts,
and a viewmodel that never clips into walls. Enemies only come through gates in a room's far wall.
The entry door locks behind you and the exit opens on the clear. Every
tenth level ends in a boss room. There's a level select, and progress is
saved on the phone. The rest is from v1.0.0: five moves, three guns
(rifle, shotgun, marksman), three enemy types plus the boss, the combo,
regen, the HUD with hit / weak-point / kill markers, audio, touch and
gamepad controls, settings, and the plaza as menu backdrop and practice
range.

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

## Tests

```sh
godot --headless --path . res://tests/check_levels.tscn     # all 99 levels obey the room rules
godot --headless --path . res://tests/autoplay.tscn -- 1 10 99   # clear levels unattended
godot --headless --path . res://tests/smoke_level.tscn --quit-after 1500 -- 45
```

Each exits non-zero on a failure. The autoplay restores your saved progress
afterwards.

## Build the APK

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. **Editor Settings → Export → Android**: set the Android SDK path
   (`%LOCALAPPDATA%\Android\Sdk`) and the Java SDK path (a JDK 17). Godot
   creates the debug keystore itself.
3. The `Android` preset is already in `export_presets.cfg` (package
   `com.cracked.pro`, arm64-v8a + x86_64, landscape, immersive).

```sh
godot --headless --export-debug "Android" build/cracked-1.0.0.apk
```

## Google Play Games

Sign-in, the gamer name on the menu, and level progress kept in a cloud
save, through
[godot-play-game-services](https://github.com/godot-sdk-integrations/godot-play-game-services)
v3.4.0 (MIT, in `addons/GodotPlayGameServices/`). **The project side is on**:
the plugin is enabled with its autoload, the Android build template is
installed in `android/`, and the Android export uses a Gradle build. On
desktop, and on a phone until you sign in, the game runs offline as before.

What's left needs your Google accounts. **Until the Project ID is pasted
in (step 4), the Android export fails**, because the plugin's manifest
entry needs it.

1. **Play Console** (one-time $25 developer account): create the app with
   package name `com.cracked.pro`.
2. **A release keystore**, kept out of git (`*.keystore` is ignored) and
   backed up somewhere safe:
   ```sh
   keytool -genkeypair -v -keystore cracked-release.keystore -alias cracked -keyalg RSA -keysize 2048 -validity 10000
   keytool -list -v -keystore cracked-release.keystore -alias cracked   # note the SHA-1
   ```
   For debug builds, get the SHA-1 of Godot's debug keystore too
   (`%APPDATA%\Godot\keystores\debug.keystore`, alias `androiddebugkey`,
   password `android`).
3. **Play Console → Play Games Services → Setup**: create the Play Games
   project, then add an **Android credential** (an OAuth client) for
   `com.cracked.pro` with each SHA-1 from step 2. Copy the project's
   numeric **Project ID**. Under **Testers**, add your Google account while
   the game is unpublished.
4. **In Godot**: Project → Export → Android. Paste the Project ID into
   **godot_play_game_services/game_id**, and set the release keystore,
   alias and passwords under **Keystore → Release**. Do not commit
   passwords: Godot keeps them in `.godot/export_credentials.cfg`, which is
   git-ignored.
5. Optional: create a leaderboard and achievements in the Play Console and
   paste their IDs into the constants at the top of
   `scripts/game/play_games.gd`. The leaderboard takes the sum of your best
   score on every level. The achievements fire on the first clear of
   levels 10, 25, 50 and 99.
6. Build a release-signed APK (`--export-release "Android" build/cracked.apk`)
   and install it. The menu shows your gamer name, or a SIGN IN button.

If sign-in fails with a "developer error", the APK's signing SHA-1 is not
one of the Android credentials from step 3. Debug and release builds are
signed by different keys, and each needs its own credential.

Current setup: Play Games project ID `676484758327` (Cloud project
`cracked-512108`), Android credentials for the release and debug keys,
saved games on, OAuth consent screen published. `tools/play_games_setup.sh`
walks through all of the above from scratch.

## Release builds and the website

```sh
bash tools/build_release.sh   # asks for the keystore password; builds build/cracked.aab + build/cracked.apk
bash tools/deploy_site.sh     # publishes site/ (and the builds) to gh-pages
```

The site at <https://cracked.rabidahal.com.np> (home, privacy policy, terms)
lives in `site/` and is served by GitHub Pages from the `gh-pages` branch;
Cloudflare has a DNS-only CNAME `cracked` → `proobker.github.io`. Upload
`build/cracked.aab` to Play (Internal testing). Store screenshots come from
`godot --path . --resolution 1920x1080 res://tests/capture_store.tscn`.

## Layout

```
scenes/menu.tscn            title screen (main scene)
scenes/main.tscn            a run or the practice range; scripts/game/main.gd builds it
scripts/game/               main, tuning (every tunable + saved settings), audio,
                            levels (the 99, generated), level run (rooms in order),
                            wave director (one room's waves), progress, score, pickups
scripts/input/              the single input layer: touch, gamepad, keyboard → intents
scripts/player/             movement, health, aim assist, weapon slots
scripts/weapons/            weapon base, rifle, shotgun, marksman
scripts/enemies/            enemy base, rusher, shooter, heavy, boss, projectile
scripts/world/              rooms, the plaza, shared blockout builders and skyline
scripts/ui/                 HUD, crosshair and markers, touch controls, menu, level select, settings
tests/                      headless checks: every level's rules, and an autoplay that clears levels
audio/                      CC0 sound and music, see CREDITS.md
models/enemies/             CC0 robot models and textures, see CREDITS.md
addons/                     the Play Games plugin
android/                    the Android build template (build/ is git-ignored)
android_icons/              adaptive launcher icon layers
```

## Credits

All sound and music is CC0. See [CREDITS.md](CREDITS.md).
