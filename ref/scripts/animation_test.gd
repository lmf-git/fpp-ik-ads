extends Node3D
class_name AnimationTest

## Animation and IK testing script focused on skeleton animations
##
## Controls:
## - Space: Play/Pause animation
## - N: Next animation
## - I: Toggle IK on/off (selective - only moved targets override animation)
## - R: Toggle ragdoll physics on/off
## - T: Reset character position
## - C: Reset IK targets instantly
## - V: Smooth reset IK targets (0.5s transition)

# Configuration
@export_group("Character Setup")
@export var character_model_path: String = "res://character.gltf"

@export_group("Physics Tuning")
@export var click_force_strength: float = 15.0  # Gentler click force
@export var head_mass: float = 0.2  # Lighter head
@export var neck_mass: float = 0.15  # Lighter neck
@export var gravity_strength: float = 0.7  # Lighter gravity for more natural ragdoll
var character_model: Node3D
var skeleton_3d: Skeleton3D
var animation_player: AnimationPlayer
var current_animation_index: int = 0
var animation_names: PackedStringArray = []
var is_playing: bool = false
var ik_enabled: bool = false
var is_ragdoll_active: bool = false
var ik_was_enabled_before_ragdoll: bool = false  # Track IK state before ragdoll activation

# Cache commonly used nodes with @onready
@onready var status_label: Label = find_child("Status")
@onready var camera: Camera3D = find_child("Camera3D")

# Performance optimization: Cache frequently used values
var cached_world_3d: World3D
var cached_space_state: PhysicsDirectSpaceState3D

# Constraint consistency system
# Removed constraint verification system - no longer needed

# IK target tracking for selective blending
var target_original_positions: Dictionary = {}
var target_moved_threshold: float = 0.1  # Minimum distance to consider target "moved"

# Ragdoll sleep system
var ragdoll_sleep_threshold: float = 0.05  # Velocity below which ragdoll sleeps
var ragdoll_wake_threshold: float = 0.2    # Velocity above which ragdoll wakes
var ragdoll_sleeping: bool = false
var last_ragdoll_position: Vector3
var ragdoll_sleep_timer: float = 0.0
var ragdoll_sleep_delay: float = 2.0       # Seconds before allowing sleep

# IK chains - arm and leg system
var left_shoulder_ik: SkeletonIK3D    # shoulder -> upperarm
var right_shoulder_ik: SkeletonIK3D
var left_elbow_ik: SkeletonIK3D       # upperarm -> lowerarm
var right_elbow_ik: SkeletonIK3D
var left_hand_ik: SkeletonIK3D        # lowerarm -> hand
var right_hand_ik: SkeletonIK3D
var left_knee_ik: SkeletonIK3D        # upperleg -> lowerleg
var right_knee_ik: SkeletonIK3D
var left_foot_ik: SkeletonIK3D        # lowerleg -> foot
var right_foot_ik: SkeletonIK3D
var left_wrist_ik: SkeletonIK3D       # upperarm -> hand (more freedom than hand IK)
var right_wrist_ik: SkeletonIK3D
var left_ankle_ik: SkeletonIK3D       # upperleg -> foot (more freedom than foot IK)
var right_ankle_ik: SkeletonIK3D
var left_toes_ik: SkeletonIK3D        # foot -> toes
var right_toes_ik: SkeletonIK3D
var left_thumb_ik: SkeletonIK3D       # hand -> thumb tip
var right_thumb_ik: SkeletonIK3D
var left_index_ik: SkeletonIK3D       # hand -> index tip
var right_index_ik: SkeletonIK3D
var head_ik: SkeletonIK3D             # neck -> head

# IK targets - arm and leg system (no hip targets)
var left_shoulder_target: Node3D  # Left shoulder positioning
var right_shoulder_target: Node3D # Right shoulder positioning
var left_elbow_target: Node3D     # Left elbow positioning
var right_elbow_target: Node3D    # Right elbow positioning
var left_hand_target: Node3D      # Left hand positioning
var right_hand_target: Node3D     # Right hand positioning
var left_wrist_target: Node3D     # Left wrist positioning (more freedom)
var right_wrist_target: Node3D    # Right wrist positioning (more freedom)
var left_knee_target: Node3D      # Left knee positioning
var right_knee_target: Node3D     # Right knee positioning
var left_foot_target: Node3D      # Left foot positioning
var right_foot_target: Node3D     # Right foot positioning
var left_ankle_target: Node3D     # Left ankle positioning (more freedom)
var right_ankle_target: Node3D    # Right ankle positioning (more freedom)
var left_toes_target: Node3D      # Left toes positioning
var right_toes_target: Node3D     # Right toes positioning
var left_thumb_target: Node3D     # Left thumb positioning
var right_thumb_target: Node3D    # Right thumb positioning
var left_index_target: Node3D     # Left index finger positioning
var right_index_target: Node3D    # Right index finger positioning
var head_target: Node3D           # Head control

# Ragdoll toggle targets - for partial ragdoll control
var left_arm_ragdoll_toggle: Node3D    # Toggle ragdoll for left arm
var right_arm_ragdoll_toggle: Node3D   # Toggle ragdoll for right arm
var left_leg_ragdoll_toggle: Node3D    # Toggle ragdoll for left leg
var right_leg_ragdoll_toggle: Node3D   # Toggle ragdoll for right leg
var torso_ragdoll_toggle: Node3D       # Toggle ragdoll for torso/spine
var head_ragdoll_toggle: Node3D        # Toggle ragdoll for head/neck

# Ragdoll state tracking
var left_arm_ragdoll_active: bool = false
var right_arm_ragdoll_active: bool = false
var left_leg_ragdoll_active: bool = false
var right_leg_ragdoll_active: bool = false
var torso_ragdoll_active: bool = false
var head_ragdoll_active: bool = false

# UI reference
var key_hints_label: Label

# Mouse interaction
var selected_target: Node3D = null
# camera is now declared with @onready

# Camera orbit controls
var camera_orbit_enabled: bool = false
var camera_orbit_speed: float = 2.0
var camera_distance: float = 5.0
var camera_height: float = 2.0
var camera_angle_h: float = 0.0  # Horizontal angle
var camera_angle_v: float = -20.0  # Vertical angle (degrees)
var camera_target_position: Vector3 = Vector3.ZERO

# IK constraints
var max_arm_reach: float = 1.2  # Maximum arm reach distance
var max_leg_reach: float = 1.8  # Maximum leg reach distance

func _ready() -> void:
	print("=== ANIMATION & IK TEST STARTING ===")
	# UI elements are now cached with @onready
	create_ground_plane()
	load_character()

	# Show controls after a brief delay to let everything initialize
	# Use direct await for better performance in Godot 4
	await get_tree().process_frame
	await get_tree().process_frame  # Wait 2 frames for initialization
	show_controls_help()

	# Create on-screen key hints display
	create_key_hints_display()

	# Cache commonly used objects for performance
	cached_world_3d = get_world_3d()
	cached_space_state = cached_world_3d.direct_space_state

func _exit_tree() -> void:
	"""Godot 4 best practice: Clean up resources on exit"""
	if character_model:
		character_model = null
	if skeleton_3d:
		skeleton_3d = null
	if animation_player:
		animation_player = null
	if key_hints_label:
		key_hints_label = null

func _process(_delta: float) -> void:
	# Update bone transitions for smooth animation mixing
	update_bone_transitions(_delta)

	# Update advanced physics-animation blending
	update_physics_animation_blending(_delta)

	# Update camera position if character is loaded
	if character_model and camera:
		camera_target_position = character_model.global_position
		update_camera_orbit()

	# Handle ragdoll safety checks
	if is_ragdoll_active:
		# Safety check: ensure no IK is running during ragdoll mode
		ensure_ik_disabled_during_ragdoll()
		# Re-enabled ragdoll sleep system with improved logic to prevent mesh stretching
		if is_ragdoll_active:
			update_ragdoll_sleep_state(_delta)

		# Removed periodic constraint verification - constraints should be set once and stay

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				toggle_animation()
			KEY_N:
				next_animation()
			KEY_I:
				toggle_ik()
			KEY_R:
				toggle_ragdoll()
			KEY_T:
				reset_character()
			KEY_C:
				reset_ik_targets()
			KEY_V:
				if ik_enabled:
					smooth_reset_ik_targets(0.5)
			KEY_O:  # Toggle camera orbit mode
				camera_orbit_enabled = !camera_orbit_enabled
				print("Camera orbit: ", "enabled" if camera_orbit_enabled else "disabled")
			KEY_B:  # Test physics blending on arms
				test_physics_blending()
			KEY_M:  # Test partial arm physics with blending (left arm)
				test_partial_arm_blending()
			KEY_L:  # Toggle left arm ragdoll specifically
				toggle_left_arm_ragdoll()
			KEY_K:  # Toggle right arm ragdoll specifically
				toggle_right_arm_ragdoll()
			KEY_J:  # Toggle both arms ragdoll
				toggle_both_arms_ragdoll()
			KEY_S:  # Test seamless full ragdoll transition
				test_seamless_ragdoll()
			KEY_H:  # Show help/controls
				show_controls_help()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if camera_orbit_enabled:
					# Do nothing while orbiting camera
					pass
				else:
					# Try body click first for ragdoll activation with force
					var body_hit = try_body_click_ragdoll(event.position)
					if not body_hit:
						# Fall back to IK target selection if no body hit
						select_target_at_mouse(event.position)
			else:
				selected_target = null
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				camera_orbit_enabled = true
			else:
				camera_orbit_enabled = false
	elif event is InputEventMouseMotion:
		if camera_orbit_enabled:
			orbit_camera_with_mouse(event.relative)
		elif selected_target:
			move_target_with_mouse(event.position)

func load_character():
	"""Load the character model and set up animation system"""
	# Clear existing character
	if character_model:
		character_model.queue_free()
		await character_model.tree_exited

	# Load new character
	var scene = load(character_model_path)
	if scene == null:
		print("ERROR: Could not load character model at path: ", character_model_path)
		print("Please ensure the file exists and is properly imported")
		return

	character_model = scene.instantiate()
	add_child(character_model)

	# Find skeleton and animation player
	skeleton_3d = find_skeleton(character_model)
	animation_player = find_animation_player(character_model)

	if skeleton_3d:
		print("Found skeleton with ", skeleton_3d.get_bone_count(), " bones")
		setup_ik_system()
		setup_ragdoll_system()
	else:
		print("ERROR: No skeleton found in character model")

	if animation_player:
		print("Found animation player")
		discover_animations()

		# Auto-play first animation if available
		if animation_names.size() > 0:
			var first_anim = animation_names[0]
			animation_player.play(first_anim)
			is_playing = true
			print("Auto-playing animation: ", first_anim)
		else:
			print("No animations found in model file")
	else:
		print("No animation player found in character model")

	update_status()

func find_skeleton(node: Node) -> Skeleton3D:
	"""Recursively find Skeleton3D in the character model"""
	if node is Skeleton3D:
		return node

	for child in node.get_children():
		var result = find_skeleton(child)
		if result:
			return result

	return null

func find_animation_player(node: Node) -> AnimationPlayer:
	"""Recursively find AnimationPlayer in the character model"""
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var result = find_animation_player(child)
		if result:
			return result

	return null

func discover_animations():
	"""Get list of available animations"""
	if not animation_player:
		return

	animation_names.clear()
	print("=== ANIMATION DISCOVERY ===")

	var library = animation_player.get_animation_library("")
	if library:
		print("Animation library found")
		for anim_name in library.get_animation_list():
			animation_names.append(anim_name)
			var animation = library.get_animation(anim_name)
			var duration = animation.length
			print("Animation: '", anim_name, "' (", duration, "s)")

	if animation_names.size() > 0:
		current_animation_index = 0
		print("Total animations in model: ", animation_names.size())
		print("Animations will play automatically until IK mode is enabled")
	else:
		print("No animations found in model file")
		print("Model contains only static pose")

func setup_ik_system():
	"""Set up IK chains for arms and legs"""
	if not skeleton_3d:
		return


	# Create IK chains for arms (3-part system: shoulder/elbow/hand)
	left_shoulder_ik = create_shoulder_ik("left")
	right_shoulder_ik = create_shoulder_ik("right")
	left_elbow_ik = create_elbow_ik("left")
	right_elbow_ik = create_elbow_ik("right")
	left_hand_ik = create_hand_ik("left")
	right_hand_ik = create_hand_ik("right")
	left_wrist_ik = create_wrist_ik("left")
	right_wrist_ik = create_wrist_ik("right")

	# Create IK chains for legs (2-part system: knee/foot only)
	left_knee_ik = create_knee_ik("left")
	right_knee_ik = create_knee_ik("right")
	left_foot_ik = create_foot_ik("left")
	right_foot_ik = create_foot_ik("right")
	left_ankle_ik = create_ankle_ik("left")
	right_ankle_ik = create_ankle_ik("right")

	# Create IK chains for detailed hand/foot control
	left_toes_ik = create_toes_ik("left")
	right_toes_ik = create_toes_ik("right")
	left_thumb_ik = create_thumb_ik("left")
	right_thumb_ik = create_thumb_ik("right")
	left_index_ik = create_index_ik("left")
	right_index_ik = create_index_ik("right")

	# Create IK chain for head
	head_ik = create_head_ik()

	# Create IK targets
	create_ik_targets()

	print("IK system ready")

func create_shoulder_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for shoulder (shoulder -> upperarm)"""
	var ik = SkeletonIK3D.new()
	ik.name = "ShoulderIK_" + side

	var shoulder_bone_name = ""
	var upperarm_bone_name = ""

	shoulder_bone_name = find_bone_by_pattern_exact_side(["shoulder", "clavicle", "Shoulder"], side)
	upperarm_bone_name = find_bone_by_pattern_exact_side(["upper_arm", "upperarm", "Upper_Arm"], side)

	if shoulder_bone_name != "" and upperarm_bone_name != "":
		# Verify bone hierarchy is correct (root index < tip index)
		var shoulder_idx = skeleton_3d.find_bone(shoulder_bone_name)
		var upperarm_idx = skeleton_3d.find_bone(upperarm_bone_name)

		if shoulder_idx < upperarm_idx:
			ik.root_bone = shoulder_bone_name
			ik.tip_bone = upperarm_bone_name
			ik.interpolation = 0.7
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " shoulder IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " shoulder: ", shoulder_idx, " >= ", upperarm_idx)
			return null
	else:
		print("Could not find shoulder bones for ", side, " side")
		print("Searched for shoulder: ", shoulder_bone_name, " upperarm: ", upperarm_bone_name)
		return null


func create_elbow_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for elbow (upperarm -> lowerarm)"""
	var ik = SkeletonIK3D.new()
	ik.name = "ElbowIK_" + side

	var upperarm_bone_name = ""
	var lowerarm_bone_name = ""

	upperarm_bone_name = find_bone_by_pattern_exact_side(["upper_arm", "upperarm", "Upper_Arm"], side)
	lowerarm_bone_name = find_bone_by_pattern_exact_side(["lower_arm", "lowerarm", "Lower_Arm"], side)

	if upperarm_bone_name != "" and lowerarm_bone_name != "":
		# Verify bone hierarchy is correct
		var upperarm_idx = skeleton_3d.find_bone(upperarm_bone_name)
		var lowerarm_idx = skeleton_3d.find_bone(lowerarm_bone_name)

		if upperarm_idx < lowerarm_idx:
			ik.root_bone = upperarm_bone_name
			ik.tip_bone = lowerarm_bone_name
			ik.interpolation = 0.6
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " elbow IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " elbow: ", upperarm_idx, " >= ", lowerarm_idx)
			return null
	else:
		print("Could not find elbow bones for ", side, " side")
		print("Searched for upperarm: ", upperarm_bone_name, " lowerarm: ", lowerarm_bone_name)
		return null

func create_hand_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for hand (lowerarm -> hand)"""
	var ik = SkeletonIK3D.new()
	ik.name = "HandIK_" + side

	var lowerarm_bone_name = ""
	var hand_bone_name = ""

	lowerarm_bone_name = find_bone_by_pattern_exact_side(["lower_arm", "lowerarm", "Lower_Arm"], side)
	hand_bone_name = find_bone_by_pattern_exact_side(["hand", "Hand"], side)

	if lowerarm_bone_name != "" and hand_bone_name != "":
		# Verify bone hierarchy is correct
		var lowerarm_idx = skeleton_3d.find_bone(lowerarm_bone_name)
		var hand_idx = skeleton_3d.find_bone(hand_bone_name)

		if lowerarm_idx < hand_idx:
			ik.root_bone = lowerarm_bone_name
			ik.tip_bone = hand_bone_name
			ik.interpolation = 0.8
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " hand IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " hand: ", lowerarm_idx, " >= ", hand_idx)
			return null
	else:
		print("Could not find hand bones for ", side, " side")
		print("Searched for lowerarm: ", lowerarm_bone_name, " hand: ", hand_bone_name)
		return null


func create_knee_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for knee (upperleg -> lowerleg)"""
	var ik = SkeletonIK3D.new()
	ik.name = "KneeIK_" + side

	var upperleg_bone_name = ""
	var lowerleg_bone_name = ""

	upperleg_bone_name = find_bone_by_pattern_exact_side(["upper_leg", "upperleg", "Upper_Leg", "thigh"], side)
	lowerleg_bone_name = find_bone_by_pattern_exact_side(["lower_leg", "lowerleg", "Lower_Leg", "calf", "shin"], side)

	if upperleg_bone_name != "" and lowerleg_bone_name != "":
		# Verify bone hierarchy is correct
		var upperleg_idx = skeleton_3d.find_bone(upperleg_bone_name)
		var lowerleg_idx = skeleton_3d.find_bone(lowerleg_bone_name)

		if upperleg_idx < lowerleg_idx:
			ik.root_bone = upperleg_bone_name
			ik.tip_bone = lowerleg_bone_name
			ik.interpolation = 0.7
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " knee IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " knee: ", upperleg_idx, " >= ", lowerleg_idx)
			return null
	else:
		print("Could not find knee bones for ", side, " side")
		print("Searched for upperleg: ", upperleg_bone_name, " lowerleg: ", lowerleg_bone_name)
		return null

func create_foot_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for foot (lowerleg -> foot)"""
	var ik = SkeletonIK3D.new()
	ik.name = "FootIK_" + side

	var lowerleg_bone_name = ""
	var foot_bone_name = ""

	lowerleg_bone_name = find_bone_by_pattern_exact_side(["lower_leg", "lowerleg", "Lower_Leg", "calf", "shin"], side)
	foot_bone_name = find_bone_by_pattern_exact_side(["foot", "ankle", "Foot"], side)

	if lowerleg_bone_name != "" and foot_bone_name != "":
		# Verify bone hierarchy is correct
		var lowerleg_idx = skeleton_3d.find_bone(lowerleg_bone_name)
		var foot_idx = skeleton_3d.find_bone(foot_bone_name)

		if lowerleg_idx < foot_idx:
			ik.root_bone = lowerleg_bone_name
			ik.tip_bone = foot_bone_name
			ik.interpolation = 0.8
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " foot IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " foot: ", lowerleg_idx, " >= ", foot_idx)
			return null
	else:
		print("Could not find foot bones for ", side, " side")
		print("Searched for lowerleg: ", lowerleg_bone_name, " foot: ", foot_bone_name)
		return null


func create_wrist_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for wrist (upperarm -> hand) - more freedom than hand IK"""
	var ik = SkeletonIK3D.new()
	ik.name = "WristIK_" + side

	var upperarm_bone_name = ""
	var hand_bone_name = ""

	upperarm_bone_name = find_bone_by_pattern_exact_side(["upper_arm", "upperarm", "Upper_Arm"], side)
	hand_bone_name = find_bone_by_pattern_exact_side(["hand", "Hand"], side)

	if upperarm_bone_name != "" and hand_bone_name != "":
		var upperarm_idx = skeleton_3d.find_bone(upperarm_bone_name)
		var hand_idx = skeleton_3d.find_bone(hand_bone_name)

		if upperarm_idx < hand_idx:
			ik.root_bone = upperarm_bone_name
			ik.tip_bone = hand_bone_name
			ik.interpolation = 0.9  # Higher interpolation for more freedom
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " wrist IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " wrist")
			return null
	else:
		print("Could not find wrist bones for ", side, " side")
		return null

