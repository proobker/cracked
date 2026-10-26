# World construction

room.gd builds rectangular rooms, cover and gates from specifications. Room
center is local origin: entry wall +Z, enemy wall -Z. spawn_points, bounds and
start_position expose world coordinates. Doors provide close_entry/open_exit;
entered notifies LevelRun.

plaza.gd builds menu/practice geometry. blockout.gd supplies reusable geometry,
environment and skyline.

LevelRun owns room progression; Room owns geometry/door state. Cover must leave
traversable gaps. Enemy spawns remain at far-wall gates.

## Planned changes and checks

Keep the layout model. Coins/effects need room identity for cleanup, but banking
belongs in game systems. Ray/shape queries use actual world collision so blasts,
chains and trajectories respect walls.

Run generated-level invariants after geometry/collision changes; exercise cover
edges, corridors, boss gates and explosions beside walls.
