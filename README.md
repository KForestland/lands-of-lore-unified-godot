# Lands of Lore II in Godot

Lands of Lore: Guardians of Destiny (Westwood, 1997) rebuilt in Godot 4.

**Latest status: [status report 2026-11-06](docs/STATUS_2026-11-06.md)** (about 60% of a complete Classic LoL2; previous: [2026-10-31](docs/STATUS_2026-10-31.md)).

## What this project is

- **Classic edition:** the original game's maps, scripts and behaviour, run from the
  original data. The original's own script records run on a native script host that
  follows the decoded executable. Every original bug is fixed, and every intentional
  difference is logged in the [deviations ledger](docs/DEVIATIONS.md).
- **Enhanced edition (later):** modern lighting, quality-of-life and wider outdoor
  maps on the same engine. See [Enhanced edition ideas](docs/ENHANCED_EDITION_IDEAS.md).

Original game files are not included and never will be. You need your own copy of the
game (the GOG release); the project builds its assets from it.

## State of this repository

**Code snapshot r17 (2026-11-07), work in progress.** This is the current Classic LoL2 code (build r17, which passed the
project's full qualification: Act 1 campaign chain, packaging and smoke tests). Earlier versions here were a September
2026 snapshot.

- **Status 2026-11-11 (the code here is still the r17 snapshot):** about **20% of the finished game**, most likely
  complete in **July 2027**; see the [LoL2 roadmap](https://github.com/KForestland/lands-of-lore-ai-comms/blob/main/LOL2_ROADMAP.md).
  Act 1 plays start to finish; Act 2 is built to the Claw Mountains but does not yet hold up for a player without help
  (the owner's latest playtest stopped in the Dracoid Cemetery); Act 3 is partly built. Combat, items, spells, dialog,
  music and the game's menus are the larger share of the remaining work.
- **No original game files are included.** The original game's art, sound, movies and data are not here and never will
  be: you build them from your own copy of Lands of Lore II (the GOG release) with the project's tools. Some test fixtures
  hold numbers measured from the original program while it ran; they contain no art, sound or text.
- Developer notes from the working tree: [docs/DEVELOPER_README_r17.md](docs/DEVELOPER_README_r17.md); every intentional
  difference from the original: [docs/DEVIATIONS.md](docs/DEVIATIONS.md).
- How the project works (AI lanes, checks, playtests): [METHOD.md](https://github.com/KForestland/lands-of-lore-ai-comms/blob/main/METHOD.md).
  Status and plans: [master plan](https://github.com/KForestland/lands-of-lore-ai-comms/blob/main/MASTER_PLAN.md).
- Modding: not supported yet. A Factorio-style mod system (mods load on top, Classic stays clean) is planned after a stable
  Classic release. Questions and findings are welcome as issues in the ai-comms repo.

## Related repositories

- Format research for LoL2: https://github.com/KForestland/lands-of-lore-2-re
- LoL1 research (closed): https://github.com/KForestland/lands-of-lore-1-re

## Licence

The project's own code and docs are MIT licensed (see [LICENSE](LICENSE)). Lands of Lore
and all original game content belong to their rights holders and are not covered.
