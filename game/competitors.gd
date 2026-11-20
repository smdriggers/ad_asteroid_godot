extends RefCounted
class_name CompAI
# game/competitors.gd — AI ships that mine the same asteroids and sell at
# the same stations as the player (DESIGN.md §14), ported from pygame's
# game/competitors.py. Pure static functions operating on a `ctx`
# Dictionary the caller (main.gd) builds each tick:
#   {"star": OrbitBody, "planet": OrbitBody, "stations": Array[OrbitBody],
#    "asteroid_views": Array of {"view","orbit"},
#    "asteroid_entries": Array of {"view","graph"} (view/graph pairs only),
#    "gravity_bodies": Array[OrbitBody], "world_time": float,
#    "last_mined": Dictionary (Node2D view -> float world_time),
#    "scanner": Scanner,
#    "loose_ore": Array (main.gd's loose_ore list, shared with the player),
#    "drop_ore": Callable(ore) — puts mined ore into loose_ore}
#
# Cycle: outbound -> mining -> returning -> (sell) -> outbound ...
# Mined ore floats loose like the player's; competitors tractor in any
# unclaimed loose ore in reach (theirs or the player's), and Scavengers fly
# to wherever the most of it is.

static func weighted_archetype_pick() -> String:
	# rng.choices(ARCHETYPES, weights=COMP_ARCHETYPE_WEIGHTS_S1)[0] — DESIGN.md §14.1.
	var weights: Array = Config.COMP_ARCHETYPE_WEIGHTS_S1
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in range(Competitor.ARCHETYPES.size()):
		acc += weights[i]
		if roll < acc:
			return Competitor.ARCHETYPES[i]
	return Competitor.ARCHETYPES[Competitor.ARCHETYPES.size() - 1]

static func next_spawn_interval(spawns_so_far: int) -> float:
	return max(Config.COMP_SPAWN_INTERVAL_MIN, Config.COMP_SPAWN_INTERVAL_S1 - Config.COMP_SPAWN_INTERVAL_STEP * spawns_so_far)

static func spawn(archetype: String, station_body: OrbitBody, group: CompetitorGroup) -> Competitor:
	var comp := Competitor.new()
	comp.position = station_body.position
	comp.velocity = Vector2.ZERO
	comp.archetype = archetype
	comp.group = group
	comp.state = Competitor.IDLE
	return comp

static func respawn(comp: Competitor, ctx: Dictionary) -> void:
	# After a crash: back at the station with empty cargo — DESIGN.md §14.4.
	var home: OrbitBody = ctx.stations[0]
	comp.position = home.position
	comp.velocity = Vector2.ZERO
	comp.cargo.clear()
	comp.mine_timer = 0.0
	pick_new_target(comp, ctx)

static func pick_new_target(comp: Competitor, ctx: Dictionary) -> void:
	# Picks fresh from what's known. With nothing left to mine, goes home
	# to sell whatever it carries, or idles at the station.
	var skip: Array = []
	for view in comp.too_hard.keys():
		if comp.laser_tier() <= comp.too_hard[view]:
			skip.append(view)
	comp.target = null
	if comp.archetype == Competitor.SCAVENGER and comp.cargo_used() < comp.cargo_capacity():
		comp.target = loose_ore_target(comp.position, ctx.asteroid_views, loose_ore_counts(ctx.loose_ore))
	if comp.target == null:
		comp.target = choose_target(comp.archetype, comp.position, ctx.asteroid_views, ctx.last_mined, skip)
	comp.mine_timer = 0.0
	if comp.target != null:
		comp.state = Competitor.OUTBOUND
	elif comp.cargo_used() > 0:
		comp.state = Competitor.RETURNING
	else:
		comp.state = Competitor.IDLE

# -- Scanning and target choice (pure) --

static func scanned_value(graph: AsteroidGraph) -> int:
	# Credits' worth of ore competitors know about in this rock: every
	# node owning at least one competitor-revealed edge counts once.
	var known: Dictionary = {}
	for key in graph.comp_revealed.keys():
		if graph.edge_owner.has(key):
			known[graph.edge_owner[key]] = true
	var total: int = 0
	for owner in known.keys():
		if graph.nodes.has(owner):
			total += Materials.value(graph.node_material.get(owner, Materials.IRON))
	return total

