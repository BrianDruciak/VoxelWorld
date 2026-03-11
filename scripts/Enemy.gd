extends CharacterBody3D
class_name Enemy

const GRAVITY := 20.0
const ATTACK_COOLDOWN := 1.2
const DETECTION_RANGE := 32.0
const DEAGGRO_RANGE := 48.0
const ATTACK_RANGE := 2.0
const KNOCKBACK_FORCE := 8.0

var move_speed: float = 3.0
var max_health: float = 20.0
var current_health: float = 20.0
var contact_damage: float = 8.0
var xp_value: int = 1
var zone_name: String = ""
var enemy_type: String = "crawler"

var _target: CharacterBody3D
var _attack_timer: float = 0.0
var _is_dead := false
var _death_timer: float = 0.0
var _body_mesh: MeshInstance3D
var _eye_left: MeshInstance3D
var _eye_right: MeshInstance3D
var _body_material: StandardMaterial3D
var _hit_flash_timer: float = 0.0

signal enemy_died(enemy: Enemy)
signal dropped_loot(position: Vector3, item_id: int, count: int)


func _ready() -> void:
	_build_mesh()
	_setup_collision()


func initialize(config: Dictionary) -> void:
	enemy_type = config.get("type", "crawler")
	move_speed = config.get("speed", 3.0)
	max_health = config.get("health", 20.0)
	contact_damage = config.get("damage", 8.0)
	zone_name = config.get("zone", "")

	var body_color: Color = config.get("body_color", Color(0.4, 0.6, 0.3))
	var eye_color: Color = config.get("eye_color", Color(1.0, 0.2, 0.2))
	var body_scale: Vector3 = config.get("scale", Vector3(0.8, 0.8, 0.8))
	var emission: Color = config.get("emission", Color.BLACK)
	var emission_strength: float = config.get("emission_strength", 0.0)

	current_health = max_health

	if _body_mesh:
		_body_mesh.scale = body_scale

	if _body_material:
		_body_material.albedo_color = body_color
		if emission_strength > 0.0:
			_body_material.emission_enabled = true
			_body_material.emission = emission
			_body_material.emission_energy_multiplier = emission_strength

	if _eye_left:
		var mat: StandardMaterial3D = _eye_left.get_surface_override_material(0)
		if mat:
			mat.albedo_color = eye_color
			mat.emission_enabled = true
			mat.emission = eye_color
			mat.emission_energy_multiplier = 2.5


func set_target(player: CharacterBody3D) -> void:
	_target = player


func _build_mesh() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.4, 0.6, 0.3)

	_body_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 0.9, 0.9)
	_body_mesh.mesh = box
	_body_mesh.position.y = 0.45
	_body_mesh.set_surface_override_material(0, _body_material)
	add_child(_body_mesh)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.2, 0.2)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.2, 0.2)
	eye_mat.emission_energy_multiplier = 2.5

	_eye_left = MeshInstance3D.new()
	var eye_box := BoxMesh.new()
	eye_box.size = Vector3(0.15, 0.12, 0.08)
	_eye_left.mesh = eye_box
	_eye_left.position = Vector3(-0.18, 0.62, -0.42)
	_eye_left.set_surface_override_material(0, eye_mat)
	_body_mesh.add_child(_eye_left)

	_eye_right = MeshInstance3D.new()
	_eye_right.mesh = eye_box
	_eye_right.position = Vector3(0.18, 0.62, -0.42)
	_eye_right.set_surface_override_material(0, eye_mat.duplicate())
	_body_mesh.add_child(_eye_right)


func _setup_collision() -> void:
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.8, 0.9, 0.8)
	shape.shape = box_shape
	shape.position.y = 0.45
	add_child(shape)


func take_damage(amount: float, from_direction: Vector3 = Vector3.ZERO) -> void:
	if _is_dead:
		return
	current_health -= amount
	_hit_flash_timer = 0.12

	if from_direction.length_squared() > 0.01:
		velocity += from_direction.normalized() * KNOCKBACK_FORCE + Vector3.UP * 3.0

	if current_health <= 0.0:
		_die()


func _die() -> void:
	_is_dead = true
	_death_timer = 0.0
	enemy_died.emit(self)

	var loot := _get_loot()
	if not loot.is_empty():
		dropped_loot.emit(global_position + Vector3.UP * 0.5, loot["id"], loot["count"])


