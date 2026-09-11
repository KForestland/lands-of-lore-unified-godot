# Textured cave preview

Launch `tools/lol2/run_textured_cave.sh` after building both original-floor and
wall-review generated assets. This separate scene places 2,373 recovered
wall spans across the complete walking map. T compares textured walls with
provisional walls; WASD moves, Shift sprints, F flies, N/P changes checkpoints.

The scene recovers the walk-map translation from its first floor anchor.
For the current assets this is (4, 430, 12794); all 1,953 floor polygons
match original coordinates scaled by64 plus this translation exactly.
The wall UV mappings remain unchanged. Native wall surfaces replace the
provisional vertical visual spans; floor, ceiling and walking collision remain.
42 material/addressing combinations batch 27 texture descriptors. First
variants only; no native visibility culling, transparency or lighting parity.
Missing spans may leave visual gaps; F allows inspection past old collision.

Validation: clean scene smoke, inspected GPU capture, all119 checkpoint
routes with zero resets. Original walk scene defaults remain unchanged.

The tracing preflight passed for the existing material hook, but its L20
capture does not establish the guest address for the cave descriptor watch.
No new live trace was launched and no runtime-table handoff is claimed.
Further guest address mapping is required before a meaningful pointer watch.
