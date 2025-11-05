extends CharacterBody3D
class_name EnhancedFPPController

## Enhanced FPP Controller with proper IK integration and animation blending
## This version demonstrates a more complete Arma 3-style system

# Movement parameters
@export_group("Movement")
@export var walk_speed: float = 3.0
@export var sprint_speed: float = 6.0
@export var crouch_speed: float = 1.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var mouse_sensitivity: float = 0.003

# Character state
var is_crouching: bool = false
var is_sprinting: bool = false
var is_aiming: bool = false
var stance_height: float = 1.8
var crouch_height: float = 1.2

# Node references
@export_group("Character Bones")
@export var head: Node3D
@export var camera: Camera3D
@export var spine: Node3D
@export var right_shoulder: Node3D
@export var right_arm: Node3D
@export var right_hand: Node3D
@export var left_shoulder: Node3D
@export var left_arm: Node3D
@export var left_hand: Node3D

# Weapon references
@export_group("Weapon System")
@export var weapon: Node3D
@export var weapon_grip: Node3D
@export var weapon_support: Node3D
@export var ads_sight: Node3D

# IK chains
@export_group("IK System")
@export var right_hand_ik: SimpleIKChain
@export var left_hand_ik: SimpleIKChain
@export var enable_ik: bool = true

# Look control
@export_group("Camera Control")
@export var max_look_up: float = 80.0
@export var max_look_down: float = 80.0
@export var spine_look_influence: float = 0.3  # How much spine follows head rotation
var camera_x_rotation: float = 0.0
var camera_y_rotation: float = 0.0

# ADS system
@export_group("ADS Settings")
@export var ads_transition_speed: float = 8.0
@export var ads_fov: float = 50.0
@export var hipfire_fov: float = 90.0
@export var ads_camera_offset: Vector3 = Vector3(0, -0.02, 0)
var ads_blend: float = 0.0
var original_camera_position: Vector3

# Procedural animation
@export_group("Procedural Effects")
@export var breathing_amount: float = 0.001
@export var breathing_speed: float = 1.5
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08
@export var weapon_inertia: float = 0.02
@export var weapon_sway_amount: float = 0.05

var breathing_time: float = 0.0
var bob_time: float = 0.0
var previous_camera_rotation: Vector2 = Vector2.ZERO

# Animation blending
@export_group("Animation")
@export var animation_tree: AnimationTree
@export var upper_body_blend: float = 1.0  # Blend between animation and IK
var current_movement_speed: float = 0.0

# IK targets (created dynamically)
var right_hand_ik_target: Node3D
var left_hand_ik_target: Node3D
var right_hand_pole_target: Node3D
var left_hand_pole_target: Node3D

func _ready():
	# Setup camera
	if camera:
		original_camera_position = camera.position
		camera.fov = hipfire_fov

	# Create IK targets
	_setup_ik_targets()

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_ik_targets():
	"""Create dynamic IK targets for hand positioning"""
	# Right hand IK target (weapon grip)
	right_hand_ik_target = Node3D.new()
	right_hand_ik_target.name = "RightHandIKTarget"
	if weapon_grip:
		weapon_grip.add_child(right_hand_ik_target)

	# Left hand IK target (weapon support)
	left_hand_ik_target = Node3D.new()
	left_hand_ik_target.name = "LeftHandIKTarget"
	if weapon_support:
		weapon_support.add_child(left_hand_ik_target)

	# Pole targets for elbow positioning
	right_hand_pole_target = Node3D.new()
	right_hand_pole_target.name = "RightPoleTarget"
	if right_shoulder:
		right_shoulder.add_child(right_hand_pole_target)
		right_hand_pole_target.position = Vector3(0.5, 0, -0.5)

	left_hand_pole_target = Node3D.new()
	left_hand_pole_target.name = "LeftPoleTarget"
	if left_shoulder:
		left_shoulder.add_child(left_hand_pole_target)
		left_hand_pole_target.position = Vector3(-0.5, 0, -0.5)

	# Setup IK chains if available
	if right_hand_ik:
		right_hand_ik.root_bone = right_shoulder
		right_hand_ik.middle_bone = right_arm
		right_hand_ik.end_bone = right_hand
		right_hand_ik.target = right_hand_ik_target
		right_hand_ik.pole_target = right_hand_pole_target

	if left_hand_ik:
		left_hand_ik.root_bone = left_shoulder
		left_hand_ik.middle_bone = left_arm
		left_hand_ik.end_bone = left_hand
		left_hand_ik.target = left_hand_ik_target
		left_hand_ik.pole_target = left_hand_pole_target

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate camera
		camera_y_rotation -= event.relative.x * mouse_sensitivity
		camera_x_rotation -= event.relative.y * mouse_sensitivity

		# Clamp vertical rotation
		camera_x_rotation = clamp(camera_x_rotation,
			deg_to_rad(-max_look_up),
			deg_to_rad(max_look_down))

	# Toggle mouse capture
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Update states
	is_sprinting = Input.is_action_pressed("sprint") and not is_aiming
	is_aiming = Input.is_action_pressed("aim_down_sights")

	if Input.is_action_just_pressed("crouch"):
		is_crouching = not is_crouching

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed = _get_current_speed()
	var direction = _get_movement_direction(input_dir)

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 10)

	move_and_slide()

	# Update systems
	_update_camera_and_head(delta)
	_update_ads_system(delta)
	_update_stance(delta)
	_update_procedural_effects(delta)

	# Update IK
	if enable_ik:
		_update_ik_system(delta)

	# Track movement speed for animation
	current_movement_speed = Vector2(velocity.x, velocity.z).length()

