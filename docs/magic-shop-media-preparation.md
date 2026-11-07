# Magic-shop media preparation

Generate both `assets/lol2/generated/magic_shop` and `magic_shop_offers` with:

```sh
python3 tools/prepare_magic_shop.py --game /path/to/original/game \
  --re-root /path/to/repository --callbacks docs/magic-shop-callbacks-checks.json \
  --output-root /path/to/fresh-output
```

Selections come from the published callback contract: the setup idle, entry dialogue and broken-Thohan knowledge response, followed by the remaining offer requests. The tool checks original archive and sound-bank pins and resolves the selected resources. It does not require generated room or Hive speech inputs. No new recipe is needed.

Dependencies are the published source readers, `monastery_media.py`, `decode_monastery_vectors.py`, Pillow, ffmpeg/ffprobe, and the pinned RE `tools/convert_cave_video_review.py` from revision `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c` (SHA256 `fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d`). Use ordinary Python without optimization; assertion checks are retained. The output must be fresh. Later decoding failures can leave partial output for diagnosis.

Independent extraction from an isolated source tree reproduced 180 room files and 69 offer files: 247 byte-identical files, a 29-frame video-only background with equal decoded RGB and encoded packet hashes, and a converter report differing only in paths and ffmpeg pointer addresses. All 246 manifest resource references resolved. Existing-output, missing-game and wrong-contract controls rejected without modifying output.

The generated offer report retains historical provenance, including the earlier Hive trailer-formula cross-check. Explicit preparation does not repeat that check against the generated Hive pack; both affected sound-bank WAVs match existing output. The local shape reader retains the existing decoding behavior. No-argument entry points preserve the historical research workflow and report writes; explicit mode writes only media packs and intermediate cache.

This verifies preparation of the recorded media selections. It does not establish native callback execution, presentation flags, live appearance, timing, audible quality or complete clean Act 1 assembly.
