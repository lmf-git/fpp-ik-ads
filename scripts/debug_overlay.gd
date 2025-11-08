extends CanvasLayer
class_name DebugOverlay

## Comprehensive debug overlay showing all system stats (F3 to toggle)

@onready var debug_panel: Panel = $DebugPanel
@onready var debug_text: RichTextLabel = $DebugPanel/MarginContainer/DebugText
@onready var performance_text: RichTextLabel = $PerformancePanel/MarginContainer/PerformanceText
@onready var ik_visualization: Node3D = null

var player: CharacterControllerMain
var debug_visible: bool = false
var show_ik_debug: bool = false

func _ready():
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	# Hide by default
	debug_panel.visible = false
	$PerformancePanel.visible = false

func _input(event):
	if event is InputEventKey and event.pressed:
		# F3 - Toggle debug overlay
		if event.keycode == KEY_F3:
			debug_visible = !debug_visible
			debug_panel.visible = debug_visible
			$PerformancePanel.visible = debug_visible

		# F4 - Toggle IK visualization
		elif event.keycode == KEY_F4:
			show_ik_debug = !show_ik_debug

func _process(_delta):
	if not debug_visible or not player:
		return

	_update_debug_text()
	_update_performance_text()

	if show_ik_debug:
		_draw_ik_debug()

func _update_debug_text():
	var text = "[b][color=cyan]FPP IK ADS DEBUG INFO[/color][/b]\n\n"

	# Player state
	text += "[b][color=yellow]PLAYER STATE[/color][/b]\n"
	text += "Position: %v\n" % player.global_position

	if player.movement_controller:
		var velocity = player.movement_controller.get_velocity()
		text += "Velocity: %v (%.2f m/s)\n" % [velocity, velocity.length()]
		text += "Stance: %s\n" % _stance_to_string(player.movement_controller.get_stance())
		text += "Sprinting: %s\n" % player.movement_controller.get_is_sprinting()

	text += "On Floor: %s\n" % player.is_on_floor()
	text += "\n"

	# Camera & Look
	text += "[b][color=yellow]CAMERA & LOOK[/color][/b]\n"

	if player.camera_controller:
		var cam_rot = player.camera_controller.get_camera_rotation()
		text += "Camera Pitch: %.1f°\n" % rad_to_deg(cam_rot.x)
		text += "Camera Yaw: %.1f°\n" % rad_to_deg(cam_rot.y)
		text += "Body Yaw: %.1f°\n" % rad_to_deg(player.camera_controller.get_body_rotation())
		text += "Freelooking: %s\n" % player.camera_controller.is_freelooking

		if player.camera_controller.is_freelooking:
			var max_angle = player.config.neck_max_yaw if player.config else 90.0
			text += "Freelook Offset: %.1f° / %.1f°\n" % [
				rad_to_deg(abs(player.camera_controller.get_freelook_offset())),
				max_angle
			]

	text += "\n"

	# ADS
	text += "[b][color=yellow]ADS SYSTEM[/color][/b]\n"

	if player.movement_controller:
		text += "Aiming: %s\n" % player.movement_controller.get_is_aiming()

	if player.camera_controller:
		text += "ADS Blend: %.2f\n" % player.camera_controller.ads_blend

	if player.fps_camera:
		text += "Current FOV: %.1f°\n" % player.fps_camera.fov

	text += "\n"

	# Weapon
	text += "[b][color=yellow]WEAPON[/color][/b]\n"
	if player.current_weapon:
		var weapon = player.current_weapon
		text += "Name: %s\n" % weapon.weapon_name
		text += "Type: %s\n" % _weapon_type_to_string(weapon.weapon_type)
		text += "Ammo: %d / %d\n" % [weapon.current_ammo, weapon.magazine_size]
		text += "Can Fire: %s\n" % weapon.can_fire
		text += "Reloading: %s\n" % weapon.is_reloading
		text += "Damage: %.1f\n" % weapon.damage
		text += "Fire Rate: %.2f s\n" % weapon.fire_rate
		text += "Recoil: %v\n" % weapon.current_recoil
	else:
		text += "[color=red]No weapon equipped[/color]\n"
	text += "\n"

	# IK System
	text += "[b][color=yellow]IK SYSTEM[/color][/b]\n"

	if player.ik_locomotion:
		text += "IK Enabled: %s\n" % player.ik_locomotion.ik_mode_enabled

	if player.skeleton:
		text += "Skeleton Bones: %d\n" % player.skeleton.get_bone_count()

	if player.bone_config:
		text += "Head Bone: %s\n" % player.bone_config.head
		text += "Spine Bone: %s\n" % player.bone_config.spine

	if player.right_hand_ik:
		text += "Right Hand IK: Active\n"

	if player.left_hand_ik:
		text += "Left Hand IK: Active\n"

	text += "\n"

	# Controls reminder
	text += "[b][color=green]DEBUG CONTROLS[/color][/b]\n"
	text += "F3 - Toggle this overlay\n"
	text += "F4 - Toggle IK visualization\n"

	debug_text.text = text

func _update_performance_text():
	var text = "[b][color=cyan]PERFORMANCE[/color][/b]\n\n"

	# FPS
	var fps = Engine.get_frames_per_second()
	var fps_color = "green"
	if fps < 30:
		fps_color = "red"
	elif fps < 60:
		fps_color = "orange"

	text += "FPS: [color=%s]%d[/color]\n" % [fps_color, fps]
	text += "Frame Time: %.2f ms\n" % (1000.0 / max(fps, 1))
	text += "\n"

	# Memory
	text += "[b]Memory[/b]\n"
	text += "Static: %.1f MB\n" % (Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	text += "\n"

	# Physics
	text += "[b]Physics[/b]\n"
	text += "Active Bodies: %d\n" % Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	text += "Collision Pairs: %d\n" % Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
	text += "\n"

	# Rendering
	text += "[b]Rendering[/b]\n"
	text += "Draw Calls: %d\n" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	text += "Vertices: %d\n" % Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	text += "Objects: %d\n" % Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)

	performance_text.text = text

func _draw_ik_debug():
	# This would use DebugDraw3D if available, or ImmediateMesh
	# For now, just a placeholder
	pass

func _stance_to_string(stance) -> String:
	match stance:
		MovementControllerComponent.Stance.STANDING:
			return "Standing"
		MovementControllerComponent.Stance.CROUCHING:
			return "Crouching"
		MovementControllerComponent.Stance.PRONE:
			return "Prone"
	return "Unknown"

func _weapon_type_to_string(type) -> String:
	match type:
		Weapon.WeaponType.PISTOL:
			return "Pistol"
		Weapon.WeaponType.RIFLE:
			return "Rifle"
		Weapon.WeaponType.SMG:
			return "SMG"
		Weapon.WeaponType.SHOTGUN:
			return "Shotgun"
		Weapon.WeaponType.SNIPER:
			return "Sniper"
		Weapon.WeaponType.LMG:
			return "LMG"
	return "Unknown"
