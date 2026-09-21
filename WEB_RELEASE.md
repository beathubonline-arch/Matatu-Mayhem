# Matatu Mayhem — Web Launch

The repository includes a Godot Web export preset targeting `build/web/index.html`.

## Release build

From the project root on Windows:

```powershell
& "C:\Users\hp\Desktop\projects\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe" --headless --path . --export-release "Web" "build/web/index.html"
```

If Godot reports that export templates are missing, install the matching Godot 4.7.2 export templates in the editor first.

## Launch gate

Before publishing, open the exported build in Chrome/Edge and complete:

1. Start Ngong Road from CBD.
2. Board passengers with a brief stage stop.
3. Complete the outward trip and return to CBD.
4. Start Mombasa Road.
5. Confirm 254 Street Radio plays.
6. Confirm KSh, route unlocks and garage state persist after reload.
7. Confirm keyboard controls and HUD fit at 1280x720.
8. Confirm no red script/runtime errors.

The Web preset is intentionally single-threaded for simpler static hosting. The project already uses Godot's GL Compatibility renderer.
