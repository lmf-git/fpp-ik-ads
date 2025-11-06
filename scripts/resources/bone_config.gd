extends Resource
class_name BoneConfig

## Centralized bone name configuration
## Eliminates hardcoded strings throughout the codebase

@export_group("Head & Spine")
@export var head: StringName = &"characters3d.com___Head"
@export var neck: StringName = &"characters3d.com___Neck"
@export var spine: StringName = &"characters3d.com___Spine"
@export var spine1: StringName = &"characters3d.com___Spine1"
@export var spine2: StringName = &"characters3d.com___Spine2"
@export var hips: StringName = &"characters3d.com___Hips"

@export_group("Left Arm")
@export var l_shoulder: StringName = &"characters3d.com___L_Shoulder"
@export var l_upper_arm: StringName = &"characters3d.com___L_Upper_Arm"
@export var l_lower_arm: StringName = &"characters3d.com___L_Lower_Arm"
@export var l_hand: StringName = &"characters3d.com___L_Hand"

@export_group("Right Arm")
@export var r_shoulder: StringName = &"characters3d.com___R_Shoulder"
@export var r_upper_arm: StringName = &"characters3d.com___R_Upper_Arm"
@export var r_lower_arm: StringName = &"characters3d.com___R_Lower_Arm"
@export var r_hand: StringName = &"characters3d.com___R_Hand"

@export_group("Left Leg")
@export var l_upper_leg: StringName = &"characters3d.com___L_Upper_Leg"
@export var l_lower_leg: StringName = &"characters3d.com___L_Lower_Leg"
@export var l_foot: StringName = &"characters3d.com___L_Foot"

@export_group("Right Leg")
@export var r_upper_leg: StringName = &"characters3d.com___R_Upper_Leg"
@export var r_lower_leg: StringName = &"characters3d.com___R_Lower_Leg"
@export var r_foot: StringName = &"characters3d.com___R_Foot"

## Get bone index from skeleton with error checking
func get_bone_index(skeleton: Skeleton3D, bone_name: StringName) -> int:
	if not skeleton:
		push_error("BoneConfig: Skeleton is null")
		return -1

	var idx := skeleton.find_bone(bone_name)
	if idx == -1:
		push_warning("BoneConfig: Bone '%s' not found in skeleton" % bone_name)
	return idx

## Get all main body bones for ragdoll generation
func get_ragdoll_bones() -> Array[StringName]:
	return [
		hips, spine, spine1, neck, head,
		l_shoulder, l_upper_arm, l_lower_arm, l_hand,
		r_shoulder, r_upper_arm, r_lower_arm, r_hand,
		l_upper_leg, l_lower_leg, l_foot,
		r_upper_leg, r_lower_leg, r_foot
	]

## Get limb bones by name
func get_limb_bones(limb: StringName) -> Array[StringName]:
	match limb:
		&"left_arm":
			return [l_shoulder, l_upper_arm, l_lower_arm, l_hand]
		&"right_arm":
			return [r_shoulder, r_upper_arm, r_lower_arm, r_hand]
		&"left_leg":
			return [l_upper_leg, l_lower_leg, l_foot]
		&"right_leg":
			return [r_upper_leg, r_lower_leg, r_foot]
		_:
			push_warning("BoneConfig: Unknown limb '%s'" % limb)
			return []
