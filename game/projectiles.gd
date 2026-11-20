extends RefCounted
class_name Projectiles
# game/projectiles.gd — bolts in flight and hit detection against
# asteroid outline edges (DESIGN.md §9.1-9.2). Each outline edge is
# treated as a capsule of BOLT_HIT_RADIUS; the whole move (p0->p1) is
# tested each step so a fast bolt can't skip through thin rock, and the
# first hit along the path wins when more than one edge is in range.

static func step_bolts(bolts: Array, dt: float, asteroid_entries: Array, laser_tier: int) -> Dictionary:
	# asteroid_entries: Array of {"view": Node2D, "graph": AsteroidGraph}.
	# laser_tier: the ship's current tier (DESIGN.md §13.1's "laser_tier"
	# upgrade), used for the hardness penalty. Mutates `bolts` in place
	# (removing used-up/expired ones) and returns
	# {"sparks": Array of {"position","color","dim"},
	#  "ore": Array of {"material","view","offset"} — one per node removed
	#  this step, DESIGN.md §10; the caller decides cargo vs. loose ore}.
	var sparks: Array = []
	var ore: Array = []
	var i: int = bolts.size() - 1
	while i >= 0:
		var bolt: Dictionary = bolts[i]
		var p0: Vector2 = bolt.position
		var p1: Vector2 = p0 + bolt.velocity * dt

		var hit: Dictionary = _find_hit(p0, p1, asteroid_entries, laser_tier)
		if not hit.is_empty():
			sparks.append({"position": hit.point, "color": hit.color, "dim": hit.dim})
			ore.append_array(_apply_hit(hit, bolt.damage, laser_tier))
			bolts.remove_at(i)
		else:
			bolt.life -= dt
			if bolt.life <= 0.0:
				bolts.remove_at(i)
			else:
				bolt.position = p1
		i -= 1
	return {"sparks": sparks, "ore": ore}

static func step_bombs(bombs: Array, dt: float, asteroid_entries: Array, laser_tier: int, shrapnel_count: int) -> Dictionary:
	# DESIGN.md §9.3-9.4. Mutates `bombs` in place (removing detonated
	# ones). Reuses bolts' own _find_hit for travel/collision — DESIGN.md
	# §9.3 says a bomb uses "the same capsule hit test as bolts". Returns
	# {"sparks": Array, "ore": Array, "shrapnel_bolts": Array of bolt dicts
	# shaped like weapons.gd's bolts, ready to append straight into `bolts`}.
	var sparks: Array = []
	var ore: Array = []
	var shrapnel_bolts: Array = []
	var i: int = bombs.size() - 1
	while i >= 0:
		var bomb: Dictionary = bombs[i]
		var p0: Vector2 = bomb.position
		var p1: Vector2 = p0 + bomb.velocity * dt
		bomb.life -= dt

		var hit: Dictionary = _find_hit(p0, p1, asteroid_entries, laser_tier)
		if not hit.is_empty():
			_detonate(hit.point, bomb, asteroid_entries, laser_tier, sparks, ore)
			if shrapnel_count > 0:
				shrapnel_bolts.append_array(_spawn_shrapnel(hit.point, shrapnel_count))
			bombs.remove_at(i)
		elif bomb.life <= 0.0:
			_detonate(p1, bomb, asteroid_entries, laser_tier, sparks, ore)
			if shrapnel_count > 0:
				shrapnel_bolts.append_array(_spawn_shrapnel(p1, shrapnel_count))
			bombs.remove_at(i)
		else:
			bomb.position = p1
		i -= 1
	return {"sparks": sparks, "ore": ore, "shrapnel_bolts": shrapnel_bolts}

static func _detonate(center: Vector2, bomb: Dictionary, asteroid_entries: Array, laser_tier: int, sparks: Array, ore: Array) -> void:
	# DESIGN.md §9.3: every node within bomb.radius of `center`, on every
	# asteroid the blast reaches, takes damage; each gets a spark.
	#
	# Simplification vs. the pygame original: pygame applies every caught
	# node's damage as one batch, then removes the dead ones together and
	# settles each affected rock once. Here each caught node is applied
	# through apply_damage_to_owner one at a time (reusing the same path
	# bolts use), which rebuilds edges and settles after every kill — so a
	# node that crumbles as a side effect of an earlier kill in this same
	# blast is skipped (the `nodes.has` check below) rather than damaged
	# twice. End state should match; a blast that kills several nodes at
	# once may settle the rock more than once along the way.
	for entry in asteroid_entries:
		var graph: AsteroidGraph = entry.graph
		var origin: Vector2 = entry.view.position
		if origin.distance_to(center) > graph.bounding_radius + bomb.radius:
			continue
		for node in graph.nodes_within(origin, center, bomb.radius):
			if not graph.nodes.has(node):
				continue  # already crumbled earlier in this same blast
			var mat: int = graph.node_material.get(node, Materials.IRON)
			sparks.append({
				"position": origin + AsteroidGraph.node_offset(node, Config.HEX_NODE_RADIUS),
				"color": Materials.color(mat),
				"dim": Materials.hardness(mat) > laser_tier,
			})
			ore.append_array(apply_damage_to_owner(graph, entry.view, node, bomb.damage, laser_tier))

static func _spawn_shrapnel(center: Vector2, count: int) -> Array:
	# DESIGN.md §9.4: mini-bolts sprayed outward from a detonation, evenly
	# spaced round a full circle, in the world frame (not relative to the
	# ship that fired the bomb).
	var bolts: Array = []
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		bolts.append({
			"position": center,
			"velocity": dir * Config.SHRAPNEL_SPEED,
			"damage": Config.SHRAPNEL_DAMAGE,
			"life": Config.SHRAPNEL_LIFETIME,
		})
	return bolts

