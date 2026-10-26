# Operational utilities

| File | Purpose and side effects |
|---|---|
| build_release.sh | Release-signed AAB/APK build; requests signing credentials and writes build outputs |
| deploy_site.sh | Temporary gh-pages worktree, copy/commit/push website publication |
| play_games_setup.sh | Interactive Play Games account/configuration setup |
| fit_image.py | Pillow-based scale-to-cover and center crop; writes an RGB PNG at exact dimensions |
| check_game.py | Runs Godot checks with isolated user data/cloud disabled; fails on script/runtime errors |
| check_android.py | Builds a debug APK, installs it on the one attached emulator/phone, runs the checks there with real `adb input` touches and screenshots (build/android/) |

The build/setup/deployment scripts are operational; check_game.py is the test runner. Building is separate from uploading
to Play. Deployment publishes externally. Keep signing credentials outside
tracked files and documentation.

Image utility: `rtk python tools/fit_image.py INPUT OUTPUT.png WIDTH HEIGHT`.
It converts to RGB (removing transparency), resizes with Lanczos and crops
centrally. Choose a separate output path to preserve the original image.

[release.md](../release.md) owns release records. Align project.godot and both
export presets before building: build_release.sh derives its suggested GitHub
release version from the first version/name entry in export_presets.cfg.

Validate gameplay/migration before preparing expansion builds. This docs update
does not run build, setup or deployment scripts.