static func loose_ore_target(pos: Vector2, asteroid_views: Array, counts: Dictionary):
	# Scavengers steal: the asteroid carrying the most unclaimed loose ore
	# (anyone's, the player's included), nearest first on ties, or null.
	# The rock may already be mined out; the ore still rides its orbit.
	var best = null
	var best_n: int = 0
	var best_d: float = INF
	for entry in asteroid_views:
		var n: int = counts.get(entry.view, 0)
		if n <= 0:
			continue
		var d: float = entry.view.position.distance_to(pos)
		if n > best_n or (n == best_n and d < best_d):
			best = entry
			best_n = n
			best_d = d
	return best

static func choose_target(archetype: String, pos: Vector2, asteroid_views: Array, last_mined: Dictionary, skip: Array):
	# The asteroid entry this archetype heads for next, or null if every
	# rock is empty (or in `skip`). Ties go to the earlier asteroid.
	var candidates: Array = []
	for entry in asteroid_views:
		if skip.has(entry.view):
			continue
		if entry.view.graph.nodes.size() > 0:
			candidates.append(entry)
	if candidates.is_empty():
		return null

	var arch: String = archetype
	if arch == Competitor.SCAVENGER:
		var partly: Array = []
		for entry in candidates:
			if last_mined.has(entry.view):
				partly.append(entry)
		if not partly.is_empty():
			var best_p = partly[0]
			var best_t: float = last_mined[best_p.view]
			for entry in partly:
				if last_mined[entry.view] > best_t:
					best_p = entry
					best_t = last_mined[entry.view]
			return best_p
		arch = Competitor.PROSPECTOR  # nothing started yet: go for the richest

	if arch == Competitor.PROSPECTOR:
		var best = candidates[0]
		var best_val: int = scanned_value(best.view.graph)
		for entry in candidates:
			var v: int = scanned_value(entry.view.graph)
			if v > best_val:
				best = entry
				best_val = v
		if best_val > 0:
			return best
	if arch == Competitor.HAULER:
		var best_h = candidates[0]
		var best_n: int = best_h.view.graph.nodes.size()
		for entry in candidates:
			var n: int = entry.view.graph.nodes.size()
			if n > best_n:
				best_h = entry
				best_n = n
		return best_h

	# RUSHER, or PROSPECTOR/HAULER with nothing known: nearest rock.
	var nearest = candidates[0]
	var nearest_d: float = nearest.view.position.distance_to(pos)
	for entry in candidates:
		var d: float = entry.view.position.distance_to(pos)
		if d < nearest_d:
			nearest = entry
			nearest_d = d
	return nearest

# -- Steering (pure) --

static func steering_dv(pos: Vector2, vel: Vector2, goal_pos: Vector2, goal_vel: Vector2, dt: float, max_dv: float) -> Vector2:
	# Velocity change for one tick: push toward matching the goal's
	# velocity plus a closing speed that shrinks near arrival, capped at
	# max_dv. Gravity is handled separately by the caller.
	var offset: Vector2 = goal_pos - pos
	var dist: float = offset.length()
	var desired: Vector2 = goal_vel
	if dist > 0.0:
		var max_accel: float = max_dv / dt
		var closing: float = min(Config.COMP_ARRIVAL_GAIN * sqrt(2.0 * max_accel * dist), Config.COMP_HOLD_GAIN * dist)
		desired += offset / dist * closing
	var dv: Vector2 = desired - vel
	if dv.length() > max_dv:
		dv = dv.normalized() * max_dv
	return dv

static func avoid_bodies(pos: Vector2, goal_pos: Vector2, frame: OrbitBody, bodies: Array, margin: float) -> Dictionary:
	# If the straight line to the goal passes within `margin` x a body's
	# radius of its center, go round it instead. bodies: Array of
	# {"pos": Vector2, "radius": float, "frame": OrbitBody}. Returns
	# {"goal_pos": Vector2, "frame": OrbitBody}. When several bodies are in
	# the way, the one met first along the path is the one gone round.
	var waypoint_scale: float = 1.0 / cos(deg_to_rad(Config.COMP_DETOUR_STEP) / 2.0)

	# Already too close to something: get out, from the nearest one first.
	var inside = null
	var inside_d: float = INF
	for body in bodies:
		var d: float = pos.distance_to(body.pos)
		if d > 0.0 and d < body.radius * margin and d - body.radius < inside_d:
			inside = body
			inside_d = d - body.radius
	if inside != null:
		var out_dir: Vector2 = (pos - inside.pos).normalized()
		return {"goal_pos": inside.pos + out_dir * inside.radius * margin * waypoint_scale, "frame": inside.frame}

	var path: Vector2 = goal_pos - pos
	var length_sq: float = path.length_squared()
	var blocker = null
	var blocker_t: float = INF
	for body in bodies:
		var safe: float = body.radius * margin
		var t: float = 0.0
		if length_sq != 0.0:
			t = clamp((body.pos - pos).dot(path) / length_sq, 0.0, 1.0)
		if (pos + path * t - body.pos).length() < safe and t < blocker_t:
			blocker = body
			blocker_t = t
	if blocker == null:
		return {"goal_pos": goal_pos, "frame": frame}
	var out: Vector2 = pos - blocker.pos
	if out.length() == 0.0:
		out = Vector2(1, 0)
	var turn: float = 1.0 if out.cross(goal_pos - blocker.pos) >= 0.0 else -1.0
	var step: Vector2 = out.normalized().rotated(turn * deg_to_rad(Config.COMP_DETOUR_STEP))
	return {"goal_pos": blocker.pos + step * blocker.radius * margin * waypoint_scale, "frame": blocker.frame}

