extends CharacterBody3D
class_name CharacterControllerMain

## Main Character Controller - Orchestrates all components
## Inspired by ARMA 3's modularity, GTA's smoothness, Outer Wilds' elegance
## Follows Godot 4.5 best practices with component-based architecture

# ===== SIGNALS - Event-driven communication (like Outer Wilds) =====
signal weapon_changed(weapon: Weapon)
signal stance_changed(old_stance: int, new_stance: int)
signal interaction_available(interactable: Node)
signal interaction_unavailable()
signal damage_taken(amount: float, limb: StringName)

# ===== CONFIGURATION RESOURCES =====
@export var config: CharacterConfig
@export var bone_config: BoneConfig

# ===== COMPONENTS - Clean separation of concerns =====
@onready var input_controller: InputControllerComponent = $InputController
@onready var camera_controller: CameraControllerComponent = $CameraController
@onready var movement_controller: MovementControllerComponent = $MovementController
@onready var ragdoll_controller: RagdollController = $RagdollController
@onready var weapon_controller: WeaponControllerComponent = $WeaponController
@onready var ik_locomotion: IKLocomotion = $IKLocomotion
@onready var ik_debug_controller: IKDebugControllerComponent = $IKDebugController

# ===== SCENE REFERENCES - Using unique names (%) for reliability =====
@onready var skeleton: Skeleton3D = get_node_or_null("CharacterModel/RootNode/Skeleton3D")
@onready var fps_camera: Camera3D = get_node_or_null("CharacterModel/RootNode/Skeleton3D/HeadAttachment/FPSCamera")
@onready var third_person_camera: Camera3D = get_node_or_null("ThirdPersonCamera")
@onready var interaction_ray: RayCast3D = get_node_or_null("CharacterModel/RootNode/Skeleton3D/HeadAttachment/FPSCamera/InteractionRay")
@onready var animation_player: AnimationPlayer = get_node_or_null("CharacterModel/AnimationPlayer")
@onready var right_hand_ik: SkeletonIK3D = get_node_or_null("CharacterModel/RootNode/Skeleton3D/RightHandIK")
@onready var left_hand_ik: SkeletonIK3D = get_node_or_null("CharacterModel/RootNode/Skeleton3D/LeftHandIK")
@onready var right_hand_attachment: Node3D = get_node_or_null("CharacterModel/RootNode/Skeleton3D/RightHandAttachment")

# ===== STATE =====
var current_weapon: Weapon
var ik_mode_enabled: bool = false

func _ready() -> void:
	_validate_setup()
	_connect_signals()
	_initialize_components()

## Validate all required components are present
func _validate_setup() -> void:
	if not config:
		push_error("CharacterController: CharacterConfig resource not assigned!")

	if not bone_config:
		push_error("CharacterController: BoneConfig resource not assigned!")

	# Check components exist
	assert(camera_controller != null, "CameraController component missing!")
	assert(movement_controller != null, "MovementController component missing!")
	assert(ragdoll_controller != null, "RagdollController component missing!")

## Connect component signals for proper orchestration
func _connect_signals() -> void:
	# Input controller signals (centralized input handling)
	if input_controller:
		input_controller.interact_requested.connect(_on_interact_requested)
		input_controller.ik_mode_toggle_requested.connect(_on_ik_mode_toggle)
		input_controller.ik_debug_toggle_requested.connect(_on_ik_debug_toggle)
		input_controller.weapon_switch_requested.connect(_on_weapon_switch_requested)
		input_controller.ragdoll_toggle_requested.connect(_on_ragdoll_toggle)
		input_controller.ragdoll_impulse_requested.connect(_on_ragdoll_impulse)
		input_controller.partial_ragdoll_requested.connect(_on_partial_ragdoll)
		input_controller.fire_started.connect(_on_fire_started)
		input_controller.reload_requested.connect(_on_reload_requested)

	# Movement signals
	if movement_controller:
		movement_controller.stance_changed.connect(_on_stance_changed)
		movement_controller.jumped.connect(_on_jumped)
		movement_controller.prone_state_changed.connect(_on_prone_state_changed)

	# Camera signals
	if camera_controller:
		camera_controller.freelook_changed.connect(_on_freelook_changed)
		camera_controller.camera_mode_changed.connect(_on_camera_mode_changed)

	# Ragdoll signals
	if ragdoll_controller:
		ragdoll_controller.ragdoll_enabled.connect(_on_ragdoll_enabled)
		ragdoll_controller.ragdoll_disabled.connect(_on_ragdoll_disabled)

