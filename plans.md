# cracked — Design Plan

> **A 3d FPS.** A neon-lit death run, ninety-nine levels deep.
>
> **Status (2026-10-22):** v1 is built and publication is underway. Play
> Console lists 1.0.1 (code 2) as Active; its release track is unspecified.
> See [release history](release.md) for verified version records.
>
> **Arsenal & Skills (2026-10-23):** implemented in the working tree, unreleased. Read §16 for the
> authoritative expansion design and the [implementation handoff](docs/expansion-implementation.md)
> before implementing progression, weapons, grenades, or new enemies.
> Older “v2” references below identify the rooms-and-levels design iteration,
> not an Android 2.0 release. Sections 1–10 describe the existing baseline
> except where superseded by §16, which defines the implemented expansion.
>
> **Structure changed 2026-10-12:** one plaza and twenty waves → 99
> levels of rectangular rooms, enemies only through the far wall. Robot
> models replace the capsule placeholders, and Google Play Games sign-in
> was introduced behind configuration; the current repository enables it. §1, §2, §3, §7, §11, §12 and
> §15 were revised in the same change. The old text's reasoning is kept
> where it still holds, and each reversal says why it was reversed.
>
> **Platform changed 2026-10-07:** browser + mouse and keyboard → native
> Android, touch with optional gamepad. Every section that depended on the
> old platform was revised in the same change; see §1 for the reasoning.

---

## 0. Purpose of This Document

This is the design intent for `cracked`. It records **what the game is and
what it refuses to be**, so that a future decision can be checked against a
decision that was already made on purpose.

It contains no architecture and no code. Those are implementation, and
implementation is allowed to change. The one exception is the platform and
engine (§1), named here because on a phone the platform decides the
controls, and the controls decide the game. The decisions
in here are the game's identity, and changing one is a real decision that
has to be made deliberately.

Where the plan has no answer, that is a deliberate gap and it is written
down as an open question in §14 or a risk in §13 — not left implied. The
worst outcome for a document like this one is not that it is wrong, but
that a decision was made somewhere it is not recorded, by someone who did
not know it was a decision.

Read this before adding a feature. A lot of good ideas are not in here, and
that is the point — see §12.

---

## 1. Premise

| | |
|---|---|
| **Genre** | First-person shooter, room-clearing levels |
| **Setting** | Stylized low-poly neon cyberpunk city |
| **Perspective** | First person, touch controls, optional gamepad |
| **Platform** | Android, native, built in Godot 4. Landscape only |
| **Movement fantasy** | Arena twitch — fast, strafing, thumb-aim mastery, forgiving |
| **Team** | Solo |
| **Deadline** | None. Scoped for "shippable", not "impressive by Friday" |
| **Budget** | ~6–10 hours/week, realistically |

### The pitch

Fight through ninety-nine levels of neon-lit rooms. Read the incoming wave,
move fast, switch guns, and protect your combo. The expansion adds
lasting player progression: earn XP, bank enemy coins after each room, and
build a specialized loadout before the next attempt.

### What kind of game this is, precisely

Three commitments define the whole project:

1. **One room shape, done well.** A walled rectangle, with enemies coming
   only through the far wall. Every level is built from it, so the room is
   still the one thing you learn so well you stop looking at it. *(Was:
   one map. See "Why levels" below.)*
2. **Ninety-nine levels, each with a clear.** A win condition per level,
   and a boss every tenth. Endless is still a screensaver. *(Was: twenty
   waves, then a boss.)*
3. **Forgiving by design.** Health regen, generous ammo drops, wide net. The
   difficulty comes from how many decisions you have to make per second, not
   from instant death.

### Why these commitments

**Why wave survival, not a tactical campaign or a deathmatch.** A campaign
needs a level-design pipeline, scripted pacing, and authored cover. A
deathmatch needs multiple maps and AI that can path through them. Wave
survival needs exactly one map done well and enemies that walk at you. It is
the shape of shooter that can actually be finished.

**Why levels, after all (2026-10-12).** The plaza's weakness in play was
that it surrounded you: a spawn ring means something is always behind you,
and on a phone, with a thumb doing the looking, turning around is the
slowest thing you can do. A rectangle with one dangerous wall turns every
fight to face the same way. Levels also answer "one more go" better than
one 15-minute run does. A level is two to six minutes, and a death costs
one level, not twenty waves. The cost the old text named is avoided
rather than paid. There is no level-design pipeline: levels are
*generated* from their number (§3, §7), built from the room and the
systems that already exist, and the AI still only walks at you.

**Why arena twitch, not grounded tactical.** Grounded tactical in 3D is an
aiming-sim problem — hit registration, hitboxes, and camera feel all have to
be near-perfect or the game feels broken rather than hard. Arena twitch is
far more forgiving, and it suits what the game is strong at: the instant you
open the app and can shoot something. It matters even more on touch, where
aiming is coarser than a mouse and a game built on precision would be
broken rather than hard.

**Why Android.** The game lives where it is actually played: on the phone,
in a break, in landscape, one run at a time. The short level session (§2)
was always phone-shaped. Godot 4 because it is free, exports to Android
directly, produces small builds, and its Mobile renderer handles low-poly
neon without asking much of a mid-range phone.

**What that costs, written down so it is not forgotten.** The browser's
"link in a group chat" is gone. Instead there is a signing keystore, an
export pipeline, an APK to sideload, and a lifecycle (calls, notifications,
backgrounding) the game must survive (§13). Mouselook is gone too, and §4
says what replaces it. The playable build exists; publication is now underway. Expansion work remains
independent of store approval (§11).

---

## 2. Core Loop

```text
Select level and loadout -> enter room -> clear its waves -> next room
                                |                              |
                                +-- death -> retry level       +-- final room -> level clear
```

The loop, in one line: **clear a wave, spend a breather, face something
worse.**

**A wave ends when every enemy in it is dead.** Not a timer, not a health
threshold, not a quota. Waves are cleared, not survived.

### What that costs

Because a wave ends when the last enemy in it dies, **wave length is
emergent** — it is however long the player takes. A strong player may clear
wave 6 in twenty seconds. A careful one may take ninety. This is correct,
and it is worth writing down so it does not get "fixed" later.

**Wave number is the difficulty axis, never wave duration.** No wave is
padded with extra health, extra bodies, or artificial delay to protect the
session length, and nothing spawns faster because the fight is dragging.
Difficulty between waves is a composition decision made in advance, never a
mid-fight correction — the same principle that cuts mid-wave ramping in
§12, applied to pacing, for the same reason: a wave that changes under you
stops being a fight you prepared for.

