extends RefCounted
class_name SystemGen
# game/system_gen.gd — builds a level's asteroids from a seed (DESIGN.md
# §7.4-7.9, §7.6-7.8, §3.4-3.5). Bodies (star/planets/stations) are built
# in main.gd, straight from Config.LEVELS[level] — this file only builds
# the belts' asteroids for that level.

const PROFILES: Array[String] = [
	"iron_slug", "mixed_common", "copper_vein", "rich_core", "pocket_rock",
	"deep_vein", "hollow", "layered_gem", "vein_gem", "jackpot",
]

class RockResult:
	var graph: AsteroidGraph
	var orbit_radius: float
	var phase: float
	var size_class: String
	var profile: String

static func generate_system(level: int, rng: RandomNumberGenerator) -> Array:
	var belts: Array = Config.LEVELS[level].belts

	# One belt-dict entry per rock it holds, in order — DESIGN.md §3.5.
	var homes: Array = []
	for belt in belts:
		for i in range(belt.count):
			homes.append(belt)
	# Nuggets all go in the belt with the largest inner radius (the
	# system's outermost, together with the other small valuable rocks).
	var nugget_belt: Dictionary = belts[0]
	for belt in belts:
		if belt.inner > nugget_belt.inner:
			nugget_belt = belt
	var nugget_recipe: Dictionary = Config.BELT_KINDS[nugget_belt.kind]

	var rocks_raw: Array = []
	var total_nodes: int = 0

	# Steps 2-3 (§7.4): roll size/profile, carve, settle — before the
	# ore budget can be sized, which needs the total node count (step 4).
	for belt in homes:
		var recipe: Dictionary = Config.BELT_KINDS[belt.kind]
		var size_class: String = _weighted_pick(recipe.sizes, rng)
		var profile_weights: Dictionary = recipe.get("profiles", Config.ASTEROID_PROFILE_WEIGHTS)
		var profile: String = _weighted_pick(profile_weights, rng)
		var graph := AsteroidGraph.new()
		_carve_shape(graph, size_class, rng)
		graph.settle()
		rocks_raw.append({"size_class": size_class, "profile": profile, "graph": graph, "belt": belt})
		total_nodes += graph.nodes.size()

	# Nuggets (§7.7): fixed count, filled first so their rare materials
	# are always paid for (§7.4 step 5). Size rolled from the nugget
	# belt's own kind, same as every other rock there.
	var nuggets: Array = []
	for i in range(Config.NUGGET_COUNT):
		var size_class: String = _weighted_pick(nugget_recipe.sizes, rng)
		var graph := AsteroidGraph.new()
		_carve_shape(graph, size_class, rng)
		graph.settle()
		nuggets.append({"size_class": size_class, "graph": graph})
		total_nodes += graph.nodes.size()

	var budget: Dictionary = {}  # material id -> remaining node count; iron (unlisted) is unlimited
	for mat_id in Config.ORE_BUDGET.keys():
		budget[mat_id] = int(Config.ORE_BUDGET[mat_id] * total_nodes)

	# Fill and finish every rock first; placement needs final sizes.
	var to_place: Array = []  # {"graph","size_class","profile","belt"}; nuggets first so they always get a spot
	for entry in nuggets:
		var mat_id: int = _pick_nugget_material(budget, rng)
		var graph: AsteroidGraph = entry["graph"]
		for node in graph.nodes.keys():
			graph.node_material[node] = mat_id
		_charge_budget(graph, budget)
		_finish_rock(graph)
		to_place.append({"graph": graph, "size_class": entry["size_class"], "profile": "nugget", "belt": nugget_belt})

	var others: Array = []
	for entry in rocks_raw:
		var graph: AsteroidGraph = entry["graph"]
		_fill_profile(graph, entry["profile"], rng)
		_charge_budget(graph, budget)
		_finish_rock(graph)
		others.append({"graph": graph, "size_class": entry["size_class"], "profile": entry["profile"], "belt": entry["belt"]})
	# Biggest first packs the lanes better; small rocks fill the gaps after.
	others.sort_custom(func(a, b): return a.graph.bounding_radius > b.graph.bounding_radius)
	to_place.append_array(others)

	return _place_all(to_place, belts, rng)

