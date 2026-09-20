# Changelog

## v0.5-passenger-service-traffic

- Added eight mobile-conscious two-way AI traffic vehicles with left-driving lane placement.
- Added active pickup and drop-off stages with low-speed dwell validation.
- Added a repeatable passenger service loop paying exactly KSh 5,000 per completed trip.
- Added HUD passenger objectives and a four-second fare/balance confirmation.
- Persisted passenger trips, the balance, owned-nganya data and upgrade-level data for the Garage milestone.

## v0.4-authentic-nganya-roads

- Corrected drivetrain polarity: FORWARD now drives toward the nganya's nose and BRAKE/REVERSE drives backward.
- Fixed the traffic-signal variable name for strict Godot 4.7 parsing.
- Added bull bars, wipers, mirrors, indicators, plates, tow hooks, door seams, handles, mud flaps, fuel cap, flag trim, roof equipment, antenna, exhaust, rear ladder and chrome hubcaps.
- Added a full junction, lane arrows, pedestrian islands, traffic signals, roadside drainage, grates, painted humps, kiosks and Nairobi direction signage.
- Kept all branding and plates fictional while grounding the design in Kenyan matatu culture.

## v0.3-nairobi-nganya

- Renamed the drive pedals to FORWARD and BRAKE/REVERSE and exposed them during desktop testing.
- Preserved held input when a finger drifts outside a button, improving touch-control reliability.
- Prevented the chase camera's target and up vectors becoming colinear while the vehicle is stationary.
- Rebuilt the Maverick as an original Kenyan nganya-style matatu.
- Added route boards, windows, mirrors, roof rails, spot lamps, neon trim, speakers and graffiti-inspired colour blocking.
- Replaced the empty test arena with a mobile-friendly Nairobi-inspired boulevard.
- Added road markings, patches, crosswalks, sidewalks, streetlights, a matatu stage, buildings, trees, billboards and a fictional skyline landmark.
- Preserved the runtime-confirmed controller, chase camera, checkpoints, HUD, saves, pause flow and mobile inputs.

## v0.2-mobile-playable

- Added responsive landscape touch controls for Android.
- Added simultaneous hold controls for steering, throttle, brake and drift.
- Added mobile reset and pause controls.
- Added safe input release when the app loses focus.
- Preserved all desktop keyboard controls.

## v0.1-playable

- Added project foundation and required input actions.
- Added GameManager, SaveManager and EconomyManager autoloads.
- Added configurable Maverick VehicleStats resource.
- Added VehicleBody3D arcade controller with suspension, braking, reverse, steering, handbrake drift and reset.
- Added smooth speed-sensitive chase camera with SpringArm3D collision protection.
- Added test environment, road barriers and ramp.
- Added sequential six-checkpoint route gameplay.
- Added timer, rewards, money persistence and best-time persistence.
- Added HUD, pause menu, route restart and replay loop.
