extends Node
class_name RagdollController

## Enhanced ragdoll physics controller with partial ragdoll support
## Supports full body ragdoll and individual limb ragdoll (arms, legs, etc.)
## Seamless transitions between animation, IK, and physics

@export var skeleton: Skeleton3D
@export var character_body: CharacterBody3D

# Ragdoll state
var is_ragdoll_active: bool = false
var physical_bones: Array[PhysicalBone3D] = []

# Partial ragdoll state tracking
var left_arm_ragdoll_active: bool = false
var right_arm_ragdoll_active: bool = false
var left_leg_ragdoll_active: bool = false
var right_leg_ragdoll_active: bool = false
var torso_ragdoll_active: bool = false
var head_ragdoll_active: bool = false

# Settings
@export var ragdoll_activation_force: float = 500.0
@export var ragdoll_mass_scale: float = 1.0
@export var ragdoll_friction: float = 0.8
@export var ragdoll_bounce: float = 0.1

# Seamless transition settings
@export var transition_duration: float = 0.3
var transitioning_bones: Dictionary = {}  # bone_name -> {start_pose, target_pose, elapsed}

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

	# Enable collision on all physical bones
	for bone in physical_bones:
		bone.collision_layer = 1
		bone.collision_mask = 1

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

	# Disable collision on all physical bones
	for bone in physical_bones:
		bone.collision_layer = 0
		bone.collision_mask = 0

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

## ============================================================================
## PARTIAL RAGDOLL SYSTEM
## ============================================================================

func enable_partial_ragdoll(limb: String, impulse: Vector3 = Vector3.ZERO):
	"""Enable ragdoll physics for a specific limb
	Args:
		limb: 'left_arm', 'right_arm', 'left_leg', 'right_leg', 'torso', 'head'
		impulse: Optional force to apply to the limb
	"""
	if is_ragdoll_active:
		print("Cannot use partial ragdoll - full ragdoll is active")
		return

	var bone_names = _get_bones_for_limb(limb)
	if bone_names.is_empty():
		print("Unknown limb: ", limb)
		return

	print("Enabling partial ragdoll for ", limb, ": ", bone_names)

	# Start physics simulation if not already running
	var needs_physics_start = not _is_any_bone_simulating()
	if needs_physics_start and skeleton:
		skeleton.physical_bones_start_simulation()

	# Transfer current poses to physical bones for seamless transition
	_transfer_poses_to_physical_bones(bone_names)

	# Enable collision and physics for these specific bones
	for bone in physical_bones:
		if bone.bone_name in bone_names:
			bone.collision_layer = 1
			bone.collision_mask = 1

			# Apply impulse if specified
			if impulse.length() > 0:
				bone.apply_central_impulse(impulse)

	# Update state
	match limb:
		"left_arm":
			left_arm_ragdoll_active = true
		"right_arm":
			right_arm_ragdoll_active = true
		"left_leg":
			left_leg_ragdoll_active = true
		"right_leg":
			right_leg_ragdoll_active = true
		"torso":
			torso_ragdoll_active = true
		"head":
			head_ragdoll_active = true

func disable_partial_ragdoll(limb: String):
	"""Disable ragdoll physics for a specific limb"""
	var bone_names = _get_bones_for_limb(limb)
	if bone_names.is_empty():
		return

	print("Disabling partial ragdoll for ", limb)

	# Disable collision for these bones and reset their poses
	for bone in physical_bones:
		if bone.bone_name in bone_names:
			bone.collision_layer = 0
			bone.collision_mask = 0
			# Reset velocities
			bone.linear_velocity = Vector3.ZERO
			bone.angular_velocity = Vector3.ZERO

	# Reset bone poses to animation-driven for these specific bones
	if skeleton:
		for bone_name in bone_names:
			var bone_idx = skeleton.find_bone(bone_name)
			if bone_idx >= 0:
				# Clear any physics override by resetting to rest
				skeleton.reset_bone_pose(bone_idx)

	# Update state
	match limb:
		"left_arm":
			left_arm_ragdoll_active = false
		"right_arm":
			right_arm_ragdoll_active = false
		"left_leg":
			left_leg_ragdoll_active = false
		"right_leg":
			right_leg_ragdoll_active = false
		"torso":
			torso_ragdoll_active = false
		"head":
			head_ragdoll_active = false

	# If no partial ragdolls are active, stop physics simulation entirely
	if not is_any_partial_ragdoll_active() and skeleton:
		skeleton.physical_bones_stop_simulation()
		print("All partial ragdolls disabled - stopped physics simulation")

func toggle_partial_ragdoll(limb: String, impulse: Vector3 = Vector3.ZERO):
	"""Toggle ragdoll physics for a specific limb"""
	var is_active = false
	match limb:
		"left_arm":
			is_active = left_arm_ragdoll_active
		"right_arm":
			is_active = right_arm_ragdoll_active
		"left_leg":
			is_active = left_leg_ragdoll_active
		"right_leg":
			is_active = right_leg_ragdoll_active
		"torso":
			is_active = torso_ragdoll_active
		"head":
			is_active = head_ragdoll_active

	if is_active:
		disable_partial_ragdoll(limb)
	else:
		enable_partial_ragdoll(limb, impulse)

func _get_bones_for_limb(limb: String) -> Array:
	"""Get bone names for a specific limb"""
	match limb:
		"left_arm":
			return ["LeftShoulder", "LeftElbow", "LeftHand"]
		"right_arm":
			return ["RightShoulder", "RightElbow", "RightHand"]
		"left_leg":
			return ["LeftHip", "LeftKnee", "LeftFoot"]  # If these exist
		"right_leg":
			return ["RightHip", "RightKnee", "RightFoot"]  # If these exist
		"torso":
			return ["Spine"]
		"head":
			return ["Head"]
		_:
			return []

func _transfer_poses_to_physical_bones(bone_names: Array):
	"""Transfer current bone poses to physical bones for seamless ragdoll transition"""
	if not skeleton:
		return

	for bone_name in bone_names:
		var bone_idx = skeleton.find_bone(bone_name)
		if bone_idx < 0:
			continue

		# Get current global transform of the bone
		var bone_global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone_idx)

		# Find the corresponding physical bone and set its transform
		for physical_bone in physical_bones:
			if physical_bone.bone_name == bone_name:
				# Set physical bone to match current animated pose
				physical_bone.global_transform = bone_global_transform
				physical_bone.linear_velocity = Vector3.ZERO
				physical_bone.angular_velocity = Vector3.ZERO
				break

func is_any_partial_ragdoll_active() -> bool:
	"""Check if any partial ragdoll is currently active"""
	return left_arm_ragdoll_active or right_arm_ragdoll_active or \
		   left_leg_ragdoll_active or right_leg_ragdoll_active or \
		   torso_ragdoll_active or head_ragdoll_active

func disable_all_partial_ragdolls():
	"""Disable all partial ragdolls"""
	if left_arm_ragdoll_active:
		disable_partial_ragdoll("left_arm")
	if right_arm_ragdoll_active:
		disable_partial_ragdoll("right_arm")
	if left_leg_ragdoll_active:
		disable_partial_ragdoll("left_leg")
	if right_leg_ragdoll_active:
		disable_partial_ragdoll("right_leg")
	if torso_ragdoll_active:
		disable_partial_ragdoll("torso")
	if head_ragdoll_active:
		disable_partial_ragdoll("head")

func _is_any_bone_simulating() -> bool:
	"""Check if any physical bone currently has collision enabled (indicating active physics)"""
	for bone in physical_bones:
		if bone.collision_layer != 0 or bone.collision_mask != 0:
			return true
	return false
