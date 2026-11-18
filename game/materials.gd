extends RefCounted
class_name Materials
# game/materials.gd — the ten-material table (DESIGN.md §8): identity,
# value, HP and color. Hardness equals the rung (id); the hardness
# penalty itself is Projectiles.effective_damage(). All numbers are
# starting points to tune in playtesting.

const IRON: int = 1
const ALUMINUM: int = 2
const COPPER: int = 3
const LITHIUM: int = 4
const TITANIUM: int = 5
const TUNGSTEN: int = 6
const SILVER: int = 7
const GOLD: int = 8
const PLATINUM: int = 9
const IRIDIUM: int = 10

# Value doubles each rung; HP grows roughly x1.5 each rung — DESIGN.md §8.
# Placeholder numbers throughout; tune by playing.
static var TABLE: Dictionary = {
	# Colors are the original project's palette (design.md / MVP.md).
	IRON:     {"value": 1,   "hp": 2.0,  "color": Color("#FF4422")},  # rust red
	ALUMINUM: {"value": 2,   "hp": 3.0,  "color": Color("#7799CC")},  # steel blue
	COPPER:   {"value": 4,   "hp": 5.0,  "color": Color("#FF8833")},  # copper orange
	LITHIUM:  {"value": 8,   "hp": 8.0,  "color": Color("#99FF55")},  # light green
	TITANIUM: {"value": 16,  "hp": 12.0, "color": Color("#44DDFF")},  # cyan
	TUNGSTEN: {"value": 32,  "hp": 18.0, "color": Color("#8855FF")},  # violet
	SILVER:   {"value": 64,  "hp": 27.0, "color": Color("#E6E6F0")},  # silver-white
	GOLD:     {"value": 128, "hp": 40.0, "color": Color("#FFD700")},  # gold
	PLATINUM: {"value": 256, "hp": 60.0, "color": Color("#66FFAA")},  # mint
	IRIDIUM:  {"value": 512, "hp": 90.0, "color": Color("#FFFFFF")},  # white
}

static func value(id: int) -> int:
	return TABLE[id]["value"]

static func hp(id: int) -> float:
	return TABLE[id]["hp"]

static func color(id: int) -> Color:
	return TABLE[id]["color"]

static func hardness(id: int) -> int:
	return id  # DESIGN.md §8: "Hardness equals the id"

const NAMES: Dictionary = {
	IRON: "Iron", ALUMINUM: "Aluminum", COPPER: "Copper", LITHIUM: "Lithium",
	TITANIUM: "Titanium", TUNGSTEN: "Tungsten", SILVER: "Silver", GOLD: "Gold",
	PLATINUM: "Platinum", IRIDIUM: "Iridium",
}

static func name_of(id: int) -> String:
	return NAMES.get(id, "?")
