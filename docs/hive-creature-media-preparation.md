# Hive warrior and worm media preparation

The existing sprite tools can use the published animation records without rerunning native analysis. They retain the same indexed-image and atlas writers:

```sh
python3 -S tools/decode_level_texture.py --game "$GAME" --area L5_HC --output "$FRESH_TEXTURE"
python3 tools/prepare_hive_warrior_sprites.py --game "$GAME" --texture "$FRESH_TEXTURE/texture.bin" --proof docs/hive-warrior-animation-checks.json --output-root "$FRESH_WARRIOR"
python3 tools/prepare_hive_worm_sprites.py --game "$GAME" --texture "$FRESH_TEXTURE/texture.bin" --proof docs/hive-worm-animation-checks.json --output-root "$FRESH_WORM"
```

Requires Pillow and repository-local readers; texture extraction additionally needs system `liblzo2`. No RE checkout, native replay or Capstone is required by these explicit commands. The Hive archive and decoded texture are hash-pinned. Each supplied animation record must contain the complete expected selector/resource/frame set, and its first-view resources are checked against original creature metadata before output creation. The records describe previously verified behavior; using them does not rerun or extend those native proofs.

Each output root must be fresh. Copy only its `assets/lol2/generated/hive_warrior_sprites` or `hive_worm_sprites` directory into a fresh asset assembly. The additional `docs/*-sprites-checks.json` is a preparation receipt, not runtime media. Failures during later decoding or writing may leave partial files in the new root.

Independent preparation from original media and freshly decoded texture matched all 106 warrior and 14 worm files byte-for-byte. Godot's existing `.png.import` sidecars were inventoried separately and are not produced by these media commands. Missing originals, incomplete animation records and existing output were rejected. Legacy no-argument invocation retains the full native verification path and its original dependencies; it was not rerun here. Combat, animation selection, clocks and shaders are unchanged. Indexed pixels and authored preview alpha/anchoring retain the limits stated in each manifest.