### Spawning

Waves are cleared rather than timed out, which makes spawn pacing a
system rather than a convenience. Three rules, all load-bearing:

- **A wave is a budget, not a dump.** Every wave has a total enemy count
  and a cap on how many may be alive at once. Enemies beyond the cap wait
  in reserve and walk in as slots open. This is what keeps a heavy wave
  readable instead of a wall of bodies, and it is also the natural ceiling
  on how much is asked of the renderer and the AI in any one instant.
- **Nothing spawns on the player.** Spawn points are distance-gated, so no
  enemy becomes active within a set radius of the player. The promise that
  you never stand in a reload animation as things appear on top of you is
  an invariant, not a best case.
- **Every spawn is telegraphed.** A short visible and audible tell, and
  only then is the enemy active. The player is never killed by something
  that was simply already there.

### The tension that drives it

The combo multiplier rises with each kill and is at risk when you take a
hit. This is the whole game in one rule, and its exact terms are in §8.

A full reset is a legible, dramatic event. It means you were hit while
*not* killing things — which is a real mistake, and the game is allowed to
say so loudly. Turtling keeps you safe from a reset at the cost of a low
ceiling. Pushing into the crowd has a high ceiling and a real chance of
losing it. Neither is strictly better, which is what makes the balance a
player decision rather than a solved one. Most players drift toward the
aggressive line as they get better.

### Session shape

A level is **2–6 minutes**: one to four rooms, one to three waves a room,
short breaks. Short enough to play one during a break. A death restarts the
level, not the game, and the next level opens when this one is cleared.

### Levels and rooms

```
  ROOM 1 ──cleared──▶ door opens ──walk──▶ ROOM 2 ── … ──▶ LEVEL CLEARED
  (waves)                                  (door locks       (next level
                                            behind you)        unlocked)
```

The loop above is what happens *inside* a room. A level chains rooms, and
the player walks from one to the next through a corridor. The entry door
locks behind them, so a room is always fought facing one way.

---

## 3. The Map

**Rectangular rooms, chained into levels, city skyline behind them.**
*(Was: a single walled rooftop plaza. The plaza stays as the menu
backdrop and the practice range.)*

### The room

- **A rectangle, 16–24 m wide and 30–46 m long.** You enter at one short
  wall. Enemies come **only through gates in the far short wall**:
  alcoves behind the wall line, framed in red light so you always know
  where the next thing will come from. Nothing spawns at your back. This
  is the room's one rule, and it is checked in tests.
- **Cover in the middle band only**, from the same vocabulary as the
  plaza: low walls to crouch behind, tall blocks to break line of sight,
  decks and ramps. Free-standing pieces leave 3 m to each other and to the
  side walls; pieces that join (a deck and its ramps, a catwalk against
  the wall) leave no gap at all. So a walker never gets trapped (§6). This
  is checked in tests.
- **Each room has a layout and a shape.** Layouts: *scatter* (blocks
  dropped at random), *pillars* (a staggered hall of columns), *lanes*
  (long low walls to slide down), *deck* (a raised middle with full-width
  ramps), *bunkers* (block-and-wall clusters), *spine* (a broken wall down
  the middle that makes two lanes), *catwalks* (raised walkways along both
  side walls). A level never uses the same layout twice in a row. Shapes:
  the long narrow *hall*, the wide short *arena*, and the standard room.
  Boss rooms are an open arena ringed by four pillars.
- **Each level has a theme**: one of seven palettes for the neon, floor,
  fog, sky and lights, never the same as the level before. Each room has
  pools of coloured light, neon strips on its walls, and a sign over the
  far wall to navigate by.
- **About two levels in five carry a modifier**, from level 6, never on a
  boss level: *swarm* (more rushers, higher cap), *crossfire* (shooter
  heavy, from 12), *juggernaut* (two more heavies, from 32), *blackout*
  (thick fog, dim light), *overdrive* (enemies 20% faster). Modifiers
  reweight a wave within its band; they never bring a type in early.
- **The entry door locks behind you; the exit door opens on the clear.**
  An opened door glows cyan. A locked one glows red.
- **Gates are open to the top** so the boss fits through.

Levels are generated from their number with a seeded random generator, so
level *n* is always the same level, and nothing about it is stored or
authored by hand. That is what makes 99 affordable.

The rooms are enclosed by real walls you can see and use for cover. Past
the walls is a flat backdrop of the cyberpunk city: towers, neon, distant
signage. The skyline is scenery, not space. You cannot get out there, and
you never try to.

### Why contained rather than open

A city setting invites a city-sized map, which invites level design, draw
distance, tall geometry, and players seeing targets they cannot reach. All
of that is expensive. A walled plaza gets the *look* for a fraction of the
cost, and one map can then absorb real effort — sightline tuning, cover
placement, spawn rhythm — instead of being spread thin across five maps.

There are no invisible walls and no "you can't leave yet" boundaries. The
edges are walls, so the rule is never surprising.

### Arena qualities to hit

*Written for the plaza, and still the test for a room.*

- **Open enough to strafe.** A room is a long rectangle, not a corridor.
  The narrowest is 16 m.
- **Cover at mid-range.** Enough to break line of sight, not enough to camp
  in. The combo rule is the real anti-camp mechanic; cover is a tool, not a
  hiding place.
- **Some verticality, and edges worth sliding off.** Raised platforms and a
  level change, because a purely flat arena makes dash and slide feel like
  they don't do anything. Slide carries momentum and a flat plane throws
  that momentum away, so the plaza needs lips, edges, and slopes to slide
  along and off of. This couples §3 to §4: the layout and the movement are
  one design, and neither can be finalised without the other.
- **Landmarks.** Three or four shapes you can navigate by without a
  minimap. You should be able to call "he's behind the sign" and have that
  be meaningful.

---

## 4. Movement

**All five are in v1. None of these are stretch.** Dash has one condition
attached, stated in full below and in §12: its invulnerability has to cost
something, and if it cannot be made to, dash is the one that gets cut.

| Move | What it does | Why it earns its place |
|---|---|---|
| **Sprint** | Sustained speed, drains a meter that refills | The default answer to "I'm not close enough" |
| **Jump** | Standard jump | Invisible when present, infuriating when missing |
| **Crouch** | Lower profile, slower, tighter accuracy | The way you use cover without losing your gun up |
| **Slide** | Crouch at speed, low and fast, momentum carry | The arena-twitch signature move; long strafe lines |
| **Dash** | Short burst in the input direction, with a brief invulnerability window | The panic button, and the only defensive move in the game |

