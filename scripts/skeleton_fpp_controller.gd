extends CharacterBody3D
class_name SkeletonFPPController

## Complete FPP controller with Skeleton3D, IK, freelook, and weapon system

# Signals for UI and other systems
signal weapon_changed(weapon: Weapon)
signal stance_changed(old_stance: Stance, new_stance: Stance)
signal interaction_available(prompt: String)
signal interaction_unavailable()

# Future signals - ready for implementation
#signal ammo_changed(current: int, max: int)  # TODO: Emit when ammo changes
#signal weapon_fired()  # TODO: Emit from weapon.gd
#signal weapon_reloaded()  # TODO: Emit from weapon.gd

# Movement
@export_group("Movement")
@export var walk_speed: float = 3.0
@export var sprint_speed: float = 6.0
@export var crouch_speed: float = 1.5
@export var prone_speed: float = 0.8
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

# Look control
@export_group("Camera Control")
@export var mouse_sensitivity: float = 0.003
@export var max_look_up: float = 80.0
@export var max_look_down: float = 80.0
@export var freelook_max_angle: float = 120.0  # How far you can look without body following
@export var body_rotation_speed: float = 5.0  # How fast body catches up in freelook

# Skeleton and IK
@export_group("Skeleton & IK")
@export var skeleton: Skeleton3D
@export var right_hand_ik: SkeletonIK3D
@export var left_hand_ik: SkeletonIK3D
@export var head_bone_name: String = "Head"
@export var spine_bone_name: String = "Spine"
@export var camera_offset: Vector3 = Vector3(0, 0, 0.1)

# Camera nodes
@export_group("References")
@export var camera: Camera3D
@export var interaction_ray: RayCast3D
@export var ragdoll: RagdollController

# ADS
@export_group("ADS")
@export var ads_transition_speed: float = 8.0
@export var ads_fov: float = 50.0
@export var hipfire_fov: float = 90.0

# State
var stance: Stance = Stance.STANDING
var is_sprinting: bool = false
var is_aiming: bool = false
var is_freelooking: bool = false

# Rotation tracking
var camera_x_rotation: float = 0.0  # Pitch
var camera_y_rotation: float = 0.0  # Yaw
var body_y_rotation: float = 0.0  # Body's actual rotation
var freelook_offset: float = 0.0  # Offset between camera and body in freelook

# ADS
var ads_blend: float = 0.0
var original_camera_position: Vector3

# Weapon system
var current_weapon: Weapon = null
var holstered_weapons: Array[Weapon] = []
var current_weapon_index: int = 0

# Bone indices (cached for performance)
var head_bone_idx: int = -1
var spine_bone_idx: int = -1

# Procedural effects
var breathing_time: float = 0.0
var bob_time: float = 0.0

enum Stance {
	STANDING,
	CROUCHING,
	PRONE
}

func _ready():
	# Add to player group for easy access
	add_to_group("player")

	if camera:
		original_camera_position = camera.position
		camera.fov = hipfire_fov

	# Cache bone indices
	if skeleton:
		head_bone_idx = skeleton.find_bone(head_bone_name)
		spine_bone_idx = skeleton.find_bone(spine_bone_name)

		# Reset skeleton to rest pose to ensure bones start at correct positions
		skeleton.reset_bone_poses()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Always update camera rotation
		camera_y_rotation -= event.relative.x * mouse_sensitivity
		camera_x_rotation -= event.relative.y * mouse_sensitivity

		# Clamp pitch
		camera_x_rotation = clamp(camera_x_rotation,
			deg_to_rad(-max_look_up),
			deg_to_rad(max_look_down))

		# Wrap yaw
		camera_y_rotation = wrapf(camera_y_rotation, -PI, PI)

	# Toggle mouse
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

	# Ragdoll controls
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_G:
			_toggle_ragdoll()
		elif event.keycode == KEY_H:
			_test_ragdoll_impulse()

	# Weapon switching
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_switch_weapon(0)
		elif event.keycode == KEY_2:
			_switch_weapon(1)
		elif event.keycode == KEY_3:
			_switch_weapon(2)

