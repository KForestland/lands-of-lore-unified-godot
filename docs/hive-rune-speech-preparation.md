# Hive rune speech preparation

From the source checkout:

```sh
python3 tools/prepare_hive_rune_speech.py \
  --game /path/to/original-game \
  --room-plan scripts/lol2/hive_rune_room.gd \
  --speech scripts/lol2/hive_rune_speech.gd \
  --liz-source scripts/lol2/liz_room_source.json \
  --output-root /path/to/fresh-output
```

Use a new destination separate from inputs. Python 3, ffmpeg, the published MIX reader and `prepare_magic_shop_offers.py` are required. No RE checkout, native replay or unpublished audit document is loaded in explicit mode. Use ordinary Python without optimization because verification includes assertions.

All fifteen speaker/line selections are checked against the published room and speech plans. The command pins those scripts, the LIZ cue contract, the formula helper, LOCALLNG.MIX and its sound bank. Speaker 2 uses the published trailer formula with bias141. Speaker100 line2 uses bias268 and is checked against the published LIZ cue's request, name, byte count and audio hash. These are existing recorded mappings, not newly derived native behavior. No new recipe is required.

The command computes all bank records before writing, then stages fifteen WAVs and `speech.json` under `assets/lol2/generated/hive_rune_speech`, with original AUD caches under `tmp/hive_rune_speech`. WAV sample counts, channel count and rate are checked. Keep original and generated media local. Existing output, missing inputs and incorrect pins are refused; later decoder failures can leave partial output, which should be preserved before retrying in a fresh directory.

The legacy no-argument producer still performs its original native replay and writes its historical source report. Its main function and replay class are AST-identical. Explicit mode does not repeat native binding, producer or setup-reset checks and writes no audit report.

Independent isolated reconstruction reproduced all sixteen runtime files byte-for-byte. All fifteen manifest resource paths resolve and their WAV hashes match. No forbidden native imports were loaded. Existing output, missing game and wrong-plan controls passed. This verifies preparation, not audible playback or whole Act 1 acceptance; R18 is unchanged.
