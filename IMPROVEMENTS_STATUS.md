# Architecture Improvements - Status & Roadmap

## ✅ COMPLETED (Just Fixed)

### 1. **Node Path Errors - FIXED**
**Problem:** Components couldn't find nodes inside instanced scenes using unique names (%)
**Solution:** Changed to full relative paths using `get_node_or_null()`
```gdscript
# Before (broken):
@onready var skeleton: Skeleton3D = %Skeleton3D

# After (works):
@onready var skeleton: Skeleton3D = get_node_or_null("../CharacterModel/RootNode/Skeleton3D")
```
**Reason:** Unique names inside instanced scenes (CharacterModel from character.gltf) don't propagate to parent scene level.

### 2. **GDScript Warnings - FIXED**
- ✅ Renamed `velocity` variable to `move_velocity` (was shadowing CharacterBody3D.velocity)
- ✅ Prefixed unused parameters with underscore (_is_freelooking, _delta, etc.)
- ✅ Added `freelook_changed.emit()` when freelook state changes

**Status:** All warnings resolved. Scene should now load without errors!

---

## 🔴 CRITICAL - Must Fix Before System is Functional

### 1. **Weapon System Non-Functional** (Estimated: 4-6 hours)
**Status:** ❌ BROKEN - State machine exists but not wired up

**Problem:**
- `WeaponSwapStateMachine` created but never instantiated
- No weapon attachment to hands
- No hand IK targeting for weapon grips
- ADS only changes FOV, doesn't position weapon to align sights
- No weapon switching (1/2/3 keys)

**What's Missing:**
```gdscript
# Need to create:
- WeaponControllerComponent (manages weapons, IK, swapping)
- Wire up WeaponSwapStateMachine as child node
- Implement hand IK target updates
- Implement full ADS weapon positioning
- Add weapon switch input handling (1/2/3 keys)
```

**Impact:** Can't use weapons at all. Weapon pickups print message but don't attach weapons.

**Priority:** ⭐⭐⭐ HIGHEST - Core gameplay feature

---

### 2. **Tight Coupling Performance Issue** (Estimated: 1 hour)
**Status:** ❌ PERFORMANCE PROBLEM

**Problem:** `MovementController.get_parent_rotation()` calls `get_node_or_null("CameraController")` **every physics frame** (60 FPS)

```gdscript
# scripts/components/movement_controller_component.gd:99-102
func get_parent_rotation() -> float:
    # THIS RUNS 60 TIMES PER SECOND!
    var camera_controller := get_parent().get_node_or_null("CameraController") as CameraControllerComponent
    return camera_controller.get_body_rotation() if camera_controller else 0.0
```

**Solution:** Cache reference in `_ready()` or use signal-based communication:

**Option A: Simple Cache (Quick Fix)**
```gdscript
var camera_controller: CameraControllerComponent  # Cached

func _ready() -> void:
    camera_controller = get_parent().get_node_or_null("CameraController") as CameraControllerComponent

func get_parent_rotation() -> float:
    return camera_controller.get_body_rotation() if camera_controller else 0.0
```

**Option B: Signal-Based (Better Architecture)**
```gdscript
# CameraController emits signal on every rotation update
signal body_rotation_changed(new_rotation: float)

# MovementController caches latest value from signal
var cached_body_rotation: float = 0.0

func _on_body_rotation_changed(rotation: float) -> void:
    cached_body_rotation = rotation
```

**Impact:** Unnecessary O(n) tree traversal 60 times/second. Wastes CPU.

**Priority:** ⭐⭐ HIGH - Performance issue

---

## 🟡 IMPORTANT - Should Fix Soon

### 3. **Input Handling Scattered** (Estimated: 2-3 hours)
**Status:** ❌ NO CENTRALIZED SYSTEM

**Problem:** Input split across 4 different scripts with no coordination:
- **CameraController:** Mouse look, ESC, O key
- **MovementController:** Sprint, aim, crouch, jump
- **CharacterControllerMain:** Interact, IK toggle
- **Weapon:** Fire, reload