## Initialize components with shared data
func _initialize_components() -> void:
	# Pass config to components
	if camera_controller:
		camera_controller.config = config
		camera_controller.bone_config = bone_config

	if movement_controller:
		movement_controller.config = config

	if ragdoll_controller:
		ragdoll_controller.bone_config = bone_config

	if weapon_controller:
		weapon_controller.config = config
		weapon_controller.bone_config = bone_config
		# Initialize with scene references
		weapon_controller.initialize(skeleton, right_hand_ik, left_hand_ik, right_hand_attachment, fps_camera)
		# Connect signals
		weapon_controller.weapon_changed.connect(_on_weapon_changed)

	if ik_locomotion:
		ik_locomotion.skeleton = skeleton
		ik_locomotion.character_body = self

	if ik_debug_controller:
		ik_debug_controller.ik_locomotion = ik_locomotion

	# Start idle animation
	if animation_player and animation_player.has_animation("www_characters3d_com | Idle"):
		animation_player.play("www_characters3d_com | Idle")

func _process(delta: float) -> void:
	# Update camera ADS (FOV only)
	if camera_controller and movement_controller:
		camera_controller.update_ads(delta, movement_controller.get_is_aiming())

	# Update weapon ADS (weapon positioning)
	if weapon_controller and movement_controller:
		weapon_controller.update_ads(delta, movement_controller.get_is_aiming())

	# Update IK locomotion
	if ik_locomotion and ik_locomotion.ik_mode_enabled and movement_controller:
		var move_velocity := movement_controller.get_velocity()
		var is_moving := movement_controller.is_moving()
		var stance := movement_controller.get_stance()
		ik_locomotion.update_locomotion(delta, move_velocity, is_moving, stance)

	# Check for interactions
	_check_interactions()

## ===== INTERACTION SYSTEM (like GTA's prompt system) =====

func _check_interactions() -> void:
	if not interaction_ray or not interaction_ray.is_colliding():
		interaction_unavailable.emit()
		return

	var collider := interaction_ray.get_collider()
	if collider and collider.is_in_group("interactable"):
		interaction_available.emit(collider)
	else:
		interaction_unavailable.emit()

func _try_interact() -> void:
	if not interaction_ray or not interaction_ray.is_colliding():
		return

	var collider := interaction_ray.get_collider()

	# Handle weapon pickups
	if collider is WeaponPickup:
		_pickup_weapon(collider)

func _pickup_weapon(pickup: WeaponPickup) -> void:
	if weapon_controller:
		weapon_controller.pickup_weapon(pickup)
	else:
		print("WeaponController not available")

## ===== IK MODE TOGGLE =====

func _toggle_ik_mode() -> void:
	if not ik_locomotion:
		return

	ik_mode_enabled = not ik_mode_enabled

	if ik_mode_enabled:
		ik_locomotion.enable_ik_mode()
		if animation_player:
			animation_player.pause()  # Pause animation, let IK take over
	else:
		ik_locomotion.disable_ik_mode()
		if animation_player:
			animation_player.play()  # Resume animation

	print("IK Mode: ", "ENABLED" if ik_mode_enabled else "DISABLED")

## ===== COMPONENT SIGNAL HANDLERS - Orchestration logic =====

func _on_stance_changed(old_stance: int, new_stance: int) -> void:
	stance_changed.emit(old_stance, new_stance)

	# Update IK locomotion stance
	if ik_locomotion and ik_locomotion.ik_mode_enabled:
		match new_stance:
			0:  # Standing
				ik_locomotion.set_stance_standing()
			1:  # Crouching
				ik_locomotion.set_stance_crouch()
			2:  # Prone
				ik_locomotion.set_stance_prone()

func _on_jumped() -> void:
	# Trigger jump animation in IK mode
	if ik_locomotion and ik_locomotion.ik_mode_enabled:
		ik_locomotion.start_jump()

## ===== INPUT CONTROLLER SIGNAL HANDLERS =====

func _on_interact_requested() -> void:
	_try_interact()

func _on_ik_mode_toggle() -> void:
	_toggle_ik_mode()

func _on_ik_debug_toggle() -> void:
	if ik_debug_controller:
		ik_debug_controller.toggle_debug_mode()

