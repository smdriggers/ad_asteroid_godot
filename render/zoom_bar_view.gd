extends Control
# render/zoom_bar_view.gd — the manual zoom control: a graduated vertical
# bar down the right edge of the screen. Top = zoomed in (ZOOM_MAX),
# bottom = zoomed out (the level's zoom_min), spaced in log scale so each
# tick is the same zoom ratio. Press anywhere on it (touch or left mouse)
# and drag to set the zoom. The mouse wheel still nudges it
# (render/camera_control.gd). Shown in flight only.
#
# Sits in the Touch canvas layer after TouchControlsView, so it receives
# input first and swallows presses on the bar before the joystick, the
# buttons or the tractor beam see them.

const MARGIN_RIGHT: float = 28.0   # bar's center line, from the right edge
const MARGIN_Y: float = 70.0       # gap above and below the bar
const HIT_HALF_WIDTH: float = 22.0 # px either side of the line that still grabs the bar
const TICKS: int = 13              # graduations, top to bottom
const KNOB_HALF: Vector2 = Vector2(14.0, 5.0)

var main: Node2D = null
var finger: int = -1        # touch index dragging the bar, or -1
var mouse_drag: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _cam() -> CameraControl:
	return main.get_node("Ship/Camera2D") as CameraControl

func _in_flight() -> bool:
	return main != null and not main.showing_instructions and not main.game_over and not main.docked

func _process(_delta: float) -> void:
	visible = _in_flight()
	if not visible:
		finger = -1
		_set_mouse_drag(false)
	else:
		queue_redraw()

func _top() -> float:
	return MARGIN_Y

func _bottom() -> float:
	return size.y - MARGIN_Y

func _x() -> float:
	return size.x - MARGIN_RIGHT

func _hit(pos: Vector2) -> bool:
	return absf(pos.x - _x()) <= HIT_HALF_WIDTH and pos.y >= _top() - HIT_HALF_WIDTH and pos.y <= _bottom() + HIT_HALF_WIDTH

func _t_for_zoom(z: float) -> float:
	# 0 at the bottom (zoom_min), 1 at the top (ZOOM_MAX), log scale.
	var cam: CameraControl = _cam()
	var lo: float = log(cam.zoom_min)
	var hi: float = log(Config.ZOOM_MAX)
	return clampf((log(z) - lo) / (hi - lo), 0.0, 1.0)

func _y_for_t(t: float) -> float:
	return lerpf(_bottom(), _top(), t)

func _set_from_y(y: float) -> void:
	var cam: CameraControl = _cam()
	var t: float = clampf((_bottom() - y) / (_bottom() - _top()), 0.0, 1.0)
	cam.set_zoom_scale(exp(lerpf(log(cam.zoom_min), log(Config.ZOOM_MAX), t)))

func _set_mouse_drag(on: bool) -> void:
	mouse_drag = on
	PlayerInput.mouse_on_ui = on  # so the held left button doesn't also fire the laser

func _input(event: InputEvent) -> void:
	if not _in_flight():
		return
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and _hit(event.position):
			finger = event.index
			_set_from_y(event.position.y)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			finger = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_set_from_y(event.position.y)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _hit(event.position):
			_set_mouse_drag(true)
			_set_from_y(event.position.y)
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_drag:
			_set_mouse_drag(false)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and mouse_drag:
		_set_from_y(event.position.y)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var x: float = _x()
	var active: bool = finger != -1 or mouse_drag
	var line_col := Color(1, 1, 1, 0.45 if active else 0.25)

	draw_line(Vector2(x, _top()), Vector2(x, _bottom()), line_col, 2.0, true)
	for i in range(TICKS):
		var y: float = lerpf(_top(), _bottom(), float(i) / float(TICKS - 1))
		var major: bool = i % 3 == 0
		var half: float = 10.0 if major else 5.0
		draw_line(Vector2(x - half, y), Vector2(x + half, y), line_col, 2.0 if major else 1.0, true)

	# + / - labels at the ends.
	var font: Font = ThemeDB.fallback_font
	var fs: int = 18
	for pair in [["+", _top() - 14.0], ["-", _bottom() + 26.0]]:
		var tw: float = font.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(x - tw / 2.0, pair[1]), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, line_col)

	# Knob at the current zoom.
	var ky: float = _y_for_t(_t_for_zoom(_cam().zoom_scale))
	var rect := Rect2(Vector2(x, ky) - KNOB_HALF, KNOB_HALF * 2.0)
	draw_rect(rect, Color(1, 1, 1, 0.6 if active else 0.4))
	draw_rect(rect, Color(1, 1, 1, 0.9), false, 1.5)
