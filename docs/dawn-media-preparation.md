# Complete Dawn media preparation

Both Dawn encounters need dialogue and creature sprites. The dialogue commands alone omit the 233 sprite files in each pack. Use published source contracts, original game archives, Pillow, NumPy and FFmpeg; texture extraction additionally needs system `liblzo2`. These media commands need no RE checkout or native-analysis package. The shared importer preserves optional legacy lookup for older native-audit callers; an explicitly invalid `LOL2_RE_ROOT` remains an error.

Choose four fresh output directories for `JUNGLE_TEXTURE`, `HIVE_TEXTURE`, `JUNGLE_STAGE` and `HIVE_STAGE`. Run from the source checkout:

```sh
python3 -S tools/decode_level_texture.py --game "$GAME" --area L4_HJ --output "$JUNGLE_TEXTURE"
python3 -S tools/decode_level_texture.py --game "$GAME" --area L5_HC --output "$HIVE_TEXTURE"
python3 tools/prepare_jungle_dawn_media.py --game "$GAME" --source scripts/lol2/jungle_dawn_source.json --output-root "$JUNGLE_STAGE"
python3 tools/prepare_museum_creature_sprites.py --game "$GAME" --archive DAT/L4_HJ.MIX --texture "$JUNGLE_TEXTURE/texture.bin" --definition 8 --output "$JUNGLE_STAGE/assets/lol2/generated/jungle_dawn_media/sprites"
python3 tools/prepare_hive_dawn20_media.py --game "$GAME" --source scripts/lol2/hive_dawn20_source.json --output-root "$HIVE_STAGE"
python3 tools/prepare_museum_creature_sprites.py --game "$GAME" --archive DAT/L5_HC.MIX --texture "$HIVE_TEXTURE/texture.bin" --definition 3 --output "$HIVE_STAGE/assets/lol2/generated/hive_dawn20_media/sprites"
```

The Jungle exporter accepts both the published runtime contract and the historical source-audit format. It checks selector 10, resource 1, `E065E.VQA` and the contract's original archive hash before creating output. Its `media.json` records the hash of whichever contract was actually supplied. The historical audit file is not a prerequisite for this recipe.

Copy each completed `assets/lol2/generated/<encounter>` directory into a fresh asset assembly with the same relative path. Do not copy intermediate `tmp` movies or replace a dialogue-only directory over an existing pack: that would lose the creature sprites. The tracked population source JSONs remain the runtime configuration; these commands do not regenerate combat behavior.

Independent isolated preparation produced all 2,256 Jungle and 1,666 Hive files from original archives, newly decoded texture blobs and published source contracts. Every PNG and WAV matched the current pack byte-for-byte. Hive metadata also matched exactly; Jungle `media.json` differed only in the actual source-contract hash. The two 233-file sprite sets also matched independently. This establishes these two media packs, not full demo assembly, native visual parity or audible playback.
