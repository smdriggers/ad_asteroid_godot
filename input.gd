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
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_SPACE)

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