func create_ankle_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for ankle (upperleg -> foot) - more freedom than foot IK"""
	var ik = SkeletonIK3D.new()
	ik.name = "AnkleIK_" + side

	var upperleg_bone_name = ""
	var foot_bone_name = ""

	upperleg_bone_name = find_bone_by_pattern_exact_side(["upper_leg", "upperleg", "Upper_Leg", "thigh"], side)
	foot_bone_name = find_bone_by_pattern_exact_side(["foot", "Foot"], side)

	if upperleg_bone_name != "" and foot_bone_name != "":
		var upperleg_idx = skeleton_3d.find_bone(upperleg_bone_name)
		var foot_idx = skeleton_3d.find_bone(foot_bone_name)

		if upperleg_idx < foot_idx:
			ik.root_bone = upperleg_bone_name
			ik.tip_bone = foot_bone_name
			ik.interpolation = 0.9  # Higher interpolation for more freedom
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " ankle IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " ankle")
			return null
	else:
		print("Could not find ankle bones for ", side, " side")
		return null

func create_toes_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for toes (foot -> toes)"""
	var ik = SkeletonIK3D.new()
	ik.name = "ToesIK_" + side

	var foot_bone_name = ""
	var toes_bone_name = ""

	foot_bone_name = find_bone_by_pattern_exact_side(["foot", "Foot"], side)
	toes_bone_name = find_bone_by_pattern_exact_side(["toes", "Toes"], side)

	if foot_bone_name != "" and toes_bone_name != "":
		var foot_idx = skeleton_3d.find_bone(foot_bone_name)
		var toes_idx = skeleton_3d.find_bone(toes_bone_name)

		if foot_idx < toes_idx:
			ik.root_bone = foot_bone_name
			ik.tip_bone = toes_bone_name
			ik.interpolation = 0.9
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " toes IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " toes: ", foot_idx, " >= ", toes_idx)
			return null
	else:
		print("Could not find toes bones for ", side, " side (this is normal if model has no toe bones)")
		return null

