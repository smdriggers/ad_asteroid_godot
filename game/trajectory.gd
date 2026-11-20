extends RefCounted
class_name Trajectory
# game/trajectory.gd — the dotted coast-ahead path (DESIGN.md §5). Always
# on. Simulates a copy of the ship forward, coasting (no thrust), using
# the exact same gravity, integrator and impact check as real flight, so
# the line never lies.
#
# Drawn relative to the ship's own circular orbit around the star at its
# current distance, so it shows drift relative to co-orbiting things
# rather than the whole system's sweep. On a predicted crash, the path is
# bent (linearly, point by point) so it ends exactly on the real current
# position of the body it hits, not a mathematically "correct" future
# one — DESIGN.md §5: "The X sits on the body being hit, at that body's
# position right now."

class BodySnapshot:
	var position: Vector2
	var mass: float
	var gravity_radius: float
	var body_radius: float

class Result:
	var points: Array[Vector2] = []   # world-space; points[0] == ship's current position
	var crash_point = null             # Vector2 or null
	var crash_body = null              # the OrbitBody actually hit (the real node, for its current position), or null

# `bodies`: the same OrbitBody list real flight uses for both gravity and
# impact (currently [star, planet]; asteroids join later).
static func simulate(ship_pos: Vector2, ship_vel: Vector2, world_time: float, bodies: Array) -> Result:
	var result := Result.new()
	var pos: Vector2 = ship_pos
	var vel: Vector2 = ship_vel
	var dt: float = Config.SIM_DT

	var r0: float = pos.length()
	var theta0: float = pos.angle()
	var ang_speed: float = 0.0
	if r0 > 0.0:
		var star_mass: float = 0.0
		for body in bodies:
			if body.parent_body == null:
				star_mass = body.mass
				break
		ang_speed = sqrt(Config.G * star_mass / pow(r0, 3))

	result.points.append(pos)

	var crash_step: int = -1
	var crash_body: OrbitBody = null

	# One snapshot per body, reused every step (only position changes);
	# making fresh ones each step cost hundreds of allocations per frame.
	var snapshots: Array = []
	for body in bodies:
		var snap := BodySnapshot.new()
		snap.mass = body.mass
		snap.gravity_radius = body.gravity_radius
		snap.body_radius = body.body_radius
		snapshots.append(snap)

	for step in range(1, Config.TRAJECTORY_STEPS + 1):
		var t: float = world_time + step * dt
		var tau: float = step * dt

		for bi in range(bodies.size()):
			snapshots[bi].position = bodies[bi].position_at(t)

		var accel: Vector2 = Gravity.acceleration(pos, snapshots)
		var prev_pos: Vector2 = pos
		vel += accel * dt
		pos += vel * dt

		var theta_ref: float = theta0 + ang_speed * tau
		var natural: Vector2 = r0 * Vector2(cos(theta_ref), sin(theta_ref))
		var drawn: Vector2 = pos - natural + ship_pos
		result.points.append(drawn)

		if Collisions.check(prev_pos, pos, snapshots):
			crash_step = result.points.size() - 1
			for i in range(bodies.size()):
				var snap: BodySnapshot = snapshots[i]
				if snap.body_radius > 0.0 and pos.distance_to(snap.position) <= snap.body_radius + Config.SHIP_RADIUS:
					crash_body = bodies[i]
					break
			break

	if crash_step >= 0 and crash_body != null:
		result.points.resize(crash_step + 1)
		var body_now_pos: Vector2 = crash_body.position
		var raw_crash_point: Vector2 = result.points[crash_step]
		var correction: Vector2 = body_now_pos - raw_crash_point
		var last: int = result.points.size() - 1
		for i in range(result.points.size()):
			var frac: float = 1.0
			if last > 0:
				frac = float(i) / float(last)
			result.points[i] += correction * frac
		result.crash_point = result.points[last]
		result.crash_body = crash_body

	return result
