# Two special-pixel layers inside the cave

The separate `special_cave_review.tscn` diagnostic places two copies of
resource474 in front of the indexed cave camera. These placements, dimensions
and coloured depth blockers are test fixtures, not native prop placements.
The default demo and its1183 ordinary props remain unchanged.

Export local assets from the RE repository:

```sh
python3 tools/draracle/export_special_sprite_indices.py --game-root /path/to/lol2 --out /path/to/godot/assets/lol2/generated/special_cave_review
```

This checks the pinned executable/cache, decodes resource474 (138×83,
650 index1 pixels), and verifies the initial row64 remap loader provenance.
No original asset files are committed.

Run from the Godot repository, after building the full indexed cave assets:

```sh
flatpak run org.godotengine.Godot --path /path/to/godot res://scenes/lol2/special_cave_review.tscn -- --capture-special-cave --checkpoint=14
python3 tools/verify_special_cave_capture.py
```

The diagnostic freezes the camera and uses960×540,75-degree vertical FOV.
Do not resize or use movement/prop-record/smoke flags. Omit capture to leave
this fixed diagnostic open. Captures/report are in captures/special_cave/.

## Compositing

Each special sprite has its own source-index viewport. Copies of static cave
meshes write an empty source index while preserving depth and ordinary prop
cutouts. An additional pair of sprite-only captures provides depth witnesses.
Two 2D passes compose far-to-near, keeping the intermediate result indexed:
0 preserves the destination,1 remaps it,2–255 replace it with the source.
The nearer remap therefore sees the farther layer's result, including a prior
remap. Only the final pass resolves palette RGB and provisional roof tint.
Unknown floor markers have no verified index, so remap leaves those diagnostic
pixels marked; ordinary sprite colours can cover them. This marker behaviour
and roof treatment are preview policy, not original renderer evidence.

## Validation

On Godot4.7.2 Compatibility/RX9070XT at checkpoint14:

- Both518400-pixel composite index buffers and marker channels: zero mismatches.
- Final518400-pixel RGB resolve: zero mismatches.
- 2776 pixels remapped twice;33215 ordinary-colour overlap pixels.
- 33132 analytic depth samples: zero mismatches. The near rectangle hides both
  layers; the between-layer rectangle hides only the farther sprite.
- 21682 nonzero raw source samples are hidden by those controlled blockers.
- Complete static cave regression: zero resolve mismatches.

CPU depth expectations use perspective projection and a one-pixel edge inset;
composite expectations are derived independently from captured source indices.
This is not original-game screenshot parity or a proof of native draw order.
The scene was visually inspected, including transparent sprite borders.

Next bind suitable special sprites to their recovered placement/state records
and validate those views. Dynamic sorting, intersecting sprite planes, native
lighting changes, arbitrary camera motion and performance remain open. The
multi-viewport diagnostic duplicates static meshes and is not a production
render path. Enhanced lighting remains a later optional mode.
