"""Run the game's checks on an Android emulator or phone, with real touch input.

Usage: rtk python tools/check_android.py              # build, install, run all
       rtk python tools/check_android.py --no-build   # reuse build/android/cracked-debug.apk
       rtk python tools/check_android.py android_touch check_visuals

Needs one device in `adb devices` (start an emulator first, e.g.
`emulator -avd Medium_Phone_API_36.1`). Builds a debug APK, whose scenes
include tests/. adb cannot pass arguments to the Godot activity, so each scene
is requested through DeviceTest's file (written with run-as, debug builds
only). Every run is isolated: no saves, no cloud.

android_touch prints TAP/SWIPE lines; this script performs them with
`adb shell input`. Screenshots are the game's own frames (SHOT), pulled to
build/android/captures: emulators drawing Vulkan on the host GPU return blank
`adb screencap` images. Android's one-time "Viewing full screen" hint would
swallow the first tap, so it is marked as already confirmed.
A scene fails on a non-zero failure count, a script error, a crash or a timeout.
"""
from pathlib import Path
import os
import queue
import re
import shutil
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "android"
APK = OUT / "cracked-debug.apk"
PACKAGE = "com.cracked.pro"
LAUNCHER = f"{PACKAGE}/com.godot.game.GodotAppLauncher"
# Scene, timeout in seconds, and the summary line it prints when done.
SCENES = {
    "check_visuals": (240, r"VISUALS: (\d+) failures"),
    "check_expansion": (240, r"EXPANSION: (\d+) failures"),
    "check_combat": (240, r"COMBAT: (\d+) failures"),
    "check_levels": (300, r"^(OK)$|FAIL"),
    "capture_visuals": (240, r"Captured visual progression screens"),
    "capture_armory": (240, r"Captured Armory starter and practice build"),
    "android_touch": (420, r"ANDROID TOUCH: (\d+) failures"),
}
ERRORS = re.compile(r"SCRIPT ERROR|^ERROR:|FATAL EXCEPTION|Fatal signal")
# Emulator images without Google Play services cannot reach Play Games; the
# plugin reports that, and it is not a game failure.
EXPECTED = re.compile(r"GodotPlayGameServices|com\.google\.android\.gms|PlayGames")


def adb(*args, check=True, capture=True, timeout=60):
    result = subprocess.run(["adb", *args], capture_output=capture, timeout=timeout)
    if check and result.returncode != 0:
        raise SystemExit(f"adb {' '.join(args)} failed: {result.stderr.decode(errors='replace')}")
    return result.stdout


def shell(command, **kwargs):
    return adb("shell", command, **kwargs).decode(errors="replace").strip()


def build():
    engine = os.environ.get("GODOT") or shutil.which("godot") or shutil.which("Godot_v4.7.2-stable_win64_console.exe")
    if not engine:
        raise SystemExit("Set GODOT to the installed Godot executable.")
    OUT.mkdir(parents=True, exist_ok=True)
    APK.unlink(missing_ok=True)
    print("Exporting debug APK (Gradle; first build takes a few minutes) ...")
    # Real APPDATA: the export needs the editor's SDK and debug keystore settings.
    # Output goes to a file, not a pipe: the Gradle daemon outlives Godot and
    # inherits its handles, so reading a pipe to EOF would never finish.
    # Godot 4.7.2 can also stay alive after "[ DONE ] export"; once the log says
    # done and the APK stops growing, the export is complete and Godot is ended.
    log = OUT / "export.log"
    with log.open("w", encoding="utf-8") as sink:
        proc = subprocess.Popen([engine, "--headless", "--path", str(ROOT), "--export-debug", "Android", str(APK)],
                                stdout=sink, stderr=subprocess.STDOUT)
        started, size, code = time.time(), -1, None
        while time.time() - started < 1200:
            code = proc.poll()
            if code is not None:
                break
            text = log.read_text(encoding="utf-8", errors="replace")
            # No \b: Godot colours the log, so "export" follows an ANSI code ("...[1mexport").
            if re.search(r"DONE.*export", text) and APK.exists():
                if APK.stat().st_size == size:
                    proc.kill()
                    code = 0
                    break
                size = APK.stat().st_size
            time.sleep(5)
        else:
            proc.kill()
    if code != 0 or not APK.exists():
        print(log.read_text(encoding="utf-8", errors="replace")[-4000:])
        raise SystemExit("Debug export failed; see build/android/export.log.")


def pull_captures():
    names = shell(f"run-as {PACKAGE} ls files/captures", check=False).split()
    folder = OUT / "captures"
    folder.mkdir(parents=True, exist_ok=True)
    for name in names:
        if name.endswith(".png"):
            (folder / name).write_bytes(adb("exec-out", "run-as", PACKAGE, "cat", f"files/captures/{name}", timeout=30))
    return [n for n in names if n.endswith(".png")]


def logcat_lines(proc, lines):
    for raw in proc.stdout:
        lines.put(raw.decode("utf-8", errors="replace").rstrip("\r\n"))


