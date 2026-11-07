# Cave prop83 lift media preparation

The published `scripts/lol2/cave_prop83_lift_source.json` supplies the runtime filenames. Prepare fresh L1_DC props as in [the scenic-guard recipe](scenic-guard-movie-preparation.md), then extract audio into a separate fresh staging root:

```sh
python3 tools/prepare_creature_audio_clips.py --game "$GAME" \
  --output-root "$AUDIO_STAGE" --folder cave_prop83_lift --request 956
```

`GAME` is the supported original installation. The command requires FFmpeg and the published source reader. Its generic CLI can write into an existing directory, so select a fresh `AUDIO_STAGE`. It creates both `956.wav` and an additional `audio.json` extraction receipt.

Create a fresh final `assets/lol2/generated/cave_prop83_lift` directory and copy only the published contract's media into it:

- `956.wav` from `AUDIO_STAGE/assets/lol2/generated/cave_prop83_lift`;
- fresh `props/sprites/prop_19_frame_0.png` through `prop_19_frame_7.png`, renamed `prop83_0.png` through `prop83_7.png`;
- the corresponding eight `_index.png` files, renamed `prop83_0_index.png` through `prop83_7_index.png`.

Retain `audio.json` in the audio staging directory as extraction evidence. It is not a file in the existing lift runtime pack. Do not delete or overwrite historical packs to obtain a matching inventory.

Independent preparation reproduced all 17 contract-selected runtime files byte-identically from fresh original-derived props and the original sound bank. The gameplay source contract stays unchanged. This proves media preparation; it does not rerun native command analysis, replace the historical gameplay-source generator or establish live lift/audio acceptance.