func _on_weapon_switch_requested(slot: int) -> void:
	if weapon_controller:
		weapon_controller.switch_to_slot(slot)

func _on_ragdoll_toggle() -> void:
	if ragdoll_controller:
		ragdoll_controller.toggle_ragdoll()

func _on_ragdoll_impulse() -> void:
	if ragdoll_controller:
		ragdoll_controller.apply_impulse(Vector3.UP * 500.0)

func _on_partial_ragdoll(limb: StringName) -> void:
	if ragdoll_controller:
		ragdoll_controller.toggle_partial_ragdoll(limb)

func _on_fire_started() -> void:
	if weapon_controller:
		weapon_controller.fire_weapon()

func _on_reload_requested() -> void:
	if weapon_controller:
		weapon_controller.reload_weapon()

func _on_freelook_changed(_is_freelooking: bool) -> void:
	# Could trigger head turn animations or effects
	pass

func _on_camera_mode_changed(_is_third_person: bool) -> void:
	# Adjust HUD or other systems based on camera mode
	pass

func _on_ragdoll_enabled() -> void:
	# Disable other systems during ragdoll
	if movement_controller:
		movement_controller.process_mode = Node.PROCESS_MODE_DISABLED

	if ik_locomotion and ik_locomotion.ik_mode_enabled:
		ik_locomotion.disable_ik_mode()

func _on_ragdoll_disabled() -> void:
	# Re-enable systems after ragdoll
	if movement_controller:
		movement_controller.process_mode = Node.PROCESS_MODE_INHERIT

	# MGSV-style: Play procedural get-up animation from ragdoll
	if ik_locomotion and ik_mode_enabled:
		ik_locomotion.play_get_up_animation()
		print("Character: Getting up from ragdoll")

func _on_prone_state_changed(is_supine: bool) -> void:
	# Update IK for prone-back (supine) vs prone-stomach transitions
	if is_supine:
		print("Character: Prone state -> SUPINE (on back)")
	else:
		print("Character: Prone state -> STOMACH")
	# IK system will handle the transition automatically based on stance

func _on_weapon_changed(new_weapon: Weapon, _old_weapon: Weapon) -> void:
	# Update current weapon reference
	current_weapon = new_weapon
	weapon_changed.emit(new_weapon)
	print("Character: Weapon changed to ", new_weapon.weapon_name if new_weapon else "None")

## ===== PUBLIC API - For external systems =====

## Apply damage to character (triggers IK reactions)
func apply_damage(amount: float, hit_position: Vector3) -> void:
	# Determine which limb was hit
	var limb := _determine_hit_limb(hit_position)

	# Emit signal
	damage_taken.emit(amount, limb)

	# Trigger IK reaction if in IK mode
	if ik_locomotion and ik_locomotion.ik_mode_enabled:
		ik_locomotion.apply_damage_reaction(limb, amount / 100.0)

	print("Damage taken: %.1f to %s" % [amount, limb])

func _determine_hit_limb(hit_position: Vector3) -> StringName:
	# Simple limb detection based on hit position
	# TODO: Improve with proper bone collision detection

	var local_hit := to_local(hit_position)

	if local_hit.y > 1.5:
		return &"head"
	elif local_hit.y > 0.5:
		if local_hit.x < -0.2:
			return &"left_arm"
		elif local_hit.x > 0.2:
			return &"right_arm"
		else:
			return &"torso"
	else:
		if local_hit.x < 0:
			return &"left_leg"
		else:
			return &"right_leg"

## Get current movement state
func get_movement_state() -> Dictionary:
	if not movement_controller:
		return {}

	return {
		"velocity": movement_controller.get_velocity(),
		"is_moving": movement_controller.is_moving(),
		"is_sprinting": movement_controller.get_is_sprinting(),
		"is_aiming": movement_controller.get_is_aiming(),
		"stance": movement_controller.get_stance()
	}

## Get current camera state
func get_camera_state() -> Dictionary:
	if not camera_controller:
		return {}

	return {
		"rotation": camera_controller.get_camera_rotation(),
		"body_rotation": camera_controller.get_body_rotation(),
		"freelook_offset": camera_controller.get_freelook_offset(),
		"is_freelooking": camera_controller.is_freelooking,
		"is_third_person": camera_controller.is_third_person
	}