func create_thumb_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for thumb (hand -> thumb distal tip)"""
	var ik = SkeletonIK3D.new()
	ik.name = "ThumbIK_" + side

	var hand_bone_name = ""
	var thumb_tip_bone_name = ""

	hand_bone_name = find_bone_by_pattern_exact_side(["hand", "Hand"], side)
	thumb_tip_bone_name = find_bone_by_pattern_exact_side(["thumb_distal_tip", "Thumb_Distal_Tip"], side)

	if hand_bone_name != "" and thumb_tip_bone_name != "":
		var hand_idx = skeleton_3d.find_bone(hand_bone_name)
		var thumb_idx = skeleton_3d.find_bone(thumb_tip_bone_name)

		if hand_idx < thumb_idx:
			ik.root_bone = hand_bone_name
			ik.tip_bone = thumb_tip_bone_name
			ik.interpolation = 0.9
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " thumb IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " thumb: ", hand_idx, " >= ", thumb_idx)
			return null
	else:
		print("Could not find thumb bones for ", side, " side (this is normal if model has no finger bones)")
		return null

func create_index_ik(side: String) -> SkeletonIK3D:
	"""Create IK chain for index finger (hand -> index distal tip)"""
	var ik = SkeletonIK3D.new()
	ik.name = "IndexIK_" + side

	var hand_bone_name = ""
	var index_tip_bone_name = ""

	hand_bone_name = find_bone_by_pattern_exact_side(["hand", "Hand"], side)
	index_tip_bone_name = find_bone_by_pattern_exact_side(["index_distal_tip", "Index_Distal_Tip"], side)

	if hand_bone_name != "" and index_tip_bone_name != "":
		var hand_idx = skeleton_3d.find_bone(hand_bone_name)
		var index_idx = skeleton_3d.find_bone(index_tip_bone_name)

		if hand_idx < index_idx:
			ik.root_bone = hand_bone_name
			ik.tip_bone = index_tip_bone_name
			ik.interpolation = 0.9
			ik.override_tip_basis = false
			skeleton_3d.add_child(ik)
			print("Created ", side, " index IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for ", side, " index: ", hand_idx, " >= ", index_idx)
			return null
	else:
		print("Could not find index finger bones for ", side, " side (this is normal if model has no finger bones)")
		return null

func create_head_ik() -> SkeletonIK3D:
	"""Create IK chain for head - configured for looking/tilting"""
	var ik = SkeletonIK3D.new()
	ik.name = "HeadIK"

	# Find neck and head bones properly
	var neck_bone = find_bone_by_pattern(["neck"])
	var head_bone = find_bone_by_pattern(["head"])

	if neck_bone != "" and head_bone != "":
		# Verify bone hierarchy is correct
		var neck_idx = skeleton_3d.find_bone(neck_bone)
		var head_idx = skeleton_3d.find_bone(head_bone)

		if neck_idx < head_idx:
			ik.root_bone = neck_bone
			ik.tip_bone = head_bone
			ik.interpolation = 0.8  # Higher interpolation for smoother head movement
			ik.override_tip_basis = true   # Enable for proper head tilting/rotation
			ik.use_magnet = false  # Keep disabled for predictable behavior
			ik.min_distance = 0.01  # Fine-tune minimum distance for better accuracy
			ik.max_iterations = 20  # Increase iterations for better convergence
			skeleton_3d.add_child(ik)
			print("Created head IK chain: ", ik.root_bone, " -> ", ik.tip_bone)
			return ik
		else:
			print("Invalid bone hierarchy for head: ", neck_idx, " >= ", head_idx)
			return null
	else:
		print("Could not find head bones - neck: ", neck_bone, " head: ", head_bone)
		return null

func find_bone_by_name(possible_names: Array) -> int:
	"""Find bone index by trying multiple possible names"""
	if not skeleton_3d:
		return -1

	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i)
		for possible_name in possible_names:
			if bone_name == possible_name:  # Exact match first
				return i
	return -1

func find_bone_by_pattern(patterns: Array) -> String:
	"""Find bone name by trying multiple possible patterns (case insensitive contains match)"""
	if not skeleton_3d:
		return ""

	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i)
		var bone_name_lower = bone_name.to_lower()

		for pattern in patterns:
			var pattern_lower = pattern.to_lower()
			if pattern_lower in bone_name_lower:
				print("Found bone '", bone_name, "' matching pattern '", pattern, "'")
				return bone_name

	print("No bone found matching patterns: ", patterns)
	return ""

func find_bone_by_pattern_exact_side(patterns: Array, side: String) -> String:
	"""Find bone name with exact left/right side matching to prevent cross-side errors"""
	if not skeleton_3d:
		return ""

	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i)
		var bone_name_lower = bone_name.to_lower()

		# Check if this bone is for the correct side - match the specific pattern
		var is_correct_side = false
		if side == "left":
			# Look for the specific left pattern in this model
			is_correct_side = "___l_" in bone_name_lower
		elif side == "right":
			# Look for the specific right pattern in this model
			is_correct_side = "___r_" in bone_name_lower

		if is_correct_side:
			for pattern in patterns:
				var pattern_lower = pattern.to_lower()
				if pattern_lower in bone_name_lower:
					print("Found ", side, " bone '", bone_name, "' matching pattern '", pattern, "'")
					return bone_name

	print("No ", side, " bone found matching patterns: ", patterns)
	return ""

func create_ik_targets():
	"""Create visual targets for IK positioning"""
	if not skeleton_3d or not character_model:
		return

	# Get actual bone positions from skeleton
	var skeleton_transform = character_model.get_global_transform() * skeleton_3d.transform

	# Create targets for complete joint coverage system

	# ARM TARGETS - 3-part system: shoulder/elbow/hand
	# Shoulder targets - position at the TIP bone (upperarm) since that's what the shoulder IK controls
	var left_upperarm_bone = find_bone_by_pattern_exact_side(["upper_arm", "upperarm", "Upper_Arm"], "left")
	var right_upperarm_bone = find_bone_by_pattern_exact_side(["upper_arm", "upperarm", "Upper_Arm"], "right")


	if left_upperarm_bone != "":
		var left_upperarm_idx = skeleton_3d.find_bone(left_upperarm_bone)
		var left_upperarm_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_upperarm_idx).origin
		# Position target at the actual bone location (no offset confusion)
		left_shoulder_target = create_target("LeftShoulderTarget", left_upperarm_pos)

	if right_upperarm_bone != "":
		var right_upperarm_idx = skeleton_3d.find_bone(right_upperarm_bone)
		var right_upperarm_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_upperarm_idx).origin
		# Position target at the actual bone location (no offset confusion)
		right_shoulder_target = create_target("RightShoulderTarget", right_upperarm_pos)

	# Elbow targets - position at the TIP bone (lowerarm) since that's what the elbow IK controls
	var left_lowerarm_bone = find_bone_by_pattern_exact_side(["lower_arm", "lowerarm", "Lower_Arm"], "left")
	var right_lowerarm_bone = find_bone_by_pattern_exact_side(["lower_arm", "lowerarm", "Lower_Arm"], "right")

	if left_lowerarm_bone != "":
		var left_lowerarm_idx = skeleton_3d.find_bone(left_lowerarm_bone)
		var left_lowerarm_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_lowerarm_idx).origin
		left_elbow_target = create_target("LeftElbowTarget", left_lowerarm_pos)

	if right_lowerarm_bone != "":
		var right_lowerarm_idx = skeleton_3d.find_bone(right_lowerarm_bone)
		var right_lowerarm_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_lowerarm_idx).origin
		right_elbow_target = create_target("RightElbowTarget", right_lowerarm_pos)

	# Hand targets - position at the TIP bone (hand) since that's what the hand IK controls
	var left_hand_bone = find_bone_by_pattern_exact_side(["hand", "Hand"], "left")
	var right_hand_bone = find_bone_by_pattern_exact_side(["hand", "Hand"], "right")

	if left_hand_bone != "":
		var left_hand_idx = skeleton_3d.find_bone(left_hand_bone)
		var left_hand_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_hand_idx).origin
		left_hand_target = create_target("LeftHandTarget", left_hand_pos)
		# Create wrist target at same position but offset slightly
		left_wrist_target = create_target("LeftWristTarget", left_hand_pos + Vector3(-0.1, 0, 0))

	if right_hand_bone != "":
		var right_hand_idx = skeleton_3d.find_bone(right_hand_bone)
		var right_hand_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_hand_idx).origin
		right_hand_target = create_target("RightHandTarget", right_hand_pos)
		# Create wrist target at same position but offset slightly
		right_wrist_target = create_target("RightWristTarget", right_hand_pos + Vector3(0.1, 0, 0))

	# LEG TARGETS - 2-part system: knee/foot only (no hip targets)
	# Knee targets - position at the TIP bone (lowerleg) since that's what the knee IK controls
	var left_lowerleg_bone = find_bone_by_pattern_exact_side(["lower_leg", "lowerleg", "Lower_Leg", "calf", "shin"], "left")
	var right_lowerleg_bone = find_bone_by_pattern_exact_side(["lower_leg", "lowerleg", "Lower_Leg", "calf", "shin"], "right")

	if left_lowerleg_bone != "":
		var left_lowerleg_idx = skeleton_3d.find_bone(left_lowerleg_bone)
		var left_lowerleg_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_lowerleg_idx).origin
		left_knee_target = create_target("LeftKneeTarget", left_lowerleg_pos)

	if right_lowerleg_bone != "":
		var right_lowerleg_idx = skeleton_3d.find_bone(right_lowerleg_bone)
		var right_lowerleg_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_lowerleg_idx).origin
		right_knee_target = create_target("RightKneeTarget", right_lowerleg_pos)

	# Foot targets - position at the TIP bone (foot) since that's what the foot IK controls
	var left_foot_bone = find_bone_by_pattern_exact_side(["foot", "ankle", "Foot"], "left")
	var right_foot_bone = find_bone_by_pattern_exact_side(["foot", "ankle", "Foot"], "right")

	if left_foot_bone != "":
		var left_foot_idx = skeleton_3d.find_bone(left_foot_bone)
		var left_foot_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_foot_idx).origin
		left_foot_target = create_target("LeftFootTarget", left_foot_pos)
		# Create ankle target at same position but offset slightly
		left_ankle_target = create_target("LeftAnkleTarget", left_foot_pos + Vector3(-0.1, 0, 0))

	if right_foot_bone != "":
		var right_foot_idx = skeleton_3d.find_bone(right_foot_bone)
		var right_foot_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_foot_idx).origin
		right_foot_target = create_target("RightFootTarget", right_foot_pos)
		# Create ankle target at same position but offset slightly
		right_ankle_target = create_target("RightAnkleTarget", right_foot_pos + Vector3(0.1, 0, 0))

	# Toes targets - only create if toes IK chains exist
	if left_toes_ik:
		var left_toes_bone = left_toes_ik.tip_bone
		var left_toes_idx = skeleton_3d.find_bone(left_toes_bone)
		var left_toes_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_toes_idx).origin
		left_toes_target = create_target("LeftToesTarget", left_toes_pos)

	if right_toes_ik:
		var right_toes_bone = right_toes_ik.tip_bone
		var right_toes_idx = skeleton_3d.find_bone(right_toes_bone)
		var right_toes_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_toes_idx).origin
		right_toes_target = create_target("RightToesTarget", right_toes_pos)

	# Thumb targets - only create if thumb IK chains exist
	if left_thumb_ik:
		var left_thumb_bone = left_thumb_ik.tip_bone
		var left_thumb_idx = skeleton_3d.find_bone(left_thumb_bone)
		var left_thumb_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_thumb_idx).origin
		left_thumb_target = create_target("LeftThumbTarget", left_thumb_pos)

	if right_thumb_ik:
		var right_thumb_bone = right_thumb_ik.tip_bone
		var right_thumb_idx = skeleton_3d.find_bone(right_thumb_bone)
		var right_thumb_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_thumb_idx).origin
		right_thumb_target = create_target("RightThumbTarget", right_thumb_pos)

	# Index finger targets - only create if index IK chains exist
	if left_index_ik:
		var left_index_bone = left_index_ik.tip_bone
		var left_index_idx = skeleton_3d.find_bone(left_index_bone)
		var left_index_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_index_idx).origin
		left_index_target = create_target("LeftIndexTarget", left_index_pos)

	if right_index_ik:
		var right_index_bone = right_index_ik.tip_bone
		var right_index_idx = skeleton_3d.find_bone(right_index_bone)
		var right_index_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_index_idx).origin
		right_index_target = create_target("RightIndexTarget", right_index_pos)

	# Head target - position at head bone with small forward offset
	var head_bone = find_bone_by_pattern(["head", "Head"])
	if head_bone != "":
		var head_idx = skeleton_3d.find_bone(head_bone)
		var head_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(head_idx).origin
		head_target = create_target("HeadTarget", head_pos + Vector3(0, 0, 0.1))
	else:
		print("WARNING: Could not find head bone, skipping head target creation")

	# Create ragdoll toggle targets near body parts
	create_ragdoll_toggle_targets()

func create_target(target_name: String, pos: Vector3) -> Node3D:
	"""Create a visual target marker"""
	var target = Node3D.new()
	target.name = target_name

	# Offset targets away from character to avoid click conflicts
	var offset_pos = pos
	if character_model:
		var character_pos = character_model.global_position
		var direction_from_character = (pos - character_pos).normalized()
		# Move targets 0.3 units further away from character center
		offset_pos = pos + direction_from_character * 0.3

	target.position = offset_pos

	# Create collision body for mouse interaction (StaticBody3D on separate layer)
	var static_body = StaticBody3D.new()
	target.add_child(static_body)

	# Create collision shape for mouse detection
	var collision_shape = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.08
	collision_shape.shape = sphere_shape
	static_body.add_child(collision_shape)

	# Set collision layers for IK targets (separate from ragdoll physics)
	static_body.collision_layer = 64  # IK target layer (bit 6) - separate from ragdoll
	static_body.collision_mask = 0    # Don't collide with anything

	# Create visual representation
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	mesh_instance.mesh = sphere_mesh
	target.add_child(mesh_instance)

	# Create material (default: red for inactive targets)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.emission_enabled = true
	material.emission = Color.RED * 0.3
	mesh_instance.material_override = material

	# Store the mesh instance for later material updates
	target.set_meta("mesh_instance", mesh_instance)

	add_child(target)

	# Store original position for movement tracking
	target_original_positions[target] = target.position

	return target

func create_ragdoll_toggle_targets():
	"""Create toggle targets for partial ragdoll control"""
	if not skeleton_3d:
		print("WARNING: No skeleton found for ragdoll toggles")
		return

	var skeleton_transform = character_model.global_transform
	print("Creating ragdoll toggle targets...")

	# Left arm toggle - position near left shoulder
	var left_shoulder_bone = find_bone_by_pattern_exact_side(["shoulder", "Shoulder"], "left")
	if left_shoulder_bone != "":
		var left_shoulder_idx = skeleton_3d.find_bone(left_shoulder_bone)
		var left_shoulder_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(left_shoulder_idx).origin
		left_arm_ragdoll_toggle = create_ragdoll_toggle("LeftArmRagdollToggle", left_shoulder_pos + Vector3(0.5, 0.3, 0.3))
		if left_arm_ragdoll_toggle:
			print("Created left arm ragdoll toggle: ", left_arm_ragdoll_toggle.name)
		else:
			print("Failed to create left arm ragdoll toggle")
	else:
		print("WARNING: Could not find left shoulder bone for toggle")

	# Right arm toggle - position near right shoulder
	var right_shoulder_bone = find_bone_by_pattern_exact_side(["shoulder", "Shoulder"], "right")
	if right_shoulder_bone != "":
		var right_shoulder_idx = skeleton_3d.find_bone(right_shoulder_bone)
		var right_shoulder_pos = skeleton_transform * skeleton_3d.get_bone_global_pose(right_shoulder_idx).origin
		right_arm_ragdoll_toggle = create_ragdoll_toggle("RightArmRagdollToggle", right_shoulder_pos + Vector3(-0.5, 0.3, 0.3))
		if right_arm_ragdoll_toggle:
			print("Created right arm ragdoll toggle: ", right_arm_ragdoll_toggle.name)
		else:
			print("Failed to create right arm ragdoll toggle")

	# REMOVED: Leg, torso, and head toggles - replaced with direct body clicking system
	# Only keeping arm toggles for targeted ragdoll control

	print("Ragdoll toggle creation complete")

func create_ragdoll_toggle(target_name: String, pos: Vector3) -> Node3D:
	"""Create a visual toggle for ragdoll control - distinct from regular IK targets"""
	var toggle = Node3D.new()
	toggle.name = target_name
	toggle.position = pos

	# Create collision body for mouse interaction
	var static_body = StaticBody3D.new()
	toggle.add_child(static_body)

	# Create collision shape for mouse detection
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(0.12, 0.06, 0.06)  # Rectangular toggle shape
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)

	# Set collision layers for ragdoll toggles (different from IK targets)
	static_body.collision_layer = 128  # Ragdoll toggle layer (bit 7)
	static_body.collision_mask = 0     # Don't collide with anything

	# Create visual representation - cube/box shape to distinguish from sphere IK targets
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.1, 0.05, 0.05)
	mesh_instance.mesh = box_mesh
	toggle.add_child(mesh_instance)

	# Create material - blue for inactive ragdoll, red for active
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.BLUE  # Blue = ragdoll off
	material.emission_enabled = true
	material.emission = Color.BLUE * 0.2
	mesh_instance.material_override = material

	# Store the mesh instance for material updates
	toggle.set_meta("mesh_instance", mesh_instance)
	toggle.set_meta("ragdoll_active", false)

	add_child(toggle)
	return toggle

func toggle_animation():
	"""Toggle animation playback"""
	if not animation_player or animation_names.size() == 0:
		print("No animations available")
		return

	is_playing = not is_playing

	if is_playing:
		var anim_name = animation_names[current_animation_index]
		animation_player.play(anim_name)
		print("Playing animation: ", anim_name)
	else:
		animation_player.pause()
		print("Animation paused")

	update_status()
	update_key_hints_text()

func next_animation():
	"""Switch to next animation"""
	if animation_names.size() == 0:
		print("No animations available")
		return

	current_animation_index = (current_animation_index + 1) % animation_names.size()
	var anim_name = animation_names[current_animation_index]

	if is_playing:
		animation_player.play(anim_name)
	else:
		animation_player.stop()
		animation_player.play(anim_name)
		animation_player.pause()

	print("Switched to animation: ", anim_name)
	update_status()
	update_key_hints_text()

func toggle_ik():
	"""Toggle IK system on/off"""
	ik_enabled = not ik_enabled

	if ik_enabled:
		enable_ik()
		print("IK ENABLED")
	else:
		disable_ik()
		print("IK DISABLED")

	update_status()
	update_key_hints_text()

func enable_ik():
	"""Enable selective IK chains - only for moved targets, animation continues for unmoved parts"""
	print("ENTERING SELECTIVE IK MODE")
	print("Move targets to override animation for specific limbs")
	print("Unmoved parts will continue following animation")

	# Keep animations playing for unmoved parts
	if animation_player and not is_playing and animation_names.size() > 0:
		var current_anim = animation_names[current_animation_index]
		animation_player.play(current_anim)
		is_playing = true
		print("Animation continues for unmoved body parts")

	# Show all targets
	var all_targets = [left_shoulder_target, right_shoulder_target, left_elbow_target, right_elbow_target,
					   left_hand_target, right_hand_target, left_wrist_target, right_wrist_target,
					   left_thumb_target, right_thumb_target, left_index_target, right_index_target,
					   left_knee_target, right_knee_target, left_foot_target, right_foot_target,
					   left_ankle_target, right_ankle_target, left_toes_target, right_toes_target,
					   head_target]
	for target in all_targets:
		if target:
			target.visible = true

	# Sync targets to current skeleton positions first (important for consistency)
	reposition_ik_targets_to_skeleton()

	# Update selective IK based on current target positions
	update_selective_ik()

	# FORCE START IK chains if none are running (post-ragdoll fix)
	var any_ik_running = false
	var all_ik_chains = [left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
						  left_hand_ik, right_hand_ik, left_wrist_ik, right_wrist_ik,
						  left_thumb_ik, right_thumb_ik, left_index_ik, right_index_ik,
						  left_knee_ik, right_knee_ik, left_foot_ik, right_foot_ik,
						  left_ankle_ik, right_ankle_ik, left_toes_ik, right_toes_ik,
						  head_ik]

	for ik_chain in all_ik_chains:
		if ik_chain and ik_chain.is_running:
			any_ik_running = true
			break

	# If no IK chains are running, force start some with minimal influence
	if not any_ik_running:
		print("No IK chains running - force starting essential chains")
		var essential_chains = [left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
								left_hand_ik, right_hand_ik]
		for ik_chain in essential_chains:
			if ik_chain:
				ik_chain.interpolation = 0.3  # Moderate influence
				ik_chain.start()
				print("Force-started essential IK chain: ", ik_chain.name)

func disable_ik():
	"""Disable all IK chains"""
	var all_ik_chains = [left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
						  left_hand_ik, right_hand_ik, left_wrist_ik, right_wrist_ik,
						  left_thumb_ik, right_thumb_ik, left_index_ik, right_index_ik,
						  left_knee_ik, right_knee_ik, left_foot_ik, right_foot_ik,
						  left_ankle_ik, right_ankle_ik, left_toes_ik, right_toes_ik,
						  head_ik]

	print("Disabling ", all_ik_chains.size(), " IK chains")
	for ik_chain in all_ik_chains:
		if ik_chain:
			ik_chain.stop()
			ik_chain.interpolation = 0.0  # Ensure zero influence
		else:
			print("Warning: IK chain is null during disable")

	# Resume animation when exiting IK mode
	if animation_player and animation_names.size() > 0:
		var current_anim = animation_names[current_animation_index]
		animation_player.play(current_anim)
		is_playing = true
		print("Resuming animation: ", current_anim)

	# Hide all targets
	var all_targets = [left_shoulder_target, right_shoulder_target, left_elbow_target, right_elbow_target,
					   left_hand_target, right_hand_target, left_wrist_target, right_wrist_target,
					   left_thumb_target, right_thumb_target, left_index_target, right_index_target,
					   left_knee_target, right_knee_target, left_foot_target, right_foot_target,
					   left_ankle_target, right_ankle_target, left_toes_target, right_toes_target,
					   head_target]
	for target in all_targets:
		if target:
			target.visible = false

func force_disable_all_ik():
	"""Force disable all IK chains without resuming animation - used for ragdoll mode"""
	print("FORCE DISABLING ALL IK SYSTEMS FOR RAGDOLL MODE")

	# COMPLETELY remove all IK chains from the skeleton during ragdoll
	var all_ik_chains = [left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
						  left_hand_ik, right_hand_ik, left_wrist_ik, right_wrist_ik,
						  left_thumb_ik, right_thumb_ik, left_index_ik, right_index_ik,
						  left_knee_ik, right_knee_ik, left_foot_ik, right_foot_ik,
						  left_ankle_ik, right_ankle_ik, left_toes_ik, right_toes_ik,
						  head_ik]

	print("AGGRESSIVELY disabling ", all_ik_chains.size(), " IK chains for ragdoll mode")

	for ik_chain in all_ik_chains:
		if ik_chain:
			# Stop and completely disable IK chain
			ik_chain.stop()
			ik_chain.interpolation = 0.0
			ik_chain.set_active(false)

			# REMOVE the IK chain from the skeleton entirely during ragdoll
			if ik_chain.get_parent() == skeleton_3d:
				skeleton_3d.remove_child(ik_chain)
				print("REMOVED IK chain from skeleton: ", ik_chain.name)
			else:
				print("Stopped IK chain: ", ik_chain.name)
		else:
			print("Warning: IK chain is null")

	# Force clear any bone overrides
	if skeleton_3d:
		skeleton_3d.clear_bones_global_pose_override()
		print("Cleared all bone pose overrides")

	# Hide all targets during ragdoll mode
	var all_targets = [left_shoulder_target, right_shoulder_target, left_elbow_target, right_elbow_target,
					   left_hand_target, right_hand_target, left_wrist_target, right_wrist_target,
					   left_thumb_target, right_thumb_target, left_index_target, right_index_target,
					   left_knee_target, right_knee_target, left_foot_target, right_foot_target,
					   left_ankle_target, right_ankle_target, left_toes_target, right_toes_target,
					   head_target]
	for target in all_targets:
		if target:
			target.visible = false

func restore_ik_interpolation():
	"""Restore original IK interpolation values after exiting ragdoll mode"""
	print("RESTORING ALL IK SYSTEMS AFTER RAGDOLL MODE")

	# Re-add all IK chains back to the skeleton and restore settings
	var all_ik_chains = [
		{"ik": left_shoulder_ik, "interp": 0.7},
		{"ik": right_shoulder_ik, "interp": 0.7},
		{"ik": left_elbow_ik, "interp": 0.6},
		{"ik": right_elbow_ik, "interp": 0.6},
		{"ik": left_hand_ik, "interp": 0.8},
		{"ik": right_hand_ik, "interp": 0.8},
		{"ik": left_thumb_ik, "interp": 0.9},
		{"ik": right_thumb_ik, "interp": 0.9},
		{"ik": left_index_ik, "interp": 0.9},
		{"ik": right_index_ik, "interp": 0.9},
		{"ik": left_knee_ik, "interp": 0.7},
		{"ik": right_knee_ik, "interp": 0.7},
		{"ik": left_foot_ik, "interp": 0.8},
		{"ik": right_foot_ik, "interp": 0.8},
		{"ik": left_toes_ik, "interp": 0.9},
		{"ik": right_toes_ik, "interp": 0.9},
		{"ik": head_ik, "interp": 0.6}
	]

	for chain_data in all_ik_chains:
		var ik_chain = chain_data["ik"]
		var interpolation = chain_data["interp"]

		if ik_chain and skeleton_3d:
			# Re-add IK chain to skeleton if it was removed
			if ik_chain.get_parent() != skeleton_3d:
				skeleton_3d.add_child(ik_chain)
				print("RE-ADDED IK chain to skeleton: ", ik_chain.name)

			# Restore interpolation and reactivate
			ik_chain.interpolation = interpolation
			ik_chain.set_active(true)
			print("Restored IK chain: ", ik_chain.name, " with interpolation: ", interpolation)

func ensure_ik_disabled_during_ragdoll():
	"""AGGRESSIVE safety check to ensure NO IK or animation interference during ragdoll mode"""
	var all_ik_chains = [left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
						  left_hand_ik, right_hand_ik, left_wrist_ik, right_wrist_ik,
						  left_thumb_ik, right_thumb_ik, left_index_ik, right_index_ik,
						  left_knee_ik, right_knee_ik, left_foot_ik, right_foot_ik,
						  left_ankle_ik, right_ankle_ik, left_toes_ik, right_toes_ik,
						  head_ik]

	var interference_found = false

	# Check for active IK chains
	for ik_chain in all_ik_chains:
		if ik_chain and ik_chain.is_active():
			print("EMERGENCY: Found active IK during ragdoll mode: ", ik_chain.name)
			ik_chain.stop()
			ik_chain.interpolation = 0.0
			ik_chain.set_active(false)
			interference_found = true

	# Check for running animations
	if animation_player and animation_player.is_playing():
		print("EMERGENCY: Found active animation during ragdoll mode")
		animation_player.stop()
		animation_player.pause()
		is_playing = false
		interference_found = true

	# Only clear global pose overrides - preserve rest poses for physics
	if skeleton_3d:
		skeleton_3d.clear_bones_global_pose_override()

	if interference_found:
		print("EMERGENCY: Cleared animation/IK interference during ragdoll mode")

func update_status():
	"""Update UI status display"""
	if not status_label:
		return

	var status_text = ""

	if animation_names.size() > 0:
		var current_anim = animation_names[current_animation_index]
		status_text += "Animation: " + current_anim + " (" + str(current_animation_index + 1) + "/" + str(animation_names.size()) + ")\n"
		status_text += "Playing: " + ("Yes" if is_playing else "No") + "\n"
	else:
		status_text += "No animations found\n"

	status_text += "IK: " + ("Enabled" if ik_enabled else "Disabled") + "\n"
	status_text += "Ragdoll: " + ("Active" if is_ragdoll_active else "Inactive") + "\n"

	if skeleton_3d:
		status_text += "Skeleton: " + str(skeleton_3d.get_bone_count()) + " bones"

	status_label.text = status_text

func select_target_at_mouse(mouse_pos: Vector2):
	"""Select IK target under mouse cursor"""
	if not camera or not ik_enabled:
		return

	var space_state = cached_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 64 + 128  # Detect both IK targets (64) and ragdoll toggles (128)
	var result = space_state.intersect_ray(query)

	if result:
		var hit_node = result.get("collider")
		if hit_node and hit_node.get_parent():
			var target = hit_node.get_parent()  # StaticBody3D -> Target/Toggle
			print("Hit target: ", target.name if target else "null")

			# Check if it's a ragdoll toggle
			var ragdoll_toggles = [left_arm_ragdoll_toggle, right_arm_ragdoll_toggle,
								   left_leg_ragdoll_toggle, right_leg_ragdoll_toggle,
								   torso_ragdoll_toggle, head_ragdoll_toggle]

			print("Available ragdoll toggles: ")
			for toggle in ragdoll_toggles:
				if toggle:
					print("  - ", toggle.name)
				else:
					print("  - null")

			if target in ragdoll_toggles:
				print("Found ragdoll toggle match: ", target.name)
				# Handle ragdoll toggle click
				toggle_ragdoll_for_body_part(target)
				return
			else:
				print("Target not found in ragdoll toggles")

			# Check if it's a regular IK target
			var all_targets = [left_shoulder_target, right_shoulder_target, left_elbow_target, right_elbow_target,
							   left_hand_target, right_hand_target,
							   left_knee_target, right_knee_target, left_foot_target, right_foot_target,
							   left_toes_target, right_toes_target,
							   left_thumb_target, right_thumb_target, left_index_target, right_index_target,
							   head_target]
			if target in all_targets:
				selected_target = target
				print("Selected target: ", target.name)

func move_target_with_mouse(mouse_pos: Vector2):
	"""Move selected IK target with mouse"""
	if not selected_target or not camera:
		return

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	# Project mouse position to a plane at the target's current Y level
	var plane = Plane(Vector3.UP, selected_target.position.y)
	var intersection = plane.intersects_ray(from, (to - from).normalized())

	if intersection:
		# Apply reach constraints
		var constrained_pos = apply_reach_constraints(intersection, selected_target)
		selected_target.position = constrained_pos
		update_ik_targets()

func orbit_camera_with_mouse(relative_motion: Vector2):
	"""Orbit camera around character based on mouse movement"""
	if not camera:
		return

	# Update camera angles based on mouse movement
	camera_angle_h -= relative_motion.x * camera_orbit_speed * 0.01
	camera_angle_v -= relative_motion.y * camera_orbit_speed * 0.01

	# Clamp vertical angle to prevent camera flipping
	camera_angle_v = clamp(camera_angle_v, -89.0, 89.0)

func update_camera_orbit():
	"""Update camera position based on current orbit angles"""
	if not camera:
		return

	# Calculate camera position based on spherical coordinates
	var angle_h_rad = deg_to_rad(camera_angle_h)
	var angle_v_rad = deg_to_rad(camera_angle_v)

	var x = camera_distance * cos(angle_v_rad) * sin(angle_h_rad)
	var y = camera_distance * sin(angle_v_rad) + camera_height
	var z = camera_distance * cos(angle_v_rad) * cos(angle_h_rad)

	var camera_position = camera_target_position + Vector3(x, y, z)
	camera.global_position = camera_position

	# Make camera look at character
	camera.look_at(camera_target_position + Vector3(0, camera_height * 0.5, 0), Vector3.UP)

func update_selective_ik():
	"""Update IK chains selectively - only enable IK for moved targets"""
	if not ik_enabled:
		return

	# Check each target and enable/disable corresponding IK chains based on movement

	# Left arm system (3-part: shoulder/elbow/hand)
	var left_shoulder_moved = is_target_moved(left_shoulder_target)
	var left_elbow_moved = is_target_moved(left_elbow_target)
	var left_hand_moved = is_target_moved(left_hand_target)

	if left_shoulder_moved and left_shoulder_ik and left_shoulder_target:
		left_shoulder_ik.target = Transform3D(Basis.IDENTITY, left_shoulder_target.global_position)
		left_shoulder_ik.start()
		update_target_visual(left_shoulder_target, true)
	elif left_shoulder_ik:
		left_shoulder_ik.stop()
		update_target_visual(left_shoulder_target, false)

	if left_elbow_moved and left_elbow_ik and left_elbow_target:
		left_elbow_ik.target = Transform3D(Basis.IDENTITY, left_elbow_target.global_position)
		left_elbow_ik.start()
		update_target_visual(left_elbow_target, true)
	elif left_elbow_ik:
		left_elbow_ik.stop()
		update_target_visual(left_elbow_target, false)

	if left_hand_moved and left_hand_ik and left_hand_target:
		left_hand_ik.target = Transform3D(Basis.IDENTITY, left_hand_target.global_position)
		left_hand_ik.start()
		update_target_visual(left_hand_target, true)
	elif left_hand_ik:
		left_hand_ik.stop()
		update_target_visual(left_hand_target, false)

	# Right arm system (3-part: shoulder/elbow/hand)
	var right_shoulder_moved = is_target_moved(right_shoulder_target)
	var right_elbow_moved = is_target_moved(right_elbow_target)
	var right_hand_moved = is_target_moved(right_hand_target)

	if right_shoulder_moved and right_shoulder_ik and right_shoulder_target:
		right_shoulder_ik.target = Transform3D(Basis.IDENTITY, right_shoulder_target.global_position)
		right_shoulder_ik.start()
		update_target_visual(right_shoulder_target, true)
	elif right_shoulder_ik:
		right_shoulder_ik.stop()
		update_target_visual(right_shoulder_target, false)

	if right_elbow_moved and right_elbow_ik and right_elbow_target:
		right_elbow_ik.target = Transform3D(Basis.IDENTITY, right_elbow_target.global_position)
		right_elbow_ik.start()
		update_target_visual(right_elbow_target, true)
	elif right_elbow_ik:
		right_elbow_ik.stop()
		update_target_visual(right_elbow_target, false)

	if right_hand_moved and right_hand_ik and right_hand_target:
		right_hand_ik.target = Transform3D(Basis.IDENTITY, right_hand_target.global_position)
		right_hand_ik.start()
		update_target_visual(right_hand_target, true)
	elif right_hand_ik:
		right_hand_ik.stop()
		update_target_visual(right_hand_target, false)

	# Left leg system (2-part: knee/foot only)
	var left_knee_moved = is_target_moved(left_knee_target)
	var left_foot_moved = is_target_moved(left_foot_target)

	if left_knee_moved and left_knee_ik and left_knee_target:
		left_knee_ik.target = Transform3D(Basis.IDENTITY, left_knee_target.global_position)
		left_knee_ik.start()
		update_target_visual(left_knee_target, true)
	elif left_knee_ik:
		left_knee_ik.stop()
		update_target_visual(left_knee_target, false)

	if left_foot_moved and left_foot_ik and left_foot_target:
		left_foot_ik.target = Transform3D(Basis.IDENTITY, left_foot_target.global_position)
		left_foot_ik.start()
		update_target_visual(left_foot_target, true)
	elif left_foot_ik:
		left_foot_ik.stop()
		update_target_visual(left_foot_target, false)

	# Right leg system (2-part: knee/foot only)
	var right_knee_moved = is_target_moved(right_knee_target)
	var right_foot_moved = is_target_moved(right_foot_target)

	if right_knee_moved and right_knee_ik and right_knee_target:
		right_knee_ik.target = Transform3D(Basis.IDENTITY, right_knee_target.global_position)
		right_knee_ik.start()
		update_target_visual(right_knee_target, true)
	elif right_knee_ik:
		right_knee_ik.stop()
		update_target_visual(right_knee_target, false)

	if right_foot_moved and right_foot_ik and right_foot_target:
		right_foot_ik.target = Transform3D(Basis.IDENTITY, right_foot_target.global_position)
		right_foot_ik.start()
		update_target_visual(right_foot_target, true)
	elif right_foot_ik:
		right_foot_ik.stop()
		update_target_visual(right_foot_target, false)


	# Detailed hand/foot control systems (toes, fingers)
	update_detail_ik_system(left_toes_ik, left_toes_target)
	update_detail_ik_system(right_toes_ik, right_toes_target)
	update_detail_ik_system(left_thumb_ik, left_thumb_target)
	update_detail_ik_system(right_thumb_ik, right_thumb_target)
	update_detail_ik_system(left_index_ik, left_index_target)
	update_detail_ik_system(right_index_ik, right_index_target)

	# Head system - improved look-at with proper IK positioning
	var head_moved = is_target_moved(head_target)
	if head_moved:
		if head_ik and head_target and skeleton_3d:
			# Get neck bone position as the reference point
			var neck_bone_idx = skeleton_3d.find_bone(head_ik.root_bone)
			if neck_bone_idx != -1:
				var neck_global_pos = skeleton_3d.to_global(skeleton_3d.get_bone_global_pose(neck_bone_idx).origin)

				# Calculate constrained target position based on neck position
				var direction_to_target = (head_target.global_position - neck_global_pos).normalized()
				var constrained_direction = apply_head_constraints(direction_to_target)

				# Calculate IK target position at appropriate distance from neck
				var head_reach_distance = 0.25  # Typical neck-to-head distance
				var ik_target_position = neck_global_pos + (constrained_direction * head_reach_distance)

				# Use simple position target instead of complex transform
				head_ik.target = Transform3D(Basis.IDENTITY, ik_target_position)
				head_ik.start()
				update_target_visual(head_target, true)

				print("Head IK: neck at ", neck_global_pos, " looking towards ", ik_target_position)
	else:
		if head_ik:
			head_ik.stop()
		update_target_visual(head_target, false)

func apply_head_constraints(direction: Vector3) -> Vector3:
	"""Apply anatomical constraints to head look direction"""
	# Define maximum rotation angles (in radians)
	var max_up_angle = deg_to_rad(60)      # Look up limit
	var max_down_angle = deg_to_rad(45)    # Look down limit
	var max_side_angle = deg_to_rad(75)    # Left/right turn limit

	# Calculate pitch (up/down rotation)
	var pitch = asin(clamp(direction.y, -1.0, 1.0))
	pitch = clamp(pitch, -max_down_angle, max_up_angle)

	# Calculate yaw (left/right rotation)
	var horizontal_dir = Vector3(direction.x, 0, direction.z).normalized()
	var yaw = atan2(horizontal_dir.x, horizontal_dir.z)
	yaw = clamp(yaw, -max_side_angle, max_side_angle)

	# Reconstruct constrained direction
	var constrained_y = sin(pitch)
	var horizontal_scale = cos(pitch)
	var constrained_x = horizontal_scale * sin(yaw)
	var constrained_z = horizontal_scale * cos(yaw)

	return Vector3(constrained_x, constrained_y, constrained_z).normalized()

func update_detail_ik_system(ik_chain: SkeletonIK3D, target: Node3D):
	"""Helper function to update detailed IK systems (fingers, toes)"""
	if ik_chain and target:
		var target_moved = is_target_moved(target)
		if target_moved:
			ik_chain.target = Transform3D(Basis.IDENTITY, target.global_position)
			ik_chain.start()
			update_target_visual(target, true)
		else:
			ik_chain.stop()
			update_target_visual(target, false)

func is_target_moved(target: Node3D) -> bool:
	"""Check if a target has been moved significantly from its original position"""
	if not target or not target in target_original_positions:
		return false

	var original_pos = target_original_positions[target]
	var current_pos = target.position
	var distance = original_pos.distance_to(current_pos)

	return distance > target_moved_threshold

func update_ik_targets():
	"""Update IK chain targets when targets are moved - now uses selective system"""
	update_selective_ik()

func print_bone_structure():
	"""Print the skeleton bone structure for debugging"""
	if not skeleton_3d:
		return

	print("=== SKELETON BONE STRUCTURE ===")
	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i)
		var parent_idx = skeleton_3d.get_bone_parent(i)
		var parent_name = ""
		if parent_idx != -1:
			parent_name = skeleton_3d.get_bone_name(parent_idx)
		print("Bone ", i, ": ", bone_name, " (parent: ", parent_name, ")")

func get_bone_names_containing(keywords: Array) -> Array:
	"""Get bone names that contain any of the keywords"""
	var matching_bones = []
	if not skeleton_3d:
		return matching_bones

	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i).to_lower()
		for keyword in keywords:
			if keyword.to_lower() in bone_name:
				matching_bones.append(skeleton_3d.get_bone_name(i))
				break
	return matching_bones

func apply_reach_constraints(target_pos: Vector3, target_node: Node3D) -> Vector3:
	"""Apply reach distance constraints to prevent bone stretching"""
	if not character_model:
		return target_pos

	var origin: Vector3
	var max_reach: float

	# Determine origin point and max reach based on target type
	if target_node == left_shoulder_target or target_node == right_shoulder_target:
		# For shoulders, origin is upper chest area
		origin = character_model.global_position + Vector3(0, 1.5, 0)
		max_reach = 0.3  # Very short reach for shoulders
	elif target_node == left_elbow_target or target_node == right_elbow_target:
		# For elbows, use actual shoulder bone position as origin
		var shoulder_bone = ""
		if target_node == left_elbow_target:
			shoulder_bone = find_bone_by_pattern_exact_side(["shoulder", "Shoulder"], "left")
		else:
			shoulder_bone = find_bone_by_pattern_exact_side(["shoulder", "Shoulder"], "right")

		if shoulder_bone != "" and skeleton_3d:
			var shoulder_idx = skeleton_3d.find_bone(shoulder_bone)
			if shoulder_idx >= 0:
				origin = skeleton_3d.to_global(skeleton_3d.get_bone_global_pose(shoulder_idx).origin)
			else:
				# Fallback to character position
				origin = character_model.global_position + Vector3(0, 1.4, 0)
		else:
			# Fallback to character position
			origin = character_model.global_position + Vector3(0, 1.4, 0)
		max_reach = max_arm_reach * 0.6  # Medium reach for elbows
	elif target_node == left_hand_target or target_node == right_hand_target:
		# For hands, use actual shoulder bone position as origin
		var shoulder_bone = ""
		if target_node == left_hand_target:
			shoulder_bone = find_bone_by_pattern_exact_side(["shoulder", "Shoulder"], "left")
		else:
			shoulder_bone = find_bone_by_pattern_exact_side(["shoulder", "Shoulder"], "right")

		if shoulder_bone != "" and skeleton_3d:
			var shoulder_idx = skeleton_3d.find_bone(shoulder_bone)
			if shoulder_idx >= 0:
				origin = skeleton_3d.to_global(skeleton_3d.get_bone_global_pose(shoulder_idx).origin)
			else:
				# Fallback to character position
				origin = character_model.global_position + Vector3(0, 1.4, 0)
		else:
			# Fallback to character position
			origin = character_model.global_position + Vector3(0, 1.4, 0)
		max_reach = max_arm_reach  # Full arm reach for hands
	elif target_node == left_knee_target or target_node == right_knee_target:
		# For knees, origin is hip area with medium reach
		origin = character_model.global_position + Vector3(0, 0.9, 0)
		max_reach = max_leg_reach * 0.7  # Medium reach for knees
	elif target_node == left_foot_target or target_node == right_foot_target:
		# For feet, origin is hip area with full reach
		origin = character_model.global_position + Vector3(0, 0.9, 0)
		max_reach = max_leg_reach  # Full leg reach for feet
	# Removed wrist and ankle target constraints - simplified to use hand/foot only
	elif target_node == left_toes_target or target_node == right_toes_target:
		# For toes, origin is foot area with very short reach
		origin = character_model.global_position + Vector3(0, 0.05, 0)
		max_reach = 0.1  # Very short reach for fine toe control
	elif target_node == left_thumb_target or target_node == right_thumb_target:
		# For thumbs, origin is hand area with very short reach
		origin = character_model.global_position + Vector3(0, 1.4, 0)
		max_reach = 0.08  # Very short reach for fine thumb control
	elif target_node == left_index_target or target_node == right_index_target:
		# For index fingers, origin is hand area with very short reach
		origin = character_model.global_position + Vector3(0, 1.4, 0)
		max_reach = 0.08  # Very short reach for fine finger control
	elif target_node == head_target:
		# For head, origin is neck area
		origin = character_model.global_position + Vector3(0, 1.7, 0)
		max_reach = 0.3  # Very short reach for head
	else:
		return target_pos

	# Calculate distance from origin to target
	var distance = origin.distance_to(target_pos)

	# If within reach, return as-is
	if distance <= max_reach:
		return target_pos

	# If too far, clamp to max reach
	var direction = (target_pos - origin).normalized()
	return origin + direction * max_reach

# ===== RAGDOLL SYSTEM =====

func setup_ragdoll_system():
	"""Set up physics bones for ragdoll"""
	if not skeleton_3d:
		return

	print("Setting up ragdoll system...")
	print("Available bones:")

	# First, let's see what bones we actually have
	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i)
		print("  ", i, ": ", bone_name)

	# Clear any existing physical bones
	remove_all_physical_bones()

	# Create physical bones for main body parts - using actual bone names from your character
	var important_bones = [
		"characters3d.com___Hips",           # pelvis
		"characters3d.com___Spine",          # spine_01
		"characters3d.com___Chest",          # spine_02
		"characters3d.com___Upper_Chest",    # spine_03
		"characters3d.com___Neck",           # neck_01
		"characters3d.com___Head",           # Head
		"characters3d.com___L_Shoulder",     # clavicle_l
		"characters3d.com___R_Shoulder",     # clavicle_r
		"characters3d.com___L_Upper_Arm",    # upperarm_l
		"characters3d.com___R_Upper_Arm",    # upperarm_r
		"characters3d.com___L_Lower_Arm",    # lowerarm_l
		"characters3d.com___R_Lower_Arm",    # lowerarm_r
		"characters3d.com___L_Hand",         # hand_l
		"characters3d.com___R_Hand",         # hand_r
		"characters3d.com___L_Upper_Leg",    # thigh_l
		"characters3d.com___R_Upper_Leg",    # thigh_r
		"characters3d.com___L_Lower_Leg",    # calf_l
		"characters3d.com___R_Lower_Leg",    # calf_r
		"characters3d.com___L_Foot",         # foot_l
		"characters3d.com___R_Foot"          # foot_r
	]

	var bones_created = 0
	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i)
		if bone_name in important_bones:
			create_physical_bone(i, bone_name)
			bones_created += 1

	print("Created ", bones_created, " physical bones")

	# Stop physics simulation initially
	skeleton_3d.physical_bones_stop_simulation()
	print("Ragdoll system ready (inactive)")

	# Skip pre-warming for now - focus on proper constraint application
	# await pre_warm_physics_system()
	# Physics ready - constraints applied during bone creation

func create_physical_bone(bone_idx: int, bone_name: String):
	"""Create a properly integrated physical bone that follows skeleton poses"""
	var physical_bone = PhysicalBone3D.new()
	physical_bone.name = "PhysicalBone_" + bone_name
	physical_bone.bone_name = bone_name

	# CRITICAL: PhysicalBone3D automatically integrates with skeleton via bone_name
	# The bone_name property creates the connection to the skeleton bone

	# Calculate bone length for proper sizing
	var bone_length = calculate_bone_length(bone_idx)

	# Create appropriately sized collision shapes to prevent crumpling
	var shape = CapsuleShape3D.new()
	var bone_name_lower = bone_name.to_lower()

	if "head" in bone_name_lower:
		shape = SphereShape3D.new()
		shape.radius = 0.03  # Much smaller head
	elif "hips" in bone_name_lower:
		shape.radius = 0.03  # Much smaller hips/pelvis
		shape.height = max(bone_length * 0.3, 0.06)
	elif "chest" in bone_name_lower or "spine" in bone_name_lower:
		shape.radius = 0.025  # Much smaller torso
		shape.height = max(bone_length * 0.3, 0.05)
	elif "neck" in bone_name_lower:
		shape.radius = 0.015
		shape.height = max(bone_length * 0.3, 0.03)
	elif "upper_leg" in bone_name_lower:
		shape.radius = 0.02  # Much smaller thighs
		shape.height = max(bone_length * 0.3, 0.08)
	elif "upper_arm" in bone_name_lower:
		shape.radius = 0.015  # Much smaller upper arms
		shape.height = max(bone_length * 0.3, 0.06)
	elif "lower_leg" in bone_name_lower:
		shape.radius = 0.015  # Much smaller calves
		shape.height = max(bone_length * 0.3, 0.06)
	elif "lower_arm" in bone_name_lower:
		shape.radius = 0.012  # Much smaller forearms
		shape.height = max(bone_length * 0.3, 0.04)
	elif "foot" in bone_name_lower:
		# Much smaller box shape for feet
		shape = BoxShape3D.new()
		shape.size = Vector3(0.05, 0.02, 0.08)  # Much smaller feet
	elif "hand" in bone_name_lower:
		shape.radius = 0.01
		shape.height = max(bone_length * 0.2, 0.03)
	elif "shoulder" in bone_name_lower:
		shape.radius = 0.015
		shape.height = max(bone_length * 0.3, 0.03)
	else:
		shape.radius = 0.01
		shape.height = max(bone_length * 0.3, 0.03)

	var collision = CollisionShape3D.new()
	collision.shape = shape
	physical_bone.add_child(collision)

	# Adjusted physics properties to prevent crumpling and falling through floor
	var bone_mass = 1.0
	if "hips" in bone_name_lower or "pelvis" in bone_name_lower:
		bone_mass = 6.0  # Very heavy center for stability and faster settling
	elif "head" in bone_name_lower:
		bone_mass = 0.3  # Very light head for stability
	elif "neck" in bone_name_lower:
		bone_mass = 0.2  # Extremely light neck for stability
	elif "upper_leg" in bone_name_lower:
		bone_mass = 3.0  # Heavy thighs for stability
	elif "chest" in bone_name_lower or "spine" in bone_name_lower:
		bone_mass = 2.5  # Heavy torso
	elif "foot" in bone_name_lower:
		bone_mass = 2.0  # Heavy feet for ground contact
	else:
		bone_mass = 1.5  # Slightly heavier for better physics

	physical_bone.mass = bone_mass
	physical_bone.friction = 1.0      # Maximum friction to prevent sliding
	physical_bone.bounce = 0.0        # No bounce to prevent jittering

	# Set head/neck specific physics properties for consistency
	if "head" in bone_name_lower:
		physical_bone.linear_damp = 8.0    # Extremely strong damping
		physical_bone.angular_damp = 10.0  # Very strong angular damping
		physical_bone.gravity_scale = 0.2  # Minimal gravity
	elif "neck" in bone_name_lower:
		physical_bone.linear_damp = 10.0   # Maximum neck damping
		physical_bone.angular_damp = 12.0  # Prevent neck flexibility
		physical_bone.gravity_scale = 0.1  # Almost no gravity on neck
	else:
		physical_bone.linear_damp = 0.9    # Very high damping for faster settling
		physical_bone.angular_damp = 0.95  # Very high angular damping to stop spinning
		physical_bone.gravity_scale = gravity_strength  # Configurable gravity strength

	# Set collision layers for proper ground collision and opposing limbs only
	var collision_layer = 8  # Default ragdoll layer
	var collision_mask = 1   # Always collide with ground (layer 1)

	# Set collision layers to prevent arms going through torso
	if "l_" in bone_name_lower or ("left" in bone_name_lower and ("arm" in bone_name_lower or "hand" in bone_name_lower or "shoulder" in bone_name_lower)):
		# Left arms/hands use layer 8, collide with torso, right arms, and ground
		collision_layer = 8
		collision_mask = 1 + 16 + 32  # Ground + right limbs + torso
	elif "r_" in bone_name_lower or ("right" in bone_name_lower and ("arm" in bone_name_lower or "hand" in bone_name_lower or "shoulder" in bone_name_lower)):
		# Right arms/hands use layer 16, collide with torso, left arms, and ground
		collision_layer = 16
		collision_mask = 1 + 8 + 32   # Ground + left limbs + torso
	elif "leg" in bone_name_lower or "foot" in bone_name_lower:
		# Legs use separate layer, collide with ground and each other but not arms
		if "left" in bone_name_lower or "l_" in bone_name_lower:
			collision_layer = 4
			collision_mask = 1 + 2 + 32  # Ground + right legs + torso
		else:
			collision_layer = 2
			collision_mask = 1 + 4 + 32  # Ground + left legs + torso
	else:
		# Torso/head/hips use layer 32, collide with everything
		collision_layer = 32
		collision_mask = 1 + 2 + 4 + 8 + 16 + 32  # Ground + all limbs + torso

	physical_bone.collision_layer = collision_layer
	physical_bone.collision_mask = collision_mask

	# Configure joint types with proper anatomical limits
	configure_joint_constraints(physical_bone, bone_name_lower)

	# Add to skeleton first to establish the bone connection
	skeleton_3d.add_child(physical_bone)

	# Verify the bone connection was established correctly
	var connected_bone_id = physical_bone.get_bone_id()
	if connected_bone_id >= 0:
		print("Created physics bone: ", bone_name, " (connected to bone_id: ", connected_bone_id, ")")
	else:
		print("WARNING: Physics bone ", bone_name, " not properly connected to skeleton!")

	# Physical bones automatically follow skeleton when not simulating physics

func configure_joint_constraints(physical_bone: PhysicalBone3D, bone_name_lower: String):
	"""Configure joint constraints based on bone type"""
	if "lower_arm" in bone_name_lower:
		# Elbows - 6DOF with strict constraints (prevent backward bending completely)
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 2.0    # Higher damping for stability
		physical_bone.angular_damp = 3.0   # Strong damping
		set_joint_linear_limits(physical_bone, 0.002)  # Tight linear limits

		# Elbow bend - ONLY forward bending, NO backward extension
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(140))  # Forward bend
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(0))    # NO backward bend
		physical_bone.set("joint_constraints/angular_limit_x/softness", 0.3)  # Firm limits
		physical_bone.set("joint_constraints/angular_limit_x/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_x/damping", 4.0)

		# Lock other rotations (elbows don't twist much)
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(10))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-10))
		physical_bone.set("joint_constraints/angular_limit_y/softness", 0.5)
		physical_bone.set("joint_constraints/angular_limit_y/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_y/damping", 5.0)

		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(5))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-5))
		physical_bone.set("joint_constraints/angular_limit_z/softness", 0.5)
		physical_bone.set("joint_constraints/angular_limit_z/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_z/damping", 5.0)
	elif "lower_leg" in bone_name_lower:
		# Knees - 6DOF joint with strict constraints to prevent backwards bending
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.5
		physical_bone.angular_damp = 0.8
		set_joint_linear_limits(physical_bone, 0.005)
		# Knee movement - only allow forward bending, NO backwards bending
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(120)) # Forward bend only
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(0))   # NO backwards bend
		set_joint_side_angular_limits(physical_bone, 5, 5)
	elif "head" in bone_name_lower:
		# Head - Very stiff joint with soft limits to prevent floppy movement
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 6.0    # High damping for stability (matches reset function)
		physical_bone.angular_damp = 8.0   # Very high damping to prevent wobble (matches reset function)
		set_joint_linear_limits(physical_bone, 0.001)  # Very tight limits

		# Much more restricted head movement with soft limits
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(15))  # Very limited look up
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-5))  # Prevent backward bending
		physical_bone.set("joint_constraints/angular_limit_x/softness", 0.8)  # Soft limits
		physical_bone.set("joint_constraints/angular_limit_x/restitution", 0.0) # No bounce
		physical_bone.set("joint_constraints/angular_limit_x/damping", 2.0)   # High damping

		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(40))  # Limited turn
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-40))
		physical_bone.set("joint_constraints/angular_limit_y/softness", 0.8)  # Soft limits
		physical_bone.set("joint_constraints/angular_limit_y/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_y/damping", 2.0)

		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(10))  # Minimal tilt
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-10))
		physical_bone.set("joint_constraints/angular_limit_z/softness", 0.9)  # Very soft limits
		physical_bone.set("joint_constraints/angular_limit_z/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_z/damping", 2.5)
	elif "neck" in bone_name_lower:
		# Neck - Very stiff supportive joint with strong soft limits
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 8.0    # Very high damping for stability (matches reset function)
		physical_bone.angular_damp = 10.0  # Very high damping to prevent excessive movement (matches reset function)
		set_joint_linear_limits(physical_bone, 0.0005)  # Extremely tight for maximum stability

		# Very restricted neck rotation with strong soft limits
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(10))  # Very limited up/down
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-5))  # Prevent backward bending
		physical_bone.set("joint_constraints/angular_limit_x/softness", 0.9)  # Very soft limits
		physical_bone.set("joint_constraints/angular_limit_x/restitution", 0.0) # No bounce
		physical_bone.set("joint_constraints/angular_limit_x/damping", 3.0)   # Very high damping

		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(15))  # Very limited turn
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-15))
		physical_bone.set("joint_constraints/angular_limit_y/softness", 0.9)  # Very soft limits
		physical_bone.set("joint_constraints/angular_limit_y/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_y/damping", 3.0)

		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(3))   # Minimal tilt
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-3))
		physical_bone.set("joint_constraints/angular_limit_z/softness", 0.95) # Maximum soft limits
		physical_bone.set("joint_constraints/angular_limit_z/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_z/damping", 4.0)
	elif "shoulder" in bone_name_lower:
		# Shoulders - COMPLETELY RIGID - no movement allowed in ragdoll
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 5.0    # Very high damping
		physical_bone.angular_damp = 8.0   # Maximum damping to prevent movement
		set_joint_linear_limits(physical_bone, 0.001)  # Almost no linear movement

		# NO rotation allowed on shoulders - lock all axes
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(1))   # Minimal movement
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-1))  # Minimal movement
		physical_bone.set("joint_constraints/angular_limit_x/softness", 0.0)  # Hard limits
		physical_bone.set("joint_constraints/angular_limit_x/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_x/damping", 10.0)  # Maximum damping

		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(1))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-1))
		physical_bone.set("joint_constraints/angular_limit_y/softness", 0.0)  # Hard limits
		physical_bone.set("joint_constraints/angular_limit_y/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_y/damping", 10.0)

		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(1))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-1))
		physical_bone.set("joint_constraints/angular_limit_z/softness", 0.0)  # Hard limits
		physical_bone.set("joint_constraints/angular_limit_z/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_z/damping", 10.0)
	elif "upper_arm" in bone_name_lower:
		# Upper arms - Ball joint with limited range to prevent backward bending
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 2.0    # High damping for stability
		physical_bone.angular_damp = 3.0   # Strong damping to prevent excessive swing
		set_joint_linear_limits(physical_bone, 0.003)  # Tight linear limits

		# Restrict backward arm movement (shoulder extension)
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(120)) # Forward swing
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-20))  # Very limited backward
		physical_bone.set("joint_constraints/angular_limit_x/softness", 0.7)  # Some softness
		physical_bone.set("joint_constraints/angular_limit_x/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_x/damping", 3.0)

		# Side-to-side movement (abduction/adduction)
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(90))   # Raise arm
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-30))  # Lower slightly
		physical_bone.set("joint_constraints/angular_limit_y/softness", 0.7)
		physical_bone.set("joint_constraints/angular_limit_y/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_y/damping", 3.0)

		# Arm rotation limits
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(45))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-45))
		physical_bone.set("joint_constraints/angular_limit_z/softness", 0.8)
		physical_bone.set("joint_constraints/angular_limit_z/restitution", 0.0)
		physical_bone.set("joint_constraints/angular_limit_z/damping", 2.0)
	elif "spine" in bone_name_lower or "chest" in bone_name_lower:
		# Spine - 6DOF joint with VERY tight limits to prevent stretching
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.95
		physical_bone.angular_damp = 0.98
		# Very tight linear limits to prevent spine stretching
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.001)  # Almost no movement
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.001)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.001)  # Almost no movement
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.001)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.001)  # Almost no movement
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.001)
		# Very restricted spine rotation limits
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(5))   # Much tighter
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-5))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(8))   # Much tighter
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-8))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(3))   # Much tighter
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-3))
	elif "hips" in bone_name_lower:
		# Hips/Pelvis - 6DOF joint (anchor point) with minimal movement
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.95
		set_joint_linear_limits(physical_bone, 0.01)
		# Limited pelvis rotation
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(20))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-20))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(15))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-15))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(10))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-10))
	elif "upper_arm" in bone_name_lower:
		# Upper arms - 6DOF joint with anatomical limits
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.8
		physical_bone.angular_damp = 0.95
		set_joint_linear_limits(physical_bone, 0.01)
		# Restricted shoulder movement to prevent body clipping
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(70))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-20))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(45))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-15))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(60))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-20))
	elif "upper_leg" in bone_name_lower:
		# Thighs - 6DOF joint with tight hip constraints
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.85
		physical_bone.angular_damp = 0.95
		set_joint_linear_limits(physical_bone, 0.01)
		# Hip movement - prevent excessive sideways bending
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(70))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-20))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(25))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-25))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(15))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-15))
	elif "hand" in bone_name_lower:
		# Hands - 6DOF joint with tight wrist constraints
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.98
		set_joint_linear_limits(physical_bone, 0.002)
		# Very restricted wrist movement - no spinning
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(20))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-30))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(15))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-15))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(10))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-10))
	elif "foot" in bone_name_lower:
		# Feet - 6DOF joint with tight ankle constraints
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.95
		set_joint_linear_limits(physical_bone, 0.005)
		# Ankle movement - very limited to prevent spinning
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(15))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-30))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(10))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-10))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(5))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-5))
	elif "shoulder" in bone_name_lower:
		# Shoulders - PIN joint for stability
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_PIN
		physical_bone.linear_damp = 0.6
		physical_bone.angular_damp = 0.8
	else:
		# Default - PIN joint with moderate damping
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_PIN
		physical_bone.linear_damp = 0.5
		physical_bone.angular_damp = 0.7

func set_joint_linear_limits(physical_bone: PhysicalBone3D, limit: float):
	"""Helper to set linear limits for 6DOF joints"""
	physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
	physical_bone.set("joint_constraints/linear_limit_x/upper_limit", limit)
	physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -limit)
	physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
	physical_bone.set("joint_constraints/linear_limit_y/upper_limit", limit)
	physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -limit)
	physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
	physical_bone.set("joint_constraints/linear_limit_z/upper_limit", limit)
	physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -limit)

func set_joint_side_angular_limits(physical_bone: PhysicalBone3D, y_limit: float, z_limit: float):
	"""Helper to set side angular limits for 6DOF joints"""
	physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
	physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(y_limit))
	physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-y_limit))
	physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
	physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(z_limit))
	physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-z_limit))

func remove_all_physical_bones():
	"""Remove all existing physical bones"""
	if not skeleton_3d:
		return

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			child.queue_free()

func toggle_ragdoll():
	"""Toggle ragdoll physics on/off"""
	if not skeleton_3d:
		print("ERROR: No skeleton found for ragdoll")
		return

	is_ragdoll_active = not is_ragdoll_active

	# Count existing physical bones
	var physical_bone_count = 0
	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			physical_bone_count += 1

	print("Physical bones found: ", physical_bone_count)

	if is_ragdoll_active:
		print("ACTIVATING SEAMLESS RAGDOLL")
		if physical_bone_count == 0:
			print("ERROR: No physical bones found! Cannot activate ragdoll.")
			is_ragdoll_active = false
			return

		# All activations should work consistently now

		# NO RESETS - Start ragdoll from exactly where IK/animation left the bones
		print("Starting ragdoll from current positions - NO RESETS")

		# Step 1: CRITICAL - Transfer IK poses to PhysicalBone3D (non-destructive)
		transfer_ik_poses_to_physical_bones()

		# Step 2: Disable IK and animation cleanly
		if ik_enabled:
			# Remember IK state before disabling it for ragdoll
			ik_was_enabled_before_ragdoll = true
			var all_ik_chains = [
				left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
				left_hand_ik, right_hand_ik, left_knee_ik, right_knee_ik,
				left_foot_ik, right_foot_ik, left_toes_ik, right_toes_ik,
				left_thumb_ik, right_thumb_ik, left_index_ik, right_index_ik, head_ik
			]
			for ik_chain in all_ik_chains:
				if ik_chain:
					ik_chain.stop()
			ik_enabled = false
			print("Stopped IK chains cleanly")
		else:
			ik_was_enabled_before_ragdoll = false

		if animation_player:
			animation_player.stop()  # Stop completely, not just pause
			print("Stopped animation player completely")

		# Step 2.5: Ensure skeleton is not overriding physical bone positions
		print("Ensuring skeleton stops affecting physical bones")
		skeleton_3d.physical_bones_stop_simulation()  # Stop any existing physics
		await get_tree().process_frame  # Wait for stop to complete

		# Step 3: Wait a frame to ensure PhysicalBone3D positions are set and conflicts resolved
		await get_tree().process_frame

		# Step 3.5: Apply head/neck stabilization BEFORE starting physics simulation
		print("Applying head/neck stabilization before physics starts")
		stabilize_head_neck_on_ragdoll_start()

		# Step 3: Start physics simulation - constraints already set during bone creation
		skeleton_3d.physical_bones_start_simulation()
		print("Physics started - constraints applied once during bone creation")

		# Step 4: Wait for physics engine to fully initialize constraints
		# This prevents the "loose first few times" issue
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame

		# Step 5: Re-ensure critical physics properties are applied after physics start
		# Sometimes physics properties need to be set after physics simulation begins
		ensure_physics_properties_applied()
		print("Physics constraints and properties fully initialized")
	else:
		print("DEACTIVATING RAGDOLL")

		# Store current ragdoll positions before stopping physics
		var ragdoll_poses = {}
		if skeleton_3d:
			for i in range(skeleton_3d.get_bone_count()):
				ragdoll_poses[i] = skeleton_3d.get_bone_global_pose(i)

		skeleton_3d.physical_bones_stop_simulation()
		print("Ragdoll physics stopped")

		# CRITICAL: Restore skeleton for IK functionality
		restore_skeleton_for_ik()

		# Restore IK interpolation values that were zeroed during ragdoll mode
		restore_ik_interpolation()

		# Resume animation when exiting ragdoll mode
		if animation_player and animation_names.size() > 0:
			var current_anim = animation_names[current_animation_index]
			animation_player.play(current_anim)
			is_playing = true
			print("Resumed animation: ", current_anim)

			# Wait a frame for animation to start, then blend from ragdoll positions
			await get_tree().process_frame
			start_ragdoll_to_animation_blend(ragdoll_poses, 0.3)  # 0.3 second blend

	update_status()
	update_key_hints_text()

func toggle_ragdoll_for_body_part(toggle_target: Node3D):
	"""Toggle ragdoll physics for a specific body part"""
	if not toggle_target:
		return

	# Don't allow partial ragdoll when full ragdoll is active
	if is_ragdoll_active:
		print("Cannot use partial ragdoll while full ragdoll is active")
		return

	var toggle_name = toggle_target.name
	var is_currently_active = toggle_target.get_meta("ragdoll_active", false)
	var new_state = not is_currently_active

	print("Toggling partial ragdoll for ", toggle_name, " to ", "ACTIVE" if new_state else "INACTIVE")

	# Update the state and visual
	toggle_target.set_meta("ragdoll_active", new_state)
	update_ragdoll_toggle_visual(toggle_target, new_state)

	# Update the corresponding state variable and apply the change
	if toggle_name == "LeftArmRagdollToggle":
		left_arm_ragdoll_active = new_state
		apply_partial_ragdoll_to_bones(get_left_arm_bones(), new_state)
	elif toggle_name == "RightArmRagdollToggle":
		right_arm_ragdoll_active = new_state
		apply_partial_ragdoll_to_bones(get_right_arm_bones(), new_state)
	# REMOVED: Leg, torso, and head toggle handling - replaced with direct body clicking

func update_ragdoll_toggle_visual(toggle: Node3D, is_active: bool):
	"""Update the visual appearance of a ragdoll toggle"""
	var mesh_instance = toggle.get_meta("mesh_instance")
	if mesh_instance:
		var material = mesh_instance.material_override
		if is_active:
			material.albedo_color = Color.RED    # Red = ragdoll active
			material.emission = Color.RED * 0.3
		else:
			material.albedo_color = Color.BLUE   # Blue = ragdoll inactive
			material.emission = Color.BLUE * 0.2

func apply_partial_ragdoll_to_bones(bone_names: Array, enable_ragdoll: bool):
	"""Enable or disable ragdoll physics for specific bones with advanced animation mixing"""
	if not skeleton_3d:
		return

	# Ensure physics bones exist and are initialized
	if not has_physical_bones():
		print("No physical bones found - cannot apply partial ragdoll")
		return

	# Start physics simulation if not already running
	if not is_physics_simulation_running():
		skeleton_3d.physical_bones_start_simulation()
		print("Started physics simulation for partial ragdoll")

	if enable_ragdoll:
		print("Starting seamless partial ragdoll for: ", bone_names)
		# Use seamless transition that matches current positions
		seamless_partial_ragdoll(bone_names, true)
	else:
		print("Stopping seamless partial ragdoll for: ", bone_names)
		# Use seamless transition back to animation
		seamless_partial_ragdoll(bone_names, false)

func has_physical_bones() -> bool:
	"""Check if physical bones exist"""
	if not skeleton_3d:
		return false

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			return true
	return false

func is_physics_simulation_running() -> bool:
	"""Check if physics simulation is currently running"""
	if not skeleton_3d:
		return false

	# Check if any physical bone is simulating
	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var physical_bone = child as PhysicalBone3D
			# If any bone has normal gravity, physics is likely running
			if physical_bone.gravity_scale > 0.0:
				return true
	return false

func disable_ik_for_bone(bone_name: String):
	"""Disable IK chains that control this specific bone"""
	# Stop IK chains that would interfere with physics on this bone
	if "L_Shoulder" in bone_name or "L_Upper_Arm" in bone_name:
		if left_shoulder_ik:
			left_shoulder_ik.stop()
	elif "R_Shoulder" in bone_name or "R_Upper_Arm" in bone_name:
		if right_shoulder_ik:
			right_shoulder_ik.stop()
	elif "L_Lower_Arm" in bone_name:
		if left_elbow_ik:
			left_elbow_ik.stop()
	elif "R_Lower_Arm" in bone_name:
		if right_elbow_ik:
			right_elbow_ik.stop()
	elif "L_Hand" in bone_name:
		if left_hand_ik:
			left_hand_ik.stop()
	elif "R_Hand" in bone_name:
		if right_hand_ik:
			right_hand_ik.stop()
	elif "L_Upper_Leg" in bone_name or "L_Lower_Leg" in bone_name:
		if left_knee_ik:
			left_knee_ik.stop()
	elif "R_Upper_Leg" in bone_name or "R_Lower_Leg" in bone_name:
		if right_knee_ik:
			right_knee_ik.stop()
	elif "L_Foot" in bone_name:
		if left_foot_ik:
			left_foot_ik.stop()
	elif "R_Foot" in bone_name:
		if right_foot_ik:
			right_foot_ik.stop()
	elif "Head" in bone_name or "Neck" in bone_name:
		if head_ik:
			head_ik.stop()

func enable_ik_for_bone(_bone_name: String):
	"""Re-enable IK chains for this specific bone"""
	# This will be handled by the normal IK update cycle
	# Just ensure the IK systems are available to run
	pass

func find_physical_bone_by_name(bone_name: String) -> PhysicalBone3D:
	"""Find a physical bone by its bone name"""
	if not skeleton_3d:
		return null

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var physical_bone = child as PhysicalBone3D
			if physical_bone.bone_name == bone_name:
				return physical_bone
	return null

func get_left_arm_bones() -> Array:
	"""Get bone names for left arm - excluding shoulder to prevent stretching"""
	return [
		"characters3d.com___L_Upper_Arm",
		"characters3d.com___L_Lower_Arm",
		"characters3d.com___L_Hand",
		# Include all finger bones for complete arm control
		"characters3d.com___L_Thumb_Proximal",
		"characters3d.com___L_Thumb_Intermediate",
		"characters3d.com___L_Thumb_Distal",
		"characters3d.com___L_Index_Proximal",
		"characters3d.com___L_Index_Intermediate",
		"characters3d.com___L_Index_Distal",
		"characters3d.com___L_Middle_Proximal",
		"characters3d.com___L_Middle_Intermediate",
		"characters3d.com___L_Middle_Distal",
		"characters3d.com___L_Ring_Proximal",
		"characters3d.com___L_Ring_Intermediate",
		"characters3d.com___L_Ring_Distal",
		"characters3d.com___L_Little_Proximal",
		"characters3d.com___L_Little_Intermediate",
		"characters3d.com___L_Little_Distal"
	]

func get_right_arm_bones() -> Array:
	"""Get bone names for right arm - excluding shoulder to prevent stretching"""
	return [
		"characters3d.com___R_Upper_Arm",
		"characters3d.com___R_Lower_Arm",
		"characters3d.com___R_Hand",
		# Include all finger bones for complete arm control
		"characters3d.com___R_Thumb_Proximal",
		"characters3d.com___R_Thumb_Intermediate",
		"characters3d.com___R_Thumb_Distal",
		"characters3d.com___R_Index_Proximal",
		"characters3d.com___R_Index_Intermediate",
		"characters3d.com___R_Index_Distal",
		"characters3d.com___R_Middle_Proximal",
		"characters3d.com___R_Middle_Intermediate",
		"characters3d.com___R_Middle_Distal",
		"characters3d.com___R_Ring_Proximal",
		"characters3d.com___R_Ring_Intermediate",
		"characters3d.com___R_Ring_Distal",
		"characters3d.com___R_Little_Proximal",
		"characters3d.com___R_Little_Intermediate",
		"characters3d.com___R_Little_Distal"
	]

func get_left_leg_bones() -> Array:
	"""Get bone names for left leg"""
	return [
		"characters3d.com___L_Upper_Leg",
		"characters3d.com___L_Lower_Leg",
		"characters3d.com___L_Foot"
	]

func get_right_leg_bones() -> Array:
	"""Get bone names for right leg"""
	return [
		"characters3d.com___R_Upper_Leg",
		"characters3d.com___R_Lower_Leg",
		"characters3d.com___R_Foot"
	]

# Advanced Animation mixing and transition functions
var stored_animation_poses: Dictionary = {}
var bone_transition_timers: Dictionary = {}
var physics_animation_blend_weights: Dictionary = {}  # Per-bone blending weights
var global_physics_blend: float = 0.0  # Global physics influence (0 = animation, 1 = physics)
var transition_curves: Dictionary = {}  # Smooth transition curves

func store_animation_pose_for_bone(bone_name: String):
	"""Store current animation pose for smooth transition to ragdoll"""
	if not skeleton_3d:
		return

	var bone_idx = skeleton_3d.find_bone(bone_name)
	if bone_idx >= 0:
		stored_animation_poses[bone_name] = skeleton_3d.get_bone_pose(bone_idx)

func disable_ik_for_bone_gradual(bone_name: String, duration: float):
	"""Gradually disable IK for smooth transition to ragdoll"""
	bone_transition_timers[bone_name + "_ik_disable"] = {
		"timer": 0.0,
		"duration": duration,
		"type": "ik_disable"
	}

func transition_bone_to_animation(bone_name: String, duration: float):
	"""Smoothly transition bone from ragdoll back to animation"""
	var physical_bone = find_physical_bone_by_name(bone_name)
	if physical_bone:
		# Stop physics simulation
		physical_bone.simulate_physics = false
		physical_bone.gravity_scale = 0.0
		physical_bone.linear_damp = 100.0
		physical_bone.angular_damp = 100.0

		# Set up transition timer
		bone_transition_timers[bone_name + "_to_anim"] = {
			"timer": 0.0,
			"duration": duration,
			"type": "to_animation",
			"start_pose": skeleton_3d.get_bone_pose(skeleton_3d.find_bone(bone_name)) if skeleton_3d.find_bone(bone_name) >= 0 else Transform3D()
		}

		# Re-enable IK after transition
		enable_ik_for_bone(bone_name)

func update_bone_transitions(delta: float):
	"""Update all bone transitions"""
	var completed_transitions = []

	for timer_key in bone_transition_timers:
		var transition = bone_transition_timers[timer_key]
		transition.timer += delta

		var progress = transition.timer / transition.duration
		progress = clamp(progress, 0.0, 1.0)

		if transition.type == "to_animation":
			apply_animation_transition(timer_key.get_slice("_to_anim", 0), progress)

		if progress >= 1.0:
			completed_transitions.append(timer_key)

	# Clean up completed transitions
	for key in completed_transitions:
		bone_transition_timers.erase(key)

func apply_animation_transition(bone_name: String, progress: float):
	"""Apply smooth transition back to animation pose"""
	if not skeleton_3d:
		return

	var bone_idx = skeleton_3d.find_bone(bone_name)
	if bone_idx < 0:
		return

	# Get current animation pose (from AnimationPlayer)
	var target_pose = Transform3D()
	if stored_animation_poses.has(bone_name):
		target_pose = stored_animation_poses[bone_name]

	# Get current bone pose
	var current_pose = skeleton_3d.get_bone_pose(bone_idx)

	# Interpolate between current and target
	var interpolated_pose = Transform3D()
	interpolated_pose.origin = current_pose.origin.lerp(target_pose.origin, progress)
	interpolated_pose.basis = current_pose.basis.slerp(target_pose.basis, progress)

	# Apply the interpolated pose
	skeleton_3d.set_bone_pose(bone_idx, interpolated_pose)

func set_physics_animation_blend(bone_name: String, physics_weight: float, transition_time: float = 0.5):
	"""Set physics-animation blend weight for a specific bone with smooth transition"""
	physics_weight = clamp(physics_weight, 0.0, 1.0)

	if not physics_animation_blend_weights.has(bone_name):
		physics_animation_blend_weights[bone_name] = 0.0

	# Create smooth transition curve
	transition_curves[bone_name] = {
		"start_weight": physics_animation_blend_weights[bone_name],
		"target_weight": physics_weight,
		"timer": 0.0,
		"duration": transition_time
	}

func update_physics_animation_blending(delta: float):
	"""Update smooth blending between physics and animation"""
	if not skeleton_3d or not animation_player:
		return

	# Update transition curves
	var completed_transitions = []
	for bone_name in transition_curves:
		var curve = transition_curves[bone_name]
		curve.timer += delta
		var progress = clamp(curve.timer / curve.duration, 0.0, 1.0)

		# Use smooth step for natural transitions
		var smooth_progress = progress * progress * (3.0 - 2.0 * progress)
		physics_animation_blend_weights[bone_name] = lerp(curve.start_weight, curve.target_weight, smooth_progress)

		if progress >= 1.0:
			completed_transitions.append(bone_name)

	# Clean up completed transitions
	for bone_name in completed_transitions:
		transition_curves.erase(bone_name)

	# Apply blended poses
	apply_physics_animation_blend()

func apply_physics_animation_blend():
	"""Apply blended poses between physics and animation"""
	if not skeleton_3d:
		return

	for bone_name in physics_animation_blend_weights:
		var blend_weight = physics_animation_blend_weights[bone_name]
		if blend_weight <= 0.0:
			continue

		var bone_idx = skeleton_3d.find_bone(bone_name)
		if bone_idx < 0:
			continue

		# Get animation pose (from current animation)
		var animation_pose = skeleton_3d.get_bone_pose(bone_idx)
		if stored_animation_poses.has(bone_name):
			animation_pose = stored_animation_poses[bone_name]

		# Get physics pose (current bone pose influenced by physics)
		var physics_pose = skeleton_3d.get_bone_pose(bone_idx)

		# Blend between animation and physics
		var blended_pose = Transform3D()
		blended_pose.origin = animation_pose.origin.lerp(physics_pose.origin, blend_weight)
		blended_pose.basis = animation_pose.basis.slerp(physics_pose.basis, blend_weight)

		# Apply blended pose
		skeleton_3d.set_bone_pose(bone_idx, blended_pose)

func start_physics_animation_transition(bone_names: Array, to_physics: bool, transition_time: float = 1.0):
	"""Start smooth transition between physics and animation for multiple bones"""
	var target_weight = 1.0 if to_physics else 0.0

	for bone_name in bone_names:
		# Store current animation pose before transition
		if to_physics:
			store_animation_pose_for_bone(bone_name)

		# Set blend transition
		set_physics_animation_blend(bone_name, target_weight, transition_time)

		# Configure physics properties gradually
		if to_physics:
			configure_physics_for_transition(bone_name, transition_time)
		else:
			restore_animation_control(bone_name, transition_time)

func configure_physics_for_transition(bone_name: String, transition_time: float):
	"""Configure physics properties for smooth transition"""
	var physical_bone = find_physical_bone_by_name(bone_name)
	if not physical_bone:
		return

	# Start with high damping and gradually reduce it
	physical_bone.linear_damp = 0.95
	physical_bone.angular_damp = 0.98
	physical_bone.gravity_scale = 0.2

	# Create timer to gradually make physics more natural
	await get_tree().create_timer(transition_time * 0.5).timeout

	if physical_bone:
		physical_bone.linear_damp = 0.8
		physical_bone.angular_damp = 0.9
		physical_bone.gravity_scale = 1.0

func restore_animation_control(bone_name: String, _transition_time: float):
	"""Restore animation control with smooth transition"""
	var physical_bone = find_physical_bone_by_name(bone_name)
	if not physical_bone:
		return

	# Gradually increase damping to stop physics influence
	physical_bone.gravity_scale = 0.5
	physical_bone.linear_damp = 0.9
	physical_bone.angular_damp = 0.95

func restore_ik_for_bones(bone_names: Array):
	"""Restore IK functionality for specific bones after ragdoll"""
	if not ik_enabled:
		return

	print("Restoring IK for bones: ", bone_names)

	for bone_name in bone_names:
		# Re-enable IK chains based on bone name
		if "L_Shoulder" in bone_name or "L_Upper_Arm" in bone_name:
			if left_shoulder_ik and not left_shoulder_ik.is_running:
				left_shoulder_ik.start()
		elif "R_Shoulder" in bone_name or "R_Upper_Arm" in bone_name:
			if right_shoulder_ik and not right_shoulder_ik.is_running:
				right_shoulder_ik.start()
		elif "L_Lower_Arm" in bone_name:
			if left_elbow_ik and not left_elbow_ik.is_running:
				left_elbow_ik.start()
		elif "R_Lower_Arm" in bone_name:
			if right_elbow_ik and not right_elbow_ik.is_running:
				right_elbow_ik.start()
		elif "L_Hand" in bone_name:
			if left_hand_ik and not left_hand_ik.is_running:
				left_hand_ik.start()
		elif "R_Hand" in bone_name:
			if right_hand_ik and not right_hand_ik.is_running:
				right_hand_ik.start()

	# Update selective IK to ensure proper state
	update_selective_ik()
	print("IK functionality restored for: ", bone_names)

func test_physics_blending():
	"""Test function to demonstrate smooth physics-animation blending"""
	var arm_bones = get_left_arm_bones()
	if arm_bones.size() > 0:
		print("Testing physics blending on left arm")
		start_physics_animation_transition(arm_bones, true, 2.0)

func test_partial_arm_blending():
	"""Test function for partial arm physics with advanced blending"""
	var left_arm_bones = get_left_arm_bones()
	print("Testing partial arm blending with advanced transition")
	apply_partial_ragdoll_to_bones(left_arm_bones, !left_arm_ragdoll_active)

func toggle_left_arm_ragdoll():
	"""Toggle ragdoll physics for left arm only"""
	if is_ragdoll_active:
		print("Cannot use partial ragdoll while full ragdoll is active")
		return

	if left_arm_ragdoll_toggle:
		toggle_ragdoll_for_body_part(left_arm_ragdoll_toggle)
	else:
		print("Left arm ragdoll toggle not found")

func toggle_right_arm_ragdoll():
	"""Toggle ragdoll physics for right arm only"""
	if is_ragdoll_active:
		print("Cannot use partial ragdoll while full ragdoll is active")
		return

	if right_arm_ragdoll_toggle:
		toggle_ragdoll_for_body_part(right_arm_ragdoll_toggle)
	else:
		print("Right arm ragdoll toggle not found")

func toggle_both_arms_ragdoll():
	"""Toggle ragdoll physics for both arms simultaneously"""
	if is_ragdoll_active:
		print("Cannot use partial ragdoll while full ragdoll is active")
		return

	print("Toggling both arms ragdoll - unified action")

	# Toggle both arms to the same state (opposite of current left arm state)
	var new_state = !left_arm_ragdoll_active

	if left_arm_ragdoll_toggle:
		if left_arm_ragdoll_active != new_state:
			toggle_ragdoll_for_body_part(left_arm_ragdoll_toggle)

	if right_arm_ragdoll_toggle:
		if right_arm_ragdoll_active != new_state:
			toggle_ragdoll_for_body_part(right_arm_ragdoll_toggle)

	print("Both arms ragdoll: ", "ACTIVE" if new_state else "INACTIVE")

func show_controls_help():
	"""Show unified IK/animation/ragdoll controls"""
	print("=== UNIFIED IK/ANIMATION/RAGDOLL CONTROLS ===")
	print("SPACE: Toggle animation")
	print("I: Toggle IK mode")
	print("R: Toggle full ragdoll")
	print("L: Toggle LEFT ARM ragdoll only")
	print("K: Toggle RIGHT ARM ragdoll only")
	print("J: Toggle BOTH ARMS ragdoll")
	print("M: Test left arm partial ragdoll")
	print("S: Test seamless full ragdoll")
	print("T: Reset character")
	print("C: Reset IK targets")
	print("V: Smooth reset IK targets")
	print("O: Toggle camera orbit")
	print("H: Show this help")
	print("=== BODY CLICKING SYSTEM ===")
	print("CLICK on character body parts to activate ragdoll with force:")
	print("  • Arms: Activates partial arm ragdoll + applies force")
	print("  • Head/Torso/Legs: Activates full ragdoll + applies force")
	print("  • Force direction: From camera toward click point")
	print("MOUSE on blue spheres: Toggle arm ragdoll (legacy)")
	print("MOUSE + O: Orbit camera around character")
	print("========================================")

func create_key_hints_display():
	"""Create on-screen key hints display in top left corner"""
	if key_hints_label:
		key_hints_label.queue_free()

	# Create the label
	key_hints_label = Label.new()
	key_hints_label.name = "KeyHintsLabel"
	key_hints_label.z_index = 1000  # Ensure it's above other UI elements

	# Godot 4 best practice: Set tree exiting connection for cleanup
	key_hints_label.tree_exiting.connect(_on_key_hints_cleanup)

	# Set initial text
	update_key_hints_text()

	# Style the label
	key_hints_label.add_theme_font_size_override("font_size", 16)
	key_hints_label.add_theme_color_override("font_color", Color.WHITE)
	key_hints_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	key_hints_label.add_theme_constant_override("shadow_offset_x", 2)
	key_hints_label.add_theme_constant_override("shadow_offset_y", 2)

	# Position in top left corner with margin
	key_hints_label.position = Vector2(20, 20)
	key_hints_label.size = Vector2(300, 100)

	# Add to the scene tree (to main scene's CanvasLayer or directly to scene)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "KeyHintsCanvasLayer"
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(key_hints_label)

func update_key_hints_text():
	"""Update the key hints text based on current mode"""
	if not key_hints_label:
		return

	var mode_text = ""
	if is_ragdoll_active:
		mode_text = "[RAGDOLL]"
	elif ik_enabled:
		mode_text = "[IK]"
	elif is_playing:
		mode_text = "[ANIMATION]"
	else:
		mode_text = "[PAUSED]"

	var hint_text = """%s

