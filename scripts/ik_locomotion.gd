extends Node
class_name IKLocomotion

## IK-based procedural locomotion system
## Handles walking, crouching, prone, and damage reactions using IK

@export var skeleton: Skeleton3D
@export var character_body: CharacterBody3D

# IK chains
var left_foot_ik: SkeletonIK3D
var right_foot_ik: SkeletonIK3D
var left_hand_ik_swing: SkeletonIK3D
var right_hand_ik_swing: SkeletonIK3D

# IK targets
var left_foot_target: Node3D
var right_foot_target: Node3D
var left_hand_target: Node3D
var right_hand_target: Node3D

# State
var ik_mode_enabled: bool = false
var walk_cycle: float = 0.0
var step_height: float = 0.15
var step_length: float = 0.4
var arm_swing_amount: float = 0.3

# Stance IK offsets
var current_stance_offset: float = 0.0  # 0 = standing, -0.5 = crouch, -1.5 = prone
var target_stance_offset: float = 0.0
var stance_transition_speed: float = 3.0

# Bone indices
var left_upperleg_idx: int = -1
var right_upperleg_idx: int = -1
var left_foot_idx: int = -1
var right_foot_idx: int = -1
var left_upperarm_idx: int = -1
var right_upperarm_idx: int = -1
var left_hand_idx: int = -1
var right_hand_idx: int = -1
var hips_idx: int = -1

# Damage reactions
var damage_reaction_time: float = 0.0
var damaged_limb: String = ""  # "left_arm", "right_arm", "left_leg", "right_leg"

# Jump state
var is_jumping: bool = false
var jump_time: float = 0.0
var jump_duration: float = 0.6

# Get-up state
var is_getting_up: bool = false
var get_up_time: float = 0.0
var get_up_duration: float = 1.5

func _ready():
	if not skeleton:
		print("IKLocomotion: No skeleton assigned!")
		return

	_cache_bone_indices()
	_create_ik_chains()
	_create_ik_targets()

	print("IKLocomotion: System initialized")

func _cache_bone_indices():
	"""Cache bone indices for performance"""
	left_upperleg_idx = skeleton.find_bone("characters3d.com___L_Upper_Leg")
	right_upperleg_idx = skeleton.find_bone("characters3d.com___R_Upper_Leg")
	left_foot_idx = skeleton.find_bone("characters3d.com___L_Foot")
	right_foot_idx = skeleton.find_bone("characters3d.com___R_Foot")
	left_upperarm_idx = skeleton.find_bone("characters3d.com___L_Upper_Arm")
	right_upperarm_idx = skeleton.find_bone("characters3d.com___R_Upper_Arm")
	left_hand_idx = skeleton.find_bone("characters3d.com___L_Hand")
	right_hand_idx = skeleton.find_bone("characters3d.com___R_Hand")
	hips_idx = skeleton.find_bone("characters3d.com___Hips")

	print("IKLocomotion: Cached bone indices")
	print("  Left foot: ", left_foot_idx, " Right foot: ", right_foot_idx)
	print("  Left hand: ", left_hand_idx, " Right hand: ", right_hand_idx)

func _create_ik_chains():
	"""Create IK chains for feet and hands"""
	# Left foot IK (upperleg -> foot)
	left_foot_ik = SkeletonIK3D.new()
	left_foot_ik.name = "LeftFootIK"
	left_foot_ik.root_bone = "characters3d.com___L_Upper_Leg"
	left_foot_ik.tip_bone = "characters3d.com___L_Foot"
	left_foot_ik.interpolation = 0.5
	skeleton.add_child(left_foot_ik)

	# Right foot IK (upperleg -> foot)
	right_foot_ik = SkeletonIK3D.new()
	right_foot_ik.name = "RightFootIK"
	right_foot_ik.root_bone = "characters3d.com___R_Upper_Leg"
	right_foot_ik.tip_bone = "characters3d.com___R_Foot"
	right_foot_ik.interpolation = 0.5
	skeleton.add_child(right_foot_ik)

	# Left hand IK for arm swing (upperarm -> hand)
	left_hand_ik_swing = SkeletonIK3D.new()
	left_hand_ik_swing.name = "LeftHandSwingIK"
	left_hand_ik_swing.root_bone = "characters3d.com___L_Upper_Arm"
	left_hand_ik_swing.tip_bone = "characters3d.com___L_Hand"
	left_hand_ik_swing.interpolation = 0.3
	skeleton.add_child(left_hand_ik_swing)

	# Right hand IK for arm swing (upperarm -> hand)
	right_hand_ik_swing = SkeletonIK3D.new()
	right_hand_ik_swing.name = "RightHandSwingIK"
	right_hand_ik_swing.root_bone = "characters3d.com___R_Upper_Arm"
	right_hand_ik_swing.tip_bone = "characters3d.com___R_Hand"
	right_hand_ik_swing.interpolation = 0.3
	skeleton.add_child(right_hand_ik_swing)

	print("IKLocomotion: Created IK chains")