static func incoming_rock(pos: Vector2, vel: Vector2, rocks: Array, world_time: float):
	# The rock that will pass too close soonest on current relative motion,
	# or null. Rocks on other orbits drift past each other, so a ship
	# holding still relative to its own target can still be run down; the
	# path-based avoid_bodies() can't see that. rocks: Array of asteroid
	# entries {"view","orbit"}. Returns {"entry","miss": Vector2 (rock ->
	# ship at closest approach)}.
	var best = null
	var best_t: float = INF
	for entry in rocks:
		var r: Vector2 = pos - entry.view.position
		var v: Vector2 = vel - entry.orbit.velocity_at(world_time)
		var t: float = 0.0
		var v2: float = v.length_squared()
		if v2 > 0.0001:
			t = clampf(-r.dot(v) / v2, 0.0, Config.COMP_EVADE_HORIZON)
		var miss: Vector2 = r + v * t
		var clear: float = entry.view.graph.bounding_radius + Config.SHIP_RADIUS + Config.COMP_EVADE_BUFFER
		if miss.length() < clear and t < best_t:
			best = {"entry": entry, "miss": miss}
			best_t = t
	return best

static func turn_toward(angle: float, target_angle: float, max_turn: float) -> float:
	# Rotates `angle` toward `target_angle` by at most `max_turn` radians,
	# the short way round.
	var diff: float = wrapf(target_angle - angle, -PI, PI)
	return angle + clamp(diff, -max_turn, max_turn)

static func nearest_target_edge(graph: AsteroidGraph, asteroid_pos: Vector2, point: Vector2, max_hardness):
	# {"edge","mid","dist"} for the outline edge whose midpoint is
	# closest to `point`, or null if the rock is empty. With
	# `max_hardness`, only edges whose owner node is no harder than that
	# count. Ties go to the lower edge key, for a stable choice.
	var best = null
	var best_dist: float = INF
	var best_key: String = ""
	for i in range(graph.exterior_keys.size()):
		var key: String = graph.exterior_keys[i]
		if max_hardness != null:
			var mat: int = graph.node_material.get(graph.exterior_owner[i], Materials.IRON)
			if Materials.hardness(mat) > max_hardness:
				continue
		var mid: Vector2 = asteroid_pos + (graph.exterior_a[i] + graph.exterior_b[i]) / 2.0
		var dist: float = mid.distance_to(point)
		if best == null or dist < best_dist or (dist == best_dist and key < best_key):
			best = {"edge": key, "mid": mid, "dist": dist}
			best_dist = dist
			best_key = key
	return best

static func _standoff_point(from_pos: Vector2, anchor: Vector2, distance: float) -> Vector2:
	# The point `distance` from `anchor`, on the side facing `from_pos`.
	var away: Vector2 = from_pos - anchor
	if away.length() == 0.0:
		away = Vector2(0, -1)
	return anchor + away.normalized() * distance

static func nearest_station(stations: Array, pos: Vector2) -> OrbitBody:
	var best: OrbitBody = stations[0]
	var best_d: float = best.parent_body.position.distance_to(pos)
	for s in stations:
		var d: float = s.parent_body.position.distance_to(pos)
		if d < best_d:
			best = s
			best_d = d
	return best

