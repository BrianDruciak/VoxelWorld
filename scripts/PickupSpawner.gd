extends Node

const MAX_PICKUPS := 8
const SPAWN_INTERVAL := 5.0
const SPAWN_RADIUS_MIN := 12.0
const SPAWN_RADIUS_MAX := 28.0
const DESPAWN_DISTANCE := 55.0

var _player: CharacterBody3D
var _chunk_manager: Node3D
var _pickups: Array[CrystalPickup] = []
var _spawn_timer: float = 0.0
var _active := false

signal item_collected(item_id: int, count: int)


func setup(player: CharacterBody3D, chunk_manager: Node3D) -> void:
	_player = player
	_chunk_manager = chunk_manager


func start() -> void:
	_active = true
	_spawn_timer = 2.0


func stop() -> void:
	_active = false
	for p in _pickups:
		if is_instance_valid(p):
			p.queue_free()
	_pickups.clear()


func _process(delta: float) -> void:
	if not _active or _player == null:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		_try_spawn()

	_check_pickups()
	_despawn_distant()


func _try_spawn() -> void:
	if _pickups.size() >= MAX_PICKUPS:
		return

	var pos := _player.global_position
	var dist := Vector2(pos.x, pos.z).length()

	var ore_id := _pick_ore_for_distance(dist)
	if ore_id <= 0:
		return

	var angle := randf() * TAU
	var radius := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
	var spawn_x := pos.x + cos(angle) * radius
	var spawn_z := pos.z + sin(angle) * radius

	if not _chunk_manager.has_method("GetHeightAt"):
		return
	var spawn_y: int = _chunk_manager.GetHeightAt(spawn_x, spawn_z) + 1

	var crystal := CrystalPickup.new()
	crystal.initialize(ore_id, randi_range(1, 2))
	crystal.picked_up.connect(_on_picked_up)

	_chunk_manager.get_parent().add_child(crystal)
	crystal.global_position = Vector3(spawn_x, spawn_y, spawn_z)
	_pickups.append(crystal)


func _check_pickups() -> void:
	if _player == null:
		return
	var ppos := _player.global_position
	for p in _pickups:
		if is_instance_valid(p):
			p.try_collect(ppos)


func _despawn_distant() -> void:
	for i in range(_pickups.size() - 1, -1, -1):
		var p := _pickups[i]
		if not is_instance_valid(p):
			_pickups.remove_at(i)
			continue
		if p.global_position.distance_to(_player.global_position) > DESPAWN_DISTANCE:
			p.queue_free()
			_pickups.remove_at(i)


func _on_picked_up(ore_id: int, count: int) -> void:
	item_collected.emit(ore_id, count)


func _pick_ore_for_distance(dist: float) -> int:
	if dist < 128.0:
		# Safe Haven: copper/iron occasionally
		if randf() < 0.3:
			return [18, 19].pick_random()
		return -1
	elif dist < 320.0:
		# The Wilds
		return [14, 20].pick_random()  # WildCrystal, Thornite
	elif dist < 560.0:
		# Frozen Wastes
		return [15, 21].pick_random()  # Frostite, GlacialGem
	elif dist < 800.0:
		# Scorched Lands
		return [16, 22].pick_random()  # Embersite, MagmaCore
	else:
		# The Void
		return 17  # VoidShard