# --- Placement: spaced orbital lanes ---
#
# Rocks orbit the star at speeds set by their distance, so two rocks at
# different distances drift past each other and will meet eventually
# unless their orbits are farther apart than their combined size. Rocks
# at exactly the same distance move in lockstep and keep their spacing
# forever. So every belt is built from lanes (shared orbit radii): a rock
# either joins a lane, spaced along it from its neighbours, or starts a
# new lane far enough from every other lane's rocks that they can never
# touch. A rock with no room anywhere in its belt is left out.

static func _place_all(to_place: Array, belts: Array, rng: RandomNumberGenerator) -> Array:
	var gap: float = Config.ASTEROID_SPACING
	var lanes_by_belt: Dictionary = {}   # belt index -> Array of {"r","max_b","rocks": Array of {"phase","b"}}
	var asked: Dictionary = {}           # belt index -> rocks wanted
	var got: Dictionary = {}             # belt index -> rocks placed
	var results: Array = []

	for item in to_place:
		var bi: int = 0
		for k in range(belts.size()):
			if is_same(belts[k], item.belt):
				bi = k
				break
		asked[bi] = asked.get(bi, 0) + 1
		if not lanes_by_belt.has(bi):
			lanes_by_belt[bi] = []
		var lanes: Array = lanes_by_belt[bi]
		var b: float = item.graph.bounding_radius
		var spot = _find_spot(lanes, item.belt, b, gap, rng)
		if spot == null:
			continue
		if spot.lane < 0:
			lanes.append({"r": spot.r, "max_b": b, "rocks": [{"phase": spot.phase, "b": b}]})
		else:
			var lane: Dictionary = lanes[spot.lane]
			lane.rocks.append({"phase": spot.phase, "b": b})
			lane.max_b = maxf(lane.max_b, b)
		got[bi] = got.get(bi, 0) + 1

		var result := RockResult.new()
		result.graph = item.graph
		result.size_class = item.size_class
		result.profile = item.profile
		result.orbit_radius = spot.r
		result.phase = spot.phase
		results.append(result)

	for bi in asked.keys():
		var belt: Dictionary = belts[bi]
		if got.get(bi, 0) < asked[bi]:
			print("Belt %d-%d (%s): room for %d of %d rocks without overlaps" % [belt.inner, belt.outer, belt.kind, got.get(bi, 0), asked[bi]])
	return results

static func _find_spot(lanes: Array, belt: Dictionary, b: float, gap: float, rng: RandomNumberGenerator):
	# {"r","phase","lane"} (lane = index into lanes, -1 = start a new one), or null if none fits.
	# 1) Join an existing lane: try just past each rock already on it.
	var order: Array = range(lanes.size())
	for i in range(order.size() - 1, 0, -1):  # shuffle with the seeded rng so a pinned SYSTEM_SEED stays reproducible
		var j: int = rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for li in order:
		var lane: Dictionary = lanes[li]
		for rock in lane.rocks:
			var step: float = _arc_angle(lane.r, rock.b + b + gap)
			if step < 0.0:
				continue
			var phase: float = wrapf(rock.phase + step, 0.0, TAU)
			if _fits(lanes, lane.r, phase, b, gap, li):
				return {"r": lane.r, "phase": phase, "lane": li}

	# 2) Start a new lane: as tight against an existing lane as allowed,
	# or at the belt's edges, or anywhere at random; pick among the valid.
	var radii: Array = [belt.inner, belt.outer]
	for lane in lanes:
		radii.append(lane.r - (lane.max_b + b + gap))
		radii.append(lane.r + (lane.max_b + b + gap))
	for i in range(Config.ASTEROID_PLACEMENT_TRIES):
		radii.append(rng.randf_range(belt.inner, belt.outer))
	var valid: Array = []
	for r in radii:
		if r < belt.inner or r > belt.outer:
			continue
		if _fits(lanes, r, 0.0, b, gap, -1):
			valid.append(r)
	if valid.is_empty():
		return null
	return {"r": valid[rng.randi() % valid.size()], "phase": rng.randf_range(0.0, TAU), "lane": -1}

