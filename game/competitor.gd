extends Ship
class_name Competitor
# game/competitor.gd — one AI ship (DESIGN.md §14). A full physics body
# like the player's, plus archetype/target/cargo state. The actual
# steering/mining/scanning logic lives in game/competitors.gd (pure
# functions, ported from pygame's game/competitors.py) so this file stays
# just the per-instance state.

const PROSPECTOR: String = "prospector"
const HAULER: String = "hauler"
const RUSHER: String = "rusher"
const SCAVENGER: String = "scavenger"
const ARCHETYPES: Array[String] = [PROSPECTOR, HAULER, RUSHER, SCAVENGER]  # order matches COMP_ARCHETYPE_WEIGHTS_S1

const OUTBOUND: String = "outbound"    # flying to a target asteroid
const MINING: String = "mining"        # hovering at the target, cutting its nodes
const RETURNING: String = "returning"  # flying home to sell
const IDLE: String = "idle"            # nothing left worth mining; waits at the station

var archetype: String = ""
var group: CompetitorGroup = null
var state: String = IDLE
var target = null          # asteroid entry {"view": Node2D, "orbit": OrbitBody}, or null
var mine_timer: float = 0.0
var scan_timer: float = 0.0
var tractor_timer: float = 0.0
var bolts: Array = []           # this competitor's laser bolts in flight; stepped by main.gd
var hold_offset = null     # Vector2 from the target rock they're firing from, once in laser reach; null = not holding
var hold_rock: Node2D = null  # the rock hold_offset is relative to
var too_hard: Dictionary = {}   # view (Node2D) -> laser tier it was too hard at
var cargo: Dictionary = {}      # material id -> unit count

func cargo_used() -> int:
	var total: int = 0
	for count in cargo.values():
		total += count
	return total

func cargo_capacity() -> int:
	return group.cargo_capacity()

func laser_tier() -> int:
	return group.laser_tier()

func scan_depth() -> int:
	if archetype == PROSPECTOR or archetype == SCAVENGER:
		return Config.COMP_SCAN_DEPTH
	return Config.COMP_RUSHER_SCAN_DEPTH

func max_hardness() -> int:
	# The hardest material worth cutting — DESIGN.md §14.5.
	return laser_tier() + Config.COMP_MAX_HARDNESS_GAP

func add_to_cargo(material: int) -> bool:
	if cargo_used() >= cargo_capacity():
		return false
	cargo[material] = cargo.get(material, 0) + 1
	return true
