extends CharacterBody3D
class_name FPPCharacterController

## Full-Body First-Person Character Controller with IK and ADS
## Inspired by Arma 3's true FPP system

# Movement
@export var walk_speed: float = 3.0
@export var sprint_speed: float = 6.0
@export var crouch_speed: float = 1.5
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.003
@export var gravity: float = 9.8

# Character state
var is_crouching: bool = false
var is_sprinting: bool = false
var is_aiming: bool = false

# Camera and look
@export var head_path: NodePath
@export var camera_path: NodePath
@export var spine_path: NodePath
@export var aim_camera_offset: Vector3 = Vector3(0, 0, 0)  # Offset when ADS

var head: Node3D
var camera: Camera3D
var spine: Node3D

# Body parts for IK
@export var right_hand_path: NodePath
@export var left_hand_path: NodePath
@export var weapon_grip_path: NodePath
@export var weapon_support_path: NodePath
@export var ads_target_path: NodePath

var right_hand: Node3D
var left_hand: Node3D
var weapon_grip: Node3D  # Where right hand grips weapon
var weapon_support: Node3D  # Where left hand supports weapon (foregrip)
var ads_target: Node3D  # Sight alignment point for ADS

# IK chains (will be created dynamically)
var right_hand_ik: Node3D
var left_hand_ik: Node3D

# Look rotation
var camera_x_rotation: float = 0.0
var camera_y_rotation: float = 0.0
@export var max_look_up: float = 80.0
@export var max_look_down: float = 80.0

# ADS
@export var ads_transition_speed: float = 8.0
var ads_blend: float = 0.0  # 0 = hipfire, 1 = ADS
@export var ads_fov: float = 50.0
@export var hipfire_fov: float = 90.0

# Weapon sway
@export var sway_amount: float = 0.02
@export var sway_speed: float = 5.0
@export var breathing_amount: float = 0.001
@export var breathing_speed: float = 1.5
var sway_time: float = 0.0
var breathing_time: float = 0.0

# Bob
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.08
var bob_time: float = 0.0

# Original camera position (relative to head)
var original_camera_position: Vector3

func _ready():
	# Get node references
	head = get_node(head_path) if head_path else null
	camera = get_node(camera_path) if camera_path else null
	spine = get_node(spine_path) if spine_path else null

	right_hand = get_node(right_hand_path) if right_hand_path else null
	left_hand = get_node(left_hand_path) if left_hand_path else null
	weapon_grip = get_node(weapon_grip_path) if weapon_grip_path else null
	weapon_support = get_node(weapon_support_path) if weapon_support_path else null
	ads_target = get_node(ads_target_path) if ads_target_path else null

	if camera:
		original_camera_position = camera.position
		camera.fov = hipfire_fov

	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate camera
		camera_y_rotation -= event.relative.x * mouse_sensitivity
		camera_x_rotation -= event.relative.y * mouse_sensitivity

		# Clamp vertical rotation
		camera_x_rotation = clamp(camera_x_rotation, deg_to_rad(-max_look_up), deg_to_rad(max_look_down))

	# Toggle mouse capture for testing
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Handle input states
	is_sprinting = Input.is_action_pressed("sprint") and not is_aiming
	is_aiming = Input.is_action_pressed("aim_down_sights")

	if Input.is_action_just_pressed("crouch"):
		is_crouching = not is_crouching

	# Handle gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Get movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Determine speed
	var speed = walk_speed
	if is_sprinting:
		speed = sprint_speed
	elif is_crouching:
		speed = crouch_speed
	elif is_aiming:
		speed = crouch_speed  # Slow when aiming

	# Calculate movement direction relative to camera
	var direction = Vector3.ZERO
	if head:
		direction = (head.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Apply movement
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 10)

	move_and_slide()

	# Update camera and body
	_update_camera_and_head(delta)
	_update_ads(delta)
	_update_weapon_ik(delta)
	_update_procedural_movement(delta)

