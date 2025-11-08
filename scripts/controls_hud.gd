extends Control
class_name ControlsHUD

## On-screen controls and debug information overlay

@onready var controls_panel: PanelContainer = $ControlsPanel
@onready var debug_panel: PanelContainer = $DebugPanel
@onready var controls_label: RichTextLabel = $ControlsPanel/MarginContainer/ControlsLabel
@onready var debug_label: RichTextLabel = $DebugPanel/MarginContainer/DebugLabel

var show_controls: bool = true
var show_debug: bool = false
var player: CharacterControllerMain

func _ready():
	# Setup controls text
	_update_controls_text()

	# Hide debug panel initially
	if debug_panel:
		debug_panel.visible = show_debug

	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	if not player:
		push_warning("ControlsHUD: No player found in 'player' group")

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_4:
			show_controls = not show_controls
			if controls_panel:
				controls_panel.visible = show_controls
		elif event.keycode == KEY_5:
			show_debug = not show_debug
			if debug_panel:
				debug_panel.visible = show_debug

func _process(_delta):
	if show_debug and player:
		_update_debug_text()

func _update_controls_text():
	if not controls_label:
		return

	var text = "[b][color=cyan]CONTROLS[/color][/b] (4 to toggle)

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
4 - Toggle controls
5 - Toggle debug info
Esc - Mouse capture"

	controls_label.text = text

func _update_debug_text():
	if not debug_label or not player:
		return

	var text = "[b][color=lime]DEBUG INFO[/color][/b] (5 to toggle)\n\n"

	# Get component states
	var movement_state = player.get_movement_state()
	var camera_state = player.get_camera_state()

	# Position
	text += "[b]Position:[/b] %.1f, %.1f, %.1f\n" % [player.global_position.x, player.global_position.y, player.global_position.z]

	# Velocity
	text += "[b]Velocity:[/b] %.1f, %.1f, %.1f\n" % [player.velocity.x, player.velocity.y, player.velocity.z]
	text += "[b]Speed:[/b] %.1f m/s\n" % Vector2(player.velocity.x, player.velocity.z).length()

	# Camera
	var cam_rot = camera_state.get("rotation", Vector2.ZERO)
	var body_rotation = camera_state.get("body_rotation", 0.0)
	text += "[b]Camera Yaw:[/b] %.1f°\n" % rad_to_deg(cam_rot.y)
	text += "[b]Camera Pitch:[/b] %.1f°\n" % rad_to_deg(cam_rot.x)
	text += "[b]Body Yaw:[/b] %.1f°\n" % rad_to_deg(body_rotation)

	# States
	text += "\n[b][color=yellow]States:[/color][/b]\n"
	text += "Freelook: %s\n" % ("ON" if camera_state.get("is_freelooking", false) else "OFF")
	text += "Aiming: %s\n" % ("ON" if movement_state.get("is_aiming", false) else "OFF")
	text += "Sprinting: %s\n" % ("ON" if movement_state.get("is_sprinting", false) else "OFF")
	text += "Stance: %s\n" % _get_stance_name(movement_state.get("stance", 0))
	text += "On Floor: %s\n" % ("YES" if player.is_on_floor() else "NO")

	# Weapon
	if player.current_weapon:
		text += "\n[b][color=yellow]Weapon:[/color][/b]\n"
		text += "%s\n" % player.current_weapon.weapon_name
		if player.camera_controller:
			text += "ADS Blend: %.2f\n" % player.camera_controller.ads_blend

	# Ragdoll
	if player.ragdoll_controller:
		text += "\n[b][color=yellow]Ragdoll:[/color][/b]\n"
		if player.ragdoll_controller.is_ragdoll_active:
			text += "[color=red]FULL ACTIVE[/color]\n"
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
