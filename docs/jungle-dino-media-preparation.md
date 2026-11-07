# Jungle dinosaur sprite preparation

The existing preparer accepts explicit original-game, texture and fresh output paths:

```sh
python3 -S tools/decode_level_texture.py --game "$GAME" --area L4_HJ --output "$FRESH_TEXTURE"
python3 tools/prepare_jungle_dino_sprites.py --game "$GAME" --texture "$FRESH_TEXTURE/texture.bin" --output-root "$FRESH_OUTPUT"
```

Requires Pillow and repository-local readers; texture decoding additionally needs system `liblzo2`. No RE checkout or native-analysis package is required. The source identity comes from published geometry profiles. The metadata and texture hashes are the same pins formerly read from the unpublished `jungle-dino-bindings.json`, now held directly by the preparer. Those were the only three fields it consumed from that audit; all original identity checks remain. Source metadata supplies all 11 selectors, directional views and frame events.

The output contains 133 indexed frame PNGs, a palette and `sprites.json` under `assets/lol2/generated/jungle_dino_sprites`. Copy that complete directory to the same path in a fresh asset assembly. `docs/jungle-dino-sprites-checks.json` under the output root is a receipt. It is not an additional runtime input. Existing output is refused; later decode or I/O failure can leave partial files in a new root.

Independent preparation from the original archive and freshly decoded texture reproduced all 135 runtime files byte-for-byte. Missing originals, a modified texture and existing output were rejected. The indexed-image writer and animation metadata remain unchanged; this does not change AI, clocks, damage, placement or shader behavior. Bare no-argument execution retains the historical game/texture/output defaults, but no longer requires the unpublished audit file.
