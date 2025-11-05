extends Node3D
class_name WeaponController

## Weapon controller for handling weapon positioning, ADS, and procedural effects

@export var ads_target: Node3D  # The sight/optic position
@export var grip_point: Node3D  # Where the shooting hand grips
@export var support_point: Node3D  # Where the support hand holds (foregrip)

# Weapon positioning
@export var hipfire_position: Vector3 = Vector3(0, 0, 0)
@export var hipfire_rotation: Vector3 = Vector3(0, 0, 0)

# Recoil
@export var recoil_amount: float = 0.1
@export var recoil_recovery_speed: float = 10.0
var current_recoil: Vector3 = Vector3.ZERO

# Weapon sway (separate from character sway)
@export var weapon_sway_amount: float = 0.05
@export var weapon_sway_smoothness: float = 10.0
var target_sway: Vector3 = Vector3.ZERO
var current_sway: Vector3 = Vector3.ZERO

# Inertia (weapon lags behind camera movement)
@export var inertia_amount: float = 0.02
@export var inertia_smoothness: float = 5.0
var previous_rotation: Vector3 = Vector3.ZERO
var inertia_offset: Vector3 = Vector3.ZERO

# References
var character_controller: FPPCharacterController

func _ready():
	# Get character controller reference
	var parent = get_parent()
	while parent:
		if parent is FPPCharacterController:
			character_controller = parent
			break
		parent = parent.get_parent()

	# Store initial position
	hipfire_position = position
	hipfire_rotation = rotation_degrees

func _process(delta):
	_update_weapon_effects(delta)

	# Handle firing
	if Input.is_action_just_pressed("fire"):
		fire()

func _update_weapon_effects(delta):
	# Recoil recovery
	current_recoil = current_recoil.lerp(Vector3.ZERO, recoil_recovery_speed * delta)

	# Weapon inertia (lags behind camera rotation)
	if character_controller:
		var current_rotation = Vector3(
			character_controller.camera_x_rotation,
			character_controller.camera_y_rotation,
			0
		)
		var rotation_delta = current_rotation - previous_rotation
		previous_rotation = current_rotation

		# Calculate inertia offset (opposite of rotation change)
		target_sway = -rotation_delta * inertia_amount

	# Smooth sway
	current_sway = current_sway.lerp(target_sway, inertia_smoothness * delta)

	# Apply effects to weapon
	var final_offset = current_recoil + current_sway

	# Apply rotation (not position, as weapon is attached to hand)
	rotation.x = hipfire_rotation.x + final_offset.x
	rotation.y = hipfire_rotation.y + final_offset.y

func fire():
	"""Simulate weapon firing with recoil"""
	# Add recoil
	current_recoil += Vector3(
		randf_range(-recoil_amount * 0.5, -recoil_amount),  # Kick up and slightly random
		randf_range(-recoil_amount * 0.2, recoil_amount * 0.2),  # Horizontal variance
		0
	)

	print("BANG! Weapon fired")

func get_ads_position() -> Vector3:
	"""Returns the ADS target position in global space"""
	if ads_target:
		return ads_target.global_position
	return global_position

func get_grip_position() -> Vector3:
	"""Returns the grip point in global space"""
	if grip_point:
		return grip_point.global_position
	return global_position

func get_support_position() -> Vector3:
	"""Returns the support point in global space"""
	if support_point:
		return support_point.global_position
	return global_position
