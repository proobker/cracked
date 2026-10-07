# cracked — Design Plan

> **A 3d FPS.** A neon-lit death run, twenty waves deep.
>
> **Status:** pre-initial. Design locked, first slice being scaffolded.
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
| **Genre** | First-person shooter, wave survival |
| **Setting** | Stylized low-poly neon cyberpunk city |
| **Perspective** | First person, touch controls, optional gamepad |
| **Platform** | Android, native, built in Godot 4. Landscape only |
| **Movement fantasy** | Arena twitch — fast, strafing, thumb-aim mastery, forgiving |
| **Team** | Solo |
| **Deadline** | None. Scoped for "shippable", not "impressive by Friday" |
| **Budget** | ~6–10 hours/week, realistically |

### The pitch

You are dropped onto a rooftop plaza in a city that wants you dead. Waves of
things come at you. You have five ways to move and three guns, and the only
thing that matters is how long you last and how big a number you can put on
the screen while you do it.

### What kind of game this is, precisely

Three commitments define the whole project:

1. **One map, done well.** Not a small city, not a level selector. One arena
   that you learn so well you stop looking at it.
2. **Twenty waves, then a boss.** A win condition. Endless is a screensaver.
3. **Forgiving by design.** Health regen, generous ammo drops, wide net. The
   difficulty comes from how many decisions you have to make per second, not
   from instant death.

### Why these commitments

**Why wave survival, not a tactical campaign or a deathmatch.** A campaign
needs a level-design pipeline, scripted pacing, and authored cover. A
deathmatch needs multiple maps and AI that can path through them. Wave
survival needs exactly one map done well and enemies that walk at you. It is
the shape of shooter that can actually be finished.

**Why arena twitch, not grounded tactical.** Grounded tactical in 3D is an
aiming-sim problem — hit registration, hitboxes, and camera feel all have to
be near-perfect or the game feels broken rather than hard. Arena twitch is
far more forgiving, and it suits what the game is strong at: the instant you
open the app and can shoot something. It matters even more on touch, where
aiming is coarser than a mouse and a game built on precision would be
broken rather than hard.

**Why Android.** The game lives where it is actually played: on the phone,
in a break, in landscape, one run at a time. The 8–15 minute session (§2)
was always phone-shaped. Godot 4 because it is free, exports to Android
directly, produces small builds, and its Mobile renderer handles low-poly
neon without asking much of a mid-range phone.

**What that costs, written down so it is not forgotten.** The browser's
"link in a group chat" is gone. Instead there is a signing keystore, an
export pipeline, an APK to sideload, and a lifecycle (calls, notifications,
backgrounding) the game must survive (§13). Mouselook is gone too, and §4
says what replaces it. v1 is still a reachable line: a signed APK that
installs and runs is the finish line, and the Play Store is not (§12).

---

## 2. Core Loop

