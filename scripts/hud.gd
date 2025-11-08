extends CanvasLayer
class_name HUD

## Complete HUD system with crosshair, ammo counter, weapon info, and prompts

@onready var crosshair: Control = $Crosshair
@onready var ammo_label: Label = $AmmoCounter/AmmoLabel
@onready var weapon_label: Label = $WeaponInfo/WeaponLabel
@onready var stance_label: Label = $StanceInfo/StanceLabel
@onready var interaction_prompt: Label = $InteractionPrompt
@onready var freelook_indicator: Label = $FreelookIndicator
@onready var ads_indicator: Control = $ADSIndicator
@onready var health_bar: ProgressBar = $HealthBar
@onready var control_hints: VBoxContainer = $ControlHints

var player: CharacterControllerMain

func _ready():
	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

	if not player:
		push_warning("HUD: No player found in 'player' group")
		return

	# Connect signals
	if player.has_signal("weapon_changed"):
		player.weapon_changed.connect(_on_weapon_changed)
	if player.has_signal("stance_changed"):
		player.stance_changed.connect(_on_stance_changed)
	if player.has_signal("interaction_available"):
		player.interaction_available.connect(_on_interaction_available)
	if player.has_signal("interaction_unavailable"):
		player.interaction_unavailable.connect(_on_interaction_unavailable)

	# Hide interaction prompt initially
	interaction_prompt.visible = false

	# Show control hints for first 10 seconds
	if control_hints:
		await get_tree().create_timer(10.0).timeout
		var tween = create_tween()
		tween.tween_property(control_hints, "modulate:a", 0.0, 1.0)
		await tween.finished
		control_hints.visible = false

func _process(_delta):
	if not player:
		return

	_update_ammo_counter()
	_update_weapon_info()
	_update_stance_info()
	_update_freelook_indicator()
	_update_ads_indicator()
	_update_crosshair()

func _update_ammo_counter():
	if player.current_weapon:
		var weapon = player.current_weapon
		ammo_label.text = "%d / %d" % [weapon.current_ammo, weapon.magazine_size]

		# Color code ammo
		if weapon.current_ammo == 0:
			ammo_label.add_theme_color_override("font_color", Color.RED)
		elif weapon.current_ammo < weapon.magazine_size * 0.3:
			ammo_label.add_theme_color_override("font_color", Color.ORANGE)
		else:
			ammo_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		ammo_label.text = "-- / --"

func _update_weapon_info():
	if player.current_weapon:
		weapon_label.text = player.current_weapon.weapon_name
	else:
		weapon_label.text = "No Weapon"

func _update_stance_info():
	var movement_state = player.get_movement_state()
	var stance = movement_state.get("stance", 0)
	match stance:
		0:  # Standing
			stance_label.text = "Standing"
		1:  # Crouching
			stance_label.text = "Crouching"
		2:  # Prone
			stance_label.text = "Prone"

func _update_freelook_indicator():
	var camera_state = player.get_camera_state()
	var is_freelooking = camera_state.get("is_freelooking", false)

	if is_freelooking:
		freelook_indicator.visible = true
		var freelook_offset = camera_state.get("freelook_offset", 0.0)
		var offset_deg = rad_to_deg(freelook_offset)
		freelook_indicator.text = "FREELOOK [%d°]" % abs(offset_deg)

		# Color based on offset (max freelook angle is typically 90°)
		var max_angle = 90.0
		var ratio = abs(offset_deg) / max_angle
		freelook_indicator.add_theme_color_override("font_color",
			Color.GREEN.lerp(Color.RED, ratio))
	else:
		freelook_indicator.visible = false

func _update_ads_indicator():
	var movement_state = player.get_movement_state()
	var is_aiming = movement_state.get("is_aiming", false)
	ads_indicator.visible = is_aiming

	# Scale crosshair with ADS
	var ads_blend = 0.0
	if player.camera_controller:
		ads_blend = player.camera_controller.ads_blend
	var scale_factor = lerp(1.0, 0.5, ads_blend)
	crosshair.scale = Vector2.ONE * scale_factor

func _update_crosshair():
	# Hide crosshair when no weapon
	crosshair.visible = player.current_weapon != null

	# Change crosshair color based on state
	var movement_state = player.get_movement_state()
	var is_aiming = movement_state.get("is_aiming", false)
	var is_sprinting = movement_state.get("is_sprinting", false)

	if is_aiming:
		crosshair.modulate = Color.GREEN
	elif is_sprinting:
		crosshair.modulate = Color.ORANGE
	else:
		crosshair.modulate = Color.WHITE

func show_interaction_prompt(text: String):
	interaction_prompt.text = text
	interaction_prompt.visible = true

func hide_interaction_prompt():
	interaction_prompt.visible = false

func _on_weapon_changed(weapon: Weapon):
	if weapon:
		_flash_element(weapon_label)

func _on_stance_changed(_old_stance, _new_stance):
	_flash_element(stance_label)

func _on_interaction_available(prompt: String):
	show_interaction_prompt(prompt)

func _on_interaction_unavailable():
	hide_interaction_prompt()

func _flash_element(element: Control):
	var tween = create_tween()
	tween.tween_property(element, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(element, "modulate", Color.WHITE, 0.2)

func show_damage_indicator():
	# Flash red edges
	var damage_overlay = $DamageOverlay
	if damage_overlay:
		damage_overlay.modulate = Color(1, 0, 0, 0.3)
		var tween = create_tween()
		tween.tween_property(damage_overlay, "modulate:a", 0.0, 0.5)