func _get_loot() -> Dictionary:
	var roll := randf()
	match zone_name:
		"THE WILDS":
			if roll < 0.25:
				return {"id": 14, "count": randi_range(1, 2)}  # WildCrystal
		"FROZEN WASTES":
			if roll < 0.2:
				return {"id": 15, "count": randi_range(1, 2)}  # Frostite
			if roll < 0.3:
				return {"id": 21, "count": 1}  # GlacialGem
		"SCORCHED LANDS":
			if roll < 0.2:
				return {"id": 16, "count": randi_range(1, 2)}  # Embersite
			if roll < 0.3:
				return {"id": 22, "count": 1}  # MagmaCore
		"THE VOID":
			if roll < 0.35:
				return {"id": 17, "count": 1}  # VoidShard
	return {}


func _physics_process(delta: float) -> void:
	if _is_dead:
		_death_timer += delta
		if _body_mesh:
			_body_mesh.scale *= (1.0 - delta * 3.0)
			_body_mesh.position.y -= delta * 2.0
		if _death_timer > 0.6:
			queue_free()
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _body_material:
			_body_material.albedo_color = Color.WHITE if fmod(_hit_flash_timer, 0.06) > 0.03 else _body_material.albedo_color

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	_attack_timer = maxf(_attack_timer - delta, 0.0)

	if _target == null or not is_instance_valid(_target):
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		move_and_slide()
		return

	var to_target := _target.global_position - global_position
	var flat_dist := Vector2(to_target.x, to_target.z).length()

	if flat_dist > DEAGGRO_RANGE:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		move_and_slide()
		return

	if flat_dist < DETECTION_RANGE:
		var dir := to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed

		# Face the player
		if _body_mesh and flat_dist > 0.5:
			var look_dir := Vector3(to_target.x, 0, to_target.z).normalized()
			_body_mesh.global_transform = _body_mesh.global_transform.looking_at(
				_body_mesh.global_position + look_dir, Vector3.UP
			)

		# Jump if blocked
		if is_on_wall() and is_on_floor():
			velocity.y = 6.0

		if flat_dist < ATTACK_RANGE and _attack_timer <= 0.0:
			_attack_timer = ATTACK_COOLDOWN
			_target.take_damage(contact_damage)

	move_and_slide()

	# Bob animation
	if _body_mesh:
		var bob := sin(Time.get_ticks_msec() * 0.005 * move_speed) * 0.08
		_body_mesh.position.y = 0.45 + bob


static func create_config(type: String) -> Dictionary:
	match type:
		"thorn_crawler":
			return {
				"type": "thorn_crawler",
				"speed": 2.8, "health": 15.0, "damage": 5.0,
				"body_color": Color(0.25, 0.5, 0.18),
				"eye_color": Color(0.9, 1.0, 0.3),
				"scale": Vector3(0.7, 0.6, 0.9),
				"emission": Color(0.1, 0.3, 0.05),
				"emission_strength": 0.4,
			}
		"frost_wraith":
			return {
				"type": "frost_wraith",
				"speed": 4.0, "health": 25.0, "damage": 8.0,
				"body_color": Color(0.55, 0.75, 0.9),
				"eye_color": Color(0.3, 0.85, 1.0),
				"scale": Vector3(0.65, 1.1, 0.65),
				"emission": Color(0.3, 0.7, 1.0),
				"emission_strength": 1.2,
			}
		"ember_golem":
			return {
				"type": "ember_golem",
				"speed": 2.2, "health": 50.0, "damage": 15.0,
				"body_color": Color(0.45, 0.18, 0.08),
				"eye_color": Color(1.0, 0.5, 0.1),
				"scale": Vector3(1.1, 1.2, 1.1),
				"emission": Color(1.0, 0.35, 0.05),
				"emission_strength": 1.8,
			}
		"void_stalker":
			return {
				"type": "void_stalker",
				"speed": 5.5, "health": 35.0, "damage": 20.0,
				"body_color": Color(0.12, 0.05, 0.18),
				"eye_color": Color(0.85, 0.4, 1.0),
				"scale": Vector3(0.6, 0.95, 0.6),
				"emission": Color(0.5, 0.1, 0.8),
				"emission_strength": 2.5,
			}
		_:
			return {
				"type": type,
				"speed": 3.0, "health": 20.0, "damage": 8.0,
				"body_color": Color(0.5, 0.5, 0.5),
				"eye_color": Color(1.0, 0.2, 0.2),
				"scale": Vector3(0.8, 0.8, 0.8),
				"emission": Color.BLACK,
				"emission_strength": 0.0,
			}
