# Entry scenes

main.tscn is a Node3D using scripts/game/main.gd, which constructs run/practice
content. menu.tscn is a Node3D using scripts/ui/menu.gd, which constructs title
UI and backdrop. The scenes intentionally remain small.

Runtime-created children and signal subscriptions need clear teardown ownership.
The planned expansion must dispose of projectiles, coins, skill callbacks and
temporary UI state on retry/menu transitions.

Read [Game](../scripts/game/README.md) and [UI](../scripts/ui/README.md) before
moving responsibilities. Check menu -> play -> retry -> menu and practice ->
menu for duplicate actors/signals and retained modifiers.
