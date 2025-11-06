extends Control
class_name ControlsHUD

## On-screen controls and debug information overlay

@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var debug_panel: PanelContainer = $DebugPanel
@onready var controls_label: RichTextLabel = $ControlsPanel/MarginContainer/ControlsLabel
@onready var debug_label: RichTextLabel = $DebugPanel/MarginContainer/DebugLabel

var show_controls: bool = true
var show_debug: bool = false
var player: SkeletonFPPController

func _ready():
	# Setup controls text
	_update_controls_text()

	# Hide debug panel initially
	if debug_panel:
		debug_panel.visible = show_debug

	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			show_controls = not show_controls
			if controls_panel:
				controls_panel.visible = show_controls
		elif event.keycode == KEY_F3:
			show_debug = not show_debug
			if debug_panel:
				debug_panel.visible = show_debug

func _process(_delta):
	if show_debug and player:
		_update_debug_text()

func _update_controls_text():
	if not controls_label:
		return

	var text = "[b][color=cyan]CONTROLS[/color][/b] (F1 to toggle)

[b][color=yellow]Movement[/color][/b]
WASD - Move
Shift - Sprint
C - Cycle Stance
Space - Jump
Alt - Freelook

[b][color=yellow]Weapon[/color][/b]
E - Pick up / Swap weapon
RMB - Aim Down Sights
1/2/3 - Switch slots

[b][color=yellow]Ragdoll[/color][/b]
G - Toggle full ragdoll
H - Ragdoll with impulse
J - Left arm ragdoll
K - Right arm ragdoll
Y - Both arms ragdoll

[b][color=yellow]Debug[/color][/b]
F1 - Toggle controls
F3 - Toggle debug info
Esc - Mouse capture"

	controls_label.text = text

func _update_debug_text():
	if not debug_label or not player:
		return

	var text = "[b][color=lime]DEBUG INFO[/color][/b] (F3 to toggle)\n\n"

	# Position
	text += "[b]Position:[/b] %.1f, %.1f, %.1f\n" % [player.global_position.x, player.global_position.y, player.global_position.z]

	# Velocity
	text += "[b]Velocity:[/b] %.1f, %.1f, %.1f\n" % [player.velocity.x, player.velocity.y, player.velocity.z]
	text += "[b]Speed:[/b] %.1f m/s\n" % Vector2(player.velocity.x, player.velocity.z).length()

	# Camera
	text += "[b]Camera Yaw:[/b] %.1f°\n" % rad_to_deg(player.camera_y_rotation)
	text += "[b]Camera Pitch:[/b] %.1f°\n" % rad_to_deg(player.camera_x_rotation)
	text += "[b]Body Yaw:[/b] %.1f°\n" % rad_to_deg(player.body_y_rotation)

	# States
	text += "\n[b][color=yellow]States:[/color][/b]\n"
	text += "Freelook: %s\n" % ("ON" if player.is_freelooking else "OFF")
	text += "Aiming: %s\n" % ("ON" if player.is_aiming else "OFF")
	text += "Sprinting: %s\n" % ("ON" if player.is_sprinting else "OFF")
	text += "Stance: %s\n" % _get_stance_name(player.stance)
	text += "On Floor: %s\n" % ("YES" if player.is_on_floor() else "NO")

	# Weapon
	if player.current_weapon:
		text += "\n[b][color=yellow]Weapon:[/color][/b]\n"
		text += "%s\n" % player.current_weapon.weapon_name
		text += "ADS Blend: %.2f\n" % player.ads_blend

		# Weapon swap status
		if player.weapon_swap_phase != 0:  # WeaponSwapPhase.NONE
			text += "[color=orange]Swapping: %s[/color]\n" % _get_swap_phase_name(player.weapon_swap_phase)

	# Ragdoll
	if player.ragdoll:
		text += "\n[b][color=yellow]Ragdoll:[/color][/b]\n"
		if player.ragdoll.is_ragdoll_active:
			text += "[color=red]FULL ACTIVE[/color]\n"
		elif player.ragdoll.is_any_partial_ragdoll_active():
			var parts = []
			if player.ragdoll.left_arm_ragdoll_active: parts.append("L_ARM")
			if player.ragdoll.right_arm_ragdoll_active: parts.append("R_ARM")
			if player.ragdoll.left_leg_ragdoll_active: parts.append("L_LEG")
			if player.ragdoll.right_leg_ragdoll_active: parts.append("R_LEG")
			text += "[color=orange]Partial: %s[/color]\n" % ", ".join(parts)
		else:
			text += "Inactive\n"

	# FPS
	text += "\n[b]FPS:[/b] %d" % Engine.get_frames_per_second()

	debug_label.text = text

func _get_stance_name(stance_val: int) -> String:
	match stance_val:
		0: return "Standing"
		1: return "Crouching"
		2: return "Prone"
		_: return "Unknown"

func _get_swap_phase_name(phase: int) -> String:
	match phase:
		1: return "Lowering"
		2: return "Switching"
		3: return "Raising"
		_: return "None"
