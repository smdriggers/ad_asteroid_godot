extends Node2D
# render/ship_view.gd — draws the ship as a triangle outline pointing along
# its parent Ship's heading (DESIGN.md §16.1: "Ships: triangle outlines
# pointing along the heading"). Pure drawing; reads Config for size/color
# and the parent Ship node for heading. No simulation logic here.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r: float = Config.SHIP_RADIUS
	var heading: float = get_parent().heading
	# Local "up"/nose direction is (0, -1), matching DESIGN.md §4.1's
	# heading convention, then rotated by the ship's current heading.
	var nose := Vector2(0, -r).rotated(heading)
	var back_left := Vector2(-r * 0.6, r * 0.8).rotated(heading)
	var back_right := Vector2(r * 0.6, r * 0.8).rotated(heading)
	var points := PackedVector2Array([nose, back_left, back_right, nose])
	Glow.polyline(self, points, Config.SHIP_COLOR, 2.0)
