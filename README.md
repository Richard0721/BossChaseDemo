# Boss Chase Demo

Godot 4.6.1 third-person boss chase vertical slice.

The project now starts in a real-time 3D main menu with randomized character
showcase, mouse-driven head tracking, deployment selection, rules and settings.

Deployment follows a white-box Mario Kart-style sequence: Boss, map preview,
character spotlight selection, interaction pose, then battle. Nintendo-style
controller mapping uses the left stick as a virtual cursor, east A to confirm,
and south B to return.

## Open

Install Git LFS once with `git lfs install`, clone the repository, then import
`project.godot` in Godot 4.7 and press F6/F5.

Team contributions use short-lived branches and pull requests into `main`. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for setup, testing, and merge guidance.

## Controls

- WASD: move
- Shift: sprint
- Space: jump
- Mouse: camera
- Hold right mouse: over-the-shoulder aim and crosshair
- Left mouse: ranged attack
- F: pick up a nearby item
- Mouse wheel: switch acquired item
- Left mouse: use the selected item (shoot or hammer attack)
- Hammer selected: left mouse charges a 1-second area slam; right mouse throws it
- Q: lock/unlock nearest boss
- Escape: release/capture mouse

## Current milestone

- Third-person movement and orbit camera
- Sprint and jump
- Free/locked camera modes
- Smooth over-the-shoulder aiming camera; crosshair only appears while aiming
- Prototype ranged and melee hit validation
- Physical moving projectiles for both player and Boss attacks
- Bright projectile trails, impact flashes and camera recoil feedback
- Universal un-aimed left-click melee; ranged fire requires right-click aiming
- 300-round player ammunition counter in the lower-right HUD
- Four selectable character-special systems wired to combat stats and movement
- Four fixed rune points; two random runes spawn each 60-second round
- The first two runes spawn immediately when battle begins
- Heal, speed, attack and one-hit defense rune effects with live visuals
- A true eight-metre-deep B1 basin with two traversal ramps
- Escape-key pause menu with resume and return-to-menu actions
- LAN lobby with offline, ENet Host and IPv4 Join paths plus synchronized member list
- One-to-four member offline parties with unique-character AI fill
- Boss HP scales 100/150/200/250 by party size
- Easy/Normal/Hard Boss tiers use 60%/80%/100% damage and 100%/150%/200% AI multipliers
- Higher difficulties unlock triple burst, charge, piercing shots, high jumps and laser sweep
- Aggressive Boss skill rotation: rapid fire, 0.15-second triple burst, charge knockback,
  high-ground jumps, piercing red shots and a 120-degree horizontal laser sweep
- Spectator target cycling via Q/E, mouse wheel or controller shoulder buttons
- Five Host-controlled item boxes at match start; one replacement check every 30 seconds
- Weighted Hammer/Propeller/RapidGun/Shield/Landmine drops and 10% bomb punishment
- One-slot inventory with ranged/item mode cycling and two-hand carry visuals
- 50/300 base ammo with 1.5-second R reload; 100-round disposable rapid gun
- 100-damage shield, 10-second propeller flight, mines and Link-style aim slow-fall
- Landmines launch players, AI and Bosses upward with a temporary somersault state
- Player death spectator camera, 15-second respawn, 3-second invulnerability and team wipe defeat
- Test hammer pickup and inventory selection
- Stamina-limited high-speed sprint; partial stamina recovers after two seconds
  without sprinting, while exhaustion requires a five-second full recovery
- Boss taunt, wander, moving ranged fire, melee charge, charged shot,
  retreat, jump reposition and stun-ready state machine
- Five-minute timer and win/lose HUD

Networking, items, runes, respawn, production animation and final balance are intentionally scheduled after this playable offline slice.
