extends StaticBody3D
class_name WeaponPickup

## Pickup object for weapons in the world

@export var weapon_scene: PackedScene
@export var weapon_name: String = "Weapon"
@export var rotate_speed: float = 45.0  # Degrees per second

var is_in_range: bool = false

@onready var label: Label3D = $Label3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Colors
const COLOR_DEFAULT := Color(1.0, 0.8, 0.0, 1.0)  # Yellow
const COLOR_IN_RANGE := Color(0.0, 1.0, 0.0, 1.0)  # Green
const EMISSION_DEFAULT := Color(1.0, 0.9, 0.3, 1.0)  # Yellow emission
const EMISSION_IN_RANGE := Color(0.3, 1.0, 0.3, 1.0)  # Green emission

func _ready():
	# Add to interaction group
	add_to_group("interactable")

	# Update label with weapon name
	if label:
		label.text = "[E] %s" % weapon_name

func _process(delta):
	# Rotate slowly
	rotate_y(deg_to_rad(rotate_speed) * delta)

## Called when player can interact with this weapon
func set_in_range(in_range: bool) -> void:
	if is_in_range == in_range:
		return

	is_in_range = in_range
	_update_appearance()

func _update_appearance() -> void:
	if not mesh_instance:
		return

	var material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if not material:
		return

	if is_in_range:
		material.albedo_color = COLOR_IN_RANGE
		material.emission = EMISSION_IN_RANGE
	else:
		material.albedo_color = COLOR_DEFAULT
		material.emission = EMISSION_DEFAULT
