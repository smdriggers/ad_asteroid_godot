extends RefCounted
class_name CompetitorGroup
# game/competitor_group.gd — the shared wallet and upgrade tiers for every
# competitor (DESIGN.md §14.7), ported from pygame's CompetitorGroup. Uses
# the player's tier tables and prices (game/upgrades.gd).

var credits: int = 0
var upgrade_tiers: Dictionary = {}

func _init() -> void:
	for stat_name in Config.COMP_UPGRADES:
		upgrade_tiers[stat_name] = 0

func deposit(amount: int) -> void:
	# Adds sale credits, then buys the cheapest affordable next tier,
	# again and again, until nothing more is affordable. Ties go to the
	# earlier name in Config.COMP_UPGRADES.
	credits += amount
	while true:
		var best_name = null
		var best_cost = null
		for stat_name in Config.COMP_UPGRADES:
			var cost = Upgrades.next_cost(stat_name, upgrade_tiers[stat_name])
			if cost != null and cost <= credits:
				if best_cost == null or cost < best_cost:
					best_cost = cost
					best_name = stat_name
		if best_name == null:
			return
		Upgrades.purchase(self, best_name)

func _value(stat_name: String):
	return Upgrades.value_at(stat_name, upgrade_tiers[stat_name])

func _ratio(stat_name: String) -> float:
	# How many times the tier-0 value the current tier gives.
	return float(_value(stat_name)) / float(Upgrades.value_at(stat_name, 0))

func laser_tier() -> int:
	return Config.COMP_LASER_TIER + _value("laser_tier") - Upgrades.value_at("laser_tier", 0)

func mine_rate() -> float:
	return Config.COMP_MINE_RATE * _ratio("fire_rate")

func cargo_capacity() -> int:
	return int(round(Config.COMP_CARGO_CAP * _ratio("cargo_capacity")))

func max_burn_dv() -> float:
	return Config.COMP_MAX_BURN_DV * _ratio("engine_power")
