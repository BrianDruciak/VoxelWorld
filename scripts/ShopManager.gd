extends Node

# Tool listings: item_id, costs (ore_id -> count), qty (always 1 for tools)
const TOOL_LISTINGS: Array[Dictionary] = [
	{"item_id": 1001, "costs": {18: 5, 19: 3}, "qty": 1},  # Stone Pickaxe
	{"item_id": 1011, "costs": {18: 3, 19: 2}, "qty": 1},  # Stone Shovel
	{"item_id": 1002, "costs": {14: 3, 20: 2}, "qty": 1},  # Crystal Pickaxe
	{"item_id": 1012, "costs": {14: 2, 20: 1}, "qty": 1},  # Crystal Shovel
	{"item_id": 1003, "costs": {15: 3, 21: 2}, "qty": 1},  # Frost Pickaxe
	{"item_id": 1013, "costs": {15: 2, 21: 1}, "qty": 1},  # Frost Shovel
	{"item_id": 1004, "costs": {16: 3, 22: 2}, "qty": 1},  # Ember Pickaxe
	{"item_id": 1014, "costs": {16: 2, 22: 1}, "qty": 1},  # Ember Shovel
	{"item_id": 1005, "costs": {17: 3, 22: 2}, "qty": 1},  # Void Pickaxe
	{"item_id": 1015, "costs": {17: 2, 22: 1}, "qty": 1},  # Void Shovel
]

# Supply listings: item_id (block), costs, qty given
const SUPPLY_LISTINGS: Array[Dictionary] = [
	{"item_id": 1, "costs": {18: 2}, "qty": 16},  # Stone x16
	{"item_id": 2, "costs": {18: 1}, "qty": 16},  # Dirt x16
	{"item_id": 6, "costs": {19: 2}, "qty": 16},  # Snow x16
	{"item_id": 11, "costs": {16: 2}, "qty": 8},   # Obsidian x8
]

# Purchased items waiting to be added to inventory at run start
var pending_items: Array[Dictionary] = []


func get_tool_listings() -> Array:
	var result: Array = []
	for l in TOOL_LISTINGS:
		result.append(l)
	return result


func get_supply_listings() -> Array:
	var result: Array = []
	for l in SUPPLY_LISTINGS:
		result.append(l)
	return result


func try_purchase(item_id: int, stash: Dictionary) -> bool:
	var listing: Dictionary = _find_listing(item_id)
	if listing.is_empty():
		return false

	var costs: Dictionary = listing.get("costs", {})
	for ore_id in costs:
		var need: int = costs[ore_id]
		var have: int = stash.get(ore_id, 0)
		if have < need:
			return false

	# Deduct costs from stash
	for ore_id in costs:
		stash[ore_id] -= costs[ore_id]
		if stash[ore_id] <= 0:
			stash.erase(ore_id)

	# Queue item for pickup
	var qty: int = listing.get("qty", 1)
	pending_items.append({"item_id": item_id, "qty": qty})
	return true


func apply_pending_to_inventory(inv: Inventory) -> void:
	for item in pending_items:
		var item_id: int = item.get("item_id", 0)
		var qty: int = item.get("qty", 1)
		if ItemDB.is_tool_item(item_id):
			inv.add_item(item_id, 1)
		else:
			inv.add_item(item_id, qty)
	pending_items.clear()


func _find_listing(item_id: int) -> Dictionary:
	for l in TOOL_LISTINGS:
		if l.get("item_id", -1) == item_id:
			return l
	for l in SUPPLY_LISTINGS:
		if l.get("item_id", -1) == item_id:
			return l
	return {}
