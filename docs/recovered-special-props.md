# Recovered special-prop placements

`special_placed_prop_review.tscn` shows three special-pixel sprites at their
original recorded anchors and state dimensions. It reuses the tested indexed
compositor, adds no coloured blockers, and keeps the default demo unchanged.
The review contains1183 existing ordinary props plus these three special props.

| Placement | Template | Resource | Region | Bounds left/right/bottom/top |
| --- | --- | --- | --- | --- |
| 1051 | 52 | 476 | 800 | -10 / 10 / 0 / 5 |
| 1057 | 51 | 475 | 800 | -13 / 15 / 0 / 20 |
| 1058 | 50 | 474 | 802 | -15 / 15 / 0 / 20 |

All three templates have one state, one frame and height flags0; all placement
selectors are0. Record1057 has horizontal frame flip0x40. Bounds use the same
previously recovered state-width/frame-trim arithmetic as ordinary props.
Original anchors are preserved, with the existing Godot coordinate translation;
no floor snapping or arbitrary sprite resizing is applied. The exporter records
source offsets and bytes, cache/MIX hashes, and initial remap provenance.

Export from the RE repository:

```sh
python3 tools/draracle/export_special_prop_placements.py --game-root /path/to/lol2 --out /path/to/godot/assets/lol2/generated/special_prop_review
```

After building the complete indexed cave assets, run from the Godot repository:

```sh
flatpak run org.godotengine.Godot --path /path/to/godot res://scenes/lol2/special_placed_prop_review.tscn -- --capture-special-cave --special-record=1057
python3 tools/verify_special_placement_capture.py --record 1057
```

Use1051 or1058 to inspect the other placements. Omit capture to leave the fixed
view open. No movement or resize is supported. The camera starts at the recorded
floor region's vertex-average position and looks toward the selected sprite,
slightly from above. This is an inspection camera, not a recovered game camera.
The generic110-unit inspection orbit crossed walls in this narrow area; only
the camera was adjusted, never the original anchors.

Each sprite has its own indexed source viewport. Fixed-Y billboard planes are
parallel and sorted by horizontal camera depth for this fixed view. This is a
preview rendering policy, not proof of native draw order. Background indices
are remapped before RGB resolution; unresolved-floor and roof policies remain
those of the indexed cave. No interaction/spawn/gameplay parity is claimed.

Validation on Godot4.7.2 Compatibility/RX9070XT:

| Inspected record | Visible special pixels | Final RGB mismatches |
| --- | ---: | ---: |
| 1051 | 2792 | 0 |
| 1057 | 22339 | 0 |
| 1058 | 3957 | 0 |

All three intermediate index/marker layers in each view also match the CPU
reference across518400 pixels. Final-image coverage totals1555200 pixels.
The checker requires the selected sprite to have visible special pixels,
preventing empty/fully hidden views from passing. All three resolved images
were visually inspected. The controlled overlap fixture still passes2776
double-remap pixels and33132 depth samples after its shared-code refactor.
Captures/reports are in captures/special_placed_RECORD/.

Still separate: moving-camera updates/sorting, broader performance work,
original screenshot/lighting parity and default-demo integration. Templates86
and87 are single-state special sprites with flag1 (11 placements); template82
has21 states (2 placements). They are identified as further work, not included
by assuming a state or flag meaning. Enhanced lighting remains optional later.
