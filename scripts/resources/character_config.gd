extends Resource
class_name CharacterConfig

## Character configuration resource
## Centralizes all movement, camera, and physics parameters

@export_group("Movement")
@export var walk_speed: float = 3.0
@export var sprint_speed: float = 6.0
@export var crouch_speed: float = 1.5
@export var prone_speed: float = 0.8
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var friction: float = 25.0
@export var air_friction: float = 2.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var max_look_up: float = 80.0
@export var max_look_down: float = 80.0
@export var body_rotation_speed: float = 3.0
@export var hipfire_fov: float = 90.0
@export var ads_fov: float = 50.0
@export var ads_transition_speed: float = 8.0

@export_group("Freelook")
@export var freelook_max_angle: float = 120.0
@export var neck_max_pitch_up: float = 60.0
@export var neck_max_pitch_down: float = 50.0
@export var neck_max_yaw: float = 80.0

@export_group("Weapon")
@export var weapon_swap_speed: float = 3.0

## Get movement speed for current stance and state
func get_movement_speed(stance: int, is_sprinting: bool, is_aiming: bool) -> float:
	if is_aiming:
		return crouch_speed * 0.8  # Slow walk when aiming

	match stance:
		0:  # Standing
			return sprint_speed if is_sprinting else walk_speed
		1:  # Crouching
			return crouch_speed
		2:  # Prone
			return prone_speed
		_:
			return walk_speed
