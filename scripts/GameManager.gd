extends Node3D

@export var world_seed: int = 12345
@export var render_distance: int = 8

@onready var chunk_manager = $ChunkManager
@onready var player = $Player
@onready var hud = $HUD
@onready var env: WorldEnvironment = $WorldEnvironment

var run_manager: Node
var upgrade_manager: Node
var save_manager: Node
var shop_manager: Node

var _cs_ready := false
var _spawn_pos := Vector3(8, 80, 8)


func _ready() -> void:
	_cs_ready = chunk_manager.has_method("GetHeightAt")
	if not _cs_ready:
		push_warning("C# not built yet — build the solution then reload the project.")
		return

	chunk_manager.set("WorldSeed", world_seed)
	chunk_manager.set("RenderDistance", render_distance)

	var spawn_x := 8.0
	var spawn_z := 8.0
	var spawn_y: int = chunk_manager.GetHeightAt(spawn_x, spawn_z) + 3
	_spawn_pos = Vector3(spawn_x, spawn_y, spawn_z)
	player.position = _spawn_pos

	chunk_manager.GenerateInitialChunks(player.position)

	# Connect player signals
	player.block_mined.connect(_on_block_mined)
	player.block_placed.connect(_on_block_placed)
	player.health_changed.connect(_on_health_changed)
	player.mining_progress_changed.connect(_on_mining_progress)

	# Wire HUD to inventory
	hud.set_inventory(player.inventory)

	_setup_save_manager()
	_setup_upgrade_manager()
	_setup_shop_manager()
	_setup_run_manager()

	_start_new_run()


func _setup_run_manager() -> void:
	run_manager = preload("res://scripts/RunManager.gd").new()
	run_manager.name = "RunManager"
	add_child(run_manager)
	run_manager.setup(player)
	run_manager.run_ended.connect(_on_run_ended)
	run_manager.player_died.connect(_on_player_died)
	run_manager.zone_changed.connect(_on_zone_changed)
	run_manager.extraction_progress_changed.connect(_on_extraction_progress)


func _setup_upgrade_manager() -> void:
	upgrade_manager = preload("res://scripts/UpgradeManager.gd").new()
	upgrade_manager.name = "UpgradeManager"
	add_child(upgrade_manager)
	if save_manager:
		upgrade_manager.load_state(save_manager.load_data())
	hud.upgrade_purchase_requested.connect(_on_upgrade_purchase)


func _setup_save_manager() -> void:
	save_manager = preload("res://scripts/SaveManager.gd").new()
	save_manager.name = "SaveManager"
	add_child(save_manager)


func _setup_shop_manager() -> void:
	shop_manager = preload("res://scripts/ShopManager.gd").new()
	shop_manager.name = "ShopManager"
	add_child(shop_manager)
	hud.shop_purchase_requested.connect(_on_shop_purchase)


func _start_new_run() -> void:
	var stats: Dictionary = upgrade_manager.get_all_stats()
	player.reset_for_run(
		stats.get("max_health", 100.0),
		stats.get("walk_speed", 5.0),
		stats.get("sprint_speed", 10.0),
		stats.get("jump_velocity", 6.0),
		stats.get("reach", 6.0),
	)

	# Apply purchased shop items to inventory
	shop_manager.apply_pending_to_inventory(player.inventory)

	run_manager.wild_resist = stats.get("wild_resist", 1.0)
	run_manager.frozen_resist = stats.get("frozen_resist", 1.0)
	run_manager.scorched_resist = stats.get("scorched_resist", 1.0)
	run_manager.void_resist = stats.get("void_resist", 1.0)
	run_manager.has_safe_regen = stats.get("safe_regen", false)

	var spawn_y: int = chunk_manager.GetHeightAt(_spawn_pos.x, _spawn_pos.z) + 3
	_spawn_pos.y = spawn_y
	player.position = _spawn_pos
	player.velocity = Vector3.ZERO

	hud.hide_death()
	hud.hide_success()
	hud.hide_shop()
	hud.hide_inventory()
	hud.show_extraction_prompt(false)
	hud.update_hotbar_from_inventory()

	player._captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	run_manager.start_run()


