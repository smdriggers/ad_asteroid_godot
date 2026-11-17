extends RefCounted
class_name Upgrades
# game/upgrades.gd — tiered ship upgrades (DESIGN.md §13.1), ported
# straight from the pygame project's game/upgrades.py. Tier 0 is each
# stat's starting value (free); each further tier costs the next entry
# in "costs", paid from credits. Placeholder progressions throughout —
# tune by playing.

const UPGRADES: Dictionary = {
	"laser_count": {
		"values": [1, 2, 3, 4, 5, 6],
		"costs": [50, 150, 400, 1000, 2500],
	},
	"fire_rate": {
		"values": [8.0, 10.0, 12.0, 14.0, 17.0, 20.0, 24.0],
		"costs": [40, 100, 200, 450, 1000, 2200],
	},
	# Caps at 10 to match the highest material hardness (Iridium): a
	# fully upgraded laser removes the hardness penalty against anything.
	"laser_tier": {
		"values": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
		"costs": [80, 200, 400, 800, 1600, 3200, 6400, 12800, 25600],
	},
	"range": {
		"values": [1.2, 1.6, 2.0, 2.4, 3.0, 3.6, 4.4],
		"costs": [30, 80, 150, 350, 800, 1800],
	},
	"cargo_capacity": {
		"values": [20, 30, 40, 50, 60, 70, 80, 90, 100, 150, 220, 320, 480],
		"costs": [40, 60, 80, 100, 120, 140, 160, 180, 400, 900, 2000, 4500],
	},
	"engine_power": {  # multiplies Config.THRUST_ACCEL in every direction
		"values": [1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0],
		"costs": [60, 150, 350, 800, 1800, 4000],
	},
	"scan_depth": {  # edges each scan ray reveals; 1 is the outline only
		"values": [1, 2, 3, 4, 6, 8, 12],
		"costs": [80, 200, 500, 1200, 2800, 6000],
	},
	"scan_range": {  # world units the scan reaches from the ship
		"values": [600.0, 800.0, 1000.0, 1300.0, 1700.0, 2200.0],
		"costs": [40, 100, 250, 600, 1400],
	},
	"scan_width": {  # full angle of the scan in degrees; 0 is a single line
		"values": [0.0, 5.0, 10.0, 20.0, 35.0, 60.0, 90.0],
		"costs": [60, 150, 350, 800, 1800, 4000],
	},
	"scan_pulse": {  # seconds between automatic scans; null is off
		"values": [null, 8.0, 6.0, 4.0, 3.0, 2.0, 1.0],
		"costs": [150, 300, 700, 1500, 3200, 7000],
	},
	# Bombs themselves are bought one at a time (BOMB_COST below), not a
	# tiered stat; these four shape every bomb the ship fires.
	"bomb_radius": {
		"values": [20.0, 30.0, 40.0, 55.0, 75.0, 100.0],
		"costs": [100, 250, 600, 1400, 3200],
	},
	"bomb_damage": {
		"values": [10.0, 15.0, 20.0, 30.0, 45.0, 65.0],
		"costs": [100, 250, 600, 1400, 3200],
	},
	"bomb_rate": {  # seconds between shots; lower is faster
		"values": [2.0, 1.5, 1.0, 0.7, 0.5, 0.35],
		"costs": [100, 250, 600, 1400, 3200],
	},
	"bomb_shrapnel": {  # mini-bolts sprayed on detonation
		"values": [0, 4, 8, 16, 32],
		"costs": [150, 300, 800, 2000],
	},
}

const LABELS: Dictionary = {
	"laser_count": "Laser count",
	"fire_rate": "Fire rate",
	"laser_tier": "Laser tier",
	"range": "Range",
	"cargo_capacity": "Cargo capacity",
	"engine_power": "Engine power",
	"scan_depth": "Scan depth",
	"scan_range": "Scan range",
	"scan_width": "Scan width",
	"scan_pulse": "Scan pulse",
	"bomb_radius": "Bomb radius",
	"bomb_damage": "Bomb damage",
	"bomb_rate": "Bomb rate of fire",
	"bomb_shrapnel": "Bomb shrapnel",
}

const BOMB_COST: int = 50  # credits per bomb; placeholder, tune by playing
const BUY_BOMB_TILE: String = "buy_bomb"
const LEVEL_UP_TILE: String = "level_up"

# DESIGN.md §13.4 grid order — the jump tile is last.
const SHOP_TILES: Array[String] = [
	"laser_count", "fire_rate", "laser_tier", "range", "cargo_capacity",
	"engine_power", "scan_depth", "scan_range", "scan_width", "scan_pulse",
	BUY_BOMB_TILE, "bomb_radius", "bomb_damage", "bomb_rate", "bomb_shrapnel",
	LEVEL_UP_TILE,
]

static func level_up_cost(level: int) -> int:
	# DESIGN.md §13.3: LEVEL_UP_BASE_COST x the Fibonacci numbers from the
	# second 1 (1, 2, 3, 5, 8...), so jumping from level `level` costs more
	# each time. Ported from pygame's station.level_up_cost.
	var a: int = 1
	var b: int = 1
	for i in range(level - 1):
		var next_b: int = a + b
		a = b
		b = next_b
	return Config.LEVEL_UP_BASE_COST * b

static func value_at(name: String, tier: int):
	return UPGRADES[name]["values"][tier]

static func max_tier(name: String) -> int:
	return UPGRADES[name]["values"].size() - 1

static func next_cost(name: String, tier: int):
	# Cost to go from `tier` to `tier + 1`, or null if already maxed.
	var costs: Array = UPGRADES[name]["costs"]
	if tier >= costs.size():
		return null
	return costs[tier]

static func purchase(entity, name: String) -> bool:
	# Spends credits to raise entity's tier for `name` by one. `entity`
	# just needs .credits and .upgrade_tiers[name] (Ship or
	# CompetitorGroup both qualify) — DESIGN.md §14.7. Returns whether it
	# succeeded.
	var tier: int = entity.upgrade_tiers[name]
	var cost = next_cost(name, tier)
	if cost == null or entity.credits < cost:
		return false
	entity.credits -= cost
	entity.upgrade_tiers[name] = tier + 1
	return true

static func move_selection(index: int, dx: int, dy: int) -> int:
	# Index of the tile one step from `index`. Stops at the grid's edges;
	# moving down into a shorter last row lands on its final tile —
	# DESIGN.md §13.4.
	var columns: int = Config.SHOP_GRID_COLUMNS
	var last: int = SHOP_TILES.size() - 1
	var row: int = clampi(index / columns + dy, 0, last / columns)
	var column: int = clampi(index % columns + dx, 0, columns - 1)
	return min(row * columns + column, last)
