# Skill tree research: BYTEPATH

Researched 23 October 2026 for the Cracked Arsenal & Skills expansion.
This note separates reference facts from proposed Cracked behavior; it does not
declare a release or replace the implementation contract in [plans.md](../plans.md).

## Reference and findings

The user's [GamingOnLinux article](https://www.gamingonlinux.com/2018/02/bytepath-is-an-arcade-shooter-with-a-huge-skill-tree-retro-visuals-and-its-insane/)
and supplied screenshot establish the visual direction: a large, dark circuit
map, many compact connected nodes, occasional larger hubs, and a clearly lit
selected route. The screenshot is a visual reference, not a specification of
Cracked's economy or progression.

The official BYTEPATH store describes build experimentation as a central feature
and advertises **900+ passive nodes**, alongside classes and ships. Its depth is
therefore broader than a single collection of numerical upgrades.
[Source: developer's Steam listing](https://store.steampowered.com/app/760330/BYTEPATH/).

The developer's tree tutorial stores node names, effects, positions, links and
sizes as data. Purchase access follows connections to already purchased nodes.
Repeated numerical passives accumulate into player statistics, while boolean
and specialized effects need their own handling. The tutorial also demonstrates
an apply/cancel step and persistent purchases. These are useful architectural
patterns; Cracked need not copy the tutorial's particular point costs or limits.
[Source: BYTEPATH #13 — Skill Tree](https://github.com/a327ex/blog/issues/27).

The released node implementation distinguishes three sizes, checks differently
sized pointer regions, and draws purchased nodes brighter than unpurchased
nodes. It skips offscreen node updates and drawing. Its removal logic checks
that neighboring purchases remain reachable. Compact presentation thus still
depends on explicit graph rules and interaction states.
[Source: Node.lua](https://github.com/a327ex/BYTEPATH/blob/master/objects/Node.lua).

The released tree screen supports mouse-wheel zoom, keyboard movement between
linked nodes, controller controls, and camera movement toward the focused node.
A large graph needs navigation as well as more content.
[Source: SkillTree.lua](https://github.com/a327ex/BYTEPATH/blob/master/rooms/SkillTree.lua).

## Recommended adaptation for Cracked

These are design recommendations derived from the references and the user's
request, not claims about BYTEPATH's mechanics.

- Provide **at least 400 distinct purchasable nodes**, excluding rank increments,
  decorative junctions, and a free central origin from the count. Preserve
  existing purchase IDs when extending the catalog.
- Use one connected overview with recognizable branch regions, forks, loops,
  and cross-branch routes. Reveal higher-level opportunities without hiding the
  scale of the full map. Larger milestone nodes should anchor the smaller
  upgrade routes.
- Draw icons inside nodes instead of permanent name labels. Use a consistent
  visual vocabulary for movement, weapons, explosives, protection, and status
  effects. Shape, border treatment and size should supplement color.
- Explain the focused node on hover, keyboard focus, or Android tap: name,
  exact effect, current rank, next purchase cost, level requirement, prerequisite
  route and purchase/activation state. Keep purchases behind an explicit panel
  action so inspecting or panning cannot spend coins.
- Support drag-to-pan, zoom controls, a fit/reset action, and keyboard focus.
  Touch targets must remain usable when zoomed out; tiny overview nodes should
  be inspectable through zooming rather than forcing precise accidental taps.
- Keep enemy coin drops as the spending currency and XP as the level gate.
  Display both clearly. Coin banking, failed-save rollback and cloud merge
  rules continue to belong to Cracked's progression system.
- Distinguish purchased travel/minor bonuses from limited active major skills
  if necessary to make hundreds of nodes worth exploring. Bound aggregated
  effects so repeated damage reduction, cooldown or spread bonuses cannot
  produce immunity, negative delays or invalid weapon behavior.
- Reuse coherent effect families with different route combinations and
  milestones; do not present hundreds of decorative or mechanically inert
  nodes as implemented content.

## Verification checklist

Automated checks should count purchasable IDs, detect duplicate IDs and broken
links, prove every node reachable from an entry, check level/prerequisite gates,
and exercise effect caps and save replay. Interaction checks should cover hover,
touch inspection versus drag, zoom, focus, and purchase confirmation. Capture
both the full overview and a close view with a detail panel. Android performance
and balance still require real-device playtesting; a desktop screenshot cannot
establish either.

The implementation should use original geometry and icons. The BYTEPATH
repository separately identifies code and asset licensing, so a source-code
license should not be assumed to cover its art or music.
[Source: repository README](https://github.com/a327ex/BYTEPATH).
