# Hive Wax and Wax Runes preparation

With Python/Pillow installed, use separate absent staging roots:

```sh
python3 tools/prepare_hive_wax.py --game /path/to/original/game \
  --source docs/game-geometry-profiles.json --output-root /path/to/fresh-wax
python3 tools/prepare_hive_wax_runes.py --game /path/to/original/game --output-root /path/to/fresh-runes
```

Produces `assets/lol2/generated/hive_wax` and `hive_wax_runes`, two files each. The Wax command also emits `docs/hive-wax-source.json`. All four runtime files and that report match the existing outputs byte-for-byte. Both extraction bodies are unchanged, apart from the Wax source-profile path becoming explicit.

The shared Wax reader now uses the three published local archive/material/creature readers directly, removing its import-time native/RE dependency. The historical default ROOT/GAME and exported helper functions remain available to older preparers. The explicit commands pin GLOBAL/LOCAL archives; Wax additionally pins the Hive archive and geometry profile. Original item0 placement/definition73/resource109 and Wax Runes definition74/resource108 are extracted with their existing identity, image and pixel checks.

Both commands pass isolated runs with only their producers and the three readers. Each passes existing-output, missing-game, altered-archive and overlapping-output checks. No generated asset input or native replay is needed. The no-argument historical paths remain available. Output must be absent and outside the inputs; later failures may leave partial output, so retry in a new destination. Original/generated media are excluded from source publication. Gameplay, admission and item effects are unchanged.
