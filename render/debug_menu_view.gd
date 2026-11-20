extends Control
# render/debug_menu_view.gd — the DEBUG button (bottom centre) and its
# panel of debug switches, on every screen: start, flight, station, game
# over. Lives in its own top canvas layer and is added last, so it gets
# input before everything else and swallows taps/clicks on itself.
# Shown only while Config.DEBUG_KEYS_ENABLED. Debug only; not for release.

const BUTTON_SIZE: Vector2 = Vector2(96.0, 30.0)
const BUTTON_BOTTOM_GAP: float = 8.0
const ROW_SIZE: Vector2 = Vector2(300.0, 44.0)
const ROW_GAP: float = 6.0
const FONT_SIZE: int = 16

var main: Node2D = null
var open: bool = false
var mouse_held: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	visible = Config.DEBUG_KEYS_ENABLED
	if visible:
		queue_redraw()

# --- Layout ---

func _rows() -> Array:
	# [label, state text or "" for actions, callable]
	return [
		["Speed readout", _on_off(DebugFlags.show_speed), func(): DebugFlags.show_speed = not DebugFlags.show_speed],
		["Performance readout", _on_off(DebugFlags.show_perf), func(): DebugFlags.show_perf = not DebugFlags.show_perf],
		["Unlimited credits (F2)", _on_off(main.unlimited_credits), func(): main.toggle_unlimited_credits()],
		["Reveal all asteroids (F1)", "", func(): main.debug_reveal_all()],
	]

func _on_off(b: bool) -> String:
	return "ON" if b else "OFF"

func _button_rect() -> Rect2:
	return Rect2(Vector2((size.x - BUTTON_SIZE.x) / 2.0, size.y - BUTTON_SIZE.y - BUTTON_BOTTOM_GAP), BUTTON_SIZE)

func _row_rect(i: int, count: int) -> Rect2:
	# Rows stack upward from just above the button.
	var bottom: float = _button_rect().position.y - ROW_GAP
	var y: float = bottom - (count - i) * (ROW_SIZE.y + ROW_GAP) + ROW_GAP
	return Rect2(Vector2((size.x - ROW_SIZE.x) / 2.0, y), ROW_SIZE)

func _panel_rect(count: int) -> Rect2:
	var top: Rect2 = _row_rect(0, count)
	var bottom: Rect2 = _row_rect(count - 1, count)
	return Rect2(top.position, Vector2(ROW_SIZE.x, bottom.end.y - top.position.y)).grow(ROW_GAP)

# --- Input ---

func _input(event: InputEvent) -> void:
	if not visible or main == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _press(event.position):
			get_viewport().set_input_as_handled()
		elif not event.pressed and open:
			get_viewport().set_input_as_handled()  # the lift of a tap that hit the menu
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _press(event.position):
			mouse_held = true
			PlayerInput.mouse_on_ui = true  # this click mustn't also fire the laser
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_held:
			mouse_held = false
			PlayerInput.mouse_on_ui = false
			get_viewport().set_input_as_handled()

func _press(pos: Vector2) -> bool:
	# Handles a press; returns whether it was ours (and so swallowed).
	if _button_rect().has_point(pos):
		open = not open
		return true
	if not open:
		return false
	var rows: Array = _rows()
	for i in range(rows.size()):
		if _row_rect(i, rows.size()).has_point(pos):
			rows[i][2].call()
			return true
	open = false  # a press anywhere else just closes the panel
	return true

# --- Drawing ---

func _draw() -> void:
	if main == null:
		return
	var font: Font = ThemeDB.fallback_font
	var accent: Color = Color(1.0, 0.4, 0.8)  # debug pink, unlike any game color

	var b: Rect2 = _button_rect()
	draw_rect(b, Color(accent, 0.35 if open else 0.15))
	draw_rect(b, Color(accent, 0.9), false, 1.5)
	_centered(font, "DEBUG", Color.WHITE, b.get_center().x, b.get_center().y + 6.0, 14)

	if not open:
		return
	var rows: Array = _rows()
	var panel: Rect2 = _panel_rect(rows.size())
	draw_rect(panel, Color(0, 0, 0, 0.85))
	draw_rect(panel, Color(accent, 0.9), false, 1.5)
	for i in range(rows.size()):
		var r: Rect2 = _row_rect(i, rows.size())
		var state: String = rows[i][1]
		var on: bool = state == "ON"
		draw_rect(r, Color(accent, 0.3 if on else 0.1))
		draw_string(font, r.position + Vector2(12.0, r.size.y / 2.0 + 6.0), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
		var right: String = state if state != "" else "DO IT"
		var tw: float = font.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		draw_string(font, r.position + Vector2(r.size.x - tw - 12.0, r.size.y / 2.0 + 6.0), right, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, accent if on or state == "" else Color(1, 1, 1, 0.5))

func _centered(font: Font, text: String, color: Color, cx: float, y: float, font_size: int) -> void:
	var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(cx - tw / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
