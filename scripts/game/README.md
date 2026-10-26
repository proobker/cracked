# Game systems

| File | Current responsibility |
|---|---|
| main.gd | Mode, runtime assembly, event wiring, score/drops, end screens, practice |
| levels.gd | Deterministic 99-level specifications, layouts, themes, waves and scaling |
| level_run.gd | Room chain, door transitions and director configuration |
| wave_director.gd | Spawn reserves, active caps, waves and intermissions |
| progress.gd | Atomic saves, migration, reward commits, purchases and build selection |
| progression_state.gd | Deterministic earning/purchase ledger and conflict reconciliation |
| skill_catalog.gd | 405-node graph, stable IDs, costs, XP gates and capped effect aggregation |
| arsenal.gd | Nine-gun factories and campaign gun/grenade unlocks |
| coin_pickup.gd | Merged, attracted coin drops; Game owns banking |
| play_games.gd | Android sign-in, cloud snapshots, achievements, leaderboard |
| score.gd | Attempt-local score, multiplier, grace window and combo loss |
| pickup.gd | Ammo pickup area and collection |
| tuning.gd | Shared tuning and settings persisted in user://settings.cfg |
| audio.gd | Shared sound/music playback |

## Contracts

Progress.complete unlocks the next level and preserves higher scores.
to_dict/merge bridge ConfigFile and cloud JSON. Earning/purchase records merge
through ProgressionState; never merge coin balances using maxima or addition.
An XP append journal avoids rewriting the full ledger on every kill.

LevelRun emits room_cleared for every room, before level_complete on the final
room. Game uses stable attempt/room keys to bank rewards exactly once.

Main's kill handler resolves a weapon for score weighting and ammo. Unknown
sources use neutral score weighting and a carried-gun ammo drop. Unknown
weapon_by_kind calls return null; delayed damage preserves its source.

PlayGames waits for cloud loading before uploading and merges both conflicting
snapshots. The legacy leaderboard is preserved; expansion submissions are
disabled until a separate board is configured. Offline play remains supported.

## Maintenance and checks

[The handoff](../../docs/expansion-implementation.md) owns persistence, banking,
migration and reconciliation requirements. Banking belongs in one authoritative
room-finalization path, not HUD callbacks. Apply skills to attempt snapshots.

Check every clear path, last-level first clear, death/retry, duplicate rewards,
save errors, cloud merge order and wave-budget accounting for new enemy kinds.
