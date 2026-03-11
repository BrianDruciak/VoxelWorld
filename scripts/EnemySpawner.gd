extends Node

const MAX_ENEMIES := 12
const SPAWN_INTERVAL := 3.0
const SPAWN_RADIUS_MIN := 18.0
const SPAWN_RADIUS_MAX := 32.0
const DESPAWN_DISTANCE := 60.0

var _player: CharacterBody3D
var _chunk_manager: Node3D
var _enemies: Array[Enemy] = []
var _spawn_timer: float = 0.0
var _active := false

signal enemy_killed(enemy: Enemy)
signal loot_dropped(position: Vector3, item_id: int, count: int)


func setup(player: CharacterBody3D, chunk_manager: Node3D) -> void:
	_player = player
	_chunk_manager = chunk_manager


func start() -> void:
	_active = true
	_spawn_timer = 1.5


func stop() -> void:
	_active = false
	for e in _enemies:
		if is_instance_valid(e):
			e.queue_free()
	_enemies.clear()


func _process(delta: float) -> void:
	if not _active or _player == null:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_try_spawn()

	_despawn_distant()


func _try_spawn() -> void:
	if _enemies.size() >= MAX_ENEMIES:
		return

	var pos := _player.global_position
	var dist := Vector2(pos.x, pos.z).length()
	var zone := _get_zone(dist)

	if zone == "SAFE HAVEN":
		return

	var enemy_type := _zone_to_enemy_type(zone)
	if enemy_type.is_empty():
		return

	var count := _desired_count(zone)
	if _enemies.size() >= count:
		return

	var angle := randf() * TAU
	var radius := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	var spawn_x := pos.x + cos(angle) * radius
	var spawn_z := pos.z + sin(angle) * radius

	if not _chunk_manager.has_method("GetHeightAt"):
		return
	var spawn_y: int = _chunk_manager.GetHeightAt(spawn_x, spawn_z) + 2

	var enemy := Enemy.new()
	var config := Enemy.create_config(enemy_type)
	config["zone"] = zone

	_chunk_manager.get_parent().add_child(enemy)
	enemy.global_position = Vector3(spawn_x, spawn_y, spawn_z)
	enemy.initialize(config)
	enemy.set_target(_player)
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.dropped_loot.connect(_on_loot_dropped)
	_enemies.append(enemy)


func _despawn_distant() -> void:
	var to_remove: Array[int] = []
	for i in range(_enemies.size() - 1, -1, -1):
		var e := _enemies[i]
		if not is_instance_valid(e):
			to_remove.append(i)
			continue
		var d := e.global_position.distance_to(_player.global_position)
		if d > DESPAWN_DISTANCE:
			e.queue_free()
			to_remove.append(i)
	for idx in to_remove:
		_enemies.remove_at(idx)


func _on_enemy_died(enemy: Enemy) -> void:
	enemy_killed.emit(enemy)


func _on_loot_dropped(pos: Vector3, item_id: int, count: int) -> void:
	loot_dropped.emit(pos, item_id, count)


func _get_zone(dist: float) -> String:
	if dist < 128.0:
		return "SAFE HAVEN"
	elif dist < 320.0:
		return "THE WILDS"
	elif dist < 560.0:
		return "FROZEN WASTES"
	elif dist < 800.0:
		return "SCORCHED LANDS"
	else:
		return "THE VOID"


func _zone_to_enemy_type(zone: String) -> String:
	match zone:
		"THE WILDS":
			return "thorn_crawler"
		"FROZEN WASTES":
			return "frost_wraith"
		"SCORCHED LANDS":
			return "ember_golem"
		"THE VOID":
			return "void_stalker"
	return ""


func _desired_count(zone: String) -> int:
	match zone:
		"THE WILDS":
			return 4
		"FROZEN WASTES":
			return 6
		"SCORCHED LANDS":
			return 8
		"THE VOID":
			return MAX_ENEMIES
	return 0