R - Ragdoll Mode
N - Next Animation
SPACE - Toggle Animation""" % mode_text

	key_hints_label.text = hint_text

func _on_key_hints_cleanup() -> void:
	"""Cleanup callback for key hints label"""
	if key_hints_label:
		key_hints_label = null

func test_seamless_ragdoll():
	"""Test seamless ragdoll transition"""
	print("Testing seamless ragdoll transition - no position jumping!")
	await seamless_ragdoll_transition(!is_ragdoll_active)
	is_ragdoll_active = !is_ragdoll_active
	update_status()

# OBSOLETE: This function is no longer needed with unified skeleton approach
# Physical bones now automatically follow skeleton due to proper bone_id setup
func match_physical_bones_to_skeleton():
	"""OBSOLETE: Match physical bone positions to current skeleton positions for seamless ragdoll transition"""
	if not skeleton_3d:
		return

	print("Matching physical bones to current skeleton positions...")
	var bones_matched = 0

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var physical_bone = child as PhysicalBone3D
			var bone_idx = skeleton_3d.find_bone(physical_bone.bone_name)

			if bone_idx >= 0:
				# Get current bone transform from skeleton (includes IK/animation modifications)
				var current_bone_transform = skeleton_3d.get_bone_global_pose(bone_idx)
				var world_transform = skeleton_3d.to_global(current_bone_transform.origin)
				var world_basis = skeleton_3d.global_transform.basis * current_bone_transform.basis

				# Set physical bone to match current position
				physical_bone.global_position = world_transform
				physical_bone.global_transform.basis = world_basis

				# Clear velocities to prevent immediate movement
				physical_bone.linear_velocity = Vector3.ZERO
				physical_bone.angular_velocity = Vector3.ZERO

				bones_matched += 1

	print("Matched ", bones_matched, " physical bones to skeleton positions")

func seamless_ragdoll_transition(enable: bool):
	"""Enable/disable ragdoll with proper IK-to-ragdoll pose transfer"""
	if enable:
		print("Starting IK-to-ragdoll pose transfer...")

		# Step 1: CRITICAL - Transfer IK poses to PhysicalBone3D (includes clearing overrides)
		# This preserves skeleton structure while making ragdoll inherit IK positions
		await transfer_ik_poses_to_physical_bones()

		# Step 2: Disable IK chains (but overrides already cleared in transfer function)
		force_disable_all_ik()
		if animation_player:
			animation_player.pause()

		# Step 3: Enable physics simulation - physical bones should maintain transferred poses
		skeleton_3d.physical_bones_start_simulation()
		is_ragdoll_active = true

		print("IK-to-ragdoll pose transfer completed - seamless!")
	else:
		print("Stopping ragdoll physics...")

		# Store current ragdoll positions before stopping physics
		var ragdoll_poses = {}
		if skeleton_3d:
			for i in range(skeleton_3d.get_bone_count()):
				ragdoll_poses[i] = skeleton_3d.get_bone_global_pose(i)

		skeleton_3d.physical_bones_stop_simulation()
		is_ragdoll_active = false

		# CRITICAL: Restore skeleton for IK functionality
		restore_skeleton_for_ik()

		# Re-enable animation smoothly
		if animation_player and animation_names.size() > 0:
			var current_anim = animation_names[current_animation_index]
			animation_player.play(current_anim)
			is_playing = true

			# Wait a frame for animation to start, then blend from ragdoll positions
			await get_tree().process_frame
			start_ragdoll_to_animation_blend(ragdoll_poses, 0.5)  # 0.5 second blend

		print("Ragdoll stopped, skeleton restored, IK ready")

func start_ragdoll_to_animation_blend(ragdoll_poses: Dictionary, blend_duration: float):
	"""Smoothly blend from ragdoll positions back to animation"""
	if not skeleton_3d:
		return

	print("Starting smooth transition from ragdoll to animation over ", blend_duration, " seconds")

	# Store animation target poses
	var animation_poses = {}
	for i in range(skeleton_3d.get_bone_count()):
		animation_poses[i] = skeleton_3d.get_bone_global_pose(i)

	# Create a smooth transition tween
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple properties to tween at once

	# Blend each bone from ragdoll position to animation position
	for bone_idx in ragdoll_poses.keys():
		if bone_idx < skeleton_3d.get_bone_count():
			var start_pose = ragdoll_poses[bone_idx]
			var end_pose = animation_poses[bone_idx]

			# Tween the bone position over the specified duration
			tween.tween_method(
				func(weight: float): blend_bone_pose(bone_idx, start_pose, end_pose, weight),
				0.0,
				1.0,
				blend_duration
			).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func blend_bone_pose(bone_idx: int, start_pose: Transform3D, end_pose: Transform3D, weight: float):
	"""Blend a single bone between two poses"""
	if not skeleton_3d:
		return

	var blended_pose = Transform3D()
	blended_pose.origin = start_pose.origin.lerp(end_pose.origin, weight)
	blended_pose.basis = start_pose.basis.slerp(end_pose.basis, weight)

	# Set bone to blended position
	skeleton_3d.set_bone_global_pose_override(bone_idx, blended_pose, 1.0, true)

func transfer_ik_poses_to_physical_bones():
	"""NON-DESTRUCTIVE: Directly set PhysicalBone3D positions from IK without corrupting skeleton"""
	if not skeleton_3d:
		return

	print("Transferring IK poses directly to PhysicalBone3D nodes...")
	var bones_transferred = 0

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var physical_bone = child as PhysicalBone3D
			var bone_idx = skeleton_3d.find_bone(physical_bone.bone_name)

			if bone_idx >= 0:
				# Get the current global pose (includes IK transformations)
				var current_bone_transform = skeleton_3d.get_bone_global_pose(bone_idx)
				var world_transform = skeleton_3d.to_global(current_bone_transform.origin)
				var world_basis = skeleton_3d.global_transform.basis * current_bone_transform.basis

				# DEBUG: Log the transfer for neck/head bones
				if "neck" in physical_bone.bone_name.to_lower() or "head" in physical_bone.bone_name.to_lower():
					print("TRANSFER DEBUG - Bone: ", physical_bone.bone_name)
					print("  Current skeleton pos: ", world_transform)
					print("  Physical bone old pos: ", physical_bone.global_position)

				# DIRECTLY set PhysicalBone3D position (non-destructive)
				physical_bone.global_position = world_transform
				physical_bone.global_transform.basis = world_basis
				physical_bone.linear_velocity = Vector3.ZERO
				physical_bone.angular_velocity = Vector3.ZERO

				# DEBUG: Verify the transfer worked
				if "neck" in physical_bone.bone_name.to_lower() or "head" in physical_bone.bone_name.to_lower():
					print("  Physical bone new pos: ", physical_bone.global_position)

				bones_transferred += 1

	print("Transferred ", bones_transferred, " IK poses directly to PhysicalBone3D (non-destructive)")

	# CRITICAL: Wait for physics bones to be positioned, then clear overrides
	# This timing is crucial - physics bones must be positioned BEFORE clearing IK
	await get_tree().process_frame

	print("Clearing IK global pose overrides after physical bones positioned...")
	skeleton_3d.clear_bones_global_pose_override()

	print("IK overrides cleared - physical bones will now control those parts")

func transfer_specific_ik_poses_to_physical_bones(bone_names: Array):
	"""NON-DESTRUCTIVE: Transfer IK poses to specific PhysicalBone3D nodes only"""
	if not skeleton_3d:
		return

	print("Transferring IK poses for specific bones: ", bone_names)
	var bones_transferred = 0

	for bone_name in bone_names:
		var physical_bone = find_physical_bone_by_name(bone_name)
		if physical_bone:
			var bone_idx = skeleton_3d.find_bone(bone_name)
			if bone_idx >= 0:
				# Get the current global pose (includes IK transformations)
				var current_bone_transform = skeleton_3d.get_bone_global_pose(bone_idx)
				var world_transform = skeleton_3d.to_global(current_bone_transform.origin)
				var world_basis = skeleton_3d.global_transform.basis * current_bone_transform.basis

				# DIRECTLY set PhysicalBone3D position (non-destructive)
				physical_bone.global_position = world_transform
				physical_bone.global_transform.basis = world_basis
				physical_bone.linear_velocity = Vector3.ZERO
				physical_bone.angular_velocity = Vector3.ZERO

				bones_transferred += 1
				print("Transferred IK pose for bone: ", bone_name)

	print("Transferred ", bones_transferred, " specific IK poses to PhysicalBone3D (non-destructive)")

	# CRITICAL: For partial ragdoll, clear overrides for ONLY the transferred bones
	# This prevents mesh stretching while preserving IK for non-ragdoll parts
	await get_tree().process_frame  # Let physical bones position first

	print("Clearing IK global pose overrides for specific bones to prevent partial ragdoll stretching...")
	for bone_name in bone_names:
		var bone_idx = skeleton_3d.find_bone(bone_name)
		if bone_idx >= 0:
			skeleton_3d.set_bone_global_pose_override(bone_idx, Transform3D(), 0.0, false)
			print("Cleared override for bone: ", bone_name)

	print("Cleared pose overrides for ragdoll bones - partial ragdoll should not stretch")

func restore_skeleton_for_ik():
	"""Restore skeleton to a clean state for IK functionality after ragdoll"""
	if not skeleton_3d:
		return

	print("Restoring skeleton for IK functionality...")

	# Step 1: Clear any lingering global pose overrides that might interfere
	skeleton_3d.clear_bones_global_pose_override()

	# Step 2: DON'T manually set bone poses - let animation system handle it naturally

	# Step 3: Reset physical bones to follow skeleton instead of driving it
	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var _physical_bone = child as PhysicalBone3D
			# Physical bones automatically follow skeleton when physics simulation stops
			# No additional action needed - they reset to skeleton-following mode

	# Step 4: Wait a frame for the animation system to take over
	await get_tree().process_frame

	# Step 5: RE-ENABLE IK SYSTEM if it was enabled before ragdoll
	if ik_was_enabled_before_ragdoll:
		print("RESTORING IK MODE - IK was enabled before ragdoll activation")
		ik_enabled = true  # Restore the IK enabled flag

		print("RESTORING ALL IK SYSTEMS AFTER RAGDOLL MODE")
		var all_ik_chains = [left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
							  left_hand_ik, right_hand_ik, left_wrist_ik, right_wrist_ik,
							  left_thumb_ik, right_thumb_ik, left_index_ik, right_index_ik,
							  left_knee_ik, right_knee_ik, left_foot_ik, right_foot_ik,
							  left_ankle_ik, right_ankle_ik, left_toes_ik, right_toes_ik,
							  head_ik]

		for ik_chain in all_ik_chains:
			if ik_chain and not ik_chain.is_running:
				# Re-enable IK chains with proper interpolation for smooth transition
				var interpolation_strength = 0.7  # Default strength
				if "thumb" in ik_chain.name.to_lower() or "index" in ik_chain.name.to_lower():
					interpolation_strength = 0.9  # Fingers need stronger interpolation
				elif "toes" in ik_chain.name.to_lower():
					interpolation_strength = 0.9  # Toes need stronger interpolation
				elif "hand" in ik_chain.name.to_lower() or "foot" in ik_chain.name.to_lower():
					interpolation_strength = 0.8  # Extremities need good interpolation
				elif "elbow" in ik_chain.name.to_lower() or "knee" in ik_chain.name.to_lower():
					interpolation_strength = 0.6  # Joints can be less interpolated

				ik_chain.interpolation = interpolation_strength
				ik_chain.start()
				print("Restored IK chain: ", ik_chain.name, " with interpolation: ", interpolation_strength)
	else:
		print("IK was not enabled before ragdoll - keeping IK disabled")

	# Resume animation after IK chains are restored
	if animation_player and animation_names.size() > 0:
		var current_anim = animation_names[current_animation_index]
		animation_player.play(current_anim)
		print("Resumed animation: ", current_anim)

	# Step 6: Make all IK targets visible again
	ensure_all_ik_targets_visible()

	# Step 7: Reposition targets to current skeleton positions
	reposition_ik_targets_to_skeleton()

	print("Skeleton fully restored for IK functionality")

	# Step 8: Force IK chains to start if IK mode is enabled
	if ik_enabled:
		print("IK mode is enabled - forcing IK chains to activate")
		# Don't update original positions yet - let user move targets
		# Force all IK chains to start with low interpolation initially
		var all_ik_chains_final = [left_shoulder_ik, right_shoulder_ik, left_elbow_ik, right_elbow_ik,
								   left_hand_ik, right_hand_ik, left_wrist_ik, right_wrist_ik,
								   left_thumb_ik, right_thumb_ik, left_index_ik, right_index_ik,
								   left_knee_ik, right_knee_ik, left_foot_ik, right_foot_ik,
								   left_ankle_ik, right_ankle_ik, left_toes_ik, right_toes_ik,
								   head_ik]
		for ik_chain in all_ik_chains_final:
			if ik_chain and not ik_chain.is_running:
				ik_chain.interpolation = 0.1  # Very low influence initially
				ik_chain.start()
				print("Force-started IK chain: ", ik_chain.name)

		# Trigger selective IK update to activate chains based on target positions
		update_selective_ik()
	else:
		# Only reset original positions if IK is not enabled
		for target in [left_shoulder_target, right_shoulder_target, left_elbow_target, right_elbow_target,
					   left_hand_target, right_hand_target, left_knee_target, right_knee_target,
					   left_foot_target, right_foot_target, left_toes_target, right_toes_target,
					   left_thumb_target, right_thumb_target, left_index_target, right_index_target,
					   head_target]:
			if target:
				target_original_positions[target] = target.position

	# Step 7: Reposition IK targets to match current skeleton state
	reposition_ik_targets_to_skeleton()

	print("Skeleton fully restored for IK functionality")

func ensure_all_ik_targets_visible():
	"""Ensure all IK targets are visible after ragdoll restoration"""
	print("Ensuring all IK targets are visible...")

	var all_targets = [
		left_shoulder_target, right_shoulder_target, left_elbow_target, right_elbow_target,
		left_hand_target, right_hand_target, left_knee_target, right_knee_target,
		left_foot_target, right_foot_target, left_toes_target, right_toes_target,
		left_thumb_target, right_thumb_target, left_index_target, right_index_target,
		head_target
	]

	var visible_count = 0
	for target in all_targets:
		if target:
			target.visible = true
			visible_count += 1
			print("Made target visible: ", target.name)

	print("Made ", visible_count, " targets visible")

func reposition_ik_targets_to_skeleton():
	"""Reposition IK targets to match current skeleton bone positions"""
	if not skeleton_3d or not character_model:
		print("ERROR: Cannot reposition targets - skeleton_3d or character_model is null")
		return

	print("Repositioning IK targets to skeleton positions...")

	# Get skeleton transform correctly - use character model as base
	var skeleton_transform = character_model.get_global_transform()
	print("DEBUG: Using character model transform: ", skeleton_transform.origin)
	print("DEBUG: Skeleton global transform: ", skeleton_3d.get_global_transform().origin)
	print("DEBUG: Skeleton local transform: ", skeleton_3d.transform.origin)

	# Reposition each target to its corresponding bone position
	var target_bone_pairs = [
		[left_shoulder_target, find_bone_by_pattern_exact_side(["upperarm", "upper_arm"], "left")],
		[right_shoulder_target, find_bone_by_pattern_exact_side(["upperarm", "upper_arm"], "right")],
		[left_elbow_target, find_bone_by_pattern_exact_side(["lowerarm", "lower_arm"], "left")],
		[right_elbow_target, find_bone_by_pattern_exact_side(["lowerarm", "lower_arm"], "right")],
		[left_hand_target, find_bone_by_pattern_exact_side(["hand"], "left")],
		[right_hand_target, find_bone_by_pattern_exact_side(["hand"], "right")],
		[left_knee_target, find_bone_by_pattern_exact_side(["lowerleg", "lower_leg"], "left")],
		[right_knee_target, find_bone_by_pattern_exact_side(["lowerleg", "lower_leg"], "right")],
		[left_foot_target, find_bone_by_pattern_exact_side(["foot"], "left")],
		[right_foot_target, find_bone_by_pattern_exact_side(["foot"], "right")]
	]

	for pair in target_bone_pairs:
		var target = pair[0]
		var bone_name = pair[1]
		if target and bone_name != "":
			var bone_idx = skeleton_3d.find_bone(bone_name)
			if bone_idx >= 0:
				# Get bone position in world space correctly
				var bone_global_pose = skeleton_3d.get_bone_global_pose(bone_idx)
				var bone_world_pos = skeleton_3d.to_global(bone_global_pose.origin)
				print("DEBUG: Positioning target ", target.name, " to bone ", bone_name, " at ", bone_world_pos)
				target.global_position = bone_world_pos
				target.visible = true  # Ensure target is visible
				# CRITICAL: Update original positions dictionary so targets can be moved again
				target_original_positions[target] = target.position
				print("DEBUG: Target position set to: ", target.global_position, " visible: ", target.visible)
				print("DEBUG: Updated original position for ", target.name, " to: ", target.position)
			else:
				print("ERROR: Could not find bone: ", bone_name)
		else:
			if not target:
				print("ERROR: Target is null in pair")
			if bone_name == "":
				print("ERROR: Bone name is empty in pair")

	# Special case for head target
	if head_target:
		var head_bone = find_bone_by_pattern(["head"])
		if head_bone != "":
			var head_idx = skeleton_3d.find_bone(head_bone)
			if head_idx >= 0:
				# Get head bone position in world space correctly
				var head_global_pose = skeleton_3d.get_bone_global_pose(head_idx)
				var head_world_pos = skeleton_3d.to_global(head_global_pose.origin)
				print("DEBUG: Positioning head target to bone ", head_bone, " at ", head_world_pos + Vector3(0, 0, 0.1))
				head_target.global_position = head_world_pos + Vector3(0, 0, 0.1)
				head_target.visible = true
				# CRITICAL: Update original positions dictionary for head target too
				target_original_positions[head_target] = head_target.position
				print("DEBUG: Head target position set to: ", head_target.global_position, " visible: ", head_target.visible)
				print("DEBUG: Updated original position for head_target to: ", head_target.position)
			else:
				print("ERROR: Could not find head bone: ", head_bone)
		else:
			print("ERROR: Head bone pattern not found")
	else:
		print("ERROR: Head target is null")

	# Also handle other IK targets that might exist (wrist, ankle, toes, fingers)
	var other_targets = [
		left_wrist_target, right_wrist_target, left_ankle_target, right_ankle_target,
		left_toes_target, right_toes_target, left_thumb_target, right_thumb_target,
		left_index_target, right_index_target
	]

	for target in other_targets:
		if target:
			# Update original positions dictionary for any existing additional targets
			target_original_positions[target] = target.position
			print("DEBUG: Updated original position for additional target ", target.name, " to: ", target.position)

	print("IK targets repositioned to skeleton and original positions updated")

func try_body_click_ragdoll(mouse_pos: Vector2) -> bool:
	"""Try to click on character body to activate ragdoll with force application"""
	# Don't activate ragdoll if already in ragdoll mode
	if is_ragdoll_active:
		print("DEBUG: Click ignored - already in ragdoll mode")
		return false

	if not camera:
		print("ERROR: No camera for body click raycast")
		return false

	var space_state = cached_space_state
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000

	print("DEBUG: Body click raycast from ", from, " to direction ", (to - from).normalized())

	# Try multiple collision masks to find character body or physical bones
	var collision_masks = [1, 2, 4, 8, 16, 32, 0xFFFFFFFF]  # Try different layers including all layers

	for mask in collision_masks:
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = mask
		var result = space_state.intersect_ray(query)

		if result:
			var hit_point = result.get("position")
			var _hit_normal = result.get("normal")
			var hit_collider = result.get("collider")

			print("DEBUG: Hit something with mask ", mask, " - collider: ", hit_collider, " at ", hit_point)

			# Check if we hit the character body or physical bones ONLY - no proximity checks
			if hit_collider and (is_character_body(hit_collider) or is_physical_bone(hit_collider)):
				print("Body click detected at: ", hit_point, " on collider: ", hit_collider)

				# Determine which body part was clicked based on hit position
				var body_part = determine_body_part_from_position(hit_point)

				# Calculate force direction (from camera towards hit point)
				var force_direction = (hit_point - from).normalized()
				var force_magnitude = click_force_strength  # Configurable force strength

				# Apply ragdoll and force to the clicked body part
				apply_ragdoll_with_force(body_part, hit_point, force_direction * force_magnitude)

				return true

	print("DEBUG: No hit detected with any collision mask - trying fallback approach")

	# NO FALLBACK - only activate ragdoll if we actually hit the character mesh
	print("DEBUG: No hit detected with any collision mask - trying fallback approach")
	print("DEBUG: No valid character collision detected - ragdoll not activated")
	return false

func is_character_body(collider: Node) -> bool:
	"""Check if the collider is part of the character body"""
	print("DEBUG: Checking if collider is character body: ", collider, " name: ", collider.name)

	# Look for the character model or its children
	var current = collider
	while current:
		print("DEBUG: Checking node: ", current.name, " type: ", current.get_class())
		if current.name.to_lower().contains("character") or current.name.to_lower().contains("model"):
			print("DEBUG: Found character by name match")
			return true
		if current == character_model:
			print("DEBUG: Found character by direct reference match")
			return true
		# Also check for mesh instances or collision shapes that might be part of character
		if current is MeshInstance3D or current is CollisionShape3D:
			var parent = current.get_parent()
			if parent and (parent == character_model or parent.name.to_lower().contains("character")):
				print("DEBUG: Found character through mesh/collision parent")
				return true
		current = current.get_parent()
	print("DEBUG: Not character body")
	return false

func is_near_character(world_pos: Vector3) -> bool:
	"""Check if the hit position is near the character"""
	if not character_model:
		return false

	var character_pos = character_model.global_position
	var distance = world_pos.distance_to(character_pos)
	print("DEBUG: Hit distance from character: ", distance)

	# If hit is within reasonable distance of character, consider it a character hit
	return distance < 2.0  # 2 meter radius around character

func is_physical_bone(collider: Node) -> bool:
	"""Check if the collider is a physical bone"""
	return collider is PhysicalBone3D

func try_screen_space_character_detection(mouse_pos: Vector2) -> bool:
	"""Fallback method: detect character click based on screen bounds"""
	if not character_model or not camera:
		return false

	# Project character position to screen space
	var character_screen_pos = camera.unproject_position(character_model.global_position)

	# Check if mouse is reasonably close to character on screen
	var screen_distance = mouse_pos.distance_to(character_screen_pos)
	print("DEBUG: Screen space - character at ", character_screen_pos, " mouse at ", mouse_pos, " distance: ", screen_distance)

	if screen_distance < 200:  # 200 pixels radius
		print("DEBUG: Screen space character click detected")

		# Estimate 3D position based on character position
		var estimated_hit_point = character_model.global_position
		var body_part = "torso"  # Default to torso for screen-space clicks

		# Calculate force direction (from camera towards character)
		var from = camera.global_position
		var force_direction = (estimated_hit_point - from).normalized()
		var force_magnitude = click_force_strength  # Configurable force strength

		# Apply ragdoll and force
		apply_ragdoll_with_force(body_part, estimated_hit_point, force_direction * force_magnitude)
		return true

	return false

func determine_body_part_from_position(world_pos: Vector3) -> String:
	"""Determine which body part was clicked based on world position"""
	if not skeleton_3d or not character_model:
		return "unknown"

	# Get character center for relative positioning
	var char_pos = character_model.global_position
	var relative_pos = world_pos - char_pos

	# Determine body part based on height and position
	var height = relative_pos.y
	var is_left = relative_pos.x > 0  # Character facing away from camera

	if height > 1.6:  # Head/neck area
		return "head"
	elif height > 1.2:  # Upper torso/arms
		if abs(relative_pos.x) > 0.3:  # Side areas = arms
			return "left_arm" if is_left else "right_arm"
		else:
			return "torso"
	elif height > 0.8:  # Mid torso
		return "torso"
	elif height > 0.4:  # Thighs/upper legs
		return "left_leg" if is_left else "right_leg"
	else:  # Lower legs/feet
		return "left_leg" if is_left else "right_leg"

func apply_ragdoll_with_force(body_part: String, hit_point: Vector3, force_vector: Vector3):
	"""Apply ragdoll to body part and add force at hit location"""
	print("Applying ragdoll with force to: ", body_part, " at ", hit_point)

	match body_part:
		"left_arm":
			if not left_arm_ragdoll_active:
				toggle_left_arm_ragdoll()
			apply_force_to_arm_bones(get_left_arm_bones(), force_vector, hit_point)
		"right_arm":
			if not right_arm_ragdoll_active:
				toggle_right_arm_ragdoll()
			apply_force_to_arm_bones(get_right_arm_bones(), force_vector, hit_point)
		"head", "torso", "left_leg", "right_leg":
			# For other body parts, activate full ragdoll with force
			print("DEBUG: Activating full ragdoll for body part: ", body_part)
			if not is_ragdoll_active:
				print("DEBUG: Ragdoll not active, toggling ragdoll")
				await toggle_ragdoll()  # Wait for ragdoll activation to complete
			else:
				print("DEBUG: Ragdoll already active")
			# Additional frame wait to ensure physics is fully started
			await get_tree().process_frame
			apply_force_to_body_part(body_part, force_vector, hit_point)

func apply_force_to_arm_bones(bone_names: Array, force: Vector3, hit_point: Vector3):
	"""Apply force to specific arm bones"""
	if not skeleton_3d:
		return

	# Find the closest bone to the hit point for primary force application
	var closest_bone = null
	var closest_distance = 999999.0

	for bone_name in bone_names:
		var physical_bone = find_physical_bone_by_name(bone_name)
		if physical_bone:
			var bone_pos = physical_bone.global_position
			var distance = bone_pos.distance_to(hit_point)
			if distance < closest_distance:
				closest_distance = distance
				closest_bone = physical_bone

	# Apply primary force to closest bone
	if closest_bone:
		closest_bone.apply_central_impulse(force)
		print("Applied force ", force, " to bone: ", closest_bone.bone_name)

		# Apply smaller force to connected bones for realistic motion
		for bone_name in bone_names:
			var physical_bone = find_physical_bone_by_name(bone_name)
			if physical_bone and physical_bone != closest_bone:
				physical_bone.apply_central_impulse(force * 0.3)  # 30% of main force

func apply_force_to_body_part(body_part: String, force: Vector3, _hit_point: Vector3):
	"""Apply force to a general body part during full ragdoll"""
	if not skeleton_3d:
		print("ERROR: No skeleton for body force application")
		return

	print("DEBUG: Applying force to body part: ", body_part, " with force: ", force)

	var target_bones = []
	match body_part:
		"head":
			target_bones = ["characters3d.com___Head", "characters3d.com___Neck"]
		"torso":
			target_bones = ["characters3d.com___Chest", "characters3d.com___Upper_Chest", "characters3d.com___Spine", "characters3d.com___Hips"]
		"left_leg":
			target_bones = ["characters3d.com___L_Upper_Leg", "characters3d.com___L_Lower_Leg"]
		"right_leg":
			target_bones = ["characters3d.com___R_Upper_Leg", "characters3d.com___R_Lower_Leg"]

	print("DEBUG: Target bones for ", body_part, ": ", target_bones)

	# Apply force to target bones
	var bones_found = 0
	for bone_name in target_bones:
		var physical_bone = find_physical_bone_by_name(bone_name)
		if physical_bone:
			physical_bone.apply_central_impulse(force)  # Use full force for more visible effect
			print("✓ Applied body force to: ", bone_name)
			bones_found += 1
		else:
			print("✗ Physical bone not found: ", bone_name)

	print("DEBUG: Applied force to ", bones_found, "/", target_bones.size(), " bones")

	# If no torso bones found, apply force to center mass (hips)
	if body_part == "torso" and bones_found == 0:
		print("DEBUG: No torso bones found, trying to find any spine/torso bone...")
		# Try to find any spine/torso related bone
		for child in skeleton_3d.get_children():
			if child is PhysicalBone3D:
				var bone_name_lower = child.bone_name.to_lower()
				if "spine" in bone_name_lower or "chest" in bone_name_lower or "hips" in bone_name_lower:
					child.apply_central_impulse(force)
					print("✓ Applied fallback torso force to: ", child.bone_name)
					bones_found += 1

func bake_specific_ik_poses_to_bone_poses(bone_names: Array):
	"""Bake IK poses to bone poses for specific bones only"""
	if not skeleton_3d:
		return

	print("Baking IK poses for specific bones: ", bone_names)
	var bones_baked = 0

	for bone_name in bone_names:
		var bone_idx = skeleton_3d.find_bone(bone_name)
		if bone_idx >= 0:
			# Check if this bone has a global pose override (from IK)
			var current_global_pose = skeleton_3d.get_bone_global_pose(bone_idx)
			var rest_global_pose = skeleton_3d.get_bone_global_rest(bone_idx)

			# If the current global pose differs from rest, it likely has IK applied
			if not current_global_pose.is_equal_approx(rest_global_pose):
				# Convert the global pose (which includes IK) to a local bone pose
				var parent_idx = skeleton_3d.get_bone_parent(bone_idx)
				var local_pose: Transform3D

				if parent_idx >= 0:
					# Convert global pose to local pose relative to parent
					var parent_global_pose = skeleton_3d.get_bone_global_pose(parent_idx)
					local_pose = parent_global_pose.affine_inverse() * current_global_pose
				else:
					# Root bone - global pose IS the local pose
					local_pose = current_global_pose

				# Set the actual bone pose (what PhysicalBone3D reads)
				skeleton_3d.set_bone_pose(bone_idx, local_pose)
				bones_baked += 1
				print("Baked IK pose for bone: ", bone_name)

	print("Baked ", bones_baked, " specific IK poses into bone poses")

func seamless_partial_ragdoll(bone_names: Array, enable: bool):
	"""Enable partial ragdoll with seamless position matching"""
	if not skeleton_3d:
		return

	if enable:
		print("Partial ragdoll with IK pose inheritance for bones: ", bone_names)

		# Step 1: Transfer IK poses for the specific bones (includes clearing overrides)
		await transfer_specific_ik_poses_to_physical_bones(bone_names)

		# Step 2: Disable only the relevant IK chains for these bones
		for bone_name in bone_names:
			disable_ik_for_bone(bone_name)

		# Step 3: Start physics simulation for specific bones - they now inherit IK poses
		skeleton_3d.physical_bones_start_simulation(bone_names)
		print("Started physics simulation with IK inheritance for bones: ", bone_names)

		print("Partial ragdoll active (unified approach): ", bone_names)
	else:
		# Smoothly transition back to animation
		start_physics_animation_transition(bone_names, false, 1.0)

		# Wait for transition to complete, then restore IK functionality
		await get_tree().create_timer(1.2).timeout
		restore_ik_for_bones(bone_names)

		# Ensure targets are repositioned correctly and visible
		reposition_ik_targets_to_skeleton()
		ensure_all_ik_targets_visible()

		print("Partial ragdoll disabled - IK functionality restored for bones: ", bone_names)

func get_torso_bones() -> Array:
	"""Get bone names for torso/spine"""
	return [
		"characters3d.com___Hips",
		"characters3d.com___Spine",
		"characters3d.com___Chest",
		"characters3d.com___Upper_Chest"
	]

func get_head_neck_bones() -> Array:
	"""Get bone names for head and neck"""
	return [
		"characters3d.com___Neck",
		"characters3d.com___Head"
	]

func reset_character():
	"""Reset character to upright position"""
	position = Vector3.ZERO
	rotation = Vector3.ZERO

	if is_ragdoll_active:
		toggle_ragdoll()  # Turn off ragdoll
		await get_tree().process_frame
		toggle_ragdoll()  # Turn back on

	print("Character reset")

func reset_ik_targets():
	"""Reset all IK targets to their original positions"""
	print("Resetting all IK targets to original positions")

	for target in target_original_positions.keys():
		if target and is_instance_valid(target):
			target.position = target_original_positions[target]

	# Update selective IK to disable all chains since targets are back to original positions
	if ik_enabled:
		update_selective_ik()

	print("All IK targets reset - animation will control all body parts")

func smooth_reset_ik_targets(duration: float = 0.5):
	"""Smoothly reset all IK targets to their original positions over time"""
	print("Smoothly resetting IK targets to original positions over ", duration, " seconds")

	# Store current positions for lerping
	var start_positions = {}
	for target in target_original_positions.keys():
		if target and is_instance_valid(target):
			start_positions[target] = target.position

	var elapsed = 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var progress = min(elapsed / duration, 1.0)

		# Smoothly interpolate each target to its original position
		for target in target_original_positions.keys():
			if target and is_instance_valid(target):
				var start_pos = start_positions[target]
				var target_pos = target_original_positions[target]
				target.position = start_pos.lerp(target_pos, progress)

		# Update IK during the transition
		if ik_enabled:
			update_selective_ik()

	# Ensure exact final positions
	for target in target_original_positions.keys():
		if target and is_instance_valid(target):
			target.position = target_original_positions[target]

	# Final IK update
	if ik_enabled:
		update_selective_ik()

	print("Smooth IK target reset complete")

func stabilize_head_neck_on_ragdoll_start():
	"""Verify and ensure head/neck physics properties are set correctly"""
	if not skeleton_3d:
		return

	print("Verifying head/neck physics properties are applied correctly")

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var bone_idx = child.get_bone_id()
			var bone_name = skeleton_3d.get_bone_name(bone_idx).to_lower()

			if "head" in bone_name or "neck" in bone_name:
				# Verify settings are correct (these should already be set during creation)
				print("Verified physics for: ", skeleton_3d.get_bone_name(bone_idx),
					" - Mass: ", child.mass,
					" - Linear Damp: ", child.linear_damp,
					" - Angular Damp: ", child.angular_damp,
					" - Gravity Scale: ", child.gravity_scale)

	# Apply additional stability measures for head/neck
	apply_additional_head_neck_constraints()

# Removed complex reapplication - constraints set once during bone creation

func final_ragdoll_preparation():
	"""Final cleanup before starting physics simulation to prevent conflicts"""
	if not skeleton_3d:
		return

	print("=== FINAL RAGDOLL PREPARATION ===")

	# Double-check that all systems are fully disabled
	if ik_enabled:
		print("WARNING: IK still enabled during ragdoll prep - force disabling")
		ik_enabled = false

	if animation_player and animation_player.is_playing():
		print("WARNING: Animation still playing during ragdoll prep - force stopping")
		animation_player.stop()

	# Ensure physical bones are in the correct state
	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			# Ensure physical bones are not following skeleton poses
			# (They should be in their transferred IK positions)
			pass

	# Make sure skeleton is ready for physics mode (Godot 4 - bones are enabled by default)
	# set_bone_enabled_count is deprecated in Godot 4

	print("=== RAGDOLL PREPARATION COMPLETE ===")

# Removed force constraint reapplication - constraints set once during bone creation

# Removed constraint verification - constraints set once during bone creation

# Removed pre-warming system - constraints set once during bone creation should work consistently

func ensure_physics_properties_applied():
	"""Reset all physics properties to original values - fixes ragdoll sleep contamination"""
	if not skeleton_3d:
		return

	print("Resetting ALL physics properties to original values")

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var bone_idx = child.get_bone_id()
			var bone_name = skeleton_3d.get_bone_name(bone_idx).to_lower()

			# Reset ALL physics properties to lighter, less stiff values
			if "head" in bone_name:
				child.mass = head_mass
				child.linear_damp = 6.0    # Much higher for head stability
				child.angular_damp = 8.0   # Much higher to prevent floppiness
				child.gravity_scale = 0.15  # Lower gravity for head
				child.friction = 1.0
			elif "neck" in bone_name:
				child.mass = neck_mass
				child.linear_damp = 8.0    # Very high for strong neck support
				child.angular_damp = 10.0  # Very high to prevent neck wobble
				child.gravity_scale = 0.1   # Minimal gravity for neck
				child.friction = 1.0
			elif "lower_arm" in bone_name:
				child.linear_damp = 2.0    # Original working values
				child.angular_damp = 3.0
				child.gravity_scale = gravity_strength
			elif "lower_leg" in bone_name:
				child.linear_damp = 0.5    # Original working values
				child.angular_damp = 0.8
				child.gravity_scale = gravity_strength
			elif "shoulder" in bone_name:
				child.linear_damp = 5.0    # Original working values
				child.angular_damp = 8.0
				child.gravity_scale = gravity_strength
			else:
				# Default values for other bones - original working values
				child.linear_damp = 0.1
				child.angular_damp = 0.1
				child.gravity_scale = gravity_strength

	print("All physics properties reset to consistent original values")

func apply_additional_head_neck_constraints():
	"""Apply additional constraints to make head/neck even more stable"""
	if not skeleton_3d:
		return

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var bone_idx = child.get_bone_id()
			var bone_name = skeleton_3d.get_bone_name(bone_idx).to_lower()

			if "head" in bone_name or "neck" in bone_name:
				# Apply additional physics constraints for stability
				# Note: Some properties may not be available on PhysicalBone3D in Godot 4.x

				# Try to limit angular velocity if the method exists
				if child.has_method("set_max_angular_velocity"):
					child.set_max_angular_velocity(2.0)

				# Force awake state to ensure physics are active
				if child.has_method("set_sleeping"):
					child.set_sleeping(false)

				print("Applied additional constraints to: ", skeleton_3d.get_bone_name(bone_idx))

func restore_normal_head_neck_damping():
	"""Restore normal damping values for head/neck after initial stabilization"""
	if not skeleton_3d:
		return

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			var bone_idx = child.get_bone_id()
			var bone_name = skeleton_3d.get_bone_name(bone_idx).to_lower()

			if "head" in bone_name:
				child.linear_damp = 8.0    # Keep extremely strong damping
				child.angular_damp = 10.0  # Maintain strong head rotation control
				child.gravity_scale = 0.2  # Keep minimal gravity
				child.mass = 0.3           # Keep very light mass
				child.friction = 1.0       # Maximum friction for control
			elif "neck" in bone_name:
				child.linear_damp = 10.0   # Keep maximum neck damping
				child.angular_damp = 12.0  # Maintain strong neck rotation control
				child.gravity_scale = 0.1  # Keep almost no gravity on neck
				child.mass = 0.2           # Keep extremely light neck
				child.friction = 1.0       # Maximum friction for neck

	print("Restored normal head/neck damping values")

func update_target_visual(target: Node3D, is_controlling_ik: bool):
	"""Update target visual to show if it's actively controlling IK"""
	if not target or not target.has_meta("mesh_instance"):
		return

	var mesh_instance = target.get_meta("mesh_instance")
	if not mesh_instance:
		return

	var material = StandardMaterial3D.new()
	material.emission_enabled = true

	if is_controlling_ik:
		# Green for active IK control
		material.albedo_color = Color.GREEN
		material.emission = Color.GREEN * 0.5
	else:
		# Red for animation control (inactive IK)
		material.albedo_color = Color.RED
		material.emission = Color.RED * 0.3

	mesh_instance.material_override = material

