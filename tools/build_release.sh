#!/usr/bin/env bash
# Builds the release-signed Android App Bundle (for Play) and APK (for direct
# download). The site links to them on the GitHub release (Pages caps files
# at 100 MB, and the APK is bigger).
#   bash tools/build_release.sh
# Asks for the release keystore password; it is never written to disk.
set -euo pipefail
# Run from PowerShell, bash may put Windows System32 (whose find.exe differs)
# ahead of its own tools; prefer the Unix ones.
export PATH="/usr/bin:/bin:$PATH"
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe}"
KEYSTORE="${KEYSTORE:-}"
if [[ -z "$KEYSTORE" ]]; then
  for k in "$HOME/keystores/cracked-release.keystore" /c/msys64/home/"$USERNAME"/keystores/cracked-release.keystore; do
    [[ -f "$k" ]] && KEYSTORE="$k" && break
  done
fi
[[ -f "$KEYSTORE" ]] || { echo "Release keystore not found. Re-run with KEYSTORE=/path/to/cracked-release.keystore"; exit 1; }
[[ -f "$GODOT" ]] || { echo "Godot not found. Re-run with GODOT=/path/to/Godot_console.exe"; exit 1; }

read -rsp "Release keystore password: " PASS; echo
keytool -list -keystore "$KEYSTORE" -alias cracked -storepass "$PASS" >/dev/null 2>&1 \
  || { echo "Wrong password (or alias isn't 'cracked')."; exit 1; }

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH; GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(cygpath -m "$KEYSTORE")"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=cracked
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS"

mkdir -p build
rm -f build/cracked.aab build/cracked.apk
echo "Building build/cracked.aab ..."
"$GODOT" --headless --path . --export-release "Android AAB" build/cracked.aab 2>&1 | tail -n 5
echo "Building build/cracked.apk ..."
"$GODOT" --headless --path . --export-release "Android" build/cracked.apk 2>&1 | tail -n 5
[[ -f build/cracked.aab && -f build/cracked.apk ]] || { echo "Export failed; see above."; exit 1; }

ls -la build/cracked.aab build/cracked.apk
VERSION="$(grep -m1 '^version/name=' export_presets.cfg | cut -d'"' -f2)"
echo "Done. Upload build/cracked.aab to Play (Internal testing)."
echo "Publish both for the website download buttons:"
echo "  gh release create v$VERSION build/cracked.apk build/cracked.aab --prerelease --title \"Cracked $VERSION\" --notes \"Test build\""
echo "  (or, for an existing release: gh release upload v$VERSION build/cracked.apk build/cracked.aab --clobber)"