Movement is not decoration. In a wave shooter, evading pressure is a
first-class option alongside aiming, and if evasion is viable the game
rewards nerve rather than turtling. The rule below is what keeps that
honest: one move buys you an escape, and the other four are about
position, not safety.

### The rule that must exist: how enemies handle a moving player

Four movement states means enemies must react to all four, and a rusher
charging a player who is mid-slide or mid-dash is the classic way this looks
broken.

**The rule: enemies aim at where you are, not where you will be.** No
leading of the target on dashes or slides. Consequences, all deliberate:

- **Movement alone does not dodge.** Strafing, sliding, and jumping will
  not save you from a shooter who is already pointed at you. What saves
  you is cover, angles, and breaking line of sight — which is the real
  reason §3's mid-range cover exists.
- **Dash is the one exception, and it is a paid one.** A dash grants a
  very short invulnerability window. It is the panic button, and it is
  the only way through a shot that is already in the air. It sits on a
  cooldown, it does not chain into another dash, and it does not last long
  enough to stand and trade shots inside it. Dash moves you out of danger
  *or* through a shot — never both, and never free.
- **Rushers commit to a path and adjust slowly.** They should visibly
  overshoot a good slide, and recover from it like a person would. A rusher
  that perfectly tracks a slide is both more expensive and less fun to
  fight. A rusher you dashed past is not defeated, only passed: it turns
  and comes back, and the cooldown is what makes that exchange survivable
  rather than a loop.
- Nothing in the game should ever cancel a dash, a slide, or a jump
  mid-flight. Input commitment is the contract.

Dash is the exception that proves the rule rather than a contradiction of
it. If its invulnerability ever stops costing something — chainable,
spammable, or holdable — then both the no-leading rule and the
anti-camping logic in §6 lose their meaning. At that point dash gets cut
rather than tuned.

If enemies start to feel unfair, this rule is the first thing to change —
not the health numbers.

### Camera

**Drag to look on the right half of the screen**, 1:1, no acceleration or
smoothing. A finger moving N pixels turns the camera by N × sensitivity,
the same frame. On a gamepad, the right stick does the same job. Any lag on
the camera reads as input lag, which is unforgivable in a game whose whole
fantasy is aiming mastery.

**Light aim assist replaces mouse precision.** A thumb is coarser than a
mouse, so the camera turns more slowly when the crosshair is over an
enemy. That is all it does: no snapping, no lock-on, and no tracking
an enemy that moves. It helps you stay on a target you already found. It
never finds one for you. Its strength is a tunable and a player setting,
and zero is a valid value.

### Controls

One input layer feeds the game. Touch and gamepad produce the same
intents, and nothing in the game reads a raw touch.

| Intent | Touch | Gamepad |
|---|---|---|
| **Move** | Left virtual stick, appears where the thumb lands | Left stick |
| **Sprint** | Push the stick past its outer ring | Left stick click |
| **Look** | Drag anywhere on the right half | Right stick |
| **Fire** | Fire button (right thumb) | Right trigger |
| **Jump** | Button | A / Cross |
| **Crouch / slide** | One button. Slides if sprinting, crouches if not | B / Circle |
| **Dash** | Button | Right bumper |
| **Reload** | Button | X / Square |
| **Swap weapon** | Tap the weapon icon | Y / Triangle |
| **Scope (marksman)** | Button, toggles | Left trigger |

Buttons sit under the right thumb, so firing and looking compete for one
finger. That is the main problem with touch shooters, and v1 handles it the
simple way: the fire button also works as a look zone, so you can drag
while holding it. Whether to add an "auto-fire when on target" mode is an
open question (§14), not a v1 feature.

---

## 5. Weapons

The existing baseline has three guns, three ranges, three reasons to swap mid-fight. If there is never
a reason to switch, there should only be one gun.

| | **Rifle** | **Shotgun** | **Marksman** |
|---|---|---|---|
| **Role** | All-rounder | Close-range brawl | Long-range precision |
| **Range** | Medium | Point blank | Far |
| **Firing** | Full-auto, learn to spray | Pump, one strong shot | Semi-auto, slow |
| **Magazine** | 30 | 6 | 5 |
| **Damage** | Moderate, drops off at range | Huge at close, useless past arm's length | Highest per shot, punishing misses |
| **Reload** | Moderate | Slow and total — you are defenceless for a moment | Moderate |
| **Cost of a miss** | Low | A full reload cycle | A whole magazine |
| **Teaching** | Hold and control | Panic button, closes the gap | Stop moving, breathe, aim |

### Ammo economy

**Magazines are real and you scavenge drops from kills.** Ammo is not
infinite, and this is the single decision that makes three weapons matter.

- Every weapon carries its own reserve, tracked separately.
- Kills drop ammo for the weapon that made them, and occasionally for
  another. You are looting the fight as it happens.
- The shotgun's six shells are a resource. A dry shotgun is worse than no
  shotgun, because you are now carrying a thing that cannot help you while
  the thing that could is on the ground.

Infinite ammo was considered and rejected: it removes a whole layer of
tension and makes players never switch weapons, which is the only reason to
have three.

### Running dry

**Being out of ammo is a real state with a real answer, and it is a
decision under pressure rather than a dead end.** The order is: your
reserve, then the ammo lying on the ground from kills, then a weapon
swap. Nothing else. No infinite trickle, no emergency top-up, no free
reload — those would all dissolve the layer the plan just built.

Two rules keep it from becoming frustration instead of tension:

- **Swapping away from a dry weapon is instant.** The player carries all
  three guns, and the swap goes straight to the next one that can still
  shoot, so a dry shotgun costs one tap, not a hunt. *Decided in the build:*
  this replaces "droppable". With all three carried, dropping a gun only
  adds a pickup to manage, and the bad state it answered is answered in
  one frame anyway. "Worse than no shotgun" still holds: a dry gun is dead
  weight you have to swap past, and the HUD marks it red.
- **A dry trigger is never a surprise.** The weapon tells you it is empty
  before you commit to the shot, and it will not click on a trigger pull
  with a reload already in progress. The player is always choosing to be
  dry, never discovering it.

