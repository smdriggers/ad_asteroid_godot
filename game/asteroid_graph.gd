extends RefCounted
class_name AsteroidGraph
# game/asteroid_graph.gd — a connected graph of nodes on a hex packing
# (DESIGN.md §7). Axial coords (q, r); the center node is always (0, 0).
# Edges exist only between hex-adjacent nodes. No drawing here — see
# render/asteroid_view.gd.
#
# Materials/HP/edge-ownership are filled in by game/system_gen.gd during
# generation (DESIGN.md §7.4-7.9). Damage/mining (§7.10, §9) arrive with
# the mining milestone — nodes just carry a material+HP for now.

const HEX_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const CENTER: Vector2i = Vector2i(0, 0)

var nodes: Dictionary = {}           # Vector2i -> true
var edges: Dictionary = {}           # edge key (see edge_key) -> true
var exterior_edges: Dictionary = {}  # cached; recomputed only when edges/nodes actually change
var node_material: Dictionary = {}   # Vector2i -> material id (game/materials.gd)
var node_hp: Dictionary = {}         # Vector2i -> float HP
var edge_owner: Dictionary = {}      # edge key -> owner Vector2i (DESIGN.md §7.9)
var revealed: Dictionary = {}        # edge key -> true; the player's own scans (DESIGN.md §11)
var comp_revealed: Dictionary = {}   # edge key -> true; shared by all competitors (DESIGN.md §14.6)

# Nothing can reach further from the center than this. Set once at spawn
# (compute_bounding_radius(), called from system_gen.gd) — rocks only ever
# shrink, so it's never recomputed as nodes are removed — DESIGN.md §14.4.
var bounding_radius: float = 0.0

static func node_offset(node: Vector2i, node_radius: float) -> Vector2:
	# World offset from the asteroid's center — DESIGN.md §7.1.
	var q: float = node.x
	var r: float = node.y
	return Vector2(node_radius * 1.5 * q, node_radius * (sqrt(3) / 2.0 * q + sqrt(3) * r))

static func hex_offset(node: Vector2i) -> Vector2:
	# In node spacings (neighbors exactly 1 apart) — DESIGN.md §7.1. Used
	# for shape/vein/pocket math; node_offset() above is for final
	# world-space rendering positions.
	var q: float = node.x
	var r: float = node.y
	return Vector2(sqrt(3) / 2.0 * q, q / 2.0 + r)

static func edge_key(a: Vector2i, b: Vector2i) -> String:
	# Order-independent key for an edge between two adjacent nodes.
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]

static func edge_nodes(key: String) -> Array:
	var parts: PackedStringArray = key.split("|")
	var a: PackedStringArray = parts[0].split(",")
	var b: PackedStringArray = parts[1].split(",")
	return [Vector2i(int(a[0]), int(a[1])), Vector2i(int(b[0]), int(b[1]))]

static func flanks(a: Vector2i, b: Vector2i) -> Array:
	# The two cells next to both A and B, one on each side — DESIGN.md §7.2.
	var dir: Vector2i = b - a
	var i: int = HEX_DIRECTIONS.find(dir)
	var d1: Vector2i = HEX_DIRECTIONS[(i - 1 + 6) % 6]
	var d2: Vector2i = HEX_DIRECTIONS[(i + 1) % 6]
	return [a + d1, a + d2]

static func coord_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)

func add_node(node: Vector2i) -> void:
	nodes[node] = true

func build_edges() -> void:
	# All pairs of hex-adjacent nodes that both exist — DESIGN.md §7.2.
	edges.clear()
	for node in nodes.keys():
		for dir in HEX_DIRECTIONS:
			var nb: Vector2i = node + dir
			if nodes.has(nb):
				edges[edge_key(node, nb)] = true
	_recompute_exterior()

func is_thin(key: String) -> bool:
	# Both flanks empty: a single-edge bridge with open space on both
	# sides — DESIGN.md §7.2.
	var n: Array = edge_nodes(key)
	var fl: Array = flanks(n[0], n[1])
	return not nodes.has(fl[0]) and not nodes.has(fl[1])

