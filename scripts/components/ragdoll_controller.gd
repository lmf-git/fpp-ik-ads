extends Node
class_name RagdollController

## Ragdoll physics controller using data-driven approach
## Follows Godot 4.5 best practices with Resources and clean architecture

signal ragdoll_enabled()
signal ragdoll_disabled()

@export var bone_config: BoneConfig
# Collision setup: Layer 3 for ragdoll, Mask 1 for environment only (prevents self-collision)
@export var collision_layer: int = 4  # Layer 3 (2^2 = 4) - ragdoll layer
@export var collision_mask: int = 1   # Layer 1 - only collide with environment, not other ragdoll bones

@onready var skeleton: Skeleton3D = get_node_or_null("../CharacterModel/RootNode/Skeleton3D")
@onready var character_body: CharacterBody3D = get_parent()

var is_ragdoll_active: bool = false
var physical_bones: Array[PhysicalBone3D] = []
var partial_ragdoll_limbs: Array[StringName] = []

# Joint configuration data
const JOINT_CONFIGS := {
	&"head": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 6.0,
		"angular_damp": 8.0,
		"linear_limit": 0.001,
		"angular_limits": {"x": [15, -5], "y": [40, -40], "z": [10, -10]},
		"softness": {"x": 0.8, "y": 0.8, "z": 0.9}
	},
	&"neck": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 8.0,
		"angular_damp": 10.0,
		"linear_limit": 0.0005,
		"angular_limits": {"x": [10, -5], "y": [15, -15], "z": [3, -3]},
		"softness": {"x": 0.9, "y": 0.9, "z": 0.95}
	},
	&"lower_arm": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.5,
		"angular_damp": 1.0,
		"linear_limit": 0.003,
		"angular_limits": {"x": [140, 0], "y": [20, -20], "z": [20, -20]},
		"softness": {"x": 0.7, "y": 0.7, "z": 0.7}
	},
	&"lower_leg": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.3,
		"angular_damp": 0.6,
		"linear_limit": 0.008,
		"angular_limits": {"x": [130, 0], "y": [15, -15], "z": [15, -15]},
		"softness": {"x": 0.6, "y": 0.6, "z": 0.6}
	},
	&"shoulder": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 1.0,
		"angular_damp": 2.0,
		"linear_limit": 0.002,
		"angular_limits": {"x": [45, -30], "y": [40, -40], "z": [30, -30]},
		"softness": {"x": 0.8, "y": 0.8, "z": 0.8}
	},
	&"upper_arm": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.8,
		"angular_damp": 1.5,
		"linear_limit": 0.004,
		"angular_limits": {"x": [120, -40], "y": [90, -45], "z": [50, -50]},
		"softness": {"x": 0.8, "y": 0.8, "z": 0.8}
	},
	&"spine": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.95,
		"angular_damp": 0.98,
		"linear_limit": 0.001,
		"angular_limits": {"x": [5, -5], "y": [8, -8], "z": [3, -3]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"hips": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.9,
		"angular_damp": 0.95,
		"linear_limit": 0.01,
		"angular_limits": {"x": [20, -20], "y": [15, -15], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"upper_leg": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.5,
		"angular_damp": 0.8,
		"linear_limit": 0.012,
		"angular_limits": {"x": [90, -30], "y": [40, -40], "z": [30, -30]},
		"softness": {"x": 0.6, "y": 0.6, "z": 0.6}
	},
	&"hand": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.9,
		"angular_damp": 0.98,
		"linear_limit": 0.002,
		"angular_limits": {"x": [20, -30], "y": [15, -15], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"foot": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.9,
		"angular_damp": 0.95,
		"linear_limit": 0.005,
		"angular_limits": {"x": [15, -30], "y": [10, -10], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	}
}

func _ready() -> void:
	if not bone_config:
		push_error("RagdollController: BoneConfig not assigned!")
		return

	_generate_physical_bones()

func _generate_physical_bones() -> void:
	if not skeleton:
		push_error("RagdollController: Skeleton not found!")
		return

	# Check if bones already exist
	for child in skeleton.get_children():
		if child is PhysicalBone3D:
			physical_bones.append(child)

	if physical_bones.is_empty():
		print("No PhysicalBone3D nodes found - auto-generating...")
		_auto_generate_bones()
	else:
		print("Found %d existing PhysicalBone3D nodes" % physical_bones.size())

func _auto_generate_bones() -> void:
	var bones := bone_config.get_ragdoll_bones()

	for bone_name in bones:
		var bone_idx := bone_config.get_bone_index(skeleton, bone_name)
		if bone_idx >= 0:
			_create_physical_bone(bone_idx, bone_name)

	# Set up collision exceptions to prevent self-collision
	_setup_collision_exceptions()

	print("Auto-generated %d PhysicalBone3D nodes" % physical_bones.size())

## Prevent physical bones from colliding with each other
func _setup_collision_exceptions() -> void:
	# Add collision exceptions between ALL physical bones to prevent self-collision
	for i in range(physical_bones.size()):
		for j in range(i + 1, physical_bones.size()):
			var bone_a := physical_bones[i]
			var bone_b := physical_bones[j]

			# Add mutual collision exception
			bone_a.add_collision_exception_with(bone_b)
			# Note: add_collision_exception_with is mutual, so we don't need to call it both ways

	print("Set up %d collision exceptions to prevent ragdoll self-collision" % (physical_bones.size() * (physical_bones.size() - 1) / 2.0))

func _create_physical_bone(_bone_idx: int, bone_name: StringName) -> void:
	var physical_bone := PhysicalBone3D.new()
	physical_bone.name = "PhysicalBone_" + bone_name.replace("characters3d.com___", "")
	physical_bone.bone_name = bone_name

	# Create collision shape
	var shape := _create_shape_for_bone(bone_name)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	physical_bone.add_child(collision)

	# Set physics properties
	physical_bone.mass = _get_bone_mass(bone_name)
	physical_bone.friction = 1.0
	physical_bone.bounce = 0.0

	# Add strong damping to reduce jitter (especially for limbs)
	physical_bone.linear_damp = 2.5
	physical_bone.angular_damp = 3.5

	# Disable collision by default
	physical_bone.collision_layer = 0
	physical_bone.collision_mask = 0

	# Configure joint
	_configure_joint(physical_bone, bone_name)

	# Add to skeleton
	skeleton.add_child(physical_bone)
	physical_bone.owner = skeleton.owner if skeleton.owner else skeleton
	physical_bones.append(physical_bone)

func _create_shape_for_bone(bone_name: StringName) -> Shape3D:
	var name_lower := String(bone_name).to_lower()

	if "head" in name_lower:
		var sphere := SphereShape3D.new()
		sphere.radius = 0.08
		return sphere
	elif "hand" in name_lower:
		var box := BoxShape3D.new()
		box.size = Vector3(0.04, 0.06, 0.025)  # Smaller hands to reduce jitter
		return box
	elif "foot" in name_lower:
		var box := BoxShape3D.new()
		box.size = Vector3(0.06, 0.04, 0.12)  # Smaller feet to reduce jitter
		return box
	elif "spine" in name_lower or "hips" in name_lower:
		var box := BoxShape3D.new()
		box.size = Vector3(0.25, 0.2, 0.2) if "hips" in name_lower else Vector3(0.2, 0.3, 0.15)
		return box
	else:
		# Default box for limbs (arms, legs, neck) - made smaller to reduce collision jitter
		var box := BoxShape3D.new()
		if "arm" in name_lower:
			box.size = Vector3(0.03, 0.14, 0.03)  # Thinner arms to prevent jitter
		elif "leg" in name_lower:
			box.size = Vector3(0.045, 0.16, 0.045)  # Thinner legs to prevent jitter
		else:
			box.size = Vector3(0.04, 0.12, 0.04)  # Smaller default box
		return box

func _get_bone_mass(bone_name: StringName) -> float:
	var name_lower := String(bone_name).to_lower()

	if "head" in name_lower: return 4.5
	if "spine" in name_lower or "hips" in name_lower: return 25.0
	if "upper_arm" in name_lower or "shoulder" in name_lower: return 2.0
	if "lower_arm" in name_lower: return 1.5
	if "hand" in name_lower: return 0.4
	if "upper_leg" in name_lower: return 8.0
	if "lower_leg" in name_lower: return 3.0
	if "foot" in name_lower: return 1.0

	return 1.0

func _configure_joint(physical_bone: PhysicalBone3D, bone_name: StringName) -> void:
	var name_lower := String(bone_name).to_lower()

	# Find matching config
	var config_key: StringName
	for key in JOINT_CONFIGS:
		if String(key) in name_lower:
			config_key = key
			break

	if not config_key:
		return  # No special joint config

	var config: Dictionary = JOINT_CONFIGS[config_key]

	physical_bone.joint_type = config["type"]
	physical_bone.linear_damp = config["linear_damp"]
	physical_bone.angular_damp = config["angular_damp"]

	# Set linear limits
	var lin_limit: float = config["linear_limit"]
	_set_linear_limits(physical_bone, lin_limit)

	# Set angular limits
	var ang_limits: Dictionary = config["angular_limits"]
	var softness: Dictionary = config["softness"]

	for axis in ["x", "y", "z"]:
		if axis in ang_limits:
			var limits: Array = ang_limits[axis]
			var soft: float = softness.get(axis, 0.0)

			physical_bone.set("joint_constraints/angular_limit_%s/enabled" % axis, true)
			physical_bone.set("joint_constraints/angular_limit_%s/upper_limit" % axis, deg_to_rad(limits[0]))
			physical_bone.set("joint_constraints/angular_limit_%s/lower_limit" % axis, deg_to_rad(limits[1]))
			physical_bone.set("joint_constraints/angular_limit_%s/softness" % axis, soft)
			physical_bone.set("joint_constraints/angular_limit_%s/restitution" % axis, 0.0)
			physical_bone.set("joint_constraints/angular_limit_%s/damping" % axis, 4.0 if "arm" in String(config_key) or "leg" in String(config_key) else 2.0)

func _set_linear_limits(physical_bone: PhysicalBone3D, limit: float) -> void:
	for axis in ["x", "y", "z"]:
		physical_bone.set("joint_constraints/linear_limit_%s/enabled" % axis, true)
		physical_bone.set("joint_constraints/linear_limit_%s/upper_limit" % axis, limit)
		physical_bone.set("joint_constraints/linear_limit_%s/lower_limit" % axis, -limit)

## Enable full body ragdoll
func enable_ragdoll(impulse: Vector3 = Vector3.ZERO) -> void:
	if is_ragdoll_active:
		return

	is_ragdoll_active = true

	# Disable character controller collision
	if character_body:
		character_body.collision_layer = 0
		character_body.collision_mask = 0

	# Start physics simulation
	skeleton.physical_bones_start_simulation()

	# Enable collision on all bones
	for bone in physical_bones:
		bone.collision_layer = collision_layer
		bone.collision_mask = collision_mask

	# Apply impulse if specified
	if impulse.length() > 0:
		for bone in physical_bones:
			bone.apply_central_impulse(impulse)

	ragdoll_enabled.emit()
	print("Ragdoll enabled with %d physical bones" % physical_bones.size())

## Disable ragdoll
func disable_ragdoll() -> void:
	if not is_ragdoll_active:
		return

	is_ragdoll_active = false

	# Stop physics simulation
	skeleton.physical_bones_stop_simulation()

	# Disable collision
	for bone in physical_bones:
		bone.collision_layer = 0
		bone.collision_mask = 0

	# Re-enable character controller
	if character_body:
		character_body.collision_layer = 1
		character_body.collision_mask = 1

	ragdoll_disabled.emit()
	print("Ragdoll disabled - returned to animated mode")

## Toggle ragdoll
func toggle_ragdoll() -> void:
	if is_ragdoll_active:
		disable_ragdoll()
	else:
		enable_ragdoll()

## Enable partial ragdoll for specific limb
func enable_partial_ragdoll(limb: StringName) -> void:
	if limb in partial_ragdoll_limbs:
		return

	var limb_bones := bone_config.get_limb_bones(limb)
	partial_ragdoll_limbs.append(limb)

	for bone_name in limb_bones:
		_enable_bone_physics(bone_name)

	print("Enabled partial ragdoll for %s" % limb)

## Disable partial ragdoll for specific limb
func disable_partial_ragdoll(limb: StringName) -> void:
	if not limb in partial_ragdoll_limbs:
		return

	partial_ragdoll_limbs.erase(limb)

	var limb_bones := bone_config.get_limb_bones(limb)
	for bone_name in limb_bones:
		_disable_bone_physics(bone_name)

	print("Disabled partial ragdoll for %s" % limb)

func _enable_bone_physics(bone_name: StringName) -> void:
	for bone in physical_bones:
		if bone.bone_name == bone_name:
			bone.collision_layer = collision_layer
			bone.collision_mask = collision_mask
			break

func _disable_bone_physics(bone_name: StringName) -> void:
	for bone in physical_bones:
		if bone.bone_name == bone_name:
			bone.collision_layer = 0
			bone.collision_mask = 0
			break

## Apply impulse to ragdoll (for testing/debugging)
func apply_impulse(impulse: Vector3) -> void:
	if not is_ragdoll_active:
		enable_ragdoll(impulse)
	else:
		# Apply impulse to all physical bones
		for bone in physical_bones:
			bone.apply_central_impulse(impulse)
		print("Applied impulse to ragdoll: ", impulse)

## Toggle partial ragdoll for a limb (for testing/debugging)
func toggle_partial_ragdoll(limb: StringName) -> void:
	if limb in partial_ragdoll_limbs:
		disable_partial_ragdoll(limb)
	else:
		enable_partial_ragdoll(limb)

## Check if any partial ragdoll is active
func is_any_partial_ragdoll_active() -> bool:
	return partial_ragdoll_limbs.size() > 0

## Check specific limb ragdoll states (for HUD compatibility)
var left_arm_ragdoll_active: bool:
	get: return &"left_arm" in partial_ragdoll_limbs

var right_arm_ragdoll_active: bool:
	get: return &"right_arm" in partial_ragdoll_limbs

var left_leg_ragdoll_active: bool:
	get: return &"left_leg" in partial_ragdoll_limbs

var right_leg_ragdoll_active: bool:
	get: return &"right_leg" in partial_ragdoll_limbs