The rule this is all protecting: a wave is never unwinnable because ammo
happened to be in the wrong place. It can be lost, and it can be badly
lost, but the loss is always traceable to a decision the player made.

### Feel notes

- Every gun needs a distinct silhouette in first person, readable at a
  glance with no text. The shape tells you the range.
- Shotgun needs a real pump and a real stagger. It is the panic button and
  must feel like one.
- Marksman needs a scope or a tight zoom, and a shot that is *slow to
  recover from* so that a panic miss is felt. The scope is a toggle button
  rather than a hold, because a held button costs a thumb that touch does
  not have to spare. Look sensitivity drops while scoped.

*Decided in the build (v2), the shared shooter feel stack:*

- **First-shot accuracy, then bloom.** The first shot goes where you point.
  Held fire widens the cone a little each shot, and it settles when you
  stop. Moving and jumping widen it, and crouching tightens it. The
  marksman stays exact only when scoped and standing still.
- **The crosshair shows the spread.** Its gap is the cone, so bloom is
  never a hidden dice roll.
- **Recoil moves the aim, and the aim recovers.** Kick goes into the real
  view, so the bullet lands where the crosshair is. Once the trigger
  rests, the view settles back toward where the burst began. Pulling down
  against it counts toward that, so recovery never overshoots.
- **Every shot is seen**: a muzzle flash that lights the room, a tracer,
  sparks where it lands (in the enemy's colour on a hit, bigger on a kill),
  and camera shake that moves the camera without turning it.
- **The gun is alive.** It sways against your look, bobs as you run,
  drops for a sprint, dips through a reload, and rises on a swap.
- **The gun never clips into walls.** It is drawn with its depth squeezed
  in front of the world (`shaders/viewmodel.gdshader`, written for reverse
  Z), so it stays visible and the right size, even against a wall.

---

## 6. Enemies

The baseline has three types, one per role. Each teaches a different lesson by existing. Shield and support robots are specified in §16.

| | **Rusher** | **Shooter** | **Heavy** |
|---|---|---|---|
| **Role** | Pressure | Spacing | Priority target |
| **Behaviour** | Closes distance relentlessly, melee at contact | Holds range, fires, repositions to keep it | Slow advance, tanky, soaks damage |
| **Threat type** | Immediate and personal | Punishes camping | Punishes ignoring |
| **Teaches** | Do not stand still | Keep moving, deny it a clean line | Aim for the weak point, or flank |
| **Spawn weight** | Common, first to appear | Appears from wave ~4 | Rare, appears from wave ~8 |

### Design constraints

- **Rushers are the most numerous** and the cheapest. They carry the volume
  of the waves and the pressure of the opening minutes.
- **Shooters are the reason the arena's cover exists.** They are what makes
  standing still expensive, and they are what force you to move through
  space instead of clearing one corner and staying.
- **Heavies are the reason you care about accuracy.** They do not die to a
  shotgun at range, so the answer is the rifle, or positioning, or the head.
  They are the wave's punctuation — one appearing changes how the whole
  wave is played.

**Heavies carry a weak point, and hitting it is confirmed differently.** A
weak-point hit returns its own hitmarker, distinct from both a body hit and
a kill, on the same principle §9 applies to kills. Since §9 cuts damage
numbers, this is the *only* signal the player has that the weak point
landed. Without it, "aim for the weak point" is just text on a page and
§6's accuracy lesson is unlearnable.

### The deliberate omission: no cover-seeking AI

Enemies do not flank through geometry or take cover. They come toward
you, shoot from where they are, and get shot.

*Revised in the build (v2): they no longer walk in straight lines.* Motion
is steering, not pathfinding, and it costs nothing a room needs to know
about:

- **Wander.** The direction an enemy wants is bent by an angle that drifts
  smoothly toward a new random target every second or so. A per-frame
  jitter would read as twitching. The bend fades out up close, so a rusher
  still connects.
- **Separation.** Enemies push apart from each other, so a wave spreads
  across the room instead of walking in single file.
- **Jukes.** A short sidestep across your line of fire. It is likeliest
  while your crosshair is on the enemy, so it reads as a dodge. It has a
  cooldown, it never happens during a stagger, and a shooter never jukes
  out of its own windup. It moves the body only: aim is still at where you
  are (§4).
- **Rhythm per type.** Rushers weave and surge in bursts of speed.
  Shooters strafe around you at a range of their own, switch sides or
  hover for a beat, and plant still while they charge. Heavies only sway.
  The boss sidesteps now and then. Every enemy also rolls its own speed,
  ±10%.

This is a real cost to ambition, taken on purpose. Cover-seeking AI needs
pathfinding and line-of-sight logic, which is the most expensive system in a
3D shooter and the most likely thing to make a small game feel unfinished.
A rusher charging straight at you is cheap, reads perfectly at a glance, and
is satisfying to kill. Aggression is a stretch item, not a v1 requirement.

---

## 7. Waves

**Ninety-nine levels, a boss every tenth.** *(Was: twenty waves, then a
boss.)* The same four phases, stretched over the levels:

| Phase | Levels | Rooms | What changes |
|---|---|---|---|
| **Open** | 1–9 | 1 | Rushers only. Learn movement, learn the rifle, learn the room |
| **Pressure** | 10–29 | 2 | Shooters join. Two types at once, mixed composition |
| **Punishment** | 30–59 | 2–3 | Heavies join. Mixes get worse, not just bigger |
| **Breakdown** | 60–98 | 3–4 | Dense mixes, multiple heavies, up to twelve alive at once |
| **Boss** | 10, 20 … 90, 99 | last room | The §7 boss. From level 30 a rusher escort walks in with it |

A wave's bodies grow slowly with the level (about one more every six
levels). A long level is long because it has more rooms, never because
one wave is padded (§2). Boss health scales with the level: level 20's
boss is the v1 boss, and level 99's has two and a half times its health.

**Escalation must come from composition before it comes from count.** Ten
rushers is less interesting and more of the same than six rushers, two
shooters, and a heavy. Wave 14 should not be wave 9 with bigger numbers.

### Intervals

Ten seconds between waves inside a room. Between rooms the breather is the
walk to the next one, as long as the player likes. Not a menu: the room
stays live and the backdrop stays lit. This is your window to:

- Reload deliberately instead of mid-wave.
- Collect the ammo lying around.
- Read the next wave's composition and position for it.
- Finish a regen, which almost certainly did not happen during the wave
  (§8).

