extends Node
class_name WeaponSwapStateMachine

## State Machine for weapon swapping
## Manages weapon swap animation phases cleanly

signal swap_started()
signal swap_completed()

@export var swap_speed: float = 3.0

var current_state: WeaponSwapState
var states: Dictionary = {}
var weapon_controller: Node

# Swap data
var pending_weapon_pickup: WeaponPickup
var current_weapon: Weapon
var swap_progress: float = 0.0
var weapon_swap_offset: Vector3 = Vector3.ZERO
var weapon_swap_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	weapon_controller = get_parent()

	# Create states
	var idle_state = IdleSwapState.new()
	var lowering_state = LoweringSwapState.new()
	var switching_state = SwitchingSwapState.new()
	var raising_state = RaisingSwapState.new()

	# Register states
	register_state(&"idle", idle_state)
	register_state(&"lowering", lowering_state)
	register_state(&"switching", switching_state)
	register_state(&"raising", raising_state)

	# Start in idle
	transition_to(&"idle")

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

## Register a state
func register_state(state_name: StringName, state: WeaponSwapState) -> void:
	states[state_name] = state
	state.state_machine = self
	state.weapon_controller = weapon_controller
	state.state_finished.connect(_on_state_finished)
	add_child(state)

## Transition to a new state
func transition_to(state_name: StringName) -> void:
	if current_state:
		current_state.exit()

	current_state = states.get(state_name)
	if current_state:
		current_state.enter()
	else:
		push_error("WeaponSwapStateMachine: State '%s' not found" % state_name)

## Handle state transitions
func _on_state_finished(next_state: StringName) -> void:
	transition_to(next_state)

## Start weapon swap
func start_swap(pickup: WeaponPickup, weapon: Weapon) -> void:
	pending_weapon_pickup = pickup
	current_weapon = weapon
	swap_progress = 0.0

	if current_weapon:
		transition_to(&"lowering")
	else:
		transition_to(&"raising")

	swap_started.emit()

## Check if swapping
func is_swapping() -> bool:
	return current_state and current_state.name != &"idle"

## Get swap offset for procedural animation
func get_swap_offset() -> Vector3:
	return weapon_swap_offset

## Get swap rotation for procedural animation
func get_swap_rotation() -> Vector3:
	return weapon_swap_rotation


## ===== CONCRETE STATES =====

class IdleSwapState extends WeaponSwapState:
	func enter() -> void:
		state_machine.weapon_swap_offset = Vector3.ZERO
		state_machine.weapon_swap_rotation = Vector3.ZERO
		state_machine.swap_progress = 0.0

class LoweringSwapState extends WeaponSwapState:
	func enter() -> void:
		print("Weapon swap: LOWERING")

	func update(delta: float) -> void:
		state_machine.swap_progress += delta * state_machine.swap_speed
		var t := minf(state_machine.swap_progress, 1.0)

		# Smoothstep for smooth animation
		t = t * t * (3.0 - 2.0 * t)

		# Lower weapon down and to the right
		state_machine.weapon_swap_offset = Vector3(0.3, -0.5, -0.2) * t
		state_machine.weapon_swap_rotation = Vector3(
			deg_to_rad(-45),  # Pitch down
			deg_to_rad(30),   # Yaw right
			deg_to_rad(-20)   # Roll
		) * t

		if state_machine.swap_progress >= 1.0:
			transition_to(&"switching")

class SwitchingSwapState extends WeaponSwapState:
	const SWITCH_DURATION := 0.1

	var timer: float = 0.0

	func enter() -> void:
		timer = 0.0
		print("Weapon swap: SWITCHING")

		# Perform actual weapon switch
		weapon_controller.perform_weapon_switch(
			state_machine.pending_weapon_pickup,
			state_machine.current_weapon
		)

	func update(delta: float) -> void:
		timer += delta
		if timer >= SWITCH_DURATION:
			transition_to(&"raising")

class RaisingSwapState extends WeaponSwapState:
	func enter() -> void:
		state_machine.swap_progress = 0.0
		print("Weapon swap: RAISING")

	func update(delta: float) -> void:
		state_machine.swap_progress += delta * state_machine.swap_speed
		var t := minf(state_machine.swap_progress, 1.0)

		# Smoothstep for smooth animation
		t = t * t * (3.0 - 2.0 * t)

		# Raise weapon from left side
		state_machine.weapon_swap_offset = Vector3(-0.3, -0.5, -0.2) * (1.0 - t)
		state_machine.weapon_swap_rotation = Vector3(
			deg_to_rad(45),   # Pitch up
			deg_to_rad(-30),  # Yaw left
			deg_to_rad(20)    # Roll
		) * (1.0 - t)

		if state_machine.swap_progress >= 1.0:
			state_machine.swap_completed.emit()
			transition_to(&"idle")
