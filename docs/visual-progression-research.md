# Visual progression: readable identity

Researched 23 October 2026. This follows the user's screenshots: keep the current
405-node graph layout, replace repeated branch marks with recognizable skill
identities, and arrange the 99 campaign buttons into the pixel letters DEAD.
The proposals below are original Cracked design decisions, not copied game art.

## Findings from primary sources

- Xbox's contrast guidance applies to symbols and glyphs as well as text. It
  recommends strong separation from the background and describes outlines and
  solid backgrounds as useful aids. A dim circuit edge can recede; a skill's
  actual silhouette must remain identifiable. [XAG 102: Contrast](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102).
- Shape and accompanying text help explain symbols; relying on color alone
  leaves important information ambiguous. An icon-led tree therefore still
  needs a descriptive inspection panel. [XAG 103: Additional channels](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/103).
- Tooltips should explain a component's purpose and operation. Unexpected
  context changes should be announced. This supports an explicit notice when
  the campaign disables a practice build. [XAG 114: UI context](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/114).
- Animated backgrounds can distract from stationary information; players
  should be able to stop distracting movement. Static, faint neon traces are
  the simplest fit for this level screen. [XAG 117: Visual distractions](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117).

## Design contract

1. The 39 implemented effect types each receive a distinct original icon and
   evocative display name. Icons communicate the action or object: a magazine,
   wing, broken shield, blast wave, or impact. A different number of dots on the
   same branch emblem does not qualify as a distinct effect icon.
2. Each of the 405 graph nodes resolves its `effect` (or its own stable ID) to
   that identity. Repeated small bonuses intentionally share the same effect
   icon. They are not advertised as 405 different mechanics. Keep IDs, edges,
   coordinates, effect weights, purchase history, and balance unchanged.
3. Give the effect name and a short action-oriented explanation first. Exact
   tuning, fractional contribution, rank, prerequisites and cost remain
   available below it. Never expose names like `evasion_circuit_1_3` as titles.
   Small nodes may use an "Echo" suffix; route metadata belongs in secondary
   text rather than the name. The name must not imply an unimplemented mechanic.
4. Hover and keyboard focus show the same explanation as touch inspection.
   Inspection does not purchase. Selected, owned and active states use border
   and marker changes as well as color. Preview icons at actual node size;
   thin intricate art that only reads when enlarged is insufficient.
5. DEAD consists of exactly 99 unique numbered level buttons. Its letter
   positions remain fixed as the player progresses; completed buttons light up
   so the completed campaign spells the word. Preserve lock rules, Continue,
   selection details and keyboard access. Neon decoration is static, subdued,
   noninteractive and behind the buttons.
6. A practice build is only usable in the Practice Range. Attempting to enable
   it for campaign play shows "Practice build is turned off" and continues
   with the player's normal saved build. Never replace the normal saved build
   with the sandbox selection or unlock sandbox items for campaign play.

## Proposed identity palette

These are design proposals for the implementation, not claims from the sources.
The original IDs remain the save-format contract.

