extends RefCounted
class_name Gravity
# game/gravity.gd — gravity on ships only (DESIGN.md §3.3). Pure, stateless
# functions so the trajectory preview and competitors can reuse them later
# without duplicating the math.

static func acceleration(ship_pos: Vector2, bodies: Array) -> Vector2:
	var accel: Vector2 = Vector2.ZERO
	for body in bodies:
		if body.mass <= 0.0:
			continue
		var to_body: Vector2 = body.position - ship_pos
		var d: float = to_body.length()
		if d > body.gravity_radius:
			continue
		var strength: float = Config.G * body.mass / (d * d + Config.SOFTENING * Config.SOFTENING)
		if d > 0.0:
			accel += (to_body / d) * strength
	return accel

static func circular_speed(mass: float, r: float) -> float:
	# DESIGN.md §3.3: the speed for a circular orbit under the same
	# softened pull ship gravity uses. Used for the launch orbit (§12.2).
	var denom: float = r * r + Config.SOFTENING * Config.SOFTENING
	return sqrt(Config.G * mass * r / denom)
