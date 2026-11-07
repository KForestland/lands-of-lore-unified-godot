# Monastery side rooms and Moff media preparation

Use separate fresh output roots for these commands:

```sh
python3 tools/prepare_monastery_side_rooms.py --game "$GAME" --re-root "$RE" \
  --fixture tests/fixtures/monastery_side_rooms.json \
  --recipe scripts/lol2/monastery_side_rooms_source.json --output-root "$SIDE_OUTPUT"
python3 tools/prepare_moff_revisit.py --game "$GAME" \
  --checks docs/moff-revisit-checks.json --output-root "$MOFF_OUTPUT"
```

The side-room command stages `monastery_side_rooms` (cellar and garden); the Moff command stages `monastery_moff` (Julian revisit/exit clips and the Power Orb icon). Both consume published recorded selections and verify original resource bindings. Explicit mode does not write fixtures or research reports. Historical no-argument entry points retain their prior research dependencies and outputs.

Requirements are Pillow, ffmpeg/ffprobe and the published movie/source/sprite readers with `monastery_media.py` and `decode_monastery_vectors.py`. Side-room backgrounds additionally use the pinned RE `tools/convert_cave_video_review.py` from revision `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c`, SHA256 `fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d`. Moff needs no RE converter. Use ordinary Python without optimization; assertion checks are retained.

The compact side-room recipe carries only the historical callback lists retained in `rooms.json` provenance. It records their source document and producer hashes. The tool checks their rel32 targets against original DLL bytes without repeating the disassembly; fixture data supplies the media sequences. This is recorded callback provenance, not new native execution evidence.

Independent extraction from an isolated source tree reproduced 199 side-room files (195 byte-identical files, two 30-frame backgrounds with equal decoded RGB and encoded packets, and two converter reports differing only in paths and ffmpeg pointer addresses). All 174 Moff files matched byte-for-byte. The side-room manifest's 196 resource references resolved, and the recipe callbacks and provenance hashes matched their recorded sources. Existing-output, missing-game and wrong-contract controls passed for both commands.

Output roots must be fresh. Later decoding failures can leave partial output for diagnosis. These recipes verify the complete existing packs, not callback execution, presentation, native timing, audible quality or the whole clean Act 1 pipeline.
