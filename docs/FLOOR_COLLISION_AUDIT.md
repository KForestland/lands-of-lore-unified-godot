# Original floor collision audit — 2026-09-11

An isolated Godot 4.7.2 ConcavePolygonShape3D now checks the recovered original
floor triangles without altering the review scene or original geometry.

## Results

- 1,953 quads yield 3,906 triangles on the original 0–2 diagonal.
- Eight degenerate/projected-degenerate triangles are skipped explicitly.
- Four interior probes per remaining triangle: 15,592 rays over 3,898 triangles.
- Review scale (original coordinates / 64): four misses, all on region 1195,
  triangle [0, 1, 2]. The other 15,588 rays pass.
- Original coordinate scale: all 15,592 rays pass.
- An outside empty-space probe passes at both scales.

The exceptionally thin region-1195 triangle is retained. These measurements
establish scale-sensitive Godot ray collision behavior, not a malformed source
polygon or a need to change source triangulation. Exact engine tolerance cause
has not been isolated. The review scale remains unchanged.

## Reproduce

From the project directory:

```sh
flatpak run org.godotengine.Godot --headless --path . res://scenes/lol2/floor_collision_audit.tscn
flatpak run org.godotengine.Godot --headless --path . res://scenes/lol2/floor_collision_audit.tscn -- --native-scale
```

The first command intentionally exits 1 to expose the known failures; the second
exits 0. Reports are captures/floor_collision_audit.json and
captures/floor_collision_native_scale.json. Failures identify region, triangle,
and barycentric probe coordinates.

## Limits and next step

This is isolated floor ray testing, not playable traversal or native collision
parity. Backface collision is enabled. Four interior samples do not prove all
surface points or seams, and overlapping faces may satisfy a ray without proving
which source triangle was hit. Walls, ceilings, hazards, doors, player capsule,
step height, and movement are untested. Original units are not yet calibrated to
player dimensions. Next: a bounded capsule-and-seam traversal experiment with
explicit scale and player-size assumptions, before adding collision to the review.