static func _fits(lanes: Array, r: float, phase: float, b: float, gap: float, own_lane: int) -> bool:
	# Whether a rock of bounding radius b at (r, phase) can never touch any
	# placed rock. own_lane: index of the lane it would join (same orbit), or -1.
	for li in range(lanes.size()):
		var lane: Dictionary = lanes[li]
		if li == own_lane:
			for rock in lane.rocks:
				var need: float = rock.b + b + gap
				var d: float = absf(wrapf(phase - rock.phase, -PI, PI))
				if 2.0 * r * sin(d / 2.0) < need:  # chord between the two centres
					return false
		else:
			if absf(r - lane.r) >= lane.max_b + b + gap:
				continue  # the whole lane is clear
			for rock in lane.rocks:
				if absf(r - lane.r) < rock.b + b + gap:
					return false  # different orbits this close meet eventually
	return true

static func _arc_angle(r: float, chord: float) -> float:
	# Angle along an orbit of radius r that spans `chord`; -1 if it can't.
	if r <= 0.0 or chord >= 2.0 * r:
		return -1.0
	return 2.0 * asin(chord / (2.0 * r))

static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator):
	var total: float = 0.0
	for w in weights.values():
		total += w
	var r: float = rng.randf() * total
	var acc: float = 0.0
	for key in weights.keys():
		acc += weights[key]
		if r <= acc:
			return key
	return weights.keys()[weights.size() - 1]

# --- Shape (DESIGN.md §7.5) ---

static func _carve_shape(graph: AsteroidGraph, size_class: String, rng: RandomNumberGenerator) -> void:
	var radius: float = Config.ASTEROID_RINGS[size_class]
	var noise: float = Config.ASTEROID_SHAPE_NOISE[size_class]
	var base: float = max(1.0, radius - noise)
	var buckets: int = Config.ASTEROID_NOISE_BUCKETS
	var bulge_values: Array = []
	for i in range(buckets):
		bulge_values.append(rng.randf_range(-1.0, 1.0))

	var bulge_at = func(theta: float) -> float:
		var t: float = (theta / TAU) * buckets
		var i0: int = int(floor(t)) % buckets
		var i1: int = (i0 + 1) % buckets
		var frac: float = t - floor(t)
		var ease: float = (1.0 - cos(frac * PI)) / 2.0
		return lerp(bulge_values[i0], bulge_values[i1], ease)

	graph.add_node(AsteroidGraph.CENTER)
	var span: int = int(ceil(radius)) + 2
	for q in range(-span, span + 1):
		for r in range(-span, span + 1):
			var node := Vector2i(q, r)
			if node == AsteroidGraph.CENTER:
				continue
			var offset: Vector2 = AsteroidGraph.hex_offset(node)
			var d: float = offset.length()
			var theta: float = offset.angle()
			if theta < 0.0:
				theta += TAU
			if d / base < 1.0 + (noise / base) * bulge_at.call(theta):
				graph.add_node(node)
	graph.build_edges()

static func _rock_size(graph: AsteroidGraph) -> float:
	# Width across, in node spacings (DESIGN.md §7.6) — approximated as
	# twice the farthest node's distance from center.
	var max_d: float = 1.0
	for node in graph.nodes.keys():
		max_d = max(max_d, AsteroidGraph.hex_offset(node).length())
	return max_d * 2.0

