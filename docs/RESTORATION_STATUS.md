# Lands of Lore II restoration status

Updated: 2026-10-31. This describes the current local build (r12t). The code published
in this repository is the older September snapshot; see the README.

## What works

- **Act 1, start to finish:** Draracle Caverns, the Museum, the Huline Jungle, the
  Hive, the village and the optional Dark Halls detour. The owner played it through on
  2026-10-31 and reported few issues.
- **Acts 2 and 3:** all ten later maps (L8_SJ, L9_DR, L10_DC, L12_CM, L13_RC, L14_HT,
  L16_CA, L17_HC, L19_BC, L20_BB) are built from the original geometry and are walkable
  through preview starts. Level-to-level exits are being connected; most already run the
  original exit scripts.
- **Native script host:** the game's own command records run on a host that follows the
  decoded original code (opcodes, timers, hit filters, record kinds). About 42% of all
  script groups are hosted. Mechanisms not yet decoded are left unhosted rather than
  guessed; where a workaround was needed it is an adapter logged in the deviations ledger.
- **Interface:** the original HUD (portraits, morph animations, 150-350% UI scale), the
  original in-game help system, My Journal, and the original transformation curse rules.

## How it is checked

Every change runs an affected-test set (about 320 headless and 270 rendered tests), and
every build runs scripted campaigns through Act 1, a package audit and a smoke test
before it reaches the owner's playtest launcher. Rendered tests compare against frames
from a full original longplay.

## Not done yet

- Items across the whole game (Act 1 items work)
- RPG stats and progression
- Dialog and dialog logic (the village dialog is broken)
- Combat polish, magic, sound
- Act 1 leftovers: some puzzle mechanisms, lighting, the village

Phase order: maps, then items, RPG, dialog, small fixes; sound and combat polish last.

## Assets

No original game data is in this repository. The asset producers read the user's own
game files; publishing a self-contained pipeline is part of the next code snapshot.
