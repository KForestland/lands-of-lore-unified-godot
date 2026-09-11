# Diagnostic wall texture review

Launch `tools/lol2/run_wall_review.sh`. N/P or left/right arrows cycle through
exported walls. The default is rock wall2168; photo material3 is labelled.
The scene shows original file-palette textures with inferred UVs, unlit and
without transparency. It does not replace cave collision or geometry.

Local assets are required under assets/lol2/generated/wall_review: walls.json
(the RE export_flat_wall_uvs.py flat_wall_uvs.json output), plus material_ID.png
for each referenced descriptor (the corrected RE wall review's first variant,
mip0). Generated game assets are excluded from Git. The RE tools accept local
game paths; see KForestland/lands-of-lore-2-re docs/wall-texture-review.md.

Validation: --wall-smoke loads946 meshes and14 textures; --wall-capture saves
captures/wall_texture_review.png. Rendered output inspected on the local Godot
OpenGL compatibility renderer. Live original-game visual parity remains open.

The review now supports2035 rectangular walls and22 textures. A nearest-filter
shader handles clamp/clamp, repeat/clamp and repeat/repeat per fragment. The
original946-wall set was accepted visually by the project owner before this
expansion. All2035 meshes load in smoke; GPU capture succeeds. The added walls
remain diagnostic and have not received that same user visual acceptance yet.

Jump directly to a record with `tools/lol2/run_wall_review.sh -- --wall-id=2702`.
Unknown or malformed IDs exit with an error. Wall2702's blue file-palette image
was audited against original indices (16384 pixels, zero mismatches); direct
selection and its GPU capture were checked. Live lighting remains unverified.