static func _depths_and_max(graph: AsteroidGraph) -> Dictionary:
	var depths: Dictionary = graph.compute_depths()
	var max_depth: int = 1
	for d in depths.values():
		max_depth = max(max_depth, d)
	return {"depths": depths, "max_depth": max_depth}

# --- Base fills (DESIGN.md §7.6) ---

static func _fill_matrix(graph: AsteroidGraph, mat_a: int, mat_b: int, share_a: float, rng: RandomNumberGenerator) -> void:
	for node in graph.nodes.keys():
		graph.node_material[node] = mat_a if rng.randf() < share_a else mat_b

static func _fill_layered(graph: AsteroidGraph, depths: Dictionary, max_depth: int, layers: Array) -> void:
	# layers: Array of [max_frac, material_id], innermost (smallest frac) first — DESIGN.md §7.6.
	for node in graph.nodes.keys():
		var frac: float = float(depths.get(node, 0)) / float(max(max_depth, 1))
		var mat: int = layers[layers.size() - 1][1]
		for layer in layers:
			if frac <= layer[0]:
				mat = layer[1]
				break
		graph.node_material[node] = mat

# --- Veins (DESIGN.md §7.6) ---

static func _add_veins(graph: AsteroidGraph, depths: Dictionary, max_depth: int, material_ids: Array, count_range: Array, rng: RandomNumberGenerator) -> void:
	var rock_size: float = _rock_size(graph)
	var count: int = rng.randi_range(count_range[0], count_range[1])
	for i in range(count):
		var mat_id: int = material_ids[rng.randi() % material_ids.size()]
		var width: float = max(rng.randf_range(Config.VEIN_MIN_WIDTH_FRAC, Config.VEIN_MAX_WIDTH_FRAC) * rock_size, Config.VEIN_MIN_RADIUS_NODES)
		var length: float = rng.randf_range(Config.VEIN_MIN_LENGTH_FRAC, Config.VEIN_MAX_LENGTH_FRAC) * rock_size

		var candidates: Array = []
		for node in graph.nodes.keys():
			var frac: float = float(depths.get(node, 0)) / float(max(max_depth, 1))
			if frac >= Config.VEIN_START_DEPTH_FRACTION:
				candidates.append(node)
		if candidates.is_empty():
			continue

		var current: Vector2i = candidates[rng.randi() % candidates.size()]
		var heading: float = rng.randf_range(0.0, TAU)
		var visited: Array = [current]
		var walked: float = 0.0
		while walked < length:
			heading += rng.randf_range(-Config.VEIN_TURN, Config.VEIN_TURN)
			var want: Vector2 = Vector2(cos(heading), sin(heading))
			var best_dir: Vector2i = AsteroidGraph.HEX_DIRECTIONS[0]
			var best_dot: float = -INF
			for dir in AsteroidGraph.HEX_DIRECTIONS:
				var dot: float = AsteroidGraph.hex_offset(dir).normalized().dot(want)
				if dot > best_dot:
					best_dot = dot
					best_dir = dir
			var next_node: Vector2i = current + best_dir
			if not graph.nodes.has(next_node):
				break
			current = next_node
			visited.append(current)
			walked += 1.0

		for node in graph.nodes.keys():
			for v in visited:
				if AsteroidGraph.hex_offset(node).distance_to(AsteroidGraph.hex_offset(v)) <= width:
					graph.node_material[node] = mat_id
					break

# --- Pockets (DESIGN.md §7.6) ---

