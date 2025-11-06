extends Node3D
class_name RagdollTest

## Simple ragdoll testing script focused on skeleton and physics
##
## Controls:
## - R: Toggle ragdoll on/off
## - Space: Reset character position

@export var character_model_path: String = "res://characters/Superhero_Male.gltf"
var character_model: Node3D
var skeleton_3d: Skeleton3D
var is_ragdoll_active: bool = false

func _ready():
	print("=== RAGDOLL TEST STARTING ===")
	load_character()

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				toggle_ragdoll()
			KEY_SPACE:
				reset_character()

func load_character():
	"""Load the current character model"""
	# Clear existing character
	if character_model:
		character_model.queue_free()
		await character_model.tree_exited

	# Load new character
	var scene = load(character_model_path)
	character_model = scene.instantiate()
	add_child(character_model)

	# Find skeleton
	skeleton_3d = find_skeleton(character_model)
	if skeleton_3d:
		print("Found skeleton with ", skeleton_3d.get_bone_count(), " bones")
		setup_ragdoll_system()
	else:
		print("ERROR: No skeleton found in character model")

func find_skeleton(node: Node) -> Skeleton3D:
	"""Recursively find Skeleton3D in the character model"""
	if node is Skeleton3D:
		return node

	for child in node.get_children():
		var result = find_skeleton(child)
		if result:
			return result

	return null

func setup_ragdoll_system():
	"""Set up physics bones for ragdoll"""
	if not skeleton_3d:
		return

	print("Setting up ragdoll system...")

	# Clear any existing physical bones
	remove_all_physical_bones()

	# Create physical bones for main body parts
	var important_bones = [
		"pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
		"clavicle_l", "clavicle_r",
		"upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
		"hand_l", "hand_r",
		"thigh_l", "thigh_r", "calf_l", "calf_r",
		"foot_l", "foot_r"
	]

	for i in range(skeleton_3d.get_bone_count()):
		var bone_name = skeleton_3d.get_bone_name(i)
		if bone_name in important_bones:
			create_physical_bone(i, bone_name)

	# Stop physics simulation initially
	skeleton_3d.physical_bones_stop_simulation()
	print("Ragdoll system ready (inactive)")

