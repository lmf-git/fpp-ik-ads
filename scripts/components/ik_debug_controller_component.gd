extends Node
class_name IKDebugControllerComponent

## Debug controller for manual IK target manipulation
## Press B to toggle debug mode, 1-4 to select targets, IJKL/UO to move

# Movement speed constants
const MOVEMENT_SPEED: float = 0.02  # Units per frame for horizontal movement
const VERTICAL_SPEED: float = 0.02  # Units per frame for vertical movement
const ROTATION_SPEED: float = 0.05  # Radians per frame

@export var ik_locomotion: IKLocomotion

# Debug state
var debug_mode_enabled: bool = false
var selected_target_index: int = 0  # 0=left_hand, 1=right_hand, 2=left_foot, 3=right_foot
var target_names: Array[String] = ["Left Hand", "Right Hand", "Left Foot", "Right Foot"]

# Input state
var movement_input: Vector3 = Vector3.ZERO

func _ready() -> void:
	if not ik_locomotion:
		push_error("IKDebugController: IKLocomotion not assigned!")
		return

	print("IKDebugController: Ready (Press B to toggle, 1-4 to select target)")

func _input(event: InputEvent) -> void:
	if not debug_mode_enabled:
		return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_select_target(0)
			KEY_2:
				_select_target(1)
			KEY_3:
				_select_target(2)
			KEY_4:
				_select_target(3)

func _process(_delta: float) -> void:
	if not debug_mode_enabled:
		return

	# Read movement input
	movement_input = Vector3.ZERO

	# Horizontal movement (Arrow Keys)
	if Input.is_key_pressed(KEY_LEFT):
		movement_input.x -= MOVEMENT_SPEED
	if Input.is_key_pressed(KEY_RIGHT):
		movement_input.x += MOVEMENT_SPEED
	if Input.is_key_pressed(KEY_UP):
		movement_input.z -= MOVEMENT_SPEED
	if Input.is_key_pressed(KEY_DOWN):
		movement_input.z += MOVEMENT_SPEED

	# Vertical movement (Page Up/Down)
	if Input.is_key_pressed(KEY_PAGEUP):
		movement_input.y += VERTICAL_SPEED
	if Input.is_key_pressed(KEY_PAGEDOWN):
		movement_input.y -= VERTICAL_SPEED

	# Apply movement to selected target
	if movement_input != Vector3.ZERO:
		_move_selected_target(movement_input)

## Toggle IK debug mode on/off
func toggle_debug_mode() -> void:
	debug_mode_enabled = not debug_mode_enabled

	if debug_mode_enabled:
		print("\n=== IK DEBUG MODE ENABLED ===")
		print("Controls:")
		print("  1-4: Select target (1=LHand, 2=RHand, 3=LFoot, 4=RFoot)")
		print("  Arrow Keys: Move target horizontally")
		print("  Page Up/Down: Move target vertically")
		print("  B: Exit debug mode")
		print("Selected: ", target_names[selected_target_index])
		print("=============================\n")
	else:
		print("\n=== IK DEBUG MODE DISABLED ===\n")

## Select which IK target to control
func _select_target(index: int) -> void:
	if index < 0 or index >= target_names.size():
		return

	selected_target_index = index
	print("Selected target: ", target_names[selected_target_index])

## Move the currently selected IK target
func _move_selected_target(offset: Vector3) -> void:
	if not ik_locomotion:
		return

	var target: Node3D = null

	match selected_target_index:
		0:  # Left hand
			target = ik_locomotion.left_hand_target
		1:  # Right hand
			target = ik_locomotion.right_hand_target
		2:  # Left foot
			target = ik_locomotion.left_foot_target
		3:  # Right foot
			target = ik_locomotion.right_foot_target

	if target:
		# Apply movement relative to character's facing direction
		var character_body := get_parent() as CharacterBody3D
		if character_body:
			var rotated_offset := character_body.global_transform.basis * offset
			target.global_position += rotated_offset

## Get current target info for display
func get_selected_target_info() -> String:
	if not debug_mode_enabled:
		return ""

	var target: Node3D = null
	match selected_target_index:
		0:
			target = ik_locomotion.left_hand_target
		1:
			target = ik_locomotion.right_hand_target
		2:
			target = ik_locomotion.left_foot_target
		3:
			target = ik_locomotion.right_foot_target

	if target:
		return "Target: %s | Pos: (%.2f, %.2f, %.2f)" % [
			target_names[selected_target_index],
			target.global_position.x,
			target.global_position.y,
			target.global_position.z
		]

	return "No target"
