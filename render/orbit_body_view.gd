extends Node2D
# render/orbit_body_view.gd — draws its parent OrbitBody as a circle
# outline (DESIGN.md §16.1). Color, camera and min_screen_size are set
# per-instance from main.gd. The body orbits by moving its node, so the
# recorded drawing just travels with it; it's only rebuilt when the zoom
# changes (the drawn radius has on-screen min/max sizes, and the glow is
# in screen px), and only while on screen — DESIGN.md §16.1: "The station
# is drawn bigger as you zoom out... also sets docking reach."

var outline_color: Color = Color.WHITE
var camera: CameraControl = null
var min_screen_size: float = 0.0  # 0 = no floor
var max_screen_size: float = 0.0  # 0 = no ceiling; set per-instance (planet/station) from main.gd
var glow_strength: float = 1.0    # halo width multiplier (render/glow.gd); the star uses more

var _drawn_zoom: float = -1.0
var _drawn_color: Color = Color(0, 0, 0, 0)

func _process(_delta: float) -> void:
	if is_equal_approx(Glow.zoom_of(self), _drawn_zoom) and outline_color == _drawn_color:
		return
	if not Glow.on_screen(self, _drawn_radius()):
		return
	queue_redraw()

func _drawn_radius() -> float:
	var r: float = get_parent().body_radius
	var drawn_r: float = r
	if camera != null:
		drawn_r = CameraControl.drawn_radius(r, min_screen_size, camera.zoom_scale)
		if max_screen_size > 0.0:
			# Not real size past this point — stops the planet/station from
			# ballooning as the camera zooms in close.
			drawn_r = min(drawn_r, max_screen_size / camera.zoom_scale)
	return drawn_r

func _draw() -> void:
	_drawn_zoom = Glow.zoom_of(self)
	_drawn_color = outline_color
	if get_parent().body_radius <= 0.0:
		return
	Glow.arc(self, Vector2.ZERO, _drawn_radius(), outline_color, 2.0, 48, glow_strength)
