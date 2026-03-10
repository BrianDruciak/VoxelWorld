extends RefCounted
class_name Inventory

const SLOT_COUNT := 36
const HOTBAR_SIZE := 9

signal inventory_changed

var slots: Array[Dictionary] = []
var selected_hotbar: int = 0

func _init() -> void:
	clear()

func clear() -> void:
	slots.clear()
	for i in SLOT_COUNT:
		slots.append({})
	inventory_changed.emit()

func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= SLOT_COUNT:
		return {}
	return slots[index]

func set_slot(index: int, data: Dictionary) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	slots[index] = data
	inventory_changed.emit()

func swap_slots(a: int, b: int) -> void:
	if a < 0 or a >= SLOT_COUNT or b < 0 or b >= SLOT_COUNT:
		return
	var temp: Dictionary = slots[a]
	slots[a] = slots[b]
	slots[b] = temp
	inventory_changed.emit()

func get_hotbar_slot() -> Dictionary:
	return get_slot(selected_hotbar)

func add_item(item_id: int, count: int, durability: int = -1) -> int:
	var max_stack: int = ItemDB.get_stack_size(item_id)
	var remaining: int = count

	if ItemDB.is_tool_item(item_id):
		for i in SLOT_COUNT:
			if remaining <= 0:
				break
			if slots[i].is_empty():
				var dur: int = durability if durability >= 0 else ItemDB.get_tool_durability(item_id)
				slots[i] = {"id": item_id, "count": 1, "durability": dur}
				remaining -= 1
		inventory_changed.emit()
		return remaining

	# Stack into existing slots first
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if slot.is_empty():
			continue
		if slot.get("id", -1) != item_id:
			continue
		var current: int = slot.get("count", 0)
		var space: int = max_stack - current
		if space <= 0:
			continue
		var to_add: int = mini(remaining, space)
		slot["count"] = current + to_add
		remaining -= to_add

	# Fill empty slots
	for i in SLOT_COUNT:
		if remaining <= 0:
			break
		if not slots[i].is_empty():
			continue
		var to_add: int = mini(remaining, max_stack)
		slots[i] = {"id": item_id, "count": to_add, "durability": -1}
		remaining -= to_add

	inventory_changed.emit()
	return remaining

func remove_item(item_id: int, count: int) -> bool:
	if not has_item(item_id, count):
		return false
	var remaining: int = count
	for i in range(SLOT_COUNT - 1, -1, -1):
		if remaining <= 0:
			break
		var slot: Dictionary = slots[i]
		if slot.is_empty():
			continue
		if slot.get("id", -1) != item_id:
			continue
		var current: int = slot.get("count", 0)
		if current <= remaining:
			slots[i] = {}
			remaining -= current
		else:
			slot["count"] = current - remaining
			remaining = 0
	inventory_changed.emit()
	return true

func has_item(item_id: int, count: int) -> bool:
	var total: int = 0
	for slot in slots:
		if slot.is_empty():
			continue
		if slot.get("id", -1) == item_id:
			total += slot.get("count", 0)
	return total >= count

func count_item(item_id: int) -> int:
	var total: int = 0
	for slot in slots:
		if slot.is_empty():
			continue
		if slot.get("id", -1) == item_id:
			total += slot.get("count", 0)
	return total

func deduct_durability(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return true
	var slot: Dictionary = slots[slot_index]
	if slot.is_empty():
		return true
	var dur: int = slot.get("durability", -1)
	if dur < 0:
		return true  # Not a durability item
	dur -= 1
	if dur <= 0:
		slots[slot_index] = {}
		inventory_changed.emit()
		return false  # Tool broke
	slot["durability"] = dur
	inventory_changed.emit()
	return true

func get_all_ores() -> Dictionary:
	var ores: Dictionary = {}
	for slot in slots:
		if slot.is_empty():
			continue
		var sid: int = slot.get("id", -1)
		if ItemDB.is_ore(sid):
			ores[sid] = ores.get(sid, 0) + slot.get("count", 0)
	return ores

func remove_all_ores() -> Dictionary:
	var removed: Dictionary = {}
	for i in SLOT_COUNT:
		var slot: Dictionary = slots[i]
		if slot.is_empty():
			continue
		var sid: int = slot.get("id", -1)
		if ItemDB.is_ore(sid):
			removed[sid] = removed.get(sid, 0) + slot.get("count", 0)
			slots[i] = {}
	inventory_changed.emit()
	return removed
