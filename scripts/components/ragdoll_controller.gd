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

# Progressive damping system - ragdoll gets stiffer over time
var ragdoll_activation_time: float = 0.0
const RAGDOLL_DAMPING_RAMP_DURATION: float = 5.0  # 5 seconds to reach full stiffness
var bone_initial_damping: Dictionary = {}  # Stores initial damping per bone
var bone_final_damping: Dictionary = {}    # Stores final damping per bone

# Joint configuration data
const JOINT_CONFIGS := {
	&"head": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 6.0,
		"angular_damp": 8.0,
		"linear_limit": 0.001,
		"angular_limits": {"x": [15, -5], "y": [40, -40], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring - prevents glitching
	},
	&"neck": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 8.0,
		"angular_damp": 10.0,
		"linear_limit": 0.0003,  # Tighter to prevent stretching
		"angular_limits": {"x": [8, -8], "y": [12, -12], "z": [5, -5]},  # Tighter to prevent extreme angles
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring - prevents head glitching
	},
	&"lower_arm": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.5,
		"angular_damp": 1.0,
		"linear_limit": 0.003,
		"angular_limits": {"x": [150, 0], "y": [45, -45], "z": [45, -45]},  # Wider limits for elbow twist
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring - stays where it falls
	},
	&"lower_leg": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.3,
		"angular_damp": 0.6,
		"linear_limit": 0.008,
		"angular_limits": {"x": [140, 0], "y": [30, -30], "z": [30, -30]},  # Wider limits for knee twist
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring - stays where it falls
	},
	&"shoulder": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 1.0,
		"angular_damp": 2.0,
		"linear_limit": 0.002,
		"angular_limits": {"x": [180, -180], "y": [180, -180], "z": [180, -180]},  # Allow full rotation - arms can flop to sides
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring
	},
	&"upper_arm": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.8,
		"angular_damp": 1.5,
		"linear_limit": 0.004,
		"angular_limits": {"x": [180, -180], "y": [180, -180], "z": [180, -180]},  # Allow full rotation - natural fall
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring
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
		"angular_limits": {"x": [120, -45], "y": [60, -60], "z": [45, -45]},  # Wider limits for natural fall
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring - stays where it falls (was 0.9!)
	},
	&"hand": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.9,
		"angular_damp": 0.98,
		"linear_limit": 0.002,
		"angular_limits": {"x": [60, -60], "y": [45, -45], "z": [45, -45]},  # Wider limits for wrist freedom
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring - limp hands
	},
	&"foot": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.9,
		"angular_damp": 0.95,
		"linear_limit": 0.005,
		"angular_limits": {"x": [45, -45], "y": [30, -30], "z": [30, -30]},  # Wider limits for ankle freedom
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}  # No spring - stays where it falls
	}
}

func _ready() -> void:
	if not bone_config:
		push_error("RagdollController: BoneConfig not assigned!")
		return

	_generate_physical_bones()

func _physics_process(delta: float) -> void:
	if not is_ragdoll_active:
		return

	# Progressive damping - ragdoll gets stiffer over time
	ragdoll_activation_time += delta

	# Calculate damping interpolation factor (0.0 to 1.0 over 5 seconds)
	var damping_factor := minf(ragdoll_activation_time / RAGDOLL_DAMPING_RAMP_DURATION, 1.0)

	# Apply smoothstep for more natural ramp (slow start, fast middle, slow end)
	damping_factor = damping_factor * damping_factor * (3.0 - 2.0 * damping_factor)

	# Update damping for all physical bones
	for bone in physical_bones:
		var bone_name: StringName = bone.bone_name
		if bone_name in bone_initial_damping and bone_name in bone_final_damping:
			var initial: Vector2 = bone_initial_damping[bone_name]
			var final: Vector2 = bone_final_damping[bone_name]

			# Lerp from initial (floppy) to final (stiff)
			bone.linear_damp = lerpf(initial.x, final.x, damping_factor)
			bone.angular_damp = lerpf(initial.y, final.y, damping_factor)

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

	# Set initial damping (floppy) and final damping (stiff) based on bone type
	var name_lower := String(bone_name).to_lower()
	var initial_linear: float
	var initial_angular: float
	var final_linear: float
	var final_angular: float

	if "hand" in name_lower or "neck" in name_lower:
		# Hands and neck: low initial damping for free fall, then stiffen
		initial_linear = 0.3
		initial_angular = 0.5
		final_linear = 3.0
		final_angular = 4.0
	elif "head" in name_lower:
		# Head: moderate damping for stability
		initial_linear = 1.0
		initial_angular = 1.5
		final_linear = 5.0
		final_angular = 6.0
	else:
		# Arms and legs: low initial damping for natural falling
		initial_linear = 0.5
		initial_angular = 0.8
		final_linear = 4.0
		final_angular = 5.0

	# Set initial damping (floppy ragdoll)
	physical_bone.linear_damp = initial_linear
	physical_bone.angular_damp = initial_angular

	# Store damping values for progressive stiffening
	bone_initial_damping[bone_name] = Vector2(initial_linear, initial_angular)
	bone_final_damping[bone_name] = Vector2(final_linear, final_angular)

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
		# Capsule for head - more stable than sphere, less rolling/glitching
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.06  # Smaller to prevent overlap with neck
		capsule.height = 0.12
		return capsule
	elif "hand" in name_lower:
		# Capsule for smooth collisions
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.02
		capsule.height = 0.06
		return capsule
	elif "foot" in name_lower:
		# Capsule for smooth ground contact
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.03
		capsule.height = 0.10
		return capsule
	elif "spine" in name_lower or "hips" in name_lower:
		# Keep boxes for torso (more stable)
		var box := BoxShape3D.new()
		box.size = Vector3(0.25, 0.2, 0.2) if "hips" in name_lower else Vector3(0.2, 0.3, 0.15)
		return box
	else:
		# Capsules for limbs (arms, legs, neck) - smooth collisions, no jitter
		var capsule := CapsuleShape3D.new()
		if "arm" in name_lower:
			capsule.radius = 0.025
			capsule.height = 0.15
		elif "leg" in name_lower:
			capsule.radius = 0.035
			capsule.height = 0.18
		else:
			# Default capsule for neck/other
			capsule.radius = 0.03
			capsule.height = 0.12
		return capsule

func _get_bone_mass(bone_name: StringName) -> float:
	var name_lower := String(bone_name).to_lower()

	if "head" in name_lower: return 6.0  # Increased for stability (prevents glitching on impact)
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

	# Reset progressive damping timer - start floppy, ramp to stiff over 5 seconds
	ragdoll_activation_time = 0.0

	# Reset all bones to initial (low) damping
	for bone in physical_bones:
		var bone_name: StringName = bone.bone_name
		if bone_name in bone_initial_damping:
			var initial: Vector2 = bone_initial_damping[bone_name]
			bone.linear_damp = initial.x
			bone.angular_damp = initial.y

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