The interval is ten seconds because regen is five. It is not dead time
between fights — it is the only place in the run where the health system
is guaranteed to complete, and it is long enough to reload, scavenge, and
reposition in. Shortening it would take all four of those away at once.

The player should never stand in a reload animation while things spawn on
top of them. §2's distance gate makes that an invariant, and the interval
is where that promise is easiest to keep.

### The boss

The baseline boss is a large, durable enemy with ranged pressure, fought in the
last room of every tenth level and level 99. Later encounters scale its health
and add the existing escort. Its purpose is to change movement and target
priorities rather than merely demand more shots.

Preserve a readable attack tell and starter-weapon viability. The expansion
adds control resistance for EMP/stagger/slow effects; it does not require
another boss archetype. Additional boss variants remain deferred.

---

## 8. Health, Death, and Score

### Health

- Regenerates after roughly **five seconds without taking damage**.
- Health is never permanent loss, never a resource to be hoarded, and never
  something you can be fully denied. In an arena shooter with a combo rule,
  permanent health damage compounds into a death spiral.
- Damage comes from enemies, not from the environment. Falling is not a
  threat; there are no pits.

**Regen is a contact timer, not a mid-wave resource.** Five seconds clear
of damage is rare in the middle of a wave with active enemies, and the
plan does not pretend otherwise: in practice regen mostly happens during
the interval. That is not a gap — it is the reason the interval is ten
seconds. The interval exists so the health system can do its work.
Lengthening it past ten buys nothing once regen has already finished, and
shortening it below five would rob the player of the window entirely.
**Interval length and regen delay are one decision, not two.**

The forgiveness this buys is positional, not numerical. You are not
slowly healed under fire; you are expected to break contact, and the game
pays you back once the pressure is off. The player's real health resource
is *space* — which is a thing the arena can genuinely deny, and which no
number on the HUD ever can.

### Death

Death ends the run immediately. No lives, no continues, no currency, no
second chances, no loading between attempts.

The death screen is: the wave you reached, your score, your best combo,
**what killed you**, and **one key to restart**. That is the entire
meta-game of v1.

Cause of death earns its line because this is a game you replay on a loop.
"Wave 14, 42,000 score, x38 best, killed by a rusher while reloading" tells
the player the one thing that would have saved the run. A death screen
without it is a scoreboard.

### Score

- Score for each kill, weighted by enemy type and weapon.
- A **combo multiplier** that climbs with kills and is at risk when you
  are hit. The exact terms are below, and they are the whole game.
- A **best combo** tracked for the run and shown on the death screen,
  because the best combo is the number players actually chase.

No score persistence between runs in v1. A high score saved locally is a
stretch item.

### The combo, in full

This is the most consequential rule in the document, so it is written out
rather than summarised — and it is the first thing to playtest, before any
enemy art exists.

Every kill refreshes a short **grace window**, on the order of one and a
half seconds. Then:

- **Damage taken inside the grace window** steps the multiplier down one
  tier instead of clearing it: a x8 becomes a x6, a x40 becomes a x32. The
  grace window is **not** refreshed by taking damage.
- **Damage taken with no grace window** clears the combo completely.

**Why the window exists.** Chip damage is not an edge case in this game.
Shooters are present from wave four, the arena is built to make standing
still expensive, and a wave is a budget of bodies that were not placed
there to be avoided. A rule that zeroes a x40 on one stray bullet does not
read as skill — it reads as the game confiscating something, and it pushes
players toward exactly the play the rule exists to discourage: hanging
back, waiting, letting the bullet pass.

**What the reset means, once the window exists.** A full reset becomes a
specific, legible event: **you were hit while not killing things.** That
is a real mistake, it belongs to the player, and the game is allowed to
punish it visibly. Aggression still risks the multiplier; stillness still
cannot build it. The balance survives.

The window length and the size of a step are both tunables, and neither
should be locked before it has been played. What must not change is the
shape: a stepped bleed under pressure, and a total reset only when the
rhythm actually breaks.

---

## 9. HUD

Seven elements. Anything beyond this is noise in a firefight.

| Element | Purpose |
|---|---|
| **Crosshair + hitmarker** | Confirmation. The single highest-value element in a shooter |
| **Health** | Am I about to lose my combo |
| **Ammo** | Current magazine and reserve, per weapon |
| **Wave counter** | Where am I on the curve |
| **Combo meter** | The stakes, always visible, always the thing to protect |
| **Score** | The number being chased |
| **Minimap** | Local awareness of threats and pickups |

**The touch controls are also on screen**, and they compete with everything
above. The stick and the buttons are semi-transparent, sit in the corners
under the thumbs, and nothing on the HUD may sit underneath them. Their size
and opacity are player settings. On a phone, every HUD element has to earn
its place against the player's thumbs as well as their attention.

### Hitmarkers

Markers are the game's entire combat feedback channel, because §9's
rejected list takes away the alternatives. They come in **three** tiers,
and the third is not optional:

| | Meaning |
|---|---|
| **Hit marker** | You hit a body |
| **Weak-point marker** | Higher again. You hit the heavy's weak point (§6) |
| **Kill marker** | Highest and loudest. You finished it |

If hitting and killing sound and look identical, shooting feels broken no
matter how good the gun is. This is the cheapest possible responsiveness
and it is mandatory. Two tiers for three events would leave the heavy's
accuracy lesson unreadable — which is the same mistake one tier down.

### On the minimap

A minimap earns its screen space only if the arena is large enough for you
to genuinely lose track of yourself. **If the plaza turns out small, the
minimap is decoration and should be cut** — on a tight arena it is either
noise or a wallhack. This is a decision to be made when the arena layout
exists, not now. It is called out here so it is a choice rather than an
accident.

The test is a concrete one, not a feeling: **if the player can see the
whole plaza from any point in it with a single turn, the minimap goes.**
On a phone the test is stricter. Screen space is scarcer, and a turn is
a swipe rather than a flick, so the minimap has to pass the test *and*
find a corner that no thumb covers.

**Decided: the minimap is cut.** The plaza is 44 m square with cover no
taller than a person, and the whole of it is visible from any point with
one turn. By the test above, the minimap goes.
§11 lists it conditionally for exactly this reason — "done" must not
include an element the plan already expects to remove.

### Rejected

Damage numbers, kill feed, objective markers, ammo counter on the gun
itself, speed indicators, damage-taken direction indicators. All of these
are cut for a reason: each one asks for screen attention that combat needs.

---

## 10. Audio

