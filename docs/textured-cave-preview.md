# Textured cave preview

Launch `tools/lol2/run_textured_cave.sh` after building both original-floor and
wall-review generated assets. This separate scene places 2,373 recovered
wall spans across the complete walking map. T compares textured walls with
provisional walls; WASD moves, Shift sprints, F flies, N/P changes checkpoints.

The scene recovers the walk-map translation from its first floor anchor.
For the current assets this is (4, 430, 12794); all 1,953 floor polygons
match original coordinates scaled by64 plus this translation exactly.
The wall UV mappings remain unchanged. Native wall surfaces replace the
provisional vertical visual spans; floor and walking collision remain. The 1,939 original ceiling faces now
use recovered rock134 with provisional planar UVs and a darker preview tint.
Ceiling material assignment is not native-verified. C toggles the roof.
42 material/addressing combinations batch 27 texture descriptors. First
variants only; no native visibility culling, transparency or lighting parity.
Missing spans may leave visual gaps; F allows inspection past old collision.

Validation: clean scene smoke, inspected GPU capture, all119 checkpoint
routes with zero resets. Original walk scene defaults remain unchanged.

The tracing preflight passed for the existing material hook, but its L20
capture does not establish the guest address for the cave descriptor watch.
No new live trace was launched and no runtime-table handoff is claimed.
Further guest address mapping is required before a meaningful pointer watch.

Roof validation: 1,939 original ceiling polygons match the walking fixture
exactly after scale/translation. Clean Godot smoke and GPU capture inspected.
Existing collision faces and the original ceiling triangle split are preserved.

## Path to a public playable demo

1. Verify ceiling material selectors and remaining wall gaps against original views.
2. Recover one plant/static-prop class, its image/transparency and placement fields;
   validate a few witnesses before applying it across the map.
3. Recover one enemy class, correct sprite sequence and spawn conditions, then
   movement/combat. Named patrol/home markers alone do not prove spawns.
4. Add verified bridge/chain interactions, triggers and hazards.
5. Package a reproducible demo, test a fresh installation and document remaining
   differences before a forum release.

Available research inventory: 1,559 spatial records, 101 action records,
52 named-state candidates and 92 markers. Marker names include roach paths,
monster homes, guard paths and fireflies. Classes, asset binding, animation,
spawn conditions and behavior still need evidence; no plants/enemies are
added by the roof change. Audio remains deferred.

Direct checkpoint navigation: `tools/lol2/run_textured_cave.sh --checkpoint=14`.
Valid checkpoint numbers are 1–119. The RE object catalogue links placement
groups to nearby checkpoints for identification work. It does not spawn props.
