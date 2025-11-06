# FPP IK ADS System - Complete Testing Guide

## 🎮 What You Should See When You Run the Project

### On Startup
1. **Mouse captured immediately** - Click if needed to capture
2. **HUD visible** with:
   - Crosshair in center (white crosshairs)
   - "No Weapon" text (bottom left)
   - "Standing" text (top right)
   - "HEALTH" bar (bottom left)
   - Control hints at bottom (auto-hide after 10 seconds)

3. **You spawn** at coordinates (0, 0.1, 5) facing forward

4. **Welcome sign** directly ahead with instructions

### What's Visible
- **Ground**: Large gray/brown platform (150x150 units)
- **Signs**: White Label3D text floating in air
- **Weapons**: **GOLDEN GLOWING CUBES** with yellow "[E] Weapon Name" labels
- **Targets**: Gray cubes at various distances
- **Walls/Platforms**: CSG geometry in various locations

---

## ✅ Step-by-Step Testing Checklist

### 1. Initial Verification (30 seconds)
- [ ] HUD is visible on screen
- [ ] Can look around with mouse
- [ ] WASD moves character
- [ ] Welcome sign is readable ahead
- [ ] Press **F3** - Debug overlay appears
- [ ] Press **F3** again - Debug overlay disappears

### 2. Movement Test (1 minute)
- [ ] Walk forward with **W** - character moves
- [ ] Strafe with **A/D** - character moves sideways
- [ ] Walk backward with **S** - character moves back
- [ ] Hold **Shift** - character sprints (faster)
- [ ] Press **C** once - HUD shows "Crouching", character lower
- [ ] Press **C** again - HUD shows "Prone", character very low
- [ ] Press **C** again - Back to "Standing"
- [ ] Press **Space** (while standing) - character jumps

### 3. Camera & Look Test (1 minute)
- [ ] Move mouse - camera rotates smoothly
- [ ] Look up - camera pitches up (limit at 80°)
- [ ] Look down - camera pitches down (limit at 80°)
- [ ] Spin 360° - no issues
- [ ] Body follows camera rotation

### 4. Freelook Test (1 minute)
**CRITICAL FEATURE**
- [ ] Hold **Alt** key
- [ ] Move mouse left/right
- [ ] "FREELOOK [XX°]" indicator appears at top center
- [ ] Angle number increases as you look
- [ ] Body does NOT turn (stays facing forward)
- [ ] Release **Alt** - body catches up to camera
- [ ] Try to exceed 120° - body automatically follows

**Where to test**: Go to Freelook Zone (turn left from spawn, walk to area with angle markers)

### 5. Weapon Pickup Test (2 minutes)
**Find weapons** - They look like **GOLDEN GLOWING CUBES** with labels

**Locations**:
- **Forward** from spawn: Shooting Range has 3 weapons on a table
- **Right** from spawn: IK Zone has 3 weapons on pedestals