func create_physical_bone(bone_idx: int, bone_name: String):
	"""Create a simple, stable physical bone"""
	var physical_bone = PhysicalBone3D.new()
	physical_bone.name = "PhysicalBone_" + bone_name
	physical_bone.bone_name = bone_name

	# Create appropriately sized collision shapes to prevent crumpling
	var shape = CapsuleShape3D.new()
	var bone_name_lower = bone_name.to_lower()

	if "head" in bone_name_lower:
		shape = SphereShape3D.new()
		shape.radius = 0.12  # Larger head
	elif "pelvis" in bone_name_lower:
		shape.radius = 0.12  # Wider pelvis
		shape.height = 0.2
	elif "spine" in bone_name_lower:
		shape.radius = 0.08  # Wider spine
		shape.height = 0.15
	elif "neck" in bone_name_lower:
		shape.radius = 0.05
		shape.height = 0.1
	elif "thigh" in bone_name_lower:
		shape.radius = 0.08  # Thick thighs
		shape.height = 0.3
	elif "upperarm" in bone_name_lower:
		shape.radius = 0.06  # Thicker upper arms
		shape.height = 0.25
	elif "calf" in bone_name_lower:
		shape.radius = 0.06  # Thicker calves
		shape.height = 0.25
	elif "lowerarm" in bone_name_lower:
		shape.radius = 0.05  # Thicker forearms
		shape.height = 0.2
	elif "clavicle" in bone_name_lower:
		shape.radius = 0.04
		shape.height = 0.15
	else:
		shape.radius = 0.04
		shape.height = 0.1

	var collision = CollisionShape3D.new()
	collision.shape = shape
	physical_bone.add_child(collision)

	# Adjusted physics properties to prevent crumpling
	var bone_mass = 1.0
	if "pelvis" in bone_name_lower:
		bone_mass = 3.0  # Heavy center
	elif "head" in bone_name_lower:
		bone_mass = 2.0  # Heavy head
	elif "thigh" in bone_name_lower:
		bone_mass = 2.5  # Heavy thighs
	elif "spine" in bone_name_lower:
		bone_mass = 2.0  # Heavy spine
	else:
		bone_mass = 1.0

	physical_bone.mass = bone_mass
	physical_bone.friction = 0.7
	physical_bone.bounce = 0.0
	physical_bone.linear_damp = 0.1  # Less damping for more natural movement
	physical_bone.angular_damp = 0.3

	# Set collision layers - importantly, enable self-collision for structure
	physical_bone.collision_layer = 8  # Ragdoll layer
	physical_bone.collision_mask = 1 + 2 + 8  # Collide with default, environment, AND other ragdoll parts

	# Configure joint types with proper anatomical limits
	if "lowerarm" in bone_name_lower:
		# Elbows - hinge joint (only bends one way)
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.98
	elif "calf" in bone_name_lower:
		# Knees - 6DOF joint with strict constraints to prevent backwards bending
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.98
		# Prevent linear movement
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.005)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.005)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.005)
		# Knee movement - only allow forward bending, NO backwards bending
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(120)) # Forward bend only
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(0))   # NO backwards bend
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(5))   # Minimal side movement
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-5))  # Minimal side movement
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(5))   # Minimal twist
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-5))  # Minimal twist
	elif "head" in bone_name_lower:
		# Head - 6DOF joint with tight limits for natural movement
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.98
		# Tight rotation limits for head
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.01)
		# Angular limits for natural head movement
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(30))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-30))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(45))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-45))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(20))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-20))
	elif "neck" in bone_name_lower:
		# Neck - 6DOF joint with very limited movement
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.85
		physical_bone.angular_damp = 0.96
		# Very tight limits for neck stability
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.005)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.005)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.005)
		# Limited neck rotation
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(15))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-15))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(20))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-20))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(10))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-10))
	elif "spine" in bone_name_lower:
		# Spine - 6DOF joint with soft limits for natural torso movement
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.8
		physical_bone.angular_damp = 0.9
		# Prevent linear movement but allow slight compression
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.02)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.02)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.02)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.02)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.02)
		# Restricted spine rotation limits - match leg constraints
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(15))  # Reduced forward bend
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-15)) # Reduced back bend
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(20))  # Reduced side bend
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-20)) # Reduced side bend
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(8))   # Much reduced rotation
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-8))  # Much reduced rotation
	elif "pelvis" in bone_name_lower:
		# Pelvis - 6DOF joint (anchor point) with minimal movement
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.95
		# Very tight limits for pelvis stability
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.01)
		# Limited pelvis rotation
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(20))
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-20))
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(15))
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-15))
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(10))
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-10))
	elif "upperarm" in bone_name_lower:
		# Upper arms - 6DOF joint with anatomical limits
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.8
		physical_bone.angular_damp = 0.95
		# Prevent linear movement
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.01)
		# Restricted shoulder movement to prevent body clipping
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(70))  # Reduced upward swing
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-20)) # Reduced backward swing
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(45))  # Reduced outward swing
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-15)) # Prevent inward clipping
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(60))  # Reduced rotation
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-20)) # Prevent twist clipping
	elif "thigh" in bone_name_lower:
		# Thighs - 6DOF joint with tight hip constraints
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.85
		physical_bone.angular_damp = 0.95
		# Prevent linear movement
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.01)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.01)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.01)
		# Hip movement - prevent excessive sideways bending
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(70))  # Forward leg swing
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-20)) # Backward limit
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(25))  # Sideways spread limit
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-25)) # Sideways spread limit
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(15))  # Hip rotation limit
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-15)) # Hip rotation limit
	elif "hand" in bone_name_lower:
		# Hands - 6DOF joint with tight wrist constraints
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.98
		# Prevent linear movement
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.002)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.002)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.002)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.002)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.002)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.002)
		# Very restricted wrist movement - no spinning
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(20))  # Wrist up
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-30)) # Wrist down
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(15))  # Side bend
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-15)) # Side bend
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(10))  # NO spinning
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-10)) # NO spinning
	elif "foot" in bone_name_lower:
		# Feet - 6DOF joint with tight ankle constraints
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		physical_bone.linear_damp = 0.9
		physical_bone.angular_damp = 0.95
		# Prevent linear movement
		physical_bone.set("joint_constraints/linear_limit_x/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_x/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_x/lower_limit", -0.005)
		physical_bone.set("joint_constraints/linear_limit_y/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_y/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_y/lower_limit", -0.005)
		physical_bone.set("joint_constraints/linear_limit_z/enabled", true)
		physical_bone.set("joint_constraints/linear_limit_z/upper_limit", 0.005)
		physical_bone.set("joint_constraints/linear_limit_z/lower_limit", -0.005)
		# Ankle movement - very limited to prevent spinning
		physical_bone.set("joint_constraints/angular_limit_x/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_x/upper_limit", deg_to_rad(15))  # Toe up
		physical_bone.set("joint_constraints/angular_limit_x/lower_limit", deg_to_rad(-30)) # Toe down
		physical_bone.set("joint_constraints/angular_limit_y/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_y/upper_limit", deg_to_rad(10))  # Foot tilt
		physical_bone.set("joint_constraints/angular_limit_y/lower_limit", deg_to_rad(-10)) # Foot tilt
		physical_bone.set("joint_constraints/angular_limit_z/enabled", true)
		physical_bone.set("joint_constraints/angular_limit_z/upper_limit", deg_to_rad(5))   # Minimal twist
		physical_bone.set("joint_constraints/angular_limit_z/lower_limit", deg_to_rad(-5))  # Minimal twist
	elif "clavicle" in bone_name_lower:
		# Shoulders - PIN joint for stability
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_PIN
		physical_bone.linear_damp = 0.6
		physical_bone.angular_damp = 0.8
	else:
		# Default - PIN joint with moderate damping
		physical_bone.joint_type = PhysicalBone3D.JOINT_TYPE_PIN
		physical_bone.linear_damp = 0.5
		physical_bone.angular_damp = 0.7

	# Add to skeleton
	skeleton_3d.add_child(physical_bone)
	print("Created physics bone: ", bone_name)

func remove_all_physical_bones():
	"""Remove all existing physical bones"""
	if not skeleton_3d:
		return

	for child in skeleton_3d.get_children():
		if child is PhysicalBone3D:
			child.queue_free()

func toggle_ragdoll():
	"""Toggle ragdoll physics on/off"""
	if not skeleton_3d:
		return

	is_ragdoll_active = not is_ragdoll_active

	if is_ragdoll_active:
		print("ACTIVATING RAGDOLL")
		skeleton_3d.physical_bones_start_simulation()
	else:
		print("DEACTIVATING RAGDOLL")
		skeleton_3d.physical_bones_stop_simulation()

func reset_character():
	"""Reset character to upright position"""
	position = Vector3.ZERO
	rotation = Vector3.ZERO

	if is_ragdoll_active:
		toggle_ragdoll()  # Turn off ragdoll
		await get_tree().process_frame
		toggle_ragdoll()  # Turn back on

	print("Character reset")
