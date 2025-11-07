extends Node
class_name WeaponControllerComponent

## Handles weapon management, swapping, IK hand positioning, and ADS
## Uses WeaponSwapStateMachine for smooth weapon transitions

signal weapon_changed(new_weapon: Weapon, old_weapon: Weapon)
signal weapon_fired(weapon: Weapon)
signal ammo_changed(current: int, max: int)

@export var config: CharacterConfig
@export var bone_config: BoneConfig

# Node references
var skeleton: Skeleton3D
var right_hand_ik: SkeletonIK3D
var left_hand_ik: SkeletonIK3D
var right_hand_attachment: Node3D
var fps_camera: Camera3D

@onready var weapon_swap_state_machine: WeaponSwapStateMachine = $WeaponSwapStateMachine

# State
var current_weapon: Weapon
var holstered_weapons: Array[Weapon] = []
var current_weapon_slot: int = 0

# IK targets (created dynamically)
var right_hand_ik_target: Node3D
var left_hand_ik_target: Node3D

# ADS state
var ads_blend: float = 0.0

func _ready() -> void:
	_validate_setup()

func _validate_setup() -> void:
	var errors: Array[String] = []

	if not config:
		errors.append("CharacterConfig resource not assigned")

	if not bone_config:
		errors.append("BoneConfig resource not assigned")

	if not weapon_swap_state_machine:
		errors.append("WeaponSwapStateMachine child node missing - add as child node")

	if errors.size() > 0:
		push_error("WeaponController setup failed:\n  - " + "\n  - ".join(errors))
		return

	# Connect state machine signals if it exists
	if weapon_swap_state_machine:
		weapon_swap_state_machine.swap_started.connect(_on_swap_started)
		weapon_swap_state_machine.swap_completed.connect(_on_swap_completed)

## Initialize with scene references from parent controller
func initialize(skel: Skeleton3D, r_hand_ik: SkeletonIK3D, l_hand_ik: SkeletonIK3D,
				r_hand_attach: Node3D, camera: Camera3D) -> void:
	skeleton = skel
	right_hand_ik = r_hand_ik
	left_hand_ik = l_hand_ik
	right_hand_attachment = r_hand_attach
	fps_camera = camera

	if skeleton:
		_create_ik_targets()

func _create_ik_targets() -> void:
	if not skeleton:
		return

	# Create persistent IK targets for hand positioning
	right_hand_ik_target = Node3D.new()
	right_hand_ik_target.name = "RightHandIKTarget"
	skeleton.add_child(right_hand_ik_target)

	left_hand_ik_target = Node3D.new()
	left_hand_ik_target.name = "LeftHandIKTarget"
	skeleton.add_child(left_hand_ik_target)

	print("WeaponController: Created IK targets")

func _process(_delta: float) -> void:
	if current_weapon:
		_update_weapon_ik()
		_apply_procedural_offsets()

## Pick up weapon and start swap animation
func pickup_weapon(pickup: WeaponPickup) -> void:
	if not pickup or not weapon_swap_state_machine:
		return

	# Don't allow pickup during active swap
	if weapon_swap_state_machine.is_swapping():
		print("Cannot pickup during weapon swap")
		return

	# Start swap via state machine
	weapon_swap_state_machine.start_swap(pickup, current_weapon)

## Called by state machine during SWITCHING phase
func perform_weapon_switch(pickup: WeaponPickup, old_weapon: Weapon) -> void:
	# Drop old weapon
	if old_weapon:
		_drop_weapon(old_weapon)

	# Instantiate new weapon
	if pickup and pickup.weapon_scene:
		var new_weapon = pickup.weapon_scene.instantiate() as Weapon
		if new_weapon and right_hand_attachment:
			right_hand_attachment.add_child(new_weapon)
			new_weapon.position = Vector3.ZERO
			new_weapon.rotation = Vector3.ZERO
			current_weapon = new_weapon

			# Configure IK
			_setup_weapon_ik(new_weapon)

			weapon_changed.emit(new_weapon, old_weapon)
			print("WeaponController: Equipped ", new_weapon.weapon_name)

		# Remove pickup from world
		pickup.queue_free()

## Detach weapon from character without dropping it (for hotswapping between slots)
func _detach_weapon(weapon: Weapon) -> void:
	if not weapon:
		return

	# Remove from hand attachment but don't destroy
	if weapon.get_parent():
		weapon.get_parent().remove_child(weapon)

	# Disable weapon IK while detached
	if right_hand_ik:
		right_hand_ik.stop()
	if left_hand_ik:
		left_hand_ik.stop()

## Attach weapon to character hand (for hotswapping between slots)
func _attach_weapon(weapon: Weapon) -> void:
	if not weapon or not right_hand_attachment:
		return

	# Add to hand attachment
	right_hand_attachment.add_child(weapon)
	weapon.position = Vector3.ZERO
	weapon.rotation = Vector3.ZERO

	# Setup IK for this weapon
	_setup_weapon_ik(weapon)

	print("WeaponController: Attached ", weapon.weapon_name)

func _drop_weapon(weapon: Weapon) -> void:
	if not weapon:
		return

	# Check if weapon has source pickup scene
	if weapon.has_method("get_source_pickup_scene"):
		var pickup_scene = weapon.get_source_pickup_scene()
		if pickup_scene:
			# Spawn weapon pickup at character position
			var pickup = pickup_scene.instantiate() as WeaponPickup
			get_tree().root.add_child(pickup)
			var drop_pos = weapon.global_position + Vector3(0, 0.5, 1)
			pickup.global_position = drop_pos

	weapon.queue_free()
	print("WeaponController: Dropped weapon")

