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

Prop frame mirroring (2026-09-11): the native sprite setup uses frame bit
0x40 for horizontal reversal and 0x80 for vertical reversal. The preview
now applies these through per-flag material UV transforms. Current placements
include 142 horizontal flips and no vertical flips, among 442 props.
The bounded native setup replay passes all 256 flag bytes on two unclipped
rectangles (512 cases). This does not establish full clipping, shading,
alpha or billboard parity. Godot smoke and rendered record365 inspection
passed; 33 extraction tests passed. Wall UVs retain their prior behavior.

Expanded static props (2026-09-11): added202 placements using already
decoded resources278/302/417, templates13/14/15/17/18/19/20/22/46.
Total644; all442 previous prop records compare identical. Source single-state,
single-frame, resource flags and dimensions pass existing exporter checks.
Both Godot copies updated. Headless644-prop smoke and45 tests pass.
GPU checkpoint14 inspected. Prop inspectors343/134 were occluded by walls;
fixed110-unit camera offset needs improvement, not treated as visual proof.
No prop collision or creature spawn changes. Creature frame binding remains
open. Source artifact lol2_out/draracle_expanded_props_2026-09-11/.

Prop inspection camera corrected (2026-09-11): after physics registration,
--prop-record samples16 horizontal directions using cave collision, keeps
the original view when clear, otherwise selects the greatest clearance
(up to110 units,6-unit wall margin). Player collision is excluded. It warns
if no8-unit horizontal view exists; this is not a guarantee for every
possible prop or occlusion by non-colliding props.
Rendered343 boulder and134 vegetation inspected successfully (previously
both blocked by walls); clearance97.2 and110 units respectively. Clean
644-prop/2373-wall/1939-ceiling smoke. Both working copies updated. Prop
positions and walking collision unchanged. Creature placement still open.

Rock formations expanded (2026-09-11): resources297/298/299/300/301 added
through the existing28E decoder. Nine total sprite resources pass44 mip
images/3142 row checks. Thirteen additional static templates supply366
placements; total1010. All644 previous placement records remain identical.
Original positions, state dimensions and trim/flip fields retained.
Headless1010-prop smoke passed; GPU252 hanging rock and273 floor rock
visually inspected.45 tests pass. Both local Godot trees updated.
Source artifacts: lol2_out/draracle_rock_previews_2026-09-11/ and
lol2_out/draracle_rock_props_2026-09-11/. Alpha, billboarding and shading
remain provisional; no prop collision or creature placement changes.

Additional pillars (2026-09-11): resources295/296 decoded with the28E
row parser;11 total sprite resources now54 mips/4058 rows checked.
Templates56/57/60/61/62/64 add86 placements, total1096; previous1010
records unchanged. Template60 has no placements. Height replay expanded
with explicit --templates selection and source flag checks:174 source
cases plus72 synthetic,zero mismatches. GPU169/363 inspected both styles;
1096-prop smoke and45 tests pass. Both Godot trees updated. Source artifacts
lol2_out/draracle_pillar_{previews,heights,props}_2026-09-11/.
Alpha, billboarding and lighting remain provisional; no prop collision
or enemy placement added.
