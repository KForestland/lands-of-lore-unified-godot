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

## Placed static props

354 instances now visible from templates16/21/23/24: vegetation, stalagmite
and boulder sprite candidates. B toggles. Direct inspection:
`tools/lol2/run_textured_cave.sh --prop-record=196` starts in fly mode facing
vegetation; N/P returns to checkpoints. Optional --walk-capture saves a view.

Build assets with RE `export_cave_prop_preview.py --game-root GAME
--sprites SPRITE_PREVIEW_OUTPUT --out GODOT/assets/lol2/generated/prop_review`
on one line, after running the sprite preview extractor. Assets ignored by Git.

Positions and state/frame dimensions come from source. Renderer129300..129377
supports width/height and frame trims by disassembly. Alpha, fixed-Y billboard
and frame-flag orientation remain provisional. No prop interactions/collision
or native spawn-state parity. Column28 deferred because of region-height flag2.
Clean354-instance smoke and GPU record196 capture inspected.

## Region-height columns

The preview now includes88 template28 columns, bringing the total to442
props. Inspect one using `--prop-record=0`. B toggles all props.
The native height selector F1DD2..F1E12 passes88 source and72 synthetic
cases: template bit2 with a region uses signed ceiling-floor, capped255
and stored as a byte; otherwise it uses the state height. Original anchors
remain intact, including nine that differ from the base region floor.
Source region association is supplied rather than live-captured.

This supersedes the earlier column exclusion. Column0 GPU view inspected;
clean442-prop smoke and33 Python tests pass. Billboard/alpha/spawn and
interaction/collision limitations still apply.
