# Original cave shell review — 2026-09-11

The original-layout Godot review now includes 1939 primary-region ceilings and
1338 absent-neighbor boundary-wall quads alongside 1953 floor quads. Child floor
subdivisions do not receive standalone ceilings or walls. Boundary spans use the
same recovered floor/ceiling endpoint heights as the geometry-v2 preview; this
is not complete native wall-span reconstruction. Interior steps, jambs, special
connectors, moving walls and collision remain open.

Run `/home/bob/run_lol2_original_floors.sh`. B toggles boundary walls; C toggles
ceilings (initially hidden so the overview remains visible). Existing drag/zoom,
arrow pan and T texture toggle remain. Walls and ceilings use neutral materials,
with review lighting, rather than invented original material assignments.

Validation: headless Godot load/count check passes all four geometry totals.
GUI render captured and visually inspected. Floor UVs remain diagnostic; no
playable-cave or complete enclosure claim. No automatic collision was created.

Changed files under `/home/bob/lands-of-lore-unified-godot`:
`tools/lol2/import_original_floors.py`,
`scripts/lol2/original_floor_review.gd`, regenerated floor review assets and
`captures/original_floor_review.png`.

Next: inspect interior close-up and resolve missing interior wall spans and
special openings, then validated collision and wall/ceiling materials. Keep the
original authored cave as the playable default until traversal is verified.

---
Historical floor-only checkpoint follows.

# Original cave floor review in Godot — 2026-09-11

A separate review scene now imports 1953 original floor quads and assigns 1860
texture candidates from verified preset/descriptor identities. The other 93
are pink. The parent floor with subdivisions is omitted in favor of its child
polygons. Source vertices/heights and 0–2 triangulation are preserved at a
provisional display scale of 1/64. No walls or collision are included.

Run `/home/bob/run_lol2_original_floors.sh`.
Drag to orbit, wheel to zoom, arrows to pan, T to toggle textures.
The authored playable cave remains the default scene.

The texture projection is DIAGNOSTIC: planar XY input to recovered rotation/scale
and offset arithmetic, native-candidate storage axes, first variant only, no
slope-specific projection. Python projection currently uses unbounded arithmetic
rather than every original signed wrap. These are not final 1:1 UVs. Generated
Godot review mipmaps reduce overview aliasing; they are not original mip selection.
Direct file palette and unshaded rendering are not a live lighting reproduction.

Files in `/home/bob/lands-of-lore-unified-godot`:
- tools/lol2/import_original_floors.py: reproducible evidence-to-review conversion
- scripts/lol2/original_floor_review.gd: orbitable review scene
- scenes/lol2/original_floor_review.tscn
- assets/lol2/generated/original_floors/: generated geometry and textures
- captures/original_floor_review.png: inspected render

Validation: Godot headless smoke reports 1953 quads and 1860 texture candidates;
GUI render completed and was visually inspected. Overview exposes unresolved
areas and some conspicuous water/UV patterns for further comparison. No claim
of playable original-cave fidelity. Next: close native UV projection on one
reference area, compare a close view against the original video, then bring in
wall spans and collision. Remake remains primary; native patch is secondary.