static func _find_hit(p0: Vector2, p1: Vector2, asteroid_entries: Array, laser_tier: int) -> Dictionary:
	var move_len: float = p0.distance_to(p1)
	var best: Dictionary = {}
	var best_dist_along: float = INF
	for entry in asteroid_entries:
		var graph: AsteroidGraph = entry.graph
		var origin: Vector2 = entry.view.position
		# Cheap cull before walking every edge of every rock: the rock's own
		# bounding radius (plus the hit capsule), not a fixed guess.
		var reach: float = graph.bounding_radius + Config.BOLT_HIT_RADIUS + move_len
		if p0.distance_squared_to(origin) > reach * reach:
			continue
		for i in range(graph.exterior_a.size()):
			var a: Vector2 = origin + graph.exterior_a[i]
			var b: Vector2 = origin + graph.exterior_b[i]
			var dist: float = _segment_distance(p0, p1, a, b)
			if dist <= Config.BOLT_HIT_RADIUS:
				var hit_point: Vector2 = (a + b) / 2.0
				var closest_on_bolt: Vector2 = _closest_point_on_segment(p0, p1, hit_point)
				var along: float = p0.distance_to(closest_on_bolt)
				if along < best_dist_along:
					best_dist_along = along
					var owner: Vector2i = graph.exterior_owner[i]
					var mat: int = graph.node_material.get(owner, Materials.IRON)
					best = {
						"graph": graph,
						"view": entry.view,
						"owner": owner,
						"point": hit_point,
						"color": Materials.color(mat),
						"dim": Materials.hardness(mat) > laser_tier,
					}
	return best

static func _apply_hit(hit: Dictionary, damage: float, laser_tier: int) -> Array:
	return apply_damage_to_owner(hit.graph, hit.view, hit.owner, damage, laser_tier)

static func apply_damage_to_edge(graph: AsteroidGraph, view: Node2D, edge: String, damage: float, laser_tier: int) -> Array:
	# Like apply_damage_to_owner, but given an edge key instead of its
	# owner node directly — for competitors, which pick a target edge
	# rather than resolving a bolt hit (DESIGN.md §14.5).
	var n: Array = AsteroidGraph.edge_nodes(edge)
	var owner: Vector2i = graph.edge_owner.get(edge, n[0])
	return apply_damage_to_owner(graph, view, owner, damage, laser_tier)

static func apply_damage_to_owner(graph: AsteroidGraph, view: Node2D, owner: Vector2i, damage: float, laser_tier: int) -> Array:
	# Takes `damage` (hardness-adjusted) HP off `owner`. Returns [] if it
	# survived, or [{"material","view","offset"}] for it and any node
	# that crumbles as a result (DESIGN.md §7.10/§10) if it didn't.
	var mat: int = graph.node_material.get(owner, Materials.IRON)
	var eff: float = effective_damage(damage, Materials.hardness(mat), laser_tier)
	graph.node_hp[owner] = graph.node_hp.get(owner, Materials.hp(mat)) - eff
	graph.version += 1  # damage changes edge colors (and a kill changes the outline): redraw
	if graph.node_hp[owner] > 0.0:
		return []

	# DESIGN.md §7.10/§10: removing the node drops its edges and
	# recomputes the outline; ownership was assigned once at generation
	# and never changes, so no reassignment here. Each node removed —
	# this one and any that crumble from settling — becomes one ore unit
	# for whoever caused it.
	var ore: Array = [{
		"material": graph.node_material.get(owner, Materials.IRON),
		"view": view,
		"offset": AsteroidGraph.node_offset(owner, Config.HEX_NODE_RADIUS),
	}]
	graph.nodes.erase(owner)
	graph.node_material.erase(owner)
	graph.node_hp.erase(owner)
	graph.build_edges()
	var crumbled: Array = graph.settle()
	for node in crumbled:
		ore.append({
			"material": graph.node_material.get(node, Materials.IRON),
			"view": view,
			"offset": AsteroidGraph.node_offset(node, Config.HEX_NODE_RADIUS),
		})
		graph.node_material.erase(node)
		graph.node_hp.erase(node)
	return ore

static func effective_damage(damage: float, hardness: int, laser_tier: int) -> float:
	# DESIGN.md §8.1.
	var gap: int = max(0, hardness - laser_tier)
	return damage / pow(Config.HARDNESS_PENALTY_BASE, gap)

static func _closest_point_on_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var len2: float = ab.length_squared()
	if len2 <= 0.0001:
		return a
	var t: float = clamp((p - a).dot(ab) / len2, 0.0, 1.0)
	return a + ab * t

static func _segment_distance(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> float:
	# Minimum distance between segment p1-p2 and segment p3-p4.
	var d1: Vector2 = p2 - p1
	var d2: Vector2 = p4 - p3
	var r: Vector2 = p1 - p3
	var a: float = d1.dot(d1)
	var e: float = d2.dot(d2)
	var f: float = d2.dot(r)
	var s: float
	var t: float
	if a <= 0.0001 and e <= 0.0001:
		return p1.distance_to(p3)
	if a <= 0.0001:
		s = 0.0
		t = clamp(f / e, 0.0, 1.0)
	else:
		var c: float = d1.dot(r)
		if e <= 0.0001:
			t = 0.0
			s = clamp(-c / a, 0.0, 1.0)
		else:
			var b: float = d1.dot(d2)
			var denom: float = a * e - b * b
			if denom != 0.0:
				s = clamp((b * f - c * e) / denom, 0.0, 1.0)
			else:
				s = 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clamp(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clamp((b - c) / a, 0.0, 1.0)
	var closest1: Vector2 = p1 + d1 * s
	var closest2: Vector2 = p3 + d2 * t
	return closest1.distance_to(closest2)
