# Cracked release history

Package: `com.cracked.pro`. Last Play Console update supplied by the owner:
**19 October 2026**. Documentation recorded **22 October 2026**.

## Recorded releases

| Version | Code | Artifact | Uploaded (Console display) | Observed status |
|---|---:|---|---|---|
| 1.0.1 | 2 | App bundle | 19 Oct 2026, 10:38 | Active; track unspecified |
| 1.0.0 | 1 | App bundle | 19 Oct 2026, 08:58 | Not supplied |

Source: owner-provided Play Console excerpt. Upload timezone, release track,
production availability, source commits and per-version changes were not supplied.
“Active” alone does not establish public production availability. The excerpt
also displayed “Enhanced” and “≤ 100”; their column meanings were not supplied,
so these are not interpreted as rollout or install counts.

## 1.1.0 (code 3) — Galaxy, Arsenal & Skills

**Prepared 24 October 2026; not yet uploaded.** Bundles the Arsenal & Skills
work below with:

- Galaxy level map: named stars on spiral arms, zoom-out/zoom-in flight between
  levels, no level count shown anywhere (game, site, store).
- Level 100 "The Crown": one 36x64 m open room, 25 boss waves (1 → 2 → 3 bosses).
  "Galaxy Conquered" ending screen and achievement (ID pending in Play Console).
- Level 101 "The Abyss": endless waves, 10% regen; best wave saved and synced.
- Fixed-position touch joystick; icon-first Armory.
- Cloud saves can now hold unlocked > 99; older versions refuse to merge them and
  pause upload instead of overwriting.
- Store: new listing copy, What's new text, nine new 1920x1080 screenshots,
  `store/play-games/ach_100.png`.

## Unreleased — Arsenal & Skills

**Implemented in working tree, 23 October 2026; not uploaded.** No new version
name, version code or upload date assigned.
See [design §16](plans.md#16-arsenal--skills--expansion) and
[implementation handoff](docs/expansion-implementation.md).

- Player XP, 405 branching skill nodes, permanent coin-funded ranks and freely selected builds.
- BYTEPATH-inspired icon canvas, pan/zoom, hover explanations, tap inspection and keyboard navigation.
- Progressive campaign node discovery: show skills once level/prerequisites
  are met, even without enough coins; keep the complete tree in Practice Range.
- 39 original skill icons and names (echo/crossing nodes reuse them); level select spells DEAD
  with its 99 buttons; practice builds only apply in Practice Range, with a visible notice.
- Desktop FPS mouse capture, visible cursor confinement in menus/Armory/pause,
  focus-loss release, focus-return restoration and resolution-independent mouse look.
- Preserved original 39 purchase IDs; 366 minor/bridge investments, capped combined effects,
  and active slots expanding from 4 to 8/14/24 at player levels 5/15/25.
- Enemy coins banked on room clears; current-room coins lost on death.
- Three-gun loadouts, six new guns and frag/EMP/incendiary grenades.
- Shield/support robots, save migration and separate expansion scores.
- All planned arsenal systems implemented; device balance and release validation remain pending.

These describe the unreleased working tree, not historical changes to 1.0.0/1.0.1.

Validation: Godot 4.7.2 import, expansion and combat checks, all 99 generated
levels, traversal of 1/10/15/25/45/99, and rendered Armory/touch-layout captures.
Headless checks intentionally skip audio playback. No Android export/upload,
real-phone thermal/touch validation, or live cloud account test was performed.
The expansion leaderboard ID remains empty to protect legacy rankings.

## Current development metadata

Local Android playtest, 23 October 2026: exported the latest working tree as
`build/android/cracked-debug.apk`, installed it on `Medium_Phone_API_36.1`
(`emulator-5554`), and verified normal foreground launch without game errors.
This is a debug build for manual testing, not a Play upload or release artifact.

Project version and both Android presets now agree on **1.0.1 / code 2**;
the versioned APK export path was aligned as well. These retain the latest
known uploaded identity; they do not make this expansion an uploaded 1.0.1
artifact. Assign a new name/code before exporting an uploadable expansion build.

## Release procedure

1. Record the actual shipped subset, fixes, validation and remaining issues.
2. Check the highest uploaded Play version code before assigning a strictly
   higher code; this record does not reserve code 3.
3. Choose a version name: patch for fixes, minor for additive features, major
   for deliberately breaking releases. Design milestones are not version names.
4. Align project version, both export presets, artifact names and notes.
5. Record source commit/tag, build date, artifacts, signing verification and
   device results. Keep keystore credentials out of documentation.
6. Record upload time/timezone when known, track, rollout and observed status.
7. Update review/rollout history separately from build and upload events.

### Entry template

- Version name / version code:
- Status / track / rollout:
- Source commit / tag:
- Build date / artifacts:
- Upload date / timezone:
- Changes:
- Save compatibility / migration:
- Validation / device:
- Known issues:
- Approval / rollout history:

Updating this file does not publish or upload anything.
