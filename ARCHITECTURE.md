# FPP IK ADS System - Architecture Overview

## Component-Based Architecture (Godot 4.5 Best Practices)

This project follows a clean, component-based architecture inspired by:
- **ARMA 3**: Modular systems with clear responsibilities
- **GTA V**: Smooth transitions and procedural animation
- **Outer Wilds**: Event-driven, decoupled components
- **Godot 4.5**: Modern best practices (Resources, Signals, @onready)

---

## Core Philosophy

### 1. **Separation of Concerns**
Each component handles ONE responsibility:
- `CameraControllerComponent`: Camera rotation, freelook, FOV
- `MovementControllerComponent`: Physics, input, movement
- `RagdollControllerRefactored`: Ragdoll physics with data-driven configuration
- `IKLocomotion`: Procedural animation via IK

### 2. **Resource-Based Configuration**
Configuration data lives in reusable Resources:
- `BoneConfig`: Centralized bone names (eliminates hardcoded strings)
- `CharacterConfig`: Movement speeds, camera settings, physics parameters

### 3. **Event-Driven Communication**
Components communicate via **Signals** (not direct coupling):
```gdscript
# Movement emits signals
movement_controller.stance_changed.emit(old, new)
movement_controller.jumped.emit()

# Main controller orchestrates
func _on_stance_changed(old, new):
    ik_locomotion.set_stance_crouch()
```

### 4. **State Machine Pattern**
Complex state transitions use proper State Machines:
- `WeaponSwapStateMachine`: idle → lowering → switching → raising
- Clean state transitions with enter/exit/update methods

---

## Component Hierarchy

```
CharacterControllerMain (CharacterBody3D)
├── CameraControllerComponent
│   ├── Handles: Mouse look, freelook, FPS/third-person
│   ├── Emits: freelook_changed, camera_mode_changed
│   └── Updates: Head/spine bone rotations
│
├── MovementControllerComponent
│   ├── Handles: Input, physics movement, stance
│   ├── Emits: stance_changed, jumped
│   └── Uses: CharacterConfig for speeds
│
├── RagdollControllerRefactored
│   ├── Handles: Full/partial ragdoll with joint constraints
│   ├── Emits: ragdoll_enabled, ragdoll_disabled
│   └── Uses: BoneConfig + data-driven joint configuration
│
├── IKLocomotion
│   ├── Handles: Procedural walking, jumping, get-up, damage reactions
│   ├── Creates: Foot/hand IK chains and targets
│   └── Toggleable: M key to switch animation/IK modes
│
└── WeaponSwapStateMachine (future)
    ├── States: Idle, Lowering, Switching, Raising
    └── Smooth procedural weapon swap animations
```

---

## Data Flow

### Input Flow
```
User Input
    ↓
CharacterControllerMain._input()
    ↓
Component Methods (camera.handle_mouse_look(), etc.)
    ↓
Component Signals (stance_changed, jumped)
    ↓
Main Controller Orchestration (_on_stance_changed)
    ↓
Other Components Updated (ik_locomotion.set_stance_crouch())
```

### Physics/Process Flow
```
_physics_process:
    MovementController → applies velocity to CharacterBody3D

_process:
    CameraController → updates head/spine bones
    IKLocomotion → updates foot/hand IK targets
    Main Controller → checks interactions, updates ADS
```

---

## Key Design Patterns

### 1. **Composition Over Inheritance**
- Character has components (not IS A movement controller)
- Each component is independent and reusable
- Easy to test components in isolation

### 2. **Dependency Injection**
```gdscript
# Resources injected at design time
@export var config: CharacterConfig
@export var bone_config: BoneConfig

# Components get what they need
camera_controller.config = config
camera_controller.bone_config = bone_config
```

### 3. **Observer Pattern** (Signals)
```gdscript
# Components emit events
signal stance_changed(old_stance: int, new_stance: int)

# Main controller observes
movement_controller.stance_changed.connect(_on_stance_changed)
```

### 4. **State Pattern** (Weapon Swap)
```gdscript
class WeaponSwapState extends Node:
    func enter() -> void: pass
    func exit() -> void: pass
    func update(delta: float) -> void: pass

# Clean transitions
transition_to(&"lowering")
```

---

## Godot 4.5 Best Practices Applied

### 1. **@onready for Node References**
```gdscript
# OLD (bad):
var skeleton: Skeleton3D
func _ready():
    skeleton = get_node("Skeleton3D")

# NEW (good):
@onready var skeleton: Skeleton3D = %Skeleton3D  # Unique name
```

### 2. **StringName (&"") for Performance**
```gdscript
# OLD: "characters3d.com___Head" (String, slower)
# NEW: &"characters3d.com___Head" (StringName, faster hashing)
```

