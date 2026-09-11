# Indexed 3D depth review

This separate diagnostic carries original palette indices through 3D depth
rendering, then applies the original special-pixel remap before resolving RGB.
The playable cave remains at 1183 static props; this is not yet its render path.

Build the special-pixel fixture as described in special-pixel-review.md, then:

```sh
flatpak run org.godotengine.Godot --path /path/to/project res://scenes/lol2/index_buffer_review.tscn -- --capture-indices
python3 tools/verify_index_buffer_capture.py --project /path/to/project
```

The 640×400 orthographic fixture includes resource474, all 256 background
indices, and strips for source0/1/2. Two rectangular objects exercise depth:
one is behind the sprite, one in front. Submission order differs from depth
order. Independent CPU checks compare both index buffers and the final RGB.
On Godot4.7.2 Compatibility / Radeon RX9070XT, all three buffers have zero
mismatches across 256000 pixels each. The previous 2D review also retains
zero mismatches after the shared shader change.

Raw grayscale output failed: low values merged during the 3D colour path.
The spatial shader instead packs two four-bit values into red/green using
64 + 12*n. The resolve pass rounds each channel back to a nibble. All256
values survive in this tested configuration. This is a data encoding,
not a colour treatment; do not apply lighting, filtering, antialiasing,
fog or artistic postprocessing to these buffers. Other renderers, hardware,
perspective edges and resolutions still need validation.

The fixture uses two independent 3D worlds with matching cameras: background
indices and visible sprite indices, followed by the palette resolve. It proves
one sprite layer with opaque occluders. Multiple overlapping special sprites,
transparency ordering, cave geometry/material conversion and performance
remain open. The fullscreen sprite plane is diagnostic, not a general-purpose
transparent sprite implementation.

## Visual direction

The user approved improvements beyond the original shaders. Keep an original
palette/material reference mode and an optional enhanced mode. Apply artistic
lighting and colour changes after special-pixel resolution, or through a
separately designed shading path, while preserving the cave's character.
The current diagnostic does not introduce enhanced lighting yet.