func _setup_weapon_ik(weapon: Weapon) -> void:
	if not weapon:
		return

	# Check if weapon has grip and support points
	var grip_point = weapon.get_node_or_null("GripPoint")
	var support_point = weapon.get_node_or_null("SupportPoint")

	# Configure right hand IK (grip)
	if right_hand_ik and grip_point and right_hand_ik_target:
		right_hand_ik.target_node = right_hand_ik_target.get_path()
		if not right_hand_ik.is_running():
			right_hand_ik.start()
		print("WeaponController: Right hand IK configured")

	# Configure left hand IK (support)
	if left_hand_ik and support_point and left_hand_ik_target:
		left_hand_ik.target_node = left_hand_ik_target.get_path()
		if not left_hand_ik.is_running():
			left_hand_ik.start()
		print("WeaponController: Left hand IK configured")

func _update_weapon_ik() -> void:
	if not current_weapon:
		return

	var grip_point = current_weapon.get_node_or_null("GripPoint")
	var support_point = current_weapon.get_node_or_null("SupportPoint")

	# Update right hand target (grip)
	if right_hand_ik_target and grip_point:
		right_hand_ik_target.global_transform = grip_point.global_transform

	# Update left hand target (support)
	if left_hand_ik_target and support_point:
		left_hand_ik_target.global_transform = support_point.global_transform

func _apply_procedural_offsets() -> void:
	if not current_weapon or not weapon_swap_state_machine:
		return

	# Apply swap animation offsets from state machine
	var swap_offset = weapon_swap_state_machine.get_swap_offset()
	var swap_rotation = weapon_swap_state_machine.get_swap_rotation()

	if swap_offset != Vector3.ZERO or swap_rotation != Vector3.ZERO:
		current_weapon.position = swap_offset
		current_weapon.rotation_degrees = swap_rotation

## Update ADS positioning - aligns weapon sight with camera center
func update_ads(delta: float, is_aiming: bool) -> void:
	if not current_weapon or not fps_camera:
		return

	# Calculate ADS blend
	var target_ads := 1.0 if is_aiming else 0.0
	ads_blend = lerpf(ads_blend, target_ads, config.ads_transition_speed * delta)

	if ads_blend < 0.01:
		return  # Not aiming, skip expensive positioning

	# Get ADS target (sight/scope position on weapon)
	var ads_target_node = current_weapon.get_node_or_null("ADSTarget")
	if not ads_target_node:
		return

	# Position weapon so ADS target aligns with camera center
	var camera_pos := fps_camera.global_position

	# Calculate where weapon should be
	var weapon_root := current_weapon.get_parent() as Node3D
	if weapon_root:
		# Offset from weapon root to ADS target in local space
		var ads_offset_local: Transform3D = current_weapon.transform * ads_target_node.transform

		# Target position: align ADS point with camera
		var target_weapon_pos: Vector3 = camera_pos - (weapon_root.global_transform.basis * ads_offset_local.origin)

		# Blend position smoothly
		weapon_root.global_position = weapon_root.global_position.lerp(target_weapon_pos, ads_blend)

## Fire current weapon
func fire_weapon() -> void:
	if not current_weapon:
		return

	if "can_fire" in current_weapon and current_weapon.can_fire:
		if current_weapon.has_method("fire"):
			current_weapon.fire()
			weapon_fired.emit(current_weapon)

			# Update ammo display
			if current_weapon.has_method("get_current_ammo") and current_weapon.has_method("get_magazine_size"):
				ammo_changed.emit(current_weapon.get_current_ammo(), current_weapon.get_magazine_size())

## Reload current weapon
func reload_weapon() -> void:
	if not current_weapon:
		return

	if "is_reloading" in current_weapon and not current_weapon.is_reloading:
		if current_weapon.has_method("reload"):
			current_weapon.reload()

## Switch to weapon in specific slot (1/2/3 keys)
func switch_to_slot(slot: int) -> void:
	if slot == current_weapon_slot:
		return  # Already equipped

	# Ensure holstered_weapons array is large enough
	while holstered_weapons.size() <= slot:
		holstered_weapons.append(null)

	# Check if there's a weapon in this slot
	var target_weapon := holstered_weapons[slot]
	if not target_weapon:
		print("WeaponController: No weapon in slot ", slot)
		return

	# Don't swap if already in progress
	if weapon_swap_state_machine and weapon_swap_state_machine.is_swapping():
		print("WeaponController: Cannot switch during weapon swap")
		return

	# Swap: put current weapon in old slot, equip target weapon
	if current_weapon:
		holstered_weapons[current_weapon_slot] = current_weapon
		_detach_weapon(current_weapon)

	holstered_weapons[slot] = null
	current_weapon_slot = slot
	current_weapon = target_weapon
	_attach_weapon(current_weapon)

	weapon_changed.emit(current_weapon)
	print("WeaponController: Switched to ", target_weapon.weapon_name, " in slot ", slot)

## Get current weapon for external systems
func get_current_weapon() -> Weapon:
	return current_weapon

## Check if weapon system is ready
func is_ready() -> bool:
	return skeleton != null and right_hand_attachment != null

## Signal handlers
func _on_swap_started() -> void:
	print("WeaponController: Weapon swap started")

func _on_swap_completed() -> void:
	print("WeaponController: Weapon swap completed")
