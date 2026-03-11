extends Node3D
class_name CrystalPickup

const PICKUP_RANGE := 2.5
const BOB_SPEED := 2.5
const BOB_HEIGHT := 0.15
const SPIN_SPEED := 1.8
const MAGNET_RANGE := 4.5
const MAGNET_SPEED := 8.0
const LIFETIME := 45.0

var item_id: int = 14
var item_count: int = 1
var _mesh: MeshInstance3D
var _light: OmniLight3D
var _base_y: float = 0.0
var _age: float = 0.0
var _collected := false

signal picked_up(item_id: int, count: int)


func initialize(p_item_id: int, p_count: int = 1) -> void:
	item_id = p_item_id
	item_count = p_count


func _ready() -> void:
	_base_y = position.y
	_build_visual()


func _build_visual() -> void:
	var color: Color = _get_crystal_color()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.85

	_mesh = MeshInstance3D.new()

	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 0.55, 0.35)
	_mesh.mesh = prism
	_mesh.set_surface_override_material(0, mat)
	_mesh.position.y = 0.4
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 1.5
	_light.omni_range = 4.0
	_light.omni_attenuation = 1.5
	_light.position.y = 0.5
	add_child(_light)


func _get_crystal_color() -> Color:
	match item_id:
		14: return Color(0.65, 0.2, 0.85)    # WildCrystal
		15: return Color(0.3, 0.85, 0.95)     # Frostite
		16: return Color(0.95, 0.45, 0.1)     # Embersite
		17: return Color(0.6, 0.3, 0.9)       # VoidShard
		18: return Color(0.72, 0.45, 0.2)     # CopperOre
		19: return Color(0.6, 0.6, 0.65)      # IronOre
		20: return Color(0.2, 0.7, 0.15)      # Thornite
		21: return Color(0.7, 0.85, 0.95)     # GlacialGem
		22: return Color(0.85, 0.25, 0.1)     # MagmaCore
		_:  return Color(0.8, 0.8, 0.8)


func try_collect(player_pos: Vector3) -> bool:
	if _collected:
		return false
	var dist := global_position.distance_to(player_pos)
	if dist < PICKUP_RANGE:
		_collected = true
		picked_up.emit(item_id, item_count)
		queue_free()
		return true
	return false


func _process(delta: float) -> void:
	if _collected:
		return

	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	if _mesh:
		_mesh.position.y = 0.4 + sin(_age * BOB_SPEED) * BOB_HEIGHT
		_mesh.rotate_y(SPIN_SPEED * delta)

	# Fade out near end of life
	if _age > LIFETIME - 5.0 and _mesh:
		var fade := 1.0 - (_age - (LIFETIME - 5.0)) / 5.0
		var mat: StandardMaterial3D = _mesh.get_surface_override_material(0)
		if mat:
			mat.albedo_color.a = fade * 0.85
		if _light:
			_light.light_energy = fade * 1.5
