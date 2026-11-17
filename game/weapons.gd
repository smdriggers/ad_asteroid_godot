extends RefCounted
class_name BoltLaser
# game/weapons.gd — the starting weapon: a volley of straight-line laser
# bolts fired along the ship's heading, not aimed at a cursor (DESIGN.md
# §9.1). Bombs (§9.3) and the scanner (§11) share this same
# update(dt, firing, ...) shape but arrive with their own milestones
# (ammo/upgrades, scanning) — mode is always "mine" for now.

var cooldown: float = 0.0  # seconds until the next volley may fire; keeps running while released

func update(dt: float, firing: bool, ship: Ship) -> Array:
	cooldown = max(0.0, cooldown - dt)
	if not firing or cooldown > 0.0:
		return []
	var fire_rate: float = Upgrades.value_at("fire_rate", ship.upgrade_tiers.fire_rate)
	cooldown += 1.0 / fire_rate
	return _volley(ship)

func _volley(ship: Ship) -> Array:
	var forward: Vector2 = Vector2(0, -1).rotated(ship.heading)
	var side: Vector2 = forward.rotated(PI / 2.0)
	var count: int = Upgrades.value_at("laser_count", ship.upgrade_tiers.laser_count)
	var life: float = Upgrades.value_at("range", ship.upgrade_tiers.range)
	var mid: float = float(count - 1) / 2.0
	var bolts: Array = []
	for i in range(count):
		var offset: float = (float(i) - mid) * Config.LASER_SPACING
		bolts.append({
			"position": ship.position + side * offset,
			"velocity": forward * Config.BOLT_SPEED + ship.velocity,
			"damage": Config.BOLT_DAMAGE,
			"life": life,
		})
	return bolts