func create_ground_plane():
	"""Create a stable ground plane for ragdoll physics"""
	var ground = StaticBody3D.new()
	ground.name = "GroundPlane"

	# Create a large ground plane
	var ground_mesh = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(50, 50)  # Large ground plane
	ground_mesh.mesh = plane_mesh
	ground.add_child(ground_mesh)

	# Create collision shape for ground - thicker for stability
	var ground_collision = CollisionShape3D.new()
	var ground_shape = BoxShape3D.new()
	ground_shape.size = Vector3(50, 0.5, 50)  # Thicker collision box for stability
	ground_collision.shape = ground_shape
	ground.add_child(ground_collision)

	# Create ground material with high friction
	var ground_material = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.3, 0.3, 1.0)  # Dark gray
	ground_mesh.material_override = ground_material

	# Position ground slightly below zero for better contact
	ground.position = Vector3(0, -0.25, 0)

	# Set collision layers for ground with physics material
	ground.collision_layer = 1  # Default environment layer
	ground.collision_mask = 0   # Ground doesn't need to detect collisions

	# Create physics material for ground with very high friction
	var physics_material = PhysicsMaterial.new()
	physics_material.friction = 1.0     # Maximum friction to prevent sliding
	physics_material.bounce = 0.0       # No bounce to prevent jittering
	ground.physics_material_override = physics_material

	add_child(ground)
	print("Created stable ground plane for ragdoll physics")

