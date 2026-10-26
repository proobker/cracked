# Documentation map

[plans.md](../plans.md) owns design decisions; [release.md](../release.md) owns
release facts. Read [the implementation handoff](expansion-implementation.md)
before expansion work, then the relevant folder guide.

| Area | Read when changing |
|---|---|
| [Scripts](../scripts/README.md) | Runtime ownership and dependency flow |
| [Game](../scripts/game/README.md) | Level lifecycle, rewards, saves, score, tuning, audio |
| [Player](../scripts/player/README.md) | Movement, health, camera and weapon slots |
| [Weapons](../scripts/weapons/README.md) | Firing, ammunition, viewmodels and effects |
| [Enemies](../scripts/enemies/README.md) | AI, damage, kill attribution and enemy roles |
| [Input](../scripts/input/README.md) | Common actions across touch/gamepad/desktop |
| [UI](../scripts/ui/README.md) | Menus, HUD, touch controls and 405-node Armory |
| [World](../scripts/world/README.md) | Geometry, gates, cover and coordinates |
| [Scenes](../scenes/README.md) | Entry scenes and runtime construction |
| [Shaders](../shaders/README.md) | First-person depth and muzzle flash |
| [Tests](../tests/README.md) | Isolated progression/combat checks and device limitations |
| [Tools](../tools/README.md) | Build, publication, account setup and image utilities |
| [Website](../site/README.md) | Static pages and deployment |
| [Android](../android/README.md) | Export template/platform boundary |
| [Addons](../addons/README.md) | Vendored integration boundary |

Folder guides document existing code and explicitly label planned work. Keep
vendor internals intact; generated outputs do not need handwritten code guides.
