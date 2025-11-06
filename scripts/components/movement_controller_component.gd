extends Node
class_name MovementControllerComponent

## Handles character physics movement
## Clean separation from camera and weapons

signal stance_changed(old_stance: int, new_stance: int)
signal jumped()

enum Stance { STANDING, CROUCHING, PRONE }

# Performance constants
const VELOCITY_SNAP_THRESHOLD: float = 0.1  # Snap velocities below this to zero
const STATIC_VELOCITY_THRESHOLD: float = 0.01  # Consider character static below this

@export var config: CharacterConfig

@onready var character_body: CharacterBody3D = get_parent()

# Cached reference to camera controller (avoid tree lookups every frame)
var camera_controller: CameraControllerComponent

# State
var current_stance: Stance = Stance.STANDING
var is_sprinting: bool = false
var is_aiming: bool = false
var velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	if not config:
		push_error("MovementController: CharacterConfig not assigned!")

	# Cache camera controller reference (called once instead of 60 times/second)
	camera_controller = get_parent().get_node_or_null("CameraController") as CameraControllerComponent
	if not camera_controller:
		push_error("MovementController: CameraController not found! Movement direction will not work correctly.")

func _physics_process(delta: float) -> void:
	# Early exit optimization: skip if character is static and no input
	var is_static := character_body.is_on_floor() and velocity.length_squared() < STATIC_VELOCITY_THRESHOLD
	if is_static and not _has_input():
		return  # Save CPU when character is completely still

	# Get input state
	is_sprinting = Input.is_action_pressed("sprint") and not is_aiming
	is_aiming = Input.is_action_pressed("aim_down_sights")

	# Handle stance switching
	if Input.is_action_just_pressed("crouch"):
		cycle_stance()

	# Apply gravity
	if not character_body.is_on_floor():
		velocity.y -= config.gravity * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and character_body.is_on_floor() and current_stance != Stance.PRONE:
		velocity.y = config.jump_velocity
		jumped.emit()

	# Get movement direction from input
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed := config.get_movement_speed(current_stance, is_sprinting, is_aiming)

	# Calculate movement direction relative to body rotation
	var body_rotation := get_parent_rotation()
	var movement_basis := Transform3D.IDENTITY.rotated(Vector3.UP, body_rotation)
	var direction := (movement_basis.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Apply movement
	if direction and character_body.is_on_floor():
		# FPS-style: instant velocity changes
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	elif character_body.is_on_floor():
		# Apply friction when not moving
		velocity.x = move_toward(velocity.x, 0, config.friction * delta)
		velocity.z = move_toward(velocity.z, 0, config.friction * delta)
	else:
		# Air friction
		velocity.x = move_toward(velocity.x, 0, config.air_friction * delta)
		velocity.z = move_toward(velocity.z, 0, config.air_friction * delta)

	# Snap small velocities to zero
	if character_body.is_on_floor():
		if abs(velocity.x) < VELOCITY_SNAP_THRESHOLD: velocity.x = 0.0
		if abs(velocity.z) < VELOCITY_SNAP_THRESHOLD: velocity.z = 0.0

	# Apply velocity to CharacterBody3D
	character_body.velocity = velocity
	character_body.move_and_slide()
	velocity = character_body.velocity

## Cycle through stances
func cycle_stance() -> void:
	var old_stance := current_stance

	match current_stance:
		Stance.STANDING:
			current_stance = Stance.CROUCHING
		Stance.CROUCHING:
			current_stance = Stance.PRONE
		Stance.PRONE:
			current_stance = Stance.STANDING

	stance_changed.emit(old_stance, current_stance)

## Get velocity for external systems (IK, effects, etc.)
func get_velocity() -> Vector3:
	return velocity

## Check if character is moving
func is_moving() -> bool:
	return velocity.length() > 0.1

## Get parent's body rotation (from CameraController)
func get_parent_rotation() -> float:
	# Use cached reference (no tree traversal!)
	return camera_controller.get_body_rotation() if camera_controller else 0.0

## Get current stance
func get_stance() -> Stance:
	return current_stance

## Check if sprinting
func get_is_sprinting() -> bool:
	return is_sprinting

## Check if aiming
func get_is_aiming() -> bool:
	return is_aiming

## Check if there's any input this frame (for early exit optimization)
func _has_input() -> bool:
	return (Input.is_action_pressed("sprint") or
			Input.is_action_pressed("aim_down_sights") or
			Input.is_action_just_pressed("crouch") or
			Input.is_action_just_pressed("jump") or
			Input.get_vector("move_left", "move_right", "move_forward", "move_back") != Vector2.ZERO)
