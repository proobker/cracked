# cracked

A 3D room-clearing FPS for Android. A neon-lit death run across a hostile galaxy.
The design is in [plans.md](plans.md); read it before adding anything.
For expansion implementation, continue to the [agent handoff](docs/expansion-implementation.md).
[Release history](release.md) tracks versions; [the documentation index](docs/README.md)
links code guides in their respective folders.

## Status

**v1 is built and publication is underway.** The supplied Play Console record
lists **1.0.1 / code 2** as Active on 19 October 2026; the release track and
public availability are unspecified. See [release.md](release.md).

The campaign is generated: each level is a chain of one to four
rectangular rooms, each level in its own colour theme, each room in one of
seven cover layouts, and some levels carrying a modifier (swarm,
crossfire, juggernaut, blackout, overdrive). Enemies weave, strafe and
juke. The guns have bloom, recoil with recovery, flash, tracers, impacts,
and a viewmodel that never clips into walls. Enemies only come through gates in a room's far wall.
The entry door locks behind you and the exit opens on the clear. Every
tenth level ends in a boss room. Past the campaign wait a one-room finale (25 waves of bosses) and an endless level with almost no regen. There's a level select, and progress is
saved on the phone. The baseline also includes five moves, three guns
(rifle, shotgun, marksman), three enemy types plus the boss, the combo,
regen, the HUD with hit / weak-point / kill markers, audio, touch and
gamepad controls, settings, and the plaza as menu backdrop and practice
range.

### Arsenal & Skills — implemented, unreleased

The working tree now includes player XP, a 405-node branching icon skill tree, enemy coins banked at room clears,
permanent skill upgrades, three-gun loadouts, six new guns, three grenades and
two enemy types. See [plans §16](plans.md#16-arsenal--skills--expansion)
for rules and milestones. Open **ARMORY** from the menu or level select.
Use **Practice build** to try unlocked gear and skills without changing campaign
progress; start Practice Range from the menu to use that preview build. The old rooms-and-levels “v2” label was a design
iteration, not a released Android 2.0 version.

## Install on a phone

1. Get `build/cracked-debug.apk` (build it as below).
2. On the phone, allow installs from unknown sources for your file manager,
   or use USB debugging and run `adb install -r build/cracked-debug.apk`.

The command below produces a **debug-signed** development build. Store builds
use the release-signing workflow. A release-signed build cannot upgrade an
installation signed with a different debug key.

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
| Grenade | G: hold to preview, release to throw; drag outside to cancel | Left bumper | G |
| Pause | II | Start | Esc |

## Requirements

- [Godot 4.7](https://godotengine.org/download) (standard build, not .NET)
- For Android export: Android SDK (platform-tools, build-tools) and JDK 17

## Run on desktop

Open `project.godot` in Godot and press F5, or run `godot --path .`.

## Tests

The runner isolates Godot user/editor data under ignored build/test-profile,
passes --isolated to disable live cloud writes, and fails on runtime errors.

```sh
rtk python tools/check_game.py --editor --quit
rtk python tools/check_game.py res://tests/check_expansion.tscn
rtk python tools/check_game.py res://tests/check_combat.tscn
rtk python tools/check_game.py res://tests/check_levels.tscn
rtk python tools/check_game.py res://tests/autoplay.tscn -- 1 10 15 25 45 99
rtk python tools/check_game.py --rendered res://tests/capture_armory.tscn
rtk python tools/check_game.py res://tests/check_visuals.tscn
rtk python tools/check_game.py --rendered res://tests/capture_visuals.tscn
rtk python tools/check_game.py --rendered res://tests/check_mouse_capture.tscn
# Android emulator/phone: debug APK, on-device checks, real touch tour
rtk python tools/check_android.py
```

Set GODOT to your executable if it is not found automatically. The rendered
check captures screenshots under build/ using an offscreen desktop window.
See [test coverage and limitations](tests/README.md). The Android checks run
on an emulator; real-phone thermal performance, thumb comfort and Play Games
account testing remain release checks.

## Build the APK

1. In Godot: **Editor → Manage Export Templates → Download and Install**.
2. **Editor Settings → Export → Android**: set the Android SDK path
   (`%LOCALAPPDATA%\Android\Sdk`) and the Java SDK path (a JDK 17). Godot
   creates the debug keystore itself.
3. The `Android` preset is already in `export_presets.cfg` (package
   `com.cracked.pro`, arm64-v8a + x86_64, landscape, immersive).

```sh
godot --headless --export-debug "Android" build/cracked-debug.apk
```

## Google Play Games

Sign-in, the gamer name on the menu, and level progress kept in a cloud
save, through
[godot-play-game-services](https://github.com/godot-sdk-integrations/godot-play-game-services)
v3.4.0 (MIT, in `addons/GodotPlayGameServices/`). **The project side is on**:
the plugin is enabled with its autoload, the Android build template is
installed in `android/`, and the Android export uses a Gradle build. On
desktop, and on a phone until you sign in, the game runs offline as before.

This repository already has project configuration recorded below. The steps
that follow are setup/recovery reference, not a claim that setup is still
pending. A fresh configuration needs the Project ID for the plugin manifest.

1. **Play Console**: create the app with
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
5. For a fresh setup, create a leaderboard and achievements in the Play Console and
   paste their IDs into the constants at the top of
   `scripts/game/play_games.gd`. The leaderboard takes the sum of your best
   score on every level. The achievements fire on the first clear of
   levels 10, 25, 50, 99 and 100 ("Galaxy Conquered": its ID is empty until
   you create it; the icon is `store/achievements/galaxy_conquered.png`).
   `ENDLESS_LEADERBOARD_ID` is optional and takes the furthest endless wave.
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
`godot --path . --resolution 1920x1080 res://tests/capture_store.tscn` (saved to
`store/screenshots/`).

## Layout

```
scenes/menu.tscn            title screen (main scene)
scenes/main.tscn            a run or the practice range; scripts/game/main.gd builds it
scripts/game/               main, tuning (every tunable + saved settings), audio,
                            levels (generated campaign, finale, endless), level run,
                            wave director (one room's waves), progress, score, pickups
scripts/input/              the single input layer: touch, gamepad, keyboard → intents
scripts/player/             movement, health, aim assist, weapon slots
scripts/weapons/            weapon base, rifle, shotgun, marksman
scripts/enemies/            enemy base, rusher, shooter, heavy, boss, projectile
scripts/world/              rooms, the plaza, shared blockout builders and skyline
scripts/ui/                 HUD, crosshair and markers, touch controls, menu, level select, settings
tests/                      headless checks: every level's rules, an autoplay that clears levels,
                            and the store screenshot capture
audio/                      CC0 sound and music, see CREDITS.md
models/enemies/             CC0 robot models and textures, see CREDITS.md
addons/                     the Play Games plugin
android/                    the Android build template (build/ is git-ignored)
android_icons/              adaptive launcher icon layers
store/                      Play Store listing: text (listing.md), graphics, screenshots,
                            Play Games achievement and leaderboard icons, ChatGPT prompts
site/                       the website (cracked.rabidahal.com.np), published to gh-pages
tools/                      release build, site deploy, Play Games setup wizard, image fitter
build/                      exported .aab/.apk (git-ignored)
```

## Code documentation

[docs/README.md](docs/README.md) indexes the guides colocated with game systems,
player, weapons, enemies, input, UI, world, scenes, shaders, tests, tools,
website, Android exports and addons. They distinguish current behavior from
implemented expansion behavior and remaining release validation.

## Credits

All sound and music is CC0. See [CREDITS.md](CREDITS.md).
