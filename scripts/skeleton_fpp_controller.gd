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
@export var body_rotation_speed: float = 3.0  # How fast body catches up when not in freelook

@export_group("Neck Limits (Freelook)")
@export var neck_max_pitch_up: float = 60.0  # Max head tilt up (degrees)
@export var neck_max_pitch_down: float = 50.0  # Max head tilt down (degrees)
@export var neck_max_yaw: float = 80.0  # Max head turn left/right (degrees)

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
@export var third_person_camera: Camera3D
@export var interaction_ray: RayCast3D
@export var ragdoll: RagdollController
@export var animation_player: AnimationPlayer

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
var is_third_person: bool = false

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

# Weapon swap system
enum WeaponSwapPhase { NONE, LOWERING, SWITCHING, RAISING }
var weapon_swap_phase: WeaponSwapPhase = WeaponSwapPhase.NONE
var weapon_swap_progress: float = 0.0
var weapon_swap_speed: float = 3.0  # How fast weapon lowers/raises
var pending_weapon_pickup: WeaponPickup = null
var weapon_swap_offset: Vector3 = Vector3.ZERO  # Current procedural offset
var weapon_swap_rotation: Vector3 = Vector3.ZERO  # Current procedural rotation

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

		print("Skeleton found: ", skeleton.name)
		print("Total bones: ", skeleton.get_bone_count())
		print("Head bone index: ", head_bone_idx, " (", head_bone_name, ")")
		print("Spine bone index: ", spine_bone_idx, " (", spine_bone_name, ")")

		# Check if mesh is present
		for child in skeleton.get_children():
			print("Skeleton child: ", child.name, " - Type: ", child.get_class())

		# Reset skeleton to rest pose to ensure bones start at correct positions
		skeleton.reset_bone_poses()

	# Start idle animation if available
	if animation_player:
		if animation_player.has_animation("www_characters3d_com | Idle"):
			animation_player.play("www_characters3d_com | Idle")
			print("Playing Idle animation")
		else:
			print("No Idle animation found in AnimationPlayer")
			print("Available animations:", animation_player.get_animation_list())

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

	# Camera toggle
	if event is InputEventKey and event.pressed and event.keycode == KEY_O:
		_toggle_third_person_camera()

	# Ragdoll controls
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_G:
			_toggle_ragdoll()
		elif event.keycode == KEY_H:
			_test_ragdoll_impulse()
		# Partial ragdoll controls
		elif event.keycode == KEY_J:
			_toggle_partial_ragdoll("left_arm")
		elif event.keycode == KEY_K:
			_toggle_partial_ragdoll("right_arm")
		elif event.keycode == KEY_Y:
			_toggle_both_arms_ragdoll()
		elif event.keycode == KEY_U:
			_toggle_partial_ragdoll("left_leg")

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

	# Update states (block during weapon swap)
	var is_swapping = weapon_swap_phase != WeaponSwapPhase.NONE
	is_sprinting = Input.is_action_pressed("sprint") and not is_aiming and not is_swapping
	is_aiming = Input.is_action_pressed("aim_down_sights") and not is_swapping
	is_freelooking = Input.is_action_pressed("freelook")  # Alt key

	# Stance switching
	if Input.is_action_just_pressed("crouch"):
		_cycle_stance()

	# Interaction (allow pickup even during swap, but swap system will block it)
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

	# FPS-style movement: instant velocity changes when on floor
	if direction and is_on_floor():
		# Set velocity directly for instant responsive movement
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	elif is_on_floor():
		# Apply strong friction when on ground with no input
		var friction = 25.0
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		velocity.z = move_toward(velocity.z, 0, friction * delta)
	else:
		# Air control - apply slight deceleration
		var air_friction = 2.0
		velocity.x = move_toward(velocity.x, 0, air_friction * delta)
		velocity.z = move_toward(velocity.z, 0, air_friction * delta)

	# Snap very small velocities to zero to prevent micro-sliding
	if is_on_floor():
		var velocity_threshold = 0.1
		if abs(velocity.x) < velocity_threshold:
			velocity.x = 0
		if abs(velocity.z) < velocity_threshold:
			velocity.z = 0

	move_and_slide()

	# Update camera mode based on ragdoll state
	_update_camera_mode()

	# Update systems
	_update_body_rotation(delta)
	_update_camera_and_head(delta)
	_update_ads(delta)
	_update_weapon_swap(delta)  # NEW: Procedural weapon swap
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
		# In freelook: camera rotates independently, head follows within neck limits
		# Calculate offset between camera and body (always wrap for proper angle handling)
		freelook_offset = wrapf(camera_y_rotation - body_y_rotation, -PI, PI)

		# Body starts turning when camera exceeds neck limit (so head stays within natural range)
		var max_neck_yaw_rad = deg_to_rad(neck_max_yaw)
		if abs(freelook_offset) > max_neck_yaw_rad:
			# Body follows to keep head within neck limits
			body_y_rotation = camera_y_rotation - sign(freelook_offset) * max_neck_yaw_rad
			freelook_offset = sign(freelook_offset) * max_neck_yaw_rad
	else:
		# Normal mode: body follows camera smoothly
		body_y_rotation = lerp_angle(body_y_rotation, camera_y_rotation, body_rotation_speed * delta)
		# Always wrap the offset to prevent camera inversion
		freelook_offset = wrapf(camera_y_rotation - body_y_rotation, -PI, PI)

	# Apply body rotation
	rotation.y = body_y_rotation

