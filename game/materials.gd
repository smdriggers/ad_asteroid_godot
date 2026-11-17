extends RefCounted
class_name Materials
# game/materials.gd — the ten-material table (DESIGN.md §8): identity,
# value and HP for generation to use, plus color for rendering once
# scanning exists. Hardness-penalty damage math (effective_damage)
# arrives with mining, a later milestone.

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
	IRON:     {"value": 1,   "hp": 2.0,  "color": Color(0.8, 0.3, 0.2)},
	ALUMINUM: {"value": 2,   "hp": 3.0,  "color": Color(0.7, 0.75, 0.8)},
	COPPER:   {"value": 4,   "hp": 5.0,  "color": Color(0.85, 0.5, 0.2)},
	LITHIUM:  {"value": 8,   "hp": 8.0,  "color": Color(0.6, 0.9, 1.0)},
	TITANIUM: {"value": 16,  "hp": 12.0, "color": Color(0.5, 0.5, 0.6)},
	TUNGSTEN: {"value": 32,  "hp": 18.0, "color": Color(0.4, 0.4, 0.5)},
	SILVER:   {"value": 64,  "hp": 27.0, "color": Color(0.85, 0.85, 0.9)},
	GOLD:     {"value": 128, "hp": 40.0, "color": Color(1.0, 0.85, 0.2)},
	PLATINUM: {"value": 256, "hp": 60.0, "color": Color(0.8, 0.9, 1.0)},
	IRIDIUM:  {"value": 512, "hp": 90.0, "color": Color(0.9, 0.95, 1.0)},
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
