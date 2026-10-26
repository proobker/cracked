"""Run Godot checks with an isolated profile and fail on script/runtime errors.

Usage: rtk python tools/check_game.py --editor --quit
       rtk python tools/check_game.py res://tests/check_expansion.tscn
All Godot user/editor data is redirected into ignored build/test-profile.
"""
from pathlib import Path
import os
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
engine = os.environ.get("GODOT") or shutil.which("godot") or shutil.which("Godot_v4.7.2-stable_win64_console.exe")
if not engine:
    raise SystemExit("Set GODOT to the installed Godot executable.")
profile = root / "build" / "test-profile"
profile.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, APPDATA=str(profile), LOCALAPPDATA=str(profile), XDG_DATA_HOME=str(profile), XDG_CONFIG_HOME=str(profile))
args = sys.argv[1:]
rendered = "--rendered" in args
if rendered:
    args.remove("--rendered")
display = ["--rendering-method", "gl_compatibility", "--position", "-10000,-10000", "--resolution", "1280x720"] if rendered else ["--headless"]
if "--" not in args:
    args += ["--"]
args += ["--isolated"]
try:
    result = subprocess.run([engine, *display, "--path", str(root), *args], cwd=root, env=env,
                            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=int(os.environ.get("CHECK_TIMEOUT", "150")),
                            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
except subprocess.TimeoutExpired as exc:
    print((exc.stdout or b"").decode("utf-8", errors="replace") if isinstance(exc.stdout, bytes) else exc.stdout or "")
    raise SystemExit("Godot check timed out.")
output = result.stdout + result.stderr
print(output)
raise SystemExit(result.returncode or (1 if "SCRIPT ERROR:" in output or "ERROR:" in output else 0))
