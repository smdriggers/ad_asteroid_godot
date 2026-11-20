extends Node2D
# render/trajectory_view.gd — draws the dotted coast-ahead path and crash
# X computed by game/trajectory.gd (DESIGN.md §5). Pure drawing; reads the
# latest Trajectory.Result from its parent (Main) each frame. A sibling of
# Star/Planet/Station/Ship, so it draws in the same world space as those —
# no extra transform needed.

var _drawn_result = null

func _process(_delta: float) -> void:
	# Redraw only when main.gd has computed a new path (or hidden it).
	var result = get_parent().trajectory_result
	if result != _drawn_result:
		_drawn_result = result
		queue_redraw()

func _draw() -> void:
	var main = get_parent()
	var result = main.trajectory_result
	if result == null:
		return
	var points: Array = result.points
	var i: int = 0
	while i < points.size():
		draw_circle(points[i], 1.5, Config.TRAJECTORY_DOT_COLOR)
		i += Config.TRAJECTORY_DOT_EVERY
	if result.crash_point != null:
		var p: Vector2 = result.crash_point
		var s: float = Config.TRAJECTORY_X_SIZE
		draw_line(p + Vector2(-s, -s), p + Vector2(s, s), Config.TRAJECTORY_CRASH_COLOR, 2.0)
		draw_line(p + Vector2(-s, s), p + Vector2(s, -s), Config.TRAJECTORY_CRASH_COLOR, 2.0)
