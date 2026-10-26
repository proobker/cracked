# Third-party integrations

GodotPlayGameServices is the vendored Android Play Games integration.
The first-party wrapper is [play_games.gd](../scripts/game/play_games.gd);
see [game documentation](../scripts/game/README.md) for its responsibilities.

Preserve vendor code and bundled documentation. Adapt the wrapper for expansion
cloud saves/leaderboards. If upgrading the plugin, record upstream version,
license, configuration changes and device verification separately.

Desktop/offline play must remain usable without sign-in. The legacy leaderboard
must not receive expansion scores.
