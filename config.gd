extends Node
# config.gd — autoload. Every tuning number lives here, with a comment,
# mirroring the pygame project's config.py: no magic numbers in game code.
# Placeholder values throughout; tune by playing (per CLAUDE.md).

# --- Simulation ---
const G: float = 50.0              # gravitational constant — ported from pygame config.py
const SOFTENING: float = 50.0      # px; prevents blow-ups at close range — ported from pygame config.py
const SIM_DT: float = 1.0 / 60.0   # fixed sim step; must match Project Settings -> Physics -> Common -> Physics Ticks Per Second

# --- Trajectory preview ---
const TRAJECTORY_STEPS: int = 300            # how many SIM_DT steps ahead to coast — DESIGN.md §5 (5s at 60Hz; tune in playtesting)
const TRAJECTORY_DOT_EVERY: int = 5          # draw every Nth simulated point as a dot
const TRAJECTORY_DOT_COLOR: Color = Color(0.6, 0.6, 0.6)
const TRAJECTORY_CRASH_COLOR: Color = Color(1.0, 0.2, 0.2)
const TRAJECTORY_X_SIZE: float = 8.0         # px; half-width of the crash X

# --- Ship ---
const SHIP_RADIUS: float = 6.0                  # px; draw/collision radius — ported from pygame config.py
const SHIP_COLOR: Color = Color(0.2, 1.0, 0.6)  # placeholder neon color
const TURN_RATE: float = 3.0                    # radians/sec while Q/E held — DESIGN.md §4.1
const THRUST_ACCEL: float = 100.0               # px/sec^2 — raised from pygame's 60
const PRECISION_FACTOR: float = 0.5             # Shift multiplier on turn rate and thrust — DESIGN.md §4.2

# --- Camera / zoom (DESIGN.md §6) ---
# "zoom" here is a magnification scale (bigger = zoomed in), not Godot's
# own Camera2D.zoom (bigger = more area shown) — see render/camera_control.gd.
# ZOOM_MIN (most zoomed out, so the whole system roughly fits) is per
# level now — see LEVELS below; CameraControl.zoom_min is set from it.
const ZOOM_DEFAULT: float = 0.25     # ported from pygame config.py (thrust scaling is unscaled at this value)
const ZOOM_MAX: float = 3.0          # ported from pygame config.py
const ZOOM_SPEED: float = 1.1        # multiplier/divisor applied per wheel notch — ported from pygame config.py
const THRUST_ZOOM_EXPONENT: float = 1.0  # DESIGN.md §4.2: thrust *= (ZOOM_DEFAULT/zoom)^this
const THRUST_ZOOM_CAP: float = 1.0       # zoom past this no longer weakens thrust, so zoomed-in play can still escape planet gravity
# Zoom is manual: the zoom bar on the right edge (render/zoom_bar_view.gd)
# spans [level zoom_min, ZOOM_MAX] in log scale; the wheel nudges it.

# --- Solar system bodies (DESIGN.md §3.1): same scale in every level; a
# level's STAR_MASS/STAR_GRAVITY_RADIUS/planet layout is in LEVELS below. ---
const STAR_RADIUS: float = 50.0      # ported from pygame config.py
const STAR_COLOR: Color = Color(1.0, 0.8, 0.2)

const PLANET_MASS: float = 300.0     # ported from pygame config.py
const PLANET_GRAVITY_RADIUS: float = 400.0  # ported from pygame config.py
const PLANET_RADIUS: float = 20.0    # ported from pygame config.py
const PLANET_COLOR: Color = Color(0.4, 0.6, 1.0)

const STATION_ORBIT_RADIUS: float = 60.0   # ported from pygame config.py
const LAUNCH_ORBIT_RADIUS: float = 45.0    # ported from pygame config.py; just beyond the station so the ship doesn't spawn on top of it
const STATION_COLOR: Color = Color(1.0, 1.0, 1.0)  # DESIGN.md §16.1: stations are white circle outlines
const STATION_RADIUS: float = 8.0          # px; draw/dock-math radius — ported from pygame config.py

