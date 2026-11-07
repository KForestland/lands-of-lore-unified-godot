# Movable and static-assembly preparation

Install the exporter as `tools/export_map_movables.py`. `--tools-root` is that tools directory. It is not the repository root and it is not `tools/lol2`.

```
<install>/
  docs/game-geometry-profiles.json
  tools/export_map_movables.py
  tools/lol2/map_materials.py
  tools/lol2/map_surfaces.py
  tools/lol2_rotation_table.py
  tools/lol2_source_format.py
  tools/lol2_texture_container.py
  tools/lol2_material_format.py
  re/tools/draracle/   # the fourteen published files named below
```

```sh
python3 -B <install>/tools/export_map_movables.py \
  --game-root /path/to/original/game \
  --material-root /path/to/fresh/materials \
  --re-root <install>/re \
  --tools-root <install>/tools \
  --area L3_DH \
  --placement-kind static_assembly \
  --out /path/to/fresh-output
```

## `--tools-root`

`--tools-root` is the directory that contains the installed program and the published Godot readers from `d6bff86f3c5f7ad75239f24480bf41a64b56893f`:

- `export_map_movables.py`
- `lol2/map_materials.py`
- `lol2/map_surfaces.py`
- `lol2_rotation_table.py`
- `lol2_source_format.py`
- `lol2_texture_container.py`
- `lol2_material_format.py`

The parent of `--tools-root` must contain `docs/game-geometry-profiles.json`. Published `tools/lol2/map_materials.py` sets `REPO_ROOT = Path(__file__).resolve().parents[2]`. With the file at `<tools-root>/lol2/map_materials.py`, `parents[0]` is `lol2`, `parents[1]` is `--tools-root`, and `parents[2]` is the parent of `--tools-root`. The inventory read is `<parent-of-tools-root>/docs/game-geometry-profiles.json`. There is no second search path and no shop-checkout fallback.

## `--re-root`

`--re-root` is a tree whose `tools/draracle/` holds the published RE `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c` closure. The program inserts only that `tools/draracle` directory. It does not read `LOL2_RE_ROOT` and it does not fall back to a checkout.

Direct binds are `lol2_verify_draracle_slopes.py` (`EXE_HASH`), `lol2_verify_spatial_constructor.py` (`ConstructorReplay`), `verify_chain_rotation.py` (`model`), and `verify_creature_states.py` (`signed`). The import closure in the same commit is those four plus:

- `lol2_extract_draracle_geometry.py`
- `lol2_verify_target_resolver.py`
- `lol2_cache_named_wall_fixture.py`
- `extract_creature_states.py`
- `catalogue_cave_entities.py`
- `extract_prop_sprite_previews.py`
- `lol2_extract_cave_materials.py`
- `lol2_palette_png.py`
- `lol2_wall_material_checkpoint.py`
- `lol2_pixel_layout.py`

Capstone and Pillow are host libraries that closure already imports. `tools/lol2/map_movables.py` is unpublished. Published `map_materials.py` has no `RE_TOOLS` attribute.

## Materials root

`materials_root` in the written report is `candidate.parent.resolve()` for the first existing file among:

1. `<material-root>/<AREA>/materials/materials.json`
2. `<material-root>/<AREA>/materials.json`
3. `<material-root>/materials.json`

Consumers such as `prepare_museum_control96.py` copy `Path(materials_root) / face['material']`. Image paths in the bundle are relative to the selected `materials.json`, so the report records that parent for every accepted layout. The CLI `--material-root` is only the search root.

The selected bundle must bind to the area being exported: `area_id`, `source.file`, `source.sha256`, and `source.geometry_key` match `docs/game-geometry-profiles.json`. A missing bundle, a wrong area, or an archive mismatch raises before an output directory is created.

Every `faces` and `state_faces` entry must name a relative image with no `..` component. `Path(materials_root) / material` must stay inside that directory and must already be a file. The check runs before `mkdir`. A missing image raises and leaves no output directory. A resource id that is absent from the bundle stays an issue row and does not invent an image. Type1 geometry stays in unpublished `tools/lol2/map_primitive_geometry.py`.

`--placement-kind` is `movable` or `static_assembly`. `--out` must be a new directory and must not overlap the game, material, RE, or tools path. One area and one placement kind per run. The rotation table is `lol2_rotation_table.rotation_table(game_root)` and must match `d7c7437da1c1be8f1d19e78433e8a976f19a90fe8004827a36dc383470294c53`. The constructor span `0xAE99A..0xAE9CE` is the existing bounded witness.

Writes are one `movables.json` after the checks. An error before that write leaves no output directory. A failure during the final write can leave an empty directory. Pose and archive checks use `require`, which stays active under normal Python.

No motion, trigger, collision, or rendered parity is claimed.
