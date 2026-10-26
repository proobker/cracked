# Shared input

player_input.gd is PlayerInput, registering keyboard/mouse/gamepad actions and
combining them with touch_move, touch_sprint and accumulated look. Gameplay
consumes common intents/actions. Touch widgets live in [UI](../ui/README.md).

Existing actions cover movement/look, fire, reload, swap, three direct slots,
scope, dash, grenade and pause. Desktop controls support testing, not a new release platform.

## Grenade interaction

Grenade hold/release uses left bumper and G, with touch producing equivalent
states. Dragging outside the touch button cancels. Movement/aiming remain available.

Cancel pending previews and consumed edge inputs on pause, focus loss, overlay
closure and scene transitions. Cancellation spends no charge. Armory gestures
must not become fire/throw actions when a level starts.

## Checks

Desktop gameplay uses captured, hidden mouse input and unscaled screen-relative
motion. Desktop menus, Armory and pause use a visible confined cursor. Focus
loss releases it and pauses an active run; returning restores the appropriate
mode, with explicit Resume after an interruption. Pointer transitions clear
pending look movement. Desktop touch capability never disables mouse bindings.
Mobile retains touch controls. See [research](../../docs/mouse-capture-research.md).

Touch pointer ownership/cancel, controller and keyboard holds, mixed-device
double triggers, preview interrupted by pause, transition input leakage and
movement/look while previewing.
