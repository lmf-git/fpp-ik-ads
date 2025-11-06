extends Node
class_name InputControllerComponent

## Centralized input handling for character
## Translates raw input (keys/mouse) into high-level semantic commands via signals
## Makes it easy to disable all input, implement rebinding, add gamepad support

# ===== HIGH-LEVEL COMMAND SIGNALS =====
# Movement
signal move_command(direction: Vector2)
signal look_command(relative_motion: Vector2)
signal sprint_started()
signal sprint_stopped()
signal jump_requested()
signal crouch_requested()

# Combat
signal fire_started()
signal fire_stopped()
signal aim_started()
signal aim_stopped()
signal reload_requested()
signal weapon_switch_requested(slot: int)

# Interaction
signal interact_requested()
signal freelook_started()
signal freelook_stopped()

# System
signal camera_mode_toggle_requested()
signal ik_mode_toggle_requested()
signal hud_toggle_requested()
signal debug_toggle_requested()

# Debug / Testing
signal ragdoll_toggle_requested()
signal ragdoll_impulse_requested()
signal partial_ragdoll_requested(limb: StringName)

# ===== STATE =====
var is_input_enabled: bool = true
var is_ui_active: bool = false
var mouse_captured: bool = true

# Continuous action states (for press/release signals)
var is_sprinting: bool = false
var is_firing: bool = false
var is_aiming: bool = false
var is_freelooking: bool = false

func _ready() -> void:
	# Capture mouse by default
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

func _input(event: InputEvent) -> void:
	if not is_input_enabled or is_ui_active:
		return

	# Mouse look
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			look_command.emit(event.relative)

	# Keyboard input
	elif event is InputEventKey and event.pressed:
		_handle_key_input(event.keycode)

func _process(_delta: float) -> void:
	if not is_input_enabled or is_ui_active:
		return

	# === MOVEMENT (continuous) ===
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir != Vector2.ZERO:
		move_command.emit(input_dir)

	# === COMBAT ACTIONS (state tracking for press/release) ===

	# Sprint
	var sprint_input := Input.is_action_pressed("sprint")
	if sprint_input and not is_sprinting:
		is_sprinting = true
		sprint_started.emit()
	elif not sprint_input and is_sprinting:
		is_sprinting = false
		sprint_stopped.emit()

	# Fire
	var fire_input := Input.is_action_pressed("fire")
	if fire_input and not is_firing:
		is_firing = true
		fire_started.emit()
	elif not fire_input and is_firing:
		is_firing = false
		fire_stopped.emit()

	# Aim down sights
	var aim_input := Input.is_action_pressed("aim_down_sights")
	if aim_input and not is_aiming:
		is_aiming = true
		aim_started.emit()
	elif not aim_input and is_aiming:
		is_aiming = false
		aim_stopped.emit()

	# Freelook
	var freelook_input := Input.is_action_pressed("freelook")
	if freelook_input and not is_freelooking:
		is_freelooking = true
		freelook_started.emit()
	elif not freelook_input and is_freelooking:
		is_freelooking = false
		freelook_stopped.emit()

	# === ONE-SHOT ACTIONS (just pressed) ===

	if Input.is_action_just_pressed("jump"):
		jump_requested.emit()

	if Input.is_action_just_pressed("crouch"):
		crouch_requested.emit()

	if Input.is_action_just_pressed("interact"):
		interact_requested.emit()

	if Input.is_action_just_pressed("reload"):
		reload_requested.emit()

func _handle_key_input(keycode: int) -> void:
	match keycode:
		# Weapon switching
		KEY_1:
			weapon_switch_requested.emit(0)
		KEY_2:
			weapon_switch_requested.emit(1)
		KEY_3:
			weapon_switch_requested.emit(2)

		# System toggles
		KEY_ESCAPE:
			_toggle_mouse_capture()
		KEY_O:
			camera_mode_toggle_requested.emit()
		KEY_M:
			ik_mode_toggle_requested.emit()
		KEY_4:
			hud_toggle_requested.emit()
		KEY_5:
			debug_toggle_requested.emit()

		# Ragdoll / Debug
		KEY_R:
			ragdoll_toggle_requested.emit()
		KEY_H:
			ragdoll_impulse_requested.emit()
		KEY_J:
			partial_ragdoll_requested.emit(&"left_arm")
		KEY_K:
			partial_ragdoll_requested.emit(&"right_arm")
		KEY_L:
			partial_ragdoll_requested.emit(&"legs")

## Enable all input
func enable_input() -> void:
	is_input_enabled = true
	print("InputController: Input enabled")

## Disable all input (for cutscenes, menus, etc.)
func disable_input() -> void:
	is_input_enabled = false
	# Reset state
	is_sprinting = false
	is_firing = false
	is_aiming = false
	is_freelooking = false
	print("InputController: Input disabled")

## Set whether UI is active (blocks character input)
func set_ui_active(active: bool) -> void:
	is_ui_active = active

## Toggle mouse capture
func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = false
		print("InputController: Mouse released")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
		print("InputController: Mouse captured")

## Check if input is currently enabled
func is_enabled() -> bool:
	return is_input_enabled and not is_ui_active