# Minimum screen sizes (DESIGN.md §16.1): drawn (and, for the station,
# dock-math) radius never shrinks below this many px on screen, however
# far the camera zooms out. Looks only for star/planet; real for the
# station, since its drawn size sets its dock reach (§12.1).
# All three ported from pygame config.py.
const STAR_MIN_SCREEN_SIZE: float = 16.0
const PLANET_MIN_SCREEN_SIZE: float = 14.0
const STATION_MIN_SCREEN_SIZE: float = 10.0

# Maximum screen sizes: drawn radius never grows past this many px on
# screen, however far the camera zooms in. Not in the pygame project;
# added so the planet/station don't balloon as you approach. Looks
# only — doesn't change the station's dock reach (§12.1), which still
# reads its real/min-floored size from drawn_radius() in main.gd.
# (First pass used 80/60, but real_radius * ZOOM_MAX never reaches
# those — planet tops out at 20*3=60, station at 8*3=24 — so the cap
# never actually engaged. These are low enough to bind well inside the
# zoom range: planet stops growing past zoom 1.5, station past zoom 2.5.)
const PLANET_MAX_SCREEN_SIZE: float = 30.0
const STATION_MAX_SCREEN_SIZE: float = 20.0

# --- Stations (DESIGN.md §12) ---
const DOCK_REACH_FACTOR: float = 3.0       # dock_radius = this × the station's drawn radius at current zoom
const DOCK_RADIUS_MAX: float = 40.0        # px; caps dock_radius so zooming way out doesn't dock from across the map — ported from pygame config.py
const STATION_COUNTUP_TIME: float = 1.0    # seconds; station-screen credits count-up — DESIGN.md §12.3

# --- Upgrades and the shop (DESIGN.md §13) ---
const HUD_TEXT_COLOR: Color = Color(1.0, 1.0, 1.0)
const UPGRADE_UNAFFORDABLE_DIM: float = 0.4  # brightness multiplier for shop tiles you can't afford
const SHOP_GRID_COLUMNS: int = 6
const SHOP_GRID_TOP: float = 300.0         # px down to the first tile row
const SHOP_TILE_WIDTH: float = 160.0
const SHOP_TILE_HEIGHT: float = 85.0
const SHOP_TILE_GAP: float = 8.0
const SHOP_TILE_LINE_SPACING: float = 26.0
const SHOP_TILE_BORDER_COLOR: Color = Color(0.27, 0.27, 0.31)
const SHOP_TILE_BORDER_WIDTH: float = 1.0
const SHOP_TILE_SELECTED_COLOR: Color = Color(0.0, 1.0, 0.63)
const SHOP_TILE_SELECTED_WIDTH: float = 3.0
const SHOP_PROMPT_Y: float = 600.0
const STATION_TEXT_TOP: float = 36.0

# --- HUD and screens (DESIGN.md §15) ---
const HUD_MARGIN: float = 16.0       # px from the top-left corner — ported from pygame config.py
const HUD_LINE_HEIGHT: float = 20.0  # px between HUD lines — ported from pygame config.py
const ORE_HUD_UPDATE_INTERVAL: float = 1.0  # seconds between recounts of asteroid nodes left — §15.2
const STRIPPED_MESSAGE_TIME: float = 6.0    # seconds THE SYSTEM IS STRIPPED stays on screen
const STRIPPED_MESSAGE_COLOR: Color = Color(1.0, 0.235, 0.235)
const GAME_OVER_TOP: float = 140.0   # px down to the first line of the game-over screen

# --- Asteroids ---
const HEX_NODE_RADIUS: float = 12.0                    # px; hex cell size — DESIGN.md §7.1
const UNSCANNED_EDGE_COLOR: Color = Color(0.5, 0.5, 0.5)  # grey, before scanning — DESIGN.md §16.2
const DAMAGED_EDGE_BRIGHTEN: float = 0.35   # damaged nodes' edges blend this far toward white — §16.2
const NEAR_DEATH_HP_FRACTION: float = 0.25  # below this share of HP a node's edges pulse — §16.2
const NEAR_DEATH_PULSE_HZ: float = 4.0      # pulses/sec for a nearly destroyed node — §16.2

