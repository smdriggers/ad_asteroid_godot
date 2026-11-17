extends Node2D
class_name Ship
# game/ship.gd — the ship's simulation state: position (inherited from
# Node2D), velocity and heading. No drawing here (see render/ship_view.gd),
# matching the pygame project's game/ vs render/ split — DESIGN.md §4, §4.3-4.5.

var velocity: Vector2 = Vector2.ZERO
var heading: float = 0.0     # radians; 0 = up (-y), increasing clockwise — DESIGN.md §4.1
var destroyed: bool = false

# Tiered upgrades (DESIGN.md §13.1), tier 0 = starting value for each. One
# dict, keyed exactly like game/upgrades.gd's UPGRADES table.
var upgrade_tiers: Dictionary = {
	"laser_count": 0, "fire_rate": 0, "laser_tier": 0, "range": 0,
	"cargo_capacity": 0, "engine_power": 0, "scan_depth": 0, "scan_range": 0,
	"scan_width": 0, "scan_pulse": 0, "bomb_radius": 0, "bomb_damage": 0,
	"bomb_rate": 0, "bomb_shrapnel": 0,
}
var bombs: int = 0  # ammo; bought one at a time at the station — DESIGN.md §9.3, §13.2
var distance_flown: float = 0.0  # run total, shown on the game-over screen — DESIGN.md §15.4

func thrust_accel_vector(local_thrust: Vector2, precision: bool, zoom_scale: float) -> Vector2:
	# local_thrust: x = strafe (+right/D, -left/A), y = forward (+W, -back/S).
	# Combined into one normalized direction so a diagonal isn't faster
	# than a single key — DESIGN.md §4.2.
	if local_thrust.length() == 0.0:
		return Vector2.ZERO
	local_thrust = local_thrust.normalized()
	var accel_mag: float = Config.THRUST_ACCEL
	if precision:
		accel_mag *= Config.PRECISION_FACTOR
	accel_mag *= pow(Config.ZOOM_DEFAULT / zoom_scale, Config.THRUST_ZOOM_EXPONENT)
	accel_mag *= Upgrades.value_at("engine_power", upgrade_tiers.engine_power)
	var forward: Vector2 = Vector2(0, -1).rotated(heading)
	var side: Vector2 = forward.rotated(PI / 2.0)
	return (forward * local_thrust.y + side * local_thrust.x) * accel_mag

func apply_turn(dt: float, turn_input: float, precision: bool) -> void:
	# turn_input: -1 (Q), 0, or +1 (E). No rotational inertia — DESIGN.md §4.1.
	var rate: float = Config.TURN_RATE
	if precision:
		rate *= Config.PRECISION_FACTOR
	heading += turn_input * rate * dt

func integrate(dt: float, accel: Vector2) -> void:
	# Semi-implicit Euler: velocity first, then position — DESIGN.md §4.3.
	velocity += accel * dt
	position += velocity * dt
