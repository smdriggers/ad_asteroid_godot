extends Control
# render/trajectory_toggle_view.gd — on-screen PATH button (top-right,
# left of the zoom bar) that shows/hides the predicted trajectory. Tap or
# left-click it; the T key does the same (main.gd). Shown in flight only.
#
# Sits in the Touch canvas layer after the zoom bar, so it gets input
# first and swallows presses on it before the joystick, buttons, tractor
# beam or laser see them.

const OFFSET: Vector2 = Vector2(-92.0, 46.0)  # button center, from the top-right corner
const RADIUS: float = 26.0
const HIT_SLACK: float = 1.25

var main: Node2D = null
var mouse_held: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _in_flight() -> bool:
	return main != null and not main.showing_instructions and not main.game_over and not main.docked

func _process(_delta: float) -> void:
	visible = _in_flight()
	if visible:
		queue_redraw()

func _center() -> Vector2:
	return Vector2(size.x + OFFSET.x, OFFSET.y)

func _hit(pos: Vector2) -> bool:
	return pos.distance_to(_center()) <= RADIUS * HIT_SLACK

func _input(event: InputEvent) -> void:
	if not _in_flight():
		return
	if event is InputEventScreenTouch and event.pressed and _hit(event.position):
		main.toggle_trajectory()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _hit(event.position):
			mouse_held = true
			PlayerInput.mouse_on_ui = true  # the click shouldn't also fire the laser
			main.toggle_trajectory()
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_held:
			mouse_held = false
			PlayerInput.mouse_on_ui = false
			get_viewport().set_input_as_handled()

func _draw() -> void:
	var c: Vector2 = _center()
	var on: bool = main.show_trajectory
	var col: Color = Config.TRAJECTORY_DOT_COLOR
	draw_circle(c, RADIUS, Color(col, 0.35 if on else 0.08))
	draw_arc(c, RADIUS, 0.0, TAU, 40, Color(col, 0.9 if on else 0.45), 2.0, true)
	# A little dotted curve as the icon.
	for i in range(5):
		var t: float = float(i) / 4.0
		var p: Vector2 = c + Vector2(lerpf(-12.0, 12.0, t), -6.0 + 12.0 * (t - 0.5) * (t - 0.5) * 4.0 - 3.0)
		draw_circle(p, 1.8, Color(1, 1, 1, 0.9 if on else 0.4))
	var font: Font = ThemeDB.fallback_font
	var fs: int = 11
	var label: String = "PATH"
	var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-tw / 2.0, 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9 if on else 0.45))
