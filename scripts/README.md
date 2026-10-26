# Runtime scripts

Godot GDScript owns most construction. The entry scenes are thin shells:
game/main.gd builds runs/practice; ui/menu.gd builds the title interface.

- [Game](game/README.md): orchestration, levels, saves, score, drops, tuning, audio.
- [Player](player/README.md): movement, health, camera and carried guns.
- [Weapons](weapons/README.md): firing, ammo, first-person models and effects.
- [Enemies](enemies/README.md): actors, AI, damage and projectiles.
- [Input](input/README.md): common device intents/actions.
- [UI](ui/README.md): menus, HUD, controls and settings.
- [World](world/README.md): geometry, gates and skyline.

Flow: menu selects level -> Game builds world/player/director -> LevelRun starts
rooms -> WaveDirector spawns enemies -> death events feed score/drops -> final
clear updates Progress/PlayGames.

Global services are declared in project.godot. Keep saved settings, persistent
progress and attempt-local state distinct. Skills must not mutate global base
tuning or survive into later attempts accidentally.

[Design §16](../plans.md#16-arsenal--skills--expansion) specifies expansion
behavior; [the handoff](../docs/expansion-implementation.md) explains integration.
