# Architecture

## Autoloads

- `GameManager.gd` — global game state, player vehicle and active route references.
- `SaveManager.gd` — JSON save/load at `user://matatu_mayhem_save.json`.
- `EconomyManager.gd` — central route reward and money logic.

## Vehicle

`Matatu.tscn` uses `VehicleBody3D` + four `VehicleWheel3D` nodes. `MatatuController.gd` owns input/physics behaviour, while `MaverickStats.tres` owns tuning values.

## Camera

`ChaseCamera.gd` follows the registered vehicle independently. A `SpringArm3D` provides practical collision protection and speed changes camera distance/FOV.

## Route

`RouteManager.gd` discovers direct child `RouteCheckpoint` instances, activates them sequentially and emits progress/completion signals.

## UI

`HUD.gd` displays speed, money, route objective, timer and completion rewards. `PauseMenu.gd` handles pause/restart/quit.
