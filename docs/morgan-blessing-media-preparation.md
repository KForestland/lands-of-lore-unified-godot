# Morgan blessing media preparation

From the source checkout:

```sh
python3 tools/prepare_morgan_blessing.py \
  --game /path/to/original-game \
  --plans scripts/lol2/morgan_orb_blessing.gd \
  --conversation scripts/lol2/monastery_conversation.gd \
  --output-root /path/to/fresh-output
```

Use a new output directory separate from the originals and source. Python 3, Pillow, ffmpeg and the published monastery media helpers are required. No RE checkout, native replay or historical generated pack is needed by the explicit path. Use ordinary Python without optimization because verification includes assertions.

The command pins MGAR.MIX and both published runtime scripts. It checks the fixed blessing lines 254/255 and refusal line 165 against the offer plan, then checks original VQA frame and SND2 sample counts against the conversation contract before writing. These are existing recorded selections; no native replay is rerun. The output is 40 patch atlases, three WAVs and `clips.json` under `assets/lol2/generated/morgan_blessing`, with intermediate original media under `tmp/morgan_blessing_source`. Keep generated media local.

The no-argument entry point retains its historical Room reader and imports. Its staging body is unchanged after extracting the archive argument and sequence constant; the shared staging helper additionally returns the sequences for final checks. Existing output, missing originals and incorrect contracts are refused. Decoder failures may leave partial output; preserve it and retry with a new directory.

Independent extraction from committed helpers reproduced all 44 runtime files byte-for-byte, including every atlas and WAV. All 43 manifest media references resolve. Three negative controls (existing output, missing game, wrong plan) passed. The isolated import record contains no native audit or RE modules. This is preparation evidence, not native room-execution or full Act 1 acceptance; R18 is unchanged.
