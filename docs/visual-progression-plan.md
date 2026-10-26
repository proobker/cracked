# Visual progression revision — 23 October 2026

This records the owner's requested changes and acceptance criteria so later
work does not lose them. **Implemented in the working tree, 23 October 2026;
not released.** Status of each item is listed under it.

1. **99 levels spell DEAD.** Every level is one letter pixel, not a rectangular
   grid behind a decorative word. Use exactly 99 distinct selectable cells,
   preserve level IDs/unlocks/continue, and light the whole word by reaching 99.
   Add subdued neon scenery behind the buttons without blocking interaction.
   *Done:* `LevelMap` (6×9 glyphs, D 1–24, E 25–49, A 50–75, D 76–99), lit
   halos per unlocked pixel, magenta once all 99 are lit.
2. **Skills communicate visually.** Keep the approved 405-node layout and saved
   IDs. Give each of the 39 actual effect types an original recognizable icon
   and evocative name. Repeated minor investments reuse the correct effect's
   icon, not a generic branch glyph. Human-readable purpose leads the inspector;
   precise tuning remains available in hover/details. Never expose circuit IDs
   such as evasion_circuit_1_3 as player-facing names or prerequisites.
   *Done:* `SkillCatalog.title/meaning/icon/requirements`; circuits are
   "<Skill> Echo", bridges "<Skill> Crossing". Tree draws the SVG art (plates
   for skills, circles for echoes, ring for capstones); inspector leads with
   icon, name and meaning. "Open Circuit" was renamed "Salt the Wound".
3. **Practice builds only run in Practice Range.** Campaign always uses the
   normal saved build. Attempts to use/enable a practice build from campaign
   context show “Practice build is turned off” and continue with the normal
   build. Keep practice selection separate, with an explicit route to the range.
   *Done:* the Armory toggle refuses outside the range with a non-blocking
   overlay; launching a level with practice on shows a HUD notice that wave
   banners cannot overwrite, and the run uses the saved build. Menu → Practice
   Range → ENTER RANGE is the route.
4. **Verification.** Test exact level count/unique IDs/letter mask, unlocks and
   selection, all icon/name mappings and uniqueness, unchanged graph/save IDs,
   practice-toggle warning, campaign fallback and real game snapshots. Render
   early/completed level maps, an icon contact sheet and the warning overlay.
   *Done:* `tests/check_visuals.gd` (pins the graph shape hash) and
   `tests/capture_visuals.gd` (build/visual-*.png).

Use original vector artwork for sharp Godot rendering at every zoom. Research
and design rationale: [visual progression research](visual-progression-research.md).
Android interaction/performance still needs real-device verification.

## Progressive discovery — 23 October 2026

Campaign nodes appear only when their player-level gate and an owned
prerequisite route are met. Coin balance never affects discovery, only buying.
Buying a parent reveals eligible children immediately; activation is not a
prerequisite for discovery. Fresh campaigns show three foundations. Practice
Range shows all 405 nodes. FIT frames the currently revealed nodes. Switching
back to campaign clears hidden selections, hover cards and pick targets.
Covered by check_visuals and check_expansion.