# --- System generation (DESIGN.md §7.4-7.9, §3.5) ---
const SYSTEM_SEED: int = 12345

# --- Levels (DESIGN.md §3.4) ---
# Each level is its own solar system, all at the same scale. main.gd reads
# LEVELS[level] straight (no pygame-style use_level() global-copying needed).
#   planets: Array of {"orbit_radius","phase"} (phase in degrees, like
#            pygame's config.PLANETS); planets[0] is home, where runs start
#            and competitors spawn/respawn. Every planet gets a station.
#   belts:   Array of {"inner","outer","count","kind"} (kind keys into
#            BELT_KINDS below), kept clear of every planet's gravity.
const LEVELS: Dictionary = {
	1: {
		"star_mass": 20000.0,            # ported from pygame config.py
		"star_gravity_radius": 3000.0,   # covers the whole system — ported from pygame config.py
		"zoom_min": 0.1,                 # ported from pygame config.py
		"comp_max": 5,                   # ported from pygame config.py (COMP_MAX_S1)
		"planets": [{"orbit_radius": 1000.0, "phase": 0.0}],
		# This port's own pre-existing belt tuning (outside the planet's
		# orbit, per DESIGN.md §3.4), not pygame's exact (1400, 2200, 20).
		"belts": [{"inner": 1500.0, "outer": 2200.0, "count": 15, "kind": "mixed"}],
	},
	2: {
		# Three planets spread round the star, each with a station; three
		# narrow belts between them — ported from pygame config.py.
		"star_mass": 20000.0,
		"star_gravity_radius": 6000.0,
		"zoom_min": 0.06,
		"comp_max": 10,
		"planets": [
			{"orbit_radius": 1000.0, "phase": 0.0},
			{"orbit_radius": 2600.0, "phase": 120.0},
			{"orbit_radius": 4200.0, "phase": 240.0},
		],
		"belts": [
			{"inner": 1700.0, "outer": 1900.0, "count": 45, "kind": "iron"},
			{"inner": 3300.0, "outer": 3500.0, "count": 60, "kind": "mixed"},
			{"inner": 4900.0, "outer": 5300.0, "count": 90, "kind": "rich"},
		],
	},
	3: {
		# Home far out, a dense belt hugging the star where rocks move
		# fast, and a low-value iron belt far out past home — ported from
		# pygame config.py.
		"star_mass": 20000.0,
		"star_gravity_radius": 3800.0,   # covers the outer belt
		"zoom_min": 0.07,
		"comp_max": 10,
		"planets": [{"orbit_radius": 1500.0, "phase": 0.0}],
		"belts": [
			{"inner": 150.0, "outer": 200.0, "count": 40, "kind": "vein_pebbles"},
			{"inner": 2900.0, "outer": 3100.0, "count": 30, "kind": "iron"},
		],
	},
}
const MAX_LEVEL: int = 3
const LEVEL_UP_BASE_COST: int = 1000  # jump cost from level n: this × the Fibonacci numbers from the second 1 (1, 2, 3, 5, 8...) — ported from pygame config.py

# What each belt "kind" is made of: size-class weights, and optionally its
# own profile weights (used instead of ASTEROID_PROFILE_WEIGHTS below).
# Any size can roll any profile — DESIGN.md §3.5.
const BELT_KINDS: Dictionary = {
	# Keeps this port's own pre-existing size tuning (not pygame's
	# 0.25/0.35) since "mixed" is already used and tuned for level 1.
	"mixed": {"sizes": {"pebble": 0.6, "small": 0.4}},
	"iron": {  # lots of plain iron rock — ported from pygame config.py
		"sizes": {"pebble": 0.3, "small": 0.7},
		"profiles": {"iron_slug": 0.85, "mixed_common": 0.15},
	},
	"vein_pebbles": {  # mostly pebbles, all veined: gem veins or deep veins — ported from pygame config.py
		"sizes": {"pebble": 0.8, "small": 0.2},
		"profiles": {"vein_gem": 0.5, "deep_vein": 0.5},
	},
	"rich": {  # small, valuable rocks — ported from pygame config.py
		"sizes": {"pebble": 0.8, "small": 0.2},
		"profiles": {"rich_core": 0.6, "jackpot": 0.4},
	},
}