**Issues:**
- Can't disable all input during cutscenes/UI
- No input rebinding system
- No input buffering/queuing
- Unclear precedence when multiple systems want same input
- Difficult to implement gamepad support

**Solution:** Create `InputControllerComponent` that translates raw input → semantic commands via signals

```gdscript
# InputController emits high-level commands:
signal move_command(direction: Vector2)
signal jump_requested()
signal weapon_switch_requested(slot: int)
signal fire_requested()

# Components connect to these signals instead of checking Input directly
```

**Benefits:**
- Single `enable_input()/disable_input()` affects entire character
- Easy to add input rebinding UI
- Can implement input buffering for combos
- Separates "what key was pressed" from "what action to take"

**Priority:** ⭐⭐ HIGH - Architecture improvement

---

### 4. **Missing Debug/Test Controls** (Estimated: 30 minutes)
**Status:** ❌ REMOVED DURING REFACTORING

**Problem:** Old system had ragdoll testing keys - all removed:
- H key: Test ragdoll impulse
- J key: Toggle partial ragdoll (left arm)
- K key: Toggle partial ragdoll (right arm)
- L key: Toggle partial ragdoll (legs)

**Solution:** Add input handling in CharacterControllerMain or InputController (once created)

```gdscript
func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        match event.keycode:
            KEY_H:
                if ragdoll_controller:
                    ragdoll_controller.apply_impulse(Vector3.UP * 500)
            KEY_J:
                if ragdoll_controller:
                    ragdoll_controller.toggle_partial_ragdoll(&"left_arm")
            KEY_K:
                if ragdoll_controller:
                    ragdoll_controller.toggle_partial_ragdoll(&"right_arm")
            KEY_L:
                if ragdoll_controller:
                    ragdoll_controller.toggle_partial_ragdoll(&"legs")
```

**Priority:** ⭐ MEDIUM - Testing/development aid

---

## 🟢 NICE TO HAVE - Polish & Optimization

### 5. **Performance Optimizations** (Estimated: 2 hours)
**Status:** ⚠️ NO LOD SYSTEM

**Optimizations to Add:**

**A) Early Exit for Static Characters**
```gdscript
# movement_controller_component.gd:_physics_process()
func _physics_process(delta: float) -> void:
    # Skip if not moving and no input
    if character_body.is_on_floor() and velocity.length_squared() < 0.01 and not _has_input():
        return  # Save CPU!

    # ... rest of physics ...
```

**B) LOD System for IK**
```gdscript
# Only update IK when character is near camera
func _should_update_ik() -> bool:
    var camera = get_viewport().get_camera_3d()
    var distance = global_position.distance_to(camera.global_position)

    if distance < 5.0:
        return true  # Full update when close
    elif distance < 15.0:
        return Engine.get_process_frames() % 2 == 0  # Every 2nd frame
    elif distance < 30.0:
        return Engine.get_process_frames() % 4 == 0  # Every 4th frame
    else:
        return false  # Disable when far
```

**C) Bone Index Validation Warnings**
```gdscript
# Add one-time warnings for invalid bone indices
var _has_warned_skeleton: bool = false

func _update_head_rotation() -> void:
    if not skeleton and not _has_warned_skeleton:
        push_warning("CameraController: Skeleton3D reference lost!")
        _has_warned_skeleton = true
        return
```

**Priority:** ⭐ LOW - Performance nice-to-have

---

### 6. **Magic Numbers → Named Constants** (Estimated: 30 minutes)
**Status:** ⚠️ MINOR CODE SMELL

**Problem:** Unclear magic numbers in code
```gdscript
# What do these numbers mean?
var spine_pitch := head_pitch * 0.3
var spine_yaw := head_yaw * 0.5
```

**Solution:**
```gdscript
const SPINE_PITCH_RATIO: float = 0.3  # How much spine follows head pitch
const SPINE_YAW_RATIO: float = 0.5    # How much spine follows head yaw

var spine_pitch := head_pitch * SPINE_PITCH_RATIO
var spine_yaw := head_yaw * SPINE_YAW_RATIO
```

**Priority:** ⭐ LOW - Code readability

---

