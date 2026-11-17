extends Camera2D
class_name CameraControl
# render/camera_control.gd — mouse-wheel zoom (DESIGN.md §6).
#
# `zoom_scale` follows DESIGN.md's own convention: bigger = more
# magnified/zoomed in, smaller = more zoomed out (hence ZOOM_MIN being
# the "whole system roughly in view" end).
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

func _ready() -> void:
	_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_scale = clamp(zoom_scale * Config.ZOOM_SPEED, zoom_min, Config.ZOOM_MAX)
			_apply()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_scale = clamp(zoom_scale / Config.ZOOM_SPEED, zoom_min, Config.ZOOM_MAX)
			_apply()

func zoom_by(factor: float) -> void:
	# Pinch-to-zoom (render/touch_controls_view.gd): factor > 1 zooms in.
	zoom_scale = clamp(zoom_scale * factor, zoom_min, Config.ZOOM_MAX)
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
