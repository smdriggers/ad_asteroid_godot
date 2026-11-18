extends Control
# render/touch_controls_view.gd — on-screen controls for phones/tablets:
# a floating joystick on the left half, three arcade buttons on the right
# (BLAST, BOMB, SCAN). Zoom is automatic (render/camera_control.gd). Writes its state into
# PlayerInput's static touch_* vars every event; main.gd reads them there.
# Only shown in flight on a touch device; desktop play is untouched.

const STICK_RADIUS: float = 90.0     # px the knob can travel from the base
const KNOB_RADIUS: float = 38.0
const STICK_HOME := Vector2(170.0, -170.0)  # base rest position, from the bottom-left corner

# Buttons, positioned from the bottom-right corner. Arcade-style arc:
# big BLAST under the thumb, BOMB to its left, SCAN above.
const BUTTONS: Array = [
	{"id": "blast", "label": "BLAST", "offset": Vector2(-135.0, -135.0), "radius": 72.0, "color": Color(1.0, 0.35, 0.3)},
	{"id": "bomb", "label": "BOMB", "offset": Vector2(-305.0, -95.0), "radius": 56.0, "color": Color(1.0, 0.7, 0.2)},
	{"id": "scan", "label": "SCAN", "offset": Vector2(-120.0, -315.0), "radius": 56.0, "color": Color(0.3, 0.85, 1.0)},
]
const BUTTON_HIT_SLACK: float = 1.25  # touch radius multiplier, so near-misses still count

var main: Node2D = null

var stick_finger: int = -1
var stick_origin: Vector2 = Vector2.ZERO
var stick_pos: Vector2 = Vector2.ZERO
var button_fingers: Dictionary = {}  # finger index -> button id
var tractor_finger: int = -1  # finger holding the tractor beam, or -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var want_visible: bool = PlayerInput.touch_ui() and _in_flight()
	if not want_visible and (stick_finger != -1 or tractor_finger != -1 or not button_fingers.is_empty()):
		_release_all()
	visible = want_visible
	if visible:
		queue_redraw()

func _in_flight() -> bool:
	return main != null and not main.showing_instructions and not main.game_over and not main.docked

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		PlayerInput.touch_active = true
		if not _in_flight():
			return
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
		_publish()
	elif event is InputEventScreenDrag:
		if not _in_flight():
			return
		_drag(event.index, event.position)
		_publish()

func _press(finger: int, pos: Vector2) -> void:
	var hit: String = _button_at(pos)
	if hit != "":
		button_fingers[finger] = hit
	elif tractor_finger == -1 and main.tractor_start(pos):
		tractor_finger = finger  # pressed on loose ore: tractor beam, not the stick
	elif pos.x < size.x * 0.5 and stick_finger == -1:
		# Floating stick: the base jumps to wherever the thumb lands (kept
		# fully on screen), so the player never has to hunt for it.
		stick_finger = finger
		stick_origin = Vector2(
			clampf(pos.x, STICK_RADIUS, size.x * 0.5),
			clampf(pos.y, STICK_RADIUS, size.y - STICK_RADIUS))
		stick_pos = pos

func _release(finger: int) -> void:
	if finger == stick_finger:
		stick_finger = -1
	if finger == tractor_finger:
		tractor_finger = -1
	button_fingers.erase(finger)

func _drag(finger: int, pos: Vector2) -> void:
	if finger == stick_finger:
		stick_pos = pos
	elif button_fingers.has(finger):
		# Sliding between buttons switches which one is held, like a real pad.
		var hit: String = _button_at(pos)
		if hit != "":
			button_fingers[finger] = hit

func _release_all() -> void:
	stick_finger = -1
	tractor_finger = -1
	button_fingers.clear()
	_publish()

func _publish() -> void:
	if stick_finger == -1:
		PlayerInput.touch_stick = Vector2.ZERO
	else:
		PlayerInput.touch_stick = ((stick_pos - stick_origin) / STICK_RADIUS).limit_length(1.0)
	var held: Array = button_fingers.values()
	PlayerInput.touch_blast = held.has("blast")
	PlayerInput.touch_bomb = held.has("bomb")
	PlayerInput.touch_scan = held.has("scan")
	PlayerInput.touch_tractor = tractor_finger != -1

func _button_center(b: Dictionary) -> Vector2:
	return size + b.offset

func _button_at(pos: Vector2) -> String:
	for b in BUTTONS:
		if pos.distance_to(_button_center(b)) <= b.radius * BUTTON_HIT_SLACK:
			return b.id
	return ""

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font

	# Joystick
	var base: Vector2 = stick_origin if stick_finger != -1 else Vector2(STICK_HOME.x, size.y + STICK_HOME.y)
	var knob: Vector2 = base + PlayerInput.touch_stick * STICK_RADIUS
	var active: bool = stick_finger != -1
	draw_circle(base, STICK_RADIUS, Color(1, 1, 1, 0.06))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35 if active else 0.2), 2.0, true)
	draw_arc(base, STICK_RADIUS * PlayerInput.STICK_AIM_ONLY, 0.0, TAU, 32, Color(1, 1, 1, 0.12), 1.0, true)
	draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.45 if active else 0.25))

	# Buttons
	for b in BUTTONS:
		var c: Vector2 = _button_center(b)
		var pressed: bool = button_fingers.values().has(b.id)
		var col: Color = b.color
		draw_circle(c, b.radius, Color(col, 0.55 if pressed else 0.15))
		draw_arc(c, b.radius, 0.0, TAU, 48, Color(col, 0.9 if pressed else 0.6), 3.0, true)
		var label: String = b.label
		if b.id == "bomb" and main != null:
			label = "BOMB %d" % main.ship.bombs
		var fs: int = 18
		var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