static func _goal(comp: Competitor, ctx: Dictionary, pos: Vector2) -> Dictionary:
	# {"goal_pos": Vector2, "frame": OrbitBody, "target": {"edge","mid","dist"} or null}
	# `frame` is the rail body whose motion they match on the way.
	if comp.state == Competitor.RETURNING or comp.state == Competitor.IDLE:
		var rock = comp.target
		if rock != null and pos.distance_to(rock.view.position) < rock.view.graph.bounding_radius + Config.COMP_MINE_STANDOFF:
			# Back straight off the rock just mined before turning for home.
			var out: Vector2 = pos - rock.view.position
			if out.length() == 0.0:
				out = Vector2(0, -1)
			return {"goal_pos": rock.view.position + out.normalized() * 2.0 * rock.view.graph.bounding_radius, "frame": rock.orbit, "target": null}
		# Docking only needs them close, at any speed, so they wait on the
		# nearest station's orbit, on their side of its planet, and let
		# the station come round to them.
		var home: OrbitBody = nearest_station(ctx.stations, pos)
		var planet_body: OrbitBody = home.parent_body
		var side: Vector2 = pos - planet_body.position
		if side.length() == 0.0:
			side = Vector2(1, 0)
		return {"goal_pos": planet_body.position + side.normalized() * home.orbit_radius, "frame": planet_body, "target": null}

	var asteroid = comp.target
	var graph: AsteroidGraph = asteroid.view.graph
	if comp.hold_rock != asteroid.view:
		comp.hold_offset = null  # a different rock: any held spot is stale
	var reach: float = graph.bounding_radius + Config.COMP_MINE_RANGE
	if pos.distance_to(asteroid.view.position) > reach:
		# Far away: aim for just outside the rock's bounds, on our side.
		comp.hold_offset = null
		var goal: Vector2 = _standoff_point(pos, asteroid.view.position, graph.bounding_radius + Config.COMP_MINE_STANDOFF)
		return {"goal_pos": goal, "frame": asteroid.orbit, "target": null}

	var target = nearest_target_edge(graph, asteroid.view.position, pos, comp.max_hardness())
	if target == null:  # empty, or nothing soft enough: hold off the rock
		comp.hold_offset = null
		var goal2: Vector2 = _standoff_point(pos, asteroid.view.position, graph.bounding_radius + Config.COMP_MINE_STANDOFF)
		return {"goal_pos": goal2, "frame": asteroid.orbit, "target": null}

	# Can they already hit something from here? Then stay put (relative to
	# the rock) and fire, rather than flying in close to the ideal spot —
	# every metre closer is crash risk for nothing.
	if target.dist <= Config.COMP_MINE_RANGE:
		if comp.hold_offset == null:
			comp.hold_offset = pos - asteroid.view.position
			comp.hold_rock = asteroid.view
		return {"goal_pos": asteroid.view.position + comp.hold_offset, "frame": asteroid.orbit, "target": target}

	# Nothing in reach from here (e.g. the near face is mined away): move in
	# to the ideal standoff from the nearest cuttable edge.
	comp.hold_offset = null
	var goal3: Vector2 = _standoff_point(pos, target.mid, Config.COMP_MINE_STANDOFF)
	return {"goal_pos": goal3, "frame": asteroid.orbit, "target": target}

static func _scan_direction(comp: Competitor) -> Vector2:
	# Where a scan pulse points: at the target rock once it's within
	# scanner range, otherwise along the heading.
	var rock = comp.target
	if rock != null and (comp.state == Competitor.OUTBOUND or comp.state == Competitor.MINING):
		var to_rock: Vector2 = rock.view.position - comp.position
		var scan_range: float = Upgrades.value_at("scan_range", 0)
		if to_rock.length() > 0.0 and to_rock.length() <= scan_range + rock.view.graph.bounding_radius:
			return to_rock.normalized()
	return Vector2(0, -1).rotated(comp.heading)

static func _is_docked(ship_pos: Vector2, station_pos: Vector2) -> bool:
	# Competitors dock at any zoom (no camera): the station's real radius,
	# not its drawn/zoom-scaled one — DESIGN.md §12.1's zoom=None case.
	var dock_radius: float = min(Config.DOCK_REACH_FACTOR * Config.STATION_RADIUS, Config.DOCK_RADIUS_MAX)
	return ship_pos.distance_to(station_pos) <= dock_radius

static func _sell_cargo(comp: Competitor) -> int:
	var total: int = 0
	for material in comp.cargo.keys():
		total += comp.cargo[material] * Materials.value(material)
	comp.cargo.clear()
	return total

# -- Per-tick update --

