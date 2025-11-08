extends Node
class_name CameraControllerComponent

## Handles first-person and third-person camera control
## Manages freelook, head rotation, and camera modes

signal freelook_changed(is_freelooking: bool)
signal camera_mode_changed(is_third_person: bool)

# Constants for spine/head coordination
const SPINE_PITCH_FOLLOW_RATIO: float = 0.3  # How much spine follows head pitch (30%)
const SPINE_YAW_FOLLOW_RATIO: float = 0.5    # How much spine follows head yaw (50%)
const THIRD_PERSON_CAMERA_HEIGHT: float = 3.0  # Height above character
const THIRD_PERSON_CAMERA_DISTANCE: float = 5.0  # Distance behind character

# Third-person camera lag/sway constants
const THIRD_PERSON_TURN_DEADZONE: float = 0.15  # Radians (~8.5°) - head turns before body
const THIRD_PERSON_CAMERA_LAG: float = 4.0  # How fast camera catches up (lower = more lag)
const THIRD_PERSON_HEAD_TURN_SPEED: float = 8.0  # How fast head aims before body follows
const THIRD_PERSON_BODY_CATCH_UP: float = 2.5  # How fast body catches up to camera

@export var config: CharacterConfig
@export var bone_config: BoneConfig

@onready var character_body: CharacterBody3D = get_parent()
@onready var skeleton: Skeleton3D = get_node_or_null("../CharacterModel/RootNode/Skeleton3D")
@onready var fps_camera: Camera3D = get_node_or_null("../CharacterModel/RootNode/Skeleton3D/HeadAttachment/FPSCamera")
@onready var third_person_camera: Camera3D = get_node_or_null("../ThirdPersonCamera")

# State
var camera_x_rotation: float = 0.0  # Pitch
var camera_y_rotation: float = 0.0  # Yaw (input target)
var body_y_rotation: float = 0.0    # Body's rotation
var freelook_offset: float = 0.0
var is_freelooking: bool = false
var is_third_person: bool = false
var ads_blend: float = 0.0

# Third-person camera lag state
var third_person_camera_yaw: float = 0.0  # Actual camera yaw (lags behind input)
var third_person_aim_offset: float = 0.0  # How far camera is ahead of body

# Cached bone indices
var _head_bone_idx: int = -1
var _spine_bone_idx: int = -1

func _ready() -> void:
	# Defer validation to allow parent to initialize config first
	call_deferred("_validate_and_initialize")

func _validate_and_initialize() -> void:
	var errors: Array[String] = []

	if not config:
		errors.append("CharacterConfig resource not assigned - assign in Inspector under 'Config'")

	if not bone_config:
		errors.append("BoneConfig resource not assigned - assign in Inspector under 'Bone Config'")

	if not skeleton:
		errors.append("Skeleton3D not found at '../CharacterModel/RootNode/Skeleton3D' - check scene structure")

	if not fps_camera:
		errors.append("FPS Camera not found - check that camera exists in scene")

	if errors.size() > 0:
		push_error("CameraController setup failed:\n  - " + "\n  - ".join(errors))
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Cache bone indices
	_head_bone_idx = bone_config.get_bone_index(skeleton, bone_config.head)
	_spine_bone_idx = bone_config.get_bone_index(skeleton, bone_config.spine)

	if _head_bone_idx < 0:
		push_warning("CameraController: Head bone not found - head rotation disabled")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event.relative)
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_toggle_mouse_capture()
		elif event.keycode == KEY_O:
			toggle_camera_mode()

func _process(delta: float) -> void:
	_update_body_rotation(delta)
	_update_head_rotation()
	_update_camera_mode()

## Handle mouse movement for camera rotation
func _handle_mouse_look(relative: Vector2) -> void:
	camera_y_rotation -= relative.x * config.mouse_sensitivity
	camera_x_rotation -= relative.y * config.mouse_sensitivity

	# Clamp pitch
	camera_x_rotation = clampf(
		camera_x_rotation,
		deg_to_rad(-config.max_look_up),
		deg_to_rad(config.max_look_down)
	)

	# Wrap yaw
	camera_y_rotation = wrapf(camera_y_rotation, -PI, PI)