func _create_ik_targets():
	"""Create target nodes for IK"""
	# Left foot target
	left_foot_target = Node3D.new()
	left_foot_target.name = "LeftFootTarget"
	skeleton.add_child(left_foot_target)
	left_foot_ik.target_node = left_foot_target.get_path()

	# Right foot target
	right_foot_target = Node3D.new()
	right_foot_target.name = "RightFootTarget"
	skeleton.add_child(right_foot_target)
	right_foot_ik.target_node = right_foot_target.get_path()

	# Left hand target
	left_hand_target = Node3D.new()
	left_hand_target.name = "LeftHandSwingTarget"
	skeleton.add_child(left_hand_target)
	left_hand_ik_swing.target_node = left_hand_target.get_path()

	# Right hand target
	right_hand_target = Node3D.new()
	right_hand_target.name = "RightHandSwingTarget"
	skeleton.add_child(right_hand_target)
	right_hand_ik_swing.target_node = right_hand_target.get_path()

	print("IKLocomotion: Created IK targets")

func enable_ik_mode():
	"""Enable IK-based locomotion"""
	ik_mode_enabled = true
	if left_foot_ik:
		left_foot_ik.start()
	if right_foot_ik:
		right_foot_ik.start()
	if left_hand_ik_swing:
		left_hand_ik_swing.start()
	if right_hand_ik_swing:
		right_hand_ik_swing.start()
	print("IKLocomotion: IK mode ENABLED")

func disable_ik_mode():
	"""Disable IK-based locomotion"""
	ik_mode_enabled = false
	if left_foot_ik:
		left_foot_ik.stop()
	if right_foot_ik:
		right_foot_ik.stop()
	if left_hand_ik_swing:
		left_hand_ik_swing.stop()
	if right_hand_ik_swing:
		right_hand_ik_swing.stop()
	print("IKLocomotion: IK mode DISABLED")

func update_locomotion(delta: float, velocity: Vector3, is_moving: bool, stance: int):
	"""Update IK-based locomotion"""
	if not ik_mode_enabled:
		return

	# Update get-up animation if active
	if is_getting_up:
		_update_get_up_animation(delta)
		return  # Skip normal locomotion during get-up

	# Update jump animation if active
	if is_jumping:
		_update_jump_animation(delta)

	# Update stance offset
	if not is_jumping:  # Don't change stance offset during jump
		match stance:
			0:  # Standing
				target_stance_offset = 0.0
			1:  # Crouching
				target_stance_offset = -0.5
			2:  # Prone
				target_stance_offset = -1.5

		current_stance_offset = lerp(current_stance_offset, target_stance_offset, stance_transition_speed * delta)

	# Update walking cycle
	if is_moving and not is_jumping:
		var speed = velocity.length()
		walk_cycle += delta * speed * 2.0  # Cycle speed based on movement

	# Update feet positions
	_update_feet_ik(delta, velocity, is_moving)

	# Update arm swing
	_update_arm_swing(delta, velocity, is_moving)

	# Update damage reactions
	if damage_reaction_time > 0:
		_update_damage_reaction(delta)
		damage_reaction_time -= delta