# Size classes: radius in hex rings, and shape bulge amount — DESIGN.md §7.5.
const ASTEROID_RINGS: Dictionary = {"pebble": 2.0, "small": 4.0}
const ASTEROID_SHAPE_NOISE: Dictionary = {"pebble": 0.6, "small": 1.0}
const ASTEROID_NOISE_BUCKETS: int = 8

# Profile weights (DESIGN.md §7.6 table); carried over from this
# project's earlier system-gen-v2 planning doc.
const ASTEROID_PROFILE_WEIGHTS: Dictionary = {
	"iron_slug": 0.20, "mixed_common": 0.20, "copper_vein": 0.15, "rich_core": 0.12,
	"pocket_rock": 0.10, "deep_vein": 0.08, "hollow": 0.07, "layered_gem": 0.05,
	"vein_gem": 0.02, "jackpot": 0.01,
}

# Base matrix fills (DESIGN.md §7.6).
const MATRIX_IRON_SHARE: float = 0.7
const MATRIX_COPPER_SHARE: float = 0.6
const IRON_SLUG_IRON_SHARE: float = 0.9
const MIXED_COMMON_SHELL_FRAC: float = 0.7
const MIXED_COMMON_COPPER_FRAC: float = 0.35

const RICH_CORE_ALUMINUM_FRAC: float = 0.6
const RICH_CORE_FRAC_MIN: float = 0.15
const RICH_CORE_FRAC_MAX: float = 0.3
const RICH_CORE_RUNG_BOOST_MIN: int = 2
const RICH_CORE_RUNG_BOOST_MAX: int = 4

const LAYERED_GEM_FRACS: Array[float] = [0.25, 0.55, 0.8]  # core / titanium / copper thresholds, surface is iron

const JACKPOT_MATERIAL_WEIGHTS: Dictionary = {8: 1.0, 9: 1.0, 10: 1.0}  # gold, platinum, iridium

const HOLLOW_INTERIOR_FRAC: float = 0.35  # jump-depth fraction removed to make the gap

# Veins (DESIGN.md §7.6); fractions are shares of rock size.
const VEIN_START_DEPTH_FRACTION: float = 0.3
const VEIN_TURN: float = 0.5                # max heading wander per step, radians
const VEIN_MIN_LENGTH_FRAC: float = 0.3
const VEIN_MAX_LENGTH_FRAC: float = 0.8
const VEIN_MIN_WIDTH_FRAC: float = 0.05
const VEIN_MAX_WIDTH_FRAC: float = 0.12
const VEIN_MIN_RADIUS_NODES: float = 1.0
const VEIN_COUNTS: Dictionary = {"copper_vein": [1, 2], "deep_vein": [1, 2], "vein_gem": [1, 2]}

# Pockets (DESIGN.md §7.6); radius fractions are shares of rock size.
const POCKET_COUNT_MIN: int = 2
const POCKET_COUNT_MAX: int = 4
const POCKET_MIN_MAX_RADIUS_FRAC: Array[float] = [0.08, 0.18]
const POCKET_TITANIUM_MIN_MAX_RADIUS_FRAC: Array[float] = [0.05, 0.1]
const POCKET_EDGE_NOISE: float = 0.3
const POCKET_SURFACE_MARGIN_FRAC: float = 0.15
const POCKET_PLACEMENT_TRIES: int = 10

# Nuggets (DESIGN.md §7.7).
const NUGGET_COUNT: int = 2
const NUGGET_MATERIALS: Array[int] = [7, 8, 9, 10]  # silver..iridium

# Ore budget (DESIGN.md §7.8): fraction of the system's total nodes each
# material may occupy. Iron (unlisted) is unlimited.
const ORE_BUDGET: Dictionary = {
	2: 0.25, 3: 0.15, 4: 0.09, 5: 0.06, 6: 0.04, 7: 0.03, 8: 0.02, 9: 0.008, 10: 0.002,
}

