extends Node
class_name CameraControllerComponent

## Handles first-person and third-person camera control
## Manages freelook, head rotation, and camera modes

signal freelook_changed(is_freelooking: bool)
signal camera_mode_changed(is_third_person: bool)

@export var config: CharacterConfig
@export var bone_config: BoneConfig

@onready var character_body: CharacterBody3D = get_parent()
@onready var skeleton: Skeleton3D = get_node_or_null("../CharacterModel/RootNode/Skeleton3D")
@onready var fps_camera: Camera3D = get_node_or_null("../CharacterModel/RootNode/Skeleton3D/HeadAttachment/FPSCamera")
@onready var third_person_camera: Camera3D = get_node_or_null("../ThirdPersonCamera")

# State
var camera_x_rotation: float = 0.0  # Pitch
var camera_y_rotation: float = 0.0  # Yaw
var body_y_rotation: float = 0.0    # Body's rotation
var freelook_offset: float = 0.0
var is_freelooking: bool = false
var is_third_person: bool = false
var ads_blend: float = 0.0

# Cached bone indices
var _head_bone_idx: int = -1
var _spine_bone_idx: int = -1

func _ready() -> void:
	if not config or not bone_config:
		push_error("CameraController: Config resources not assigned!")
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Cache bone indices
	_head_bone_idx = bone_config.get_bone_index(skeleton, bone_config.head)
	_spine_bone_idx = bone_config.get_bone_index(skeleton, bone_config.spine)

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

	if is_freelooking:
		# Freelook: camera rotates independently
		freelook_offset = wrapf(camera_y_rotation - body_y_rotation, -PI, PI)

		# Body turns when camera exceeds neck limit
		var max_neck_yaw_rad := deg_to_rad(config.neck_max_yaw)
		if abs(freelook_offset) > max_neck_yaw_rad:
			body_y_rotation = camera_y_rotation - sign(freelook_offset) * max_neck_yaw_rad
			freelook_offset = sign(freelook_offset) * max_neck_yaw_rad
	else:
		# Normal mode: body follows camera smoothly
		body_y_rotation = lerp_angle(body_y_rotation, camera_y_rotation, config.body_rotation_speed * delta)
		freelook_offset = wrapf(camera_y_rotation - body_y_rotation, -PI, PI)

	# Always wrap body rotation
	body_y_rotation = wrapf(body_y_rotation, -PI, PI)

	# Apply to character
	character_body.rotation.y = body_y_rotation

## Update head and spine bone rotations for freelook
func _update_head_rotation() -> void:
	if not skeleton or _head_bone_idx < 0:
		return

	# Calculate head rotation (compensate for camera-body offset)
	var head_pitch := -camera_x_rotation  # Negate for character model orientation
	var head_yaw := freelook_offset

	# Apply neck limits
	head_pitch = clampf(
		head_pitch,
		deg_to_rad(-config.neck_max_pitch_down),
		deg_to_rad(config.neck_max_pitch_up)
	)
	head_yaw = clampf(head_yaw, deg_to_rad(-config.neck_max_yaw), deg_to_rad(config.neck_max_yaw))

	# Apply to head bone
	skeleton.set_bone_pose_rotation(_head_bone_idx, Quaternion.from_euler(Vector3(head_pitch, head_yaw, 0)))

	# Partial rotation to spine for natural look
	if _spine_bone_idx >= 0:
		var spine_pitch := head_pitch * 0.3
		var spine_yaw := head_yaw * 0.5
		skeleton.set_bone_pose_rotation(_spine_bone_idx, Quaternion.from_euler(Vector3(spine_pitch, spine_yaw, 0)))

## Update camera mode (FPS vs third-person)
func _update_camera_mode() -> void:
	if not fps_camera or not third_person_camera:
		return

	if is_third_person:
		if fps_camera.current:
			fps_camera.current = false
			third_person_camera.current = true

		# Position third-person camera behind character
		var camera_offset := Vector3(0, 3, 5)
		var rotated_offset := Transform3D.IDENTITY.rotated(Vector3.UP, body_y_rotation).basis * camera_offset
		third_person_camera.global_position = character_body.global_position + rotated_offset
		third_person_camera.look_at(character_body.global_position + Vector3.UP, Vector3.UP)
	else:
		if third_person_camera.current:
			third_person_camera.current = false
			fps_camera.current = true

## Update ADS (Aim Down Sights) FOV
func update_ads(delta: float, is_aiming: bool) -> void:
	var target_ads := 1.0 if is_aiming else 0.0
	ads_blend = lerpf(ads_blend, target_ads, config.ads_transition_speed * delta)

	if fps_camera:
		fps_camera.fov = lerpf(config.hipfire_fov, config.ads_fov, ads_blend)

## Toggle between first and third person
func toggle_camera_mode() -> void:
	is_third_person = not is_third_person
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
