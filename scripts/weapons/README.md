# Weapons and shot effects

weapon.gd provides hitscan firing, magazines/reserves, reloads, damage falloff,
pellets, bloom, recoil recovery, scope and viewmodel animation. It emits
fired(result) and ammo_changed(weapon); tick returns recoil for Player to apply.

rifle.gd, shotgun.gd and marksman.gd configure tuning and build their models.
shot_fx.gd supplies transient shot visuals. [Shaders](../../shaders/README.md)
keep first-person models visible beside walls.

Player supplies camera, effect parent and motion information. Game consumes
shot results for feedback; weapon kinds also identify ammo and current rewards.

## Expansion implementation

Stable Arsenal IDs select nine guns. expansion_weapon.gd configures six new
guns, including burst/charge/projectile/chain behaviors. combat.gd centralizes
attributed hits, wall visibility and radial damage; ordnance.gd owns swept
projectiles, frag bounces, EMP and bounded incendiary fields.
All weapons reuse ammo/reload/feedback contracts.
World collision remains independent of depth-squeezed viewmodels.

Damage captures its source so delayed kills retain attribution after swapping.
Reserve-to-magazine skills transfer existing ammo and respect capacity.
Use bounded chains/effects and wall occlusion per
[design](../../plans.md#16-arsenal--skills--expansion).

## Checks

For every gun: cadence, reload, empty states, swaps, moving spread, scope where
supported, feedback and walls. Also test charge interruption, self-blast,
multi-target kills, delayed sources and repeated damage to one enemy.