func _get_current_speed() -> float:
	if is_sprinting:
		return sprint_speed
	elif is_crouching:
		return crouch_speed
	elif is_aiming:
		return crouch_speed
	return walk_speed

func _get_movement_direction(input_dir: Vector2) -> Vector3:
	var direction = Vector3.ZERO
	if head:
		direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	return direction

func _update_camera_and_head(delta):
	if not head or not camera:
		return

	# Rotate body to follow camera yaw
	rotation.y = camera_y_rotation

	# Apply pitch to head
	head.rotation.x = camera_x_rotation

	# Apply partial rotation to spine for more natural look
	if spine:
		spine.rotation.x = camera_x_rotation * spine_look_influence

func _update_ads_system(delta):
	# Smooth ADS transition
	var target_ads = 1.0 if is_aiming else 0.0
	ads_blend = lerp(ads_blend, target_ads, ads_transition_speed * delta)

	if not camera or not ads_sight:
		return

	# Transition FOV
	camera.fov = lerp(hipfire_fov, ads_fov, ads_blend)

	# Calculate camera offset to align sight with screen center
	if ads_blend > 0.01:
		var sight_local_pos = camera.to_local(ads_sight.global_position)
		var target_pos = original_camera_position - (sight_local_pos * ads_blend)
		camera.position = camera.position.lerp(target_pos, 10.0 * delta)
	else:
		camera.position = camera.position.lerp(original_camera_position, 10.0 * delta)

	# Adjust IK blend during ADS
	if right_hand_ik:
		right_hand_ik.blend_amount = 0.5 + (ads_blend * 0.5)  # More IK during ADS
	if left_hand_ik:
		left_hand_ik.blend_amount = 0.7 + (ads_blend * 0.3)

func _update_stance(delta):
	# Smooth crouch transition
	var target_height = crouch_height if is_crouching else stance_height
	if spine:
		var current_y = spine.position.y
		spine.position.y = lerp(current_y, target_height * 0.7, 5.0 * delta)

func _update_procedural_effects(delta):
	if not camera:
		return

	breathing_time += delta

	# Breathing animation (reduced when aiming)
	var breath_multiplier = lerp(1.0, 0.3, ads_blend)
	var breathing_offset = Vector3(
		sin(breathing_time * breathing_speed) * breathing_amount * breath_multiplier,
		cos(breathing_time * breathing_speed * 0.5) * breathing_amount * breath_multiplier,
		0
	)

	# Head bob when moving
	var is_moving = current_movement_speed > 0.1 and is_on_floor()
	if is_moving:
		bob_time += delta * current_movement_speed * 0.5
		var bob_multiplier = lerp(1.0, 0.2, ads_blend)
		breathing_offset += Vector3(
			cos(bob_time * bob_frequency * 0.5) * bob_amplitude * 0.5 * bob_multiplier,
			abs(sin(bob_time * bob_frequency)) * bob_amplitude * bob_multiplier,
			0
		)
	else:
		bob_time = 0.0

	# Weapon inertia (lags behind camera movement)
	var current_rotation = Vector2(camera_x_rotation, camera_y_rotation)
	var rotation_delta = current_rotation - previous_camera_rotation
	previous_camera_rotation = current_rotation

	var inertia_offset = Vector3(-rotation_delta.y, rotation_delta.x, 0) * weapon_inertia
	inertia_offset *= lerp(1.0, 0.3, ads_blend)  # Reduce during ADS

	# Apply combined offset to weapon
	if weapon:
		weapon.rotation.x = lerp(weapon.rotation.x, inertia_offset.x, 10.0 * delta)
		weapon.rotation.y = lerp(weapon.rotation.y, inertia_offset.y, 10.0 * delta)

	# Apply breathing to camera (subtle)
	var camera_offset = breathing_offset * 0.5
	# Don't override ADS positioning, add to it
	var base_pos = camera.position
	camera.position = base_pos + camera_offset * 0.1

func _update_ik_system(delta):
	"""Update IK chains for realistic hand positioning"""
	if not enable_ik:
		return

	# IK chains automatically update in their _physics_process
	# We can add additional logic here if needed

	# Adjust IK based on weapon state
	if right_hand_ik and weapon:
		# Ensure right hand stays on grip
		if weapon_grip and right_hand_ik_target:
			right_hand_ik_target.global_position = weapon_grip.global_position

	if left_hand_ik and weapon:
		# Ensure left hand stays on foregrip
		if weapon_support and left_hand_ik_target:
			left_hand_ik_target.global_position = weapon_support.global_position

func _process(_delta):
	# Debug output
	if Input.is_action_just_pressed("ui_accept"):
		print("=== FPP Controller Debug ===")
		print("ADS Blend: ", ads_blend)
		print("Is Aiming: ", is_aiming)
		print("Camera FOV: ", camera.fov if camera else "N/A")
		print("Movement Speed: ", current_movement_speed)
		print("Crouching: ", is_crouching)
		print("Sprinting: ", is_sprinting)