### 7. **Improved Error Messages** (Estimated: 1 hour)
**Status:** ⚠️ ERRORS UNCLEAR

**Problem:**
```gdscript
if not config or not bone_config:
    push_error("CameraController: Config resources not assigned!")
    # Which one is null? How to fix?
```

**Solution:**
```gdscript
func _ready() -> void:
    var errors: Array[String] = []

    if not config:
        errors.append("CharacterConfig resource not assigned. Assign in Inspector under 'Config'.")

    if not bone_config:
        errors.append("BoneConfig resource not assigned. Assign in Inspector under 'Bone Config'.")

    if not skeleton:
        errors.append("Skeleton3D not found at path '../CharacterModel/RootNode/Skeleton3D'.")

    if errors.size() > 0:
        push_error("CameraController setup failed:\n  - " + "\n  - ".join(errors))
        return
```

**Priority:** ⭐ LOW - Developer experience

---

## 📋 Recommended Implementation Order

### **Phase 1: Critical Fixes (Required for Functionality)**
1. ✅ ~~Fix node path errors~~ - **DONE**
2. ✅ ~~Fix GDScript warnings~~ - **DONE**
3. ❌ **Fix tight coupling** (1 hour) - Cache camera controller reference
4. ❌ **Implement weapon system** (4-6 hours) - WeaponControllerComponent

**After Phase 1:** Game is playable with all features working

---

### **Phase 2: Architecture Improvements (Better Code Quality)**
5. ❌ **Create InputControllerComponent** (2-3 hours) - Centralized input
6. ❌ **Add debug controls** (30 mins) - Ragdoll testing keys

**After Phase 2:** Code is cleaner, more maintainable

---

### **Phase 3: Polish (Nice-to-Have)**
7. ❌ **Performance optimizations** (2 hours) - LOD, early exits
8. ❌ **Magic numbers → constants** (30 mins) - Code readability
9. ❌ **Better error messages** (1 hour) - Developer experience

**After Phase 3:** Production-ready, optimized, professional

---

## 🎯 Total Estimated Time

- **Phase 1 (Critical):** 5-7 hours ⚠️ Required
- **Phase 2 (Important):** 2.5-3.5 hours ⭐ Recommended
- **Phase 3 (Polish):** 3.5 hours ✨ Optional

**Total:** 11-14 hours for complete implementation

---

## 📊 Current Status Summary

| Category | Status | Priority | Time | Ready? |
|----------|--------|----------|------|--------|
| Node paths | ✅ Fixed | Critical | ✅ Done | ✅ Yes |
| Warnings | ✅ Fixed | Critical | ✅ Done | ✅ Yes |
| Weapon system | ❌ Broken | Critical | 4-6h | ❌ No |
| Tight coupling | ❌ Issue | High | 1h | ❌ No |
| Input centralization | ❌ Missing | High | 2-3h | ❌ No |
| Debug controls | ❌ Missing | Medium | 30m | ❌ No |
| Performance | ⚠️ Basic | Low | 2h | ⚠️ OK |
| Code polish | ⚠️ Basic | Low | 1.5h | ⚠️ OK |

---

## ✅ Ready to Test

The refactored scene **should now load without errors**!

You can test:
- ✅ Movement (WASD, sprint, jump, crouch)
- ✅ Camera (mouse look, freelook with Alt, O for third-person)
- ✅ IK mode toggle (M key)
- ✅ Ragdoll (R key)
- ❌ Weapon system (broken - needs Phase 1 item #4)

---

## 🚀 Next Steps

**Immediate:**
1. Test the game to verify errors are fixed
2. Decide priority: Fix weapon system first? Or add InputController?

**My Recommendation:**
Start with **Phase 1** to get everything functional, then decide if Phase 2/3 are needed based on your requirements.

Would you like me to:
- **A) Fix the tight coupling** (quick 1-hour fix)
- **B) Implement the weapon system** (4-6 hours, makes weapons work)
- **C) Create InputControllerComponent** (2-3 hours, better architecture)
- **D) All of Phase 1** (comprehensive fix pass)

Let me know what to tackle next!