```
        ┌──────────────────────────────────────────┐
        │                                          │
        ▼                                          │
   ┌─────────┐   cleared    ┌──────────┐   die     │
   │  WAVE   │─────────────▶│ INTERVAL │──────────▶ GAME OVER
   │  N  /20 │              │   10s    │           (instant retry)
   └─────────┘              └──────────┘                │
         ▲                          │                    │
         │      cleared             │    loot ammo       │
         │      the wave            └────────────────────┘
        │
        ▼
   wave 20 cleared ──▶ BOSS ──▶ WIN
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

A full run is **8–15 minutes**: twenty short waves, short breaks, a boss.
Short enough to replay during a break. Long enough that dying at wave 18
stings.

---

## 3. The Map

**A single walled rooftop plaza, city skyline behind it.**

The arena is enclosed by real walls you can see and use for cover. Past the
walls is a flat backdrop of the cyberpunk city — towers, neon, distant
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

- **Open enough to strafe in a circle.** Never a corridor.
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

Three guns, three ranges, three reasons to swap mid-fight. If there is never
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

- **Weapons are droppable and instant.** A player carrying a dry shotgun
  can put it on the ground and pick up what they can actually use in a
  frame. This is what makes §5's "worse than no shotgun" line true rather
  than merely clever, and it is the cheapest possible answer to a bad
  state.
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

---

## 6. Enemies

Three types, one per role. Each teaches a different lesson by existing.

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

Enemies do not strafe, flank through geometry, or take cover. They walk
toward you, shoot from where they stand, and get shot.

This is a real cost to ambition, taken on purpose. Cover-seeking AI needs
pathfinding and line-of-sight logic, which is the most expensive system in a
3D shooter and the most likely thing to make a small game feel unfinished.
A rusher charging straight at you is cheap, reads perfectly at a glance, and
is satisfying to kill. Aggression is a stretch item, not a v1 requirement.

---

## 7. Waves

**Twenty waves, then a boss.** Escalation in phases rather than a flat
difficulty slider:

| Phase | Waves | What changes |
|---|---|---|
| **Open** | 1–4 | Rushers only. Learn movement, learn the rifle, learn the arena |
| **Pressure** | 5–9 | Shooters join. Two types at once, mixed composition |
| **Punishment** | 10–15 | Heavies join. Mixes get worse, not just bigger. Fewer bodies, more variety |
| **Breakdown** | 16–19 | Dense mixes, multiple heavies, the arena at its worst |
| **Boss** | 20 | Something that is not a bigger rusher |

**Escalation must come from composition before it comes from count.** Ten
rushers is less interesting and more of the same than six rushers, two
shooters, and a heavy. Wave 14 should not be wave 9 with bigger numbers.

### Intervals

Ten seconds between waves. Not a menu — the arena stays live and the
backdrop stays lit. This is your window to:

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

**Design intent, not a finished design.** It should be recognisably from
this game, not a boss archetype pasted in.

- It is a **single entity**, not a swarm, so the wave is a fight rather
  than a survival test you have already done 19 times.
- It should **change the fight, not just the numbers** — a ranged boss
  means standing still finally costs you, a boss that summons turns wave 20
  into a hybrid of 20 and the last five waves.
- It should be **winnable in about a minute**, on the same weapons, with
  the same three to five mistakes allowed as the rest of the game.

**The floor, so that wave 20 can never be what blocks v1.** The boss is
the least designed thing in this document and the most likely to overrun a
six-to-ten-hour-a-week budget. So it has a stated minimum, and the minimum
is v1:

> A single large enemy. It advances slowly, soaks damage like a heavy, and
> adds exactly one new thing — a ranged attack. It needs no new AI, no new
> navigation, and no system that does not already exist on the plaza.

That floor satisfies every bullet above. The fight-changing behaviour and
the summon variant are stretch stacked on top of a floor that already
works, and the floor gets built first. A plain boss that works is a far
better outcome than an ambitious one that delays the whole project, and
both are better than a v1 that ships nineteen waves.

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
| **Synth-wave track, intensifying with wave number** | Escalation you feel before you read the counter |
| **Wave start sting** | A beat to reset and reposition |

### Governing principle

**A miss, a hit, a weak point, and a kill must all sound different.** If
those states are indistinguishable, the shooting feels unresponsive and the
game feels broken, regardless of how it looks. This is non-negotiable, and
it is three separate sounds rather than two — see §9.

No announcer voice. No dialogue. The music gains intensity with the wave
number and nothing else changes mid-fight.

---

## 11. Scope Tiers

### v1 — the finish line

This is the definition of done. If nothing else ever gets built, this is a
complete game.

- A signed Android APK that installs on a mid-range phone and holds §14's
  frame floor
- Touch controls per §4, with gamepad as an alternative, and light aim
  assist
- Settings: look sensitivity, FOV, aim assist strength, control size and
  opacity, volume
- Pause on backgrounding, and resume to a paused run (§13)
- One map: walled rooftop plaza, cyberpunk skyline backdrop
- Movement: sprint, jump, crouch, slide, dash — with dash invulnerability
- Three weapons: rifle, shotgun, marksman, with real magazines, droppable
- Three enemy types: rusher, shooter, heavy
- Heavy weak point, with its own hitmarker
- Twenty waves in four phases, then a boss built to §7's floor
- Spawning per §2: enemy budget, concurrent cap, distance-gated points,
  telegraphed
- Ten-second intermissions with ammo drops
- Health with ~5s regen, instant death, instant restart
- Score with the stepped combo bleed and full reset from §8
- HUD: crosshair with hit, weak-point, and kill markers; health, ammo,
  wave counter, combo, score; minimap only if §9's test fails
- Death screen naming the cause of death
- A practice range, so three weapons can be learned without a 10-minute
  run in the way
- Audio per §10, including the hit/weak-point/kill/miss distinction
- Menu, win screen, lose screen, restart

Nothing else. Not one more feature.

**Two items on this list are new since the design was first drafted**, and
they are here because the friction they remove is not a nice-to-have:

- **The practice range.** A run is 8–15 minutes, every attempt restarts at
  wave 1, and there are three weapons with genuinely different handling
  and different failure costs. Without somewhere to learn them, the only
  way to learn a gun is to spend ten minutes getting to a wave that needs
  it. That is a real tax on the one promise §1 makes — open the app,
  start shooting. A range, or a "start at wave N", is a few lines next to
  systems that already exist.
- **Cause of death on the death screen.** See §8. The whole meta-game of
  v1 is retrying, and a retry is only informed if the player is told what
  they did wrong.

### Stretch — after v1 exists and is fun

In rough priority order:

1. **A difficulty setting.** The one stretch item that is arguably v1, held
   back only because a lone developer testing their own game cannot judge
   whether it is fair, and shipping one honest difficulty beats shipping a
   slider that hides the question.
2. **Weapon unlocks between runs.** A reward for reaching further.
3. **A second map.** The single biggest content upgrade available, because
   the systems already exist to fill it.
4. **A fourth enemy type.**
5. **Persisted high scores.** Local, not online.
6. **Enemies that strafe or take cover.** The aggressive-AI problem.
7. **Gyro aim.** Fine aim by tilting the phone, on top of drag-look.
8. **A Play Store release.** Listing, content rating, store policies.

### Future

Explicitly out of reach for now, listed so it is not re-proposed as if it
were new: multiplayer, weapon upgrades and attachments, skill trees,
cutscenes and story, online leaderboards, vehicles, slow-motion, melee,
multiple maps as a campaign, a progression-based economy, iOS, and a
desktop or browser build.

---

## 12. What NOT to Build

Every item here sounds good. That is precisely why it is written down.

| Cut | Why |
|---|---|
| **Multiplayer** | Doubles the design work and adds a second game to keep balanced |
| **More than one map in v1** | One arena is the commitment. A second is stretch, a fifth is a different project |
| **More than 3 weapons or 3 enemy types in v1** | Breadth over depth. Depth is what makes it feel good |
| **Weapon upgrades / attachments** | A second economy to balance, for no gain in the core loop |
| **Skill trees** | Progression belongs in the run, not in a menu |
| **Unlocks between runs** | Same. Also risks a player grinding instead of playing |
| **Cutscenes / story** | An arena shooter with twenty waves does not need a plot |
| **Gyro aim in v1** | A second aiming system to tune. Stretch, after drag-look is right |
| **Ads / in-app purchases** | They pull the game toward session-padding and grinding, which §2 and §11 reject |
| **Play Store release in v1** | Store policy, listing, and review are a project of their own. A sideloaded APK is the finish line |
| **Aim assist that aims for you** | Snap, lock-on, or tracking. Slowdown only — see §4 |
| **iOS / browser / desktop builds** | One platform, done well. The same reasoning as one map |
| **Difficulty slider at launch** | See stretch item 1. One honest difficulty first |
| **Online leaderboards** | Backend, hosting, and cheating. Local scores answer the same need |
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
11. **Twenty waves is a guess.** It may be too short or too long. The
    escalation curve is a starting shape, and wave length should be tuned
    by playing, not by keeping a number.
12. **The boss is undesigned.** §7 gives it a floor, and the floor is
    buildable. What is not buildable on a six-to-ten-hour-a-week budget is
    the ambition above it — and treating the ambition as the requirement is
    how wave 20 ends up delaying the entire project.

---

## 14. Open Questions

Undecided, in no particular order:

- Exact wave counts per phase, and the length of an individual wave
- Arena dimensions and layout — the minimap decision depends on this, and
  so does the slide geometry, so §3 cannot be finalised without §4
- The boss above its §7 floor, if there is ever time for it
- The grace window's length and the size of a combo step (§8)
- Dash invulnerability's duration, and the cooldown that gates it (§4)
- The concurrent enemy cap, which the frame budget will end up deciding
- Whether the music changes at the boss, or only in intensity
- Menu, and anything adjustable beyond §11's settings list (invert,
  left-handed layout, button repositioning)
- Aim assist strength by default, and whether it differs per weapon (§4)
- Whether to offer an "auto-fire when on target" touch mode (§4)
- Which real phone is the mid-range test device. The targets themselves are
  decided: **60 fps target, 30 fps floor** through a whole run, Godot's
  Mobile renderer, landscape only, minimum Android version per Godot's
  export defaults
- Difficulty, until the game is beatable and can be honestly judged

---

## 15. Terminology

- **The plaza** — the arena, the single map
- **A wave** — one round of spawns, waves 1 through 20. Ends when the last
  enemy in it is dead
- **An interval** — the ten seconds between waves, and the ten seconds the
  health system needs to do its work
- **The boss** — wave 20, to §7's floor
- **A run** — one attempt, from wave 1 to death or victory
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
- **The finish line** — v1 in §11