func update_ragdoll_sleep_state(delta: float):
	"""Monitor ragdoll movement and put it to sleep when movement is minimal"""
	if not skeleton_3d or not character_model:
		return

	var current_position = character_model.global_position
	var movement_speed = last_ragdoll_position.distance_to(current_position) / delta if delta > 0 else 0.0
	last_ragdoll_position = current_position

	ragdoll_sleep_timer += delta

	# Don't allow sleep for first few seconds to let ragdoll settle naturally
	if ragdoll_sleep_timer < ragdoll_sleep_delay:
		return

	if ragdoll_sleeping:
		# Check if ragdoll should wake up (significant movement)
		if movement_speed > ragdoll_wake_threshold:
			wake_ragdoll()
	else:
		# Check if ragdoll should sleep (minimal movement)
		if movement_speed < ragdoll_sleep_threshold:
			sleep_ragdoll()

func sleep_ragdoll():
	"""Put ragdoll to sleep by setting very high damping"""
	if ragdoll_sleeping:
		return

	ragdoll_sleeping = true
	print("Ragdoll going to sleep - movement too low")

	# Use very high damping to stop movement without mesh stretching
	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			child.linear_damp = 0.99   # Very high damping
			child.angular_damp = 0.99
			# Also set low gravity scale to reduce settling forces
			child.gravity_scale = 0.1

func wake_ragdoll():
	"""Wake ragdoll up by restoring normal physics"""
	if not ragdoll_sleeping:
		return

	ragdoll_sleeping = false
	print("Ragdoll waking up - movement detected")

	# Restore normal physics properties
	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			child.linear_damp = 0.9    # Normal high damping
			child.angular_damp = 0.95
			child.gravity_scale = 1.2  # Normal gravity

func calculate_bone_length(bone_idx: int) -> float:
	"""Calculate approximate bone length based on children or default value"""
	if not skeleton_3d:
		return 0.1

	# Get bone children to calculate length
	var bone_children = []
	for i in range(skeleton_3d.get_bone_count()):
		if skeleton_3d.get_bone_parent(i) == bone_idx:
			bone_children.append(i)

	if bone_children.size() > 0:
		# Use distance to first child as bone length
		var bone_pose = skeleton_3d.get_bone_pose(bone_idx)
		var child_pose = skeleton_3d.get_bone_pose(bone_children[0])
		var length = bone_pose.origin.distance_to(child_pose.origin)
		return max(length, 0.05)  # Minimum length
	else:
		# No children, use default small length
		return 0.1
