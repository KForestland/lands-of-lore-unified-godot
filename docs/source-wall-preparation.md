# Prepare source wall geometry

Start with fresh geometry and its ceiling-subdivision patch as described in `creature-navigation-preparation.md`. Then run the existing wall replay against the original installation:

```sh
LOL2_RE_ROOT=/path/to/lands-of-lore-2-re \
python3 tools/lol2/map_source_walls.py \
  --game-root /path/to/original/game --root /path/to/fresh/maps --area L1_DC
```

Repeat for L3_DH, L4_HJ and L5_HC. The root must contain `<AREA>/geometry/geometry.json`; output is `<AREA>/geometry/source_walls.json`. The command prints per-area results and returns a nonzero exit code if any requested area fails. Library callers still receive the list of results from `main`.

Dependencies are Python 3, Capstone (verified with 5.0.7), the published geometry profiles, `re_helper_root.py`, and four companion-RE modules: `lol2_extract_draracle_geometry`, `lol2_verify_flat_wall_spans`, `lol2_verify_target_resolver`, and `lol2_verify_draracle_slopes`. All four were tested from an isolated copy of published commit 2791eb11e453ad5cbccdce5d5d29efc1850a2d3c. An explicit invalid helper root is rejected. The original archive, geometry and executable hashes remain required.

Independent exports from freshly regenerated geometry matched all four existing wall JSON files byte for byte. No wall replay or interpretation rule changed. A separate CLI run matched the Cave output, and missing-game/invalid-helper controls returned failure without replacing it. This does not certify complete area scenery, runtime rendering or a full clean game build.