**Test**:
- [ ] Walk toward golden cube - Label shows "[E] Rifle" (or Pistol/SMG)
- [ ] Interaction prompt appears in HUD center
- [ ] Press **E** - Weapon attaches to your hands
- [ ] HUD bottom-left shows "Assault Rifle" (or weapon name)
- [ ] HUD shows ammo "30 / 30" (or weapon's magazine size)
- [ ] Crosshair appears (was hidden before)
- [ ] Weapon name flashes yellow briefly

### 6. ADS (Aim Down Sights) Test (1 minute)
**Requires**: Pick up a weapon first

- [ ] Hold **Right Mouse Button**
- [ ] FOV narrows (zoom in effect)
- [ ] Crosshair scales down (50% size)
- [ ] Crosshair turns GREEN
- [ ] "ADS" indicator appears
- [ ] Small cube (sight) visible on weapon aligns with center
- [ ] Movement feels slower
- [ ] Release RMB - FOV returns to normal
- [ ] Crosshair back to white

**Where to test**: Shooting Range - aim at targets at 10m, 25m, 50m

### 7. Shooting Test (1 minute)
**Requires**: Pick up a weapon, have ammo

- [ ] Aim at target (optional: hold RMB for ADS)
- [ ] Click **Left Mouse Button**
- [ ] Console prints "BANG! Weapon fired"
- [ ] Console prints "HIT: Target..." (if you hit)
- [ ] Ammo counter decreases "29 / 30"
- [ ] Fire until empty - ammo shows "0 / 30" in RED
- [ ] Crosshair disappears when empty
- [ ] Press **R** to reload
- [ ] Console prints "Reloading..."
- [ ] Wait ~2.5 seconds
- [ ] Console prints "Reload complete!"
- [ ] Ammo back to "30 / 30" in WHITE

### 8. IK System Test (2 minutes)
**Requires**: Pick up a weapon

**Visual Test**:
- [ ] Look at your hands/weapon while standing still
- [ ] Hands are attached to weapon (not floating)
- [ ] Move while holding weapon - hands stay attached
- [ ] Aim (RMB) - hands adjust to ADS position
- [ ] Jump while holding weapon - hands stay on weapon
- [ ] Crouch - weapon adjusts naturally

**Mirror Test** (IK Zone):
- [ ] Go to IK Testing Zone (right from spawn)
- [ ] Approach mirror walls
- [ ] Look at reflection - see full body with weapon
- [ ] Move around - see IK working in reflection
- [ ] Switch weapons - see hands reposition

### 9. Debug Overlay Test (1 minute)
- [ ] Press **F3** - Two panels appear
- [ ] **Left panel** shows:
  - Player position
  - Velocity
  - Stance
  - Camera angles
  - ADS blend
  - Weapon info
  - IK status
- [ ] **Right panel** shows:
  - FPS (should be 60+)
  - Frame time
  - Memory usage
  - Draw calls
- [ ] Values update in real-time
- [ ] Move around - position changes
  - Shoot - ammo changes
  - Press F3 again - overlays disappear

### 10. Zone Exploration (5 minutes)
**Shooting Range** (Forward from spawn):
- [ ] See weapon table
- [ ] Pick up Rifle - test it
- [ ] Pick up Pistol - different fire rate
- [ ] Pick up SMG - fastest fire rate
- [ ] Shoot targets at 10m, 25m, 50m
- [ ] Test accuracy at each distance

**Freelook Zone** (Left from spawn):
- [ ] See angle markers in circle
- [ ] Stand in center
- [ ] Hold Alt, look at each marker
- [ ] 0° CENTER straight ahead
- [ ] 45° LEFT/RIGHT diagonally
- [ ] 90° LEFT/RIGHT to the sides
- [ ] 120° markers behind you (max angle)
- [ ] Try to look past 120° - body turns

**IK Testing Zone** (Right from spawn):
- [ ] See mirror walls (dark boxes)
- [ ] See 3 weapon pedestals (cylinders)
- [ ] Pick up each weapon
- [ ] Look in mirrors - see full body
- [ ] Test IK with each weapon type

**Movement Course** (Back-right from spawn):
- [ ] Find stairs - walk up them
- [ ] Jump between platforms
- [ ] Crouch under obstacles
- [ ] Go prone - very low profile
- [ ] Sprint through course
- [ ] Test all movement combinations

**Performance Zone** (Back-left from spawn):
- [ ] Multiple weapon pickups
- [ ] Grid of targets
- [ ] Press F3 - check FPS
- [ ] Should be 60+ easily
- [ ] Fire at multiple targets
- [ ] Performance stays good

---

## 🐛 Troubleshooting

### "I don't see any weapons!"
**Solution**: Look for **GOLDEN GLOWING CUBES** - they emit light
- **Forward**: Shooting range table (3 weapons close together)
- **Right**: IK zone pedestals (3 weapons spread out)
- They rotate slowly and bob up/down
- They have yellow labels saying "[E] Rifle" etc.

### "HUD is not showing!"
**Check**:
1. Project is running `enhanced_demo.tscn` (not `main.tscn`)
2. Look at screen edges:
   - Bottom-left: Ammo/Weapon/Health
   - Top-right: Stance
   - Center: Crosshair (only when holding weapon)
3. Try picking up a weapon - HUD should update

### "Controls aren't working!"
**Solutions**:
- Click in the game window to capture mouse
- Press ESC to toggle mouse capture
- Make sure window has focus
- Try pressing the key again

### "Freelook (Alt) doesn't work!"
**Check**:
1. Hold Alt key (don't just press)
2. While holding Alt, move mouse
3. Look for "FREELOOK [XX°]" at top-center of screen
4. If not appearing - check input map in project settings

### "Debug overlay (F3) doesn't show!"
**Solutions**:
- Press F3 key
- Two panels should appear (left and top-right)
- Try pressing F3 again to toggle
- Check console for errors

### "I picked up weapon but can't see it!"
**Check**:
- Weapon is very small (blockout cube)
- Look down slightly - should see small box in front
- Crosshair should be visible
- HUD should show weapon name
- Try firing (LMB) - should work even if hard to see

### "Performance is bad!"
**Solutions**:
- Press F3 to check actual FPS
- Should be 60+ on modern hardware
- If lower: reduce window size, check other programs
- System is very optimized - shouldn't lag

---

## 📊 Expected Performance

### On Modern Hardware
- **FPS**: 60+ (capped by VSync usually)
- **Frame Time**: <16ms
- **Draw Calls**: ~50-100
- **Memory**: <200MB

### Stress Test
- Pick up all weapons
- Fire rapidly
- Run around all zones
- FPS should stay 60+

---

## 🎯 Feature Verification Checklist

| Feature | How to Test | Expected Result |
|---------|-------------|-----------------|
| **Skeleton3D** | Pick up weapon, move | Hands attached via bones |
| **SkeletonIK3D** | Weapon in hand, look around | Hands stay on weapon |
| **Freelook (Alt)** | Hold Alt, move mouse | Body stays put, angle shows |
| **ADS** | Hold RMB with weapon | FOV narrows, sight aligns |
| **HUD** | Just play | Info visible on screen |
| **Weapons** | Find golden cubes | Glowing, rotating, labeled |
| **Interaction** | Walk near weapon | "[E] Weapon Name" prompt |
| **Signals** | Pick up weapon | HUD updates, name flashes |
| **Stances** | Press C repeatedly | Standing→Crouch→Prone→Standing |
| **Debug (F3)** | Press F3 | Two panels with live data |
| **Combat** | Fire weapon (LMB) | Ammo decreases, recoil |
| **Reload** | Press R when low ammo | 2.5s delay, ammo refills |
| **Testing Zones** | Explore map | 5 distinct themed areas |

---

## 📸 Visual Reference

### What Golden Weapons Look Like
```
     [E] Assault Rifle  ← Yellow label
           ╔═══╗
           ║   ║        ← Golden cube
           ╚═══╝        ← Glowing (emission)
     (rotating & bobbing)
```

### HUD Layout
```
┌─────────────────── Screen ───────────────────┐
│                                               │
│  STANCE: Standing ────────────────────┐  (TR)│
│                                       │      │
│               ┼  ← Crosshair                 │
│         FREELOOK [45°]  (appears w/ Alt)     │
│                                               │
│         [E] Pick up Rifle  (interaction)     │
│                                               │
│  ┌──────────┐                                │
│  │ WEAPON   │                                │
│  │ Rifle    │                          (BL)  │
│  │ AMMO     │                                │
│  │ 30 / 30  │                                │
│  │ HEALTH   │                                │
│  │ ████████ │                                │
│  └──────────┘                                │
└───────────────────────────────────────────────┘
```

### Debug Overlay (F3)
```
┌──────────── Left Panel ────────────┐  ┌── Right Panel ──┐
│ FPP IK ADS DEBUG INFO              │  │ PERFORMANCE     │
│                                    │  │                 │
│ PLAYER STATE                       │  │ FPS: 62         │
│ Position: (0, 1, -5)               │  │ Frame: 16ms     │
│ Velocity: (0, 0, 0) 0.00 m/s       │  │                 │
│ ...                                │  │ Memory          │
│                                    │  │ Static: 45 MB   │
│ WEAPON                             │  │ ...             │
│ Name: Assault Rifle                │  │                 │
│ Ammo: 30 / 30                      │  │ Rendering       │
│ ...                                │  │ Draw Calls: 87  │
└────────────────────────────────────┘  └─────────────────┘
```

---

## ✨ Quick 2-Minute Test

If you only have 2 minutes:

1. **Run project** - HUD should appear
2. **Walk forward (W)** - see welcome sign
3. **Press F3** - debug overlay appears
4. **Hold Alt, move mouse** - freelook indicator shows
5. **Walk to golden cube** - interaction prompt appears
6. **Press E** - weapon picked up, HUD updates
7. **Hold RMB** - ADS zoom works
8. **Click LMB** - weapon fires, ammo decreases
9. **Press R** - reload works

**If all 9 work** = System is fully functional! ✅

---

## 🎓 Learning Path

### Beginner (10 minutes)
- Basic movement (WASD)
- Look around (mouse)
- Pick up weapon (E)
- Fire weapon (LMB)

### Intermediate (20 minutes)
- Test all stances (C)
- Use freelook (Alt)
- ADS aiming (RMB)
- Reload (R)
- Explore all zones

### Advanced (30+ minutes)
- Study debug overlay (F3)
- Test IK in mirrors
- Try all weapons
- Performance testing
- Read the code!

---

## 🚀 Next Steps After Testing

Once you've verified everything works:

1. **Read FEATURES.md** - Complete feature list
2. **Read IMPROVEMENTS.md** - How to enhance further
3. **Study the scripts** - Learn the implementation
4. **Customize** - Adjust exported variables
5. **Extend** - Add your own weapons/features
6. **Build** - Use as foundation for your game!

---

**If anything doesn't work as described, there may be an issue. Let me know!**

Good luck testing! 🎮