| Sound | Purpose |
|---|---|
| **Per-weapon gunshots** | Three distinct reports. Instantly tells you what you're holding |
| **Reloads** | Audible cost. Tells you the fight is not happening right now |
| **Hitmarker ping** | You connected |
| **Weak-point marker**, higher again | You found the heavy's weak point |
| **Kill marker**, highest and loudest | You finished them |
| **Enemy sounds, distinct per type** | Rusher, shooter, and heavy must be separable by ear alone |
| **Synth-wave track, intensifying through levels and rooms** | Escalation you feel before you read the counter |
| **Wave start sting** | A beat to reset and reposition |

### Governing principle

**A miss, a hit, a weak point, and a kill must all sound different.** If
those states are indistinguishable, the shooting feels unresponsive and the
game feels broken, regardless of how it looks. This is non-negotiable, and
it is three separate sounds rather than two — see §9.

No announcer voice. No dialogue. The music gains intensity through levels and rooms; bosses use their own track.

---

## 11. Current Scope and Delivery

### Existing baseline

The current repository contains 99 generated levels, room gates and cover,
boss rooms, robot models, three guns, movement and regen, combo scoring,
touch/gamepad controls, practice, settings, level select, local progress,
and Play Games integration. Publication is underway; see [release.md](release.md).
The earlier plaza/twenty-wave prototype is historical, not the current loop.

### Expansion delivery

The expansion is defined in §16. All three implementation groups are present;
Android device checks and release preparation remain:

1. XP, room-banked coins, save migration, Armory, complete tree UI and Runner
   effects; SMG, burst rifle, frag.
2. Gunner and Demolition effects; LMG, plasma launcher, EMP, shield robot.
3. Railgun, arc gun, incendiary, support robot; full build and economy tuning.

During staged delivery, unfinished nodes are visibly upcoming and cannot be
purchased. Activate cross-links only when their destination effects ship.
Existing publication work is independent of these milestones. Milestones
are scope groups, not promises of specific version names or dates.

### Deferred

Difficulty settings and gyro aim remain possible later work. Attachments,
multiplayer, authored campaigns, story, vehicles, melee, slow-motion,
additional platforms, and monetization remain outside this expansion.

---

## 12. What NOT to Build

Every item here sounds good. That is precisely why it is written down.

| Cut | Why |
|---|---|
| **Multiplayer** | Doubles the design work and adds a second game to keep balanced |
| **Hand-built levels** | 99 authored levels is a different project. Levels are generated from one room design (§3) |
| **More than 3 weapons or 3 enemy types in v1** | Breadth over depth. Depth is what makes it feel good |
| **Weapon upgrades / attachments** | Coins fund skills only; guns unlock through campaign clears |
| **Unbounded skill power** | §16 now permits a branching tree; active slots and one capstone preserve build choices |
| **Mandatory grinding** | §16 permits XP, coins and unlocks; baseline encounters must remain beatable with the starter arsenal and no skills |
| **Cutscenes / story** | Room-clearing combat remains the focus |
| **Gyro aim in v1** | A second aiming system to tune. Stretch, after drag-look is right |
| **Ads / in-app purchases** | They pull the game toward session-padding and grinding, which §2 and §11 reject |
| **Publication blocking expansion work** | Publication is underway; gameplay and offline progression remain independent of sign-in and store approval |
| **Aim assist that aims for you** | Snap, lock-on, or tracking. Slowdown only — see §4 |
| **iOS / browser / desktop builds** | One platform, done well. The same reasoning as one map |
| **Difficulty slider at launch** | See stretch item 1. One honest difficulty first |
| **Our own online backend** | Hosting and cheating. Anything online goes through Play Games, or not at all |
| **Vehicles** | A second game inside the first |
| **Slow-motion** | A camera change that costs feel to everyone else |
| **Melee** | Removes the reason to aim, which is the entire game |
| **Difficulty ramping mid-wave** | Waves should escalate between, not during, a fight |
| **Pacing corrections mid-wave** | Spawning faster because the fight is dragging. Wave length is emergent — see §2 |
| **Aiming at player intent** | See §4. Enemies aim where you are. This is load-bearing |
| **A free dash** | See §4. Invulnerability that can be chained, spammed, or held. The panic button stops being a decision and starts being a reset button |

---

## 13. Design Risks

Recorded so they are decisions rather than surprises.

1. **Five movement states is a lot for three enemy types to handle.** The
   §4 rule exists to contain this. If enemies feel unfair in testing, fix
   the rule before touching health or damage.
2. **Dash invulnerability is the most balance-sensitive thing here.** A
   panic button is what a player reaches for when they are already losing,
   so a generous window turns a bad moment into a free reset. It needs a
   cooldown, a short duration, and no chaining. If it cannot be held to
   that, cut dash — see §12.
3. **The combo terms are unproven.** §8's grace window and step size are
   the first thing to play, and ideally before any enemy art exists. The
   risk is not that the rule is too harsh — the window was added for
   exactly that — but that a stepped bleed is harder to read than a hard
   reset, and players misjudge their own state. If that shows up, the fix
   is a clearer meter, not a harsher rule.
4. **The minimap may not survive contact with a small arena.** §9. Cut it
   if the player can see the whole plaza from anywhere.
5. **Aggression-free AI makes early waves flat.** Rushers only for four
   waves is a gentle on-ramp, not a design flaw. Accept the slow start.
6. **Enemies have to be readable against a neon city.** This is the one
   aesthetic risk with a failure mode the player cannot play around: a dark
   silhouette on a dark skyline is not a hard wave, it is an unplayable
   one. Enemy colour and rim treatment are a readability requirement, not
   a polish pass, and they are decided alongside the lighting rather than
   after it.
7. **Phones get hot and slow down.** A mid-range phone that holds 60 fps
   for two minutes may drop to 40 after ten, which is a full run. §2's
   concurrent cap is the one lever keeping the heaviest wave affordable, and
   it will be the first thing to move if the budget turns out to have been
   optimistic. The cap is a design decision, so lowering it is allowed;
   ignoring it is not. Test on a real phone, through a whole run, not just
   in the editor.
8. **The Android lifecycle interrupts runs.** A phone call, a notification
   pulled down, the app switched away from, or the screen locked mid-wave.
   These are ordinary events. The answer is defined now: **any loss of
   focus pauses the run, and the run is never lost to it.** Coming back
   shows the pause screen, never a live wave.
