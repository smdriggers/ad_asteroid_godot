extends Node2D
# render/competitor_view.gd — draws a competitor as a triangle outline in
# Config.COMP_COLOR, same shape as render/ship_view.gd's player triangle
# (DESIGN.md §16.1 implies competitors share the ship's look, in their own
# color — §14 intro / amber in the pygame project).

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r: float = Config.SHIP_RADIUS
	var heading: float = get_parent().heading
	var nose := Vector2(0, -r).rotated(heading)
	var back_left := Vector2(-r * 0.6, r * 0.8).rotated(heading)
	var back_right := Vector2(r * 0.6, r * 0.8).rotated(heading)
	var points := PackedVector2Array([nose, back_left, back_right, nose])
	Glow.polyline(self, points, Config.COMP_COLOR, 2.0)
