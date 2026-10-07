class_name Crosshair
extends Control
## Crosshair plus the three markers (§9): hit, weak point, kill. Each one
## looks different, because hitting and killing must never look the same.

const MARKERS := {
	"hit": {"color": Color(1, 1, 1), "size": 9.0, "time": 0.12},
	"weak": {"color": Color(1.0, 0.65, 0.1), "size": 12.0, "time": 0.18},
	"kill": {"color": Color(1.0, 0.15, 0.3), "size": 16.0, "time": 0.3},
}

var _marker := ""
var _marker_left := 0.0


func show_marker(kind: String) -> void:
	if not MARKERS.has(kind):
		return
	# A kill marker is never overwritten by a hit landing in the same instant.
	if _marker == "kill" and _marker_left > 0.0 and kind != "kill":
		return
	_marker = kind
	_marker_left = MARKERS[kind]["time"]
	queue_redraw()


func _process(delta: float) -> void:
	if _marker_left > 0.0:
		_marker_left -= delta
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var white := Color(1, 1, 1, 0.85)
	draw_line(c + Vector2(-10, 0), c + Vector2(-4, 0), white, 2.0)
	draw_line(c + Vector2(4, 0), c + Vector2(10, 0), white, 2.0)
	draw_line(c + Vector2(0, -10), c + Vector2(0, -4), white, 2.0)
	draw_line(c + Vector2(0, 4), c + Vector2(0, 10), white, 2.0)
	if _marker_left > 0.0:
		var spec: Dictionary = MARKERS[_marker]
		var col: Color = spec["color"]
		var s: float = spec["size"]
		var w := 3.0 if _marker == "kill" else 2.0
		draw_line(c + Vector2(-s, -s), c + Vector2(-s / 2, -s / 2), col, w)
		draw_line(c + Vector2(s, -s), c + Vector2(s / 2, -s / 2), col, w)
		draw_line(c + Vector2(-s, s), c + Vector2(-s / 2, s / 2), col, w)
		draw_line(c + Vector2(s, s), c + Vector2(s / 2, s / 2), col, w)
