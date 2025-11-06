extends Node
class_name WeaponSwapState

## Base class for weapon swap states
## Implements State pattern for cleaner swap logic

signal state_finished(next_state: StringName)

var state_machine: WeaponSwapStateMachine
var weapon_controller: Node

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

## Transition to next state
func transition_to(next_state: StringName) -> void:
	state_finished.emit(next_state)