# --- Mining (DESIGN.md §8-9) ---
const LASER_TIER: int = 1                 # starting tier; the "laser tier" upgrade raises this later
const HARDNESS_PENALTY_BASE: float = 2.0  # damage halves per rung of hardness above the laser tier — §8.1
const LASER_COUNT: int = 1                # bolts per volley; the "laser count" upgrade raises this later
const LASER_SPACING: float = 10.0         # px between parallel bolts in a volley
const FIRE_RATE: float = 3.0              # volleys/sec
const BOLT_SPEED: float = 500.0           # px/sec, relative to the ship — ported from pygame config.py
const BOLT_DAMAGE: float = 2.0
const BOLT_LIFETIME: float = 1.2          # seconds; the "mining_range" upgrade raises this later
const BOLT_HIT_RADIUS: float = 6.0        # px; capsule radius around each outline edge
const BOLT_TRAIL_LENGTH: float = 10.0     # px; purely visual
const BOLT_COLOR: Color = Color(1.0, 1.0, 0.4)
const SPARK_LIFETIME: float = 0.2         # seconds
const SPARK_DIM_FACTOR: float = 0.6       # darkened() amount for sparks on too-hard materials

# --- Bombs and shrapnel (DESIGN.md §9.3-9.4) ---
const BOMB_SPEED: float = 200.0          # px/sec, relative to the ship (slower than a bolt) — ported from pygame config.py
const BOMB_FUSE_TIME: float = 2.5        # seconds before an unspent bomb detonates anyway — ported from pygame config.py
const BOMB_COLOR: Color = Color(1.0, 0.706, 0.235)  # ported from pygame config.py (255, 180, 60)
const BOMB_DRAW_RADIUS: float = 4.0      # px; drawn dot size while in flight — ported from pygame config.py

const SHRAPNEL_SPEED: float = 300.0      # px/sec, world-frame (not relative to the ship) — ported from pygame config.py
const SHRAPNEL_DAMAGE: float = 1.0       # HP per shrapnel piece, before the hardness penalty — ported from pygame config.py
const SHRAPNEL_LIFETIME: float = 0.4     # seconds before an unspent shrapnel bolt despawns — ported from pygame config.py

# --- Ore and cargo (DESIGN.md §10) ---
# Cargo capacity itself is tiered now (game/upgrades.gd's "cargo_capacity"),
# starting at that table's tier 0 (20).
# Mined ore no longer goes straight to cargo: it floats loose, riding its
# asteroid's orbit, until the player taps it (or right-clicks it) to pull
# it in with the tractor beam.
# The beam reaches as far as the laser (mining range, see
# Upgrades.mining_range); holding the press keeps grabbing more ore,
# nearest to the ship first.
const TRACTOR_TAP_RADIUS: float = 48.0    # screen px; a press must land this close to in-range loose ore to start the beam
const TRACTOR_GRAB_INTERVAL: float = 0.15 # seconds between grabs while the press is held
const TRACTOR_SPEED: float = 250.0        # px/sec the beam reels ore in, on top of the ship's own speed
const TRACTOR_BEAM_COLOR: Color = Color(0.6, 1.0, 0.6)

# --- Scanning (DESIGN.md §11) ---
# Range, depth and width are tiered now (game/upgrades.gd's "scan_range",
# "scan_depth", "scan_width"), starting at that table's tier 0 values.
const SCAN_RAY_SPACING: float = 0.5       # node spacings between neighboring cone rays, at scan_range — DESIGN.md §11.2
const SCAN_PULSE_FLASH_TIME: float = 0.15 # seconds an automatic pulse's beam stays drawn — DESIGN.md §11.3
const SCAN_BEAM_COLOR: Color = Color(0.4, 1.0, 1.0)

# --- Look ---
const BG_COLOR: Color = Color(0, 0, 0)  # black background (also set as the project's default clear color)

