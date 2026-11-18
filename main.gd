extends Node2D
# main.gd — world driver. Plays the role of DESIGN.md's game/world.py for
# now (owns the bodies, steps the simulation); folded into the root scene
# until docking/station screens force a split into scenes/flight.py-style
# scenes. Godot's _physics_process already runs at a fixed rate (Project
# Settings -> Physics -> Common -> Physics Ticks Per Second = 60, matching
# the pygame project's SIM_DT), so there's no manual accumulator to write.
#
# Milestone 2 (DESIGN.md §3-4): one star, one planet, one station, all on
# circular rails; ship gravity, thrust/turn/strafe, and impact/death
# against the star and planet.

@onready var ship: Ship = $Ship
@onready var star: OrbitBody = $Star

# DESIGN.md §3.4: a level can have more than one planet (each with its own
# station), so these are built dynamically in _build_level() rather than as
# fixed scene nodes. planets[0]/stations[0] are always the home pair, where
# runs start and competitors spawn/respawn.
var planets: Array = []   # Array[OrbitBody]
var stations: Array = []  # Array[OrbitBody]
var level: int = 1
var comp_max: int = 5     # cached from Config.LEVELS[level].comp_max

var world_time: float = 0.0
var gravity_bodies: Array = []
var fatal_bodies: Array = []
var trajectory_result: Trajectory.Result = null
var asteroid_views: Array = []  # Array of {"view": Node2D, "orbit": OrbitBody}

var bolt_laser: BoltLaser = BoltLaser.new()
var bolts: Array = []   # Array of {"position", "velocity", "damage", "life"}
var sparks: Array = []  # Array of {"position", "color", "dim", "age"}

var bomb_launcher: BombLauncher = BombLauncher.new()
var bombs: Array = []   # Array of {"position", "velocity", "radius", "damage", "life"} — DESIGN.md §9.3

# Screens (DESIGN.md §15)
@onready var instructions_view: Control = $Instructions/InstructionsView
@onready var hud_view: Control = $HUD/HUDView
@onready var game_over_view: Control = $GameOver/GameOverView
var showing_instructions: bool = true
var game_over: bool = false
var restart_key_was_down: bool = false
var game_over_at_msec: int = 0  # so a panicked tap right at death doesn't skip the game-over screen
const GAME_OVER_TAP_DELAY_MSEC: int = 800
var touch_launch_requested: bool = false  # set by tapping LAUNCH on the station screen

# ORE % and "system stripped" tracking (DESIGN.md §15.2)
var nodes_at_spawn: int = 0
var ore_fraction: float = 1.0
var ore_count_timer: float = 0.0
var stripped_time = null  # float; world_time the system was first stripped bare, or null

# Thrust puffs (DESIGN.md §16.3)
var thrust_puffs: Array = []
var puff_carry_main: float = Particles.PUFF_DUE
var puff_carry_strafe: float = Particles.PUFF_DUE
var puff_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Debug keys (DESIGN.md §17)
var unlimited_credits: bool = false  # toggled by F2

var scanner: Scanner = Scanner.new()
var scan_beam: Dictionary = {}       # {"hit","left_end","right_end"}, or {} when not scanning
var player_mode: String = "mine"     # "mine" or "scan" — DESIGN.md §11.1
var g_key_was_down: bool = false

var pulse_timer: float = 0.0
var pulse_beam: Dictionary = {}
var pulse_beam_timer: float = 0.0    # >0 while a pulse's beam is still flashing — DESIGN.md §11.3

var cargo: Cargo = Cargo.new()
var loose_ore: Array = []  # Array of {"view", "offset", "material", "pulled": bool, "pos": world Vector2 once pulled}
var tractor_held: bool = false      # the press that started the tractor beam is still down
var tractor_grab_timer: float = 0.0

var credits: int = 0
var credits_earned: int = 0

# Auto-zoom's distance input, rate-limited so it only grows about as fast
# as the ship could fly it — when the nearest body vanishes (asteroid
# destroyed), the camera drifts out instead of jumping. -1 = reset.
var zoom_dist: float = -1.0

var docked: bool = false
var docked_station: OrbitBody = null  # which station the ship is docked/launching from — DESIGN.md §12.1-12.2
var dock_armed: bool = true   # false right after launch until re-armed (DESIGN.md §12.1)
var tab_key_was_down: bool = false

