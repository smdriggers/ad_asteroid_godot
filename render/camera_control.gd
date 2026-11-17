extends Camera2D
class_name CameraControl
# render/camera_control.gd — auto-zoom by proximity, plus a mouse-wheel
# nudge on top (DESIGN.md §6).
#
# `zoom_scale` follows DESIGN.md's own convention: bigger = more
# magnified/zoomed in, smaller = more zoomed out (hence ZOOM_MIN being
# the "whole system roughly in view" end).
#
# Auto-zoom: main.gd calls step_auto() every physics tick with the
# distance from the ship to the nearest body's surface; the camera eases
# (in log space, so zooming feels even at every scale) toward a zoom that
# frames that gap. The wheel scales `zoom_bias`, multiplied on top.
#
# NOTE: the official Camera2D docs describe `zoom` as "bigger value shows
# more area" (i.e. the opposite of our convention), which is why this used
# to set `zoom = 1/zoom_scale`. Measured on-device (debug print of the
# live `zoom` property vs. the actual rendered size), this build's
# Camera2D.zoom instead magnifies as it grows — bigger `zoom` = bigger
# on screen — matching our convention directly. So `zoom` is set straight
# to `zoom_scale`, no inversion. If a future Godot upgrade flips this back,
# the symptom will be bodies drawn far larger or smaller than
# drawn_radius()/the HUD/thrust math expect — recheck with the same
# print-the-live-zoom-and-compare-to-measured-pixels approach before
# changing this again.

var zoom_scale: float = Config.ZOOM_DEFAULT
var zoom_min: float = 0.1  # DESIGN.md §3.4: per level ("whole system roughly in view"); set from main.gd when the system is (re)built
var auto_zoom: float = Config.ZOOM_DEFAULT  # smoothed auto-zoom, before zoom_bias
var zoom_bias: float = 1.0                  # mouse-wheel multiplier on top of auto_zoom

func _ready() -> void:
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_bias = clamp(zoom_bias * Config.ZOOM_SPEED, Config.ZOOM_BIAS_MIN, Config.ZOOM_BIAS_MAX)
			_recompute()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_bias = clamp(zoom_bias / Config.ZOOM_SPEED, Config.ZOOM_BIAS_MIN, Config.ZOOM_BIAS_MAX)
			_recompute()

func target_zoom(surface_dist: float) -> float:
	var view: Vector2 = get_viewport_rect().size
	var half_min: float = min(view.x, view.y) * 0.5
	var gap: float = max(surface_dist, 0.0) + Config.AUTO_ZOOM_PADDING
	return clamp(Config.AUTO_ZOOM_VIEW_FRACTION * half_min / gap, zoom_min, Config.AUTO_ZOOM_MAX)

func step_auto(delta: float, surface_dist: float) -> void:
	var target: float = target_zoom(surface_dist)
	var t: float = 1.0 - exp(-Config.AUTO_ZOOM_RATE * delta)
	auto_zoom = exp(lerp(log(max(auto_zoom, 0.0001)), log(target), t))
	_recompute()

func _recompute() -> void:
	zoom_scale = clamp(auto_zoom * zoom_bias, zoom_min, Config.ZOOM_MAX)
	_apply()

func _apply() -> void:
	zoom = Vector2(zoom_scale, zoom_scale)

static func drawn_radius(real_radius: float, min_screen_size: float, zoom_scale: float) -> float:
	# DESIGN.md §16.1: never smaller than min_screen_size px on screen.
	# Screen size = world size * zoom_scale (this class's own convention,
	# not Godot's native zoom), so the world-space floor is the inverse.
	if min_screen_size <= 0.0:
		return real_radius
	return max(real_radius, min_screen_size / zoom_scale)
