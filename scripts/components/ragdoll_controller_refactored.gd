extends Node
class_name RagdollControllerRefactored

## Refactored ragdoll controller using data-driven approach
## Follows Godot 4.5 best practices with Resources and clean architecture

signal ragdoll_enabled()
signal ragdoll_disabled()

@export var bone_config: BoneConfig
@export var collision_layer: int = 2  # Ragdoll on layer 2
@export var collision_mask: int = 1   # Only collide with environment (layer 1)

@onready var skeleton: Skeleton3D = get_node_or_null("../CharacterModel/RootNode/Skeleton3D")
@onready var character_body: CharacterBody3D = get_parent()

var is_ragdoll_active: bool = false
var physical_bones: Array[PhysicalBone3D] = []
var partial_ragdoll_limbs: Array[StringName] = []

# Sleep timer
var ragdoll_sleep_timer: float = 0.0
const RAGDOLL_SLEEP_DELAY: float = 5.0  # Freeze bodies after 5 seconds

# Joint configuration data
const JOINT_CONFIGS := {
	&"head": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 3.5,
		"angular_damp": 5.0,
		"linear_limit": 0.0,
		"angular_limits": {"x": [15, -5], "y": [40, -40], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"neck": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 4.0,
		"angular_damp": 6.0,
		"linear_limit": 0.0,
		"angular_limits": {"x": [10, -5], "y": [15, -15], "z": [3, -3]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"lower_arm": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 2.5,
		"angular_damp": 3.5,
		"linear_limit": 0.0,
		"angular_limits": {"x": [140, 0], "y": [10, -10], "z": [5, -5]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"lower_leg": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.5,
		"angular_damp": 1.0,
		"linear_limit": 0.0,
		"angular_limits": {"x": [120, 0], "y": [5, -5], "z": [5, -5]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"shoulder": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 4.0,
		"angular_damp": 5.0,
		"linear_limit": 0.0,
		"angular_limits": {"x": [1, -1], "y": [1, -1], "z": [1, -1]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"upper_arm": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 2.5,
		"angular_damp": 3.5,
		"linear_limit": 0.0,
		"angular_limits": {"x": [120, -20], "y": [90, -30], "z": [45, -45]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"spine": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 5.0,
		"angular_damp": 7.0,
		"linear_limit": 0.0,
		"angular_limits": {"x": [5, -5], "y": [8, -8], "z": [3, -3]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"hips": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 2.0,
		"angular_damp": 3.0,
		"linear_limit": 0.0,
		"angular_limits": {"x": [20, -20], "y": [15, -15], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"upper_leg": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.5,
		"angular_damp": 1.0,
		"linear_limit": 0.0,
		"angular_limits": {"x": [70, -20], "y": [25, -25], "z": [15, -15]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"hand": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 2.5,
		"angular_damp": 3.5,
		"linear_limit": 0.0,
		"angular_limits": {"x": [20, -30], "y": [15, -15], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	},
	&"foot": {
		"type": PhysicalBone3D.JOINT_TYPE_6DOF,
		"linear_damp": 0.8,
		"angular_damp": 1.2,
		"linear_limit": 0.0,
		"angular_limits": {"x": [15, -30], "y": [10, -10], "z": [10, -10]},
		"softness": {"x": 0.0, "y": 0.0, "z": 0.0}
	}
}

func _ready() -> void:
	# Defer validation to allow parent to initialize config first
	call_deferred("_validate_and_initialize")

func _process(delta: float) -> void:
	if is_ragdoll_active:
		ragdoll_sleep_timer += delta
		if ragdoll_sleep_timer >= RAGDOLL_SLEEP_DELAY:
			_freeze_ragdoll_bones()

func _validate_and_initialize() -> void:
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

	print("Auto-generated %d PhysicalBone3D nodes" % physical_bones.size())

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
	physical_bone.friction = 0.8
	physical_bone.bounce = 0.0
	physical_bone.gravity_scale = 1.0
	physical_bone.can_sleep = true

	# Disable collision by default (enabled when ragdoll activates)
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
	elif "shoulder" in name_lower:
		# Very small sphere for shoulders - they don't move much
		var sphere := SphereShape3D.new()
		sphere.radius = 0.02
		return sphere
	elif "hand" in name_lower:
		var box := BoxShape3D.new()
		box.size = Vector3(0.04, 0.06, 0.02)  # Smaller hands
		return box
	elif "foot" in name_lower:
		var box := BoxShape3D.new()
		box.size = Vector3(0.08, 0.04, 0.12)  # Slightly smaller feet
		return box
	elif "spine" in name_lower or "hips" in name_lower:
		var box := BoxShape3D.new()
		box.size = Vector3(0.22, 0.18, 0.18) if "hips" in name_lower else Vector3(0.18, 0.25, 0.13)
		return box
	else:
		# Default capsule for limbs - smaller radius to allow arms to cross body
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.025  # Reduced from 0.03
		capsule.height = 0.18   # Slightly shorter
		return capsule

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
			physical_bone.set("joint_constraints/angular_limit_%s/damping" % axis, 15.0 if "arm" in String(config_key) or "leg" in String(config_key) else 12.0)

func _set_linear_limits(physical_bone: PhysicalBone3D, limit: float) -> void:
	# Only enable linear limits if limit is greater than 0
	# Zero linear limits can cause jitter
	if limit > 0.0:
		for axis in ["x", "y", "z"]:
			physical_bone.set("joint_constraints/linear_limit_%s/enabled" % axis, true)
			physical_bone.set("joint_constraints/linear_limit_%s/upper_limit" % axis, limit)
			physical_bone.set("joint_constraints/linear_limit_%s/lower_limit" % axis, -limit)
	else:
		for axis in ["x", "y", "z"]:
			physical_bone.set("joint_constraints/linear_limit_%s/enabled" % axis, false)

## Enable full body ragdoll
func enable_ragdoll(impulse: Vector3 = Vector3.ZERO) -> void:
	if is_ragdoll_active:
		return

	is_ragdoll_active = true
	ragdoll_sleep_timer = 0.0  # Reset sleep timer

	# Capture character's current velocity before disabling controller
	var character_velocity := Vector3.ZERO
	if character_body:
		character_velocity = character_body.velocity

	# Disable character controller collision
	if character_body:
		character_body.collision_layer = 0
		character_body.collision_mask = 0

	# Start physics simulation
	skeleton.physical_bones_start_simulation()

	# Enable collision on all bones
	# Layer 2 = ragdoll bones, Mask 1 = environment only (no self-collision)
	for bone in physical_bones:
		bone.collision_layer = collision_layer
		bone.collision_mask = collision_mask
		# Explicitly disable self-collision between physical bones
		for other_bone in physical_bones:
			if bone != other_bone:
				bone.add_collision_exception_with(other_bone)

	# Transfer character velocity to ragdoll bones for momentum continuity
	if character_velocity.length() > 0.1:
		for bone in physical_bones:
			bone.linear_velocity = character_velocity

	# Apply additional impulse if specified (for impacts, explosions, etc.)
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

## Freeze ragdoll bones after sleep delay
func _freeze_ragdoll_bones() -> void:
	if ragdoll_sleep_timer < RAGDOLL_SLEEP_DELAY:
		return

	# Put all physical bones to sleep to stop physics simulation
	for bone in physical_bones:
		bone.sleeping = true

	# Only do this once
	ragdoll_sleep_timer = -1.0
	print("Ragdoll frozen - bodies put to sleep")

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