func _update_feet_ik(delta: float, velocity: Vector3, is_moving: bool):
	"""Update foot IK targets for walking"""
	if not left_foot_target or not right_foot_target or not character_body:
		return

	var char_pos = character_body.global_position
	var char_basis = character_body.global_transform.basis

	if is_moving:
		# Procedural walking - alternate feet
		var left_phase = sin(walk_cycle)
		var right_phase = sin(walk_cycle + PI)  # Opposite phase

		# Calculate foot positions
		var base_y = char_pos.y + current_stance_offset

		# Left foot
		var left_step = left_phase * step_length
		var left_lift = max(0, sin(walk_cycle)) * step_height
		left_foot_target.global_position = char_pos + char_basis * Vector3(-0.15, base_y + left_lift - char_pos.y, left_step)

		# Right foot
		var right_step = right_phase * step_length
		var right_lift = max(0, sin(walk_cycle + PI)) * step_height
		right_foot_target.global_position = char_pos + char_basis * Vector3(0.15, base_y + right_lift - char_pos.y, right_step)
	else:
		# Standing still - feet on ground with stance offset
		var base_y = char_pos.y + current_stance_offset
		left_foot_target.global_position = char_pos + char_basis * Vector3(-0.15, base_y - char_pos.y, 0)
		right_foot_target.global_position = char_pos + char_basis * Vector3(0.15, base_y - char_pos.y, 0)

func _update_arm_swing(delta: float, velocity: Vector3, is_moving: bool):
	"""Update arm IK targets for natural swing"""
	if not left_hand_target or not right_hand_target or not character_body:
		return

	var char_pos = character_body.global_position
	var char_basis = character_body.global_transform.basis

	if is_moving and current_stance_offset > -1.0:  # Don't swing arms in prone
		# Arms swing opposite to legs
		var left_arm_swing = -sin(walk_cycle + PI) * arm_swing_amount
		var right_arm_swing = -sin(walk_cycle) * arm_swing_amount

		# Position hands
		left_hand_target.global_position = char_pos + char_basis * Vector3(-0.3, -0.5 + current_stance_offset * 0.5, left_arm_swing)
		right_hand_target.global_position = char_pos + char_basis * Vector3(0.3, -0.5 + current_stance_offset * 0.5, right_arm_swing)
	else:
		# Arms at rest
		left_hand_target.global_position = char_pos + char_basis * Vector3(-0.3, -0.6 + current_stance_offset * 0.5, 0)
		right_hand_target.global_position = char_pos + char_basis * Vector3(0.3, -0.6 + current_stance_offset * 0.5, 0)

func set_stance_crouch():
	"""Transition to crouch stance via IK"""
	target_stance_offset = -0.5

func set_stance_prone():
	"""Transition to prone stance via IK"""
	target_stance_offset = -1.5

	# In prone, rotate body forward slightly (handled by controller)

func set_stance_standing():
	"""Transition to standing stance via IK"""
	target_stance_offset = 0.0

func start_jump():
	"""Start jump animation"""
	if is_jumping or is_getting_up:
		return

	is_jumping = true
	jump_time = 0.0
	print("IKLocomotion: Jump started")

func _update_jump_animation(delta: float):
	"""Update procedural jump animation"""
	jump_time += delta
	var progress = jump_time / jump_duration

	if progress >= 1.0:
		is_jumping = false
		jump_time = 0.0
		return

	# Jump arc - crouch down, then extend up
	if progress < 0.3:
		# Crouch phase
		var crouch_progress = progress / 0.3
		current_stance_offset = lerp(0.0, -0.4, crouch_progress)
	else:
		# Extend up phase
		var extend_progress = (progress - 0.3) / 0.7
		current_stance_offset = lerp(-0.4, 0.2, extend_progress)

	# Wave arms during jump
	if left_hand_target and right_hand_target and character_body:
		var char_pos = character_body.global_position
		var char_basis = character_body.global_transform.basis

		var arm_wave = sin(progress * PI * 2) * 0.2
		left_hand_target.global_position = char_pos + char_basis * Vector3(-0.4, -0.3 + arm_wave, 0)
		right_hand_target.global_position = char_pos + char_basis * Vector3(0.4, -0.3 + arm_wave, 0)

	# Feet together during jump
	if left_foot_target and right_foot_target and character_body:
		var char_pos = character_body.global_position
		var char_basis = character_body.global_transform.basis

		left_foot_target.global_position = char_pos + char_basis * Vector3(-0.1, current_stance_offset - char_pos.y, 0)
		right_foot_target.global_position = char_pos + char_basis * Vector3(0.1, current_stance_offset - char_pos.y, 0)

func play_get_up_animation():
	"""Start procedural get-up animation using IK"""
	if is_getting_up:
		return

	is_getting_up = true
	get_up_time = 0.0
	print("IKLocomotion: Get-up animation started")

