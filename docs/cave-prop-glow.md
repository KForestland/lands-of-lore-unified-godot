# Optional glow on existing props

Enhanced lighting now adds a green glow to resource469 at its four existing
placements:111,543,1108 and1137. Its mushroom/fungus-like identity is a visual
interpretation, not a recovered original name. The positions and sprite pixels
remain the existing recovered assets; the emission is an artistic enhancement.

G toggles the glow. L toggles all enhanced lighting. Hiding props with B also
suppresses these light sources. The previous global distance-lighting curve is
retained; matching original overall brightness awaits a reference comparison.

Each source is anchored in world space near the prop's upper portion. It raises
local green illumination with a squared falloff ending at80 game units. The
prop itself receives a brighter multiplier. This creates local colour spill,
not bloom or shadow-casting point lights: the analytic radius has no wall
occlusion, so thin-wall light leakage is a known limitation. Torches are not
placed in this pass; original reference evidence can guide that separately.

The RGB8 light buffer now encodes0..2 multipliers at half scale so it can
brighten above the original palette value; final resolution multiplies by2.
This changes only enhanced RGB presentation. Indices and reference mode remain
intact. Clamping at output may saturate bright greens intentionally.

To start near a glow while keeping walking controls:

```sh
/home/bob/run_lol2_cave_walkthrough.sh --glow-record=1108
```

For repeatable fixed-camera comparisons:

```sh
flatpak run org.godotengine.Godot --path /path/to/project res://scenes/lol2/cave_walkthrough.tscn -- --glow-capture --glow-record=1108
python3 tools/verify_cave_glow.py --record 1108
```

Records1108,543 and1137 were captured and checked. Source indices are byte-
identical with glow on/off/on, restored glow images are identical, and enhanced
RGB matches CPU multiplication within one8-bit channel level. Each capture is
960×540.1108 and1137 provide clear visual comparisons;543 is a tight close-up.
No new props or geometry are introduced. Checkpoint14's reference toggle also
passes after the light-buffer encoding change, and all four reference-mode
movement/resize/visibility captures still have zero mismatches.

The optional review camera uses the original floor region, moving toward an
interior point if the region average is too close to the prop. This is a viewing
aid, not an original camera position. Interactive review starts slightly above
the floor to allow the existing walking collision to settle normally.