# Thrust puffs (DESIGN.md §16.3); ported from pygame config.py. Purely
# visual exhaust, blown out opposite each thruster.
const THRUST_PUFF_COLOR: Color = Color(1.0, 0.78, 0.47)
const THRUST_PUFF_LIFETIME: float = 0.5        # seconds before a puff fades out completely
const THRUST_PUFF_RATE: float = 30.0           # puffs/sec at intensity 1
const THRUST_PUFF_MIN_RATE: float = 10.0       # puffs/sec floor, so weak thrust still shows a stream
const THRUST_PUFF_MAX_RATE: float = 60.0       # puffs/sec ceiling when zoomed far out
const THRUST_PUFF_SPEED: float = 140.0         # world units/sec relative to the ship, at intensity 1
const THRUST_PUFF_RADIUS: float = 8.0          # world units when spawned, at intensity 1
const THRUST_PUFF_GROWTH: float = 0.75         # extra size gained by the end of its life (0.75 = +75%)
const THRUST_PUFF_SPREAD: float = 0.35         # radians of random scatter either side of straight back
const THRUST_PUFF_OFFSET: float = 9.0          # world units from the ship's center to where puffs appear
const THRUST_PUFF_MIN_SCREEN_RADIUS: float = 1.0  # screen px, so puffs never vanish when drawn
const THRUST_PUFF_MAX_SCREEN_RADIUS: float = 5.0  # screen px, so upgraded engines don't bury the ship

# --- Competitors (DESIGN.md §14); ported from pygame config.py ---
# The live-count cap is per level now (LEVELS[level].comp_max above);
# main.gd caches it into `comp_max` when the system is (re)built.
const COMP_SPAWN_INTERVAL_S1: float = 90.0     # seconds before the first spawns
const COMP_SPAWN_INTERVAL_STEP: float = 10.0   # each later gap is this much shorter...
const COMP_SPAWN_INTERVAL_MIN: float = 20.0    # ...down to this floor
const COMP_MAX_BURN_DV: float = 4.0        # max velocity change per tick
const COMP_ARRIVAL_GAIN: float = 0.8       # closing speed = gain * sqrt(2 * max accel * distance)
const COMP_MINE_RATE: float = 4.0          # laser hits per second, tier 0
const COMP_MINE_RANGE: float = 30.0        # world units from the competitor to the edge midpoint it mines
const COMP_MINE_STANDOFF: float = 18.0     # world units they try to hover from the nearest outline edge's midpoint
const COMP_LASER_TIER: int = 1             # tier 0 laser tier for effective_damage()
const COMP_MAX_HARDNESS_GAP: int = 2       # skip edges whose owner is more than this many rungs harder than their laser
const COMP_CARGO_CAP: int = 5              # ore units per cargo trip, tier 0
const COMP_SCAN_DEPTH: int = 3             # Prospector/Scavenger scan depth
const COMP_RUSHER_SCAN_DEPTH: int = 1      # Rusher/Hauler scan depth (surface only)
const COMP_SCAN_PULSE_INTERVAL: float = 1.0  # seconds between automatic scan pulses
const COMP_ARCHETYPE_WEIGHTS_S1: Array[float] = [1.0, 3.0, 4.0, 1.0]  # [prospector, hauler, rusher, scavenger]
const COMP_HOLD_GAIN: float = 2.0          # 1/sec: close in, closing speed = gain * distance
const COMP_AVOID_MARGIN: float = 1.5       # radii kept clear of the star/planets/nearby rocks
const COMP_DETOUR_STEP: float = 45.0       # degrees round the circle each detour waypoint sits ahead
const COMP_ROCK_AVOID_RANGE: float = 400.0     # rocks closer than this are steered round too...
const COMP_ROCK_AVOID_LOOKAHEAD: float = 1.0   # ...plus this many seconds of travel
const COMP_HEADING_MIN_DV: float = 0.4     # burns smaller than this are strafes; they don't turn the ship
const COMP_UPGRADES: Array[String] = ["laser_tier", "fire_rate", "cargo_capacity", "engine_power"]
const COMP_COLOR: Color = Color(1.0, 0.4, 0.0)  # amber; all competitors share it

# --- Debug keys (DESIGN.md §17) ---
const DEBUG_KEYS_ENABLED: bool = true  # F1 reveals every asteroid edge; F2 toggles unlimited credits — ported from pygame config.py
const DEBUG_CREDITS: int = 1_000_000   # what unlimited credits keeps you topped up to — ported from pygame config.py
