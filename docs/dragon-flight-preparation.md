# Prepare the dragon flight clips

Production playback reads three files and no other dragon media:

| Review index | Title | File | Original name | MIX entry |
| --- | --- | --- | --- | --- |
| 6 | Dragon · Departure | `assets/lol2/generated/dragon_flight/dragon7.ogv` | `WOMS\DRAGON\DRAGON7.VQA` | 3 |
| 7 | Dragon · Flight | `assets/lol2/generated/dragon_flight/drgnflgt.ogv` | `WOMS\DRAGON\DRGNFLGT.VQA` | 0 |
| 8 | Dragon · Arrival | `assets/lol2/generated/dragon_flight/dragon8.ogv` | `WOMS\DRAGON\DRAGON8.VQA` | 4 |

`scripts/lol2/cave_video_review.gd` stores those resource paths at indices 6, 7 and 8. `scripts/lol2/museum_walkthrough.gd` plays `DRAGON_CLIPS` `[6, 7, 8]` through `cave_video_overlay.gd`. That order is the recorded DLL name order DRAGON7, DRGNFLGT, DRAGON8. This preparation does not change those consumers.

Use the original installation and an isolated copy of lands-of-lore-2-re commit `2791eb11e453ad5cbccdce5d5d29efc1850a2d3c`. The exporter checks these published bytes before it reads the archive: `tools/convert_cave_video_review.py` `fd8a40bdd50b9394ac4a21574907562247cddd32ccded2491731c28922dde77d`, `tools/lol2_westwood_hash.py` `35f884e62cd2538f9071ccceb019dbaa37f3daa08b8f6b3b485629c7a25f1796`, and `tools/draracle/lol2_extract_draracle_geometry.py` `d2e959d2dc2a90f29387158d89e87fda4cdd29951d96f5dd094fef4803fedcba`. `DAT/DRAGON.MIX` must hash to `e1f6a78df62620d3b3219f9b4c1b5dcd63696c25851371563cf7e6869214cc39`. ffmpeg must provide `libtheora`, `libvorbis` and `vqavideo`.

```sh
python3 -S tools/export_dragon_flight.py \
  --game-root /path/to/original/game \
  --re-root /path/to/lands-of-lore-2-re \
  --out /path/to/fresh/dragon_flight
```

The command checks the archive, the three full-path hashes and entry indices, and the WVQA headers before it creates output. Conversions finish in a staging directory and move into place only after all three succeed. Final moves are sequential; an I/O failure during those moves is not an atomic directory replacement. A missing archive, a changed archive, or an invalid helper leaves an existing output directory unchanged. No-argument invocation is rejected.

Each clip keeps the converter's frame count, rate, dimensions and stream report. `provenance.json` keeps the archive hash, the WOMS name, the MIX entry, the source hash, the output hash, the frame count and the rate. Expected header counts are 160, 548 and 105 frames at 15 fps. The Ogg container bytes can differ between encodes. Compare decoded video and audio streams, and record the decoder exit status. This does not test audible playback, native launch conditions or scene integration.
