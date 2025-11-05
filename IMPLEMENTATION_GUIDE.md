# Implementation Guide - FPP IK ADS System

This guide provides detailed instructions for implementing and extending the FPP IK ADS system in your own projects.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [IK Mathematics](#ik-mathematics)
3. [ADS Implementation](#ads-implementation)
4. [Integration with Animations](#integration-with-animations)
5. [Advanced Features](#advanced-features)
6. [Common Issues](#common-issues)

---

## System Architecture

### Component Hierarchy

The system uses a modular architecture where each component has a specific responsibility:

```
┌─────────────────────────────────────┐
│   CharacterController (Physics)     │
│  - Movement & collision             │
│  - Input handling                   │
└──────────┬──────────────────────────┘
           │
           ├── Camera System
           │   - Head tracking
           │   - FOV transitions
           │   - Procedural effects
           │
           ├── IK System
           │   - Arm chains
           │   - Hand positioning
           │   - Pole vectors
           │
           ├── ADS System
           │   - Sight alignment
           │   - State blending
           │   - Speed modifiers
           │
           └── Weapon System
               - Recoil
               - Sway & inertia
               - Attachments
```

### Data Flow

```
Input → Controller → Camera Rotation → Body Rotation
                   ↓
              IK Updates → Hand Positions
                   ↓
              ADS State → Sight Alignment
                   ↓
           Procedural FX → Final Render
```

---

## IK Mathematics

### Two-Bone IK Algorithm

The `SimpleIKChain` uses the **law of cosines** to solve for joint angles.

#### Problem Setup

Given:
- `a` = length from shoulder to elbow (upper arm)
- `b` = length from elbow to hand (forearm)
- `c` = distance from shoulder to target (reach)

Find: angles for shoulder and elbow joints

#### Solution

**Step 1: Calculate elbow angle (β)**

Using the law of cosines for the triangle formed by the arm:

```
b² = a² + c² - 2ac·cos(β)

cos(β) = (a² + c² - b²) / (2ac)

β = arccos((a² + c² - b²) / (2ac))
```

**Step 2: Calculate shoulder angle (α)**

```
c² = a² + b² - 2ab·cos(α)

cos(α) = (a² + b² - c²) / (2ab)

α = arccos((a² + b² - c²) / (2ab))
```

**Step 3: Apply rotations**

```gdscript
# In world space
var direction_to_target = (target_pos - shoulder_pos).normalized()

# Create basis for shoulder
var forward = direction_to_target
var right = forward.cross(pole_direction).normalized()
var up = right.cross(forward).normalized()

shoulder_basis = Basis(right, up, -forward)
shoulder_basis = shoulder_basis.rotated(right, -shoulder_angle)

# Elbow bends along the plane
elbow_basis = elbow_basis.rotated(right, PI - elbow_angle)
```

#### Handling Edge Cases

```gdscript
# Target too far (unreachable)
if target_distance > total_arm_length:
    target_distance = total_arm_length * 0.99  # Almost fully extended

# Target too close (collapsed)
if target_distance < abs(upper_length - lower_length):
    target_distance = abs(upper_length - lower_length) * 1.01

# Prevent NaN from arccos
cos_value = clamp(cos_value, -1.0, 1.0)
```

### Pole Vectors

Pole vectors determine which direction the elbow points:

```gdscript
# Without pole vector: elbow direction is ambiguous
# With pole vector: elbow points toward pole target

var to_pole = pole_target.global_position - shoulder.global_position
var pole_direction = to_pole.normalized()

# This becomes the "up" direction when calculating shoulder rotation
var right = forward.cross(pole_direction).normalized()
```

**Practical tip**: Place pole targets slightly in front and to the side of shoulders for natural arm posture.

---

## ADS Implementation

### Sight Alignment Theory

The goal is to make the weapon's sight appear at the exact center of the screen when aiming.

#### Method 1: Camera Movement (Used in this project)

Move the camera to align with the sight:

```gdscript
# Calculate where sight is relative to camera
var sight_local = camera.to_local(sight.global_position)

# Offset camera by inverse of this
camera.position = original_position - (sight_local * ads_blend)
```

**Pros**:
- Simple to implement
- Works without changing weapon position
- Smooth transitions

**Cons**:
- Camera moves off-center from head
- May feel slightly disconnected

#### Method 2: Weapon Movement (Alternative)

Move the weapon so sight aligns with camera:

```gdscript
# Calculate offset needed
var camera_center_world = camera.project_ray_origin(viewport_center)
var sight_to_center = camera_center_world - sight.global_position

# Move weapon by this offset
weapon.global_position += sight_to_center * ads_blend
```

**Pros**:
- Camera stays centered on head
- More realistic feeling

**Cons**:
- Weapon moves independently of hand
- Requires IK adjustment

#### Hybrid Approach (Best)

Combination of both:

```gdscript
# Move camera 70%
camera.position -= sight_offset * 0.7 * ads_blend

# Move weapon 30%
weapon.position += sight_offset * 0.3 * ads_blend
```

### FOV Transition

```gdscript
# Linear interpolation (simple)
camera.fov = lerp(hipfire_fov, ads_fov, ads_blend)

# Smoothstep (more natural)
camera.fov = lerp(hipfire_fov, ads_fov, smoothstep(0.0, 1.0, ads_blend))

# Ease-out (fast start, slow end)
var eased = ease(ads_blend, -2.0)
camera.fov = lerp(hipfire_fov, ads_fov, eased)
```

### State Management

```gdscript
enum ADSState {
    HIPFIRE,
    TRANSITIONING_IN,
    ADS,
    TRANSITIONING_OUT
}

var ads_state = ADSState.HIPFIRE

func _process(delta):
    match ads_state:
        ADSState.HIPFIRE:
            if Input.is_action_pressed("aim"):
                ads_state = ADSState.TRANSITIONING_IN

        ADSState.TRANSITIONING_IN:
            ads_blend += delta * ads_speed
            if ads_blend >= 1.0:
                ads_blend = 1.0
                ads_state = ADSState.ADS

        ADSState.ADS:
            if not Input.is_action_pressed("aim"):
                ads_state = ADSState.TRANSITIONING_OUT

        ADSState.TRANSITIONING_OUT:
            ads_blend -= delta * ads_speed
            if ads_blend <= 0.0:
                ads_blend = 0.0
                ads_state = ADSState.HIPFIRE
```

---

## Integration with Animations

### Animation Tree Setup

For production use, integrate with Godot's AnimationTree:

```
AnimationTree
├── StateMachine (Locomotion)
│   ├── Idle
│   ├── WalkBlendSpace2D
│   │   ├── WalkForward
│   │   ├── WalkBackward
│   │   ├── StrafeLeft
│   │   └── StrafeRight
│   ├── Run
│   └── Crouch
│
└── AnimationNodeAdd2
    ├── Base: Locomotion
    └── Add: UpperBody
        ├── BlendSpace2D (Aim Offset)
        │   ├── LookUp (-80°)
        │   ├── LookCenter (0°)
        │   └── LookDown (80°)
        └── AnimationNodeBlend2
            ├── A: AimPose
            └── B: IK Override
```

### Setting up Bone Masks

```gdscript
# Create animation tree
@onready var anim_tree = $AnimationTree
@onready var state_machine = anim_tree.get("parameters/playback")

# Setup bone mask for upper body
func _ready():
    var upper_body_mask = AnimationNodeStateMachinePlayback.new()

    # Exclude lower body bones from upper body animations
    for bone in ["Hip", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]:
        anim_tree.set_bone_mask(bone, false)  # Don't affect these bones
```

### Blending Animation with IK

```gdscript
# In your character controller
@export var ik_blend: float = 0.5  # 0 = full animation, 1 = full IK

func _process(delta):
    # Apply animation first
    anim_tree.advance(delta)

    # Then apply IK on top
    if right_hand_ik:
        right_hand_ik.blend_amount = ik_blend

    # Increase IK blend during ADS
    var target_ik = lerp(0.5, 1.0, ads_blend)
    ik_blend = lerp(ik_blend, target_ik, 5.0 * delta)
```

### Aim Offset Implementation

Create a 2D blend space for aiming:

```gdscript
# Calculate aim angles
var pitch = camera_x_rotation  # -80 to +80
var yaw = camera_y_rotation  # -180 to +180

# Normalize to -1..1 range
var aim_x = yaw / PI
var aim_y = pitch / (PI / 2)

# Set blend space position
anim_tree.set("parameters/AimOffset/blend_position", Vector2(aim_x, aim_y))
```

---

## Advanced Features

### Foot IK for Uneven Terrain

Extend the IK system to include feet:

```gdscript
class FootIK extends Node3D:
    @export var foot_bone: Node3D
    @export var raycast: RayCast3D
    @export var max_step_height: float = 0.3

    func _physics_process(delta):
        if raycast.is_colliding():
            var hit_point = raycast.get_collision_point()
            var target_y = hit_point.y

            # Smoothly move foot to ground
            foot_bone.global_position.y = lerp(
                foot_bone.global_position.y,
                target_y,
                10.0 * delta
            )

            # Rotate foot to match ground normal
            var normal = raycast.get_collision_normal()
            foot_bone.global_transform.basis = Basis.looking_at(normal)
```

### Look-at IK for Head

Make the head track targets:

```gdscript
@export var look_target: Node3D
@export var look_speed: float = 5.0
@export var max_look_angle: float = 60.0

func _process(delta):
    if look_target:
        var to_target = look_target.global_position - head.global_position
        var target_rotation = head.global_transform.looking_at(
            look_target.global_position,
            Vector3.UP
        )

        # Clamp rotation
        var angle = head.rotation.angle_to(target_rotation.basis.get_euler())
        if angle < deg_to_rad(max_look_angle):
            head.rotation = head.rotation.slerp(
                target_rotation.basis.get_euler(),
                look_speed * delta
            )
```

### Procedural Leaning

Add Q/E leaning:

```gdscript
@export var lean_angle: float = 30.0
@export var lean_speed: float = 5.0
var current_lean: float = 0.0

func _process(delta):
    var target_lean = 0.0

    if Input.is_action_pressed("lean_left"):
        target_lean = -lean_angle
    elif Input.is_action_pressed("lean_right"):
        target_lean = lean_angle

    current_lean = lerp(current_lean, target_lean, lean_speed * delta)

    # Apply to spine
    spine.rotation_degrees.z = current_lean

    # Offset camera to side
    camera.position.x = -current_lean * 0.01
```

### Weapon Collision

Prevent weapon clipping through walls:

```gdscript
@export var weapon: Node3D
@export var weapon_length: float = 0.8
var collision_pushback: float = 0.0

func _physics_process(delta):
    # Raycast from camera forward
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(
        camera.global_position,
        camera.global_position + camera.global_transform.basis.z * weapon_length
    )

    var result = space_state.intersect_ray(query)

    if result:
        # Calculate how much to push weapon back
        var hit_distance = camera.global_position.distance_to(result.position)
        collision_pushback = (weapon_length - hit_distance) / weapon_length
    else:
        collision_pushback = 0.0

    # Smoothly push weapon back
    weapon.position.z = lerp(
        weapon.position.z,
        -collision_pushback * 0.3,
        10.0 * delta
    )
```

---

## Common Issues

### Issue: IK causes jittering

**Cause**: Solver iterating too fast or pole vector unstable

**Solution**:
```gdscript
# Add damping to IK
right_hand_ik.blend_amount = lerp(
    right_hand_ik.blend_amount,
    target_blend,
    5.0 * delta  # Slower blend
)

# Stabilize pole vector
pole_target.global_position = pole_target.global_position.lerp(
    calculate_stable_pole_position(),
    10.0 * delta
)
```

### Issue: Hands not reaching weapon grip

**Cause**: Arm length vs. weapon position mismatch

**Solution**:
```gdscript
# Ensure weapon is within reach
var shoulder_to_grip = right_shoulder.global_position.distance_to(
    weapon_grip.global_position
)
var max_arm_length = upper_arm_length + forearm_length

if shoulder_to_grip > max_arm_length * 0.98:
    # Move weapon closer
    weapon.position.z += (shoulder_to_grip - max_arm_length * 0.98)
```

### Issue: Camera clips through geometry

**Cause**: Camera inside collision shapes

**Solution**:
```gdscript
# Add collision check for camera
var camera_ray = PhysicsRayQueryParameters3D.create(
    head.global_position,
    camera.global_position
)
var hit = space_state.intersect_ray(camera_ray)

if hit:
    # Pull camera forward
    camera.position.z = head.to_local(hit.position).z + 0.1
```

### Issue: ADS sight not perfectly centered

**Cause**: Rounding errors or incorrect local space calculation

**Solution**:
```gdscript
# Use viewport center as reference
var viewport_center = get_viewport().get_visible_rect().size / 2
var sight_screen_pos = camera.unproject_position(ads_sight.global_position)

var offset = viewport_center - sight_screen_pos
# Adjust camera until offset is near zero
```

### Issue: Animation and IK fighting each other

**Cause**: Both trying to control the same bones

**Solution**:
```gdscript
# Apply animation first, IK second
func _process(delta):
    anim_tree.advance(delta)  # Animation updates bones

    # Force update transforms
    get_tree().physics_frame

    # Then apply IK
    right_hand_ik.solve_ik()  # IK overrides bones
```

---

## Performance Optimization

### Reduce IK Updates

```gdscript
# Only update IK when needed
var ik_update_interval: float = 0.016  # ~60 FPS
var time_since_ik_update: float = 0.0

func _process(delta):
    time_since_ik_update += delta

    if time_since_ik_update >= ik_update_interval:
        right_hand_ik.solve_ik()
        left_hand_ik.solve_ik()
        time_since_ik_update = 0.0
```

### LOD for Distant Characters

```gdscript
# Disable IK for far away characters
func _process(delta):
    var distance_to_camera = global_position.distance_to(active_camera.global_position)

    if distance_to_camera > 20.0:
        enable_ik = false  # Use animation only
    else:
        enable_ik = true
```

---

## Debugging Tools

### Visual IK Debug

```gdscript
func _draw_ik_debug():
    # Draw skeleton lines
    debug_draw_line(shoulder.global_position, elbow.global_position, Color.RED)
    debug_draw_line(elbow.global_position, hand.global_position, Color.GREEN)
    debug_draw_line(hand.global_position, ik_target.global_position, Color.BLUE)

    # Draw target sphere
    debug_draw_sphere(ik_target.global_position, 0.05, Color.YELLOW)

    # Draw pole target
    debug_draw_sphere(pole_target.global_position, 0.05, Color.CYAN)
```

### Print IK Info

```gdscript
func _debug_print_ik():
    print("=== IK Debug ===")
    print("Target Distance: ", shoulder.global_position.distance_to(ik_target.global_position))
    print("Max Reach: ", upper_length + lower_length)
    print("Shoulder Angle: ", rad_to_deg(shoulder_angle))
    print("Elbow Angle: ", rad_to_deg(elbow_angle))
    print("Blend Amount: ", ik_blend_amount)
```

---

## Next Steps

1. **Add Animation Tree** with proper blend spaces
2. **Implement Skeleton3D** and replace node-based bones
3. **Create Multiple Weapons** with different IK points
4. **Add Reloading** with procedural magazine handling
5. **Implement Contextual Actions** (climbing, vaulting)

This system provides a solid foundation for a full-featured first-person shooter with realistic character handling!
