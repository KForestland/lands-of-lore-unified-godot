# Lands of Lore II in Godot

Lands of Lore: Guardians of Destiny (Westwood, 1997) rebuilt in Godot 4.

**Latest status: [status report 2026-10-31](docs/STATUS_2026-10-31.md).**

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

The code here is a **September 2026 snapshot** (the Draracle Caverns research build).
Development continues locally; the current work (Act 1 playable start to finish, all
Act 2-3 maps walkable, the native script host, HUD, help and journal) is not published
yet. It will be published as a cleaned snapshot without any original game media.

Docs that describe the current local build:

- [Status report 2026-10-31](docs/STATUS_2026-10-31.md): progress per area and estimated time
- [Restoration status](docs/RESTORATION_STATUS.md): what works, how it is tested, known limits
- [Deviations ledger](docs/DEVIATIONS.md): every intentional difference from the original
- [Classic HUD](docs/classic-hud.md), [help system](docs/help-system.md), [My Journal](docs/my-journal.md)
- [Enhanced edition ideas](docs/ENHANCED_EDITION_IDEAS.md)

Docs that describe the September snapshot in this repository:

- [Executioner combat core](docs/executioner-combat-core.md)
- [Standalone cave demo packaging](docs/standalone-demo.md)
- [Full cave walk](docs/FULL_CAVE_WALK.md) and the other Cave reviews in `docs/`

## Related repositories

- Format research for LoL2: https://github.com/KForestland/lands-of-lore-2-re
- LoL1 research (closed): https://github.com/KForestland/lands-of-lore-1-re

## Licence

The project's own code and docs are MIT licensed (see [LICENSE](LICENSE)). Lands of Lore
and all original game content belong to their rights holders and are not covered.
