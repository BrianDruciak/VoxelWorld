extends Node

var stash: Dictionary = {}
var purchased: Dictionary = {}

# Costs now use new common ores (18=CopperOre, 19=IronOre) for early tiers
# and rare ores for advanced tiers
const UPGRADES: Array[Dictionary] = [
	{
		"id": "tough_skin",
		"name": "Tough Skin",
		"description": "+20 max HP per level",
		"costs": {18: 5, 19: 3},
		"max_level": 5,
		"stat": "max_health",
		"per_level": 20.0,
	},
	{
		"id": "swift_feet",
		"name": "Swift Feet",
		"description": "+1 walk speed, +2 sprint per level",
		"costs": {18: 4, 14: 2},
		"max_level": 3,
		"stat": "swift_feet",
		"per_level": 1.0,
	},
	{
		"id": "strong_legs",
		"name": "Strong Legs",
		"description": "+0.8 jump velocity per level",
		"costs": {19: 5, 20: 2},
		"max_level": 3,
		"stat": "jump_velocity",
		"per_level": 0.8,
	},
	{
		"id": "cold_resist",
		"name": "Cold Resist",
		"description": "-33% frozen zone damage per level",
		"costs": {15: 2, 21: 1},
		"max_level": 3,
		"stat": "frozen_resist",
		"per_level": -0.33,
	},
	{
		"id": "heat_resist",
		"name": "Heat Resist",
		"description": "-33% scorched zone damage per level",
		"costs": {16: 2, 22: 1},
		"max_level": 3,
		"stat": "scorched_resist",
		"per_level": -0.33,
	},
	{
		"id": "void_ward",
		"name": "Void Ward",
		"description": "-33% void zone damage per level",
		"costs": {17: 3},
		"max_level": 3,
		"stat": "void_resist",
		"per_level": -0.33,
	},
	{
		"id": "long_reach",
		"name": "Long Reach",
		"description": "+1.5 block reach per level",
		"costs": {14: 3, 20: 2},
		"max_level": 2,
		"stat": "reach",
		"per_level": 1.5,
	},
	{
		"id": "safe_haven",
		"name": "Safe Haven",
		"description": "Slowly regenerate HP in the safe zone",
		"costs": {17: 5, 16: 3, 22: 2},
		"max_level": 1,
		"stat": "safe_regen",
		"per_level": 1.0,
	},
]


func load_state(data: Dictionary) -> void:
	stash = data.get("stash", {})
	purchased = data.get("purchased", {})
	var fixed_stash: Dictionary = {}
	for k in stash:
		fixed_stash[int(k)] = int(stash[k])
	stash = fixed_stash


func get_save_data() -> Dictionary:
	return {"stash": stash, "purchased": purchased}


func get_upgrade_definitions() -> Array:
	var result: Array = []
	for u in UPGRADES:
		result.append(u)
	return result


func add_to_stash(ore_id: int, count: int) -> void:
	if not stash.has(ore_id):
		stash[ore_id] = 0
	stash[ore_id] += count


func try_purchase(upgrade_id: String) -> bool:
	var upgrade: Dictionary = _find_upgrade(upgrade_id)
	if upgrade.is_empty():
		return false

	var cur_level: int = purchased.get(upgrade_id, 0)
	if cur_level >= upgrade["max_level"]:
		return false

	var costs: Dictionary = upgrade["costs"]
	for ore_id in costs:
		var need: int = costs[ore_id]
		var have: int = stash.get(ore_id, 0)
		if have < need:
			return false

	for ore_id in costs:
		stash[ore_id] -= costs[ore_id]
		if stash[ore_id] <= 0:
			stash.erase(ore_id)

	purchased[upgrade_id] = cur_level + 1
	return true


func get_all_stats() -> Dictionary:
	var stats: Dictionary = {
		"max_health": 100.0,
		"walk_speed": 5.0,
		"sprint_speed": 10.0,
		"jump_velocity": 6.0,
		"reach": 6.0,
		"wild_resist": 1.0,
		"frozen_resist": 1.0,
		"scorched_resist": 1.0,
		"void_resist": 1.0,
		"safe_regen": false,
	}

	for u in UPGRADES:
		var level: int = purchased.get(u["id"], 0)
		if level <= 0:
			continue

		var stat_key: String = u["stat"]
		var per_level: float = u["per_level"]

		match stat_key:
			"swift_feet":
				stats["walk_speed"] += level * per_level
				stats["sprint_speed"] += level * per_level * 2.0
			"frozen_resist", "scorched_resist", "void_resist":
				stats[stat_key] = maxf(stats[stat_key] + level * per_level, 0.01)
			"safe_regen":
				stats["safe_regen"] = true
			_:
				stats[stat_key] += level * per_level

	return stats


func _find_upgrade(upgrade_id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == upgrade_id:
			return u
	return {}
