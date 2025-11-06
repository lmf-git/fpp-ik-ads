extends Node
class_name RagdollController

## Controls ragdoll physics for the character skeleton
## Toggles between animated skeleton and physics-based ragdoll

@export var skeleton: Skeleton3D
@export var character_body: CharacterBody3D

# Ragdoll state
var is_ragdoll_active: bool = false
var physical_bones: Array[PhysicalBone3D] = []

# Settings
@export var ragdoll_activation_force: float = 500.0
@export var ragdoll_mass_scale: float = 1.0
@export var ragdoll_friction: float = 0.8
@export var ragdoll_bounce: float = 0.1

func _ready():
	if skeleton:
		_find_physical_bones()
		_disable_ragdoll()

func _find_physical_bones():
	"""Find all PhysicalBone3D nodes in the skeleton"""
	physical_bones.clear()

	if not skeleton:
		return

	for child in skeleton.get_children():
		if child is PhysicalBone3D:
			physical_bones.append(child)
			_configure_physical_bone(child)

func _configure_physical_bone(bone: PhysicalBone3D):
	"""Configure a physical bone's physics properties"""
	# Set mass based on bone (approximate human body part masses)
	var mass = _get_bone_mass(bone.bone_name) * ragdoll_mass_scale
	bone.mass = mass

	# Set physics material properties
	bone.friction = ragdoll_friction
	bone.bounce = ragdoll_bounce

func _get_bone_mass(bone_name: String) -> float:
	"""Get approximate mass for body parts (in kg)"""
	# Based on average human body segment masses
	match bone_name.to_lower():
		"head":
			return 4.5  # Head ~4.5kg
		"spine", "root":
			return 25.0  # Torso ~25kg
		"rightshoulder", "leftshoulder":
			return 2.0  # Upper arm ~2kg each
		"rightelbow", "leftelbow":
			return 1.5  # Forearm ~1.5kg each
		"righthand", "lefthand":
			return 0.4  # Hand ~0.4kg each
		_:
			return 1.0  # Default 1kg

func enable_ragdoll(impulse: Vector3 = Vector3.ZERO):
	"""Enable ragdoll physics mode"""
	if is_ragdoll_active:
		return

	is_ragdoll_active = true

	# Disable character controller collision
	if character_body:
		character_body.collision_layer = 0
		character_body.collision_mask = 0

	# Enable all physical bones using Skeleton3D
	if skeleton:
		skeleton.physical_bones_start_simulation()

	# Apply impulse if specified (e.g., from damage direction)
	if impulse.length() > 0:
		for bone in physical_bones:
			bone.apply_central_impulse(impulse)

	print("Ragdoll enabled with %d physical bones" % physical_bones.size())

func disable_ragdoll():
	"""Disable ragdoll physics mode (return to animated skeleton)"""
	if not is_ragdoll_active:
		return

	is_ragdoll_active = false

	# Re-enable character controller collision
	if character_body:
		character_body.collision_layer = 1
		character_body.collision_mask = 1

	# Disable all physical bones
	_disable_ragdoll()

	print("Ragdoll disabled - returned to animated mode")

func _disable_ragdoll():
	"""Internal method to disable all physical bones"""
	if skeleton:
		skeleton.physical_bones_stop_simulation()

func apply_force_to_bone(bone_name: String, force: Vector3):
	"""Apply force to a specific bone (e.g., hit reaction)"""
	for bone in physical_bones:
		if bone.bone_name == bone_name:
			bone.apply_central_force(force)
			return

func apply_impulse_to_bone(bone_name: String, impulse: Vector3):
	"""Apply impulse to a specific bone (e.g., bullet hit)"""
	for bone in physical_bones:
		if bone.bone_name == bone_name:
			bone.apply_central_impulse(impulse)
			return

func get_ragdoll_state() -> bool:
	"""Check if ragdoll is currently active"""
	return is_ragdoll_active

func reset_pose():
	"""Reset skeleton to rest pose (useful after disabling ragdoll)"""
	if skeleton:
		skeleton.reset_bone_poses()
