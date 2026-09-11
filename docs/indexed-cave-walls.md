# Indexed cave wall pass

The separate `indexed_cave_wall_review.tscn` scene renders all 2373 current
wall spans through a packed palette-index viewport and an RGB resolve pass.
It reuses the walking camera, wall geometry, UV/addressing and collision from
the existing cave. There are 27 source materials and 42 material/address groups.

Export the original indices using the RE repository:

```sh
python3 tools/draracle/export_wall_index_textures.py --game-root /path/to/lol2 --wall-assets /path/to/godot/assets/lol2/generated/wall_review --out /path/to/godot/assets/lol2/generated/wall_indices
```

Each texture is compared byte-for-byte, after palette resolution, with the
already reviewed variant0 RGB image. All27 match. A9 column-major storage is
converted to rows; other raw layouts preserve the existing row-major preview
and retain its unverified native-layout status. No orientation fixes, RGB-to-index
inference or new shade assignments are introduced. Source assets stay outside Git.

Run and verify from the Godot repository:

```sh
flatpak run org.godotengine.Godot --path /path/to/godot res://scenes/lol2/indexed_cave_wall_review.tscn -- --capture-indexed-walls --checkpoint=14
python3 tools/verify_cave_wall_index_capture.py --project /path/to/godot --label checkpoint14
```

Omit the capture argument for interactive WASD/mouse movement. N/P select
checkpoints; F toggles flight. This diagnostic is walls only: black openings
are surfaces excluded from the index viewport, not removed cave geometry.
The normal textured cave and its1183 props are unchanged. Props, floors and
roof are still built by the inherited scene but excluded from this pass.
Avoid the parent scene's smoke/capture/comparison flags in this diagnostic.

Validation on Godot4.7.2 Compatibility / RX9070XT:

| Checkpoint | Pixels | Distinct indices | Resolve mismatches |
| --- | ---: | ---: | ---: |
| 1 | 518400 | 80 | 0 |
| 14 | 518400 | 106 | 0 |
| 119 | 518400 | 87 | 0 |

Captures and reports are under `captures/indexed_walls/`. This validates GPU
palette resolution against each captured index buffer; it is not a comparison
with original-game screenshots or an independent geometry/occlusion proof.
Index encoding uses the previously tested two-nibble scheme. No lighting,
MSAA or fog is applied to the data pass. Other rendering backends are untested.
The normal scene also renders under the overlay, so current performance is
not representative of a finished pipeline.

Next convert floors, roof and ordinary props before integrating special-pixel
sprites against a complete background. Multiple overlapping special sprites
remain open. Enhanced lighting remains an optional presentation direction;
keep the original palette/material reference mode available.