# Station screen / shop (DESIGN.md §12.3, §13.4)
@onready var shop_view: Control = $StationShop/ShopView
var shop_selection: int = 0
var last_sale_breakdown: Dictionary = {}  # material id -> count, from the last dock
var last_sale_total: int = 0
var sale_countup_timer: float = 0.0
var nav_left_was_down: bool = false
var nav_right_was_down: bool = false
var nav_up_was_down: bool = false
var nav_down_was_down: bool = false
var buy_key_was_down: bool = false

# Competitors (DESIGN.md §14)
var competitors: Array = []
var competitor_group: CompetitorGroup = CompetitorGroup.new()
var competitor_spawn_timer: float = 0.0
var competitor_spawns: int = 0
var last_mined: Dictionary = {}  # asteroid view (Node2D) -> world_time it last lost a node
var competitor_view_script: Script = load("res://render/competitor_view.gd")

func _ready() -> void:
	_build_level(1)

	cargo.capacity = Upgrades.value_at("cargo_capacity", ship.upgrade_tiers.cargo_capacity)
	shop_view.main = self
	hud_view.main = self
	game_over_view.main = self
	$Touch/TouchControlsView.main = self
	$StationShop.visible = false
	$GameOver.visible = false
	puff_rng.randomize()

	docked_station = stations[0]
	place_ship_in_launch_orbit()
	dock_armed = false  # spawning in the launch orbit is just like a launch — needs to clear the planet first
	setup_asteroids()

