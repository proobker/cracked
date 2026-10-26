# Enemy actors

enemy.gd is the shared CharacterBody3D with died(enemy), telegraph/activation,
damage/weak-point state and steering helpers. Subclasses configure stats/models
and implement _act. It exposes kind, points, target and last_hit_by.

- rusher.gd: close-pressure behavior.
- shooter.gd: ranged behavior.
- heavy.gd: durable pressure and weak-point combat.
- boss.gd: boss behavior.
- projectile.gd: enemy projectiles.
- shield_robot.gd: frontal mitigation, rear weak point and EMP shield interruption.
- support_robot.gd: visible repair beam to an eligible injured ally.
- enemy_model.gd: robot presentation.

Game owns rewards and saves; actors report deaths. Preserve far-wall spawns,
telegraphs, room bounds and active caps. Steering is not general cover-seeking
navigation. A death produces one reward event. Practice dummies grant none.

## Expansion contracts

Shield/support entries replace existing wave bodies from levels 15/25, preserving
composition budgets. Damage retains grenade/burn/chain sources. Keep shield exposure, repair visibility
and control resistance legible. Support never repairs itself, other supports
or bosses. See [design](../../plans.md#16-arsenal--skills--expansion).

## Checks

Gate placement, activation, exactly-once death, wall-blocked attacks, delayed
sources, boss control caps, EMP shields, interrupted repair and starter-gun
viability without upgrades.