static func update(comp: Competitor, ctx: Dictionary, dt: float) -> bool:
	# One tick for one competitor. Returns whether it crashed (the
	# caller respawns it).
	comp.scan_timer -= dt
	if comp.scan_timer <= 0.0:
		comp.scan_timer = Config.COMP_SCAN_PULSE_INTERVAL
		var dir: Vector2 = _scan_direction(comp)
		var scan_heading: float = atan2(dir.x, -dir.y)
		ctx.scanner.scan_for_competitor(comp.position, scan_heading, comp.scan_depth(), ctx.asteroid_entries)

	# Rails have already moved to this tick's end; compare like with like
	# by working from where the ship will be after coasting this tick.
	var coast_pos: Vector2 = comp.position + comp.velocity * dt
	var goal: Dictionary = _goal(comp, ctx, coast_pos)
	var goal_pos: Vector2 = goal.goal_pos
	var frame: OrbitBody = goal.frame
	var target = goal.target

	# Steer round the star, every planet and every rock except the one
	# they're working (backing off it on the way home is _goal's job).
	# DESIGN.md §14.4: avoids ctx.gravity_bodies (star + all planets, not
	# just home), matching the pygame original — matters once a level has
	# more than one planet to fly past.
	# The target is only exempt while heading to or working it; once
	# they've turned for home it's just another rock to steer round.
	var working: bool = comp.state == Competitor.OUTBOUND or comp.state == Competitor.MINING
	var lookout: float = Config.COMP_ROCK_AVOID_RANGE + comp.velocity.length() * Config.COMP_ROCK_AVOID_LOOKAHEAD
	var avoid_list: Array = []
	var nearby_rocks: Array = []
	for body in ctx.gravity_bodies:
		avoid_list.append({"pos": body.position, "radius": body.body_radius, "frame": body})
	for entry in ctx.asteroid_views:
		if working and entry == comp.target:
			continue
		if entry.view.graph.nodes.is_empty():
			continue
		if entry.view.position.distance_to(coast_pos) < lookout:
			avoid_list.append({"pos": entry.view.position, "radius": entry.view.graph.bounding_radius, "frame": entry.orbit})
			nearby_rocks.append(entry)

	# A rock on a collision course comes first: match its motion (so it
	# can't hit us) and slip sideways out of its way. Otherwise plan round
	# whatever's in the way of the goal.
	var threat = incoming_rock(coast_pos, comp.velocity, nearby_rocks, ctx.world_time)
	var dodging: bool = threat != null
	if dodging:
		var away: Vector2 = threat.miss
		if away.length() < 0.001:
			away = coast_pos - threat.entry.view.position
		if away.length() < 0.001:
			away = Vector2(1, 0)
		var clear: float = threat.entry.view.graph.bounding_radius * Config.COMP_AVOID_MARGIN + Config.COMP_EVADE_BUFFER
		goal_pos = threat.entry.view.position + away.normalized() * clear
		frame = threat.entry.orbit
	else:
		var avoided: Dictionary = avoid_bodies(coast_pos, goal_pos, frame, avoid_list, Config.COMP_AVOID_MARGIN)
		goal_pos = avoided.goal_pos
		frame = avoided.frame

	# Gravity: part of each burn first makes up the difference between
	# how the frame they're matching accelerates and what gravity does
	# to them; what's left steers.
	var pull: Vector2 = Gravity.acceleration(comp.position, ctx.gravity_bodies)
	var frame_vel_now: Vector2 = frame.velocity_at(ctx.world_time)
	var frame_vel_next: Vector2 = frame.velocity_at(ctx.world_time + dt)
	var max_dv: float = comp.group.max_burn_dv()
	var hold_dv: Vector2 = (frame_vel_next - frame_vel_now) - pull * dt
	if hold_dv.length() > max_dv:
		hold_dv = hold_dv.normalized() * max_dv
	var steer_dv: Vector2 = steering_dv(coast_pos, comp.velocity, goal_pos, frame_vel_now, dt, max(0.0, max_dv - hold_dv.length()))
	if steer_dv.length() >= Config.COMP_HEADING_MIN_DV:
		# Big burns turn the ship (at the player's turn rate); small ones
		# are strafes and leave it facing as it was.
		var burn_angle: float = atan2(steer_dv.x, -steer_dv.y)
		comp.heading = turn_toward(comp.heading, burn_angle, Config.TURN_RATE * dt)

	# Same integrator as the player: thrust is applied as an acceleration.
	var accel: Vector2 = pull + (hold_dv + steer_dv) / dt
	var previous_pos: Vector2 = comp.position
	comp.integrate(dt, accel)

	if Collisions.find_impact(previous_pos, comp.position, ctx.gravity_bodies, ctx.asteroid_entries, Config.SHIP_RADIUS):
		return true

	# Tractor in loose ore in reach — their own drops, and anyone else's.
	_tractor(comp, ctx, dt)

	if dodging:
		pass  # mining and target decisions wait until the rock has gone by
	elif comp.state == Competitor.OUTBOUND or comp.state == Competitor.MINING:
		var rock = comp.target
		var at_rock: bool = comp.position.distance_to(rock.view.position) <= rock.view.graph.bounding_radius + Config.COMP_MINE_RANGE
		if rock.view.graph.nodes.size() == 0:
			if comp.state == Competitor.MINING or at_rock:
				pick_new_target(comp, ctx)  # mined out, or arrived to find it empty
		elif at_rock and target == null:
			# Nothing here soft enough to cut: try elsewhere until the laser improves.
			comp.too_hard[rock.view] = comp.laser_tier()
			if comp.cargo_used() > 0 and comp.cargo_used() >= comp.cargo_capacity():
				comp.state = Competitor.RETURNING
			else:
				pick_new_target(comp, ctx)
		elif comp.state == Competitor.OUTBOUND:
			if target != null and target.dist <= Config.COMP_MINE_RANGE:
				comp.state = Competitor.MINING
		elif target != null:  # null: drifted out of reach, still steering back
			_mine(comp, target, dt, ctx)
	elif comp.state == Competitor.RETURNING:
		for s in ctx.stations:
			if _is_docked(comp.position, s.position):
				var earned: int = _sell_cargo(comp)
				comp.group.deposit(earned)
				pick_new_target(comp, ctx)
				break

	return false

