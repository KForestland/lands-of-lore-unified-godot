# Hive Ancient Stone preparation

```sh
python3 tools/prepare_hive_ancient_stone_media.py --game /path/to/original/game --output-root /path/to/fresh-output
```

Requires Python, NumPy, Pillow, FFmpeg and the published local item/movie readers. Produces all six files under `assets/lol2/generated/hive_ancient_stone`: inventory icon, four RGB atlas pages and `stone.json`, plus `docs/hive-ancient-stone-source.json`. All runtime files and the report match the existing outputs byte-for-byte.

GLOBAL/LOCAL/RUNES archives and the item/graphics/movie payloads are pinned. Definition68's original name, identity and resource308 are verified directly. The old supplementary generated label lookup is unnecessary because the original name check and fixed runtime identifier remain. RUNES archive identity replaces the old audit-file lookup; the movie binding and metadata use the published equivalent reader. No new recipe or historical generated input is required, and the legacy producer remains untouched.

The published VQA classifier identifies RUNES3_ as non-partial, so this55-frame film follows the producer's existing FFmpeg fallback. The isolated proof verifies all resulting atlas bytes against the shipped pack; audio samples remain0. FFmpeg emits end-of-stream demux diagnostics but exits successfully and produces the expected55frames. The Python partial-codebook decoder is retained for the existing decision path, not claimed as the decoder used for this film. No RE/native replay modules are imported.

The destination must be absent and outside the original game tree. Existing-output, missing-game, altered-archive and overlapping-output controls pass. Later decode/filesystem failures can leave partial output; retry in a new destination. Original/generated media are excluded from source publication. Playback layout and the historical scope text remain unchanged; source-contract gameplay and item effects are not modified. Whole-build qualification remains separate.