func _process(_delta: float) -> void:
	if not _cs_ready:
		return

	chunk_manager.UpdatePlayerPosition(player.global_position)

	var p: Vector3 = player.global_position
	var dist: float = Vector2(p.x, p.z).length()

	_update_atmosphere(dist)

	if hud:
		hud.update_debug({
			"x": p.x, "y": p.y, "z": p.z,
			"cx": floori(p.x / 16.0),
			"cz": floori(p.z / 16.0),
			"loaded": chunk_manager.GetLoadedChunkCount(),
			"pending": chunk_manager.GetPendingChunkCount(),
			"biome": chunk_manager.GetBiomeNameAt(p.x, p.z),
			"dist": dist,
		})

		if run_manager:
			hud.update_timer(run_manager.run_time)
			var zone_name: String = run_manager.get_zone_name_at_dist(dist)
			hud.update_zone(zone_name)

			var health_ratio: float = player.current_health / player.max_health if player.max_health > 0 else 0.0
			hud.update_vfx(zone_name, health_ratio, run_manager.run_time)

			var in_zone: bool = run_manager.is_in_extraction_zone()
			var is_running: bool = run_manager.state == 1  # State.RUNNING
			hud.show_extraction_prompt(in_zone and is_running)

		hud.update_minimap(p, player.rotation.y)

	_handle_overlay_input()


func _handle_overlay_input() -> void:
	if Input.is_action_just_pressed("ui_accept"):
		if hud.is_death_visible():
			hud.hide_death()
			_show_shop_screen()
		elif hud.is_success_visible():
			hud.hide_success()
			_show_shop_screen()

	if Input.is_action_just_pressed("toggle_upgrades"):
		# During a run: toggle inventory
		if run_manager and run_manager.state == 1:  # RUNNING
			if hud.is_inventory_visible():
				hud.hide_inventory()
				player.input_frozen = false
				player._captured = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				hud.show_inventory()
				player.input_frozen = true
				player._captured = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Between runs: toggle shop
		elif not hud.is_death_visible() and not hud.is_success_visible():
			if hud.is_shop_visible():
				hud.hide_shop()
				_start_new_run()
			elif run_manager and run_manager.state != 1:
				_show_shop_screen()


func _show_shop_screen() -> void:
	player.input_frozen = true
	player._captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var upgrades: Array = upgrade_manager.get_upgrade_definitions()
	var stash: Dictionary = upgrade_manager.stash
	var purchased: Dictionary = upgrade_manager.purchased
	var tool_listings: Array = shop_manager.get_tool_listings()
	var supply_listings: Array = shop_manager.get_supply_listings()
	hud.show_shop(upgrades, stash, purchased, tool_listings, supply_listings)


func _on_block_mined(wx: int, wy: int, wz: int, block_id: int) -> void:
	chunk_manager.SetBlockWorld(wx, wy, wz, 0)
	# Add mined block to inventory
	player.inventory.add_item(block_id, 1)


func _on_block_placed(wx: int, wy: int, wz: int, block_id: int) -> void:
	var existing: int = chunk_manager.GetBlockWorld(wx, wy, wz)
	if existing != 0:
		return
	chunk_manager.SetBlockWorld(wx, wy, wz, block_id)


func _on_health_changed(current: float, maximum: float) -> void:
	if hud:
		hud.update_health(current, maximum)


func _on_mining_progress(progress: float) -> void:
	if hud:
		hud.update_mining_progress(progress)


func _on_zone_changed(_zone_name: String) -> void:
	pass


func _on_extraction_progress(progress: float) -> void:
	if hud:
		hud.update_extraction_progress(progress)


func _on_run_ended(success: bool) -> void:
	if success:
		var ores: Dictionary = player.inventory.remove_all_ores()
		for ore_id in ores:
			upgrade_manager.add_to_stash(ore_id, ores[ore_id])
		save_manager.save_data(upgrade_manager.get_save_data())
		hud.show_success(ores, run_manager.run_time, run_manager.max_distance_reached)
	else:
		var lost_ores: Dictionary = player.inventory.get_all_ores()
		hud.show_death(lost_ores, run_manager.run_time, run_manager.max_distance_reached)


