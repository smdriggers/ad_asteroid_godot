extends Node2D
# render/ship_view.gd — draws the ship as a triangle outline pointing along
# its parent Ship's heading (DESIGN.md §16.1: "Ships: triangle outlines
# pointing along the heading"). Pure drawing; reads Config for size/color
# and the parent Ship node for heading. No simulation logic here.
#
# The triangle is drawn once, nose up, and turned by rotating this node
# (heading convention: 0 = up, clockwise — same as Node2D.rotation), so
# it's only rebuilt when the zoom changes (glow/tube widths are screen px).

var _drawn_zoom: float = -1.0

func _process(_delta: float) -> void:
	rotation = get_parent().heading
	if not is_equal_approx(Glow.zoom_of(self), _drawn_zoom):
		queue_redraw()

func _draw() -> void:
	_drawn_zoom = Glow.zoom_of(self)
	var r: float = Config.SHIP_RADIUS
	# Local "up"/nose direction is (0, -1), matching DESIGN.md §4.1.
	var nose := Vector2(0, -r)
	var back_left := Vector2(-r * 0.6, r * 0.8)
	var back_right := Vector2(r * 0.6, r * 0.8)
	var points := PackedVector2Array([nose, back_left, back_right, nose])
	Glow.polyline(self, points, Config.SHIP_COLOR, 2.0)