| Effect ID | Display name | Distinct icon metaphor | Meaning to explain first |
| --- | --- | --- | --- |
| swap_speed | Quickdraw | Pistol lifted from an open holster | Bring your next weapon up faster. |
| recoil_recovery | Counterweight | Gun with hanging stabilizer weight | Settle your aim after each shot. |
| throw_recovery | Sleight of Hand | Open palm releasing a grenade | Recover faster after a throw. |
| moving_accuracy | Gyrostride | Boot inside a crosshair | Keep your shots tighter while moving. |
| slide_distance | Low Rider | Boot skimming a long ground trail | Carry your slide farther. |
| moving_reload | Roadside Reload | Magazine between running legs | Reload faster on the move. |
| sprint_recovery | Chase Breaker | Running figure raising a barrel | Ready your weapon sooner after sprinting. |
| slide_guard | Asphalt Armor | Low wedge shield over a skid | Take less damage while sliding. |
| slide_stagger | Knee Breaker | Sliding boot striking a cracked target | Prime a staggering shot by sliding. |
| dash_cooldown | Second Wind | Circular gust around a forward arrow | Dash again sooner. |
| air_control | Skyhook | Wing hooked around a turning arrow | Steer harder while airborne. |
| dash_handling | Slipstream Sight | Wind ribbon through a sight ring | Steady your weapon just after a dash. |
| dash_reload | Ghost Loader | Fading hand feeding a magazine | Reload faster just after a dash. |
| dash_guard | Afterimage Aegis | Offset silhouettes behind a shield | Take less damage just after a dash. |
| near_miss | Thread the Needle | Projectile threading a needle eye | Dash past a bolt to gain a burst of speed. |
| scoped_handling | Dead Calm | Eye above a still horizontal line | Keep scoped shots steady. |
| first_shot | Clean Slate | Spreading rays converging into one dot | Let shot spread settle faster. |
| weak_damage | Achilles | Cracked armor with a bright exposed center | Hit exposed weak points harder. |
| scope_speed | Snap Focus | Iris blades around a square pupil | Enter and leave your scope faster. |
| weak_stagger | Nerve Strike | Impact star on a jointed limb | Interrupt enemies with weak-point hits. |
| precision_feed | Death Dividend | Skull returning a round into a magazine | Weak-point kills feed reserve rounds into your magazine. |
| bloom_control | Chokehold | Two clamps narrowing a cone | Keep sustained shots from spreading as quickly. |
| reserves | Deep Pockets | Open ammunition pouch with three rounds | Carry more spare ammunition. |
| sustained_handling | Walking Thunder | Walking legs beneath a firing barrel | Keep moving fire tighter. |
| reload_speed | Fresh Teeth | Magazine with teeth-like rounds and a return arrow | Reload your weapon faster. |
| sustained_stagger | Hammer Rhythm | Hammer above four impact ticks | Stagger an enemy on every fourth hit. |
| focus_fire | Tunnel Vision | Four inward arrows around a target | Repeated hits on one enemy sharpen your aim. |
| blast_radius | Event Horizon | Explosion surrounded by expanding rings | Reach farther with explosions and EMPs. |
| blast_guard | Blast Cocoon | Shield wrapping an inward explosion | Resist your own explosive damage. |
| blast_stagger | Shock Front | Jagged shockwave tipping a figure | Make explosions stagger enemies. |
| grenade_capacity | Spare Pin | Pair of grenades with a spare pin | Carry one extra grenade. |
| plasma_reload | Hot Swap | Energy cell inside an exchange loop | Reload plasma faster. |
| blast_reload | Kill Switch | Grenade blast pulling a magazine latch | Grenade kills briefly accelerate reloading. |
| emp_duration | Blackout | Severed plug beneath a lightning pulse | Keep enemies disrupted by EMPs longer. |
| burn_duration | Eternal Ember | Flame inside an hourglass | Keep incendiary ground burning longer. |
| throw_accuracy | Deadeye Delivery | Grenade following an arc into a bullseye | Land moving throws more precisely. |
| shield_break | Glassbreaker | Shield split into separated shards | Keep EMP-hit shields disabled longer. |
| burn_slow | Cinder Snare | Ankle caught by a flame-shaped loop | Slow enemies standing in your fire. |
| disrupt_damage | Salt the Wound | Broken circuit exposing an impact point | Shoot grenade-affected enemies for extra damage. |

## Verification targets

- Exactly 99 unique level IDs map to distinct occupied cells, with four
  separated readable glyph regions; unlock and completion states are unchanged.
- All 39 effect IDs resolve to nonempty unique names and distinct icon geometry;
  every graph node resolves a known effect. Check actual rendered silhouettes,
  not only different filenames or identifiers.
- Inspect hover, keyboard focus and tap descriptions; ensure internal IDs do
  not leak into titles and all tuning remains inspectable.
- Test campaign entry with a practice selection pending, rejection of an
  activation attempt, unchanged normal loadout, and practice-only access to
  sandbox weapons/skills. Test the notice and continuation behavior together.
- Capture a fresh campaign and a fully completed campaign at desktop and narrow
  sizes, plus an icon contact sheet. Check decoration never steals pointer
  events and does not obscure numbers, tooltips or outlines.
