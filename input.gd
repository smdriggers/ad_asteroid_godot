extends RefCounted
class_name PlayerInput
# input.gd — keyboard -> turn/thrust, mirroring DESIGN.md §4.1. Stateless;
# reads physical key state directly rather than the Input Map, so this
# matches DESIGN.md's exact keys without needing project-settings action
# bindings set up first. Fire/mode-switch (mouse, Space, G) arrive with
# mining in a later milestone.

static func turn_input() -> float:
	# -1 (Q), 0, or +1 (E). Matches the pygame project's input.py exactly.
	var t := 0.0
	if Input.is_physical_key_pressed(KEY_E):
		t += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		t -= 1.0
	return t

static func local_thrust() -> Vector2:
	# x = strafe (+right/D, -left/A); y = forward (+W, -back/S), in the
	# ship's own frame. Ship.thrust_accel_vector() turns this into world
	# acceleration using the ship's heading.
	var x := 0.0
	var y := 0.0
	if Input.is_physical_key_pressed(KEY_D):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_W):
		y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		y -= 1.0
	return Vector2(x, y)

static func precision() -> bool:
	return Input.is_physical_key_pressed(KEY_SHIFT)

static func firing() -> bool:
	# DESIGN.md §9, §11.1: "Left mouse or Space — The trigger." What it
	# does (fire or scan) depends on the current mode, tracked in main.gd.
	var mouse: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not mouse_on_ui
	return mouse or Input.is_physical_key_pressed(KEY_SPACE)

static var mouse_on_ui: bool = false  # left button is dragging an on-screen control (the zoom bar), not firing

static func scan_key_down() -> bool:
	# Raw key state; main.gd edge-detects this itself to toggle mode on
	# press rather than every frame it's held — DESIGN.md §11.1 ("G
	# switches the trigger between mine and scan").
	return Input.is_physical_key_pressed(KEY_G)

static func launch_key_down() -> bool:
	# Raw key state; main.gd edge-detects this to launch once per press —
	# DESIGN.md §12.2 ("Tab launches from the station you're docked at").
	return Input.is_physical_key_pressed(KEY_TAB)

# Shop navigation (DESIGN.md §13.4) — raw key state, edge-detected in
# main.gd so each press moves the selection once, not every frame held.
static func nav_left_down() -> bool:
	return Input.is_physical_key_pressed(KEY_LEFT)

static func nav_right_down() -> bool:
	return Input.is_physical_key_pressed(KEY_RIGHT)

static func nav_up_down() -> bool:
	return Input.is_physical_key_pressed(KEY_UP)

static func nav_down_down() -> bool:
	return Input.is_physical_key_pressed(KEY_DOWN)

static func buy_key_down() -> bool:
	return Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)

# --- Touch (mobile) -------------------------------------------------------
# Written every frame by render/touch_controls_view.gd; read here alongside
# the keyboard so main.gd has one place to ask. All zero/false on desktop.
static var touch_active: bool = false     # a touch has been seen this session
static var touch_stick: Vector2 = Vector2.ZERO  # screen-space, length 0..1
static var touch_blast: bool = false
static var touch_bomb: bool = false
static var touch_scan: bool = false
static var touch_tractor: bool = false  # a finger that started the tractor beam is still down

const STICK_AIM_ONLY: float = 0.35     # below this deflection the stick only turns the ship
const STICK_FULL_THRUST: float = 0.75  # above this, full thrust; between, precision (half) thrust
const STICK_THRUST_CONE: float = PI / 6.0  # only thrust once heading is within 30 deg of the stick

static func touch_ui() -> bool:
	# Show touch prompts/controls: either the device says it has a touch
	# screen, or we've actually received a touch.
	return touch_active or DisplayServer.is_touchscreen_available()

static func stick_controls(heading: float, dt: float) -> Dictionary:
	# Point-and-thrust: the ship turns toward the stick's direction (no
	# overshoot), and thrusts forward once it's facing roughly that way.
	# Small deflection = aim only; medium = precision thrust; big = full.
	# Returns {"turn": -1..1, "thrust": Vector2, "precision": bool}, in the
	# same shape as the keyboard inputs above.
	var mag: float = touch_stick.length()
	if mag <= 0.0:
		return {"turn": 0.0, "thrust": Vector2.ZERO, "precision": false}
	# Heading convention (ship.gd): 0 = up (-y), increasing clockwise.
	var target: float = atan2(touch_stick.x, -touch_stick.y)
	var diff: float = wrapf(target - heading, -PI, PI)
	var precision: bool = mag < STICK_FULL_THRUST
	var rate: float = Config.TURN_RATE * (Config.PRECISION_FACTOR if precision else 1.0)
	var turn: float = clampf(diff / (rate * dt), -1.0, 1.0) if dt > 0.0 else 0.0
	var thrust := Vector2.ZERO
	if mag >= STICK_AIM_ONLY and absf(diff) <= STICK_THRUST_CONE:
		thrust = Vector2(0.0, 1.0)
	return {"turn": turn, "thrust": thrust, "precision": precision}
