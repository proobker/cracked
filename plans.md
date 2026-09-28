# cracked — Design Plan

> **A 3d FPS.** A neon-lit death run, twenty waves deep.
>
> **Status:** pre-initial. Design locked, nothing built.

---

## 0. Purpose of This Document

This is the design intent for `cracked`. It records **what the game is and
what it refuses to be**, so that a future decision can be checked against a
decision that was already made on purpose.

It contains no tech stack, no engine, no architecture, and no code. Those
are implementation, and implementation is allowed to change. The decisions
in here are the game's identity, and changing one is a real decision that
has to be made deliberately.

Read this before adding a feature. A lot of good ideas are not in here, and
that is the point — see §12.

---

## 1. Premise

| | |
|---|---|
| **Genre** | First-person shooter, wave survival |
| **Setting** | Stylized low-poly neon cyberpunk city |
| **Perspective** | First person, mouse and keyboard |
| **Platform** | Browser — playable from a link, no install |
| **Movement fantasy** | Arena twitch — fast, strafing, mouselook mastery, forgiving |
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
open a browser tab and can shoot something.

**Why browser.** No install, no store approval, no code signing, no build
pipeline. A link goes in a group chat and the game is playable twenty
seconds later. It also means "done" is a real, reachable line.

---

## 2. Core Loop

```
        ┌──────────────────────────────────────────┐
        │                                          │
        ▼                                          │
   ┌─────────┐   survive    ┌──────────┐   die     │
   │  WAVE   │─────────────▶│ INTERVAL │──────────▶ GAME OVER
   │  N  /20 │              │   10s    │           (instant retry)
   └─────────┘              └──────────┘                │
        ▲                          │                    │
        │      survive              │    loot ammo       │
        │      the wave             └────────────────────┘
        │
    cleared
        │
        ▼
   wave 20 cleared ──▶ BOSS ──▶ WIN
```

The loop, in one line: **survive a wave, spend a breather, face something
worse.**

**The tension that drives it.** Combo multiplier rises with each kill and
**resets the moment you take a hit**. This is the whole game in one rule.
It means turtling in a corner is safe and scores poorly, and pushing forward
into a group scores well and is dangerous. Every player finds their own
balance and most of them drift forward over time as they get better.

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
- **Some verticality.** Raised platforms and a level change, because a purely
  flat arena makes dash and slide feel like they don't do anything.
- **Landmarks.** Three or four shapes you can navigate by without a
  minimap. You should be able to call "he's behind the sign" and have that
  be meaningful.

---

## 4. Movement

**All five are in v1. None of these are stretch.**

| Move | What it does | Why it earns its place |
|---|---|---|
| **Sprint** | Sustained speed, drains a meter that refills | The default answer to "I'm not close enough" |
| **Jump** | Standard jump | Invisible when present, infuriating when missing |
| **Crouch** | Lower profile, slower, tighter accuracy | The way you use cover without losing your gun up |
| **Slide** | Crouch at speed, low and fast, momentum carry | The arena-twitch signature move; long strafe lines |
| **Dash** | Short burst in the input direction | A panic button and a repositioning tool |

Movement is not decoration. In a wave shooter, dodging is a first-class
option alongside aiming, and if dodging is viable the game rewards nerve
rather than turtling.

### The rule that must exist: how enemies handle a moving player

Four movement states means enemies must react to all four, and a rusher
charging a player who is mid-slide or mid-dash is the classic way this looks
broken.

**The rule: enemies aim at where you are, not where you will be.** No
leading of the target on dashes or slides. Consequences, all deliberate:

- Dash and slide are for **repositioning out of danger**, not for dodging
  bullets on the way past. A dash will not save you from a shooter who is
  already pointed at you.
- Rushers **commit to a path and adjust slowly.** They should visibly
  overshoot a good slide, and recover from it like a person would. A rusher
  that perfectly tracks a slide is both more expensive and less fun to fight.
- Nothing in the game should ever cancel a dash, a slide, or a jump
  mid-flight. Input commitment is the contract.

If enemies start to feel unfair, this rule is the first thing to change —
not the health numbers.

### Camera

Mouse-look with no acceleration or smoothing. Turning is instant and
1:1. Any lag on the camera reads as input lag, which is unforgivable in a
game whose whole fantasy is mouselook mastery.

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

### Feel notes

- Every gun needs a distinct silhouette in first person, readable at a
  glance with no text. The shape tells you the range.
- Shotgun needs a real pump and a real stagger. It is the panic button and
  must feel like one.
- Marksman needs a scope or a tight zoom, and a shot that is *slow to
  recover from* so that a panic miss is felt.

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

The player should never stand in a reload animation while things spawn on
top of them. That is the whole purpose of the interval.

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

---

## 8. Health, Death, and Score

### Health

- Regenerates after roughly **five seconds without taking damage**.
- Health is never permanent loss, never a resource to be hoarded, and never
  something you can be fully denied. In an arena shooter with a combo rule,
  permanent health damage compounds into a death spiral.
- Damage comes from enemies, not from the environment. Falling is not a
  threat; there are no pits.

### Death

Death ends the run immediately. No lives, no continues, no currency, no
second chances, no loading between attempts.

The death screen is: the wave you reached, your score, your best combo, and
**one key to restart**. That is the entire meta-game of v1.

### Score

- Score for each kill, weighted by enemy type and weapon.
- A **combo multiplier** that climbs with consecutive kills and **resets
  completely the moment you take damage**.
