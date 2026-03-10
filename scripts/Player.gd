extends CharacterBody3D

const DEFAULT_WALK_SPEED := 5.0
const DEFAULT_SPRINT_SPEED := 10.0
const DEFAULT_JUMP_VELOCITY := 6.0
const MOUSE_SENS := 0.002
const GRAVITY := 20.0
const DEFAULT_REACH := 6.0
const RAY_STEPS := 100
const DEFAULT_MAX_HEALTH := 100.0

@onready var camera: Camera3D = $Camera3D

var _captured := true
var input_frozen := false

# Stats (reset each run from upgrades)
var walk_speed: float = DEFAULT_WALK_SPEED
var sprint_speed: float = DEFAULT_SPRINT_SPEED
var jump_velocity: float = DEFAULT_JUMP_VELOCITY
var reach: float = DEFAULT_REACH

# Health
var max_health: float = DEFAULT_MAX_HEALTH
var current_health: float = DEFAULT_MAX_HEALTH
var _is_dead := false

# Inventory
var inventory: Inventory

# Mining state
var _mining_target := Vector3i(-9999, -9999, -9999)
var _mining_progress: float = 0.0
var _mining_time: float = 0.0
var _is_mining := false

signal block_mined(wx: int, wy: int, wz: int, block_id: int)
signal block_placed(wx: int, wy: int, wz: int, block_id: int)
signal health_changed(current: float, maximum: float)
signal player_died
signal mining_progress_changed(progress: float)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	current_health = max_health
	inventory = Inventory.new()


func take_damage(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_dead = true
		player_died.emit()


func heal(amount: float) -> void:
	if _is_dead or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func reset_for_run(p_max_health: float, p_walk: float, p_sprint: float, p_jump: float, p_reach: float) -> void:
	max_health = p_max_health
	walk_speed = p_walk
	sprint_speed = p_sprint
	jump_velocity = p_jump
	reach = p_reach
	current_health = max_health
	_is_dead = false
	input_frozen = false
	_reset_mining()
	inventory.clear()
	# Starting loadout
	inventory.add_item(1000, 1)  # Wood Pickaxe
	inventory.add_item(1010, 1)  # Wood Shovel
	health_changed.emit(current_health, max_health)


func _reset_mining() -> void:
	_mining_target = Vector3i(-9999, -9999, -9999)
	_mining_progress = 0.0
	_mining_time = 0.0
	_is_mining = false
	mining_progress_changed.emit(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if input_frozen:
		return

	if event is InputEventMouseMotion and _captured:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -PI * 0.49, PI * 0.49)

	if event.is_action_pressed("ui_cancel"):
		_captured = not _captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _captured else Input.MOUSE_MODE_VISIBLE

	if not _captured:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_try_place_block()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_hotbar(-1)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_hotbar(1)

	if event is InputEventKey and event.is_pressed():
		var key: InputEventKey = event
		if key.keycode >= KEY_1 and key.keycode <= KEY_9:
			inventory.selected_hotbar = key.keycode - KEY_1
			inventory.inventory_changed.emit()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if input_frozen or _is_dead:
		velocity.x = move_toward(velocity.x, 0, walk_speed)
		velocity.z = move_toward(velocity.z, 0, walk_speed)
		_reset_mining()
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	# Hold-to-mine
	if _captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_process_mining(delta)
	elif _is_mining:
		_reset_mining()


func _process_mining(delta: float) -> void:
	var result: Dictionary = _voxel_raycast()
	if result.is_empty():
		if _is_mining:
			_reset_mining()
		return

	var hit: Vector3i = result["hit"]
	var block_id: int = result["block"]

	# Check if block is minable
	if not ItemDB.is_minable(block_id):
		if _is_mining:
			_reset_mining()
		return

	# Target changed — restart progress
	if hit != _mining_target:
		_mining_target = hit
		_mining_progress = 0.0
		_is_mining = true

		var held: Dictionary = inventory.get_hotbar_slot()
		var held_id: int = held.get("id", 0)
		_mining_time = ItemDB.get_mining_time(block_id, held_id)
		if _mining_time <= 0.0:
			_reset_mining()
			return

	_mining_progress += delta
	mining_progress_changed.emit(_mining_progress / _mining_time if _mining_time > 0 else 0.0)

	if _mining_progress >= _mining_time:
		# Deduct tool durability
		var held: Dictionary = inventory.get_hotbar_slot()
		if ItemDB.is_tool_item(held.get("id", 0)):
			inventory.deduct_durability(inventory.selected_hotbar)
		block_mined.emit(hit.x, hit.y, hit.z, block_id)
		_reset_mining()


func _voxel_raycast() -> Dictionary:
	var origin: Vector3 = camera.global_position
	var dir: Vector3 = -camera.global_basis.z.normalized()
	var step: float = reach / RAY_STEPS
	var prev := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))

	for i in range(1, RAY_STEPS + 1):
		var p: Vector3 = origin + dir * step * i
		var bx: int = floori(p.x)
		var by: int = floori(p.y)
		var bz: int = floori(p.z)
		var cur := Vector3i(bx, by, bz)

		if cur == prev:
			continue

		var chunk_mgr = get_parent().get_node("ChunkManager")
		var block_id: int = chunk_mgr.GetBlockWorld(bx, by, bz)

		if block_id != 0:
			return {"hit": cur, "prev": prev, "block": block_id}
		prev = cur

	return {}


func _try_place_block() -> void:
	var result: Dictionary = _voxel_raycast()
	if result.is_empty():
		return

	var held: Dictionary = inventory.get_hotbar_slot()
	if held.is_empty():
		return
	var item_id: int = held.get("id", 0)
	if not ItemDB.is_block(item_id):
		return

	var prev: Vector3i = result["prev"]
	# Don't place inside the player
	var player_block := Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
	var player_head := Vector3i(floori(global_position.x), floori(global_position.y + 1), floori(global_position.z))
	if prev == player_block or prev == player_head:
		return

	# Deduct from inventory
	var slot_idx: int = inventory.selected_hotbar
	var slot: Dictionary = inventory.get_slot(slot_idx)
	var count: int = slot.get("count", 0)
	if count <= 1:
		inventory.set_slot(slot_idx, {})
	else:
		slot["count"] = count - 1
		inventory.inventory_changed.emit()

	block_placed.emit(prev.x, prev.y, prev.z, item_id)


func _cycle_hotbar(dir: int) -> void:
	var idx: int = inventory.selected_hotbar + dir
	if idx < 0:
		idx = Inventory.HOTBAR_SIZE - 1
	elif idx >= Inventory.HOTBAR_SIZE:
		idx = 0
	inventory.selected_hotbar = idx
	inventory.inventory_changed.emit()
