extends RefCounted
class_name Cargo
# game/cargo.gd — ore cargo, counted per material and capped in total
# (DESIGN.md §10). Loose-ore overflow and pickup live in main.gd, since
# they need an asteroid's orbiting view to ride along with.

var counts: Dictionary = {}  # material id -> int
var total: int = 0
var blocks_mined: int = 0    # every node removed, whether or not it fit in cargo
var blocks_mined_by_material: Dictionary = {}  # material id -> int; game-over breakdown (DESIGN.md §15.4)
var capacity: int = 20       # tier 0 of the "cargo_capacity" upgrade (DESIGN.md §13.1); main.gd keeps this in sync

func room() -> int:
	return capacity - total

func add(material: int) -> bool:
	# Returns true if it fit in cargo, false if cargo is full (caller
	# should make it loose ore instead).
	if total >= capacity:
		return false
	counts[material] = counts.get(material, 0) + 1
	total += 1
	return true

func record_mined(material: int) -> void:
	blocks_mined += 1
	blocks_mined_by_material[material] = blocks_mined_by_material.get(material, 0) + 1
