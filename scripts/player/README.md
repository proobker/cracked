# Player actor

player.gd owns the CharacterBody3D, head/camera, movement, health/regen, aim
assistance, recoil application and weapon selection. Death, damage and weapon
change signals feed Game and the HUD.

It constructs the selected three guns through Arsenal in _ready, attaches them
to the camera and equips the first. Motion data drives weapon spread and
viewmodel effects. collect_ammo dispatches by kind. weapon_by_kind returns
null when no match exists; grenade kills retain their own attribution.

## Expansion contracts

The validated three-slot loadout and aggregated skill effects come from a
frozen attempt build; services own purchases and permanent selections.
SkillCatalog folds small circuit bonuses into the original combat effect keys.
Player owns timed movement/handling buffs and hold/release grenade preview.
Reset temporary bonuses, callbacks and resistance during teardown. Preserve
dash invulnerability duration and dry-gun skipping.

[The handoff](../../docs/expansion-implementation.md) defines grenade interaction
with movement, aim, reload, swapping and pause.

## Checks

Exercise three slots, all-dry states, collection, scope, dash/slide, death and
repeated attempts with different builds. Verify modifiers do not accumulate
and no paused/closed UI action triggers a shot on returning to play.