func _on_player_died() -> void:
	pass


func _on_upgrade_purchase(upgrade_id: String) -> void:
	if upgrade_manager.try_purchase(upgrade_id):
		save_manager.save_data(upgrade_manager.get_save_data())
		_refresh_shop_display()


func _on_shop_purchase(item_id: int) -> void:
	if shop_manager.try_purchase(item_id, upgrade_manager.stash):
		save_manager.save_data(upgrade_manager.get_save_data())
		_refresh_shop_display()


func _refresh_shop_display() -> void:
	var upgrades: Array = upgrade_manager.get_upgrade_definitions()
	var stash: Dictionary = upgrade_manager.stash
	var purchased: Dictionary = upgrade_manager.purchased
	var tool_listings: Array = shop_manager.get_tool_listings()
	var supply_listings: Array = shop_manager.get_supply_listings()
	hud.show_shop(upgrades, stash, purchased, tool_listings, supply_listings)


func _update_atmosphere(dist: float) -> void:
	if env == null or env.environment == null:
		return

	var e: Environment = env.environment
	var time_factor := 0.0
	if run_manager:
		time_factor = clampf(run_manager.run_time / 720.0, 0.0, 1.0)

	if dist < 128:
		e.ambient_light_color = Color(0.8, 0.85, 0.95).lerp(Color(0.5, 0.5, 0.55), time_factor * 0.5)
		e.ambient_light_energy = lerpf(0.5, 0.35, time_factor)
		e.fog_enabled = time_factor > 0.6
		if e.fog_enabled:
			e.fog_density = lerpf(0.0, 0.002, (time_factor - 0.6) / 0.4)
			e.fog_light_color = Color(0.4, 0.35, 0.3)
	elif dist < 320:
		var t: float = clampf((dist - 128.0) / 192.0, 0.0, 1.0)
		e.ambient_light_color = Color(0.8, 0.85, 0.95).lerp(Color(0.3, 0.35, 0.3), t)
		e.ambient_light_energy = lerpf(0.5, 0.35, t) - time_factor * 0.1
		e.fog_enabled = t > 0.3 or time_factor > 0.4
		e.fog_light_color = Color(0.4, 0.45, 0.35)
		e.fog_density = lerpf(0.0, 0.003, t) + time_factor * 0.001
	elif dist < 560:
		var t: float = clampf((dist - 320.0) / 240.0, 0.0, 1.0)
		e.ambient_light_color = Color(0.3, 0.35, 0.3).lerp(Color(0.6, 0.7, 0.85), t)
		e.ambient_light_energy = lerpf(0.35, 0.45, t) - time_factor * 0.1
		e.fog_enabled = true
		e.fog_light_color = Color(0.4, 0.45, 0.35).lerp(Color(0.7, 0.75, 0.85), t)
		e.fog_density = lerpf(0.003, 0.004, t) + time_factor * 0.001
	elif dist < 800:
		var t: float = clampf((dist - 560.0) / 240.0, 0.0, 1.0)
		e.ambient_light_color = Color(0.6, 0.7, 0.85).lerp(Color(0.6, 0.25, 0.15), t)
		e.ambient_light_energy = lerpf(0.45, 0.55, t) - time_factor * 0.1
		e.fog_enabled = true
		e.fog_light_color = Color(0.7, 0.75, 0.85).lerp(Color(0.5, 0.2, 0.1), t)
		e.fog_density = lerpf(0.004, 0.006, t) + time_factor * 0.001
	else:
		e.ambient_light_color = Color(0.4, 0.1, 0.05)
		e.ambient_light_energy = 0.6 - time_factor * 0.15
		e.fog_enabled = true
		e.fog_light_color = Color(0.35, 0.1, 0.05)
		e.fog_density = 0.008 + time_factor * 0.002
