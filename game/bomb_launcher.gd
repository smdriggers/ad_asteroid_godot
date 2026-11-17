extends RefCounted
class_name BombLauncher
# game/bomb_launcher.gd — the bomb weapon: fires from a finite stock of
# bombs (ship.bombs), bought one at a time at the station (DESIGN.md
# §13.2). A bomb travels forward like a bolt, but slower, and detonates
# in a radius on hitting an asteroid or on fuse timeout (§9.3). Fires
# alongside the laser in mine mode, at its own rate.
#
# Like game/weapons.gd's BoltLaser, fires at most once per call even if
# the cooldown has run well past zero — this port's established
# simplification of pygame's catch-up "while cooldown <= 0" loop.

var cooldown: float = 0.0  # seconds until the next bomb may fire; keeps running while released

func update(dt: float, firing: bool, ship: Ship) -> Array:
	cooldown = max(0.0, cooldown - dt)
	if ship.bombs <= 0 or not firing or cooldown > 0.0:
		return []
	var rate: float = Upgrades.value_at("bomb_rate", ship.upgrade_tiers.bomb_rate)
	cooldown += rate
	ship.bombs -= 1
	var forward: Vector2 = Vector2(0, -1).rotated(ship.heading)
	return [{
		"position": ship.position,
		"velocity": forward * Config.BOMB_SPEED + ship.velocity,
		"radius": Upgrades.value_at("bomb_radius", ship.upgrade_tiers.bomb_radius),
		"damage": Upgrades.value_at("bomb_damage", ship.upgrade_tiers.bomb_damage),
		"life": Config.BOMB_FUSE_TIME,  # fuse: detonates on hit, or when this runs out
	}]
