extends RefCounted
class_name ItemDB

const TOOL_ID_BASE := 1000

# Block IDs 0-22 match C# BlockID enum
# Tool IDs 1000+ are GDScript-only items

# --- Block hardness (seconds at 1.0 mining speed) ---
static var block_hardness: Dictionary = {
	1: 1.5,   # Stone
	2: 0.5,   # Dirt
	3: 0.75,  # Grass
	4: 0.5,   # Sand
	5: 0.0,   # Water (not minable)
	6: 0.5,   # Snow
	7: 1.0,   # Ice
	8: 0.75,  # DarkGrass
	9: 0.75,  # DarkDirt
	10: 2.0,  # Basalt
	11: 3.0,  # Obsidian
	12: 0.0,  # Lava (not minable)
	13: 0.5,  # Ash
	14: 2.0,  # WildCrystal
	15: 2.5,  # Frostite
	16: 3.0,  # Embersite
	17: 4.0,  # VoidShard
	18: 1.5,  # CopperOre
	19: 1.5,  # IronOre
	20: 2.0,  # Thornite
	21: 2.5,  # GlacialGem
	22: 3.0,  # MagmaCore
}

# "pickaxe" or "shovel" - determines which tool type gets bonus speed
static var block_tool_affinity: Dictionary = {
	1: "pickaxe",  # Stone
	2: "shovel",   # Dirt
	3: "shovel",   # Grass
	4: "shovel",   # Sand
	6: "shovel",   # Snow
	7: "pickaxe",  # Ice
	8: "shovel",   # DarkGrass
	9: "shovel",   # DarkDirt
	10: "pickaxe", # Basalt
	11: "pickaxe", # Obsidian
	13: "shovel",  # Ash
	14: "pickaxe", # WildCrystal
	15: "pickaxe", # Frostite
	16: "pickaxe", # Embersite
	17: "pickaxe", # VoidShard
	18: "pickaxe", # CopperOre
	19: "pickaxe", # IronOre
	20: "pickaxe", # Thornite
	21: "pickaxe", # GlacialGem
	22: "pickaxe", # MagmaCore
}

# --- Tool definitions ---
# {id: {name, tool_type, mining_speed, max_durability, tier, color}}
static var tools: Dictionary = {
	1000: {"name": "Wood Pickaxe",    "tool_type": "pickaxe", "mining_speed": 1.0,  "max_durability": 60,   "tier": "Wood",    "color": Color(0.55, 0.35, 0.15), "icon": "P"},
	1001: {"name": "Stone Pickaxe",   "tool_type": "pickaxe", "mining_speed": 2.0,  "max_durability": 130,  "tier": "Stone",   "color": Color(0.5, 0.5, 0.5),    "icon": "P"},
	1002: {"name": "Crystal Pickaxe", "tool_type": "pickaxe", "mining_speed": 3.5,  "max_durability": 250,  "tier": "Crystal", "color": Color(0.6, 0.2, 0.8),    "icon": "P"},
	1003: {"name": "Frost Pickaxe",   "tool_type": "pickaxe", "mining_speed": 5.0,  "max_durability": 500,  "tier": "Frost",   "color": Color(0.3, 0.75, 0.95),  "icon": "P"},
	1004: {"name": "Ember Pickaxe",   "tool_type": "pickaxe", "mining_speed": 7.0,  "max_durability": 1000, "tier": "Ember",   "color": Color(0.95, 0.4, 0.1),   "icon": "P"},
	1005: {"name": "Void Pickaxe",    "tool_type": "pickaxe", "mining_speed": 10.0, "max_durability": 2000, "tier": "Void",    "color": Color(0.2, 0.05, 0.3),   "icon": "P"},
	1010: {"name": "Wood Shovel",     "tool_type": "shovel",  "mining_speed": 1.0,  "max_durability": 60,   "tier": "Wood",    "color": Color(0.55, 0.35, 0.15), "icon": "S"},
	1011: {"name": "Stone Shovel",    "tool_type": "shovel",  "mining_speed": 2.0,  "max_durability": 130,  "tier": "Stone",   "color": Color(0.5, 0.5, 0.5),    "icon": "S"},
	1012: {"name": "Crystal Shovel",  "tool_type": "shovel",  "mining_speed": 3.5,  "max_durability": 250,  "tier": "Crystal", "color": Color(0.6, 0.2, 0.8),    "icon": "S"},
	1013: {"name": "Frost Shovel",    "tool_type": "shovel",  "mining_speed": 5.0,  "max_durability": 500,  "tier": "Frost",   "color": Color(0.3, 0.75, 0.95),  "icon": "S"},
	1014: {"name": "Ember Shovel",    "tool_type": "shovel",  "mining_speed": 7.0,  "max_durability": 1000, "tier": "Ember",   "color": Color(0.95, 0.4, 0.1),   "icon": "S"},
	1015: {"name": "Void Shovel",     "tool_type": "shovel",  "mining_speed": 10.0, "max_durability": 2000, "tier": "Void",    "color": Color(0.2, 0.05, 0.3),   "icon": "S"},
}