func settle() -> Array:
	# Removes every thin edge and every node no longer connected to the
	# rock's main piece (see _anchor_piece), repeating until stable, since
	# crumbling can create new thin edges — DESIGN.md §7.3. Returns the
	# removed nodes.
	var removed: Array = []
	while true:
		var thin: Array = []
		for key in edges.keys():
			if is_thin(key):
				thin.append(key)
		for key in thin:
			edges.erase(key)

		var kept: Dictionary = _anchor_piece()
		var lost: Array = []
		for node in nodes.keys():
			if not kept.has(node):
				lost.append(node)

		if thin.is_empty() and lost.is_empty():
			break

		for node in lost:
			nodes.erase(node)
			removed.append(node)
		var dead_edges: Array = []
		for key in edges.keys():
			var n: Array = edge_nodes(key)
			if not nodes.has(n[0]) or not nodes.has(n[1]):
				dead_edges.append(key)
		for key in dead_edges:
			edges.erase(key)

	_recompute_exterior()
	return removed

func compute_depths() -> Dictionary:
	# BFS hop-distance from the center — DESIGN.md §7.6. Used for mineral
	# fills and edge ownership.
	var depths: Dictionary = {}
	if not nodes.has(CENTER):
		return depths
	depths[CENTER] = 0
	var queue: Array = [CENTER]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in HEX_DIRECTIONS:
			var nb: Vector2i = current + dir
			if nodes.has(nb) and edges.has(edge_key(current, nb)) and not depths.has(nb):
				depths[nb] = depths[current] + 1
				queue.append(nb)
	return depths

func assign_edge_ownership() -> void:
	# DESIGN.md §7.9. Edges processed by (shallower end's depth, coord,
	# then deeper end's); owner picked by depth, then fewest edges owned
	# so far, then higher material value, then lower coord. The center
	# is then given one spoke if rules 1-4 left it with none.
	var depths: Dictionary = compute_depths()
	var keys: Array = edges.keys()
	keys.sort_custom(func(k1, k2): return _edge_order_less(k1, k2, depths))

	edge_owner.clear()
	var owned_count: Dictionary = {}
	for key in keys:
		var n: Array = edge_nodes(key)
		var a: Vector2i = n[0]
		var b: Vector2i = n[1]
		var owner: Vector2i
		if depths.get(a, 0) != depths.get(b, 0):
			owner = a if depths.get(a, 0) > depths.get(b, 0) else b
		elif owned_count.get(a, 0) != owned_count.get(b, 0):
			owner = a if owned_count.get(a, 0) < owned_count.get(b, 0) else b
		elif _value(a) != _value(b):
			owner = a if _value(a) > _value(b) else b
		else:
			owner = a
		edge_owner[key] = owner
		owned_count[owner] = owned_count.get(owner, 0) + 1

	_give_center_an_edge(owned_count)

func _give_center_an_edge(owned_count: Dictionary) -> void:
	if owned_count.get(CENTER, 0) > 0 or not nodes.has(CENTER):
		return
	var best_neighbor = null
	var best_key: String = ""
	var best_count: int = -1
	for dir in HEX_DIRECTIONS:
		var nb: Vector2i = CENTER + dir
		var key: String = edge_key(CENTER, nb)
		if not edges.has(key):
			continue
		var count: int = owned_count.get(nb, 0)
		if count < 2:
			continue
		if best_neighbor == null or count > best_count or (count == best_count and coord_less(nb, best_neighbor)):
			best_neighbor = nb
			best_key = key
			best_count = count
	if best_neighbor != null:
		edge_owner[best_key] = CENTER
		owned_count[best_neighbor] -= 1
		owned_count[CENTER] = owned_count.get(CENTER, 0) + 1

func _value(node: Vector2i) -> int:
	return Materials.value(node_material.get(node, Materials.IRON))

func _edge_sort_key(key: String, depths: Dictionary) -> Array:
	var n: Array = edge_nodes(key)
	var a: Vector2i = n[0]
	var b: Vector2i = n[1]
	var da: int = depths.get(a, 0)
	var db: int = depths.get(b, 0)
	if da > db or (da == db and not coord_less(a, b)):
		var tmp: Vector2i = a
		a = b
		b = tmp
		var tmpd: int = da
		da = db
		db = tmpd
	return [da, a.x, a.y, db, b.x, b.y]

func _edge_order_less(k1: String, k2: String, depths: Dictionary) -> bool:
	var key1: Array = _edge_sort_key(k1, depths)
	var key2: Array = _edge_sort_key(k2, depths)
	for i in range(key1.size()):
		if key1[i] != key2[i]:
			return key1[i] < key2[i]
	return false

func _has_any_edge(node: Vector2i) -> bool:
	for dir in HEX_DIRECTIONS:
		if edges.has(edge_key(node, node + dir)):
			return true
	return false