func _update_get_up_animation(delta: float):
	"""Update procedural get-up animation"""
	get_up_time += delta
	var progress = get_up_time / get_up_duration

	if progress >= 1.0:
		is_getting_up = false
		get_up_time = 0.0
		current_stance_offset = 0.0
		print("IKLocomotion: Get-up complete")
		return

	if not character_body:
		return

	var char_pos = character_body.global_position
	var char_basis = character_body.global_transform.basis

	# Get-up sequence: prone -> push up with hands -> lift torso -> stand
	if progress < 0.3:
		# Phase 1: Push up with hands (0.0 - 0.3)
		var push_progress = progress / 0.3
		current_stance_offset = lerp(-1.5, -1.0, push_progress)

		# Hands push down
		if left_hand_target and right_hand_target:
			left_hand_target.global_position = char_pos + char_basis * Vector3(-0.3, -1.3, 0.2)
			right_hand_target.global_position = char_pos + char_basis * Vector3(0.3, -1.3, 0.2)

		# Feet stay on ground
		if left_foot_target and right_foot_target:
			left_foot_target.global_position = char_pos + char_basis * Vector3(-0.15, -1.5, -0.3)
			right_foot_target.global_position = char_pos + char_basis * Vector3(0.15, -1.5, -0.3)

	elif progress < 0.6:
		# Phase 2: Lift to kneeling (0.3 - 0.6)
		var kneel_progress = (progress - 0.3) / 0.3
		current_stance_offset = lerp(-1.0, -0.7, kneel_progress)

		# Hands move to sides
		if left_hand_target and right_hand_target:
			left_hand_target.global_position = char_pos + char_basis * Vector3(-0.4, -0.8, 0)
			right_hand_target.global_position = char_pos + char_basis * Vector3(0.4, -0.8, 0)

		# One foot forward (right foot)
		if left_foot_target and right_foot_target:
			left_foot_target.global_position = char_pos + char_basis * Vector3(-0.2, -1.0, -0.2)
			right_foot_target.global_position = char_pos + char_basis * Vector3(0.2, -0.8, 0.3)

	else:
		# Phase 3: Stand up (0.6 - 1.0)
		var stand_progress = (progress - 0.6) / 0.4
		current_stance_offset = lerp(-0.7, 0.0, stand_progress)

		# Arms return to rest
		if left_hand_target and right_hand_target:
			var rest_y = -0.6 + current_stance_offset * 0.5
			left_hand_target.global_position = char_pos + char_basis * Vector3(-0.3, rest_y, 0)
			right_hand_target.global_position = char_pos + char_basis * Vector3(0.3, rest_y, 0)

		# Feet spread to walking stance
		if left_foot_target and right_foot_target:
			var base_y = current_stance_offset
			left_foot_target.global_position = char_pos + char_basis * Vector3(-0.15, base_y, 0)
			right_foot_target.global_position = char_pos + char_basis * Vector3(0.15, base_y, 0)

func apply_damage_reaction(limb: String, strength: float = 1.0):
	"""Apply IK-based damage reaction to specific limb"""
	damaged_limb = limb
	damage_reaction_time = 0.5  # Duration of reaction

	print("IKLocomotion: Damage reaction on ", limb, " (strength: ", strength, ")")

func _update_damage_reaction(delta: float):
	"""Update damage reaction animation"""
	var reaction_progress = 1.0 - (damage_reaction_time / 0.5)

	# Pull damaged limb back based on reaction
	match damaged_limb:
		"left_arm":
			if left_hand_target:
				var pullback = sin(reaction_progress * PI) * 0.3
				left_hand_target.global_position += character_body.global_transform.basis * Vector3(0, -pullback, pullback)
		"right_arm":
			if right_hand_target:
				var pullback = sin(reaction_progress * PI) * 0.3
				right_hand_target.global_position += character_body.global_transform.basis * Vector3(0, -pullback, pullback)
		"left_leg":
			if left_foot_target:
				var pullback = sin(reaction_progress * PI) * 0.2
				left_foot_target.global_position += character_body.global_transform.basis * Vector3(0, pullback, pullback)
		"right_leg":
			if right_foot_target:
				var pullback = sin(reaction_progress * PI) * 0.2
				right_foot_target.global_position += character_body.global_transform.basis * Vector3(0, pullback, pullback)
