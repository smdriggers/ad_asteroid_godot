extends Camera2D
class_name CameraControl
# render/camera_control.gd — manual zoom (DESIGN.md §6). The player sets
# it with the zoom bar on the right edge (render/zoom_bar_view.gd); the
# mouse wheel nudges it.
#
# `zoom_scale` follows DESIGN.md's own convention: bigger = more
# magnified/zoomed in, smaller = more zoomed out (hence zoom_min being
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
			set_zoom_scale(zoom_scale * Config.ZOOM_SPEED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom_scale(zoom_scale / Config.ZOOM_SPEED)

func set_zoom_scale(z: float) -> void:
	zoom_scale = clamp(z, zoom_min, Config.ZOOM_MAX)
	_apply()

# --- Opening shot: whole system, then glide in to the ship ---
# The camera rides the ship, so the "system view" is the camera pushed
# back onto the star with `offset` (world units) at zoom_min, then eased
# to no offset at the player's zoom. main.gd freezes the sim meanwhile.

var intro_time: float = -1.0   # < 0 = no intro running
var intro_from_offset: Vector2 = Vector2.ZERO
var intro_to_zoom: float = Config.ZOOM_DEFAULT

func intro_active() -> bool:
	return intro_time >= 0.0

func start_intro(star_offset: Vector2) -> void:
	# star_offset: star position minus ship position.
	intro_from_offset = star_offset
	intro_to_zoom = clampf(maxf(zoom_scale, Config.INTRO_END_ZOOM), zoom_min, Config.ZOOM_MAX)
	intro_time = 0.0
	_step_intro_view()

func step_intro(delta: float) -> void:
	if not intro_active():
		return
	intro_time += delta
	if intro_time >= Config.INTRO_HOLD + Config.INTRO_ZOOM_TIME:
		end_intro()
	else:
		_step_intro_view()

func end_intro() -> void:
	intro_time = -1.0
	offset = Vector2.ZERO
	set_zoom_scale(intro_to_zoom)

func _step_intro_view() -> void:
	var t: float = clampf((intro_time - Config.INTRO_HOLD) / Config.INTRO_ZOOM_TIME, 0.0, 1.0)
	var e: float = t * t * (3.0 - 2.0 * t)  # ease in and out
	offset = intro_from_offset * (1.0 - e)
	# Log space, so the zoom-in feels even from system scale down to ship scale.
	zoom_scale = exp(lerpf(log(zoom_min), log(intro_to_zoom), e))
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
