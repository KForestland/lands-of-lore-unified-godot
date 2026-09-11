# Experimental original-cave walk view — 2026-09-11

Launch `/home/bob/run_lol2_original_walk.sh`.

WASD moves; mouse looks; Escape releases the mouse and left-click recaptures it.
R resets to the sample start. N/P selects the next/previous region pair. Falling
256 units below the sample automatically resets. There is no jump or interaction.

The scene exposes all 119 tested two-region samples with their original floor
pixels and diagnostic UVs, plus neutral ceilings and provisional boundary walls.
Each sample is translated to its seam midpoint in original coordinate units.
This is local walk inspection, not a connected or complete cave level. Missing
neighbor geometry is visible as open space; special connectors and subdivisions
are outside the selected sample set. Player radius 8, height 64 and camera eye
height 56 above the capsule bottom are assumptions. Water/lava have no hazard
or movement semantics. Missing material bindings remain pink.

Validation: Godot 4.7.2 headless smoke traversed all 119 samples in the forward
direction using this scene's actual controller and switched scenes between them,
with zero fall resets. The prior isolated audit covers both directions. GUI
capture of the first sample was rendered and inspected: floor texture, neutral
shell and controls visible. Capture: captures/original_walk_review.png.
Manual mouse/keyboard feel and every sample's appearance are not yet reviewed.

```sh
flatpak run org.godotengine.Godot --headless --fixed-fps 60 --path /home/bob/lands-of-lore-unified-godot res://scenes/lol2/original_walk_review.tscn -- --walk-smoke
```

Source: scripts/lol2/original_walk_review.gd and scenes/lol2/original_walk_review.tscn.
Requires generated floors.json and traversal_expanded.json; regenerate with the
existing floor exporter and tools/lol2/build_traversal_fixtures.py --all if needed.
Default authored cave and original orbit review remain available through their
existing launchers. Next: assemble a connected ordinary-region area and measure
its missing wall/opening coverage before extending traversal beyond local pairs.

Correction: shell fixtures also include provisional interior-span candidates. See CONNECTED_WALK_REVIEW.md for scope clarification.
