extends RefCounted
class_name Scanner
# game/scanner.gd — the scan ray/cone (DESIGN.md §11.1-11.2). Sits behind
# the same weapon-style interface as the lasers/bombs and does no damage.
# scan_range/scan_depth/scan_width are the ship's tiered upgrades
# (game/upgrades.gd); at scan_width tier 0 (0 degrees) this is a single
# ray, same as before the shop existed.

func scan(ship_position: Vector2, heading: float, ship: Ship, asteroid_entries: Array) -> Dictionary:
	# Mutates every hit asteroid's graph.revealed in place. Returns
	# {"hit": bool, "left_end": Vector2, "right_end": Vector2} — the
	# cone's two edges to draw (DESIGN.md §11.2); both are the same point
	# when scan_width is 0.
	var tiers: Dictionary = ship.upgrade_tiers
	var scan_range: float = Upgrades.value_at("scan_range", tiers.scan_range)
	var scan_depth: int = Upgrades.value_at("scan_depth", tiers.scan_depth)
	var width_deg: float = Upgrades.value_at("scan_width", tiers.scan_width)
	return _scan_impl(ship_position, heading, scan_range, scan_depth, width_deg, asteroid_entries, false)

func scan_for_competitor(pos: Vector2, heading: float, scan_depth: int, asteroid_entries: Array) -> Dictionary:
	# DESIGN.md §14.6: competitors scan with the player's starting
	# (tier-0) range and width, but their own archetype-specific depth,
	# revealing onto the shared comp_revealed map instead of the
	# player's own.
	var scan_range: float = Upgrades.value_at("scan_range", 0)
	var width_deg: float = Upgrades.value_at("scan_width", 0)
	return _scan_impl(pos, heading, scan_range, scan_depth, width_deg, asteroid_entries, true)

func _scan_impl(ship_position: Vector2, heading: float, scan_range: float, scan_depth: int, width_deg: float, asteroid_entries: Array, for_competitors: bool) -> Dictionary:
	var half_angle: float = deg_to_rad(width_deg) / 2.0

	var ray_count: int = 1
	if half_angle > 0.0:
		# DESIGN.md §11.2: rays no more than SCAN_RAY_SPACING node
		# spacings apart at the far side (scan_range, worst case).
		var node_spacing: float = Config.HEX_NODE_RADIUS * sqrt(3.0)
		var angular_step: float = (Config.SCAN_RAY_SPACING * node_spacing) / scan_range
		ray_count = max(2, int(ceil((2.0 * half_angle) / angular_step)) + 1)
		# A wide, long cone wants hundreds of rays; cap it so a maxed scanner
		# can't eat the frame (rays then sit a little wider apart far out).
		ray_count = min(ray_count, Config.SCAN_MAX_RAYS)

	var any_hit: bool = false
	var left_end: Vector2 = ship_position
	var right_end: Vector2 = ship_position
	for i in range(ray_count):
		var t: float = 0.5 if ray_count == 1 else float(i) / float(ray_count - 1)
		var angle: float = heading - half_angle + t * 2.0 * half_angle
		var dir: Vector2 = Vector2(0, -1).rotated(angle)
		var hit_end = _cast_ray(ship_position, dir, scan_range, scan_depth, asteroid_entries, for_competitors)
		var end_point: Vector2 = hit_end if hit_end != null else ship_position + dir * scan_range
		if hit_end != null:
			any_hit = true
		if i == 0:
			left_end = end_point
		if i == ray_count - 1:
			right_end = end_point

	return {"hit": any_hit, "left_end": left_end, "right_end": right_end}

func _cast_ray(p0: Vector2, dir: Vector2, scan_range: float, scan_depth: int, asteroid_entries: Array, for_competitors: bool):
	# One single-ray scan (DESIGN.md §11.2's scan_width=0 rule): reveals
	# the first scan_depth edges crossed on the first asteroid whose
	# outline the ray crosses, in order along the ray. Returns the point
	# the beam should be drawn to, or null if nothing was hit.
	var p1: Vector2 = p0 + dir * scan_range

	var best_entry: Dictionary = {}
	var best_t: float = INF
	var ray: Vector2 = p1 - p0
	var ray_len_sq: float = ray.length_squared()
	# Only rocks near the ray's line (game/rock_grid.gd), when the grid is live.
	var candidates: Array = asteroid_entries
	if RockGrid.current != null:
		candidates = RockGrid.current.query_segment(p0, p1)
	for entry in candidates:
		var graph: AsteroidGraph = entry.graph
		var origin: Vector2 = entry.view.position
		# Cheap cull: skip rocks the ray can't come within reach of.
		var along: float = clampf((origin - p0).dot(ray) / ray_len_sq, 0.0, 1.0) if ray_len_sq > 0.0 else 0.0
		if (p0 + ray * along).distance_squared_to(origin) > graph.bounding_radius * graph.bounding_radius:
			continue
		for i in range(graph.exterior_a.size()):
			var a: Vector2 = origin + graph.exterior_a[i]
			var b: Vector2 = origin + graph.exterior_b[i]
			var t: float = _ray_segment_t(p0, p1, a, b)
			if t >= 0.0 and t < best_t:
				best_t = t
				best_entry = entry

	if best_entry.is_empty():
		return null

	var graph: AsteroidGraph = best_entry.graph
	var origin: Vector2 = best_entry.view.position
	var hits: Array = []
	for key in graph.edges.keys():
		var n: Array = AsteroidGraph.edge_nodes(key)
		var a: Vector2 = origin + AsteroidGraph.node_offset(n[0], Config.HEX_NODE_RADIUS)
		var b: Vector2 = origin + AsteroidGraph.node_offset(n[1], Config.HEX_NODE_RADIUS)
		var t: float = _ray_segment_t(p0, p1, a, b)
		if t >= 0.0:
			hits.append({"key": key, "t": t})
	hits.sort_custom(func(h1, h2): return h1.t < h2.t)

	var end_t: float = best_t
	for i in range(min(scan_depth, hits.size())):
		if for_competitors:
			graph.comp_revealed[hits[i].key] = true
		elif not graph.revealed.has(hits[i].key):
			graph.revealed[hits[i].key] = true
			graph.version += 1  # newly revealed edge: the view must redraw
		end_t = max(end_t, hits[i].t)

	return p0 + dir * scan_range * end_t

static func _ray_segment_t(p0: Vector2, p1: Vector2, a: Vector2, b: Vector2) -> float:
	# Parametric position (0..1 along p0->p1) where the ray crosses
	# segment a-b, or -1.0 if they don't cross within range.
	var d1: Vector2 = p1 - p0
	var d2: Vector2 = b - a
	var denom: float = d1.cross(d2)
	if abs(denom) < 0.0001:
		return -1.0
	var diff: Vector2 = a - p0
	var t: float = diff.cross(d2) / denom
	var u: float = diff.cross(d1) / denom
	if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
		return -1.0
	return t