9. **Touch aim may not be precise enough.** The marksman is the weapon most
   at risk: "stop moving, breathe, aim" asks for precision that a thumb may
   not have. Fix it with scope sensitivity and aim assist before changing
   the weapon's role. If neither works, the marksman's damage falloff gets
   more forgiving. Its role stays the same.
10. **Thumbs cover the screen.** Enemies that come in under the controls are
    hard to see. This is the touch version of risk 6, and it is answered
    the same way: decided with the layout, not patched in afterwards.
11. **Progression can turn into mandatory grinding.** Validate skill-free
    starter loadouts throughout the campaign, then measure the upgrade curve.
12. **Persistent rewards can duplicate.** Room banking, first clears, migration,
    and cloud conflicts need idempotent accounting, not maximum coin balances.
13. **Effects compete for a phone's frame budget.** Bound chain targets, active
    fields, coin stacks, particles, and simultaneous control effects.
14. **The tree can become unreadable.** Show prerequisite paths, tier locks,
    active slots and next-rank effects; test it on a real landscape phone.

---

## 14. Tuning and Validation Still Required

These are measured implementation tasks, not permission to change §16's rules:

- XP thresholds to player level 30, per-enemy XP/coin rewards, clear bonuses,
  and increasing node/rank prices. Target the first foundation purchase after
  the first cleared room.
- Exact skill percentages, durations, cooldowns, grenade radii/fuses, new gun
  damage/ammo curves, and shield/support composition weights.
- A named mid-range Android test device. Retain a 60 fps target and 30 fps
  floor through a sustained session, not just a short editor run.
- Readability and comfort of the tree and grenade controls on touch.
- Save-journal size under long play; compact only after merge safety is proven.

Record chosen values and measured results in the implementation handoff as
each milestone ships. Store approval, release track, and rollout details
belong in [release.md](release.md), not inferred from local configuration.

---

## 15. Terminology

- **The plaza** — the v1 arena, now the menu backdrop and practice range
- **A room** — a walled rectangle; enemies enter only through its far wall
- **A gate** — one of the alcoves in a room's far wall that enemies come
  through
- **A level** — one to four rooms in a chain, numbered 1 to 99
- **A wave** — one round of spawns inside a room. Ends when the last
  enemy in it is dead
- **An interval** — the ten seconds between waves, and the ten seconds the
  health system needs to do its work
- **The boss** — the last room of every tenth level and of level 99, to
  §7's floor
- **A run** — one attempt at a level, to death or the clear
- **The combo** — the kill multiplier, at risk when you are hit
- **The grace window** — the short period after a kill during which damage
  steps the combo down instead of clearing it (§8)
- **A wave's budget** — its total enemy count, and the smaller number that
  may be alive at once (§2)
- **A rusher / shooter / heavy** — the three enemy types
- **A marker** — hit, weak-point, or kill. The game's whole combat
  feedback channel
- **The floor** — the minimum buildable version of a thing, so that one
  undesigned element cannot block everything behind it (§7)
- **The finish line** — the current playable baseline in §11

---

## 16. Arsenal & Skills — Expansion

**Implemented in the working tree on 2026-10-23; not published.** This section supersedes the old bans on
skill trees and between-run unlocks. Player progression adds lasting choices
without changing the far-wall room structure or requiring purchases.
Implementation contracts, test results and remaining device checks are in
[the handoff](docs/expansion-implementation.md); folder READMEs explain current code.

### Three forms of progression

- **Campaign level:** one of the existing 99 encounters. First clears unlock guns.
- **Player level:** persistent XP progression, capped at 30 initially. Kills,
  room clears and level clears grant XP; first-time level clears grant a bonus.
  XP survives death, including XP earned in an uncleared room.
- **Coins:** enemies drop collectible coins; these purchase permanent skill
  ranks. Rewards scale by enemy class and campaign difficulty, never combo.

Collected coins are unbanked until the room clears. On clear, collect remaining
room coin drops and bank all that room's earnings exactly once, including the
final room. Death, restart or abandonment loses only the current room's unbanked
coins. A replay is a new attempt with fresh rewards. Practice grants none.
Pausing/backgrounding does not abandon the attempt; process termination loses
unbanked coins but preserves committed XP and banked rewards.

Use generous pickup attraction and merged coin stacks for readability and
performance. Show banked and unbanked amounts distinctly. First-time clears also
grant a coin bonus, committed with the final-room bank. Target enough earnings
to purchase the first foundation rank after the first cleared room. No premium
currency, upgrade failures, loot boxes, or repeat-clear penalties.

### Tree structure: 405 nodes, increasing choices

Campaign reveals nodes only when their level and purchased-parent requirements
are satisfied; affordability must never hide them. Practice exposes the full
catalog. This supersedes the earlier always-visible locked-node overview.

**Visual revision (implemented 2026-10-23):** [checklist](docs/visual-progression-plan.md)
requires a 99-cell DEAD level map, distinct icons/names for every effect type,
and a visible practice-build fallback when entering campaign. Preserve graph IDs.

The 39 major nodes retain their original stable purchase IDs. Three
specializations each contain one foundation, two paths of three core
nodes, two advanced alternatives per path, and one capstone per path: thirteen
nodes per specialization. Non-capstone nodes normally have three ranks;
capstones and the extra-grenade-capacity exception have one. Coins purchase
ranks permanently. Each of the six paths now adds six ten-node circuits
and one bridge: 39 + (6 × 61) = **405 distinct purchasable nodes**.
Circuits split into two lanes, rejoin through alternative prerequisites,
and fan outward as player-level gates rise through 5/10/15/20/25.
Bridges connect neighboring disciplines through alternative parent routes.
These are repeated small stat investments, not 405 distinct combat mechanics.
Each circuit node grants 0.25 rank-equivalent of its specified effect; bridges
grant 0.5 foundation rank-equivalent. Combined ordinary effects cap at three
ranks, capacity at one, and capstones at one. Small-node cost is tier × 5;
major-node rank cost remains tier × 20 × rank. Existing purchases stay valid.

