extends Node

enum State { IDLE, RUNNING, DEAD, EXTRACTING, UPGRADING }

const EXTRACTION_RADIUS := 48.0
const EXTRACTION_TIME := 3.0

const ZONE_SAFE_END := 128.0
const ZONE_WILD_END := 320.0
const ZONE_FROZEN_END := 560.0
const ZONE_SCORCHED_END := 800.0
const ZONE_BLEND := 64.0

signal run_started
signal run_ended(success: bool)
signal player_died
signal extraction_progress_changed(progress: float)
signal zone_changed(zone_name: String)

var state: State = State.IDLE
var run_time: float = 0.0
var max_distance_reached: float = 0.0
var zones_visited: Dictionary = {}

var _player: CharacterBody3D
var _extraction_timer: float = 0.0
var _was_extracting := false
var _last_zone: String = ""

# Damage resistance multipliers (0.0 = immune, 1.0 = full damage)
var wild_resist: float = 1.0
var frozen_resist: float = 1.0
var scorched_resist: float = 1.0
var void_resist: float = 1.0
var has_safe_regen: bool = false


func setup(player: CharacterBody3D) -> void:
	_player = player
	_player.player_died.connect(_on_player_died)


func start_run() -> void:
	if state == State.RUNNING:
		return
	state = State.RUNNING
	run_time = 0.0
	max_distance_reached = 0.0
	zones_visited.clear()
	_extraction_timer = 0.0
	_was_extracting = false
	_last_zone = ""
	run_started.emit()


func _process(delta: float) -> void:
	if state != State.RUNNING:
		return

	run_time += delta

	var pos: Vector3 = _player.global_position
	var dist: float = Vector2(pos.x, pos.z).length()
	max_distance_reached = maxf(max_distance_reached, dist)

	var zone_name := _get_zone_name(dist)
	if zone_name != _last_zone:
		_last_zone = zone_name
		zones_visited[zone_name] = true
		zone_changed.emit(zone_name)

	_apply_zone_damage(dist, delta)
	_check_safe_regen(dist, delta)
	_handle_extraction(dist, delta)


func _apply_zone_damage(dist: float, delta: float) -> void:
	var minutes := run_time / 60.0
	var dps := 0.0

	if dist < ZONE_SAFE_END:
		var escalation := maxf(minutes - 8.0, 0.0) * 0.5
		dps = escalation
	elif dist < ZONE_SAFE_END + ZONE_BLEND:
		var t := (dist - ZONE_SAFE_END) / ZONE_BLEND
		var safe_dps := maxf(minutes - 8.0, 0.0) * 0.5
		var wild_dps := (0.5 + minutes * 0.3) * wild_resist
		dps = lerpf(safe_dps, wild_dps, t)
	elif dist < ZONE_WILD_END:
		dps = (0.5 + minutes * 0.3) * wild_resist
	elif dist < ZONE_WILD_END + ZONE_BLEND:
		var t := (dist - ZONE_WILD_END) / ZONE_BLEND
		var wild_dps := (0.5 + minutes * 0.3) * wild_resist
		var frozen_dps := (2.0 + minutes * 0.5) * frozen_resist
		dps = lerpf(wild_dps, frozen_dps, t)
	elif dist < ZONE_FROZEN_END:
		dps = (2.0 + minutes * 0.5) * frozen_resist
	elif dist < ZONE_FROZEN_END + ZONE_BLEND:
		var t := (dist - ZONE_FROZEN_END) / ZONE_BLEND
		var frozen_dps := (2.0 + minutes * 0.5) * frozen_resist
		var scorched_dps := (3.0 + minutes * 0.7) * scorched_resist
		dps = lerpf(frozen_dps, scorched_dps, t)
	elif dist < ZONE_SCORCHED_END:
		dps = (3.0 + minutes * 0.7) * scorched_resist
	elif dist < ZONE_SCORCHED_END + ZONE_BLEND:
		var t := (dist - ZONE_SCORCHED_END) / ZONE_BLEND
		var scorched_dps := (3.0 + minutes * 0.7) * scorched_resist
		var void_dps := (6.0 + minutes * 1.5) * void_resist
		dps = lerpf(scorched_dps, void_dps, t)
	else:
		dps = (6.0 + minutes * 1.5) * void_resist

	if dps > 0.0:
		_player.take_damage(dps * delta)


func _check_safe_regen(dist: float, delta: float) -> void:
	if has_safe_regen and dist < ZONE_SAFE_END:
		_player.heal(1.0 * delta)


func _handle_extraction(dist: float, delta: float) -> void:
	if dist > EXTRACTION_RADIUS:
		if _was_extracting:
			_extraction_timer = 0.0
			_was_extracting = false
			extraction_progress_changed.emit(0.0)
		return

	var is_pressing := Input.is_action_pressed("extract")
	var is_moving := _player.velocity.length() > 0.5

	if is_pressing and not is_moving:
		_was_extracting = true
		_extraction_timer += delta
		extraction_progress_changed.emit(_extraction_timer / EXTRACTION_TIME)

		if _extraction_timer >= EXTRACTION_TIME:
			_complete_extraction()
	else:
		if _was_extracting:
			_extraction_timer = maxf(_extraction_timer - delta * 2.0, 0.0)
			extraction_progress_changed.emit(_extraction_timer / EXTRACTION_TIME)
			if _extraction_timer <= 0.0:
				_was_extracting = false


func _complete_extraction() -> void:
	state = State.EXTRACTING
	_player.input_frozen = true
	_extraction_timer = 0.0
	extraction_progress_changed.emit(1.0)
	run_ended.emit(true)


func _on_player_died() -> void:
	if state != State.RUNNING:
		return
	state = State.DEAD
	_player.input_frozen = true
	player_died.emit()
	run_ended.emit(false)


func get_zone_name_at_dist(dist: float) -> String:
	return _get_zone_name(dist)


func _get_zone_name(dist: float) -> String:
	if dist < ZONE_SAFE_END:
		return "SAFE HAVEN"
	elif dist < ZONE_WILD_END:
		return "THE WILDS"
	elif dist < ZONE_FROZEN_END:
		return "FROZEN WASTES"
	elif dist < ZONE_SCORCHED_END:
		return "SCORCHED LANDS"
	else:
		return "THE VOID"


func get_zone_danger(dist: float) -> float:
	if dist < ZONE_SAFE_END:
		return 0.0
	elif dist < ZONE_WILD_END:
		return 0.25
	elif dist < ZONE_FROZEN_END:
		return 0.5
	elif dist < ZONE_SCORCHED_END:
		return 0.75
	else:
		return 1.0


func is_in_extraction_zone() -> bool:
	if _player == null:
		return false
	var pos: Vector3 = _player.global_position
	return Vector2(pos.x, pos.z).length() < EXTRACTION_RADIUS