func _build_level(lvl: int) -> void:
	# Builds a level's star/planets/stations from Config.LEVELS[lvl]
	# (DESIGN.md §3.4). Planets and stations vary in count per level, so
	# they're created here as plain nodes rather than fixed scene children;
	# $Star/$Star View are the only static bodies, since every level has
	# exactly one star.
	level = lvl
	var level_data: Dictionary = Config.LEVELS[lvl]
	comp_max = level_data.comp_max

	star.setup(null, 0.0, 0.0, level_data.star_mass, level_data.star_gravity_radius, Config.STAR_RADIUS)

	var cam: CameraControl = $Ship/Camera2D as CameraControl
	cam.zoom_min = level_data.zoom_min
	cam.auto_zoom = clamp(cam.auto_zoom, cam.zoom_min, Config.AUTO_ZOOM_MAX)
	cam._recompute()

	$Star/StarView.outline_color = Config.STAR_COLOR
	$Star/StarView.camera = cam
	$Star/StarView.min_screen_size = Config.STAR_MIN_SCREEN_SIZE

	for p in planets:
		p.queue_free()
	for s in stations:
		s.queue_free()
	planets.clear()
	stations.clear()

	var orbit_body_view_script: Script = load("res://render/orbit_body_view.gd")
	for planet_data in level_data.planets:
		var new_planet := OrbitBody.new()
		new_planet.setup(star, planet_data.orbit_radius, deg_to_rad(planet_data.phase), Config.PLANET_MASS, Config.PLANET_GRAVITY_RADIUS, Config.PLANET_RADIUS)
		add_child(new_planet)
		var planet_view := Node2D.new()
		planet_view.set_script(orbit_body_view_script)
		planet_view.outline_color = Config.PLANET_COLOR
		planet_view.camera = cam
		planet_view.min_screen_size = Config.PLANET_MIN_SCREEN_SIZE
		planet_view.max_screen_size = Config.PLANET_MAX_SCREEN_SIZE
		new_planet.add_child(planet_view)
		planets.append(new_planet)

		var new_station := OrbitBody.new()
		new_station.setup(new_planet, Config.STATION_ORBIT_RADIUS, 0.0, 0.0, 0.0, Config.STATION_RADIUS)  # no gravity, not fatal
		add_child(new_station)
		var station_view := Node2D.new()
		station_view.set_script(orbit_body_view_script)
		station_view.outline_color = Config.STATION_COLOR
		station_view.camera = cam
		station_view.min_screen_size = Config.STATION_MIN_SCREEN_SIZE
		station_view.max_screen_size = Config.STATION_MAX_SCREEN_SIZE
		new_station.add_child(station_view)
		stations.append(new_station)

	gravity_bodies = [star] + planets
	fatal_bodies = [star] + planets

	star.position = star.position_at(world_time)
	for p in planets:
		p.position = p.position_at(world_time)
	for s in stations:
		s.position = s.position_at(world_time)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_screen_tap(event.position)
		return

	# Desktop tractor beam: hold right mouse on loose ore (left click fires).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT \
			and not showing_instructions and not game_over and not docked:
		tractor_start(event.position)
		return

	# DESIGN.md §15.1: any key or mouse click dismisses the instructions.
	if showing_instructions and (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		showing_instructions = false
		instructions_view.visible = false
		return

	# DESIGN.md §17: F1/F2 debug keys. Work in flight and while docked, but
	# not over the instructions screen or the game-over screen — matching
	# scenes/flight.py, which returns before reaching them in both cases.
	if Config.DEBUG_KEYS_ENABLED and not showing_instructions and not game_over \
			and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_debug_reveal_all()
		elif event.keycode == KEY_F2:
			unlimited_credits = not unlimited_credits
			_debug_top_up()

func _handle_screen_tap(pos: Vector2) -> void:
	# Touch equivalents of the menu keys: tap dismisses the instructions,
	# restarts from game over, and drives the station screen (tap a tile to
	# select it, tap it again to buy; LAUNCH to leave). In-flight touches
	# belong to render/touch_controls_view.gd.
	if showing_instructions:
		showing_instructions = false
		instructions_view.visible = false
	elif game_over:
		if Time.get_ticks_msec() - game_over_at_msec >= GAME_OVER_TAP_DELAY_MSEC:
			_restart_game()
	elif docked:
		if shop_view.launch_rect().has_point(pos):
			touch_launch_requested = true
			return
		var i: int = shop_view.tile_at(pos)
		if i == -1:
			return
		if i == shop_selection:
			_buy_selected_tile()
		else:
			shop_selection = i

func _debug_reveal_all() -> void:
	# F1: marks every edge of every asteroid in the system as scanned.
	for entry in asteroid_views:
		var graph: AsteroidGraph = entry.view.graph
		for key in graph.edges.keys():
			graph.revealed[key] = true

func _debug_top_up() -> void:
	# F2: brings credits up to Config.DEBUG_CREDITS (never down) while
	# unlimited_credits is on. Called once per physics frame too, so it
	# stays topped up through purchases and sales alike.
	if unlimited_credits:
		credits = max(credits, Config.DEBUG_CREDITS)

func _physics_process(delta: float) -> void:
	if showing_instructions:
		return

	if game_over:
		_handle_game_over_input()
		return

	if ship.destroyed:
		game_over = true
		game_over_at_msec = Time.get_ticks_msec()
		$GameOver.visible = true
		return

	_debug_top_up()

	if docked:
		# DESIGN.md §11.3: "the simulation doesn't run" while docked —
		# everything freezes except listening for the shop/launch keys.
		sale_countup_timer += delta
		_handle_docked_input()
		return

	world_time += delta
	star.position = star.position_at(world_time)
	for p in planets:
		p.position = p.position_at(world_time)
	for s in stations:
		s.position = s.position_at(world_time)
	for entry in asteroid_views:
		entry.view.position = entry.orbit.position_at(world_time)
		entry.view.world_time = world_time  # drives the near-death pulse — DESIGN.md §16.2

	var asteroid_entries: Array = []
	for entry in asteroid_views:
		asteroid_entries.append({"view": entry.view, "graph": entry.view.graph})

	var turn_input: float = PlayerInput.turn_input()
	var local_thrust: Vector2 = PlayerInput.local_thrust()
	var precision: bool = PlayerInput.precision()
	if PlayerInput.touch_stick != Vector2.ZERO:
		# Touch joystick (point-and-thrust) — see PlayerInput.stick_controls().
		var stick: Dictionary = PlayerInput.stick_controls(ship.heading, delta)
		turn_input = clampf(turn_input + stick.turn, -1.0, 1.0)
		local_thrust += stick.thrust
		precision = precision or stick.precision

	ship.apply_turn(delta, turn_input, precision)

	var cam: CameraControl = $Ship/Camera2D as CameraControl
	var raw_dist: float = _nearest_surface_distance()
	if zoom_dist < 0.0 or raw_dist <= zoom_dist:
		zoom_dist = raw_dist
	else:
		zoom_dist = min(raw_dist, zoom_dist + (ship.velocity.length() + Config.AUTO_ZOOM_DIST_SLACK) * delta)
	cam.step_auto(delta, zoom_dist)
	var zoom_scale: float = cam.zoom_scale
	var gravity_accel: Vector2 = Gravity.acceleration(ship.position, gravity_bodies)
	var thrust_accel: Vector2 = ship.thrust_accel_vector(local_thrust, precision, zoom_scale)
	var prev_pos: Vector2 = ship.position
	ship.integrate(delta, gravity_accel + thrust_accel)
	ship.distance_flown += ship.position.distance_to(prev_pos)

	if Collisions.find_impact(prev_pos, ship.position, fatal_bodies, asteroid_entries, Config.SHIP_RADIUS):
		ship.destroyed = true
		ship.velocity = Vector2.ZERO
		return

	# Thrust puffs (DESIGN.md §16.3): main (W/S) and strafe (A/D) each get
	# their own exhaust stream, so burning diagonally shows two streams.
	thrust_puffs = Particles.step(thrust_puffs, delta)
	var main_accel: Vector2 = ship.thrust_accel_vector(Vector2(0.0, local_thrust.y), precision, zoom_scale)
	var strafe_accel: Vector2 = ship.thrust_accel_vector(Vector2(local_thrust.x, 0.0), precision, zoom_scale)
	var main_puffs: Dictionary = Particles.emit(ship.position, ship.velocity, main_accel, delta, puff_carry_main, puff_rng)
	thrust_puffs.append_array(main_puffs.puffs)
	puff_carry_main = main_puffs.carry
	var strafe_puffs: Dictionary = Particles.emit(ship.position, ship.velocity, strafe_accel, delta, puff_carry_strafe, puff_rng)
	thrust_puffs.append_array(strafe_puffs.puffs)
	puff_carry_strafe = strafe_puffs.carry

	trajectory_result = Trajectory.simulate(ship.position, ship.velocity, world_time, gravity_bodies)

	# G toggles mine/scan mode — DESIGN.md §11.1. Edge-detected so holding
	# it doesn't flip the mode every frame.
	var g_down: bool = PlayerInput.scan_key_down()
	if g_down and not g_key_was_down:
		player_mode = "scan" if player_mode == "mine" else "mine"
	g_key_was_down = g_down

	var firing: bool = PlayerInput.firing()

	if player_mode == "scan" or PlayerInput.touch_scan:
		# Nothing fires in scan mode; in-flight bolts still resolve
		# normally below, they just stop getting new company. On touch,
		# holding SCAN is a momentary scan mode.
		var scanning: bool = firing or PlayerInput.touch_scan
		scan_beam = scanner.scan(ship.position, ship.heading, ship, asteroid_entries) if scanning else {}
	else:
		# DESIGN.md §9: in mine mode, holding the trigger fires the laser
		# and the bomb launcher together, each at its own rate. On touch,
		# BLAST and BOMB are separate buttons.
		scan_beam = {}
		var new_bolts: Array = bolt_laser.update(delta, firing or PlayerInput.touch_blast, ship)
		bolts.append_array(new_bolts)
		var new_bombs: Array = bomb_launcher.update(delta, firing or PlayerInput.touch_bomb, ship)
		bombs.append_array(new_bombs)

	# Automatic scan pulses, in either mode, once the "scan_pulse" upgrade
	# is bought — DESIGN.md §11.3. Paused while docked (the outer early
	# return above already covers that).
	var pulse_interval = Upgrades.value_at("scan_pulse", ship.upgrade_tiers.scan_pulse)
	if pulse_interval != null:
		pulse_timer += delta
		if pulse_timer >= pulse_interval:
			pulse_timer = 0.0
			pulse_beam = scanner.scan(ship.position, ship.heading, ship, asteroid_entries)
			pulse_beam_timer = Config.SCAN_PULSE_FLASH_TIME
	if pulse_beam_timer > 0.0:
		pulse_beam_timer -= delta

	# Milestone 6-7 (DESIGN.md §8-10): fly and resolve bolts, crediting
	# any ore from destroyed/crumbled nodes to cargo (or loose ore if full).
	var laser_tier: int = Upgrades.value_at("laser_tier", ship.upgrade_tiers.laser_tier)
	var step_result: Dictionary = Projectiles.step_bolts(bolts, delta, asteroid_entries, laser_tier)
	for s in step_result.sparks:
		s["age"] = 0.0
		sparks.append(s)
	for ore in step_result.ore:
		_collect_ore(ore)

	# DESIGN.md §9.3-9.4: bombs travel and detonate like bolts, but with an
	# area blast and (once the bomb_shrapnel upgrade is bought) a spray of
	# shrapnel bolts on detonation, fed straight back into `bolts` above.
	var shrapnel_count: int = Upgrades.value_at("bomb_shrapnel", ship.upgrade_tiers.bomb_shrapnel)
	var bomb_result: Dictionary = Projectiles.step_bombs(bombs, delta, asteroid_entries, laser_tier, shrapnel_count)
	bolts.append_array(bomb_result.shrapnel_bolts)
	for s in bomb_result.sparks:
		s["age"] = 0.0
		sparks.append(s)
	for ore in bomb_result.ore:
		_collect_ore(ore)

	var i: int = sparks.size() - 1
	while i >= 0:
		sparks[i].age += delta
		if sparks[i].age >= Config.SPARK_LIFETIME:
			sparks.remove_at(i)
		i -= 1

	_step_tractor(delta)

	_check_docking()
	_step_competitors(delta, asteroid_entries)
	_step_ore_count(delta)

func _nearest_surface_distance() -> float:
	# Auto-zoom input: gap from the ship to the closest body's surface —
	# star, planets, stations, and asteroids (by their bounding radius).
	var best: float = INF
	for b in [star] + planets + stations:
		best = min(best, ship.position.distance_to(b.position) - b.body_radius)
	for entry in asteroid_views:
		var graph: AsteroidGraph = entry.view.graph
		if graph.nodes.is_empty():
			continue
		best = min(best, ship.position.distance_to(entry.view.position) - graph.bounding_radius)
	return max(best, 0.0)

func _step_ore_count(delta: float) -> void:
	# DESIGN.md §15.2: recounted every ORE_HUD_UPDATE_INTERVAL seconds
	# (cheap, not every tick); notes when the system first hits 0%.
	ore_count_timer += delta
	if ore_count_timer < Config.ORE_HUD_UPDATE_INTERVAL:
		return
	ore_count_timer = 0.0
	var count: int = _count_nodes()
	ore_fraction = float(count) / float(nodes_at_spawn) if nodes_at_spawn > 0 else 0.0
	if ore_fraction <= 0.0 and stripped_time == null:
		stripped_time = world_time

func _count_nodes() -> int:
	var total: int = 0
	for entry in asteroid_views:
		total += entry.view.graph.nodes.size()
	return total

func _step_competitors(delta: float, asteroid_entries: Array) -> void:
	# DESIGN.md §14.1: one at a time, up to the level's cap, each later
	# gap shorter than the last.
	competitor_spawn_timer += delta
	if (competitor_spawn_timer >= CompAI.next_spawn_interval(competitor_spawns)
			and competitors.size() < comp_max):
		competitor_spawn_timer = 0.0
		competitor_spawns += 1
		var archetype: String = CompAI.weighted_archetype_pick()
		var comp: Competitor = CompAI.spawn(archetype, stations[0], competitor_group)
		var view := Node2D.new()
		view.set_script(competitor_view_script)
		add_child(comp)
		comp.add_child(view)
		var ctx: Dictionary = _build_comp_ctx(asteroid_entries)
		CompAI.pick_new_target(comp, ctx)
		competitors.append(comp)

	var ctx: Dictionary = _build_comp_ctx(asteroid_entries)
	for comp in competitors:
		var crashed: bool = CompAI.update(comp, ctx, delta)
		if crashed:
			CompAI.respawn(comp, ctx)
		elif comp.state == Competitor.MINING and comp.cargo_used() >= comp.cargo_capacity():
			# A hit that filled the cargo mid-mine still leaves a valid
			# target; head home anyway — DESIGN.md §14.3 (world.py's
			# equivalent post-update check).
			comp.state = Competitor.RETURNING

func _build_comp_ctx(asteroid_entries: Array) -> Dictionary:
	return {
		"star": star, "stations": stations,
		"asteroid_views": asteroid_views, "asteroid_entries": asteroid_entries,
		"gravity_bodies": gravity_bodies, "world_time": world_time,
		"last_mined": last_mined, "scanner": scanner,
	}

func _check_docking() -> void:
	# DESIGN.md §12.1. Re-arming: after launching, docking stays off
	# until the ship is farther from the launch station's planet than
	# that station's orbit radius plus DOCK_RADIUS_MAX. The ship docks on
	# reaching ANY station, not just the one it launched from.
	if not dock_armed:
		var launch_planet: OrbitBody = docked_station.parent_body
		if ship.position.distance_to(launch_planet.position) > docked_station.orbit_radius + Config.DOCK_RADIUS_MAX:
			dock_armed = true
		return

	var zoom_scale: float = ($Ship/Camera2D as CameraControl).zoom_scale
	for s in stations:
		var drawn_r: float = CameraControl.drawn_radius(s.body_radius, Config.STATION_MIN_SCREEN_SIZE, zoom_scale)
		var dock_radius: float = min(Config.DOCK_REACH_FACTOR * drawn_r, Config.DOCK_RADIUS_MAX)
		if ship.position.distance_to(s.position) <= dock_radius:
			_dock(s)
			return

func _dock(station: OrbitBody) -> void:
	# DESIGN.md §12.1, §12.3: docking on reaching any station, at any
	# speed, sells all cargo at once and opens the station screen.
	docked = true
	docked_station = station
	ship.velocity = Vector2.ZERO
	last_sale_breakdown = cargo.counts.duplicate()
	var sale: int = 0
	for mat_id in last_sale_breakdown.keys():
		sale += last_sale_breakdown[mat_id] * Materials.value(mat_id)
	last_sale_total = sale
	sale_countup_timer = 0.0
	credits += sale
	credits_earned += sale
	cargo.counts.clear()
	cargo.total = 0
	shop_selection = 0
	$StationShop.visible = true
	hud_view.visible = false  # the station screen takes over — DESIGN.md §15.3

func _handle_docked_input() -> void:
	var tab_down: bool = PlayerInput.launch_key_down()
	if (tab_down and not tab_key_was_down) or touch_launch_requested:
		touch_launch_requested = false
		docked = false
		dock_armed = false
		$StationShop.visible = false
		hud_view.visible = true
		place_ship_in_launch_orbit()
	tab_key_was_down = tab_down

	# DESIGN.md §13.4: arrows move the selection, Enter buys.
	var left_down: bool = PlayerInput.nav_left_down()
	if left_down and not nav_left_was_down:
		shop_selection = Upgrades.move_selection(shop_selection, -1, 0)
	nav_left_was_down = left_down

	var right_down: bool = PlayerInput.nav_right_down()
	if right_down and not nav_right_was_down:
		shop_selection = Upgrades.move_selection(shop_selection, 1, 0)
	nav_right_was_down = right_down

	var up_down: bool = PlayerInput.nav_up_down()
	if up_down and not nav_up_was_down:
		shop_selection = Upgrades.move_selection(shop_selection, 0, -1)
	nav_up_was_down = up_down

	var down_down: bool = PlayerInput.nav_down_down()
	if down_down and not nav_down_was_down:
		shop_selection = Upgrades.move_selection(shop_selection, 0, 1)
	nav_down_was_down = down_down

	var buy_down: bool = PlayerInput.buy_key_down()
	if buy_down and not buy_key_was_down:
		_buy_selected_tile()
	buy_key_was_down = buy_down

func _buy_selected_tile() -> void:
	# DESIGN.md §13.1-13.2: a failed purchase does nothing.
	var tile: String = Upgrades.SHOP_TILES[shop_selection]
	if tile == Upgrades.BUY_BOMB_TILE:
		if credits >= Upgrades.BOMB_COST:
			credits -= Upgrades.BOMB_COST
			ship.bombs += 1
		return

	if tile == Upgrades.LEVEL_UP_TILE:
		if level >= Config.MAX_LEVEL:
			return  # "Final level" tile does nothing — DESIGN.md §13.3
		var cost: int = Upgrades.level_up_cost(level)
		if credits < cost:
			return
		credits -= cost
		_jump_to_level(level + 1)
		return

	var tier: int = ship.upgrade_tiers[tile]
	var cost = Upgrades.next_cost(tile, tier)
	if cost == null or credits < cost:
		return
	credits -= cost
	ship.upgrade_tiers[tile] = tier + 1
	if tile == "cargo_capacity":
		cargo.capacity = Upgrades.value_at("cargo_capacity", tier + 1)

func _jump_to_level(next_level: int) -> void:
	# DESIGN.md §3.4, §13.3: the ship (credits, upgrades, bombs, run stats)
	# and the competitors' shared wallet/upgrades carry over; everything
	# else about the system — asteroids, in-flight bolts/bombs/sparks/loose
	# ore/thrust puffs, live competitors and their spawn schedule, scan
	# state — is freshly built for the new level. Arrives docked at the new
	# home station with no sale shown; their old ships stay behind.
	world_time = 0.0

	bolts.clear()
	bombs.clear()
	sparks.clear()
	loose_ore.clear()
	scan_beam = {}
	pulse_beam = {}
	pulse_beam_timer = 0.0
	pulse_timer = 0.0
	thrust_puffs.clear()
	puff_carry_main = Particles.PUFF_DUE
	puff_carry_strafe = Particles.PUFF_DUE

	for entry in asteroid_views:
		entry.view.queue_free()
	asteroid_views.clear()

	for comp in competitors:
		comp.queue_free()
	competitors.clear()
	competitor_spawn_timer = 0.0
	competitor_spawns = 0
	last_mined.clear()

	_build_level(next_level)
	setup_asteroids()

	docked_station = stations[0]
	ship.position = docked_station.position
	ship.velocity = docked_station.velocity_at(world_time)
	dock_armed = false

	last_sale_breakdown = {}
	last_sale_total = 0
	sale_countup_timer = 0.0
	shop_selection = 0
	# Stays docked: this is a same-screen transition from one station to
	# the next, not a fresh dock — docked/$StationShop.visible are already
	# set from the dock that opened this shop screen.

func _collect_ore(ore: Dictionary) -> void:
	# One node removed = one ore unit. It floats loose, riding the source
	# asteroid's orbit at a fixed offset, until tractored in (tractor_start / _step_tractor).
	cargo.record_mined(ore.material)
	last_mined[ore.view] = world_time  # DESIGN.md §14.2: Scavengers watch for this
	loose_ore.append({"view": ore.view, "offset": ore.offset, "material": ore.material, "pulled": false, "pos": Vector2.ZERO})

static func loose_ore_position(item: Dictionary) -> Vector2:
	return item.pos if item.pulled else item.view.position + item.offset

func mining_range() -> float:
	return Upgrades.mining_range(ship.upgrade_tiers.mining_range)

func tractor_start(screen_pos: Vector2) -> bool:
	# A press (touch or right mouse) starts the tractor beam if it lands
	# within TRACTOR_TAP_RADIUS screen px of loose ore inside mining range.
	# Grabs one piece at once; holding keeps grabbing (_step_tractor).
	# Returns true if the press was taken, so the joystick ignores it.
	var to_screen: Transform2D = get_viewport().get_canvas_transform()
	var reach: float = mining_range()
	for item in loose_ore:
		if item.pulled:
			continue
		var pos: Vector2 = loose_ore_position(item)
		if ship.position.distance_to(pos) <= reach \
				and (to_screen * pos).distance_to(screen_pos) <= Config.TRACTOR_TAP_RADIUS:
			tractor_held = true
			_tractor_grab_next()
			tractor_grab_timer = Config.TRACTOR_GRAB_INTERVAL
			return true
	return false

func _tractor_grab_next() -> void:
	# Pulls in the unpulled loose ore nearest the ship, within mining range,
	# if cargo has room for it after the ore already in the beam.
	var reserved: int = 0
	var best: Dictionary = {}
	var best_d: float = mining_range()
	for item in loose_ore:
		if item.pulled:
			reserved += 1
			continue
		var d: float = ship.position.distance_to(loose_ore_position(item))
		if d <= best_d:
			best_d = d
			best = item
	if best.is_empty() or cargo.room() - reserved <= 0:
		return
	best.pos = loose_ore_position(best)
	best.pulled = true

func _step_tractor(delta: float) -> void:
	# While the press that started the beam is held, grab another piece
	# every TRACTOR_GRAB_INTERVAL; then reel every grabbed piece toward the
	# ship, landing it in cargo on arrival (its slot was reserved on grab).
	if not (PlayerInput.touch_tractor or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		tractor_held = false
	if tractor_held:
		tractor_grab_timer -= delta
		if tractor_grab_timer <= 0.0:
			tractor_grab_timer += Config.TRACTOR_GRAB_INTERVAL
			_tractor_grab_next()

	var reel: float = (Config.TRACTOR_SPEED + ship.velocity.length()) * delta
	var j: int = loose_ore.size() - 1
	while j >= 0:
		var item: Dictionary = loose_ore[j]
		if item.pulled:
			item.pos = item.pos.move_toward(ship.position, reel)
			if item.pos.distance_to(ship.position) <= Config.SHIP_RADIUS:
				cargo.add(item.material)
				loose_ore.remove_at(j)
		j -= 1

func place_ship_in_launch_orbit() -> void:
	# DESIGN.md §12.2: launch places the ship in a circular orbit round the
	# docked station's planet at LAUNCH_ORBIT_RADIUS, on that station's
	# side of the planet, going the same way, at the planet's orbit speed
	# plus the planet's own velocity.
	var t: float = world_time
	var launch_planet: OrbitBody = docked_station.parent_body
	var planet_pos: Vector2 = launch_planet.position_at(t)
	var planet_vel: Vector2 = launch_planet.velocity_at(t)
	var station_angle: float = docked_station.angular_speed * t + docked_station.phase  # "the station's side of the planet"
	var radial_dir: Vector2 = Vector2(cos(station_angle), sin(station_angle))
	var tangent_dir: Vector2 = Vector2(-radial_dir.y, radial_dir.x)  # same direction of travel as the rails

	ship.position = planet_pos + radial_dir * Config.LAUNCH_ORBIT_RADIUS
	var orbit_speed: float = Gravity.circular_speed(launch_planet.mass, Config.LAUNCH_ORBIT_RADIUS)
	ship.velocity = planet_vel + tangent_dir * orbit_speed

func setup_asteroids() -> void:
	# DESIGN.md §7.4-7.9, §3.4-3.5: belt generation for the current level.
	# No gravity; fatal only via mining collision handling elsewhere.
	var rng := RandomNumberGenerator.new()
	rng.seed = Config.SYSTEM_SEED
	var rocks: Array = SystemGen.generate_system(level, rng)
	var view_script: Script = load("res://render/asteroid_view.gd")

	var total_nodes: int = 0
	var profile_counts: Dictionary = {}
	for rock in rocks:
		total_nodes += rock.graph.nodes.size()
		profile_counts[rock.profile] = profile_counts.get(rock.profile, 0) + 1

		var view := Node2D.new()
		view.set_script(view_script)
		view.graph = rock.graph
		add_child(view)

		var orbit := OrbitBody.new()
		orbit.setup(star, rock.orbit_radius, rock.phase, 0.0, 0.0, 0.0)
		view.position = orbit.position_at(world_time)

		asteroid_views.append({"view": view, "orbit": orbit})

	nodes_at_spawn = total_nodes
	ore_fraction = 1.0
	ore_count_timer = 0.0
	stripped_time = null
	print("Generated %d rocks, %d nodes total: %s" % [rocks.size(), total_nodes, profile_counts])

func _handle_game_over_input() -> void:
	# DESIGN.md §15.4: Enter starts over. Reuses the shop's buy-key check —
	# same physical key (Enter/Keypad Enter) as pygame's RESTART_KEY.
	var enter_down: bool = PlayerInput.buy_key_down()
	if enter_down and not restart_key_was_down:
		_restart_game()
	restart_key_was_down = enter_down

func _restart_game() -> void:
	# DESIGN.md §15.4: a completely new run — level 1, no credits, upgrades
	# or bombs, a fresh competitor group, docked at home. The system
	# regenerates from the same SYSTEM_SEED, so it's identical but unmined.
	game_over = false
	$GameOver.visible = false

	world_time = 0.0
	_build_level(1)  # also re-positions star/planets/stations for the fresh world_time

	ship.velocity = Vector2.ZERO
	ship.heading = 0.0
	ship.destroyed = false
	ship.bombs = 0
	ship.distance_flown = 0.0
	for key in ship.upgrade_tiers.keys():
		ship.upgrade_tiers[key] = 0

	credits = 0
	credits_earned = 0
	cargo = Cargo.new()
	cargo.capacity = Upgrades.value_at("cargo_capacity", ship.upgrade_tiers.cargo_capacity)
	loose_ore.clear()
	bolts.clear()
	bombs.clear()
	sparks.clear()
	scan_beam = {}
	pulse_beam = {}
	pulse_beam_timer = 0.0
	pulse_timer = 0.0
	player_mode = "mine"
	thrust_puffs.clear()
	puff_carry_main = Particles.PUFF_DUE
	puff_carry_strafe = Particles.PUFF_DUE

	for entry in asteroid_views:
		entry.view.queue_free()
	asteroid_views.clear()

	for comp in competitors:
		comp.queue_free()
	competitors.clear()
	competitor_group = CompetitorGroup.new()
	competitor_spawn_timer = 0.0
	competitor_spawns = 0
	last_mined.clear()

	setup_asteroids()

	docked_station = stations[0]
	ship.position = docked_station.position
	ship.velocity = docked_station.velocity_at(world_time)
	dock_armed = false
	_dock(docked_station)