| Specialization | Foundation | Path and core nodes, in prerequisite order | Advanced fork | Capstone |
|---|---|---|---|---|
| Runner | Faster weapon swaps | Momentum: moving accuracy → slide distance → moving reload | Sprint recovery OR slide damage resistance | Sliding primes the next shot to stagger an ordinary enemy |
| Runner | Same foundation | Evasion: dash cooldown → air control → post-dash handling | Post-dash reload OR brief post-dash damage resistance | Narrowly avoiding an attack grants a brief movement boost |
| Gunner | Recoil recovery | Precision: scoped handling → first-shot recovery → weak-point damage | Scope transition speed OR weak-point stagger | Weak-point kills transfer ammunition from reserve to magazine |
| Gunner | Same foundation | Suppression: bloom control → reserve capacity → sustained-fire handling | Reload speed OR sustained-hit stagger | Sustained hits on one target grant a brief handling bonus |
| Demolition | Throw recovery | Ordnance: blast radius → self-blast resistance → explosive stagger | One extra grenade capacity OR faster plasma reload | Grenade kills grant a brief, non-stacking gun-reload boost |
| Demolition | Same foundation | Disruption: EMP duration → incendiary duration → grenade placement handling | Shield disruption OR incendiary slowdown | Guns briefly deal more damage to enemies affected by your grenades |

- Foundations open at player level 1, all core nodes at 5, advanced nodes at
  15, capstones at 25. Buying a node requires a purchased parent rank and the
  player-level gate. Rank prices increase with tier and rank.
- Each core path is a chain; both advanced alternatives branch from its third
  core node; either advanced node leads to that path's capstone. Both sides
  may be purchased and equipped if slots allow.
- Cross-links add hybrid routes: Momentum's third core node also parents both
  Suppression advanced nodes; Precision's third core node also parents both
  Disruption advanced nodes. These are alternative prerequisites, not extra
  requirements, and do not bypass level gates.
- Start with four active-node slots; expand to eight at level 5, fourteen at
  level 15 and twenty-four at level 25. Each node costs one slot regardless of rank; foundations and
  capstones count. Only one capstone may be active.
- An active node needs a connected active prerequisite path to a foundation.
  Deactivating a prerequisite removes dependents unless another active route
  supports them. Purchased ranks remain owned.
- Freely change active nodes between attempts; purchases are permanent, with
  no reset fee or refund system. The earlier twelve-point/free-refund proposal
  is superseded by permanent purchases and free activation.
- Builds are immutable during an attempt. Skill effects never extend dash
  invulnerability, create ammunition, or modify score multipliers.
- The extra-grenade-capacity node is a **single-rank exception**, granting +1
  capacity. Other major non-capstone nodes have three ranks; capstones and
  the 366 added circuit/bridge nodes have one.

Use a single connected, icon-only canvas inspired by the supplied BYTEPATH
reference, with dim locked routes, brighter owned routes, white active markers
and ringed capstones. Drag to pan, wheel/pinch or buttons to zoom, FIT to see
all nodes, and branch shortcuts to focus foundations. Hover explains nodes;
click/tap keeps details, costs, ranks and requirements in the inspection panel.
Purchases require the explicit upgrade button. Keyboard arrows navigate,
Enter inspects, +/- zoom, and F fits. See [research](docs/skill-tree-research.md).
Armory is accessible from the menu and level select. Unavailable staged content
is marked upcoming and cannot be bought or activated.

### Loadouts and new guns

Carry three distinct selected guns, with per-gun magazines and reserves, plus
one selected grenade type. Keep rifle, shotgun and marksman unlocked from the
start. Choose in the Armory before a level; retries reset combat supplies.
Guns unlock on campaign clears and never cost coins.

| New gun | Clear level | Role and cost |
|---|---:|---|
| SMG | 3 | Mobile close-range spray; weak range, high ammo consumption |
| Burst rifle | 8 | Controlled medium-range bursts; firing gap after misses |
| LMG | 15 | Sustained fire; long reload, poor accuracy while moving |
| Plasma launcher | 25 | Slow explosive projectiles; scarce ammo, self-damage |
| Railgun | 35 | Charged penetrating precision; slow recovery, expensive misses |
| Arc gun | 45 | Short-range chains; weak against isolated targets |

Railgun shots penetrate enemies, not walls. Arc chains have a fixed target cap,
require visibility between hops, and cannot revisit a target. The marksman
remains the immediate-fire precision choice. Every gun needs distinct feel,
silhouette, audio and a meaningful reason to select it.

Gun ammo drops serve carried weapons. Grenade/effect kills must have explicit
attribution rather than pretending to be rifle kills. Neither grenade charges
nor free magazine ammunition are generated by kills.

### Grenades and controls

| Type | Clear level | Behavior |
|---|---:|---|
| Frag | 1 | Bouncing timed explosive with radial damage falloff |
| EMP | 10 | Brief robot disable and shield disruption; boss slowdown instead of stun |
| Incendiary | 20 | Short-lived burning area; overlapping fields do not multiply damage |

Start an attempt with two charges. Clearing each room restores one, up to two
normally or three with the capacity skill. The skill raises the cap, not the
starting count. Frag/plasma blasts and incendiary fields can hurt the player;
cover blocks blast damage. Pause freezes all projectiles, fuses and fields.

Touch: tap the grenade button for a quick throw; hold for trajectory preview,
release to throw, drag outside to cancel. Gamepad: left bumper. Keyboard: G.
No cooking. Cancelling spends no charge. Movement and aiming remain available
while previewing; suppress firing during the actual throw animation.

### New enemies

- **Shield robot**, from campaign level 15: frontal protection with an exposed
  rear/weak point; EMP temporarily disables the shield. Starter guns can win.
- **Support robot**, from level 25: visibly repairs one nearby ally; never
  itself, another support robot or a boss. Breaking visibility interrupts it.

Both enter through far-wall gates and replace entries within existing wave
budgets/caps. Neither requires a specific loadout. Boss control resistance and
bounded effect stacking prevent stun locks. Skills and unlocks make builds
different; baseline campaign success must not require grinding.

### Existing players, scores and acceptance

Preserve existing progress. Infer cleared levels from saved best-score keys and
the sequential levels below the highest unlocked level; level 99 requires its
own recorded clear. Grant a one-time catch-up award equivalent to the new
first-clear XP/coin bonuses, not fabricated historical kill rewards. Derive
weapon unlocks from these clears.

Keep legacy scores separate. Expansion scores use a separate leaderboard;
retain them locally if its ID is not configured. Cloud economy merges require
deduplicated earning/purchase records and validated spending, not max balances.

Each milestone must verify room/final-room banking, replay and death behavior,
duplicate events, migration, offline cloud conflicts, tree paths and slot
limits, every delivered effect, all damage-source kills, touch cancellation,
background pause, starter-loadout viability and sustained phone performance.
See the handoff for concrete cases and current integration hazards.
