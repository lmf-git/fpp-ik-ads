extends Node3D
class_name SimpleIKChain

## Simple 2-bone IK solver for arm chains
## Implements basic IK for shoulder -> elbow -> hand chains

@export var root_bone: Node3D  # Shoulder
@export var middle_bone: Node3D  # Elbow
@export var end_bone: Node3D  # Hand
@export var target: Node3D  # IK target position
@export var pole_target: Node3D  # Optional pole vector for elbow direction

@export var enabled: bool = true
@export var blend_amount: float = 1.0  # How much IK to apply (0-1)
@export var iterations: int = 10  # Solver iterations for accuracy

var original_root_rotation: Quaternion
var original_middle_rotation: Quaternion
var original_end_rotation: Quaternion

func _ready():
	if root_bone:
		original_root_rotation = root_bone.quaternion
	if middle_bone:
		original_middle_rotation = middle_bone.quaternion
	if end_bone:
		original_end_rotation = end_bone.quaternion

func _physics_process(_delta):
	if enabled and target:
		solve_ik()

func solve_ik():
	if not root_bone or not middle_bone or not end_bone or not target:
		return

	# Get positions in global space
	var root_pos = root_bone.global_position
	var middle_pos = middle_bone.global_position
	var end_pos = end_bone.global_position
	var target_pos = target.global_position

	# Calculate bone lengths
	var upper_length = root_pos.distance_to(middle_pos)
	var lower_length = middle_pos.distance_to(end_pos)
	var total_length = upper_length + lower_length

	# Distance to target
	var target_distance = root_pos.distance_to(target_pos)

	# Clamp target to reachable distance
	if target_distance > total_length * 0.99:
		target_distance = total_length * 0.99

	# Two-bone IK solution using law of cosines
	var a = upper_length
	var b = lower_length
	var c = target_distance

	# Angle at root (shoulder)
	var cos_root_angle = (a * a + c * c - b * b) / (2.0 * a * c)
	cos_root_angle = clamp(cos_root_angle, -1.0, 1.0)
	var root_angle = acos(cos_root_angle)

	# Angle at middle (elbow)
	var cos_middle_angle = (a * a + b * b - c * c) / (2.0 * a * b)
	cos_middle_angle = clamp(cos_middle_angle, -1.0, 1.0)
	var middle_angle = acos(cos_middle_angle)

	# Direction from root to target
	var root_to_target = (target_pos - root_pos).normalized()

	# Calculate the plane normal (pole vector)
	var pole_dir = Vector3.UP
	if pole_target:
		var to_pole = pole_target.global_position - root_pos
		pole_dir = to_pole.normalized()

	# Create rotation for root bone
	var forward = root_to_target
	var right = forward.cross(pole_dir).normalized()
	if right.length_squared() < 0.001:  # Vectors are parallel
		right = forward.cross(Vector3.RIGHT).normalized()
	var up = right.cross(forward).normalized()

	# Apply root rotation
	var root_basis = Basis(right, up, -forward)
	root_basis = root_basis.rotated(right, -root_angle)
	root_bone.global_transform.basis = root_bone.global_transform.basis.slerp(root_basis, blend_amount)

	# Apply middle rotation (elbow)
	var middle_basis = middle_bone.global_transform.basis
	var bend_axis = right
	var bend_rotation = Basis(bend_axis, PI - middle_angle)
	middle_bone.global_transform.basis = middle_bone.global_transform.basis.slerp(
		middle_basis * bend_rotation,
		blend_amount
	)

	# End effector points toward target
	if end_bone:
		var end_to_target = (target_pos - end_bone.global_position).normalized()
		var end_forward = -end_bone.global_transform.basis.z
		var rotation_to_target = end_forward.signed_angle_to(end_to_target, right)
		end_bone.rotate_object_local(right, rotation_to_target * blend_amount)

func reset_to_animation():
	"""Reset bones to their animated/original rotations"""
	if root_bone:
		root_bone.quaternion = original_root_rotation
	if middle_bone:
		middle_bone.quaternion = original_middle_rotation
	if end_bone:
		end_bone.quaternion = original_end_rotation