# --- Block item display ---
static var block_names: Dictionary = {
	0: "Air", 1: "Stone", 2: "Dirt", 3: "Grass", 4: "Sand", 5: "Water",
	6: "Snow", 7: "Ice", 8: "DarkGrass", 9: "DarkDirt", 10: "Basalt",
	11: "Obsidian", 12: "Lava", 13: "Ash",
	14: "Wild Crystal", 15: "Frostite", 16: "Embersite", 17: "Void Shard",
	18: "Copper Ore", 19: "Iron Ore", 20: "Thornite", 21: "Glacial Gem", 22: "Magma Core",
}

static var block_colors: Dictionary = {
	1: Color(0.50, 0.50, 0.50),   # Stone
	2: Color(0.55, 0.36, 0.20),   # Dirt
	3: Color(0.30, 0.65, 0.20),   # Grass
	4: Color(0.86, 0.80, 0.55),   # Sand
	5: Color(0.20, 0.40, 0.80),   # Water
	6: Color(0.92, 0.95, 0.97),   # Snow
	7: Color(0.70, 0.85, 0.95),   # Ice
	8: Color(0.15, 0.35, 0.10),   # DarkGrass
	9: Color(0.30, 0.20, 0.10),   # DarkDirt
	10: Color(0.25, 0.25, 0.28),  # Basalt
	11: Color(0.10, 0.08, 0.12),  # Obsidian
	12: Color(0.90, 0.30, 0.00),  # Lava
	13: Color(0.40, 0.38, 0.35),  # Ash
	14: Color(0.6, 0.2, 0.8),     # WildCrystal
	15: Color(0.3, 0.85, 0.95),   # Frostite
	16: Color(0.95, 0.4, 0.15),   # Embersite
	17: Color(0.15, 0.05, 0.2),   # VoidShard
	18: Color(0.72, 0.45, 0.20),  # CopperOre
	19: Color(0.55, 0.55, 0.60),  # IronOre
	20: Color(0.20, 0.55, 0.15),  # Thornite
	21: Color(0.65, 0.80, 0.95),  # GlacialGem
	22: Color(0.70, 0.15, 0.10),  # MagmaCore
}

# All ore IDs (minable resources the player collects)
static var ORE_IDS: Array[int] = [14, 15, 16, 17, 18, 19, 20, 21, 22]

const BARE_HANDS_SPEED := 0.5
const WRONG_TOOL_MULT := 0.25

static func is_tool_item(item_id: int) -> bool:
	return item_id >= TOOL_ID_BASE

static func is_block(item_id: int) -> bool:
	return item_id > 0 and item_id < TOOL_ID_BASE

static func is_ore(item_id: int) -> bool:
	return item_id in ORE_IDS

static func get_stack_size(item_id: int) -> int:
	if is_tool_item(item_id):
		return 1
	return 64

static func get_item_name(item_id: int) -> String:
	if is_tool_item(item_id):
		var t: Dictionary = tools.get(item_id, {})
		return t.get("name", "Unknown Tool")
	return block_names.get(item_id, "Unknown")

static func get_item_color(item_id: int) -> Color:
	if is_tool_item(item_id):
		var t: Dictionary = tools.get(item_id, {})
		return t.get("color", Color(0.5, 0.5, 0.5))
	return block_colors.get(item_id, Color(0.3, 0.3, 0.3))

static func get_mining_time(block_id: int, held_item_id: int) -> float:
	var hardness: float = block_hardness.get(block_id, 1.0)
	if hardness <= 0.0:
		return -1.0  # Not minable

	var speed: float = BARE_HANDS_SPEED
	if is_tool_item(held_item_id):
		var tool_data: Dictionary = tools.get(held_item_id, {})
		var tool_type: String = tool_data.get("tool_type", "")
		var tool_speed: float = tool_data.get("mining_speed", 1.0)
		var affinity: String = block_tool_affinity.get(block_id, "pickaxe")
		if tool_type == affinity:
			speed = tool_speed
		else:
			speed = tool_speed * WRONG_TOOL_MULT

	return hardness / speed

static func get_tool_durability(item_id: int) -> int:
	if not is_tool_item(item_id):
		return -1
	var t: Dictionary = tools.get(item_id, {})
	return t.get("max_durability", 60)

static func get_tool_icon(item_id: int) -> String:
	if not is_tool_item(item_id):
		return ""
	var t: Dictionary = tools.get(item_id, {})
	return t.get("icon", "?")

static func is_minable(block_id: int) -> bool:
	return block_hardness.get(block_id, 0.0) > 0.0