func _update_camera_and_head(_delta):
	if not camera or not skeleton or head_bone_idx < 0:
		return

	# Head always compensates for difference between camera and body rotation
	# This ensures camera (attached to head) looks where mouse is pointing
	# Negate pitch because character.gltf head bone is oriented differently
	var head_pitch = -camera_x_rotation
	var head_yaw = freelook_offset  # Always use offset, not just during freelook

	# Apply realistic neck limits to prevent unnatural head rotation
	# Limit head pitch (up/down)
	var max_pitch_up_rad = deg_to_rad(neck_max_pitch_up)  # Positive now because we negated
	var max_pitch_down_rad = deg_to_rad(-neck_max_pitch_down)  # Negative now
	head_pitch = clamp(head_pitch, max_pitch_down_rad, max_pitch_up_rad)

	# Limit head yaw (left/right) - this controls how far head can turn
	var max_yaw_rad = deg_to_rad(neck_max_yaw)
	head_yaw = clamp(head_yaw, -max_yaw_rad, max_yaw_rad)

	# Always apply head rotation to make camera look where it should
	# Apply pitch and yaw to head bone
	var head_rotation = Vector3(head_pitch, head_yaw, 0)
	skeleton.set_bone_pose_rotation(head_bone_idx, Quaternion.from_euler(head_rotation))

	# Apply partial rotation to spine for more natural look
	if spine_bone_idx >= 0:
		var spine_pitch = head_pitch * 0.3
		var spine_yaw = head_yaw * 0.5
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

	# ADS: Position weapon so its ADSTarget aligns with camera center
	if ads_blend > 0.01:
		var ads_target_node = current_weapon.get_ads_target()
		if ads_target_node:
			# Calculate where the weapon should be to align sight with camera
			var camera_global_pos = camera.global_position

			# Get the weapon's current position
			var weapon_root = current_weapon.get_parent()  # RightHandAttachment
			if weapon_root:
				# Calculate offset from weapon root to ADS target
				var ads_offset_local = current_weapon.transform * ads_target_node.transform

				# Position weapon so ADS target is at camera position
				var target_weapon_pos = camera_global_pos - (weapon_root.global_transform.basis * ads_offset_local.origin)

				# Blend weapon position for smooth ADS
				var current_pos = weapon_root.global_position
				weapon_root.global_position = current_pos.lerp(target_weapon_pos, ads_blend)

func _update_weapon_ik(_delta):
	if not current_weapon or not skeleton:
		return

	# Position IK targets at weapon grip points
	if right_hand_ik:
		var grip = current_weapon.get_grip_point()
		if grip:
			# Get or create IK target for right hand
			var ik_target = _get_or_create_ik_target("RightHandTarget", right_hand_ik)
			if ik_target:
				# Position target at weapon grip point
				ik_target.global_transform = grip.global_transform

				# Make sure IK is using this target
				if right_hand_ik.target_node != ik_target.get_path():
					right_hand_ik.target_node = ik_target.get_path()
					right_hand_ik.start()

	if left_hand_ik:
		var support = current_weapon.get_support_point()
		if support:
			# Get or create IK target for left hand
			var ik_target = _get_or_create_ik_target("LeftHandTarget", left_hand_ik)
			if ik_target:
				# Position target at weapon support point
				ik_target.global_transform = support.global_transform

				# Make sure IK is using this target
				if left_hand_ik.target_node != ik_target.get_path():
					left_hand_ik.target_node = ik_target.get_path()
					left_hand_ik.start()

