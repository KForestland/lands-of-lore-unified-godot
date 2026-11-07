# Generic static-assembly renderer

One producer and one runtime node draw every original static assembly of a map that no feature host already draws.

```
python3 tools/prepare_static_assemblies.py --game ~/lol2_runtime_root \
  --re-root ~/lol2_re_publish_20260911 --area L1_DC   # or L3_DH
```

- **Producer** (`tools/prepare_static_assemblies.py`):
  - Exports the map's materials (`lol2/map_materials.py`) and all static-assembly placements (`tools/export_map_movables.py`).
  - Writes `assets/lol2/generated/static_assemblies/AREA/` (gitignored like the other packs).
  - Indexed areas (Cave) get `mip_0_indices.png` images for the indexed surface shader. Colour areas (Museum) get RGBA `mip_0_palette.png`.
  - `cutout` is set when the palette image has transparent pixels.
- **Owners** (`scripts/lol2/static_assembly_owners.json`):
  - Lists the assemblies drawn by feature hosts (curtain, control96, rubble blocks, portraits, broken case, escape wall, rapids controls, Mana-foil stone); they are skipped.
  - The producer refuses to build when an unlisted assembly face coincides with a face in the listed host packs.
  - A new host that starts drawing an assembly must add it here.
- **Runtime** (`scripts/lol2/static_assemblies.gd`):
  - `setup(host, area)` draws initial-mode faces, batched into one mesh per material.
  - Assemblies with other-mode faces get their own meshes. `set_mode(assembly, mode)` selects faces by `mask & (1 << mode)`, as the original mode byte does.
  - Cave meshes use layer 2 plus the host's occluder and lighting copies; they are added before `_build_lighting()`.
  - Builds native-data box collision for drawn, unscripted solids at least 16 units tall (mode 3: one box per child record). Feature-owned colliders and separately moved assemblies are excluded. `tools/prepare_static_collision.py` generates the pinned box records; see `docs/DEVIATIONS.md` for low-object and zero-depth adapters.
- **Hosts:** `cave_walkthrough.gd` (before `_build_lighting`), `museum_walkthrough.gd` (after the rubble blocks).
- **New maps** (Jungle, Hive, Act 2/3) need:
  1. an `AREAS` row in the producer,
  2. an owners entry,
  3. a producer run,
  4. a `setup(self, AREA)` call in the area host.

## Counts (2026-10-20)

| Map | Placements | Owned by hosts | Drawn | Initial faces | Stateful | Without type0 faces |
|---|---|---|---|---|---|---|
| L1_DC | 174 | 6 | 114 | 616 | 0 | 54 |
| L3_DH | 191 | 25 | 93 | 1049 | 40 | 50 |

Before this, the Cave drew 6 static assemblies through feature hosts and the Museum 25.

## Open

- **Type1 children** (attached props) are not exported by this exporter: 17 in the Cave, 1 in the Museum (`open_children` in the pack). The museum wall brackets and the cave torches are likely among them.
- **Collision:** added 2026-10-21: 21 Cave and 10 Museum generic boxes after scripted/host exclusions. The regression checks Cave crates 96/97 blocking the capsule. Native placement flags/template dimensions are pinned; the Godot box/step behavior remains an adapter. The corner test asserts all Cave boxes (20 of 21 angled, e.g. timber frames 64–71 at heading 18204) and all Museum boxes (axis-aligned) against the native formula, so a wrong rotation sign fails.
- **Not wired to `set_mode` yet:**
  - Museum key locks (template36: 78, 87, 113, 114, 140) are drawn in their initial empty state. `museum_key_locks.gd` doesn't call `set_mode` when a key goes in.
  - Sconces 117–139 have only state faces (the fire, drawn by the key-lock flames host).
- **Animated materials** (variant frames) are drawn at frame 0.
- **Banner 89:** one face coincides with a review wall face (`review_coincident`), so it may z-fight.
- **Lighting:** none; all faces are unshaded, like the rest of the Museum.
