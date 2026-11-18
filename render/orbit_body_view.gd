extends Node2D
# render/orbit_body_view.gd — draws its parent OrbitBody as a circle
# outline (DESIGN.md §16.1). Color, camera and min_screen_size are set
# per-instance from main.gd. Redraws every frame, not just once, since
# the drawn radius now depends on the camera's zoom (which the player
# changes live) whenever min_screen_size is set — DESIGN.md §16.1: "The
# station is drawn bigger as you zoom out... also sets docking reach."

var outline_color: Color = Color.WHITE
var camera: CameraControl = null
var min_screen_size: float = 0.0  # 0 = no floor
var max_screen_size: float = 0.0  # 0 = no ceiling; set per-instance (planet/station) from main.gd
var glow_strength: float = 1.0    # halo width multiplier (render/glow.gd); the star uses more

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r: float = get_parent().body_radius
	if r <= 0.0:
		return
	var drawn_r: float = r
	if camera != null:
		drawn_r = CameraControl.drawn_radius(r, min_screen_size, camera.zoom_scale)
		if max_screen_size > 0.0:
			# Not real size past this point — stops the planet/station from
			# ballooning as the camera zooms in close.
			drawn_r = min(drawn_r, max_screen_size / camera.zoom_scale)
	Glow.arc(self, Vector2.ZERO, drawn_r, outline_color, 2.0, 48, glow_strength)
