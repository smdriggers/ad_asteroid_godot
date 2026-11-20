extends RefCounted
class_name RockGrid
# game/rock_grid.gd — broad phase for "which rocks could this touch?".
# Every physics tick main.gd sorts the system's rocks into square cells by
# their current position (cheap: one pass). Bolts, scan rays and ship
# collisions then only test the rocks in the cells they pass through,
# instead of every rock in the system (hundreds on later levels).
#
# Each rock is filed under the cell holding its centre, so queries widen
# their area by the biggest rock's radius to catch rocks that poke over a
# cell edge.

const CELL: float = 200.0   # world px per cell; a bit above the biggest rock's diameter

# The grid for the system currently in play, set by main.gd. Hot paths
# (projectiles, collisions, scanner) use it when present and fall back to
# checking every rock when not.
static var current: RockGrid = null

var cells: Dictionary = {}   # Vector2i -> Array of rock entries {"view","graph"}
var max_radius: float = 0.0  # biggest bounding radius of any rock

func rebuild(entries: Array) -> void:
	cells.clear()
	for e in entries:
		var graph: AsteroidGraph = e.graph
		if graph.nodes.is_empty():
			continue
		max_radius = maxf(max_radius, graph.bounding_radius)
		var key := _cell_of(e.view.position)
		if cells.has(key):
			cells[key].append(e)
		else:
			cells[key] = [e]

func query_rect(area: Rect2) -> Array:
	# Every rock that could overlap `area`.
	var grown: Rect2 = area.grow(max_radius)
	var lo := _cell_of(grown.position)
	var hi := _cell_of(grown.end)
	var found: Array = []
	for cy in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var key := Vector2i(cx, cy)
			if cells.has(key):
				found.append_array(cells[key])
	return found

func query_segment(p0: Vector2, p1: Vector2, pad: float = 0.0) -> Array:
	# Every rock that could come within `pad` of the segment p0-p1. For
	# short segments (a bolt's move, a ship's move) the bounding box is tight.
	if p0.distance_squared_to(p1) <= CELL * CELL:
		return query_rect(Rect2(p0, Vector2.ZERO).expand(p1).grow(pad))
	# Long segments (scan rays): walk along in half-cell steps so we only
	# touch cells near the line, not its whole bounding box.
	var seen: Dictionary = {}
	var found: Array = []
	var reach: int = ceili((max_radius + pad) / CELL)
	var steps: int = ceili(p0.distance_to(p1) / (CELL * 0.5))
	for s in range(steps + 1):
		var c := _cell_of(p0.lerp(p1, float(s) / float(steps)))
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var key := Vector2i(c.x + dx, c.y + dy)
				if seen.has(key):
					continue
				seen[key] = true
				if cells.has(key):
					found.append_array(cells[key])
	return found

static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))
