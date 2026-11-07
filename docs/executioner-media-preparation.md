# Executioner sprite preparation

The existing media writers can assemble all 97 Executioner frames directly from the original Hive archive and freshly decoded texture:

```sh
python3 -S tools/decode_level_texture.py --game "$GAME" --area L5_HC --output "$FRESH_TEXTURE"
python3 tools/prepare_hive_executioner_sprites.py --game "$GAME" --texture "$FRESH_TEXTURE/texture.bin" --output-root "$FRESH_OUTPUT"
```

Requires Pillow and repository-local readers; texture extraction additionally needs system `liblzo2`. No RE checkout, capture directory or native-analysis package is needed by this explicit command. It checks original archive and texture hashes, then verifies all eight EXEC first-view resource bindings in the original state table before preparing images. Pose and attack frames use the existing block decoder; outcome frames retain their original 320×200 or 320×240 canvas sizes.

The output is `assets/lol2/generated/hive_executioner_sprites`: eight selector atlases and `sprites.json`. Copy that directory to the same path in a fresh asset assembly. The 32 pose, 35 attack and 30 outcome frames are decoded in a temporary directory which is removed afterwards. Two redundant first-frame previews produced internally by the pose writer are not additional animation frames or runtime files.

An independent run with minimal published helpers reproduced all nine runtime files byte-for-byte. Missing originals, wrong-area texture and existing output were rejected. Existing output is refused; failures during final atlas writing can leave partial files in a new root. Bare no-argument invocation retains the historical audit/export path and its research-workspace dependencies. Its dispatch and assembly were checked with stubbed audits after fixing an out-of-scope output variable; the actual native audits were not rerun. This change affects preparation, not clocks, combat or shader behavior.