static func _add_pockets(graph: AsteroidGraph, depths: Dictionary, max_depth: int, material_id: int, count_range: Array, radius_frac_range: Array, rng: RandomNumberGenerator) -> void:
	var rock_size: float = _rock_size(graph)
	var count: int = rng.randi_range(count_range[0], count_range[1])
	var placed_centers: Array = []
	for i in range(count):
		for attempt in range(Config.POCKET_PLACEMENT_TRIES):
			var candidates: Array = []
			for node in graph.nodes.keys():
				var frac: float = float(depths.get(node, 0)) / float(max(max_depth, 1))
				if frac <= 1.0 - Config.POCKET_SURFACE_MARGIN_FRAC:
					candidates.append(node)
			if candidates.is_empty():
				break
			var center_node: Vector2i = candidates[rng.randi() % candidates.size()]
			var center_pos: Vector2 = AsteroidGraph.hex_offset(center_node)
			var radius: float = rng.randf_range(radius_frac_range[0], radius_frac_range[1]) * rock_size

			var too_close: bool = false
			for other in placed_centers:
				if center_pos.distance_to(other) < radius * 2.0:
					too_close = true
					break
			if too_close:
				continue

			for node in graph.nodes.keys():
				var bulge: float = 1.0 + rng.randf_range(-Config.POCKET_EDGE_NOISE, Config.POCKET_EDGE_NOISE)
				if AsteroidGraph.hex_offset(node).distance_to(center_pos) <= radius * bulge:
					graph.node_material[node] = material_id
			placed_centers.append(center_pos)
			break

# --- Profiles (DESIGN.md §7.6 table) ---

static func _fill_profile(graph: AsteroidGraph, profile: String, rng: RandomNumberGenerator) -> void:
	var dd: Dictionary = _depths_and_max(graph)
	var depths: Dictionary = dd["depths"]
	var max_depth: int = dd["max_depth"]

	match profile:
		"iron_slug":
			_fill_matrix(graph, Materials.IRON, Materials.ALUMINUM, Config.IRON_SLUG_IRON_SHARE, rng)
		"mixed_common":
			_fill_layered(graph, depths, max_depth, [
				[Config.MIXED_COMMON_COPPER_FRAC, Materials.COPPER],
				[Config.MIXED_COMMON_SHELL_FRAC, Materials.ALUMINUM],
				[1.0, Materials.IRON],
			])
		"copper_vein":
			_fill_matrix(graph, Materials.IRON, Materials.ALUMINUM, Config.MATRIX_IRON_SHARE, rng)
			_add_veins(graph, depths, max_depth, [Materials.COPPER], Config.VEIN_COUNTS["copper_vein"], rng)
		"rich_core":
			var boost: int = rng.randi_range(Config.RICH_CORE_RUNG_BOOST_MIN, Config.RICH_CORE_RUNG_BOOST_MAX)
			var core_mat: int = clampi(Materials.ALUMINUM + boost, Materials.IRON, Materials.IRIDIUM)
			var core_frac: float = rng.randf_range(Config.RICH_CORE_FRAC_MIN, Config.RICH_CORE_FRAC_MAX)
			_fill_layered(graph, depths, max_depth, [
				[core_frac, core_mat],
				[Config.RICH_CORE_ALUMINUM_FRAC, Materials.ALUMINUM],
				[1.0, Materials.IRON],
			])
		"pocket_rock":
			_fill_matrix(graph, Materials.IRON, Materials.ALUMINUM, Config.MATRIX_IRON_SHARE, rng)
			var pocket_mat: int = Materials.LITHIUM if rng.randf() < 0.5 else Materials.TITANIUM
			var radius_range: Array = Config.POCKET_MIN_MAX_RADIUS_FRAC if pocket_mat == Materials.LITHIUM else Config.POCKET_TITANIUM_MIN_MAX_RADIUS_FRAC
			_add_pockets(graph, depths, max_depth, pocket_mat, [Config.POCKET_COUNT_MIN, Config.POCKET_COUNT_MAX], radius_range, rng)
		"deep_vein":
			_fill_matrix(graph, Materials.COPPER, Materials.LITHIUM, Config.MATRIX_COPPER_SHARE, rng)
			var vein_mat: int = Materials.TITANIUM if rng.randf() < 0.5 else Materials.TUNGSTEN
			_add_veins(graph, depths, max_depth, [vein_mat], Config.VEIN_COUNTS["deep_vein"], rng)
		"hollow":
			_fill_matrix(graph, Materials.IRON, Materials.ALUMINUM, Config.MATRIX_IRON_SHARE, rng)
			var to_remove: Array = []
			for node in depths.keys():
				var frac: float = float(depths[node]) / float(max(max_depth, 1))
				if frac < Config.HOLLOW_INTERIOR_FRAC:
					to_remove.append(node)
			for node in to_remove:
				graph.nodes.erase(node)
				graph.node_material.erase(node)
			graph.build_edges()  # no center afterwards; the shell is self-connected, so no settle() needed
		"layered_gem":
			var core_mat: int = Materials.SILVER if rng.randf() < 0.5 else Materials.GOLD
			_fill_layered(graph, depths, max_depth, [
				[Config.LAYERED_GEM_FRACS[0], core_mat],
				[Config.LAYERED_GEM_FRACS[1], Materials.TITANIUM],
				[Config.LAYERED_GEM_FRACS[2], Materials.COPPER],
				[1.0, Materials.IRON],
			])
		"vein_gem":
			_fill_matrix(graph, Materials.COPPER, Materials.LITHIUM, Config.MATRIX_COPPER_SHARE, rng)
			var choices: Array = [Materials.SILVER, Materials.GOLD, Materials.PLATINUM]
			var vein_mat: int = choices[rng.randi() % choices.size()]
			_add_veins(graph, depths, max_depth, [vein_mat], Config.VEIN_COUNTS["vein_gem"], rng)
		"jackpot":
			for node in graph.nodes.keys():
				graph.node_material[node] = _weighted_pick(Config.JACKPOT_MATERIAL_WEIGHTS, rng)
		_:
			_fill_matrix(graph, Materials.IRON, Materials.ALUMINUM, Config.MATRIX_IRON_SHARE, rng)

