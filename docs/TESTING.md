# Testing

## Launch

- Project imports in Godot 4.x.
- `Main.tscn` starts with no parser errors.
- Maverick spawns near the south end of the route.
- First green checkpoint is visible ahead.

## Vehicle

- W accelerates forward.
- S brakes, then reverses near zero speed.
- A/D steer.
- Steering becomes less aggressive at high speed.
- Space reduces rear grip for oversteer.
- R resets the vehicle upright.
- Vehicle collides with road barriers and ramp.

## Android touch controls

- Landscape orientation is used.
- Left/right buttons steer while held.
- GO accelerates while held.
- BRAKE slows the vehicle and reverses near zero speed.
- DRIFT can be held at the same time as steering and throttle.
- RESET restores the vehicle upright.
- Pause button opens the pause menu.
- Held inputs release when the app loses focus.

## Camera

- Camera follows smoothly.
- Distance/FOV increases with speed.
- Spring arm avoids obvious clipping into world geometry.

## Route

- Only current checkpoint is visible.
- Checkpoints must be crossed in order.
- HUD advances from checkpoint 1 through 6.
- Finish panel appears after checkpoint 6.
- Reward is added once.
- Replay resets the vehicle and route.

## Persistence

- Money persists after restarting the game.
- Best time persists.
- Routes completed increments after each finish.

## Known environment limitation

The generated project was statically checked for internal file/resource references, but this build environment does not contain a Godot executable, so engine runtime validation must be completed on a machine with Godot 4.x installed.
