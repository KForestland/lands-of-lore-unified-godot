# Jungle village alarm audio preparation

Use the existing published audio helper with a fresh staging directory:

```sh
python3 tools/prepare_creature_audio_clips.py --game /path/to/original/game \
  --output-root /path/to/fresh-staging --folder jungle_village_alarm/sounds --request 403
```

Requires Python and FFmpeg plus the local `lol2_source_format.py` reader. This decodes the pinned LOCALLNG sound bank's request403, `bells1.aud`. The runtime pack consists only of `assets/lol2/generated/jungle_village_alarm/sounds/403.wav`; its SHA256 is `0d89c631830d7b72cd3373ae3befbd03e7b5d40322936a04bc9e101c2830b648`. The request, name and WAV hash match the published `scripts/lol2/jungle_village_alarm_source.json` sound record. An isolated run with just the helper and MIX reader reproduces the runtime WAV byte-for-byte.

The helper also writes `sounds/audio.json` as a diagnostic report and the original AUD under the staging `tmp` directory. Copy only the WAV into the prepared runtime pack. The lower-level helper permits overwriting outputs: choose an absent staging directory outside the original game tree. It validates bank identity, request bounds, AUD framing, PCM length and WAV round-trip. No source-contract regeneration or native alarm/archer replay is necessary for this media step. Existing gameplay and source contracts are unchanged. Original/generated media are excluded from source publication.
