# Matatu Mayhem — Nairobi Nganya Vertical Slice

Matatu Mayhem is an original 3D arcade driving game inspired by the energy and visual personality of Kenyan matatu culture.

## Current build

This package is a playable Godot 4.x desktop and Android prototype/vertical slice. It includes:

- The Maverick playable vehicle
- Arcade-realism acceleration, braking, reverse and steering
- Suspension and speed-sensitive handling
- Handbrake oversteer/drift behaviour
- Vehicle reset
- Smooth chase camera with speed-sensitive FOV/distance and spring-arm collision
- Test route with six sequential checkpoints
- Route timer and KSh reward loop
- Persistent money, best time and routes-completed save data
- HUD
- Pause, resume, restart and quit
- Replay after route completion
- Responsive Android touch controls for steering, throttle, brake/reverse, drift, reset and pause
- Original nganya-style Maverick with route boards, graffiti-inspired colour blocking, roof lamps, underglow, speakers and detailed trim
- Nairobi-inspired boulevard with keep-left cues, a matatu stage, sidewalks, streetlights, crosswalks, road patches, city blocks and a fictional landmark
- Eight lightweight two-way traffic vehicles following Kenya's left-driving pattern
- Repeatable passenger service: stop at the pickup stage, carry passengers to the active drop-off and earn KSh 5,000
- Persistent passenger fares, trip totals, owned-nganya data and upgrade-level data ready for the Garage milestone

## Run

1. Install Godot 4.x.
2. Import this folder by selecting `project.godot`.
3. Open the project.
4. Press F6/F5 (Run Project).

## Controls

- W / Up — accelerate
- S / Down — brake / reverse
- A / Left — steer left
- D / Right — steer right
- Space — handbrake
- R — reset vehicle upright
- Esc — pause

On Android, use the labelled on-screen controls. The game is designed for landscape orientation.

### Android APK

Every successful `main` build now produces a signed debug APK for arm64 Android phones. The latest APK is also published with the Web build at `/downloads/MatatuMayhem-Android.apk` for direct device testing.

## Goal

Drive through the glowing checkpoints while respecting traffic. Stop inside the active passenger stage at 4 km/h or less for 1.5 seconds, then drive to the active drop-off. Every successful passenger trip pays KSh 5,000 into the persistent balance. The money is reserved for performance upgrades and new nganya purchases in the Garage milestone.

## Save data

Save data uses Godot's `user://` path and records money, best route time and completed routes.

## Scope

This is the first playable Nairobi-themed vertical slice, not the final commercial game. The environment and vehicle use optimized procedural geometry suitable for Web and Android iteration. Traffic, passengers, a larger city, garage customization, rival AI, police and production audio remain future phases.