## Update body rotation to follow camera (with freelook support)
func _update_body_rotation(delta: float) -> void:
	var was_freelooking := is_freelooking
	is_freelooking = Input.is_action_pressed("freelook")

	# Emit signal when state changes
	if was_freelooking != is_freelooking:
		freelook_changed.emit(is_freelooking)

	# === THIRD-PERSON MODE: Camera lag with deadzone ===
	if is_third_person:
		# Camera smoothly lags behind input
		third_person_camera_yaw = lerp_angle(
			third_person_camera_yaw,
			camera_y_rotation,
			THIRD_PERSON_CAMERA_LAG * delta
		)
		third_person_camera_yaw = wrapf(third_person_camera_yaw, -PI, PI)

		# Calculate how far camera is ahead of body
		third_person_aim_offset = wrapf(third_person_camera_yaw - body_y_rotation, -PI, PI)

		# Deadzone: head turns before body
		if abs(third_person_aim_offset) > THIRD_PERSON_TURN_DEADZONE:
			# Camera exceeded deadzone - body catches up
			var target_body_yaw: float = third_person_camera_yaw - sign(third_person_aim_offset) * THIRD_PERSON_TURN_DEADZONE
			body_y_rotation = lerp_angle(
				body_y_rotation,
				target_body_yaw,
				THIRD_PERSON_BODY_CATCH_UP * delta
			)
			# Update offset after body movement
			third_person_aim_offset = wrapf(third_person_camera_yaw - body_y_rotation, -PI, PI)

		# Freelook offset is how far head turns within deadzone
		freelook_offset = third_person_aim_offset

	# === FIRST-PERSON MODE: Original behavior ===
	elif is_freelooking:
		# Freelook: camera rotates independently
		freelook_offset = wrapf(camera_y_rotation - body_y_rotation, -PI, PI)

		# Body turns when camera exceeds neck limit
		var max_neck_yaw_rad := deg_to_rad(config.neck_max_yaw)
		if abs(freelook_offset) > max_neck_yaw_rad:
			body_y_rotation = camera_y_rotation - sign(freelook_offset) * max_neck_yaw_rad
			freelook_offset = sign(freelook_offset) * max_neck_yaw_rad
	else:
		# Normal FPS mode: body instantly follows camera
		body_y_rotation = camera_y_rotation
		freelook_offset = 0.0  # No offset in normal mode

	# Always wrap body rotation
	body_y_rotation = wrapf(body_y_rotation, -PI, PI)

	# Apply to character
	character_body.rotation.y = body_y_rotation

## Update head and spine bone rotations for freelook
func _update_head_rotation() -> void:
	if not skeleton or _head_bone_idx < 0:
		return

	# Apply head rotation for visual feedback
	# Note: Character model is rotated 180° so bone axes are flipped
	var head_pitch := -camera_x_rotation  # Inverted for 180° rotated model
	var head_yaw := 0.0

	# In freelook/third-person, also apply yaw rotation
	if is_freelooking or is_third_person:
		head_yaw = -freelook_offset  # Inverted for 180° rotated model

	# Apply neck limits
	head_pitch = clampf(
		head_pitch,
		deg_to_rad(-config.neck_max_pitch_up),  # Limits also inverted
		deg_to_rad(config.neck_max_pitch_down)
	)
	head_yaw = clampf(head_yaw, deg_to_rad(-config.neck_max_yaw), deg_to_rad(config.neck_max_yaw))

	# Apply to head bone
	skeleton.set_bone_pose_rotation(_head_bone_idx, Quaternion.from_euler(Vector3(head_pitch, head_yaw, 0)))

	# Partial rotation to spine for natural look
	if _spine_bone_idx >= 0:
		var spine_pitch := head_pitch * SPINE_PITCH_FOLLOW_RATIO
		var spine_yaw := head_yaw * SPINE_YAW_FOLLOW_RATIO
		skeleton.set_bone_pose_rotation(_spine_bone_idx, Quaternion.from_euler(Vector3(spine_pitch, spine_yaw, 0)))

## Update camera mode (FPS vs third-person)
func _update_camera_mode() -> void:
	if not fps_camera or not third_person_camera:
		return

	if is_third_person:
		if fps_camera.current:
			fps_camera.current = false
			third_person_camera.current = true

		# Position third-person camera behind character using lagged yaw
		# This creates smooth camera lag as the camera catches up to input
		var camera_offset := Vector3(0, THIRD_PERSON_CAMERA_HEIGHT, THIRD_PERSON_CAMERA_DISTANCE)
		var rotated_offset := Transform3D.IDENTITY.rotated(Vector3.UP, third_person_camera_yaw).basis * camera_offset
		third_person_camera.global_position = character_body.global_position + rotated_offset
		third_person_camera.look_at(character_body.global_position + Vector3.UP, Vector3.UP)
	else:
		if third_person_camera.current:
			third_person_camera.current = false
			fps_camera.current = true

		# In FPS mode, camera handles pitch only
		# Character model is rotated 180° so camera needs 0° yaw to face forward
		fps_camera.rotation = Vector3(camera_x_rotation, 0, 0)

## Update ADS (Aim Down Sights) FOV
func update_ads(delta: float, is_aiming: bool) -> void:
	var target_ads := 1.0 if is_aiming else 0.0
	ads_blend = lerpf(ads_blend, target_ads, config.ads_transition_speed * delta)

	if fps_camera:
		fps_camera.fov = lerpf(config.hipfire_fov, config.ads_fov, ads_blend)

## Toggle between first and third person
func toggle_camera_mode() -> void:
	is_third_person = not is_third_person

	# Initialize third-person camera yaw to current body rotation to avoid jump
	if is_third_person:
		third_person_camera_yaw = body_y_rotation
		third_person_aim_offset = 0.0

	camera_mode_changed.emit(is_third_person)
	print("Camera mode: ", "Third Person" if is_third_person else "First Person")

## Toggle mouse capture
func _toggle_mouse_capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

## Get current camera rotation for other systems
func get_camera_rotation() -> Vector2:
	return Vector2(camera_x_rotation, camera_y_rotation)

## Get body rotation
func get_body_rotation() -> float:
	return body_y_rotation

## Get freelook offset
func get_freelook_offset() -> float:
	return freelook_offset
