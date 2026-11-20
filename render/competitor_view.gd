extends Node2D
# render/competitor_view.gd — draws a competitor as a triangle outline in
# Config.COMP_COLOR, same shape as render/ship_view.gd's player triangle
# (DESIGN.md §16.1 implies competitors share the ship's look, in their own
# color — §14 intro / amber in the pygame project).
#
# Like the player's ship: drawn once nose up and turned by rotating the
# node; rebuilt only on a zoom change, and only while on screen.

var _drawn_zoom: float = -1.0

func _process(_delta: float) -> void:
	rotation = get_parent().heading
	if not is_equal_approx(Glow.zoom_of(self), _drawn_zoom) and Glow.on_screen(self, Config.SHIP_RADIUS):
		queue_redraw()

func _draw() -> void:
	_drawn_zoom = Glow.zoom_of(self)
	var r: float = Config.SHIP_RADIUS
	var nose := Vector2(0, -r)
	var back_left := Vector2(-r * 0.6, r * 0.8)
	var back_right := Vector2(r * 0.6, r * 0.8)
	var points := PackedVector2Array([nose, back_left, back_right, nose])
	Glow.polyline(self, points, Config.COMP_COLOR, 2.0)
