# Optional cave lighting

The walkthrough starts with enhanced lighting. Press L to switch to the
reference view; --reference-lighting starts there directly. The HUD shows
the selected mode. Existing indexed diagnostic scenes default to reference.

This first artistic pass keeps nearby surfaces warmer and dims/cools distant
surfaces. It uses actual view-space surface distance: near/far colours blend
with exp(-distance/240). It is camera-relative ambient fill, not restored
original lighting, world-anchored torches, directional light or cast shadows.

A separate geometry pass draws the light multiplier. It shares source meshes,
UVs and fixed-Y billboard transforms, handles ordinary sprite cutouts, and
skips special index1 so it receives the underlying surface's light. Final RGB
is multiplied only after indexed special-pixel remapping and palette resolve.
The original palette-index buffers remain unchanged. Roof and unresolved-floor
preview policies are retained. Visibility and viewport size follow the cave;
the extra light viewport stops rendering in reference mode.

This pass adds a geometry draw and mesh instances. Material duplicates are
cached, but broad performance measurements and other graphics backends are
still pending. No frame-rate improvement is claimed.

## Checks

```sh
flatpak run org.godotengine.Godot --path /path/to/project res://scenes/lol2/cave_walkthrough.tscn -- --lighting-capture --checkpoint=14
python3 tools/verify_cave_lighting.py --checkpoint 14
```

Repeat with checkpoint119. Both comparisons cover518400 pixels:

- Background and fully composited index buffers stay byte-identical across
  enhanced/reference/enhanced captures.
- Reference RGB matches the CPU palette/tint resolve exactly.
- Returning to enhanced mode restores the exact enhanced image.
- Enhanced RGB agrees with CPU multiplication within one8-bit channel level
  (GPU rounding);93975 pixels at14 and92131 at119 have that one-level difference.

Reference-mode moving-camera, resizing and visibility regression still passes
all four views with zero mismatches. Both enhanced cave captures were visually
inspected. Tested with Godot4.7.2 Compatibility/RX9070XT. Screenshots and JSON
reports are local under captures/lighting_14 and captures/lighting_119.

Next evaluate the look while walking and refine if needed. Dummy creature
sprites remain a subsequent visual step; gameplay is outside the demo scope.
