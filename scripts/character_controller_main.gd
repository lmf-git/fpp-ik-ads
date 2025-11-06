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
@onready var camera_controller: CameraControllerComponent = $CameraController
@onready var movement_controller: MovementControllerComponent = $MovementController
@onready var ragdoll_controller: RagdollControllerRefactored = $RagdollController
@onready var ik_locomotion: IKLocomotion = $IKLocomotion

# ===== SCENE REFERENCES - Using unique names (%) for reliability =====
@onready var skeleton: Skeleton3D = %Skeleton3D
@onready var fps_camera: Camera3D = %FPSCamera
@onready var third_person_camera: Camera3D = %ThirdPersonCamera
@onready var interaction_ray: RayCast3D = %InteractionRay
@onready var animation_player: AnimationPlayer = %AnimationPlayer
@onready var right_hand_ik: SkeletonIK3D = %RightHandIK
@onready var left_hand_ik: SkeletonIK3D = %LeftHandIK

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
	# Movement signals
	if movement_controller:
		movement_controller.stance_changed.connect(_on_stance_changed)
		movement_controller.jumped.connect(_on_jumped)

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

	if ik_locomotion:
		ik_locomotion.skeleton = skeleton
		ik_locomotion.character_body = self

	# Start idle animation
	if animation_player and animation_player.has_animation("www_characters3d_com | Idle"):
		animation_player.play("www_characters3d_com | Idle")

func _input(event: InputEvent) -> void:
	# Centralized input handling
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("toggle_ik_mode"):
		_toggle_ik_mode()

func _process(delta: float) -> void:
	# Update ADS based on movement state
	if camera_controller and movement_controller:
		camera_controller.update_ads(delta, movement_controller.get_is_aiming())

	# Update IK locomotion
	if ik_locomotion and ik_locomotion.ik_mode_enabled and movement_controller:
		var velocity := movement_controller.get_velocity()
		var is_moving := movement_controller.is_moving()
		var stance := movement_controller.get_stance()
		ik_locomotion.update_locomotion(delta, velocity, is_moving, stance)

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
	# TODO: Implement weapon swap using state machine
	print("Picking up weapon: ", pickup.weapon_name)
	weapon_changed.emit(null)  # Placeholder

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

func _on_freelook_changed(is_freelooking: bool) -> void:
	# Could trigger head turn animations or effects
	pass

func _on_camera_mode_changed(is_third_person: bool) -> void:
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