# --- Nuggets + ore budget (DESIGN.md §7.7-7.8) ---

static func _pick_nugget_material(budget: Dictionary, rng: RandomNumberGenerator) -> int:
	var candidates: Array = []
	for mat_id in Config.NUGGET_MATERIALS:
		if budget.get(mat_id, 0) > 0:
			candidates.append(mat_id)
	if candidates.is_empty():
		candidates = Config.NUGGET_MATERIALS
	return candidates[rng.randi() % candidates.size()]

static func _charge_budget(graph: AsteroidGraph, budget: Dictionary) -> void:
	var counts: Dictionary = {}
	for node in graph.nodes.keys():
		var mat: int = graph.node_material.get(node, Materials.IRON)
		counts[mat] = counts.get(mat, 0) + 1

	# Cascades any over-budget material down one rung at a time, from
	# iridium to iron — DESIGN.md §7.8. Iron is unlimited, so the cascade
	# always has somewhere to land.
	for mat_id in range(Materials.IRIDIUM, Materials.ALUMINUM - 1, -1):
		var have: int = counts.get(mat_id, 0)
		if not budget.has(mat_id):
			continue
		var allowed: int = max(budget[mat_id], 0)
		if have > allowed:
			var excess: int = have - allowed
			var moved: int = 0
			for node in graph.nodes.keys():
				if moved >= excess:
					break
				if graph.node_material.get(node) == mat_id:
					graph.node_material[node] = mat_id - 1
					moved += 1
			counts[mat_id] = allowed
			counts[mat_id - 1] = counts.get(mat_id - 1, 0) + excess

	for mat_id in budget.keys():
		budget[mat_id] -= counts.get(mat_id, 0)

static func _finish_rock(graph: AsteroidGraph) -> void:
	# Step 6 (§7.4): HP from material, edge ownership, and the bounding
	# radius competitors use for avoidance/reach (§14.4) — fixed now,
	# before any mining ever happens.
	for node in graph.nodes.keys():
		var mat: int = graph.node_material.get(node, Materials.IRON)
		graph.node_hp[node] = Materials.hp(mat)
	graph.assign_edge_ownership()
	graph.compute_bounding_radius()
