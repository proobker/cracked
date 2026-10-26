# Arsenal & Skills implementation handoff

**Implemented in the working tree. Updated 23 October 2026.** Read
[design §16](../plans.md#16-arsenal--skills--expansion) first, then the
[relevant folder guide](README.md). Release facts belong in
[release.md](../release.md). Publishing is separate from implementation.

## Delivery and completion

1. **Foundation:** persistence/migration, XP, coins, Armory, complete tree UI,
   Runner effects, SMG, burst rifle, frag. Done when migration, banking and
   valid touch-driven purchase/equip/play flows work. Unshipped nodes stay unavailable.
2. **Heavy combat:** Gunner/Demolition effects, LMG, plasma, EMP, shield robot.
   Done when every delivered rank affects gameplay and starter guns beat shields.
3. **Full expansion:** railgun, arc gun, incendiary, support robot, cross-links,
   economy tuning. Done when the acceptance matrix and device checks pass.

Implement migration before activating rewards and damage attribution before
area/delayed damage. Freeze the effective build at attempt start; skill effects
must not mutate global base tuning or leak into later attempts.

## Implementation map

- SkillCatalog owns all 405 node IDs, graph, XP thresholds, costs and effect descriptions.
  The original 39 IDs are unchanged. Six disciplines each add 60 circuit nodes
  and one bridge. Minor effects aggregate into existing combat stat keys and
  are capped at three rank-equivalents (one for capacity/capstones).
- Arsenal owns campaign unlocks and factories; Player constructs the selected
  three guns and freezes the build at attempt start.
- Progress coordinates saves/rewards/selections; ProgressionState deterministically
  reconciles earning outputs and purchases. Atomic ConfigFile checkpoints have
  a prior backup. A small append-only XP journal avoids full-save writes per kill.
- LevelRun now emits room_cleared before level_complete for the final room.
  Game commits collected and remaining room coins once and replenishes grenades.
- Combat and Ordnance handle attributed damage, occlusion, explosions, fields
  and trajectories; unknown weapon kinds return null rather than the first gun.
- Armory and SkillTree provide one zoomable icon graph, hover/tap inspection, permanent rank purchases,
  free activation, three weapon selectors and separate practice builds.
- PlayGames debounces uploads, rejects invalid/newer snapshots and keeps
  expansion scores off the configured legacy leaderboard.

## Initial tuning and validation status

- Player levels: cumulative XP = 100 × (level - 1) × level, capped at 30.
- Major node rank price: player-tier gate × 20 × purchased rank; minor/bridge price: tier × 5.
- Active slots: 4 / 8 / 14 / 24 at player levels 1 / 5 / 15 / 25.
- Circuit bonuses: 0.25 rank-equivalent; bridges: 0.5. All nodes have real effects;
  repeated effects are small alternative investments, not unique mechanics.
- Kill XP: max(10, enemy points / 5); coins: max(6, points / 20) + floor(level / 5).
- Room XP: 50 + 3 × campaign level. Level-clear XP: another 100 + 5 × level.
- First-clear bonus: 30 + 2 × level coins and 100 + 10 × level XP.
- All effect magnitudes are in SkillCatalog descriptions; gun tuning is in
  ExpansionWeapon. The new models are procedural; existing CC0 shot sounds
  use distinct pitch/cadence profiles.
- Expansion/progression and combat checks pass, as do all 99 layout checks and
  traversal of levels 1, 10, 15, 25, 45 and 99. Rendered desktop captures were inspected.
- Remaining release validation: named Android device, sustained 60 fps target /
  30 fps floor, touch comfort, audio, balance without skills, live Play Games
  conflicts/achievements and configuration of a separate expansion leaderboard.
  No store upload or release build is implied by these checks.

## Ownership boundaries

These are logical responsibilities; Progress currently coordinates progression,
economy and selection persistence, with the pure ledger in ProgressionState.

| Boundary | Owns |
|---|---|
| Progression | Idempotent XP, player level, campaign clears and catalog unlocks |
| Economy | Room coins, bank commits, rank payments and transaction reconciliation |
| Skill catalog/evaluator | Stable IDs, ranks, prices, tier/prerequisite graph, active validation and effects |
| Loadout catalog | Stable gun/grenade IDs, availability, factories and defaults |
| Combat reward event | Attempt/room/enemy identity, damage source/owner and reward attribution |
| Armory | State presentation and service requests; no independent reward accounting |
| Run coordinator | Frozen build, room boundaries, cleanup and persistent-service calls |

Reject invalid purchases without mutating state. Emit persistent change signals
after successful durable writes. Save failures retain pending state, show retry
feedback and never report a successful purchase prematurely.

## Tree and effects

Represent the tree as a directed acyclic graph with alternative-parent routes.
Validate player tier, purchased ranks, shipped availability, unique active nodes,
slot budget and one capstone. A node needs one active route to a foundation;
deactivating a parent preserves dependents only when another active route exists.
Ranks alter strength, not slot cost. Capacity is a single-rank +1 exception.

Operational definitions:

- Sprint recovery shortens the weapon-ready delay after sprinting.
- Post-dash handling temporarily improves recoil/spread after a dash.
- Sustained-fire handling reduces movement-related aim penalty during held fire;
  it remains distinct from bloom control and recoil recovery.
- Grenade placement handling reduces movement-induced throw deviation; preview
  must match the actual throw.
- A narrow dodge is a hostile projectile passing within a tuned near-miss
  radius during a dash without damaging the player. Reward each projectile at
  most once, with a cooldown; add no invulnerability.
- A primed stagger is consumed by the next shot even on a miss. Bosses resist
  it. Repeated effects cannot maintain permanent control.
- Temporary bonuses refresh duration instead of multiplying their strength.

Keep percentages, durations, XP thresholds, rewards, prices, fuse/radius values
and effect caps in one catalog/tuning source. The initial values above are implemented defaults; revise them from device
playtests rather than treating desktop traversal as balance evidence. Verify every rank and reset callbacks/buffs on attempt teardown.

## Saves, migration and offline conflicts

Version the save format. Persist clears, XP/reward records, purchased ranks,
active IDs, three gun IDs, grenade ID and separate score eras. Use atomic writes
with a recoverable prior copy; preserve unsupported newer saves instead of
overwriting them. Validate malformed amounts, ranks and IDs.

Use unique attempt IDs, room indices and per-room spawn IDs. Kill/room/clear
events have stable idempotency keys. Replays create new attempts; retrying a
commit reuses its key. Coins become persistent earnings only at room clear.
XP is committed when earned and survives death. Pause keeps transient state;
process termination discards unbanked coins.

Migration unions best-score keys with levels below the highest unlock. A clear
of level 99 requires its own saved entry. Give deterministic per-level catch-up
awards matching first-clear XP/coin bonuses, once across devices, and derive
catalog unlocks. Preserve legacy scores; invent no historical kill rewards.

First implementation cloud protocol:

1. Union immutable earning/purchase records by unique ID. Reject conflicting
   payloads under the same ID; repeated identical records are harmless.
2. Deduplicate first-clear/migration bonuses by level and reward category. Derive
   XP from unique records rather than adding device totals.
3. Purchases identify node/rank, cost, causal prerequisites and consumed earning
   outputs; change receives deterministic output IDs.
4. Validate the transaction DAG. Concurrent spends of the same coins use a
   stable transaction-ID tie-break. Reject the losing purchase and dependent
   spends; duplicate rank purchases accept one valid payment only.
5. Recompute balance/ranks from accepted records. Explain rolled-back provisional
   offline purchases to the player. Never grant both conflicting purchases or
   leave a negative balance.
6. Preserve valid local build/loadout selections on merge. Remove invalid
   dependents after reconciliation and fall back to starter gear if needed.
   An ongoing attempt retains its snapshot; reconciliation affects the next one.

This provides client consistency, not a cheat-proof backend. Retain the journal
initially. Stress-test save size/upload latency; compact only after equivalent
merge behavior has been demonstrated.

## Combat, controls and presentation

One enemy death awards score/XP/coins once despite overlapping burn/blast/chain
hits. Delayed damage retains its source after a swap. Non-gun effects use neutral
score weighting and feed carried-gun ammo; never silently fall back to rifle
attribution. Precision flags apply only to attacks that support weak-point hits.

Projectiles/fields live in the paused world. Walls stop blasts/chain hops;
overlapping incendiary fields apply one damage tick rather than summed damage.
Cap controls and give bosses resistance. Healing/shields grant no extra rewards.

Armory displays costs, ranks, paths, slots, XP and banked coins. HUD distinguishes
unbanked room coins; clear feedback confirms the bank. Practice previews all
shipped gear/builds without modifying permanent selections or earning rewards.

Route grenade states through common input. Pause/focus loss cancels a pending
preview without spending a charge. The actual throw suppresses firing; pause
reload progress during the throw, then resume. Test simultaneous movement/look.

## Acceptance matrix

| Area | Cases |
|---|---|
| Banking | Ordinary/final/one-room clear, duplicate signal, death before/after bank, abandonment, replay, remaining-drop collection |
| XP | Kill before death, room/level bonuses, first clear of 99, reload, player-level cap |
| Migration | Fresh/legacy/zero-score clear/final clear, repeated migration, local/cloud overlap |
| Cloud | Replayed snapshots, merge-order reversal, disjoint earnings, concurrent spending, duplicate rank purchase, rejected dependent spend |
| Tree | Tier/rank boundaries, forks/cross-links, alternative route, parent removal, slots, one capstone, unavailable content |
| Combat | Every gun, dry swapping, reload/scope, delayed sources, simultaneous lethal effects, walls, chain caps, boss resistance, interrupted repair |
| Lifecycle | Background/resume, cancelled preview, process exit, save failure/retry, scene teardown |
| Practice | Full preview, no progression rewards, restored campaign selection |
| Balance | Starter/no-skill viability, early/late/boss/final levels, first-upgrade affordability |
| Performance | Sustained Android play with effects/coins/enemies: target 60 fps, floor 30 fps |

Run existing generated-level/traversal checks plus targeted new tests. Isolate
test saves and disable real cloud uploads. Autoplay is not proof of balance.
