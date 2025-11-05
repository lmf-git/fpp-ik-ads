extends Node3D
class_name Weapon

## Base class for all weapons with IK points and properties

@export_group("Weapon Info")
@export var weapon_name: String = "Rifle"
@export var weapon_type: WeaponType = WeaponType.RIFLE

@export_group("IK Points")
@export var grip_point: Node3D
@export var support_point: Node3D
@export var ads_target: Node3D  # Sight/optic position

@export_group("Weapon Properties")
@export var damage: float = 30.0
@export var fire_rate: float = 0.1  # Seconds between shots
@export var magazine_size: int = 30
@export var reload_time: float = 2.5
@export var recoil_amount: Vector2 = Vector2(2.0, 0.5)  # Vertical, Horizontal

@export_group("Positioning")
@export var hipfire_position: Vector3 = Vector3.ZERO
@export var hipfire_rotation: Vector3 = Vector3.ZERO

# State
var current_ammo: int = 30
var can_fire: bool = true
var is_reloading: bool = false

# Recoil
var current_recoil: Vector3 = Vector3.ZERO
@export var recoil_recovery_speed: float = 10.0

# Timers
var fire_timer: float = 0.0

enum WeaponType {
	PISTOL,
	RIFLE,
	SMG,
	SHOTGUN,
	SNIPER,
	LMG
}

func _ready():
	current_ammo = magazine_size

	# Auto-find IK points if not set
	if not grip_point:
		grip_point = get_node_or_null("GripPoint")
	if not support_point:
		support_point = get_node_or_null("SupportPoint")
	if not ads_target:
		ads_target = get_node_or_null("ADSTarget")

func _process(delta):
	# Update timers
	fire_timer = max(0, fire_timer - delta)
	can_fire = fire_timer <= 0 and not is_reloading and current_ammo > 0

	# Recover from recoil
	current_recoil = current_recoil.lerp(Vector3.ZERO, recoil_recovery_speed * delta)

	# Handle input
	if Input.is_action_pressed("fire") and can_fire:
		fire()

	if Input.is_action_just_pressed("reload") and current_ammo < magazine_size and not is_reloading:
		reload()

func fire():
	if not can_fire:
		return

	# Consume ammo
	current_ammo -= 1

	# Apply recoil
	current_recoil.x += randf_range(-recoil_amount.x * 0.8, -recoil_amount.x)
	current_recoil.y += randf_range(-recoil_amount.y, recoil_amount.y)

	# Start cooldown
	fire_timer = fire_rate

	# Visual/audio feedback
	_play_fire_effects()

	# Raycast for hit detection
	_check_hit()

	print("[%s] FIRE! Ammo: %d/%d" % [weapon_name, current_ammo, magazine_size])

func _play_fire_effects():
	# TODO: Muzzle flash, sound, etc.
	pass

func _check_hit():
	# Raycast from camera center
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z * 100.0)

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_parent().get_parent()]  # Don't hit self

	var result = space_state.intersect_ray(query)
	if result:
		print("  HIT: ", result.collider.name, " at distance ", from.distance_to(result.position))

func reload():
	if is_reloading:
		return

	is_reloading = true
	print("[%s] Reloading..." % weapon_name)

	# Start reload timer
	await get_tree().create_timer(reload_time).timeout

	current_ammo = magazine_size
	is_reloading = false
	print("[%s] Reload complete!" % weapon_name)

func get_grip_point() -> Node3D:
	return grip_point

func get_support_point() -> Node3D:
	return support_point

func get_ads_target() -> Node3D:
	return ads_target

func get_ammo_status() -> String:
	return "%d/%d" % [current_ammo, magazine_size]