func _physics_process(delta):
	# Skip normal physics if ragdolled
	if ragdoll and ragdoll.is_ragdoll_active:
		return

	# Update states
	is_sprinting = Input.is_action_pressed("sprint") and not is_aiming
	is_aiming = Input.is_action_pressed("aim_down_sights")
	is_freelooking = Input.is_action_pressed("freelook")  # Alt key

	# Stance switching
	if Input.is_action_just_pressed("crouch"):
		_cycle_stance()

	# Interaction
	if Input.is_action_just_pressed("interact"):
		_try_interact()

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor() and stance != Stance.PRONE:
		velocity.y = jump_velocity

	# Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed = _get_movement_speed()

	# Calculate movement direction relative to body (not camera in freelook)
	var movement_basis = Transform3D.IDENTITY.rotated(Vector3.UP, body_y_rotation)
	var direction = (movement_basis.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Use acceleration instead of instant velocity for smooth movement
	var acceleration = 80.0  # Fast acceleration
	var deceleration = 100.0  # Very strong deceleration for instant stopping

	if direction and is_on_floor():
		# Accelerate towards target speed
		var target_velocity = direction * speed
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		# Decelerate to stop
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

	# Snap very small velocities to zero to prevent micro-sliding
	var velocity_threshold = 0.01
	if abs(velocity.x) < velocity_threshold:
		velocity.x = 0
	if abs(velocity.z) < velocity_threshold:
		velocity.z = 0

	move_and_slide()

	# Update systems
	_update_body_rotation(delta)
	_update_camera_and_head(delta)
	_update_ads(delta)
	_update_weapon_ik(delta)
	_update_procedural_effects(delta)
	_check_interactions()

func _get_movement_speed() -> float:
	# Reduce speed significantly when aiming
	if is_aiming:
		return crouch_speed * 0.8  # Slow walk when aiming

	match stance:
		Stance.STANDING:
			return sprint_speed if is_sprinting else walk_speed
		Stance.CROUCHING:
			return crouch_speed
		Stance.PRONE:
			return prone_speed
	return walk_speed

func _cycle_stance():
	var old_stance = stance
	match stance:
		Stance.STANDING:
			stance = Stance.CROUCHING
		Stance.CROUCHING:
			stance = Stance.PRONE
		Stance.PRONE:
			stance = Stance.STANDING
	stance_changed.emit(old_stance, stance)

func _update_body_rotation(delta):
	if is_freelooking:
		# In freelook: camera rotates independently, body stays put
		# Calculate offset between camera and body
		freelook_offset = wrapf(camera_y_rotation - body_y_rotation, -PI, PI)

		# If offset gets too large, body follows
		var max_freelook_rad = deg_to_rad(freelook_max_angle)
		if abs(freelook_offset) > max_freelook_rad:
			body_y_rotation = camera_y_rotation - sign(freelook_offset) * max_freelook_rad
			freelook_offset = sign(freelook_offset) * max_freelook_rad
	else:
		# Normal mode: body follows camera immediately
		body_y_rotation = lerp_angle(body_y_rotation, camera_y_rotation, body_rotation_speed * delta)
		freelook_offset = camera_y_rotation - body_y_rotation

	# Apply body rotation
	rotation.y = body_y_rotation

func _update_camera_and_head(_delta):
	if not camera or not skeleton or head_bone_idx < 0:
		return

	# Apply pitch to head bone
	var head_rotation = Vector3(camera_x_rotation, freelook_offset, 0)
	skeleton.set_bone_pose_rotation(head_bone_idx, Quaternion.from_euler(head_rotation))

	# Apply partial rotation to spine for more natural look
	if spine_bone_idx >= 0:
		var spine_pitch = camera_x_rotation * 0.3
		var spine_yaw = freelook_offset * 0.5
		skeleton.set_bone_pose_rotation(spine_bone_idx,
			Quaternion.from_euler(Vector3(spine_pitch, spine_yaw, 0)))

	# Update camera position (attached to head bone in scene tree, but we can offset)
	# Camera is child of head bone attachment in the scene

func _update_ads(delta):
	var target_ads = 1.0 if is_aiming else 0.0
	ads_blend = lerp(ads_blend, target_ads, ads_transition_speed * delta)

	if camera:
		camera.fov = lerp(hipfire_fov, ads_fov, ads_blend)

	if not current_weapon or not camera:
		return

	# Simplified ADS camera positioning
	# Move camera slightly forward when aiming to bring eye closer to sight
	var ads_offset = Vector3(0, -0.05, 0.05)  # Slight down and forward
	var target_cam_pos = original_camera_position.lerp(original_camera_position + ads_offset, ads_blend)
	camera.position = camera.position.lerp(target_cam_pos, 10.0 * delta)

func _update_weapon_ik(_delta):
	if not current_weapon or not skeleton:
		return

	# Update IK targets
	if right_hand_ik:
		var grip = current_weapon.get_grip_point()
		if grip:
			right_hand_ik.target_node = grip.get_path()
			right_hand_ik.start()

	if left_hand_ik:
		var support = current_weapon.get_support_point()
		if support:
			left_hand_ik.target_node = support.get_path()
			left_hand_ik.start()

func _update_procedural_effects(delta):
	breathing_time += delta

	# Add subtle breathing and bob
	# This would be applied to the camera or weapon in a more complete system
	# For now, handled by weapon controller

func _try_interact():
	if not interaction_ray or not interaction_ray.is_colliding():
		return

	var collider = interaction_ray.get_collider()
	if collider is WeaponPickup:
		_pickup_weapon(collider)

func _pickup_weapon(pickup: WeaponPickup):
	# Create weapon instance
	var weapon = pickup.weapon_scene.instantiate() as Weapon

	# Drop current weapon if holding one
	if current_weapon:
		_drop_weapon()

	# Attach weapon to right hand
	if skeleton and weapon:
		var hand_attachment = _get_hand_attachment()
		if hand_attachment:
			hand_attachment.add_child(weapon)
			current_weapon = weapon

			# Store source scene for dropping later
			weapon.source_scene = pickup.weapon_scene

			# Setup IK
			_update_weapon_ik(0)

			# Remove pickup from world
			pickup.queue_free()

			# Emit signal
			weapon_changed.emit(weapon)

			print("Picked up: ", weapon.weapon_name)

func _drop_weapon():
	if not current_weapon:
		return

	# Only drop if we have the source scene
	if not current_weapon.source_scene:
		print("Warning: Cannot drop weapon without source_scene")
		current_weapon.queue_free()
		current_weapon = null
		return

	# Create pickup in world
	var pickup_scene = preload("res://scenes/weapon_pickup.tscn")
	var pickup = pickup_scene.instantiate() as WeaponPickup
	pickup.weapon_scene = current_weapon.source_scene
	pickup.weapon_name = current_weapon.weapon_name
	pickup.global_position = global_position + global_transform.basis.z * -1.0
	get_tree().root.add_child(pickup)

	# Remove weapon
	current_weapon.queue_free()
	current_weapon = null

func _switch_weapon(index: int):
	if index < holstered_weapons.size():
		# Switch logic here
		pass

func _get_hand_attachment() -> Node3D:
	# Get the BoneAttachment3D for the right hand
	# This should be set up in the scene
	return get_node_or_null("Skeleton3D/RightHandAttachment")

func _toggle_ragdoll():
	"""Toggle ragdoll physics on/off (G key)"""
	if not ragdoll:
		print("No ragdoll controller found!")
		return

	if ragdoll.is_ragdoll_active:
		ragdoll.disable_ragdoll()
		print("Ragdoll disabled - controls restored")
	else:
		ragdoll.enable_ragdoll()
		print("Ragdoll enabled - press G to recover")

func _test_ragdoll_impulse():
	"""Test ragdoll with impulse force (H key)"""
	if not ragdoll:
		return

	# Enable ragdoll with forward impulse
	var impulse = -global_transform.basis.z * 500.0  # Forward direction
	ragdoll.enable_ragdoll(impulse)
	print("Ragdoll enabled with impulse!")

func _check_interactions():
	"""Check for nearby interactable objects and emit prompts"""
	if not interaction_ray:
		return

	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider is WeaponPickup:
			interaction_available.emit("[E] Pick up %s" % collider.weapon_name)
		else:
			interaction_unavailable.emit()
	else:
		interaction_unavailable.emit()

func _process(_delta):
	# Skip camera control if ragdolled
	if ragdoll and ragdoll.is_ragdoll_active:
		return

	# Debug
	if Input.is_action_just_pressed("ui_accept"):
		print("=== FPP Debug ===")
		print("Freelook: ", is_freelooking)
		print("Camera Yaw: ", rad_to_deg(camera_y_rotation))
		print("Body Yaw: ", rad_to_deg(body_y_rotation))
		print("Freelook Offset: ", rad_to_deg(freelook_offset))
		print("ADS Blend: ", ads_blend)
		print("Stance: ", stance)
		if current_weapon:
			print("Weapon: ", current_weapon.weapon_name)
		if ragdoll:
			print("Ragdoll: ", "ACTIVE" if ragdoll.is_ragdoll_active else "INACTIVE")
