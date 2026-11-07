# Jungle actor62 media preparation

The published sprite and audio writers can prepare this complete encounter pack. Use the freshly decoded L4_HJ `texture.bin` and the supported original installation:

```sh
python3 tools/prepare_museum_creature_sprites.py --game "$GAME" \
  --archive DAT/L4_HJ.MIX --texture "$TEXTURE" --definition 1 \
  --output "$OUTPUT/assets/lol2/generated/jungle_actor62/sprites"
python3 tools/prepare_creature_audio_clips.py --game "$GAME" \
  --output-root "$AUDIO_STAGE" --folder jungle_actor62/voice \
  --request 243 --request 258 --request 325 --request 333
```

Choose new `OUTPUT` and `AUDIO_STAGE` directories; these shared writers do not enforce a fresh whole-project output. Copy the four WAVs from `AUDIO_STAGE/assets/lol2/generated/jungle_actor62/voice` into the same relative directory under `OUTPUT`. Keep the generic CLI's extra `audio.json` receipt in the audio staging directory; it is not part of the existing runtime pack.

The published `scripts/lol2/jungle_actor62_source.json` binds requests 243, 258, 325 and 333 to `0120704e.aud`, `0120604e.aud`, `0220504e.aud` and `0220404e.aud`, respectively, including paths, durations and WAV hashes. Preparation uses original definition1 (TIG_MAL). Pillow, NumPy and FFmpeg are required; the explicit media path needs no RE checkout.

An isolated independent run regenerated all 767 files byte-identically, including the complete sprite manifest and all four voice clips. Voice paths, names, durations and hashes matched the published encounter contract. The run used the shared `stage_clips(..., game=...)` API, which emits only the WAV files rather than the CLI's extra receipt.

This recipe prepares media only. Existing actor/group/region/predicate source contracts remain unchanged. It does not rerun the historical actor62 audit or establish native event delivery, timing, audible quality or whole-Act-1 acceptance.
