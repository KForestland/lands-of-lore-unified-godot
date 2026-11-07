# Weapon-shop media preparation

With the published tools, the original game and the pinned RE video converter available, run:

```sh
python3 tools/prepare_weapon_shop.py --game /path/to/original/game \
  --re-root /path/to/repository --data scripts/lol2/weapon_shop_data.gd \
  --entrances scripts/lol2/weapon_shop_entrance_source.json --output-root /path/to/fresh-output
```

This builds the complete `assets/lol2/generated/weapon_shop` pack, including item icons. It consumes the published runtime PLANS/DURATIONS and compact entrance recipe, and derives entrance polygons and return pose from the original Jungle geometry. The recipe records the room-name-table selection and its provenance; preparation checks the original bytes and command list without repeating the historical native audit. No runtime contract or research report is rewritten.

Dependencies are `monastery_media.py`, `decode_monastery_vectors.py`, the published source readers, Pillow, ffmpeg/ffprobe, and `tools/convert_cave_video_review.py` from RE revision `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c` (SHA256 `fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d`). Use ordinary Python without optimization: this path retains assertion checks. The no-argument entry point preserves the historical native workflow and its research dependencies.

An independent clean-tree extraction reproduced all 239 runtime files: 236 byte-identical files, two backgrounds with equal decoded RGB and encoded packet hashes, and one converter report differing only in paths and ffmpeg pointer addresses. All 231 manifest resource references resolved. The exterior source records eight identical frames; the existing Theora conversion produces one frame in both historical and fresh outputs. The interior background has 30 frames. Original containers may differ in serial metadata.

Existing output, missing originals and incorrect recipe controls reject without modifying output. Inputs are checked before staging; a later decode or duration failure may leave partial fresh output, which should be retained for diagnosis. This proves media preparation, not native callbacks, live admission, combat, audible quality or a whole-game clean build.