func _update_camera_and_head(delta):
	if not head or not camera:
		return

	# Rotate body around Y axis to follow camera yaw
	rotation.y = camera_y_rotation

	# Rotate head for pitch (with some spine involvement for realism)
	head.rotation.x = camera_x_rotation

	# Optional: Add some spine rotation for looking up/down (more realistic)
	if spine:
		# Distribute pitch rotation between spine and head
		spine.rotation.x = camera_x_rotation * 0.3
		head.rotation.x = camera_x_rotation * 0.7

func _update_ads(delta):
	# Smooth ADS transition
	var target_ads = 1.0 if is_aiming else 0.0
	ads_blend = lerp(ads_blend, target_ads, ads_transition_speed * delta)

	if not camera or not ads_target:
		return

	# Transition FOV
	camera.fov = lerp(hipfire_fov, ads_fov, ads_blend)

	# Move camera to align with sight when ADS
	# In true ADS, we move the weapon so the sight aligns with camera center
	# But for visual clarity, we can also slightly move camera toward the sight
	var target_cam_pos = original_camera_position
	if ads_blend > 0.01:
		# Calculate offset to align sight with screen center
		var sight_local_pos = camera.to_local(ads_target.global_position)
		target_cam_pos = original_camera_position - sight_local_pos * ads_blend

	camera.position = camera.position.lerp(target_cam_pos, 10.0 * delta)

func _update_weapon_ik(delta):
	# This is where we'd update IK chains for hands
	# For now, this is a simplified version

	if not right_hand or not left_hand or not weapon_grip or not weapon_support:
		return

	# Right hand IK to weapon grip
	if weapon_grip:
		# In a full IK system, we'd use SkeletonIK3D or custom IK solver
		# For blockout, we can directly position hands
		right_hand.global_position = right_hand.global_position.lerp(
			weapon_grip.global_position,
			20.0 * delta
		)
		right_hand.global_rotation = right_hand.global_rotation.lerp(
			weapon_grip.global_rotation,
			20.0 * delta
		)

	# Left hand IK to weapon support/foregrip
	if weapon_support:
		left_hand.global_position = left_hand.global_position.lerp(
			weapon_support.global_position,
			20.0 * delta
		)
		left_hand.global_rotation = left_hand.global_rotation.lerp(
			weapon_support.global_rotation,
			20.0 * delta
		)

func _update_procedural_movement(delta):
	if not camera:
		return

	sway_time += delta
	breathing_time += delta

	# Calculate sway based on mouse movement
	var mouse_velocity = Vector2.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_velocity = Vector2(camera_y_rotation, camera_x_rotation)

	# Breathing sway (subtle sine wave)
	var breathing_offset = Vector3(
		sin(breathing_time * breathing_speed) * breathing_amount,
		cos(breathing_time * breathing_speed * 0.5) * breathing_amount,
		0
	)

	# Movement bob
	var is_moving = velocity.length() > 0.1 and is_on_floor()
	if is_moving:
		bob_time += delta * velocity.length() * 0.5
		var bob_offset = Vector3(
			cos(bob_time * bob_frequency * 0.5) * bob_amplitude * 0.5,
			sin(bob_time * bob_frequency) * bob_amplitude,
			0
		)
		breathing_offset += bob_offset
	else:
		bob_time = 0.0

	# Reduce sway when aiming
	var sway_multiplier = lerp(1.0, 0.2, ads_blend)
	breathing_offset *= sway_multiplier

	# Apply subtle offset (we'd typically apply this to weapon bone)
	# For now, apply small offset to camera
	var target_offset = breathing_offset
	camera.position = camera.position.lerp(
		original_camera_position + target_offset,
		5.0 * delta
	)

func _process(_delta):
	# Debug info
	if Input.is_action_just_pressed("ui_accept"):
		print("ADS Blend: ", ads_blend)
		print("Is Aiming: ", is_aiming)
		print("Camera FOV: ", camera.fov if camera else "N/A")