func _get_or_create_ik_target(target_name: String, _ik_node: SkeletonIK3D) -> Node3D:
	"""Get existing IK target or create a new one"""
	if not skeleton:
		return null

	# Try to find existing target
	var existing_target = skeleton.get_node_or_null(target_name)
	if existing_target:
		return existing_target

	# Create new target marker
	var target = Node3D.new()
	target.name = target_name
	skeleton.add_child(target)
	return target

func _update_weapon_swap(delta):
	"""Handle procedural weapon swap animation"""
	if weapon_swap_phase == WeaponSwapPhase.NONE:
		# No swap happening, reset offsets
		weapon_swap_offset = weapon_swap_offset.lerp(Vector3.ZERO, 10.0 * delta)
		weapon_swap_rotation = weapon_swap_rotation.lerp(Vector3.ZERO, 10.0 * delta)
		return

	# Update swap progress
	weapon_swap_progress += delta * weapon_swap_speed

	match weapon_swap_phase:
		WeaponSwapPhase.LOWERING:
			# Lower current weapon down and to the side
			var target_offset = Vector3(0.3, -0.5, -0.2)  # Right, down, back
			var target_rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), deg_to_rad(-20))

			weapon_swap_offset = weapon_swap_offset.lerp(target_offset, 8.0 * delta)
			weapon_swap_rotation = weapon_swap_rotation.lerp(target_rotation, 8.0 * delta)

			# When fully lowered, switch to next phase
			if weapon_swap_progress >= 1.0:
				weapon_swap_phase = WeaponSwapPhase.SWITCHING
				weapon_swap_progress = 0.0
				_perform_weapon_switch()

		WeaponSwapPhase.SWITCHING:
			# Weapon is out of view, perform actual switch
			# Short pause at bottom
			if weapon_swap_progress >= 0.3:
				weapon_swap_phase = WeaponSwapPhase.RAISING
				weapon_swap_progress = 0.0

		WeaponSwapPhase.RAISING:
			# Raise new weapon into view from bottom
			var start_offset = Vector3(-0.3, -0.5, -0.2)  # Start from left side
			var start_rotation = Vector3(deg_to_rad(-45), deg_to_rad(-30), deg_to_rad(20))

			weapon_swap_offset = start_offset.lerp(Vector3.ZERO, weapon_swap_progress)
			weapon_swap_rotation = start_rotation.lerp(Vector3.ZERO, weapon_swap_progress)

			# When fully raised, complete swap
			if weapon_swap_progress >= 1.0:
				weapon_swap_phase = WeaponSwapPhase.NONE
				weapon_swap_progress = 0.0
				weapon_swap_offset = Vector3.ZERO
				weapon_swap_rotation = Vector3.ZERO

	# Apply procedural offset to weapon
	_apply_weapon_swap_offset()

func _apply_weapon_swap_offset():
	"""Apply procedural offset to weapon during swap"""
	if not current_weapon:
		return

	var weapon_root = current_weapon.get_parent()  # RightHandAttachment
	if weapon_root:
		# Apply position offset
		current_weapon.position = weapon_swap_offset

		# Apply rotation offset
		current_weapon.rotation = weapon_swap_rotation

func _update_procedural_effects(delta):
	breathing_time += delta

	# Add subtle breathing and bob
	# This would be applied to the camera or weapon in a more complete system
	# For now, handled by weapon controller

func _try_interact():
	print("Trying to interact...")
	if not interaction_ray:
		print("  No interaction_ray!")
		return

	print("  Ray enabled: ", interaction_ray.enabled)
	print("  Ray colliding: ", interaction_ray.is_colliding())

	if not interaction_ray.is_colliding():
		print("  Ray not hitting anything")
		return

	var collider = interaction_ray.get_collider()
	print("  Ray hit: ", collider.name, " (", collider.get_class(), ")")

	if collider is WeaponPickup:
		print("  It's a WeaponPickup! Picking up...")
		_pickup_weapon(collider)
	else:
		print("  Not a WeaponPickup")