### 3. **Typed GDScript**
```gdscript
# Everything is typed for performance and safety
var bones: Array[StringName]  # Not just Array
func get_speed() -> float:  # Return type
var config: CharacterConfig  # Resource type
```

### 4. **Resource-Based Config**
```gdscript
# Configuration lives in .tres files
# Shareable between characters
# Editable in inspector without code changes
```

### 5. **Signals for Decoupling**
```gdscript
# Components never call each other directly
# Main controller orchestrates via signal handlers
```

### 6. **Unique Node Names (%)**
```gdscript
# Reliable node access even if hierarchy changes
@onready var skeleton: Skeleton3D = %Skeleton3D
```

---

## Performance Optimizations

### 1. **Cached Bone Indices**
```gdscript
var _head_bone_idx: int = -1  # Cached in _ready()
# Avoids repeated skeleton.find_bone() calls
```

### 2. **Data-Driven Joint Configuration**
```gdscript
const JOINT_CONFIGS := {  # Compile-time constant
    &"head": { ... },
    &"neck": { ... }
}
# No repeated code, easy to tune
```

### 3. **Component Process Modes**
```gdscript
# Disable components when not needed
movement_controller.process_mode = Node.PROCESS_MODE_DISABLED
```

### 4. **Forward+ Renderer Optimizations**
- Skeletal animations handled by GPU
- Minimal bone updates from script
- IK only when mode enabled
- Efficient ragdoll with proper collision masks

---

## Future Improvements

### 1. **Animation Tree**
- Replace AnimationPlayer with AnimationTree
- Blend between animations smoothly
- Procedural animation blending

### 2. **Network Synchronization**
- Component state is already separated
- Easy to add MultiplayerSynchronizer nodes
- Signal-based events map naturally to RPCs

### 3. **Save/Load System**
- Component state → Dictionary → JSON
- Resource-based config already serializable

### 4. **AI Controller**
- Replace input with AIController component
- Same signals, different input source
- Can test in editor with AIController

---

## File Structure

```
scripts/
├── character_controller_main.gd      # Main orchestrator
├── components/
│   ├── camera_controller_component.gd
│   ├── movement_controller_component.gd
│   ├── ragdoll_controller_refactored.gd
│   └── (future: weapon_controller_component.gd)
├── resources/
│   ├── bone_config.gd               # Resource class
│   ├── character_config.gd          # Resource class
│   └── (instances in res://config/)
├── state_machines/
│   ├── weapon_swap_state.gd         # Base state
│   └── weapon_swap_state_machine.gd # State machine + concrete states
└── ik_locomotion.gd                 # IK-based procedural animation
```

---

## Testing Strategy

### Unit Testing (Components)
Each component can be tested in isolation:
```gdscript
# Test MovementComponent alone
var movement = MovementControllerComponent.new()
movement.config = test_config
assert(movement.get_speed() == expected)
```

### Integration Testing (Main Controller)
Test component orchestration:
```gdscript
# Test stance change triggers IK update
emit_signal("stance_changed", 0, 1)
assert(ik_locomotion.target_offset == -0.5)
```

### Scene Testing
- Create test scenes with single components
- Verify signals fire correctly
- Check state transitions

---

## Comparison: Before vs After

### Before (Monolithic)
```gdscript
# skeleton_fpp_controller.gd (756 lines)
extends CharacterBody3D

# Everything in one file:
# - Camera rotation (100 lines)
# - Movement (150 lines)
# - Weapon system (200 lines)
# - IK (100 lines)
# - Ragdoll (100 lines)
# - Interactions (50 lines)
# - Procedural effects (56 lines)

# Hard to test, hard to reuse, hard to maintain
```

### After (Component-Based)
```gdscript
# character_controller_main.gd (300 lines)
extends CharacterBody3D

# Clean orchestration:
@onready var camera: CameraControllerComponent = $Camera
@onready var movement: MovementControllerComponent = $Movement

# Each component: ~150-200 lines, single responsibility
# Easy to test, easy to reuse, easy to maintain
```

---

## Learning Resources

- **Godot 4.5 Docs**: [Component Pattern](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)
- **State Machines**: [Game Programming Patterns](https://gameprogrammingpatterns.com/state.html)
- **Signals**: [Observer Pattern](https://refactoring.guru/design-patterns/observer)
- **Resource-Based Config**: [Data-Driven Design](https://www.dataorienteddesign.com/)

---

## Summary

This refactored architecture provides:

✅ **Clean Separation**: Each component has one job
✅ **Reusability**: Components work in any character
✅ **Testability**: Components test in isolation
✅ **Maintainability**: Small, focused files
✅ **Performance**: Godot 4.5 optimizations
✅ **Scalability**: Easy to add new features
✅ **Professional**: Industry-standard patterns

The codebase is now production-ready, following AAA game development practices.