- A **best combo** tracked for the run and shown on the death screen,
  because the best combo is the number players actually chase.

No score persistence between runs in v1. A high score saved locally is a
stretch item.

---

## 9. HUD

Six elements. Anything beyond this is noise in a firefight.

| Element | Purpose |
|---|---|
| **Crosshair + hitmarker** | Confirmation. The single highest-value element in a shooter |
| **Health** | Am I about to lose my combo |
| **Ammo** | Current magazine and reserve, per weapon |
| **Wave counter** | Where am I on the curve |
| **Combo meter** | The stakes, always visible, always the thing to protect |
| **Score** | The number being chased |
| **Minimap** | Local awareness of threats and pickups |

### Hitmarkers

A hitmarker fires on hit. A **kill marker is a distinctly higher-pitched,
louder hitmarker.** If hitting an enemy and killing one sound and look
identical, shooting feels broken no matter how good the gun is — this is the
cheapest possible responsiveness and it is mandatory.

### On the minimap

A minimap earns its screen space only if the arena is large enough for you
to genuinely lose track of yourself. **If the plaza turns out small, the
minimap is decoration and should be cut** — on a tight arena it is either
noise or a wallhack. This is a decision to be made when the arena layout
exists, not now. It is called out here so it is a choice rather than an
accident.

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
| **Kill marker**, higher and louder | You finished them |
| **Enemy sounds, distinct per type** | Rusher, shooter, and heavy must be separable by ear alone |
| **Synth-wave track, intensifying with wave number** | Escalation you feel before you read the counter |
| **Wave start sting** | A beat to reset and reposition |

### Governing principle

**A hit and a kill must sound different, and a miss and a hit must sound
different.** If the three states are indistinguishable, the shooting feels
unresponsive and the game feels broken, regardless of how it looks. This
is non-negotiable.

No announcer voice. No dialogue. The music gains intensity with the wave
number and nothing else changes mid-fight.

---

## 11. Scope Tiers

### v1 — the finish line

This is the definition of done. If nothing else ever gets built, this is a
complete game.

- One map: walled rooftop plaza, cyberpunk skyline backdrop
- Movement: sprint, jump, crouch, slide, dash
- Three weapons: rifle, shotgun, marksman, with real magazines
- Three enemy types: rusher, shooter, heavy
- Twenty waves in four phases, then a boss
- Ten-second intermissions with ammo drops
- Health with ~5s regen, instant death, instant restart
- Score with a combo multiplier that resets on damage
- HUD: crosshair with hitmarker and kill marker, health, ammo, wave
  counter, combo, score, minimap
- Audio per §10, including the hit/kill/miss distinction
- Menu, win screen, lose screen, restart

Nothing else. Not one more feature.

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

### Future

Explicitly out of reach for now, listed so it is not re-proposed as if it
were new: multiplayer, weapon upgrades and attachments, skill trees,
cutscenes and story, mobile and touch controls, online leaderboards,
vehicles, slow-motion, melee, multiple maps as a campaign, a
progression-based economy.

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
| **Mobile / touch controls** | A different control design, not a port |
| **Difficulty slider at launch** | See stretch item 1. One honest difficulty first |
| **Online leaderboards** | Backend, hosting, and cheating. Local scores answer the same need |
| **Vehicles** | A second game inside the first |
| **Slow-motion** | A camera change that costs feel to everyone else |
| **Melee** | Removes the reason to aim, which is the entire game |
| **Difficulty ramping mid-wave** | Waves should escalate between, not during, a fight |
| **Aiming at player intent** | See §4. Enemies aim where you are. This is load-bearing |

---

## 13. Design Risks

Recorded so they are decisions rather than surprises.

1. **Five movement states is a lot for three enemy types to handle.** The
   §4 rule exists to contain this. If enemies feel unfair in testing, fix
   the rule before touching health or damage.
2. **The minimap may not survive contact with a small arena.** §9. Cut it
   if the plaza is tight.
3. **Aggravating-free AI makes early waves flat.** Rushers only for four
   waves is a gentle on-ramp, not a design flaw. Accept the slow start.
4. **The combo rule punishes cautious play.** Some players will not
   understand it or will not want it. It is still correct — it is what makes
   the game a game — but it will lose some players early.
5. **Twenty waves is a guess.** It may be too short or too long. The
   escalation curve is a starting shape, and wave length should be tuned by
   playing, not by keeping a number.
6. **The boss is undesigned.** See §7. It is the most likely thing to be
   wrong and the most visible thing if it is.

---

## 14. Open Questions

Undecided, in no particular order:

- Exact wave counts per phase, and the length of an individual wave
- Arena dimensions and layout — the minimap decision depends on this
- The boss, concretely
- Whether a firing range or practice mode exists for learning the guns
- Whether the music changes at the boss, or only in intensity
- Menu, settings, and what is adjustable (sensitivity, volume, FOV, invert)
- Difficulty, until the game is beatable and can be honestly judged

---

## 15. Terminology

- **The plaza** — the arena, the single map
- **A wave** — one round of spawns, waves 1 through 20
- **An interval** — the ten seconds between waves
- **The boss** — wave 20
- **A run** — one attempt, from wave 1 to death or victory
- **The combo** — the kill multiplier, reset by taking damage
- **A rusher / shooter / heavy** — the three enemy types
- **The finish line** — v1 in §11
