# Quick Start Guide

Get up and running with the FPP IK ADS system in 5 minutes.

## 1. Open the Project

```bash
# Open in Godot 4.5+
godot --path /path/to/fpp-ik-ads
```

Or use Godot's project manager to open the project folder.

## 2. Run the Demo

1. Press **F5** (or click the Play button)
2. Click in the window to capture mouse
3. Start playing!

## 3. Controls

```
WASD          - Move
Mouse         - Look around
Right Click   - Aim Down Sights (ADS)
Left Click    - Fire weapon
Left Shift    - Sprint
C             - Crouch (toggle)
Space         - Jump
ESC           - Release mouse
Enter         - Debug info
```

## 4. What You'll See

- **Full body blockout** - Simple boxes representing body parts
- **Working camera** - Attached to head, rotates naturally
- **Smooth ADS transition** - Right-click to see weapon sight align with center
- **Procedural effects** - Breathing, weapon sway, head bob
- **IK system** - Hands stay glued to weapon (simplified in blockout)

## 5. Understanding the System

### Scene Structure

Open `scenes/main.tscn` to see:

- **Player** node with character controller script
- **Body hierarchy** with spine, head, arms
- **Weapon** attached to right hand
- **IK target points** at grip and foregrip

### Key Scripts

| Script | Purpose |
|--------|---------|
| `fpp_character_controller.gd` | Basic controller (good for learning) |
| `enhanced_fpp_controller.gd` | Advanced version (more features) |
| `simple_ik_chain.gd` | IK solver for arms |
| `weapon_controller.gd` | Weapon behavior |

### Testing ADS

1. Run the project
2. Right-click and hold to enter ADS
3. Notice:
   - FOV narrows (zoom in effect)
   - Small box (sight) aligns with screen center
   - Movement slows down
   - Weapon sway reduces
   - Camera adjusts position

### Testing IK

The IK system keeps hands on the weapon:

1. Look around while in hipfire
2. Notice hands stay attached to weapon
3. Enter ADS (right-click)
4. Hands grip tighter (IK blend increases)

## 6. Customization Quick Reference

Want to tweak behavior? Edit these values in the Player node inspector:

### Movement
```
Walk Speed: 3.0      → How fast you walk
Sprint Speed: 6.0    → How fast you run
Mouse Sensitivity: 0.003 → Look sensitivity
```

### ADS
```
ADS Transition Speed: 8.0  → How fast ADS transitions
ADS FOV: 50.0             → Zoom level when aiming
Hipfire FOV: 90.0         → Normal FOV
```

### Procedural Effects
```
Breathing Amount: 0.001   → Subtle breathing motion
Bob Amplitude: 0.08       → Head bob intensity
Weapon Sway: 0.05         → Weapon lag amount
```

## 7. Next Steps

### For Learning
- Read `README.md` for full documentation
- Read `IMPLEMENTATION_GUIDE.md` for technical details
- Experiment with the exported variables in inspector

### For Your Project

**Option A: Use as Reference**
- Study the scripts to understand the techniques
- Implement similar systems in your own project
- Adapt the IK math and ADS logic

**Option B: Integrate This System**
1. Copy scripts to your project
2. Replace blockout meshes with your character model
3. Setup bone paths to point to your skeleton
4. Add proper animations via AnimationTree
5. Use Godot's SkeletonIK3D for production IK

## 8. Common Tweaks

### Make ADS Faster/Slower
```gdscript
# In player node inspector
ADS Transition Speed: 12.0  # Faster
ADS Transition Speed: 4.0   # Slower
```

### Change Zoom Level
```gdscript
ADS FOV: 40.0   # More zoom
ADS FOV: 60.0   # Less zoom
```

### Adjust Weapon Position
```gdscript
# Select: Player/Body/Spine/RightShoulder/RightArm/RightHand/Weapon
# Modify Transform in inspector:
Position: (0, -0.1, -0.4)  # Move weapon forward/back/up/down
Rotation: (45, 0, 0)       # Tilt weapon
```

### Change Camera Height
```gdscript
# Select: Player/Body/Spine/Head
# Modify Position Y to change head height
Position: (0, 0.6, 0)  # Higher head
Position: (0, 0.4, 0)  # Lower head
```

## 9. Troubleshooting

### Mouse Not Captured
- Click in the game window
- Press ESC to toggle mouse capture

### Can't Move
- Make sure window has focus
- Check input map in Project Settings

### ADS Not Working
- Hold right mouse button (don't click)
- Check console for errors

### Performance Issues
- This is a lightweight demo, should run smoothly
- If lagging, check Debug > Performance Monitor

## 10. Screenshots

### Hipfire Mode
- Wide FOV (90°)
- Weapon at relaxed position
- Full weapon sway active

### ADS Mode
- Narrow FOV (50°)
- Sight centered on screen
- Reduced sway for stability
- Slower movement

## What's Special About This System?

Unlike typical FPS games that use separate arm models, this system:

✅ Uses **one model** for first and third person
✅ Camera is **attached to head bone**
✅ **Full body visible** when looking down
✅ **IK ensures** hands never leave weapon
✅ **ADS perfectly aligns** sights with aim point
✅ **Procedural effects** add life to movement

This is how games like **Arma 3**, **Escape from Tarkov**, and **Ready or Not** handle first-person!

## Resources

- **README.md** - Complete documentation
- **IMPLEMENTATION_GUIDE.md** - Technical deep dive
- **scripts/** - All source code with comments

## Getting Help

If something doesn't work:

1. Check console (Output panel in Godot) for errors
2. Verify you're using Godot 4.5 or later
3. Make sure project.godot is in the root folder
4. Review the README for detailed explanations

---

**Enjoy building your FPP game! 🎮**