func _anchor_piece() -> Dictionary:
	# The nodes that stay put; everything else crumbles. With
	# Config.ASTEROID_CORE_COLLAPSE on (the original rule) that's whatever
	# is still joined to the center node, so mining out the core destroys
	# the whole rock. Off (the default), it's the largest joined piece
	# (the center's piece wins a tie), so a rock survives losing its core
	# and only fragments smaller than the main body break away.
	if Config.ASTEROID_CORE_COLLAPSE:
		if nodes.has(CENTER) and _has_any_edge(CENTER):
			return _reachable(CENTER)
		return {}
	var best: Dictionary = {}
	var seen: Dictionary = {}
	for node in nodes.keys():
		if seen.has(node) or not _has_any_edge(node):
			continue  # nodes with no edges left can't be drawn or hit: they crumble
		var piece: Dictionary = _reachable(node)
		for n in piece.keys():
			seen[n] = true
		if piece.size() > best.size() or (piece.size() == best.size() and piece.has(CENTER)):
			best = piece
	return best

func _reachable(start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in HEX_DIRECTIONS:
			var nb: Vector2i = current + dir
			if nodes.has(nb) and edges.has(edge_key(current, nb)) and not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
	return seen

func compute_bounding_radius() -> void:
	# Called once, right after generation finishes (system_gen.gd's
	# _finish_rock) — DESIGN.md §14.4.
	var farthest: float = 0.0
	for node in nodes.keys():
		var off: Vector2 = node_offset(node, Config.HEX_NODE_RADIUS)
		farthest = max(farthest, off.length())
	bounding_radius = Config.HEX_NODE_RADIUS + farthest

func nodes_within(origin: Vector2, center: Vector2, radius: float) -> Array:
	# DESIGN.md §9.3: every node within `radius` of world point `center`,
	# for a bomb's blast. `origin` is this asteroid's own position.
	var found: Array = []
	for node in nodes.keys():
		var pos: Vector2 = origin + node_offset(node, Config.HEX_NODE_RADIUS)
		if pos.distance_to(center) <= radius:
			found.append(node)
	return found

func circle_touches(origin: Vector2, center: Vector2, radius: float) -> bool:
	# Whether a circle at world `center` touches the rock: its center is
	# within HEX_NODE_RADIUS of an existing node (covers being anywhere
	# inside the outline), or it overlaps an exterior edge — DESIGN.md §14.4.
	# Brute-force over nodes/edges rather than pygame's nearest-hex-cell
	# lookup; asteroids here are small enough (tens of nodes) that this
	# costs nothing noticeable.
	var local: Vector2 = center - origin
	var reach_sq: float = Config.HEX_NODE_RADIUS * Config.HEX_NODE_RADIUS
	for node in nodes.keys():
		var off: Vector2 = node_offset(node, Config.HEX_NODE_RADIUS)
		if off.distance_squared_to(local) <= reach_sq:
			return true
	var radius_sq: float = radius * radius
	for key in exterior_edges.keys():
		var n: Array = edge_nodes(key)
		var a: Vector2 = node_offset(n[0], Config.HEX_NODE_RADIUS)
		var b: Vector2 = node_offset(n[1], Config.HEX_NODE_RADIUS)
		if _point_segment_distance_sq(local, a, b) <= radius_sq:
			return true
	return false

static func _point_segment_distance_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_squared_to(a)
	var t: float = clamp((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_squared_to(a + ab * t)

func _recompute_exterior() -> void:
	# An edge is exterior if at least one of its two flank cells is
	# empty — DESIGN.md §7.2.
	exterior_edges.clear()
	for key in edges.keys():
		var n: Array = edge_nodes(key)
		var fl: Array = flanks(n[0], n[1])
		if not nodes.has(fl[0]) or not nodes.has(fl[1]):
			exterior_edges[key] = true
	_forget_stale_edges()

func _forget_stale_edges() -> void:
	# Mining can remove an edge entirely (build_edges()/settle() both end
	# up here). Without this, a scanned-then-mined edge's reveal/ownership
	# bookkeeping lingers forever and render/asteroid_view.gd keeps drawing
	# it as a ghost line — mirrors pygame's AsteroidGraph._forget_edges().
	for key in revealed.keys():
		if not edges.has(key):
			revealed.erase(key)
	for key in comp_revealed.keys():
		if not edges.has(key):
			comp_revealed.erase(key)
	for key in edge_owner.keys():
		if not edges.has(key):
			edge_owner.erase(key)