static func _mine(comp: Competitor, target: Dictionary, dt: float, ctx: Dictionary) -> void:
	# Fires real laser bolts at the target edge, at the group's mine rate —
	# the same bolts as the player's (game/projectiles.gd), so they fly,
	# throw sparks and can clip other rocks. main.gd steps comp.bolts at
	# this competitor's laser tier and drops the ore they cut as loose ore.
	comp.mine_timer += dt
	var interval: float = 1.0 / comp.group.mine_rate()
	if comp.mine_timer < interval:
		return
	comp.mine_timer = minf(comp.mine_timer - interval, interval)  # don't bank shots while out of range
	if target.dist > Config.COMP_MINE_RANGE:
		return  # drifted out of range; keep closing in
	var to_edge: Vector2 = target.mid - comp.position
	if to_edge.length() < 0.001:
		return
	var dir: Vector2 = to_edge.normalized()
	comp.heading = atan2(dir.x, -dir.y)  # face the shot
	comp.bolts.append({
		"position": comp.position,
		"velocity": dir * Config.BOLT_SPEED + comp.velocity,
		"damage": Config.BOLT_DAMAGE,
		"life": (Config.COMP_MINE_RANGE + Config.COMP_BOLT_RANGE_SLACK) / Config.BOLT_SPEED,
	})

static func _tractor(comp: Competitor, ctx: Dictionary, dt: float) -> void:
	# Every COMP_TRACTOR_INTERVAL, grab the nearest loose ore within
	# COMP_TRACTOR_RANGE that nobody is pulling yet — whoever mined it —
	# if cargo has room after what's already in the beam. main.gd reels it
	# in and calls add_to_cargo() on arrival.
	comp.tractor_timer -= dt
	if comp.tractor_timer > 0.0:
		return
	comp.tractor_timer = Config.COMP_TRACTOR_INTERVAL
	var pulling: int = 0
	var best = null
	var best_d: float = Config.COMP_TRACTOR_RANGE
	for item in ctx.loose_ore:
		if item.pulled:
			if item.puller == comp:
				pulling += 1
			continue
		if item.dropper != comp and ctx.world_time - item.dropped_at < Config.COMP_STEAL_DELAY:
			continue  # someone else's, too fresh to snatch yet
		var d: float = comp.position.distance_to(item.view.position + item.offset)
		if d <= best_d:
			best = item
			best_d = d
	if best == null or comp.cargo_used() + pulling >= comp.cargo_capacity():
		return
	best.pos = best.view.position + best.offset
	best.pulled = true
	best.puller = comp

static func loose_ore_counts(loose_ore: Array) -> Dictionary:
	# Asteroid view (Node2D) -> how many unclaimed loose ore ride it.
	var counts: Dictionary = {}
	for item in loose_ore:
		if not item.pulled:
			counts[item.view] = counts.get(item.view, 0) + 1
	return counts
