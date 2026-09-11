# Connected original-cave walk — 2026-09-11

Update: now 21 regions, walk speed 80, Shift sprint 144. See
CONNECTED_WALK_EXPANSION.md for current validation and coverage.
The 12-region figures below describe the initial checkpoint.

Launch `/home/bob/run_lol2_connected_walk.sh`.
WASD/mouse move/look; Escape releases the mouse; click recaptures; R resets.
Falls automatically reset. The earlier local-pair launcher remains available.

The largest component of the 119 tested seam pairs contains 12 regions:
1377, 1378, 1384, 1387, 1440, 1444, 1449, 1450, 1451, 1472, 1473, 1474.
All have original cave-floor material 134. Their vertices share one translated
original-unit coordinate frame, enabling continuous movement without switching
samples. The render retains diagnostic UVs and original floor pixels.

Coverage: 12 tested internal seams, 12 ceilings, four candidate interior spans,
zero absent-neighbor boundary quads. Twenty directed exits lead outside the
sample and are marked with amber lines without collision caps. Four internal
neighbor directions (two pairs) are outside the selected tested-seam graph;
no traversal claim is made for them. Detailed indices and exit vertices are in
assets/lol2/generated/original_floors/connected_walk_audit.json.

Validation: a continuous depth-first tour completed all 43 waypoints through
the component and returned without any fall reset. The tour crosses a spanning
tree, not every internal edge. The actual-scene smoke for all 119 old pair samples
also passes. GUI capture captures/connected_walk_review.png was inspected:
rock floor and amber omitted-exit markers are visible, with open black space
beyond the selected geometry. No manual gameplay check claimed.

```sh
python3 tools/lol2/build_connected_walk.py
flatpak run org.godotengine.Godot --headless --fixed-fps 60 --path . res://scenes/lol2/original_walk_review.tscn -- --connected --walk-smoke
```

This remains a partial experimental area. Capsule dimensions, speed and eye
height are assumptions. Interior spans are geometric candidates, not verified
native walls; no doors, hazards or action semantics are added. Automatic reset
prevents an unrecoverable fall, not departure through open exits. Next: inspect
and extend the 20 outgoing links with adjacent original geometry and explicitly
classify their steps, walls and special-connector needs.

## Correction to earlier traversal notes

The fixture generator selected all exported shell faces owned by a region,
including candidate interior spans. Earlier notes saying only boundary walls
and ceilings were included understated that scope. The experiments used those
provisional interior spans too; the numerical results stand, but they do not
validate native wall semantics. This connected area's four interior spans are
now counted explicitly.
