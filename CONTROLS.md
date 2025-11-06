# FPP IK ADS System - Controls Reference

## Movement Controls

| Key | Action |
|-----|--------|
| **W** | Move Forward |
| **A** | Move Left |
| **S** | Move Back |
| **D** | Move Right |
| **Space** | Jump |
| **Shift** | Sprint (only when standing) |
| **C** | Cycle Stance (Standing → Crouching → Prone → Standing) |

## Camera & Look Controls

| Input | Action |
|-------|--------|
| **Mouse Movement** | Look around / Rotate camera |
| **Alt** (Hold) | Freelook - Camera rotates independently of body (up to 120°) |
| **Esc** | Toggle mouse capture (show/hide cursor) |

## Weapon Controls

| Input | Action |
|-------|--------|
| **Left Mouse Button** | Fire weapon |
| **Right Mouse Button** (Hold) | Aim Down Sights (ADS) - Zooms FOV and aligns sight |
| **E** | Interact / Pick up weapon |
| **R** | Reload (feature ready, not yet implemented) |
| **1** | Switch to weapon slot 1 |
| **2** | Switch to weapon slot 2 |
| **3** | Switch to weapon slot 3 |

## Debug & UI Controls

| Key | Action |
|-----|--------|
| **F3** | Toggle Debug Overlay (shows detailed system stats) |
| **F4** | Toggle IK Visualization (work in progress) |

## Stance System

The stance system affects movement speed and collision height:

- **Standing**: Full speed, normal height
  - Walk: 3.0 m/s
  - Sprint: 6.0 m/s (only available while standing)

- **Crouching**: Reduced speed and height
  - Speed: 1.5 m/s

- **Prone**: Minimal speed and height (lowest profile)
  - Speed: 0.8 m/s

## Freelook System

Hold **Alt** to enable freelook mode:
- Camera rotates independently from your body
- Body will only turn when you exceed 120° offset
- Useful for looking around while maintaining your direction
- Freelook indicator shows in HUD when active

## Aim Down Sights (ADS)

Hold **Right Mouse Button** to aim:
- Camera FOV transitions from 90° (hipfire) to 50° (ADS)
- Weapon sight perfectly aligns with camera center
- IK system keeps hands attached to weapon during transition
- Can't sprint while aiming

## IK (Inverse Kinematics) System

The skeleton-based IK system works automatically:
- Both hands stay attached to weapon grip and support points
- Head bone controls camera position (at eye level)
- Spine bone partially rotates for natural upper body movement
- IK adapts in real-time during movement, aiming, and stance changes

## Testing the Demo

The enhanced demo has 5 dedicated zones:

1. **Start Area** - Spawn point with control overview
2. **Shooting Range** - Weapon pedestals and targets
3. **Freelook Zone** - Angle markers to test 120° freelook
4. **IK Testing Zone** - Reflective mirrors to watch IK system
5. **Movement Course** - Stairs, platforms, and obstacles

## Weapon Pickups

- **Golden glowing cubes** are weapon pickups
- Approach and press **E** to pick up
- Current weapon is dropped when picking up a new one
- Interaction prompt shows at bottom of HUD

## Available Weapons

1. **Pistol** - Fast fire rate, low damage
   - Magazine: 15 rounds
   - Fire rate: 0.15s
   - Damage: 25

2. **Rifle** - Balanced, medium range
   - Magazine: 30 rounds
   - Fire rate: 0.1s
   - Damage: 40

3. **SMG** - High fire rate, close range
   - Magazine: 30 rounds
   - Fire rate: 0.08s
   - Damage: 20

## Tips

- Use **Alt + Mouse** to look around corners without turning your body
- Watch the mirrors in IK Testing Zone to see your skeleton in action
- Press **F3** for detailed performance and system info
- Sprint is disabled while aiming or crouching/prone
- The crosshair changes color based on interaction availability
