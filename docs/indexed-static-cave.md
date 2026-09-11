# Indexed static cave review

`indexed_complete_cave_review.tscn` extends the indexed wall diagnostic to
1953 floor faces,1939 ceiling faces and1183 ordinary static props. It reuses
the existing geometry, positions, frame flips and walking controls. This is
a separate review scene; the default textured cave is unchanged.

Build the existing cave/wall/prop assets and indexed wall textures first,
then run the RE repository's exporter:

```sh
python3 tools/draracle/export_cave_surface_indices.py --game-root /path/to/lol2 --godot-project /path/to/godot
```

It exports13 floor and19 prop index textures. Every floor RGB and prop RGBA
image matches the current preview byte-for-byte after palette resolution.
The floor importer historically preserved/reshaped texture bytes differently
from the walls. Export checks source-derived raw/column-converted layouts
against those existing images, records the match, and preserves it. This is
not a new native orientation claim. Ordinary props reject source index1;
that value requires the separate special-pixel compositor.

Run the complete static review:

```sh
flatpak run org.godotengine.Godot --path /path/to/godot res://scenes/lol2/indexed_complete_cave_review.tscn -- --capture-indexed-walls --checkpoint=14
python3 tools/verify_cave_wall_index_capture.py --project /path/to/godot --complete --label complete14
```

Omit capture for interactive review. B toggles props, C roof, N/P checkpoints,
F flight. Use the normal movement/mouse controls. Captures retain the inherited
cave_wall filenames; the checker archives labelled copies. Do not use the
parent's prop-record or smoke/capture flags in this diagnostic.

The index viewport contains all static surface types. Floors/roof repeat
nearest first-mip indices; no averaged RGB mipmaps are used in the data path.
Props use fixed-Y billboards and discard index0 so the background depth and
indices survive transparent texels. Scale/alpha assumptions remain those of
the existing preview. Multiple special-sprite ordering is not implemented.

Red/green carry the index. Blue marks roof or unresolved floor material.
Roof material134 and its0.65 darkening remain provisional; the new pass
applies explicitly byte-rounded darkening after palette resolution. This is
not a claim of exact parity with StandardMaterial's previous colour pipeline.
The93 unresolved floor faces stay diagnostic pink; their sampled index is not
original material evidence. There are14 floor groups, including this fallback.

On Godot4.7.2 Compatibility/RX9070XT, checkpoints14 and119 each match the
independent CPU resolve at all518400 pixels, including roof treatment.
The wall-only regression also has zero mismatches. These tests validate
resolution from captured indices, not original-game screenshot parity,
independent billboard/occlusion parity or all119 viewpoints. Captures at both
complete checkpoints were visually inspected. Other renderers are untested.
The inherited main scene still renders under the overlay, so this is not a
performance-ready replacement for the default cave renderer.

Next integrate special-pixel sprites against this complete background,
verify depth and overlapping remaps, then address performance. Optional
improved lighting remains planned alongside an original-material reference.
