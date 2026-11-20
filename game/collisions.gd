extends RefCounted
class_name Collisions
# game/collisions.gd — ship impact with the star, planets and asteroids
# (DESIGN.md §4.5, §14.4). The move from the previous position is checked
# in hops no longer than the ship's radius so a fast ship can't skip
# through a body; the first contact wins.

static func check(prev_pos: Vector2, new_pos: Vector2, fatal_bodies: Array) -> bool:
	# Star/planet only — kept for callers that don't pass asteroids.
	var delta: Vector2 = new_pos - prev_pos
	var dist: float = delta.length()
	var hops: int = maxi(1, ceili(dist / Config.SHIP_RADIUS))
	for i in range(1, hops + 1):
		var p: Vector2 = prev_pos + delta * (float(i) / float(hops))
		for body in fatal_bodies:
			if body.body_radius <= 0.0:
				continue
			if p.distance_to(body.position) <= body.body_radius + Config.SHIP_RADIUS:
				return true
	return false

static func find_impact(prev_pos: Vector2, new_pos: Vector2, fatal_bodies: Array, asteroid_entries: Array, ship_radius: float) -> bool:
	# Like check(), but also tests every asteroid's actual outline —
	# DESIGN.md §4.5: "touching the star, a planet or an asteroid destroys
	# the ship." asteroid_entries: Array of {"view": Node2D, "graph": AsteroidGraph}.
	var delta: Vector2 = new_pos - prev_pos
	var dist: float = delta.length()
	var hops: int = maxi(1, ceili(dist / ship_radius))
	# Only rocks near this move (game/rock_grid.gd), when the grid is live.
	var rocks: Array = asteroid_entries
	if RockGrid.current != null:
		rocks = RockGrid.current.query_segment(prev_pos, new_pos, ship_radius)
	for i in range(1, hops + 1):
		var p: Vector2 = prev_pos + delta * (float(i) / float(hops))
		for body in fatal_bodies:
			if body.body_radius <= 0.0:
				continue
			if p.distance_to(body.position) <= body.body_radius + ship_radius:
				return true
		for entry in rocks:
			var graph: AsteroidGraph = entry.graph
			if p.distance_to(entry.view.position) > graph.bounding_radius + ship_radius:
				continue
			if graph.circle_touches(entry.view.position, p, ship_radius):
				return true
	return false
