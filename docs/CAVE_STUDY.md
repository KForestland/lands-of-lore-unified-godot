# Cave study 01

A first playable LoL2 material study: roughly 70 metres of connected chambers
and narrow passages, first-person movement, solid walls/floor/ceiling, a blue
exit marker, restart and a lighting toggle. It is the project's startup scene.
The geometry is newly authored, not an extracted Draracle cave map. All surfaces
use the same verified L20 rock texture; its assignment to floors and ceilings
is provisional. No combat, doors, saves, original level triggers or audio yet.

## Run

Open `project.godot` in Godot 4.6+ and press F6 on
`scenes/lol2/cave_study.tscn`, or F5 for the project. Validated here with
Godot 4.7.2 Flatpak and the compatibility renderer.

```bash
flatpak run org.godotengine.Godot --path /home/bob/lands-of-lore-unified-godot
```

WASD moves, mouse looks, Escape releases/captures the pointer, R restarts,
and F toggles prototype lighting versus a fixed original shade colour.
Walk to the blue marker at the far end to complete the route.

## Reproduce the material

Generated game content is ignored by Git. Supply the verified renderer's
output directory, produced from your compatible original GOG installation
using the LoL2 material contributor kit:

```bash
python3 tools/lol2/import_cave_material.py /path/to/native_material_file_render
```

The importer pins the named L20 blob, descriptor 556, shade bank 45 and PNG
hash. This intentionally accepts the current PNG fixture only; if another PNG
encoder produces different bytes, investigate against the kit's raw-byte
checks before updating the pin. The resulting provenance JSON travels with
local generated content. Missing material logs an error and shows a grey
fallback for interactive use; the automated check fails instead.

The base PNG carries the verified file palette and fixed shade row. Godot
builds its own filtered mipmaps for this prototype; the original five mip
levels and original distance/shade selection are not reproduced. Default
lighting adds an artistic lighting pass to those already shaded colours.
F disables that extra lighting, but neither mode establishes original-engine
screen-pixel fidelity. Nothing has been published or seeded.

## Validation

```bash
flatpak run org.godotengine.Godot --headless --path . -- --cave-smoke
flatpak run org.godotengine.Godot --path . -- --cave-capture
```

Smoke mode moves the real CharacterBody3D through each chamber using physics,
checks initial floor support and lateral wall obstruction, detects falling,
and requires reaching the exit within 35 simulated seconds. A timeout or
missing texture exits with failure. Capture mode saves a rendered view to
`captures/cave_first_room.png` and exits. This does not replace manual testing
of mouse controls or constitute exhaustive collision coverage.

Next: add uneven ground and a branch chamber, validate another material for
floor/wall variety, then compare candidate Draracle geometry against original
runtime evidence before presenting any layout as a reconstruction.
