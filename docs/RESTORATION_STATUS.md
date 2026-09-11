# Lands of Lore 2 restoration status

The current experimental full-cave view assembles all recovered static floor
geometry in one world: 1,953 floor polygons, 1,939 ceilings, 1,338 boundary quads
and 955 provisional interior spans. Floors use original extracted pixels where
bindings are available; unresolved materials are pink. This is not a completed
1:1 remake. Wall geometry and floor UVs remain provisional; native wall textures,
special openings, objects, actions, hazards and sound need further work.

## Run the local build

With generated assets available, run `tools/lol2/run_full_cave.sh` from any directory.
It uses an installed `godot` executable, falling back to Flatpak Godot.
WASD/mouse move/look, Shift sprints, F toggles inspection flight, Space/Ctrl move
vertically in flight, N/P jump to checkpoints, and R resets. Escape releases the
mouse. These controls and dimensions are experimental, not recovered native movement.

See [full-cave notes](FULL_CAVE_WALK.md) for validation and fidelity limits.
The full-world sprint checks cover a continuous 79-waypoint route and 119 separate
checkpoint routes; they do not prove every cave connection is traversable.

## Contributor setup limitation

Generated game assets and screenshots are excluded from Git. A fresh clone is
not yet a self-contained extraction pipeline or playable cave download.
The Python exporters currently consume evidence artifacts from Bob's local
`/home/bob/lol2_out` workspace, including decoded geometry, descriptor bindings,
replayed setup values and recovered lookup tables. Several extraction tools and
the original game files live outside this repository. The exporter defaults
still contain those local paths. Do not treat missing assets as a Godot bug.

The next packaging task is to bundle the required source-only extraction tools
with configurable input/output paths and document their dependency order, so
contributors can regenerate assets from their own game installation.

## Latest wall evidence

3,052 eight-byte wall records partition across 1,471 regions without gaps or
overlap. Native instruction-span checks agree on region indexing and surface
fields. The static wall resource consumer maps their signed first word to 30
compact resource descriptors, with 3,052 checks and zero mismatches. These are
host replays of original instructions, not live gameplay captures. Explicit
loader-to-global provenance and native wall-span geometry still need closure
before those bindings are applied to the Godot shell.