def run_scene(scene, args=""):
    timeout, done = SCENES.get(scene, (300, r"(\d+) failures"))
    shell(f"am force-stop {PACKAGE}")
    request = f"res://tests/{scene}.tscn {args}".strip()
    shell(f"run-as {PACKAGE} sh -c 'mkdir -p files && echo \"{request}\" > files/device_test.txt'")
    adb("logcat", "-c")
    proc = subprocess.Popen(["adb", "logcat", "-v", "raw", "-s", "godot:V", "AndroidRuntime:E", "DEBUG:V"],
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    lines = queue.Queue()
    threading.Thread(target=logcat_lines, args=(proc, lines), daemon=True).start()
    shell(f"am start -n {LAUNCHER}")
    started = time.time()
    problems, log, result, seen_request, shots = [], [], None, False, []
    try:
        while time.time() - started < timeout:
            try:
                line = lines.get(timeout=1)
            except queue.Empty:
                if seen_request and not shell(f"pidof {PACKAGE}", check=False):
                    problems.append("app exited before reporting a result")
                    break
                continue
            log.append(line)
            if line.startswith("DEVICE TEST MISSING"):
                problems.append(line)
                seen_request = True
                break
            if line.startswith("DEVICE TEST"):
                seen_request = True
            words = line.split()
            if words[:1] == ["TAP"]:
                shell(f"input tap {words[2]} {words[3]}")
            elif words[:1] == ["SWIPE"]:
                shell(f"input swipe {' '.join(words[2:7])}")
            elif words[:1] == ["SHOT"]:
                shots.append(words[1])
            elif line.startswith("CHECK FAIL") or (ERRORS.search(line) and not EXPECTED.search(line)):
                problems.append(line)
            match = re.search(done, line)
            if match:
                result = match
                break
    finally:
        proc.kill()
    (OUT / f"{scene}.log").write_text("\n".join(log), encoding="utf-8")
    if not seen_request:
        problems.append("the app never picked up the test request (is the APK a debug build?)")
    if shots:
        captured = set(shell(f"run-as {PACKAGE} ls files/captures", check=False).split())
        missing = [s for s in shots if f"touch-{s}.png" not in captured]
        if missing:
            problems.append(f"screenshots not captured: {', '.join(missing)}")
    if result is None:
        problems.append(f"no result within {timeout} s")
    elif result.groups() and result.group(1) not in (None, "OK", "0"):
        problems.append(result.group(0))
    elif "FAIL" in result.group(0):
        problems.append(result.group(0))
    return problems


def normal_launch():
    """The real game after the tests: request consumed, menu renders, no errors."""
    shell(f"am force-stop {PACKAGE}")
    adb("logcat", "-c")
    shell(f"am start -n {LAUNCHER}")
    time.sleep(12)
    log = adb("logcat", "-d", "-v", "raw", "-s", "godot:V", "AndroidRuntime:E").decode(errors="replace")
    (OUT / "launch.log").write_text(log, encoding="utf-8")
    problems = [l for l in log.splitlines() if ERRORS.search(l) and not EXPECTED.search(l)]
    if "DEVICE TEST" in log:
        problems.append("a normal launch ran a test request")
    if not shell(f"pidof {PACKAGE}", check=False):
        problems.append("the game is not running after launch")
    focus = shell("dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'", check=False)
    if PACKAGE not in focus:
        problems.append(f"the game is not in the foreground: {focus}")
    return problems


def main():
    args = sys.argv[1:]
    skip_build = "--no-build" in args
    scenes = [a for a in args if not a.startswith("--")] or list(SCENES)
    devices = [l for l in adb("devices").decode().splitlines()[1:] if l.strip().endswith("device")]
    if len(devices) != 1:
        raise SystemExit(f"Need exactly one device or emulator; found {len(devices)}.")
    print("Device:", shell("getprop ro.product.model"), "Android", shell("getprop ro.build.version.release"),
          shell("getprop ro.product.cpu.abi"), shell("wm size"))
    if not skip_build:
        build()
    # The immersive-mode hint takes focus on first launch and eats one tap.
    shell("settings put secure immersive_mode_confirmations confirmed")
    print("Installing", APK.name)
    adb("install", "-r", "-t", str(APK), timeout=300)
    OUT.mkdir(parents=True, exist_ok=True)
    report = {}
    for scene in scenes:
        print(f"== {scene}", flush=True)
        report[scene] = run_scene(scene)
        for problem in report[scene]:
            print("   ", problem)
        print("   ", "PASS" if not report[scene] else "FAIL", flush=True)
    captures = pull_captures()
    print(f"Pulled {len(captures)} rendered captures to build/android/captures")
    print("== normal launch")
    report["normal launch"] = normal_launch()
    for problem in report["normal launch"]:
        print("   ", problem)
    print("   ", "PASS" if not report["normal launch"] else "FAIL")
    shell(f"am force-stop {PACKAGE}")
    failed = [name for name, problems in report.items() if problems]
    print(f"ANDROID: {len(report) - len(failed)}/{len(report)} passed" + (f"; failed: {', '.join(failed)}" if failed else ""))
    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
