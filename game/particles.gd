extends RefCounted
class_name Particles
# game/particles.gd — thrust puffs: purely visual exhaust, blown out
# opposite each thruster and scaled to its strength (DESIGN.md §16.3).
# Pure logic; drawing is render/thrust_puffs_view.gd. Ported from pygame's
# game/particles.py (thrust-puff half only — sparks/loose ore already
# exist as their own thing in main.gd/render/sparks_view.gd and
# render/loose_ore_view.gd).

const PUFF_DUE: float = 1.0  # one puff's already due, so even a quick tap shows one

static func emit(ship_position: Vector2, ship_velocity: Vector2, thrust_accel: Vector2, delta: float, carry: float, rng: RandomNumberGenerator) -> Dictionary:
	# One thruster's exhaust for this step. `carry` holds fractional puffs
	# left over from earlier steps. Returns {"puffs": Array, "carry": float}.
	if thrust_accel.length_squared() == 0.0:
		return {"puffs": [], "carry": PUFF_DUE}

	var intensity: float = thrust_accel.length() / Config.THRUST_ACCEL
	var rate: float = clamp(Config.THRUST_PUFF_RATE * intensity, Config.THRUST_PUFF_MIN_RATE, Config.THRUST_PUFF_MAX_RATE)
	carry += rate * delta
	var count: int = int(carry)
	carry -= count

	var exhaust: Vector2 = -thrust_accel.normalized()
	var spawn_pos: Vector2 = ship_position + exhaust * Config.THRUST_PUFF_OFFSET
	var puffs: Array = []
	for i in range(count):
		var spread: float = rng.randf_range(-Config.THRUST_PUFF_SPREAD, Config.THRUST_PUFF_SPREAD)
		var heading: Vector2 = exhaust.rotated(spread)
		var vel: Vector2 = ship_velocity + heading * (Config.THRUST_PUFF_SPEED * intensity)
		puffs.append({
			"position": spawn_pos, "velocity": vel,
			"lifetime": Config.THRUST_PUFF_LIFETIME,
			"base_radius": Config.THRUST_PUFF_RADIUS * intensity,
		})
	return {"puffs": puffs, "carry": carry}

static func step(puffs: Array, delta: float) -> Array:
	var remaining: Array = []
	for puff in puffs:
		puff.lifetime -= delta
		if puff.lifetime > 0.0:
			puff.position += puff.velocity * delta
			remaining.append(puff)
	return remaining

static func life_fraction(puff: Dictionary) -> float:
	# 1 when freshly spawned, falling to 0 as it expires.
	return max(0.0, puff.lifetime / Config.THRUST_PUFF_LIFETIME)

static func radius(puff: Dictionary) -> float:
	# Current size in world units; grows as it fades.
	return puff.base_radius * (1.0 + Config.THRUST_PUFF_GROWTH * (1.0 - life_fraction(puff)))
