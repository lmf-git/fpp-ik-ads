extends StaticBody3D
class_name WeaponPickup

## Pickup object for weapons in the world

@export var weapon_scene: PackedScene
@export var weapon_name: String = "Weapon"
@export var rotate_speed: float = 45.0  # Degrees per second
@export var bob_amount: float = 0.1
@export var bob_speed: float = 2.0

var time: float = 0.0
var original_y: float = 0.0

@onready var label: Label3D = $Label3D

func _ready():
	original_y = position.y

	# Add to interaction group
	add_to_group("interactable")

	# Update label with weapon name
	if label:
		label.text = "[E] %s" % weapon_name

func _process(delta):
	time += delta

	# Rotate slowly
	rotate_y(deg_to_rad(rotate_speed) * delta)

	# Bob up and down
	position.y = original_y + sin(time * bob_speed) * bob_amount
