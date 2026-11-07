# Act 1 departure media preparation

Prepare the complete departure pack with:

```sh
python3 tools/prepare_act_one_departure.py --game /path/to/original/game \
  --re-root /path/to/lands-of-lore-2-re \
  --recipe scripts/lol2/act_one_departure_source.json --output-root /path/to/fresh-output
```

The command derives departure regions and the destination arrival from original L4_HJ/L8_SJ geometry using published readers, looks up the original E125E movie, and stages `assets/lol2/generated/act_one_departure`. No historical generated geometry is required. The separate [darker-Jungle recipe](darker-jungle-preparation.md) prepares the destination pack.

The compact recipe records two historical fixup lookups and three opcode21 argument cases with source/producer provenance. Preparation checks original executable bytes, implied fixup targets and the handler call. It does not repeat the fixup-table walk or native emulation. Geometry and movie bindings are re-derived, not copied from that recipe.

Dependencies are Pillow, NumPy, FFmpeg/ffprobe, published geometry/movie readers, `monastery_media.py`, `decode_monastery_vectors.py`, and the pinned RE `tools/convert_cave_video_review.py` from revision `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c` (SHA256 `fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d`). Use ordinary Python without optimization; assertion checks are retained.

Independent fresh extraction checked all 24 runtime files: 22 were byte-identical; the OGV matched all 318 decoded RGB frames, decoded PCM and encoded packets. `playback.json` matched every value except informational `decoder_note` wording, with a different key order. The shipped manifest predates the current playback producer; the unchanged legacy producer has the same difference. All 22 resource references resolved. Recipe provenance hashes and existing-output/missing-game/wrong-recipe controls passed.

The manifest difference is accepted for preparation because it changes no consumed paths or numbers. This does not assert byte-identical manifests or Ogg containers. The verified R18 candidate remains unchanged.

Explicit mode writes no research reports. Historical entry points retain their prior behavior and dependencies. The output root must be fresh; later decoding failures can leave partial output for diagnosis. Native timing, live route acceptance, audible quality and complete clean Act 1 preparation remain separate checks.