func _pickup_weapon(pickup: WeaponPickup):
	"""Start procedural weapon swap animation"""
	# Don't allow pickup during active swap
	if weapon_swap_phase != WeaponSwapPhase.NONE:
		return

	# Store pending pickup for later
	pending_weapon_pickup = pickup

	# Start weapon swap animation
	if current_weapon:
		# Have a weapon, start lowering animation
		weapon_swap_phase = WeaponSwapPhase.LOWERING
		weapon_swap_progress = 0.0
		print("Starting weapon swap: ", current_weapon.weapon_name, " → ", pickup.weapon_name)
	else:
		# No weapon, skip lowering and go straight to raising
		weapon_swap_phase = WeaponSwapPhase.RAISING
		weapon_swap_progress = 0.0
		_perform_weapon_switch()

func _perform_weapon_switch():
	"""Perform actual weapon switch (called during SWITCHING phase)"""
	if not pending_weapon_pickup:
		return

	var pickup = pending_weapon_pickup
	pending_weapon_pickup = null

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

			print("Switched to: ", weapon.weapon_name)

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
	if is_inside_tree():
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

	# Enable ragdoll with gentle forward impulse
	var impulse = -global_transform.basis.z * 5.0  # Gentle push forward
	ragdoll.enable_ragdoll(impulse)
	print("Ragdoll enabled with gentle impulse!")

func _toggle_partial_ragdoll(limb: String):
	"""Toggle partial ragdoll for a specific limb"""
	if not ragdoll:
		print("No ragdoll controller found!")
		return

	ragdoll.toggle_partial_ragdoll(limb)
	print("Toggled partial ragdoll for ", limb)

func _toggle_both_arms_ragdoll():
	"""Toggle ragdoll for both arms simultaneously"""
	if not ragdoll:
		return

	# If either arm is not ragdolled, enable both. Otherwise disable both.
	if not ragdoll.left_arm_ragdoll_active or not ragdoll.right_arm_ragdoll_active:
		ragdoll.enable_partial_ragdoll("left_arm")
		ragdoll.enable_partial_ragdoll("right_arm")
		print("Both arms ragdoll ENABLED")
	else:
		ragdoll.disable_partial_ragdoll("left_arm")
		ragdoll.disable_partial_ragdoll("right_arm")
		print("Both arms ragdoll DISABLED")

func _update_camera_mode():
	"""Switch between first-person and third-person camera"""
	if not camera or not third_person_camera:
		return

	# Switch to third-person when enabled OR when ragdoll is active
	var should_be_third_person = is_third_person or (ragdoll and ragdoll.is_ragdoll_active)

	if should_be_third_person:
		if camera.current:
			camera.current = false
			third_person_camera.current = true
		# Update third-person camera position every frame to follow character
		third_person_camera.global_position = global_position + Vector3(0, 3, 5)
		third_person_camera.look_at(global_position + Vector3(0, 1, 0), Vector3.UP)
	else:
		# Switch back to first-person
		if third_person_camera.current:
			third_person_camera.current = false
			camera.current = true

func _toggle_third_person_camera():
	"""Toggle between first-person and third-person camera views (O key)"""
	is_third_person = not is_third_person
	print("Third person camera: ", "ON" if is_third_person else "OFF")

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
		print("Freelook: ", is_freelooking, " (Hold Alt to enable)")
		print("Camera Yaw: ", "%.1f°" % rad_to_deg(camera_y_rotation))
		print("Body Yaw: ", "%.1f°" % rad_to_deg(body_y_rotation))
		print("Freelook Offset: ", "%.1f°" % rad_to_deg(freelook_offset), " (head yaw)")
		print("Head visible turn: ", "%.1f°" % clamp(rad_to_deg(freelook_offset), -neck_max_yaw, neck_max_yaw))
		print("ADS Blend: ", ads_blend)
		print("Stance: ", stance)
		if current_weapon:
			print("Weapon: ", current_weapon.weapon_name)
		if ragdoll:
			print("Ragdoll: ", "ACTIVE" if ragdoll.is_ragdoll_active else "INACTIVE")
			if ragdoll.is_any_partial_ragdoll_active():
				var parts = []
				if ragdoll.left_arm_ragdoll_active: parts.append("L_ARM")
				if ragdoll.right_arm_ragdoll_active: parts.append("R_ARM")
				if ragdoll.left_leg_ragdoll_active: parts.append("L_LEG")
				if ragdoll.right_leg_ragdoll_active: parts.append("R_LEG")
				if ragdoll.torso_ragdoll_active: parts.append("TORSO")
				if ragdoll.head_ragdoll_active: parts.append("HEAD")
				print("Partial Ragdoll: ", ", ".join(parts))
